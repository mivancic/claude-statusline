#!/usr/bin/env bash
# Claude Code statusLine command
# Reads JSON from stdin and prints a compact, colored one-line status.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // empty')
project_raw=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // empty')
project=$(echo "$project_raw" | sed "s|$HOME|~|")
effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
version=$(echo "$input" | jq -r '.version // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
org_uuid=$(jq -r '.oauthAccount.organizationUuid // empty' ~/.claude.json 2>/dev/null)
extra_enabled=$(jq -r '.oauthAccount.hasExtraUsageEnabled // false' ~/.claude.json 2>/dev/null)
extra_granted=$(jq -r --arg u "$org_uuid" '.overageCreditGrantCache[$u].info.granted // false' ~/.claude.json 2>/dev/null)
extra_minor=$(jq -r --arg u "$org_uuid" '.overageCreditGrantCache[$u].info.amount_minor_units // empty' ~/.claude.json 2>/dev/null)
extra_currency=$(jq -r --arg u "$org_uuid" '.overageCreditGrantCache[$u].info.currency // "usd"' ~/.claude.json 2>/dev/null)

branch=""
if [ -n "$project_raw" ] && [ -d "$project_raw/.git" -o -f "$project_raw/.git" ]; then
  branch=$(git -C "$project_raw" branch --show-current 2>/dev/null)
fi

fmt_tokens() {
  local n="$1"
  [ -z "$n" ] && return
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.1fM\", $n/1000000}"
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    awk "BEGIN {printf \"%.0fk\", $n/1000}"
  else
    printf '%s' "$n"
  fi
}

email=$(jq -r '.oauthAccount.emailAddress // empty' ~/.claude.json 2>/dev/null)
[ -z "$email" ] && email="$USER"

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_ctx_tokens=$(echo "$input" | jq -r '
  (.context_window.current_usage.input_tokens // 0)
  + (.context_window.current_usage.output_tokens // 0)
  + (.context_window.current_usage.cache_creation_input_tokens // 0)
  + (.context_window.current_usage.cache_read_input_tokens // 0)
  | if . > 0 then . else empty end
')

if [ -n "$total_ctx_tokens" ] && [ "$total_ctx_tokens" -ge 1000 ] 2>/dev/null; then
  ctx_tokens="$(awk "BEGIN {printf \"%.0fk\", $total_ctx_tokens/1000}")"
else
  ctx_tokens="${total_ctx_tokens}"
fi

if [ -n "$used_pct" ]; then
  ctx_pct="$(printf '%.0f' "$used_pct")"
fi

five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

fmt_eta() {
  local target="$1"
  [ -z "$target" ] && return
  local now secs
  now=$(date +%s)
  secs=$((target - now))
  [ "$secs" -le 0 ] && { echo "now"; return; }
  local d=$((secs / 86400))
  local h=$(( (secs % 86400) / 3600 ))
  local m=$(( (secs % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"
  fi
}

reset=$'\033[0m'
dim=$'\033[2m'
cyan=$'\033[38;5;39m'
green=$'\033[38;5;46m'
yellow=$'\033[38;5;220m'
red=$'\033[38;5;196m'

pct_color() {
  local pct="$1"
  if [ -z "$pct" ]; then echo "$dim"; return; fi
  local n
  n=$(printf '%.0f' "$pct" 2>/dev/null)
  if   [ "$n" -ge 85 ] 2>/dev/null; then echo "$red"
  elif [ "$n" -ge 60 ] 2>/dev/null; then echo "$yellow"
  else echo "$green"
  fi
}

parts=()

parts+=("${dim}${email}${reset}")

if [ -n "$project" ]; then
  parts+=("${dim}${project}${reset}")
fi

if [ -n "$model" ]; then
  if [ -n "$effort" ]; then
    parts+=("${cyan}${model}${reset} ${dim}(${effort})${reset}")
  else
    parts+=("${cyan}${model}${reset}")
  fi
fi

if [ -n "$ctx_pct" ]; then
  ctx_col=$(pct_color "$used_pct")
  if [ -n "$ctx_tokens" ]; then
    parts+=("ctx:${ctx_col}${ctx_tokens}/↑${ctx_pct}%${reset}")
  else
    parts+=("ctx:${ctx_col}↑${ctx_pct}%${reset}")
  fi
fi

if [ -n "$five_pct" ]; then
  col=$(pct_color "$five_pct")
  rem=$(awk "BEGIN {printf \"%.0f\", 100 - $five_pct}")
  eta=""
  if [ "$col" = "$red" ]; then
    t=$(fmt_eta "$five_resets")
    [ -n "$t" ] && eta=" ${red}(${t})${reset}"
  fi
  parts+=("5h:${col}↓${rem}%${reset}${eta}")
fi

if [ -n "$week_pct" ]; then
  col=$(pct_color "$week_pct")
  rem=$(awk "BEGIN {printf \"%.0f\", 100 - $week_pct}")
  eta=""
  if [ "$col" = "$red" ]; then
    t=$(fmt_eta "$week_resets")
    [ -n "$t" ] && eta=" ${red}(${t})${reset}"
  fi
  parts+=("7d:${col}↓${rem}%${reset}${eta}")
fi

sep="${dim} | ${reset}"
out=""
for part in "${parts[@]}"; do
  if [ -z "$out" ]; then
    out="$part"
  else
    out="${out}${sep}${part}"
  fi
done

line2_parts=()
[ -n "$branch" ] && line2_parts+=("${dim}⎇${reset} ${branch}")

if [ -n "$total_in" ] || [ -n "$total_out" ]; then
  in_fmt=$(fmt_tokens "$total_in")
  out_fmt=$(fmt_tokens "$total_out")
  line2_parts+=("${dim}in:${reset}${in_fmt:-0} ${dim}out:${reset}${out_fmt:-0}")
fi

if [ "$extra_enabled" = "true" ] && [ "$extra_granted" = "true" ] && [ -n "$extra_minor" ]; then
  extra_dollars=$(awk "BEGIN {printf \"%.2f\", $extra_minor/100}")
  cur_upper=$(printf '%s' "$extra_currency" | tr '[:lower:]' '[:upper:]')
  line2_parts+=("${dim}credits:${reset}${extra_dollars} ${cur_upper}")
fi

[ -n "$version" ] && line2_parts+=("${dim}v${version}${reset}")

line2=""
for part in "${line2_parts[@]}"; do
  if [ -z "$line2" ]; then
    line2="$part"
  else
    line2="${line2}${sep}${part}"
  fi
done

printf '%s\n' "$out"
[ -n "$line2" ] && printf '%s\n' "$line2"
