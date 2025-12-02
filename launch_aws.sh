#!/bin/bash
set -e
set -o pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/launch_aws.log"
ERROR_LOG_FILE="${SCRIPT_DIR}/launch_aws_errors.log"
source "${SCRIPT_DIR}/common.sh"

# --- COMMAND-LINE ARGUMENTS ---
KEY_PATH=""
KEY_NAME=""              # Derived from KEY_PATH basename in validate_arguments()
INSTANCE_TYPE="c7i.12xlarge"
USER_REGION=""           # If specified, all files launch in this region
REPLACE_INSTANCE_ID=""   # If set, update this instance ID instead of adding new entry
declare -a FDS_FILES=()

# --- CONSTANTS ---
CLOUD_INIT_FILE="fds-cloud-init.yaml"
S3_BUCKET_REGION="us-east-1" # S3 bucket region (us-east-1 for global accessibility)
S3_BUCKET="fds-output-wang-fuk-fire"
IAM_ROLE_NAME="fds-s3-access-role"
INSTANCE_PROFILE_NAME="fds-s3-access-profile"

# --- CLEANUP ---

# Safety net for Ctrl+C during instance setup.
# If user interrupts while an instance is launching but before setup completes,
# the instance would be left running. This trap ensures we clean up.
# Normal error handling is done by cleanup_instance() in setup_instance().
function handle_interrupt() {
    echo ""
    echo "Interrupted!"

    # Query DB for all pending instances and terminate them
    if check_instances_db; then
        local PENDING_COUNT=0
        while IFS='|' read -r INSTANCE_ID REGION_NAME; do
            : $((PENDING_COUNT++))
            echo "   Terminating $INSTANCE_ID in $REGION_NAME..."
            aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION_NAME" 2> /dev/null || true
            update_instance_status "$INSTANCE_ID" "terminated"
        done < <(get_pending_instances)

        if [ "$PENDING_COUNT" -gt 0 ]; then
            echo "Cleaned up $PENDING_COUNT pending instance(s)"
        fi
    fi

    exit 130 # Standard exit code for Ctrl+C (128 + SIGINT=2)
}

trap handle_interrupt INT

# Cleanup a specific instance
function cleanup_instance() {
    local INSTANCE_ID=$1
    local INSTANCE_REGION=$2

    if [ -z "$INSTANCE_ID" ]; then
        return
    fi

    echo "   Cleaning up instance $INSTANCE_ID..."
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$INSTANCE_REGION" > /dev/null 2>&1 || true
    update_instance_status "$INSTANCE_ID" "terminated"
}

# Mark instance as successfully completed setup
function complete_instance() {
    local INSTANCE_ID=$1

    # Update status from 'pending' to 'active'
    update_instance_status "$INSTANCE_ID" "active"
}

# --- NETWORK FUNCTIONS ---

function setup_internet_gateway() {
    local REGION=$1
    local VPC_ID=$2
    local IGW_ID

    # Check if IGW is already attached to this VPC
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --region "$REGION" \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query "InternetGateways[*].InternetGatewayId" \
        --output text) || {
        log_error "Failed to query Internet Gateways"
        return 1
    }

    if [ -z "$IGW_ID" ] || [ "$IGW_ID" == "None" ]; then
        IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" --query 'InternetGateway.InternetGatewayId' --output text) || {
            log_error "Failed to create Internet Gateway"
            return 1
        }
        aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$REGION" > /dev/null || {
            log_error "Failed to attach Internet Gateway"
            return 1
        }
    fi

    echo "$IGW_ID"
}

function setup_route_table() {
    local REGION=$1
    local VPC_ID=$2
    local IGW_ID=$3
    local RT_ID

    # Check for existing custom route table in this VPC with route to IGW
    RT_ID=$(aws ec2 describe-route-tables \
        --region "$REGION" \
        --filters "Name=vpc-id,Values=$VPC_ID" \
                  "Name=route.gateway-id,Values=$IGW_ID" \
        --query "RouteTables[*].RouteTableId" \
        --output text) || {
        log_error "Failed to query Route Tables"
        return 1
    }

    if [ -z "$RT_ID" ] || [ "$RT_ID" == "None" ]; then
        RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text) || {
            log_error "Failed to create Route Table"
            return 1
        }

        aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$REGION" > /dev/null || {
            log_error "Failed to create route"
            return 1
        }
    fi

    echo "$RT_ID"
}

