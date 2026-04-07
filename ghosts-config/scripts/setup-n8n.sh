#!/bin/bash
set -euo pipefail

# =============================================================================
# GHOSTS n8n Workflow Setup Script
#
# This script:
#   1. Waits for n8n to be ready
#   2. Builds NPC token map from npc_tokens.json
#   3. Imports all workflows via n8n API (with IP/model/token substitution)
#   4. Falls back to manual import instructions if no API key
#
# Prerequisites:
#   - Docker Compose stack is running (docker compose up -d)
#   - n8n initial account has been created via web UI
#   - setup-mastodon-npcs.sh has been run (npc_tokens.json exists)
#
# Usage:
#   ./setup-n8n.sh [N8N_API_KEY]
# =============================================================================

GHOSTS_DIR="${GHOSTS_DIR:-$HOME/ghosts}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "$SCRIPT_DIR/../n8n-workflows" && pwd)"
MASTODON_DIR="$(cd "$SCRIPT_DIR/../mastodon" && pwd)"
TOKEN_FILE="${MASTODON_DIR}/npc-data/npc_tokens.json"

# Configuration
N8N_HOST="${N8N_HOST:-localhost}"
N8N_PORT="${N8N_PORT:-5678}"
N8N_BASE_URL="http://${N8N_HOST}:${N8N_PORT}"
N8N_API_URL="${N8N_BASE_URL}/api/v1"

# API Key (from argument or environment)
N8N_API_KEY="${1:-${N8N_API_KEY:-}}"

HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo "============================================"
echo "  GHOSTS n8n Workflow Setup"
echo "============================================"
echo ""
echo "  n8n URL:      ${N8N_BASE_URL}"
echo "  Host IP:      ${HOST_IP}"
echo "  Workflow dir: ${WORKFLOW_DIR}"
echo "  Token file:   ${TOKEN_FILE}"
echo ""

# -----------------------------------------------------------------------------
# 1. Wait for n8n to be ready
# -----------------------------------------------------------------------------
echo "[1/4] Waiting for n8n to be ready..."

MAX_RETRIES=30
RETRY_INTERVAL=5

for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf "${N8N_BASE_URL}/healthz" > /dev/null 2>&1 || \
       curl -sf "${N8N_BASE_URL}" > /dev/null 2>&1; then
        echo "  -> n8n is ready!"
        break
    fi

    if [ "$i" -eq "$MAX_RETRIES" ]; then
        echo "  [ERROR] n8n did not become ready after $((MAX_RETRIES * RETRY_INTERVAL)) seconds."
        echo "  Check: docker compose logs ghosts-n8n"
        exit 1
    fi

    echo "  -> Waiting... (attempt $i/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

# -----------------------------------------------------------------------------
# 2. Build NPC token map (saved to temp file to avoid bash quoting issues)
# -----------------------------------------------------------------------------
echo ""
echo "[2/4] Building NPC token map..."

TOKEN_MAP_FILE=$(mktemp)
if [ -f "$TOKEN_FILE" ]; then
    python3 - "$TOKEN_FILE" "$TOKEN_MAP_FILE" << 'PYEOF'
import json, sys
token_file, out_file = sys.argv[1], sys.argv[2]
with open(token_file) as f:
    data = json.load(f)
simple = {}
for username, info in data.items():
    if isinstance(info, dict) and 'token' in info:
        simple[username] = info['token']
    elif isinstance(info, str):
        simple[username] = info
with open(out_file, 'w') as f:
    json.dump(simple, f)
