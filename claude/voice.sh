#!/bin/bash
# ─── CLAUDE CODE VOICE ──────────────────────────────────────
# Reads the last Claude reply aloud with ElevenLabs, or the macOS say
# voice when there is no key or the API fails. Opened by clicking 🔊 in
# the statusline (WezTerm); a click during playback stops it.
# The API key lives in the macOS Keychain, never in this repo.

export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
export LC_ALL=en_US.UTF-8
umask 077

VOICE_ID=${CLAUDE_VOICE_ID:-21m00Tcm4TlvDq8ikWAM}
MODEL_ID=${CLAUDE_VOICE_MODEL:-eleven_multilingual_v2}
MAX_CHARS=${CLAUDE_VOICE_MAX:-4000}
KEYCHAIN_SERVICE=elevenlabs-api-key
SAY_VOICES=("${CLAUDE_SAY_VOICE:-}" "Audrey (Premium)" "Audrey (Enhanced)" "Audrey"
  "Flo (French (France))" "Amélie")

sid=${1//[!A-Za-z0-9_-]/}
sid=${sid:-default}
CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline"
SESSION="$CACHE_DIR/session-$sid"
PID_FILE="$CACHE_DIR/voice.pid"
MP3="$CACHE_DIR/voice-$sid.mp3"

notify() {
  osascript -e "display notification \"$1\" with title \"Claude voice\"" >/dev/null 2>&1
}

if [[ -r $PID_FILE ]]; then
  read -r old <"$PID_FILE"
  if [[ $old =~ ^[0-9]+$ ]] && ps -p "$old" -o command= 2>/dev/null | grep -q voice.sh; then
    pkill -P "$old" 2>/dev/null
    kill "$old" 2>/dev/null
    rm -f "$PID_FILE"
    exit 0
  fi
fi
echo $$ >"$PID_FILE"
trap 'pkill -P $$ 2>/dev/null; rm -f "$PID_FILE"' EXIT

transcript=""
[[ -r $SESSION ]] && IFS= read -r transcript <"$SESSION"
if [[ ! -r $transcript ]]; then
  notify "Transcript introuvable"
  exit 1
fi

# Text blocks of the assistant since the last real user message.
LAST_REPLY_JQ='
  reduce (inputs | fromjson? | select(.isSidechain != true and .isMeta != true)) as $e ([];
    if $e.type == "user" and ($e.message.content
         | type == "string" or (type == "array" and any(.[]; .type == "text")))
    then []
    elif $e.type == "assistant"
    then . + [$e.message.content[]? | select(.type == "text") | .text]
    else . end)
  | join("\n\n")'

# Turns markdown into speakable text: URLs become their site, code and
# tables are skipped, paths become file names, secrets are masked.
SPEAKABLE_PL='
  use utf8; local $/; $_ = <STDIN>;
  s/```.*?(?:```|\z)/\nBloc de code, je passe.\n/gs;
  s/(?:^[ \t]*\|.*(?:\n|\z))+/Un tableau, je passe.\n/gm;
  s/-----BEGIN [^-]+-----.*?(?:-----END [^-]+-----|\z)/certificat masqué/gs;
  s/\[([^\]\n]+)\]\([^)\s]+\)/$1/g;
  s{<?https?://(?:www\.)?([^/\s)>\]:]+)[^\s)>\]]*?>?(?=[.,;:!?)\]]*(?:\s|\z))}{le site $1}g;
  s/\b(?:sk|pk|rk)[-_][A-Za-z0-9_-]{16,}/secret masqué/g;
  s/\b(?:ghp|gho|ghs|ghu|github_pat|glpat|xox[abprs]|AKIA)[A-Za-z0-9_-]{10,}/secret masqué/g;
  s/\beyJ[\w-]{10,}\.[\w-]{10,}\.[\w-]+/secret masqué/g;
  s/\b((?:pass(?:word)?|pwd|secret|token|api[_-]?key)\s*[=:]\s*)\S+/${1}masqué/gi;
  s{\b[A-Za-z0-9+/_-]{40,}={0,2}}{une longue chaîne}g;
  s{(?:~|\.{1,2})?(?:/[\w.@-]+)+/([\w.@-]+)}{$1}g;
  s{\b(?:[\w.@-]+/)+([\w.2772]*\.\w+)}{$1}g;
  s/\b([\w-]+\.\w+):(\d+)(?:-(\d+))?/"$1 ligne $2" . ($3 ? " à $3" : "")/ge;
  s/`([^`\n]*)`/$1/g;
  s/^[ \t]*#+[ \t]*//gm;
  s/^[ \t]*>[ \t]?//gm;
  s/^[ \t]*[-*_]{3,}[ \t]*$//gm;
  s/^[ \t]*[-*+][ \t]+//gm;
  s/\*\*|__|(?<!\w)\*(?!\s)|(?<!\s)\*(?!\w)//g;
  s/[ \t]*→[ \t]*/, puis /g;
  s/([^\s.!?:;,])[ \t]*$/$1./gm;
  s/\n{3,}/\n\n/g;
  s/[ \t]+/ /g;
  s/^\s+|\s+$//g;
  print;'

text=$(jq -Rrn "$LAST_REPLY_JQ" "$transcript" 2>/dev/null | perl -CSD -e "$SPEAKABLE_PL")
if [[ -z $text ]]; then
  notify "Rien à lire"
  exit 0
fi
if (( ${#text} > MAX_CHARS )); then
  text="${text:0:MAX_CHARS}"
  text="${text%[.!?]*}. La suite est tronquée."
fi

hash=$(printf '%s|%s|%s' "$VOICE_ID" "$MODEL_ID" "$text" | shasum -a 256)
hash=${hash%% *}
cached=""
[[ -r $MP3.sha ]] && read -r cached <"$MP3.sha"

speak_local() {
  local installed v voice=""
  installed=$'\n'$(say -v '?' 2>/dev/null)
  for v in "${SAY_VOICES[@]}"; do
    if [[ -n $v && $installed == *$'\n'"$v "* ]]; then
      voice=$v
      break
    fi
  done
  if [[ -n $voice ]]; then
    say -v "$voice" <<<"$text" &
  else
    say <<<"$text" &
  fi
  wait $!
  exit 0
}

if [[ $cached != "$hash" || ! -s $MP3 ]]; then
  key=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)
  [[ -n $key ]] || speak_local
  body="$CACHE_DIR/voice-$sid.json"
  jq -n --arg t "$text" --arg m "$MODEL_ID" \
    '{text: $t, model_id: $m,
      voice_settings: {stability: 0.6, similarity_boost: 0.75, style: 0, use_speaker_boost: true}}' >"$body"
  code=$(printf 'header = "xi-api-key: %s"\n' "$key" | curl -sS -K - \
    -X POST -H 'Content-Type: application/json' -H 'Accept: audio/mpeg' \
    --data-binary @"$body" -o "$MP3.tmp" -w '%{http_code}' \
    "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_128")
  unset key
  rm -f "$body"
  if [[ $code != 200 ]]; then
    rm -f "$MP3.tmp"
    notify "ElevenLabs a répondu $code, voix macOS"
    speak_local
  fi
  mv -f "$MP3.tmp" "$MP3"
  printf '%s\n' "$hash" >"$MP3.sha"
fi

afplay "$MP3" &
wait $!
