import 'package:access_mobile/shared/constants/facebook_config.dart';

/// Public Facebook Page / post URLs for in-app links (requestor gallery, share flow).
class FacebookLinks {
  FacebookLinks._();

  static String get pageUrl =>
      'https://www.facebook.com/profile.php?id=${FacebookConfig.defaultPageId}';

  /// Graph post id format: `{pageId}_{storyId}`.
  static String? postUrl(String? postId) {
    final trimmed = postId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final underscore = trimmed.indexOf('_');
    if (underscore <= 0 || underscore >= trimmed.length - 1) return pageUrl;
    final pageId = trimmed.substring(0, underscore);
    final storyId = trimmed.substring(underscore + 1);
    return 'https://www.facebook.com/$pageId/posts/$storyId';
  }
}

/// Resolved link when an event has been published to Facebook.
class EventGalleryFacebookLink {
  const EventGalleryFacebookLink({
    required this.url,
    required this.labelsDirectPost,
  });

  final String url;
  final bool labelsDirectPost;

  String get buttonLabel =>
      labelsDirectPost ? 'View on Facebook' : 'View on Facebook Page';
}