print(len(simple))
PYEOF
    TOKEN_COUNT=$(cat "$TOKEN_MAP_FILE" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    echo "  -> Loaded ${TOKEN_COUNT} NPC tokens."
else
    echo "  [WARNING] Token file not found: ${TOKEN_FILE}"
    echo "  -> Run setup-mastodon-npcs.sh first for Mastodon posting."
    echo "{}" > "$TOKEN_MAP_FILE"
fi

# -----------------------------------------------------------------------------
# 3. Check API key
# -----------------------------------------------------------------------------
echo ""
echo "[3/4] Checking n8n API access..."

SKIP_API_IMPORT=true

if [ -n "$N8N_API_KEY" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_API_URL}/workflows" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        echo "  -> API access confirmed (HTTP ${HTTP_CODE})"
        SKIP_API_IMPORT=false
    else
        echo "  [WARNING] API access failed (HTTP ${HTTP_CODE})"
    fi
else
    echo "  -> No API key provided."
fi

if [ "$SKIP_API_IMPORT" = "true" ]; then
    echo ""
    echo "  API를 통한 자동 임포트를 사용하려면:"
    echo "    1. 브라우저에서 ${N8N_BASE_URL} 접속"
    echo "    2. 초기 계정 생성 (최초 접속 시)"
    echo "    3. Settings > API > Create API Key"
    echo "    4. 아래 명령으로 다시 실행:"
    echo ""
    echo "       $0 <your-api-key>"
    echo ""
fi

# -----------------------------------------------------------------------------
# 4. Import workflows
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] Importing workflows..."

# Process a workflow JSON: replace placeholders, strip read-only fields, import
import_workflow() {
    local file="$1"
    local name
    name=$(basename "$file" .json)

    if [ ! -f "$file" ]; then
        echo "  [SKIP] File not found: $file"
        return 1
    fi

    echo -n "  -> ${name} ... "

    local temp_file
    temp_file=$(mktemp)

    # Use heredoc + sys.argv to avoid bash variable quoting issues
    python3 - "$file" "${HOST_IP}" "${TOKEN_MAP_FILE}" > "$temp_file" 2>/dev/null << 'PYEOF'
import json, sys

workflow_file = sys.argv[1]
host_ip = sys.argv[2]
token_map_file = sys.argv[3]

with open(workflow_file) as f:
    d = json.load(f)

# Keep only fields that n8n import API accepts
keep = {"name", "nodes", "connections", "settings"}
d = {k: v for k, v in d.items() if k in keep}

raw = json.dumps(d)

# Replace placeholders
raw = raw.replace("host.docker.internal", host_ip)
raw = raw.replace("mistral:7b", "qwen3.5:9b")
raw = raw.replace("mistral", "qwen3.5:9b")

# Inject NPC token map into jsCode strings
# __NPC_TOKEN_MAP__ sits inside a JSON string value, so quotes must be escaped
if "__NPC_TOKEN_MAP__" in raw:
    with open(token_map_file) as f:
        token_map = json.dumps(json.load(f))
    # Escape for embedding inside a JSON string value: \ -> \\, " -> \"
    escaped = token_map.replace("\\", "\\\\").replace('"', '\\"')
    raw = raw.replace("__NPC_TOKEN_MAP__", escaped)

# Parse back to validate JSON
d = json.loads(raw)
print(json.dumps(d))
PYEOF

    if [ ! -s "$temp_file" ]; then
        echo "FAILED (JSON processing error)"
        rm -f "$temp_file"
        return 1
    fi

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d @"$temp_file" \
        "${N8N_API_URL}/workflows" 2>/dev/null || echo "000")

    rm -f "$temp_file"

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "OK"
        return 0
    else
        echo "FAILED (HTTP ${HTTP_CODE})"
        return 1
    fi
}

IMPORTED=0
FAILED=0

