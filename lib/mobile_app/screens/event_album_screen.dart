import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/screens/member_gallery_media_viewer.dart';
import 'package:access_mobile/mobile_app/widgets/gallery_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/member_network_image.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

enum _AlbumMediaFilter { all, photos, videos }

const _kAlbumRequestorBg = Color(0xFFF2F9FD);
const _kAlbumRequestorCyan = Color(0xFF00C4E8);

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

  int get _livePhotoCount => _albumMedia.where((m) => m.isPhoto).length;
  int get _liveVideoCount => _albumMedia.where((m) => m.isVideo).length;

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
    for (final req in appState.serviceRequests) {
      if (req.requestId == reqId) {
        final d = req.description?.trim();
        if (d != null && d.isNotEmpty) return d;
      }
    }
    return null;
  }

  int _gridCrossAxisCount(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final textScale = mq.textScaler.scale(1.0);

    if (widget.requestorMode) {
      // Infinix X695 (~392 logical px) → 3 columns; narrow / large text → 2.
      if (w < 340 || textScale >= 1.35) return 2;
      return 3;
    }

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
    final requestor = widget.requestorMode;

    return Scaffold(
      backgroundColor: requestor ? _kAlbumRequestorBg : kBg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([appState, memberDataController]),
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventDetailHeader(
                  album: widget.album,
                  description: description,
                  requestorMode: requestor,
                  photoCount: _livePhotoCount,
                  videoCount: _liveVideoCount,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                if (requestor)
                  _RequestorEventMediaHeading(
                    totalCount: _albumMedia.length,
                  ),
                _EventDetailFilterTabs(
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                  requestorMode: requestor,
                ),
                Expanded(
                  child: Builder(
                    builder: (_) {
                      if (memberDataController.eventGalleryLoading &&
                          _albumMedia.isEmpty) {
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
                      final gap = requestor
                          ? (compact ? 6.0 : 7.0)
                          : (compact ? 5.0 : 6.0);

                      return RefreshIndicator(
                        color: requestor
                            ? _kAlbumRequestorCyan
                            : kMemberDashboardAccent,
                        onRefresh: () =>
                            memberDataController.refreshEventGallery(),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                padding,
                                requestor ? 2 : 4,
                                padding,
                                24,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                  childAspectRatio: 1,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = filtered[index];
                                    return _EventMediaGridTile(
                                      item: item,
                                      requestorMode: requestor,
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
            );
          },
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
    this.photoCount,
    this.videoCount,
  });

  final EventGalleryAlbum album;
  final String? description;
  final VoidCallback onBack;
  final bool requestorMode;
  final int? photoCount;
  final int? videoCount;

  @override
  Widget build(BuildContext context) {
    if (requestorMode) {
      return _RequestorEventDetailHeader(
        album: album,
        description: description,
        photoCount: photoCount ?? album.photoCount,
        videoCount: videoCount ?? album.videoCount,
        onBack: onBack,
      );
    }
    return _MemberEventDetailHeader(
      album: album,
      onBack: onBack,
    );
  }
}

/// Compact light-blue event summary for requestor album details (no cover hero).
class _RequestorEventDetailHeader extends StatelessWidget {
  const _RequestorEventDetailHeader({
    required this.album,
    required this.description,
    required this.photoCount,
    required this.videoCount,
    required this.onBack,
  });

  final EventGalleryAlbum album;
  final String? description;
  final int photoCount;
  final int videoCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, compact ? 4 : 6, padding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Material(
                color: kSurface,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: InkWell(
                  onTap: onBack,
                  customBorder: const CircleBorder(),
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
          SizedBox(height: compact ? 8 : 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 14,
              compact ? 12 : 13,
              compact ? 12 : 14,
              compact ? 12 : 13,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F6FC),
                  Color(0xFFF2F9FD),
                  Color(0xFFEAF2FF),
                ],
              ),
              border: Border.all(color: kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        album.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: kTextPrimary,
                          fontSize: compact ? 16 : 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.2,
                        )),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: kAccent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'Your event',
                        style: dashText(const TextStyle(
                          color: kAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.15,
                        )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: kAccent,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        album.dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dashText(TextStyle(
                          color: kTextSecondary,
                          fontSize: compact ? 12 : 12.5,
                          fontWeight: FontWeight.w500,
                        )),
                      ),
                    ),
                  ],
                ),
                if (description != null && description!.isNotEmpty) ...[
                  SizedBox(height: compact ? 8 : 9),
                  Text(
                    description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(TextStyle(
                      color: kTextSecondary,
                      fontSize: compact ? 12 : 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    )),
                  ),
                ],
                SizedBox(height: compact ? 10 : 11),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _RequestorAlbumCountChip(
                      icon: Icons.photo_library_rounded,
                      label:
                          '$photoCount photo${photoCount == 1 ? '' : 's'}',
                      iconColor: kGreen,
                      background: kGreenDim,
                      compact: compact,
                    ),
                    _RequestorAlbumCountChip(
                      icon: Icons.videocam_rounded,
                      label:
                          '$videoCount video${videoCount == 1 ? '' : 's'}',
                      iconColor: _kAlbumRequestorCyan,
                      background: kCyanDim,
                      compact: compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestorAlbumCountChip extends StatelessWidget {
  const _RequestorAlbumCountChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.background,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color background;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: iconColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: dashText(TextStyle(
              color: kTextPrimary,
              fontSize: compact ? 11 : 11.5,
              fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
    );
  }
}

class _RequestorEventMediaHeading extends StatelessWidget {
  const _RequestorEventMediaHeading({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        padding,
        compact ? 12 : 14,
        padding,
        compact ? 6 : 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Event Media',
              style: dashText(TextStyle(
                color: kTextPrimary,
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.15,
              )),
            ),
          ),
          Text(
            '$totalCount',
            style: dashText(TextStyle(
              color: kTextSecondary,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
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
                    ? MemberNetworkImage(
                        url: coverUrl,
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
    this.requestorMode = false,
  });

  final _AlbumMediaFilter selected;
  final ValueChanged<_AlbumMediaFilter> onSelected;
  final bool requestorMode;

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

    if (requestorMode) {
      return Padding(
        padding: EdgeInsets.fromLTRB(padding, 0, padding, compact ? 6 : 8),
        child: Row(
          children: [
            for (var i = 0; i < _AlbumMediaFilter.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _EventDetailFilterTab(
                  label: _labels[_AlbumMediaFilter.values[i]]!,
                  icon: _icons[_AlbumMediaFilter.values[i]]!,
                  inactiveIconColor: kTextSecondary,
                  active: selected == _AlbumMediaFilter.values[i],
                  compact: compact,
                  requestorStyle: true,
                  onTap: () => onSelected(_AlbumMediaFilter.values[i]),
                ),
              ),
            ],
          ],
        ),
      );
    }

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
    this.requestorStyle = false,
  });

  final String label;
  final IconData icon;
  final Color inactiveIconColor;
  final bool active;
  final bool compact;
  final VoidCallback onTap;
  final bool requestorStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: requestorStyle ? 0 : 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(requestorStyle ? 12 : 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: requestorStyle ? 40 : null,
            padding: EdgeInsets.symmetric(
              vertical: requestorStyle ? 0 : (compact ? 9 : 10),
              horizontal: requestorStyle ? (compact ? 4 : 6) : 0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(requestorStyle ? 12 : 10),
              color: requestorStyle
                  ? (active ? _kAlbumRequestorCyan : kSurface)
                  : null,
              gradient: (!requestorStyle && active)
                  ? kMemberDashboardAccentGradient
                  : null,
              border: requestorStyle
                  ? Border.all(
                      color: active ? _kAlbumRequestorCyan : kBorder,
                    )
                  : null,
              boxShadow: active && !requestorStyle
                  ? [
                      BoxShadow(
                        color: kMemberDashboardAccent.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : (requestorStyle && !active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: compact ? 14 : 15,
                  color: active
                      ? Colors.white
                      : (requestorStyle ? kTextSecondary : inactiveIconColor),
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
    this.requestorMode = false,
  });

  final EventGalleryMedia item;
  final VoidCallback onTap;
  final bool requestorMode;

  @override
  Widget build(BuildContext context) {
    final radius = requestorMode ? 12.0 : 10.0;

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GalleryMediaThumbnail(
              url: item.thumbnailUrl,
              isVideo: item.isVideo,
              fallbackIconSize: requestorMode ? 28 : 36,
            ),
            if (item.isVideo) ...[
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
              ),
              Center(
                child: Container(
                  width: requestorMode ? 32 : 36,
                  height: requestorMode ? 32 : 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: requestorMode ? 20 : 22,
                  ),
                ),
              ),
            ],
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
