#!/bin/bash
set -o pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# --- CONFIGURATION ---
KEY_PATH=""
WATCH_MODE=false
CHECK_INTERVAL=60
AUTO_RESTART=false
LAUNCH_SCRIPT="${SCRIPT_DIR}/launch_aws.sh"
S3_BUCKET="fds-output-wang-fuk-fire"

# --- FUNCTIONS ---

function print_usage() {
    echo "Usage: $0 --key-path PATH [OPTIONS]"
    echo ""
    echo "Required arguments:"
    echo "  --key-path PATH           Path to SSH private key"
    echo ""
    echo "Optional arguments:"
    echo "  --watch                   Continuous monitoring mode"
    echo "  --interval SECONDS        Check interval for watch mode (default: 20)"
    echo "  --auto-restart            Automatically restart terminated spot instances"
    echo ""
    echo "Examples:"
    echo "  $0 --key-path ~/.ssh/fds-key-pair                        # Monitor all active instances"
    echo "  $0 --key-path ~/.ssh/fds-key-pair --watch --auto-restart # Watch with auto-restart"
}

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
            --watch)
                WATCH_MODE=true
                shift
                ;;
            --interval)
                if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
                    echo "ERROR: --interval must be a positive integer" >&2
                    exit 1
                fi
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --auto-restart)
                AUTO_RESTART=true
                shift
                ;;
            *)
                echo "ERROR: Unknown argument: $1" >&2
                print_usage
                exit 1
                ;;
        esac
    done
}

function validate_arguments() {
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

    # Check if database exists
    if ! check_instances_db; then
        echo "ERROR: Instances database not found: $DB_FILE" >&2
        echo "       Run launch_aws.sh first to create instances" >&2
        return 1
    fi

    # Auto-restart requires watch mode
    if [ "$AUTO_RESTART" = true ] && [ "$WATCH_MODE" = false ]; then
        echo "Auto-restart enabled, enabling watch mode..."
        WATCH_MODE=true
    fi
}

function ssh_exec() {
    local IP=$1
    local COMMAND=$2
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$KEY_PATH" "ubuntu@$IP" "$COMMAND" < /dev/null
}

function get_fds_end_time() {
    local FDS_FILE=$1

    # Extract T_END from &TIME namelist in FDS file
    # Format: &TIME T_END=3600.0 /
    if [ ! -f "$FDS_FILE" ]; then
        echo "3600.0" # Default fallback
        return
    fi

    local T_END
    T_END=$(grep -i "&TIME" "$FDS_FILE" | sed -n 's/.*T_END[[:space:]]*=[[:space:]]*\([0-9.]*\).*/\1/p' | head -1)

    if [ -z "$T_END" ]; then
        echo "3600.0" # Default fallback
    else
        echo "$T_END"
    fi
}

function calculate_progress() {
    local CURRENT_SIM_TIME=$1
    local TARGET_TIME=$2
    local START_TIME=$3
    local CURRENT_TIME=$4

    local ELAPSED_WALL_TIME=$((CURRENT_TIME - START_TIME))

    # Calculate progress percentage
    local PROGRESS
    PROGRESS=$(printf "%.2f" "$(echo "scale=4; ($CURRENT_SIM_TIME * 100) / $TARGET_TIME" | bc -l)")

    # Calculate elapsed wall minutes
    local ELAPSED_WALL_MINS
    ELAPSED_WALL_MINS=$(echo "scale=2; $ELAPSED_WALL_TIME / 60" | bc -l)

    # Calculate rate (sim seconds per wall minute)
    local RATE
    RATE=$(printf "%.2f" "$(echo "scale=4; $CURRENT_SIM_TIME / $ELAPSED_WALL_MINS" | bc -l)")

    # Estimate remaining time
    local REMAINING_SIM_TIME
    REMAINING_SIM_TIME=$(echo "$TARGET_TIME - $CURRENT_SIM_TIME" | bc -l)
    local ESTIMATED_WALL_MINS
    ESTIMATED_WALL_MINS=$(echo "scale=0; $REMAINING_SIM_TIME / $RATE" | bc -l)

    # Format elapsed time
    local ELAPSED_HOURS=$((ELAPSED_WALL_TIME / 3600))
    local ELAPSED_MINS=$(((ELAPSED_WALL_TIME % 3600) / 60))

    # Format estimated finish time
    local ESTIMATED_WALL_SECONDS
    ESTIMATED_WALL_SECONDS=$(echo "$ESTIMATED_WALL_MINS * 60" | bc)
    local FINISH_TIMESTAMP=$((CURRENT_TIME + ESTIMATED_WALL_SECONDS))
    local FINISH_TIME
    FINISH_TIME=$(date -d "@$FINISH_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2> /dev/null || date -r "$FINISH_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2> /dev/null || echo "unknown")
    local ETA_HOURS
    ETA_HOURS=$(echo "scale=0; $ESTIMATED_WALL_MINS / 60" | bc)
    local ETA_MINS
    ETA_MINS=$(echo "scale=0; $ESTIMATED_WALL_MINS % 60" | bc)

    echo "Progress: ${PROGRESS}% (${CURRENT_SIM_TIME}s / ${TARGET_TIME}s)"
    echo "Elapsed: ${ELAPSED_HOURS}h ${ELAPSED_MINS}m"
    echo "Rate: ${RATE} sim-sec/wall-min"
    echo "ETA: ${ETA_HOURS}h ${ETA_MINS}m (finish: $FINISH_TIME)"
}

