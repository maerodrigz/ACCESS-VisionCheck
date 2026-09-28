import 'package:flutter/material.dart';

const kAiRemarkSuggestions = [
  'Possible AI-generated media. Requires manual verification.',
  'Low confidence result. Needs further review.',
  'Verified as human-made media.',
  'Confirmed AI-generated content.',
  'Please reupload the original photo or video.',
  'Accepted with warning after manual review.',
];

class AdminRemarksBox extends StatelessWidget {
  const AdminRemarksBox({
    super.key,
    required this.controller,
    this.onChanged,
    this.focusNode,
    this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Admin feedback (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: kAiRemarkSuggestions.map((s) {
            return ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 11)),
              onPressed: () {
                final base = controller.text.trim();
                controller.text = base.isEmpty ? '$s ' : '$base $s';
                controller.selection = TextSelection.collapsed(offset: controller.text.length);
                onChanged?.call(controller.text);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hintText ?? 'Optional note for the member about this review.',
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
