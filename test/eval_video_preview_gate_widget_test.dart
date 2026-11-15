import 'package:access_mobile/mobile_app/widgets/eval_video_playback_chrome.dart';
import 'package:access_mobile/mobile_app/widgets/eval_video_preview_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal stand-in for buffering vs paused chrome overlays.
class _ChromeProbe extends StatelessWidget {
  const _ChromeProbe({required this.kind});

  final EvalVideoChromeKind kind;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        if (evalVideoShowBufferingSpinner(kind))
          const CircularProgressIndicator(key: Key('buffering_spinner')),
        if (evalVideoShowPlayBadge(kind))
          const Icon(Icons.play_arrow, key: Key('play_badge')),
      ],
    );
  }
}

void main() {
  tearDown(() {
    EvalVideoPreviewGate.instance.resetForTest();
  });

  testWidgets('buffering shows spinner and hides play badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _ChromeProbe(kind: EvalVideoChromeKind.buffering),
        ),
      ),
    );
    expect(find.byKey(const Key('buffering_spinner')), findsOneWidget);
    expect(find.byKey(const Key('play_badge')), findsNothing);
  });

  testWidgets('paused shows play badge and no spinner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _ChromeProbe(kind: EvalVideoChromeKind.paused),
        ),
      ),
    );
    expect(find.byKey(const Key('play_badge')), findsOneWidget);
    expect(find.byKey(const Key('buffering_spinner')), findsNothing);
  });

  testWidgets('playing shows neither spinner nor play badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _ChromeProbe(kind: EvalVideoChromeKind.playing),
        ),
      ),
    );
    expect(find.byKey(const Key('play_badge')), findsNothing);
    expect(find.byKey(const Key('buffering_spinner')), findsNothing);
  });

  testWidgets('gate begin/end toggles suspended flag for navigation lifecycle', (tester) async {
    final gate = EvalVideoPreviewGate.instance;
    var suspended = gate.previewsSuspended;
    gate.addListener(() => suspended = gate.previewsSuspended);

    gate.beginFullscreenPlayback();
    await tester.pump();
    expect(suspended, isTrue);

    gate.endFullscreenPlayback();
    await tester.pump();
    expect(suspended, isFalse);
  });
}
