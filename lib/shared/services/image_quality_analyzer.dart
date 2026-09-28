import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Deterministic pixel metrics for validation and scoring (same image → same metrics).
class ImageQualityMetrics {
  const ImageQualityMetrics({
    required this.width,
    required this.height,
    required this.blurScore,
    required this.brightness,
    required this.contrast,
    required this.colorBalance,
    required this.edgeBalance,
    required this.noiseLevel,
    required this.subjectClarity,
    this.blockingArtifacts = 0.15,
    this.ringingArtifacts = 0.12,
  });

  final int width;
  final int height;
  final double blurScore;
  final double brightness;
  final double contrast;
  final double colorBalance;
  final double edgeBalance;
  final double noiseLevel;
  final double subjectClarity;
  final double blockingArtifacts;
  final double ringingArtifacts;

  double get resolutionScore {
    final pixels = width * height;
    if (pixels >= 1920 * 1080) return 1.0;
    if (pixels >= 1280 * 720) return 0.85;
    if (pixels >= 640 * 480) return 0.65;
    return 0.4;
  }
}

ImageQualityMetrics? analyzeImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return _analyzePixels(decoded);
}

/// True when the file cannot be decoded or is essentially blank/black.
bool isBlankOrCorrupt(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return true;
  if (decoded.width < 8 || decoded.height < 8) return true;

  final w = decoded.width;
  final h = decoded.height;
  final stepX = (w / 24).ceil().clamp(1, w);
  final stepY = (h / 24).ceil().clamp(1, h);
  var samples = 0;
  var sumLum = 0.0;
  var minLum = 1.0;
  var maxLum = 0.0;

  for (var y = 0; y < h; y += stepY) {
    for (var x = 0; x < w; x += stepX) {
      final p = decoded.getPixel(x, y);
      final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
      sumLum += lum;
      if (lum < minLum) minLum = lum;
      if (lum > maxLum) maxLum = lum;
      samples++;
    }
  }
  if (samples == 0) return true;

  final mean = sumLum / samples;
  final spread = maxLum - minLum;
  if (mean < 0.04 && spread < 0.06) return true;
  if (mean > 0.97 && spread < 0.04) return true;
  return false;
}

ImageQualityMetrics _analyzePixels(img.Image image) {
  final w = image.width;
  final h = image.height;
  final stepX = (w / 48).ceil().clamp(1, w);
  final stepY = (h / 48).ceil().clamp(1, h);

  final lum = <double>[];
  final rVals = <int>[];
  final gVals = <int>[];
  final bVals = <int>[];
  var edgeSum = 0.0;
  var edgeCount = 0;
  var leftEdge = 0.0;
  var rightEdge = 0.0;
  var centerEdge = 0.0;

  for (var y = 0; y < h - stepY; y += stepY) {
    for (var x = 0; x < w - stepX; x += stepX) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      rVals.add(r);
      gVals.add(g);
      bVals.add(b);
      final l = 0.299 * r + 0.587 * g + 0.114 * b;
      lum.add(l / 255);

      if (x + stepX < w && y + stepY < h) {
        final p2 = image.getPixel(x + stepX, y + stepY);
        final l2 = 0.299 * p2.r + 0.587 * p2.g + 0.114 * p2.b;
        final diff = (l - l2).abs() / 255;
        edgeSum += diff;
        edgeCount++;
        final cx = x / w;
        if (cx < 0.33) {
          leftEdge += diff;
        } else if (cx > 0.66) {
          rightEdge += diff;
        } else {
          centerEdge += diff;
        }
      }
    }
  }

  final meanLum = lum.isEmpty ? 0.5 : lum.reduce((a, b) => a + b) / lum.length;
  final variance = lum.isEmpty
      ? 0.0
      : lum.map((v) => (v - meanLum) * (v - meanLum)).reduce((a, b) => a + b) / lum.length;

  final blurScore = edgeCount == 0 ? 0 : (edgeSum / edgeCount).clamp(0.0, 1.0);

  double channelMean(List<int> vals) =>
      vals.isEmpty ? 0 : vals.reduce((a, b) => a + b) / vals.length;
  final rM = channelMean(rVals);
  final gM = channelMean(gVals);
  final bM = channelMean(bVals);
  final maxC = [rM, gM, bM].reduce((a, b) => a > b ? a : b);
  final minC = [rM, gM, bM].reduce((a, b) => a < b ? a : b);
  final colorBalance = maxC == 0 ? 1 : (1 - (maxC - minC) / maxC).clamp(0.0, 1.0);

  final edgeBalance = (leftEdge + rightEdge) > 0
      ? (1 - ((leftEdge - rightEdge).abs() / (leftEdge + rightEdge + 0.001))).clamp(0.0, 1.0)
      : 0.5;

  final centerRatio = edgeCount == 0 ? 0.5 : (centerEdge / (edgeSum + 0.001)).clamp(0.0, 1.0);
  final subjectClarity = (blurScore * 0.55 + centerRatio * 0.45).clamp(0.0, 1.0);

  var highLum = 0;
  for (final l in lum) {
    if (l > 0.92) highLum++;
  }
  final overexposed = lum.isEmpty ? 0.0 : highLum / lum.length;

  final blocking = _blockingArtifactScore(image);
  final ringing = _ringingArtifactScore(image);

  return ImageQualityMetrics(
    width: w,
    height: h,
    blurScore: blurScore.toDouble(),
    brightness: meanLum.clamp(0.0, 1.0).toDouble(),
    contrast: math.sqrt(variance).clamp(0.0, 1.0).toDouble(),
    colorBalance: colorBalance.toDouble(),
    edgeBalance: edgeBalance.toDouble(),
    noiseLevel: overexposed.clamp(0.0, 1.0).toDouble(),
    subjectClarity: subjectClarity.toDouble(),
    blockingArtifacts: blocking,
    ringingArtifacts: ringing,
  );
}

