#!/bin/bash
set -e
set -o pipefail

# --- CONFIGURATION ---
KEY_PATH=""
REGION="eu-north-1" # Stockholm
INSTANCE_TYPE="c7i.12xlarge"
AMI_ID="ami-0ac901f79b0bf67c0" # Ubuntu 24.04 LTS
CLOUD_INIT_FILE="fds-cloud-init.yaml"

# Global variables
VPC_ID=""
SG_ID=""
SCRIPT_DIR=""
declare -a SUBNET_IDS=()
declare -a FDS_FILES=()
declare -a INSTANCES=()
declare -a IPS=()
declare -a INSTANCE_FILES=()
declare -a PENDING_INSTANCES=()

# --- CLEANUP ---

# Safety net for Ctrl+C during instance setup.
# If user interrupts while an instance is launching but before setup completes,
# the instance would be left running. This trap ensures we clean up.
# Normal error handling is done by cleanup_instance() in setup_instance().
handle_interrupt() {
    echo ""
    echo "Interrupted!"

    if [ ${#PENDING_INSTANCES[@]} -gt 0 ]; then
        echo "Cleaning up ${#PENDING_INSTANCES[@]} pending instance(s)..."
        for INSTANCE_ID in "${PENDING_INSTANCES[@]}"; do
            echo "   Terminating $INSTANCE_ID..."
            aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" 2> /dev/null || true
        done
    fi

    exit 130 # Standard exit code for Ctrl+C (128 + SIGINT=2)
}

trap handle_interrupt INT

# Cleanup a specific instance and remove from pending
cleanup_instance() {
    local INSTANCE_ID=$1

    if [ -z "$INSTANCE_ID" ]; then
        return
    fi

    echo "   Cleaning up instance $INSTANCE_ID..."
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null 2>&1 || true

    # Remove from pending array
    local NEW_PENDING=()
    for ID in "${PENDING_INSTANCES[@]}"; do
        if [ "$ID" != "$INSTANCE_ID" ]; then
            NEW_PENDING+=("$ID")
        fi
    done
    PENDING_INSTANCES=("${NEW_PENDING[@]}")
}

# Mark instance as successfully completed
complete_instance() {
    local INSTANCE_ID=$1
    local PUBLIC_IP=$2
    local SIM_FILE=$3

    # Remove from pending
    local NEW_PENDING=()
    for ID in "${PENDING_INSTANCES[@]}"; do
        if [ "$ID" != "$INSTANCE_ID" ]; then
            NEW_PENDING+=("$ID")
        fi
    done
    PENDING_INSTANCES=("${NEW_PENDING[@]}")

    # Add to completed
    INSTANCES+=("$INSTANCE_ID")
    IPS+=("$PUBLIC_IP")
    INSTANCE_FILES+=("$SIM_FILE")
}

# --- NETWORK FUNCTIONS ---

setup_vpc() {
    echo "   Checking/Creating VPC..."
    VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:Name,Values=fds-vpc" --query "Vpcs[*].VpcId" --output text) || {
        echo "ERROR: Failed to query VPCs" >&2
        return 1
    }

    if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
        echo "   Creating VPC..."
        VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region "$REGION" --query 'Vpc.VpcId' --output text) || {
            echo "ERROR: Failed to create VPC" >&2
            return 1
        }
        aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=fds-vpc --region "$REGION" > /dev/null || true

        setup_internet_gateway || return 1
        setup_route_table || return 1
    else
        echo "   Using existing VPC: $VPC_ID"
    fi
}

setup_internet_gateway() {
    echo "   Creating Internet Gateway..."
    local IGW_ID
    IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" --query 'InternetGateway.InternetGatewayId' --output text) || {
        echo "ERROR: Failed to create Internet Gateway" >&2
        return 1
    }
    aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value=fds-igw --region "$REGION" > /dev/null || true
    aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$REGION" > /dev/null || {
        echo "ERROR: Failed to attach Internet Gateway" >&2
        return 1
    }
}

