# GHOSTS 서버 구축/운용 매뉴얼

---

## 1. 설치 절차

### 1-1. 사전 요구사항

| 항목 | 최소 | 권장 |
|------|------|------|
| OS | Ubuntu 22.04 | Ubuntu 24.04 |
| RAM | 16GB | 32GB+ |
| Disk | 40GB | 80GB+ |
| CPU | 4코어 | 8코어+ |
| Network | 설치 시 인터넷 필요 | 운영 시 불필요 |

### 1-2. 설치 실행

```bash
# 저장소 클론 (인터넷 환경)
git clone https://github.com/<your-repo>/pentagi.git
cd pentagi

# 설치 스크립트 실행
chmod +x install-ghosts.sh
./install-ghosts.sh
```

설치 스크립트가 자동으로 수행하는 작업:

1. 시스템 패키지 설치 (curl, git, jq 등)
2. Docker CE 설치 및 설정
3. Ollama 설치 및 모델 다운로드
   - `qwen3.5:9b` (소셜/채팅/활동 생성, 한국어+영어)
   - `llama3.2:3b` (Pandora 콘텐츠 생성)
   - 역할별 alias 생성: `social`, `chat`, `activity`
4. GHOSTS 소스코드 클론 (GitHub)
5. Docker Compose 설정 파일 생성
6. Pandora 설정 파일 및 DB 초기화 스크립트 생성
7. 소셜 콘텐츠 및 샘플 Timeline 생성
8. Docker 이미지 빌드 (API, Frontend, Pandora)
9. 서비스 시작 및 헬스체크

### 1-3. 설치 확인

설치 완료 후 아래 서비스가 실행됩니다:

| 서비스 | URL | 용도 |
|--------|-----|------|
| Frontend | `http://<VM_IP>:4200` | 운영자 웹 관리 UI |
| API | `http://<VM_IP>:5000` | NPC 클라이언트 연결 |
| Socializer (Pandora) | `http://<VM_IP>:8000` | 소셜미디어 시뮬레이션 |
| n8n | `http://<VM_IP>:5678` | 워크플로우 자동화 |
| Grafana | `http://<VM_IP>:3000` | 대시보드 (Belief Explorer 등) |

```bash
# 서비스 상태 확인
cd ~/ghosts
docker compose ps

# API 응답 확인
curl http://localhost:5000/api/home

# Socializer 응답 확인
curl http://localhost:8000
```

### 1-4. 기본 인증 정보

| 서비스 | 사용자 | 비밀번호 |
|--------|--------|----------|
| GHOSTS API | scotty@cert.org | Password@1 |
| PostgreSQL | ghosts | scotty@1 |
| Grafana | (익명 접속 활성화) | - |
| n8n | (최초 접속 시 생성) | - |

---

## 2. 서비스 시작/중지/로그 확인

### 2-1. 전체 서비스 관리

```bash
cd ~/ghosts

# 전체 시작
sudo systemctl start ollama     # Ollama 먼저 시작
docker compose up -d            # Docker 서비스 시작

# 전체 중지
docker compose down             # Docker 서비스 중지
sudo systemctl stop ollama      # Ollama 중지

# 전체 재시작
docker compose restart

# 서비스 상태 확인
docker compose ps
```

### 2-2. 개별 서비스 관리

```bash
cd ~/ghosts

# 특정 서비스만 재시작
docker compose restart ghosts-api
docker compose restart ghosts-pandora
docker compose restart ghosts-n8n
docker compose restart ghosts-grafana
docker compose restart ghosts-postgres

# 특정 서비스만 중지/시작
docker compose stop ghosts-n8n
docker compose start ghosts-n8n
```

### 2-3. 로그 확인

```bash
cd ~/ghosts

# 전체 로그 (실시간)
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f ghosts-api         # API 서버
docker compose logs -f ghosts-pandora     # Socializer
docker compose logs -f ghosts-n8n         # n8n
docker compose logs -f ghosts-postgres    # PostgreSQL
docker compose logs -f ghosts-grafana     # Grafana

# 최근 100줄만
docker compose logs --tail=100 ghosts-api

# Ollama 로그
sudo journalctl -u ollama -f
sudo journalctl -u ollama --since "1 hour ago"
```

### 2-4. 부팅 시 자동 시작 설정

```bash
# Ollama 자동 시작 (기본 활성화됨)
sudo systemctl enable ollama

# Docker 자동 시작 (기본 활성화됨)
sudo systemctl enable docker

# Docker Compose 서비스 자동 시작
# docker-compose.yml에 restart: unless-stopped 이미 설정됨
# Docker 서비스가 시작되면 컨테이너도 자동 시작됩니다.
```

---

