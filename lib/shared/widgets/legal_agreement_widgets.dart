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
    this.registrationAudience,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final RegistrationLegalAudience? registrationAudience;

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: kAccent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _LegalAgreementText(
                  style: const TextStyle(color: kTextSecondary, fontSize: 12, height: 1.45),
                  linkColor: kAccent,
                  registrationAudience: registrationAudience,
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
  const _LegalAgreementText({
    required this.style,
    required this.linkColor,
    this.registrationAudience,
  });

  final TextStyle style;
  final Color linkColor;
  final RegistrationLegalAudience? registrationAudience;

  Widget _agreementLine({required List<Widget> children}) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 0,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMember = registrationAudience == RegistrationLegalAudience.member;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _agreementLine(
          children: [
            Text('I agree to the ', style: style),
            _LegalLinkButton(
              label: 'Terms and Conditions',
              color: linkColor,
              onTap: () => openAccessLegalDocument(
                context,
                AccessLegalDocument.terms,
                registrationAudience: registrationAudience,
              ),
            ),
            Text(' and ', style: style),
            _LegalLinkButton(
              label: 'Privacy Policy',
              color: linkColor,
              onTap: () => openAccessLegalDocument(
                context,
                AccessLegalDocument.privacy,
                registrationAudience: registrationAudience,
              ),
            ),
            Text('.', style: style),
          ],
        ),
        if (isMember) ...[
          const SizedBox(height: 6),
          _agreementLine(
            children: [
              Text('I accept the ', style: style),
              _LegalLinkButton(
                label: 'Content Standards',
                color: linkColor,
                onTap: () => openAccessLegalDocument(
                  context,
                  AccessLegalDocument.contentStandards,
                  registrationAudience: registrationAudience,
                ),
              ),
              Text('.', style: style),
            ],
          ),
        ),
      ),
    );
  }
}
