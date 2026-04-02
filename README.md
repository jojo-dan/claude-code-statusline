# Claude Code Statusline

![statusline](https://github.com/user-attachments/assets/placeholder-screenshot.png)

Claude Code 터미널 하단에 컨텍스트 사용률, 5시간/7일 토큰 쿼터, 모델, 브랜치를 실시간으로 표시합니다.

## 설치 (3단계)

```bash
# 1. clone
git clone https://github.com/jojo-dan/claude-code-statusline.git ~/.claude/statusline

# 2. settings.json에 추가
# ~/.claude/settings.json
# {
#   "statusLine": {
#     "command": "bash ~/.claude/statusline/scripts/statusline.sh"
#   }
# }

# 3. Claude Code 재시작
```

5H/7D 사용량 바는 Claude Code 로그인 정보를 자동으로 감지하여 추가 설정 없이 동작합니다.

## 기능

- **CTX** — 컨텍스트 윈도우 사용률 바
- **5H / 7D** — 5시간 / 7일 토큰 사용량 바 + 리셋 타이머
- **모델** — 현재 사용 중인 모델 (opus4.6, sonnet4.6, haiku4.5 등)
- **브랜치 + Phase** — git 브랜치 + 프로젝트 phase 표시
- **반응형 레이아웃** — 터미널 폭에 따라 L/M/S 3단계 자동 조절
- **행 토글** — settings.json에서 개별 행 켜기/끄기

## 자세한 가이드

브라우저에서 [`docs/guide.html`](docs/guide.html)을 열어보세요. 설치 플로우, 출력 프리뷰, 커스터마이징 옵션을 시각적으로 확인할 수 있습니다.

## 라이선스

MIT
