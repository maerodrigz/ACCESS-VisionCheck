import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_splash_gate.dart';
import 'package:access_mobile/shared/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash shows branding, loader, and footer on first frame', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: MobileSplashGate(
          child: Text('signed_in_home'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ACCESS'), findsOneWidget);
    expect(find.text('VisionCheck'), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    expect(find.text(AppConstants.organization), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });
}