function check_aws_instance() {
    local REGION=$1
    local INSTANCE_ID=$2

    local INSTANCE_STATE STATE_REASON
    read -r INSTANCE_STATE STATE_REASON <<< "$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].[State.Name,StateReason.Code]' --output text 2> /dev/null < /dev/null)"

    # Check for spot interruption first
    if [ "$STATE_REASON" = "Server.SpotInstanceTermination" ]; then
        echo "Status: 🚨 SPOT INTERRUPTED"
        return 10
    fi

    # Check if instance is running
    if [ "$INSTANCE_STATE" != "running" ]; then
        echo "Status: ⏹️  INSTANCE NOT RUNNING (state: ${INSTANCE_STATE:-unknown})"
        return 10
    fi

    return 0
}

function check_simulation_completion() {
    local IP=$1
    local TMUX_OUTPUT=$2

    # Check if pane is dead (process exited)
    local PANE_DEAD
    PANE_DEAD=$(ssh_exec "$IP" "tmux display-message -p -t fds_run '#{pane_dead}'" 2> /dev/null || echo "")

    if [ "$PANE_DEAD" != "1" ]; then
        return 0 # Still running
    fi

    # Pane is dead, get exit status
    local EXIT_STATUS
    EXIT_STATUS=$(ssh_exec "$IP" "tmux display-message -p -t fds_run '#{pane_dead_status}'" 2> /dev/null || echo "")

    if [ "$EXIT_STATUS" = "0" ]; then
        echo "Status: ✅ COMPLETED"
        echo ""
        echo "Last output:"
        echo "$TMUX_OUTPUT" | tail -5
        echo ""
        return 2
    else
        echo "Status: ❌ ERROR (exit code: ${EXIT_STATUS:-unknown})"
        echo ""
        echo "Last output:"
        echo "$TMUX_OUTPUT"
        echo ""
        return 3
    fi
}

function check_instance_status() {
    local IP=$1
    local INSTANCE_ID=$2
    local SIM_FILE=$3
    local REGION=$4
    local INSTANCE_TYPE=$5

    echo "========================================"
    echo "Instance: $INSTANCE_ID"
    echo "IP: $IP"
    echo "File: $SIM_FILE"
    echo "Region: $REGION"
    echo "Type: $INSTANCE_TYPE"
    echo "========================================"

    # Check AWS instance state
    if ! check_aws_instance "$REGION" "$INSTANCE_ID"; then
        echo ""
        return 10
    fi

    # Check if SSH is accessible
    if ! ssh_exec "$IP" "exit" 2> /dev/null; then
        echo "Status: ⚠️  INSTANCE RUNNING BUT SSH NOT ACCESSIBLE"
        echo ""
        return 10
    fi

    # Check if tmux session exists
    if ! ssh_exec "$IP" "tmux has-session -t fds_run 2>/dev/null"; then
        echo "Status: ❌ TMUX SESSION NOT FOUND"
        echo ""
        return 10
    fi

    # Get last 20 lines of tmux output
    local TMUX_OUTPUT
    TMUX_OUTPUT=$(ssh_exec "$IP" "tmux capture-pane -p -t fds_run | tail -20")

    # Check if simulation has completed or errored
    check_simulation_completion "$IP" "$TMUX_OUTPUT"
    local COMPLETION_STATUS=$?
    if [ "$COMPLETION_STATUS" -ne 0 ]; then
        return "$COMPLETION_STATUS"
    fi

    # Extract current time step if running
    local TIME_STEP
    TIME_STEP=$(echo "$TMUX_OUTPUT" | grep "Time Step:" | tail -1)
    if [ -n "$TIME_STEP" ]; then
        echo "Status: 🔄 RUNNING"
        echo "$TIME_STEP"

        # Extract simulation time and calculate progress
        local CURRENT_SIM_TIME
        CURRENT_SIM_TIME=$(echo "$TIME_STEP" | sed -n 's/.*Simulation Time:[[:space:]]*\([0-9.]*\).*/\1/p')
        CURRENT_SIM_TIME=${CURRENT_SIM_TIME:-0}
        local TARGET_TIME
        TARGET_TIME=$(get_fds_end_time "$SIM_FILE")

        # Get process start time from FDS output file birth time (Linux)
        local START_TIME
        local SIM_BASE="${SIM_FILE%.fds}"
        local CHID
        CHID=$(basename "$SIM_BASE")
        START_TIME=$(ssh_exec "$IP" "stat -c %W /home/ubuntu/fds-work/${CHID}/${CHID}.out 2>/dev/null || echo 0")
        local CURRENT_TIME
        CURRENT_TIME=$(date +%s)

        # Only calculate progress if we have valid start time (>0 and not epoch)
        # and simulation has started (CURRENT_SIM_TIME > 0)
        if [ "$START_TIME" -gt 0 ] && [ "$(echo "$CURRENT_SIM_TIME > 0" | bc -l 2> /dev/null || echo 0)" = "1" ]; then
            calculate_progress "$CURRENT_SIM_TIME" "$TARGET_TIME" "$START_TIME" "$CURRENT_TIME"
        fi

        echo ""
        echo "Last few time steps:"
        echo "$TMUX_OUTPUT" | grep "Time Step:" | tail -5
        echo ""
        return 0
    else
        echo "Status: ⚠️  UNKNOWN - No time step output"
        echo ""
        echo "Last output:"
        echo "$TMUX_OUTPUT"
        echo ""
        return 1
    fi
}

