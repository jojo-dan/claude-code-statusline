# claude-code-statusline

A terminal statusline for [Claude Code](https://claude.ai/code) that displays context window usage, active model, git branch, effort level, and (optionally) your Anthropic API quota — all in a compact, color-coded header.

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

---

## Files

| File | Description |
|------|-------------|
| `statusline.sh` | Main statusline renderer — reads Claude Code JSON input from stdin |
| `fetch-usage.sh` | Background fetcher for Anthropic quota API |
| `setup.sh` | Installer — creates wrapper and registers `statusLine` in settings.json |
| `examples/demo-output.txt` | Annotated output examples |

---

## License

MIT — see [LICENSE](LICENSE)
