#!/bin/bash
set -euo pipefail

# =============================================================================
# GHOSTS NPC Framework — All-in-One Install Script for Ubuntu 24.04
# Designed for: install online → test → move VM to air-gapped network
#
# Components:
#   - GHOSTS API (C2 server, .NET 10)
#   - GHOSTS Frontend (Angular, nginx)
#   - GHOSTS Pandora/Socializer (social media simulation)
#   - PostgreSQL 16.8
#   - n8n (workflow automation)
#   - Grafana (dashboards)
#   - Ollama (local LLM for content generation)
#
# Source: https://github.com/cmu-sei/GHOSTS.git
# =============================================================================

GHOSTS_DIR="$HOME/ghosts"
GHOSTS_REPO="https://github.com/cmu-sei/GHOSTS.git"
GHOSTS_BRANCH="master"

# LLM Models
MODEL_PRIMARY="qwen3.5:9b"        # Social/Chat/Activity content generation (Korean+English)
MODEL_PANDORA="llama3.2:3b"       # Pandora lightweight content generation

# Ports
PORT_API=5000
PORT_FRONTEND=4200
PORT_PANDORA=8000
PORT_POSTGRES=5432
PORT_N8N=5678
PORT_GRAFANA=3000

echo "============================================"
echo "  GHOSTS NPC Framework Installer"
echo "  Ubuntu 24.04 — Air-gapped Ready"
echo "  Primary Model: $MODEL_PRIMARY"
echo "============================================"
echo ""

# Helper: use sudo for docker if current user is not in docker group yet
DOCKER_CMD="docker"
COMPOSE_CMD="docker compose"
_maybe_sudo_docker() {
    if ! docker info &>/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
        COMPOSE_CMD="sudo docker compose"
    fi
}

# -----------------------------------------------------------------------------
# 1. System packages
# -----------------------------------------------------------------------------
echo "[1/15] Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    curl wget git unzip ca-certificates gnupg lsb-release openssl jq

# -----------------------------------------------------------------------------
# 2. Docker
# -----------------------------------------------------------------------------
if command -v docker &>/dev/null; then
    echo "[2/15] Docker already installed: $(docker --version)"
else
    echo "[2/15] Installing Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker "$USER"
    echo "  -> Docker installed. Group change applied (re-login may be needed)."
fi

sudo systemctl enable docker
sudo systemctl start docker

# Detect whether we need sudo for docker commands
_maybe_sudo_docker

# -----------------------------------------------------------------------------
# 3. Ollama
# -----------------------------------------------------------------------------
if command -v ollama &>/dev/null; then
    echo "[3/15] Ollama already installed: $(ollama --version)"
else
    echo "[3/15] Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

if ! systemctl is-active --quiet ollama 2>/dev/null; then
    echo "  -> Starting Ollama service..."
    sudo systemctl enable ollama
    sudo systemctl start ollama
    sleep 3
fi

# Ensure Ollama listens on all interfaces (needed for Docker containers)
if ! grep -q "OLLAMA_HOST=0.0.0.0" /etc/systemd/system/ollama.service.d/override.conf 2>/dev/null; then
    echo "  -> Configuring Ollama to listen on all interfaces..."
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<OLLAMAEOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
OLLAMAEOF
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    sleep 3
fi

echo "  -> Pulling primary model: $MODEL_PRIMARY (this may take a while)..."
ollama pull "$MODEL_PRIMARY"

echo "  -> Pulling Pandora model: $MODEL_PANDORA..."
ollama pull "$MODEL_PANDORA"

# Model aliases removed — using single qwen3.5:9b with per-request system prompts
# (CPU-only environment cannot handle model swapping)
echo "  -> Ollama models ready (${MODEL_PRIMARY} + ${MODEL_PANDORA})."

# -----------------------------------------------------------------------------
# 4. Clone GHOSTS source
# -----------------------------------------------------------------------------
echo "[4/15] Cloning GHOSTS source..."
mkdir -p "$GHOSTS_DIR"
cd "$GHOSTS_DIR"

if [ -d "GHOSTS/.git" ]; then
    echo "  -> GHOSTS repo already exists, pulling latest..."
    cd GHOSTS && git pull origin "$GHOSTS_BRANCH" && cd ..
else
    git clone --branch "$GHOSTS_BRANCH" "$GHOSTS_REPO"
fi

# -----------------------------------------------------------------------------
# 5. Create unified docker-compose.yml
# -----------------------------------------------------------------------------
echo "[5/15] Creating unified docker-compose configuration..."

HOST_IP=$(hostname -I | awk '{print $1}')

