import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class MediaStatsRow extends StatelessWidget {
  const MediaStatsRow({super.key, required this.stats});

  final MediaLibraryStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 560 ? 2 : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: cols >= 4 ? 2.4 : 2.1,
          children: [
            _StatCard(icon: Icons.photo_library_outlined, label: 'Total Photos', value: '${stats.totalPhotos}', color: AdminTheme.accentBlue),
            _StatCard(icon: Icons.videocam_outlined, label: 'Total Videos', value: '${stats.totalVideos}', color: const Color(0xFF0891B2)),
            _StatCard(icon: Icons.collections_bookmark_outlined, label: 'Total Albums', value: '${stats.totalAlbums}', color: const Color(0xFF7C3AED)),
            _StatCard(icon: Icons.storage_outlined, label: 'Storage Used', value: stats.storageUsedLabel, color: AdminTheme.success),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: AdminTheme.cardDecoration().copyWith(
          border: Border.all(color: _hovered ? widget.color.withValues(alpha: 0.35) : AdminTheme.border),
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, height: 1)),
                  const SizedBox(height: 4),
                  Text(widget.label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
