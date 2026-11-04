import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_mobile/mobile_app/screens/mobile_welcome_screen.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('welcome shows heading, cards, and get started', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: MobileWelcomeScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('VisionCheck!'), findsOneWidget);
    expect(find.textContaining('Welcome to'), findsOneWidget);
    expect(find.text('MEMBER'), findsOneWidget);
    expect(find.text('REQUESTOR'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
