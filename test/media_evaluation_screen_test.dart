import 'package:access_mobile/mobile_app/screens/evaluation_screen.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/gallery_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';

Evaluation _samplePracticeEvaluation({
  String id = 'MED-100',
  String title = 'Practice sunset shot',
  String? reviewStatus = 'pending_review',
  DateTime? evaluatedAt,
}) {
  return Evaluation(
    id: id,
    title: title,
    score: 4.2,
    composition: 'Good',
    lighting: 'Good',
    feedback: 'Nice work',
    date: 'Oct 28, 2026',
    imageUrl: 'http://127.0.0.1:3001/api/media/100/stream',
    mediaType: 'photo',
    evaluatedAt: evaluatedAt ?? DateTime(2026, 10, 28),
    reviewStatus: reviewStatus,
  );
}

Future<void> _pumpEvaluationScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const MaterialApp(home: EvaluationScreen()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tapRecentEvaluationCard(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));

  final title = find.text('Practice sunset shot');
  await tester.ensureVisible(title.first);
  final card = find.ancestor(
    of: title.first,
    matching: find.byType(MemberDashboardTapScale),
  );
  await tester.tap(card.first);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Media Evaluation screen', () {
    late List<Evaluation> savedEvaluations;
    late List<GalleryItem> savedGallery;
    late bool savedTabLoading;
    late bool savedTabSynced;
    late int savedToday;
    late int savedLimit;
    late bool savedQuotaConfirmed;
    late String? savedTimezone;

    setUp(() {
      savedEvaluations = List.of(appState.evaluations);
      savedGallery = List.of(appState.gallery);
      savedTabLoading = memberDataController.evaluationsTabLoading;
      savedTabSynced = memberDataController.evaluationsTabSynced;
      savedToday = appState.evaluationsTodayCount;
      savedLimit = appState.dailyEvaluationLimit;
      savedQuotaConfirmed = appState.evaluationsTodayQuotaConfirmed;
      savedTimezone = appState.evaluationDailyTimezone;

      appState.evaluations
        ..clear()
        ..add(_samplePracticeEvaluation());
      appState.gallery.clear();
      memberDataController.evaluationsTabLoading = false;
      memberDataController.evaluationsTabSynced = true;
      appState.applyParticipation(
        evaluationsToday: 0,
        dailyEvaluationLimit: 3,
        evaluationDailyTimezone: 'Asia/Manila',
      );
    });

    tearDown(() {
      appState.evaluations
        ..clear()
        ..addAll(savedEvaluations);
      appState.gallery
        ..clear()
        ..addAll(savedGallery);
      memberDataController.evaluationsTabLoading = savedTabLoading;
      memberDataController.evaluationsTabSynced = savedTabSynced;
      appState.applyParticipation(
        evaluationsToday: savedToday,
        dailyEvaluationLimit: savedLimit,
        evaluationDailyTimezone: savedTimezone,
      );
      if (!savedQuotaConfirmed) {
        // Restore unconfirmed quota state used by some flows.
        appState.evaluationsTodayQuotaConfirmed = false;
      }
    });

    testWidgets('banner and Daily Practice card show live 0/3 counter',
        (tester) async {
      await _pumpEvaluationScreen(tester);

      expect(find.text('Media Evaluation'), findsWidgets);
      expect(
        find.text('Evaluate media to improve your capture quality.'),
        findsOneWidget,
      );
      expect(find.text('Daily Practice'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(find.textContaining('Resets at midnight'), findsOneWidget);
      expect(find.text('3 left'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/evaluation/media_evaluation_bg.png',
        ),
        findsOneWidget,
      );
    });

    testWidgets('banner counter reflects 1 evaluation used', (tester) async {
      appState.applyParticipation(
        evaluationsToday: 1,
        dailyEvaluationLimit: 3,
        evaluationDailyTimezone: 'Asia/Manila',
      );
      await _pumpEvaluationScreen(tester);

      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('2 left'), findsOneWidget);
    });

    testWidgets('banner counter reflects 2 evaluations used', (tester) async {
      appState.applyParticipation(
        evaluationsToday: 2,
        dailyEvaluationLimit: 3,
        evaluationDailyTimezone: 'Asia/Manila',
      );
      await _pumpEvaluationScreen(tester);

      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('1 left'), findsOneWidget);
    });

    testWidgets('banner shows daily limit reached at 3/3', (tester) async {
      appState.applyParticipation(
        evaluationsToday: 3,
        dailyEvaluationLimit: 3,
        evaluationDailyTimezone: 'Asia/Manila',
      );
      await _pumpEvaluationScreen(tester);

      expect(find.text('3/3'), findsOneWidget);
      expect(find.text('Limit reached'), findsOneWidget);
    });

    testWidgets('Photo and Video Evaluation cards render without overflow',
        (tester) async {
      await _pumpEvaluationScreen(tester);

      expect(find.text('Photo Evaluation'), findsOneWidget);
      expect(find.text('Video Evaluation'), findsOneWidget);
      expect(
        find.text('Analyze photo quality and get feedback.'),
        findsOneWidget,
      );
      expect(
        find.text('Analyze video quality and get feedback.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Photo Evaluation card opens photo evaluation flow',
        (tester) async {
      await _pumpEvaluationScreen(tester);

      await tester.ensureVisible(find.text('Photo Evaluation'));
      await tester.tap(find.text('Photo Evaluation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Practice Photo Evaluation'), findsOneWidget);
    });

    testWidgets('Video Evaluation card opens video evaluation flow',
        (tester) async {
      await _pumpEvaluationScreen(tester);

      await tester.ensureVisible(find.text('Video Evaluation'));
      await tester.tap(find.text('Video Evaluation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Practice Video Evaluation'), findsOneWidget);
    });

    testWidgets('Recent Evaluations section shows saved evaluations', (tester) async {
      await _pumpEvaluationScreen(tester);

      expect(find.text('Recent Evaluations'), findsOneWidget);
      expect(find.text('Practice sunset shot'), findsWidgets);
    });

    testWidgets('Recent Evaluations uses cover-flow PageView', (tester) async {
      await _pumpEvaluationScreen(tester);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Practice sunset shot'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('All Evaluations shows heading, segmented tabs, search, and filter',
        (tester) async {
      await _pumpEvaluationScreen(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -640));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('All Evaluations'), findsOneWidget);
      expect(find.text('Pending Verification'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('1 pending'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('Pending and Verified tabs show correct records', (tester) async {
      appState.evaluations
        ..clear()
        ..addAll([
          _samplePracticeEvaluation(
            id: 'MED-100',
            title: 'Practice sunset shot',
            reviewStatus: 'pending_review',
            // Outside Recent carousel window so only All Evaluations lists apply.
            evaluatedAt: DateTime(2025, 6, 1),
          ),
          _samplePracticeEvaluation(
            id: 'MED-101',
            title: 'Verified plaza shot',
            reviewStatus: 'verified_human',
            evaluatedAt: DateTime(2025, 5, 1),
          ),
        ]);

      await _pumpEvaluationScreen(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -720));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('1 pending'), findsOneWidget);
      expect(find.text('Practice sunset shot'), findsOneWidget);
      expect(find.text('Verified plaza shot'), findsNothing);

      await tester.tap(find.text('Verified'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('1 verified'), findsOneWidget);
      expect(find.text('Verified plaza shot'), findsOneWidget);
      expect(find.text('Practice sunset shot'), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });

    testWidgets('All Evaluations search filters compact cards', (tester) async {
      await _pumpEvaluationScreen(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -640));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'zzzz-no-match');
      await tester.pump();

      expect(
        find.text('No evaluations match your search or filter.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'sunset');
      await tester.pump();

      expect(find.text('Practice sunset shot'), findsWidgets);
      expect(
        find.text('No evaluations match your search or filter.'),
        findsNothing,
      );
    });

    testWidgets('tapping evaluation card opens Evaluation Report', (tester) async {
      await _pumpEvaluationScreen(tester);

      await _tapRecentEvaluationCard(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Evaluation Report'), findsOneWidget);
      expect(find.text('View Original'), findsOneWidget);
    });

    testWidgets('tapping report hero does not open zoom viewer', (tester) async {
      await _pumpEvaluationScreen(tester);

      await _tapRecentEvaluationCard(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final thumbs = find.byType(EvaluationMediaThumbnail);
      expect(thumbs, findsWidgets);

      await tester.tap(thumbs.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Evaluation Report'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('GalleryMediaThumbnail stays a passive preview tile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 120,
              child: GalleryMediaThumbnail(
                url: 'http://127.0.0.1:3001/api/media/1/stream',
                isVideo: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GalleryMediaThumbnail), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsNothing);
    });
  });
}
