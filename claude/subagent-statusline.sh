#!/bin/bash
# ─── CLAUDE CODE SUBAGENT STATUSLINE ────────────────────────
# One row per sub-agent in the Agents panel, plus two per-session files:
# a counter (total running failed done) read by statusline.sh and a
# detail view shown by agents-watch.sh.

umask 077
export LC_ALL=en_US.UTF-8

input=$(cat)

F=()
while IFS= read -r line; do F+=("$line"); done < <(jq -r '
  def s: if . == null then "" else tostring | gsub("[[:cntrl:]]"; " ") end;
  def num: type == "number";
  (.session_id | s),
  (.columns | if num then floor | tostring else "" end),
  (now | strflocaltime("%H:%M:%S")),
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
    (if (.description // "") != "" then .description else .label end | s),
    (.agentType | s),
    (.effort | s),
    (.tokenCount | if num then floor | tostring else "" end),
    (.contextWindowSize | if num then floor | tostring else "" end),
    (.cwd | s),
    (.label | s)
  )
' <<<"$input" 2>/dev/null)

(( ${#F[@]} == 0 )) && exit 0

SID=${F[0]//[!A-Za-z0-9_-]/}
SID=${SID:-default}
COLS=${F[1]:-${COLUMNS:-80}}
[[ $COLS =~ ^[0-9]+$ ]] || COLS=80
UPDATED=${F[2]}

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

format_tokens() {
  local n=$1
  if   (( n >= 1000000 )); then printf -v TOK '%d.%dM' $(( n / 1000000 )) $(( n % 1000000 / 100000 ))
  elif (( n >= 1000 ));    then TOK="$(( n / 1000 ))k"
  else                          TOK=$n
  fi
}

pct_color() {
  if   (( $1 >= 80 )); then COLOR=$RED
  elif (( $1 >= 50 )); then COLOR=$YELLOW
  else                      COLOR=$GREEN
  fi
}

make_bar() {
  local p=$1 w=$2 f j
  f=$(( p * w / 100 )); (( p > 0 && f == 0 )) && f=1
  BAR=""
  for (( j = 0; j < w; j++ )); do
    if (( j < f )); then BAR+="▰"; else BAR+="▱"; fi
  done
}

format_duration() {
  local t=$1
  if   (( t < 60 ));   then DUR="${t}s"
  elif (( t < 3600 )); then printf -v DUR '%dm%02ds' $(( t / 60 )) $(( t % 60 ))
  else                      printf -v DUR '%dh%02dm' $(( t / 3600 )) $(( t % 3600 / 60 ))
  fi
}

PER=14
COUNT=$(( (${#F[@]} - 3) / PER ))
HIDE_DONE=${CC_HIDE_DONE:-1}
N_RUN=0 N_FAIL=0 N_DONE=0
STATE=() VISIBLE=()

for (( i = 0; i < COUNT; i++ )); do
  case ${F[3 + i * PER + 2]} in
    *fail*|*error*)             st=fail; N_FAIL=$(( N_FAIL + 1 )) ;;
    *kill*|*cancel*|*stop*)     st=kill ;;
    *complet*|*done*|*success*) st=done; N_DONE=$(( N_DONE + 1 )) ;;
    *)                          st=run;  N_RUN=$(( N_RUN + 1 )) ;;
  esac
  STATE[i]=$st
  if [[ $st == done && $HIDE_DONE != 0 ]]; then
    emit "${F[3 + i * PER]}" ""
  else
    VISIBLE+=("$i")
  fi
done

for (( k = 0; k < ${#VISIBLE[@]}; k++ )); do
  i=${VISIBLE[k]}
  b=$(( 3 + i * PER ))
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
      pct_color "$pct"; make_bar "$pct" 5
      out+=" ${COLOR}${BAR} ${pct}%${RESET}"; plain+=" $BAR ${pct}%"
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

DETAIL="" TILDE="~"
for (( i = 0; i < COUNT; i++ )); do
  b=$(( 3 + i * PER ))
  name=${F[b + 1]} model=${F[b + 3]} pct=${F[b + 4]} elapsed=${F[b + 5]}
  desc=${F[b + 7]} atype=${F[b + 8]} effort=${F[b + 9]} tokens=${F[b + 10]}
  size=${F[b + 11]} cwd=${F[b + 12]} label=${F[b + 13]}
  case ${STATE[i]} in
    fail) icon="${RED}✗${RESET}" ;;
    kill) icon="${GRAY}■${RESET}" ;;
    done) icon="${GREEN}✓${RESET}" ;;
    *)    icon="${YELLOW}⟳${RESET}" ;;
  esac

  meta=""
  for v in "$atype" "$model" "$effort"; do
    [[ -n $v ]] && meta+="${meta:+ · }$v"
  done
  line="$icon ${BOLD}${name}${RESET}"
  [[ -n $meta ]] && line+="  ${GRAY}${meta}${RESET}"
  if [[ ${STATE[i]} == run && $elapsed =~ ^[0-9]+$ ]]; then
    format_duration "$elapsed"; line+="  $DUR"
  fi
  DETAIL+="$line"$'\n'

  if [[ $pct =~ ^[0-9]+$ ]]; then
    (( pct > 100 )) && pct=100
    pct_color "$pct"; make_bar "$pct" 20
    format_tokens "$tokens"; used=$TOK
    format_tokens "$size"
    DETAIL+="  ${GRAY}context${RESET} ${COLOR}${BAR} ${pct}%${RESET}  ${used}/${TOK}"$'\n'
  elif [[ $tokens =~ ^[0-9]+$ ]]; then
    format_tokens "$tokens"
    DETAIL+="  ${GRAY}tokens${RESET}  $TOK"$'\n'
  fi
  [[ -n $cwd ]]  && DETAIL+="  ${GRAY}cwd${RESET}     ${cwd/#"$HOME"/$TILDE}"$'\n'
  [[ -n $desc ]] && DETAIL+="  ${GRAY}task${RESET}    $desc"$'\n'
  [[ -n $label && $label != "$desc" ]] && DETAIL+="  ${GRAY}now${RESET}     $label"$'\n'
  DETAIL+=$'\n'
done

head="${BOLD}Agents${RESET}"
(( N_RUN > 0 ))  && head+="  ${YELLOW}⟳${N_RUN}${RESET}"
(( N_FAIL > 0 )) && head+="  ${RED}✗${N_FAIL}${RESET}"
(( N_DONE > 0 )) && head+="  ${GREEN}✓${N_DONE}${RESET}"
head+="  ${GRAY}updated ${UPDATED}${RESET}"
(( COUNT == 0 )) && DETAIL="${GRAY}No sub-agent${RESET}"$'\n'

AG_DIR="${CC_AGENTS_DIR:-${TMPDIR:-/tmp}/claude-agents}"
mkdir -p "$AG_DIR" 2>/dev/null && chmod 700 "$AG_DIR" 2>/dev/null
tmp="$AG_DIR/agents-$SID.count.tmp.$$"
printf '%d %d %d %d\n' "$COUNT" "$N_RUN" "$N_FAIL" "$N_DONE" >"$tmp" 2>/dev/null \
  && mv -f "$tmp" "$AG_DIR/agents-$SID.count" 2>/dev/null
tmp="$AG_DIR/agents-$SID.txt.tmp.$$"
printf '%s\n\n%s' "$head" "$DETAIL" >"$tmp" 2>/dev/null \
  && mv -f "$tmp" "$AG_DIR/agents-$SID.txt" 2>/dev/null
exit 0
