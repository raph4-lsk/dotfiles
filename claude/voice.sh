#!/bin/bash
# ─── CLAUDE CODE VOICE ──────────────────────────────────────
# Reads the last Claude reply aloud with ElevenLabs, or the macOS say
# voice when there is no key or the API fails. Driven by the statusline
# buttons (WezTerm): play or resume, pause or resume, skip ahead, replay.
# The API key lives in the macOS Keychain, never in this repo.

export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"
export LC_ALL=en_US.UTF-8
umask 077

VOICE_ID=${CLAUDE_VOICE_ID:-21m00Tcm4TlvDq8ikWAM}
MODEL_ID=${CLAUDE_VOICE_MODEL:-eleven_multilingual_v2}
SKIP_SECONDS=15
KEYCHAIN_SERVICE=elevenlabs-api-key
SAY_VOICES=("${CLAUDE_SAY_VOICE:-}" "Audrey (Premium)" "Audrey (Enhanced)" "Audrey"
  "Flo (French (France))" "Amélie")

sid=${1//[!A-Za-z0-9_-]/}
sid=${sid:-default}
CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline"
SESSION="$CACHE_DIR/session-$sid"
PID_FILE="$CACHE_DIR/voice.pid"
PAUSED_FILE="$CACHE_DIR/voice.paused"
SEEK_FILE="$CACHE_DIR/voice.seek"
PLAYER_JS="${BASH_SOURCE%/*}/voice-player.js"
action=${2:-play}

notify() {
  osascript -e "display notification \"$1\" with title \"Claude voice\"" >/dev/null 2>&1
}

player=""
if [[ -r $PID_FILE ]]; then
  read -r old <"$PID_FILE"
  if [[ $old =~ ^[0-9]+$ ]] && ps -p "$old" -o command= 2>/dev/null | grep -q voice.sh; then
    player=$old
  fi
fi
[[ -n $player ]] || rm -f "$PAUSED_FILE" "$SEEK_FILE"

# The player polls these files, so pausing never freezes the audio mid-buffer.
toggle_pause() {
  if [[ -e $PAUSED_FILE ]]; then
    rm -f "$PAUSED_FILE"
  else
    : >"$PAUSED_FILE"
  fi
}

play_file() {
  osascript -l JavaScript "$PLAYER_JS" "$1" "$PAUSED_FILE" "$SEEK_FILE" >/dev/null 2>&1 &
  wait $!
}

case $action in
  pause)
    [[ -n $player ]] && toggle_pause
    exit 0
    ;;
  skip)
    [[ -n $player ]] && echo "$SKIP_SECONDS" >>"$SEEK_FILE"
    exit 0
    ;;
  play)
    if [[ -n $player ]]; then
      [[ -e $PAUSED_FILE ]] && toggle_pause
      exit 0
    fi
    ;;
  replay)
    if [[ -n $player ]]; then
      children=$(pgrep -P "$player")
      kill -KILL "$player" $children 2>/dev/null
      rm -f "$PAUSED_FILE" "$SEEK_FILE"
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        kill -0 "$player" 2>/dev/null || break
        sleep 0.1
      done
    fi
    ;;
  *)
    exit 1
    ;;
esac

echo $$ >"$PID_FILE"
trap 'pkill -P $$ 2>/dev/null
      read -r owner <"$PID_FILE" 2>/dev/null
      [[ $owner == "$$" ]] && rm -f "$PID_FILE" "$PAUSED_FILE" "$SEEK_FILE"' EXIT

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

text=$(tail -c 3000000 "$transcript" | jq -Rrn "$LAST_REPLY_JQ" 2>/dev/null | perl -CSD -e "$SPEAKABLE_PL")
if [[ -z $text ]]; then
  notify "Rien à lire"
  exit 0
fi

# A short first chunk starts playback fast, the next ones are generated
# while the previous one plays.
CHUNK_PL='
  use utf8; local $/; my $t = <STDIN>; my @out; my $cur = "";
  for my $s (split /(?<=[.!?:;])\s+/, $t) {
    my $max = @out ? 800 : 200;
    if ($cur ne "" && length($cur) + length($s) + 1 > $max) { push @out, $cur; $cur = $s; }
    else { $cur = $cur eq "" ? $s : "$cur $s"; }
  }
  push @out, $cur if $cur ne "";
  print join("\0", @out), "\0";'

