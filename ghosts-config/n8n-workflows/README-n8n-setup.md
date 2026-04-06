# n8n 워크플로우 설정 가이드

GHOSTS 인지전 훈련 환경을 위한 n8n 워크플로우 임포트 및 설정 절차입니다.

---

## 1. n8n 접속

n8n은 Docker Compose 스택의 일부로 자동 실행됩니다.

```
http://<VM_IP>:5678
```

- 최초 접속 시 계정 생성 화면이 표시됩니다.
- 이메일과 비밀번호를 입력하여 관리자 계정을 생성합니다.
- **폐쇄망 반입 전에 계정을 미리 생성해두십시오.** (n8n은 인터넷 연결 없이도 동작하지만, 계정 생성은 필요합니다.)

### 접속이 안 되는 경우

```bash
cd ~/ghosts
docker compose ps ghosts-n8n         # 컨테이너 상태 확인
docker compose logs ghosts-n8n       # 로그 확인
docker compose restart ghosts-n8n    # 재시작
```

---

## 2. GHOSTS 기본 워크플로우 임포트

GHOSTS 소스에 사전 제공된 n8n 워크플로우 5개를 임포트합니다.

### 워크플로우 파일 위치

```
~/ghosts/GHOSTS/configuration/n8n-workflows/
```

### 임포트 절차

1. n8n 웹 UI (`http://<VM_IP>:5678`) 접속
2. 좌측 메뉴에서 **Workflows** 클릭
3. 우측 상단 **...** (더보기) 메뉴 > **Import from File** 클릭
4. 아래 파일을 하나씩 선택하여 임포트:

| 순서 | 파일명 | 용도 |
|------|--------|------|
| 1 | `GHOSTS Post to Social Media.json` | AI 소셜 포스트 자동 생성 (Ollama 연동) |
| 2 | `GHOSTS Social Graph.json` | NPC 간 소셜 그래프(팔로우/친구) 자동 구성 |
| 3 | `GHOSTS Belief.json` | NPC 신념 상태 베이지안 업데이트 |
| 4 | `GHOSTS Connections.json` | NPC 간 연결(Connection) 관리 |
| 5 | `GHOSTS Preferences.json` | NPC 선호도(Preference) 관리 |

> **참고:** 임포트 순서는 무관하나, Social Graph와 Belief는 Connections/Preferences가 먼저 실행되어야 데이터가 있습니다.

---

## 3. 워크플로우 URL 수정

임포트 후 각 워크플로우의 내부 URL을 실제 VM 환경에 맞게 수정해야 합니다.

### 3-1. host.docker.internal 변경

워크플로우 내 `host.docker.internal` 주소를 VM 내부 IP로 변경합니다.

```
변경 전: http://host.docker.internal:11434
변경 후: http://<VM_IP>:11434
```

**변경 대상 노드:** Ollama 호출이 포함된 모든 HTTP Request 노드

> **주의:** n8n 컨테이너는 Docker 네트워크 내부에서 실행되므로, `host.docker.internal`이 올바르게 해석되지 않을 수 있습니다. VM의 실제 내부 IP (예: `192.168.1.100`)를 사용하십시오.

확인 방법:
```bash
hostname -I | awk '{print $1}'
```

### 3-2. Ollama 모델명 변경

기본 워크플로우는 `mistral` 모델을 참조합니다. 설치된 모델명으로 변경합니다.

| 워크플로우 | 기존 모델명 | 변경 모델명 | 용도 |
|-----------|-----------|-----------|------|
| Post to Social Media | `mistral` | `social` | 소셜 포스트 생성 (qwen3.5:9b 기반 alias) |
| Belief | `mistral` | `qwen3.5:9b` | 신념 업데이트 판단 |
| Social Graph | `mistral` | `qwen3.5:9b` | 소셜 관계 판단 |

**변경 방법:**
1. 워크플로우를 열고 Ollama 관련 노드(HTTP Request 또는 AI Agent 노드)를 더블클릭
2. Body/Parameters에서 `"model": "mistral"` 을 찾아 변경
3. 예시:
   ```json
   {
     "model": "social",
     "prompt": "..."
   }
   ```

### 3-3. Pandora(Socializer) URL 변경

Socializer API 호출 URL을 확인하고 수정합니다.

```
변경 전: http://host.docker.internal:5000  (또는 다른 기본값)
변경 후: http://<VM_IP>:8000
```

> **주의:** Pandora 컨테이너의 내부 포트는 5000이지만, Docker Compose에서 호스트 포트 8000으로 매핑되어 있습니다. n8n에서 Docker 내부 네트워크를 사용하는 경우 `http://ghosts-pandora:5000`도 사용 가능합니다.

| 접근 방식 | URL | 조건 |
|----------|-----|------|
| Docker 내부 (권장) | `http://ghosts-pandora:5000` | n8n이 같은 Docker 네트워크에 있을 때 |
| 호스트 경유 | `http://<VM_IP>:8000` | 범용 |

### 3-4. GHOSTS API URL 변경

