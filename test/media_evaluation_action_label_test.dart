import 'package:access_mobile/mobile_app/screens/ai_media_evaluation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('action label follows selected media and the daily limit', () {
    expect(
      mediaEvaluationActionLabel(atLimit: false, hasMedia: false, isVideo: false),
      'Evaluate Media',
    );
    expect(
      mediaEvaluationActionLabel(atLimit: false, hasMedia: true, isVideo: false),
      'Evaluate Photo',
    );
    expect(
      mediaEvaluationActionLabel(atLimit: false, hasMedia: true, isVideo: true),
      'Evaluate Video',
    );
    expect(
      mediaEvaluationActionLabel(atLimit: true, hasMedia: true, isVideo: true),
      'Daily limit reached',
    );
  });

  testWidgets('photo and video screens show Evaluate Media before a file is selected',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AiMediaEvaluationScreen(mode: AiMediaEvaluationMode.photo),
      ),
    );
    await tester.pump();
    expect(find.text('Evaluate Media'), findsOneWidget);
    expect(find.text('Evaluate Photo'), findsNothing);
    expect(find.text('Start AI Evaluation'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: AiMediaEvaluationScreen(mode: AiMediaEvaluationMode.video),
      ),
    );
    await tester.pump();
    expect(find.text('Evaluate Media'), findsOneWidget);
    expect(find.text('Evaluate Video'), findsNothing);
    expect(find.text('Start AI Evaluation'), findsNothing);
  });
}
