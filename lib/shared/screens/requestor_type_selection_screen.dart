import 'package:flutter/material.dart';
import 'package:access_mobile/shared/models/requestor_type.dart';
import 'package:access_mobile/shared/screens/organization_registration_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';

/// Choose Faculty, Instructor, or Organization before the requestor registration form.
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
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Requestor Type',
          style: TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                children: [
                  const Text(
                    'Tell us what type of requestor you are.',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose the option that best describes you or your organization.',
                    style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (var i = 0; i < RequestorType.values.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _RequestorTypeOptionCard(
                      type: RequestorType.values[i],
                      selected: _selected == RequestorType.values[i],
                      onTap: () => setState(() => _selected = RequestorType.values[i]),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kAccent.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _selected == null ? null : _continue,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kAccent : kBorder,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.06 : 0.04),
                blurRadius: selected ? 10 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? kCyanDim : kAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(type),
                  color: selected ? kCyan : kAccent,
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
                color: selected ? kAccent : kIconInactive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(RequestorType type) {
    switch (type) {
      case RequestorType.faculty:
        return Icons.school_rounded;
      case RequestorType.instructor:
        return Icons.menu_book_rounded;
      case RequestorType.organization:
        return Icons.groups_rounded;
    }
  }
}
