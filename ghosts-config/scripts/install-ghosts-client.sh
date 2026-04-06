#!/bin/bash
set -euo pipefail

# =============================================================================
# GHOSTS NPC Client (Universal) — Install Script for Ubuntu 24.04
# Installs on NPC VMs and connects to the GHOSTS API server.
#
# The client executes Timelines: browser automation, document creation,
# SSH sessions, social media posts, and other NPC behaviours.
#
# Source: https://github.com/cmu-sei/GHOSTS.git  (Ghosts.Client.Universal)
# =============================================================================

# ---- Defaults ---------------------------------------------------------------
GHOSTS_API_URL=""
SOCIALIZER_URL=""
CLIENT_DIR="/opt/ghosts-client"
CONTENT_DIR="/opt/ghosts/content/social"
GHOSTS_REPO="https://github.com/cmu-sei/GHOSTS.git"
GHOSTS_BRANCH="master"
DOTNET_CHANNEL="9.0"

# ---- Usage -------------------------------------------------------------------
usage() {
    cat <<USAGE
Usage: $(basename "$0") --api-url <URL> [--socializer-url <URL>]

Required:
  --api-url          GHOSTS API server URL (e.g., http://192.168.92.184:5000)

Optional:
  --socializer-url   Socializer/Pandora URL (default: derived from api-url on port 8000)
  -h, --help         Show this help message

Example:
  sudo $(basename "$0") --api-url http://192.168.92.184:5000
  sudo $(basename "$0") --api-url http://192.168.92.184:5000 --socializer-url http://192.168.92.184:8000
USAGE
    exit 1
}

# ---- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --api-url)
            GHOSTS_API_URL="$2"; shift 2 ;;
        --socializer-url)
            SOCIALIZER_URL="$2"; shift 2 ;;
        -h|--help)
            usage ;;
        *)
            echo "ERROR: Unknown option: $1"
            usage ;;
    esac
done

if [[ -z "$GHOSTS_API_URL" ]]; then
    echo "ERROR: --api-url is required."
    usage
fi

# Strip trailing slash
GHOSTS_API_URL="${GHOSTS_API_URL%/}"

# Derive socializer URL from api-url host if not provided
if [[ -z "$SOCIALIZER_URL" ]]; then
    API_HOST=$(echo "$GHOSTS_API_URL" | sed -E 's|https?://([^:/]+).*|\1|')
    SOCIALIZER_URL="http://${API_HOST}:8000"
fi
SOCIALIZER_URL="${SOCIALIZER_URL%/}"

# ---- Root check --------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (use sudo)."
    exit 1
fi

echo "============================================"
echo "  GHOSTS NPC Client Installer"
echo "  Ubuntu 24.04"
echo "============================================"
echo ""
echo "  API Server : $GHOSTS_API_URL"
echo "  Socializer : $SOCIALIZER_URL"
echo "  Install to : $CLIENT_DIR"
echo ""

# ---- Helper: fail with message -----------------------------------------------
fail() {
    echo "FATAL: $1" >&2
    exit 1
}

# =============================================================================
# 1. System packages
# =============================================================================
echo "[1/7] Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq curl jq unzip git ca-certificates gnupg wget

# =============================================================================
# 2. .NET 9 Runtime
# =============================================================================
echo "[2/7] Installing .NET ${DOTNET_CHANNEL} SDK and runtime..."
if command -v dotnet &>/dev/null && dotnet --list-runtimes 2>/dev/null | grep -q "Microsoft.NETCore.App ${DOTNET_CHANNEL}"; then
    echo "  -> .NET ${DOTNET_CHANNEL} runtime already present."
else
    # Microsoft package feed for Ubuntu 24.04
    wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    rm -f /tmp/packages-microsoft-prod.deb

    apt-get update -qq
    apt-get install -y -qq dotnet-sdk-9.0

    dotnet --version || fail ".NET SDK installation failed."
    echo "  -> .NET $(dotnet --version) installed."
fi

# =============================================================================
# 3. Firefox + Geckodriver (browser automation)
# =============================================================================
echo "[3/7] Installing Firefox and Geckodriver..."

# Firefox
if command -v firefox &>/dev/null; then
    echo "  -> Firefox already installed: $(firefox --version 2>/dev/null || echo 'unknown')"
else
    apt-get install -y -qq firefox
    echo "  -> Firefox installed."
fi

# Geckodriver
if command -v geckodriver &>/dev/null; then
    echo "  -> Geckodriver already installed: $(geckodriver --version 2>/dev/null | head -1)"
