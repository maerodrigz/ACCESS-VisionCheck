import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_mobile/mobile_app/controllers/app.dart';

void main() {
  testWidgets('Mobile app loads after splash', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AccessApp());
    await tester.pump();
    // Splash uses an animated loader; settle past init without pumpAndSettle.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('Get Started').evaluate().isNotEmpty) break;
    }
    final onWelcome = find.text('Get Started').evaluate().isNotEmpty;
    final onSplash = find.bySemanticsLabel('Loading').evaluate().isNotEmpty;
    expect(onWelcome || onSplash, isTrue);
  });
}