cat > "$GHOSTS_DIR/docker-compose.yml" << COMPOSEOF
services:
  # === PostgreSQL ===
  ghosts-postgres:
    image: postgres:16.8
    container_name: ghosts-postgres
    environment:
      POSTGRES_DB: ghosts
      POSTGRES_USER: ghosts
      POSTGRES_PASSWORD: "scotty@1"
    volumes:
      - ghosts-postgres-data:/var/lib/postgresql/data
      - ./config/init-pandora-db.sql:/docker-entrypoint-initdb.d/init-pandora-db.sql:ro
    logging:
      options:
        max-size: "100m"
        max-file: "5"
    ports:
      - "${PORT_POSTGRES}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ghosts"]
      interval: 10s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  # === GHOSTS API (C2 Server) ===
  ghosts-api:
    build:
      context: ./GHOSTS/src
      dockerfile: Dockerfile-api
    container_name: ghosts-api
    depends_on:
      ghosts-postgres:
        condition: service_healthy
    ports:
      - "${PORT_API}:5000"
    environment:
      ConnectionStrings__DefaultConnection: "Host=ghosts-postgres;Port=5432;Database=ghosts;User Id=ghosts;Password=scotty@1;"
      N8N_API_URL: "http://ghosts-n8n:5678/api/v1/workflows"
      N8N_API_KEY: "replace-me"
      # CORS: allow all origins (credentials disabled to avoid AllowAnyOrigin conflict)
      CorsPolicy__AllowAnyOrigin: "true"
      CorsPolicy__SupportsCredentials: "false"
      # AnimatorSettings overrides for air-gapped Ollama
      AnimatorSettings__Animations__SocialSharing__PostUrl: "http://ghosts-pandora:5000"
      AnimatorSettings__Animations__SocialSharing__ContentEngine__Host: "http://host.docker.internal:11434"
      AnimatorSettings__Animations__Chat__ContentEngine__Host: "http://host.docker.internal:11434"
      AnimatorSettings__Animations__FullAutonomy__ContentEngine__Host: "http://host.docker.internal:11434"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

  # === GHOSTS Frontend (Angular Web UI) ===
  ghosts-frontend:
    build:
      context: ./GHOSTS/src/Ghosts.Frontend
      dockerfile: Dockerfile
    container_name: ghosts-frontend
    ports:
      - "${PORT_FRONTEND}:80"
    environment:
      API_URL: "http://${HOST_IP}:${PORT_API}/api"
      N8N_API_URL: "http://${HOST_IP}:${PORT_N8N}"
    restart: unless-stopped

  # === GHOSTS Pandora / Socializer ===
  ghosts-pandora:
    build:
      context: ./GHOSTS/src/Ghosts.Pandora/src
      dockerfile: Dockerfile
    container_name: ghosts-pandora
    depends_on:
      ghosts-postgres:
        condition: service_healthy
    ports:
      - "${PORT_PANDORA}:5000"
    environment:
      MODE_TYPE: "social"
      DEFAULT_THEME: "x"
      DATABASE_PROVIDER: "PostgreSQL"
      CONNECTION_STRING: "Host=ghosts-postgres;Port=5432;Database=pandora;Username=ghosts;Password=scotty@1"
      GHOSTS_API_URL: "http://ghosts-api:5000/api"
    volumes:
      - ./config/pandora-appsettings.json:/app/appsettings.json:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

  # === n8n (Workflow Automation) ===
  ghosts-n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: ghosts-n8n
    ports:
      - "${PORT_N8N}:5678"
    environment:
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
      - N8N_SECURE_COOKIE=false
    volumes:
      - ghosts-n8n-data:/home/node/.n8n
    restart: unless-stopped

  # === Grafana (Dashboards) ===
  ghosts-grafana:
    image: grafana/grafana
    container_name: ghosts-grafana
    depends_on:
      ghosts-postgres:
        condition: service_healthy
    user: root
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
      - GF_AUTH_DISABLE_LOGIN_FORM=true
      - "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/provisioning/dashboards/GHOSTS-default Grafana dashboard.json"
    ports:
      - "${PORT_GRAFANA}:3000"
    restart: unless-stopped
    volumes:
      - ghosts-grafana-data:/var/lib/grafana
      - ./GHOSTS/configuration/grafana/datasources:/etc/grafana/provisioning/datasources
      - ./GHOSTS/configuration/grafana/dashboards:/etc/grafana/provisioning/dashboards

volumes:
  ghosts-postgres-data:
  ghosts-n8n-data:
  ghosts-grafana-data:
COMPOSEOF

# -----------------------------------------------------------------------------
# 6. Create configuration files
# -----------------------------------------------------------------------------
echo "[6/15] Creating configuration files..."

mkdir -p "$GHOSTS_DIR/config"
mkdir -p "$GHOSTS_DIR/content/social"
mkdir -p "$GHOSTS_DIR/timelines"

