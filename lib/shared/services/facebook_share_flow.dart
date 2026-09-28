import 'package:flutter/material.dart';
import 'package:access_mobile/shared/services/facebook_browser_share.dart';

/// Opens Facebook share in the browser and optionally logs to the API.
Future<bool> runFacebookBrowserShare({
  required String imageUrl,
  String? message,
  Future<void> Function()? onLogged,
}) async {
  if (imageUrl.isEmpty) {
    return false;
  }
  final opened = await FacebookBrowserShare.openShare(
    linkUrl: imageUrl,
    quote: message,
  );
  if (opened && onLogged != null) {
    try {
      await onLogged();
    } catch (_) {
      // Facebook already opened; logging is best-effort.
    }
  }
  return opened;
}

void showFacebookShareSnackBar(BuildContext context, {required bool opened}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        opened
            ? 'Facebook opened — finish your post there. '
                'Org page: ACCESS'
            : 'Could not open Facebook. Allow pop-ups for this site.',
      ),
      backgroundColor: opened ? Colors.green : Colors.red,
      duration: const Duration(seconds: 6),
      action: opened
          ? SnackBarAction(
              label: 'Open Page',
              textColor: Colors.white,
              onPressed: () => FacebookBrowserShare.openPage(),
            )
          : null,
    ),
  );
}
