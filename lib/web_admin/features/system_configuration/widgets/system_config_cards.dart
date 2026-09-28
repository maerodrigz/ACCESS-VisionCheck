import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/theme/admin_theme.dart';

Future<bool> confirmSaveChanges(BuildContext context, {String? message}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Apply changes?', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text(
        message ?? 'Are you sure you want to apply these changes?',
        style: const TextStyle(color: AdminTheme.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
          child: const Text('Save Changes'),
        ),
      ],
    ),
  );
  return ok == true;
}

class ConfigCategoryCard extends StatefulWidget {
  const ConfigCategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final bool busy;

  @override
  State<ConfigCategoryCard> createState() => _ConfigCategoryCardState();
}

class _ConfigCategoryCardState extends State<ConfigCategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: AdminTheme.cardDecoration().copyWith(
          border: Border.all(color: _hovered ? AdminTheme.accentBlue.withValues(alpha: 0.25) : AdminTheme.border),
          boxShadow: _hovered ? AdminTheme.cardShadow : null,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminTheme.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: AdminTheme.accentBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(widget.subtitle, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            widget.child,
            if (widget.primaryActionLabel != null && widget.onPrimaryAction != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: widget.busy ? null : widget.onPrimaryAction,
                  style: FilledButton.styleFrom(backgroundColor: AdminTheme.accentBlue),
                  child: widget.busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.primaryActionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ConfigToggleRow extends StatelessWidget {
  const ConfigToggleRow({super.key, required this.label, required this.subtitle, required this.value, required this.onChanged});

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AdminTheme.accentBlue),
        ],
      ),
    );
  }
}

class ConfigReadOnlyRow extends StatelessWidget {
  const ConfigReadOnlyRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class ConfigNumberField extends StatelessWidget {
  const ConfigNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) onChanged(n);
        },
      ),
    );
  }
}

class ConfigSliderRow extends StatelessWidget {
  const ConfigSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            Text('${(value * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AdminTheme.accentBlue)),
          ],
        ),
        Slider(
          value: value,
          min: 0.5,
          max: 0.99,
          divisions: 49,
          activeColor: AdminTheme.accentBlue,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
