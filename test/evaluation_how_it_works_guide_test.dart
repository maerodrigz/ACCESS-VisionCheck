import 'package:access_mobile/mobile_app/widgets/evaluation_how_it_works_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('How It Works uses the updated evaluation steps', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EvaluationHowItWorksGuide())),
    );
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();

    expect(find.text('1. Select Your Media'), findsOneWidget);
    expect(find.text('2. Evaluate Your Media'), findsOneWidget);
    expect(find.text('3. AI-Powered Analysis'), findsOneWidget);
    expect(find.text('4. View Your Results'), findsOneWidget);
    expect(find.textContaining('Evaluate Photo or Evaluate Video'), findsOneWidget);
    expect(find.textContaining('AI Score'), findsOneWidget);
    expect(find.text('Start AI Evaluation'), findsNothing);
    expect(find.textContaining('EfficientNet'), findsNothing);
    expect(
      find.textContaining('not proof that media is authentic or AI-generated'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Potentially AI-generated or suspicious media may be flagged'),
      findsOneWidget,
    );
  });
}
