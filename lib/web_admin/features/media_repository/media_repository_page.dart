import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/admin_api_service.dart';
import 'package:access_mobile/shared/models/user_model.dart';
import 'package:access_mobile/shared/services/facebook_share_flow.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_models.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_repository.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/best_shots_row.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/event_albums_section.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/media_bulk_toolbar.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/media_gallery_grid.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/media_preview_drawer.dart';
import 'package:access_mobile/web_admin/features/media_repository/widgets/media_stats_row.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/admin_session_scope.dart';
import 'package:access_mobile/web_admin/layout/confirm_dialog.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/services/file_picker_service.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';
import 'package:url_launcher/url_launcher.dart';

/// Media Library — store, organize, preview, and publish campus event documentation.
class MediaRepositoryPage extends StatefulWidget {
  const MediaRepositoryPage({super.key});

  @override
  State<MediaRepositoryPage> createState() => _MediaRepositoryPageState();
}

class _MediaRepositoryPageState extends State<MediaRepositoryPage> {
  final _repo = MediaRepositoryRepository();
  final _searchController = TextEditingController();

  List<MediaAsset> _all = [];
  List<MediaAlbum> _albums = [];
  MediaLibraryStats _stats = const MediaLibraryStats(
    totalPhotos: 0,
    totalVideos: 0,
    totalAlbums: 0,
    storageUsedLabel: '0 MB',
  );
  List<Map<String, dynamic>> _requests = [];

  bool _loading = true;
  String? _error;
  String _search = '';
  String? _selectedAlbumId;
  String? _selectedAlbumName;

  MediaAsset? _previewItem;
  bool _drawerOpen = false;
  final Set<int> _selectedIds = {};
  bool _uploading = false;
  bool _sharing = false;

  bool get _isAdmin {
    final role = AdminSessionScope.maybeOf(context)?.role;
    return role == AccessRole.admin;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.loadAll();
      final reqs = await adminApi.allServiceRequests();
      final approved = reqs.where((r) => (r['status'] as String?)?.toLowerCase() == 'approved').toList();
      final albums = _repo.buildAlbums(items);
      if (mounted) {
        setState(() {
          _all = items;
          _albums = albums;
          _stats = _repo.computeStats(items, albums);
          _requests = approved.isNotEmpty ? approved : reqs;
          _loading = false;
          if (_previewItem != null) {
            final id = _previewItem!.id;
            _previewItem = items.where((a) => a.id == id).firstOrNull ?? _previewItem;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _all = [];
          _loading = false;
        });
      }
    }
  }

  List<MediaAsset> get _filtered => _repo.filter(items: _all, search: _search, albumId: _selectedAlbumId);

  List<MediaAsset> get _recentItems {
    final base = _filtered;
    if (_selectedAlbumId != null) return base;
    return _search.isEmpty ? _repo.recentUploads(base) : base;
  }

  void _openPreview(MediaAsset item) {
    setState(() {
      _previewItem = item;
      _drawerOpen = true;
    });
  }

  void _closeDrawer() => setState(() => _drawerOpen = false);

