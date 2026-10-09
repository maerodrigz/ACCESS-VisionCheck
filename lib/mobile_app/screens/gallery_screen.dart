import 'dart:async';

import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/shared/models/event_gallery.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/mobile_app/screens/event_album_screen.dart';
import 'package:access_mobile/mobile_app/widgets/mobile_ui_kit.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';
import 'package:access_mobile/mobile_app/widgets/requestor/requestor_tab_hero.dart';

enum _GalleryFilter { all, photos, videos }

/// Shared layout rhythm for the member gallery screen.
const _kGallerySectionTop = 6.0;
const _kGalleryListGap = 10.0;
const _kGalleryListBottom = 20.0;
const _kGalleryEmptyTop = 20.0;
const _kGalleryControlHeight = 36.0;

/// Fixed album card size shared by the Recent Events row and the album grid.
const _kGalleryAlbumCardWidth = 168.0;
const _kGalleryAlbumCardHeight = 190.0;

BoxDecoration _gallerySurfaceCardDecoration({List<BoxShadow>? shadows}) =>
    memberDashboardCardDecoration(shadows: shadows ?? memberDashboardCardShadows());

int _galleryCollectionCrossAxisCount(double width) {
  if (width >= 900) return 3;
  if (width >= 600) return 2;
  return 1;
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
    this.subtitle = 'Explore photos and videos from ACCESS events and activities.',
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
  bool _searchExpanded = false;
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
    if (widget.requestorMode || _hasActiveSearch) return const [];
    return pickGalleryRecentAlbums(_albums);
  }

  List<EventGalleryAlbum> get _catalogAlbums {
    if (_hasActiveSearch) return _albums;
    return galleryAlbumsExcluding(_albums, _recentAlbums);
  }

  bool get _hasActiveSearch => _searchQuery.trim().isNotEmpty;

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (_searchExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocusNode.requestFocus();
        });
      } else {
        _searchFocusNode.unfocus();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _dismissSearch() {
    if (_searchQuery.trim().isNotEmpty) {
      _clearSearch();
      return;
    }
    setState(() {
      _searchExpanded = false;
      _searchFocusNode.unfocus();
    });
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
          if (widget.requestorMode)
            ListenableBuilder(
              listenable: Listenable.merge([appState, memberDataController]),
              builder: (_, __) {
                final albums = _albums;
                final photos = albums.fold<int>(0, (sum, a) => sum + a.photoCount);
                final videos = albums.fold<int>(0, (sum, a) => sum + a.videoCount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RequestorTabHero(
                      title: 'Gallery',
                      subtitle: widget.subtitle,
                      onNotifications: widget.onNotificationsTap,
                      onProfileTap: widget.onProfileTap,
                      mini: true,
                    ),
                    if (albums.isNotEmpty)
                      _RequestorGalleryStatsBar(
                        albumCount: albums.length,
                        photoCount: photos,
                        videoCount: videos,
                      ),
                  ],
                );
              },
            )
          else
            ListenableBuilder(
              listenable: Listenable.merge([appState, memberDataController]),
              builder: (_, __) {
                if (memberDataController.eventGalleryLoading &&
                    appState.eventGallery.isEmpty) {
                  return const SizedBox.shrink();
                }
                final albums = _albums;
                final photos = albums.fold<int>(0, (sum, a) => sum + a.photoCount);
                final videos = albums.fold<int>(0, (sum, a) => sum + a.videoCount);
                return _GalleryMiniHero(
                  albumCount: albums.length,
                  photoCount: photos,
                  videoCount: videos,
                  filter: _filter,
                  searching: _hasActiveSearch,
                  myWorkOnly: _myWorkOnly,
                  requestorMode: false,
                  onNotificationsTap: widget.onNotificationsTap,
                  onProfileTap: widget.onProfileTap,
                );
              },
            ),
          _GalleryToolbar(
            onSearch: _toggleSearch,
            hasActiveSearch: _hasActiveSearch || _searchExpanded,
            myWorkOnly: _myWorkOnly,
            onMyWorkChanged: (value) => setState(() => _myWorkOnly = value),
            showMyWorkFilter: !widget.requestorMode,
            requestorMode: widget.requestorMode,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _searchExpanded
                ? _GallerySearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    onDismiss: _dismissSearch,
                    hasQuery: _hasActiveSearch,
                    hintText: widget.requestorMode
                        ? 'Search your documented events…'
                        : 'Search events, dates, or categories…',
                  )
                : const SizedBox(width: double.infinity, height: 0),
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

                final recentAlbums = _recentAlbums;
                final catalogAlbums = _catalogAlbums;
                final showRecentRow = recentAlbums.isNotEmpty;
                final showCatalogGrid = catalogAlbums.isNotEmpty;
                final catalogTitle = widget.requestorMode
                    ? (_hasActiveSearch ? 'Matching events' : 'Your documented events')
                    : (_hasActiveSearch
                        ? 'Matching Events'
                        : showRecentRow
                            ? 'All Event Albums'
                            : 'Event Albums');

                return RefreshIndicator(
                  color: kMemberDashboardAccent,
                  onRefresh: () => memberDataController.refreshEventGallery(fullCatalog: true),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      if (showRecentRow) ...[
                        SliverToBoxAdapter(
                          child: _GalleryListSectionHeader(
                            padding: padding,
                            title: 'Recent Events',
                            count: recentAlbums.length,
                            searching: false,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _GalleryRecentAlbumsRow(
                            padding: padding,
                            albums: recentAlbums,
                            onOpenAlbum: _openAlbum,
                          ),
                        ),
                      ],
                      if (showCatalogGrid) ...[
                        SliverToBoxAdapter(
                          child: _GalleryListSectionHeader(
                            padding: padding,
                            title: catalogTitle,
                            count: catalogAlbums.length,
                            searching: _hasActiveSearch,
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            0,
                            padding,
                            _kGalleryListBottom,
                          ),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: _kGalleryAlbumCardWidth + 40,
                              mainAxisSpacing: _kGalleryListGap,
                              crossAxisSpacing: _kGalleryListGap,
                              mainAxisExtent: _kGalleryAlbumCardHeight,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final album = catalogAlbums[index];
                                return _GalleryAlbumCard(
                                  album: album,
                                  isPersonal:
                                      !widget.requestorMode && galleryAlbumIsPersonal(album),
                                  personalLabel: widget.requestorMode
                                      ? 'Your event'
                                      : galleryAlbumPersonalLabel(album),
                                  showPersonalBadge: !widget.requestorMode,
                                  requestorMode: widget.requestorMode,
                                  onTap: () => _openAlbum(album),
                                  titleMaxLines: 1,
                                );
                              },
                              childCount: catalogAlbums.length,
                            ),
                          ),
                        ),
                      ] else if (showRecentRow)
                        const SliverToBoxAdapter(
                          child: SizedBox(height: _kGalleryListBottom),
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

class _GalleryToolbar extends StatelessWidget {
  const _GalleryToolbar({
    required this.onSearch,
    required this.hasActiveSearch,
    required this.myWorkOnly,
    required this.onMyWorkChanged,
    this.showMyWorkFilter = true,
    this.requestorMode = false,
  });

  final VoidCallback onSearch;
  final bool hasActiveSearch;
  final bool myWorkOnly;
  final ValueChanged<bool> onMyWorkChanged;
  final bool showMyWorkFilter;
  final bool requestorMode;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 10, padding, 8),
      child: Row(
        children: [
          if (showMyWorkFilter)
            Semantics(
              button: true,
              toggled: myWorkOnly,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onMyWorkChanged(!myWorkOnly),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: _kGalleryControlHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: myWorkOnly ? kAccent.withValues(alpha: 0.1) : kSurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: myWorkOnly ? kAccent.withValues(alpha: 0.35) : kBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          myWorkOnly
                              ? Icons.person_rounded
                              : Icons.person_outline_rounded,
                          size: 16,
                          color: myWorkOnly ? kAccent : kIconInactive,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'My Work',
                          style: dashText(TextStyle(
                            color: myWorkOnly ? kAccent : kTextSecondary,
                            fontWeight: myWorkOnly ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 12.5,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              requestorMode ? 'Browse your events' : 'Event albums',
              style: TextStyle(
                color: kTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: _kGalleryControlHeight,
                height: _kGalleryControlHeight,
                decoration: BoxDecoration(
                  color: hasActiveSearch ? kAccent.withValues(alpha: 0.1) : kSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hasActiveSearch ? kAccent.withValues(alpha: 0.35) : kBorder,
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: hasActiveSearch ? kAccent : kIconInactive,
                ),
              ),
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
    required this.onDismiss,
    required this.hasQuery,
    this.hintText = 'Search events, dates, or categories…',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onDismiss;
  final bool hasQuery;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 2, padding, compact ? 6 : 8),
      child: Material(
        color: kSurface,
        elevation: 0,
        borderRadius: BorderRadius.circular(12),
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
              color: kMemberDashboardAccent.withValues(alpha: 0.85),
              size: compact ? 20 : 22,
            ),
            suffixIcon: IconButton(
              onPressed: onDismiss,
              tooltip: hasQuery ? 'Clear search' : 'Close search',
              icon: Icon(
                hasQuery ? Icons.close_rounded : Icons.keyboard_arrow_up_rounded,
                color: kIconInactive,
                size: compact ? 20 : 22,
              ),
            ),
            filled: true,
            fillColor: kSurface,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4,
              vertical: compact ? 10 : 12,
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
              borderSide: const BorderSide(color: kMemberDashboardAccent, width: 1.5),
            ),
          ),
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
    final crossAxisCount =
        _galleryCollectionCrossAxisCount(MediaQuery.sizeOf(context).width);

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
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: crossAxisCount == 1 ? 560 : 380,
                  mainAxisSpacing: _kGalleryListGap,
                  crossAxisSpacing: _kGalleryListGap,
                  mainAxisExtent: crossAxisCount == 1 ? 208 : 196,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, __) => _GalleryEventCardSkeleton(pulse: t),
                  childCount: count,
                ),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _GallerySkeletonBone(
              height: double.infinity,
              radius: 0,
              pulse: pulse,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 11,
              8,
              compact ? 10 : 11,
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GallerySkeletonBone(
                  height: compact ? 13 : 14,
                  radius: 6,
                  pulse: pulse,
                ),
                const SizedBox(height: 6),
                _GallerySkeletonBone(
                  height: compact ? 10 : 11,
                  width: MediaQuery.sizeOf(context).width * 0.42,
                  radius: 5,
                  pulse: pulse,
                ),
              ],
            ),
          ),
        ],
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

