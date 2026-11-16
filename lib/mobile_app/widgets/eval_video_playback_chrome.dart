/// Pure playback chrome state for evaluation network video viewers.
///
/// Separates buffering from paused so the UI does not show a play badge while
/// ExoPlayer is still filling buffers.
enum EvalVideoChromeKind {
  loading,
  error,
  buffering,
  playing,
  paused,
}

EvalVideoChromeKind evalVideoChromeKind({
  required bool loading,
  required bool error,
  required bool initialized,
  required bool isPlaying,
  required bool isBuffering,
}) {
  if (loading) return EvalVideoChromeKind.loading;
  if (error) return EvalVideoChromeKind.error;
  if (!initialized) return EvalVideoChromeKind.loading;
  if (isBuffering) return EvalVideoChromeKind.buffering;
  if (isPlaying) return EvalVideoChromeKind.playing;
  return EvalVideoChromeKind.paused;
}

/// Whether the large center play badge should show.
bool evalVideoShowPlayBadge(EvalVideoChromeKind kind) =>
    kind == EvalVideoChromeKind.paused;

/// Whether a buffering spinner should overlay the video surface.
bool evalVideoShowBufferingSpinner(EvalVideoChromeKind kind) =>
    kind == EvalVideoChromeKind.buffering || kind == EvalVideoChromeKind.loading;

/// User-toggled play: avoid spamming [play] while already playing+buffering.
bool evalVideoShouldIssuePlay({
  required bool isPlaying,
  required bool isBuffering,
  required bool userWantsPlay,
}) {
  if (!userWantsPlay) return false;
  if (isPlaying) return false;
  return true;
}

bool evalVideoShouldIssuePause({
  required bool isPlaying,
  required bool userWantsPause,
}) {
  if (!userWantsPause) return false;
  return isPlaying;
}
