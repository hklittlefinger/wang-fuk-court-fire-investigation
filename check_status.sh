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
    echo "  --interval SECONDS        Check interval for watch mode (default: 60)"
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

    # Guard against division by zero
    if [ "$ELAPSED_WALL_TIME" -lt 1 ]; then
        ELAPSED_WALL_TIME=1
    fi

    # Calculate progress percentage
    local PROGRESS
    PROGRESS=$(printf "%.2f" "$(echo "scale=4; ($CURRENT_SIM_TIME * 100) / $TARGET_TIME" | bc -l)")

    # Calculate elapsed wall minutes (minimum 0.01 to avoid division by zero)
    local ELAPSED_WALL_MINS
    ELAPSED_WALL_MINS=$(echo "scale=2; x=$ELAPSED_WALL_TIME / 60; if (x < 0.01) 0.01 else x" | bc -l)

    # Calculate rate (sim seconds per wall minute)
    local RATE
    RATE=$(printf "%.2f" "$(echo "scale=4; $CURRENT_SIM_TIME / $ELAPSED_WALL_MINS" | bc -l)")

    # Estimate remaining time (guard against zero rate)
    local REMAINING_SIM_TIME
    REMAINING_SIM_TIME=$(echo "$TARGET_TIME - $CURRENT_SIM_TIME" | bc -l)
    local ESTIMATED_WALL_MINS
    if [ "$(echo "$RATE > 0" | bc -l)" = "1" ]; then
        ESTIMATED_WALL_MINS=$(echo "scale=0; $REMAINING_SIM_TIME / $RATE" | bc -l)
    else
        ESTIMATED_WALL_MINS=0
    fi

    # Format elapsed time
    local ELAPSED_HOURS=$((ELAPSED_WALL_TIME / 3600))
    local ELAPSED_MINS=$(((ELAPSED_WALL_TIME % 3600) / 60))

    # Format estimated finish time (convert to integer for bash arithmetic)
    local ESTIMATED_WALL_SECONDS
    ESTIMATED_WALL_SECONDS=$(printf "%.0f" "$(echo "$ESTIMATED_WALL_MINS * 60" | bc)")
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
        return 11  # Special code for spot interruption
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
    local SIM_FILE=$3

    # Check if pane is dead (process exited)
    local PANE_DEAD
    PANE_DEAD=$(ssh_exec "$IP" "tmux display-message -p -t fds_run '#{pane_dead}'" 2> /dev/null || echo "")

    if [ "$PANE_DEAD" != "1" ]; then
        return 0 # Still running
    fi

    # Pane is dead, get exit status
    local EXIT_STATUS
    EXIT_STATUS=$(ssh_exec "$IP" "tmux display-message -p -t fds_run '#{pane_dead_status}'" 2> /dev/null || echo "")

    # Get more output to check for errors (FDS may exit 0 even on ERROR)
    local FULL_OUTPUT
    FULL_OUTPUT=$(ssh_exec "$IP" "tmux capture-pane -p -t fds_run -S -100" 2> /dev/null || echo "")

    # Check for ERROR in output (FDS returns exit code 0 even on numerical instability)
    if echo "$FULL_OUTPUT" | grep -q "ERROR"; then
        echo "Status: ❌ ERROR (found ERROR in output, exit code: ${EXIT_STATUS:-unknown})"
        echo ""
        echo "Last output:"
        echo "$FULL_OUTPUT" | grep -A5 "ERROR" | head -10
        echo ""
        return 3
    fi

    # Check if simulation actually completed (reached T_END)
    local T_END
    T_END=$(get_fds_end_time "$SIM_FILE")
    local LAST_SIM_TIME
    LAST_SIM_TIME=$(echo "$FULL_OUTPUT" | grep "Simulation Time:" | tail -1 | sed -n 's/.*Simulation Time:[[:space:]]*\([0-9.]*\).*/\1/p')

    if [ -n "$LAST_SIM_TIME" ] && [ -n "$T_END" ]; then
        # Check if we reached at least 99% of T_END
        local PROGRESS
        PROGRESS=$(echo "scale=2; $LAST_SIM_TIME / $T_END" | bc -l 2>/dev/null || echo "0")
        if [ "$(echo "$PROGRESS < 0.99" | bc -l 2>/dev/null || echo 1)" = "1" ]; then
            echo "Status: ❌ INCOMPLETE (reached ${LAST_SIM_TIME}s / ${T_END}s, exit code: ${EXIT_STATUS:-unknown})"
            echo ""
            echo "Last output:"
            echo "$TMUX_OUTPUT" | tail -10
            echo ""
            return 3
        fi
    fi

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
    check_aws_instance "$REGION" "$INSTANCE_ID"
    local AWS_STATUS=$?
    if [ "$AWS_STATUS" -ne 0 ]; then
        echo ""
        return "$AWS_STATUS"  # Propagate 10 (not running) or 11 (spot interrupted)
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
    check_simulation_completion "$IP" "$TMUX_OUTPUT" "$SIM_FILE"
    local COMPLETION_STATUS=$?
    if [ "$COMPLETION_STATUS" -ne 0 ]; then
        return "$COMPLETION_STATUS"
    fi

    # Simulation is running
    show_running_status "$IP" "$SIM_FILE" "$TMUX_OUTPUT"
    return 0
}

