import 'package:flutter/material.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';
import 'package:access_mobile/shared/legal/access_legal_content.dart';
import 'package:access_mobile/shared/screens/legal_document_screen.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/widgets/login/login_page_tokens.dart';

/// Registration checkbox: agree to Terms and Privacy.
class LegalAgreementCheckbox extends StatelessWidget {
  const LegalAgreementCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: value ? kAccent.withValues(alpha: 0.45) : kBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: kAccent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _LegalAgreementText(
                    style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.4),
                    linkColor: kAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Login footer links: Terms · Privacy.
class LegalFooterLinks extends StatelessWidget {
  const LegalFooterLinks({super.key, this.useLoginTokens = false, this.onDarkBackground = false});

  final bool useLoginTokens;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final muted = onDarkBackground
        ? Colors.white.withValues(alpha: 0.6)
        : (useLoginTokens ? LoginPageTokens.textSecondary : kTextSecondary);
    final link = onDarkBackground ? kCyan : (useLoginTokens ? LoginPageTokens.secondary : kAccent);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegalLinkButton(
          label: 'Terms and Conditions',
          color: link,
          onTap: () => openAccessLegalDocument(context, AccessLegalDocument.terms),
        ),
        Text('  ·  ', style: TextStyle(color: muted.withValues(alpha: 0.8), fontSize: 12)),
        _LegalLinkButton(
          label: 'Privacy Policy',
          color: link,
          onTap: () => openAccessLegalDocument(context, AccessLegalDocument.privacy),
        ),
      ],
    );
  }
}

/// Short footnote on upload / evaluation flows.
class LegalUploadFootnote extends StatelessWidget {
  const LegalUploadFootnote({super.key, this.onDarkBackground = false});

  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final muted = onDarkBackground ? kEvalGuideDarkTextSecondary : kTextSecondary;
    final link = onDarkBackground ? kMemberCyan : kAccent;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('By submitting, you agree to the ', style: _mutedStyle(muted)),
        _LegalLinkButton(
          label: 'Terms and Conditions',
          color: link,
          onTap: () => openAccessLegalDocument(context, AccessLegalDocument.terms),
        ),
        Text(' and ', style: _mutedStyle(muted)),
        _LegalLinkButton(
          label: 'Content Standards',
          color: link,
          onTap: () => openAccessLegalDocument(context, AccessLegalDocument.contentStandards),
        ),
        Text('.', style: _mutedStyle(muted)),
      ],
    );
  }

  TextStyle _mutedStyle(Color color) {
    return dashText(TextStyle(color: color, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500));
  }
}

class _LegalAgreementText extends StatelessWidget {
  const _LegalAgreementText({required this.style, required this.linkColor});

  final TextStyle style;
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('I agree to the ', style: style),
        _LegalLinkButton(
          label: 'Terms and Conditions',
          color: linkColor,
          onTap: () => openAccessLegalDocument(context, AccessLegalDocument.terms),
        ),
        Text(' and ', style: style),
        _LegalLinkButton(
          label: 'Privacy Policy',
          color: linkColor,
          onTap: () => openAccessLegalDocument(context, AccessLegalDocument.privacy),
        ),
        Text('.', style: style),
      ],
    );
  }
}

class _LegalLinkButton extends StatelessWidget {
  const _LegalLinkButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, height: 1.4),
        ),
      ),
    );
  }
}
