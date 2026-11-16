import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/screens/member_gallery_media_viewer.dart';
import 'package:access_mobile/mobile_app/widgets/gallery_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

enum _AlbumMediaFilter { all, photos, videos }

const _kAlbumDetailBg = Color(0xFFF2F9FD);
const _kAlbumDetailCyan = Color(0xFF00C4E8);

/// Shared event album detail for Member and Requestor browse.
///
/// Layout matches the Requestor album experience. [requestorMode] only gates
/// Requestor-only capabilities (currently download in the media viewer) and the
/// "Your event" badge — it does not change media access rules.
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
    // Shared album grid: Infinix X695 (~392 logical px) → 3 columns; narrow / large text → 2.
    if (w < 340 || textScale >= 1.35) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final description = _eventDescription;

    return Scaffold(
      backgroundColor: _kAlbumDetailBg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([appState, memberDataController]),
          builder: (context, _) {
            final galleryError = memberDataController.eventGalleryError;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AlbumDetailHeader(
                  album: widget.album,
                  description: description,
                  photoCount: _livePhotoCount,
                  videoCount: _liveVideoCount,
                  badgeLabel:
                      widget.requestorMode ? 'Your event' : null,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                _AlbumEventMediaHeading(
                  totalCount: _albumMedia.length,
                ),
                _EventDetailFilterTabs(
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
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

                      if (_albumMedia.isEmpty &&
                          galleryError != null &&
                          galleryError.trim().isNotEmpty) {
                        return MobileEmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'Could not load album media',
                          subtitle: galleryError.trim(),
                          actionLabel: 'Retry',
                          onAction: () =>
                              memberDataController.refreshEventGallery(),
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
                      final gap = compact ? 6.0 : 7.0;

                      return RefreshIndicator(
                        color: _kAlbumDetailCyan,
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
                                2,
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
      // Download remains Requestor-only.
      allowDownload: widget.requestorMode,
    );
  }
}

/// Compact light-blue album summary shared by Member and Requestor album detail.
class _AlbumDetailHeader extends StatelessWidget {
  const _AlbumDetailHeader({
    required this.album,
    required this.description,
    required this.photoCount,
    required this.videoCount,
    required this.onBack,
    this.badgeLabel,
  });

  final EventGalleryAlbum album;
  final String? description;
  final int photoCount;
  final int videoCount;
  final VoidCallback onBack;
  final String? badgeLabel;

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
                    if (badgeLabel != null && badgeLabel!.trim().isNotEmpty) ...[
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
                          badgeLabel!,
                          style: dashText(const TextStyle(
                            color: kAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.15,
                          )),
                        ),
                      ),
                    ],
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
                    _AlbumCountChip(
                      icon: Icons.photo_library_rounded,
                      label:
                          '$photoCount photo${photoCount == 1 ? '' : 's'}',
                      iconColor: kGreen,
                      background: kGreenDim,
                      compact: compact,
                    ),
                    _AlbumCountChip(
                      icon: Icons.videocam_rounded,
                      label:
                          '$videoCount video${videoCount == 1 ? '' : 's'}',
                      iconColor: _kAlbumDetailCyan,
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

class _AlbumCountChip extends StatelessWidget {
  const _AlbumCountChip({
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

class _AlbumEventMediaHeading extends StatelessWidget {
  const _AlbumEventMediaHeading({required this.totalCount});

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
      padding: EdgeInsets.fromLTRB(padding, 0, padding, compact ? 6 : 8),
      child: Row(
        children: [
          for (var i = 0; i < _AlbumMediaFilter.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _EventDetailFilterTab(
                label: _labels[_AlbumMediaFilter.values[i]]!,
                icon: _icons[_AlbumMediaFilter.values[i]]!,
                active: selected == _AlbumMediaFilter.values[i],
                compact: compact,
                onTap: () => onSelected(_AlbumMediaFilter.values[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventDetailFilterTab extends StatelessWidget {
  const _EventDetailFilterTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active ? _kAlbumDetailCyan : kSurface,
            border: Border.all(
              color: active ? _kAlbumDetailCyan : kBorder,
            ),
            boxShadow: active
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 14 : 15,
                color: active ? Colors.white : kTextSecondary,
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
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GalleryMediaThumbnail(
              url: item.thumbnailUrl,
              isVideo: item.isVideo,
              fallbackIconSize: 28,
            ),
            if (item.isVideo) ...[
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
              ),
              Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
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