CHUNKS=()
while IFS= read -r -d '' c; do
  CHUNKS+=("$c")
done < <(printf '%s' "$text" | perl -CSD -e "$CHUNK_PL")
n=${#CHUNKS[@]}

speak_local() {
  local installed v i voice=()
  installed=$'\n'$(say -v '?' 2>/dev/null)
  for v in "${SAY_VOICES[@]}"; do
    if [[ -n $v && $installed == *$'\n'"$v "* ]]; then
      voice=(-v "$v")
      break
    fi
  done
  for (( i = $1; i < n; i++ )); do
    say "${voice[@]}" -o "$AUDIO_DIR/say-$i.aiff" <<<"${CHUNKS[i]}" && play_file "$AUDIO_DIR/say-$i.aiff"
  done
  exit 0
}

hash=$(printf '%s|%s|%s' "$VOICE_ID" "$MODEL_ID" "$text" | shasum -a 256)
AUDIO_DIR="$CACHE_DIR/voice-$sid-${hash:0:16}"
if [[ ! -d $AUDIO_DIR ]]; then
  for old in "$CACHE_DIR/voice-$sid-"*; do
    [[ -d $old ]] && rm -rf "$old"
  done
  mkdir -p "$AUDIO_DIR"
fi
rm -f "$AUDIO_DIR/failed"

synthesize() {
  local i=$1 prev="" next="" code body="$AUDIO_DIR/$1.json"
  (( i > 0 )) && prev=${CHUNKS[i-1]}
  (( i + 1 < n )) && next=${CHUNKS[i+1]}
  jq -n --arg t "${CHUNKS[i]}" --arg m "$MODEL_ID" --arg p "$prev" --arg x "$next" \
    '{text: $t, model_id: $m, previous_text: $p, next_text: $x,
      voice_settings: {stability: 0.6, similarity_boost: 0.75, style: 0, use_speaker_boost: true}}
     | with_entries(select(.value != ""))' >"$body"
  code=$(printf 'header = "xi-api-key: %s"\n' "$key" | curl -sS -K - \
    -X POST -H 'Content-Type: application/json' -H 'Accept: audio/mpeg' \
    --data-binary @"$body" -o "$AUDIO_DIR/$i.tmp" -w '%{http_code}' \
    "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID?output_format=mp3_44100_128")
  rm -f "$body"
  if [[ $code == 200 ]]; then
    mv -f "$AUDIO_DIR/$i.tmp" "$AUDIO_DIR/$i.mp3"
  else
    rm -f "$AUDIO_DIR/$i.tmp"
    printf '%s\n' "$code" >"$AUDIO_DIR/failed"
    return 1
  fi
}

# Stays one chunk ahead of playback: skipped or unheard text costs no credits.
generate() {
  local i playing
  for (( i = 0; i < n; i++ )); do
    [[ -s $AUDIO_DIR/$i.mp3 ]] && continue
    while read -r playing <"$AUDIO_DIR/playing" 2>/dev/null && (( i > playing + 1 )); do
      sleep 0.2
    done
    synthesize "$i" || return
  done
}

echo 0 >"$AUDIO_DIR/playing"
gen_pid=""
for (( i = 0; i < n; i++ )); do
  if [[ ! -s $AUDIO_DIR/$i.mp3 ]]; then
    key=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)
    [[ -n $key ]] || speak_local 0
    generate &
    gen_pid=$!
    unset key
    break
  fi
done

for (( i = 0; i < n; i++ )); do
  echo "$i" >"$AUDIO_DIR/playing"
  while [[ ! -s $AUDIO_DIR/$i.mp3 ]]; do
    if [[ -e $AUDIO_DIR/failed || -z $gen_pid ]] || ! kill -0 "$gen_pid" 2>/dev/null; then
      [[ -s $AUDIO_DIR/$i.mp3 ]] && break
      code=""
      [[ -r $AUDIO_DIR/failed ]] && read -r code <"$AUDIO_DIR/failed"
      notify "ElevenLabs a répondu ${code:-rien}, voix macOS"
      speak_local "$i"
    fi
    sleep 0.1
  done
  play_file "$AUDIO_DIR/$i.mp3"
done
