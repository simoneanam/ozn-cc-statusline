#!/usr/bin/env bash
# Claude Code status bar — hairline-mono aesthetic
# Line 1: › dir branch  ┊  › 5h quota  ┊  › 7d quota  ┊  › model effort flags (used/max · %)
# Line 2: › cost  ┊  › prompt cache  (omitted while both are empty)

export LC_ALL=C

# ── color codes (ANSI 256) ────────────────────────────────────────────────────
DIM=$'\033[38;5;247m'      # rgb(140,140,140) — labels (›, 5h, 7d, reset time)
SPARK=$'\033[38;5;253m'    # rgb(220,220,220) — sparkline chars
PCT=$'\033[38;5;254m'      # rgb(228,228,228) — percentage number
SEP_C=$'\033[38;5;238m'    # rgb(70,70,70)   — separator ┊
MODEL_C=$'\033[38;5;254m'  # rgb(228,228,228) — model name + token info
DIR_C=$'\033[38;5;109m'    # rgb(135,175,175) — working directory
EFFORT_C=$'\033[38;5;247m' # rgb(140,140,140) — effort level + thinking
FAST_C=$'\033[38;5;180m'   # rgb(215,175,135) — fast mode
BRANCH_C=$'\033[38;5;139m' # rgb(175,135,175) — git branch
COST_C=$'\033[38;5;254m'   # rgb(228,228,228) — session cost
ADD_C=$'\033[38;5;108m'    # rgb(135,175,135) — lines added
DEL_C=$'\033[38;5;174m'    # rgb(215,135,135) — lines removed
WARN_C=$'\033[38;5;179m'   # rgb(215,175,95)  — usage >= WARN_AT, cold cache
CRIT_C=$'\033[38;5;167m'   # rgb(215,95,95)   — usage >= CRIT_AT
CAVEMAN_C=$'\033[38;5;172m'
RST=$'\033[0m'

# usage thresholds (percent) for quota and context colors
WARN_AT=70
CRIT_AT=90

# ── extract fields ────────────────────────────────────────────────────────────
# One jq call reads stdin and emits shell-quoted assignments; derived values (rounded
# percentages, token counts, seconds left) are computed here too, so the rest
# of the script needs no further subprocesses.

eval "$(jq -r '
  def int: if . == null then "" else round end;
  def left: if . == null then "" else (. - now | floor) end;
  def k: if . < 1000 then (. / 100 | round) as $d | "\($d / 10 | floor).\($d % 10)k"
         else "\(. / 1000 | round)k" end;
  .context_window as $cw | .rate_limits as $rl | .cost as $c | .prompt_cache as $pc |
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "model=\(.model.display_name // .model.id // "")",
  @sh "effort=\(.effort.level // "")",
  @sh "fast=\(.fast_mode // false)",
  @sh "thinking=\(.thinking.enabled // false)",
  @sh "ctx_pct=\($cw.used_percentage | int)",
  @sh "ctx_info=\(if $cw.used_percentage != null and $cw.context_window_size != null
                  then "\($cw.used_percentage * $cw.context_window_size / 100 | k)/\($cw.context_window_size | k)"
                  else "" end)",
  @sh "five_pct=\($rl.five_hour.used_percentage | int)",
  @sh "five_left=\($rl.five_hour.resets_at | left)",
  @sh "week_pct=\($rl.seven_day.used_percentage | int)",
  @sh "week_left=\($rl.seven_day.resets_at | left)",
  @sh "cost_usd=\($c.total_cost_usd // 0)",
  @sh "dur_ms=\($c.total_duration_ms // 0 | floor)",
  @sh "api_ms=\($c.total_api_duration_ms // 0 | floor)",
  @sh "lines_add=\($c.total_lines_added // 0)",
  @sh "lines_del=\($c.total_lines_removed // 0)",
  @sh "cache_seen=\($pc.caching_observed // false)",
  @sh "cache_warm=\($pc.warm // false)",
  @sh "cache_hit=\(if $pc.hit_ratio == null then "" else $pc.hit_ratio * 100 | round end)",
  @sh "cache_left=\($pc.expires_at | left)"
