import 'package:access_mobile/mobile_app/screens/evaluation_screen.dart';
import 'package:access_mobile/mobile_app/widgets/evaluation_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/gallery_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';

Evaluation _samplePracticeEvaluation() {
  return Evaluation(
    id: 'MED-100',
    title: 'Practice sunset shot',
    score: 4.2,
    composition: 'Good',
    lighting: 'Good',
    feedback: 'Nice work',
    date: 'Oct 28, 2026',
    imageUrl: 'http://127.0.0.1:3001/api/media/100/stream',
    mediaType: 'photo',
    evaluatedAt: DateTime(2026, 10, 28),
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

  final card = find.ancestor(
    of: find.text('Practice sunset shot'),
    matching: find.byType(MemberDashboardTapScale),
  );
  await tester.ensureVisible(card.first);
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

    setUp(() {
      savedEvaluations = List.of(appState.evaluations);
      savedGallery = List.of(appState.gallery);
      savedTabLoading = memberDataController.evaluationsTabLoading;
      savedTabSynced = memberDataController.evaluationsTabSynced;

      appState.evaluations
        ..clear()
        ..add(_samplePracticeEvaluation());
      appState.gallery.clear();
      memberDataController.evaluationsTabLoading = false;
      memberDataController.evaluationsTabSynced = true;
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
    });

    testWidgets('Recent Evaluations section shows saved evaluations', (tester) async {
      await _pumpEvaluationScreen(tester);

      expect(find.text('Recent Evaluations'), findsOneWidget);
      expect(find.text('Practice sunset shot'), findsWidgets);
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
