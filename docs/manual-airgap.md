# 폐쇄망 반입 절차 매뉴얼

GHOSTS 인지전 훈련 환경을 인터넷이 차단된 폐쇄망(air-gapped network)에 반입하여 운영하는 절차입니다.

---

## 1. 반입 전 체크리스트

인터넷 환경에서 아래 항목을 모두 준비/확인한 후 VM을 내보냅니다.

### 1-1. Docker 이미지 확인

```bash
docker images | grep -E "ghosts|postgres|n8n|grafana"
```

필수 이미지 목록:

| 이미지 | 용도 | 확인 명령 |
|--------|------|----------|
| `ghosts-ghosts-api` | GHOSTS API 서버 | `docker images \| grep ghosts-api` |
| `ghosts-ghosts-frontend` | Frontend 웹 UI | `docker images \| grep frontend` |
| `ghosts-ghosts-pandora` | Socializer | `docker images \| grep pandora` |
| `postgres:16.8` | PostgreSQL DB | `docker images \| grep postgres` |
| `docker.n8n.io/n8nio/n8n` | n8n 워크플로우 | `docker images \| grep n8n` |
| `grafana/grafana` | Grafana 대시보드 | `docker images \| grep grafana` |

### 1-2. 빌드 SDK 이미지 확인 (소스 재빌드용)

폐쇄망에서 소스코드 수정 후 이미지 재빌드가 필요한 경우를 대비하여 SDK 이미지도 보존합니다:

```bash
docker images | grep -E "dotnet|node|nginx"
```

| 이미지 | 용도 |
|--------|------|
| `mcr.microsoft.com/dotnet/sdk:10.0` | API/Pandora 빌드 |
| `mcr.microsoft.com/dotnet/aspnet:10.0` | API/Pandora 런타임 |
| `node:22-alpine` | Frontend 빌드 |
| `nginx:alpine` | Frontend 런타임 |

> **주의:** 이 이미지들이 없으면 폐쇄망에서 `docker compose build`를 실행할 수 없습니다. install-ghosts.sh가 설치 시 자동으로 pull합니다.

### 1-3. Ollama 모델 확인

```bash
ollama list
```

필수 모델:

| 모델 | 크기 | 확인 |
|------|------|------|
| `qwen3.5:9b` | ~5.5GB | `ollama show qwen3.5:9b` |
| `llama3.2:3b` | ~2GB | `ollama show llama3.2:3b` |
| `social` (alias) | - | `ollama show social` |
| `chat` (alias) | - | `ollama show chat` |
| `activity` (alias) | - | `ollama show activity` |

커스텀 모델 alias가 추가로 있다면 함께 확인:
```bash
ollama list | grep -v "NAME"
```

### 1-4. 소스코드 및 설정 파일

```bash
ls ~/ghosts/
```

| 항목 | 경로 | 확인 |
|------|------|------|
| GHOSTS 소스 | `~/ghosts/GHOSTS/` | `.git` 디렉토리 존재 |
| Docker Compose | `~/ghosts/docker-compose.yml` | 파일 존재 |
| 설정 파일 | `~/ghosts/config/` | `pandora-appsettings.json`, `init-pandora-db.sql` |
| 소셜 콘텐츠 | `~/ghosts/content/social/` | 토픽별 디렉토리 |
| Timeline 샘플 | `~/ghosts/timelines/` | JSON 파일들 |

### 1-5. 서비스 동작 확인

반입 전 모든 서비스가 정상 동작하는지 확인합니다:

```bash
cd ~/ghosts

# Docker 서비스 상태
docker compose ps

# 각 서비스 응답 확인
curl -s http://localhost:5000/api/home > /dev/null && echo "API: OK" || echo "API: FAIL"
curl -s http://localhost:8000 > /dev/null && echo "Socializer: OK" || echo "Socializer: FAIL"
curl -s http://localhost:5678 > /dev/null && echo "n8n: OK" || echo "n8n: FAIL"
curl -s http://localhost:3000 > /dev/null && echo "Grafana: OK" || echo "Grafana: FAIL"

# Ollama 응답 확인
curl -s http://localhost:11434/api/tags > /dev/null && echo "Ollama: OK" || echo "Ollama: FAIL"

# DB 확인
docker compose exec ghosts-postgres pg_isready -U ghosts && echo "PostgreSQL: OK"
```

