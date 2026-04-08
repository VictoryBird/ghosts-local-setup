#!/usr/bin/env bash
###############################################################################
# fix-broken-npcs.sh
#
# 1. GHOSTS API에서 문제있는 NPC 6개 삭제
# 2. Mastodon에서 해당 계정 삭제 (존재하는 경우)
# 3. GHOSTS API에 올바른 이름으로 NPC 재생성
# 4. Mastodon 계정 생성 + 토큰 발급
# 5. npc_tokens.json 업데이트
###############################################################################

set -euo pipefail

DOCKER_CMD="docker"
if ! docker info &>/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GHOSTS_API="http://localhost:5000"
MASTODON_URL="http://localhost:8000"
TOKEN_FILE="${SCRIPT_DIR}/../mastodon/npc-data/npc_tokens.json"

# NPC IDs to delete from GHOSTS
DELETE_IDS=(
    "019d6884-aa39-7d8e-b6d5-1ec3b0650645"
    "019d6884-adcc-79ca-a03f-4a85c06a8bd1"
    "019d6884-aded-7100-9fc5-e25ed4d2abd1"
    "019d6884-adfa-72d4-a29b-c2800bb5f622"
    "019d6884-ae08-7f3f-9515-394b26f75698"
    "019d6884-af4c-75bd-9f87-f10fe93d11fd"
)

# Mastodon usernames to delete (if they exist)
DELETE_MASTODON_USERS=(
    "vwa_official"
    "gov20190847"
    "spectr3"
)

# New NPCs to create
# Format: username|first|last|email|role|country|display_name
NEW_NPCS=(
    "mnd_inspector|MND|Inspector|mnd.inspector@mnd.valdoria.gov|official|valdoria|MND Inspector"
    "mois_official|MOIS|Official|mois.official@mois.valdoria.gov|official|valdoria|MOIS Official"
    "mnd_official|MND|Official|mnd.official@mnd.valdoria.gov|official|valdoria|MND Official"
    "cdc_official|CDC|Official|cdc.official@cdc.valdoria.gov|official|valdoria|CDC Official"
    "vwa_official|VWA|Official|vwa.official@vwa.valdoria.gov|official|valdoria|VWA Official"
    "spectr3|Spectr3|Ghost|spectr3@darknet.tk|gorgon|krasnovia|Spectr3"
)

echo "============================================================"
echo " Fix Broken NPCs"
echo "============================================================"

###############################################################################
# Step 1: Delete from GHOSTS API
###############################################################################
echo ""
echo "[1/4] GHOSTS API에서 NPC 삭제..."

for npc_id in "${DELETE_IDS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${GHOSTS_API}/api/npcs/${npc_id}")
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
        echo "  [OK] Deleted NPC: ${npc_id}"
    else
        echo "  [WARN] HTTP ${HTTP_CODE} for NPC: ${npc_id}"
    fi
done

###############################################################################
# Step 2: Delete from Mastodon
###############################################################################
echo ""
echo "[2/4] Mastodon에서 계정 삭제..."

for username in "${DELETE_MASTODON_USERS[@]}"; do
    RESULT=$($DOCKER_CMD exec mastodon-web rails runner "
account = Account.find_local('${username}')
if account
  if account.user
    account.user.destroy!
  end
  account.destroy!
  puts 'DELETED'
else
  puts 'NOT_FOUND'
end
" 2>/dev/null || echo "ERROR")

    if [[ "$RESULT" == *"DELETED"* ]]; then
        echo "  [OK] Deleted Mastodon account: @${username}"
    elif [[ "$RESULT" == *"NOT_FOUND"* ]]; then
        echo "  [SKIP] Not found: @${username}"
    else
        echo "  [WARN] Error deleting @${username}: ${RESULT}"
    fi
done

###############################################################################
# Step 3: Create new NPCs in GHOSTS API
###############################################################################
echo ""
echo "[3/4] GHOSTS API에 NPC 재생성..."

declare -A NEW_NPC_IDS

for entry in "${NEW_NPCS[@]}"; do
    IFS='|' read -r username first last email role country display_name <<< "$entry"

    NPC_JSON=$(cat <<NPEOF
{
  "npcProfile": {
    "name": {
      "first": "${first}",
      "last": "${last}"
    },
    "email": "${email}",
    "attributes": {
      "role": "${role}",
      "country": "${country}"
    }
  }
}
NPEOF
)

    RESPONSE=$(curl -s -X POST "${GHOSTS_API}/api/npcs" \
        -H "Content-Type: application/json" \
        -d "${NPC_JSON}")

    NPC_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

    if [[ -n "$NPC_ID" && "$NPC_ID" != "" ]]; then
        echo "  [OK] Created NPC: ${display_name} (${NPC_ID})"
        NEW_NPC_IDS["${username}"]="${NPC_ID}"
    else
        echo "  [FAIL] Failed to create NPC: ${display_name}"
        echo "    Response: ${RESPONSE}"
    fi
done

###############################################################################
# Step 4: Create Mastodon accounts + update token file
###############################################################################
echo ""
echo "[4/4] Mastodon 계정 생성 + 토큰 발급..."

for entry in "${NEW_NPCS[@]}"; do
    IFS='|' read -r username first last email role country display_name <<< "$entry"

    safe_display_name="${display_name//\'/\\\'}"

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

    DATA_LINE=$(echo "${RESULT}" | grep -E "^[0-9]+\|" || true)

    if [[ -z "${DATA_LINE}" ]]; then
        echo "  [FAIL] ${username}: ${RESULT}"
        continue
    fi

    MASTODON_ID=$(echo "${DATA_LINE}" | cut -d'|' -f1)
    TOKEN=$(echo "${DATA_LINE}" | cut -d'|' -f2)
    NPC_ID="${NEW_NPC_IDS[${username}]:-}"

    echo "  [OK] @${username} (mastodon_id: ${MASTODON_ID})"

    # Update token file
    python3 -c "
import json

with open('${TOKEN_FILE}', 'r') as f:
    tokens = json.load(f)

# Remove old entries that map to these usernames
for old_key in ['gov20190847']:
    tokens.pop(old_key, None)

tokens['${username}'] = {
    'npc_id': '${NPC_ID}',
    'mastodon_id': '${MASTODON_ID}',
    'display_name': '${display_name}',
    'email': '${email}',
    'country': '${country}',
    'role': '${role}',
    'token': '${TOKEN}'
}

with open('${TOKEN_FILE}', 'w') as f:
    json.dump(tokens, f, indent=2)
"

done

###############################################################################
# Summary
###############################################################################
echo ""
echo "============================================================"
echo " 완료!"
echo "  삭제: ${#DELETE_IDS[@]} NPCs from GHOSTS"
echo "  생성: ${#NEW_NPCS[@]} NPCs (GHOSTS + Mastodon)"
echo "  토큰 파일: ${TOKEN_FILE}"
echo "============================================================"
