#!/usr/bin/env python3
"""
locustfile.py - 더미 웹 트래픽 생성기

YAML 설정 파일(locust-targets.yaml)을 읽어서 네트워크별로
다양한 GET 요청 패턴의 정상 웹 트래픽을 생성한다.
소스 IP 바인딩을 지원하여 여러 클라이언트에서 접속하는 것처럼 보이게 한다.

Usage:
    # 단일 네트워크 (설정 파일의 첫 번째 네트워크)
    locust -f locustfile.py --headless -t 30m

    # 특정 네트워크 지정
    LOCUST_NETWORK=network-b locust -f locustfile.py --headless -t 30m

    # Web UI 모드
    locust -f locustfile.py
"""

import os
import random
import socket
import time

import yaml
from locust import HttpUser, between, events, task
from requests.adapters import HTTPAdapter
from urllib3.util.connection import create_connection as _orig_create_connection

# ---------------------------------------------------------------------------
# 설정 로드
# ---------------------------------------------------------------------------

CONFIG_PATH = os.environ.get(
    "LOCUST_CONFIG",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "locust-targets.yaml"),
)

with open(CONFIG_PATH, "r") as f:
    _config = yaml.safe_load(f)

# 네트워크 선택
_network_name = os.environ.get("LOCUST_NETWORK", "")
_networks = _config.get("networks", [])

if _network_name:
    _selected = [n for n in _networks if n["name"] == _network_name]
    if not _selected:
        raise ValueError(f"Network '{_network_name}' not found in {CONFIG_PATH}")
    _network = _selected[0]
else:
    _network = _networks[0] if _networks else {}

TARGETS = _network.get("targets", [])
SOURCE_IPS = _network.get("source_ips", [])
NUM_USERS = _network.get("users", 5)
SPAWN_RATE = _network.get("spawn_rate", 1)


# ---------------------------------------------------------------------------
# 소스 IP 바인딩 어댑터
# ---------------------------------------------------------------------------

class SourceIPAdapter(HTTPAdapter):
    """특정 소스 IP에 바인딩하는 HTTP 어댑터."""

    def __init__(self, source_ip, **kwargs):
        self._source_ip = source_ip
        super().__init__(**kwargs)

    def init_poolmanager(self, *args, **kwargs):
        kwargs["source_address"] = (self._source_ip, 0)
        super().init_poolmanager(*args, **kwargs)


# ---------------------------------------------------------------------------
# 일반적인 웹 브라우징 경로 패턴
# ---------------------------------------------------------------------------

# 다양한 웹서버에서 공통적으로 존재하는 경로들
COMMON_PATHS = [
    "/",
    "/index.html",
    "/about",
    "/contact",
    "/login",
    "/help",
    "/faq",
    "/terms",
    "/privacy",
    "/sitemap.xml",
    "/robots.txt",
    "/favicon.ico",
]

# 정적 리소스 경로
STATIC_PATHS = [
    "/css/style.css",
    "/css/main.css",
    "/js/app.js",
    "/js/main.js",
    "/images/logo.png",
    "/images/banner.jpg",
    "/assets/style.css",
    "/static/js/bundle.js",
]

# API 탐색 패턴 (일반적인 REST 경로)
API_PATHS = [
    "/api/",
    "/api/v1/",
    "/api/status",
    "/api/health",
    "/api/version",
]

# 게시판/콘텐츠 페이지 패턴
CONTENT_PATHS = [
    "/board",
    "/board/list",
    "/news",
    "/notice",
    "/posts",
    "/articles",
    "/gallery",
    "/download",
    "/search",
]

# 관리/인증 페이지 패턴
ADMIN_PATHS = [
    "/admin",
    "/admin/login",
    "/dashboard",
    "/manager",
    "/wp-admin",
    "/wp-login.php",
]

ALL_PATHS = COMMON_PATHS + STATIC_PATHS + API_PATHS + CONTENT_PATHS + ADMIN_PATHS

# 일반적인 User-Agent 문자열
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36",
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
]

