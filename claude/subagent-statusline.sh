#!/bin/bash
# ─── CLAUDE CODE SUBAGENT STATUSLINE ────────────────────────
# One row per sub-agent in the Agents panel, plus a counter file
# (total running failed done) read by statusline.sh.

umask 077
export LC_ALL=en_US.UTF-8

input=$(cat)

F=()
while IFS= read -r line; do F+=("$line"); done < <(jq -r '
  def s: if . == null then "" else tostring | gsub("[[:cntrl:]]"; " ") end;
  def num: type == "number";
  (.session_id | s),
  (.columns | if num then floor | tostring else "" end),
  ((.tasks // [])[] |
    (.id | s),
    (if (.name // "") != "" then .name else .type end | s),
    (.status | s | ascii_downcase),
    ([.model // "" | tostring | ascii_downcase | capture("(?<m>opus|sonnet|haiku|fable)")][0].m // ""),
    (if (.tokenCount | num) and (.contextWindowSize | num) and .contextWindowSize > 0
       then .tokenCount * 100 / .contextWindowSize | floor | tostring else "" end),
    (if .startTime | num
       then now - (if .startTime > 1e12 then .startTime / 1000 else .startTime end)
            | floor | if . < 0 then 0 else . end | tostring
       else "" end),
    (.cwd | s | split("/") | map(select(. != "")) | last // ""),
    (if (.description // "") != "" then .description else .label end | s)
  )
' <<<"$input" 2>/dev/null)

(( ${#F[@]} == 0 )) && exit 0

SID=${F[0]//[!A-Za-z0-9_-]/}
SID=${SID:-default}
COLS=${F[1]:-${COLUMNS:-80}}
[[ $COLS =~ ^[0-9]+$ ]] || COLS=80

E=$'\033'
RESET="$E[0m"; BOLD="$E[1m"; GRAY="$E[90m"
RED="$E[31m"; GREEN="$E[32m"; YELLOW="$E[33m"

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$E/\\u001b}
  ESCAPED=$s
}

emit() {
  json_escape "$1"; local id=$ESCAPED
  json_escape "$2"
  printf '{"id":"%s","content":"%s"}\n' "$id" "$ESCAPED"
}

format_duration() {
  local t=$1
  if   (( t < 60 ));   then DUR="${t}s"
  elif (( t < 3600 )); then printf -v DUR '%dm%02ds' $(( t / 60 )) $(( t % 60 ))
  else                      printf -v DUR '%dh%02dm' $(( t / 3600 )) $(( t % 3600 / 60 ))
  fi
}

PER=8
COUNT=$(( (${#F[@]} - 2) / PER ))
HIDE_DONE=${CC_HIDE_DONE:-1}
N_RUN=0 N_FAIL=0 N_DONE=0
STATE=() VISIBLE=()

for (( i = 0; i < COUNT; i++ )); do
  case ${F[2 + i * PER + 2]} in
    *fail*|*error*)             st=fail; N_FAIL=$(( N_FAIL + 1 )) ;;
    *kill*|*cancel*|*stop*)     st=kill ;;
    *complet*|*done*|*success*) st=done; N_DONE=$(( N_DONE + 1 )) ;;
    *)                          st=run;  N_RUN=$(( N_RUN + 1 )) ;;
  esac
  STATE[i]=$st
  if [[ $st == done && $HIDE_DONE != 0 ]]; then
    emit "${F[2 + i * PER]}" ""
  else
    VISIBLE+=("$i")
  fi
done

for (( k = 0; k < ${#VISIBLE[@]}; k++ )); do
  i=${VISIBLE[k]}
  b=$(( 2 + i * PER ))
  id=${F[b]} name=${F[b + 1]} model=${F[b + 3]} pct=${F[b + 4]}
  elapsed=${F[b + 5]} dir=${F[b + 6]} desc=${F[b + 7]}
  st=${STATE[i]}

  if (( k == ${#VISIBLE[@]} - 1 )); then tree="└─"; else tree="├─"; fi
  case $st in
    fail) icon="${RED}✗${RESET}";  plain_icon="✗" ;;
    kill) icon="${GRAY}■${RESET}"; plain_icon="■" ;;
    done) icon="${GREEN}✓${RESET}"; plain_icon="✓" ;;
    *)    icon="${YELLOW}⟳${RESET}"; plain_icon="⟳" ;;
  esac

  out="$tree $icon ${BOLD}${name}${RESET}"
  plain="$tree $plain_icon $name"
  if [[ -n $model ]]; then out+=" ${GRAY}${model}${RESET}"; plain+=" $model"; fi

  if [[ $st == fail ]]; then
    out+=" ${RED}échec${RESET}"; plain+=" échec"
    if [[ -n $dir ]]; then out+=" ${GRAY}→ ${dir}/${RESET}"; plain+=" → ${dir}/"; fi
  else
    if [[ $pct =~ ^[0-9]+$ ]]; then
      (( pct > 100 )) && pct=100
      if   (( pct >= 80 )); then c=$RED
      elif (( pct >= 50 )); then c=$YELLOW
      else                       c=$GREEN
      fi
      f=$(( pct * 5 / 100 )); (( pct > 0 && f == 0 )) && f=1
      bar=""
      for (( j = 0; j < 5; j++ )); do
        if (( j < f )); then bar+="▰"; else bar+="▱"; fi
      done
      out+=" ${c}${bar} ${pct}%${RESET}"; plain+=" $bar ${pct}%"
    fi
    if [[ $st == run && $elapsed =~ ^[0-9]+$ ]]; then
      format_duration "$elapsed"
      out+=" $DUR"; plain+=" $DUR"
    fi
  fi

  if [[ -n $desc ]]; then
    avail=$(( COLS - ${#plain} - 2 ))
    if (( avail >= 2 )); then
      (( ${#desc} > avail )) && desc="${desc:0:avail-1}…"
      out+="  ${GRAY}${desc}${RESET}"
    fi
  fi

  emit "$id" "$out"
done

AG_DIR="${CC_AGENTS_DIR:-${TMPDIR:-/tmp}/claude-agents}"
mkdir -p "$AG_DIR" 2>/dev/null && chmod 700 "$AG_DIR" 2>/dev/null
tmp="$AG_DIR/agents-$SID.count.tmp.$$"
printf '%d %d %d %d\n' "$COUNT" "$N_RUN" "$N_FAIL" "$N_DONE" >"$tmp" 2>/dev/null \
  && mv -f "$tmp" "$AG_DIR/agents-$SID.count" 2>/dev/null
exit 0
