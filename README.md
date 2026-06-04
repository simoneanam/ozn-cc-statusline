# ozn-cc-statusline

A minimal Claude Code status line showing quota usage, rate limit countdowns, working directory, and context window size.

```
› …/ozn/prjs/ozn-cc-statusline  ┊  › 5h  ▁▁▁  3%  ↺ 4h32m  ┊  › 7d  ████▄▄  72%  ↺ 3d14h  ┊  › claude-sonnet-4-6 high (12k/200k · 6%)
```

## What it shows

Segments appear left to right in this order:

| Segment | Meaning |
|---------|---------|
| `[CAVEMAN]` | Badge prefix shown when [caveman](https://github.com/JuliusBrussee/caveman) plugin is active |
| `› dir` | Working directory: last 3 path segments (capped at 40 chars) |
| `› 5h` | 5-hour rolling quota: sparkline + % used + time to reset |
| `› 7d` | 7-day rolling quota: sparkline + % used + time to reset |
| `› model-id effort (used/max · %)` | Current model + reasoning effort + context window usage and % |

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

## Update

Re-run the installer — it overwrites the installed script and re-merges the `statusLine` key (idempotent):

```bash
# If cloned:
git pull && ./install.sh

# Or one-liner:
curl -fsSL https://raw.githubusercontent.com/simoneanam/ozn-cc-statusline/main/install.sh | bash
```

Restart Claude Code to pick up the new version.

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
