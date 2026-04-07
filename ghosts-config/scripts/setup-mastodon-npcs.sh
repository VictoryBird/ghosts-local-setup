#!/usr/bin/env bash
###############################################################################
# setup-mastodon-npcs.sh
#
# Creates Mastodon accounts for all 130 GHOSTS NPCs, generates API tokens,
# and establishes follow relationships for the cyber exercise.
#
# Prerequisites:
#   - GHOSTS API running at localhost:5000 with NPCs already created
#   - Mastodon running (setup-mastodon.sh completed)
#   - mastodon-credentials.env exists (created by setup-mastodon.sh)
#   - jq installed
#
# Usage:
#   ./setup-mastodon-npcs.sh [MASTODON_DOMAIN] [GHOSTS_API_URL]
#
# Arguments:
#   MASTODON_DOMAIN  Default: meridianet.local
#   GHOSTS_API_URL   Default: http://localhost:5000
###############################################################################

set -euo pipefail

# Use sudo for docker if current user is not in docker group
DOCKER_CMD="docker"
if ! docker info &>/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTODON_DIR="${SCRIPT_DIR}/../mastodon"
MASTODON_DOMAIN="${1:-meridianet.local}"
GHOSTS_API="${2:-http://localhost:5000}"
OUTPUT_DIR="${MASTODON_DIR}/npc-data"
TOKEN_FILE="${OUTPUT_DIR}/npc_tokens.json"
ACCOUNTS_FILE="${OUTPUT_DIR}/npc_accounts.csv"
CREDS_FILE="${MASTODON_DIR}/mastodon-credentials.env"

mkdir -p "${OUTPUT_DIR}"

echo "============================================================"
echo " Mastodon NPC Account Generator"
echo " Domain:     ${MASTODON_DOMAIN}"
echo " GHOSTS API: ${GHOSTS_API}"
echo " Output:     ${OUTPUT_DIR}"
echo "============================================================"
echo ""

###############################################################################
# Preflight checks
###############################################################################
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required. Install with: sudo apt install jq"
    exit 1
fi

if ! curl -sf "${GHOSTS_API}/api/npcs" >/dev/null 2>&1; then
    echo "ERROR: GHOSTS API not reachable at ${GHOSTS_API}"
    exit 1
fi

if ! curl -sf http://localhost:8000/health >/dev/null 2>&1 && \
   ! $DOCKER_CMD inspect --format='{{.State.Health.Status}}' mastodon-web 2>/dev/null | grep -q healthy; then
    echo "ERROR: mastodon-web container is not healthy."
    exit 1
fi

###############################################################################
# Fetch all NPCs from GHOSTS API
###############################################################################
echo "[1/4] Fetching NPCs from GHOSTS API..."

NPC_JSON=$(curl -sf "${GHOSTS_API}/api/npcs" 2>/dev/null)
NPC_COUNT=$(echo "${NPC_JSON}" | jq 'length')

echo "  Found ${NPC_COUNT} NPCs."

if [[ "${NPC_COUNT}" -eq 0 ]]; then
    echo "ERROR: No NPCs found. Run generate-npcs.sh first."
    exit 1
fi

###############################################################################
# Create Mastodon accounts and generate tokens
###############################################################################
echo "[2/4] Creating Mastodon accounts and generating API tokens..."

# Initialize JSON output
echo "{" > "${TOKEN_FILE}"
echo "username,email,mastodon_id,country,role,token" > "${ACCOUNTS_FILE}"

CREATED=0
FAILED=0
SKIPPED=0
FIRST_ENTRY=true

# Official accounts to create (institutional)
declare -A OFFICIAL_ACCOUNTS=(
    ["valdoriagov"]="valdoriagov@${MASTODON_DOMAIN}"
    ["mnd_valdoria"]="mnd@${MASTODON_DOMAIN}"
    ["vwa_official"]="vwa@${MASTODON_DOMAIN}"
    ["valdoria_cdc"]="cdc@${MASTODON_DOMAIN}"
    ["krasnovia_state"]="krasnoviastate@${MASTODON_DOMAIN}"
)

# Track account IDs for follow setup
declare -A ACCOUNT_IDS
declare -A ACCOUNT_TOKENS