setup_route_table() {
    echo "   Creating Route Table..."
    local RT_ID IGW_ID

    RT_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" --query 'RouteTable.RouteTableId' --output text) || {
        echo "ERROR: Failed to create Route Table" >&2
        return 1
    }
    aws ec2 create-tags --resources "$RT_ID" --tags Key=Name,Value=fds-rt --region "$REGION" > /dev/null || true

    IGW_ID=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=tag:Name,Values=fds-igw" --query "InternetGateways[*].InternetGatewayId" --output text) || {
        echo "ERROR: Failed to find Internet Gateway" >&2
        return 1
    }

    aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$REGION" > /dev/null || {
        echo "ERROR: Failed to create route" >&2
        return 1
    }
}

create_subnet() {
    local AZ=$1
    local CIDR_OCTET=$2
    local NEW_SUBNET RT_ID

    NEW_SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "10.0.${CIDR_OCTET}.0/24" --availability-zone "$AZ" --region "$REGION" --query 'Subnet.SubnetId' --output text) || {
        echo "ERROR: Failed to create subnet in $AZ" >&2
        return 1
    }

    aws ec2 modify-subnet-attribute --subnet-id "$NEW_SUBNET" --map-public-ip-on-launch --region "$REGION" > /dev/null || {
        echo "ERROR: Failed to modify subnet attributes" >&2
        return 1
    }

    RT_ID=$(aws ec2 describe-route-tables --region "$REGION" --filters "Name=tag:Name,Values=fds-rt" --query "RouteTables[*].RouteTableId" --output text)
    if [ -n "$RT_ID" ] && [ "$RT_ID" != "None" ]; then
        aws ec2 associate-route-table --subnet-id "$NEW_SUBNET" --route-table-id "$RT_ID" --region "$REGION" > /dev/null || true
    fi

    echo "$NEW_SUBNET"
}

setup_subnets() {
    echo "   Ensuring Subnets in $REGION..."
    SUBNET_IDS=()

    # Get actual availability zones for this region
    local AZS_RAW
    AZS_RAW=$(aws ec2 describe-availability-zones --region "$REGION" --filters "Name=state,Values=available" --query "AvailabilityZones[*].ZoneName" --output text) || {
        echo "ERROR: Failed to query availability zones" >&2
        return 1
    }

    # Convert to array
    local -a AZS
    read -ra AZS <<< "$AZS_RAW"
    local CIDR_OCTET=1

    for AZ in "${AZS[@]}"; do
        local EXISTING_SUBNET
        EXISTING_SUBNET=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=availability-zone,Values=$AZ" --query "Subnets[*].SubnetId" --output text) || {
            echo "ERROR: Failed to query subnets" >&2
            return 1
        }

        if [ -z "$EXISTING_SUBNET" ] || [ "$EXISTING_SUBNET" == "None" ]; then
            echo "   Creating Subnet in $AZ..."
            local NEW_SUBNET
            NEW_SUBNET=$(create_subnet "$AZ" "$CIDR_OCTET") || return 1
            SUBNET_IDS+=("$NEW_SUBNET")
        else
            SUBNET_IDS+=("$EXISTING_SUBNET")
        fi
        : $((CIDR_OCTET++))
    done
}

setup_security_group() {
    echo "   Checking/Creating Security Group..."
    SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=fds-sg" --query "SecurityGroups[*].GroupId" --output text) || {
        echo "ERROR: Failed to query security groups" >&2
        return 1
    }

    if [ -z "$SG_ID" ] || [ "$SG_ID" == "None" ]; then
        echo "   Creating Security Group..."
        SG_ID=$(aws ec2 create-security-group --group-name fds-sg --description "FDS SSH Access" --vpc-id "$VPC_ID" --region "$REGION" --query 'GroupId' --output text) || {
            echo "ERROR: Failed to create security group" >&2
            return 1
        }

        # Get current public IP
        local MY_IP
        MY_IP=$(curl -s --retry 3 --retry-delay 1 --max-time 5 https://checkip.amazonaws.com)
        if [ -z "$MY_IP" ]; then
            echo "ERROR: Failed to detect current IP address after retries" >&2
            return 1
        fi

        echo "   Allowing SSH from your IP: $MY_IP/32"
        aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP/32" --region "$REGION" > /dev/null || {
            echo "ERROR: Failed to authorize security group ingress" >&2
            return 1
        }
    else
        echo "   Using existing Security Group: $SG_ID"
    fi
}

