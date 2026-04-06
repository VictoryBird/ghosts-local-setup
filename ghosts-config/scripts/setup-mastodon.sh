#!/usr/bin/env bash
###############################################################################
# setup-mastodon.sh
#
# Complete Mastodon setup for GHOSTS NPC Framework cyber exercises.
# Replaces Pandora/Socializer with a federated Mastodon instance running
# in limited-federation mode on port 8000.
#
# Prerequisites:
#   - Docker and Docker Compose installed
#   - GHOSTS stack running (ghosts-postgres on port 5432)
#   - openssl available
#
# Usage:
#   ./setup-mastodon.sh [MASTODON_DIR]
#
# Arguments:
#   MASTODON_DIR  Directory containing docker-compose-mastodon.yml
#                 Default: ../mastodon (relative to this script)
#
# What this script does:
#   1. Generates cryptographic secrets
#   2. Creates .env.mastodon configuration
#   3. Creates mastodon database on shared PostgreSQL
#   4. Starts Mastodon containers
#   5. Runs database migrations
#   6. Creates admin account
#   7. Creates OAuth application for NPC automation
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTODON_DIR="${1:-${SCRIPT_DIR}/../mastodon}"
MASTODON_DIR="$(cd "${MASTODON_DIR}" && pwd)"

# Configuration
LOCAL_DOMAIN="meridianet.local"
DB_HOST="ghosts-postgres"
DB_USER="ghosts"
DB_PASS="scotty@1"
DB_NAME="mastodon_production"
REDIS_HOST="mastodon-redis"
ADMIN_USER="admin"
ADMIN_EMAIL="admin@${LOCAL_DOMAIN}"

ENV_FILE="${MASTODON_DIR}/.env.mastodon"
COMPOSE_FILE="${MASTODON_DIR}/docker-compose-mastodon.yml"

echo "============================================================"
echo " Mastodon Setup for GHOSTS NPC Framework"
echo " Domain:     ${LOCAL_DOMAIN}"
echo " Directory:  ${MASTODON_DIR}"
echo " Web port:   8000 (replacing Pandora)"
echo " Streaming:  4000"
echo "============================================================"
echo ""

###############################################################################
# Step 1: Generate secrets
###############################################################################
echo "[1/7] Generating cryptographic secrets..."

SECRET_KEY_BASE="$(openssl rand -hex 64)"
OTP_SECRET="$(openssl rand -hex 64)"

# Generate VAPID keys using openssl ecparam (Web Push)
VAPID_PRIVATE_KEY_PEM="$(openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null)"
VAPID_PRIVATE_KEY="$(echo "${VAPID_PRIVATE_KEY_PEM}" | openssl ec -outform DER 2>/dev/null | tail -c 32 | openssl base64 -A | tr '+/' '-_' | tr -d '=')"
VAPID_PUBLIC_KEY="$(echo "${VAPID_PRIVATE_KEY_PEM}" | openssl ec -pubout -outform DER 2>/dev/null | tail -c 65 | openssl base64 -A | tr '+/' '-_' | tr -d '=')"

# Active Record encryption keys
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="$(openssl rand -base64 32)"
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="$(openssl rand -base64 32)"
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="$(openssl rand -base64 32)"

echo "  Secrets generated successfully."

###############################################################################
# Step 2: Create .env.mastodon
###############################################################################
echo "[2/7] Writing ${ENV_FILE}..."

cat > "${ENV_FILE}" <<ENVEOF
###############################################################################
# Mastodon Environment — GHOSTS NPC Cyber Exercise
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Domain: ${LOCAL_DOMAIN}
###############################################################################

# --- Federation ---
LOCAL_DOMAIN=${LOCAL_DOMAIN}
LIMITED_FEDERATION_MODE=true
AUTHORIZED_FETCH=true
SINGLE_USER_MODE=false

# --- Database (shared with GHOSTS stack) ---
DB_HOST=${DB_HOST}
DB_PORT=5432
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_NAME=${DB_NAME}
DATABASE_URL=postgres://${DB_USER}:${DB_PASS}@${DB_HOST}:5432/${DB_NAME}