# Pandora appsettings.json (mounted into container)
cat > "$GHOSTS_DIR/config/pandora-appsettings.json" << 'PANDORAEOF'
{
  "Logging": {
    "LogLevel": {
      "Microsoft.AspNetCore": "Warning",
      "Default": "Information",
      "Microsoft": "Warning",
      "System": "Warning",
      "Microsoft.EntityFrameworkCore.Database.Command": "Error"
    }
  },
  "AllowedHosts": "*",
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=db/pandora.db",
    "PostgreSQL": "Host=ghosts-postgres;Port=5432;Database=pandora;Username=ghosts;Password=scotty@1"
  },
  "Database": {
    "Provider": "PostgreSQL"
  },
  "ApplicationConfiguration": {
    "Ghosts": {
      "ApiUrl": "http://ghosts-api:5000/api",
      "WorkflowsUrl": "http://ghosts-n8n:5678"
    },
    "Mode": {
      "Type": "social",
      "DefaultTheme": "x",
      "SiteType": "news",
      "SiteName": "Daily Chronicle",
      "ArticleCount": 12
    },
    "DefaultDisplay": 35,
    "MinutesToCheckForDuplicatePost": 2,
    "CleanupDiskUtilThreshold": 70,
    "CleanupJob": { "Hours": 0, "Minutes": 15, "Seconds": 0 },
    "CleanupAge": { "Days": 0, "Hours": 60, "Minutes": 0 },
    "Payloads": {
      "Enabled": true,
      "PayloadDirectory": "Payloads",
      "Mappings": [
        { "Url": "/downloads/document", "FileName": "sample.pdf", "ContentType": "application/pdf" }
      ]
    },
    "Pandora": {
      "Enabled": true,
      "StoreResults": true,
      "ContentCacheDirectory": "_data",
      "OllamaEnabled": true,
      "OllamaApiUrl": "http://host.docker.internal:11434/api/generate",
      "OllamaTimeout": 120,
      "OllamaModels": {
        "Html": "llama3.2:3b",
        "Image": "llama3.2:3b",
        "Json": "llama3.2:3b",
        "Ppt": "llama3.2:3b",
        "Script": "llama3.2:3b",
        "Stylesheet": "llama3.2:3b",
        "Text": "llama3.2:3b",
        "Voice": "llama3.2:3b",
        "Xlsx": "llama3.2:3b",
        "Pdf": "llama3.2:3b",
        "Csv": "llama3.2:3b"
      },
      "ImageGeneration": { "Enabled": false, "Model": "stabilityai/sdxl-turbo" },
      "VideoGeneration": { "Enabled": false },
      "VoiceGeneration": { "Enabled": false }
    }
  }
}
PANDORAEOF

# Pandora DB init script (create separate database for Pandora)
cat > "$GHOSTS_DIR/config/init-pandora-db.sql" << 'SQLEOF'
-- Create Pandora database on the same PostgreSQL instance
SELECT 'CREATE DATABASE pandora OWNER ghosts'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pandora')\gexec
SQLEOF

# --- Sample Social Content ---
echo "  -> Creating sample social content..."

# Topic: politics (한국어)
mkdir -p "$GHOSTS_DIR/content/social/politics/001"
cat > "$GHOSTS_DIR/content/social/politics/001/post.txt" << 'EOF'
이번 선거에서 사이버 보안 정책이 가장 중요한 이슈가 될 것 같다. 디지털 시대에 국가 안보는 곧 사이버 안보. 여러분은 어떻게 생각하시나요?
EOF

mkdir -p "$GHOSTS_DIR/content/social/politics/002"
cat > "$GHOSTS_DIR/content/social/politics/002/post.txt" << 'EOF'
정부의 새로운 AI 규제안이 발표됐는데, 보안 연구자들 입장에서는 좀 더 유연한 접근이 필요하다고 봅니다. 기술 발전과 안전 사이의 균형이 핵심.
EOF

mkdir -p "$GHOSTS_DIR/content/social/politics/003"
cat > "$GHOSTS_DIR/content/social/politics/003/post.txt" << 'EOF'
국방부 사이버사령부 인력 확충 계획이 발표됐네요. 민간 전문가 영입도 포함된다고. 좋은 방향이라고 생각합니다.
EOF

# Topic: tech (한국어/영어 혼합)
mkdir -p "$GHOSTS_DIR/content/social/tech/001"
cat > "$GHOSTS_DIR/content/social/tech/001/post.txt" << 'EOF'
오늘 새로운 LLM 모델 테스트해봤는데 성능이 놀랍다. 로컬에서 돌려도 충분히 쓸만한 수준. AI 발전 속도가 정말 빠르다 🚀
EOF

mkdir -p "$GHOSTS_DIR/content/social/tech/002"
cat > "$GHOSTS_DIR/content/social/tech/002/post.txt" << 'EOF'
Just finished setting up a zero-trust network architecture for our lab. The learning curve is steep but worth it. #cybersecurity #zerotrust
EOF

mkdir -p "$GHOSTS_DIR/content/social/tech/003"
cat > "$GHOSTS_DIR/content/social/tech/003/post.txt" << 'EOF'
클라우드 보안 컨퍼런스 다녀왔는데, 요즘 트렌드는 확실히 SASE랑 SSE. 제로트러스트가 대세가 된 건 맞는 것 같다.
EOF

# Topic: military (한국어)
mkdir -p "$GHOSTS_DIR/content/social/military/001"
cat > "$GHOSTS_DIR/content/social/military/001/post.txt" << 'EOF'
합동 사이버 훈련이 다음 주에 시작된다고 합니다. 올해는 AI 기반 공격 시나리오도 포함된다니 기대됩니다.
EOF

mkdir -p "$GHOSTS_DIR/content/social/military/002"
cat > "$GHOSTS_DIR/content/social/military/002/post.txt" << 'EOF'
사이버전의 핵심은 결국 사람이다. 기술도 중요하지만 훈련된 인력이 있어야 진정한 방어가 가능하다.
EOF