')"

# ── helpers ───────────────────────────────────────────────────────────────────
# Helpers return their result in REPLY instead of printing it: $(...) forks a
# subshell per call, which dominated the runtime.

# level_color <percent_int> <default_color>
# WARN_C / CRIT_C when the threshold is crossed, else the default.
level_color() {
  if [ "$1" -ge "$CRIT_AT" ]; then
    REPLY=$CRIT_C
  elif [ "$1" -ge "$WARN_AT" ]; then
    REPLY=$WARN_C
  else
    REPLY=$2
  fi
}

# make_sparkline <percent_int>
# 3 block chars representing the fill level.
SPARK_BLOCKS=(" " "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
make_sparkline() {
  local p3=$(( $1 * 3 )) i start level
  REPLY=""
  for i in 0 1 2; do
    start=$(( i * 100 ))
    if [ "$p3" -ge $(( start + 100 )) ]; then
      level=8
    elif [ "$p3" -le "$start" ]; then
      level=1
    else
      level=$(( ((p3 - start) * 8 + 50) / 100 ))
      [ "$level" -lt 1 ] && level=1
      [ "$level" -gt 8 ] && level=8
    fi
    REPLY+=${SPARK_BLOCKS[level]}
  done
}

# secs_to_remaining <seconds>
# e.g. "2d3h", "2h07m" or "34m"; "0m" if already elapsed.
secs_to_remaining() {
  local diff=$1
  if [ "$diff" -le 0 ]; then
    REPLY="0m"
    return
  fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    printf -v REPLY '%dd%dh' "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf -v REPLY '%dh%02dm' "$hours" "$mins"
  else
    printf -v REPLY '%dm' "$mins"
  fi
}

# ms_to_duration <milliseconds>
# e.g. "1h05m", "14m" or "40s".
ms_to_duration() {
  local secs=$(( $1 / 1000 ))
  local hours=$(( secs / 3600 ))
  local mins=$(( (secs % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    printf -v REPLY '%dh%02dm' "$hours" "$mins"
  elif [ "$mins" -gt 0 ]; then
    printf -v REPLY '%dm' "$mins"
  else
    printf -v REPLY '%ds' "$secs"
  fi
}

# join_sections <section>...
# Joins the non-empty sections with the separator.
join_sections() {
  local s
  REPLY=""
  for s in "$@"; do
    [ -z "$s" ] && continue
    REPLY="${REPLY:+$REPLY$SEP}$s"
  done
}

# quota_section <label> <percent_int> <seconds_left>
quota_section() {
  local label=$1 pct=$2 left=$3 spark spark_c pct_c remain=""
  if [ -z "$pct" ]; then
    REPLY="${DIM}› ${label}  ---${RST}"
    return
  fi
  if [ -n "$left" ]; then
    secs_to_remaining "$left"
    remain="  ${DIM}↺ ${REPLY}${RST}"
  fi
  make_sparkline "$pct"; spark=$REPLY
  level_color "$pct" "$SPARK"; spark_c=$REPLY
  level_color "$pct" "$PCT"; pct_c=$REPLY
  REPLY="${DIM}› ${label}${RST}  ${spark_c}${spark}${RST}  ${pct_c}${pct}%${RST}${remain}"
}

# ── build sections ────────────────────────────────────────────────────────────

SEP=" ${SEP_C}┊${RST} "

# cwd section: › <last 3 path segments> ⎇ <branch>
if [ -n "$cwd" ]; then
  IFS=/ read -ra parts <<<"${cwd#/}"
  n=${#parts[@]}
  if [ "$n" -gt 3 ]; then
    cwd_disp="…/${parts[n-3]}/${parts[n-2]}/${parts[n-1]}"
  else
    cwd_disp="${cwd#/}"
  fi
  # hard length cap
  [ "${#cwd_disp}" -gt 40 ] && cwd_disp="…${cwd_disp: -39}"
  cwd_sec="${DIM}›${RST} ${DIR_C}${cwd_disp}${RST}"
  # --no-optional-locks: don't take index.lock while Claude runs git too
  branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null \
    || git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && cwd_sec+=" ${BRANCH_C}⎇ ${branch}${RST}"
else
  cwd_sec="${DIM}› dir${RST}"
fi

# Model section: › model effort think fast (used/max · %)
if [ -n "$model" ]; then
  model_sec="${DIM}›${RST} ${MODEL_C}${model}${RST}"
  [ -n "$effort" ] && model_sec+=" ${EFFORT_C}${effort}${RST}"
  [ "$thinking" = "true" ] && model_sec+=" ${EFFORT_C}think${RST}"
  [ "$fast" = "true" ] && model_sec+=" ${FAST_C}fast${RST}"
  if [ -n "$ctx_pct" ] && [ -n "$ctx_info" ]; then
    level_color "$ctx_pct" "$MODEL_C"
    model_sec+="${MODEL_C} (${ctx_info} · ${REPLY}${ctx_pct}%${MODEL_C})${RST}"
  fi
else
  model_sec="${DIM}› model${RST}"
fi

quota_section 5h "$five_pct" "$five_left"; five_sec=$REPLY
quota_section 7d "$week_pct" "$week_left"; week_sec=$REPLY

# Cost section: › $1.23 · 14m (api 3m) · +156/-23
# total_cost_usd is an estimate at API list price, not the subscription bill.
cost_sec=""
if [ "$cost_usd" != "0" ] || [ "$lines_add" -gt 0 ] || [ "$lines_del" -gt 0 ]; then
  printf -v cost_fmt '$%.2f' "$cost_usd"
  cost_sec="${DIM}›${RST} ${COST_C}${cost_fmt}${RST}"
  if [ "$dur_ms" -gt 0 ]; then
    ms_to_duration "$dur_ms"; dur=$REPLY
    ms_to_duration "$api_ms"
    cost_sec+=" ${DIM}· ${dur} (api ${REPLY})${RST}"
  fi
  if [ "$lines_add" -gt 0 ] || [ "$lines_del" -gt 0 ]; then
    cost_sec+=" ${DIM}·${RST} ${ADD_C}+${lines_add}${RST}${DIM}/${RST}${DEL_C}-${lines_del}${RST}"
  fi
fi

# Prompt cache section: › cache 91%  ↺ 47m  (warm)  /  › cache 91% cold
cache_sec=""
if [ "$cache_seen" = "true" ]; then
  cache_sec="${DIM}› cache${RST}"
  [ -n "$cache_hit" ] && cache_sec+=" ${PCT}${cache_hit}%${RST}"
  if [ "$cache_warm" = "true" ]; then
    if [ -n "$cache_left" ]; then
      secs_to_remaining "$cache_left"
      cache_sec+="  ${DIM}↺ ${REPLY}${RST}"
    fi
  else
    cache_sec+=" ${WARN_C}cold${RST}"
  fi
fi

# ── caveman badge ─────────────────────────────────────────────────────────────

caveman_flag="$HOME/.claude/.caveman-active"
caveman_sec=""
if [ -f "$caveman_flag" ]; then
  mode=""
  read -r mode <"$caveman_flag"
  if [ "$mode" = "full" ] || [ -z "$mode" ]; then
    caveman_sec="${CAVEMAN_C}[CAVEMAN]${RST}"
  else
    suffix=$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')
    caveman_sec="${CAVEMAN_C}[CAVEMAN:${suffix}]${RST}"
  fi
fi

# ── assemble lines ────────────────────────────────────────────────────────────

join_sections "$caveman_sec" "$cwd_sec" "$five_sec" "$week_sec" "$model_sec"; line1=$REPLY
join_sections "$cost_sec" "$cache_sec"; line2=$REPLY
printf '%s' "$line1"
[ -n "$line2" ] && printf '\n%s' "$line2"
