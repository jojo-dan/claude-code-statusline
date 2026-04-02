# Claude Code Statusline

Claude Code 터미널 하단에 컨텍스트 사용률, 토큰 쿼터, 모델, 브랜치를 표시하는 statusline 플러그인.

## 빠른 설치

```bash
git clone https://github.com/jojo-dan/claude-code-statusline.git ~/.claude/statusline
```

`~/.claude/settings.json`에 추가:

```json
{
  "statusLine": {
    "command": "bash ~/.claude/statusline/scripts/statusline.sh"
  }
}
```

Claude Code를 재시작하면 즉시 동작한다.

## 설정

### 행 토글

`~/.claude/settings.json`의 `statusline` 객체로 개별 행을 켜고 끌 수 있다. 미설정 키는 기본 `true`.

| 키 | 항목 | 기본값 |
|----|------|--------|
| `statusline.ctx` | CTX 컨텍스트 바 | `true` |
| `statusline.5h` | 5H 사용량 바 | `true` |
| `statusline.7d` | 7D 사용량 바 | `true` |
| `statusline.branch` | 브랜치 + phase 행 | `true` |

```json
{
  "statusline": {
    "5h": false,
    "7d": false
  }
}
```

### 환경변수

| 변수 | 설명 |
|------|------|
| `CLAUDE_STATUSLINE_OFF=1` | 세션 단위 statusline 비활성화 |
| `CLAUDE_OAUTH_TOKEN` | OAuth 토큰 수동 지정 (credential store 접근 불가 시 폴백) |

## 동작 원리

### statusline.sh

Claude Code가 stdin으로 전달하는 JSON을 파싱하여 출력한다.

stdin JSON 구조:
```json
{
  "context_window": {
    "used_percentage": 42.5,
    "context_window_size": 200000
  },
  "workspace": {
    "project_dir": "/path/to/project",
    "current_dir": "/path/to/project"
  },
  "model": {
    "id": "claude-opus-4-6"
  }
}
```

추가로 `~/.claude/settings.json`에서 `fastMode`, `effortLevel`을 읽는다.

### fetch-usage.sh

Claude Code 로그인 시 OS credential store에 저장된 OAuth 토큰을 자동으로 읽어 사용량 API를 호출한다.

토큰 획득 순서:
1. macOS Keychain (`security find-generic-password`)
2. Linux libsecret (`secret-tool lookup`)
3. `$CLAUDE_OAUTH_TOKEN` 환경변수

캐시: `/tmp/claude-usage-cache.json`, TTL 120초. 백그라운드 실행으로 statusline 출력을 차단하지 않는다.

### 프로젝트명 추출

`workspace.project_dir` → git repo root의 basename을 프로젝트명으로 사용한다. git repo가 아니면 디렉토리명을 사용.

### phase 표시

프로젝트 루트의 `.phase` 파일(JSON)에서 `"phase"` 값을 읽어 브랜치 옆에 표시한다. 파일이 없으면 브랜치만 표시.

## 문제 해결

| 증상 | 원인 | 해결 |
|------|------|------|
| statusline이 아예 안 보임 | `settings.json`의 `statusLine.command` 경로 오류 | 경로 확인. `bash -n ~/.claude/statusline/scripts/statusline.sh`로 구문 검증 |
| 5H/7D 바가 안 보임 | credential store에서 토큰을 못 읽음 | `CLAUDE_OAUTH_TOKEN` 환경변수 설정, 또는 Claude Code 재로그인 |
| 5H/7D에 `⚠ stale` 표시 | 캐시의 reset 시각이 과거 | 자동 갱신 대기 (최대 120초). API rate limit 중일 수 있음 |
| 프로젝트명이 전체 경로로 표시됨 | git repo 밖에서 실행 중 | 정상 동작. git repo 안에서는 repo 이름이 표시됨 |
| `date` 관련 에러 | GNU/BSD date 호환 이슈 | `bash`, `jq`, `python3`이 설치되어 있는지 확인 |

## 파일 구조

| 파일 | 역할 |
|------|------|
| `scripts/statusline.sh` | 메인 statusline 출력 스크립트 |
| `scripts/fetch-usage.sh` | OAuth API로 사용량 조회 + 캐시 |
| `.claude-plugin/plugin.json` | 플러그인 메타데이터 |
| `docs/guide.html` | 시각적 설치/사용 가이드 (브라우저에서 열기) |

## 의존성

- `bash`, `jq`, `python3`, `curl`, `git`
- macOS: `security` (기본 설치됨)
- Linux: `secret-tool` (선택 — 없으면 `CLAUDE_OAUTH_TOKEN` 환경변수 사용)
