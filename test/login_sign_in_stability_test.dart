import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/widgets/login/login_error_toast.dart';
import 'package:access_mobile/shared/widgets/login/login_notice_host.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_sign_in_form.dart';

class _LoginHarness extends StatefulWidget {
  const _LoginHarness({required this.onReady});

  final void Function(_LoginHarnessState state) onReady;

  @override
  State<_LoginHarness> createState() => _LoginHarnessState();
}

class _LoginHarnessState extends State<_LoginHarness>
    with LoginNoticeHost<_LoginHarness> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool obscure = true;
  bool loading = false;
  bool submitLocked = false;
  int submitCalls = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady(this));
  }

  @override
  void dispose() {
    disposeLoginNotice();
    passCtrl.clear();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> submit({
    required Future<void> Function() login,
  }) async {
    if (loading || submitLocked) return;
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;
    submitLocked = true;
    submitCalls += 1;
    setState(() => loading = true);
    try {
      await login();
      if (!mounted) return;
      passCtrl.clear();
      setState(() => loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      showLoginNotice('Invalid email or password.', LoginNoticeKind.credentials);
    } finally {
      submitLocked = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildWithLoginNotice(
      Scaffold(
        body: MobileAuthSignInForm(
          emailController: emailCtrl,
          passwordController: passCtrl,
          obscurePassword: obscure,
          rememberMe: false,
          loading: loading,
          onToggleObscure: () => setState(() => obscure = !obscure),
          onRememberMeChanged: (_) {},
          onSubmit: () {
            unawaited(
              submit(
                login: () async {
                  throw Exception('fail');
                },
              ),
            );
          },
          onForgotPassword: () {},
        ),
      ),
    );
  }
}

void main() {
  testWidgets('failed sign-in preserves email, password, and selection', (tester) async {
    late _LoginHarnessState host;
    await tester.pumpWidget(
      MaterialApp(home: _LoginHarness(onReady: (s) => host = s)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('mobile_sign_in_email')), 'member@access.edu');
    await tester.enterText(find.byKey(const ValueKey('mobile_sign_in_password')), 'SecretPass1');
    host.emailCtrl.selection = const TextSelection.collapsed(offset: 8);
    host.passCtrl.selection = const TextSelection.collapsed(offset: 4);

    await host.submit(login: () async {
      throw Exception('401');
    });
    await tester.pump();

    expect(host.emailCtrl.text, 'member@access.edu');
    expect(host.passCtrl.text, 'SecretPass1');
    expect(host.emailCtrl.selection.baseOffset, 8);
    expect(host.passCtrl.selection.baseOffset, 4);
    expect(find.byType(LoginErrorToast), findsOneWidget);
  });

  testWidgets('rapid Sign In taps produce one submission', (tester) async {
    late _LoginHarnessState host;
    final gate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(home: _LoginHarness(onReady: (s) => host = s)),
    );
    await tester.pump();

    host.emailCtrl.text = 'a@b.com';
    host.passCtrl.text = 'pass';

    final first = host.submit(login: () => gate.future);
    final second = host.submit(login: () => gate.future);
    final third = host.submit(login: () => gate.future);
    await tester.pump();

    expect(host.submitCalls, 1);
    expect(host.loading, isTrue);

    gate.completeError(Exception('fail'));
    await first;
    await second;
    await third;
    await tester.pump();
    expect(host.submitCalls, 1);
  });

  testWidgets('show/hide password preserves value', (tester) async {
    final email = TextEditingController(text: 'a@b.com');
    final pass = TextEditingController(text: 'KeepMe123');
    var obscure = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return MobileAuthSignInForm(
                emailController: email,
                passwordController: pass,
                obscurePassword: obscure,
                rememberMe: false,
                loading: false,
                onToggleObscure: () => setState(() => obscure = !obscure),
                onRememberMeChanged: (_) {},
                onSubmit: () {},
                onForgotPassword: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(pass.text, 'KeepMe123');
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(pass.text, 'KeepMe123');
    expect(obscure, isFalse);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(pass.text, 'KeepMe123');
    expect(obscure, isTrue);

    email.dispose();
    pass.dispose();
  });

  testWidgets('error toast does not change text field size', (tester) async {
    late _LoginHarnessState host;
    await tester.pumpWidget(
      MaterialApp(home: _LoginHarness(onReady: (s) => host = s)),
    );
    await tester.pump();

    final emailBefore = tester.getSize(find.byKey(const ValueKey('mobile_sign_in_email')));
    final passBefore = tester.getSize(find.byKey(const ValueKey('mobile_sign_in_password')));

    host.showLoginNotice('Invalid email or password.', LoginNoticeKind.credentials);
    await tester.pump();

    final emailAfter = tester.getSize(find.byKey(const ValueKey('mobile_sign_in_email')));
    final passAfter = tester.getSize(find.byKey(const ValueKey('mobile_sign_in_password')));
    expect(emailAfter, emailBefore);
    expect(passAfter, passBefore);
  });

  test('postLogin uses a single host and does not fan out on 401', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      return http.Response(jsonEncode({'detail': 'Invalid credentials'}), 401);
    });
    final api = ApiClient(client: client);

    await expectLater(
      () => api.postLogin('/auth/login', {
        'email': 'a@b.com',
        'password': 'x',
      }),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
    expect(calls, 1);
  });
}
