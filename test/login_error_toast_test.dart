import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_mobile/shared/screens/vision_login_screen.dart';
import 'package:access_mobile/shared/widgets/login/login_error_toast.dart';
import 'package:access_mobile/shared/widgets/login/login_notice_host.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_sign_in_form.dart';

class _HostProbe extends StatefulWidget {
  const _HostProbe({required this.onReady});

  final void Function(_HostProbeState state) onReady;

  @override
  State<_HostProbe> createState() => _HostProbeState();
}

class _HostProbeState extends State<_HostProbe> with LoginNoticeHost<_HostProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady(this));
  }

  @override
  void dispose() {
    disposeLoginNotice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildWithLoginNotice(
      const Scaffold(
        body: Center(child: Text('Login form')),
      ),
    );
  }
}

Widget _app({
  required Widget home,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MaterialApp(
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          viewInsets: viewInsets,
          textScaler: TextScaler.noScaling,
        ),
        child: child!,
      );
    },
    home: home,
  );
}

void main() {
  test('notice durations match product requirements', () {
    expect(LoginNoticeKind.credentials.displayDuration, const Duration(seconds: 3));
    expect(LoginNoticeKind.lockout.displayDuration, const Duration(seconds: 5));
    expect(LoginNoticeKind.network.displayDuration, const Duration(seconds: 4));
    expect(LoginNoticeKind.server.displayDuration, const Duration(seconds: 4));
  });

  test('lockoutSupportingMessage uses backend remaining minutes', () {
    expect(
      lockoutSupportingMessage(
        'Account temporarily locked due to too many failed sign-in attempts. '
        'Try again in about 18 minutes.',
      ),
      'Please try again in 18 minutes.',
    );
    expect(
      lockoutSupportingMessage('Try again in about 1 minute.'),
      'Please try again in 1 minute.',
    );
    expect(
      lockoutSupportingMessage('Account temporarily locked.'),
      'Please try again later.',
    );
  });

  test('toastBottomOffset clears footer when closed and sits above keyboard', () {
    expect(
      LoginNoticeHost.toastBottomOffset(
        keyboardInset: 280,
        safeBottom: 24,
        screenHeight: 800,
      ),
      296, // 280 + 16
    );
    final closed = LoginNoticeHost.toastBottomOffset(
      keyboardInset: 0,
      safeBottom: 24,
      screenHeight: 800,
    );
    expect(closed, 24 + LoginNoticeHost.footerClearance);
    expect(closed, lessThanOrEqualTo(800 * 0.34));
  });

  testWidgets('toast replaces previous notice and can be dismissed', (tester) async {
    late _HostProbeState host;
    await tester.pumpWidget(
      _app(home: _HostProbe(onReady: (state) => host = state)),
    );
    await tester.pump();

    host.showLoginNotice('Invalid email or password.', LoginNoticeKind.credentials);
    await tester.pump();
    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.byType(LoginErrorToast), findsOneWidget);

    host.showLoginNotice(
      'Please try again in 12 minutes.',
      LoginNoticeKind.lockout,
      title: 'Account temporarily locked',
    );
    await tester.pump();
    expect(find.text('Invalid email or password.'), findsNothing);
    expect(find.text('Account temporarily locked'), findsOneWidget);
    expect(find.text('Please try again in 12 minutes.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.byType(LoginErrorToast), findsNothing);
  });

  testWidgets('credentials notice auto-dismisses after about 3 seconds', (tester) async {
    late _HostProbeState host;
    await tester.pumpWidget(
      _app(home: _HostProbe(onReady: (state) => host = state)),
    );
    await tester.pump();

    host.showLoginNotice('Invalid email or password.', LoginNoticeKind.credentials);
    await tester.pump();
    expect(find.byType(LoginErrorToast), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byType(LoginErrorToast), findsNothing);
  });

  testWidgets('lockout notice lasts about 5 seconds', (tester) async {
    late _HostProbeState host;
    await tester.pumpWidget(
      _app(home: _HostProbe(onReady: (state) => host = state)),
    );
    await tester.pump();

    host.showLoginNotice(
      'Please try again in 8 minutes.',
      LoginNoticeKind.lockout,
      title: 'Account temporarily locked',
    );
    await tester.pump();
    expect(find.byType(LoginErrorToast), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LoginErrorToast), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(LoginErrorToast), findsNothing);
  });

  testWidgets('credentials toast stays compact (~42–64px)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: LoginErrorToast(
                message: 'Invalid email or password.',
                kind: LoginNoticeKind.credentials,
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final size = tester.getSize(find.byType(LoginErrorToast));
    expect(size.height, greaterThanOrEqualTo(40));
    expect(size.height, lessThanOrEqualTo(64));
  });

  testWidgets('lockout toast shows full title and body without ellipsis', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: LoginErrorToast(
                title: 'Account temporarily locked',
                message: 'Please try again in 27 minutes.',
                kind: LoginNoticeKind.lockout,
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Account temporarily locked'), findsOneWidget);
    expect(find.text('Please try again in 27 minutes.'), findsOneWidget);
    expect(find.textContaining('…'), findsNothing);
    expect(find.textContaining('...'), findsNothing);

    final size = tester.getSize(find.byType(LoginErrorToast));
    expect(size.height, greaterThan(48));
    expect(size.height, lessThanOrEqualTo(110));
  });

  testWidgets('keyboard open places toast above the IME inset', (tester) async {
    late _HostProbeState host;
    const keyboard = 320.0;
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        viewInsets: const EdgeInsets.only(bottom: keyboard),
        home: _HostProbe(onReady: (state) => host = state),
      ),
    );
    await tester.pump();

    host.showLoginNotice('Invalid email or password.', LoginNoticeKind.credentials);
    await tester.pumpAndSettle();

    final toast = tester.getRect(find.byType(LoginErrorToast));
    final keyboardTop = 780 - keyboard;
    expect(toast.bottom, closeTo(keyboardTop - 16, 2.0));
  });

  testWidgets('keyboard closed places toast above footer clearance', (tester) async {
    late _HostProbeState host;
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(home: _HostProbe(onReady: (state) => host = state)),
    );
    await tester.pump();

    host.showLoginNotice(
      'Please try again in 18 minutes.',
      LoginNoticeKind.lockout,
      title: 'Account temporarily locked',
    );
    await tester.pumpAndSettle();

    final toast = tester.getRect(find.byType(LoginErrorToast));
    final expectedBottom = 780 - LoginNoticeHost.footerClearance;
    expect(toast.bottom, closeTo(expectedBottom, 8));
    // Remains above the bottom legal strip.
    expect(toast.bottom, lessThanOrEqualTo(780 - 80));
    expect(find.text('Please try again in 18 minutes.'), findsOneWidget);
  });

  testWidgets('password visibility toggle remains usable', (tester) async {
    final email = TextEditingController();
    final pass = TextEditingController();
    var obscure = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: MobileAuthSignInForm(
                  emailController: email,
                  passwordController: pass,
                  obscurePassword: obscure,
                  rememberMe: false,
                  loading: false,
                  onToggleObscure: () => setState(() => obscure = !obscure),
                  onRememberMeChanged: (_) {},
                  onSubmit: () {},
                  onForgotPassword: () {},
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    email.dispose();
    pass.dispose();
  });
}
