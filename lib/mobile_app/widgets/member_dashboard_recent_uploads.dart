import 'package:flutter/material.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';
import 'package:access_mobile/mobile_app/widgets/gallery_media_thumbnail.dart';
import 'package:access_mobile/mobile_app/widgets/member_dashboard_theme.dart';

class MemberDashboardRecentUploads extends StatelessWidget {
  const MemberDashboardRecentUploads({
    super.key,
    this.onViewPortfolio,
    this.onViewEventGallery,
  });

  final VoidCallback? onViewPortfolio;
  final VoidCallback? onViewEventGallery;

  static const _thumbWidth = 160.0;
  static const _thumbHeight = 210.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, memberDataController]),
      builder: (context, _) {
        final recent = appState.gallery.take(4).toList();

        return MemberDashboardSection(
          title: 'Recent Uploads',
          subtitle: 'Your latest practice evaluation photos and videos',
          child: recent.isEmpty
              ? MemberDashboardEmptyState(
                  icon: Icons.photo_library_outlined,
                  message:
                      'Save a practice evaluation to build your portfolio. '
                      'Event coverage photos live under the Gallery tab.',
                  backgroundColor: kDashAccentUploads,
                  iconColor: kDashAccentUploadsIcon,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _thumbHeight,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: recent.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, index) => _UploadThumbnailCard(
                          item: recent[index],
                          width: _thumbWidth,
                          height: _thumbHeight,
                          index: index,
                          onTap: () => openPortfolioGalleryItem(context, recent[index]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    MemberDashboardPrimaryButton(
                      label: 'View all evaluations',
                      icon: Icons.analytics_rounded,
                      color: kDashAccentUploadsIcon,
                      onPressed: onViewPortfolio,
                    ),
                    if (onViewEventGallery != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: onViewEventGallery,
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Browse event gallery'),
                          style: TextButton.styleFrom(
                            foregroundColor: kDashTextSecondary,
                            textStyle: dashText(const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            )),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _UploadThumbnailCard extends StatelessWidget {
  const _UploadThumbnailCard({
    required this.item,
    required this.width,
    required this.height,
    required this.index,
    this.onTap,
  });

  final GalleryItem item;
  final double width;
  final double height;
  final int index;
  final VoidCallback? onTap;

  Color _statusColor(String status) {
    return switch (status) {
      'Evaluated' => kDashAccentUploadsIcon,
      'Needs review' => const Color(0xFFF97316),
      _ => kDashTextSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final eventName = eventNameForUpload(item);
    final status = item.evalStatus;
    final score = item.scoreLabel;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kDashAccentUploadsIcon.withValues(alpha: 0.15)),
              boxShadow: memberDashboardCardShadows(tint: kDashAccentUploadsIcon),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ThumbnailImage(item: item),
                      if (item.isVideo)
                        Center(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      if (score != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kDashCardBg.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              score,
                              style: dashText(const TextStyle(
                                color: kDashAccentUploadsIcon,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              )),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  color: kDashCardBg,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: memberDashboardCardTitleStyle.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(item.date, style: memberDashboardMetaStyle.copyWith(fontSize: 11)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: dashText(TextStyle(
                            color: _statusColor(status),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
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
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({required this.item});

  final GalleryItem item;

  @override
  Widget build(BuildContext context) {
    return GalleryMediaThumbnail(
      url: item.networkUrl,
      isVideo: item.isVideo,
      memoryBytes: item.imageBytes,
      fallbackIconColor: kDashAccentUploadsIcon,
      fallbackIconSize: 32,
    );
  }
}