class _GalleryRecentAlbumsRow extends StatelessWidget {
  const _GalleryRecentAlbumsRow({
    required this.padding,
    required this.albums,
    required this.onOpenAlbum,
  });

  static const _bottomInset = 8.0;

  final double padding;
  final List<EventGalleryAlbum> albums;
  final ValueChanged<EventGalleryAlbum> onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kGalleryAlbumCardHeight + _bottomInset,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(padding, 0, padding, _bottomInset),
        physics: const BouncingScrollPhysics(),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: _kGalleryListGap),
        itemBuilder: (context, index) {
          final album = albums[index];
          return SizedBox(
            width: _kGalleryAlbumCardWidth,
            height: _kGalleryAlbumCardHeight,
            child: _GalleryAlbumCard(
              album: album,
              isPersonal: galleryAlbumIsPersonal(album),
              personalLabel: galleryAlbumPersonalLabel(album),
              onTap: () => onOpenAlbum(album),
              titleMaxLines: 1,
            ),
          );
        },
      ),
    );
  }
}

class _GalleryAlbumCardFooter extends StatelessWidget {
  const _GalleryAlbumCardFooter({
    required this.album,
    this.compact = false,
    this.titleMaxLines = 2,
    this.requestorMode = false,
  });

  final EventGalleryAlbum album;
  final bool compact;
  final int titleMaxLines;
  final bool requestorMode;

