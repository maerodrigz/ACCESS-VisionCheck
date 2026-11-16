import 'package:access_mobile/mobile_app/widgets/member_skill_progress_section.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpProgressSection(
  WidgetTester tester, {
  double width = 360,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: width,
              child: const MemberSkillProgressSection(compact: true),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
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

  testWidgets('video filter empty state shows simplified copy without overflow', (tester) async {
    await _pumpProgressSection(tester, width: 360, textScale: 1.3);

    await tester.tap(find.text('Video'));
    await tester.pump();

    expect(find.text('Not enough video evaluations yet'), findsOneWidget);
    expect(
      find.text('Complete at least 2 eligible video evaluations to see your progress.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo and all filters use matching empty copy', (tester) async {
    await _pumpProgressSection(tester);

    await tester.tap(find.text('Photo'));
    await tester.pump();
    expect(find.text('Not enough photo evaluations yet'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.text('Not enough evaluations yet'), findsOneWidget);
  });

  testWidgets('narrow width with large text scale does not overflow', (tester) async {
    await _pumpProgressSection(tester, width: 320, textScale: 1.4);
    await tester.tap(find.text('Video'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
