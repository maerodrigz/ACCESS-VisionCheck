import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/screens/member_gallery_media_viewer.dart';
import 'package:access_mobile/mobile_app/widgets/gallery_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/shared/services/facebook_links.dart';
import 'package:access_mobile/shared/services/facebook_open_url.dart';

enum _AlbumMediaFilter { all, photos, videos }

/// Event media detail — approved event photos/videos only (from [appState.eventGallery]).
class EventAlbumScreen extends StatefulWidget {
  const EventAlbumScreen({
    super.key,
    required this.album,
    this.requestorMode = false,
  });

  final EventGalleryAlbum album;
  final bool requestorMode;

  @override
  State<EventAlbumScreen> createState() => _EventAlbumScreenState();
}

class _EventAlbumScreenState extends State<EventAlbumScreen> {
  _AlbumMediaFilter _filter = _AlbumMediaFilter.all;

  /// Media for this event album only — never member evaluation uploads.
  List<EventGalleryMedia> get _albumMedia =>
      appState.eventGallery.where((m) => m.albumId == widget.album.id).toList();

  List<EventGalleryMedia> get _filtered {
    switch (_filter) {
      case _AlbumMediaFilter.photos:
        return _albumMedia.where((m) => m.isPhoto).toList();
      case _AlbumMediaFilter.videos:
        return _albumMedia.where((m) => m.isVideo).toList();
      case _AlbumMediaFilter.all:
        return _albumMedia;
    }
  }

  String? get _eventDescription {
    final fromAlbum = widget.album.eventDescription?.trim();
    if (fromAlbum != null && fromAlbum.isNotEmpty) return fromAlbum;

    final reqId = widget.album.requestId;
    if (reqId == null) return null;
    for (final event in appState.events) {
      if (event.requestId == reqId) {
        final d = event.description.trim();
        if (d.isNotEmpty) return d;
      }
    }
    return null;
  }

