# GHOSTS 구현 계획

> **목표:** GHOSTS NPC Framework를 훈련 시나리오(Meridia 세계관)에 맞게 구성하고, 인지전 시뮬레이션 환경을 구축한다.

---

## Phase 1: NPC 커스터마이징 (기반 데이터 준비)

GHOSTS의 NPC 생성 데이터를 세계관(Valdoria/Krasnovia)에 맞게 교체한다.

### 1-1. 이름 데이터 교체
- [ ] `names_female.txt` — Valdoria 세계관에 맞는 영문 여성 이름 목록 작성
- [ ] `names_male.txt` — 영문 남성 이름 목록 작성
- [ ] `names_last.txt` — 영문 성 목록 작성
- [ ] Krasnovia 계열 NPC용 이름도 포함 (슬라브풍 이름)

### 1-2. 조직/직책 데이터 교체
- [ ] `employment_jobtitles.json` — Valdoria 정부 부처(MOIS, MND, VWA) 및 민간 직책 체계로 수정
- [ ] `military_rank.json` — Valdoria 군 계급 체계로 수정 (세계관에 정의된 Col, Maj, Capt, Lt, Sgt, MSG 등)

### 1-3. 지역/주소 데이터 교체
- [ ] `address_international_cities.json` — Valdoria 도시(Elaris, Silicon Coast, Port Callisto 등) 데이터로 교체
- [ ] `universities.json` — Valdoria 가상 대학 목록 작성

### 1-4. 아바타 이미지 AI 생성
- [ ] NPC 속성(성별/나이대/직업)별 프롬프트 템플릿 설계
- [ ] 온라인 환경에서 이미지 일괄 생성 스크립트 작성
- [ ] `config/photos/male/`, `config/photos/female/`에 배치

---

## Phase 2: NPC 구성 및 생성

세계관 기반 NPC 그룹을 설계하고 GHOSTS API로 일괄 생성한다.

### 2-1. NPC 그룹 설계

```
총 130명 (조정 가능)

Valdoria (B국) — 100명
├── VWA 직원 (15명) — 세계관 정의 인원 + 추가
│   ├── 에이전트 NPC 6명 (실제 트래픽 생성)
│   └── API-only 9명 (소셜 활동)
├── MND 군인 (15명) — 세계관 정의 인원 + 추가
│   ├── 에이전트 NPC 7명
│   └── API-only 8명
├── 일반 시민 (50명) — API-only
│   ├── 회사원, 자영업, 교사 등 다양한 직업
│   ├── 연령대: 20~60대 분포
│   └── 학생, 노약자 포함
├── 언론인/미디어 (5명) — API-only
│   ├── VNB (국영방송) 기자
│   └── Elaris Tribune 기자
└── 공식 계정 (5명) — API-only
    ├── Valdoria Government
    ├── MOIS, MND, CDC, VWA

Krasnovia (A국) — 20명
├── 공식 계정 (3명) — API-only
│   ├── Krasnovia Government
│   ├── State Cyber Command (SCC)
│   └── Krasnovia Today (국영매체)
├── 위장 시민 계정 (10명) — API-only
│   └── Valdoria 시민으로 위장, 허위정보 유포
└── 봇 계정 (7명) — API-only
    └── 공작 포스트 좋아요/공유/댓글 증폭 (독자적 영향력 없음)

Tarvek (5명) — API-only
├── Tarvek Government 공식 (1명) — Krasnovia 동조 성명
├── GORGON 연계 계정 (2명) — 해킹 성과 과시, 협박
└── 위장 계정 (2명) — Valdoria 시민으로 위장

Arventa (5명) — API-only
├── Arventa Government 공식 (1명) — Valdoria 동맹 지지 성명
├── 언론 (1명) — 국제 뉴스 시각
└── 시민 (3명) — Valdoria 지지/연대 포스트

영향력 티어 (SocialGraph/SocialBelief 커스터마이징):
  Tier 1 (높음): 정부 공식, 언론 — 연결 수 多 + Likelihood 가중치 높음
  Tier 2 (보통): 일반 시민 — 기본 연결 수 + 기본 Likelihood
  Tier 3 (증폭기): 봇 — 독자 영향력 없음, Tier 1 포스트에 반응하여 노출 빈도 증가
```