mkdir -p "$GHOSTS_DIR/content/social/military/003"
cat > "$GHOSTS_DIR/content/social/military/003/post.txt" << 'EOF'
최근 APT 그룹의 공격 패턴이 변화하고 있다는 분석 보고서가 나왔네요. 위협 인텔리전스 공유가 그 어느 때보다 중요해지고 있습니다.
EOF

# Topic: daily (일상)
mkdir -p "$GHOSTS_DIR/content/social/daily/001"
cat > "$GHOSTS_DIR/content/social/daily/001/post.txt" << 'EOF'
오늘 점심은 부대찌개. 역시 추운 날엔 따뜻한 국물이 최고다 🍲
EOF

mkdir -p "$GHOSTS_DIR/content/social/daily/002"
cat > "$GHOSTS_DIR/content/social/daily/002/post.txt" << 'EOF'
주말에 한강 러닝 다녀왔는데 날씨가 완벽했다. 10km 완주! 다음 목표는 하프마라톤 💪
EOF

mkdir -p "$GHOSTS_DIR/content/social/daily/003"
cat > "$GHOSTS_DIR/content/social/daily/003/post.txt" << 'EOF'
새로 나온 넷플릭스 다큐 시리즈 보는 중. 사이버 범죄 관련인데 꽤 잘 만들었다. 추천!
EOF

# Topic: news (시사/뉴스)
mkdir -p "$GHOSTS_DIR/content/social/news/001"
cat > "$GHOSTS_DIR/content/social/news/001/post.txt" << 'EOF'
글로벌 랜섬웨어 공격이 올해 들어 30% 증가했다는 통계가 나왔다. 기업들의 보안 투자가 더 늘어야 할 때.
EOF

mkdir -p "$GHOSTS_DIR/content/social/news/002"
cat > "$GHOSTS_DIR/content/social/news/002/post.txt" << 'EOF'
국내 IT 기업들이 오픈소스 보안 도구 개발에 적극 참여하기 시작했다는 소식. 좋은 흐름이다.
EOF

mkdir -p "$GHOSTS_DIR/content/social/news/003"
cat > "$GHOSTS_DIR/content/social/news/003/post.txt" << 'EOF'
유럽 사이버보안청에서 새로운 IoT 보안 가이드라인을 발표했습니다. 국내에도 비슷한 기준이 필요하다고 봅니다.
EOF

# --- Sample Timelines ---
echo "  -> Creating sample timelines..."

# Timeline 1: Web browsing (Pandora + internal sites)
cat > "$GHOSTS_DIR/timelines/web-browsing.json" << TIMELINEOF
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "BrowserFirefox",
      "Initial": "about:blank",
      "UtcTimeOn": "08:00:00",
      "UtcTimeOff": "18:00:00",
      "Loop": true,
      "HandlerArgs": {
        "isheadless": "false",
        "stickiness": "60",
        "stickiness-depth-min": "2",
        "stickiness-depth-max": "10",
        "visited-remember": "10",
        "actions-before-restart": 50,
        "delay-jitter": "0.3",
        "command-line-args": ["--ignore-certificate-errors"]
      },
      "TimeLineEvents": [
        {
          "Command": "random",
          "CommandArgs": [
            "http://${HOST_IP}:${PORT_PANDORA}",
            "http://${HOST_IP}:${PORT_PANDORA}/posts",
            "http://${HOST_IP}:${PORT_PANDORA}/search?q=cyber",
            "http://${HOST_IP}:${PORT_PANDORA}/search?q=security",
            "http://${HOST_IP}:${PORT_FRONTEND}"
          ],
          "DelayAfter": {
            "random": true,
            "min": 10000,
            "max": 120000
          },
          "DelayBefore": 3000
        }
      ]
    }
  ]
}
TIMELINEOF

# Timeline 2: Social media posting on Socializer
cat > "$GHOSTS_DIR/timelines/social-posting.json" << TIMELINEOF
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "BrowserFirefox",
      "Initial": "about:blank",
      "UtcTimeOn": "09:00:00",
      "UtcTimeOff": "21:00:00",
      "Loop": true,
      "HandlerArgs": {
        "isheadless": "false",
        "stickiness": "40",
        "stickiness-depth-min": "1",
        "stickiness-depth-max": "5",
        "delay-jitter": "0.3",
        "command-line-args": ["--ignore-certificate-errors"],
        "social-version": "1.0",
        "social-content-directory": "/opt/ghosts/content/social",
        "social-topiclist": "politics,tech,military,daily,news",
        "social-post-probability": "40",
        "social-like-probability": "30",
        "social-browse-probability": "30",
        "social-addimage-probability": "10",
        "social-use-unique-user": "true"
      },
      "TimeLineEvents": [
        {
          "Command": "social",
          "CommandArgs": [
            "site:http://${HOST_IP}:${PORT_PANDORA}"
          ],
          "DelayAfter": {
            "random": true,
            "min": 30000,
            "max": 180000
          },
          "DelayBefore": 5000
        }
      ]
    }
  ]
}
TIMELINEOF

