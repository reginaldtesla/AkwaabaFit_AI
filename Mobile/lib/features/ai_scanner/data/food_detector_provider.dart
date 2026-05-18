import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/ai_scanner/data/food_detector_service.dart';

/// Loads the bundled v1 ONNX model once (offline, no network).
final foodDetectorProvider = FutureProvider<FoodDetectorService>((ref) async {
  return FoodDetectorService.instance();
});
