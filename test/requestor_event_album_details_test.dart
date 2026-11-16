import 'package:access_mobile/mobile_app/screens/event_album_screen.dart';
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
  String? eventDescription,
}) {
  return EventGalleryMedia(
    id: id,
    fileName: fileName,
    fileType: fileType,
    fileUrl: 'https://example.com/$fileName',
    uploadedAt: eventDate ?? DateTime(2026, 1, 1),
    eventTitle: eventTitle,
    eventDate: eventDate,
    eventDescription: eventDescription,
    requestId: requestId,
  );
}

EventGalleryAlbum _albumFrom(List<EventGalleryMedia> items) {
  return buildEventGalleryAlbums(items).first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    appState.eventGallery.clear();
    appState.serviceRequests.clear();
    appState.events.clear();
  });

  Future<void> pumpAlbum(
    WidgetTester tester, {
    required EventGalleryAlbum album,
    Size size = const Size(392, 1600),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: EventAlbumScreen(
            album: album,
            requestorMode: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('compact header shows event info without cover AspectRatio',
      (tester) async {
    final items = [
      _media(
        id: 1,
        eventTitle: 'Campus Orientation Day',
        fileType: 'image',
        fileName: 'a.jpg',
        eventDate: DateTime(2026, 11, 6),
        requestId: 21,
        eventDescription: 'Documented orientation sessions for new requestors.',
      ),
      _media(
        id: 2,
        eventTitle: 'Campus Orientation Day',
        fileType: 'video',
        fileName: 'b.mp4',
        eventDate: DateTime(2026, 11, 6),
        requestId: 21,
        eventDescription: 'Documented orientation sessions for new requestors.',
      ),
    ];
    appState.eventGallery.addAll(items);
    final album = _albumFrom(items);

    await pumpAlbum(tester, album: album);

    expect(find.text('Campus Orientation Day'), findsOneWidget);
    expect(find.text('November 6, 2026'), findsOneWidget);
    expect(
      find.text('Documented orientation sessions for new requestors.'),
      findsOneWidget,
    );
    expect(find.text('Your event'), findsOneWidget);
    expect(find.textContaining('1 photo'), findsOneWidget);
    expect(find.textContaining('1 video'), findsOneWidget);
    expect(find.text('Event Media'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    // No oversized cover AspectRatio hero in requestor mode.
    expect(find.byType(AspectRatio), findsNothing);
  });

  testWidgets('0 media shows empty state and zero counts', (tester) async {
    final album = EventGalleryAlbum(
      id: 'req_99',
      name: 'Empty Future Event',
      date: DateTime(2026, 12, 1),
      photoCount: 0,
      videoCount: 0,
      coverUrl: '',
      requestId: 99,
      eventDescription: 'Awaiting uploads.',
    );

    await pumpAlbum(tester, album: album);

    expect(find.text('Empty Future Event'), findsOneWidget);
    expect(find.textContaining('0 photo'), findsOneWidget);
    expect(find.textContaining('0 video'), findsOneWidget);
    expect(find.text('Event Media'), findsOneWidget);
    expect(find.text('No media in this filter'), findsOneWidget);
  });

  testWidgets('1 and 2 media items do not duplicate tiles', (tester) async {
    final one = [
      _media(
        id: 1,
        eventTitle: 'Solo Photo',
        fileType: 'image',
        fileName: 'one.jpg',
        eventDate: DateTime(2026, 5, 1),
        requestId: 31,
      ),
    ];
    appState.eventGallery.addAll(one);
    await pumpAlbum(tester, album: _albumFrom(one));
    expect(find.byType(InkWell), findsWidgets);
    expect(find.text('1'), findsWidgets);

    appState.eventGallery
      ..clear()
      ..addAll([
        _media(
          id: 1,
          eventTitle: 'Pair Shoot',
          fileType: 'image',
          fileName: 'a.jpg',
          eventDate: DateTime(2026, 5, 2),
          requestId: 32,
        ),
        _media(
          id: 2,
          eventTitle: 'Pair Shoot',
          fileType: 'image',
          fileName: 'b.jpg',
          eventDate: DateTime(2026, 5, 2),
          requestId: 32,
        ),
      ]);
    await pumpAlbum(tester, album: _albumFrom(appState.eventGallery));
    expect(find.text('Event Media'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.textContaining('2 photo'), findsOneWidget);
    expect(find.textContaining('0 video'), findsOneWidget);
  });

  testWidgets('photo and video filters use real album media', (tester) async {
    final items = [
      _media(
        id: 1,
        eventTitle: 'Mixed Media Night',
        fileType: 'image',
        fileName: 'p1.jpg',
        eventDate: DateTime(2026, 7, 4),
        requestId: 41,
      ),
      _media(
        id: 2,
        eventTitle: 'Mixed Media Night',
        fileType: 'image',
        fileName: 'p2.jpg',
        eventDate: DateTime(2026, 7, 4),
        requestId: 41,
      ),
      _media(
        id: 3,
        eventTitle: 'Mixed Media Night',
        fileType: 'video',
        fileName: 'v1.mp4',
        eventDate: DateTime(2026, 7, 4),
        requestId: 41,
      ),
    ];
    appState.eventGallery.addAll(items);
    await pumpAlbum(tester, album: _albumFrom(items));

    await tester.tap(find.text('Photos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('No media in this filter'), findsNothing);

    await tester.tap(find.text('Videos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('No media in this filter'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('3-column grid on X695 width; 2 columns when narrow',
      (tester) async {
    final items = List.generate(
      6,
      (i) => _media(
        id: i + 1,
        eventTitle: 'Grid Event',
        fileType: i.isEven ? 'image' : 'video',
        fileName: i.isEven ? 'p$i.jpg' : 'v$i.mp4',
        eventDate: DateTime(2026, 8, 8),
        requestId: 51,
      ),
    );
    appState.eventGallery.addAll(items);

    await pumpAlbum(tester, album: _albumFrom(items), size: const Size(392, 1600));
    final wideGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final wideDelegate =
        wideGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(wideDelegate.crossAxisCount, 3);

    await pumpAlbum(tester, album: _albumFrom(items), size: const Size(320, 1400));
    final narrowGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final narrowDelegate =
        narrowGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(narrowDelegate.crossAxisCount, 2);
  });

  testWidgets('long event name remains readable', (tester) async {
    final items = [
      _media(
        id: 1,
        eventTitle:
            'Very Long Non-faculty Leadership Seminar With Extra Words For Truncation',
        fileType: 'image',
        fileName: 'long.jpg',
        eventDate: DateTime(2026, 9, 9),
        requestId: 61,
      ),
    ];
    appState.eventGallery.addAll(items);
    await pumpAlbum(tester, album: _albumFrom(items), size: const Size(320, 1400));

    expect(
      find.textContaining('Very Long Non-faculty Leadership Seminar'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text scale falls back to 2 columns', (tester) async {
    final items = List.generate(
      3,
      (i) => _media(
        id: i + 1,
        eventTitle: 'Scaled Grid',
        fileType: 'image',
        fileName: 's$i.jpg',
        eventDate: DateTime(2026, 10, 1),
        requestId: 71,
      ),
    );
    appState.eventGallery.addAll(items);
    await pumpAlbum(
      tester,
      album: _albumFrom(items),
      size: const Size(392, 1600),
      textScale: 1.4,
    );

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });
}