# Timeline 3: Document creation (LightWord + LightExcel)
cat > "$GHOSTS_DIR/timelines/document-work.json" << 'TIMELINEOF'
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "LightWord",
      "Initial": "",
      "UtcTimeOn": "09:00:00",
      "UtcTimeOff": "17:00:00",
      "Loop": true,
      "TimeLineEvents": [
        {
          "Command": "create",
          "CommandArgs": [
            {
              "PathWin": "%USERPROFILE%\\Documents\\Reports",
              "PathLinux": "/tmp/ghosts/documents/reports",
              "OutputFormat": "pdf"
            }
          ],
          "DelayAfter": {
            "random": true,
            "min": 300000,
            "max": 900000
          },
          "DelayBefore": 5000
        }
      ]
    },
    {
      "HandlerType": "LightExcel",
      "Initial": "",
      "UtcTimeOn": "10:00:00",
      "UtcTimeOff": "16:00:00",
      "Loop": true,
      "TimeLineEvents": [
        {
          "Command": "create",
          "CommandArgs": [
            {
              "PathWin": "%USERPROFILE%\\Documents\\Spreadsheets",
              "PathLinux": "/tmp/ghosts/documents/spreadsheets"
            }
          ],
          "DelayAfter": {
            "random": true,
            "min": 600000,
            "max": 1800000
          },
          "DelayBefore": 3000
        }
      ]
    }
  ]
}
TIMELINEOF

# Timeline 4: SSH activity
cat > "$GHOSTS_DIR/timelines/ssh-activity.json" << 'TIMELINEOF'
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "Ssh",
      "Initial": "",
      "UtcTimeOn": "08:00:00",
      "UtcTimeOff": "20:00:00",
      "Loop": true,
      "TimeLineEvents": [
        {
          "Command": "ssh",
          "CommandArgs": [
            {
              "HostIp": "TARGET_SSH_HOST",
              "Username": "admin",
              "Password": "changeme",
              "Port": 22,
              "Commands": [
                "uptime",
                "df -h",
                "free -m",
                "ps aux --sort=-%mem | head -10",
                "cat /var/log/syslog | tail -20"
              ]
            }
          ],
          "DelayAfter": {
            "random": true,
            "min": 600000,
            "max": 3600000
          },
          "DelayBefore": 2000
        }
      ]
    }
  ]
}
TIMELINEOF

# Timeline 5: Combined realistic workday (browsing + social + docs)
cat > "$GHOSTS_DIR/timelines/workday-combined.json" << TIMELINEOF
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "BrowserFirefox",
      "Initial": "about:blank",
      "UtcTimeOn": "09:00:00",
      "UtcTimeOff": "12:00:00",
      "Loop": true,
      "HandlerArgs": {
        "isheadless": "false",
        "stickiness": "50",
        "stickiness-depth-min": "2",
        "stickiness-depth-max": "8",
        "visited-remember": "15",
        "delay-jitter": "0.3",
        "command-line-args": ["--ignore-certificate-errors"]
      },
      "TimeLineEvents": [
        {
          "Command": "random",
          "CommandArgs": [
            "http://${HOST_IP}:${PORT_PANDORA}",
            "http://${HOST_IP}:${PORT_PANDORA}/posts",
            "http://${HOST_IP}:${PORT_PANDORA}/search?q=news"
          ],
          "DelayAfter": {
            "random": true,
            "min": 15000,
            "max": 90000
          }
        }
      ]
    },
    {
      "HandlerType": "BrowserFirefox",
      "Initial": "about:blank",
      "UtcTimeOn": "12:00:00",
      "UtcTimeOff": "13:00:00",
      "Loop": true,
      "HandlerArgs": {
        "isheadless": "false",
        "delay-jitter": "0.4",
        "command-line-args": ["--ignore-certificate-errors"],
        "social-version": "1.0",
        "social-content-directory": "/opt/ghosts/content/social",
        "social-topiclist": "daily,news",
        "social-post-probability": "50",
        "social-like-probability": "30",
        "social-browse-probability": "20",
        "social-addimage-probability": "5",
        "social-use-unique-user": "true"
      },
      "TimeLineEvents": [
        {
          "Command": "social",
          "CommandArgs": [
            "site:http://${HOST_IP}:${PORT_PANDORA}"
          ],
          "DelayAfter": {
            "random": true,
            "min": 30000,
            "max": 120000
          }
        }
      ]
    },
    {
      "HandlerType": "LightWord",
      "Initial": "",
      "UtcTimeOn": "14:00:00",
      "UtcTimeOff": "17:00:00",
      "Loop": true,
      "TimeLineEvents": [
        {
          "Command": "create",
          "CommandArgs": [
            {
              "PathWin": "%USERPROFILE%\\Documents",
              "PathLinux": "/tmp/ghosts/documents",
              "OutputFormat": "pdf"
            }
          ],
          "DelayAfter": {
            "random": true,
            "min": 600000,
            "max": 1200000
          }
        }
      ]
    }
  ]
}
TIMELINEOF