if [ "$SKIP_API_IMPORT" = "false" ]; then
    echo ""
    echo "  --- Custom Meridia Workflows ---"

    for wf in \
        "${WORKFLOW_DIR}/GHOSTS-Post-to-Mastodon.json" \
        "${WORKFLOW_DIR}/GHOSTS-Belief-Meridia.json" \
        "${WORKFLOW_DIR}/GHOSTS-Social-Graph.json" \
        "${WORKFLOW_DIR}/GHOSTS-Phase-Trigger.json" \
        "${WORKFLOW_DIR}/GHOSTS-Timeline-Deploy.json"; do
        if import_workflow "$wf"; then
            IMPORTED=$((IMPORTED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done

    echo ""
    echo "  --- GHOSTS 기본 워크플로우 ---"

    GHOSTS_WF_DIR="${GHOSTS_DIR}/GHOSTS/configuration/n8n-workflows"
    for wf in \
        "${GHOSTS_WF_DIR}/GHOSTS Connections.json" \
        "${GHOSTS_WF_DIR}/GHOSTS Preferences.json"; do
        if [ -f "$wf" ]; then
            if import_workflow "$wf"; then
                IMPORTED=$((IMPORTED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
        else
            echo "  [SKIP] Not found: $wf"
        fi
    done

    echo ""
    echo "  Imported: ${IMPORTED}  Failed: ${FAILED}"
fi

# Clean up token map temp file
rm -f "$TOKEN_MAP_FILE"

# -----------------------------------------------------------------------------
# Print summary and instructions
# -----------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  n8n Workflow Setup Summary"
echo "============================================"
echo ""

if [ "$SKIP_API_IMPORT" = "false" ]; then
    echo "  자동 임포트 완료: ${IMPORTED}개 성공, ${FAILED}개 실패"
    echo ""
    echo "  워크플로우 활성화:"
    echo "    ${N8N_BASE_URL} 접속 → 각 워크플로우 → Active 토글"
    echo ""
    if [ "$FAILED" -gt 0 ]; then
        echo "  실패한 워크플로우는 수동으로 임포트해주세요."
        echo ""
    fi
else
    echo "  수동 임포트 안내:"
    echo ""
    echo "  1. 브라우저에서 ${N8N_BASE_URL} 접속"
    echo ""
    echo "  2. Workflows > ... > Import from File:"
    echo ""
    echo "     커스텀 워크플로우 (${WORKFLOW_DIR}/):"
    echo "     [1] GHOSTS-Post-to-Mastodon.json    (Mastodon 소셜 포스트)"
    echo "     [2] GHOSTS-Belief-Meridia.json       (Meridia 신념 모델링)"
    echo "     [3] GHOSTS-Social-Graph.json         (소셜 그래프)"
    echo "     [4] GHOSTS-Phase-Trigger.json        (인지전 Phase 트리거)"
    echo "     [5] GHOSTS-Timeline-Deploy.json      (에이전트 Timeline 배포)"
    echo ""
    echo "     GHOSTS 기본 워크플로우 (${GHOSTS_DIR}/GHOSTS/configuration/n8n-workflows/):"
    echo "     [6] GHOSTS Connections.json           (NPC 연결)"
    echo "     [7] GHOSTS Preferences.json           (NPC 선호도)"
    echo ""
    echo "  3. 임포트 후 URL 수정 (각 워크플로우에서):"
    echo "     host.docker.internal → ${HOST_IP}"
    echo "     mistral:7b           → qwen3.5:9b"
    echo ""
    echo "  4. Post-to-Mastodon/Phase-Trigger 워크플로우:"
    echo "     __NPC_TOKEN_MAP__ 을 실제 토큰 맵으로 교체 필요"
    echo "     토큰 파일: ${TOKEN_FILE}"
    echo ""
fi

echo "  워크플로우 테스트:"
echo ""
echo "  # Phase 2 인지전 트리거 (루머 시작)"
echo "  curl -X POST ${N8N_BASE_URL}/webhook/phase-change \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"phase\": 2, \"intensity\": \"low\"}'"
echo ""
echo "  # Timeline 배포 (정상 활동)"
echo "  curl -X POST ${N8N_BASE_URL}/webhook/deploy-timeline \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"phase\": 1, \"targetGroup\": \"all\"}'"
echo ""
echo "============================================"
