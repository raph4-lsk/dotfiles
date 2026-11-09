#!/bin/bash
# ─── CLAUDE CODE STATUSLINE ─────────────────────────────────
# Model │ dir │ branch │ PR │ context │ cost │ limits │ agents
# Single jq call per run; git cached 5 s per session; agent counters
# come from the file written by subagent-statusline.sh.

umask 077

input=$(cat)

F=()
while IFS= read -r line; do F+=("$line"); done < <(jq -r '
  def s: if . == null then "" else tostring | gsub("[[:cntrl:]]"; " ") end;
  def n: if type == "number" then floor | tostring else "" end;
  (.model.display_name | s),
  (.workspace.current_dir // .cwd | s),
  (.workspace.repo.host | s),
  (.workspace.repo.owner | s),
  (.workspace.repo.name | s),
  (.pr.number | s),
  (.pr.url | s),
  (.pr.review_state | s),
  (.context_window.used_percentage | n),
  (.cost.total_cost_usd | if type == "number" then . * 100 | round | tostring else "" end),
  (.rate_limits.five_hour.used_percentage | n),
  (.rate_limits.seven_day.used_percentage | n),
  (.session_id | s)
' <<<"$input" 2>/dev/null)

MODEL=${F[0]}     DIR=${F[1]}
R_HOST=${F[2]}    R_OWNER=${F[3]}   R_NAME=${F[4]}
PR=${F[5]}        PR_URL=${F[6]}    PR_STATE=${F[7]}
CTX=${F[8]}       CENTS=${F[9]}
RL5=${F[10]}      RL7=${F[11]}      SID=${F[12]}

SID=${SID//[!A-Za-z0-9_-]/}
SID=${SID:-default}

E=$'\033'
RESET="$E[0m"; BOLD="$E[1m"; GRAY="$E[90m"
RED="$E[31m"; GREEN="$E[32m"; YELLOW="$E[33m"; MAGENTA="$E[35m"
VIOLET="$E[38;2;177;121;252m"
SEP=" ${GRAY}│${RESET} "

link() { LINK="$E]8;;$1"$'\a'"$2$E]8;;"$'\a'; }

clamp_pct() {
  local p=${1:-0}
  [[ $p =~ ^-?[0-9]+$ ]] || p=0
  (( p < 0 )) && p=0
  (( p > 100 )) && p=100
  PCT=$p
}

level_color() {
  if   (( $1 >= 80 )); then COLOR=$RED
  elif (( $1 >= 50 )); then COLOR=$YELLOW
  else                      COLOR=$GREEN
  fi
}

make_bar() {
  local p=$1 w=$2 f e
  f=$(( p * w / 100 ))
  (( p > 0 && f == 0 )) && f=1
  e=$(( w - f ))
  BAR=""
  while (( f-- > 0 )); do BAR+="▰"; done
  while (( e-- > 0 )); do BAR+="▱"; done
}

git_info() {
  local dir=$1 cache=$2 now mtime cdir line xy oid=""
  if [[ -f $cache ]]; then
    now=$(date +%s)
    mtime=$(stat -f %m "$cache" 2>/dev/null || echo 0)
    if (( now - mtime < 5 )); then
      { IFS= read -r cdir; IFS= read -r BRANCH; read -r STAGED; read -r MODIFIED; } <"$cache"
      [[ $cdir == "$dir" ]] && return
    fi
  fi
  BRANCH="" STAGED=0 MODIFIED=0
  while IFS= read -r line; do
    case $line in
      '# branch.oid '*)  oid=${line#'# branch.oid '} ;;
      '# branch.head '*) BRANCH=${line#'# branch.head '} ;;
      [12u]' '*)
        xy=${line:2:2}
        [[ ${xy:0:1} != . ]] && STAGED=$(( STAGED + 1 ))
        [[ ${xy:1:1} != . ]] && MODIFIED=$(( MODIFIED + 1 ))
        ;;
    esac
  done < <(git -C "$dir" --no-optional-locks status --porcelain=v2 --branch -uno 2>/dev/null)
  [[ $BRANCH == '(detached)' ]] && BRANCH=${oid:0:7}
  printf '%s\n%s\n%s\n%s\n' "$dir" "$BRANCH" "$STAGED" "$MODIFIED" >"$cache.$$" 2>/dev/null \
    && mv -f "$cache.$$" "$cache" 2>/dev/null
}

SEGS=()

MODEL=${MODEL%% (*}
[[ -n $MODEL ]] && SEGS+=("${VIOLET}${BOLD}${MODEL}${RESET}")

if [[ -n $DIR ]]; then
  name=${DIR##*/}
  link "file://${DIR// /%20}" "${name:-/}"
  SEGS+=("$LINK")
fi

if [[ -n $DIR && -d $DIR ]]; then
  CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline"
  [[ -d $CACHE_DIR ]] || mkdir -p -m 700 "$CACHE_DIR" 2>/dev/null
  git_info "$DIR" "$CACHE_DIR/git-$SID.cache"
  if [[ -n $BRANCH ]]; then
    text="⎇ $BRANCH"
    if [[ -n $R_HOST && -n $R_OWNER && -n $R_NAME ]]; then
      link "https://$R_HOST/$R_OWNER/$R_NAME/tree/$BRANCH" "$text"
      text=$LINK
    fi
    seg="${MAGENTA}${text}${RESET}"
    (( STAGED > 0 ))   && seg+=" ${GREEN}+${STAGED}${RESET}"
    (( MODIFIED > 0 )) && seg+=" ${YELLOW}~${MODIFIED}${RESET}"
    SEGS+=("$seg")
  fi
fi

if [[ -n $PR ]]; then
  case $PR_STATE in
    approved)          COLOR=$GREEN ;;
    changes_requested) COLOR=$RED ;;
    pending)           COLOR=$YELLOW ;;
    draft)             COLOR=$GRAY ;;
    *)                 COLOR="" ;;
  esac
  text="PR #$PR"
  if [[ -n $PR_URL ]]; then link "$PR_URL" "$text"; text=$LINK; fi
  SEGS+=("${COLOR}${text}${RESET}")