function create_subnet() {
    local AZ=$1
    local CIDR_OCTET=$2
    local REGION=$3
    local VPC_ID=$4
    local RT_ID=$5
    local NEW_SUBNET

    NEW_SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "10.0.${CIDR_OCTET}.0/24" --availability-zone "$AZ" --region "$REGION" --query 'Subnet.SubnetId' --output text) || {
        log_error "Failed to create subnet in $AZ"
        return 1
    }

    aws ec2 modify-subnet-attribute --subnet-id "$NEW_SUBNET" --map-public-ip-on-launch --region "$REGION" > /dev/null || {
        log_error "Failed to modify subnet attributes"
        return 1
    }

    aws ec2 associate-route-table --subnet-id "$NEW_SUBNET" --route-table-id "$RT_ID" --region "$REGION" > /dev/null || true

    echo "$NEW_SUBNET"
}

function setup_subnets() {
    local REGION=$1
    local VPC_ID=$2
    local RT_ID=$3
    local -a SUBNET_IDS=()

    # Get actual availability zones for this region
    local AZS_RAW
    AZS_RAW=$(aws ec2 describe-availability-zones --region "$REGION" --filters "Name=state,Values=available" --query "AvailabilityZones[*].ZoneName" --output text) || {
        log_error "Failed to query availability zones"
        return 1
    }

    # Convert to array
    local -a AZS
    read -ra AZS <<< "$AZS_RAW"
    local CIDR_OCTET=1

    for AZ in "${AZS[@]}"; do
        local EXISTING_SUBNET
        EXISTING_SUBNET=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=availability-zone,Values=$AZ" --query "Subnets[*].SubnetId" --output text) || {
            log_error "Failed to query subnets"
            return 1
        }

        if [ -z "$EXISTING_SUBNET" ] || [ "$EXISTING_SUBNET" == "None" ]; then
            local NEW_SUBNET
            NEW_SUBNET=$(create_subnet "$AZ" "$CIDR_OCTET" "$REGION" "$VPC_ID" "$RT_ID") || return 1
            SUBNET_IDS+=("$NEW_SUBNET")
        else
            SUBNET_IDS+=("$EXISTING_SUBNET")
        fi
        : $((CIDR_OCTET++))
    done

    echo "${SUBNET_IDS[@]}"
}

function setup_security_group() {
    local REGION=$1
    local VPC_ID=$2
    local SG_ID
    SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=fds-sg" --query "SecurityGroups[*].GroupId" --output text) || {
        log_error "Failed to query security groups"
        return 1
    }

    if [ -z "$SG_ID" ] || [ "$SG_ID" == "None" ]; then
        SG_ID=$(aws ec2 create-security-group --group-name fds-sg --description "FDS SSH Access" --vpc-id "$VPC_ID" --region "$REGION" --query 'GroupId' --output text) || {
            log_error "Failed to create security group"
            return 1
        }

        # Get current public IP
        local MY_IP
        MY_IP=$(curl -s --retry 3 --retry-delay 1 --max-time 5 https://checkip.amazonaws.com)
        if [ -z "$MY_IP" ]; then
            log_error "Failed to detect current IP address after retries"
            return 1
        fi

        aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP/32" --region "$REGION" > /dev/null || {
            log_error "Failed to authorize security group ingress"
            return 1
        }
    fi

    echo "$SG_ID"
}

function setup_key_pair() {
    local REGION=$1

    log "Checking/Importing key pair in $REGION"
    # Check if key pair exists in this region
    local KEY_EXISTS
    KEY_EXISTS=$(aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" --query "KeyPairs[*].KeyName" --output text 2> /dev/null || echo "")

    if [ -z "$KEY_EXISTS" ]; then
        log "Importing key pair to $REGION"
        aws ec2 import-key-pair --region "$REGION" --key-name "$KEY_NAME" --public-key-material fileb://<(ssh-keygen -y -f "$KEY_PATH") > /dev/null || {
            log_error "Failed to import key pair"
            return 1
        }
        log "Key pair imported successfully"
    else
        log "Key pair already exists in $REGION"
    fi
}

