# claude-code-statusline

[![CI](https://github.com/jojo-dan/claude-code-statusline/actions/workflows/ci.yml/badge.svg)](https://github.com/jojo-dan/claude-code-statusline/actions/workflows/ci.yml)

A terminal statusline for [Claude Code](https://claude.ai/code) that displays context window usage, active model, git branch, effort level, and (optionally) your Anthropic API quota — all in a compact, color-coded header.

> **Demo screenshot coming soon.** See [`examples/demo-output.txt`](examples/demo-output.txt) for annotated output.

```
📂 ~/dev/my-project  sonnet4.6 ⚡hi  200k  🔀 main
CTX ▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱  42%  84k/200k
5H  ▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱  28%  ↻ 3h15m
7D  ▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱  15%  ↻ 5d8h
```

See [`examples/demo-output.txt`](examples/demo-output.txt) for annotated output examples.

---

## Prerequisites

- **macOS** (the quota feature uses macOS Keychain via `security`)
- **[jq](https://stedolan.github.io/jq/)** — JSON processor (`brew install jq`)
- **Claude Code CLI** — authenticated (`claude login`) for quota display

> The statusline works without Claude Code CLI authentication. Quota rows (5H / 7D / EX) are simply omitted when the token is unavailable.

---

## Installation

### Option A: One-line install (recommended)

```bash
git clone https://github.com/jojo-dan/claude-code-statusline.git ~/.claude/hud/claude-code-statusline
cd ~/.claude/hud/claude-code-statusline
bash setup.sh
```

### Option B: Project-local install

```bash
cd /path/to/your/project
git clone https://github.com/jojo-dan/claude-code-statusline.git .claude/statusline
bash .claude/statusline/setup.sh
```

### Option C: Manual install

1. Clone the repo anywhere:
   ```bash
   git clone https://github.com/jojo-dan/claude-code-statusline.git /path/of/your/choice
   ```
2. Edit `~/.claude/settings.json` and add:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/path/of/your/choice/statusline.sh"
     }
   }
   ```
3. Restart Claude Code.

> **Note:** If you move the repo directory after installation, re-run `bash setup.sh` to update the path registered in `~/.claude/settings.json`.

---

## Usage

After installation, Claude Code automatically calls `statusline.sh` at the start of each session and displays the output in the status area.

### What each row shows

| Row | Description |
|-----|-------------|
| Line 1 | Working directory, model name, effort level (`⚡lo/md/hi`), context window size, git branch, fast mode indicator |
| `CTX` | Context window usage — bar + percentage + tokens used/total |
| `5H` | 5-hour rolling quota — bar + percentage + time until reset *(requires auth)* |
| `7D` | 7-day rolling quota — bar + percentage + time until reset *(requires auth)* |
| `EX` | Extra usage credits — bar + percentage + dollar amount *(shown only when enabled)* |

### Color coding

| Color | Meaning |
|-------|---------|
| Cyan | Normal (< 70%) |
| Yellow | Moderate (≥ 50% for quota, ≥ 70% for context) |
| Red | High usage (≥ 80% for quota, ≥ 90% for context) |

---

## Configuration

`statusline.sh` reads two optional fields from `~/.claude/settings.json`:

| Field | Values | Effect |
|-------|--------|--------|
| `fastMode` | `true` / `false` | Shows `↯fast` indicator when true |
| `effortLevel` | `"low"` / `"medium"` / `"high"` | Shows `⚡lo`, `⚡md`, or `⚡hi` |

> **Note:** `fastMode` and `effortLevel` are read from `settings.json` because Claude Code's statusline stdin JSON does not expose these fields ([anthropics/claude-code#24279](https://github.com/anthropics/claude-code/issues/24279)). This means the indicator reflects the **user setting**, not a runtime-confirmed state. On the native Claude Code binary, the setting and actual state are consistent, so the indicator is accurate in practice.

No other configuration is required.

---

## Quota feature

The `5H`, `7D`, and `EX` rows show your Anthropic API usage, fetched from the Anthropic OAuth endpoint using the token Claude Code CLI stores in the macOS Keychain.

**Requirements:**
- macOS (uses `security` command to access Keychain)
- Claude Code CLI authenticated: run `claude login` if quota rows are not showing

**How it works:**
1. `fetch-usage.sh` runs in the background each time `statusline.sh` is called
2. Results are cached in `/tmp/claude-usage-cache.json` (60-second TTL)
3. If the token is missing or the request fails, the script exits silently — quota rows are not shown, but the rest of the statusline works normally

**Resources accessed:**

| Resource | Access | Purpose |
|----------|--------|---------|
| `~/.claude/settings.json` | Read-only | `fastMode`, `effortLevel` fields |
| `/tmp/claude-usage-cache.json` | Read + Write | Quota cache (60-second TTL) |
| macOS Keychain (`security`) | Read-only | OAuth access token for Anthropic API |
| `https://api.anthropic.com/api/oauth/usage` | Network (GET) | Quota data fetch |
| `git rev-parse` | Local process | Current git branch name |

**Performance:**
- `statusline.sh` itself completes in tens of milliseconds — it reads cached data only, never blocks on network.
- Network requests happen in a detached background process (`fetch-usage.sh`). When the 60-second cache is still valid, no network request is made. When the cache expires, one GET request is issued with a 5-second timeout (`curl --max-time 5`).

---

## Files

| File | Description |
|------|-------------|
| `statusline.sh` | Main statusline renderer — reads Claude Code JSON input from stdin |
| `fetch-usage.sh` | Background fetcher for Anthropic quota API |
| `setup.sh` | Installer — creates wrapper and registers `statusLine` in settings.json |
| `examples/demo-output.txt` | Annotated output examples |
| `CHANGELOG.md` | Version history |

---

## Troubleshooting

### `jq` not installed — blank output or error

**Symptom:** The statusline shows nothing, or you see a `jq: command not found` error.

**Cause:** `statusline.sh` depends on `jq` to parse the JSON input from Claude Code.

**Fix:**
```bash
brew install jq
```

---

### Quota rows not showing (no 5H / 7D / EX rows)

**Symptom:** Only the `CTX` row appears; the `5H`, `7D`, and `EX` rows are missing.

**Cause:**
- Claude Code CLI is not authenticated, or
- You are not on macOS (the quota feature requires the macOS Keychain)

**Fix:**
```bash
# Re-authenticate Claude Code CLI
claude login
```

If the rows still do not appear after authentication, verify that the token was saved correctly in the macOS Keychain:
```bash
security find-generic-password -s "claude.ai" -w 2>/dev/null | head -c 20
```
If there is no output, run `claude login` again.

---

### Statusline not showing after running `setup.sh`

**Symptom:** You ran `bash setup.sh` but the statusline does not appear in Claude Code.

**Fix:**
1. Quit Claude Code completely and restart it.
2. Verify that the `statusLine` key was registered correctly in `settings.json`:
   ```bash
   jq '.statusLine' ~/.claude/settings.json
   ```
   Expected output:
   ```json
   {
     "type": "command",
     "command": "/absolute/path/to/statusline.sh"
   }
   ```
   If `null` is returned, run `bash setup.sh` again.

---

### Statusline stops working after moving the repo

**Symptom:** The statusline disappears after you move the repo directory to a new location.

**Cause:** The wrapper created by `setup.sh` contains a hardcoded absolute path.

**Fix:** Re-run `setup.sh` from the new location:
```bash
bash /new/path/to/setup.sh
```

---

## Contributing

Contributions are welcome. Please follow the steps below.

### Reporting issues

Open an issue on [GitHub Issues](https://github.com/jojo-dan/claude-code-statusline/issues) and include:
- Your macOS version and shell
- Steps to reproduce the problem
- The actual output vs. what you expected

### Submitting a pull request

1. Fork the repository on GitHub.
2. Create a branch from `main`: `git checkout -b your-feature-name`
3. Make your changes and commit them.
4. Open a pull request against `main` with a clear description of the change.

### Code style

- Scripts are written in **bash**. Keep them POSIX-friendly where possible.
- Run [ShellCheck](https://www.shellcheck.net/) on any `.sh` files you modify (`shellcheck statusline.sh`).
- Avoid introducing external dependencies beyond `jq`, `curl`, and standard macOS utilities.

---

## License

MIT — see [LICENSE](LICENSE)
