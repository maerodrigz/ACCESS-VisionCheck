import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:access_mobile/shared/themes/theme.dart';
import 'package:access_mobile/shared/controllers/app_state.dart';

// Conditional import: web uses dart:html, mobile/desktop use stub
import 'package:access_mobile/mobile_app/services/file_picker_service.dart';

void showImageEvaluation(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => const SubmitAssessmentSheet(),
  );
}

class _PickedImage {
  final String name;
  final Uint8List bytes;
  _PickedImage(this.name, this.bytes);
}

class SubmitAssessmentSheet extends StatefulWidget {
  const SubmitAssessmentSheet({super.key});
  @override
  State<SubmitAssessmentSheet> createState() => _SubmitAssessmentSheetState();
}

class _SubmitAssessmentSheetState extends State<SubmitAssessmentSheet> {
  final _picker = ImagePicker();
  final List<_PickedImage> _images = [];
  final _titleCtrl = TextEditingController();
  String _selectedCategory = '';
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (kIsWeb) {
      final picked = await pickImagesFromWeb();
      if (picked.isNotEmpty) {
        setState(() => _images.addAll(
            picked.map((p) => _PickedImage(p.name, p.bytes))));
      }
    } else {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      final loaded = await Future.wait(
          picked.map((f) async => _PickedImage(f.name, await f.readAsBytes())));
      setState(() => _images.addAll(loaded));
    }
  }

  Future<void> _pickFromCamera() async {
    final picked =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _images.add(_PickedImage(picked.name, bytes)));
  }

  void _removeImage(int i) => setState(() => _images.removeAt(i));

  Future<void> _submit() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select at least one image'),
          backgroundColor: kRed));
      return;
    }
    final title = _titleCtrl.text.trim().isEmpty
        ? (_selectedCategory.isEmpty
            ? 'Submitted Assessment'
            : '$_selectedCategory Assessment')
        : _titleCtrl.text.trim();
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final now = DateTime.now();
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';
    final id =
        'ACC-${now.year % 100}-${(appState.evaluations.length + 1).toString().padLeft(3, '0')}';

    appState.addEvaluation(Evaluation(
      id: id,
      title: title,
      score: 0.0,
      composition: _selectedCategory.isEmpty ? 'Pending' : _selectedCategory,
      lighting: 'Pending',
      feedback:
          'Your submission is under review. Results will be available soon.',
      date: dateStr,
      evaluatedAt: now,
      images: _images.map((i) => i.bytes).toList(),
    ));

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('${_images.length} image(s) submitted. Check the Assessments tab.'),
        backgroundColor: kGreen));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Submit Assessment',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Upload photos from your event coverage or documentation task',
              style: TextStyle(color: kTextSecondary, fontSize: 12)),
          const SizedBox(height: 20),

          // Title field
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: kTextPrimary),
            decoration: const InputDecoration(
              labelText: 'Event / Coverage Title',
              hintText: 'e.g. Foundation Day 2024',
              hintStyle: TextStyle(color: kTextSecondary),
            ),
          ),
          const SizedBox(height: 16),

          // Upload buttons
          if (kIsWeb)
            _UploadBtn(
                label: 'Select Files',
                icon: Icons.upload_file_outlined,
                onTap: _pickFiles)
          else
            Row(children: [
              Expanded(
                  child: _UploadBtn(
                      label: 'Gallery',
                      icon: Icons.photo_library_outlined,
                      onTap: _pickFiles)),
              const SizedBox(width: 10),
              Expanded(
                  child: _UploadBtn(
                      label: 'Camera',
                      icon: Icons.camera_alt_outlined,
                      onTap: _pickFromCamera)),
            ]),

          const SizedBox(height: 16),

          // Preview or drop zone
          if (_images.isNotEmpty) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${_images.length} image(s) selected',
                  style:
                      const TextStyle(color: kTextSecondary, fontSize: 12)),
              GestureDetector(
                  onTap: () => setState(() => _images.clear()),
                  child: const Text('Clear all',
                      style: TextStyle(
                          color: kRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_images[i].bytes,
                          width: 100, height: 100, fit: BoxFit.cover)),
                  Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                  color: kRed, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 14)))),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _UploadZone(onTap: _pickFiles),
            const SizedBox(height: 16),
          ],

          // Category
          const Text('Category',
              style: TextStyle(color: kTextSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              children: ['Coverage', 'Portrait', 'Documentary', 'Behind the Scenes', 'Official']
                  .map((cat) => GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: _selectedCategory == cat
                                    ? kCyan
                                    : kSurfaceAlt,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _selectedCategory == cat
                                        ? kCyan
                                        : kBorder)),
                            child: Text(cat,
                                style: TextStyle(
                                    color: _selectedCategory == cat
                                        ? kBg
                                        : kTextSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                      ))
                  .toList()),
          const SizedBox(height: 20),

          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kCyan,
                      foregroundColor: kBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kBg))
                      : const Text('Submit Assessment',
                          style: TextStyle(fontWeight: FontWeight.w700)))),
        ]),
      ),
    );
  }
}

class _UploadBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _UploadBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: kSurfaceAlt,
                foregroundColor: kCyan,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: kBorder)),
                elevation: 0),
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
      );
}

class _UploadZone extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadZone({required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kSurfaceAlt,
                foregroundColor: kCyan,
                padding: const EdgeInsets.symmetric(vertical: 28),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: kCyan.withOpacity(0.4), width: 1.5)),
                elevation: 0),
            onPressed: onTap,
            child: const Column(children: [
              Icon(Icons.add_photo_alternate_outlined, size: 32),
              SizedBox(height: 6),
              Text('Tap to select images',
                  style: TextStyle(fontSize: 13)),
              Text('JPG, PNG supported',
                  style:
                      TextStyle(color: kTextSecondary, fontSize: 11)),
            ])),
      );
}
