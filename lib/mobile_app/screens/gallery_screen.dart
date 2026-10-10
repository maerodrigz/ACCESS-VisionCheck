import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/shared/models/request_status.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/screens/event_album_screen.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

enum _GalleryFilter { all, photos, videos }

/// Shared layout rhythm for the member gallery screen.
const _kGallerySectionTop = 6.0;
const _kGalleryListGap = 10.0;
const _kGalleryListBottom = 20.0;
const _kGalleryEmptyTop = 20.0;
const _kGalleryControlHeight = 36.0;

/// Event album cover frame (16:9).
const _kGalleryAlbumCoverAspectRatio = 16 / 9;

BoxDecoration _gallerySurfaceCardDecoration({List<BoxShadow>? shadows}) =>
    memberDashboardCardDecoration(shadows: shadows ?? memberDashboardCardShadows());

int _galleryCollectionCrossAxisCount(double width) {
  if (width >= 900) return 2;
  if (width >= 600) return 2;
  return 1;
}

double _galleryAlbumMainAxisExtent(double viewportWidth, int columns, double horizontalPadding) {
  final gap = _kGalleryListGap;
  final usable = viewportWidth - horizontalPadding * 2 - gap * (columns - 1);
  final cardWidth = usable / columns;
  final coverHeight = cardWidth / _kGalleryAlbumCoverAspectRatio;
  return coverHeight + 92;
}

Map<int, String> _eventCategoriesByRequestId() {
  final map = <int, String>{};
  for (final event in appState.events) {
    final id = event.requestId;
    final tag = event.tag.trim();
    if (id != null && tag.isNotEmpty) map[id] = tag;
  }
  return map;
}

List<EventGalleryMedia> _enrichGalleryMediaWithCategories(
  Iterable<EventGalleryMedia> source,
  Map<int, String> categories,
) {
  return source.map((m) {
    if (m.requestId == null) return m;
    final cat = categories[m.requestId!];
    if (cat == null || cat == m.eventCategory) return m;
    return EventGalleryMedia(
      id: m.id,
      fileName: m.fileName,
      fileType: m.fileType,
      fileUrl: m.fileUrl,
      uploadedAt: m.uploadedAt,
      requestId: m.requestId,
      eventTitle: m.eventTitle,
      eventDate: m.eventDate,
      eventDescription: m.eventDescription,
      eventCategory: cat,
      facebookPublishStatus: m.facebookPublishStatus,
      facebookPostId: m.facebookPostId,
    );
  }).toList();
}

bool galleryAlbumIsPersonal(EventGalleryAlbum album) {
  final requestId = album.requestId;
  if (requestId != null) {
    if (appState.gallery.any((g) => g.requestId == requestId)) return true;
    for (final task in appState.challenges) {
      if (task.requestId != requestId) continue;
      final status = task.status.toLowerCase();
      if (status == 'cancelled' ||
          status == 'canceled' ||
          status == 'declined' ||
          status == 'completed' ||
          status == 'done') {
        continue;
      }
      return true;
    }
  }
  final key = album.name.trim().toLowerCase();
  if (key.isEmpty) return false;
  return appState.gallery.any((g) {
    final title = g.title.trim().toLowerCase();
    final category = g.category.trim().toLowerCase();
    return title == key || category == key;
  });
}