fi

if [[ -n $CTX ]]; then
  clamp_pct "$CTX"
  level_color "$PCT"
  make_bar "$PCT" 10
  SEGS+=("${COLOR}${BAR} ${PCT}%${RESET}")
fi

if [[ $CENTS =~ ^[0-9]+$ ]]; then
  printf -v cost '$%d.%02d' $(( CENTS / 100 )) $(( CENTS % 100 ))
  SEGS+=("${GRAY}${cost}${RESET}")
fi

for pair in "5h:$RL5" "7j:$RL7"; do
  v=${pair#*:}
  [[ $v =~ ^[0-9]+$ ]] || continue
  (( v < 60 )) && continue
  if (( v >= 85 )); then COLOR=$RED; else COLOR=$YELLOW; fi
  SEGS+=("${COLOR}! ${pair%%:*} ${v}%${RESET}")
done

AG_FILE="${CC_AGENTS_DIR:-${TMPDIR:-/tmp}/claude-agents}/agents-$SID.count"
if [[ -r $AG_FILE ]] && read -r a_total a_run a_fail a_done <"$AG_FILE"; then
  for v in a_total a_run a_fail a_done; do
    [[ ${!v} =~ ^[0-9]+$ ]] || eval "$v=0"
  done
  if (( a_total > 0 && a_run + a_fail + a_done > 0 )); then
    seg="${VIOLET}${BOLD}Agents${RESET}"
    (( a_run > 0 ))  && seg+=" ${YELLOW}⟳${a_run}${RESET}"
    (( a_fail > 0 )) && seg+=" ${RED}${BOLD}✗${a_fail}${RESET}"
    (( a_done > 0 )) && seg+=" ${GREEN}✓${a_done}${RESET}"
    SEGS+=("$seg")
  fi
fi

out=""
for seg in "${SEGS[@]}"; do
  [[ -n $out ]] && out+=$SEP
  out+=$seg
done
printf '%s\n' "$out"