# -----------------------------------------------------------------------------
# 7. Build Docker images from source
# -----------------------------------------------------------------------------
echo "[7/15] Building Docker images from source (this may take several minutes)..."
cd "$GHOSTS_DIR"

# Pull base images (runtime + build SDKs for air-gapped rebuild)
echo "  -> Pulling base images..."
$DOCKER_CMD pull postgres:16.8
$DOCKER_CMD pull docker.n8n.io/n8nio/n8n:latest
$DOCKER_CMD pull grafana/grafana

echo "  -> Pulling build SDK images (for air-gapped source rebuild)..."
$DOCKER_CMD pull mcr.microsoft.com/dotnet/sdk:10.0
$DOCKER_CMD pull mcr.microsoft.com/dotnet/aspnet:10.0
$DOCKER_CMD pull node:22-alpine
$DOCKER_CMD pull nginx:alpine

# Patch Frontend Dockerfile: fix Angular peer dependency conflict
FRONTEND_DOCKERFILE="$GHOSTS_DIR/GHOSTS/src/Ghosts.Frontend/Dockerfile"
echo "  -> Patching Frontend Dockerfile (npm peer dependency fix)..."
# Replace any "RUN npm ci" that doesn't already have --legacy-peer-deps
if grep -q 'npm ci' "$FRONTEND_DOCKERFILE" 2>/dev/null; then
    sed -i 's|RUN npm ci\b.*|RUN npm ci --legacy-peer-deps|' "$FRONTEND_DOCKERFILE"
    echo "  -> Patched: $(grep 'npm ci' "$FRONTEND_DOCKERFILE")"
fi

# Patch GHOSTS API: influence tier system
if [ -f "$GHOSTS_DIR/config-repo/ghosts-config/scripts/patch-influence-tier.sh" ]; then
    echo "  -> Applying influence tier patch..."
    bash "$GHOSTS_DIR/config-repo/ghosts-config/scripts/patch-influence-tier.sh" "$GHOSTS_DIR/GHOSTS/src"
elif [ -f "$GHOSTS_DIR/GHOSTS/src/Ghosts.Api/Infrastructure/Animations/AnimationDefinitions/SocialGraphJob.cs.bak" ]; then
    echo "  -> Influence tier patch already applied."
fi

# Build GHOSTS images from source
echo "  -> Building GHOSTS API..."
$COMPOSE_CMD build ghosts-api

echo "  -> Building GHOSTS Frontend (no-cache due to Dockerfile patch)..."
$COMPOSE_CMD build --no-cache ghosts-frontend

echo "  -> Building GHOSTS Pandora/Socializer..."
$COMPOSE_CMD build ghosts-pandora

# -----------------------------------------------------------------------------
# 8. Start services
# -----------------------------------------------------------------------------
echo "[8/15] Starting all services..."
$COMPOSE_CMD up -d

echo "  -> Waiting for services to initialize..."
sleep 15

# Health checks
echo "  -> Checking service status..."
$COMPOSE_CMD ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || $COMPOSE_CMD ps

echo ""
echo "  -> Testing API connectivity..."
for i in $(seq 1 12); do
    if curl -sf "http://localhost:${PORT_API}/api/home" > /dev/null 2>&1; then
        echo "  -> GHOSTS API: OK"
        break
    fi
    if [ "$i" -eq 12 ]; then
        echo "  -> GHOSTS API: Not responding yet (may still be starting)"
    fi
    sleep 5
done

echo "  -> Testing Pandora/Socializer..."
for i in $(seq 1 12); do
    if curl -sf "http://localhost:${PORT_PANDORA}" > /dev/null 2>&1; then
        echo "  -> Pandora/Socializer: OK"
        break
    fi
    if [ "$i" -eq 12 ]; then
        echo "  -> Pandora/Socializer: Not responding yet (may still be starting)"
    fi
    sleep 5
done

# Seed some initial social posts
echo "  -> Seeding initial social media posts..."
sleep 3
curl -sf -X POST "http://localhost:${PORT_PANDORA}/api/admin/generate/10" > /dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# 9. Clone config repo and setup Ollama role-specific models
# -----------------------------------------------------------------------------
echo "[9/15] Setting up cognitive warfare configuration..."
cd "$GHOSTS_DIR"

if [ -d "config-repo/.git" ]; then
    echo "  -> Config repo already exists, pulling latest..."
    cd config-repo && git pull && cd ..
else
    echo "  -> Cloning config repo..."
    git clone https://github.com/VictoryBird/ghosts-local-setup.git config-repo
fi

# Ollama model aliases are no longer used (CPU-only environment cannot swap models)
# Instead, qwen3.5:9b is used directly with system prompts passed per request
echo "  -> Using single model (${MODEL_PRIMARY}) with per-request system prompts."

# -----------------------------------------------------------------------------
# 10. Generate 130 NPCs
# -----------------------------------------------------------------------------
echo "[10/15] Generating 130 NPCs..."