setup_key_pair() {
    echo "   Checking/Importing Key Pair..."

    # Check if key pair exists in this region
    local KEY_EXISTS
    KEY_EXISTS=$(aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" --query "KeyPairs[*].KeyName" --output text 2>/dev/null || echo "")

    if [ -z "$KEY_EXISTS" ]; then
        echo "   Importing key pair to $REGION..."
        aws ec2 import-key-pair --region "$REGION" --key-name "$KEY_NAME" --public-key-material "fileb://<(ssh-keygen -y -f \"$KEY_PATH\")" > /dev/null || {
            echo "ERROR: Failed to import key pair" >&2
            return 1
        }
        echo "   Key pair imported successfully"
    else
        echo "   Key pair already exists in $REGION"
    fi
}

setup_network() {
    echo "1. Checking/Creating Network Resources..."
    setup_key_pair || return 1
    setup_vpc || return 1
    setup_subnets || return 1
    setup_security_group || return 1
}

# --- INSTANCE FUNCTIONS ---

try_launch_in_subnet() {
    local SIM_FILE=$1
    local SUBNET=$2

    aws ec2 run-instances \
        --region "$REGION" \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --subnet-id "$SUBNET" \
        --security-group-ids "$SG_ID" \
        --user-data "file://${SCRIPT_DIR}/${CLOUD_INIT_FILE}" \
        --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=fds-${SIM_FILE%.fds}}]" \
        --query 'Instances[*].InstanceId' \
        --output text
}

launch_instance() {
    local SIM_FILE=$1
    local INSTANCE_ID=""

    echo "3. Launching new instance..."

    for SUBNET in "${SUBNET_IDS[@]}"; do
        echo "   Trying subnet: $SUBNET"
        if INSTANCE_ID=$(try_launch_in_subnet "$SIM_FILE" "$SUBNET"); then
            echo "   SUCCESS: Launched $INSTANCE_ID"
            PENDING_INSTANCES+=("$INSTANCE_ID")
            break
        fi
    done

    if [ -z "$INSTANCE_ID" ]; then
        echo "ERROR: Could not launch instance for $SIM_FILE in any subnet" >&2
        return 1
    fi

    echo "   Waiting for instance to be running..."
    if ! aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"; then
        echo "ERROR: Instance $INSTANCE_ID failed to start" >&2
        return 1
    fi

    local PUBLIC_IP
    PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text) || {
        echo "ERROR: Failed to get public IP for $INSTANCE_ID" >&2
        return 1
    }

    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" == "None" ]; then
        echo "ERROR: Instance $INSTANCE_ID has no public IP" >&2
        return 1
    fi

    echo "   Server IP: $PUBLIC_IP"
    echo "$INSTANCE_ID $PUBLIC_IP"
}

# --- SSH FUNCTIONS ---

wait_for_ssh() {
    local PUBLIC_IP=$1
    local TIMEOUT=${2:-300}
    local ELAPSED=0

    echo "4. Waiting for SSH (timeout: ${TIMEOUT}s)..."
    while ! nc -z -w 5 "$PUBLIC_IP" 22 2> /dev/null; do
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
            echo ""
            echo "ERROR: SSH timeout after ${TIMEOUT}s" >&2
            return 1
        fi
        echo -n "."
        sleep 5
        : $((ELAPSED += 5))
    done
    echo " SSH Ready!"
    sleep 3
}

ssh_exec() {
    local PUBLIC_IP=$1
    local COMMAND=$2
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$KEY_PATH" "ubuntu@$PUBLIC_IP" "$COMMAND"
}

