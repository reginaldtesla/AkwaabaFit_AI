import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/food_scan/data/food_nutrition_info.dart';
import 'package:mobile/features/food_scan/data/food_scan_api_service.dart';
import 'package:mobile/features/food_scan/data/hybrid_nutrition_service.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/food_scan/data/not_food_scan_exception.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/nutrition/dietitian_advice.dart';
import 'package:mobile/shared/nutrition/nutrition_refresh.dart';
import 'package:mobile/shared/nutrition/nutrition_repository.dart';

class FoodScanResult {
  const FoodScanResult({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.ironMg,
    required this.folateMcg,
    required this.safetyStatus,
    required this.confidence,
    required this.detectedItems,
    required this.selectedClassNames,
    required this.strategy,
    this.portionLabel = '1 serving',
    this.alternateLabels = const [],
    this.imagePath,
    this.mealSaved = false,
    this.isRefiningNutrition = false,
    this.nutritionSource = 'bundled',
    this.isGenericFallback = false,
    this.dietitianInsight = '',
    this.dietitianPairing,
    this.dietitianSource = 'rules',
  });

  final String name;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final double ironMg;
  final int folateMcg;
  final String safetyStatus;
  final double confidence;
  final List<ScannedFoodItem> detectedItems;
  final List<String> selectedClassNames;
  final String strategy;
  final String portionLabel;
  final List<String> alternateLabels;
  final String? imagePath;
  final bool mealSaved;
  final bool isRefiningNutrition;
  final String nutritionSource;
  final bool isGenericFallback;
  final String dietitianInsight;
  final String? dietitianPairing;
  final String dietitianSource;

  FoodScanResult copyWith({
    bool? mealSaved,
    bool? isRefiningNutrition,
    String? nutritionSource,
    bool? isGenericFallback,
    List<ScannedFoodItem>? detectedItems,
    List<String>? selectedClassNames,
    String? portionLabel,
    List<String>? alternateLabels,
    String? dietitianInsight,
    String? dietitianPairing,
    String? dietitianSource,
  }) {
    return FoodScanResult(
      name: name,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      ironMg: ironMg,
      folateMcg: folateMcg,
      safetyStatus: safetyStatus,
      confidence: confidence,
      detectedItems: detectedItems ?? this.detectedItems,
      selectedClassNames: selectedClassNames ?? this.selectedClassNames,
      strategy: strategy,
      portionLabel: portionLabel ?? this.portionLabel,
      alternateLabels: alternateLabels ?? this.alternateLabels,
      imagePath: imagePath,
      mealSaved: mealSaved ?? this.mealSaved,
      isRefiningNutrition: isRefiningNutrition ?? this.isRefiningNutrition,
      nutritionSource: nutritionSource ?? this.nutritionSource,
      isGenericFallback: isGenericFallback ?? this.isGenericFallback,
      dietitianInsight: dietitianInsight ?? this.dietitianInsight,
      dietitianPairing: dietitianPairing ?? this.dietitianPairing,
      dietitianSource: dietitianSource ?? this.dietitianSource,
    );
  }
}

class ScannedFoodItem {
  const ScannedFoodItem({
    required this.className,
    required this.displayName,
    required this.confidence,
    required this.source,
    required this.nutrition,
  });

  final String className;
  final String displayName;
  final double confidence;
  final String source;
  final FoodNutritionInfo nutrition;
}

final foodScannerProvider =
    AsyncNotifierProvider<FoodScannerNotifier, FoodScanResult?>(
  FoodScannerNotifier.new,
);

class FoodScannerNotifier extends AsyncNotifier<FoodScanResult?> {
  @override
  Future<FoodScanResult?> build() async => null;

  Future<void> scanFood({XFile? image}) async {
    state = const AsyncValue.loading();
    try {
      if (image == null || image.path.isEmpty) {
        throw StateError('No image to scan. Take a photo or pick from gallery.');
      }
      await _scanPath(image.path);
    } catch (e, st) {
      state = AsyncValue.error(_scanError(e), st);
    }
  }