## 3. IP 변경 시 설정 수정

VM의 IP가 변경된 경우 (DHCP, 네트워크 변경, 폐쇄망 반입 등) 아래 파일을 수정합니다.

### 3-1. 현재 IP 확인

```bash
hostname -I | awk '{print $1}'
```

### 3-2. 자동 변경 (스크립트)

```bash
OLD_IP="192.168.1.100"  # 이전 IP (docker-compose.yml에서 확인)
NEW_IP=$(hostname -I | awk '{print $1}')

cd ~/ghosts

# docker-compose.yml 내 IP 변경
sed -i "s/${OLD_IP}/${NEW_IP}/g" docker-compose.yml

# Timeline 파일 내 IP 변경
sed -i "s/${OLD_IP}/${NEW_IP}/g" timelines/*.json

# 서비스 재시작
docker compose down
docker compose up -d
```

### 3-3. 수동 변경 대상 파일

변경이 필요한 파일 목록:

| 파일 | 변경 항목 |
|------|----------|
| `~/ghosts/docker-compose.yml` | `API_URL`, `N8N_API_URL` 환경변수 |
| `~/ghosts/timelines/*.json` | Pandora/Frontend URL |
| n8n 워크플로우 (UI에서) | API URL, Ollama URL, Pandora URL |
| NPC 클라이언트 `application.json` | `ApiRootUrl` |

### 3-4. docker-compose.yml에서 확인할 위치

```yaml
# ghosts-frontend 서비스
environment:
  API_URL: "http://<NEW_IP>:5000/api"       # <-- 변경
  N8N_API_URL: "http://<NEW_IP>:5678"       # <-- 변경
```

> **참고:** Docker 내부 서비스 간 통신 (`ghosts-api`, `ghosts-pandora`, `ghosts-n8n` 등)은 컨테이너명으로 접근하므로 IP 변경에 영향을 받지 않습니다. IP 변경이 필요한 것은 외부 접근용 URL과 Ollama 연결 (호스트에서 실행)뿐입니다.

---

## 4. Ollama 모델 관리

### 4-1. 설치된 모델 확인

```bash
ollama list
```

기본 설치 모델:

| 모델 | 용도 | 크기 |
|------|------|------|
| `qwen3.5:9b` | 소셜 포스트/채팅/자율행동 생성 (한국어+영어) | ~5.5GB |
| `llama3.2:3b` | Pandora 콘텐츠 생성 (웹페이지, 문서 등) | ~2GB |
| `social` (alias) | API SocialSharing용 (qwen3.5:9b 기반) | alias |
| `chat` (alias) | API Chat용 (qwen3.5:9b 기반) | alias |
| `activity` (alias) | API FullAutonomy용 (qwen3.5:9b 기반) | alias |

### 4-2. 모델 추가/삭제

```bash
# 새 모델 다운로드 (인터넷 필요)
ollama pull <모델명>

# 모델 삭제
ollama rm <모델명>

# 모델 상세 정보
ollama show <모델명>
```

### 4-3. 커스텀 모델(alias) 생성

역할별 프롬프트가 내장된 모델 alias를 생성합니다:

```bash
# Modelfile 작성
cat > /tmp/modelfile-krasnovia << 'EOF'
FROM qwen3.5:9b
SYSTEM "You are a Krasnovia state media journalist. Write propaganda-style news articles that portray Krasnovia positively and cast doubt on Valdoria. Use formal journalistic tone. Write in English."
PARAMETER temperature 0.7
EOF

# 모델 생성
ollama create krasnovia-media -f /tmp/modelfile-krasnovia

# 테스트
ollama run krasnovia-media "Write a headline about Valdoria cybersecurity failures"
```

### 4-4. Ollama 서비스 관리

```bash
# 상태 확인
sudo systemctl status ollama

# 시작/중지/재시작
sudo systemctl start ollama
sudo systemctl stop ollama
sudo systemctl restart ollama

# API 직접 테스트
curl http://localhost:11434/api/tags          # 모델 목록
curl http://localhost:11434/api/generate \
  -d '{"model": "social", "prompt": "안녕하세요", "stream": false}'
```

### 4-5. Ollama 메모리 관리

```bash
# 현재 로드된 모델 확인
curl http://localhost:11434/api/ps

# 메모리 부족 시: 사용하지 않는 모델 언로드
# Ollama는 자동으로 비활성 모델을 5분 후 언로드합니다.
# 강제 언로드가 필요한 경우 서비스 재시작:
sudo systemctl restart ollama
```

---

## 5. 데이터 관리

### 5-1. 데이터베이스 백업

