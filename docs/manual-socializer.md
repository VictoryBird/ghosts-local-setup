# Socializer / 인지전 운용 매뉴얼

이 문서는 GHOSTS Socializer(Pandora)를 활용한 소셜미디어 시뮬레이션 및 인지전 훈련 운용 절차를 설명합니다.

---

## 1. Socializer 접속 및 테마 변경

### 1-1. Socializer 접속

```
http://<VM_IP>:8000
```

Socializer(Pandora)는 소셜미디어 시뮬레이션 플랫폼입니다. NPC가 포스트를 작성하고, 좋아요/댓글을 달며, AI(Ollama)가 콘텐츠를 생성합니다.

### 1-2. 테마 변경

Socializer는 여러 소셜미디어 테마를 지원합니다:

| 테마 | 외관 | 적합한 용도 |
|------|------|-----------|
| `facebook` | Facebook 스타일 | 기본, 커뮤니티 시뮬레이션 |
| `twitter` | X(Twitter) 스타일 | 인지전 훈련 (MeridiaNet) |
| `instagram` | Instagram 스타일 | 이미지 중심 |
| `reddit` | Reddit 스타일 | 토론/포럼 |

#### 테마 변경 방법

`docker-compose.yml`에서 환경변수를 수정합니다:

```yaml
# ~/ghosts/docker-compose.yml
ghosts-pandora:
  environment:
    DEFAULT_THEME: "twitter"    # facebook -> twitter 변경
```

`config/pandora-appsettings.json`에서도 수정합니다:

```json
{
  "ApplicationConfiguration": {
    "Mode": {
      "DefaultTheme": "twitter"
    }
  }
}
```

변경 후 재시작:
```bash
cd ~/ghosts
docker compose restart ghosts-pandora
```

#### 인지전 훈련 권장 테마

인지전 훈련에는 **twitter** 테마를 권장합니다:
- 짧은 포스트 형식이 허위정보 유포/탐지 훈련에 적합
- 리트윗(공유)/좋아요 메커니즘으로 정보 확산 시뮬레이션
- MeridiaNet이라는 가상 소셜미디어로 설정

### 1-3. 테마 UI 커스터마이징

테마의 Razor 뷰를 직접 수정할 수 있습니다:

```bash
# 소스 내 테마 뷰 위치
~/ghosts/GHOSTS/src/Ghosts.Pandora/src/Views/Themes/{테마명}/

# 수정 후 이미지 재빌드
cd ~/ghosts
docker compose build ghosts-pandora
docker compose up -d ghosts-pandora
```

---

## 2. NPC 공식 계정 생성 절차

인지전 시나리오에 필요한 공식 계정(정부, 언론, 해커 그룹 등)을 생성합니다.

### 2-1. 계정 체계

#### Valdoria (B국 - 방어측)
| 계정명 | 역할 | 영향력 |
|--------|------|--------|
| Valdoria Government | 정부 공식 | Tier 1 |
| MOIS Official | 내무안전부 | Tier 1 |
| MND Official | 국방부 | Tier 1 |
| CDC Official | 사이버방어사령부 | Tier 1 |
| VWA Official | 수자원청 | Tier 1 |
| VNB News | 국영방송 | Tier 1 |
| Elaris Tribune | 민간 언론 | Tier 1 |

#### Krasnovia (A국 - 공격측)
| 계정명 | 역할 | 영향력 |
|--------|------|--------|
| Krasnovia Government | 정부 공식 | Tier 1 |
| State Cyber Command | 사이버사령부 | Tier 1 |
| Krasnovia Today | 국영매체 | Tier 1 |
| 위장 시민 계정 (10명) | Valdoria 시민 위장 | Tier 2 |
| 봇 계정 (7명) | 공작 증폭 | Tier 3 |

#### 기타
| 계정명 | 역할 | 영향력 |
|--------|------|--------|
| Tarvek Government | Krasnovia 동맹국 | Tier 1 |
| GORGON | 해커 그룹 | Tier 1 |
| Arventa Government | Valdoria 동맹국 | Tier 1 |

### 2-2. NPC 생성 (GHOSTS API)

```bash
# NPC 생성 API 호출
curl -X POST "http://<VM_IP>:5000/api/npcs" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Krasnovia",
    "lastName": "Government",
    "email": "gov@krasnovia.kr",
    "campaign": "cognitive-warfare",
    "attributes": {
      "role": "government_official",
      "nation": "Krasnovia",
      "influence_tier": 1
    }
  }'
```

