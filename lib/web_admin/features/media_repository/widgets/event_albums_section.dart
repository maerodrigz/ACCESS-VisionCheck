import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_models.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class EventAlbumsSection extends StatelessWidget {
  const EventAlbumsSection({
    super.key,
    required this.albums,
    required this.selectedAlbumId,
    required this.onAlbumTap,
    required this.onClearAlbum,
  });

  final List<MediaAlbum> albums;
  final String? selectedAlbumId;
  final ValueChanged<MediaAlbum> onAlbumTap;
  final VoidCallback onClearAlbum;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Event Albums',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary),
              ),
            ),
            if (selectedAlbumId != null)
              TextButton.icon(
                onPressed: onClearAlbum,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Show all albums'),
                style: TextButton.styleFrom(foregroundColor: AdminTheme.accentBlue),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => EventAlbumCard(
              album: albums[i],
              selected: albums[i].id == selectedAlbumId,
              onTap: () => onAlbumTap(albums[i]),
              gradientIndex: i,
            ),
          ),
        ),
      ],
    );
  }
}

class EventAlbumCard extends StatefulWidget {
  const EventAlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    required this.gradientIndex,
    this.selected = false,
  });

  final MediaAlbum album;
  final VoidCallback onTap;
  final int gradientIndex;
  final bool selected;

  @override
  State<EventAlbumCard> createState() => _EventAlbumCardState();
}

class _EventAlbumCardState extends State<EventAlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.album;
    final dateStr = a.date != null ? _formatDate(a.date!) : 'Date TBD';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
          width: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.selected
                  ? AdminTheme.accentBlue
                  : _hovered
                      ? AdminTheme.accentBlue.withValues(alpha: 0.4)
                      : AdminTheme.border,
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: _hovered || widget.selected ? AdminTheme.cardShadow : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (a.coverUrl.isNotEmpty)
                Image.network(
                  a.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(gradient: AdminTheme.albumGradientAt(widget.gradientIndex)),
                  ),
                )
              else
                Container(decoration: BoxDecoration(gradient: AdminTheme.albumGradientAt(widget.gradientIndex))),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.78), Colors.transparent],
                    stops: const [0.0, 0.65],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CountPill(icon: Icons.photo_outlined, label: '${a.photoCount} Photos'),
                        const SizedBox(width: 6),
                        _CountPill(icon: Icons.videocam_outlined, label: '${a.videoCount} Videos'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
