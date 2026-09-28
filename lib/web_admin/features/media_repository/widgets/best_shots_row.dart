import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class BestShotsRow extends StatelessWidget {
  const BestShotsRow({
    super.key,
    required this.items,
    required this.onPreview,
    required this.isAdmin,
    required this.onToggleBestShot,
  });

  final List<MediaAsset> items;
  final ValueChanged<MediaAsset> onPreview;
  final bool isAdmin;
  final ValueChanged<MediaAsset> onToggleBestShot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Best Shots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text(
                    'Curated highlights marked by administrators',
                    style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              Text(
                'Mark from preview drawer',
                style: TextStyle(fontSize: 11, color: AdminTheme.textSecondary.withValues(alpha: 0.9)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AdminTheme.cardDecoration(radius: 16),
            child: const Text(
              'No best shots yet. Open any media preview and mark it as a Best Shot.',
              style: TextStyle(fontSize: 13, color: AdminTheme.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _BestShotCard(
                item: items[i],
                onPreview: () => onPreview(items[i]),
                isAdmin: isAdmin,
                onToggleBestShot: () => onToggleBestShot(items[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _BestShotCard extends StatefulWidget {
  const _BestShotCard({
    required this.item,
    required this.onPreview,
    required this.isAdmin,
    required this.onToggleBestShot,
  });

  final MediaAsset item;
  final VoidCallback onPreview;
  final bool isAdmin;
  final VoidCallback onToggleBestShot;

  @override
  State<_BestShotCard> createState() => _BestShotCardState();
}

class _BestShotCardState extends State<_BestShotCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final url = item.thumbnailUrl;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 240,
        decoration: AdminTheme.cardDecoration(radius: 18).copyWith(boxShadow: _hovered ? AdminTheme.cardShadow : null),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url.isNotEmpty && item.isPhoto)
                    Image.network(url, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(gradient: AdminTheme.albumGradientAt(item.id)),
                      child: item.isVideo
                          ? const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40))
                          : null,
                    ),
                  if (item.isPublished)
                    const Positioned(top: 8, left: 8, child: FacebookPublishedBadge(compact: true)),
                  if (widget.isAdmin && _hovered)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        onPressed: widget.onToggleBestShot,
                        icon: const Icon(Icons.star, size: 16),
                        tooltip: 'Remove from Best Shots',
                        style: IconButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(32, 32)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.eventName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${item.uploaderRoleLabel}: ${item.uploaderName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                  if (item.uploadDateLabel != null)
                    Text(item.uploadDateLabel!, style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: widget.onPreview,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminTheme.accentBlue,
                      side: const BorderSide(color: AdminTheme.accentBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FacebookPublishedBadge extends StatelessWidget {
  const FacebookPublishedBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: AdminTheme.facebookBlue.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.facebook, size: compact ? 11 : 12, color: Colors.white),
          if (!compact) ...[
            const SizedBox(width: 4),
            const Text('Facebook Published', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ],
      ),
    );
  }
}

class PublishedStatusPill extends StatelessWidget {
  const PublishedStatusPill({super.key, required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    if (published) return const FacebookPublishedBadge(compact: true);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AdminTheme.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('Draft', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AdminTheme.textSecondary)),
    );
  }
}
