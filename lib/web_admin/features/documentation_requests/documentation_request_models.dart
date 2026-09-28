enum RequestFilterTab { all, pending, approved, rejected, completed }

enum RequestViewMode { cards, kanban }

enum RequestSortOption { newest, oldest, eventDateAsc, eventDateDesc, priority }

enum RequestPriority { urgent, high, normal, low }

enum RequestDisplayStatus { pending, approved, rejected, completed }

class AssignedMemberInfo {
  const AssignedMemberInfo({
    required this.id,
    required this.name,
    required this.role,
    this.initials,
  });

  final int id;
  final String name;
  final String role;
  final String? initials;

  String get avatarLabel {
    if (initials != null && initials!.isNotEmpty) return initials!;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class DocumentationRequestItem {
  const DocumentationRequestItem({
    required this.id,
    required this.requesterId,
    required this.eventTitle,
    required this.requestor,
    required this.eventDate,
    required this.venue,
    required this.details,
    required this.rawStatus,
    required this.displayStatus,
    required this.priority,
    required this.createdAt,
    required this.assignedMembers,
    this.rejectionReason,
  });

  final int id;
  final int requesterId;
  final String eventTitle;
  final String requestor;
  final DateTime? eventDate;
  final String? venue;
  final String? details;
  final String rawStatus;
  final RequestDisplayStatus displayStatus;
  final RequestPriority priority;
  final DateTime? createdAt;
  final List<AssignedMemberInfo> assignedMembers;
  final String? rejectionReason;

  String get eventDateLabel {
    if (eventDate == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[eventDate!.month - 1]} ${eventDate!.day}, ${eventDate!.year}';
  }

  String get createdAtLabel {
    if (createdAt == null) return 'Recently';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[createdAt!.month - 1]} ${createdAt!.day}, ${createdAt!.year}';
  }

  String get statusLabel => switch (displayStatus) {
        RequestDisplayStatus.pending => 'Pending',
        RequestDisplayStatus.approved => 'Approved',
        RequestDisplayStatus.rejected => 'Rejected',
        RequestDisplayStatus.completed => 'Completed',
      };

  String get priorityLabel => switch (priority) {
        RequestPriority.urgent => 'Urgent',
        RequestPriority.high => 'High',
        RequestPriority.normal => 'Normal',
        RequestPriority.low => 'Low',
      };

  bool matchesFilter(RequestFilterTab tab) {
    return switch (tab) {
      RequestFilterTab.all => true,
      RequestFilterTab.pending => displayStatus == RequestDisplayStatus.pending,
      RequestFilterTab.approved => displayStatus == RequestDisplayStatus.approved,
      RequestFilterTab.rejected => displayStatus == RequestDisplayStatus.rejected,
      RequestFilterTab.completed => displayStatus == RequestDisplayStatus.completed,
    };
  }

  static DocumentationRequestItem fromMaps(
    Map<String, dynamic> request,
    List<Map<String, dynamic>> tasksForRequest,
  ) {
    final eventDate = _parseDate(request['event_date']);
    final createdAt = _parseDate(request['created_at']);
    final rawStatus = (request['status'] as String? ?? 'Pending').toString();

    final members = tasksForRequest
        .map(
          (t) => AssignedMemberInfo(
            id: t['member_id'] as int? ?? 0,
            name: t['member_name'] as String? ?? 'Member',
            role: t['task_role'] as String? ?? 'photographer',
          ),
        )
        .toList();

    final displayStatus = _deriveDisplayStatus(rawStatus, eventDate, tasksForRequest);
    final priority = _derivePriority(eventDate, displayStatus);

    return DocumentationRequestItem(
      id: request['request_id'] as int? ?? request['id'] as int? ?? 0,
      requesterId: request['requester_id'] as int? ?? 0,
      eventTitle: request['event_name'] as String? ?? request['title'] as String? ?? 'Documentation request',
      requestor: request['requester_name'] as String? ?? 'Unknown',
      eventDate: eventDate,
      venue: request['venue'] as String?,
      details: request['details'] as String? ?? request['description'] as String?,
      rawStatus: rawStatus,
      displayStatus: displayStatus,
      priority: priority,
      createdAt: createdAt,
      assignedMembers: members,
      rejectionReason: request['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toRequestMap() => {
        'request_id': id,
        'requester_id': requesterId,
        'event_name': eventTitle,
        'title': eventTitle,
        'requester_name': requestor,
        'event_date': eventDate?.toIso8601String().split('T').first,
        'venue': venue,
        'details': details,
        'status': rawStatus,
        'rejection_reason': rejectionReason,
        'created_at': createdAt?.toIso8601String(),
      };
}

RequestDisplayStatus _deriveDisplayStatus(
  String rawStatus,
  DateTime? eventDate,
  List<Map<String, dynamic>> tasks,
) {
  final s = rawStatus.toLowerCase();
  if (s == 'rejected') return RequestDisplayStatus.rejected;
  if (s == 'pending') return RequestDisplayStatus.pending;
  if (s == 'completed') return RequestDisplayStatus.completed;
  if (s == 'approved') return RequestDisplayStatus.approved;
  return RequestDisplayStatus.pending;
}

RequestPriority _derivePriority(DateTime? eventDate, RequestDisplayStatus status) {
  if (status == RequestDisplayStatus.completed || status == RequestDisplayStatus.rejected) {
    return RequestPriority.low;
  }
  if (eventDate == null) return RequestPriority.normal;
  final days = eventDate.difference(DateTime.now()).inDays;
  if (days < 0) return RequestPriority.high;
  if (days <= 2) return RequestPriority.urgent;
  if (days <= 7) return RequestPriority.high;
  if (days <= 21) return RequestPriority.normal;
  return RequestPriority.low;
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
}

RequestFilterTab filterTabFromString(String? raw) {
  return switch (raw?.toLowerCase()) {
    'pending' => RequestFilterTab.pending,
    'approved' => RequestFilterTab.approved,
    'rejected' => RequestFilterTab.rejected,
    'completed' => RequestFilterTab.completed,
    _ => RequestFilterTab.all,
  };
}
