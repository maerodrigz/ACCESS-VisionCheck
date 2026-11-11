import 'package:access_mobile/shared/copy/mobile_registration_copy.dart';
import 'package:access_mobile/shared/models/requestor_type.dart';
import 'package:access_mobile/shared/screens/member_registration_screen.dart';
import 'package:access_mobile/shared/screens/organization_registration_screen.dart';
import 'package:access_mobile/shared/widgets/registration_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('member registration has no Email OTP panel and requires phone', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: MemberRegistrationScreen()));
    await tester.pump();

    expect(find.text('Email verification'), findsNothing);
    expect(find.text('Send code'), findsNothing);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.textContaining('SMS password recovery'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('requestor registration has no Email OTP panel and requires phone', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: RequestorRegistrationScreen(requestorType: RequestorType.facultyStaff),
      ),
    );
    await tester.pump();

    expect(find.text('Email verification'), findsNothing);
    expect(find.text('Send code'), findsNothing);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  test('philippine mobile validator accepts common formats', () {
    expect(RegistrationValidators.philippineMobile('09171234567'), isNull);
    expect(RegistrationValidators.philippineMobile('+639171234567'), isNull);
    expect(RegistrationValidators.philippineMobile('9171234567'), isNull);
    expect(RegistrationValidators.philippineMobile('123'), isNotNull);
    expect(RegistrationValidators.philippineMobile(''), isNotNull);
  });

  test('registration copy no longer requires email OTP before submit', () {
    expect(MobileRegistrationCopy.memberSuccessMessage('a@b.com'), contains('pending'));
    expect(MobileRegistrationCopy.memberSuccessMessage('a@b.com'), contains('SMS password recovery'));
  });
}
