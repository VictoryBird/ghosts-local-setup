# GHOSTS 개선사항

## Socializer UI
- [ ] Facebook 테마 UI가 지저분함 — X 테마로 변경 테스트해보기
- [ ] 테마 UI 커스터마이징 검토 (`Views/Themes/{테마명}/` Razor 뷰 수정)

## 인지전 시나리오 구현
- [ ] 훈련 시나리오 연계 인지전 설계 (A국 공산당 vs B국 민주공화국)
  - A국 공작 계정 NPC: 허위정보 유포, 정부 불신/군 사기 저하/사회 분열 유도
  - A국 봇 계정 NPC: 공작 포스트 좋아요/공유/댓글로 확산
  - B국 시민/군인 NPC: 정상 활동 + 허위정보 노출에 따른 신념 변화
- [ ] Socializer(MeridiaNet) 공식 계정 구성
  - Krasnovia: Government, State Cyber Command(SCC), Krasnovia Today(국영매체)
  - Valdoria: Government, MOIS(내무안전부), MND(국방부), CDC(사이버방어사령부), VWA(수자원청)
  - 양측 정부 간 성명전 시나리오 설계
- [ ] Socializer 테마를 X로 변경 (MeridiaNet = Twitter 등가)
- [ ] 사이버 공격 Phase 1~6과 인지전 연동 (플레이북 기준)
  - 사전공격(Phase 1~3): 인지전 분위기 조성 (루머 시작)
  - 본훈련 Day 1(Phase 4): 인지전 본격화 (해킹 보도, GORGON 협박)
  - 본훈련 Day 2(Phase 5): 조작 정보 (가짜 성명, 내부 협조자 1차)
  - 본훈련 Day 3(Phase 6): 인지전 총공세 (전 채널 동원, 타이밍 심리전)
- [ ] NPC 그룹별 신념 초기값 및 Ollama 포스트 생성 프롬프트 설계
- [ ] 영향력 티어 시스템 구현 (SocialGraphJob/SocialBeliefJob 소스 커스터마이징)
  - Tier 1 (정부/언론): 연결 수 多 + Likelihood 가중치 높음
  - Tier 2 (일반 시민): 기본 연결 수 + 기본 Likelihood
  - Tier 3 (봇): 독자 영향력 없음, 증폭만 수행, 신념 변화 고정
- [ ] Tarvek NPC 추가: Government(1), GORGON 연계(2), 위장(2)
- [ ] Arventa NPC 추가: Government(1), 언론(1), 시민(3)
- [ ] Belief Explorer(Grafana) 대시보드로 여론 변화 모니터링 구성
- [ ] 방어팀 미션 설계: 공작 계정 식별, 허위정보 추적, 팩트체크 대응
- [ ] 정보판단 → 보고 → 지시 체계 구현
  - 대항군이 X(Socializer)에 허위정보/진짜정보 혼합 게시
  - 방어팀 정보담당이 Socializer 모니터링하며 진위 판단
  - 판단 결과를 상부에 보고 (보고 체계/양식 설계)
  - 상부가 보고 기반으로 사이버작전 지시 (대응 조치)
- [ ] 딥페이크/조작 정보 대응 (텍스트 기반)
  - A국이 B국 고위 관료의 가짜 발언/성명을 텍스트로 조작하여 Socializer에 유포
  - 방어팀이 조작 여부 판별 → 보고 → 지시 체계와 연계
- [ ] 방어팀 인지전 대응 (판단/보고/방어만, 역공 없음)
  - Belief Explorer(Grafana)에서 여론 변화 모니터링
- [ ] 내부 협조자(스파이) 시나리오
  - B국 NPC 중 일부가 A국에 포섭된 내부 협조자 설정
  - 평시 정상 활동 → 특정 시점에 내부 정보 Socializer 유출
  - 방어팀이 활동 패턴 분석으로 내부 위협 식별
- [ ] 타이밍 기반 심리전
  - 사이버 공격(정전/통신장애) 직후 공포를 이용한 허위정보 집중 투하
  - 방어팀의 위기 커뮤니케이션 대응 능력 평가

## Frontend UI 개선
- [ ] GHOSTS Frontend UI/UX 개선 검토
  - 기존 UI 그대로 쓰되, 필요 시 훈련 통제 전용 대시보드 별도 개발 검토

## NPC 구성 계획
- [ ] NPC 총 100~150명 구성 설계
  - 에이전트 NPC 20명 (VM 4~5대, 실제 트래픽 생성)
  - API-only NPC 80~130명 (소셜/인지전 시뮬레이션, VM 불필요)
- [ ] NPC 역할별 분류: 군인, 공무원, 일반 시민, 학생, 노약자 등
- [ ] NPC 속성 스키마 설계 후 일괄 생성 스크립트 작성
- [ ] LLM 콘텐츠 100% 실시간 생성 (사전 생성 X)
  - CPU-only qwen3.5:9b: 포스트 1건당 15~30초 예상, NPC 특성상 자연스러운 속도
  - NPC 프로필 기반 개인화된 포스트 생성
  - 병목 시 소셜 포스트 전용 경량 모델(llama3.2:3b) 전환 검토

## NPC 커스터마이징
- [ ] 이름 데이터 한국식으로 교체 (names_female.txt, names_male.txt, names_last.txt)
- [ ] 주소/도시 데이터 한국 지역으로 교체
- [ ] 직책/부서 데이터 한국 군/공무원 체계에 맞게 수정
- [ ] 계급 체계 한국군 기준으로 수정 (military_rank.json)
- [ ] 아바타 이미지를 NPC 속성(성별/나이/계급 등) 기반으로 AI 생성 검토
- [ ] 대학/전공 데이터 한국 대학으로 교체

## 매뉴얼 작성
- [ ] 서버 구축/운용 매뉴얼
- [ ] NPC 클라이언트 설치 매뉴얼
- [ ] Timeline 작성 가이드
- [ ] Socializer/인지전 설정 가이드
- [ ] 폐쇄망 반입 절차

## 향후 작업
- [ ] NPC 클라이언트 VM 구성 및 API 연동 테스트
- [ ] n8n 워크플로우 임포트 및 활성화 (Social Media, Belief, Social Graph)
- [ ] 소셜 콘텐츠 추가 (한국어 토픽 확장)
- [ ] 폐쇄망 반입 전 최종 점검
- [ ] 커스터마이징 후 개인 GitHub 저장소에 올리기
