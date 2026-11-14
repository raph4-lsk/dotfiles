// ─── CLAUDE CODE VOICE PLAYER ───────────────────────────────
// Plays one audio file, holds it paused while the pause file exists and
// jumps ahead by the seconds listed in the seek file (one line per click).
// Usage: osascript -l JavaScript voice-player.js <audio> <pause-file> <seek-file>
ObjC.import('AVFoundation');

function takeSeek(files, path) {
  if (!files.fileExistsAtPath(path)) return 0;
  const raw = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  files.removeItemAtPathError(path, null);
  if (raw.isNil()) return 0;
  return raw.js.split('\n').reduce((sum, line) => sum + (parseFloat(line) || 0), 0);
}

function run(argv) {
  const [audio, pauseFile, seekFile] = argv;
  const files = $.NSFileManager.defaultManager;
  const player = $.AVAudioPlayer.alloc.initWithContentsOfURLError($.NSURL.fileURLWithPath(audio), null);
  if (player.isNil()) return;
  let paused = null;
  for (;;) {
    const seek = takeSeek(files, seekFile);
    if (seek > 0) {
      const target = player.currentTime + seek;
      if (target >= player.duration) {
        const rest = String(target - player.duration);
        $(rest).writeToFileAtomicallyEncodingError(seekFile, true, $.NSUTF8StringEncoding, null);
        return;
      }
      player.currentTime = target;
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