function setup_s3_bucket() {
    log "Checking/Creating S3 bucket: $S3_BUCKET"
    if ! aws s3 ls "s3://${S3_BUCKET}" --region "$S3_BUCKET_REGION" 2> /dev/null; then
        log "Creating S3 bucket: $S3_BUCKET"
        aws s3api create-bucket --bucket "$S3_BUCKET" --region "$S3_BUCKET_REGION"
        log "S3 bucket created: $S3_BUCKET"
    else
        log "S3 bucket already exists: $S3_BUCKET"
    fi
}

function setup_iam_role() {
    log "Checking/Creating IAM role: $IAM_ROLE_NAME"
    # Check if role exists
    if ! aws iam get-role --role-name "$IAM_ROLE_NAME" > /dev/null 2>&1; then
        log "Creating IAM role: $IAM_ROLE_NAME"
        # Create trust policy for EC2
        local TRUST_POLICY='{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "ec2.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }'

        aws iam create-role \
            --role-name "$IAM_ROLE_NAME" \
            --assume-role-policy-document "$TRUST_POLICY" \
            --description "FDS EC2 instances S3 access" > /dev/null || {
            log_error "Failed to create IAM role"
            return 1
        }

        # Attach S3 full access policy
        aws iam attach-role-policy \
            --role-name "$IAM_ROLE_NAME" \
            --policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess" || {
            log_error "Failed to attach S3 policy"
            return 1
        }
        log "IAM role created successfully"
    else
        log "IAM role already exists: $IAM_ROLE_NAME"
    fi

    # Check if instance profile exists
    log "Checking/Creating instance profile: $INSTANCE_PROFILE_NAME"
    if ! aws iam get-instance-profile --instance-profile-name "$INSTANCE_PROFILE_NAME" > /dev/null 2>&1; then
        log "Creating instance profile: $INSTANCE_PROFILE_NAME"
        aws iam create-instance-profile \
            --instance-profile-name "$INSTANCE_PROFILE_NAME" > /dev/null || {
            log_error "Failed to create instance profile"
            return 1
        }

        # Add role to instance profile
        aws iam add-role-to-instance-profile \
            --instance-profile-name "$INSTANCE_PROFILE_NAME" \
            --role-name "$IAM_ROLE_NAME" || {
            log_error "Failed to add role to instance profile"
            return 1
        }

        log "Instance profile created, waiting 10s for IAM propagation"
        sleep 10
    else
        log "Instance profile already exists: $INSTANCE_PROFILE_NAME"
    fi
}

function find_ami() {
    local REGION=$1
    local ami
    ami=$(aws ec2 describe-images \
        --region "$REGION" \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text 2>&1)

    if [ -z "$ami" ] || [ "$ami" == "None" ]; then
        log_error "Could not find Ubuntu 24.04 AMI in $REGION"
        return 1
    fi

    echo "$ami"
}

# --- INSTANCE FUNCTIONS ---

function try_launch_in_subnet() {
    local SIM_FILE=$1
    local SUBNET=$2
    local REGION=$3
    local AMI_ID=$4
    local SG_ID=$5

    aws ec2 run-instances \
        --region "$REGION" \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --subnet-id "$SUBNET" \
        --security-group-ids "$SG_ID" \
        --iam-instance-profile "Name=$INSTANCE_PROFILE_NAME" \
        --user-data "file://${SCRIPT_DIR}/${CLOUD_INIT_FILE}" \
        --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=fds-${SIM_FILE%.fds}}]" \
        --query 'Instances[*].InstanceId' \
        --output text
}

