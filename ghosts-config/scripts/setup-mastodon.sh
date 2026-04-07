#!/usr/bin/env bash
###############################################################################
# setup-mastodon.sh
#
# Clean Mastodon setup for GHOSTS NPC Framework.
# Based on official docs: https://docs.joinmastodon.org/admin/install/
#
# Prerequisites:
#   - GHOSTS stack running (provides ghosts-postgres + ghosts_default network)
#
# Usage:
#   ./setup-mastodon.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MASTODON_DIR="$(cd "$SCRIPT_DIR/../mastodon" && pwd)"

LOCAL_DOMAIN="meridianet.local"
ADMIN_USER="ghostsadmin"
ADMIN_EMAIL="ghostsadmin@meridianet.local"

DB_HOST="ghosts-postgres"
DB_USER="ghosts"
DB_PASS="scotty@1"
DB_NAME="mastodon_production"

echo "============================================"
echo "  Mastodon Setup for GHOSTS"
echo "  Domain: ${LOCAL_DOMAIN}"
echo "============================================"
echo ""

# Detect docker command
DOCKER_CMD="docker"
COMPOSE_CMD="docker compose"
if ! docker info &>/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
    COMPOSE_CMD="sudo docker compose"
fi

# -----------------------------------------------------------------------------
# 1. Cleanup
# -----------------------------------------------------------------------------
echo "[1/7] Cleaning up..."
cd "$MASTODON_DIR"
$COMPOSE_CMD -f docker-compose-mastodon.yml down -v 2>/dev/null || true
$DOCKER_CMD stop ghosts-pandora 2>/dev/null || true
$DOCKER_CMD rm -f ghosts-pandora 2>/dev/null || true

# Drop old mastodon DB if exists (clean start)
$DOCKER_CMD exec ghosts-postgres psql -U "$DB_USER" -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true

# -----------------------------------------------------------------------------
# 2. Generate secrets
# -----------------------------------------------------------------------------
echo "[2/7] Generating secrets..."

SECRET_KEY_BASE=$(openssl rand -hex 64)
OTP_SECRET=$(openssl rand -hex 64)
ARE_DETERMINISTIC_KEY=$(openssl rand -hex 32)
ARE_KEY_DERIVATION_SALT=$(openssl rand -hex 32)
ARE_PRIMARY_KEY=$(openssl rand -hex 32)
VAPID_PRIVATE_KEY=$(openssl rand -hex 32)
VAPID_PUBLIC_KEY=$(openssl rand -hex 32)

# -----------------------------------------------------------------------------
# 3. Create .env.mastodon
# -----------------------------------------------------------------------------
echo "[3/7] Creating .env.mastodon..."

cat > "$MASTODON_DIR/.env.mastodon" << ENVEOF
# Mastodon — GHOSTS Cyber Exercise (Air-Gapped)
LOCAL_DOMAIN=${LOCAL_DOMAIN}
LIMITED_FEDERATION_MODE=false
AUTHORIZED_FETCH=false
DB_HOST=${DB_HOST}
DB_PORT=5432
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
REDIS_HOST=mastodon-redis
REDIS_PORT=6379
ES_ENABLED=false
SECRET_KEY_BASE=${SECRET_KEY_BASE}
OTP_SECRET=${OTP_SECRET}
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=${ARE_DETERMINISTIC_KEY}
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=${ARE_KEY_DERIVATION_SALT}
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=${ARE_PRIMARY_KEY}
VAPID_PRIVATE_KEY=${VAPID_PRIVATE_KEY}
VAPID_PUBLIC_KEY=${VAPID_PUBLIC_KEY}
SMTP_SERVER=localhost
SMTP_PORT=25
SMTP_FROM_ADDRESS=mastodon@${LOCAL_DOMAIN}
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_LEVEL=warn
WEB_CONCURRENCY=2
MAX_THREADS=5
ENVEOF

