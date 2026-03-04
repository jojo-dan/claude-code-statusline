# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-04

### Added

- Context window usage bar (`CTX`) — displays tokens used / total with a color-coded progress bar
- 5-hour rolling quota display (`5H`) — bar + percentage + time until reset
- 7-day rolling quota display (`7D`) — bar + percentage + time until reset
- Extra usage credits display (`EX`) — bar + percentage + dollar amount (shown only when enabled)
- Model name display on the header line
- Effort level indicator (`⚡lo` / `⚡md` / `⚡hi`)
- Fast mode indicator (`↯fast`)
- Git branch display on the header line
- Color-coded progress bars: cyan (normal) / yellow (moderate) / red (high usage)
- Background quota fetching via `fetch-usage.sh` with 60-second cache (`/tmp/claude-usage-cache.json`)
- One-line installer (`setup.sh`) — registers `statusLine` command in `~/.claude/settings.json`
- macOS Keychain integration — reads Anthropic OAuth token via `security find-generic-password`

[1.0.0]: https://github.com/jojo-dan/claude-code-statusline/releases/tag/v1.0.0