# Helper: create a Mastodon account and get its API token
# Uses Rails console directly to bypass email domain validation
# Sets _RETURN_ID and _RETURN_TOKEN globals (avoids subshell variable loss)
create_account_and_token() {
    local username="$1"
    local email="$2"
    local display_name="${3:-}"

    _RETURN_ID=""
    _RETURN_TOKEN=""

    # Escape single quotes for Ruby string safety
    local safe_display_name="${display_name//\'/\\\'}"

    # Create account + generate token in a single Rails call
    local RESULT
    RESULT=$($DOCKER_CMD exec mastodon-web rails runner "
account = Account.find_local('${username}')
if account && account.user
  STDERR.puts 'ALREADY_EXISTS'
  user = account.user
else
  account = Account.new(username: '${username}')
  account.display_name = '${safe_display_name}'
  account.save!(validate: false)

  user = User.new(
    email: '${email}',
    password: SecureRandom.hex(16),
    account: account,
    confirmed_at: Time.now.utc,
    approved: true,
    agreement: true
  )
  user.save!(validate: false)
  STDERR.puts 'CREATED'
end

app = Doorkeeper::Application.find_or_create_by!(name: 'GHOSTS NPC Automation') do |a|
  a.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
  a.scopes = 'read write follow push'
end

token = Doorkeeper::AccessToken.find_or_create_for(
  application: app,
  resource_owner: user,
  scopes: Doorkeeper::OAuth::Scopes.from_string('read write follow push'),
  expires_in: nil,
  use_refresh_token: false
)

puts \"#{account.id}|#{token.token}\"
" 2>&1)

    local STDERR_LINE
    STDERR_LINE=$(echo "${RESULT}" | grep -E "ALREADY_EXISTS|CREATED" || true)
    local DATA_LINE
    DATA_LINE=$(echo "${RESULT}" | grep -E "^[0-9]+\|" || true)

    if [[ -z "${DATA_LINE}" ]]; then
        FAILED=$((FAILED + 1))
        echo "  FAIL: ${username}: ${RESULT}" >&2
        return 1
    fi

    _RETURN_ID=$(echo "${DATA_LINE}" | cut -d'|' -f1)
    _RETURN_TOKEN=$(echo "${DATA_LINE}" | cut -d'|' -f2)

    if echo "${STDERR_LINE}" | grep -q "ALREADY_EXISTS"; then
        SKIPPED=$((SKIPPED + 1))
    else
        CREATED=$((CREATED + 1))
    fi

    ACCOUNT_IDS["${username}"]="${_RETURN_ID}"
    ACCOUNT_TOKENS["${username}"]="${_RETURN_TOKEN}"
}

# Helper: derive username from NPC name
derive_username() {
    local first="$1"
    local last="$2"
    # lowercase first initial + last name, no spaces or special chars
    local username
    username=$(echo "${first:0:1}${last}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_')
    echo "${username}"
}

echo ""
echo "  --- Creating official/institutional accounts ---"

for acct_name in "${!OFFICIAL_ACCOUNTS[@]}"; do
    local_email="${OFFICIAL_ACCOUNTS[${acct_name}]}"
    echo "  Creating: ${acct_name} (${local_email})"
    create_account_and_token "${acct_name}" "${local_email}" "${acct_name}" || true
done

echo ""
echo "  --- Creating NPC accounts ---"

# Process each NPC from GHOSTS API
for i in $(seq 0 $((NPC_COUNT - 1))); do
    FIRST=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.name.first // empty")
    LAST=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.name.last // empty")
    EMAIL=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.email // empty")
    COUNTRY=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.attributes.country // \"unknown\"")
    ROLE=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.attributes.role // \"citizen\"")
    NPC_ID=$(echo "${NPC_JSON}" | jq -r ".[$i].id // empty")

    if [[ -z "${FIRST}" || -z "${LAST}" ]]; then
        echo "  SKIP: NPC index ${i} — missing name."
        continue
    fi

    USERNAME=$(derive_username "${FIRST}" "${LAST}")
    DISPLAY_NAME="${FIRST} ${LAST}"

    # Use NPC email or generate one
    if [[ -z "${EMAIL}" ]]; then
        EMAIL="${USERNAME}@${MASTODON_DOMAIN}"
    fi

    echo "  [$(( i + 1 ))/${NPC_COUNT}] ${DISPLAY_NAME} -> @${USERNAME} (${COUNTRY}/${ROLE})"

    create_account_and_token "${USERNAME}" "${EMAIL}" "${DISPLAY_NAME}" || true
    ACCT_ID="${_RETURN_ID}"
    TOKEN="${_RETURN_TOKEN}"

    # Append to JSON
    if [[ "${FIRST_ENTRY}" == "true" ]]; then
        FIRST_ENTRY=false
    else
        echo "," >> "${TOKEN_FILE}"
    fi

    cat >> "${TOKEN_FILE}" <<JEOF
  "${USERNAME}": {
    "npc_id": "${NPC_ID}",
    "mastodon_id": "${ACCT_ID}",
    "display_name": "${DISPLAY_NAME}",
    "email": "${EMAIL}",
    "country": "${COUNTRY}",
    "role": "${ROLE}",
    "token": "${TOKEN}"
  }
JEOF

    echo "${USERNAME},${EMAIL},${ACCT_ID},${COUNTRY},${ROLE},${TOKEN}" >> "${ACCOUNTS_FILE}"
done

echo "}" >> "${TOKEN_FILE}"

echo ""
echo "  Created: ${CREATED}  Skipped: ${SKIPPED}  Failed: ${FAILED}"

###############################################################################
# Step 3: Set up follow relationships
###############################################################################
echo ""
echo "[3/4] Setting up follow relationships..."

# Helper: make one account follow another via Mastodon API
follow_account() {
    local follower_username="$1"
    local target_username="$2"
    local follower_token="${ACCOUNT_TOKENS[${follower_username}]:-}"
    local target_id="${ACCOUNT_IDS[${target_username}]:-}"

    if [[ -z "${follower_token}" || -z "${target_id}" ]]; then
        return 1
    fi

    curl -sf -X POST "http://localhost:8000/api/v1/accounts/${target_id}/follow" \
        -H "Authorization: Bearer ${follower_token}" \
        -o /dev/null 2>/dev/null || true
}

# Build lists of accounts by country/role for follow logic
echo "  Building account category lists..."

declare -a VALDORIA_CITIZENS=()
declare -a VALDORIA_OFFICIALS=()
declare -a KRASNOVIA_DISGUISED=()
declare -a KRASNOVIA_BOTS=()
declare -a ARVENTA_CITIZENS=()
declare -a ALL_USERNAMES=()

for i in $(seq 0 $((NPC_COUNT - 1))); do
    FIRST=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.name.first // empty")
    LAST=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.name.last // empty")
    COUNTRY=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.attributes.country // \"unknown\"")
    ROLE=$(echo "${NPC_JSON}" | jq -r ".[$i].npcProfile.attributes.role // \"citizen\"")

    [[ -z "${FIRST}" || -z "${LAST}" ]] && continue

    USERNAME=$(derive_username "${FIRST}" "${LAST}")
    ALL_USERNAMES+=("${USERNAME}")

    case "${COUNTRY}" in
        valdoria)
            case "${ROLE}" in
                citizen|media) VALDORIA_CITIZENS+=("${USERNAME}") ;;
                official|military) VALDORIA_OFFICIALS+=("${USERNAME}") ;;
            esac
            ;;
        krasnovia)
            case "${ROLE}" in
                disguised|gorgon) KRASNOVIA_DISGUISED+=("${USERNAME}") ;;
                bot) KRASNOVIA_BOTS+=("${USERNAME}") ;;
            esac
            ;;
        arventa)
            ARVENTA_CITIZENS+=("${USERNAME}")
            ;;
    esac
