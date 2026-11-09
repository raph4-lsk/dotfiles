#!/bin/bash
# ─── CLAUDE CODE AGENTS WATCH ───────────────────────────────
# Live sub-agent detail view for one session, opened by clicking
# "Agents" in the statusline (WezTerm open-uri handler). q quits.

sid=${1//[!A-Za-z0-9_-]/}
file="${CC_AGENTS_DIR:-${TMPDIR:-/tmp}/claude-agents}/agents-${sid:-default}.txt"

printf '\033[?1049h\033[?25l'
trap 'printf "\033[?25h\033[?1049l"' EXIT

while :; do
  printf '\033[H\033[J'
  if [[ -r $file ]]; then
    cat "$file"
  else
    printf 'No sub-agent data yet for session %s\n' "${sid:-?}"
  fi
  printf '\n\033[90mq to quit\033[0m'
  if read -rsn1 -t 1 key && [[ $key == q ]]; then break; fi
done
