# ozn-cc-statusline

A minimal Claude Code status line showing working directory, git branch, quota usage with reset countdowns, model, and context window size, plus a second line with session cost and prompt cache state.

```
› …/ozn/prjs/ozn-cc-statusline ⎇ main  ┊  › 5h  ▁▁▁  3%  ↺ 4h32m  ┊  › 7d  ██▄  72%  ↺ 3d14h  ┊  › Opus 5.5 high think fast (12k/200k · 6%)
› $1.23 · 14m (api 3m) · +156/-23  ┊  › cache 91%  ↺ 47m
```

## What it shows

**Line 1**

| Segment | Meaning |
|---------|---------|
| `[CAVEMAN]` | Badge prefix shown when [caveman](https://github.com/JuliusBrussee/caveman) plugin is active |
| `› dir ⎇ branch` | Working directory (last 3 path segments, capped at 40 chars) + git branch, or short SHA when detached |
| `› 5h` | 5-hour rolling quota: sparkline + % used + time to reset |
| `› 7d` | 7-day rolling quota: sparkline + % used + time to reset |
| `› model effort think fast (used/max · %)` | Model display name + reasoning effort + `think` when extended thinking is on + `fast` when fast mode is on + context window usage and % |

**Line 2** (shown once there is cost, changed lines, or cache data)

| Segment | Meaning |
|---------|---------|
| `› $cost · time (api time) · +added/-removed` | Estimated session cost, session duration, time spent waiting on the API, lines changed. Hidden until there is cost or changed lines |
| `› cache 91%  ↺ 47m` | Prompt cache hit ratio + time until the cache goes cold; `cold` when it has expired (the next request re-caches the conversation). Hidden until the first API response |

Quota and context percentages turn yellow at 70% and red at 90% (`WARN_AT` / `CRIT_AT` at the top of the script).

The cost is Claude Code's client-side estimate at API list price. On a Pro/Max subscription it is not what you are billed.

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

The script receives a JSON payload from Claude Code on stdin and outputs one or two ANSI-colored lines via stdout. A single `jq` call extracts every field; the rest is plain bash, so a refresh takes ~25ms.
