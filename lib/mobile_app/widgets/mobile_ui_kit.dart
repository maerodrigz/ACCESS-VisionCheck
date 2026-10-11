import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:access_mobile/shared/api/api_client.dart';
import 'package:access_mobile/shared/constants/api_config.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';
import 'package:access_mobile/shared/controllers/member_data_controller.dart';

/// Standard horizontal padding for mobile tab content.
const double kMobilePagePadding = 16;

/// Vertical gap between major sections on tab screens.
const double kMobileSectionGap = 16;

/// Minimum touch height for tappable controls (Android Material guideline).
const double kMobileMinTouch = 48;

/// Responsive horizontal padding for phone widths.
double mobilePagePaddingOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 360) return 14;
  if (width < 400) return 16;
  return kMobilePagePadding;
}

/// Scroll/form padding that clears the software keyboard.
EdgeInsets mobileScrollPadding(
  BuildContext context, {
  double top = 8,
  double bottom = 32,
}) {
  final horizontal = mobilePagePaddingOf(context);
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottom + MediaQuery.viewInsetsOf(context).bottom,
  );
}

/// Wraps tab body with pull-to-refresh and optional offline banner.
class MobilePageWrapper extends StatelessWidget {
  const MobilePageWrapper({
    super.key,
    required this.child,
    this.showOffline = true,
  });

  final Widget child;
  final bool showOffline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: memberDataController,
          builder: (_, __) {
            final hasError = appState.memberSyncError != null;
            final offline = showOffline && hasError && !memberDataController.isLoading;
            if (!offline) return const SizedBox.shrink();
            return MobileOfflineBanner(
              error: appState.memberSyncError,
              onRetry: () => memberDataController.refreshAll(),
            );
          },
        ),
        Expanded(child: child),
      ],
    );
  }
}

Future<void> refreshMemberData(BuildContext context) async {
  await memberDataController.refreshAll();
  if (context.mounted) showMobileToast(context, 'Data updated');
}

class MobileOfflineBanner extends StatelessWidget {
  const MobileOfflineBanner({super.key, this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  bool get _isAuthError {
    final text = (error ?? '').toLowerCase();
    return text.contains('invalid token') ||
        text.contains('no token') ||
        text.contains('session expired');
  }

  String get _bannerTitle =>
      _isAuthError ? 'Session expired' : "Can't reach backend";

  @override
  Widget build(BuildContext context) {
    final body = error ?? 'Sync issue. Pull down to retry.';
    final accentSoft = kAccent.withValues(alpha: 0.08);
    final accentLine = kAccent.withValues(alpha: 0.22);
    final bannerIcon = _isAuthError ? Icons.lock_clock_rounded : Icons.cloud_off_rounded;
    return Material(
      color: accentSoft,
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: accentLine)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(bannerIcon, color: kAccent, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _bannerTitle,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      body.split('\n').first,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 10,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: kAccent,
                    minimumSize: const Size(0, kMobileMinTouch),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: kYellow, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Backend unreachable',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
            ),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error ?? 'Unable to load data.',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diagnostics',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      ApiConfig.describe(),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '• Start backend on PC: cd access_backend && python manage.py runserver\n'
                '• Android emulator → use 10.0.2.2 (default)\n'
                '• Physical phone → set the PC LAN IPv4 below.',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 11, height: 1.5),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final changed = await showBackendUrlDialog(context);
                  if (changed && onRetry != null) onRetry!();
                },
                icon: const Icon(Icons.dns_outlined, size: 16),
                label: const Text('Set backend URL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: const BorderSide(color: kAccent),
                  minimumSize: const Size(double.infinity, kMobileMinTouch),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (onRetry != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kAccent),
              onPressed: () {
                Navigator.pop(context);
                onRetry!();
              },
              child: const Text('Retry now'),
            ),
        ],
      ),
    );
  }
}