function launch_instance() {
    local SIM_FILE=$1
    local REGION=$2
    local AMI_ID=$3
    local SG_ID=$4
    # shellcheck disable=SC2178
    local SUBNET_IDS=$5
    local INSTANCE_ID=""

    log "Launching instance for $SIM_FILE in $REGION"

    # shellcheck disable=SC2128
    for SUBNET in $SUBNET_IDS; do
        log "Trying subnet: $SUBNET"
        if INSTANCE_ID=$(try_launch_in_subnet "$SIM_FILE" "$SUBNET" "$REGION" "$AMI_ID" "$SG_ID"); then
            log "Successfully launched instance $INSTANCE_ID"
            break
        fi
    done

    if [ -z "$INSTANCE_ID" ]; then
        log_error "Could not launch instance for $SIM_FILE in any subnet"
        return 1
    fi

    log "Waiting for instance $INSTANCE_ID to be running..."
    if ! aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"; then
        log_error "Instance $INSTANCE_ID failed to start"
        return 1
    fi
    log "Instance $INSTANCE_ID is running"

    local PUBLIC_IP
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text) || {
        log_error "Failed to get public IP for $INSTANCE_ID"
        return 1
    }

    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "None" ]; then
        log_error "Instance $INSTANCE_ID has no public IP"
        return 1
    fi

    # Insert into database with 'pending' status immediately
    if [ -n "$REPLACE_INSTANCE_ID" ]; then
        update_instance "$REPLACE_INSTANCE_ID" "$INSTANCE_ID" "$PUBLIC_IP" "$REGION" "pending"
    else
        add_instance "$PUBLIC_IP" "$INSTANCE_ID" "$SIM_FILE" "$REGION" "$INSTANCE_TYPE"
    fi

    log "Instance $INSTANCE_ID has IP $PUBLIC_IP"
    echo "$INSTANCE_ID $PUBLIC_IP"
}

# --- SSH FUNCTIONS ---

function wait_for_ssh() {
    local PUBLIC_IP=$1
    local TIMEOUT=${2:-300}
    local ELAPSED=0

    log "Waiting for SSH on $PUBLIC_IP (timeout: ${TIMEOUT}s)"
    while ! nc -z -w 5 "$PUBLIC_IP" 22 2> /dev/null; do
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
            log_error "SSH timeout after ${TIMEOUT}s"
            return 1
        fi
        sleep 5
        : $((ELAPSED += 5))
    done
    log "SSH ready on $PUBLIC_IP"
    sleep 3
}

function ssh_exec() {
    local PUBLIC_IP=$1
    local COMMAND=$2
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$KEY_PATH" "ubuntu@$PUBLIC_IP" "$COMMAND"
}

function wait_for_cloud_init() {
    local PUBLIC_IP=$1
    local TIMEOUT=${2:-900}

    log "Waiting for cloud-init on $PUBLIC_IP (timeout: ${TIMEOUT}s)"
    # Use cloud-init status --wait with timeout
    ssh_exec "$PUBLIC_IP" "timeout $TIMEOUT cloud-init status --wait" 2> /dev/null
    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        log "Cloud-init completed successfully on $PUBLIC_IP"
        return 0
    else
        # Check if it was a timeout (exit code 124) or actual failure
        if [ $EXIT_CODE -eq 124 ]; then
            log_error "Cloud-init timeout after ${TIMEOUT}s"
        else
            log_error "Cloud-init failed"
        fi

        echo "--- Cloud-init Output ---" >&2
        ssh_exec "$PUBLIC_IP" "tail -50 /var/log/cloud-init-output.log 2>/dev/null" || true
        return 1
    fi
}

# --- QUOTA FUNCTIONS ---

function select_region_with_quota() {
    local INSTANCE_TYPE=$1
    local REQUIRED_VCPUS=$2

    # Get sorted list of regions by price
    local REGION_PRICES
    REGION_PRICES=$(get_region_prices "$INSTANCE_TYPE")
    if [ -z "$REGION_PRICES" ]; then
        log_error "Failed to get region prices"
        return 1
    fi

    # Iterate through regions from cheapest to most expensive
    for PRICE_REGION in $REGION_PRICES; do
        local PRICE="${PRICE_REGION%|*}"
        local TEST_REGION="${PRICE_REGION#*|}"

        log "Checking region $TEST_REGION (\$$PRICE)"

        # Check if quota is available in this region
        if check_quota_available "$TEST_REGION" "$INSTANCE_TYPE" "$REQUIRED_VCPUS"; then
            log "Selected region: $TEST_REGION (\$$PRICE)"
            echo "$TEST_REGION"
            return 0
        fi
    done

    log_error "No region with sufficient quota found"
    return 1
}

