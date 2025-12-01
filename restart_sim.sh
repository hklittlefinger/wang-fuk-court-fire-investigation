#!/bin/bash
set -e

# Restart FDS Simulation Script
# Usage: ./restart_sim.sh --key-path PATH --ip IP --file FILE

KEY_PATH=""
IP=""
FDS_FILE=""
CLEAN=false

# SSH helper function for consistent options
ssh_exec() {
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$KEY_PATH" "ubuntu@$IP" "$@"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --key-path)
            KEY_PATH="$2"
            shift 2
            ;;
        --ip)
            IP="$2"
            shift 2
            ;;
        --file)
            FDS_FILE="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --help | -h)
            echo "Usage: $0 --key-path PATH --ip IP --file FILE [--clean]"
            echo ""
            echo "Required arguments:"
            echo "  --key-path PATH    Path to SSH private key"
            echo "  --ip IP            EC2 instance public IP"
            echo "  --file FILE        FDS input file to restart"
            echo ""
            echo "Optional arguments:"
            echo "  --clean            Delete old output files instead of preserving them"
            echo ""
            echo "Example:"
            echo "  $0 --key-path ~/.ssh/fds-key-pair --ip 16.171.113.205 --file tier1_2_steel_PP_styro.fds"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Validate arguments
if [ -z "$KEY_PATH" ]; then
    echo "ERROR: --key-path is required" >&2
    exit 1
fi

if [ -z "$IP" ]; then
    echo "ERROR: --ip is required" >&2
    exit 1
fi

if [ -z "$FDS_FILE" ]; then
    echo "ERROR: --file is required" >&2
    exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
    echo "ERROR: Key file not found: $KEY_PATH" >&2
    exit 1
fi

if [ ! -f "$FDS_FILE" ]; then
    echo "ERROR: FDS file not found: $FDS_FILE" >&2
    exit 1
fi

REMOTE_FILE=$(basename "$FDS_FILE")
CHID="${REMOTE_FILE%.fds}"

# Count number of meshes (MPI processes)
NUM_MESHES=$(grep -c "^&MESH" "$FDS_FILE" || echo "1")

echo "========================================="
echo "Restarting FDS Simulation"
echo "========================================="
echo "Instance IP: $IP"
echo "FDS File: $FDS_FILE"
echo "CHID: $CHID"
echo "MPI Processes: $NUM_MESHES"
echo ""

# Step 1: Upload FDS file
echo "1. Uploading FDS file to instance..."
if ! scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$KEY_PATH" "$FDS_FILE" "ubuntu@$IP:~/"; then
    echo "ERROR: Failed to upload $FDS_FILE" >&2
    exit 1
fi
echo "   ✓ Upload complete"

# Step 2: Kill existing tmux session
echo "2. Stopping existing simulation..."
ssh_exec "tmux kill-session -t fds_run 2>/dev/null" || true
echo "   ✓ Stopped"

# Step 3: Clean old output files
if [ "$CLEAN" = true ]; then
    echo "3. Cleaning old output files..."
    ssh_exec "rm -f ${CHID}*.out ${CHID}*.smv ${CHID}*.s3d ${CHID}*.sf ${CHID}*.csv 2>/dev/null" || true
    echo "   ✓ Cleaned"
else
    echo "3. Preserving old output files..."
    TIMESTAMP=$(ssh_exec "stat -c %Y ${CHID}.out 2>/dev/null | xargs -I{} date -d @{} +%Y%m%d_%H%M%S || date +%Y%m%d_%H%M%S")
    BACKUP_DIR="${CHID}_${TIMESTAMP}"
    ssh_exec "mkdir -p $BACKUP_DIR && mv ${CHID}*.out ${CHID}*.smv ${CHID}*.s3d ${CHID}*.sf ${CHID}*.csv $BACKUP_DIR/ 2>/dev/null" || true
    echo "   ✓ Moved to $BACKUP_DIR/"
fi

# Step 4: Start simulation in tmux
echo "4. Starting simulation in tmux..."
if ! ssh_exec "tmux new-session -d -s fds_run 'source \$HOME/FDS/FDS6/bin/FDS6VARS.sh && mpiexec -n $NUM_MESHES fds $REMOTE_FILE' && tmux set-option -t fds_run remain-on-exit on"; then
    echo "ERROR: Failed to start simulation" >&2
    exit 1
fi
echo "   ✓ Simulation started in tmux session 'fds_run'"

# Step 5: Wait and verify
echo "5. Verifying simulation started..."
sleep 30

OUTPUT=$(ssh_exec "tail -30 ${CHID}.out 2>/dev/null || tmux capture-pane -t fds_run -p | tail -20")

if echo "$OUTPUT" | grep -qE "^ERROR\([0-9]+\)|ERROR:.*FDS stopped"; then
    echo ""
    echo "❌ ERROR DETECTED:"
    echo "$OUTPUT"
    exit 1
elif echo "$OUTPUT" | grep -qE "Time Step:\s+[0-9]+, Simulation Time:"; then
    echo "   ✓ Simulation running successfully"
    echo ""
    echo "========================================="
    echo "SUCCESS"
    echo "========================================="
    echo "Attach to session: ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $KEY_PATH ubuntu@$IP 'tmux attach -t fds_run'"
    echo "Monitor output:    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $KEY_PATH ubuntu@$IP 'tail -f ${CHID}.out'"
else
    echo ""
    echo "⚠️  WARNING: Could not verify simulation status"
    echo "Last output:"
    echo "$OUTPUT"
    exit 2
fi
