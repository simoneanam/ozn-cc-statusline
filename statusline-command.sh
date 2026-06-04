#!/usr/bin/env bash
# Claude Code status bar — hairline-mono aesthetic
# Shows: › 5h quota  ┊  › 7d quota  ┊  › model(used/max)

export LC_ALL=C

input=$(cat)

# ── color codes (ANSI 256) ────────────────────────────────────────────────────
DIM=$'\033[38;5;247m'      # rgb(140,140,140) — labels (›, 5h, 7d, reset time)
SPARK=$'\033[38;5;253m'    # rgb(220,220,220) — sparkline chars
PCT=$'\033[38;5;254m'      # rgb(228,228,228) — percentage number
SEP_C=$'\033[38;5;238m'    # rgb(70,70,70)   — separator ┊
MODEL_C=$'\033[38;5;254m'  # rgb(228,228,228) — model name + token info
DIR_C=$'\033[38;5;109m'    # rgb(135,175,175) — working directory
EFFORT_C=$'\033[38;5;247m' # rgb(140,140,140) — effort level
RST=$'\033[0m'

# ── sparkline ─────────────────────────────────────────────────────────────────
# make_sparkline <percent>
# Returns 3 block chars representing the fill level.
make_sparkline() {
  local pct=$1
  awk -v p="$pct" 'BEGIN {
    blocks[0]  = " "
    blocks[1]  = "▁"
    blocks[2]  = "▂"
    blocks[3]  = "▃"
    blocks[4]  = "▄"
    blocks[5]  = "▅"
    blocks[6]  = "▆"
    blocks[7]  = "▇"
    blocks[8]  = "█"
    seg = 100.0 / 3.0
    result = ""
    for (i = 0; i < 3; i++) {
      start = i * seg
      end   = (i + 1) * seg
      if (p >= end) {
        level = 8
      } else if (p <= start) {
        level = 1
      } else {
        level = int((p - start) / seg * 8 + 0.5)
        if (level < 1) level = 1
        if (level > 8) level = 8
      }
      result = result blocks[level]
    }
    printf "%s", result
  }'
}

# ── relative reset time ───────────────────────────────────────────────────────
# epoch_to_remaining <unix_epoch>
# Returns e.g. "2h47m" or "34m" or "" if already elapsed.
epoch_to_remaining() {
  local epoch=$1
  local now
  now=$(date +%s)
  local diff=$(( epoch - now ))
  if [ "$diff" -le 0 ]; then
    echo "0m"
    return
  fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    printf '%dd%dh' "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf '%dh%02dm' "$hours" "$mins"
  else
    printf '%dm' "$mins"
  fi
}

# ── extract fields ────────────────────────────────────────────────────────────

cwd=$(echo "$input"         | jq -r '.cwd // empty')
effort=$(echo "$input"      | jq -r '.effort.level // empty')
model_id=$(echo "$input"    | jq -r '.model.id // empty')
ctx_size=$(echo "$input"    | jq -r '.context_window.context_window_size // empty')
ctx_pct=$(echo "$input"     | jq -r '.context_window.used_percentage // empty')