### 1-6. n8n 워크플로우 확인

```bash
# n8n에 로그인하여 워크플로우가 임포트되어 있는지 확인
# http://localhost:5678
# 워크플로우 목록 > 모두 Active 상태인지 확인
```

### 1-7. 반입 전 최종 체크리스트

```
[ ] Docker 이미지 6종 존재 확인
[ ] SDK/빌드 이미지 4종 존재 확인
[ ] Ollama 모델 2종 + alias 3종 존재 확인
[ ] 소스코드 및 설정 파일 존재 확인
[ ] 모든 서비스 (API, Socializer, n8n, Grafana, PostgreSQL, Ollama) 정상 동작 확인
[ ] n8n 워크플로우 임포트 및 활성화 확인
[ ] 소셜 콘텐츠 및 Timeline 샘플 존재 확인
[ ] NPC 데이터 생성 완료 확인 (필요 시)
[ ] Socializer 테마 설정 확인 (twitter 권장)
[ ] VM 디스크 여유 공간 10GB 이상 확인
```

---

## 2. VM 종료 및 내보내기

### 2-1. 서비스 정상 종료

```bash
cd ~/ghosts

# Docker 서비스 종료
docker compose down

# Ollama 종료
sudo systemctl stop ollama

# VM 종료
sudo shutdown -h now
```

> **주의:** `docker compose down`은 컨테이너를 삭제하지만 볼륨(데이터)은 보존됩니다. `docker compose down -v`는 볼륨까지 삭제하므로 사용하지 마십시오.

### 2-2. VM 이미지 내보내기

#### VirtualBox

```bash
# VM 목록 확인
VBoxManage list vms

# OVA 형식으로 내보내기
VBoxManage export "GHOSTS-VM" -o GHOSTS-VM.ova
```

#### VMware

```bash
# OVF 형식으로 내보내기
ovftool /path/to/vmx "GHOSTS-VM.ova"
```

#### KVM/QEMU

```bash
# qcow2 이미지 복사
cp /var/lib/libvirt/images/ghosts-vm.qcow2 /export/path/

# XML 설정도 백업
virsh dumpxml ghosts-vm > ghosts-vm.xml
```

### 2-3. 반출 매체에 복사

VM 이미지를 반출 매체(외장 HDD, USB 등)에 복사합니다.

예상 크기:
| 항목 | 크기 |
|------|------|
| VM 디스크 이미지 | 20~40GB |
| Docker 이미지 (내부) | ~10GB |
| Ollama 모델 (내부) | ~8GB |
| **합계** | **20~40GB** (VM 이미지에 포함) |

---

## 3. 반입 후 IP 변경 및 재시작

### 3-1. VM 가져오기 및 부팅

반입 매체에서 VM 이미지를 가져와 부팅합니다.

#### VirtualBox
```bash
VBoxManage import GHOSTS-VM.ova
VBoxManage startvm "GHOSTS-VM"
```

#### VMware
VMware UI에서 OVA 파일을 가져옵니다.

#### KVM/QEMU
```bash
cp /import/path/ghosts-vm.qcow2 /var/lib/libvirt/images/
virsh define ghosts-vm.xml
virsh start ghosts-vm
```

### 3-2. 네트워크 설정

VM의 네트워크 어댑터를 폐쇄망의 네트워크에 연결합니다.

```bash
# IP 확인
ip addr show
hostname -I

# 필요 시 정적 IP 설정 (Ubuntu 24.04 netplan)
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens33:      # 인터페이스 이름 확인 (ip addr)
      addresses:
        - 10.0.0.100/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        addresses: []     # 폐쇄망에서는 DNS 불필요
```

```bash
sudo netplan apply
```

### 3-3. IP 변경 적용

