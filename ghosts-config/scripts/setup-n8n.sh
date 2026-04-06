#!/bin/bash
set -euo pipefail

# =============================================================================
# GHOSTS n8n Workflow Setup Script
#
# This script:
#   1. Waits for n8n to be ready
#   2. Imports the Phase Trigger workflow via n8n API
#   3. Prints instructions for manual workflow imports
#
# Prerequisites:
#   - Docker Compose stack is running (docker compose up -d)
#   - n8n initial account has been created via web UI
#
# Usage:
#   ./setup-n8n.sh [N8N_API_KEY]
#
# The N8N_API_KEY can be generated in n8n UI:
#   Settings > API > Create API Key
# =============================================================================

GHOSTS_DIR="${GHOSTS_DIR:-$HOME/ghosts}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "$SCRIPT_DIR/../n8n-workflows" && pwd)"

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
echo "  n8n URL:    ${N8N_BASE_URL}"
echo "  Host IP:    ${HOST_IP}"
echo "  Workflow dir: ${WORKFLOW_DIR}"
echo ""

# -----------------------------------------------------------------------------
# 1. Wait for n8n to be ready
# -----------------------------------------------------------------------------
echo "[1/3] Waiting for n8n to be ready..."

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
# 2. Check API key
# -----------------------------------------------------------------------------
echo ""
echo "[2/3] Checking n8n API access..."

if [ -z "$N8N_API_KEY" ]; then
    echo ""
    echo "  ============================================================"
    echo "  n8n API Key가 설정되지 않았습니다."
    echo ""
    echo "  API를 통한 자동 임포트를 사용하려면:"
    echo "    1. 브라우저에서 ${N8N_BASE_URL} 접속"
    echo "    2. 초기 계정 생성 (최초 접속 시)"
    echo "    3. Settings > API > Create API Key"
    echo "    4. 아래 명령으로 다시 실행:"
    echo ""
    echo "       N8N_API_KEY=<your-api-key> $0"
    echo "       또는: $0 <your-api-key>"
    echo ""
    echo "  ============================================================"
    echo ""
    echo "  -> API 키 없이 수동 임포트 안내로 진행합니다."
    echo ""

    # Skip to manual instructions
    SKIP_API_IMPORT=true
else
    # Test API access
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        "${N8N_API_URL}/workflows" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        echo "  -> API 접근 확인 완료 (HTTP ${HTTP_CODE})"
        SKIP_API_IMPORT=false
    else
        echo "  [WARNING] API 접근 실패 (HTTP ${HTTP_CODE})"
        echo "  API 키를 확인하세요. 수동 임포트 안내로 진행합니다."
        SKIP_API_IMPORT=true
    fi
fi

# -----------------------------------------------------------------------------
# 3. Import workflows
# -----------------------------------------------------------------------------
echo "[3/3] Importing workflows..."

import_workflow() {
    local file="$1"
    local name=$(basename "$file" .json)

    if [ ! -f "$file" ]; then
        echo "  [SKIP] File not found: $file"
        return 1
    fi

    echo "  -> Importing: $name"

    # Replace host.docker.internal with actual host IP in the workflow
    local temp_file=$(mktemp)
    sed "s/host\.docker\.internal/${HOST_IP}/g" "$file" > "$temp_file"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
        -H "Content-Type: application/json" \
        -d @"$temp_file" \
        "${N8N_API_URL}/workflows" 2>/dev/null || echo "000")

    rm -f "$temp_file"

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "     OK (HTTP ${HTTP_CODE})"
        return 0
    else
        echo "     FAILED (HTTP ${HTTP_CODE})"
        return 1
    fi
}

if [ "${SKIP_API_IMPORT:-false}" = "false" ]; then
    echo ""
    echo "  --- 인지전 전용 워크플로우 ---"

    # Import phase trigger workflow
    PHASE_TRIGGER="${WORKFLOW_DIR}/phase-trigger-workflow.json"
    if [ -f "$PHASE_TRIGGER" ]; then
        import_workflow "$PHASE_TRIGGER" && \
            echo "     Phase Trigger webhook: ${N8N_BASE_URL}/webhook/phase-change" || true
    fi

    echo ""
    echo "  --- GHOSTS 기본 워크플로우 (수동 임포트 필요) ---"
    echo ""
fi

# -----------------------------------------------------------------------------
# Print manual import instructions
# -----------------------------------------------------------------------------
echo "============================================"
echo "  수동 워크플로우 임포트 안내"
echo "============================================"
echo ""
echo "  1. 브라우저에서 n8n 접속: ${N8N_BASE_URL}"
echo ""
echo "  2. GHOSTS 기본 워크플로우 임포트:"
echo "     파일 위치: ${GHOSTS_DIR}/GHOSTS/configuration/n8n-workflows/"
echo ""
echo "     Workflows > ... > Import from File 에서 아래 파일 선택:"
echo ""
echo "     [1] GHOSTS Post to Social Media.json  (AI 소셜 포스트 생성)"
echo "     [2] GHOSTS Social Graph.json           (소셜 그래프 구성)"
echo "     [3] GHOSTS Belief.json                 (신념 모델링)"
echo "     [4] GHOSTS Connections.json            (NPC 연결 관리)"
echo "     [5] GHOSTS Preferences.json            (NPC 선호도 관리)"
echo ""
echo "  3. 인지전 전용 워크플로우 임포트:"
echo "     파일 위치: ${WORKFLOW_DIR}/"
echo ""
echo "     [6] phase-trigger-workflow.json        (Phase 전환 트리거)"
echo ""
echo "  4. 임포트 후 URL 수정 (각 워크플로우에서):"
echo ""
echo "     host.docker.internal  ->  ${HOST_IP}"
echo "     mistral               ->  social (또는 qwen3.5:9b)"
echo "     Pandora URL           ->  http://${HOST_IP}:8000"
echo "     GHOSTS API URL        ->  http://${HOST_IP}:5000/api"
echo ""
echo "     Docker 내부 네트워크 사용 시 (n8n -> 같은 compose 서비스):"
echo "     Ollama                ->  http://${HOST_IP}:11434"
echo "     Pandora               ->  http://ghosts-pandora:5000"
echo "     GHOSTS API            ->  http://ghosts-api:5000/api"
echo ""
echo "  5. 워크플로우 활성화:"
echo "     각 워크플로우를 열고 우측 상단 토글을 Active로 변경"
echo ""
echo "  6. Phase Trigger 테스트:"
echo ""
echo "     curl -X POST ${N8N_BASE_URL}/webhook/phase-change \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"phase\": 2, \"intensity\": \"low\"}'"
echo ""
echo "============================================"
echo ""
echo "  상세 설정 가이드: ${WORKFLOW_DIR}/README-n8n-setup.md"
echo ""
echo "============================================"