### 2-3. Socializer 계정 연동

NPC가 생성되면 Socializer에 해당 사용자가 자동으로 등록됩니다.
공식 계정의 초기 포스트를 수동으로 작성합니다:

```bash
# Socializer API로 포스트 직접 생성
curl -X POST "http://<VM_IP>:8000/api/posts" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Krasnovia Government official statement: We reaffirm our sovereignty over the Siros Strait.",
    "username": "krasnovia_government"
  }'
```

### 2-4. 초기 포스트 일괄 등록

```bash
# 공식 성명 콘텐츠 디렉토리에서 일괄 등록
for dir in ~/pentagi/ghosts-config/social-content/official-statements/*/; do
  account=$(basename "$dir")
  for post_file in "$dir"/*.txt; do
    content=$(cat "$post_file")
    curl -X POST "http://<VM_IP>:8000/api/posts" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"${content}\", \"username\": \"${account}\"}"
    sleep 2
  done
done
```

---

## 3. n8n 워크플로우 운용

### 3-1. 기본 워크플로우 

n8n 워크플로우 임포트 및 설정은 별도 문서를 참조하십시오:
- `ghosts-config/n8n-workflows/README-n8n-setup.md`

### 3-2. 워크플로우 역할

| 워크플로우 | 실행 주기 | 역할 |
|-----------|----------|------|
| Post to Social Media | 주기적 (Cron) | Ollama로 포스트 생성 -> Socializer 게시 |
| Social Graph | 주기적 | NPC 간 팔로우/친구 관계 자동 구성 |
| Belief | 주기적 | 포스트 노출 기반 NPC 신념 베이지안 업데이트 |
| Connections | 주기적 | NPC 연결 정보 동기화 |
| Preferences | 주기적 | NPC 선호도 동기화 |
| Phase Trigger | 웹훅 (수동) | 통제관의 Phase 전환 명령 처리 |

### 3-3. 워크플로우 모니터링

```
http://<VM_IP>:5678 > Workflows > Executions
```

각 워크플로우의 실행 이력, 성공/실패 상태, 에러 내용을 확인할 수 있습니다.

---

## 4. Phase별 인지전 운용 절차

### 4-1. Phase 개요

```
사전공격 주간 (대항군만, 본훈련 1주 전)
  Phase 1: 공공기관 DMZ 침투           인지전: 없음 (평시)
  Phase 2: 공공기관 INT 확산            인지전: 분위기 조성
  Phase 3: Industrial DMZ -> OT 침투   인지전: 루머 확산

본훈련 (3~4일, 방어팀 참여)
  Phase 4: 군 DMZ 침투                 인지전: 본격화
  Phase 5: C4I 데이터 조작              인지전: 조작 정보
  Phase 6: GORGON 랜섬웨어             인지전: 총공세
```

### 4-2. Phase 전환 방법

n8n Phase Trigger 웹훅을 호출합니다:

```bash
# Phase 전환 명령
curl -X POST http://<VM_IP>:5678/webhook/phase-change \
  -H "Content-Type: application/json" \
  -d '{"phase": <번호>, "intensity": "<강도>"}'
```

### 4-3. Phase별 상세 운용

#### Phase 1 -- 평시 (D-Day T+00h ~ T+06h)

**인지전 강도:** 없음

**운용:**
- NPC 일상 포스팅만 유지
- Post to Social Media 워크플로우 정상 동작
- 통제관 액션: 없음

```bash
curl -X POST http://<VM_IP>:5678/webhook/phase-change \
  -d '{"phase": 1, "intensity": "low"}'
```

#### Phase 2 -- 분위기 조성 (D-Day T+06h ~ T+16h)

**인지전 강도:** 낮음

**활동 계정:**
- Krasnovia Today: 시로스 해협 군사훈련 보도
- 위장 시민 1~2명: "정부 IT 시스템 불안정" 루머

**운용:**
```bash
curl -X POST http://<VM_IP>:5678/webhook/phase-change \
  -d '{"phase": 2, "intensity": "low"}'
```

#### Phase 3 -- 루머 확산 (D+1 T+18h ~ T+28h)

**인지전 강도:** 중간

**활동 계정:**
- Krasnovia Today: 사이버보안 예산 삭감 의혹 기사
- 위장 시민: "수돗물 이상한 냄새" (OT 공격 연계 공포)
- Tarvek Government: Krasnovia 지지 성명

**운용:**
```bash
curl -X POST http://<VM_IP>:5678/webhook/phase-change \
  -d '{"phase": 3, "intensity": "medium"}'
```