```bash
# 이전 IP 확인 (docker-compose.yml에서)
OLD_IP=$(grep -oP 'http://\K[0-9.]+(?=:5000/api)' ~/ghosts/docker-compose.yml | head -1)
echo "이전 IP: ${OLD_IP}"

# 새 IP 확인
NEW_IP=$(hostname -I | awk '{print $1}')
echo "새 IP: ${NEW_IP}"

# IP가 같으면 변경 불필요
if [ "$OLD_IP" = "$NEW_IP" ]; then
    echo "IP 변경 없음. 서비스만 시작합니다."
else
    echo "IP 변경 적용 중..."

    cd ~/ghosts

    # docker-compose.yml 내 IP 변경
    sed -i "s/${OLD_IP}/${NEW_IP}/g" docker-compose.yml

    # Timeline 파일 내 IP 변경
    sed -i "s/${OLD_IP}/${NEW_IP}/g" timelines/*.json

    # pandora-appsettings.json (IP가 포함된 경우)
    sed -i "s/${OLD_IP}/${NEW_IP}/g" config/pandora-appsettings.json 2>/dev/null || true

    echo "IP 변경 완료: ${OLD_IP} -> ${NEW_IP}"
fi
```

### 3-4. 서비스 시작

```bash
# Ollama 시작
sudo systemctl start ollama

# Ollama 모델 확인
ollama list

# Docker 서비스 시작
cd ~/ghosts
docker compose up -d

# 서비스 시작 대기 (30초)
echo "서비스 시작 대기 중..."
sleep 30
```

### 3-5. n8n 워크플로우 IP 수정

n8n 워크플로우 내부의 URL은 `sed`로 자동 변경되지 않습니다.
n8n UI에서 수동으로 수정해야 합니다:

1. `http://<NEW_IP>:5678` 접속
2. 각 워크플로우를 열고 HTTP Request 노드의 URL을 수정
3. 특히 Ollama URL: `http://<OLD_IP>:11434` -> `http://<NEW_IP>:11434`

> **팁:** Docker 내부 네트워크명(예: `http://ghosts-api:5000`)을 사용하면 IP 변경에 영향을 받지 않습니다. Ollama만 호스트 IP가 필요합니다.

---

## 4. 동작 검증 체크리스트

반입 후 모든 서비스가 정상 동작하는지 체계적으로 검증합니다.

### 4-1. 기본 인프라 확인

```bash
# [1] Docker 서비스 상태
cd ~/ghosts
docker compose ps
# 모든 컨테이너가 "Up" 상태인지 확인

# [2] Ollama 상태
sudo systemctl status ollama
ollama list
```

**예상 결과:**
```
[ ] ghosts-postgres    Up (healthy)
[ ] ghosts-api         Up
[ ] ghosts-pandora     Up
[ ] ghosts-n8n         Up
[ ] ghosts-grafana     Up
[ ] Ollama service     active (running)
```

### 4-2. 서비스 응답 확인

```bash
NEW_IP=$(hostname -I | awk '{print $1}')

# [3] API 응답
curl -s "http://${NEW_IP}:5000/api/home" | head -c 200
echo ""

# [4] Frontend 접속
curl -s -o /dev/null -w "HTTP %{http_code}" "http://${NEW_IP}:4200"
echo ""

# [5] Socializer 접속
curl -s -o /dev/null -w "HTTP %{http_code}" "http://${NEW_IP}:8000"
echo ""

# [6] n8n 접속
curl -s -o /dev/null -w "HTTP %{http_code}" "http://${NEW_IP}:5678"
echo ""

# [7] Grafana 접속
curl -s -o /dev/null -w "HTTP %{http_code}" "http://${NEW_IP}:3000"
echo ""

# [8] Ollama API
curl -s "http://${NEW_IP}:11434/api/tags" | jq '.models[].name' 2>/dev/null || \
  curl -s "http://localhost:11434/api/tags"
```

**예상 결과:**
```
[ ] API:        HTTP 200 + JSON 응답
[ ] Frontend:   HTTP 200
[ ] Socializer: HTTP 200
[ ] n8n:        HTTP 200
[ ] Grafana:    HTTP 200
[ ] Ollama:     모델 목록 출력 (qwen3.5:9b, llama3.2:3b, social, chat, activity)
```

### 4-3. 기능 확인

```bash
# [9] Ollama 텍스트 생성 테스트
curl -s http://localhost:11434/api/generate \
  -d '{"model": "social", "prompt": "Hello", "stream": false}' | \
  jq '.response' 2>/dev/null | head -c 200
echo ""

# [10] Socializer 포스트 생성 테스트
curl -s -X POST "http://${NEW_IP}:8000/api/admin/generate/3"
echo ""

# [11] PostgreSQL 연결 확인
docker compose exec ghosts-postgres pg_isready -U ghosts
docker compose exec ghosts-postgres psql -U ghosts -d pandora -c "SELECT count(*) FROM posts;" 2>/dev/null || echo "Pandora DB 확인 필요"
```

