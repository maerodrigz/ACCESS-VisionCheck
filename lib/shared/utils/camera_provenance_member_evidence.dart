import 'package:access_mobile/shared/models/photo_evaluation_result.dart';

/// Member-facing provenance evidence lines derived only from stored evaluation JSON.
class CameraProvenanceMemberEvidence {
  const CameraProvenanceMemberEvidence({
    required this.isVideoContainer,
    this.recordingTimestamp,
    this.androidVersion,
    this.cameraManufacturer,
    this.cameraModel,
    required this.showCameraIdentityUnavailable,
  });

  final bool isVideoContainer;
  final String? recordingTimestamp;
  final String? androidVersion;
  final String? cameraManufacturer;
  final String? cameraModel;
  final bool showCameraIdentityUnavailable;

  List<String> toDisplayLines() {
    final lines = <String>[];
    if (recordingTimestamp != null && recordingTimestamp!.isNotEmpty) {
      lines.add('Recording timestamp: $recordingTimestamp');
    }
    if (androidVersion != null && androidVersion!.isNotEmpty) {
      lines.add('Android version: $androidVersion');
    }
    if (cameraManufacturer != null && cameraManufacturer!.isNotEmpty) {
      lines.add('Camera manufacturer: $cameraManufacturer');
    }
    if (cameraModel != null && cameraModel!.isNotEmpty) {
      lines.add('Camera model: $cameraModel');
    }
    if (showCameraIdentityUnavailable) {
      lines.add('Camera identity unavailable');
    }
    return lines;
  }
}

String? _fieldValue(Map<String, String> index, Iterable<String> keys) {
  for (final key in keys) {
    final v = index[key.toLowerCase()];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

Map<String, String> _provenanceFieldIndex(AiDetectionResult automated) {
  final index = <String, String>{};
  void ingestRow(dynamic row) {
    if (row is! Map) return;
    final m = Map<String, dynamic>.from(row);
    final key = (m['key'] ?? m['label'] ?? '').toString().trim();
    final value = (m['value'] ?? '').toString().trim();
    if (key.isEmpty || value.isEmpty) return;
    index[key.toLowerCase()] = value;
  }

  for (final row in automated.provenanceContainerFields) {
    ingestRow(row);
  }
  final exif = automated.exifMetadata;
  if (exif != null) {
    final fields = exif['fields'];
    if (fields is List) {
      for (final row in fields) {
        ingestRow(row);
      }
    }
  }
  return index;
}

bool memberAiDetectionIsVideoContainerProvenance(AiDetectionResult automated) {
  if (automated.isVideoProvenanceFlag == true) return true;
  final exif = automated.exifMetadata;
  if (exif == null) return false;
  if (exif['is_video'] == true) return true;
  final format = (exif['format'] as String? ?? '').toLowerCase();
  return format == 'video_container';
}

String? _formatRecordingTimestampDisplay(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  final local = parsed.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi (local time)';
}

CameraProvenanceMemberEvidence buildCameraProvenanceMemberEvidence(
  AiDetectionResult automated,
) {
  final index = _provenanceFieldIndex(automated);
  final isVideo = memberAiDetectionIsVideoContainerProvenance(automated);

  final rawTime = _fieldValue(index, const [
    'creation_time',
    'com.apple.quicktime.creationdate',
    'datetimeoriginal',
    'createdate',
    'date/time original',
  ]);
  final android = _fieldValue(index, const ['com.android.version']);
  final make = _fieldValue(index, const [
    'make',
    'com.android.manufacturer',
    'manufacturer',
  ]);
  final model = _fieldValue(index, const [
    'model',
    'com.android.model',
  ]);

  final partial = automated.isCameraProvenancePartial;
  final absent = automated.isCameraProvenanceAbsent;
  final needsIdentityNote = (partial || absent) && make == null && model == null;

  return CameraProvenanceMemberEvidence(
    isVideoContainer: isVideo,
    recordingTimestamp:
        rawTime == null ? null : _formatRecordingTimestampDisplay(rawTime),
    androidVersion: android,
    cameraManufacturer: make,
    cameraModel: model,
    showCameraIdentityUnavailable: needsIdentityNote,
  );
}

List<String> memberCameraProvenanceEvidenceLines(AiDetectionResult automated) {
  return buildCameraProvenanceMemberEvidence(automated).toDisplayLines();
}