String galleryAlbumPersonalLabel(EventGalleryAlbum album) {
  final requestId = album.requestId;
  if (requestId != null && appState.gallery.any((g) => g.requestId == requestId)) {
    return 'Your uploads';
  }
  return 'Your event';
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({
    super.key,
    this.onViewCalendar,
    this.onViewPortfolio,
    this.onNotificationsTap,
    this.onProfileTap,
    this.subtitle = 'Explore official event documentation.',
    this.requestorMode = false,
    this.onViewRequests,
  });

  /// Switches the member shell to the Calendar tab (index 2).
  final VoidCallback? onViewCalendar;

  /// Switches the member shell to the Evaluations tab (index 1).
  final VoidCallback? onViewPortfolio;

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  final String subtitle;

  /// Hides member-only controls (My work filter, hero avatar/notification buttons).
  final bool requestorMode;

  /// Requestor shell: open the Requests tab (e.g. from empty gallery).
  final VoidCallback? onViewRequests;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  _GalleryFilter _filter = _GalleryFilter.all;
  String _searchQuery = '';
  bool _myWorkOnly = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.microtask(() {
        if (!mounted) return;
        unawaited(memberDataController.ensureGalleryTab());
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<EventGalleryMedia> get _scopedEventGallery {
    final categories = _eventCategoriesByRequestId();
    var media = _enrichGalleryMediaWithCategories(appState.eventGallery, categories);
    if (widget.requestorMode) {
      final ids = _requestorRequestIds;
      if (ids.isEmpty) {
        return const [];
      }
      media = media.where((m) => m.requestId != null && ids.contains(m.requestId)).toList();
    }
    return media;
  }

  Set<int> get _requestorRequestIds => appState.serviceRequests
      .where(
        (r) =>
            r.requestStatus == RequestStatus.approved ||
            r.requestStatus == RequestStatus.completed,
      )
      .map((r) => r.requestId)
      .whereType<int>()
      .toSet();

  List<EventGalleryMedia> get _mediaForTypeFilter {
    switch (_filter) {
      case _GalleryFilter.photos:
        return _scopedEventGallery.where((m) => m.isPhoto).toList();
      case _GalleryFilter.videos:
        return _scopedEventGallery.where((m) => m.isVideo).toList();
      case _GalleryFilter.all:
        return _scopedEventGallery;
    }
  }

  List<EventGalleryMedia> get _mediaMatchingSearch {
    final q = _searchQuery.trim();
    final base = _mediaForTypeFilter;
    if (q.isEmpty) return base;
    return base.where((m) => m.matchesSearch(q)).toList();
  }

  List<EventGalleryAlbum> get _allAlbums => buildEventGalleryAlbums(
        _mediaMatchingSearch,
        eventCategoriesByRequestId: _eventCategoriesByRequestId(),
      );

  List<EventGalleryAlbum> get _albums {
    var list = _allAlbums;
    if (_myWorkOnly) {
      list = list.where(galleryAlbumIsPersonal).toList();
    }
    final q = _searchQuery.trim();
    if (q.isEmpty) return list;
    return list.where((a) => a.matchesSearch(q)).toList();
  }

  List<EventGalleryAlbum> get _recentAlbums {
    if (_hasActiveSearch) return const [];
    return pickGalleryRecentAlbums(_albums);
  }

  List<EventGalleryAlbum> get _catalogAlbums {
    if (_hasActiveSearch) return _albums;
    return galleryAlbumsExcluding(_albums, _recentAlbums);
  }

  bool get _hasActiveSearch => _searchQuery.trim().isNotEmpty;

  List<EventGalleryAlbum> get _displayAlbums {
    if (_hasActiveSearch) return _albums;
    if (_recentAlbums.isEmpty) return _catalogAlbums;
    return [..._recentAlbums, ..._catalogAlbums];
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _openAlbum(EventGalleryAlbum album) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventAlbumScreen(
          album: album,
          requestorMode: widget.requestorMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);

    return ColoredBox(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([appState, memberDataController]),
            builder: (_, __) {
              final albums = _albums;
              final photos = albums.fold<int>(0, (sum, a) => sum + a.photoCount);
              final videos = albums.fold<int>(0, (sum, a) => sum + a.videoCount);
              final gallerySyncing = (memberDataController.eventGalleryLoading ||
                      memberDataController.galleryTabLoading) &&
                  appState.eventGallery.isNotEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GalleryMemberHeader(
                    subtitle: widget.subtitle,
                    onNotificationsTap: widget.onNotificationsTap,
                    onProfileTap: widget.onProfileTap,
                  ),
                  if (gallerySyncing)
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: kAccent,
                      backgroundColor: kBorder,
                    ),
                  _GalleryStatsRow(
                    albumCount: albums.length,
                    photoCount: photos,
                    videoCount: videos,
                  ),
                ],
              );
            },
          ),
          _GallerySearchBar(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
            hasQuery: _hasActiveSearch,
            hintText: widget.requestorMode
                ? 'Search your documented events…'
                : 'Search event albums...',
          ),
          _GalleryFilterTabs(
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([appState, memberDataController]),
              builder: (_, __) {
                final galleryLoading = (memberDataController.galleryTabLoading ||
                        memberDataController.eventGalleryLoading) &&
                    appState.eventGallery.isEmpty;
                final galleryError = memberDataController.eventGalleryError;

                if (galleryLoading) {
                  return _GalleryLoadingSkeletonList(padding: padding);
                }

                if (galleryError != null && appState.eventGallery.isEmpty) {
                  return RefreshIndicator(
                    color: kMemberDashboardAccent,
                    onRefresh: () => memberDataController.refreshEventGallery(fullCatalog: true),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        _GalleryEmptyStateSliver(
                          padding: padding,
                          child: _GalleryLoadErrorState(
                            onRetry: () =>
                                memberDataController.refreshEventGallery(fullCatalog: true),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (_albums.isEmpty) {
                  final searching = _hasActiveSearch;
                  final noApprovedMedia =
                      appState.eventGallery.isEmpty && galleryError == null;
                  return RefreshIndicator(
                    color: kMemberDashboardAccent,
                    onRefresh: () => memberDataController.refreshEventGallery(fullCatalog: true),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        _GalleryEmptyStateSliver(
                          padding: padding,
                          top: searching ? 16 : _kGalleryEmptyTop,
                          child: searching
                              ? _GalleryInlineEmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: widget.requestorMode
                                      ? 'No matching events'
                                      : 'No matching events',
                                  subtitle: widget.requestorMode
                                      ? 'No albums match "${_searchQuery.trim()}". Try an event name or date.'
                                      : 'No albums match "${_searchQuery.trim()}". Try an event name, date, or media type.',
                                )
                              : widget.requestorMode
                                  ? (_requestorRequestIds.isEmpty
                                      ? _GalleryNoEventMediaEmptyState(
                                          requestorMode: true,
                                          onViewRequests: widget.onViewRequests,
                                        )
                                      : _scopedEventGallery.isEmpty
                                          ? const _GalleryInlineEmptyState(
                                              icon: Icons.photo_library_outlined,
                                              title: 'No albums for your events yet',
                                              subtitle:
                                                  'Photos and videos appear here after ACCESS publishes coverage from your approved documentation requests.',
                                            )
                                          : _GalleryInlineEmptyState(
                                              icon: Icons.filter_alt_outlined,
                                              title: 'No media in this filter',
                                              subtitle:
                                                  'Try All, or switch to Photos or Videos for your documented events.',
                                            ))
                              : _myWorkOnly
                                  ? _GalleryInlineEmptyState(
                                      icon: Icons.person_outline_rounded,
                                      title: 'No albums with your work',
                                      subtitle:
                                          'Turn off My work to browse all event albums, or upload coverage from your assignments.',
                                    )
                                  : noApprovedMedia
                                      ? _GalleryNoEventMediaEmptyState(
                                          requestorMode: widget.requestorMode,
                                          onViewCalendar: widget.onViewCalendar,
                                          onViewPortfolio: widget.onViewPortfolio,
                                          onViewRequests: widget.onViewRequests,
                                        )
                                      : _GalleryInlineEmptyState(
                                          icon: Icons.filter_alt_outlined,
                                          title: 'No media in this filter',
                                          subtitle:
                                              'Try All, or choose Photos or Videos that exist for approved events.',
                                        ),
                        ),
                      ],
                    ),
                  );
                }

                final displayAlbums = _displayAlbums;
                final sectionTitle =
                    _hasActiveSearch ? 'Matching events' : 'Event albums';

                return RefreshIndicator(
                  color: kMemberDashboardAccent,
                  onRefresh: () => memberDataController.refreshEventGallery(fullCatalog: true),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _GalleryListSectionHeader(
                          padding: padding,
                          title: sectionTitle,
                          count: displayAlbums.length,
                          searching: _hasActiveSearch,
                        ),
                      ),
                      _GalleryAlbumSliver(
                        padding: padding,
                        albums: displayAlbums,
                        requestorMode: widget.requestorMode,
                        onOpenAlbum: _openAlbum,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryEmptyStateSliver extends StatelessWidget {
  const _GalleryEmptyStateSliver({
    required this.padding,
    required this.child,
    this.top = _kGalleryEmptyTop,
  });

  final double padding;
  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding, top, padding, 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

class _GalleryListSectionHeader extends StatelessWidget {
  const _GalleryListSectionHeader({
    required this.padding,
    required this.title,
    required this.count,
    required this.searching,
  });

  final double padding;
  final String title;
  final int count;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final countLabel = searching
        ? '$count result${count == 1 ? '' : 's'}'
        : '$count album${count == 1 ? '' : 's'}';

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, _kGallerySectionTop, padding, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: memberDashboardSectionTitleStyle.copyWith(
                    fontSize: compact ? 15 : 16,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                countLabel,
                style: memberDashboardMetaStyle.copyWith(
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GalleryMemberHeader extends StatelessWidget {
  const _GalleryMemberHeader({
    required this.subtitle,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final String subtitle;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return ColoredBox(
      color: kBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, compact ? 8 : 10, padding - 4, compact ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gallery',
                      style: dashText(TextStyle(
                        color: kTextPrimary,
                        fontSize: compact ? 24 : 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.45,
                        height: 1.12,
                      )),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: memberDashboardMetaStyle.copyWith(
                        fontSize: compact ? 12.5 : 13.5,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              MemberPageNotificationButton(onTap: onNotificationsTap),
              MemberPageProfileAvatar(onTap: onProfileTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryStatsRow extends StatelessWidget {
  const _GalleryStatsRow({
    required this.albumCount,
    required this.photoCount,
    required this.videoCount,
  });

  final int albumCount;
  final int photoCount;
  final int videoCount;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 6),
      child: Row(
        children: [
          Expanded(
            child: _GalleryStatCard(
              value: '$albumCount',
              label: 'Albums',
              icon: Icons.photo_album_outlined,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _GalleryStatCard(
              value: '$photoCount',
              label: 'Photos',
              icon: Icons.photo_library_outlined,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _GalleryStatCard(
              value: '$videoCount',
              label: 'Videos',
              icon: Icons.videocam_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryStatCard extends StatelessWidget {
  const _GalleryStatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 7 : 8),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 26 : 28,
            height: compact ? 26 : 28,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: compact ? 14 : 15, color: kAccent),
          ),
          SizedBox(width: compact ? 6 : 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: dashText(TextStyle(
                    color: kTextPrimary,
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  )),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: memberDashboardMetaStyle.copyWith(
                    fontSize: compact ? 9 : 10,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GallerySearchBar extends StatelessWidget {
  const _GallerySearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
    this.hintText = 'Search event albums...',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, compact ? 8 : 10),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        style: memberDashboardMetaStyle.copyWith(
          fontSize: compact ? 13 : 14,
          color: kTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: memberDashboardMetaStyle.copyWith(
            fontSize: compact ? 13 : 14,
            color: kTextSecondary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: kAccent.withValues(alpha: 0.85),
            size: compact ? 20 : 22,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: onClear,
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close_rounded, color: kIconInactive, size: compact ? 20 : 22),
                )
              : null,
          filled: true,
          fillColor: kSurface,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: compact ? 10 : 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: kAccent.withValues(alpha: 0.65), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _GalleryAlbumSliver extends StatelessWidget {
  const _GalleryAlbumSliver({
    required this.padding,
    required this.albums,
    required this.requestorMode,
    required this.onOpenAlbum,
  });

  final double padding;
  final List<EventGalleryAlbum> albums;
  final bool requestorMode;
  final ValueChanged<EventGalleryAlbum> onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final width = MediaQuery.sizeOf(context).width;
    final columns = _galleryCollectionCrossAxisCount(width);

    if (columns == 1) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(padding, 0, padding, _kGalleryListBottom),
        sliver: SliverList.separated(
          itemCount: albums.length,
          separatorBuilder: (_, __) => const SizedBox(height: _kGalleryListGap),
          itemBuilder: (context, index) {
            final album = albums[index];
            return _GalleryAlbumCard(
              album: album,
              isPersonal: !requestorMode && galleryAlbumIsPersonal(album),
              personalLabel:
                  requestorMode ? 'Your event' : galleryAlbumPersonalLabel(album),
              showPersonalBadge: !requestorMode,
              requestorMode: requestorMode,
              onTap: () => onOpenAlbum(album),
            );
          },
        ),
      );
    }

    final mainExtent = _galleryAlbumMainAxisExtent(width, columns, padding);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, _kGalleryListBottom),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: _kGalleryListGap,
          crossAxisSpacing: _kGalleryListGap,
          mainAxisExtent: mainExtent,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final album = albums[index];
            return _GalleryAlbumCard(
              album: album,
              isPersonal: !requestorMode && galleryAlbumIsPersonal(album),
              personalLabel:
                  requestorMode ? 'Your event' : galleryAlbumPersonalLabel(album),
              showPersonalBadge: !requestorMode,
              requestorMode: requestorMode,
              onTap: () => onOpenAlbum(album),
            );
          },
          childCount: albums.length,
        ),
      ),
    );
  }
}

class _GalleryFilterTabs extends StatelessWidget {
  const _GalleryFilterTabs({
    required this.selected,
    required this.onSelected,
  });

  final _GalleryFilter selected;
  final ValueChanged<_GalleryFilter> onSelected;

  static const _labels = {
    _GalleryFilter.all: 'All',
    _GalleryFilter.photos: 'Photos',
    _GalleryFilter.videos: 'Videos',
  };

  static const _icons = {
    _GalleryFilter.all: Icons.grid_view_rounded,
    _GalleryFilter.photos: Icons.photo_library_rounded,
    _GalleryFilter.videos: Icons.videocam_rounded,
  };

  static const _iconsInactive = {
    _GalleryFilter.all: Icons.grid_view_outlined,
    _GalleryFilter.photos: Icons.photo_library_outlined,
    _GalleryFilter.videos: Icons.videocam_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, compact ? 6 : 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
          border: Border.all(color: kBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: _GalleryFilter.values.map((filter) {
              return Expanded(
                child: _GalleryFilterTab(
                  label: _labels[filter]!,
                  icon: selected == filter
                      ? _icons[filter]!
                      : _iconsInactive[filter]!,
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

class _GalleryFilterTab extends StatelessWidget {
  const _GalleryFilterTab({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: _kGalleryControlHeight - 4,
            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: active ? kAccent : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: compact ? 15 : 16,
                  color: active ? Colors.white : kIconInactive,
                ),
                SizedBox(width: compact ? 4 : 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dashText(TextStyle(
                      color: active ? Colors.white : kTextSecondary,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
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

class _GalleryLoadingSkeletonList extends StatefulWidget {
  const _GalleryLoadingSkeletonList({required this.padding});

  final double padding;

  static int skeletonCountFor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.height < 640 || size.width < 360) return 2;
    if (size.height < 780) return 3;
    return 4;
  }

  @override
  State<_GalleryLoadingSkeletonList> createState() =>
      _GalleryLoadingSkeletonListState();
}

class _GalleryLoadingSkeletonListState extends State<_GalleryLoadingSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _GalleryLoadingSkeletonList.skeletonCountFor(context);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.padding,
                  _kGallerySectionTop,
                  widget.padding,
                  8,
                ),
                child: Row(
                  children: [
                    _GallerySkeletonBone(
                      height: 16,
                      width: 112,
                      radius: 6,
                      pulse: t,
                    ),
                    const Spacer(),
                    _GallerySkeletonBone(
                      height: 12,
                      width: 56,
                      radius: 5,
                      pulse: t,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                widget.padding,
                0,
                widget.padding,
                _kGalleryListBottom,
              ),
              sliver: SliverList.separated(
                itemCount: count,
                separatorBuilder: (_, __) => const SizedBox(height: _kGalleryListGap),
                itemBuilder: (context, index) => _GalleryEventCardSkeleton(pulse: t),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GalleryEventCardSkeleton extends StatelessWidget {
  const _GalleryEventCardSkeleton({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: _kGalleryAlbumCoverAspectRatio,
            child: _GallerySkeletonBone(
              height: double.infinity,
              radius: 0,
              pulse: pulse,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 14,
              10,
              compact ? 12 : 14,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GallerySkeletonBone(
                  height: compact ? 14 : 15,
                  radius: 6,
                  pulse: pulse,
                ),
                const SizedBox(height: 8),
                _GallerySkeletonBone(
                  height: compact ? 11 : 12,
                  width: MediaQuery.sizeOf(context).width * 0.35,
                  radius: 5,
                  pulse: pulse,
                ),
                const SizedBox(height: 8),
                _GallerySkeletonBone(
                  height: 10,
                  width: MediaQuery.sizeOf(context).width * 0.5,
                  radius: 5,
                  pulse: pulse,
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

class _GallerySkeletonBone extends StatelessWidget {
  const _GallerySkeletonBone({
    required this.height,
    required this.radius,
    required this.pulse,
    this.width,
  });

  final double height;
  final double? width;
  final double radius;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final dim = kBorder.withValues(alpha: 0.28 + pulse * 0.22);
    final highlight = kMemberDashboardAccentLight.withValues(alpha: 0.06 + pulse * 0.14);

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: radius > 0 ? BorderRadius.circular(radius) : null,
        gradient: LinearGradient(
          begin: Alignment(-1 + pulse * 2, 0),
          end: Alignment(1 + pulse * 2, 0),
          colors: [dim, highlight, dim],
        ),
      ),
    );
  }
}

class _GalleryAlbumCard extends StatelessWidget {
  const _GalleryAlbumCard({
    required this.album,
    required this.isPersonal,
    required this.personalLabel,
    required this.onTap,
    this.showPersonalBadge = true,
    this.requestorMode = false,
  });

  final EventGalleryAlbum album;
  final bool isPersonal;
  final String personalLabel;
  final VoidCallback onTap;
  final bool showPersonalBadge;
  final bool requestorMode;

  static const _facebookBlue = Color(0xFF1877F2);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final accent = requestorMode ? kAccent : (isPersonal ? kMemberPrimary : kAccent);

    return Material(
      color: kSurface,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPersonal ? accent.withValues(alpha: 0.28) : kBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: _kGalleryAlbumCoverAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _AlbumCoverImage(url: album.coverUrl),
                    if (showPersonalBadge && isPersonal)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kMemberPrimary.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            personalLabel,
                            style: dashText(const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            )),
                          ),
                        ),
                      )
                    else if (requestorMode)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Your event',
                            style: dashText(const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            )),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 14,
                  11,
                  compact ? 12 : 14,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: memberDashboardSectionTitleStyle.copyWith(
                        fontSize: compact ? 15 : 16,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 14, color: kTextSecondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            album.dateLabel,
                            style: memberDashboardMetaStyle.copyWith(
                              fontSize: compact ? 12 : 13,
                              color: kTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _GalleryMediaCountChip(
                          icon: Icons.photo_library_outlined,
                          label: '${album.photoCount} photo${album.photoCount == 1 ? '' : 's'}',
                        ),
                        _GalleryMediaCountChip(
                          icon: Icons.videocam_outlined,
                          label: '${album.videoCount} video${album.videoCount == 1 ? '' : 's'}',
                        ),
                      ],
                    ),
                    if (requestorMode && album.hasFacebookPublish) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.facebook_rounded, size: 13, color: _facebookBlue),
                          const SizedBox(width: 4),
                          Text(
                            'On Facebook',
                            style: memberDashboardMetaStyle.copyWith(
                              fontSize: 11,
                              color: _facebookBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryMediaCountChip extends StatelessWidget {
  const _GalleryMediaCountChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccent.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kAccent),
          const SizedBox(width: 5),
          Text(
            label,
            style: memberDashboardMetaStyle.copyWith(
              fontSize: 11,
              color: kTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumCoverImage extends StatelessWidget {
  const _AlbumCoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: kSurfaceAlt,
        child: const Center(
          child: Icon(Icons.photo_library_outlined, color: kIconInactive, size: 36),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: kMemberDashboardAccentLight,
          alignment: Alignment.center,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kMemberDashboardAccent.withValues(alpha: 0.7),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: kSurfaceAlt,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: kIconInactive, size: 32),
        ),
      ),
    );
  }
}

/// Compact gallery-styled panel for search/filter empty results.
class _GalleryInlineEmptyState extends StatelessWidget {
  const _GalleryInlineEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return _GalleryStatusCard(
      compact: compact,
      icon: icon,
      iconGradient: false,
      title: title,
      subtitle: subtitle,
    );
  }
}

class _GalleryStatusCard extends StatelessWidget {
  const _GalleryStatusCard({
    required this.compact,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconGradient = true,
    this.badgeIcon,
    this.action,
  });

  final bool compact;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool iconGradient;
  final IconData? badgeIcon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 44.0 : 48.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 14 : 16,
        ),
        decoration: _gallerySurfaceCardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: iconSize + 22,
              height: iconSize + 22,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: iconSize + 22,
                    height: iconSize + 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kMemberDashboardAccentLight,
                    ),
                  ),
                  Container(
                    width: iconSize + 8,
                    height: iconSize + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kMemberDashboardAccent.withValues(alpha: 0.1),
                    ),
                  ),
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: iconGradient ? kMemberDashboardAccentGradient : null,
                      color: iconGradient ? null : kMemberDashboardAccent.withValues(alpha: 0.14),
                      boxShadow: iconGradient
                          ? [
                              BoxShadow(
                                color: kMemberDashboardAccent.withValues(alpha: 0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: iconGradient ? Colors.white : kMemberDashboardAccent,
                      size: compact ? 24 : 26,
                    ),
                  ),
                  if (badgeIcon != null)
                    Positioned(
                      right: compact ? 4 : 6,
                      bottom: compact ? 4 : 6,
                      child: Container(
                        width: compact ? 22 : 24,
                        height: compact ? 22 : 24,
                        decoration: BoxDecoration(
                          color: kSurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kMemberDashboardAccent.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Icon(
                          badgeIcon,
                          size: compact ? 12 : 13,
                          color: kMemberDashboardAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: memberDashboardSectionTitleStyle.copyWith(
                fontSize: compact ? 16 : 17,
              ),
            ),
            SizedBox(height: compact ? 5 : 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: memberDashboardMetaStyle.copyWith(
                fontSize: compact ? 12 : 13,
                height: 1.42,
                color: kTextSecondary,
              ),
            ),
            if (action != null) ...[
              SizedBox(height: compact ? 14 : 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _GalleryPrimaryButton extends StatelessWidget {
  const _GalleryPrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kMemberDashboardAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: Size.fromHeight(compact ? 44 : kMobileMinTouch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: dashText(const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          )),
        ),
      ),
    );
  }
}

/// Shown when the Gallery API request fails.
class _GalleryLoadErrorState extends StatelessWidget {
  const _GalleryLoadErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return _GalleryStatusCard(
      compact: compact,
      icon: Icons.cloud_off_rounded,
      title: 'Unable to Load Gallery',
      subtitle:
          'Something went wrong while loading event media. Please try again.',
      action: _GalleryPrimaryButton(
        label: 'Retry',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    );
  }
}

class _GalleryNoEventMediaEmptyState extends StatelessWidget {
  const _GalleryNoEventMediaEmptyState({
    this.requestorMode = false,
    this.onViewCalendar,
    this.onViewPortfolio,
    this.onViewRequests,
  });

  final bool requestorMode;
  final VoidCallback? onViewCalendar;
  final VoidCallback? onViewPortfolio;
  final VoidCallback? onViewRequests;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;

    return _GalleryStatusCard(
      compact: compact,
      icon: Icons.photo_camera_rounded,
      badgeIcon: Icons.photo_library_rounded,
      title: requestorMode ? 'No event albums yet' : 'No Event Media Yet',
      subtitle: requestorMode
          ? 'After ACCESS completes coverage for your approved events, published photos and videos appear here as albums.'
          : 'Once ACCESS documents your approved events, photos and videos will show up here.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (requestorMode && onViewRequests != null) ...[
            _GalleryPrimaryButton(
              label: 'View my requests',
              icon: Icons.description_rounded,
              onPressed: onViewRequests!,
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: Gallery fills in after members upload and admins publish event media.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kTextSecondary,
                fontSize: compact ? 11 : 12,
                height: 1.35,
              ),
            ),
          ]
          else ...[
            if (onViewCalendar != null)
              _GalleryPrimaryButton(
                label: 'View Upcoming Events',
                icon: Icons.event_rounded,
                onPressed: onViewCalendar!,
              ),
            if (onViewPortfolio != null) ...[
              if (onViewCalendar != null) const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onViewPortfolio,
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('Practice evaluations'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kAccent.withValues(alpha: 0.35)),
                  minimumSize: Size.fromHeight(compact ? 44 : kMobileMinTouch),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kMemberDashboardButtonRadius),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