# Check if NPCs already exist
NPC_COUNT=$(curl -sf "http://localhost:${PORT_API}/api/npcs/list" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [ "$NPC_COUNT" -ge 120 ]; then
    echo "  -> ${NPC_COUNT} NPCs already exist, skipping generation."
else
    if [ "$NPC_COUNT" -gt 0 ]; then
        echo "  -> Deleting ${NPC_COUNT} existing NPCs..."
        curl -sf "http://localhost:${PORT_API}/api/npcs/list" 2>/dev/null | \
            python3 -c "import sys,json; [print(n['id']) for n in json.load(sys.stdin)]" 2>/dev/null | \
            while read id; do
                curl -sf -X DELETE "http://localhost:${PORT_API}/api/npcs/$id" > /dev/null 2>&1
            done
    fi

    echo "  -> Running NPC generation script..."
    chmod +x config-repo/ghosts-config/scripts/generate-npcs.sh
    config-repo/ghosts-config/scripts/generate-npcs.sh "http://localhost:${PORT_API}"

    # Update Campaign/Enclave/Team via DB
    echo "  -> Setting Campaign/Enclave/Team for all NPCs..."
    $DOCKER_CMD exec ghosts-postgres psql -U ghosts -d ghosts -c "
    UPDATE npcs SET
      campaign = 'Meridia2026',
      enclave = CASE
        WHEN npcprofile->'attributes'->>'country' = 'valdoria' THEN 'Valdoria'
        WHEN npcprofile->'attributes'->>'country' = 'krasnovia' THEN 'Krasnovia'
        WHEN npcprofile->'attributes'->>'country' = 'tarvek' THEN 'Tarvek'
        WHEN npcprofile->'attributes'->>'country' = 'arventa' THEN 'Arventa'
        ELSE 'Unknown'
      END,
      team = CASE
        WHEN npcprofile->'attributes'->>'role' = 'official' THEN 'Government'
        WHEN npcprofile->'attributes'->>'role' = 'military' THEN 'Military'
        WHEN npcprofile->'attributes'->>'role' = 'citizen' THEN 'Citizen'
        WHEN npcprofile->'attributes'->>'role' = 'media' THEN 'Media'
        WHEN npcprofile->'attributes'->>'role' = 'disguised' THEN 'DisguisedOps'
        WHEN npcprofile->'attributes'->>'role' = 'bot' THEN 'BotNetwork'
        WHEN npcprofile->'attributes'->>'role' = 'gorgon' THEN 'GORGON'
        WHEN npcprofile->'attributes'->>'role' = 'liaison' THEN 'Government'
        ELSE 'Other'
      END;
    " 2>/dev/null && echo "  -> Campaign/Enclave/Team updated." || echo "  -> WARNING: DB update failed."
fi

# -----------------------------------------------------------------------------
# 11. Setup Mastodon (MeridiaNet)
# -----------------------------------------------------------------------------
echo "[11/15] Setting up Mastodon (MeridiaNet)..."

chmod +x config-repo/ghosts-config/scripts/setup-mastodon.sh
config-repo/ghosts-config/scripts/setup-mastodon.sh

# Wait for Mastodon to be healthy
echo "  -> Waiting for Mastodon..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:${PORT_PANDORA}/health > /dev/null 2>&1 || \
       curl -sf http://localhost:${PORT_PANDORA}/ > /dev/null 2>&1; then
        echo "  -> Mastodon is ready!"
        break
    fi
    [ "$i" -eq 30 ] && echo "  -> WARNING: Mastodon may not be fully ready yet."
    sleep 5
done

# -----------------------------------------------------------------------------
# 12. Create Mastodon NPC accounts + tokens
# -----------------------------------------------------------------------------
echo "[12/15] Creating Mastodon NPC accounts..."

chmod +x config-repo/ghosts-config/scripts/setup-mastodon-npcs.sh
config-repo/ghosts-config/scripts/setup-mastodon-npcs.sh

# Update display names for all NPC accounts
echo "  -> Updating NPC display names..."
TOKEN_FILE="config-repo/ghosts-config/mastodon/npc-data/npc_tokens.json"
if [ -f "$TOKEN_FILE" ]; then
    python3 -c "
import json, subprocess
with open('${TOKEN_FILE}') as f:
    data = json.load(f)
for username, info in data.items():
    if isinstance(info, dict) and info.get('token') and info.get('display_name'):
        subprocess.run(['curl', '-s', '-X', 'PATCH',
            'http://localhost:${PORT_PANDORA}/api/v1/accounts/update_credentials',
            '-H', 'Authorization: Bearer ' + info['token'],
            '-d', 'display_name=' + info['display_name']],
            capture_output=True)
" 2>/dev/null && echo "  -> Display names updated." || echo "  -> WARNING: Display name update failed."
fi

# -----------------------------------------------------------------------------
# 13. Apply influence tier patch + rebuild API
# -----------------------------------------------------------------------------
echo "[13/15] Applying influence tier patch..."

chmod +x config-repo/ghosts-config/scripts/patch-influence-tier.sh
config-repo/ghosts-config/scripts/patch-influence-tier.sh "${GHOSTS_DIR}/GHOSTS/src"

echo "  -> Rebuilding GHOSTS API with influence tier support..."
cd "$GHOSTS_DIR"
$COMPOSE_CMD build --no-cache ghosts-api
$COMPOSE_CMD up -d ghosts-api
echo "  -> Waiting for API to restart..."
sleep 10
for i in $(seq 1 30); do
    if curl -sf "http://localhost:${PORT_API}/api/home" > /dev/null 2>&1; then
        echo "  -> API is ready!"
        break
    fi
    sleep 3
done

# -----------------------------------------------------------------------------
# 14. Import n8n workflows
# -----------------------------------------------------------------------------
echo "[14/15] Setting up n8n workflows..."

chmod +x config-repo/ghosts-config/scripts/setup-n8n.sh
echo "  -> n8n workflow auto-import requires an API key."
echo "  -> After install, create one at http://${HOST_IP}:${PORT_N8N}"
echo "  -> Then run: config-repo/ghosts-config/scripts/setup-n8n.sh <API_KEY>"
echo ""
echo "  -> Or import manually from config-repo/ghosts-config/n8n-workflows/"

# -----------------------------------------------------------------------------
# 15. Final summary
# -----------------------------------------------------------------------------
echo "[15/15] Final checks..."
NPC_FINAL=$(curl -sf "http://localhost:${PORT_API}/api/npcs/list" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
echo "  -> NPCs created: ${NPC_FINAL}"

echo ""
echo "============================================"
echo "  GHOSTS Installation Complete!"
echo "============================================"
echo ""
echo "  Services:"
echo "    Frontend (Web UI):   http://${HOST_IP}:${PORT_FRONTEND}"
echo "    API Server:          http://${HOST_IP}:${PORT_API}"
echo "    Socializer:          http://${HOST_IP}:${PORT_PANDORA}"
echo "    n8n Workflows:       http://${HOST_IP}:${PORT_N8N}"
echo "    Grafana Dashboards:  http://${HOST_IP}:${PORT_GRAFANA}"
echo ""
echo "  Default Credentials:"
echo "    API Admin:   scotty@cert.org / Password@1"
echo "    PostgreSQL:  ghosts / scotty@1"
echo ""
echo "  Mastodon (MeridiaNet):"
echo "    URL:         http://${HOST_IP}:${PORT_PANDORA}"
echo "    Admin:       ghostsadmin (see ~/ghosts/mastodon/mastodon-credentials.env)"
echo "    NPC accounts: 130+ with API tokens"
echo ""
echo "  Ollama Models:"
echo "    Primary:     ${MODEL_PRIMARY} (single model + per-request system prompts)"
echo "    Pandora:     ${MODEL_PANDORA}"
echo ""
echo "  Project Layout:"
echo "    ${GHOSTS_DIR}/"
echo "    ├── GHOSTS/              ← Source code (git clone)"
echo "    ├── docker-compose.yml   ← Unified compose"
echo "    ├── config/              ← Configuration overrides"
echo "    ├── content/social/      ← Social media content"
echo "    └── timelines/           ← Sample NPC timelines"
echo ""
echo "  Sample Timelines (deploy to NPC clients):"
echo "    timelines/web-browsing.json      — Web browsing simulation"
echo "    timelines/social-posting.json    — Social media interaction"
echo "    timelines/document-work.json     — Document creation"
echo "    timelines/ssh-activity.json      — SSH activity"
echo "    timelines/workday-combined.json  — Realistic workday pattern"
echo ""
echo "  NPC Configuration:"
echo "    NPCs: ${NPC_FINAL} created (Meridia2026 scenario)"
echo "    Influence tiers: Tier1=Gov/Media, Tier2=Citizens, Tier3=Bots"
echo ""
echo "  n8n Workflow Setup:"
echo "    Auto-import: config-repo/ghosts-config/scripts/setup-n8n.sh <API_KEY>"
echo "    Manual:      Import from config-repo/ghosts-config/n8n-workflows/"
echo "    API key:     Create at http://${HOST_IP}:${PORT_N8N} > Settings > API"
echo ""
echo "  ─── Air-Gapped Deployment ───"
echo ""
echo "  After testing, move VM to air-gapped network:"
echo "    1. Stop services:"
echo "       cd ${GHOSTS_DIR} && docker compose down"
echo "       sudo systemctl stop ollama"
echo "       sudo shutdown -h now"
echo ""
echo "    2. Export VM image and transfer to air-gapped network"
echo ""
echo "    3. After import, update IP if changed:"
echo "       NEW_IP=\$(hostname -I | awk '{print \$1}')"
echo "       cd ${GHOSTS_DIR}"
echo "       sed -i \"s/${HOST_IP}/\${NEW_IP}/g\" docker-compose.yml"
echo "       sed -i \"s/${HOST_IP}/\${NEW_IP}/g\" timelines/*.json"
echo "       sudo systemctl start ollama"
echo "       docker compose up -d"
echo ""
echo "  ─── Useful Commands ───"
echo ""
echo "    cd ${GHOSTS_DIR}"
echo "    docker compose ps              # Service status"
echo "    docker compose logs -f         # Follow all logs"
echo "    docker compose logs ghosts-api # API logs only"
echo "    docker compose down            # Stop all"
echo "    docker compose up -d           # Start all"
echo "    ollama list                    # Check models"
echo ""
echo "============================================"
