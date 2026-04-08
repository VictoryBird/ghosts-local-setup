#!/usr/bin/env bash
# =============================================================================
# setup-locust.sh - Locust 더미 트래픽 생성기 설치 및 실행
#
# 기능:
#   1. Locust + 의존성 설치
#   2. YAML 설정에서 소스 IP 읽어서 네트워크 인터페이스에 추가
#   3. Locust 실행 (headless 또는 Web UI)
#
# Usage:
#   # 기본 실행 (headless, 첫 번째 네트워크, 30분)
#   sudo bash setup-locust.sh
#
#   # 특정 네트워크 지정
#   sudo bash setup-locust.sh --network network-b
#
#   # Web UI 모드 (브라우저에서 http://VM_IP:8089 접속)
#   sudo bash setup-locust.sh --web-ui
#
#   # 실행 시간 지정
#   sudo bash setup-locust.sh --duration 1h
#
#   # 소스 IP 설정만 (Locust 실행 안함)
#   sudo bash setup-locust.sh --setup-ips-only
#
#   # 소스 IP 제거
#   sudo bash setup-locust.sh --cleanup-ips
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/locust-targets.yaml"
LOCUST_FILE="${SCRIPT_DIR}/locustfile.py"

# 기본값
NETWORK=""
WEB_UI=false
DURATION="30m"
SETUP_IPS_ONLY=false
CLEANUP_IPS=false

# ---------------------------------------------------------------------------
# 인자 파싱
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)      NETWORK="$2"; shift 2 ;;
        --web-ui)       WEB_UI=true; shift ;;
        --duration)     DURATION="$2"; shift 2 ;;
        --setup-ips-only) SETUP_IPS_ONLY=true; shift ;;
        --cleanup-ips)  CLEANUP_IPS=true; shift ;;
        --config)       CONFIG_FILE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo bash setup-locust.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --network NAME     네트워크 이름 (기본: 첫 번째)"
            echo "  --web-ui           Web UI 모드 (포트 8089)"
            echo "  --duration TIME    실행 시간 (기본: 30m)"
            echo "  --setup-ips-only   소스 IP 설정만"
            echo "  --cleanup-ips      소스 IP 제거"
            echo "  --config PATH      설정 파일 경로"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# YAML 파서 (python3 사용)
# ---------------------------------------------------------------------------
parse_yaml() {
    python3 -c "
import yaml, json, sys

with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)

network_name = '${NETWORK}'
networks = config.get('networks', [])

if network_name:
    selected = [n for n in networks if n['name'] == network_name]
    if not selected:
        print(f'ERROR: Network \"{network_name}\" not found', file=sys.stderr)
        sys.exit(1)
    net = selected[0]
else:
    net = networks[0] if networks else {}

print(json.dumps(net))
"
}

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

get_network_value() {
    local key="$1"
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

print(net.get('${key}', ''))
"
}

# ---------------------------------------------------------------------------
# 네트워크 인터페이스 감지
# ---------------------------------------------------------------------------
detect_interface() {
    # 기본 라우트의 인터페이스 감지
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
        # 이미 할당되어 있는지 확인
        if ip addr show dev "$iface" | grep -q "$ip"; then
            echo "  [SKIP] ${ip} (이미 할당됨)"
        else
            # IP에서 서브넷 추출 (같은 대역의 /24 사용)
            local subnet
            subnet=$(echo "$ip" | awk -F. '{print $1"."$2"."$3".0/24"}')
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
# 설치
# ---------------------------------------------------------------------------
install_locust() {
    echo "=== Locust 설치 ==="

    if command -v locust &>/dev/null; then
        echo "  [SKIP] Locust 이미 설치됨: $(locust --version 2>&1 | head -1)"
        return
    fi

    # pip3 설치
    if ! command -v pip3 &>/dev/null; then
        echo "  pip3 설치 중..."
        apt-get update -qq && apt-get install -y -qq python3-pip
    fi

    echo "  Locust 패키지 설치 중..."
    pip3 install locust pyyaml --break-system-packages 2>/dev/null \
        || pip3 install locust pyyaml

    echo "  [OK] Locust 설치 완료: $(locust --version 2>&1 | head -1)"
}

# ---------------------------------------------------------------------------
# 메인
# ---------------------------------------------------------------------------

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

# Locust 설치
install_locust

# 소스 IP 설정
SOURCE_IP_LIST=$(get_source_ips)
if [[ -n "$SOURCE_IP_LIST" ]]; then
    setup_source_ips
fi

# IP 설정만 모드
if $SETUP_IPS_ONLY; then
    echo "소스 IP 설정 완료. Locust는 실행하지 않습니다."
    exit 0
fi

# 네트워크 정보 출력
NET_NAME=$(get_network_value "name")
USERS=$(get_network_value "users")
SPAWN=$(get_network_value "spawn_rate")

echo ""
echo "=========================================="
echo " Locust Dummy Traffic Generator"
echo "  Network:  ${NET_NAME:-default}"
echo "  Users:    ${USERS:-5}"
echo "  Spawn:    ${SPAWN:-1}/s"
echo "  Duration: ${DURATION}"
echo "  Mode:     $($WEB_UI && echo 'Web UI (http://0.0.0.0:8089)' || echo 'Headless')"
echo "=========================================="
echo ""

# Locust 실행
export LOCUST_CONFIG="$CONFIG_FILE"
export LOCUST_NETWORK="$NETWORK"

if $WEB_UI; then
    echo "Web UI 모드로 실행 중... (http://0.0.0.0:8089)"
    locust -f "$LOCUST_FILE" \
        --web-host 0.0.0.0 \
        --web-port 8089
else
    echo "Headless 모드로 실행 중... (${DURATION})"
    locust -f "$LOCUST_FILE" \
        --headless \
        --users "${USERS:-5}" \
        --spawn-rate "${SPAWN:-1}" \
        --run-time "$DURATION" \
        --only-summary
fi