  int _gridCrossAxisCount(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 5;
    if (w >= 600) return 4;
    if (w >= 380) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    // Request notes / coverage instructions live on Calendar and My Assignments, not gallery browse.
    final description = widget.requestorMode ? _eventDescription : null;
    final facebookLink = widget.requestorMode
        ? resolveEventGalleryFacebookLink(_albumMedia)
        : null;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventDetailHeader(
              album: widget.album,
              description: description,
              requestorMode: widget.requestorMode,
              facebookLink: facebookLink,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            _EventDetailFilterTabs(
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([appState, memberDataController]),
                builder: (_, __) {
                  if (memberDataController.eventGalleryLoading && _albumMedia.isEmpty) {
                    return _EventAlbumLoadingGrid(
                      padding: padding,
                      crossAxisCount: _gridCrossAxisCount(context),
                    );
                  }

                  final filtered = _filtered;
                  if (filtered.isEmpty) {
                    return MobileEmptyState(
                      icon: _filter == _AlbumMediaFilter.videos
                          ? Icons.videocam_outlined
                          : _filter == _AlbumMediaFilter.photos
                              ? Icons.photo_outlined
                              : Icons.photo_library_outlined,
                      title: 'No media in this filter',
                      subtitle: _filter == _AlbumMediaFilter.all
                          ? 'Approved photos and videos for this event will appear here.'
                          : 'No ${_filter == _AlbumMediaFilter.photos ? 'photos' : 'videos'} for this event yet.',
                    );
                  }

                  final crossAxisCount = _gridCrossAxisCount(context);
                  final compact = MediaQuery.sizeOf(context).width < 360;

                  return RefreshIndicator(
                    color: kMemberDashboardAccent,
                    onRefresh: () => memberDataController.refreshEventGallery(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(padding, 4, padding, 24),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: compact ? 5 : 6,
                              mainAxisSpacing: compact ? 5 : 6,
                              childAspectRatio: 1,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = filtered[index];
                                return _EventMediaGridTile(
                                  item: item,
                                  onTap: () => _openMedia(context, item),
                                );
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMedia(BuildContext context, EventGalleryMedia item) {
    final filtered = _filtered;
    final index = filtered.indexWhere((m) => m.id == item.id);
    openMemberGalleryMediaViewer(
      context,
      items: filtered,
      initialIndex: index >= 0 ? index : 0,
      eventName: widget.album.name,
      eventDate: widget.album.date,
      allowDownload: widget.requestorMode,
    );
  }
}

class _EventDetailHeader extends StatelessWidget {
  const _EventDetailHeader({
    required this.album,
    required this.description,
    required this.onBack,
    this.requestorMode = false,
    this.facebookLink,
  });

  final EventGalleryAlbum album;
  final String? description;
  final VoidCallback onBack;
  final bool requestorMode;
  final EventGalleryFacebookLink? facebookLink;

  @override
  Widget build(BuildContext context) {
    if (requestorMode) {
      return _RequestorEventDetailHeader(
        album: album,
        description: description,
        facebookLink: facebookLink,
        onBack: onBack,
      );
    }
    return _MemberEventDetailHeader(
      album: album,
      onBack: onBack,
    );
  }
}

/// Cover-image hero header for requestor event albums.
class _RequestorEventDetailHeader extends StatelessWidget {
  const _RequestorEventDetailHeader({
    required this.album,
    required this.description,
    required this.onBack,
    this.facebookLink,
  });

  final EventGalleryAlbum album;
  final String? description;
  final VoidCallback onBack;
  final EventGalleryFacebookLink? facebookLink;

  static const _heroHeight = 132.0;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;
    final coverUrl = album.coverUrl.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, compact ? 4 : 6, padding, compact ? 6 : 8),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
          border: Border.all(color: kBorder),
          boxShadow: memberDashboardCardShadows(tint: kAccent),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _heroHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _RequestorAlbumCoverFallback(),
                    )
                  else
                    const _RequestorAlbumCoverFallback(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.52),
                          Colors.black.withValues(alpha: 0.78),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _RequestorHeroBackButton(onBack: onBack),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Your event',
                            style: dashText(const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            )),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: dashText(const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.2,
                          )),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                album.dateLabel,
                                style: dashText(TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                )),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 14,
                compact ? 12 : 14,
                compact ? 12 : 14,
                compact ? 12 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (album.eventCategory != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kBlueDim,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kAccent.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        album.eventCategory!,
                        style: memberDashboardMetaStyle.copyWith(
                          fontSize: compact ? 11 : 12,
                          color: kAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 10 : 12),
                  ],
                  if (description != null) ...[
                    Text(
                      description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: memberDashboardBodyStyle.copyWith(
                        fontSize: compact ? 12 : 13,
                        height: 1.45,
                        color: kTextSecondary,
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 14),
                  ],
                  Row(
                    children: [
                      if (album.photoCount > 0)
                        Expanded(
                          child: _RequestorMediaStatTile(
                            icon: Icons.photo_library_rounded,
                            value: '${album.photoCount}',
                            label: album.photoCount == 1 ? 'Photo' : 'Photos',
                            accent: kCyan,
                            background: kCyanDim,
                            compact: compact,
                          ),
                        ),
                      if (album.photoCount > 0 && album.videoCount > 0)
                        SizedBox(width: compact ? 8 : 10),
                      if (album.videoCount > 0)
                        Expanded(
                          child: _RequestorMediaStatTile(
                            icon: Icons.videocam_rounded,
                            value: '${album.videoCount}',
                            label: album.videoCount == 1 ? 'Video' : 'Videos',
                            accent: kDashStatPurpleIcon,
                            background: kPurpleDim,
                            compact: compact,
                          ),
                        ),
                      if (album.photoCount == 0 && album.videoCount == 0)
                        Expanded(
                          child: _RequestorMediaStatTile(
                            icon: Icons.photo_library_outlined,
                            value: '0',
                            label: 'Media',
                            accent: kAccent,
                            background: kBlueDim,
                            compact: compact,
                          ),
                        ),
                    ],
                  ),
                  if (facebookLink != null) ...[
                    SizedBox(height: compact ? 12 : 14),
                    _RequestorFacebookLinkButton(link: facebookLink!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestorFacebookLinkButton extends StatelessWidget {
  const _RequestorFacebookLinkButton({required this.link});

  final EventGalleryFacebookLink link;

  static const _facebookBlue = Color(0xFF1877F2);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final opened = await openExternalUrl(link.url);
          if (!context.mounted) return;
          if (!opened) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open Facebook. Check your browser or Facebook app.'),
              ),
            );
          }
        },
        icon: const Icon(Icons.facebook_rounded, size: 18, color: _facebookBlue),
        label: Text(
          link.buttonLabel,
          style: memberDashboardMetaStyle.copyWith(
            color: _facebookBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _facebookBlue,
          side: BorderSide(color: _facebookBlue.withValues(alpha: 0.35)),
          backgroundColor: _facebookBlue.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _RequestorAlbumCoverFallback extends StatelessWidget {
  const _RequestorAlbumCoverFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kAccent.withValues(alpha: 0.85),
            const Color(0xFF0F2744),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_library_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _RequestorHeroBackButton extends StatelessWidget {
  const _RequestorHeroBackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onBack,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _RequestorMediaStatTile extends StatelessWidget {
  const _RequestorMediaStatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    required this.background,
    required this.compact,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final Color background;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 110;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: stacked ? 8 : (compact ? 10 : 12),
            vertical: stacked ? 10 : (compact ? 10 : 11),
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, color: accent, size: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: dashText(TextStyle(
                        color: kTextPrimary,
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      )),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: dashText(TextStyle(
                        color: kTextSecondary,
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w500,
                      )),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, color: accent, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: dashText(TextStyle(
                              color: kTextPrimary,
                              fontSize: compact ? 16 : 17,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            )),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: dashText(TextStyle(
                              color: kTextSecondary,
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w500,
                            )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _MemberEventDetailHeader extends StatelessWidget {
  const _MemberEventDetailHeader({
    required this.album,
    required this.onBack,
  });

  final EventGalleryAlbum album;
  final VoidCallback onBack;

  static const _coverAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final padding = mobilePagePaddingOf(context);
    final coverUrl = album.coverUrl.trim();

    return ColoredBox(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, compact ? 4 : 6, padding, 8),
            child: Row(
              children: [
                Material(
                  color: kSurface,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onBack,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: compact ? 20 : 22,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Event album',
                    style: memberDashboardMetaStyle.copyWith(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: _coverAspectRatio,
                child: coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _MemberAlbumCoverFallback(),
                      )
                    : const _MemberAlbumCoverFallback(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              padding,
              compact ? 10 : 12,
              padding,
              compact ? 10 : 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.name,
                  style: memberDashboardSectionTitleStyle.copyWith(
                    fontSize: compact ? 17 : 18,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: compact ? 13 : 14,
                      color: kAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      album.dateLabel,
                      style: TextStyle(
                        color: kTextSecondary,
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (album.eventCategory != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      album.eventCategory!,
                      style: TextStyle(
                        color: kAccent,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _EventDetailMediaSummary(album: album, compact: compact),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: kBorder.withValues(alpha: 0.7)),
        ],
      ),
    );
  }
}

class _MemberAlbumCoverFallback extends StatelessWidget {
  const _MemberAlbumCoverFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kSurfaceAlt,
      child: Center(
        child: Icon(Icons.photo_library_outlined, size: 40, color: kAccent.withValues(alpha: 0.55)),
      ),
    );
  }
}

class _EventDetailMediaSummary extends StatelessWidget {
  const _EventDetailMediaSummary({
    required this.album,
    required this.compact,
  });

  final EventGalleryAlbum album;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (album.photoCount > 0) {
      parts.add('${album.photoCount} Photo${album.photoCount == 1 ? '' : 's'}');
    }
    if (album.videoCount > 0) {
      parts.add('${album.videoCount} Video${album.videoCount == 1 ? '' : 's'}');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    final label = parts.join(' • ');

    return Row(
      children: [
        Icon(
          Icons.photo_library_outlined,
          size: compact ? 14 : 15,
          color: kAccent,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: kAccent,
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}




class _EventDetailFilterTabs extends StatelessWidget {
  const _EventDetailFilterTabs({
    required this.selected,
    required this.onSelected,
  });

  final _AlbumMediaFilter selected;
  final ValueChanged<_AlbumMediaFilter> onSelected;

  static const _labels = {
    _AlbumMediaFilter.all: 'All',
    _AlbumMediaFilter.photos: 'Photos',
    _AlbumMediaFilter.videos: 'Videos',
  };

  static const _icons = {
    _AlbumMediaFilter.all: Icons.grid_view_rounded,
    _AlbumMediaFilter.photos: Icons.photo_outlined,
    _AlbumMediaFilter.videos: Icons.videocam_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 6, padding, compact ? 8 : 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: _AlbumMediaFilter.values.map((filter) {
              return Expanded(
                child: _EventDetailFilterTab(
                  label: _labels[filter]!,
                  icon: _icons[filter]!,
                  inactiveIconColor: switch (filter) {
                    _AlbumMediaFilter.all => kAccent,
                    _AlbumMediaFilter.photos => kGreen,
                    _AlbumMediaFilter.videos => kCyan,
                  },
                  active: selected == filter,
                  compact: compact,
                  onTap: () => onSelected(filter),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _EventDetailFilterTab extends StatelessWidget {
  const _EventDetailFilterTab({
    required this.label,
    required this.icon,
    required this.inactiveIconColor,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color inactiveIconColor;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(vertical: compact ? 9 : 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: active ? kMemberDashboardAccentGradient : null,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: kMemberDashboardAccent.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: compact ? 14 : 15,
                  color: active ? Colors.white : inactiveIconColor,
                ),
                SizedBox(width: compact ? 4 : 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(TextStyle(
                      color: active ? Colors.white : kTextSecondary,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventMediaGridTile extends StatelessWidget {
  const _EventMediaGridTile({
    required this.item,
    required this.onTap,
  });

  final EventGalleryMedia item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isPhoto)
              GalleryMediaThumbnail(url: item.thumbnailUrl, isVideo: false)
            else
              GalleryMediaThumbnail(url: item.thumbnailUrl, isVideo: true),
            if (item.isVideo)
              Container(
                color: Colors.black.withValues(alpha: 0.22),
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventAlbumLoadingGrid extends StatelessWidget {
  const _EventAlbumLoadingGrid({
    required this.padding,
    required this.crossAxisCount,
  });

  final double padding;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    const cells = 9;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(padding, 4, padding, 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => DecoratedBox(
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: kMemberDashboardAccentLight.withValues(alpha: 0.65),
                  ),
                ),
              ),
              childCount: cells,
            ),
          ),
        ),
      ],
    );
  }
}
