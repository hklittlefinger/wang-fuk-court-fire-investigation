#!/bin/bash

# Shared utility functions for FDS simulation scripts

# --- UTILITIES ---

function get_chid() {
    local SIM_FILE=$1
    basename "${SIM_FILE%.fds}"
}

# --- LOGGING ---

function log() {
    if [ -n "$LOG_FILE" ]; then
        local message="$1"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    fi
}

function log_error() {
    local message="$1"
    echo "ERROR: $message" >&2
    if [ -n "$ERROR_LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $message" >> "$ERROR_LOG_FILE"
    fi
}

function log_warning() {
    local message="$1"
    echo "WARNING: $message" >&2
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $message" >> "$LOG_FILE"
    fi
}

# --- SQLite Database Functions ---

DB_FILE="${DB_FILE:-${SCRIPT_DIR}/../data/instances.db}"

function check_instances_db() {
    if [ ! -f "$DB_FILE" ]; then
        return 1
    fi
    return 0
}

function init_instances_db() {
    sqlite3 "$DB_FILE" <<'EOF'
CREATE TABLE IF NOT EXISTS instances (
    ip TEXT NOT NULL,
    instance_id TEXT PRIMARY KEY,
    sim_file TEXT NOT NULL,
    region TEXT NOT NULL,
    instance_type TEXT NOT NULL,
    status TEXT DEFAULT 'active' CHECK(status IN ('pending', 'active', 'terminated')),
    sim_status TEXT DEFAULT NULL CHECK(sim_status IS NULL OR sim_status IN ('running', 'completed', 'failed', 'interrupted')),
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_sim_file ON instances(sim_file);
CREATE INDEX IF NOT EXISTS idx_status ON instances(status);
CREATE INDEX IF NOT EXISTS idx_sim_status ON instances(sim_status);

-- Trigger to auto-update updated_at on UPDATE
CREATE TRIGGER IF NOT EXISTS update_timestamp
AFTER UPDATE ON instances
FOR EACH ROW
BEGIN
    UPDATE instances SET updated_at = strftime('%s', 'now') WHERE instance_id = NEW.instance_id;
END;
EOF
}

function add_instance() {
    local IP=$1
    local INSTANCE_ID=$2
    local SIM_FILE=$3
    local REGION=$4
    local INSTANCE_TYPE=$5

    sqlite3 "$DB_FILE" <<EOF
INSERT INTO instances (ip, instance_id, sim_file, region, instance_type, status)
VALUES ('$IP', '$INSTANCE_ID', '$SIM_FILE', '$REGION', '$INSTANCE_TYPE', 'pending');
EOF
}

function get_pending_instances() {
    sqlite3 "$DB_FILE" "SELECT instance_id, region FROM instances WHERE status='pending';"
}

function update_instance() {
    local OLD_INSTANCE_ID=$1
    local NEW_INSTANCE_ID=$2
    local NEW_IP=$3
    local NEW_REGION=$4
    local STATUS=$5
    local INSTANCE_TYPE=$6

    sqlite3 "$DB_FILE" <<EOF
UPDATE instances
SET instance_id = '$NEW_INSTANCE_ID',
    ip = '$NEW_IP',
    region = '$NEW_REGION',
    status = '$STATUS',
    instance_type = '$INSTANCE_TYPE'
WHERE instance_id = '$OLD_INSTANCE_ID';
EOF
}

function update_instance_status() {
    local INSTANCE_ID=$1
    local STATUS=$2

    sqlite3 "$DB_FILE" <<EOF
UPDATE instances
SET status = '$STATUS'
WHERE instance_id = '$INSTANCE_ID';
EOF
}

function update_sim_status() {
    local INSTANCE_ID=$1
    local SIM_STATUS=$2

    sqlite3 "$DB_FILE" <<EOF
UPDATE instances
SET sim_status = '$SIM_STATUS'
WHERE instance_id = '$INSTANCE_ID';
EOF
}

function delete_instance() {
    local INSTANCE_ID=$1
    sqlite3 "$DB_FILE" "DELETE FROM instances WHERE instance_id = '$INSTANCE_ID';"
}

function get_instances() {
    local STATUSES=("${@:-active}")
    local IFS=','
    local SQL_IN="${STATUSES[*]}"
    SQL_IN="${SQL_IN//,/','}"
    sqlite3 "$DB_FILE" "SELECT ip, instance_id, sim_file, region, instance_type FROM instances WHERE status IN ('$SQL_IN');"
}

# --- Region Functions ---

# Blacklisted regions - these will be excluded from region selection
# ap-east-1 (Hong Kong): Excluded due to the subject matter of this investigation
BLACKLISTED_REGIONS=("ap-east-1")

function is_region_blacklisted() {
    local region=$1
    for blacklisted in "${BLACKLISTED_REGIONS[@]}"; do
        if [ "$region" == "$blacklisted" ]; then
            return 0
        fi
    done
    return 1
}

function get_region_prices() {
    local INSTANCE_TYPE=$1

    log "Getting spot prices for $INSTANCE_TYPE across all regions"

    local REGIONS
    REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

    local -a REGION_PRICES=()

    for region in $REGIONS; do
        # Skip blacklisted regions
        if is_region_blacklisted "$region"; then
            log "Skipping blacklisted region: $region"
            continue
        fi
        local PRICE
        PRICE=$(aws ec2 describe-spot-price-history \
            --instance-types "$INSTANCE_TYPE" \
            --region "$region" \
            --product-descriptions "Linux/UNIX" \
            --max-results 1 \
            --query 'SpotPriceHistory[0].SpotPrice' \
            --output text 2>/dev/null || echo "")

        if [ -n "$PRICE" ] && [ "$PRICE" != "None" ]; then
            log "Region $region: \$$PRICE"
            REGION_PRICES+=("$PRICE|$region")
        fi
    done

    if [ ${#REGION_PRICES[@]} -eq 0 ]; then
        log_error "No pricing data available for $INSTANCE_TYPE"
        return 1
    fi

    # Sort by price (ascending) and output as space-separated list
    printf '%s\n' "${REGION_PRICES[@]}" | sort -t'|' -k1 -n | tr '\n' ' ' | sed 's/ $//'
}
