import 'package:access_mobile/mobile_app/widgets/eval_video_playback_chrome.dart';
import 'package:access_mobile/mobile_app/widgets/eval_video_preview_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evalVideoChromeKind', () {
    test('loading takes priority', () {
      expect(
        evalVideoChromeKind(
          loading: true,
          error: false,
          initialized: false,
          isPlaying: false,
          isBuffering: true,
        ),
        EvalVideoChromeKind.loading,
      );
    });

    test('error takes priority over buffering', () {
      expect(
        evalVideoChromeKind(
          loading: false,
          error: true,
          initialized: true,
          isPlaying: false,
          isBuffering: true,
        ),
        EvalVideoChromeKind.error,
      );
    });

    test('buffering is distinct from paused', () {
      expect(
        evalVideoChromeKind(
          loading: false,
          error: false,
          initialized: true,
          isPlaying: false,
          isBuffering: true,
        ),
        EvalVideoChromeKind.buffering,
      );
      expect(
        evalVideoChromeKind(
          loading: false,
          error: false,
          initialized: true,
          isPlaying: true,
          isBuffering: true,
        ),
        EvalVideoChromeKind.buffering,
      );
    });

    test('paused when not playing and not buffering', () {
      expect(
        evalVideoChromeKind(
          loading: false,
          error: false,
          initialized: true,
          isPlaying: false,
          isBuffering: false,
        ),
        EvalVideoChromeKind.paused,
      );
    });

    test('playing when playing and not buffering', () {
      expect(
        evalVideoChromeKind(
          loading: false,
          error: false,
          initialized: true,
          isPlaying: true,
          isBuffering: false,
        ),
        EvalVideoChromeKind.playing,
      );
    });
  });

  group('chrome helpers', () {
    test('play badge only for paused', () {
      expect(evalVideoShowPlayBadge(EvalVideoChromeKind.paused), isTrue);
      expect(evalVideoShowPlayBadge(EvalVideoChromeKind.buffering), isFalse);
      expect(evalVideoShowPlayBadge(EvalVideoChromeKind.playing), isFalse);
      expect(evalVideoShowPlayBadge(EvalVideoChromeKind.loading), isFalse);
    });

    test('spinner for loading and buffering', () {
      expect(evalVideoShowBufferingSpinner(EvalVideoChromeKind.loading), isTrue);
      expect(evalVideoShowBufferingSpinner(EvalVideoChromeKind.buffering), isTrue);
      expect(evalVideoShowBufferingSpinner(EvalVideoChromeKind.paused), isFalse);
      expect(evalVideoShowBufferingSpinner(EvalVideoChromeKind.playing), isFalse);
    });

    test('does not re-issue play while already playing', () {
      expect(
        evalVideoShouldIssuePlay(
          isPlaying: true,
          isBuffering: true,
          userWantsPlay: true,
        ),
        isFalse,
      );
      expect(
        evalVideoShouldIssuePlay(
          isPlaying: false,
          isBuffering: true,
          userWantsPlay: true,
        ),
        isTrue,
      );
    });

    test('pause only while playing', () {
      expect(
        evalVideoShouldIssuePause(isPlaying: true, userWantsPause: true),
        isTrue,
      );
      expect(
        evalVideoShouldIssuePause(isPlaying: false, userWantsPause: true),
        isFalse,
      );
    });
  });

  group('EvalVideoPreviewGate', () {
    tearDown(() {
      EvalVideoPreviewGate.instance.resetForTest();
    });

    test('suspends previews while fullscreen session is open', () {
      final gate = EvalVideoPreviewGate.instance;
      expect(gate.previewsSuspended, isFalse);

      gate.beginFullscreenPlayback();
      expect(gate.previewsSuspended, isTrue);
      expect(gate.fullscreenSessionCount, 1);

      gate.beginFullscreenPlayback();
      expect(gate.fullscreenSessionCount, 2);
      expect(gate.previewsSuspended, isTrue);

      gate.endFullscreenPlayback();
      expect(gate.previewsSuspended, isTrue);

      gate.endFullscreenPlayback();
      expect(gate.previewsSuspended, isFalse);
      expect(gate.fullscreenSessionCount, 0);
    });

    test('endFullscreenPlayback is idempotent at zero', () {
      final gate = EvalVideoPreviewGate.instance;
      gate.endFullscreenPlayback();
      gate.endFullscreenPlayback();
      expect(gate.fullscreenSessionCount, 0);
      expect(gate.previewsSuspended, isFalse);
    });

    test('notifies listeners on begin and end', () {
      final gate = EvalVideoPreviewGate.instance;
      var notifications = 0;
      void listener() => notifications++;
      gate.addListener(listener);
      gate.beginFullscreenPlayback();
      gate.endFullscreenPlayback();
      gate.removeListener(listener);
      expect(notifications, 2);
    });
  });
}
