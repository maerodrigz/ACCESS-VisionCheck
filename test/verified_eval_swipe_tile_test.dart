import 'package:access_mobile/mobile_app/widgets/verified_eval_swipe_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VerifiedEvalSwipeTile', () {
    testWidgets('swipe left reveals Delete action', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var open = false;
      var deleteTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return VerifiedEvalSwipeTile(
                      isOpen: open,
                      onOpenChanged: (v) => setState(() => open = v),
                      onDeletePressed: () => deleteTaps++,
                      child: Container(
                        key: const Key('card_body'),
                        height: 72,
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const Text('Verified card'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);

      await tester.drag(find.byKey(const Key('card_body')), const Offset(-90, 0));
      await tester.pumpAndSettle();

      expect(open, isTrue);
      expect(find.byKey(const Key('verified_eval_swipe_delete')), findsOneWidget);

      final delete = find.byKey(const Key('verified_eval_swipe_delete'));
      await tester.ensureVisible(delete);
      await tester.tap(delete, warnIfMissed: false);
      // Prefer a precise hit in the revealed right strip.
      final box = tester.renderObject(delete) as RenderBox;
      final topLeft = box.localToGlobal(Offset.zero);
      await tester.tapAt(topLeft + Offset(box.size.width / 2, box.size.height / 2));
      await tester.pump();
      expect(deleteTaps, greaterThanOrEqualTo(1));
    });

    testWidgets('swipe right closes Delete action', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var open = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return VerifiedEvalSwipeTile(
                      isOpen: open,
                      onOpenChanged: (v) => setState(() => open = v),
                      onDeletePressed: () {},
                      child: Container(
                        key: const Key('card_body'),
                        height: 72,
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const Text('Verified card'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(open, isTrue);

      await tester.drag(find.byKey(const Key('card_body')), const Offset(90, 0));
      await tester.pumpAndSettle();

      expect(open, isFalse);
    });

    testWidgets('photo and video sized cards do not overflow at 360 width',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      for (final label in ['Photo verified', 'Video verified']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: VerifiedEvalSwipeTile(
                  isOpen: true,
                  onOpenChanged: (_) {},
                  onDeletePressed: () {},
                  child: Container(
                    height: 88,
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
