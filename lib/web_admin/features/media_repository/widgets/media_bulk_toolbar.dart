import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class MediaBulkToolbar extends StatelessWidget {
  const MediaBulkToolbar({
    super.key,
    required this.count,
    required this.isAdmin,
    required this.onClear,
    required this.onDownload,
    required this.onPublish,
    required this.onMove,
    required this.onArchive,
    required this.onDelete,
  });

  final int count;
  final bool isAdmin;
  final VoidCallback onClear;
  final VoidCallback onDownload;
  final VoidCallback onPublish;
  final VoidCallback onMove;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: Center(
        child: Material(
          elevation: 12,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          color: AdminTheme.textPrimary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Text('$count selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 8),
                _BulkBtn(icon: Icons.download_outlined, label: 'Download', onTap: onDownload),
                _BulkBtn(icon: Icons.drive_file_move_outline, label: 'Move', onTap: onMove),
                if (isAdmin) ...[
                  _BulkBtn(icon: Icons.archive_outlined, label: 'Archive', onTap: onArchive),
                  _BulkBtn(icon: Icons.delete_outline, label: 'Delete', onTap: onDelete, danger: true),
                  _BulkBtn(icon: Icons.facebook, label: 'Publish to Facebook', onTap: onPublish),
                ],
                IconButton(onPressed: onClear, icon: const Icon(Icons.close, color: Colors.white70, size: 20), tooltip: 'Clear selection'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: danger ? const Color(0xFFFCA5A5) : Colors.white),
      label: Text(label, style: TextStyle(color: danger ? const Color(0xFFFCA5A5) : Colors.white, fontSize: 12)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    );
  }
}
