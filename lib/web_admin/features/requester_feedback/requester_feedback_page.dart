import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/requester_feedback_models.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/requester_feedback_repository.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/widgets/featured_testimonial_card.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/widgets/feedback_details_drawer.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/widgets/feedback_overview_cards.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/widgets/feedback_review_card.dart';
import 'package:access_mobile/web_admin/layout/admin_breakpoints.dart';
import 'package:access_mobile/web_admin/layout/page_header.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';
import 'package:access_mobile/web_admin/widgets/admin_empty_state.dart';

/// Requester Feedback Dashboard — submitted reviews only (waiting feedback lives in Request Status).
class RequesterFeedbackPage extends StatefulWidget {
  const RequesterFeedbackPage({super.key});

  @override
  State<RequesterFeedbackPage> createState() => _RequesterFeedbackPageState();
}

class _RequesterFeedbackPageState extends State<RequesterFeedbackPage> {
  final _repo = RequesterFeedbackRepository();
  final _searchController = TextEditingController();

  RequesterFeedbackDashboardData? _data;
  bool _loading = true;
  String? _error;
  String _search = '';
  FeedbackFilterChip _chip = FeedbackFilterChip.all;

  RequesterFeedbackItem? _selected;
  bool _drawerOpen = false;
  bool _focusResponse = false;

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
      final data = await _repo.loadAll();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          if (_selected != null) {
            final id = _selected!.id;
            _selected = data.feedback.where((f) => f.id == id).firstOrNull ?? _selected;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<RequesterFeedbackItem> get _visible {
    final data = _data;
    if (data == null) return [];
    return _repo.filter(items: data.feedback, chip: _chip, search: _search);
  }

  void _toast(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? AdminTheme.success : AdminTheme.danger, behavior: SnackBarBehavior.floating),
    );
  }

  void _openDetails(RequesterFeedbackItem item, {bool respond = false}) {
    setState(() {
      _selected = item;
      _drawerOpen = true;
      _focusResponse = respond;
    });
  }

  void _closeDrawer() => setState(() {
        _drawerOpen = false;
        _focusResponse = false;
      });

  Future<void> _exportReport() async {
    final data = _data;
    if (data == null) return;
    await Clipboard.setData(ClipboardData(text: _repo.buildExportReport(data)));
    _toast('Feedback report copied to clipboard');
  }

  Future<void> _markReviewed(RequesterFeedbackItem item) async {
    await _repo.setReviewStatus(item.id, FeedbackReviewStatus.reviewed);
    _closeDrawer();
    await _load();
    _toast('Feedback marked as reviewed');
  }

  Future<void> _archive(RequesterFeedbackItem item) async {
    await _repo.setReviewStatus(item.id, FeedbackReviewStatus.archived);
    _closeDrawer();
    await _load();
    _toast('Feedback archived');
  }

  Future<void> _sendResponse() async {
    final item = _selected;
    if (item == null) return;
    final text = item.adminResponse?.trim() ?? '';
    if (text.isEmpty) {
      _toast('Write a response before sending', success: false);
      return;
    }
    await _repo.setAdminResponse(item.id, text);
    await _repo.setReviewStatus(item.id, FeedbackReviewStatus.reviewed);
    _closeDrawer();
    await _load();
    _toast('Response saved');
  }

  @override
  Widget build(BuildContext context) {
    final padding = AdminBreakpoints.pagePadding(context);
    final items = _visible;

    return Container(
      color: AdminTheme.contentBg,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: padding.copyWith(bottom: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageHeader(
                      title: 'Requester Feedback',
                      subtitle:
                          'Review submitted requester evaluations, respond to feedback, and improve documentation services.',
                      actions: [
                        OutlinedButton.icon(
                          onPressed: _data == null ? null : _exportReport,
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: const Text('Export Report', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        PageHeaderRefreshButton(onPressed: _load),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search event, organization, requester, rating, date…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final chip in FeedbackFilterChip.values) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(chip.label),
                                selected: _chip == chip,
                                onSelected: (_) => setState(() => _chip = chip),
                                selectedColor: AdminTheme.accentBlue.withValues(alpha: 0.12),
                                checkmarkColor: AdminTheme.accentBlue,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _chip == chip ? AdminTheme.accentBlue : AdminTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
                        : SingleChildScrollView(
                            padding: padding.copyWith(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_data != null) FeedbackOverviewCards(stats: _data!.stats),
                                if (_data?.featured != null) ...[
                                  const SizedBox(height: 20),
                                  FeaturedTestimonialCard(testimonial: _data!.featured!),
                                ],
                                const SizedBox(height: 24),
                                const Text('Submitted Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                const Text(
                                  'Only completed-request feedback appears here. Track outstanding feedback requests in Request Status.',
                                  style: TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                if (items.isEmpty)
                                  const AdminEmptyState(
                                    title: 'No reviews match filters',
                                    message: 'When requesters submit feedback after documentation is delivered, reviews appear here.',
                                    icon: Icons.rate_review_outlined,
                                  )
                                else
                                  LayoutBuilder(
                                    builder: (context, c) {
                                      final cols = c.maxWidth >= 1100 ? 2 : 1;
                                      if (cols == 1) {
                                        return Column(
                                          children: [
                                            for (final f in items) ...[
                                              SizedBox(
                                                height: f.needsAttention ? 360 : 320,
                                                child: FeedbackReviewCard(
                                                  item: f,
                                                  onViewDetails: (i) => _openDetails(i),
                                                  onRespond: (i) => _openDetails(i, respond: true),
                                                  onArchive: _archive,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                            ],
                                          ],
                                        );
                                      }
                                      return GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 14,
                                          childAspectRatio: 0.78,
                                        ),
                                        itemCount: items.length,
                                        itemBuilder: (_, i) => FeedbackReviewCard(
                                          item: items[i],
                                          onViewDetails: (item) => _openDetails(item),
                                          onRespond: (item) => _openDetails(item, respond: true),
                                          onArchive: _archive,
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(height: 40),
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
          FeedbackDetailsDrawer(
            item: _selected,
            open: _drawerOpen,
            focusResponse: _focusResponse,
            onClose: _closeDrawer,
            onSendResponse: _sendResponse,
            onMarkReviewed: _selected == null ? () {} : () => _markReviewed(_selected!),
            onArchive: _selected == null ? () {} : () => _archive(_selected!),
            onResponseChanged: (text) {
              if (_selected != null) setState(() => _selected = _selected!.copyWith(adminResponse: text));
            },
          ),
        ],
      ),
    );
  }
}
