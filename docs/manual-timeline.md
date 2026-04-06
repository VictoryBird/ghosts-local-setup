# GHOSTS Timeline 작성 가이드

이 문서는 GHOSTS NPC의 행동을 정의하는 Timeline JSON 파일의 구조와 작성법을 설명합니다.

---

## 1. Timeline JSON 구조

Timeline은 NPC가 수행할 작업을 시간 기반으로 정의하는 JSON 파일입니다.

### 기본 구조

```json
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "BrowserFirefox",
      "Initial": "about:blank",
      "UtcTimeOn": "09:00:00",
      "UtcTimeOff": "18:00:00",
      "Loop": true,
      "HandlerArgs": { ... },
      "TimeLineEvents": [
        {
          "Command": "random",
          "CommandArgs": [ ... ],
          "DelayAfter": { ... },
          "DelayBefore": 3000
        }
      ]
    }
  ]
}
```

### 최상위 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `Status` | string | `"Run"` = 실행, `"Stop"` = 정지 |
| `TimeLineHandlers` | array | 핸들러 목록 (복수 핸들러 동시 실행 가능) |

### TimeLineHandler 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `HandlerType` | string | 핸들러 종류 (아래 목록 참조) |
| `Initial` | string | 핸들러 초기화 값 (브라우저: 초기 URL 등) |
| `UtcTimeOn` | string | 활동 시작 시각 (UTC, `"HH:mm:ss"`) |
| `UtcTimeOff` | string | 활동 종료 시각 (UTC, `"HH:mm:ss"`) |
| `Loop` | boolean | `true`: 이벤트 목록을 반복 실행 |
| `HandlerArgs` | object | 핸들러별 설정 (선택) |
| `TimeLineEvents` | array | 실행할 이벤트 목록 |

### TimeLineEvent 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `Command` | string | 실행할 명령어 |
| `CommandArgs` | array | 명령어 인자 |
| `DelayAfter` | object/number | 이벤트 후 대기 시간 (ms) |
| `DelayBefore` | number | 이벤트 전 대기 시간 (ms) |

### DelayAfter 상세

고정 값 또는 랜덤 범위를 지정할 수 있습니다:

```json
// 고정 대기 (30초)
"DelayAfter": 30000

// 랜덤 대기 (10초 ~ 2분)
"DelayAfter": {
  "random": true,
  "min": 10000,
  "max": 120000
}
```

---

## 2. HandlerType 목록 및 설명

### 브라우저 핸들러

| HandlerType | 설명 |
|-------------|------|
| `BrowserFirefox` | Firefox 브라우저 자동 조작 |
| `BrowserChrome` | Chrome 브라우저 자동 조작 |

### 문서 핸들러

| HandlerType | 설명 |
|-------------|------|
| `LightWord` | 워드 문서(.docx, .pdf) 자동 생성 |
| `LightExcel` | 엑셀 스프레드시트(.xlsx) 자동 생성 |
| `LightPowerPoint` | 파워포인트(.pptx) 자동 생성 |

### 네트워크 핸들러

| HandlerType | 설명 |
|-------------|------|
| `Ssh` | SSH 원격 접속 및 명령 실행 |
| `Sftp` | SFTP 파일 전송 |
| `Curl` | HTTP 요청 (API 호출 등) |
| `NpcSystem` | 시스템 명령 실행 |

### 기타 핸들러

| HandlerType | 설명 |
|-------------|------|
| `Outlook` | Outlook 이메일 송수신 |
| `Print` | 문서 인쇄 작업 |
| `Reboot` | 시스템 재부팅 |
| `Watcher` | 파일/디렉토리 변경 감시 |

---

## 3. 브라우저 명령어

BrowserFirefox/BrowserChrome 핸들러에서 사용하는 명령어:

### random

URL 목록 중 무작위로 하나를 선택하여 방문합니다.

```json
{
  "Command": "random",
  "CommandArgs": [
    "http://192.168.1.100:8000",
    "http://192.168.1.100:8000/posts",
    "http://192.168.1.100:4200"
  ]
}
```

### browse

지정된 URL을 순서대로 방문합니다.

