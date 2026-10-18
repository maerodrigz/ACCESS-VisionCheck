import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/models/requestor_type.dart';
import 'package:access_mobile/shared/screens/organization_registration_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_scaffold.dart';
import 'package:access_mobile/shared/copy/mobile_registration_copy.dart';
import 'package:access_mobile/shared/widgets/mobile_auth/mobile_auth_widgets.dart';

/// Choose faculty/staff or organization before the requestor registration form.
class RequestorTypeSelectionScreen extends StatefulWidget {
  const RequestorTypeSelectionScreen({super.key});

  @override
  State<RequestorTypeSelectionScreen> createState() =>
      _RequestorTypeSelectionScreenState();
}

class _RequestorTypeSelectionScreenState extends State<RequestorTypeSelectionScreen> {
  RequestorType? _selected;

  Future<void> _continue() async {
    final type = _selected;
    if (type == null) return;

    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RequestorRegistrationScreen(requestorType: type),
      ),
    );
    if (email != null && mounted) {
      Navigator.pop(context, email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!kIsWeb) const MobileAuthBackButton(),
        const MobileAuthSectionHeader(
          title: MobileRegistrationCopy.requestorTypeTitle,
          subtitle: MobileRegistrationCopy.requestorTypeSubtitle,
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < RequestorType.values.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _RequestorTypeOptionCard(
            type: RequestorType.values[i],
            selected: _selected == RequestorType.values[i],
            onTap: () => setState(() => _selected = RequestorType.values[i]),
          ),
        ],
        const SizedBox(height: 24),
        MobileAuthGradientButton(
          label: 'Continue',
          onPressed: _selected == null ? null : _continue,
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          MobileAuthTextLinkRow(
            prompt: 'Already have an account?',
            linkLabel: 'Sign In',
            onLinkTap: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ],
    );

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kSurface,
          elevation: 0,
          title: const Text('Requestor Type', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: body)),
      );
    }

    return MobileAuthScaffold(body: body);
  }
}

class _RequestorTypeOptionCard extends StatelessWidget {
  const _RequestorTypeOptionCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final RequestorType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kBlueDim : kSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? kCyan : kBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? kCyanDim : kCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(type),
                  color: kCyan,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.description,
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: selected ? kCyan : kIconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(RequestorType type) {
    switch (type) {
      case RequestorType.facultyStaff:
        return Icons.school_rounded;
      case RequestorType.organization:
        return Icons.groups_rounded;
    }
  }
}
