import 'package:flutter/material.dart';

import 'package:access_mobile/web_admin/layout/breadcrumbs.dart';

import 'package:access_mobile/web_admin/layout/last_updated_text.dart';

import 'package:access_mobile/web_admin/theme/admin_theme.dart';



/// Standard admin page header — title, breadcrumbs, description, actions, last updated.

class PageHeader extends StatelessWidget {

  const PageHeader({

    super.key,

    required this.title,

    required this.subtitle,

    this.breadcrumbs = const [],

    this.actions = const [],

    this.lastUpdated,

  });



  final String title;

  final String subtitle;

  final List<String> breadcrumbs;

  final List<Widget> actions;

  final DateTime? lastUpdated;



  @override

  Widget build(BuildContext context) {

    return LayoutBuilder(

      builder: (context, c) {

        // Stack title/actions only on narrow content — not at tablet viewport (sidebar reduces width).
        final compact = c.maxWidth < 560;
        final titleSize = c.maxWidth < 430 ? 22.0 : (compact ? 24.0 : 26.0);



        final titleBlock = Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            if (breadcrumbs.isNotEmpty) ...[

              Breadcrumbs(segments: breadcrumbs),

              const SizedBox(height: 8),

            ],

            Text(

              title,

              style: TextStyle(

                fontSize: titleSize,

                fontWeight: FontWeight.w800,

                color: AdminTheme.textPrimary,

                letterSpacing: -0.5,

                height: 1.2,

              ),

            ),

            const SizedBox(height: 6),

            Text(

              subtitle,

              style: const TextStyle(

                color: AdminTheme.textSecondary,

                fontSize: 13,

                height: 1.45,

              ),

            ),

            if (lastUpdated != null) ...[

              const SizedBox(height: 6),

              LastUpdatedText(updatedAt: lastUpdated),

            ],

          ],

        );



        if (compact) {

          return Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              titleBlock,

              if (actions.isNotEmpty) ...[

                const SizedBox(height: 14),

                Align(

                  alignment: Alignment.centerRight,

                  child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions),

                ),

              ],

            ],

          );

        }



        return Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Expanded(child: titleBlock),

            if (actions.isNotEmpty) ...[

              const SizedBox(width: 16),

              Wrap(

                spacing: 8,

                runSpacing: 8,

                alignment: WrapAlignment.end,

                crossAxisAlignment: WrapCrossAlignment.center,

                children: actions,

              ),

            ],

          ],

        );

      },

    );

  }

}



/// Rounded outline action for page headers.

class PageHeaderButton extends StatelessWidget {

  const PageHeaderButton({

    super.key,

    required this.label,

    required this.icon,

    required this.onPressed,

    this.filled = false,

    this.enabled = true,

  });



  final String label;

  final IconData icon;

  final VoidCallback? onPressed;

  final bool filled;

  final bool enabled;



  @override

  Widget build(BuildContext context) {

    if (filled) {

      return FilledButton.icon(

        onPressed: enabled ? onPressed : null,

        icon: Icon(icon, size: 18),

        label: Text(label),

      );

    }

    return OutlinedButton.icon(

      onPressed: enabled ? onPressed : null,

      style: OutlinedButton.styleFrom(

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

      ),

      icon: Icon(icon, size: 18),

      label: Text(label),

    );

  }

}



/// Compact pill refresh — pairs with export toolbar buttons on page headers.

class PageHeaderRefreshButton extends StatelessWidget {

  const PageHeaderRefreshButton({

    super.key,

    required this.onPressed,

    this.enabled = true,

  });



  final VoidCallback? onPressed;

  final bool enabled;



  static ButtonStyle get _style => OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF334155),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(88, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: _style,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, size: 16),
          SizedBox(width: 6),
          Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

}



class PageHeaderIconButton extends StatelessWidget {

  const PageHeaderIconButton({

    super.key,

    required this.icon,

    required this.onPressed,

    this.tooltip,

    this.enabled = true,

  });



  final IconData icon;

  final VoidCallback? onPressed;

  final String? tooltip;

  final bool enabled;



  @override

  Widget build(BuildContext context) {

    return IconButton.filledTonal(

      onPressed: enabled ? onPressed : null,

      icon: Icon(icon, size: 20),

      tooltip: tooltip ?? 'Refresh',

      style: IconButton.styleFrom(

        backgroundColor: Colors.white,

        foregroundColor: AdminTheme.textPrimary,

        disabledForegroundColor: AdminTheme.textSecondary,

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(10),

          side: const BorderSide(color: AdminTheme.border),

        ),

      ),

    );

  }

}