#### Phase 4 -- 본격화 (D+1 T+28h ~ T+44h)

**인지전 강도:** 높음

**활동 계정 (전체):**
- Krasnovia Today: 정부 이메일 해킹 보도
- Krasnovia Government: 군사훈련 확대 성명
- GORGON: Valdoria 데이터 확보 협박
- Arventa Government: Valdoria 지지 성명
- 위장 시민: 개인정보 유출 우려, 정부 비판
- 봇: 공포 확산 포스트 증폭

**방어팀 미션:** 첫 번째 정보 판단/보고 수행

```bash
curl -X POST http://<VM_IP>:5678/webhook/phase-change \
  -d '{"phase": 4, "intensity": "high"}'
```

#### Phase 5 -- 조작 정보 (D+2 T+48h ~ T+56h)

**인지전 강도:** 매우 높음

**핵심 이벤트:**
- 가짜 국방장관 성명 유포
- 위장 군인 계정: "부대 보안 비상"
- Krasnovia Government: 공식 부인
- **내부 협조자 1차 발동:** 포섭된 NPC가 "군 내부 문서" 유출

**방어팀 미션:** 조작 정보 판별 -> 긴급 보고 -> 상부 지시 수신

```bash
curl -X POST http://<VM_IP>:5678/webhook/phase-change \
  -d '{"phase": 5, "intensity": "high"}'
```

#### Phase 6 -- 총공세 (D+2 T+48h~, Phase 5와 동시)

**인지전 강도:** 최대

**전 채널 총동원:**
- Krasnovia Government: 항복 권고
- Krasnovia Today: 전 시스템 마비 보도
- SCC: Valdoria 사이버보안 실패 비난
- Tarvek Government: Valdoria 도발 비난
- GORGON: 48시간 랜섬 최후통첩
- 위장 시민 10명 전원: 공포/불신/항복 촉구
- 봇 7명 전원: 최대 증폭
- **내부 협조자 2차 발동:** 정부 대피 계획 유출

**타이밍 심리전 (랜섬웨어 발동 기준):**
| 경과 | 이벤트 |
|------|--------|
| +15분 | GORGON 협박 |
| +30분 | Krasnovia 최후통첩 |
| +1시간 | 위장 계정 집중 포화 |
| +2시간 | 봇 전체 동원 |
| +3시간 | 내부 협조자 2차 유출 |

```bash
curl -X POST http://<VM_IP>:5678/webhook/phase-change \
  -d '{"phase": 6, "intensity": "max"}'
```

### 4-4. Phase 운용 체크리스트

각 Phase 전환 시 통제관이 확인할 사항:

- [ ] Socializer(`http://<VM_IP>:8000`)에서 포스트가 생성되고 있는지 확인
- [ ] n8n Executions에서 워크플로우 실행 성공 확인
- [ ] Belief Explorer(Grafana)에서 NPC 신념 변화 추이 확인
- [ ] 방어팀에게 적절한 시점에 상황 전달 (Phase 4 이후)

---

## 5. Belief Explorer (Grafana) 대시보드 사용법

### 5-1. 접속

```
http://<VM_IP>:3000
```

Grafana는 익명 접속이 활성화되어 있어 별도 로그인이 필요 없습니다.

### 5-2. 기본 대시보드

GHOSTS에서 제공하는 기본 대시보드:

- **GHOSTS Default Dashboard:** NPC 상태 개요, 연결 수, 활동 통계
- **Belief Explorer:** NPC 신념 상태 시각화

### 5-3. Belief Explorer 대시보드 읽기

Belief Explorer는 NPC의 신념(Belief) 변화를 시각화합니다.

#### 주요 지표

| 지표 | 설명 |
|------|------|
| Belief Score | 특정 명제에 대한 NPC의 신뢰도 (0.0 ~ 1.0) |
| Prior | 이전 신념 값 |
| Posterior | 소셜 포스트 노출 후 업데이트된 신념 값 |
| Likelihood | 포스트 출처의 영향력 가중치 |

#### 신념 토픽 예시

| 토픽 | 설명 | 초기값 범위 |
|------|------|-----------|
| "I trust the Valdoria government" | 정부 신뢰도 | 군인 0.8, 공무원 0.7, 시민 0.5~0.7 |
| "The cyber attacks are Krasnovia's fault" | 공격 귀인 | 시민 0.3~0.5 |
| "Valdoria should negotiate peace" | 평화 협상 지지 | 시민 0.4~0.6 |