done

# Official institutional accounts that NPCs should follow
VALDORIA_OFFICIAL_ACCOUNTS=("valdoriagov" "mnd_valdoria" "vwa_official" "valdoria_cdc")
KRASNOVIA_OFFICIAL_ACCOUNTS=("krasnovia_state")

FOLLOW_COUNT=0
FOLLOW_FAILED=0

# All Valdoria citizens follow Valdoria official institutional accounts
echo "  Valdoria citizens -> Valdoria institutional accounts..."
for citizen in "${VALDORIA_CITIZENS[@]}"; do
    for official in "${VALDORIA_OFFICIAL_ACCOUNTS[@]}"; do
        if follow_account "${citizen}" "${official}"; then
            FOLLOW_COUNT=$((FOLLOW_COUNT + 1))
        else
            FOLLOW_FAILED=$((FOLLOW_FAILED + 1))
        fi
    done
done

# Valdoria officials also follow institutional accounts
echo "  Valdoria officials -> Valdoria institutional accounts..."
for official_npc in "${VALDORIA_OFFICIALS[@]}"; do
    for official in "${VALDORIA_OFFICIAL_ACCOUNTS[@]}"; do
        follow_account "${official_npc}" "${official}" && FOLLOW_COUNT=$((FOLLOW_COUNT + 1)) || FOLLOW_FAILED=$((FOLLOW_FAILED + 1))
    done
