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

# -----------------------------------------------------------------------------
# 1. System packages
# -----------------------------------------------------------------------------
echo "[1/8] Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    curl wget git unzip ca-certificates gnupg lsb-release openssl jq

# -----------------------------------------------------------------------------
# 2. Docker
# -----------------------------------------------------------------------------
if command -v docker &>/dev/null; then
    echo "[2/8] Docker already installed: $(docker --version)"
else
    echo "[2/8] Installing Docker..."
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

# -----------------------------------------------------------------------------
# 3. Ollama
# -----------------------------------------------------------------------------
if command -v ollama &>/dev/null; then
    echo "[3/8] Ollama already installed: $(ollama --version)"
else
    echo "[3/8] Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

if ! systemctl is-active --quiet ollama 2>/dev/null; then
    echo "  -> Starting Ollama service..."
    sudo systemctl enable ollama
    sudo systemctl start ollama
    sleep 3
fi

echo "  -> Pulling primary model: $MODEL_PRIMARY (this may take a while)..."
ollama pull "$MODEL_PRIMARY"

echo "  -> Pulling Pandora model: $MODEL_PANDORA..."
ollama pull "$MODEL_PANDORA"

# Create Ollama model aliases for GHOSTS API ContentEngine
echo "  -> Creating Ollama model aliases..."

# "social" model — for social media post generation
ollama create social -f /dev/stdin <<'MODELFILE'
FROM qwen3.5:9b
SYSTEM "You are a social media user. Write short, natural social media posts. Mix Korean and English naturally. Be casual and authentic. Keep posts under 280 characters."
PARAMETER temperature 0.8
MODELFILE

# "chat" model — for NPC chat messages
ollama create chat -f /dev/stdin <<'MODELFILE'
FROM qwen3.5:9b
SYSTEM "You are participating in a casual chat conversation. Respond naturally and briefly in Korean or English depending on context. Keep messages conversational and under 200 characters."
PARAMETER temperature 0.7
MODELFILE

# "activity" model — for FullAutonomy NPC decision-making
ollama create activity -f /dev/stdin <<'MODELFILE'
FROM qwen3.5:9b
SYSTEM "You are an AI deciding what a simulated office worker should do next on their computer. Suggest realistic activities like browsing websites, writing documents, checking email, or chatting with colleagues. Respond with a brief action description."
PARAMETER temperature 0.6
MODELFILE

echo "  -> Ollama models ready."

# -----------------------------------------------------------------------------
# 4. Clone GHOSTS source
# -----------------------------------------------------------------------------
echo "[4/8] Cloning GHOSTS source..."
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
echo "[5/8] Creating unified docker-compose configuration..."

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
      DEFAULT_THEME: "facebook"
      DATABASE_PROVIDER: "PostgreSQL"
      CONNECTION_STRING: "Host=ghosts-postgres;Port=5432;Database=pandora;Username=ghosts;Password=scotty@1"
      GHOSTS_API_URL: "http://ghosts-api:5000/api"
      # Ollama for content generation
      ApplicationConfiguration__Pandora__OllamaEnabled: "true"
      ApplicationConfiguration__Pandora__OllamaApiUrl: "http://host.docker.internal:11434/api/generate"
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
echo "[6/8] Creating configuration files..."

mkdir -p "$GHOSTS_DIR/config"
mkdir -p "$GHOSTS_DIR/content/social"
mkdir -p "$GHOSTS_DIR/timelines"

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
echo "[7/8] Building Docker images from source (this may take several minutes)..."
cd "$GHOSTS_DIR"

# Pull base images first
echo "  -> Pulling base images..."
docker pull postgres:16.8
docker pull docker.n8n.io/n8nio/n8n:latest
docker pull grafana/grafana

# Build GHOSTS images from source
echo "  -> Building GHOSTS API..."
docker compose build ghosts-api

echo "  -> Building GHOSTS Frontend..."
docker compose build ghosts-frontend

echo "  -> Building GHOSTS Pandora/Socializer..."
docker compose build ghosts-pandora

# -----------------------------------------------------------------------------
# 8. Start services
# -----------------------------------------------------------------------------
echo "[8/8] Starting all services..."
docker compose up -d

echo "  -> Waiting for services to initialize..."
sleep 15

# Health checks
echo "  -> Checking service status..."
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || docker compose ps

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
echo "  Ollama Models:"
echo "    Primary:     ${MODEL_PRIMARY} (+ aliases: social, chat, activity)"
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
echo "  n8n Workflow Templates:"
echo "    ${GHOSTS_DIR}/GHOSTS/configuration/n8n-workflows/"
echo "    Import via n8n UI at http://${HOST_IP}:${PORT_N8N}"
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