```json
{
  "Command": "browse",
  "CommandArgs": [
    "http://192.168.1.100:8000"
  ]
}
```

### social

소셜미디어(Socializer) 활동을 시뮬레이션합니다. 포스트 작성, 좋아요, 브라우징을 자동 수행합니다.

```json
{
  "Command": "social",
  "CommandArgs": [
    "site:http://192.168.1.100:8000"
  ]
}
```

`social` 명령어는 `HandlerArgs`의 social 관련 설정과 함께 동작합니다 (5절 참조).

### type

지정된 요소에 텍스트를 입력합니다.

```json
{
  "Command": "type",
  "CommandArgs": [
    "css:#search-input",
    "cybersecurity news"
  ]
}
```

- 첫 번째 인자: CSS 셀렉터 (대상 요소)
- 두 번째 인자: 입력할 텍스트

### click

지정된 요소를 클릭합니다.

```json
{
  "Command": "click",
  "CommandArgs": [
    "css:#submit-button"
  ]
}
```

### clickByText

텍스트 내용으로 요소를 찾아 클릭합니다.

```json
{
  "Command": "clickByText",
  "CommandArgs": [
    "로그인"
  ]
}
```

### download

파일을 다운로드합니다.

```json
{
  "Command": "download",
  "CommandArgs": [
    "http://192.168.1.100:8000/downloads/document"
  ]
}
```

### js

JavaScript를 실행합니다.

```json
{
  "Command": "js",
  "CommandArgs": [
    "document.title"
  ]
}
```

---

## 4. 소셜 미디어 Timeline 작성법

### 4-1. 기본 소셜 미디어 Timeline

Socializer(Pandora)에서 소셜 활동을 하는 NPC Timeline:

```json
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
            "site:http://192.168.1.100:8000"
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
```

### 4-2. 소셜 콘텐츠 디렉토리 구조

소셜 포스트에 사용할 콘텐츠는 아래 구조로 배치합니다:

```
content/social/
├── politics/
│   ├── 001/
│   │   ├── post.txt          ← 포스트 텍스트
│   │   └── image.jpg         ← (선택) 첨부 이미지
│   ├── 002/
│   │   └── post.txt
│   └── ...
├── tech/
│   ├── 001/
│   │   └── post.txt
│   └── ...
├── military/
├── daily/
└── news/
```

- 각 토픽 디렉토리 아래 번호 디렉토리를 생성
- `post.txt`에 포스트 내용 작성
- 이미지를 포함하려면 같은 디렉토리에 이미지 파일 배치

### 4-3. 소셜 활동 확률 조정

NPC 성격에 따라 활동 확률을 조정합니다:

```
활동적인 NPC (공무원, 언론인):
  social-post-probability: 50
  social-like-probability: 30
  social-browse-probability: 20

소극적인 NPC (일반 시민):
  social-post-probability: 15
  social-like-probability: 35
  social-browse-probability: 50

봇 NPC (증폭용):
  social-post-probability: 10
  social-like-probability: 70
  social-browse-probability: 20
```

---

## 5. HandlerArgs 설명

### 브라우저 공통 설정

| 키 | 타입 | 설명 | 기본값 |
|----|------|------|--------|
| `isheadless` | string | 헤드리스 모드 (`"true"`/`"false"`) | `"false"` |
| `stickiness` | string | 같은 사이트에 머무를 확률 (0-100) | `"50"` |
| `stickiness-depth-min` | string | 사이트 내 최소 페이지 방문 수 | `"1"` |
| `stickiness-depth-max` | string | 사이트 내 최대 페이지 방문 수 | `"10"` |
| `visited-remember` | string | 방문 기록 저장 수 | `"5"` |
| `actions-before-restart` | number | 브라우저 재시작 전 최대 동작 수 | `50` |
| `delay-jitter` | string | 지연 시간 변동 비율 (0.0-1.0) | `"0.3"` |
| `command-line-args` | array | 브라우저 명령줄 인자 | `[]` |

### 소셜 미디어 설정

