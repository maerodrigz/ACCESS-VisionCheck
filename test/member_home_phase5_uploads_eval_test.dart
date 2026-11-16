import 'package:access_mobile/mobile_app/widgets/member_home_dashboard.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpHome(
  WidgetTester tester, {
  double width = 390,
  VoidCallback? onViewPortfolio,
  VoidCallback? onViewEventGallery,
  VoidCallback? onViewAllRecentUploads,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 1600)),
      child: MaterialApp(
        home: Scaffold(
          body: MemberHomeDashboard(
            userName: 'Shan Lee',
            onViewPortfolio: onViewPortfolio ?? () {},
            onViewEventGallery: onViewEventGallery ?? () {},
            onViewAllRecentUploads: onViewAllRecentUploads,
            onRefresh: () async {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

GalleryItem _item({
  required bool video,
  String title = 'Practice',
}) {
  return GalleryItem(
    title: title,
    category: 'Practice',
    date: 'Nov 10',
    color: const Color(0xFF00C4E8),
    mediaType: video ? MediaType.video : MediaType.photo,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  late List<GalleryItem> savedGallery;
  late bool savedLoading;
  late bool savedSynced;

  setUp(() {
    savedGallery = List.of(appState.gallery);
    savedLoading = memberDataController.evaluationsTabLoading;
    savedSynced = memberDataController.evaluationsTabSynced;
    appState.gallery.clear();
    memberDataController.evaluationsTabLoading = false;
    memberDataController.evaluationsTabSynced = true;
  });

  tearDown(() {
    appState.gallery
      ..clear()
      ..addAll(savedGallery);
    memberDataController.evaluationsTabLoading = savedLoading;
    memberDataController.evaluationsTabSynced = savedSynced;
  });

  testWidgets('compact Recent Uploads and Media Evaluation CTA are present',
      (tester) async {
    await _pumpHome(tester);
    await tester.scrollUntilVisible(
      find.text('Recent Uploads'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Recent Uploads'), findsOneWidget);
    expect(find.text('View All'), findsWidgets);
    expect(find.text('No practice uploads yet.'), findsOneWidget);
    expect(find.text('Start Evaluation'), findsNothing);
    expect(find.text('View Evaluation'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Media Evaluation'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Media Evaluation'), findsOneWidget);
    expect(
      find.text('Check your media quality and get instant feedback.'),
      findsOneWidget,
    );
    expect(find.text('Evaluate Media'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thumbnails show play overlay for videos and keep View All',
      (tester) async {
    appState.gallery.addAll([
      _item(video: false, title: 'Photo A'),
      _item(video: true, title: 'Video B'),
      _item(video: false, title: 'Photo C'),
      _item(video: true, title: 'Video D'),
    ]);

    var galleryTaps = 0;
    var evaluationsTaps = 0;
    await _pumpHome(
      tester,
      onViewEventGallery: () => galleryTaps++,
      onViewAllRecentUploads: () => evaluationsTaps++,
    );
    await tester.scrollUntilVisible(
      find.text('Recent Uploads'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('No practice uploads yet.'), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

    final uploadsViewAll = find.descendant(
      of: find.ancestor(
        of: find.text('Recent Uploads'),
        matching: find.byType(Column),
      ),
      matching: find.text('View All'),
    );
    await tester.ensureVisible(uploadsViewAll.first);
    await tester.tap(uploadsViewAll.first);
    await tester.pump();
    expect(evaluationsTaps, 1);
    expect(galleryTaps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recent Uploads View All prefers evaluations over gallery',
      (tester) async {
    appState.gallery.add(_item(video: false, title: 'Photo A'));

    var galleryTaps = 0;
    var portfolioTaps = 0;
    await _pumpHome(
      tester,
      onViewEventGallery: () => galleryTaps++,
      onViewPortfolio: () => portfolioTaps++,
    );
    await tester.scrollUntilVisible(
      find.text('Recent Uploads'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final uploadsViewAll = find.descendant(
      of: find.ancestor(
        of: find.text('Recent Uploads'),
        matching: find.byType(Column),
      ),
      matching: find.text('View All'),
    );
    await tester.tap(uploadsViewAll.first);
    await tester.pump();

    expect(portfolioTaps, 1);
    expect(galleryTaps, 0);
  });

  testWidgets('Evaluate Media remains tappable', (tester) async {
    var opened = 0;
    await _pumpHome(tester, onViewPortfolio: () => opened++);
    await tester.scrollUntilVisible(
      find.text('Evaluate Media'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(find.text('Evaluate Media'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('narrow width keeps Phase 5 labels readable', (tester) async {
    await _pumpHome(tester, width: 320);
    await tester.scrollUntilVisible(
      find.text('Recent Uploads'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Recent Uploads'), findsOneWidget);
    expect(find.text('Evaluate Media'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
