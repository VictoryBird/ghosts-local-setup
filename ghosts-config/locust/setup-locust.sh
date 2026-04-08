#!/usr/bin/env bash
# =============================================================================
# setup-locust.sh - Locust 더미 트래픽 생성기 (Docker)
#
# 기능:
#   1. Docker로 Locust 컨테이너 빌드/실행
#   2. YAML 설정에서 소스 IP 읽어서 호스트 인터페이스에 추가
#   3. host 네트워크 모드로 소스 IP 바인딩 지원
#
# Usage:
#   # 기본 실행 (Web UI, http://VM_IP:8089)
#   sudo bash setup-locust.sh
#
#   # 특정 네트워크 지정
#   sudo bash setup-locust.sh --network network-b
#
#   # 소스 IP 설정만 (Locust 실행 안함)
#   sudo bash setup-locust.sh --setup-ips-only
#
#   # 소스 IP 제거
#   sudo bash setup-locust.sh --cleanup-ips
#
#   # 중지
#   sudo bash setup-locust.sh --stop
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/locust-targets.yaml"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose-locust.yaml"

# 기본값
NETWORK=""
SETUP_IPS_ONLY=false
CLEANUP_IPS=false
STOP=false

# ---------------------------------------------------------------------------
# 인자 파싱
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)        NETWORK="$2"; shift 2 ;;
        --setup-ips-only) SETUP_IPS_ONLY=true; shift ;;
        --cleanup-ips)    CLEANUP_IPS=true; shift ;;
        --stop)           STOP=true; shift ;;
        -h|--help)
            echo "Usage: sudo bash setup-locust.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --network NAME     네트워크 이름 (기본: 첫 번째)"
            echo "  --setup-ips-only   소스 IP 설정만"
            echo "  --cleanup-ips      소스 IP 제거"
            echo "  --stop             Locust 컨테이너 중지"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# YAML 파서
# ---------------------------------------------------------------------------
get_source_ips() {
    python3 -c "
import yaml

with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)

network_name = '${NETWORK}'
networks = config.get('networks', [])

if network_name:
    selected = [n for n in networks if n['name'] == network_name]
    net = selected[0] if selected else {}
else:
    net = networks[0] if networks else {}

for ip in net.get('source_ips', []):
    print(ip)
"
}

get_all_source_ips() {
    python3 -c "
import yaml

with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)

for net in config.get('networks', []):
    for ip in net.get('source_ips', []):
        print(ip)
"
}

# ---------------------------------------------------------------------------
# 네트워크 인터페이스 감지
# ---------------------------------------------------------------------------
detect_interface() {
    ip route show default | awk '{print $5}' | head -1
}

# ---------------------------------------------------------------------------
# 소스 IP 설정/제거
# ---------------------------------------------------------------------------
setup_source_ips() {
    local iface
    iface=$(detect_interface)
    echo "=== 소스 IP 설정 (인터페이스: ${iface}) ==="

    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        if ip addr show dev "$iface" | grep -q "$ip"; then
            echo "  [SKIP] ${ip} (이미 할당됨)"
        else
            ip addr add "${ip}/24" dev "$iface" 2>/dev/null || true
            echo "  [OK] ${ip}/24 -> ${iface}"
        fi
    done < <(get_source_ips)
}

cleanup_source_ips() {
    local iface
    iface=$(detect_interface)
    echo "=== 소스 IP 제거 (인터페이스: ${iface}) ==="

    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        if ip addr show dev "$iface" | grep -q "$ip"; then
            ip addr del "${ip}/24" dev "$iface" 2>/dev/null || true
            echo "  [OK] ${ip} 제거됨"
        else
            echo "  [SKIP] ${ip} (할당 안됨)"
        fi
    done < <(get_all_source_ips)
}

# ---------------------------------------------------------------------------
# 메인
# ---------------------------------------------------------------------------

# 중지 모드
if $STOP; then
    echo "=== Locust 컨테이너 중지 ==="
    cd "$SCRIPT_DIR"
    docker compose -f "$COMPOSE_FILE" down
    echo "완료."
    exit 0
fi

# IP 제거 모드
if $CLEANUP_IPS; then
    cleanup_source_ips
    echo "완료."
    exit 0
fi

# 설정 파일 확인
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: 설정 파일 없음: ${CONFIG_FILE}"
    exit 1
fi

# 소스 IP 설정
SOURCE_IP_LIST=$(get_source_ips)
if [[ -n "$SOURCE_IP_LIST" ]]; then
    setup_source_ips
fi

# IP 설정만 모드
if $SETUP_IPS_ONLY; then
    echo "소스 IP 설정 완료."
    exit 0
fi

# Docker 빌드 및 실행
echo ""
echo "=== Locust Docker 빌드 및 실행 ==="
cd "$SCRIPT_DIR"
export LOCUST_NETWORK="$NETWORK"

docker compose -f "$COMPOSE_FILE" up -d --build

echo ""
echo "=========================================="
echo " Locust 실행 중"
echo "  Web UI: http://$(hostname -I | awk '{print $1}'):8089"
echo "  Network: ${NETWORK:-default (첫 번째)}"
echo "  설정 파일: ${CONFIG_FILE}"
echo ""
echo " 중지: sudo bash setup-locust.sh --stop"
echo "=========================================="
