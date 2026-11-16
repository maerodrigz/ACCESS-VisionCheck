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
  int? requestId,
  String? fileUrl,
}) {
  return EventGalleryMedia(
    id: id,
    fileName: fileName,
    fileType: fileType,
    fileUrl: fileUrl ?? 'https://example.com/$fileName',
    uploadedAt: eventDate ?? DateTime(2026, 1, 1),
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
          eventTitle:
              'Very Long Non-faculty Leadership Seminar With Extra Words',
          fileType: 'image',
          fileName: 'cover.jpg',
          eventDate: DateTime(2026, 11, 6),
          requestId: 10,
        ),
        _media(
          id: 2,
          eventTitle:
              'Very Long Non-faculty Leadership Seminar With Extra Words',
          fileType: 'video',
          fileName: 'clip.mp4',
          eventDate: DateTime(2026, 11, 6),
          requestId: 10,
        ),
        _media(
          id: 3,
          eventTitle: 'Video Only Night',
          fileType: 'video',
          fileName: 'night.mp4',
          eventDate: DateTime(2026, 6, 15),
          requestId: 11,
          fileUrl: '',
        ),
      ]);
    appState.serviceRequests
      ..clear()
      ..addAll([
        ServiceRequest(
          id: '10',
          requestId: 10,
          eventName:
              'Very Long Non-faculty Leadership Seminar With Extra Words',
          eventDate: DateTime(2026, 11, 6),
          requesterName: 'Lin Ti',
          status: 'Completed',
        ),
        ServiceRequest(
          id: '11',
          requestId: 11,
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

  Future<void> pumpGallery(
    WidgetTester tester, {
    Size size = const Size(390, 1600),
  }) async {
    tester.view.physicalSize = size;
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

  testWidgets('requestor album cards are compact horizontal rows',
      (tester) async {
    await pumpGallery(tester);

    expect(
      find.textContaining('Very Long Non-faculty Leadership Seminar'),
      findsWidgets,
    );
    expect(find.text('November 6, 2026'), findsOneWidget);
    expect(find.textContaining('1 photo'), findsOneWidget);
    expect(find.textContaining('1 video'), findsWidgets);
    expect(find.text('Your event'), findsNothing);
    // No full-bleed 16:9 AspectRatio cover for requestor cards.
    expect(find.byType(AspectRatio), findsNothing);
  });

  testWidgets('video-only album still renders without photo cover',
      (tester) async {
    await pumpGallery(tester);

    expect(find.text('Video Only Night'), findsOneWidget);
    expect(find.textContaining('0 photo'), findsOneWidget);
    expect(find.textContaining('1 video'), findsWidgets);
  });

  testWidgets('narrow width keeps horizontal album cards readable',
      (tester) async {
    await pumpGallery(tester, size: const Size(320, 1400));

    expect(find.text('Video Only Night'), findsOneWidget);
    expect(find.textContaining('photo'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping album card opens album details route', (tester) async {
    await pumpGallery(tester);

    await tester.tap(find.text('Video Only Night'));
    await tester.pumpAndSettle();

    // EventAlbumScreen app bar / title content.
    expect(find.text('Video Only Night'), findsWidgets);
  });
}