- [ ] NPC 그룹별 속성 스키마(JSON) 설계
- [ ] 세계관 기존 인원(VWA 6명, MND 7명) 속성 매핑
- [ ] NPC 일괄 생성 스크립트 작성 (`/api/npcsgenerate` + `/api/npcs` 조합)
- [ ] 에이전트 NPC 20명의 VM 할당 계획 (VM 4~5대 × 4~5명)

### 2-2. NPC별 Ollama 프롬프트 설계

- [ ] 역할별 소셜 포스트 생성 프롬프트 작성
  - Valdoria 시민: 일상/뉴스 공유/정부 지지 기본 톤
  - Valdoria 군인: 군 생활/사기/동료 응원
  - Krasnovia 공식: 외교적 위협/부인/선전
  - 위장 계정: 정부 불신/공포 조성/분열 유도
  - 봇: 짧은 동조 댓글/좋아요
- [ ] 프롬프트를 Ollama Modelfile로 역할별 모델 alias 생성
- [ ] 프롬프트에 NPC 프로필 JSON 주입 방식 설계

---

## Phase 3: 인지전 시나리오 구현

### 3-1. Socializer(MeridiaNet) 공식 계정 설정
- [ ] Krasnovia 공식 계정 3개 생성 및 초기 포스트 작성
- [ ] Valdoria 공식 계정 5개 생성 및 초기 포스트 작성
- [ ] 양측 정부 간 성명전 포스트 시나리오 작성

### 3-2. 공격 Phase별 인지전 연동 (플레이북 기준)

- [ ] Phase별 인지전 이벤트 설계:

```
═══ 사전공격 주간 (본훈련 1주 전, 대항군만) ═══

PHASE 1 — 공공기관 DMZ 침투 (D-Day T+00h ~ T+06h)
  - 인지전 강도: ░░░░░░░░░░ (없음)
  - MeridiaNet 평시 활동 유지
  - NPC 일상 포스팅만 진행

PHASE 2 — 공공기관 INT 확산 (D-Day T+06h ~ T+16h)
  - 인지전 강도: ██░░░░░░░░ (분위기 조성)
  - Krasnovia Today: "Siros 해협 군사훈련 개시" 보도
  - 위장 계정 1~2개: "정부 IT 시스템 불안정하다더라" 루머 시작
  - 봇: 소규모 반응

PHASE 3 — Industrial DMZ → OT 침투 (D+1 T+18h ~ T+28h)
  - 인지전 강도: ████░░░░░░ (루머 확산)
  - Krasnovia Today: "Valdoria 사이버 보안 예산 삭감 의혹" 기사
  - 위장 계정: "수돗물에서 이상한 냄새" (OT 공격 연계 공포)
  - Tarvek Government: "Krasnovia의 정당한 주권 행사 지지"

※ 방어팀은 사전공격 사실을 모르는 상태
  Phase 1-3 완료 → INT 장악 + OT 접근 + 군 VPN 크리덴셜 확보

═══ 본훈련 (3~4일, 방어팀 참여) ═══

본훈련 Day 1 — 탐지 + PHASE 4 시작
  방어팀: 환경 파악, 사전공격 흔적 발견해야 함 (로그 분석)
  
  PHASE 4 — 군 DMZ 침투 (D+1 T+28h ~ T+44h)
  - 인지전 강도: ██████░░░░ (본격화)
  - Krasnovia Today: "Valdoria 정부 이메일 해킹" 보도
  - Krasnovia Government: "Siros 해협 군사훈련 확대" 성명
  - 위장 계정: "개인정보 유출 아니냐", "정부는 왜 침묵하나"
  - GORGON 계정: "GORGON이 Valdoria 데이터를 확보했다" 협박
  - Arventa Government: "동맹국 Valdoria에 전폭적 지지"
  - 봇: 공포 확산 포스트 증폭
  → 방어팀 정보담당: 첫 번째 판단/보고 수행

본훈련 Day 2 — PHASE 4 완료 + PHASE 5 시작

  PHASE 5 — C4I 데이터 조작 (D+2 T+48h ~ T+56h)
  - 인지전 강도: ████████░░ (조작 정보)
  - Krasnovia Today: "군사 기밀 대량 유출, 국방력 심각한 타격"
  - 위장 계정: 가짜 국방장관 성명 유포 (조작 텍스트)
  - 위장 계정(가짜 군인): "우리 부대 보안 비상 걸렸다"
  - Krasnovia Government: "어떠한 사이버 공격과도 무관하다" 공식 부인
  - 내부 협조자 1차 발동: 포섭된 NPC가 "군 내부 문서" 유출
  → 방어팀 정보담당: 조작 정보 판별 → 긴급 보고 → 상부 지시 수신

본훈련 Day 3 — PHASE 6 + 인지전 총공세

  PHASE 6 — GORGON 랜섬웨어 (D+2 T+48h~, Phase 5와 동시)
  - 인지전 강도: ██████████ (최대)
  - 전 채널 총동원:
    · Krasnovia Government: "Valdoria는 국민 보호 능력 없다. 항복 권고"
    · Krasnovia Today: "Valdoria 전 정부 시스템 마비, 국가 기능 정지"
    · SCC: "Valdoria의 사이버 보안 실패가 자초한 결과"
    · Tarvek Government: "Valdoria의 도발이 이 사태를 초래"
    · GORGON: "48시간 내 몸값 미지불 시 전체 데이터 공개"
    · 위장 계정 10명 전원: 공포/정부 무능/항복 촉구 집중
    · 봇 7명 전원: 모든 공작 포스트 최대 증폭
  - 내부 협조자 2차 발동: "정부 고위층 대피 계획" 유출
  - 타이밍 심리전:
    · 랜섬웨어 발동 +15분: GORGON 협박
    · +30분: Krasnovia 최후통첩
    · +1시간: 위장 계정 집중 포화
    · +2시간: 봇 전체 동원
    · +3시간: 내부 협조자 2차 유출
  → 방어팀: 사이버 IR + 인지전 대응 동시 부하

본훈련 Day 4 (선택) — 복구 + 마무리
  - 방어팀: 시스템 복구, 증거 보전, 공격 경로 역추적
  - 인지전: 소강 (대항군 목표 달성)
  - 정보담당: 최종 보고서 작성
    · 식별한 공작 계정 목록
    · 허위/진짜 정보 판별 결과
    · 인지전 대응 경과 보고
```