function check_quota_available() {
    local REGION=$1
    local INSTANCE_TYPE=$2
    local REQUIRED_VCPUS=$3

    log "Checking spot quota for $INSTANCE_TYPE in $REGION (requires $REQUIRED_VCPUS vCPUs)"

    # Dynamically look up the quota code and value for spot instances in one call
    local QUOTA_INFO
    QUOTA_INFO=$(aws service-quotas list-service-quotas \
        --service-code ec2 \
        --region "$REGION" \
        --query 'Quotas[?contains(QuotaName, `Spot`) && contains(QuotaName, `Standard`)] | [0]' \
        --output json 2>/dev/null) || {
        log_warning "Failed to get quota info for spot instances"
        return 1
    }

    if [ -z "$QUOTA_INFO" ] || [ "$QUOTA_INFO" == "null" ]; then
        log_warning "No spot instance quota found in $REGION"
        return 1
    fi

    local QUOTA_CODE
    local QUOTA_VALUE
    QUOTA_CODE=$(echo "$QUOTA_INFO" | jq -r '.QuotaCode // empty')
    QUOTA_VALUE=$(echo "$QUOTA_INFO" | jq -r '.Value // empty')

    if [ -z "$QUOTA_CODE" ] || [ -z "$QUOTA_VALUE" ]; then
        log_warning "Invalid quota info in $REGION"
        return 1
    fi

    log "Using quota code: $QUOTA_CODE, value: $QUOTA_VALUE vCPUs"

    # Get current spot instance usage
    local CURRENT_USAGE
    CURRENT_USAGE=$(aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=instance-state-name,Values=running,pending" \
                  "Name=instance-lifecycle,Values=spot" \
        --query 'Reservations[].Instances[].{Type:InstanceType}' \
        --output json 2>/dev/null | \
        jq -r '[.[] | select(.Type | startswith("c7")) | 48] | add // 0') || {
        log_warning "Failed to get current usage, assuming full usage"
        return 1
    }

    log "Spot quota: $QUOTA_VALUE vCPUs, Current usage: $CURRENT_USAGE vCPUs, Required: $REQUIRED_VCPUS vCPUs"

    local AVAILABLE
    AVAILABLE=$(echo "$QUOTA_VALUE - $CURRENT_USAGE" | bc)

    if (( $(echo "$AVAILABLE >= $REQUIRED_VCPUS" | bc -l) )); then
        log "Sufficient spot quota available: $AVAILABLE vCPUs available"
        return 0
    else
        log_warning "Insufficient spot quota: only $AVAILABLE vCPUs available, need $REQUIRED_VCPUS"
        return 1
    fi
}

function get_instance_vcpus() {
    local INSTANCE_TYPE=$1

    # Query AWS for instance type vCPU count
    local VCPUS
    VCPUS=$(aws ec2 describe-instance-types \
        --instance-types "$INSTANCE_TYPE" \
        --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' \
        --output text 2>/dev/null) || {
        log_error "Failed to get vCPU count for $INSTANCE_TYPE"
        return 1
    }

    if [ -z "$VCPUS" ] || [ "$VCPUS" == "None" ]; then
        log_error "No vCPU info for $INSTANCE_TYPE"
        return 1
    fi

    echo "$VCPUS"
}

# --- SIMULATION FUNCTIONS ---

function upload_file() {
    local SIM_FILE=$1
    local PUBLIC_IP=$2

    log "Uploading $SIM_FILE to $PUBLIC_IP"
    if ! scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$KEY_PATH" "$SIM_FILE" "ubuntu@$PUBLIC_IP:/home/ubuntu/"; then
        log_error "Failed to upload $SIM_FILE"
        return 1
    fi
    log "Successfully uploaded $SIM_FILE"
}