function check_s3_for_completion() {
    local SIM_FILE=$1
    local SIM_BASE="${SIM_FILE%.fds}"
    local CHID
    CHID=$(basename "$SIM_BASE")

    echo "   Checking S3 for simulation status..."

    # Stream .out file from S3 and check last 50 lines for STOP message
    local STOP_MSG
    STOP_MSG=$(aws s3 cp "s3://${S3_BUCKET}/${CHID}/${CHID}.out" - 2> /dev/null | tail -50 | grep "STOP:" | tail -1)

    if [ -n "$STOP_MSG" ]; then
        if echo "$STOP_MSG" | grep -q "FDS completed successfully"; then
            echo "   ✅ Simulation completed successfully"
            echo "   $STOP_MSG"
            echo "   → Not restarting completed simulation"
            return 1
        else
            echo "   ❌ Simulation stopped with error/crash:"
            echo "   $STOP_MSG"
            echo "   → Not restarting crashed simulation"
            return 1
        fi
    fi

    echo "   ✓ No completion or crash markers found, safe to restart"
    return 0
}

function restart_simulation() {
    local SIM_FILE=$1
    local INSTANCE_TYPE=$2
    local OLD_INSTANCE_ID=$3

    echo "🔄 Restarting simulation: $SIM_FILE"

    # Check S3 for completion/crash evidence before restarting
    if ! check_s3_for_completion "$SIM_FILE"; then
        return 1
    fi

    local TARGET_REGION
    TARGET_REGION=$(find_cheapest_region "$INSTANCE_TYPE")
    echo "   Target region: $TARGET_REGION"

    if $LAUNCH_SCRIPT --key-path "$KEY_PATH" --replace-instance-id "$OLD_INSTANCE_ID" --region "$TARGET_REGION" --instance-type "$INSTANCE_TYPE" "$SIM_FILE"; then
        echo "✅ Successfully restarted $SIM_FILE in $TARGET_REGION"
        return 0
    else
        echo "❌ Failed to restart $SIM_FILE"
        return 1
    fi
}