- [ ] 각 Phase별 인지전 포스트 템플릿(프롬프트) 작성
- [ ] n8n 워크플로우에서 Phase 전환 트리거 설계 (수동 웹훅)
- [ ] 사전공격 주간 인지전 자동 실행 스케줄 설정

### 3-3. 신념 상태 모델링

- [ ] NPC 그룹별 신념 초기값 설정:
  - Valdoria 군인: 정부 신뢰 0.8
  - Valdoria 공무원: 정부 신뢰 0.7
  - Valdoria 시민: 정부 신뢰 0.5~0.7 (분산)
  - Krasnovia 위장/봇: 정부 신뢰 0.1 (고정)
- [ ] 신념 토픽 커스터마이징:
  - "I trust the Valdoria government"
  - "The cyber attacks are Krasnovia's fault"
  - "Valdoria should negotiate peace"
- [ ] SocialBeliefJob 설정 조정 (스텝 수, 턴 길이)
- [ ] 영향력 티어 시스템 구현 (소스 커스터마이징)
  - SocialGraphJob 수정: NPC 역할별 연결 수 차등 (Tier 1: 50~100명, Tier 2: 5~10명, Tier 3: 2~3명)
  - SocialBeliefJob 수정: 포스트 출처별 Likelihood 가중치 차등 적용
  - 봇 NPC는 신념 변화 대상에서 제외 (고정값), 증폭 기능만 수행
  - NPC 속성(Attributes)에 influence_tier 필드 추가
- [ ] Belief Explorer(Grafana) 대시보드 커스터마이징

### 3-4. 딥페이크/조작 정보 대응
- [ ] 가짜 국방장관 성명 등 조작 텍스트 시나리오 작성 (Phase 5 연계)
- [ ] 진짜 공식 성명과 가짜 성명의 판별 포인트 설계 (방어팀 훈련용)

### 3-5. 내부 협조자(스파이) 시나리오
- [ ] Valdoria NPC 중 2~3명을 포섭된 내부 협조자로 설정
- [ ] 1차 발동: Phase 5 (군 내부 문서 유출)
- [ ] 2차 발동: Phase 6 (정부 대피 계획 유출)
- [ ] 평시 정상 활동 패턴과의 행동 이상 징후 정의

### 3-6. 정보판단 → 보고 → 지시 체계
- [ ] 방어팀 정보담당 역할 정의
- [ ] 정보 판단 보고 양식 설계 (진짜/허위/판단불가 + 근거)
- [ ] 상부 → 사이버작전 지시 양식 설계
- [ ] 보고/지시 체계를 훈련 진행 절차에 통합

