import 'package:access_mobile/mobile_app/screens/edit_profile_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: buildAccessLightTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  testWidgets('verified phone shows status without Verify Number', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tapped = false;
    await tester.pumpWidget(
      wrap(
        EditProfilePhoneStatus(
          verified: true,
          verifying: false,
          enabled: true,
          onVerify: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Phone Verified'), findsOneWidget);
    expect(find.text('Enabled for SMS password recovery.'), findsOneWidget);
    expect(find.text('Verify Number'), findsNothing);
    expect(find.text('Phone Not Verified'), findsNothing);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

    await tester.tap(find.text('Phone Verified'));
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('unverified phone shows Verify Number action', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tapped = false;
    await tester.pumpWidget(
      wrap(
        EditProfilePhoneStatus(
          verified: false,
          verifying: false,
          enabled: true,
          onVerify: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Phone Not Verified'), findsOneWidget);
    expect(find.text('Verify to enable SMS password recovery.'), findsOneWidget);
    expect(find.text('Verify Number'), findsOneWidget);
    expect(find.text('Phone Verified'), findsNothing);

    await tester.tap(find.text('Verify Number'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('verifying state disables duplicate submit label', (tester) async {
    await tester.pumpWidget(
      wrap(
        EditProfilePhoneStatus(
          verified: false,
          verifying: true,
          enabled: false,
          onVerify: () {},
        ),
      ),
    );

    expect(find.text('Sending…'), findsOneWidget);
    expect(find.text('Verify Number'), findsNothing);
  });
}