**예상 결과:**
```
[ ] Ollama:     텍스트 생성 응답 (15~30초 소요)
[ ] Socializer: 테스트 포스트 생성 성공
[ ] PostgreSQL: 연결 성공, 포스트 수 확인
```

### 4-4. Docker 내부 네트워크 확인

```bash
# [12] Docker 컨테이너 간 통신 확인
docker compose exec ghosts-api curl -s http://ghosts-pandora:5000 > /dev/null && \
  echo "API -> Pandora: OK" || echo "API -> Pandora: FAIL"

docker compose exec ghosts-n8n curl -s http://ghosts-api:5000/api/home > /dev/null && \
  echo "n8n -> API: OK" || echo "n8n -> API: FAIL"

# [13] Docker에서 호스트 Ollama 접근 확인
docker compose exec ghosts-api curl -s http://host.docker.internal:11434/api/tags > /dev/null && \
  echo "Docker -> Ollama: OK" || echo "Docker -> Ollama: FAIL"
```

### 4-5. n8n 워크플로우 확인

```
[14] 브라우저에서 http://<NEW_IP>:5678 접속
[ ] 로그인 가능
[ ] 워크플로우 목록 확인
[ ] 각 워크플로우 Active 상태 확인
[ ] 워크플로우 내 URL이 새 IP로 수정되었는지 확인
```

### 4-6. 전체 검증 요약

```
기본 인프라:
  [ ] Docker 컨테이너 5개 모두 Up
  [ ] Ollama 서비스 active
  [ ] 모델 5종 확인

서비스 응답:
  [ ] API (port 5000)        HTTP 200
  [ ] Frontend (port 4200)   HTTP 200
  [ ] Socializer (port 8000) HTTP 200
  [ ] n8n (port 5678)        HTTP 200
  [ ] Grafana (port 3000)    HTTP 200
  [ ] Ollama (port 11434)    모델 목록 응답

기능 확인:
  [ ] Ollama 텍스트 생성 정상
  [ ] Socializer 포스트 생성 정상
  [ ] PostgreSQL 연결 정상

네트워크:
  [ ] Docker 컨테이너 간 통신 정상
  [ ] Docker -> 호스트 Ollama 접근 정상
  [ ] n8n 워크플로우 URL 업데이트 완료

준비 완료:
  [ ] Phase Trigger 테스트 (curl로 webhook 호출)
  [ ] NPC 클라이언트 연결 준비 (application.json에 새 API URL 설정)
```

---

## 5. 폐쇄망 운용 시 주의사항

### 5-1. 시간 동기화

폐쇄망에서는 NTP가 동작하지 않으므로 VM 시계가 점차 어긋날 수 있습니다.

```bash
# 현재 시간 확인
date

# 수동 시간 설정 (필요 시)
sudo date -s "2026-04-06 09:00:00"

# 하드웨어 시계도 동기화
sudo hwclock --systohc
```

### 5-2. Docker 이미지 업데이트 불가

폐쇄망에서는 Docker 이미지를 pull할 수 없습니다.
- `docker compose pull` 실행 금지
- `docker-compose.yml`에서 이미지 태그를 `latest`에서 특정 버전으로 고정하는 것을 권장

### 5-3. Ollama 모델 추가 불가

폐쇄망에서는 새 모델을 다운로드할 수 없습니다.
필요한 모델은 반입 전에 모두 pull해야 합니다.

### 5-4. 로그 관리

장시간 운용 시 로그가 디스크를 차지할 수 있습니다:

```bash
# 로그 크기 확인
docker system df

# 오래된 로그 정리
docker compose logs --no-color ghosts-api 2>/dev/null | wc -l

# Docker 로그 크기 제한 (docker-compose.yml에 이미 설정됨)
# logging:
#   options:
#     max-size: "100m"
#     max-file: "5"
```

### 5-5. 디스크 공간 모니터링

```bash
# 디스크 사용량
df -h

# Docker 사용량
docker system df

# 공간 부족 시 정리
docker system prune -f
```
