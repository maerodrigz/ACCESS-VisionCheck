import 'package:access_mobile/mobile_app/screens/profile_screen.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    appState.profileName = 'Alex Rivera';
    appState.profileEmail = 'alex@access.edu';
    appState.profileStatus = 'approved';
    appState.profileSkillLevel = 'Intermediate';
    appState.profileRankPosition = 4;
    appState.profilePoints = 820;
    appState.profileEvaluationsCount = 12;
    appState.profileImageUrl = null;
    memberDataController.profileLoaded = true;
    memberDataController.profileLoadAttempted = true;
    memberDataController.profileLoadError = null;
    memberDataController.requestorRatingsLoaded = true;
  });

  tearDown(() {
    appState.profileName = '';
    appState.profileEmail = '';
    appState.profileStatus = '';
    appState.profileSkillLevel = null;
    appState.profileRankPosition = null;
    appState.profilePoints = 0;
    appState.profileEvaluationsCount = 0;
    memberDataController.profileLoaded = false;
    memberDataController.profileLoadAttempted = false;
    memberDataController.requestorRatingsLoaded = false;
  });

  testWidgets('member profile shows compact dashboard sections', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Edit Profile'), findsWidgets);
    expect(find.text('Quick stats'), findsOneWidget);
    expect(find.text('#4'), findsWidgets);
    expect(find.text('820'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Skill progress'), findsOneWidget);
    expect(find.text('My Activity'), findsOneWidget);
    expect(find.text('Evaluations'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Account & Settings'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Account & Settings'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Legal & Privacy'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Log Out'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Log Out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
