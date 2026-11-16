import 'package:access_mobile/mobile_app/screens/gallery_screen.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_gallery_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('requestor gallery shows illustrated header asset and live copy',
      (tester) async {
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

    expect(find.byType(RequestorGalleryIllustratedHeader), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Relive your documented events.'), findsOneWidget);
    expect(find.text('Photos and videos from your documented events.'), findsNothing);

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(RequestorGalleryIllustratedHeader),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      kRequestorGalleryHeaderAsset,
    );

    // Phase 2 chrome still present below the banner.
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Search events or albums...'), findsOneWidget);
  });

  testWidgets('member gallery matches requestor illustrated header chrome',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GalleryScreen(requestorMode: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RequestorGalleryIllustratedHeader), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Browse published event documentation.'), findsOneWidget);
    expect(find.text('Search events or albums...'), findsOneWidget);

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(RequestorGalleryIllustratedHeader),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as AssetImage).assetName,
      kRequestorGalleryHeaderAsset,
    );
  });
}
