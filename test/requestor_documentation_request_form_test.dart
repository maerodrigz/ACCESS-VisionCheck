import 'package:access_mobile/mobile_app/screens/requestor/documentation_request_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    DateTime? initialEventDate,
  }) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DocumentationRequestFormScreen(
          initialEventDate: initialEventDate,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact form hides intro and two-step progress', (tester) async {
    await pumpForm(tester);

    expect(find.text('New Documentation Request'), findsOneWidget);
    expect(find.text('Event Details'), findsOneWidget);
    expect(
      find.text('Tell us when and where your event will happen.'),
      findsOneWidget,
    );
    expect(find.text('Request Event Coverage'), findsNothing);
    expect(find.text('Event Information'), findsNothing);
    expect(find.text('Documentation Requirements'), findsNothing);
    expect(find.text('Coverage Needed'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Submit Request'), findsOneWidget);
    expect(find.text('Additional Details (Optional)'), findsOneWidget);
  });

  testWidgets('calendar date prefill is preserved', (tester) async {
    await pumpForm(tester, initialEventDate: DateTime(2026, 12, 1));
    expect(find.textContaining('December'), findsWidgets);
  });

  testWidgets('additional details expand/collapse keeps typed text',
      (tester) async {
    await pumpForm(tester);

    await tester.tap(find.text('Additional Details (Optional)'));
    await tester.pumpAndSettle();

    final descriptionField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText ?? '') ==
              'Describe the event and its purpose...',
    );
    expect(descriptionField, findsOneWidget);
    await tester.enterText(descriptionField, 'Campus celebration details');
    await tester.pump();

    await tester.tap(find.text('Additional Details (Optional)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Additional Details (Optional)'));
    await tester.pumpAndSettle();
    expect(find.text('Campus celebration details'), findsOneWidget);
  });

  testWidgets('submit without coverage shows coverage error', (tester) async {
    await pumpForm(tester, initialEventDate: DateTime(2026, 12, 5));

    final nameField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText ?? '') == 'Enter event name',
    );
    await tester.enterText(nameField, 'Seminar');
    await tester.pump();

    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();

    expect(
      find.text('Select at least one coverage type (Photo or Video).'),
      findsOneWidget,
    );
  });

  testWidgets('photo and video can both be selected', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    // Both options remain visible and tappable after multi-select.
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);

    // Tapping again toggles photo off without clearing video label.
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Video'), findsOneWidget);
  });
}
