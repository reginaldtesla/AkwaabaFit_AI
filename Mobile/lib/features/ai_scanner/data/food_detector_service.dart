import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

/// One detected food item from YOLOv8 v1 (offline ONNX on device).
class FoodDetection {
  const FoodDetection({
    required this.className,
    required this.classIndex,
    required this.confidence,
  });

  final String className;
  final int classIndex;
  final double confidence;
}

/// Offline food detector using `food_model` v1 ONNX (22 classes, 416×416).
class FoodDetectorService {
  FoodDetectorService._({
    required OrtSession session,
    required List<String> labels,
  })  : _session = session,
        _labels = labels;

  static const String _modelAsset = 'assets/models/food_v1.onnx';
  static const String _labelsAsset = 'assets/models/food_labels.json';
  static const int inputSize = 416;
  static const int numClasses = 22;
  static const double confThreshold = 0.35;
  static const double iouThreshold = 0.45;

  final OrtSession _session;
  final List<String> _labels;
  static FoodDetectorService? _instance;

  static Future<FoodDetectorService> instance() async {
    if (_instance != null) return _instance!;
    _instance = await _create();
    return _instance!;
  }

  static Future<FoodDetectorService> _create() async {
    OrtEnv.instance.init();
    final options = OrtSessionOptions();
    options.setIntraOpNumThreads(2);
    options.setInterOpNumThreads(1);

    final modelBytes = (await rootBundle.load(_modelAsset)).buffer.asUint8List();
    final labelsJson =
        jsonDecode(await rootBundle.loadString(_labelsAsset)) as List<dynamic>;
    final labels = labelsJson.map((e) => e.toString()).toList();
    if (labels.length != numClasses) {
      throw StateError('Expected $numClasses labels, got ${labels.length}');
    }

    final session = OrtSession.fromBuffer(modelBytes, options);
    return FoodDetectorService._(session: session, labels: labels);
  }

  /// Runs inference on an image file path (camera or gallery). Fully offline.
  Future<List<FoodDetection>> detectFromFile(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return detectFromBytes(bytes);
  }

