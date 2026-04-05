# GHOSTS NPC Framework — Local Setup (Air-Gapped Ready)

Ubuntu 24.04 VM에서 [GHOSTS NPC Framework](https://github.com/cmu-sei/GHOSTS)를 소스에서 빌드하여 구축하는 설치 스크립트입니다.
**인터넷 환경에서 설치/테스트 후, VM을 폐쇄망에 반입하여 운영**하는 것을 전제로 설계되었습니다.

## 용도

- **사이버 훈련**: NPC가 실제 컴퓨터에서 웹 브라우징, 문서 작업, SSH 등을 자동 수행
- **유저 시뮬레이션**: 현실적인 네트워크 트래픽 및 사용자 활동 생성
- **인지전 연구**: 소셜미디어 시뮬레이션(Socializer) + NPC 신념 상태 모델링

## Architecture

```
+──────────────────────────────────────────────────────+
│  Ubuntu 24.04 VM  (CPU-only, 32GB RAM)              │
│                                                      │
│  +----------+     +─────────────────────────────+    │
│  │  Ollama  │◄────│  Docker Compose Stack       │    │
│  │ qwen3.5  │     │                             │    │
│  │  :9b     │     │  ghosts-api      (:5000)    │    │
│  │ llama3.2 │     │  ghosts-frontend (:4200)    │    │
│  │  :3b     │     │  ghosts-pandora  (:8000)    │    │
│  +----------+     │  ghosts-postgres (:5432)    │    │
│                   │  ghosts-n8n      (:5678)    │    │
│                   │  ghosts-grafana  (:3000)    │    │
│                   +─────────────────────────────+    │
│                                                      │
│  NPC 클라이언트 (별도 VM) ──────► API(:5000) 연결     │
+──────────────────────────────────────────────────────+
```

## Requirements

| 항목 | 최소 | 권장 |
|------|------|------|
| OS | Ubuntu 22.04 | Ubuntu 24.04 |
| RAM | 16GB | 32GB+ |
| Disk | 40GB | 80GB+ |
| CPU | 4코어 | 8코어+ |
| Network | 설치 시 인터넷 필요 | 운영 시 불필요 |

## Quick Start

```bash
# 인터넷 되는 환경에서 (VM 안에서)
chmod +x install-ghosts.sh
./install-ghosts.sh
```

설치 완료 후 접속:

| 서비스 | URL | 용도 |
|--------|-----|------|
| Frontend | `http://<VM_IP>:4200` | 운영자 웹 관리 UI |
| API | `http://<VM_IP>:5000` | NPC 클라이언트 연결 |
| Socializer | `http://<VM_IP>:8000` | 소셜미디어 시뮬레이션 (Facebook 테마) |
| n8n | `http://<VM_IP>:5678` | 워크플로우 자동화 |
| Grafana | `http://<VM_IP>:3000` | 대시보드 |

## Air-Gapped Deployment

### 1. 설치 및 테스트 (인터넷 환경)

```bash
./install-ghosts.sh

# 브라우저에서 확인
# http://<VM_IP>:4200  — Frontend
# http://<VM_IP>:8000  — Socializer (Facebook 스타일 소셜미디어)
```

### 2. VM 종료 및 이미지 반출

```bash
cd ~/ghosts && docker compose down
sudo systemctl stop ollama
sudo shutdown -h now
```

VM 이미지(.ova, .vmdk, .qcow2 등)를 반출 매체에 복사.

### 3. 폐쇄망에서 VM 가져오기

```bash
# VM 부팅 후 IP 변경 시:
NEW_IP=$(hostname -I | awk '{print $1}')
cd ~/ghosts
sed -i "s/OLD_IP/${NEW_IP}/g" docker-compose.yml
sed -i "s/OLD_IP/${NEW_IP}/g" timelines/*.json

# 서비스 시작
sudo systemctl start ollama
docker compose up -d
```

## Project Layout

```
~/ghosts/
├── GHOSTS/                     ← 소스코드 (git clone)
├── docker-compose.yml          ← 통합 Docker Compose
├── config/
│   └── init-pandora-db.sql     ← Pandora DB 초기화
├── content/social/             ← 소셜미디어 샘플 콘텐츠
│   ├── politics/               ← 정치/정책 (한국어)
│   ├── tech/                   ← 기술/사이버보안 (한/영)
│   ├── military/               ← 군사/안보 (한국어)
│   ├── daily/                  ← 일상 (한국어)
│   └── news/                   ← 시사/뉴스 (한국어)
└── timelines/                  ← 샘플 NPC 타임라인
    ├── web-browsing.json       ← 웹 브라우징
    ├── social-posting.json     ← 소셜미디어 활동
    ├── document-work.json      ← 문서 작성
    ├── ssh-activity.json       ← SSH 접속
    └── workday-combined.json   ← 복합 근무일 패턴
```

## NPC 클라이언트 설정

별도 VM에 GHOSTS 클라이언트를 설치한 후, `application.json`에서 API 서버 주소를 설정합니다:

```json
{
  "ApiRootUrl": "http://<GHOSTS_SERVER_IP>:5000/api",
  "Sockets": {
    "IsEnabled": true,
    "Heartbeat": 50000
  },
  "ClientUpdates": {
    "IsEnabled": true,
    "CycleSleep": 300000
  }
}
```

소셜 콘텐츠를 사용하려면 클라이언트 VM에 `content/social/` 디렉토리를 복사하고 Timeline의 `social-content-directory`를 해당 경로로 설정합니다.

## n8n 워크플로우 설정

설치 후 n8n에 사전 제공된 워크플로우를 임포트합니다:

1. `http://<VM_IP>:5678` 접속
2. Workflows > Import from file
3. `~/ghosts/GHOSTS/configuration/n8n-workflows/` 에서 선택:
   - `GHOSTS Post to Social Media.json` — AI 소셜 포스트 자동 생성
   - `GHOSTS Social Graph.json` — NPC 간 소셜 그래프 시뮬레이션
   - `GHOSTS Belief.json` — NPC 신념 상태 베이지안 업데이트
   - `GHOSTS Connections.json` — NPC 연결 관리
   - `GHOSTS Preferences.json` — NPC 선호도 관리

워크플로우 내 URL을 내부 IP로 수정한 뒤 활성화합니다.

## Ollama 모델

| 모델 | 용도 | 크기 |
|------|------|------|
| `qwen3.5:9b` | 소셜 포스트/채팅/자율행동 생성 (한국어+영어) | ~5.5GB |
| `llama3.2:3b` | Pandora 콘텐츠 생성 | ~2GB |
| `social` (alias) | API SocialSharing용 (qwen3.5:9b 기반) | alias |
| `chat` (alias) | API Chat용 (qwen3.5:9b 기반) | alias |
| `activity` (alias) | API FullAutonomy용 (qwen3.5:9b 기반) | alias |

## Default Credentials

| 서비스 | 사용자 | 비밀번호 |
|--------|--------|----------|
| GHOSTS API | scotty@cert.org | Password@1 |
| PostgreSQL | ghosts | scotty@1 |

## Useful Commands

```bash
cd ~/ghosts

# 서비스 상태
docker compose ps

# 로그 (실시간)
docker compose logs -f
docker compose logs -f ghosts-api        # API만
docker compose logs -f ghosts-pandora    # Socializer만

# 전체 중지/시작
docker compose down
docker compose up -d

# 소스 업데이트 (인터넷 환경에서)
cd ~/ghosts/GHOSTS && git pull origin master && cd ..
docker compose build && docker compose up -d

# Ollama
ollama list
sudo systemctl status ollama

# Socializer 테스트 포스트 생성
curl -X POST http://localhost:8000/api/admin/generate/10
```

## Troubleshooting

### API가 시작되지 않는 경우

```bash
docker compose logs ghosts-api
# PostgreSQL 연결 확인
docker compose exec ghosts-postgres pg_isready -U ghosts
```

### Pandora/Socializer 접속 안 되는 경우

```bash
docker compose logs ghosts-pandora
# DB 확인
docker compose exec ghosts-postgres psql -U ghosts -d pandora -c "SELECT 1"
```

### Ollama 연결 문제

```bash
sudo systemctl status ollama
curl http://localhost:11434/api/tags
# Docker에서 호스트 접근 확인
docker run --rm --add-host=host.docker.internal:host-gateway \
  curlimages/curl curl -s http://host.docker.internal:11434/api/tags
```

### 폐쇄망 반입 후 IP 변경

```bash
NEW_IP=$(hostname -I | awk '{print $1}')
cd ~/ghosts
sed -i "s/OLD_IP/${NEW_IP}/g" docker-compose.yml
sed -i "s/OLD_IP/${NEW_IP}/g" timelines/*.json
docker compose down && docker compose up -d
```

## License

이 설치 스크립트는 MIT License.
GHOSTS 자체는 [CMU SEI GHOSTS](https://github.com/cmu-sei/GHOSTS) 참조 (MIT License).