| 키 | 타입 | 설명 |
|----|------|------|
| `social-version` | string | 소셜 핸들러 버전 (`"1.0"`) |
| `social-content-directory` | string | 소셜 콘텐츠 디렉토리 경로 |
| `social-topiclist` | string | 포스트 토픽 목록 (쉼표 구분) |
| `social-post-probability` | string | 포스트 작성 확률 (0-100) |
| `social-like-probability` | string | 좋아요 확률 (0-100) |
| `social-browse-probability` | string | 브라우징만 하는 확률 (0-100) |
| `social-addimage-probability` | string | 포스트에 이미지 첨부 확률 (0-100) |
| `social-use-unique-user` | string | 고유 사용자명 사용 (`"true"`) |

> **참고:** `social-post-probability` + `social-like-probability` + `social-browse-probability`의 합이 100이 되어야 합니다.

### delay-jitter 설명

`delay-jitter`는 DelayAfter/DelayBefore에 적용되는 변동 비율입니다:

- `0.0`: 정확히 지정된 시간만큼 대기
- `0.3`: 지정 시간의 70%~130% 범위에서 랜덤 대기
- `1.0`: 지정 시간의 0%~200% 범위에서 랜덤 대기

NPC 활동을 자연스럽게 만들려면 `0.2`~`0.4` 범위를 권장합니다.

### stickiness 설명

`stickiness`는 NPC가 현재 사이트에 머무를 확률입니다:

- `0`: 매번 다른 사이트로 이동
- `60`: 60% 확률로 현재 사이트 내 링크를 따라감
- `100`: 항상 현재 사이트에 머무름

`stickiness-depth-min/max`와 결합하여 사이트 내 탐색 깊이를 제어합니다.

---

## 6. 예제 Timeline

### 예제 1: 일반 시민 NPC (웹 브라우징 + 소셜)

낮 시간에 웹 브라우징과 소셜 미디어를 번갈아 하는 일반 시민:

```json
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
            "http://192.168.1.100:8000",
            "http://192.168.1.100:8000/posts",
            "http://192.168.1.100:8000/search?q=news"
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
        "social-post-probability": "30",
        "social-like-probability": "40",
        "social-browse-probability": "30",
        "social-addimage-probability": "5",
        "social-use-unique-user": "true"
      },
      "TimeLineEvents": [
        {
          "Command": "social",
          "CommandArgs": [
            "site:http://192.168.1.100:8000"
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
      "HandlerType": "BrowserFirefox",
      "Initial": "about:blank",
      "UtcTimeOn": "18:00:00",
      "UtcTimeOff": "22:00:00",
      "Loop": true,
      "HandlerArgs": {
        "isheadless": "false",
        "delay-jitter": "0.5",
        "command-line-args": ["--ignore-certificate-errors"],
        "social-version": "1.0",
        "social-content-directory": "/opt/ghosts/content/social",
        "social-topiclist": "daily,tech,news",
        "social-post-probability": "40",
        "social-like-probability": "35",
        "social-browse-probability": "25",
        "social-addimage-probability": "10",
        "social-use-unique-user": "true"
      },
      "TimeLineEvents": [
        {
          "Command": "social",
          "CommandArgs": [
            "site:http://192.168.1.100:8000"
          ],
          "DelayAfter": {
            "random": true,
            "min": 60000,
            "max": 300000
          }
        }
      ]
    }
  ]
}
```

### 예제 2: 군인 NPC (사무 + 소셜 + SSH)

근무 시간에 문서 작업과 SSH를 하고, 휴식 시간에 소셜을 하는 군인:

```json
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "LightWord",
      "Initial": "",
      "UtcTimeOn": "08:00:00",
      "UtcTimeOff": "12:00:00",
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
            "min": 600000,
            "max": 1800000
          },
          "DelayBefore": 5000
        }
      ]
    },
    {
      "HandlerType": "Ssh",
      "Initial": "",
      "UtcTimeOn": "09:00:00",
      "UtcTimeOff": "17:00:00",
      "Loop": true,
      "TimeLineEvents": [
        {
          "Command": "ssh",
          "CommandArgs": [
            {
              "HostIp": "192.168.1.50",
              "Username": "operator",
              "Password": "changeme",
              "Port": 22,
              "Commands": [
                "uptime",
                "df -h",
                "free -m",
                "systemctl status nginx",
                "tail -5 /var/log/syslog"
              ]
            }
          ],
          "DelayAfter": {
            "random": true,
            "min": 900000,
            "max": 3600000
          },
          "DelayBefore": 2000
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
        "delay-jitter": "0.3",
        "command-line-args": ["--ignore-certificate-errors"],
        "social-version": "1.0",
        "social-content-directory": "/opt/ghosts/content/social",
        "social-topiclist": "military,news,daily",
        "social-post-probability": "25",
        "social-like-probability": "45",
        "social-browse-probability": "30",
        "social-addimage-probability": "5",
        "social-use-unique-user": "true"
      },
      "TimeLineEvents": [
        {
          "Command": "social",
          "CommandArgs": [
            "site:http://192.168.1.100:8000"
          ],
          "DelayAfter": {
            "random": true,
            "min": 60000,
            "max": 180000
          }
        }
      ]
    },
    {
      "HandlerType": "LightExcel",
      "Initial": "",
      "UtcTimeOn": "14:00:00",
      "UtcTimeOff": "17:00:00",
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
            "min": 900000,
            "max": 2700000
          },
          "DelayBefore": 3000
        }
      ]
    }
  ]
}
```

### 예제 3: 봇 NPC (소셜 증폭 전용)

24시간 소셜미디어에서 좋아요와 짧은 댓글로 특정 포스트를 증폭하는 봇:

```json
{
  "Status": "Run",
  "TimeLineHandlers": [
    {
      "HandlerType": "BrowserFirefox",
      "Initial": "about:blank",
      "UtcTimeOn": "00:00:00",
      "UtcTimeOff": "23:59:59",
      "Loop": true,
      "HandlerArgs": {
        "isheadless": "true",
        "stickiness": "90",
        "stickiness-depth-min": "1",
        "stickiness-depth-max": "3",
        "delay-jitter": "0.5",
        "command-line-args": ["--ignore-certificate-errors"],
        "social-version": "1.0",
        "social-content-directory": "/opt/ghosts/content/social",
        "social-topiclist": "politics,military,news",
        "social-post-probability": "10",
        "social-like-probability": "70",
        "social-browse-probability": "20",
        "social-addimage-probability": "0",
        "social-use-unique-user": "true"
      },
      "TimeLineEvents": [
        {
          "Command": "social",
          "CommandArgs": [
            "site:http://192.168.1.100:8000"
          ],
          "DelayAfter": {
            "random": true,
            "min": 10000,
            "max": 60000
          },
          "DelayBefore": 2000
        }
      ]
    }
  ]
}
```

**봇 NPC 특징:**
- `isheadless: "true"` -- GUI 없이 실행 (리소스 절약)
- `stickiness: "90"` -- Socializer에 거의 항상 머무름
- `social-like-probability: "70"` -- 주로 좋아요 반응
- `social-post-probability: "10"` -- 가끔 짧은 동조 댓글
- 24시간 활동 (`00:00:00` ~ `23:59:59`)
- 짧은 간격 (`10초 ~ 60초`)

---

## 7. Timeline API 배포

작성한 Timeline을 NPC 클라이언트에 배포하는 방법:

### 7-1. 직접 파일 배치

NPC 클라이언트 VM에 Timeline JSON 파일을 직접 배치합니다:

```
Windows: C:\ghosts\config\timeline.json
Linux:   /opt/ghosts/config/timeline.json
```

### 7-2. API를 통한 배포

GHOSTS API를 통해 원격으로 Timeline을 배포합니다:

```bash
# 특정 NPC에게 Timeline 배포
curl -X POST "http://<VM_IP>:5000/api/machines/<MACHINE_ID>/timeline" \
  -H "Content-Type: application/json" \
  -d @timeline.json

# NPC 그룹에게 일괄 배포
curl -X POST "http://<VM_IP>:5000/api/machines/group/<GROUP_ID>/timeline" \
  -H "Content-Type: application/json" \
  -d @timeline.json
```

### 7-3. Frontend UI를 통한 배포

1. `http://<VM_IP>:4200` 접속
2. Machines 메뉴에서 대상 NPC 선택
3. Timeline 탭에서 JSON 편집 또는 업로드