  void _toggleSelect(MediaAsset item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AdminTheme.success : AdminTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _upload() async {
    if (!_isAdmin) {
      _toast('Only administrators can upload media.', success: false);
      return;
    }
    if (_requests.isEmpty) {
      _toast('Approve a documentation request before uploading media.', success: false);
      return;
    }

    final picked = await pickImagesFromWeb();
    if (picked.isEmpty) return;
    final requestId = _requests.first['request_id'] as int? ?? _requests.first['id'] as int;

    setState(() => _uploading = true);
    try {
      for (final f in picked) {
        await adminApi.uploadMedia(bytes: f.bytes, fileName: f.name, requestId: requestId, displayName: f.name);
      }
      await _load();
      _toast('Uploaded ${picked.length} file(s)');
    } catch (e) {
      _toast(e.toString(), success: false);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadItem(MediaAsset item) async {
    final url = item.thumbnailUrl;
    if (url.isEmpty) {
      _toast('No download URL available', success: false);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _publishFacebook(MediaAsset item) async {
    if (!_isAdmin) {
      _toast('Only administrators can publish to Facebook.', success: false);
      return;
    }
    final imageUrl = item.thumbnailUrl;
    if (imageUrl.isEmpty) {
      _toast('No media URL to share', success: false);
      return;
    }

    setState(() => _sharing = true);
    try {
      final opened = await runFacebookBrowserShare(
        imageUrl: imageUrl,
        message: item.fileName,
        onLogged: () => adminApi.logFacebookShareOpened(mediaId: item.id, message: item.fileName, shareUrl: imageUrl),
      );
      await _repo.markPublished(item.id);
      item.isPublished = true;
      if (mounted) {
        showFacebookShareSnackBar(context, opened: opened);
        setState(() {});
      }
    } catch (e) {
      _toast(e.toString(), success: false);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _pickAndPublishFacebook() async {
    if (!_isAdmin) {
      _toast('Only administrators can publish to Facebook.', success: false);
      return;
    }
    if (_all.isEmpty) {
      _toast('No media to publish. Upload photos first.', success: false);
      return;
    }

    final picked = await showDialog<MediaAsset>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Publish to Facebook'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('Select media to open Facebook and publish.', style: TextStyle(fontSize: 13, color: AdminTheme.textSecondary)),
          ),
          for (final item in _all.take(20))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, item),
              child: Text('${item.eventName} — ${item.fileName}'),
            ),
        ],
      ),
    );
    if (picked != null && !_sharing) await _publishFacebook(picked);
  }

  Future<void> _deleteItem(MediaAsset item) async {
    if (!_isAdmin) return;
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete media?',
      message: 'This permanently removes "${item.fileName}" from the library.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (ok != true) return;
    try {
      await adminApi.deleteMedia(item.id);
      _selectedIds.remove(item.id);
      if (_previewItem?.id == item.id) _closeDrawer();
      await _load();
      _toast('Media deleted');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _archiveItem(MediaAsset item) async {
    if (!_isAdmin) return;
    final ok = await ConfirmDialog.show(
      context,
      title: 'Archive media?',
      message: '"${item.fileName}" will be removed from the active library.',
      confirmLabel: 'Archive',
      icon: Icons.archive_outlined,
    );
    if (ok != true) return;
    await _repo.archiveMedia(item.id);
    _selectedIds.remove(item.id);
    if (_previewItem?.id == item.id) _closeDrawer();
    await _load();
    _toast('Media archived');
  }

  Future<void> _toggleBestShot(MediaAsset item) async {
    if (!_isAdmin) return;
    await _repo.toggleBestShot(item.id);
    item.isBestShot = !item.isBestShot;
    if (mounted) {
      setState(() {});
      _toast(item.isBestShot ? 'Marked as Best Shot' : 'Removed from Best Shots');
    }
  }

  Future<void> _showMoveAlbumDialog(List<MediaAsset> items) async {
    if (_albums.isEmpty) {
      _toast('No albums available yet', success: false);
      return;
    }
    final picked = await showDialog<MediaAlbum>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Move to album'),
        children: _albums
            .map((a) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, a), child: Text('${a.name} (${a.totalCount})')))
            .toList(),
      ),
    );
    if (picked == null) return;
    for (final item in items) {
      await _repo.moveToAlbum(item.id, picked.name);
    }
    await _load();
    _toast('${items.length} item(s) moved to "${picked.name}"');
  }

  void _handleTileAction(String action, MediaAsset item) {
    switch (action) {
      case 'download':
        _downloadItem(item);
      case 'move':
        _showMoveAlbumDialog([item]);
      case 'archive':
        _archiveItem(item);
      case 'delete':
        _deleteItem(item);
      case 'publish':
        _publishFacebook(item);
    }
  }

  Future<void> _bulkDelete() async {
    if (!_isAdmin || _selectedIds.isEmpty) return;
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete selected media?',
      message: 'This removes ${_selectedIds.length} item(s) permanently.',
      confirmLabel: 'Delete all',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (ok != true) return;
    try {
      for (final id in _selectedIds.toList()) {
        await adminApi.deleteMedia(id);
      }
      _clearSelection();
      await _load();
      _toast('Deleted selected media');
    } catch (e) {
      _toast(e.toString(), success: false);
    }
  }

  Future<void> _bulkArchive() async {
    if (!_isAdmin || _selectedIds.isEmpty) return;
    await _repo.archiveMany(_selectedIds);
    _clearSelection();
    await _load();
    _toast('Selected media archived');
  }

  @override
  Widget build(BuildContext context) {
    final padding = AdminBreakpoints.pagePadding(context);
    final bestShots = _repo.bestShots(_all);
    final showOverviewSections = _selectedAlbumId == null && _search.isEmpty;

    return Container(
      color: AdminTheme.contentBg,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: padding.copyWith(bottom: 0),
                child: _PageHeader(
                  searchController: _searchController,
                  search: _search,
                  onSearchChanged: (v) => setState(() => _search = v),
                  onUpload: _isAdmin && !_uploading ? _upload : null,
                  onPublishFacebook: _isAdmin && !_sharing ? _pickAndPublishFacebook : null,
                  onRefresh: _load,
                  uploading: _uploading,
                  sharing: _sharing,
                  isAdmin: _isAdmin,
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AdminTheme.accentBlue))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: _load, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : _all.isEmpty
                            ? AdminEmptyState(
                                title: 'No media uploaded yet.',
                                message: 'Upload photos and videos from approved campus documentation events.',
                                icon: Icons.photo_library_outlined,
                                actionLabel: _isAdmin ? 'Upload Media' : null,
                                onAction: _isAdmin && !_uploading ? _upload : null,
                              )
                            : SingleChildScrollView(
                                padding: padding.copyWith(top: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (showOverviewSections) ...[
                                      MediaStatsRow(stats: _stats),
                                      const SizedBox(height: 24),
                                      EventAlbumsSection(
                                        albums: _albums,
                                        selectedAlbumId: _selectedAlbumId,
                                        onAlbumTap: (a) => setState(() {
                                          _selectedAlbumId = a.id;
                                          _selectedAlbumName = a.name;
                                        }),
                                        onClearAlbum: () => setState(() {
                                          _selectedAlbumId = null;
                                          _selectedAlbumName = null;
                                        }),
                                      ),
                                      const SizedBox(height: 28),
                                      BestShotsRow(
                                        items: bestShots,
                                        isAdmin: _isAdmin,
                                        onPreview: _openPreview,
                                        onToggleBestShot: _toggleBestShot,
                                      ),
                                      const SizedBox(height: 28),
                                    ],
                                    RecentUploadsSection(
                                      items: _recentItems,
                                      albumName: _selectedAlbumName,
                                      selectedIds: _selectedIds,
                                      isAdmin: _isAdmin,
                                      onItemTap: _openPreview,
                                      onSelectToggle: _toggleSelect,
                                      onAction: _handleTileAction,
                                    ),
                                    const SizedBox(height: 80),
                                  ],
                                ),
                              ),
              ),
            ],
          ),
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(onTap: _closeDrawer, child: Container(color: Colors.black.withValues(alpha: 0.25))),
            ),
          MediaPreviewDrawer(
            item: _previewItem,
            open: _drawerOpen,
            isAdmin: _isAdmin,
            onClose: _closeDrawer,
            onDownload: () {
              if (_previewItem != null) _downloadItem(_previewItem!);
            },
            onPublishFacebook: () {
              if (_previewItem != null && !_sharing) _publishFacebook(_previewItem!);
            },
            onMoveToAlbum: () {
              if (_previewItem != null) _showMoveAlbumDialog([_previewItem!]);
            },
            onArchive: () {
              if (_previewItem != null) _archiveItem(_previewItem!);
            },
            onDelete: () {
              if (_previewItem != null) _deleteItem(_previewItem!);
            },
            onToggleBestShot: () {
              if (_previewItem != null) _toggleBestShot(_previewItem!);
            },
          ),
          MediaBulkToolbar(
            count: _selectedIds.length,
            isAdmin: _isAdmin,
            onClear: _clearSelection,
            onDownload: () {
              for (final id in _selectedIds) {
                final item = _all.where((a) => a.id == id).firstOrNull;
                if (item != null) _downloadItem(item);
              }
            },
            onPublish: () async {
              for (final id in _selectedIds.toList()) {
                final item = _all.where((a) => a.id == id).firstOrNull;
                if (item != null) await _publishFacebook(item);
              }
              _clearSelection();
            },
            onMove: () {
              final items = _all.where((a) => _selectedIds.contains(a.id)).toList();
              _showMoveAlbumDialog(items);
            },
            onArchive: _bulkArchive,
            onDelete: _bulkDelete,
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.searchController,
    required this.search,
    required this.onSearchChanged,
    required this.onUpload,
    required this.onPublishFacebook,
    required this.onRefresh,
    required this.uploading,
    required this.sharing,
    required this.isAdmin,
  });

  final TextEditingController searchController;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onUpload;
  final VoidCallback? onPublishFacebook;
  final VoidCallback onRefresh;
  final bool uploading;
  final bool sharing;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final compact = AdminBreakpoints.widthOf(context) < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media Library',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary, letterSpacing: -0.5),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Store, organize, preview, and publish campus event documentation.',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (!compact && isAdmin) ...[
              _HeaderBtn(
                label: 'Upload Media',
                icon: Icons.cloud_upload_outlined,
                onPressed: onUpload,
                loading: uploading,
                primary: true,
              ),
              const SizedBox(width: 8),
              _HeaderBtn(
                label: 'Publish to Facebook',
                icon: Icons.facebook,
                onPressed: onPublishFacebook,
                loading: sharing,
                facebook: true,
              ),
              const SizedBox(width: 4),
              PageHeaderRefreshButton(onPressed: onRefresh),
            ] else if (!compact)
              PageHeaderRefreshButton(onPressed: onRefresh),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search event, album, photographer, file name, date…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            if (compact) PageHeaderRefreshButton(onPressed: onRefresh),
          ],
        ),
        if (compact && isAdmin) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderBtn(label: 'Upload Media', icon: Icons.cloud_upload_outlined, onPressed: onUpload, loading: uploading, primary: true, compact: true),
              _HeaderBtn(label: 'Publish to Facebook', icon: Icons.facebook, onPressed: onPublishFacebook, loading: sharing, facebook: true, compact: true),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.primary = false,
    this.facebook = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool primary;
  final bool facebook;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
        icon: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: compact ? 16 : 18),
        label: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: facebook ? AdminTheme.facebookBlue : AdminTheme.accentBlue),
      icon: loading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: compact ? 16 : 18),
      label: Text(label),
    );
  }
}
