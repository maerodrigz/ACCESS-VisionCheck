import 'package:access_mobile/mobile_app/widgets/member_improvement_card.dart';
import 'package:access_mobile/shared/controllers/app_state.dart' hide AiDetectionResult;
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/photo_evaluation_result.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';

Evaluation _v2({
  required double score,
  required DateTime at,
  String mediaType = 'photo',
}) {
  return Evaluation(
    id: 'MED-${at.millisecondsSinceEpoch}-$mediaType',
    title: mediaType == 'video' ? 'clip.mp4' : 'shot.jpg',
    score: score,
    composition: '',
    lighting: '',
    feedback: '',
    date: at.toIso8601String(),
    evaluatedAt: at,
    reviewStatus: 'verified',
    mediaType: mediaType,
    parsedEvaluation: PhotoEvaluationResult(
      overallScore: score * 5,
      qualityLevel: 'Good',
      recommendation: 'Accepted',
      feedback: '',
      improvementSuggestions: '',
      criteria: const [],
      scoringFormulaVersion: 'v2',
      mediaType: mediaType,
      aiDetection: const AiDetectionResult(
        verdict: 'authentic',
        confidence: 0.95,
        detail: '',
      ),
    ),
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  double width = 360,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  // Infinix Note 10 Pro-ish width (~720 logical at 2.0 dpr ≈ 360).
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAccessLightTheme(),
      darkTheme: buildAccessDarkTheme(),
      themeMode: themeMode,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: width,
            child: const MemberImprovementCard(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late List<Evaluation> savedEvaluations;
  late bool savedTabSynced;
  late String? savedTabError;

  setUp(() {
    savedEvaluations = List.of(appState.evaluations);
    savedTabSynced = memberDataController.evaluationsTabSynced;
    savedTabError = memberDataController.evaluationsTabError;
    appState.evaluations.clear();
    memberDataController.evaluationsTabSynced = true;
    memberDataController.evaluationsTabError = null;
  });

  tearDown(() {
    appState.evaluations
      ..clear()
      ..addAll(savedEvaluations);
    memberDataController.evaluationsTabSynced = savedTabSynced;
    memberDataController.evaluationsTabError = savedTabError;
  });

  testWidgets('empty state is compact and has no overflow on small width', (tester) async {
    await _pumpCard(tester, width: 320);
    expect(find.text('My Improvement'), findsOneWidget);
    expect(find.textContaining('Not enough comparable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows latest previous change trend and view details', (tester) async {
    final base = DateTime(2026, 6, 1);
    appState.evaluations.addAll([
      _v2(score: 0.60, at: base),
      _v2(score: 0.72, at: base.add(const Duration(days: 1))),
    ]);

    await _pumpCard(tester, width: 360);
    expect(find.text('My Improvement'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Improving'), findsOneWidget);
    expect(find.textContaining('/5'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme renders without overflow', (tester) async {
    final base = DateTime(2026, 7, 1);
    appState.evaluations.addAll([
      _v2(score: 0.70, at: base),
      _v2(score: 0.68, at: base.add(const Duration(days: 1))),
    ]);
    await _pumpCard(tester, width: 360, themeMode: ThemeMode.dark);
    expect(find.text('Stable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