# --- Redis ---
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=6379
REDIS_URL=redis://${REDIS_HOST}:6379/0

# --- Elasticsearch (disabled) ---
ES_ENABLED=false

# --- Secrets ---
SECRET_KEY_BASE=${SECRET_KEY_BASE}
OTP_SECRET=${OTP_SECRET}

# --- Web Push (VAPID) ---
VAPID_PRIVATE_KEY=${VAPID_PRIVATE_KEY}
VAPID_PUBLIC_KEY=${VAPID_PUBLIC_KEY}

# --- Active Record Encryption ---
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=${ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY}
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=${ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT}
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=${ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY}

# --- SMTP (disabled — local only) ---
SMTP_SERVER=localhost
SMTP_PORT=25
SMTP_FROM_ADDRESS=notifications@${LOCAL_DOMAIN}
SMTP_DELIVERY_METHOD=none

# --- Performance tuning for 130 NPCs ---
MAX_THREADS=10
WEB_CONCURRENCY=4
STREAMING_CLUSTER_NUM=2
SIDEKIQ_CONCURRENCY=25
PREPARED_STATEMENTS=true

# --- Misc ---
RAILS_ENV=production
RAILS_LOG_LEVEL=warn
NODE_ENV=production
RAILS_SERVE_STATIC_FILES=true
BIND=0.0.0.0
PORT=3000
STREAMING_API_BASE_URL=http://mastodon-streaming:4000
ENVEOF

chmod 600 "${ENV_FILE}"
echo "  Environment file created."

###############################################################################
# Step 3: Create mastodon database on shared PostgreSQL
###############################################################################
echo "[3/7] Creating mastodon database on ghosts-postgres..."

# Check if ghosts-postgres is reachable
if ! docker exec ghosts-postgres pg_isready -U "${DB_USER}" >/dev/null 2>&1; then
    echo "  ERROR: ghosts-postgres is not running or not reachable."
    echo "  Start the GHOSTS stack first, then re-run this script."
    exit 1
fi