# Referer 패턴
REFERERS = [
    "",  # 직접 접속
    "https://www.google.com/search?q=site",
    "https://www.google.com/",
    "https://search.naver.com/",
]


# ---------------------------------------------------------------------------
# Locust User 클래스
# ---------------------------------------------------------------------------

class WebTrafficUser(HttpUser):
    """다양한 웹서버에 정상 GET 트래픽을 생성하는 가상 유저."""

    # 요청 간 대기시간: 1~5초 (현실적인 브라우징 패턴)
    wait_time = between(1, 5)

    # host는 런타임에 랜덤 선택
    host = TARGETS[0] if TARGETS else "http://localhost"

    def on_start(self):
        """유저 시작 시 소스 IP 및 타겟 설정."""
        # 소스 IP 바인딩
        if SOURCE_IPS:
            source_ip = random.choice(SOURCE_IPS)
            adapter = SourceIPAdapter(source_ip)
            self.client.mount("http://", adapter)
            self.client.mount("https://", adapter)

        # User-Agent 고정 (세션 동안 동일 브라우저)
        self._user_agent = random.choice(USER_AGENTS)
        self._referer = random.choice(REFERERS)

    def _get_headers(self):
        """현실적인 HTTP 헤더 생성."""
        headers = {
            "User-Agent": self._user_agent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive",
        }
        if self._referer:
            headers["Referer"] = self._referer
        return headers

    def _pick_target(self):
        """랜덤 타겟 서버 선택 후 host 변경."""
        if len(TARGETS) > 1:
            self.host = random.choice(TARGETS)
            self.client.base_url = self.host

    @task(50)
    def browse_common_page(self):
        """일반 페이지 조회 (가장 빈번)."""
        self._pick_target()
        path = random.choice(COMMON_PATHS)
        self.client.get(path, headers=self._get_headers(),
                        name=f"[common] {path}", catch_response=True).__enter__()

    @task(20)
    def browse_static_resource(self):
        """정적 리소스 로드."""
        self._pick_target()
        path = random.choice(STATIC_PATHS)
        self.client.get(path, headers=self._get_headers(),
                        name=f"[static] {path}", catch_response=True).__enter__()

    @task(15)
    def browse_content_page(self):
        """게시판/콘텐츠 페이지."""
        self._pick_target()
        path = random.choice(CONTENT_PATHS)
        # 가끔 페이지 파라미터 추가
        if random.random() < 0.3:
            path += f"?page={random.randint(1, 20)}"
        self.client.get(path, headers=self._get_headers(),
                        name=f"[content] {path.split('?')[0]}", catch_response=True).__enter__()

    @task(10)
    def browse_api(self):
        """API 엔드포인트 탐색."""
        self._pick_target()
        path = random.choice(API_PATHS)
        headers = self._get_headers()
        headers["Accept"] = "application/json"
        self.client.get(path, headers=headers,
                        name=f"[api] {path}", catch_response=True).__enter__()

    @task(5)
    def browse_admin(self):
        """관리 페이지 접근 시도 (소량)."""
        self._pick_target()
        path = random.choice(ADMIN_PATHS)
        self.client.get(path, headers=self._get_headers(),
                        name=f"[admin] {path}", catch_response=True).__enter__()


# ---------------------------------------------------------------------------
# Locust 이벤트: 설정값으로 유저 수/속도 자동 적용
# ---------------------------------------------------------------------------

@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """테스트 시작 시 정보 출력."""
    net_name = _network.get("name", "default")
    print(f"\n{'='*60}")
    print(f" Locust Dummy Traffic Generator")
    print(f"  Network:    {net_name}")
    print(f"  Targets:    {len(TARGETS)} servers")
    print(f"  Source IPs: {len(SOURCE_IPS) if SOURCE_IPS else 'system default'}")
    print(f"  Users:      {NUM_USERS}")
    print(f"  Spawn Rate: {SPAWN_RATE}/s")
    print(f"{'='*60}\n")