  Future<List<FoodDetection>> detectFromBytes(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode image');
    }
    return _detect(decoded);
  }

  Future<List<FoodDetection>> _detect(img.Image source) async {
    final letterbox = _letterbox(source, inputSize);
    final inputTensor = _imageToTensor(letterbox.image);
    final inputName = _session.inputNames.first;
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      inputTensor,
      [1, 3, inputSize, inputSize],
    );
    final runOptions = OrtRunOptions();
    final outputs = _session.run(runOptions, {inputName: inputOrt});
    inputOrt.release();
    runOptions.release();

    try {
      final output = outputs.first;
      if (output is! OrtValueTensor) {
        throw StateError('Unexpected ONNX output type');
      }
      final raw = _flattenTensor(output.value);
      final detections = _postprocess(
        raw,
        srcWidth: source.width,
        srcHeight: source.height,
        padX: letterbox.padX,
        padY: letterbox.padY,
        scale: letterbox.scale,
      );
      detections.sort((a, b) => b.confidence.compareTo(a.confidence));
      return detections;
    } finally {
      for (final o in outputs) {
        o?.release();
      }
    }
  }

  List<num> _flattenTensor(dynamic value) {
    if (value is List<num>) return value;
    final out = <num>[];
    void walk(dynamic node) {
      if (node is List) {
        for (final child in node) {
          walk(child);
        }
      } else if (node is num) {
        out.add(node);
      }
    }
    walk(value);
    if (out.isEmpty) {
      throw StateError('Could not read ONNX output tensor');
    }
    return out;
  }

  List<FoodDetection> _postprocess(
    List<num> raw, {
    required int srcWidth,
    required int srcHeight,
    required double padX,
    required double padY,
    required double scale,
  }) {
    // ONNX output shape [1, 26, 3549] → rows of 26 features per anchor.
    const anchors = 3549;
    final candidates = <_BoxScore>[];

    for (var i = 0; i < anchors; i++) {
      final cx = raw[i].toDouble();
      final cy = raw[anchors + i].toDouble();
      final w = raw[2 * anchors + i].toDouble();
      final h = raw[3 * anchors + i].toDouble();

      var bestScore = 0.0;
      var bestClass = 0;
      for (var c = 0; c < numClasses; c++) {
        final score = raw[(4 + c) * anchors + i].toDouble();
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }
      if (bestScore < confThreshold) continue;

      var x1 = cx - w / 2;
      var y1 = cy - h / 2;
      var x2 = cx + w / 2;
      var y2 = cy + h / 2;

      x1 = (x1 - padX) / scale;
      y1 = (y1 - padY) / scale;
      x2 = (x2 - padX) / scale;
      y2 = (y2 - padY) / scale;

      x1 = x1.clamp(0, srcWidth.toDouble());
      y1 = y1.clamp(0, srcHeight.toDouble());
      x2 = x2.clamp(0, srcWidth.toDouble());
      y2 = y2.clamp(0, srcHeight.toDouble());

      candidates.add(
        _BoxScore(
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          score: bestScore,
          classIndex: bestClass,
        ),
      );
    }

    final kept = _nms(candidates, iouThreshold);
    return kept
        .map(
          (b) => FoodDetection(
            className: _labels[b.classIndex],
            classIndex: b.classIndex,
            confidence: b.score,
          ),
        )
        .toList();
  }

  List<_BoxScore> _nms(List<_BoxScore> boxes, double iouThresh) {
    boxes.sort((a, b) => b.score.compareTo(a.score));
    final selected = <_BoxScore>[];
    final suppressed = List<bool>.filled(boxes.length, false);

    for (var i = 0; i < boxes.length; i++) {
      if (suppressed[i]) continue;
      selected.add(boxes[i]);
      for (var j = i + 1; j < boxes.length; j++) {
        if (suppressed[j]) continue;
        if (_iou(boxes[i], boxes[j]) > iouThresh) {
          suppressed[j] = true;
        }
      }
    }
    return selected;
  }

  double _iou(_BoxScore a, _BoxScore b) {
    final interX1 = math.max(a.x1, b.x1);
    final interY1 = math.max(a.y1, b.y1);
    final interX2 = math.min(a.x2, b.x2);
    final interY2 = math.min(a.y2, b.y2);
    final interW = math.max(0, interX2 - interX1);
    final interH = math.max(0, interY2 - interY1);
    final inter = interW * interH;
    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
    final union = areaA + areaB - inter;
    if (union <= 0) return 0;
    return inter / union;
  }

  Float32List _imageToTensor(img.Image rgb) {
    final buffer = Float32List(3 * inputSize * inputSize);
    var i = 0;
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final pixel = rgb.getPixel(x, y);
          final value = switch (c) {
            0 => pixel.r,
            1 => pixel.g,
            _ => pixel.b,
          };
          buffer[i++] = value / 255.0;
        }
      }
    }
    return buffer;
  }

  _LetterboxResult _letterbox(img.Image src, int size) {
    final r = math.min(size / src.width, size / src.height);
    final newW = (src.width * r).round();
    final newH = (src.height * r).round();
    final padX = (size - newW) / 2;
    final padY = (size - newH) / 2;

    final resized = img.copyResize(src, width: newW, height: newH);
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(
      canvas,
      resized,
      dstX: padX.round(),
      dstY: padY.round(),
    );
    return _LetterboxResult(
      image: canvas,
      scale: r,
      padX: padX,
      padY: padY,
    );
  }
}

class _LetterboxResult {
  const _LetterboxResult({
    required this.image,
    required this.scale,
    required this.padX,
    required this.padY,
  });

  final img.Image image;
  final double scale;
  final double padX;
  final double padY;
}

class _BoxScore {
  const _BoxScore({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.classIndex,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double score;
  final int classIndex;
}

/// Top-level for [compute] — keeps UI responsive during inference.
Future<List<FoodDetection>> detectFoodOffline(String imagePath) async {
  final detector = await FoodDetectorService.instance();
  return detector.detectFromFile(imagePath);
}
