import 'package:access_mobile/mobile_app/screens/requestor/requestor_home_screen.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RequestorHomeHeader shows brand, greeting, and real name', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    var notificationsTapped = false;
    var profileTapped = false;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          home: Scaffold(
            body: RequestorHomeHeader(
              displayName: 'Campus Partners Org',
              onNotifications: () => notificationsTapped = true,
              onProfileTap: () => profileTapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ACCESS'), findsOneWidget);
    expect(find.text('VisionCheck'), findsOneWidget);
    expect(find.text('${memberDashboardGreeting()},'), findsOneWidget);
    expect(find.text('Campus Partners Org!'), findsOneWidget);
    expect(
      find.text('Request and track your event documentation.'),
      findsOneWidget,
    );
    expect(find.text('Ready to plan your next event?'), findsNothing);
    expect(find.text('Manage your documentation requests.'), findsNothing);
    expect(find.byIcon(Icons.event_available_rounded), findsNothing);
    expect(find.textContaining('Welcome back'), findsNothing);
    expect(find.byType(Image), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                kRequestorGreetingBackgroundAsset,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pump();
    expect(notificationsTapped, isTrue);

    await tester.tap(find.byType(InkWell).last);
    await tester.pump();
    expect(profileTapped, isTrue);
  });

  testWidgets('Requestor home screen uses transparent header and keeps body sections', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final savedName = appState.profileName;
    appState.profileName = 'Lin Ti Partner';
    addTearDown(() => appState.profileName = savedName);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 1200)),
        child: MaterialApp(
          home: Scaffold(
            body: RequestorHomeScreen(
              userName: 'Session Name',
              onOpenRequestTab: _noopFilter,
              onOpenFeedback: _noopFeedback,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RequestorHomeHeader), findsOneWidget);
    expect(find.byType(RequestorBrandAppBar), findsOneWidget);
    expect(find.byType(RequestorTabHero), findsNothing);
    expect(find.text('Lin Ti Partner!'), findsOneWidget);
    expect(find.text('Need event coverage?'), findsOneWidget);
    expect(
      find.text(
        'Schedule your event in advance and request documentation coverage.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Book ACCESS photographers and videographers for your next event.'),
      findsNothing,
    );
    expect(find.text('Request Overview'), findsOneWidget);
    expect(find.text('Your event documentation requests'), findsOneWidget);
    expect(find.text('Total Requests'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Recent Requests'), findsOneWidget);
    expect(
      find.text('Track your latest documentation requests'),
      findsOneWidget,
    );
    expect(find.text('Upcoming Documentation'), findsOneWidget);

    final brandBar = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(RequestorBrandAppBar),
        matching: find.byType(ColoredBox),
      ).first,
    );
    expect(brandBar.color, Colors.transparent);
  });
}

void _noopFilter({RequestStatus? filter}) {}

void _noopFeedback({int? requestId}) {}
