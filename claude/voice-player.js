// ─── CLAUDE CODE VOICE PLAYER ───────────────────────────────
// Plays one audio file and holds it paused while the pause file exists.
// Usage: osascript -l JavaScript voice-player.js <audio-file> <pause-file>
ObjC.import('AVFoundation');

function run(argv) {
  const files = $.NSFileManager.defaultManager;
  const url = $.NSURL.fileURLWithPath(argv[0]);
  const player = $.AVAudioPlayer.alloc.initWithContentsOfURLError(url, null);
  if (player.isNil()) return;
  let paused = null;
  for (;;) {
    const wantPause = !!files.fileExistsAtPath(argv[1]);
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
