import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/web_admin/features/documentation_requests/documentation_request_models.dart';

class DocumentationRequestsRepository {
  Future<List<DocumentationRequestItem>> loadAll() async {
    final requests = await adminApi.allServiceRequests();
    final tasks = await adminApi.allTasks();

    final tasksByRequest = <int, List<Map<String, dynamic>>>{};
    for (final t in tasks) {
      final rid = t['request_id'] as int?;
      if (rid == null) continue;
      tasksByRequest.putIfAbsent(rid, () => []).add(t);
    }

    return requests
        .map((r) {
          final id = r['request_id'] as int? ?? 0;
          return DocumentationRequestItem.fromMaps(r, tasksByRequest[id] ?? []);
        })
        .toList();
  }

  List<DocumentationRequestItem> filterAndSort({
    required List<DocumentationRequestItem> items,
    required RequestFilterTab tab,
    required String search,
    required RequestSortOption sort,
    RequestPriority? priorityFilter,
  }) {
    var list = items.where((item) {
      if (!item.matchesFilter(tab)) return false;
      if (priorityFilter != null && item.priority != priorityFilter) return false;
      if (search.isEmpty) return true;
      final q = search.toLowerCase();
      return item.eventTitle.toLowerCase().contains(q) ||
          item.requestor.toLowerCase().contains(q) ||
          (item.venue ?? '').toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      switch (sort) {
        case RequestSortOption.newest:
          return (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
        case RequestSortOption.oldest:
          return (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000));
        case RequestSortOption.eventDateAsc:
          return (a.eventDate ?? DateTime(2100)).compareTo(b.eventDate ?? DateTime(2100));
        case RequestSortOption.eventDateDesc:
          return (b.eventDate ?? DateTime(2000)).compareTo(a.eventDate ?? DateTime(2000));
        case RequestSortOption.priority:
          return b.priority.index.compareTo(a.priority.index);
      }
    });

    return list;
  }

  Map<RequestDisplayStatus, int> countByStatus(List<DocumentationRequestItem> items) {
    return {
      for (final s in RequestDisplayStatus.values)
        s: items.where((i) => i.displayStatus == s).length,
    };
  }
}