  Future<void> scanFromPicker({ImageSource source = ImageSource.camera}) async {
    state = const AsyncValue.loading();
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (picked == null) {
        state = const AsyncValue.data(null);
        return;
      }
      await _scanPath(picked.path);
    } catch (e, st) {
      state = AsyncValue.error(_scanError(e), st);
    }
  }

  Future<void> _scanPath(String path) async {
    final hybrid = await ref.read(hybridNutritionProvider.future);
    if (!await hybrid.isOnline()) {
      throw StateError('Internet required. Connect to Wi‑Fi or mobile data.');
    }

    final api = ref.read(foodScanApiProvider);
    final scan = await api.scanImage(path);
    final minConf = AppConfig.minScanConfidence;
    final detections = scan.detections
        .where((d) => d.confidence >= minConf)
        .toList();
    if (detections.isEmpty) {
      throw NotFoodScanException(
        detail: scan.message ??
            "This doesn't look like food. Point your camera at a meal on a plate and scan again.",
      );
    }

    final items = <ScannedFoodItem>[];
    for (final d in detections.take(5)) {
      final nutrition = await hybrid.resolve(d.className);
      items.add(
        ScannedFoodItem(
          className: d.className,
          displayName:
              d.displayName.isNotEmpty ? d.displayName : nutrition.displayName,
          confidence: d.confidence,
          source: d.source,
          nutrition: nutrition,
        ),
      );
    }

    final selected = [items.first.className];
    var result = _aggregate(
      items: items,
      selected: selected,
      imagePath: path,
      strategy: scan.strategy,
    );
    state = AsyncValue.data(result);

    state = AsyncValue.data(result.copyWith(isRefiningNutrition: true));
    final refreshed = await hybrid.refreshFromServer(selected.first);
    if (refreshed != null) {
      final nextItems = items
          .map(
            (it) => it.className == selected.first
                ? ScannedFoodItem(
                    className: it.className,
                    displayName: refreshed.displayName,
                    confidence: it.confidence,
                    source: it.source,
                    nutrition: refreshed,
                  )
                : it,
          )
          .toList();
      result = _aggregate(
        items: nextItems,
        selected: selected,
        imagePath: path,
        strategy: scan.strategy,
      );
    }
    state = AsyncValue.data(
      result.copyWith(isRefiningNutrition: false),
    );

    await _enrichWithDietitianAdvice();
  }

  Future<void> _enrichWithDietitianAdvice() async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final api = ref.read(foodScanApiProvider);
      final primaryClass = current.selectedClassNames.isNotEmpty
          ? current.selectedClassNames.first
          : null;
      final advice = await api.fetchMealAdvice(
        name: current.name,
        className: primaryClass,
        calories: current.calories,
        proteinG: current.proteinG,
        carbsG: current.carbsG,
        fatG: current.fatG,
      );
      if (advice.insight.trim().isEmpty) return;
      state = AsyncValue.data(
        current.copyWith(
          dietitianInsight: advice.insight,
          dietitianPairing: advice.pairing,
          dietitianSource: advice.source,
        ),
      );
    } catch (_) {
      // Keep rule-based tip from _aggregate when Gemini is unavailable.
    }
  }

  void toggleItem(String className) {
    final current = state.valueOrNull;
    if (current == null) return;
    final selected = [...current.selectedClassNames];
    if (selected.contains(className)) {
      if (selected.length <= 1) return;
      selected.remove(className);
    } else {
      selected.add(className);
    }
    state = AsyncValue.data(
      _aggregate(
        items: current.detectedItems,
        selected: selected,
        imagePath: current.imagePath,
        strategy: current.strategy,
      ),
    );
  }

  void toggleDetectedItem(String className) => toggleItem(className);

  Future<void> logCurrentSelection() => logMeal();

  void clearScan() => clear();

  Object _scanError(Object e) {
    if (e is NotFoodScanException) return e;
    final msg = _friendlyError(e);
    if (msg.contains("doesn't look like food") ||
        msg.contains('Point your camera at a meal')) {
      return NotFoodScanException(detail: msg);
    }
    return msg;
  }

  String _friendlyError(Object e) {
    if (e is NotFoodScanException) return e.detail;
    if (e is StateError) return e.message;
    final raw = e.toString();
    if (raw.contains('SocketException') || raw.contains('Connection')) {
      return 'Could not reach the scan service. Check your connection.';
    }
    if (raw.contains('DioException')) {
      return "This doesn't look like food. Point your camera at a meal on a plate and scan again.";
    }
    return raw.replaceFirst('Exception: ', '');
  }

  Future<void> logMeal() async {
    final current = state.valueOrNull;
    if (current == null || current.mealSaved) return;

    state = AsyncValue.data(current.copyWith(isRefiningNutrition: true));
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      await repo.logMeal(_mealPayload(current));
      ref.invalidate(nutritionHistoryProvider);
      bumpNutritionDashboardRefresh(ref);
      state = AsyncValue.data(
        current.copyWith(mealSaved: true, isRefiningNutrition: false),
      );
    } catch (e, st) {
      state = AsyncValue.error('Could not log meal. $e', st);
    }
  }

  void clear() => state = const AsyncValue.data(null);

  FoodScanResult _aggregate({
    required List<ScannedFoodItem> items,
    required List<String> selected,
    required String? imagePath,
    required String strategy,
  }) {
    final chosen =
        items.where((it) => selected.contains(it.className)).toList();
    final primary = chosen.isNotEmpty ? chosen.first : items.first;

    final calories = chosen.fold<int>(0, (s, it) => s + it.nutrition.calories);
    final protein = chosen.fold<int>(0, (s, it) => s + it.nutrition.proteinG);
    final carbs = chosen.fold<int>(0, (s, it) => s + it.nutrition.carbsG);
    final fat = chosen.fold<int>(0, (s, it) => s + it.nutrition.fatG);
    final iron = chosen.fold<double>(0, (s, it) => s + it.nutrition.ironMg);
    final folate = chosen.fold<int>(0, (s, it) => s + it.nutrition.folateMcg);

    final name = chosen.length <= 1
        ? primary.displayName
        : chosen.map((e) => e.displayName).take(3).join(' + ');

    final alternates = items
        .where((it) => !selected.contains(it.className))
        .take(3)
        .map((it) => it.displayName)
        .toList();

    final label = chosen.length <= 1
        ? primary.nutrition.portionLabel
        : '1 plate (multi‑item)';

    final source = chosen.any((it) => it.nutrition.source == 'server')
        ? 'server'
        : chosen.any((it) => it.nutrition.source == 'cache')
            ? 'cache'
            : 'bundled';

    final mealAdvice = MealDietitianAdvice.forFood(
      name: name,
      className: primary.className,
      calories: calories,
    );

    return FoodScanResult(
      name: name,
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      ironMg: iron,
      folateMcg: folate,
      safetyStatus:
          chosen.any((it) => it.nutrition.safetyStatus != 'safe') ? 'caution' : 'safe',
      confidence: primary.confidence,
      detectedItems: items,
      selectedClassNames: selected,
      strategy: strategy,
      portionLabel: label,
      alternateLabels: alternates,
      imagePath: imagePath,
      nutritionSource: source,
      isGenericFallback: chosen.any((it) => it.nutrition.isGenericFallback),
      dietitianInsight: mealAdvice.insight,
      dietitianPairing: mealAdvice.pairing,
      dietitianSource: 'rules',
    );
  }

  Map<String, dynamic> _mealPayload(FoodScanResult r) {
    final primary = r.selectedClassNames.isNotEmpty ? r.selectedClassNames.first : null;
    return {
      'eaten_at': DateTime.now().toIso8601String(),
      'name': r.name,
      'calories': r.calories,
      'protein_g': r.proteinG,
      'carbs_g': r.carbsG,
      'fat_g': r.fatG,
      'safety_status': r.safetyStatus,
      'insight_message': r.dietitianInsight,
      'source': 'scan',
      'meta': {
        'iron_mg': r.ironMg,
        'folate_mcg': r.folateMcg,
        'image_path': r.imagePath,
        'model': 'hybrid',
        'strategy': r.strategy,
        'confidence': r.confidence,
        'class_name': primary,
        'selected_items': r.selectedClassNames,
        'detections': [
          for (final d in r.detectedItems)
            {
              'class_name': d.className,
              'display_name': d.displayName,
              'confidence': d.confidence,
              'source': d.source,
            }
        ],
      },
    };
  }
}

