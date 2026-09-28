import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_evaluation/media_evaluation_models.dart';

class MediaEvaluationFilters {
  String mediaQuery = '';
  String memberQuery = '';
  AiResultLabel? aiFilter;
  QualityStatus? qualityFilter;
  bool? standaloneOnly;
  bool sortByOverallDesc = false;
}

class MediaEvaluationFilterBar extends StatelessWidget {
  const MediaEvaluationFilterBar({
    super.key,
    required this.filters,
    required this.mediaSearchController,
    required this.memberSearchController,
    required this.onChanged,
    required this.onClear,
    this.showFilters = false,
    this.onToggleFilters,
  });

  final MediaEvaluationFilters filters;
  final TextEditingController mediaSearchController;
  final TextEditingController memberSearchController;
  final VoidCallback onChanged;
  final VoidCallback onClear;
  final bool showFilters;
  final VoidCallback? onToggleFilters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < 860;
        final searchFields = stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _searchField(mediaSearchController, 'Search by media name…', Icons.image_search_outlined, (v) {
                    filters.mediaQuery = v;
                    onChanged();
                  }),
                  const SizedBox(height: 10),
                  _searchField(memberSearchController, 'Search by member name…', Icons.person_search_outlined, (v) {
                    filters.memberQuery = v;
                    onChanged();
                  }),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _searchField(mediaSearchController, 'Search by media name…', Icons.image_search_outlined, (v) {
                      filters.mediaQuery = v;
                      onChanged();
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _searchField(memberSearchController, 'Search by member name…', Icons.person_search_outlined, (v) {
                      filters.memberQuery = v;
                      onChanged();
                    }),
                  ),
                ],
              );

        return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          searchFields,
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (onToggleFilters != null)
                OutlinedButton.icon(
                  onPressed: onToggleFilters,
                  icon: Icon(showFilters ? Icons.filter_list_off : Icons.filter_list),
                  label: Text(showFilters ? 'Hide filters' : 'Filter results'),
                ),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
          if (showFilters) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _FilterDropdown<AiResultLabel?>(
                  label: 'AI result',
                  value: filters.aiFilter,
                  items: const [
                    (null, 'All'),
                    (AiResultLabel.human, 'Human'),
                    (AiResultLabel.aiGenerated, 'AI-Generated'),
                    (AiResultLabel.suspicious, 'Suspicious'),
                    (AiResultLabel.pending, 'Pending'),
                  ],
                  onChanged: (v) {
                    filters.aiFilter = v;
                    onChanged();
                  },
                ),
                _FilterDropdown<QualityStatus?>(
                  label: 'Quality status',
                  value: filters.qualityFilter,
                  items: const [
                    (null, 'All'),
                    (QualityStatus.excellent, 'Excellent'),
                    (QualityStatus.good, 'Good'),
                    (QualityStatus.needsImprovement, 'Needs Improvement'),
                  ],
                  onChanged: (v) {
                    filters.qualityFilter = v;
                    onChanged();
                  },
                ),
                _FilterDropdown<bool?>(
                  label: 'Source',
                  value: filters.standaloneOnly,
                  items: const [
                    (null, 'All submissions'),
                    (true, 'Practice only'),
                    (false, 'Event-linked only'),
                  ],
                  onChanged: (v) {
                    filters.standaloneOnly = v;
                    onChanged();
                  },
                ),
              ],
            ),
          ],
        ],
        );
      },
    );
  }

  Widget _searchField(
    TextEditingController controller,
    String hint,
    IconData icon,
    ValueChanged<String> onChangedField,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
      ),
      onChanged: onChangedField,
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth < 720 ? c.maxWidth : 200.0;
        return SizedBox(
      width: w,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            items: items
                .map((e) => DropdownMenuItem<T>(value: e.$1, child: Text(e.$2)))
                .toList(),
            onChanged: (v) => onChanged(v as T),
          ),
        ),
      ),
        );
      },
    );
  }
}
