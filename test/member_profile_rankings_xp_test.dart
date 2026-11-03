import 'package:access_mobile/mobile_app/widgets/member_dashboard_competency_progress.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('rankings section shows rank and XP at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    appState.profileRankPosition = 5;
    appState.profilePoints = 1250;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: MemberProfileRankingsXpSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Rankings & XP'), findsOneWidget);
    expect(find.text('#5'), findsOneWidget);
    expect(find.text('1,250'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  tearDown(() {
    appState.profileRankPosition = null;
    appState.profilePoints = 0;
  });
}
