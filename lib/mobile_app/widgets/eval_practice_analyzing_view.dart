import 'package:flutter/material.dart';

import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/member_evaluation_theme.dart';

/// Indeterminate analyzing UI while deferred server evaluation runs (no fake progress %).
class EvalPracticeAnalyzingView extends StatelessWidget {
  const EvalPracticeAnalyzingView({super.key, required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: kEvalBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                'Analyzing your media…',
                textAlign: TextAlign.center,
                style: dashText(const TextStyle(
                  color: kDashTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                )),
              ),
              const SizedBox(height: 12),
              Text(
                'Technical quality and AI authenticity risk are being assessed.',
                textAlign: TextAlign.center,
                style: evalBodyStyle.copyWith(fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 8),
              Text(
                isVideo
                    ? 'Video analysis may take a few minutes.'
                    : 'This may take a short while.',
                textAlign: TextAlign.center,
                style: evalBodyStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(strokeWidth: 3, color: kEvalPrimary),
              ),
              const Spacer(flex: 2),
              Text(
                'Please keep the app open until analysis finishes.',
                textAlign: TextAlign.center,
                style: memberDashboardMetaStyle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