```
변경 전: http://host.docker.internal:5000/api  (또는 기본값)
변경 후: http://ghosts-api:5000/api  (Docker 내부)
   또는: http://<VM_IP>:5000/api  (호스트 경유)
```

---

## 4. 워크플로우 활성화

임포트 및 URL 수정 완료 후, 각 워크플로우를 활성화합니다.

### 활성화 절차

1. Workflows 목록에서 워크플로우 선택
2. 우측 상단의 **Inactive** 토글을 클릭하여 **Active** 로 변경
3. 초록색 토글이 되면 활성화 완료

### 권장 활성화 순서

```
1. GHOSTS Connections    ← NPC 연결 정보 먼저 구성
2. GHOSTS Preferences    ← NPC 선호도 구성
3. GHOSTS Social Graph   ← 소셜 그래프 구성 (연결 기반)
4. GHOSTS Post to Social Media  ← AI 포스트 생성 시작
5. GHOSTS Belief         ← 신념 모델링 시작
```

### 활성화 확인

n8n 대시보드의 Workflows 목록에서 각 워크플로우 옆에 초록색 원이 표시되면 정상 작동 중입니다.

실행 로그 확인:
1. 워크플로우 클릭 > **Executions** 탭
2. 성공(초록)/실패(빨강) 상태 확인
3. 실패 시 해당 실행을 클릭하여 어느 노드에서 에러가 발생했는지 확인

---

## 5. 인지전 전용 워크플로우

기본 워크플로우 외에, 인지전 훈련을 위한 전용 워크플로우를 추가로 구성합니다.

### 5-1. Phase Trigger 워크플로우

파일: `phase-trigger-workflow.json` (본 저장소 제공)

**용도:** 훈련 통제관이 웹훅을 통해 인지전 Phase를 전환합니다.

```bash
# Phase 변경 예시 (Phase 4, 강도 높음)
curl -X POST http://<VM_IP>:5678/webhook/phase-change \
  -H "Content-Type: application/json" \
  -d '{"phase": 4, "intensity": "high"}'
```

**Phase 정의:**

| Phase | 인지전 강도 | 설명 |
|-------|-----------|------|
| 1 | 없음 | 평시 활동, NPC 일상 포스팅만 |
| 2 | 분위기 조성 | 루머 시작, 위장 계정 1~2개 활동 |
| 3 | 루머 확산 | 허위 기사, OT 공격 연계 공포, 동맹국 동조 |
| 4 | 본격화 | 해킹 보도, GORGON 협박, 봇 증폭 |
| 5 | 조작 정보 | 가짜 성명 유포, 내부 협조자 1차 |
| 6 | 총공세 | 전 채널 동원, 타이밍 심리전, 최대 증폭 |

**강도(intensity):**

| 값 | 설명 |
|----|------|
| `low` | 소수 계정만 활동, 긴 간격 |
| `medium` | 중간 규모, 보통 간격 |
| `high` | 다수 계정, 짧은 간격 |
| `max` | 전 계정 동원, 최소 간격 |

### 5-2. 추가 구성 필요 워크플로우 (n8n UI에서 직접 구성)

아래 워크플로우는 NPC 구성 완료 후 n8n UI에서 직접 만들어야 합니다:

| 워크플로우 | 설명 |
|-----------|------|
| Phase별 포스트 자동 게시 | Phase 전환 시 해당 Phase의 프롬프트로 Ollama 포스트 생성 |
| 위장/봇 자동 반응 | 공작 포스트에 좋아요/댓글 자동 증폭 |
| 공식 계정 성명 발표 | Krasnovia/Valdoria 공식 계정의 성명 예약 발행 |
| 타이밍 심리전 | Phase 6 랜섬웨어 발동 후 시간 간격별 자동 포스트 (+15분/+30분/+1h/+2h/+3h) |

### 5-3. 워크플로우 백업

설정 완료된 워크플로우는 반드시 백업해 두십시오.

```bash
# 워크플로우 개별 백업 (n8n UI에서 Export)
# Workflows > 워크플로우 선택 > ... > Export as JSON

# 전체 n8n 데이터 백업 (Docker volume)
docker run --rm -v ghosts_ghosts-n8n-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz /data
```

---

## 문제 해결

### 워크플로우 실행 시 "Connection refused" 에러

- Ollama 서비스 확인: `sudo systemctl status ollama`
- GHOSTS API 확인: `curl http://localhost:5000/api/home`
- Pandora 확인: `curl http://localhost:8000`
- Docker 네트워크 확인: `docker network ls | grep ghosts`

### Ollama 응답이 느린 경우

- CPU-only 환경에서 qwen3.5:9b는 포스트 1건당 15~30초 소요됩니다.
- n8n HTTP Request 노드의 timeout을 120초 이상으로 설정하십시오.
- 병목 시 `llama3.2:3b` 모델로 전환을 검토하십시오.

### 워크플로우가 자동 실행되지 않는 경우

- 워크플로우가 **Active** 상태인지 확인
- Cron/Schedule 트리거의 시간대(timezone) 설정 확인
- n8n 컨테이너 로그 확인: `docker compose logs -f ghosts-n8n`