/// Lower score = more blocking (JPEG macro-block flatness).
double _blockingArtifactScore(img.Image image) {
  const block = 8;
  final w = image.width;
  final h = image.height;
  if (w < block * 2 || h < block * 2) return 0.1;

  var flatBlocks = 0;
  var totalBlocks = 0;
  for (var by = 0; by < h - block; by += block) {
    for (var bx = 0; bx < w - block; bx += block) {
      final vars = <double>[];
      for (var y = by; y < by + block && y < h; y++) {
        for (var x = bx; x < bx + block && x < w; x++) {
          final p = image.getPixel(x, y);
          vars.add((0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0);
        }
      }
      if (vars.isEmpty) continue;
      final mean = vars.reduce((a, b) => a + b) / vars.length;
      final v = vars.map((e) => (e - mean) * (e - mean)).reduce((a, b) => a + b) / vars.length;
      if (v < 0.0008) flatBlocks++;
      totalBlocks++;
    }
  }
  if (totalBlocks == 0) return 0.1;
  return (flatBlocks / totalBlocks).clamp(0.0, 1.0);
}

/// Higher = more ringing halos along strong edges.
double _ringingArtifactScore(img.Image image) {
  final w = image.width;
  final h = image.height;
  if (w < 16 || h < 16) return 0.1;

  var oscillations = 0;
  var edges = 0;
  final stepY = (h / 24).ceil().clamp(1, h);
  for (var y = 0; y < h; y += stepY) {
    int? prevSign;
    for (var x = 1; x < w; x += 2) {
      final p1 = image.getPixel(x - 1, y);
      final p2 = image.getPixel(x, y);
      final l1 = (0.299 * p1.r + 0.587 * p1.g + 0.114 * p1.b) / 255.0;
      final l2 = (0.299 * p2.r + 0.587 * p2.g + 0.114 * p2.b) / 255.0;
      final diff = l2 - l1;
      if (diff.abs() > 0.08) {
        edges++;
        final sign = diff > 0 ? 1 : -1;
        if (prevSign != null && sign != prevSign) oscillations++;
        prevSign = sign;
      }
    }
  }
  if (edges == 0) return 0.08;
  return (oscillations / edges).clamp(0.0, 1.0);
}
