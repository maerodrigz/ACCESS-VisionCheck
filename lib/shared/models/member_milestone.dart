import 'package:flutter/material.dart';
import 'package:access_mobile/shared/themes/theme.dart';

class MemberMilestone {
  const MemberMilestone({
    required this.id,
    required this.kind,
    required this.key,
    required this.title,
    required this.message,
    required this.earnedAt,
    this.acknowledgedAt,
  });

  final int id;
  final String kind;
  final String key;
  final String title;
  final String message;
  final DateTime? earnedAt;
  final DateTime? acknowledgedAt;

  bool get isAcknowledged => acknowledgedAt != null;

  factory MemberMilestone.fromApi(Map<String, dynamic> json) {
    final earnedRaw = json['earned_at'] as String?;
    final ackRaw = json['acknowledged_at'] as String?;
    return MemberMilestone(
      id: json['id'] as int? ?? 0,
      kind: json['milestone_kind'] as String? ?? '',
      key: json['milestone_key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      earnedAt: earnedRaw != null ? DateTime.tryParse(earnedRaw) : null,
      acknowledgedAt: ackRaw != null ? DateTime.tryParse(ackRaw) : null,
    );
  }

  IconData get icon => switch (kind) {
        'skill_tier' => Icons.workspace_premium_rounded,
        'first_evaluation' => Icons.fact_check_rounded,
        'eval_gate' => Icons.flag_rounded,
        'photographer_title' => Icons.camera_enhance_rounded,
        _ => Icons.emoji_events_outlined,
      };

  Color get accentColor => switch (kind) {
        'skill_tier' => kAccent,
        'first_evaluation' => kCyan,
        'eval_gate' => kGreen,
        'photographer_title' => kPurple,
        _ => kAccent,
      };
}