else
    echo "  -> Installing Geckodriver..."
    GECKO_VERSION=$(curl -fsSL https://api.github.com/repos/mozilla/geckodriver/releases/latest | jq -r '.tag_name')
    if [[ -z "$GECKO_VERSION" || "$GECKO_VERSION" == "null" ]]; then
        # Fallback version
        GECKO_VERSION="v0.35.0"
        echo "  -> Could not fetch latest version, using fallback: $GECKO_VERSION"
    fi
    ARCH=$(dpkg --print-architecture)
    case "$ARCH" in
        amd64) GECKO_ARCH="linux64" ;;
        arm64) GECKO_ARCH="linux-aarch64" ;;
        *)     fail "Unsupported architecture for Geckodriver: $ARCH" ;;
    esac
    curl -fsSL "https://github.com/mozilla/geckodriver/releases/download/${GECKO_VERSION}/geckodriver-${GECKO_VERSION}-${GECKO_ARCH}.tar.gz" \
        -o /tmp/geckodriver.tar.gz
    tar -xzf /tmp/geckodriver.tar.gz -C /usr/local/bin/
    chmod +x /usr/local/bin/geckodriver
    rm -f /tmp/geckodriver.tar.gz
    echo "  -> Geckodriver ${GECKO_VERSION} installed."
fi

# =============================================================================
# 4. Clone GHOSTS and build the Universal client
# =============================================================================
echo "[4/7] Building GHOSTS Universal client..."

BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "  -> Cloning GHOSTS repository (branch: ${GHOSTS_BRANCH})..."
git clone --depth 1 --branch "$GHOSTS_BRANCH" "$GHOSTS_REPO" "$BUILD_DIR/GHOSTS"

CLIENT_SRC="$BUILD_DIR/GHOSTS/src/Ghosts.Client.Universal"
if [[ ! -d "$CLIENT_SRC" ]]; then
    # Fallback: search for the project file
    CLIENT_SRC=$(find "$BUILD_DIR/GHOSTS" -type d -name "Ghosts.Client.Universal" | head -1)
    [[ -z "$CLIENT_SRC" ]] && fail "Could not locate Ghosts.Client.Universal in the repository."
fi

echo "  -> Publishing release build to ${CLIENT_DIR}..."
mkdir -p "$CLIENT_DIR"
dotnet publish "$CLIENT_SRC" -c Release -o "$CLIENT_DIR" || fail "dotnet publish failed."

echo "  -> Build complete. Client installed to ${CLIENT_DIR}."

# =============================================================================
# 5. Client configuration
# =============================================================================
echo "[5/7] Writing client configuration..."

CONFIG_DIR="${CLIENT_DIR}/config"
mkdir -p "$CONFIG_DIR"

# ---- application.json --------------------------------------------------------
cat > "${CONFIG_DIR}/application.json" <<APPJSON
{
  "IdEnabled": true,
  "IdFormat": "machinename",
  "ApiRootUrl": "${GHOSTS_API_URL}/api",
  "Sockets": {
    "IsEnabled": true,
    "Heartbeat": 50000
  },
  "ClientUpdates": {
    "IsEnabled": true,
    "CycleSleep": 300000
  },
  "ClientResults": {
    "IsEnabled": true,
    "CycleSleep": 300000
  },
  "Survey": {
    "IsEnabled": true,
    "Frequency": "once"
  },
  "HealthIsEnabled": true,
  "HandleCount": 10,
  "Listener": {
    "IsEnabled": false,
    "Port": 5001
  },
  "Content": {
    "ContentDirectory": "/opt/ghosts/content",
    "SocialDirectory": "${CONTENT_DIR}"
  },
  "ResourceControl": {
    "ManageProcesses": false
  }
}
APPJSON

echo "  -> ${CONFIG_DIR}/application.json written."

# ---- timeline.json -----------------------------------------------------------
# If the build shipped a default timeline, keep it; otherwise create a minimal one.
if [[ -f "${CONFIG_DIR}/timeline.json" ]]; then
    echo "  -> Default timeline.json already present from build."
else
    cat > "${CONFIG_DIR}/timeline.json" <<'TIMELINE'
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "BrowserFirefox",
      "Initial": "about:blank",
      "UtcTimeOn": "00:00:00",
      "UtcTimeOff": "23:59:59",
      "Loop": true,
      "TimeLineEvents": [
        {
          "Command": "browse",
          "CommandArgs": [
            "https://example.com"
          ],
          "DelayAfter": 30000,
          "DelayBefore": 0
        }
      ]
    }
  ]
}
TIMELINE
    echo "  -> Minimal timeline.json created (edit to add real behaviours)."
