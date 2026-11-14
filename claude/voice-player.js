// ─── CLAUDE CODE VOICE PLAYER ───────────────────────────────
// Plays one chunk, holds it paused while the pause file exists and obeys
// the "next" / "prev" lines of the command file, one line per click.
// Exit 4 asks voice.sh for the next paragraph, exit 3 for the previous one;
// extra clicks are written back so the following chunk carries them on.
// mode: first (start of reply), start (paragraph start) or inner. "prev"
// restarts first and start chunks in place once past 3 s.
// Usage: osascript -l JavaScript voice-player.js <audio> <pause> <commands> <mode>
ObjC.import('AVFoundation');
ObjC.import('stdlib');

const RESTART_AFTER = 3;

function readMoves(files, path) {
  if (!files.fileExistsAtPath(path)) return 0;
  const raw = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  files.removeItemAtPathError(path, null);
  if (raw.isNil()) return 0;
  return raw.js.split('\n').reduce((net, line) => net + (line === 'next') - (line === 'prev'), 0);
}

function writeMoves(path, moves) {
  if (moves === 0) return;
  const line = moves > 0 ? 'next\n' : 'prev\n';
  $(line.repeat(Math.abs(moves))).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}

function run(argv) {
  const [audio, pauseFile, commandFile, mode] = argv;
  const files = $.NSFileManager.defaultManager;
  const player = $.AVAudioPlayer.alloc.initWithContentsOfURLError($.NSURL.fileURLWithPath(audio), null);
  if (player.isNil()) return;
  let paused = null;
  for (;;) {
    const moves = readMoves(files, commandFile);
    if (moves > 0) {
      player.stop;
      writeMoves(commandFile, moves - 1);
      $.exit(4);
    }
    if (moves < 0) {
      const restart = mode === 'first' || (mode === 'start' && player.currentTime > RESTART_AFTER);
      if (restart) {
        player.currentTime = 0;
        writeMoves(commandFile, mode === 'first' ? 0 : moves + 1);
      } else {
        player.stop;
        writeMoves(commandFile, moves + 1);
        $.exit(3);
      }
    }
    const wantPause = !!files.fileExistsAtPath(pauseFile);
    if (wantPause !== paused) {
      if (wantPause) player.pause;
      else player.play;
      paused = wantPause;
    } else if (!paused && !player.playing) {
      return;
    }
    delay(0.05);
  }
}