function check_all_instances() {
    local TOTAL=0
    local RUNNING=0
    local COMPLETED=0
    local ERRORS=0
    local UNKNOWN=0
    local NOT_RUNNING=0

    while IFS='|' read -r IP INSTANCE_ID SIM_FILE REGION INSTANCE_TYPE; do
        # Skip empty lines
        [ -z "$IP" ] && continue

        : $((TOTAL++))

        check_instance_status "$IP" "$INSTANCE_ID" "$SIM_FILE" "$REGION" "$INSTANCE_TYPE"
        local STATUS=$?

        # Return codes: 0=running, 1=unknown, 2=completed, 3=error, 10=not running/inaccessible
        case $STATUS in
            0)
                : $((RUNNING++))
                ;;
            1)
                : $((UNKNOWN++))
                ;;
            2)
                : $((COMPLETED++))
                update_instance_status "$INSTANCE_ID" "completed"
                echo "🛑 Terminating completed instance $INSTANCE_ID in $REGION..."
                aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null 2>&1 || echo "   ⚠️  Warning: Failed to terminate instance"
                ;;
            3)
                : $((ERRORS++))
                update_instance_status "$INSTANCE_ID" "failed"
                echo "🛑 Terminating failed instance $INSTANCE_ID in $REGION..."
                aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null 2>&1 || echo "   ⚠️  Warning: Failed to terminate instance"
                ;;
            10)
                : $((NOT_RUNNING++))
                if [ "$AUTO_RESTART" = true ]; then
                    echo "🚨 Instance terminated, restarting..."
                    if restart_simulation "$SIM_FILE" "$INSTANCE_TYPE" "$INSTANCE_ID"; then
                        echo "   ✅ Database entry updated with new instance"
                    else
                        echo "⚠️  Restart failed, marking as terminated"
                        update_instance_status "$INSTANCE_ID" "terminated"
                    fi
                else
                    update_instance_status "$INSTANCE_ID" "terminated"
                fi
                ;;
            *)
                : $((UNKNOWN++))
                ;;
        esac
    done < <(get_instances)

    echo "========================================"
    echo "SUMMARY"
    echo "========================================"
    echo "Total instances: $TOTAL"
    echo "Running simulations: $RUNNING"
    echo "Completed: $COMPLETED"
    echo "Errors: $ERRORS"
    echo "Unknown status: $UNKNOWN"
    echo "Not running/inaccessible: $NOT_RUNNING"
    echo "========================================"

    # Return status based on state:
    # 0 = still running (keep watching)
    # 1 = all completed successfully
    # 2 = all crashed/errored
    # 3 = mixed results (some completed, some crashed)
    # 4 = no instances to monitor
    if [ "$TOTAL" -eq 0 ]; then
        return 4
    fi

    if [ "$RUNNING" -gt 0 ]; then
        return 0
    fi

    # All simulations stopped, check if we have definitive results
    local STUCK=$((UNKNOWN + NOT_RUNNING))

    # If nothing is running and we have stuck instances, stop watching
    # to avoid infinite loop
    if [ "$STUCK" -gt 0 ]; then
        echo ""
        echo "⚠️  Warning: ${STUCK} instance(s) in unknown/inaccessible state with no running simulations"
        # Return mixed results status since we can't determine final state
        return 3
    fi

    # All accounted for with definitive results
    if [ "$COMPLETED" -eq "$TOTAL" ]; then
        return 1
    elif [ "$ERRORS" -eq "$TOTAL" ]; then
        return 2
    else
        return 3
    fi
}

# --- MAIN ---

function main() {
    parse_arguments "$@"

    if ! validate_arguments; then
        exit 1
    fi

    echo "--- FDS Job Status Checker ---"
    echo "Database: $DB_FILE"
    echo "Monitoring: All active instances"
    if [ "$WATCH_MODE" = true ]; then
        echo "Watch mode: enabled (checking every ${CHECK_INTERVAL}s)"
        echo "Auto-restart: $AUTO_RESTART"
        echo "Press Ctrl+C to stop"
    fi
    echo ""

    if [ "$WATCH_MODE" = true ]; then
        while true; do
            check_all_instances
            local EXIT_CODE=$?

            case $EXIT_CODE in
                0)
                    # Still running, keep watching
                    echo ""
                    echo "Next check in ${CHECK_INTERVAL} seconds..."
                    sleep "$CHECK_INTERVAL"
                    echo ""
                    ;;
                1)
                    echo ""
                    echo "✅ All simulations completed successfully. Exiting."
                    exit 0
                    ;;
                2)
                    echo ""
                    echo "❌ All simulations crashed or errored. Exiting."
                    exit 2
                    ;;
                3)
                    echo ""
                    echo "⚠️  Mixed results: some completed, some crashed. Exiting."
                    exit 3
                    ;;
                4)
                    echo ""
                    echo "No instances to monitor. Exiting."
                    exit 0
                    ;;
            esac
        done
    else
        check_all_instances
        local EXIT_CODE=$?

        case $EXIT_CODE in
            0)
                # Still running
                exit 0
                ;;
            1)
                # All completed
                exit 0
                ;;
            2)
                # All errors
                exit 2
                ;;
            3)
                # Mixed results
                exit 3
                ;;
            4)
                # No instances
                exit 0
                ;;
        esac
    fi
}

main "$@"
