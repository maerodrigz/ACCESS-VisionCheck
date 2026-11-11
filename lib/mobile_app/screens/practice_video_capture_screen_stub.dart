import 'package:flutter/material.dart';

import 'package:access_mobile/shared/themes/theme.dart';

/// Result of an in-app practice video recording (Phase 0, no session binding).
class PracticeVideoCaptureResult {
  const PracticeVideoCaptureResult({
    required this.filePath,
    required this.fileName,
  });

  final String filePath;
  final String fileName;
}

/// Web/desktop stub: in-app recording is Android-only for Phase 0.
class PracticeVideoCaptureScreen extends StatelessWidget {
  const PracticeVideoCaptureScreen({
    super.key,
    required this.maxDuration,
  });

  final Duration maxDuration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Video')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'In-app video recording is available on the Android Member app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextPrimary, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