/// Lets the user paste the PC's LAN IPv4 (e.g. `192.168.1.42` or
/// `192.168.1.42:3001`) and saves it as the active backend host.
///
/// Returns `true` if the user saved a new value.
Future<bool> showBackendUrlDialog(BuildContext context) async {
  final savedUrl = ApiConfig.runtimeBaseUrl.value;
  final suggested = (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          savedUrl == null)
      ? 'http://${ApiConfig.knownLanHosts.first}:${ApiConfig.defaultPort}'
      : '';
  final controller = TextEditingController(
    text: savedUrl ?? suggested,
  );
  String? errorText;
  bool didSave = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> handleSave() async {
            final raw = controller.text.trim();
            if (raw.isEmpty) {
              setLocal(() => errorText = 'Enter the PC IPv4, e.g. 192.168.1.42');
              return;
            }
            await ApiConfig.runtimeBaseUrl.save(raw);
            if (ApiConfig.runtimeBaseUrl.value == null) {
              setLocal(() => errorText =
                  'Could not parse. Try `192.168.1.42` or `http://192.168.1.42:3001`.');
              return;
            }
            await apiClient.reconnect();
            didSave = true;
            if (ctx.mounted) Navigator.pop(ctx);
          }

          return AlertDialog(
            backgroundColor: ctx.colors.surface,
            title: Text(
              'Backend URL',
              style: TextStyle(color: ctx.colors.textPrimary, fontSize: 16),
            ),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Type your computer's LAN IPv4. On Windows run "
                  '`ipconfig` and copy "IPv4 Address" from your Wi-Fi adapter.',
                  style: TextStyle(
                    color: ctx.colors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: ctx.colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '192.168.1.42  or  http://192.168.1.42:3001',
                    hintStyle: TextStyle(color: ctx.colors.textSecondary, fontSize: 12),
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.dns_outlined, size: 18),
                  ),
                  onChanged: (_) {
                    if (errorText != null) setLocal(() => errorText = null);
                  },
                  onSubmitted: (_) => handleSave(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Default port is ${ApiConfig.defaultPort}.',
                  style: TextStyle(color: ctx.colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            actions: [
              if (ApiConfig.runtimeBaseUrl.value != null)
                TextButton(
                  onPressed: () async {
                    await ApiConfig.runtimeBaseUrl.clear();
                    didSave = true;
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: TextButton.styleFrom(foregroundColor: kRed),
                  child: const Text('Use default'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kAccent),
                onPressed: handleSave,
                child: const Text('Save & retry'),
              ),
            ],
          );
        },
      );
    },
  );

  return didSave;
}

class MobilePageTitle extends StatelessWidget {
  const MobilePageTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(mobilePagePaddingOf(context), 12, mobilePagePaddingOf(context), 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
}

class MobileLoadingView extends StatelessWidget {
  const MobileLoadingView({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: kAccent),
            ),
            const SizedBox(height: 14),
            Text(message, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          ],
        ),
      );
}

class MobileEmptyState extends StatelessWidget {
  const MobileEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: context.colors.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kAccent,
                    side: BorderSide(color: kAccent.withValues(alpha: 0.45)),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}

class MobileErrorState extends StatelessWidget {
  const MobileErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: kRed, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(backgroundColor: kAccent),
                  child: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      );
}

class MobileFilterChips extends StatelessWidget {
  const MobileFilterChips({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: kMobileMinTouch,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kMobilePagePadding),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = filters[i];
            final active = f == selected;
            return GestureDetector(
              onTap: () => onSelected(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? kAccent : context.colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: active ? kAccent : context.colors.border,
                    width: active ? 1 : 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: kAccent.withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    color: active ? Colors.white : context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class MobilePrimaryButton extends StatelessWidget {
  const MobilePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, kMobileMinTouch),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Standard elevated surface card (dashboard sections, forms, lists).
class MobileContentCard extends StatelessWidget {
  const MobileContentCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(14);
    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(color: colors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

void showMobileToast(BuildContext context, String message, {bool success = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        Icon(success ? Icons.check_circle_outline : Icons.info_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: success ? kGreen : kAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Lively post-save banner after a practice evaluation is stored.
void showEvalSaveSuccessToast(
  BuildContext context, {
  required int xp,
  required int submissionsRemaining,
  bool xpPending = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 22),
      duration: const Duration(seconds: 4),
      content: _EvalSaveSuccessBanner(
        xp: xp,
        submissionsRemaining: submissionsRemaining,
        xpPending: xpPending,
      ),
    ),
  );
}

class _EvalSaveSuccessBanner extends StatelessWidget {
  const _EvalSaveSuccessBanner({
    required this.xp,
    required this.submissionsRemaining,
    this.xpPending = false,
  });

  final int xp;
  final int submissionsRemaining;
  final bool xpPending;

  @override
  Widget build(BuildContext context) {
    final remainingLabel = submissionsRemaining == 1
        ? '1 upload left today'
        : '$submissionsRemaining uploads left today';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGreen.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: kGreen.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kGreen, kCyan],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kGreen.withValues(alpha: 0.95),
                            kGreen.withValues(alpha: 0.78),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: kGreen.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Evaluation saved!',
                            style: TextStyle(
                              color: kTextPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            xpPending
                                ? 'Saved. XP is pending officer review.'
                                : 'Nice work. Your score is on the leaderboard.',
                            style: TextStyle(
                              color: kTextSecondary.withValues(alpha: 0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _EvalSaveChip(
                                icon: xpPending ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
                                label: xpPending ? 'XP pending review' : '+$xp XP',
                                iconColor: xpPending ? kYellow : kYellow,
                                background: kYellowDim,
                                borderColor: kYellow.withValues(alpha: 0.35),
                              ),
                              _EvalSaveChip(
                                icon: Icons.photo_camera_rounded,
                                label: remainingLabel,
                                iconColor: kAccent,
                                background: kCyanDim,
                                borderColor: kCyan.withValues(alpha: 0.35),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _EvalSaveChip extends StatelessWidget {
  const _EvalSaveChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.background,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: kTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> showMobileConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.colors.surface,
      title: Text(title, style: TextStyle(color: context.colors.textPrimary)),
      content: Text(message, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(color: destructive ? kRed : kAccent, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
