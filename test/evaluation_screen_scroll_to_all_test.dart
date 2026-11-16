import 'package:access_mobile/mobile_app/screens/evaluation_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late List<Evaluation> savedEvaluations;
  late List<GalleryItem> savedGallery;
  late bool savedLoading;
  late bool savedSynced;
  late String? savedError;

  setUp(() {
    savedEvaluations = List.of(appState.evaluations);
    savedGallery = List.of(appState.gallery);
    savedLoading = memberDataController.evaluationsTabLoading;
    savedSynced = memberDataController.evaluationsTabSynced;
    savedError = memberDataController.evaluationsTabError;
    appState.evaluations
      ..clear()
      ..add(
        Evaluation(
          id: 'MED-1',
          title: 'Practice',
          score: 4.2,
          composition: 'Good',
          lighting: 'Good',
          feedback: 'ok',
          date: 'Nov 11, 2026',
          reviewStatus: 'verified_human',
          evaluatedAt: DateTime(2026, 11, 1),
        ),
      );
    appState.gallery.clear();
    memberDataController.evaluationsTabLoading = false;
    memberDataController.evaluationsTabSynced = true;
    memberDataController.evaluationsTabError = null;
  });

  tearDown(() {
    appState.evaluations
      ..clear()
      ..addAll(savedEvaluations);
    appState.gallery
      ..clear()
      ..addAll(savedGallery);
    memberDataController.evaluationsTabLoading = savedLoading;
    memberDataController.evaluationsTabSynced = savedSynced;
    memberDataController.evaluationsTabError = savedError;
  });

  testWidgets('scrollToAllEvaluations reveals All Evaluations section',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var cleared = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 700)),
        child: MaterialApp(
          home: EvaluationScreen(
            scrollToAllEvaluations: true,
            onDidScrollToAllEvaluations: () => cleared = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Media Evaluation'), findsWidgets);
    expect(find.text('All Evaluations'), findsOneWidget);
    // After scroll request settles, host can clear the one-shot flag.
    expect(cleared, isTrue);
    expect(tester.takeException(), isNull);
  });
}
