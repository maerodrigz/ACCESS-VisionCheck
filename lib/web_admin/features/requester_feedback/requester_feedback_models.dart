import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

enum FeedbackReviewStatus {
  pending,
  reviewed,
  archived;

  String get label => switch (this) {
        FeedbackReviewStatus.pending => 'Pending Review',
        FeedbackReviewStatus.reviewed => 'Reviewed',
        FeedbackReviewStatus.archived => 'Archived',
      };

  Color get color => switch (this) {
        FeedbackReviewStatus.pending => AdminTheme.warning,
        FeedbackReviewStatus.reviewed => AdminTheme.success,
        FeedbackReviewStatus.archived => AdminTheme.textSecondary,
      };
}

enum FeedbackFilterChip {
  all,
  star5,
  star4,
  star3,
  star2,
  star1,
  needsAttention;

  String get label => switch (this) {
        FeedbackFilterChip.all => 'All Reviews',
        FeedbackFilterChip.star5 => '5 Stars',
        FeedbackFilterChip.star4 => '4 Stars',
        FeedbackFilterChip.star3 => '3 Stars',
        FeedbackFilterChip.star2 => '2 Stars',
        FeedbackFilterChip.star1 => '1 Star',
        FeedbackFilterChip.needsAttention => 'Needs Attention',
      };
}

class FeedbackOverviewStats {
  const FeedbackOverviewStats({
    required this.averageRating,
    required this.totalReceived,
    required this.positiveReviews,
    required this.needsAttention,
  });

  final double averageRating;
  final int totalReceived;
  final int positiveReviews;
  final int needsAttention;
}

class EventServiceSummary {
  const EventServiceSummary({
    required this.eventName,
    required this.photographers,
    required this.videographers,
    required this.photoCount,
    required this.videoCount,
    required this.facebookPublished,
    required this.completionDate,
  });

  final String eventName;
  final List<String> photographers;
  final List<String> videographers;
  final int photoCount;
  final int videoCount;
  final bool facebookPublished;
  final DateTime? completionDate;

  String get photographersLabel => photographers.isEmpty ? '—' : photographers.join(', ');
  String get videographersLabel => videographers.isEmpty ? '—' : videographers.join(', ');
  String get facebookLabel => facebookPublished ? 'Yes' : 'No';
}

class RequesterFeedbackItem {
  const RequesterFeedbackItem({
    required this.id,
    required this.requestId,
    required this.eventName,
    required this.organization,
    required this.requesterName,
    required this.eventDate,
    required this.submittedAt,
    required this.completionDate,
    required this.rating,
    required this.comment,
    required this.reviewStatus,
    required this.eventSummary,
    this.adminResponse,
    this.needsAttention = false,
    this.attentionReason,
  });

  final int id;
  final int requestId;
  final String eventName;
  final String organization;
  final String requesterName;
  final DateTime? eventDate;
  final DateTime? submittedAt;
  final DateTime? completionDate;
  final int rating;
  final String comment;
  final FeedbackReviewStatus reviewStatus;
  final EventServiceSummary eventSummary;
  final String? adminResponse;
  final bool needsAttention;
  final String? attentionReason;

  String get organizationInitials {
    final parts = organization.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    return organization.isNotEmpty ? organization[0].toUpperCase() : '?';
  }

  String get commentPreview {
    final text = comment.trim();
    if (text.isEmpty) return 'No written comment provided.';
    return text.length <= 120 ? text : '${text.substring(0, 117)}…';
  }

  bool get isArchived => reviewStatus == FeedbackReviewStatus.archived;

  bool matchesChip(FeedbackFilterChip chip) {
    if (isArchived && chip != FeedbackFilterChip.all) return false;
    return switch (chip) {
      FeedbackFilterChip.all => !isArchived,
      FeedbackFilterChip.star5 => rating == 5,
      FeedbackFilterChip.star4 => rating == 4,
      FeedbackFilterChip.star3 => rating == 3,
      FeedbackFilterChip.star2 => rating == 2,
      FeedbackFilterChip.star1 => rating == 1,
      FeedbackFilterChip.needsAttention => needsAttention,
    };
  }

  RequesterFeedbackItem copyWith({
    FeedbackReviewStatus? reviewStatus,
    String? adminResponse,
  }) =>
      RequesterFeedbackItem(
        id: id,
        requestId: requestId,
        eventName: eventName,
        organization: organization,
        requesterName: requesterName,
        eventDate: eventDate,
        submittedAt: submittedAt,
        completionDate: completionDate,
        rating: rating,
        comment: comment,
        reviewStatus: reviewStatus ?? this.reviewStatus,
        eventSummary: eventSummary,
        adminResponse: adminResponse ?? this.adminResponse,
        needsAttention: needsAttention,
        attentionReason: attentionReason,
      );
}

class FeaturedTestimonial {
  const FeaturedTestimonial({
    required this.quote,
    required this.organization,
    required this.rating,
    required this.eventName,
  });

  final String quote;
  final String organization;
  final int rating;
  final String eventName;
}

class RequesterFeedbackDashboardData {
  const RequesterFeedbackDashboardData({
    required this.feedback,
    required this.stats,
    this.featured,
  });

  final List<RequesterFeedbackItem> feedback;
  final FeedbackOverviewStats stats;
  final FeaturedTestimonial? featured;
}

String formatFeedbackDate(DateTime? d) {
  if (d == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

const kDefaultAdminResponse =
    'Thank you for your valuable feedback. We appreciate your suggestions and will continue improving our documentation services.';

(String type, String body) parseRequesterFeedbackComment(String comment) {
  final text = comment.trim();
  final match = RegExp(r'^([^:]+):\s*(.+)$', dotAll: true).firstMatch(text);
  if (match != null) {
    return (match.group(1)!.trim(), match.group(2)!.trim());
  }
  return ('General', text);
}
