#!/bin/bash
# ─── CLAUDE CODE AGENTS WATCH ───────────────────────────────
# Live view of one session: main agent's recent actions, live sub-agent
# stats and each sub-agent's last actions, read from local transcripts.
# Opened by clicking "Agents" in the statusline (WezTerm). q quits.

export LC_ALL=en_US.UTF-8

sid=${1//[!A-Za-z0-9_-]/}
sid=${sid:-default}
SESSION="${TMPDIR:-/tmp}/claude-statusline/session-$sid"
LIVE="${CC_AGENTS_DIR:-${TMPDIR:-/tmp}/claude-agents}/agents-$sid.txt"
MAIN_ACTIONS=${CC_WATCH_MAIN:-8}
SUB_ACTIONS=${CC_WATCH_SUB:-3}
SUB_MAX=${CC_WATCH_SUB_MAX:-6}

E=$'\033'
RESET="$E[0m"; BOLD="$E[1m"; GRAY="$E[90m"
GREEN="$E[32m"; YELLOW="$E[33m"; VIOLET="$E[38;2;177;121;252m"

ACTIONS_JQ='
  def clean: tostring | gsub("[[:cntrl:]]"; " ") | split($home) | join("~");
  def cut: if length > $w then .[0:$w - 1] + "…" else . end;
  def ts: (.timestamp // "") | sub("\\.[0-9]+Z$"; "Z")
          | (try (fromdateiso8601 | strflocaltime("%H:%M:%S")) catch "--:--:--");
  def arg: if type == "object" then
             (.description // .file_path // .path // .pattern // .query // .url
              // .command // .prompt // .subject // "") | clean
           else "" end;
  fromjson? |
  if .type == "assistant" then
    ts as $t | .message.content[]? |
    if .type == "tool_use" then
      "\($t) \u001b[33m→\u001b[0m \(.name)  \u001b[90m\(.input | arg | cut)\u001b[0m"
    elif .type == "text" and (.text | clean | test("\\S")) then
      "\($t) \u001b[90m·\u001b[0m \(.text | clean | cut)"
    else empty end
  elif .type == "user" then
    (.message.content
     | if type == "string" then .
       else [.[]? | select(.type == "text") | .text] | join(" ") end
     | clean) as $p
    | select(($p | test("\\S")) and ($p | startswith("<") | not))
    | "\(ts) \u001b[35m»\u001b[0m \($p | cut)"
  else empty end'

actions() {
  tail -n "$2" "$1" 2>/dev/null \
    | jq -Rr --arg home "$HOME" --argjson w "$W" "$ACTIONS_JQ" 2>/dev/null \
    | tail -n "$3"
}

render() {
  local transcript="" dir="" model="" ctx="" now cols meta jsonl info atype desc done mtime icon
  now=$(date +%s)
  cols=$(tput cols 2>/dev/null || echo 80)
  W=$(( cols - 24 )); (( W < 20 )) && W=20

  if [[ -r $SESSION ]]; then
    { IFS= read -r transcript; IFS= read -r dir; IFS= read -r model; IFS= read -r ctx; } <"$SESSION"
  fi

  FRAME="${VIOLET}${BOLD}Session${RESET}  ${dir:-?}"
  [[ -n $model ]] && FRAME+=" · $model"
  [[ -n $ctx ]] && FRAME+=" · ctx ${ctx}%"
  FRAME+="  ${GRAY}$(date +%H:%M:%S)${RESET}"$'\n'
  if [[ -r $transcript ]]; then
    FRAME+="$(actions "$transcript" 400 "$MAIN_ACTIONS" | sed 's/^/  /')"$'\n'
  else
    FRAME+="  ${GRAY}no transcript yet for session $sid${RESET}"$'\n'
  fi

  if [[ -r $LIVE ]] && (( now - $(stat -f %m "$LIVE" 2>/dev/null || echo 0) <= 30 )); then
    FRAME+=$'\n'"$(cat "$LIVE")"$'\n'
  fi

  local subdir="${transcript%.jsonl}/subagents" n=0
  FRAME+=$'\n'"${VIOLET}${BOLD}Sub-agents${RESET}"$'\n'
  while IFS= read -r meta; do
    [[ -n $meta ]] || continue
    n=$(( n + 1 ))
    jsonl=${meta%.meta.json}.jsonl
    info=$(jq -r '(.agentType // "agent"), (.description // ""), (.finished // "" | tostring)' "$meta" 2>/dev/null)
    { IFS= read -r atype; IFS= read -r desc; IFS= read -r done; } <<<"$info"
    mtime=$(stat -f %m "$jsonl" 2>/dev/null || echo 0)
    if   [[ $done == true ]];          then icon="${GREEN}✓${RESET}"
    elif (( now - mtime > 300 ));      then icon="${GRAY}?${RESET}"
    else                                    icon="${YELLOW}⟳${RESET}"
    fi
    FRAME+="$icon ${BOLD}${atype}${RESET}  ${GRAY}${desc}${RESET}"$'\n'
    FRAME+="$(actions "$jsonl" 150 "$SUB_ACTIONS" | sed 's/^/  /')"$'\n'
  done < <(ls -t "$subdir"/agent-*.meta.json 2>/dev/null | head -n "$SUB_MAX")
  (( n == 0 )) && FRAME+="  ${GRAY}none in this session${RESET}"$'\n'
}

printf '\033[?1049h\033[?25l'
trap 'printf "\033[?25h\033[?1049l"' EXIT

while :; do
  render
  FRAME+=$'\n'"${GRAY}q to quit${RESET}"
  printf '\033[H%s\033[J' "${FRAME//$'\n'/$'\033[K\n'}"
  if read -rsn1 -t 2 key && [[ $key == q ]]; then break; fi
done