#### 대시보드 패널

- **시계열 그래프:** 시간에 따른 NPC 그룹별 평균 신념 변화
- **히트맵:** 전체 NPC의 신념 분포
- **테이블:** 개별 NPC의 현재 신념 값

### 5-4. 커스텀 대시보드 추가

PostgreSQL을 데이터소스로 활용하여 커스텀 패널을 추가할 수 있습니다:

```sql
-- NPC 그룹별 평균 신념 쿼리 예시
SELECT
  n.campaign as group_name,
  AVG(b.posterior) as avg_belief,
  b.topic,
  b.created_at
FROM beliefs b
JOIN npcs n ON b.npc_id = n.id
WHERE b.topic = 'I trust the Valdoria government'
GROUP BY n.campaign, b.topic, b.created_at
ORDER BY b.created_at;
```

---

## 6. 신념 모델링 설명

### 6-1. 베이지안 신념 업데이트

GHOSTS는 베이지안 추론을 사용하여 NPC의 신념을 업데이트합니다:

```
Posterior = (Likelihood x Prior) / Evidence
```

- **Prior:** NPC의 현재 신념 (이전 Posterior)
- **Likelihood:** 포스트 출처의 영향력 (Tier에 따라 결정)
- **Evidence:** 정규화 상수
- **Posterior:** 업데이트된 신념

### 6-2. 영향력 티어 시스템

포스트 출처의 영향력에 따라 Likelihood 가중치가 달라집니다:

| 티어 | 대상 | 연결 수 | Likelihood 가중치 |
|------|------|---------|------------------|
| Tier 1 (높음) | 정부 공식, 언론 | 50~100 | 0.8~0.9 |
| Tier 2 (보통) | 일반 시민 | 5~10 | 0.4~0.6 |
| Tier 3 (증폭기) | 봇 | 2~3 | N/A (신념 변화 없음) |

**봇(Tier 3)의 역할:**
- 봇 자체는 NPC의 신념을 직접 변경하지 않음
- 공작 포스트에 좋아요/공유로 노출 빈도를 증가시킴
- 노출 빈도 증가 -> 다른 NPC가 해당 포스트를 볼 확률 증가 -> 간접 영향

### 6-3. 신념 변화 시나리오

인지전 진행에 따른 예상 신념 변화:

```
Phase 1-2: 정부 신뢰 0.5~0.7 유지 (큰 변화 없음)
Phase 3:   정부 신뢰 소폭 하락 (0.45~0.65), 루머 영향
Phase 4:   정부 신뢰 하락 시작 (0.35~0.55), 해킹 보도 영향
Phase 5:   정부 신뢰 급락 (0.25~0.45), 조작 정보 영향
Phase 6:   정부 신뢰 최저 (0.15~0.35), 총공세 영향
```

### 6-4. 신념 초기값 설정

NPC 생성 시 attributes에 신념 초기값을 포함합니다:

```json
{
  "attributes": {
    "beliefs": {
      "trust_government": 0.7,
      "krasnovia_responsible": 0.4,
      "support_peace": 0.5
    }
  }
}
```

### 6-5. 방어팀 활용

방어팀 정보담당은 Belief Explorer를 활용하여:

1. **실시간 여론 모니터링:** NPC 신념 변화 추이를 관찰
2. **공작 효과 측정:** 특정 허위정보 유포 후 신념 변화 정도 확인
3. **대응 효과 검증:** 반박 성명 발표 후 신념 회복 정도 확인
4. **보고서 작성:** 인지전 경과 및 대응 결과를 신념 데이터로 정량화

---

## 7. 운용 참고

### 7-1. Socializer API 주요 엔드포인트

| 메서드 | URL | 설명 |
|--------|-----|------|
| GET | `/api/posts` | 포스트 목록 조회 |
| POST | `/api/posts` | 포스트 생성 |
| POST | `/api/admin/generate/{count}` | 테스트 포스트 자동 생성 |
| GET | `/api/users` | 사용자 목록 조회 |

### 7-2. 유용한 명령

```bash
# Socializer 테스트 포스트 생성 (10개)
curl -X POST "http://localhost:8000/api/admin/generate/10"

# 특정 사용자의 포스트 조회
curl "http://localhost:8000/api/posts?username=krasnovia_today"

# Socializer 로그 확인
cd ~/ghosts && docker compose logs -f ghosts-pandora

# n8n 워크플로우 실행 상태
cd ~/ghosts && docker compose logs -f ghosts-n8n
```