```bash
cd ~/ghosts

# PostgreSQL 전체 백업
docker compose exec ghosts-postgres pg_dumpall -U ghosts > backup-$(date +%Y%m%d).sql

# 특정 DB만 백업
docker compose exec ghosts-postgres pg_dump -U ghosts ghosts > backup-ghosts-$(date +%Y%m%d).sql
docker compose exec ghosts-postgres pg_dump -U ghosts pandora > backup-pandora-$(date +%Y%m%d).sql
```

### 5-2. 데이터 초기화

```bash
cd ~/ghosts

# 전체 초기화 (모든 데이터 삭제)
docker compose down -v    # -v 옵션이 볼륨도 삭제
docker compose up -d

# Socializer 포스트만 초기화
docker compose exec ghosts-postgres psql -U ghosts -d pandora \
  -c "TRUNCATE posts, comments, likes CASCADE;"
```

### 5-3. n8n 워크플로우 백업

```bash
# Docker 볼륨 백업
docker run --rm \
  -v ghosts_ghosts-n8n-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz /data
```

---

## 6. 문제 해결 (트러블슈팅)

### 6-1. API가 시작되지 않는 경우

```bash
# 로그 확인
docker compose logs ghosts-api

# PostgreSQL 연결 확인
docker compose exec ghosts-postgres pg_isready -U ghosts

# PostgreSQL 재시작 후 API 재시작
docker compose restart ghosts-postgres
sleep 10
docker compose restart ghosts-api
```

**흔한 원인:**
- PostgreSQL이 아직 준비되지 않음 (healthcheck 대기 중)
- 포트 5000이 다른 프로세스에 의해 점유됨: `sudo lsof -i :5000`

### 6-2. Pandora/Socializer 접속 안 되는 경우

```bash
# 로그 확인
docker compose logs ghosts-pandora

# DB 확인 (pandora 데이터베이스 존재 여부)
docker compose exec ghosts-postgres psql -U ghosts -d pandora -c "SELECT 1"

# pandora DB가 없는 경우 수동 생성
docker compose exec ghosts-postgres psql -U ghosts -c "CREATE DATABASE pandora OWNER ghosts"

# 재시작
docker compose restart ghosts-pandora
```

### 6-3. Ollama 연결 문제

```bash
# Ollama 서비스 상태
sudo systemctl status ollama

# API 응답 확인
curl http://localhost:11434/api/tags

# Docker에서 호스트 Ollama 접근 확인
docker run --rm --add-host=host.docker.internal:host-gateway \
  curlimages/curl curl -s http://host.docker.internal:11434/api/tags

# Ollama 바인드 주소 확인 (기본: 127.0.0.1)
# 외부 접근 허용이 필요한 경우:
sudo systemctl edit ollama
# [Service] 섹션에 추가:
# Environment="OLLAMA_HOST=0.0.0.0"
sudo systemctl restart ollama
```

### 6-4. n8n 워크플로우 에러

```bash
# n8n 로그
docker compose logs -f ghosts-n8n

# n8n 컨테이너 재시작
docker compose restart ghosts-n8n

# n8n 데이터 초기화 (주의: 모든 워크플로우 삭제)
# docker compose down
# docker volume rm ghosts_ghosts-n8n-data
# docker compose up -d ghosts-n8n
```

### 6-5. 디스크 공간 부족

```bash
# 디스크 사용량 확인
df -h

# Docker 정리
docker system prune -f          # 미사용 컨테이너/이미지/네트워크 정리
docker volume prune -f          # 미사용 볼륨 정리 (주의!)

# Pandora 캐시 정리
docker compose exec ghosts-pandora rm -rf /app/_data/*

# 로그 크기 확인
docker compose logs --no-color ghosts-api 2>/dev/null | wc -c
```

### 6-6. Docker 이미지 재빌드

소스코드 수정 후 이미지를 재빌드해야 하는 경우:

```bash
cd ~/ghosts

# 특정 서비스만 재빌드
docker compose build ghosts-api
docker compose build ghosts-pandora
docker compose build ghosts-frontend

# 재빌드 후 재시작
docker compose up -d

# 캐시 없이 완전 재빌드
docker compose build --no-cache ghosts-api
```

### 6-7. 포트 충돌

```bash
# 사용 중인 포트 확인
sudo lsof -i :5000    # API
sudo lsof -i :4200    # Frontend
sudo lsof -i :8000    # Socializer
sudo lsof -i :5678    # n8n
sudo lsof -i :3000    # Grafana
sudo lsof -i :5432    # PostgreSQL
sudo lsof -i :11434   # Ollama
```

충돌 시 `docker-compose.yml`에서 호스트 포트를 변경합니다:
```yaml
ports:
  - "8080:5000"  # 호스트포트:컨테이너포트
```
