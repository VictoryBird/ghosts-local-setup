# Locust 더미 트래픽 생성기 매뉴얼

## 개요

Locust를 활용하여 정상 웹 트래픽(GET 요청)을 생성한다.  
방어팀 훈련 시 **80% 정상 로그 + 20% 공격 로그** 비율을 유지하기 위한 정상 트래픽 담당.

- Docker 기반 배포 (의존성 문제 없음)
- 네트워크별 대상 서버 분리
- 소스 IP 다중 설정 지원
- Web UI로 실시간 강도 조절

## 파일 구조

```
ghosts-config/locust/
├── locust-targets.yaml        # 네트워크/대상서버/소스IP 설정
├── locustfile.py              # 트래픽 시나리오 스크립트
├── Dockerfile                 # Locust Docker 이미지
├── docker-compose-locust.yaml # Docker Compose 설정
└── setup-locust.sh            # 설치/실행 스크립트
```

## 1. 사전 준비

Docker가 설치되어 있어야 한다. (install-ghosts.sh에서 이미 설치됨)

```bash
docker --version
docker compose version
```

## 2. 설정 파일 수정

`locust-targets.yaml`을 현장 네트워크 환경에 맞게 수정한다.

```yaml
networks:
  - name: "network-a"          # 네트워크 식별 이름
    targets:                    # 대상 웹서버 URL 목록
      - http://10.0.1.10
      - http://10.0.1.20
      - http://10.0.1.30
    users: 5                    # 동시 가상 유저 수
    spawn_rate: 1               # 초당 유저 생성 속도
    source_ips:                 # 소스 IP 목록
      - 10.0.1.100
      - 10.0.1.101
      - 10.0.1.102

  - name: "network-b"
    targets:
      - http://10.0.2.10
      - http://10.0.2.20
    users: 3
    spawn_rate: 1
    source_ips:
      - 10.0.2.100
      - 10.0.2.101
```

### 설정 항목 설명

| 항목 | 설명 | 예시 |
|------|------|------|
| `name` | 네트워크 식별 이름 | `"network-a"` |
| `targets` | 트래픽을 보낼 웹서버 URL | `http://10.0.1.10` |
| `users` | 동시 가상 유저 수 (트래픽 강도) | `5` |
| `spawn_rate` | 초당 유저 생성 속도 | `1` |
| `source_ips` | 요청 출발 IP (호스트 인터페이스에 할당 필요) | `10.0.1.100` |

### 트래픽 강도 가이드

| users | 예상 RPS | 용도 |
|-------|----------|------|
| 3~5 | 1~3 | 저강도 (서버 부하 최소) |
| 10~20 | 5~15 | 중강도 (일반 업무 트래픽 수준) |
| 50+ | 30+ | 고강도 (피크 트래픽 시뮬레이션) |

> 서버 부하가 우려되면 `users: 3`부터 시작해서 Web UI에서 실시간 조절.

## 3. 소스 IP 설정

소스 IP를 사용하려면 호스트 네트워크 인터페이스에 가상 IP를 추가해야 한다.

```bash
# 자동 설정 (YAML에서 읽어서 할당)
sudo bash setup-locust.sh --setup-ips-only

# 수동 설정
sudo ip addr add 10.0.1.100/24 dev eth0
sudo ip addr add 10.0.1.101/24 dev eth0

# 확인
ip addr show dev eth0

# 제거
sudo bash setup-locust.sh --cleanup-ips
```

> **주의**: 소스 IP는 대상 네트워크까지 라우팅이 가능한 대역이어야 한다.
> 폐쇄망 반입 후 네트워크 대역이 변경되면 YAML 수정 후 재설정.

## 4. 실행

### 기본 실행 (Web UI)

```bash
sudo bash setup-locust.sh
```

브라우저에서 `http://VM_IP:8089` 접속하여 Web UI 사용.

### 특정 네트워크 지정

```bash
sudo bash setup-locust.sh --network network-b
```

### 직접 Docker Compose 실행

```bash
cd ghosts-config/locust

# 기본 (첫 번째 네트워크)
docker compose -f docker-compose-locust.yaml up -d --build

# 특정 네트워크
LOCUST_NETWORK=network-b docker compose -f docker-compose-locust.yaml up -d --build
```

## 5. Web UI 사용법

`http://VM_IP:8089` 접속 후:

1. **Number of users**: 동시 유저 수 입력 (YAML의 users 값)
2. **Ramp up**: 초당 유저 증가 속도
3. **Host**: 비워두면 YAML 설정 사용
4. **Start** 클릭

### 실시간 조절

- 실행 중 **Edit** 버튼으로 유저 수 변경 가능
- **Statistics** 탭에서 RPS, 응답시간, 실패율 확인
- **Charts** 탭에서 시간별 추이 그래프

## 6. 트래픽 패턴

locustfile.py에 정의된 5가지 GET 요청 패턴:

| 패턴 | 비중 | 요청 예시 |
|------|------|-----------|
| 일반 페이지 | 50% | `/`, `/index.html`, `/about`, `/login` |
| 정적 리소스 | 20% | `/css/style.css`, `/js/app.js`, `/images/logo.png` |
| 콘텐츠 페이지 | 15% | `/board/list?page=3`, `/news`, `/notice` |
| API 탐색 | 10% | `/api/status`, `/api/v1/`, `/api/health` |
| 관리 페이지 | 5% | `/admin`, `/wp-admin`, `/dashboard` |

- 각 유저는 랜덤 User-Agent를 가짐 (Chrome, Firefox, Safari 등)
- 요청 간 1~5초 대기 (현실적 브라우징 패턴)
- 대상 서버 목록 중 랜덤 선택

## 7. 중지

```bash
# 스크립트로 중지
sudo bash setup-locust.sh --stop

# 또는 직접
docker compose -f docker-compose-locust.yaml down
```

## 8. 로그 확인

```bash
# 컨테이너 로그
docker logs locust

# 실시간 로그
docker logs -f locust
```

## 9. 폐쇄망 반입 후 재설정

1. `locust-targets.yaml` 수정 (현장 네트워크 대역, 대상 서버)
2. 소스 IP 재설정:
   ```bash
   sudo bash setup-locust.sh --cleanup-ips   # 기존 IP 제거
   sudo bash setup-locust.sh --setup-ips-only # 새 IP 설정
   ```
3. Locust 재시작:
   ```bash
   sudo bash setup-locust.sh --stop
   sudo bash setup-locust.sh
   ```

## 10. 트러블슈팅

### 컨테이너가 시작 안될 때
```bash
docker compose -f docker-compose-locust.yaml logs
```

### 소스 IP에서 요청이 안 나갈 때
```bash
# IP 할당 확인
ip addr show dev eth0

# 라우팅 확인
ip route show

# 대상 서버 연결 테스트
curl --interface 10.0.1.100 http://10.0.1.10/
```

### 대상 서버에 로그가 안 남을 때
- 대상 서버의 웹서버 액세스 로그 경로 확인
- 방화벽 규칙 확인
- `docker logs locust`에서 Connection refused 에러 확인
