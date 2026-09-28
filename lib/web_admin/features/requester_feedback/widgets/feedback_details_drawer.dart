import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/requester_feedback_models.dart';
import 'package:access_mobile/web_admin/features/requester_feedback/widgets/feedback_badges.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

class FeedbackDetailsDrawer extends StatefulWidget {
  const FeedbackDetailsDrawer({
    super.key,
    required this.item,
    required this.open,
    required this.onClose,
    required this.onSendResponse,
    required this.onMarkReviewed,
    required this.onArchive,
    required this.onResponseChanged,
    this.focusResponse = false,
  });

  final RequesterFeedbackItem? item;
  final bool open;
  final VoidCallback onClose;
  final VoidCallback onSendResponse;
  final VoidCallback onMarkReviewed;
  final VoidCallback onArchive;
  final ValueChanged<String> onResponseChanged;
  final bool focusResponse;

  @override
  State<FeedbackDetailsDrawer> createState() => _FeedbackDetailsDrawerState();
}

class _FeedbackDetailsDrawerState extends State<FeedbackDetailsDrawer> {
  late final TextEditingController _responseController;
  final _responseFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _responseController = TextEditingController(text: widget.item?.adminResponse ?? kDefaultAdminResponse);
  }

  @override
  void didUpdateWidget(covariant FeedbackDetailsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item?.id != widget.item?.id) {
      _responseController.text = widget.item?.adminResponse ?? kDefaultAdminResponse;
    }
    if (widget.open && widget.focusResponse && !oldWidget.focusResponse) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _responseFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _responseController.dispose();
    _responseFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: widget.open ? 0 : -600,
      width: 580,
      child: Material(
        elevation: 16,
        child: Container(
          decoration: const BoxDecoration(
            color: AdminTheme.surface,
            border: Border(left: BorderSide(color: AdminTheme.border)),
          ),
          child: item == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(onClose: widget.onClose),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionTitle('EVENT INFORMATION'),
                            const SizedBox(height: 8),
                            _Row(label: 'Event name', value: item.eventName),
                            _Row(label: 'Organization', value: item.organization),
                            _Row(label: 'Event date', value: formatFeedbackDate(item.eventDate)),
                            _Row(label: 'Completion date', value: formatFeedbackDate(item.completionDate)),
                            const SizedBox(height: 16),
                            const _SectionTitle('SERVICE SUMMARY'),
                            const SizedBox(height: 8),
                            _ServiceSummaryBlock(summary: item.eventSummary),
                            const SizedBox(height: 16),
                            const _SectionTitle('REQUESTER RATING'),
                            const SizedBox(height: 8),
                            StarRatingDisplay(rating: item.rating, size: 28, showValue: true),
                            if (item.needsAttention) ...[
                              const SizedBox(height: 12),
                              LowRatingAlertBanner(reason: item.attentionReason ?? 'Low rating'),
                            ],
                            const SizedBox(height: 16),
                            const _SectionTitle('REQUESTER COMMENTS'),
                            const SizedBox(height: 8),
                            Builder(builder: (_) {
                              final parsed = parseRequesterFeedbackComment(item.comment);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Type: ${parsed.$1}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AdminTheme.contentBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AdminTheme.border),
                                    ),
                                    child: Text(
                                      parsed.$2.isEmpty ? 'No written comment provided.' : parsed.$2,
                                      style: const TextStyle(fontSize: 13, height: 1.5),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            const SizedBox(height: 20),
                            const _SectionTitle('ADMIN RESPONSE'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _responseController,
                              focusNode: _responseFocus,
                              maxLines: 5,
                              onChanged: widget.onResponseChanged,
                              decoration: const InputDecoration(hintText: 'Reply to the requester…'),
                            ),
                            if (item.reviewStatus == FeedbackReviewStatus.reviewed) ...[
                              const SizedBox(height: 8),
                              FeedbackStatusBadge(status: item.reviewStatus),
                            ],
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: widget.onSendResponse,
                                  style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
                                  child: const Text('Send Response'),
                                ),
                                OutlinedButton(onPressed: widget.onMarkReviewed, child: const Text('Mark as Reviewed')),
                                OutlinedButton(onPressed: widget.onArchive, child: const Text('Archive Feedback')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AdminTheme.border))),
      child: Row(
        children: [
          const Expanded(child: Text('Feedback Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AdminTheme.textPrimary));
  }
}

class _ServiceSummaryBlock extends StatelessWidget {
  const _ServiceSummaryBlock({required this.summary});

  final EventServiceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.contentBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        children: [
          _Row(label: 'Photographer(s)', value: summary.photographersLabel),
          _Row(label: 'Videographer(s)', value: summary.videographersLabel),
          _Row(label: 'Photos delivered', value: '${summary.photoCount}'),
          _Row(label: 'Videos delivered', value: '${summary.videoCount}'),
          _Row(label: 'Facebook published', value: summary.facebookLabel),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
