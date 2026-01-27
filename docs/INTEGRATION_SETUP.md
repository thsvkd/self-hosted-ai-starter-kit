# GitLab-Slack-Notion 통합 설정 가이드

이 가이드는 n8n을 사용하여 내부 GitLab 서버와 Slack, Notion을 연동하는 방법을 단계별로 설명합니다.

## 목차
1. [개요](#개요)
2. [빠른 시작](#빠른-시작)
3. [상세 설정 가이드](#상세-설정-가이드)
4. [워크플로우 사용법](#워크플로우-사용법)
5. [사용 시나리오](#사용-시나리오)
6. [API 토큰 발급 가이드](#api-토큰-발급-가이드)
7. [문제 해결](#문제-해결)

---

## 개요

이 통합을 통해 다음과 같은 워크플로우가 가능합니다:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         이슈 생성 플로우                                  │
│                                                                         │
│   [Slack/Notion에서 이슈 요청] ──▶ [n8n 처리] ──▶ [GitLab 이슈 생성]    │
│                                        │                                │
│                                        ▼                                │
│                              [Slack/Notion에 알림]                      │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         이슈 해결 플로우                                  │
│                                                                         │
│   [개발자 커밋 (이슈번호 포함)] ──▶ [n8n 감지] ──▶ [GitLab 이슈 닫기]   │
│                                         │                               │
│                                         ▼                               │
│                         [Slack/Notion 상태 업데이트]                    │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         코멘트 동기화 플로우                              │
│                                                                         │
│   [Slack/Notion 코멘트] ──▶ [n8n 처리] ──▶ [GitLab 이슈 코멘트 추가]    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 빠른 시작

### 1단계: 환경 설정

```bash
# 저장소 클론 및 이동
git clone https://github.com/your-org/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit

# 환경 변수 파일 복사 및 수정
cp .env.example .env
```

### 2단계: 환경 변수 설정

`.env` 파일을 열어 다음 값들을 설정합니다:

```bash
# 기본 설정 (기존)
POSTGRES_USER=root
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=n8n
N8N_ENCRYPTION_KEY=your_encryption_key
N8N_USER_MANAGEMENT_JWT_SECRET=your_jwt_secret

# GitLab 설정 (새로 추가)
GITLAB_URL=https://gitlab.your-company.com
GITLAB_ACCESS_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
GITLAB_PROJECT_ID=1

# Slack 설정 (새로 추가)
SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxx
SLACK_CHANNEL=#issue-notifications

# Notion 설정 (새로 추가)
NOTION_API_KEY=secret_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
NOTION_DATABASE_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Cloudflare Tunnel (설정 후 업데이트)
CLOUDFLARE_TUNNEL_TOKEN=your_tunnel_token
N8N_WEBHOOK_URL=https://n8n.yourdomain.com
```

### 3단계: 서비스 시작

```bash
# GPU 사용 시
./scripts/run.sh

# 또는 CPU만 사용 시
docker compose --profile cpu up -d
```

### 4단계: Cloudflare Tunnel 시작

```bash
# 개발/테스트용 임시 터널
./scripts/expose-with-cloudflare.sh
```

### 5단계: n8n 접속 및 설정

1. 브라우저에서 `http://localhost:5678` 접속
2. 관리자 계정 생성
3. **Settings** > **Credentials**에서 각 서비스 인증 정보 입력
4. 워크플로우 활성화

---

## 상세 설정 가이드

### GitLab Credential 설정

1. n8n 대시보드에서 **Credentials** > **New Credential** 클릭
2. **GitLab API** 선택
3. 다음 정보 입력:
   - **Server URL**: `https://gitlab.your-company.com`
   - **Access Token**: GitLab Personal Access Token

### Slack Credential 설정

1. n8n 대시보드에서 **Credentials** > **New Credential** 클릭
2. **Slack API** 선택
3. **Access Token**: Bot User OAuth Token 입력

### Notion Credential 설정

1. n8n 대시보드에서 **Credentials** > **New Credential** 클릭
2. **Notion API** 선택
3. **Internal Integration Token**: Notion API 키 입력

---

## 워크플로우 사용법

### 1. GitLab-Slack-Notion Issue Sync

**목적**: Slack 또는 Notion에서 생성된 이슈 요청을 GitLab에 자동으로 등록

**트리거**:
- Slack: `/issue create [제목] - [설명]` 명령어 또는 특정 채널 메시지
- Notion: 데이터베이스에 새 페이지 생성 시

**동작**:
1. 요청 수신 및 파싱
2. GitLab에 이슈 생성
3. Slack 채널에 알림 전송
4. Notion 페이지에 GitLab 이슈 링크 추가

### 2. GitLab Commit Issue Resolver

**목적**: 커밋 메시지에 이슈 번호가 포함된 경우 자동으로 이슈 해결

**트리거**: GitLab push webhook

**지원하는 커밋 메시지 형식**:
```
fix: 버그 수정 #123
closes #456
fixes #789
resolves #101
```

**동작**:
1. 커밋 메시지에서 이슈 번호 추출
2. 해당 이슈 상태를 "closed"로 변경
3. 이슈에 해결 코멘트 추가
4. Slack/Notion에 해결 알림 전송

### 3. Comment Sync

**목적**: Slack/Notion의 코멘트를 GitLab 이슈에 동기화

**트리거**: Slack 메시지 또는 Notion 코멘트

**동작**:
1. 코멘트 내용 및 작성자 정보 수집
2. 해당 GitLab 이슈에 코멘트 추가
3. 동기화 완료 알림

### 4. Slack Issue Bot

**목적**: Slack 슬래시 명령어로 GitLab 이슈 관리

**명령어**:
```
/issue create [제목] - [설명]   # 새 이슈 생성
/issue status #123              # 이슈 상태 확인
/issue comment #123 [메시지]    # 이슈에 코멘트 추가
```

---

## 사용 시나리오

### 시나리오 1: 디자이너가 버그 리포트

1. **디자이너**: Slack에서 `/issue create 로그인 버튼 색상 오류 - 모바일에서 버튼 색상이 다르게 표시됩니다` 입력
2. **n8n**: 자동으로 GitLab에 이슈 #42 생성
3. **Slack**: "✅ GitLab 이슈가 생성되었습니다! #42 - 로그인 버튼 색상 오류" 메시지 표시

### 시나리오 2: 개발자가 이슈 해결

1. **개발자**: 코드 수정 후 커밋
   ```bash
   git commit -m "fix: 모바일 버튼 색상 수정 closes #42"
   git push
   ```
2. **n8n**: GitLab webhook 수신, 이슈 #42 자동 닫기
3. **Slack**: "✅ 이슈 #42 해결됨!" 메시지 표시
4. **디자이너**: Slack에서 확인 후 `/issue comment #42 확인했습니다. 감사합니다!` 입력
5. **n8n**: GitLab 이슈에 코멘트 추가

### 시나리오 3: Notion을 통한 이슈 관리

1. **PM**: Notion 데이터베이스에 새 태스크 페이지 생성
2. **n8n**: 자동으로 GitLab 이슈 생성, Notion 페이지에 이슈 링크 추가
3. **개발자**: GitLab에서 작업 후 커밋
4. **n8n**: 이슈 해결 감지, Notion 페이지 상태를 "Resolved" 로 업데이트

---

## API 토큰 발급 가이드

### GitLab Personal Access Token

1. GitLab 프로필 > **Preferences** > **Access Tokens**
2. **Add new token** 클릭
3. 설정:
   - **Token name**: `n8n-integration`
   - **Expiration date**: 적절한 만료일 설정
   - **Scopes**: `api`, `read_user`, `read_repository`
4. **Create personal access token** 클릭
5. 생성된 토큰 복사 (한 번만 표시됨!)

### Slack Bot Token

1. [Slack API](https://api.slack.com/apps) 접속
2. **Create New App** > **From scratch**
3. 앱 이름과 워크스페이스 선택
4. **OAuth & Permissions** > **Scopes** > **Bot Token Scopes**:
   - `chat:write`
   - `chat:write.public`
   - `commands`
   - `channels:read`
   - `groups:read`
5. **Install to Workspace** 클릭
6. **Bot User OAuth Token** 복사

### Notion Integration Token

1. [Notion Integrations](https://www.notion.so/my-integrations) 접속
2. **New integration** 클릭
3. 설정:
   - **Name**: `n8n-gitlab-sync`
   - **Associated workspace**: 워크스페이스 선택
   - **Capabilities**: 
     - Read content
     - Update content
     - Insert content
4. **Submit** 클릭
5. **Internal Integration Token** 복사
6. **연동할 데이터베이스**에서:
   - 페이지 우상단 `...` > **Connections** > 생성한 통합 선택

---

## 문제 해결

### "Credential 연결 실패" 오류

1. API 토큰이 올바른지 확인
2. 토큰의 권한(scope)이 충분한지 확인
3. 서버 URL이 올바른지 확인

### "Webhook 응답 없음" 오류

1. Cloudflare Tunnel이 실행 중인지 확인
2. n8n 워크플로우가 활성화되어 있는지 확인
3. Webhook URL이 올바른지 확인

### "GitLab 이슈 생성 실패" 오류

1. GitLab 프로젝트 ID가 올바른지 확인
2. 토큰에 이슈 생성 권한이 있는지 확인
3. GitLab 서버 연결 상태 확인

### 로그 확인

```bash
# n8n 로그 확인
docker logs n8n

# Cloudflare Tunnel 로그 확인
docker logs cloudflared

# 전체 스택 로그 확인
docker compose logs -f
```

---

## 다음 단계

- [Cloudflare Tunnel 설정 가이드](./CLOUDFLARE_TUNNEL_SETUP.md)
- [n8n 공식 문서](https://docs.n8n.io/)
- [워크플로우 커스터마이징 가이드](https://docs.n8n.io/workflows/)
