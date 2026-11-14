// ─── CLAUDE CODE VOICE PLAYER ───────────────────────────────
// Plays one audio file, holds it paused while the pause file exists and
// seeks by the seconds listed in the seek file (one line per click,
// negative to rewind). Seeking past either end hands the rest over to the
// next or previous chunk: exit status 3 asks voice.sh for the previous one.
// Usage: osascript -l JavaScript voice-player.js <audio> <pause> <seek> <has-prev>
ObjC.import('AVFoundation');
ObjC.import('stdlib');

const FROM_END = 'end:';

function readSeek(files, path) {
  const seek = { relative: 0, fromEnd: null };
  if (!files.fileExistsAtPath(path)) return seek;
  const raw = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  files.removeItemAtPathError(path, null);
  if (raw.isNil()) return seek;
  for (const line of raw.js.split('\n')) {
    if (line.startsWith(FROM_END)) seek.fromEnd = parseFloat(line.slice(FROM_END.length)) || 0;
    else seek.relative += parseFloat(line) || 0;
  }
  return seek;
}

function writeSeek(path, text) {
  $(text).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}

function run(argv) {
  const [audio, pauseFile, seekFile, hasPrev] = argv;
  const files = $.NSFileManager.defaultManager;
  const player = $.AVAudioPlayer.alloc.initWithContentsOfURLError($.NSURL.fileURLWithPath(audio), null);
  if (player.isNil()) return;
  let paused = null;
  for (;;) {
    const seek = readSeek(files, seekFile);
    if (seek.fromEnd !== null) player.currentTime = Math.max(0, player.duration + seek.fromEnd);
    if (seek.relative !== 0) {
      const target = player.currentTime + seek.relative;
      if (target >= player.duration) {
        writeSeek(seekFile, String(target - player.duration));
        return;
      }
      if (target < 0 && hasPrev === '1') {
        player.stop;
        writeSeek(seekFile, FROM_END + target);
        $.exit(3);
      }
      player.currentTime = Math.max(0, target);
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