# -----------------------------------------------------------------------------
# 4. Create database
# -----------------------------------------------------------------------------
echo "[4/7] Creating database..."
$DOCKER_CMD exec ghosts-postgres psql -U "$DB_USER" -c "CREATE DATABASE ${DB_NAME};" 2>/dev/null || true

# Verify ghosts_default network
if ! $DOCKER_CMD network inspect ghosts_default &>/dev/null; then
    echo "  ERROR: ghosts_default network not found. Start GHOSTS stack first."
    exit 1
fi

# -----------------------------------------------------------------------------
# 5. Start Redis + run DB migration
# -----------------------------------------------------------------------------
echo "[5/7] Starting Redis and running migrations..."
cd "$MASTODON_DIR"
$COMPOSE_CMD -f docker-compose-mastodon.yml up -d mastodon-redis
sleep 5

# Run schema load via one-off container
echo "  -> Loading database schema..."
$COMPOSE_CMD -f docker-compose-mastodon.yml run --rm -e RAILS_ENV=production \
    mastodon-web bundle exec rails db:schema:load 2>&1 | tail -3

echo "  -> Seeding database..."
$COMPOSE_CMD -f docker-compose-mastodon.yml run --rm -e RAILS_ENV=production \
    mastodon-web bundle exec rails db:seed 2>&1 | tail -3

# -----------------------------------------------------------------------------
# 6. Start all services
# -----------------------------------------------------------------------------
echo "[6/7] Starting all services..."
$COMPOSE_CMD -f docker-compose-mastodon.yml up -d
echo "  -> Waiting for services..."

for i in $(seq 1 30); do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        echo "  -> Mastodon is healthy!"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "  -> WARNING: Health check timed out. Continuing anyway..."
    fi
    sleep 5
done

# -----------------------------------------------------------------------------
# 7. Create admin account + configure instance
# -----------------------------------------------------------------------------
echo "[7/7] Creating admin and configuring instance..."

# Create admin account via Rails console (bypasses email domain validation)
GENERATED_PASS=$(openssl rand -hex 12)
$COMPOSE_CMD -f docker-compose-mastodon.yml exec -T mastodon-web \
    bin/rails runner "
account = Account.find_local('${ADMIN_USER}')
if account && account.user
  puts 'Admin account already exists'
else
  account = Account.new(username: '${ADMIN_USER}')
  account.display_name = 'GHOSTS Admin'
  account.save!(validate: false)

  user = User.new(
    email: '${ADMIN_EMAIL}',
    password: '${GENERATED_PASS}',
    account: account,
    confirmed_at: Time.now.utc,
    approved: true,
    agreement: true
  )
  user.save!(validate: false)
  puts 'Admin account created'
end

# Set admin role
u = User.find_by(email: '${ADMIN_EMAIL}')
if u
  role = UserRole.find_by(name: 'Admin') || UserRole.find_by(id: 3)
  u.update!(role: role) if role
  puts 'Admin role set'
end

Setting.registrations_mode = 'open'
Setting.site_title = 'MeridiaNet'
Setting.site_short_description = 'Meridia Social Network'
puts 'Instance configured: open registration, title=MeridiaNet'
" 2>&1

# Final test
sleep 3
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ 2>/dev/null || echo "000")

# Save credentials
cat > "$MASTODON_DIR/mastodon-credentials.env" << CREDEOF
ADMIN_USER=${ADMIN_USER}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASS=${GENERATED_PASS}
MASTODON_URL=http://$(hostname -I | awk '{print $1}'):8000
CREDEOF

echo ""
echo "============================================"
echo "  Mastodon Setup Complete"
echo "============================================"
echo "  URL:       http://$(hostname -I | awk '{print $1}'):8000"
echo "  HTTP test: ${HTTP_CODE}"
echo "  Admin:     ${ADMIN_USER} / ${GENERATED_PASS}"
echo "  Creds:     ${MASTODON_DIR}/mastodon-credentials.env"
echo ""
echo "  Next: ./setup-mastodon-npcs.sh"
echo "============================================"
