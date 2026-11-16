import 'package:access_mobile/mobile_app/screens/requestor/requestor_feedback_screen.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_feedback_header.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('requestor feedback shows brand bar and scrollable illustrated header',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RequestorFeedbackScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RequestorBrandAppBar), findsOneWidget);
    expect(find.text('ACCESS'), findsOneWidget);
    expect(find.text('VisionCheck'), findsOneWidget);
    expect(find.byType(RequestorFeedbackIllustratedHeader), findsOneWidget);
    expect(find.text('Feedback'), findsOneWidget);
    expect(
      find.text('Share your experience. Help us improve event coverage.'),
      findsOneWidget,
    );
    expect(
      find.text('Rate your documentation team and share how coverage went.'),
      findsNothing,
    );

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(RequestorFeedbackIllustratedHeader),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      kRequestorFeedbackHeaderAsset,
    );

    // Illustrated banner lives inside the scrollable ListView.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(RequestorFeedbackIllustratedHeader),
      ),
      findsOneWidget,
    );
  });
}
