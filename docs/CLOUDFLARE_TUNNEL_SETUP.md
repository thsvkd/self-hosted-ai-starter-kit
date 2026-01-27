# Cloudflare Tunnel 설정 가이드

이 문서는 내부 GitLab 서버와 클라우드 서비스(Slack, Notion)를 안전하게 연동하기 위한 Cloudflare Tunnel 설정 방법을 설명합니다.

## 목차
1. [개요](#개요)
2. [사전 요구사항](#사전-요구사항)
3. [Cloudflare 계정 설정](#cloudflare-계정-설정)
4. [Cloudflare Tunnel 설치 및 설정](#cloudflare-tunnel-설치-및-설정)
5. [n8n과 GitLab 연동 설정](#n8n과-gitlab-연동-설정)
6. [보안 고려사항](#보안-고려사항)
7. [문제 해결](#문제-해결)

---

## 개요

Cloudflare Tunnel(이전 Argo Tunnel)은 내부 서비스를 인터넷에 안전하게 노출하는 방법을 제공합니다. 이를 통해:

- 방화벽에서 인바운드 포트를 열 필요 없이 외부에서 접근 가능
- 모든 트래픽이 Cloudflare의 네트워크를 통해 암호화
- DDoS 보호 및 웹 보안 기능 활용
- 내부 GitLab 서버를 Slack, Notion 등 클라우드 서비스와 안전하게 연동

### 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                        내부 네트워크                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────┐ │
│  │   GitLab     │────▶│     n8n      │────▶│ Cloudflare Tunnel│─┼──▶ Cloudflare Edge
│  │   Server     │     │   Instance   │     │   (cloudflared)  │ │
│  └──────────────┘     └──────────────┘     └──────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                                      │
                                                      ▼
                                            ┌──────────────────┐
                                            │  Cloudflare Edge │
                                            │   (*.trycloudflare.com 또는   │
                                            │    사용자 정의 도메인)         │
                                            └──────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    ▼                                 ▼                                 ▼
            ┌──────────────┐                 ┌──────────────┐                 ┌──────────────┐
            │    Slack     │                 │    Notion    │                 │  External    │
            │   Webhooks   │                 │   Webhooks   │                 │   Services   │
            └──────────────┘                 └──────────────┘                 └──────────────┘
```

---

## 사전 요구사항

1. **Cloudflare 계정**: 무료 플랜 사용 가능
2. **도메인 (선택사항)**: 사용자 정의 도메인 사용 시 필요
3. **Docker**: 이미 설치되어 있어야 함
4. **내부 GitLab 서버**: HTTP/HTTPS로 접근 가능해야 함

---

## Cloudflare 계정 설정

### 1. Cloudflare 계정 생성

1. [Cloudflare 대시보드](https://dash.cloudflare.com/sign-up)에서 계정 생성
2. 이메일 인증 완료

### 2. 도메인 추가 (선택사항)

사용자 정의 도메인을 사용하려면:

1. Cloudflare 대시보드에서 "Add a Site" 클릭
2. 도메인 입력 후 플랜 선택 (무료 플랜 가능)
3. DNS 레코드 스캔 후 네임서버 변경
4. 네임서버 변경 완료 대기 (최대 24시간)

---

## Cloudflare Tunnel 설치 및 설정

### 방법 1: 빠른 시작 (임시 URL 사용)

이 방법은 테스트용으로 적합하며, 영구적인 URL이 필요 없을 때 사용합니다.

```bash
# 프로젝트 디렉토리에서 실행
./scripts/expose-with-cloudflare.sh
```

또는 직접 실행:

```bash
docker run --rm -it \
  --network self-hosted-ai-starter-kit_demo \
  cloudflare/cloudflared:latest \
  tunnel --url http://n8n:5678
```

출력에서 `*.trycloudflare.com` 형식의 임시 URL을 확인할 수 있습니다.

### 방법 2: 영구 터널 설정 (권장)

프로덕션 환경에서는 영구 터널을 설정하는 것이 좋습니다.

#### 2.1 Cloudflare Tunnel 토큰 생성

1. [Cloudflare Zero Trust 대시보드](https://one.dash.cloudflare.com/) 접속
2. **Networks** > **Tunnels** 이동
3. **Create a tunnel** 클릭
4. 터널 이름 입력 (예: `n8n-gitlab-integration`)
5. **Cloudflared** 선택
6. 터널 토큰 복사 (형식: `eyJhIjoi...`)

#### 2.2 환경 변수 설정

`.env` 파일에 다음 추가:

```bash
# Cloudflare Tunnel 설정
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoi...여기에_토큰_붙여넣기...
```

#### 2.3 docker-compose.yml에 Cloudflare Tunnel 서비스 추가

`docker-compose.yml` 파일에 다음 서비스 추가:

```yaml
services:
  # ... 기존 서비스들 ...

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    networks: ["demo"]
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
    depends_on:
      - n8n
```

#### 2.4 터널 라우팅 설정

Cloudflare Zero Trust 대시보드에서:

1. 생성한 터널 클릭
2. **Public Hostname** 탭 이동
3. **Add a public hostname** 클릭
4. 다음 설정 입력:
   - **Subdomain**: `n8n` (또는 원하는 서브도메인)
   - **Domain**: 등록된 도메인 선택
   - **Service Type**: `HTTP`
   - **URL**: `n8n:5678`
5. 저장

---

## n8n과 GitLab 연동 설정

### 1. 환경 변수 설정

`.env` 파일에 다음 변수들을 추가합니다:

```bash
# GitLab 설정
GITLAB_URL=https://your-gitlab-server.internal
GITLAB_ACCESS_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
GITLAB_PROJECT_ID=1

# Slack 설정
SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx
SLACK_SIGNING_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SLACK_CHANNEL=#issue-notifications

# Notion 설정
NOTION_API_KEY=secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
NOTION_DATABASE_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Cloudflare Tunnel URL (터널 설정 후 업데이트)
N8N_WEBHOOK_URL=https://n8n.yourdomain.com
```

### 2. GitLab Webhook 설정

1. GitLab 프로젝트 > **Settings** > **Webhooks**
2. URL: `https://your-n8n-url/webhook/gitlab-webhook`
3. 다음 이벤트 선택:
   - Push events
   - Issues events
   - Comments
4. **Add webhook** 클릭

### 3. Slack App 설정

1. [Slack API](https://api.slack.com/apps)에서 새 앱 생성
2. **OAuth & Permissions**에서 다음 스코프 추가:
   - `chat:write`
   - `channels:read`
   - `commands`
3. 워크스페이스에 앱 설치
4. **Slash Commands**에서 새 명령 추가:
   - Command: `/issue`
   - Request URL: `https://your-n8n-url/webhook/slack-bot`

### 4. Notion Integration 설정

1. [Notion Integrations](https://www.notion.so/my-integrations)에서 새 통합 생성
2. Capabilities 설정:
   - Read content
   - Update content
   - Insert content
3. 연동할 데이터베이스에서 통합 연결

---

## 보안 고려사항

### 1. Webhook 시크릿 사용

모든 webhook에 시크릿 토큰을 설정하여 요청 검증:

```javascript
// n8n에서 Slack 서명 검증 예시
const crypto = require('crypto');
const signature = $request.headers['x-slack-signature'];
const timestamp = $request.headers['x-slack-request-timestamp'];
const sigBasestring = 'v0:' + timestamp + ':' + JSON.stringify($request.body);
const mySignature = 'v0=' + crypto.createHmac('sha256', $env.SLACK_SIGNING_SECRET)
  .update(sigBasestring)
  .digest('hex');

if (signature !== mySignature) {
  throw new Error('Invalid signature');
}
```

### 2. Access Control

Cloudflare Zero Trust에서 추가 보안 설정:

1. **Access** > **Applications** 이동
2. 새 애플리케이션 추가
3. 접근 정책 설정 (이메일 도메인, IP 범위 등)

### 3. Rate Limiting

Cloudflare에서 Rate Limiting 규칙 설정:

1. 도메인의 **Security** > **WAF** 이동
2. **Rate limiting rules** 추가
3. 분당 요청 수 제한 설정

---

## 문제 해결

### 터널 연결 실패

```bash
# 터널 상태 확인
docker logs cloudflared

# 네트워크 연결 테스트
docker exec cloudflared cloudflared tunnel info
```

### n8n Webhook 접근 불가

1. n8n이 실행 중인지 확인
2. 터널 라우팅 설정 확인
3. Cloudflare 대시보드에서 터널 상태 확인

### GitLab Webhook 오류

1. GitLab Webhook 설정에서 **Recent Deliveries** 확인
2. 응답 코드와 본문 확인
3. n8n 워크플로우 실행 로그 확인

---

## 다음 단계

1. [GitLab-Slack-Notion 통합 설정 가이드](./INTEGRATION_SETUP.md)로 이동
2. n8n 워크플로우 활성화
3. 테스트 이슈 생성하여 통합 확인

---

## 참고 자료

- [Cloudflare Tunnel 공식 문서](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [n8n Webhook 문서](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)
- [GitLab Webhooks 문서](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html)
