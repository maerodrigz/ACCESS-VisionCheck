import 'package:access_mobile/shared/api/api_client.dart';

/// User-facing copy for linked replacement upload API errors.
String replacementUploadErrorMessage(ApiException e) {
  switch (e.code) {
    case 'replacement_upload_disabled':
      return 'Replacement upload is not enabled on this server yet. Contact your administrator.';
    case 'replacement_not_requested':
      return 'An administrator has not requested a re-upload for this submission.';
    case 'replacement_already_active':
      return 'A replacement is already being processed. Wait for review or contact an administrator.';
    case 'invalid_replacement_target':
      if (e.statusCode == 403) {
        return 'You can only replace your own practice submissions.';
      }
      return e.message.trim().isNotEmpty
          ? e.message.trim()
          : 'This submission cannot be replaced.';
    default:
      break;
  }
  if (e.statusCode == 401 || e.statusCode == 403) {
    return 'Session expired or access denied. Sign in again and retry.';
  }
  if (e.statusCode == 404) {
    return 'Submission not found. Refresh your evaluations list.';
  }
  if (e.statusCode == 422) {
    return e.message.trim().isNotEmpty ? e.message.trim() : 'Invalid upload. Check file type and size.';
  }
  if (e.statusCode == 409 && e.message.toLowerCase().contains('already been submitted')) {
    return 'You already uploaded this exact file. Choose a different photo or video.';
  }
  final msg = e.message.trim();
  if (e.statusCode == null ||
      msg.toLowerCase().contains('connection') ||
      msg.toLowerCase().contains('timeout') ||
      msg.toLowerCase().contains('network')) {
    return 'Could not reach the server. Check Wi-Fi and your backend URL.';
  }
  if (msg.isNotEmpty) return msg;
  return 'Replacement upload failed. Please try again.';
}