wait_for_cloud_init() {
    local PUBLIC_IP=$1
    local TIMEOUT=${2:-900}

    echo "5. Waiting for cloud-init to complete (timeout: ${TIMEOUT}s)..."

    # Use cloud-init status --wait with timeout
    ssh_exec "$PUBLIC_IP" "timeout $TIMEOUT cloud-init status --wait" 2> /dev/null
    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo "   Cloud-init completed successfully"
        return 0
    else
        echo ""

        # Check if it was a timeout (exit code 124) or actual failure
        if [ $EXIT_CODE -eq 124 ]; then
            echo "ERROR: Cloud-init timeout after ${TIMEOUT}s" >&2
        else
            echo "ERROR: Cloud-init failed" >&2
        fi

        echo "--- FDS Setup Log ---"
        ssh_exec "$PUBLIC_IP" "tail -50 /var/log/fds-setup.log 2>/dev/null" || true
        echo "--- Cloud-init Output ---"
        ssh_exec "$PUBLIC_IP" "tail -50 /var/log/cloud-init-output.log 2>/dev/null" || true
        return 1
    fi
}

# --- SIMULATION FUNCTIONS ---

upload_file() {
    local SIM_FILE=$1
    local PUBLIC_IP=$2

    echo "6. Uploading Simulation File..."
    if ! scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$KEY_PATH" "$SIM_FILE" "ubuntu@$PUBLIC_IP:/home/ubuntu/"; then
        echo "ERROR: Failed to upload $SIM_FILE" >&2
        return 1
    fi
}

start_simulation() {
    local SIM_FILE=$1
    local PUBLIC_IP=$2
    local REMOTE_FILE
    REMOTE_FILE=$(basename "$SIM_FILE")

    # Count number of meshes in FDS file (one MPI process per mesh)
    local NUM_MESHES
    NUM_MESHES=$(grep -c "^&MESH" "$SIM_FILE" || echo "1")

    echo "7. Starting Simulation in tmux (${NUM_MESHES} MPI processes)..."
    if ! ssh_exec "$PUBLIC_IP" "tmux new-session -d -s fds_run 'tmux set-option -t fds_run remain-on-exit on && source \$HOME/FDS/FDS6/bin/FDS6VARS.sh && mpiexec -n ${NUM_MESHES} fds $REMOTE_FILE'"; then
        echo "ERROR: Failed to start simulation" >&2
        return 1
    fi
    echo "   Simulation started in tmux session 'fds_run'"
}

# --- OUTPUT FUNCTIONS ---

print_summary() {
    echo ""
    echo "========================================"
    echo "LAUNCH SUMMARY"
    echo "========================================"

    if [ ${#INSTANCES[@]} -eq 0 ]; then
        echo "No instances were successfully launched."
    else
        # Append instance info to file
        local OUTPUT_FILE="${SCRIPT_DIR}/instances.txt"

        for i in "${!INSTANCES[@]}"; do
            local FILE_NUM=$((i + 1))
            echo "Instance $FILE_NUM: ${INSTANCES[$i]}"
            echo "  IP: ${IPS[$i]}"
            echo "  File: ${INSTANCE_FILES[$i]}"
            echo "  SSH: ssh -i $KEY_PATH ubuntu@${IPS[$i]}"
            echo "  Attach: ssh -i $KEY_PATH ubuntu@${IPS[$i]} 'tmux attach -t fds_run'"
            echo ""

            # Append to instances file: IP|INSTANCE_ID|FILE|REGION
            echo "${IPS[$i]}|${INSTANCES[$i]}|${INSTANCE_FILES[$i]}|${REGION}" >> "$OUTPUT_FILE"
        done

        echo "Instance info appended to: $OUTPUT_FILE"
    fi

    echo "========================================"
}

# --- ARGUMENT PARSING ---

parse_arguments() {
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
                REGION="$2"
                shift 2
                ;;
            --instance-type)
                INSTANCE_TYPE="$2"
                shift 2
                ;;
            --ami-id)
                AMI_ID="$2"
                shift 2
                ;;
            *)
                FDS_FILES+=("$1")
                shift
                ;;
        esac
    done
}