  static const _facebookBlue = Color(0xFF1877F2);

  String get _metaLine {
    final parts = <String>[album.dateLabel];
    final category = album.eventCategory?.trim();
    if (category != null && category.isNotEmpty) parts.add(category);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          album.name,
          maxLines: titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: memberDashboardSectionTitleStyle.copyWith(
            fontSize: compact ? 13 : 14,
            height: 1.15,
            letterSpacing: -0.15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _metaLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: memberDashboardMetaStyle.copyWith(
            fontSize: compact ? 10 : 11,
            color: kTextSecondary,
            height: 1.2,
          ),
        ),
        if (requestorMode && album.hasFacebookPublish) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.facebook_rounded, size: 12, color: _facebookBlue),
              const SizedBox(width: 4),
              Text(
                'On Facebook',
                style: memberDashboardMetaStyle.copyWith(
                  fontSize: compact ? 10 : 11,
                  color: _facebookBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GalleryAlbumCard extends StatelessWidget {
  const _GalleryAlbumCard({
    required this.album,
    required this.isPersonal,
    required this.personalLabel,
    required this.onTap,
    this.titleMaxLines = 2,
    this.showPersonalBadge = true,
    this.requestorMode = false,
  });

  final EventGalleryAlbum album;
  final bool isPersonal;
  final String personalLabel;
  final VoidCallback onTap;
  final int titleMaxLines;
  final bool showPersonalBadge;
  final bool requestorMode;

  @override
  Widget build(BuildContext context) {
    const compact = true;
    final accent = requestorMode ? kAccent : (isPersonal ? kMemberPrimary : kMemberCyan);

    return Material(
      color: kSurface,
      elevation: 0,
      borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(
              color: isPersonal ? accent.withValues(alpha: 0.3) : kBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _AlbumCoverImage(url: album.coverUrl),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 32,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.38),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (showPersonalBadge && isPersonal)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: kMemberPrimary.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            personalLabel,
                            style: dashText(const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.25,
                            )),
                          ),
                        ),
                      )
                    else if (requestorMode)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: kAccent.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Your event',
                            style: dashText(const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.25,
                            )),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 7,
                      child: _GalleryCoverMetaBadge(album: album, compact: compact),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: _GalleryAlbumCardFooter(
                  album: album,
                  compact: compact,
                  titleMaxLines: titleMaxLines,
                  requestorMode: requestorMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestorGalleryStatsBar extends StatelessWidget {
  const _RequestorGalleryStatsBar({
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
      padding: EdgeInsets.fromLTRB(padding, 10, padding, 4),
      child: Row(
        children: [
          Expanded(
            child: _RequestorGalleryStatTile(
              icon: Icons.photo_album_outlined,
              value: '$albumCount',
              label: albumCount == 1 ? 'Album' : 'Albums',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RequestorGalleryStatTile(
              icon: Icons.photo_library_outlined,
              value: '$photoCount',
              label: photoCount == 1 ? 'Photo' : 'Photos',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _RequestorGalleryStatTile(
              icon: Icons.videocam_outlined,
              value: '$videoCount',
              label: videoCount == 1 ? 'Video' : 'Videos',
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestorGalleryStatTile extends StatelessWidget {
  const _RequestorGalleryStatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 100;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: stacked ? 8 : 10,
            vertical: stacked ? 10 : 10,
          ),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(kMemberDashboardInnerRadius),
            border: Border.all(color: kBorder),
          ),
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, size: 16, color: kAccent),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: memberDashboardCardTitleStyle.copyWith(fontSize: 14),
                    ),
                    Text(
                      label,
                      style: memberDashboardMetaStyle.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, size: 17, color: kAccent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: memberDashboardCardTitleStyle.copyWith(fontSize: 15),
                          ),
                          Text(
                            label,
                            style: memberDashboardMetaStyle.copyWith(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

class _GalleryMiniHero extends StatelessWidget {
  const _GalleryMiniHero({
    required this.albumCount,
    required this.photoCount,
    required this.videoCount,
    required this.filter,
    required this.searching,
    this.myWorkOnly = false,
    this.requestorMode = false,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  final int albumCount;
  final int photoCount;
  final int videoCount;
  final _GalleryFilter filter;
  final bool searching;
  final bool myWorkOnly;
  final bool requestorMode;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  String get _filterLabel => switch (filter) {
        _GalleryFilter.photos => 'photos',
        _GalleryFilter.videos => 'videos',
        _ => 'all media',
      };

  String _buildSummary() {
    if (albumCount == 0) {
      if (searching) return 'No albums match your search';
      if (myWorkOnly) return 'No albums with your work';
      return 'No event albums yet';
    }
    final parts = <String>[];
    parts.add('$albumCount Album${albumCount == 1 ? '' : 's'}');
    if (photoCount > 0) parts.add('$photoCount Photo${photoCount == 1 ? '' : 's'}');
    if (videoCount > 0) parts.add('$videoCount Video${videoCount == 1 ? '' : 's'}');
    final base = parts.join(' • ');
    return filter != _GalleryFilter.all ? '$base ($_filterLabel)' : base;
  }

  @override
  Widget build(BuildContext context) {
    final padding = mobilePagePaddingOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;
    final summary = _buildSummary();
    final hasSummary = albumCount > 0;

    return ColoredBox(
      color: kSurface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, compact ? 10 : 12, padding - 4, compact ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title + summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gallery',
                      style: TextStyle(
                        color: kTextPrimary,
                        fontSize: compact ? 22 : 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (hasSummary) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kAccent.withValues(alpha: 0.18)),
                            ),
                            child: Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: kAccent,
                                fontSize: compact ? 10.5 : 11,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: kTextSecondary,
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Notifications (light variant)
              MemberPageNotificationButton(onTap: onNotificationsTap),
              // Profile avatar (light variant)
              if (!requestorMode)
                MemberPageProfileAvatar(onTap: onProfileTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryCoverMetaBadge extends StatelessWidget {
  const _GalleryCoverMetaBadge({
    required this.album,
    required this.compact,
  });

  final EventGalleryAlbum album;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (album.totalCount == 0) return const SizedBox.shrink();

    final parts = <Widget>[];
    if (album.photoCount > 0) {
      parts.add(_badgePart(
        icon: Icons.photo_library_rounded,
        label: '${album.photoCount}',
        compact: compact,
      ));
    }
    if (album.photoCount > 0 && album.videoCount > 0) {
      parts.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(
          '·',
          style: dashText(TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          )),
        ),
      ));
    }
    if (album.videoCount > 0) {
      parts.add(_badgePart(
        icon: Icons.play_circle_rounded,
        label: '${album.videoCount}',
        compact: compact,
      ));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 8,
            vertical: compact ? 4 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: parts,
          ),
        ),
      ),
    );
  }

  Widget _badgePart({
    required IconData icon,
    required String label,
    required bool compact,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: compact ? 12 : 13),
        const SizedBox(width: 3),
        Text(
          label,
          style: dashText(TextStyle(
            color: Colors.white,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
          )),
        ),
      ],
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
    final iconSize = compact ? 50.0 : 56.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: compact ? 16 : 18,
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
          ? 'Approved documentation requests from your organization appear here once ACCESS publishes photos and videos.'
          : 'Once ACCESS documents your approved events, photos and videos will show up here.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (requestorMode && onViewRequests != null)
            _GalleryPrimaryButton(
              label: 'View my requests',
              icon: Icons.description_rounded,
              onPressed: onViewRequests!,
            )
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