class FoodScannerScreen extends ConsumerStatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  ConsumerState<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends ConsumerState<FoodScannerScreen> {
  final Color secondaryBlue = const Color(0xFF5B8C8C);
  final Color softBlue = const Color(0xFFE8F1F2);
  final Color textBlue = const Color(0xFF4A7070);
  final Color slate800 = const Color(0xFF1E293B);
  final Color slate900 = const Color(0xFF0F172A);

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _navigatedToHistoryAfterSave = false;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Camera Error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _openNutritionHistory() {
    if (!mounted) return;
    ref.read(foodScannerProvider.notifier).clearScan();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NutritionHistoryScreen()),
    );
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (!_isCameraInitialized || controller == null) return;
    try {
      final next = !_isFlashOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _isFlashOn = next);
    } catch (e) {
      debugPrint('Flash Error: $e');
    }
  }

  Future<void> _pickFromGalleryAndScan() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;
      if (!mounted) return;
      await ref.read(foodScannerProvider.notifier).scanFood(image: picked);
    } catch (e) {
      debugPrint('Gallery Picker Error: $e');
    }
  }

  Future<void> _captureAndScan() async {
    final controller = _cameraController;
    if (!_isCameraInitialized || controller == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera not ready. Use gallery or try again.'),
        ),
      );
      return;
    }

    try {
      final photo = await controller.takePicture();
      if (!mounted) return;
      await ref.read(foodScannerProvider.notifier).scanFood(image: photo);
    } catch (e) {
      debugPrint('Capture Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(foodScannerProvider);

    ref.listen<AsyncValue<FoodScanResult?>>(foodScannerProvider, (prev, next) {
      if (next.isLoading) {
        _navigatedToHistoryAfterSave = false;
        return;
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      }
      final saved = next.value?.mealSaved == true;
      final wasSaved = prev?.value?.mealSaved == true;
      if (saved && !wasSaved && !_navigatedToHistoryAfterSave) {
        _navigatedToHistoryAfterSave = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openNutritionHistory();
        });
      }
    });

    final result = scanState.valueOrNull;
    final showCaptured =
        result?.imagePath != null && File(result!.imagePath!).existsSync();

    return Scaffold(
      backgroundColor: slate900,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showCaptured)
            Image.file(File(result.imagePath!), fit: BoxFit.cover)
          else if (_isCameraInitialized && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Container(color: slate900),

          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Colors.transparent, Colors.black45],
                stops: [0.3, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopBar(),
                if (scanState.value == null && !scanState.isLoading)
                  Expanded(child: _buildScannerFrame()),
                if (scanState.isLoading)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            'Analyzing…',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (scanState.hasError)
                  Expanded(child: _buildScanError(scanState.error!)),
                if (scanState.value != null && !scanState.isLoading)
                  _buildResultCard(context, ref, scanState.value!),
                _buildBottomControls(scanState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlassButton(Icons.arrow_back_ios_new, () {
            final hasResult = ref.read(foodScannerProvider).value != null;
            if (hasResult) {
              ref.read(foodScannerProvider.notifier).clearScan();
            } else {
              Navigator.pop(context);
            }
          }),
          Column(
            children: [
              Text(
                'AKWAABAFIT AI',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
              Text(
                'Medical Wellness Scanner',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          _buildGlassButton(
            _isFlashOn ? Icons.flash_on : Icons.flash_off,
            _toggleFlash,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            color: Colors.white.withValues(alpha: 0.2),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerFrame() {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            _buildCornerBracket(Alignment.topLeft, top: true, left: true),
            _buildCornerBracket(Alignment.topRight, top: true, left: false),
            _buildCornerBracket(Alignment.bottomLeft, top: false, left: true),
            _buildCornerBracket(Alignment.bottomRight, top: false, left: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerBracket(
    Alignment alignment, {
    required bool top,
    required bool left,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(24) : Radius.zero,
            topRight: top && !left ? const Radius.circular(24) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(24) : Radius.zero,
            bottomRight: !top && !left ? const Radius.circular(24) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildScanError(Object error) {
    final notFood = error is NotFoodScanException;
    final title = notFood
        ? error.title
        : 'Could not scan';
    final detail = notFood
        ? error.detail
        : (error is String
            ? error
            : "This doesn't look like food. Point your camera at a meal on a plate and scan again.");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.no_food_outlined,
                color: Colors.white.withValues(alpha: 0.9),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (notFood) ...[
              const SizedBox(height: 10),
              Text(
                'Tip: hold the phone steady, use daylight if you can, and fill the frame with the plate.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                ref.read(foodScannerProvider.notifier).clearScan();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Scan a meal',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    WidgetRef ref,
    FoodScanResult result,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified, color: secondaryBlue, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'AI VERIFIED ANALYSIS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: secondaryBlue,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.name,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: slate800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result.confidence > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${(result.confidence * 100).toStringAsFixed(0)}% match • ${_strategyLabel(result.strategy)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.blueGrey.shade500,
                          ),
                        ),
                      ],
                      if (result.confidence > 0 &&
                          result.confidence < 0.5) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Colors.amber.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Low confidence — scan again with the meal centered and well lit.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.amber.shade900,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (result.dietitianInsight.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9F4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF1A5D1A).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.spa_outlined,
                                    size: 16,
                                    color: Color(0xFF1A5D1A),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    result.dietitianSource == 'gemini'
                                        ? 'AI DIETITIAN'
                                        : 'DIETITIAN TIP',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1A5D1A),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                result.dietitianInsight,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade800,
                                  height: 1.45,
                                ),
                              ),
                              if (result.dietitianPairing != null &&
                                  result.dietitianPairing!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Pair with: ${result.dietitianPairing}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A5D1A),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (result.isRefiningNutrition) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Updating nutrition from server…',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.blueGrey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (result.detectedItems.length > 1) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: result.detectedItems.map((item) {
                            final selected = result.selectedClassNames
                                .contains(item.className);
                            return FilterChip(
                              selected: selected,
                              label: Text(
                                '${item.displayName} ${(item.confidence * 100).toStringAsFixed(0)}%',
                              ),
                              onSelected: (_) {
                                ref
                                    .read(foodScannerProvider.notifier)
                                    .toggleDetectedItem(item.className);
                              },
                              labelStyle: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : slate800,
                              ),
                              selectedColor: secondaryBlue,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.blueGrey.shade200,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: softBlue, shape: BoxShape.circle),
                  child: Icon(Icons.restaurant, color: secondaryBlue),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    Icons.local_fire_department,
                    'Calories',
                    '${result.calories}',
                    'kcal',
                    textBlue,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    Icons.bloodtype,
                    'Iron',
                    result.ironMg.toStringAsFixed(1),
                    'mg',
                    textBlue,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    Icons.medication,
                    'Folate (B9)',
                    '${result.folateMcg}',
                    'mcg',
                    textBlue,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    Icons.health_and_safety,
                    'Safety',
                    _safetyLabel(result.safetyStatus),
                    '',
                    secondaryBlue,
                    isStatus: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: result.confidence.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.blueGrey.shade100,
                color: secondaryBlue,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: result.mealSaved || result.isRefiningNutrition
                    ? null
                    : () async {
                        await ref
                            .read(foodScannerProvider.notifier)
                            .logCurrentSelection();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: slate900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  result.mealSaved ? 'SAVED' : 'LOG MEAL',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    IconData icon,
    String label,
    String value,
    String unit,
    Color color, {
    bool isStatus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: isStatus ? 16 : 24,
                fontWeight: FontWeight.bold,
                color: isStatus ? color : slate800,
                letterSpacing: -0.5,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBottomControls(AsyncValue<FoodScanResult?> scanState) {
    final isScanning = scanState.isLoading;

    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: 32, right: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: isScanning ? null : _pickFromGalleryAndScan,
          ),
          GestureDetector(
            onTap: isScanning ? null : _captureAndScan,
            child: Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 3,
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(color: slate900, shape: BoxShape.circle),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: isScanning
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileSettingsScreen(),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }

  String _safetyLabel(String status) {
    return switch (status.toLowerCase()) {
      'safe' => 'Bio-Optimal',
      'caution' => 'Watch',
      'moderate' => 'Moderate',
      _ => status,
    };
  }

  String _strategyLabel(String strategy) {
    return switch (strategy) {
      'ghana_classifier' => 'Ghana AI',
      'gemini_flash_fallback' => 'Gemini Flash',
      'ghana_classifier_low_confidence' => 'Ghana AI',
      'hybrid_agreement' => 'Hybrid verified',
      _ => 'Hybrid scan',
    };
  }
}
