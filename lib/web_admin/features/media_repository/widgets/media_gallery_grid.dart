import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_models.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/media_tile.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef MediaGalleryAction = void Function(String action, MediaAsset item);

class MediaGalleryGrid extends StatelessWidget {
  const MediaGalleryGrid({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onItemTap,
    required this.onSelectToggle,
    required this.onAction,
    required this.isAdmin,
  });

  final List<MediaAsset> items;
  final Set<int> selectedIds;
  final ValueChanged<MediaAsset> onItemTap;
  final ValueChanged<MediaAsset> onSelectToggle;
  final MediaGalleryAction onAction;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1400 ? 5 : width >= 1100 ? 4 : width >= 820 ? 3 : width >= 520 ? 2 : 1;

        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                MediaTile(
                  item: items[i],
                  selected: selectedIds.contains(items[i].id),
                  aspectRatio: _ratioFor(i),
                  isAdmin: isAdmin,
                  onTap: () => onItemTap(items[i]),
                  onSelectToggle: () => onSelectToggle(items[i]),
                  onAction: onAction,
                ),
                if (i < items.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        final colItems = List<List<MediaAsset>>.generate(columns, (_) => []);
        for (var i = 0; i < items.length; i++) {
          colItems[i % columns].add(items[i]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < colItems[c].length; i++) ...[
                      MediaTile(
                        item: colItems[c][i],
                        selected: selectedIds.contains(colItems[c][i].id),
                        aspectRatio: _ratioFor(c * 10 + i),
                        isAdmin: isAdmin,
                        onTap: () => onItemTap(colItems[c][i]),
                        onSelectToggle: () => onSelectToggle(colItems[c][i]),
                        onAction: onAction,
                      ),
                      if (i < colItems[c].length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  double _ratioFor(int index) {
    const ratios = [0.85, 1.05, 0.95, 1.15, 0.9, 1.0];
    return ratios[index % ratios.length];
  }
}

class RecentUploadsSection extends StatelessWidget {
  const RecentUploadsSection({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onItemTap,
    required this.onSelectToggle,
    required this.onAction,
    required this.isAdmin,
    this.albumName,
  });

  final List<MediaAsset> items;
  final Set<int> selectedIds;
  final ValueChanged<MediaAsset> onItemTap;
  final ValueChanged<MediaAsset> onSelectToggle;
  final MediaGalleryAction onAction;
  final bool isAdmin;
  final String? albumName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          albumName != null ? '$albumName — Gallery' : 'Recent Uploads',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '${items.length} ${items.length == 1 ? 'item' : 'items'}',
          style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AdminTheme.cardDecoration(radius: 16),
            child: const Center(child: Text('No media in this album yet.', style: TextStyle(color: AdminTheme.textSecondary))),
          )
        else
          MediaGalleryGrid(
            items: items,
            selectedIds: selectedIds,
            onItemTap: onItemTap,
            onSelectToggle: onSelectToggle,
            onAction: onAction,
            isAdmin: isAdmin,
          ),
      ],
    );
  }
}
