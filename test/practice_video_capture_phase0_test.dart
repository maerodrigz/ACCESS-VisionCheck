import 'package:access_mobile/mobile_app/screens/ai_media_evaluation_screen.dart';
import 'package:access_mobile/mobile_app/screens/practice_video_capture_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('video evaluation shows Record Video and Upload from Gallery', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AiMediaEvaluationScreen(mode: AiMediaEvaluationMode.video),
      ),
    );
    await tester.pump();

    expect(find.text('Record Video'), findsOneWidget);
    expect(find.text('Upload from Gallery'), findsOneWidget);
    expect(find.textContaining('Record a video or upload from Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsNothing);
  });

  testWidgets('photo evaluation keeps Camera and does not show Record Video', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AiMediaEvaluationScreen(mode: AiMediaEvaluationMode.photo),
      ),
    );
    await tester.pump();

    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Record Video'), findsNothing);
    expect(find.text('Upload from Gallery'), findsNothing);
  });

  testWidgets('Record Video opens capture screen route', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AiMediaEvaluationScreen(mode: AiMediaEvaluationMode.video),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Record Video'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(PracticeVideoCaptureScreen), findsOneWidget);
    expect(find.text('Record Video'), findsWidgets);
  });

  test('PracticeVideoCaptureResult carries path and name', () {
    const result = PracticeVideoCaptureResult(
      filePath: '/tmp/access_practice_1.mp4',
      fileName: 'access_practice_1.mp4',
    );
    expect(result.filePath, endsWith('.mp4'));
    expect(result.fileName, 'access_practice_1.mp4');
  });
}