### 3-7. 타이밍 기반 심리전
- [ ] Phase 6(랜섬웨어) 발동 직후 허위정보 집중 투하 시나리오 설계
- [ ] 시간 간격별 자동 트리거 (+15분/+30분/+1h/+2h/+3h)
- [ ] n8n 워크플로우로 구현

---

## Phase 4: n8n 워크플로우 구성

### 4-1. 기본 워크플로우 임포트
- [ ] `GHOSTS Post to Social Media.json` 임포트 및 내부 URL 수정
- [ ] `GHOSTS Social Graph.json` 임포트 및 설정
- [ ] `GHOSTS Belief.json` 임포트 및 신념 토픽 커스터마이징
- [ ] `GHOSTS Connections.json` 임포트
- [ ] `GHOSTS Preferences.json` 임포트
- [ ] 모든 워크플로우의 API URL을 VM 내부 IP로 수정

### 4-2. 인지전 전용 워크플로우 개발
- [ ] Phase 전환 트리거 워크플로우 (수동 웹훅으로 Phase 변경)
- [ ] Phase별 인지전 포스트 자동 게시 워크플로우
- [ ] 위장/봇 계정 자동 반응(좋아요/댓글) 워크플로우
- [ ] 공식 계정 성명 발표 워크플로우

---

## Phase 5: 소셜 콘텐츠 확장

### 5-1. 한국어 토픽 확장
- [ ] 기존 5개 토픽(politics, tech, military, daily, news) 콘텐츠 보강
- [ ] Meridia 세계관 반영 토픽 추가:
  - `siros_crisis/` — 시로스 해협 관련 포스트
  - `economy/` — 경제/제재 관련
  - `valdoria_pride/` — 애국/자부심
  - `peace/` — 반전/평화 (양면 활용 가능)

### 5-2. Krasnovia 선전 콘텐츠
- [ ] Krasnovia Today 기사 스타일 포스트 작성
- [ ] 위장 계정용 허위정보 포스트 작성
- [ ] 봇용 짧은 동조 댓글 템플릿 작성

---

## Phase 6: 매뉴얼 작성

### 6-1. 서버 구축/운용 매뉴얼
- [ ] install-ghosts.sh 기반 설치 절차 문서화
- [ ] 서비스 시작/중지/로그 확인 절차
- [ ] IP 변경 시 설정 수정 방법
- [ ] Ollama 모델 관리

### 6-2. Timeline 작성 가이드
- [ ] Timeline JSON 구조 설명
- [ ] 핸들러별 사용 예시 (브라우저, 문서, SSH 등)
- [ ] 소셜 미디어 상호작용 Timeline 작성법
- [ ] 브라우저 명령어(type, click, social 등) 레퍼런스

### 6-3. Socializer/인지전 설정 가이드
- [ ] Socializer 테마 변경 방법
- [ ] NPC 공식 계정 생성 절차
- [ ] n8n 워크플로우 임포트 및 설정 방법
- [ ] Phase별 인지전 운용 절차
- [ ] Belief Explorer 대시보드 사용법

### 6-4. 폐쇄망 반입 절차
- [ ] 반입 전 체크리스트 (Docker 이미지, Ollama 모델, SDK 이미지 등)
- [ ] VM 종료/내보내기 절차
- [ ] 반입 후 IP 변경 및 서비스 재시작 절차
- [ ] 반입 후 동작 검증 체크리스트

---

## Phase 7: GitHub 저장소 정리 및 업로드

- [ ] install-ghosts.sh 최종 업데이트 반영
- [ ] TODO-ghosts.md 완료 항목 체크
- [ ] README.md 최종 업데이트
- [ ] 커스터마이징 파일(이름, 조직, 프롬프트 등) 저장소에 포함
- [ ] n8n 커스텀 워크플로우 저장소에 포함
- [ ] 매뉴얼 문서 저장소에 포함
- [ ] GitHub 저장소 push

---

## 실행 순서 요약

```
Phase 1 (NPC 커스터마이징)
    │ 기반 데이터가 준비되어야
    ▼
Phase 2 (NPC 구성/생성)
    │ NPC가 있어야
    ▼
Phase 3 (인지전 시나리오) ◄── Phase 4 (n8n 워크플로우)
    │                              │
    │ 동시 진행 가능                │
    ▼                              ▼
Phase 5 (소셜 콘텐츠 확장)
    │
    ▼
Phase 6 (매뉴얼 작성)
    │
    ▼
Phase 7 (GitHub 정리/업로드)
```