function start_simulation() {
    local SIM_FILE=$1
    local PUBLIC_IP=$2
    local REMOTE_FILE
    REMOTE_FILE=$(basename "$SIM_FILE")
    local CHID
    CHID=$(basename "$SIM_FILE" .fds)

    # Count number of meshes in FDS file (one MPI process per mesh)
    local NUM_MESHES
    NUM_MESHES=$(grep -c "^&MESH" "$SIM_FILE" || echo "1")

    log "Creating working directory for $CHID"
    # Create CHID subdirectory in working directory
    if ! ssh_exec "$PUBLIC_IP" "mkdir -p /home/ubuntu/fds-work/$CHID"; then
        log_error "Failed to create working directory"
        return 1
    fi

    # Check for existing restart files in S3 and download if present
    log "Checking for restart files in S3 for $CHID"
    if ssh_exec "$PUBLIC_IP" "ls /mnt/fds-output/$CHID/*.restart 2>/dev/null" > /dev/null 2>&1; then
        log "Found restart files, downloading for restart"
        if ! ssh_exec "$PUBLIC_IP" "rsync -av /mnt/fds-output/$CHID/ /home/ubuntu/fds-work/$CHID/"; then
            log_warning "Failed to download restart files, starting fresh"
        else
            log "Restart files downloaded successfully"
        fi
    else
        log "No restart files found, starting fresh"
    fi

    log "Starting simulation in tmux ($NUM_MESHES MPI processes)"
    if ! ssh_exec "$PUBLIC_IP" "tmux new-session -d -s fds_run 'tmux set-option -t fds_run remain-on-exit on && source \$HOME/FDS/FDS6/bin/FDS6VARS.sh && cd /home/ubuntu/fds-work/$CHID && mpiexec -n ${NUM_MESHES} fds \$HOME/$REMOTE_FILE'"; then
        log_error "Failed to start simulation"
        return 1
    fi
    log "Simulation started successfully for $CHID"
}

# --- OUTPUT FUNCTIONS ---

function print_summary() {
    echo ""
    echo "========================================"
    echo "LAUNCH SUMMARY"
    echo "========================================"

    local INSTANCE_COUNT=0
    local FILE_NUM=0

    while IFS='|' read -r IP INSTANCE_ID SIM_FILE REGION INSTANCE_TYPE; do
        [ -z "$IP" ] && continue
        : $((INSTANCE_COUNT++))
        : $((FILE_NUM++))

        echo "Instance $FILE_NUM: $INSTANCE_ID"
        echo "  IP: $IP"
        echo "  File: $SIM_FILE"
        echo "  Region: $REGION"
        echo "  Type: $INSTANCE_TYPE"
        echo "  SSH: ssh -i $KEY_PATH ubuntu@$IP"
        echo "  Attach: ssh -i $KEY_PATH ubuntu@$IP 'tmux attach -t fds_run'"
        echo ""
    done < <(get_instances)

    if [ "$INSTANCE_COUNT" -eq 0 ]; then
        echo "No instances were successfully launched."
    else
        echo "Instance info saved to database: ${DB_FILE}"
        echo ""
        echo "Check status with:"
        echo "  ./check_status.sh --key-path $KEY_PATH"
        echo ""
        echo "Launch and tail logs simultaneously:"
        echo "  ./launch_aws.sh --key-path $KEY_PATH <files...> & tail -f $LOG_FILE"
    fi

    echo "========================================"
}

# --- ARGUMENT PARSING ---

function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help | -h)
                print_usage
                exit 0
                ;;
            --key-path)
                KEY_PATH="$2"
                shift 2
                ;;
            --region)
                USER_REGION="$2"
                shift 2
                ;;
            --instance-type)
                INSTANCE_TYPE="$2"
                shift 2
                ;;
            --replace-instance-id)
                REPLACE_INSTANCE_ID="$2"
                shift 2
                ;;
            *)
                FDS_FILES+=("$1")
                shift
                ;;
        esac
    done
}

