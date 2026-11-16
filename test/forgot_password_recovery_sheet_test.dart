import 'package:access_mobile/shared/widgets/forgot_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSheet(WidgetTester tester, {Size size = const Size(360, 740)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ForgotPasswordRecoverySheet(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('step 1 shows compact phone entry and Send SMS Code', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Send SMS Code'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('New password'), findsNothing);
    expect(find.text('Confirm password'), findsNothing);
    expect(find.text('Update password'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('step 1 validates short phone without calling complete', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField).first, '0917');
    await tester.tap(find.text('Send SMS Code'));
    await tester.pump();

    expect(
      find.text('Enter your registered Philippine mobile number.'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small Android viewport without overflow on step 1', (tester) async {
    await pumpSheet(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(find.text('Send SMS Code'), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