done

# Krasnovia disguised accounts follow Valdoria institutional accounts (to see posts)
echo "  Krasnovia disguised -> Valdoria institutional accounts..."
for disguised in "${KRASNOVIA_DISGUISED[@]}"; do
    for official in "${VALDORIA_OFFICIAL_ACCOUNTS[@]}"; do
        follow_account "${disguised}" "${official}" && FOLLOW_COUNT=$((FOLLOW_COUNT + 1)) || FOLLOW_FAILED=$((FOLLOW_FAILED + 1))
    done
done

# Krasnovia bots follow Krasnovia official accounts + disguised accounts
echo "  Krasnovia bots -> Krasnovia officials + disguised accounts..."
for bot in "${KRASNOVIA_BOTS[@]}"; do
    for official in "${KRASNOVIA_OFFICIAL_ACCOUNTS[@]}"; do
        follow_account "${bot}" "${official}" && FOLLOW_COUNT=$((FOLLOW_COUNT + 1)) || FOLLOW_FAILED=$((FOLLOW_FAILED + 1))
    done
    for disguised in "${KRASNOVIA_DISGUISED[@]}"; do
        follow_account "${bot}" "${disguised}" && FOLLOW_COUNT=$((FOLLOW_COUNT + 1)) || FOLLOW_FAILED=$((FOLLOW_FAILED + 1))
    done
done

# Arventa citizens follow Valdoria Government
echo "  Arventa citizens -> Valdoria Government..."
for citizen in "${ARVENTA_CITIZENS[@]}"; do
    follow_account "${citizen}" "valdoriagov" && FOLLOW_COUNT=$((FOLLOW_COUNT + 1)) || FOLLOW_FAILED=$((FOLLOW_FAILED + 1))
done

echo ""
echo "  Follow relationships: ${FOLLOW_COUNT} created, ${FOLLOW_FAILED} failed."

###############################################################################
# Step 4: Summary
###############################################################################
echo ""
echo "[4/4] Summary"
echo ""
echo "============================================================"
echo " Mastodon NPC Setup Complete"
echo "============================================================"
echo ""
echo " Accounts created:   ${CREATED}"
echo " Accounts skipped:   ${SKIPPED}"
echo " Accounts failed:    ${FAILED}"
echo " Follow relations:   ${FOLLOW_COUNT}"
echo ""
echo " Breakdown by category:"
echo "   Valdoria citizens: ${#VALDORIA_CITIZENS[@]}"
echo "   Valdoria officials: ${#VALDORIA_OFFICIALS[@]}"
echo "   Krasnovia disguised: ${#KRASNOVIA_DISGUISED[@]}"
echo "   Krasnovia bots: ${#KRASNOVIA_BOTS[@]}"
echo "   Arventa citizens: ${#ARVENTA_CITIZENS[@]}"
echo ""
echo " Output files:"
echo "   Token JSON:  ${TOKEN_FILE}"
echo "   Accounts CSV: ${ACCOUNTS_FILE}"
echo ""
echo " Token JSON format:"
echo '   {"username": {"npc_id": "...", "mastodon_id": "...", "token": "..."}}'
echo ""
echo " To verify an account token:"
echo "   curl -s http://localhost:8000/api/v1/accounts/verify_credentials \\"
echo '     -H "Authorization: Bearer <TOKEN>" | jq .username'
echo ""
echo "============================================================"