function validate_arguments() {
    if [ -z "$KEY_PATH" ]; then
        log_error "--key-path is required"
        echo ""
        print_usage
        return 1
    fi

    if [ ! -f "$KEY_PATH" ]; then
        log_error "Key file not found: $KEY_PATH"
        return 1
    fi

    # Derive key name from key path (basename without extension)
    KEY_NAME=$(basename "$KEY_PATH")

    if [ ${#FDS_FILES[@]} -eq 0 ]; then
        log_error "At least one FDS file is required"
        echo ""
        print_usage
        return 1
    fi

    if [ ! -f "${SCRIPT_DIR}/${CLOUD_INIT_FILE}" ]; then
        log_error "Cloud-init file not found: ${SCRIPT_DIR}/${CLOUD_INIT_FILE}"
        return 1
    fi

    for FDS_FILE in "${FDS_FILES[@]}"; do
        if [ ! -f "$FDS_FILE" ]; then
            log_error "FDS file not found: $FDS_FILE"
            return 1
        fi
    done
}

function print_usage() {
    echo "Usage: $0 --key-path PATH [OPTIONS] <fds_file1> [fds_file2] ..."
    echo ""
    echo "Required arguments:"
    echo "  --key-path PATH        Path to SSH private key (key name derived from basename)"
    echo ""
    echo "Optional arguments:"
    echo "  --region REGION        AWS region (auto-detected if not specified)"
    echo "  --instance-type TYPE   EC2 instance type (default: c7i.12xlarge)"
    echo ""
    echo "Example:"
    echo "  $0 --key-path ~/.ssh/fds-key-pair tier1_1.fds tier1_2.fds"
}

# --- INSTANCE SETUP WORKFLOW ---

# Run all setup steps after instance is launched
# Returns 0 on success, 1 on failure (caller handles cleanup)
function run_instance_setup() {
    local SIM_FILE=$1
    local PUBLIC_IP=$2

    wait_for_ssh "$PUBLIC_IP" || return 1
    wait_for_cloud_init "$PUBLIC_IP" || return 1
    upload_file "$SIM_FILE" "$PUBLIC_IP" || return 1
    start_simulation "$SIM_FILE" "$PUBLIC_IP" || return 1
}

function setup_instance() {
    local SIM_FILE=$1
    local REGION=$2
    local AMI_ID=$3
    local SG_ID=$4
    # shellcheck disable=SC2178
    local SUBNET_IDS=$5
    local INSTANCE_ID="" PUBLIC_IP=""

    # Launch instance
    local RESULT
    # shellcheck disable=SC2128
    if ! RESULT=$(launch_instance "$SIM_FILE" "$REGION" "$AMI_ID" "$SG_ID" "$SUBNET_IDS"); then
        return 1
    fi

    read -r INSTANCE_ID PUBLIC_IP <<< "$(echo "$RESULT" | tail -1)"

    # Run setup - single cleanup point on failure
    if run_instance_setup "$SIM_FILE" "$PUBLIC_IP"; then
        complete_instance "$INSTANCE_ID"
        log "Successfully set up $SIM_FILE on $INSTANCE_ID ($PUBLIC_IP)"
    else
        cleanup_instance "$INSTANCE_ID" "$REGION"
        return 1
    fi
}

function process_files() {
    local FILE_INDEX=0
    local SUCCESS_COUNT=0
    local FAIL_COUNT=0

    # Get instance vCPU count once
    local REQUIRED_VCPUS
    if ! REQUIRED_VCPUS=$(get_instance_vcpus "$INSTANCE_TYPE"); then
        log_error "Failed to get vCPU count for $INSTANCE_TYPE"
        return 1
    fi
    log "Instance type $INSTANCE_TYPE requires $REQUIRED_VCPUS vCPUs"

    for SIM_FILE in "${FDS_FILES[@]}"; do
        : $((FILE_INDEX++))
        log "Processing file $FILE_INDEX/${#FDS_FILES[@]}: $SIM_FILE"

        # Select region with quota available
        local REGION
        local AMI_ID
        if [ -z "$USER_REGION" ]; then
            if ! REGION=$(select_region_with_quota "$INSTANCE_TYPE" "$REQUIRED_VCPUS"); then
                log_error "Failed to select region with quota"
                : $((FAIL_COUNT++))
                continue
            fi
        else
            REGION="$USER_REGION"
            log "Using specified region: $REGION"

            # Still check quota even when user specifies region
            if ! check_quota_available "$REGION" "$INSTANCE_TYPE" "$REQUIRED_VCPUS"; then
                log_error "Insufficient quota in specified region $REGION"
                : $((FAIL_COUNT++))
                continue
            fi
        fi

        # Auto-detect AMI for this region
        if ! AMI_ID=$(find_ami "$REGION"); then
            log_error "Failed to find AMI in $REGION"
            : $((FAIL_COUNT++))
            continue
        fi
        log "Using AMI: $AMI_ID"

        # Setup region-specific infrastructure
        log "Setting up infrastructure in $REGION"
        if ! setup_key_pair "$REGION"; then
            log_error "Key pair setup failed in $REGION"
            : $((FAIL_COUNT++))
            continue
        fi

        # Setup VPC
        local VPC_ID
        log "Checking/Creating VPC in $REGION"
        VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:Name,Values=fds-vpc" --query "Vpcs[*].VpcId" --output text) || {
            log_error "Failed to query VPCs"
            : $((FAIL_COUNT++))
            continue
        }

        if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
            log "Creating VPC in $REGION"
            VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region "$REGION" --query 'Vpc.VpcId' --output text) || {
                log_error "Failed to create VPC"
                : $((FAIL_COUNT++))
                continue
            }
            aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=fds-vpc --region "$REGION" > /dev/null || true
            log "Created VPC: $VPC_ID"
        else
            log "Using existing VPC: $VPC_ID"
        fi

        # Setup internet gateway
        local IGW_ID
        log "Checking/Creating Internet Gateway in $REGION"
        if ! IGW_ID=$(setup_internet_gateway "$REGION" "$VPC_ID"); then
            log_error "Internet gateway setup failed in $REGION"
            : $((FAIL_COUNT++))
            continue
        fi
        log "Using Internet Gateway: $IGW_ID"

        # Setup route table
        local RT_ID
        log "Checking/Creating Route Table in $REGION"
        if ! RT_ID=$(setup_route_table "$REGION" "$VPC_ID" "$IGW_ID"); then
            log_error "Route table setup failed in $REGION"
            : $((FAIL_COUNT++))
            continue
        fi
        log "Using Route Table: $RT_ID"

        # Setup subnets
        local SUBNET_IDS
        log "Checking/Creating Subnets in $REGION"
        if ! SUBNET_IDS=$(setup_subnets "$REGION" "$VPC_ID" "$RT_ID"); then
            log_error "Subnet setup failed in $REGION"
            : $((FAIL_COUNT++))
            continue
        fi
        log "Using Subnets: $SUBNET_IDS"

        # Setup security group
        local SG_ID
        log "Checking/Creating Security Group in $REGION"
        if ! SG_ID=$(setup_security_group "$REGION" "$VPC_ID"); then
            log_error "Security group setup failed in $REGION"
            : $((FAIL_COUNT++))
            continue
        fi
        log "Using Security Group: $SG_ID"

        # Launch and setup instance
        if setup_instance "$SIM_FILE" "$REGION" "$AMI_ID" "$SG_ID" "$SUBNET_IDS"; then
            : $((SUCCESS_COUNT++))
        else
            : $((FAIL_COUNT++))
        fi
    done
}

# --- MAIN ---

function main() {
    parse_arguments "$@"

    if ! validate_arguments; then
        exit 1
    fi

    # Initialize instances database
    init_instances_db

    log "=== FDS Multi-Instance Launcher Started ==="
    log "Instance Type: $INSTANCE_TYPE"
    log "Key Name: $KEY_NAME"
    log "Launching ${#FDS_FILES[@]} instances for files: ${FDS_FILES[*]}"

    # Setup global infrastructure (S3 and IAM - not region-specific)
    log "Setting up global infrastructure"
    if ! setup_s3_bucket; then
        log_error "S3 bucket setup failed"
        exit 1
    fi

    if ! setup_iam_role; then
        log_error "IAM role setup failed"
        exit 1
    fi

    process_files
    print_summary
    log "=== FDS Multi-Instance Launcher Completed ==="
}

main "$@"
