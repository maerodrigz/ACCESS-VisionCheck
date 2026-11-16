import 'package:access_mobile/mobile_app/widgets/access_global_background.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RequestorBrandAppBar is transparent over global background',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          home: AccessGlobalBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RequestorBrandAppBar(),
                  Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final brandBar = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(RequestorBrandAppBar),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(brandBar.color, Colors.transparent);
    expect(find.text('ACCESS'), findsOneWidget);
    expect(find.text('VisionCheck'), findsOneWidget);
    expect(find.byType(AccessGlobalBackground), findsOneWidget);
  });
}