validate_arguments() {
    if [ -z "$KEY_PATH" ]; then
        echo "ERROR: --key-path is required" >&2
        echo ""
        print_usage
        return 1
    fi

    if [ ! -f "$KEY_PATH" ]; then
        echo "ERROR: Key file not found: $KEY_PATH" >&2
        return 1
    fi

    # Derive key name from key path (basename without extension)
    KEY_NAME=$(basename "$KEY_PATH")

    if [ ${#FDS_FILES[@]} -eq 0 ]; then
        echo "ERROR: At least one FDS file is required" >&2
        echo ""
        print_usage
        return 1
    fi

    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    if [ ! -f "${SCRIPT_DIR}/${CLOUD_INIT_FILE}" ]; then
        echo "ERROR: Cloud-init file not found: ${SCRIPT_DIR}/${CLOUD_INIT_FILE}" >&2
        return 1
    fi

    for FDS_FILE in "${FDS_FILES[@]}"; do
        if [ ! -f "$FDS_FILE" ]; then
            echo "ERROR: FDS file not found: $FDS_FILE" >&2
            return 1
        fi
    done
}

print_usage() {
    echo "Usage: $0 --key-path PATH [--region REGION] [--instance-type TYPE] [--ami-id AMI] <fds_file1> [fds_file2] ..."
    echo ""
    echo "Required arguments:"
    echo "  --key-path PATH        Path to SSH private key (key name derived from basename)"
    echo ""
    echo "Optional arguments:"
    echo "  --region REGION        AWS region (default: eu-north-1)"
    echo "  --instance-type TYPE   EC2 instance type (default: c7i.12xlarge)"
    echo "  --ami-id AMI           Ubuntu AMI ID (default: ami-0ac901f79b0bf67c0)"
    echo ""
    echo "Example:"
    echo "  $0 --key-path ~/.ssh/fds-key-pair tier1_1.fds tier1_2.fds"
}

print_config() {
    echo "--- FDS Multi-Instance Launcher ---"
    echo "Region: $REGION"
    echo "Instance Type: $INSTANCE_TYPE"
    echo "AMI ID: $AMI_ID"
    echo "Key Name: $KEY_NAME"
    echo "Key Path: $KEY_PATH"
    echo "Launching ${#FDS_FILES[@]} instances for files: ${FDS_FILES[*]}"
    echo ""
}

# --- INSTANCE SETUP WORKFLOW ---

# Run all setup steps after instance is launched
# Returns 0 on success, 1 on failure (caller handles cleanup)
run_instance_setup() {
    local SIM_FILE=$1
    local PUBLIC_IP=$2

    wait_for_ssh "$PUBLIC_IP" || return 1
    wait_for_cloud_init "$PUBLIC_IP" || return 1
    upload_file "$SIM_FILE" "$PUBLIC_IP" || return 1
    start_simulation "$SIM_FILE" "$PUBLIC_IP" || return 1
}

setup_instance() {
    local SIM_FILE=$1
    local INSTANCE_ID="" PUBLIC_IP=""

    # Launch instance (adds to PENDING_INSTANCES on success)
    local RESULT
    if ! RESULT=$(launch_instance "$SIM_FILE"); then
        return 1
    fi

    read -r INSTANCE_ID PUBLIC_IP <<< "$(echo "$RESULT" | tail -1)"

    # Run setup - single cleanup point on failure
    if run_instance_setup "$SIM_FILE" "$PUBLIC_IP"; then
        complete_instance "$INSTANCE_ID" "$PUBLIC_IP" "$SIM_FILE"
        echo "SUCCESS: $SIM_FILE running on $INSTANCE_ID ($PUBLIC_IP)"
    else
        cleanup_instance "$INSTANCE_ID"
        return 1
    fi
}

process_files() {
    local FILE_INDEX=0
    local SUCCESS_COUNT=0
    local FAIL_COUNT=0

    for SIM_FILE in "${FDS_FILES[@]}"; do
        : $((FILE_INDEX++))
        echo ""
        echo "========================================"
        echo "FILE $FILE_INDEX/${#FDS_FILES[@]}: $SIM_FILE"
        echo "========================================"

        if setup_instance "$SIM_FILE"; then
            : $((SUCCESS_COUNT++))
        else
            : $((FAIL_COUNT++))
            echo "FAILED: $SIM_FILE"
        fi
    done

    echo ""
    echo "Completed: $SUCCESS_COUNT succeeded, $FAIL_COUNT failed"
}

# --- MAIN ---

main() {
    parse_arguments "$@"

    if ! validate_arguments; then
        exit 1
    fi

    print_config

    if ! setup_network; then
        echo "ERROR: Network setup failed" >&2
        exit 1
    fi

    process_files
    print_summary
}

main "$@"
