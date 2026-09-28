import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_models.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/best_shots_row.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

typedef MediaTileAction = void Function(String action, MediaAsset item);

class MediaTile extends StatefulWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onSelectToggle,
    required this.onAction,
    required this.isAdmin,
    this.aspectRatio = 1.0,
  });

  final MediaAsset item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSelectToggle;
  final MediaTileAction onAction;
  final bool isAdmin;
  final double aspectRatio;

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final url = item.thumbnailUrl;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.selected ? AdminTheme.accentBlue : AdminTheme.border, width: widget.selected ? 2 : 1),
            boxShadow: _hovered || widget.selected ? AdminTheme.cardShadow : null,
            color: AdminTheme.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url.isNotEmpty && item.isPhoto)
                      Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(item))
                    else
                      _placeholder(item),
                    if (item.isVideo)
                      const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 44)),
                    Positioned(top: 8, left: 8, child: _TypeChip(label: item.mediaTypeLabel)),
                    if (item.isBestShot)
                      const Positioned(top: 8, right: 40, child: Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 22)),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: widget.onSelectToggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: widget.selected ? AdminTheme.accentBlue : Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: widget.selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                        ),
                      ),
                    ),
                    if (_hovered)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              _HoverAction(icon: Icons.visibility_outlined, label: 'Preview', onTap: widget.onTap),
                              _HoverAction(icon: Icons.download_outlined, label: 'Download', onTap: () => widget.onAction('download', item)),
                              _HoverAction(icon: Icons.drive_file_move_outline, label: 'Move', onTap: () => widget.onAction('move', item)),
                              if (widget.isAdmin) ...[
                                _HoverAction(icon: Icons.archive_outlined, label: 'Archive', onTap: () => widget.onAction('archive', item)),
                                _HoverAction(icon: Icons.delete_outline, label: 'Delete', onTap: () => widget.onAction('delete', item)),
                                _HoverAction(icon: Icons.facebook, label: 'Publish', onTap: () => widget.onAction('publish', item)),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.eventName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(item.uploaderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
                    if (item.uploadDateLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(item.uploadDateLabel!, style: const TextStyle(fontSize: 10, color: AdminTheme.textSecondary)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TypeChip(label: item.mediaTypeLabel, mini: true),
                        const Spacer(),
                        PublishedStatusPill(published: item.isPublished),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(MediaAsset item) {
    return Container(decoration: BoxDecoration(gradient: AdminTheme.albumGradientAt(item.id % 5)));
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, this.mini = false});

  final String label;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: mini ? 6 : 8, vertical: mini ? 2 : 4),
      decoration: BoxDecoration(
        color: mini ? AdminTheme.accentBlue.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: mini ? AdminTheme.accentBlue : Colors.white,
          fontSize: mini ? 9 : 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HoverAction extends StatelessWidget {
  const _HoverAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AdminTheme.accentBlue),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
