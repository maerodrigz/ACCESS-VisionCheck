import 'package:access_mobile/mobile_app/screens/gallery_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

EventGalleryMedia _media({
  required int id,
  required String eventTitle,
  required String fileType,
  required String fileName,
  DateTime? eventDate,
  DateTime? uploadedAt,
  int? requestId,
}) {
  return EventGalleryMedia(
    id: id,
    fileName: fileName,
    fileType: fileType,
    fileUrl: 'https://example.com/$fileName',
    uploadedAt: uploadedAt ?? eventDate ?? DateTime(2026, 1, 1),
    eventTitle: eventTitle,
    eventDate: eventDate,
    requestId: requestId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    appState.eventGallery
      ..clear()
      ..addAll([
        _media(
          id: 1,
          eventTitle: 'Old Seminar',
          fileType: 'image',
          fileName: 'old.jpg',
          eventDate: DateTime(2026, 1, 10),
          requestId: 1,
        ),
        _media(
          id: 2,
          eventTitle: 'New Festival',
          fileType: 'image',
          fileName: 'new.jpg',
          eventDate: DateTime(2026, 11, 1),
          requestId: 2,
        ),
        _media(
          id: 3,
          eventTitle: 'New Festival',
          fileType: 'video',
          fileName: 'new.mp4',
          eventDate: DateTime(2026, 11, 1),
          requestId: 2,
        ),
        _media(
          id: 4,
          eventTitle: 'Video Only Night',
          fileType: 'video',
          fileName: 'night.mp4',
          eventDate: DateTime(2026, 6, 15),
          requestId: 3,
        ),
      ]);
    appState.serviceRequests
      ..clear()
      ..addAll([
        ServiceRequest(
          id: '1',
          requestId: 1,
          eventName: 'Old Seminar',
          eventDate: DateTime(2026, 1, 10),
          requesterName: 'Lin Ti',
          status: 'Completed',
        ),
        ServiceRequest(
          id: '2',
          requestId: 2,
          eventName: 'New Festival',
          eventDate: DateTime(2026, 11, 1),
          requesterName: 'Lin Ti',
          status: 'Completed',
        ),
        ServiceRequest(
          id: '3',
          requestId: 3,
          eventName: 'Video Only Night',
          eventDate: DateTime(2026, 6, 15),
          requesterName: 'Lin Ti',
          status: 'Approved',
        ),
      ]);
  });

  tearDown(() {
    appState.eventGallery.clear();
    appState.serviceRequests.clear();
  });

  Future<void> pumpGallery(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GalleryScreen(requestorMode: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows compact stats search filters and sort chrome',
      (tester) async {
    await pumpGallery(tester);

    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Photos'), findsWidgets);
    expect(find.text('Videos'), findsWidgets);
    expect(find.text('Search events or albums...'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Event Albums'), findsOneWidget);
    expect(
      find.textContaining('Newest'),
      findsWidgets,
    );
    expect(find.text('3'), findsWidgets);
    // Unified stats bar: one row of equal columns (not three colored cards).
    expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsWidgets);
    expect(find.byType(VerticalDivider), findsNWidgets(2));
  });

  testWidgets('search filters album names case-insensitively', (tester) async {
    await pumpGallery(tester);

    await tester.enterText(find.byType(TextField), 'festival');
    await tester.pumpAndSettle();

    expect(find.text('New Festival'), findsWidgets);
    expect(find.text('Old Seminar'), findsNothing);
    expect(find.textContaining('result'), findsOneWidget);
  });

  testWidgets('photos filter hides video-only albums', (tester) async {
    await pumpGallery(tester);

    await tester.tap(find.text('Photos').last);
    await tester.pumpAndSettle();

    expect(find.text('Video Only Night'), findsNothing);
    expect(find.text('New Festival'), findsWidgets);
    expect(find.text('Old Seminar'), findsWidgets);
  });

  testWidgets('videos filter shows albums with videos', (tester) async {
    await pumpGallery(tester);

    await tester.tap(find.text('Videos').last);
    await tester.pumpAndSettle();

    expect(find.text('Old Seminar'), findsNothing);
    expect(find.text('Video Only Night'), findsWidgets);
    expect(find.text('New Festival'), findsWidgets);
  });

  testWidgets('sort oldest first reorders albums by event date', (tester) async {
    await pumpGallery(tester);

    await tester.tap(find.textContaining('Newest').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest First').last);
    await tester.pumpAndSettle();

    final names = tester
        .widgetList<Text>(find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Old Seminar' ||
                  w.data == 'New Festival' ||
                  w.data == 'Video Only Night'),
        ))
        .map((t) => t.data!)
        .toList();

    expect(names.first, 'Old Seminar');
    expect(names.contains('New Festival'), isTrue);
  });

  testWidgets('search filter and sort work together', (tester) async {
    await pumpGallery(tester);

    await tester.enterText(find.byType(TextField), 'night');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Videos').last);
    await tester.pumpAndSettle();

    expect(find.text('Video Only Night'), findsWidgets);
    expect(find.text('New Festival'), findsNothing);
    expect(find.text('Old Seminar'), findsNothing);
  });

  testWidgets('empty search state appears for unmatched query', (tester) async {
    await pumpGallery(tester);

    await tester.enterText(find.byType(TextField), 'zzzz-no-match');
    await tester.pumpAndSettle();

    expect(find.text('No matching events'), findsOneWidget);
    expect(find.textContaining('zzzz-no-match'), findsWidgets);
  });
}
