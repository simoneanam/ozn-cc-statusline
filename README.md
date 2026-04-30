# ozn-cc-statusline

A minimal Claude Code status line showing quota usage, rate limit countdowns, and context window size.

```
› 5h  ▁▁▁  3%  ↺ 4h32m  ┊  › 7d  ████▄▄  72%  ↺ 3d14h  ┊  › claude-sonnet-4-6(12.3k/200.0k)
```

## What it shows

| Segment | Meaning |
|---------|---------|
| `› 5h` | 5-hour rolling quota: sparkline + % used + time to reset |
| `› 7d` | 7-day rolling quota: sparkline + % used + time to reset |
| `› model-id(used/max)` | Current model + context window usage |
| `[CAVEMAN]` | Badge shown when [caveman](https://github.com/JuliusBrussee/caveman) plugin is active |

## Requirements

- Claude Code
- [`jq`](https://jqlang.github.io/jq/)

```bash
# macOS
brew install jq

# Debian/Ubuntu
apt install jq
```

## Install

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/simoneanam/ozn-cc-statusline/main/install.sh | bash
```

**Or clone and run:**

```bash
git clone https://github.com/simoneanam/ozn-cc-statusline.git
cd ozn-cc-statusline
./install.sh
```

Restart Claude Code after install.

## Uninstall

```bash
# If cloned:
./install.sh --uninstall

# Or one-liner:
curl -fsSL https://raw.githubusercontent.com/simoneanam/ozn-cc-statusline/main/install.sh | bash -s -- --uninstall
```

## How it works

`install.sh` copies `statusline-command.sh` to `~/.claude/` and merges the `statusLine` key into `~/.claude/settings.json`. Existing settings are backed up to `settings.json.bak` before any changes.

The script receives a JSON payload from Claude Code on stdin and outputs an ANSI-colored string via stdout.
