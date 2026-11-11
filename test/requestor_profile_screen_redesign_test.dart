import 'package:access_mobile/mobile_app/screens/requestor/requestor_profile_screen.dart';
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
    appState.profileName = 'Lin Ti';
    appState.profileEmail = 'lin.ti@example.edu';
    appState.profileImageUrl = null;
    memberDataController.profileLoaded = true;
    memberDataController.profileLoadAttempted = true;
    memberDataController.profileLoadError = null;
  });

  testWidgets('requestor profile shows compact card and Sign Out near footer',
      (tester) async {
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RequestorProfileScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Lin Ti'), findsOneWidget);
    expect(find.text('Organization Requestor'), findsOneWidget);
    expect(find.text('lin.ti@example.edu'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Account & Security'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Legal & Policies'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Content Standards'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Log Out'), findsNothing);

    // Sign Out sits below settings content in the scroll layout.
    final signOutY = tester.getTopLeft(find.text('Sign Out')).dy;
    final changePasswordY = tester.getTopLeft(find.text('Change Password')).dy;
    expect(signOutY, greaterThan(changePasswordY));
  });

  testWidgets('Sign Out opens confirmation dialog', (tester) async {
    tester.view.physicalSize = const Size(392, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RequestorProfileScreen(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign Out?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(
      find.text('Are you sure you want to sign out of your account?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sign Out?'), findsNothing);
  });
}