# Create database if it does not exist
DB_EXISTS=$(docker exec ghosts-postgres psql -U "${DB_USER}" -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" 2>/dev/null || true)

if [[ "${DB_EXISTS}" == "1" ]]; then
    echo "  Database '${DB_NAME}' already exists — skipping creation."
else
    docker exec ghosts-postgres psql -U "${DB_USER}" -c \
        "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" >/dev/null 2>&1
    echo "  Database '${DB_NAME}' created."
fi

###############################################################################
# Step 4: Start Mastodon containers
###############################################################################
echo "[4/7] Starting Mastodon containers..."

# Verify the external network exists
NETWORK_NAME="ghosts_default"
if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    echo "  WARNING: Network '${NETWORK_NAME}' not found."
    echo "  Trying to detect the GHOSTS network..."
    DETECTED=$(docker network ls --filter "label=com.docker.compose.network=default" \
        --format '{{.Name}}' | grep -i ghosts | head -1 || true)
    if [[ -n "${DETECTED}" ]]; then
        echo "  Detected network: ${DETECTED}"
        echo "  Update docker-compose-mastodon.yml 'ghosts-external' network name to: ${DETECTED}"
    fi
    echo "  ERROR: Cannot proceed without the GHOSTS network."
    echo "  Ensure the GHOSTS stack is running and the network name in"
    echo "  docker-compose-mastodon.yml matches your setup."
    exit 1
fi

cd "${MASTODON_DIR}"
docker compose -f "${COMPOSE_FILE}" up -d

echo "  Waiting for mastodon-web to become healthy..."
RETRIES=0
MAX_RETRIES=30
until docker exec mastodon-web curl -sf http://localhost:3000/health >/dev/null 2>&1; do
    RETRIES=$((RETRIES + 1))
    if [[ ${RETRIES} -ge ${MAX_RETRIES} ]]; then
        echo "  ERROR: mastodon-web did not become healthy within 5 minutes."
        echo "  Check logs: docker logs mastodon-web"
        exit 1
    fi
    echo "  Waiting... (${RETRIES}/${MAX_RETRIES})"
    sleep 10
done
echo "  mastodon-web is healthy."

###############################################################################
# Step 5: Run database migrations
###############################################################################
echo "[5/7] Running database migrations..."

docker compose -f "${COMPOSE_FILE}" exec -T mastodon-web \
    bundle exec rails db:setup SAFETY_ASSURED=1 2>&1 | tail -5

echo "  Migrations complete."

###############################################################################
# Step 6: Create admin account
###############################################################################
echo "[6/7] Creating admin account..."

ADMIN_OUTPUT=$(docker exec mastodon-web \
    tootctl accounts create "${ADMIN_USER}" \
        --email "${ADMIN_EMAIL}" \
        --confirmed \
        --role Owner 2>&1 || true)

# Extract password from tootctl output (format: "New password: <password>")
ADMIN_PASSWORD=$(echo "${ADMIN_OUTPUT}" | grep -oP '(?<=New password: ).*' || true)

if [[ -z "${ADMIN_PASSWORD}" ]]; then
    # Account may already exist — reset password
    ADMIN_PASSWORD=$(docker exec mastodon-web \
        tootctl accounts modify "${ADMIN_USER}" --reset-password 2>&1 \
        | grep -oP '(?<=New password: ).*' || true)
fi

if [[ -z "${ADMIN_PASSWORD}" ]]; then
    echo "  WARNING: Could not extract admin password from tootctl output."
    echo "  Raw output: ${ADMIN_OUTPUT}"
    echo "  You may need to reset it manually:"
    echo "    docker exec mastodon-web tootctl accounts modify admin --reset-password"
    ADMIN_PASSWORD="(see manual reset above)"
fi

echo "  Admin account created."

###############################################################################
# Step 7: Create OAuth application for NPC automation
###############################################################################
echo "[7/7] Creating OAuth application for NPC automation..."

OAUTH_OUTPUT=$(docker exec mastodon-web rails runner '
app = Doorkeeper::Application.find_or_create_by!(name: "GHOSTS NPC Automation") do |a|
  a.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
  a.scopes = "read write follow push admin:read admin:write"
  a.website = "http://localhost:5000"
end
puts "CLIENT_ID=#{app.uid}"
puts "CLIENT_SECRET=#{app.secret}"
' 2>&1)

CLIENT_ID=$(echo "${OAUTH_OUTPUT}" | grep "^CLIENT_ID=" | cut -d= -f2)
CLIENT_SECRET=$(echo "${OAUTH_OUTPUT}" | grep "^CLIENT_SECRET=" | cut -d= -f2)

# Save credentials to file
CREDS_FILE="${MASTODON_DIR}/mastodon-credentials.env"
cat > "${CREDS_FILE}" <<CREDEOF
# Mastodon Credentials — GHOSTS NPC Cyber Exercise
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

MASTODON_URL=http://localhost:8000
MASTODON_DOMAIN=${LOCAL_DOMAIN}
ADMIN_USER=${ADMIN_USER}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
OAUTH_CLIENT_ID=${CLIENT_ID}
OAUTH_CLIENT_SECRET=${CLIENT_SECRET}
CREDEOF
chmod 600 "${CREDS_FILE}"

echo ""
echo "============================================================"
echo " Mastodon Setup Complete"
echo "============================================================"
echo ""
echo " Web UI:          http://localhost:8000"
echo " Streaming API:   http://localhost:4000"
echo " Domain:          ${LOCAL_DOMAIN}"
echo " Federation:      LIMITED (air-gapped)"
echo ""
echo " Admin Account:"
echo "   Username:      ${ADMIN_USER}"
echo "   Email:         ${ADMIN_EMAIL}"
echo "   Password:      ${ADMIN_PASSWORD}"
echo ""
echo " OAuth Application (NPC Automation):"
echo "   Client ID:     ${CLIENT_ID}"
echo "   Client Secret: ${CLIENT_SECRET}"
echo ""
echo " Credentials saved to: ${CREDS_FILE}"
echo ""
echo " Next steps:"
echo "   1. Run setup-mastodon-npcs.sh to create 130 NPC accounts"
echo "   2. Update GHOSTS NPC social timelines to use Mastodon API"
echo "   3. Configure n8n workflows for Mastodon posting"
echo ""
echo "============================================================"