five_pct=$(echo "$input"    | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input"  | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input"    | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input"  | jq -r '.rate_limits.seven_day.resets_at // empty')

# ── format token counts as e.g. "45.0k" ─────────────────────────────────────
fmt_k() {
  awk -v n="$1" 'BEGIN { printf (n < 1000 ? "%.1fk" : "%.0fk"), n / 1000 }'
}

# ── build sections ────────────────────────────────────────────────────────────

SEP="$(printf ' %s┊%s ' "$SEP_C" "$RST")"

# cwd section: › <basename>
if [ -n "$cwd" ]; then
  cwd_disp=$(awk -v p="$cwd" 'BEGIN {
    n = split(p, a, "/")
    # drop empty leading element from absolute paths
    start = (a[1] == "" ? 2 : 1)
    cnt = n - start + 1
    keep = 3
    out = ""
    from = (cnt > keep ? n - keep + 1 : start)
    for (i = from; i <= n; i++) out = (out == "" ? a[i] : out "/" a[i])
    if (cnt > keep) out = "…/" out
    # hard length cap
    max = 40
    if (length(out) > max) out = "…" substr(out, length(out) - max + 2)
    printf "%s", out
  }')
  cwd_sec="$(printf '%s›%s %s%s%s' "$DIM" "$RST" "$DIR_C" "$cwd_disp" "$RST")"
else
  cwd_sec="$(printf '%s› dir%s' "$DIM" "$RST")"
fi

# 5h section
if [ -n "$five_pct" ]; then
  five_pct_int=$(printf '%.0f' "$five_pct")
  five_spark=$(make_sparkline "$five_pct_int")
  five_remain=""
  if [ -n "$five_reset" ]; then
    five_remain="  $(printf '%s↺ %s%s' "$DIM" "$(epoch_to_remaining "$five_reset")" "$RST")"
  fi
  five_sec="$(printf '%s› 5h%s  %s%s%s  %s%d%%%s%s' \
    "$DIM" "$RST" \
    "$SPARK" "$five_spark" "$RST" \
    "$PCT" "$five_pct_int" "$RST" \
    "$five_remain")"
else
  five_sec="$(printf '%s› 5h  ---%s' "$DIM" "$RST")"
fi

# 7d section
if [ -n "$week_pct" ]; then
  week_pct_int=$(printf '%.0f' "$week_pct")
  week_spark=$(make_sparkline "$week_pct_int")
  week_remain=""
  if [ -n "$week_reset" ]; then
    week_remain="  $(printf '%s↺ %s%s' "$DIM" "$(epoch_to_remaining "$week_reset")" "$RST")"
  fi
  week_sec="$(printf '%s› 7d%s  %s%s%s  %s%d%%%s%s' \
    "$DIM" "$RST" \
    "$SPARK" "$week_spark" "$RST" \
    "$PCT" "$week_pct_int" "$RST" \
    "$week_remain")"
else
  week_sec="$(printf '%s› 7d  ---%s' "$DIM" "$RST")"
fi

# Model section: › model-id(used/max)
if [ -n "$model_id" ]; then
  token_info=""
  if [ -n "$ctx_pct" ] && [ -n "$ctx_size" ]; then
    used_tokens=$(awk -v pct="$ctx_pct" -v size="$ctx_size" \
      'BEGIN { printf "%.0f", pct * size / 100 }')
    ctx_pct_int=$(printf '%.0f' "$ctx_pct")
    token_info=" ($(fmt_k "$used_tokens")/$(fmt_k "$ctx_size") · ${ctx_pct_int}%)"
  fi
  effort_info=""
  if [ -n "$effort" ]; then
    effort_info="$(printf ' %s%s%s' "$EFFORT_C" "$effort" "$RST")"
  fi
  model_sec="$(printf '%s›%s %s%s%s%s%s' \
    "$DIM" "$RST" \
    "$MODEL_C" "$model_id" "$RST" \
    "$effort_info" \
    "$(printf '%s%s%s' "$MODEL_C" "$token_info" "$RST")")"
else
  model_sec="$(printf '%s› model%s' "$DIM" "$RST")"
fi

# ── caveman badge ─────────────────────────────────────────────────────────────

CAVEMAN_C=$'\033[38;5;172m'
caveman_flag="$HOME/.claude/.caveman-active"
caveman_sec=""
if [ -f "$caveman_flag" ]; then
  mode=$(cat "$caveman_flag" 2>/dev/null)
  if [ "$mode" = "full" ] || [ -z "$mode" ]; then
    caveman_sec="$(printf '%s[CAVEMAN]%s' "$CAVEMAN_C" "$RST")${SEP}"
  else
    suffix=$(echo "$mode" | tr '[:lower:]' '[:upper:]')
    caveman_sec="$(printf '%s[CAVEMAN:%s]%s' "$CAVEMAN_C" "$suffix" "$RST")${SEP}"
  fi
fi

# ── assemble line ─────────────────────────────────────────────────────────────

printf '%s%s%s%s%s%s%s%s' \
  "$caveman_sec" \
  "$cwd_sec" "$SEP" \
  "$five_sec" "$SEP" \
  "$week_sec" "$SEP" \
  "$model_sec"
