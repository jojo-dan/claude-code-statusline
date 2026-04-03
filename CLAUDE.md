# Claude Code Statusline

A statusline plugin that displays context window usage, token quotas, model info, and git branch at the bottom of the Claude Code terminal.

## Quick Install

```bash
git clone https://github.com/jojo-dan/claude-code-statusline.git ~/.claude/statusline
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "command": "bash ~/.claude/statusline/scripts/statusline.sh"
  }
}
```

Restart Claude Code and it works immediately.

## Configuration

### Row toggles

Individual rows can be toggled via the `statusline` object in `~/.claude/settings.json`. Omitted keys default to `true`.

| Key | Row | Default |
|-----|-----|---------|
| `statusline.ctx` | CTX context bar | `true` |
| `statusline.5h` | 5H usage bar | `true` |
| `statusline.7d` | 7D usage bar | `true` |
| `statusline.branch` | Branch + phase row | `true` |

```json
{
  "statusline": {
    "5h": false,
    "7d": false
  }
}
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_STATUSLINE_OFF=1` | Disable statusline for the session |
| `CLAUDE_OAUTH_TOKEN` | Manual OAuth token fallback (when credential store is unavailable) |

## How it works

### statusline.sh

Parses the JSON that Claude Code pipes to stdin and renders the output.

stdin JSON structure:
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

Also reads `fastMode` and `effortLevel` from `~/.claude/settings.json`.

### fetch-usage.sh

Reads the OAuth token stored in the OS credential store on Claude Code login and calls the usage API.

Token retrieval order:
1. macOS Keychain (`security find-generic-password`)
2. Linux libsecret (`secret-tool lookup`)
3. `$CLAUDE_OAUTH_TOKEN` environment variable

Cache: `/tmp/claude-usage-cache.json`, TTL 120s. Runs in the background so it never blocks the statusline output.

### Project name

Uses `workspace.project_dir` → git repo root basename as the project name. Falls back to the directory name if not a git repo.

### Phase display

Reads the `"phase"` value from a `.phase` JSON file at the project root and displays it next to the branch. If no file exists, only the branch is shown.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Statusline doesn't appear | Wrong path in `settings.json` `statusLine.command` | Check the path. Validate with `bash -n ~/.claude/statusline/scripts/statusline.sh` |
| 5H/7D bars missing | Can't read token from credential store | Set `CLAUDE_OAUTH_TOKEN` env var, or re-login to Claude Code |
| 5H/7D shows `⚠ stale` | Cached reset time is in the past | Wait for auto-refresh (up to 120s). May be API rate-limited |
| Project name shows full path | Running outside a git repo | Normal behavior. Inside a git repo, the repo name is shown |
| `date` errors | GNU/BSD date compatibility | Ensure `bash`, `jq`, `python3` are installed |

## File structure

| File | Purpose |
|------|---------|
| `scripts/statusline.sh` | Main statusline render script |
| `scripts/fetch-usage.sh` | OAuth API usage fetch + cache |
| `.claude-plugin/plugin.json` | Plugin metadata |
| `docs/guide.html` | Visual setup/usage guide (open in browser) |

## Dependencies

- `bash`, `jq`, `python3`, `curl`, `git`
- macOS: `security` (pre-installed)
- Linux: `secret-tool` (optional — falls back to `CLAUDE_OAUTH_TOKEN` env var)
