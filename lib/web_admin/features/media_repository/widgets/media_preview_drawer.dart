import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_models.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/best_shots_row.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class MediaPreviewDrawer extends StatelessWidget {
  const MediaPreviewDrawer({
    super.key,
    required this.item,
    required this.open,
    required this.isAdmin,
    required this.onClose,
    required this.onDownload,
    required this.onPublishFacebook,
    required this.onMoveToAlbum,
    required this.onArchive,
    required this.onDelete,
    required this.onToggleBestShot,
  });

  final MediaAsset? item;
  final bool open;
  final bool isAdmin;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final VoidCallback onPublishFacebook;
  final VoidCallback onMoveToAlbum;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onToggleBestShot;

  @override
  Widget build(BuildContext context) {
    final m = item;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: open ? 0 : -560,
      width: 540,
      child: Material(
        elevation: 16,
        shadowColor: Colors.black26,
        child: Container(
          decoration: const BoxDecoration(color: AdminTheme.surface, border: Border(left: BorderSide(color: AdminTheme.border))),
          child: m == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DrawerHeader(title: m.fileName, onClose: onClose),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PreviewImage(item: m),
                            const SizedBox(height: 20),
                            _Section(
                              title: 'Event information',
                              children: [
                                _InfoRow(label: 'Event name', value: m.eventName),
                                _InfoRow(label: 'Album', value: m.albumName),
                                _InfoRow(label: 'Upload date', value: m.uploadDateLabel ?? '—'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _Section(
                              title: 'Media details',
                              children: [
                                _InfoRow(label: 'File name', value: m.fileName),
                                _InfoRow(label: 'File type', value: m.mediaTypeLabel),
                                _InfoRow(label: 'Resolution', value: m.resolutionLabel),
                                _InfoRow(label: 'File size', value: m.estimatedFileSize),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _Section(
                              title: 'Uploader',
                              children: [
                                _InfoRow(label: m.uploaderRoleLabel, value: m.uploaderName),
                              ],
                            ),
                            if (m.isPublished) ...[
                              const SizedBox(height: 12),
                              const FacebookPublishedBadge(),
                            ],
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ActionButton(icon: Icons.download_outlined, label: 'Download', onTap: onDownload),
                                _ActionButton(icon: Icons.folder_outlined, label: 'Move to Album', onTap: onMoveToAlbum),
                                if (isAdmin) ...[
                                  _ActionButton(
                                    icon: m.isBestShot ? Icons.star : Icons.star_outline,
                                    label: m.isBestShot ? 'Remove Best Shot' : 'Mark Best Shot',
                                    onTap: onToggleBestShot,
                                  ),
                                  _ActionButton(icon: Icons.archive_outlined, label: 'Archive', onTap: onArchive),
                                  _ActionButton(icon: Icons.delete_outline, label: 'Delete', onTap: onDelete, color: AdminTheme.danger),
                                  _ActionButton(
                                    icon: Icons.facebook,
                                    label: 'Publish to Facebook',
                                    onTap: onPublishFacebook,
                                    color: AdminTheme.facebookBlue,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AdminTheme.border))),
      child: Row(
        children: [
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.item});

  final MediaAsset item;

  @override
  Widget build(BuildContext context) {
    final url = item.thumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isNotEmpty && item.isPhoto)
              Image.network(url, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(gradient: AdminTheme.albumGradientAt(item.id % 5)),
                child: item.isVideo ? const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 56)) : null,
              ),
            if (item.isPublished) const Positioned(top: 10, left: 10, child: FacebookPublishedBadge()),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary))),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AdminTheme.accentBlue;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: c),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