function show_running_status() {
    local IP=$1
    local SIM_FILE=$2
    local TMUX_OUTPUT=$3

    echo "Status: 🔄 RUNNING"

    local TIME_STEP
    TIME_STEP=$(echo "$TMUX_OUTPUT" | grep "Time Step:" | tail -1)
    [ -z "$TIME_STEP" ] && echo "" && return

    echo "$TIME_STEP"

    local CURRENT_SIM_TIME
    CURRENT_SIM_TIME=$(echo "$TIME_STEP" | sed -n 's/.*Simulation Time:[[:space:]]*\([0-9.]*\).*/\1/p')
    CURRENT_SIM_TIME=${CURRENT_SIM_TIME:-0}

    local TARGET_TIME
    TARGET_TIME=$(get_fds_end_time "$SIM_FILE")

    local CHID
    CHID=$(get_chid "$SIM_FILE")

    local START_TIME
    START_TIME=$(ssh_exec "$IP" "stat -c %W /home/ubuntu/fds-work/${CHID}/${CHID}.out 2>/dev/null || echo 0")

    local CURRENT_TIME
    CURRENT_TIME=$(date +%s)

    if [ "$START_TIME" -gt 0 ] && [ "$(echo "$CURRENT_SIM_TIME > 0" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
        calculate_progress "$CURRENT_SIM_TIME" "$TARGET_TIME" "$START_TIME" "$CURRENT_TIME"
    fi

    echo ""
    echo "Last few time steps:"
    echo "$TMUX_OUTPUT" | grep "Time Step:" | tail -5
    echo ""
}

# Check simulation status from S3 output when instance is not accessible
# Returns: "completed" or "failed"
function check_sim_status_from_s3() {
    local SIM_FILE=$1
    local CHID
    CHID=$(get_chid "$SIM_FILE")

    # Check for successful completion in .out file
    if aws s3 cp "s3://${S3_BUCKET}/${CHID}/${CHID}.out" - 2>/dev/null | tail -50 | grep -iq "STOP.*completed"; then
        echo "completed"
    else
        echo "failed"
    fi
}

function is_simulation_restartable() {
    local SIM_FILE=$1
    local CHID
    CHID=$(get_chid "$SIM_FILE")

    # Check for restart files in S3
    local RESTART_COUNT
    RESTART_COUNT=$(aws s3 ls "s3://${S3_BUCKET}/${CHID}/" 2>/dev/null | grep -c '\.restart' || true)

    if [ "$RESTART_COUNT" -eq 0 ]; then
        return 1
    fi

    # Not restartable if already completed
    [ "$(check_sim_status_from_s3 "$SIM_FILE")" = "completed" ] && return 1

    return 0
}

function check_all_instances() {
    local TOTAL=0
    local RUNNING=0
    local COMPLETED=0
    local ERRORS=0
    local NOT_RUNNING=0
    local INTERRUPTED=0

    while IFS='|' read -r IP INSTANCE_ID SIM_FILE REGION INSTANCE_TYPE; do
        [ -z "$IP" ] && continue
        : $((TOTAL++))

        check_instance_status "$IP" "$INSTANCE_ID" "$SIM_FILE" "$REGION" "$INSTANCE_TYPE"
        local STATUS=$?

        case $STATUS in
            0)
                # Simulation is running
                : $((RUNNING++))
                update_sim_status "$INSTANCE_ID" "running"
                ;;
            2)
                # Simulation completed successfully
                : $((COMPLETED++))
                update_sim_status "$INSTANCE_ID" "completed"
                update_instance_status "$INSTANCE_ID" "terminated"
                echo "🛑 Terminating completed instance $INSTANCE_ID in $REGION..."
                aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null 2>&1 || echo "   ⚠️  Warning: Failed to terminate instance"
                ;;
            3)
                # Simulation failed (FDS error)
                : $((ERRORS++))
                update_sim_status "$INSTANCE_ID" "failed"
                update_instance_status "$INSTANCE_ID" "terminated"
                echo "🛑 Terminating failed instance $INSTANCE_ID in $REGION..."
                aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null 2>&1 || echo "   ⚠️  Warning: Failed to terminate instance"
                ;;
            10)
                # Instance not running - check S3 for actual sim status
                : $((NOT_RUNNING++))
                local S3_STATUS
                S3_STATUS=$(check_sim_status_from_s3 "$SIM_FILE")
                update_sim_status "$INSTANCE_ID" "$S3_STATUS"
                update_instance_status "$INSTANCE_ID" "terminated"
                ;;
            11)
                # Spot interrupted - simulation was interrupted, may restart
                : $((INTERRUPTED++))
                update_sim_status "$INSTANCE_ID" "interrupted"
                update_instance_status "$INSTANCE_ID" "terminated"
                if [ "$AUTO_RESTART" = true ] && is_simulation_restartable "$SIM_FILE"; then
                    echo "🔄 Restarting interrupted simulation: $SIM_FILE"
                    if $LAUNCH_SCRIPT --key-path "$KEY_PATH" --replace-instance-id "$INSTANCE_ID" --instance-type "$INSTANCE_TYPE" "$SIM_FILE"; then
                        echo "   ✅ Restarted successfully"
                    else
                        echo "   ⚠️  Restart failed"
                    fi
                fi
                ;;
        esac
    done < <(get_instances active)

    echo "========================================"
    echo "SUMMARY - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo "Total active instances: $TOTAL"
    echo "Running simulations: $RUNNING"
    echo "Completed: $COMPLETED"
    echo "Failed (FDS errors): $ERRORS"
    echo "Interrupted (spot): $INTERRUPTED"
    echo "Not running/other: $NOT_RUNNING"
    echo "========================================"
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
            echo ""
            echo "Next check in ${CHECK_INTERVAL} seconds... (Ctrl+C to stop)"
            sleep "$CHECK_INTERVAL"
            echo ""
        done
    else
        check_all_instances
    fi
}


main "$@"
