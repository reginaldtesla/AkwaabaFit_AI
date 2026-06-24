import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/food_scan/data/food_scan_api_service.dart';

final foodScanApiProvider = Provider<FoodScanApiService>((ref) {
  return FoodScanApiService();
});