fi

# =============================================================================
# 6. Social content directory
# =============================================================================
echo "[6/7] Setting up social content directory..."

mkdir -p "$CONTENT_DIR"
mkdir -p /opt/ghosts/content/docs
mkdir -p /opt/ghosts/content/email

# Create a placeholder README inside the content dir
cat > "${CONTENT_DIR}/README.txt" <<'SOCIAL'
Place social content files here for Socializer/Pandora posts.

Supported file types:
  - *.txt   (one post per line, or free-form text)
  - *.json  (structured post arrays)

Copy content from the GHOSTS server:
  scp user@ghosts-server:/path/to/content/* /opt/ghosts/content/social/

The client will read files from this directory when executing
Social timeline handlers.
SOCIAL

echo "  -> Content directories created under /opt/ghosts/content/"

# =============================================================================
# 7. Systemd service
# =============================================================================
echo "[7/7] Creating systemd service..."

cat > /etc/systemd/system/ghosts-client.service <<SERVICE
[Unit]
Description=GHOSTS NPC Client (Universal)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${CLIENT_DIR}
ExecStart=/usr/bin/dotnet ${CLIENT_DIR}/ghosts.client.universal.dll
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ghosts-client
Environment=DOTNET_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable ghosts-client.service
systemctl start ghosts-client.service

echo "  -> ghosts-client.service enabled and started."

# Brief pause for the service to initialise
sleep 3

# =============================================================================
# Verification
# =============================================================================
echo ""
echo "============================================"
echo "  Verification"
echo "============================================"

# Service status
SERVICE_STATUS="UNKNOWN"
if systemctl is-active --quiet ghosts-client.service; then
    SERVICE_STATUS="RUNNING"
    echo "  Client service  : RUNNING"
else
    SERVICE_STATUS="NOT RUNNING"
    echo "  Client service  : NOT RUNNING (check: journalctl -u ghosts-client -n 50)"
fi

# API connectivity
API_STATUS="UNKNOWN"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${GHOSTS_API_URL}/api/home" 2>/dev/null || true)
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
    API_STATUS="CONNECTED (HTTP ${HTTP_CODE})"
    echo "  API connection  : CONNECTED (HTTP ${HTTP_CODE})"
elif [[ -n "$HTTP_CODE" && "$HTTP_CODE" != "000" ]]; then
    API_STATUS="REACHABLE (HTTP ${HTTP_CODE})"
    echo "  API connection  : REACHABLE but unexpected response (HTTP ${HTTP_CODE})"
else
    API_STATUS="UNREACHABLE"
    echo "  API connection  : UNREACHABLE — verify the server is running at ${GHOSTS_API_URL}"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "============================================"
echo "  GHOSTS Client Installation Complete"
echo "============================================"
echo ""
echo "  Install path    : ${CLIENT_DIR}"
echo "  Config path     : ${CONFIG_DIR}"
echo "  Content path    : /opt/ghosts/content/"
echo "  API URL         : ${GHOSTS_API_URL}"
echo "  Socializer URL  : ${SOCIALIZER_URL}"
echo "  Service status  : ${SERVICE_STATUS}"
echo "  API status      : ${API_STATUS}"
echo ""
echo "--- Managing the client ---"
echo ""
echo "  View logs        : journalctl -u ghosts-client -f"
echo "  Restart client   : systemctl restart ghosts-client"
echo "  Stop client      : systemctl stop ghosts-client"
echo ""
echo "--- Deploying Timelines ---"
echo ""
echo "  1. Edit the local timeline:"
echo "       nano ${CONFIG_DIR}/timeline.json"
echo "     Then restart: systemctl restart ghosts-client"
echo ""
echo "  2. Push a timeline from the API server:"
echo "       curl -X POST ${GHOSTS_API_URL}/api/machines/<MACHINE_ID>/timelines \\"
echo "            -H 'Content-Type: application/json' \\"
echo "            -d @my-timeline.json"
echo ""
echo "--- Social Content ---"
echo ""
echo "  Copy content files to this machine:"
echo "    scp user@ghosts-server:/path/to/content/* ${CONTENT_DIR}/"
echo ""
echo "  The client reads from ${CONTENT_DIR}/ during Social timeline events."
echo ""
echo "============================================"
