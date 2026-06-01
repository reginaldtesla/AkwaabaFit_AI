import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/ai_scanner/data/food_detector_provider.dart';
import 'package:mobile/features/ai_scanner/data/food_nutrition_info.dart';
import 'package:mobile/features/ai_scanner/data/hybrid_nutrition_provider.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/shared/nutrition/meal_macro_row.dart';
import 'package:mobile/shared/nutrition/nutrition_repository.dart';

// =====================================================================
// 1. STATE MANAGEMENT — offline v1 YOLO (ONNX on device)
// =====================================================================

class AiScanResult {
  final String name;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final double ironMg;
  final int folateMcg;
  final String safetyStatus;
  final double confidence;
  final List<String> alternateLabels;
  final String? insightMessage;

  /// bundled | cache | server
  final String nutritionSource;
  final String portionLabel;
  final bool isGenericFallback;
  final bool isRefiningNutrition;

  /// Multi-food plates: candidate detections + selected items.
  /// `className` values match `food_labels.json` entries.
  final List<AiDetectedFoodItem> detectedItems;
  final List<String> selectedClassNames;

  /// Original image path (camera/gallery) for logging.
  final String? imagePath;

  /// Set after [NutritionRepository.logMeal] succeeds (triggers history navigation).
  final bool mealSaved;

  AiScanResult({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.ironMg,
    required this.folateMcg,
    required this.safetyStatus,
    this.confidence = 0,
    this.alternateLabels = const [],
    this.insightMessage,
    this.nutritionSource = 'bundled',
    this.portionLabel = '1 serving',
    this.isGenericFallback = false,
    this.isRefiningNutrition = false,
    this.detectedItems = const [],
    this.selectedClassNames = const [],
    this.imagePath,
    this.mealSaved = false,
  });

  AiScanResult copyWith({
    String? name,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    double? ironMg,
    int? folateMcg,
    String? safetyStatus,
    String? insightMessage,
    String? nutritionSource,
    String? portionLabel,
    bool? isGenericFallback,
    bool? isRefiningNutrition,
    List<AiDetectedFoodItem>? detectedItems,
    List<String>? selectedClassNames,
    String? imagePath,
    bool? mealSaved,
  }) {
    return AiScanResult(
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      ironMg: ironMg ?? this.ironMg,
      folateMcg: folateMcg ?? this.folateMcg,
      safetyStatus: safetyStatus ?? this.safetyStatus,
      confidence: confidence,
      alternateLabels: alternateLabels,
      insightMessage: insightMessage ?? this.insightMessage,
      nutritionSource: nutritionSource ?? this.nutritionSource,
      portionLabel: portionLabel ?? this.portionLabel,
      isGenericFallback: isGenericFallback ?? this.isGenericFallback,
      isRefiningNutrition: isRefiningNutrition ?? this.isRefiningNutrition,
      detectedItems: detectedItems ?? this.detectedItems,
      selectedClassNames: selectedClassNames ?? this.selectedClassNames,
      imagePath: imagePath ?? this.imagePath,
      mealSaved: mealSaved ?? this.mealSaved,
    );
  }
}

class AiDetectedFoodItem {
  const AiDetectedFoodItem({
    required this.className,
    required this.displayName,
    required this.confidence,
    required this.nutrition,
  });

  final String className;
  final String displayName;
  final double confidence;
  final FoodNutritionInfo nutrition;
}

final aiScannerProvider =
    AsyncNotifierProvider<AiScannerNotifier, AiScanResult?>(
      AiScannerNotifier.new,
    );

class AiScannerNotifier extends AsyncNotifier<AiScanResult?> {
  @override
  Future<AiScanResult?> build() async {
    return null; // Null means no scan result yet (show viewfinder)
  }

  Future<void> scanFood({XFile? image}) async {
    state = const AsyncValue.loading();
    try {
      if (image == null || image.path.isEmpty) {
        throw StateError('No image to scan. Take a photo or pick from gallery.');
      }

      final detector = await ref.read(foodDetectorProvider.future);
      final detections = await detector.detectFromFile(image.path);

      if (detections.isEmpty) {
        throw StateError(
          'No food detected. Try better lighting and center the plate in the frame.',
        );
      }

      final hybrid = await ref.read(hybridNutritionProvider.future);

      // Resolve nutrition for the top few detections so multi-food plates can be selected.
      final topDetections = detections.take(5).toList(growable: false);
      final items = <AiDetectedFoodItem>[];
      for (final d in topDetections) {
        final nutrition = await hybrid.resolve(d.className);
        items.add(
          AiDetectedFoodItem(
            className: d.className,
            displayName: nutrition.displayName,
            confidence: d.confidence,
            nutrition: nutrition,
          ),
        );
      }

      // Default selection: top-1 detection.
      final selected = <String>[topDetections.first.className];
      final result = _aggregateFromSelected(
        items: items,
        selectedClassNames: selected,
        imagePath: image.path,
      );

      state = AsyncValue.data(result);

      // Best-effort: refresh nutrition for the selected top class when online (does not log yet).
      state = AsyncValue.data(result.copyWith(isRefiningNutrition: true));
      final refreshed = await hybrid.refreshFromServer(selected.first);
      if (refreshed != null) {
        final nextItems = items
            .map((it) => it.className == selected.first
                ? AiDetectedFoodItem(
                    className: it.className,
                    displayName: refreshed.displayName,
                    confidence: it.confidence,
                    nutrition: refreshed,
                  )
                : it)
            .toList(growable: false);
        state = AsyncValue.data(
          _aggregateFromSelected(
            items: nextItems,
            selectedClassNames: selected,
            imagePath: image.path,
          ).copyWith(isRefiningNutrition: false),
        );
      } else {
        state = AsyncValue.data(result.copyWith(isRefiningNutrition: false));
      }
    } catch (e, st) {
      final raw = e.toString();
      final message = e is StateError
          ? e.message
          : raw.contains('Opset') || raw.contains('onnxruntime')
              ? 'Food scanner model failed to load. Stop the app, run flutter clean, then flutter run again. If it persists, reinstall the app.'
              : 'Failed to analyze image. $raw';
      state = AsyncValue.error(message, st);
    }
  }

  void toggleDetectedItem(String className) {
    final current = state.valueOrNull;
    if (current == null) return;
    final items = current.detectedItems;
    if (items.isEmpty) return;

    final selected = [...current.selectedClassNames];
    if (selected.contains(className)) {
      // Keep at least one item selected.
      if (selected.length <= 1) return;
      selected.remove(className);
    } else {
      selected.add(className);
    }

    state = AsyncValue.data(
      _aggregateFromSelected(
        items: items,
        selectedClassNames: selected,
        imagePath: current.imagePath,
      ).copyWith(
        isRefiningNutrition: current.isRefiningNutrition,
      ),
    );
  }

  Future<void> logCurrentSelection() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.mealSaved) return;
    final imagePath = current.imagePath;
    if (imagePath == null || imagePath.isEmpty) {
      throw StateError('Missing image for this scan. Please scan again.');
    }

    state = AsyncValue.data(current.copyWith(isRefiningNutrition: true));
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final payload = _mealPayloadFromAggregate(current);
      await repo.logMeal(payload);
      ref.invalidate(nutritionHistoryProvider);
      state = AsyncValue.data(current.copyWith(mealSaved: true, isRefiningNutrition: false));
    } catch (e, st) {
      state = AsyncValue.error('Could not log meal. ${e.toString()}', st);
    }
  }

  void clearScan() {
    state = const AsyncValue.data(null);
  }

  AiScanResult _aggregateFromSelected({
    required List<AiDetectedFoodItem> items,
    required List<String> selectedClassNames,
    required String? imagePath,
  }) {
    final selected = items
        .where((it) => selectedClassNames.contains(it.className))
        .toList(growable: false);
    final primary = selected.isNotEmpty ? selected.first : items.first;

    final calories = selected.fold<int>(0, (s, it) => s + it.nutrition.calories);
    final protein = selected.fold<int>(0, (s, it) => s + it.nutrition.proteinG);
    final carbs = selected.fold<int>(0, (s, it) => s + it.nutrition.carbsG);
    final fat = selected.fold<int>(0, (s, it) => s + it.nutrition.fatG);
    final iron = selected.fold<double>(0, (s, it) => s + it.nutrition.ironMg);
    final folate = selected.fold<int>(0, (s, it) => s + it.nutrition.folateMcg);

    final anyCaution = selected.any((it) => it.nutrition.safetyStatus != 'safe');
    final safety = anyCaution ? 'caution' : 'safe';

    final source = selected.any((it) => it.nutrition.source == 'server')
        ? 'server'
        : selected.any((it) => it.nutrition.source == 'cache')
            ? 'cache'
            : 'bundled';

    final label = selected.length <= 1
        ? primary.nutrition.portionLabel
        : '1 plate (multi‑item)';

    final name = selected.length <= 1
        ? primary.displayName
        : selected.map((e) => e.displayName).take(3).join(' + ') +
            (selected.length > 3 ? ' + more' : '');

    // Alternates: show other detections not selected.
    final alternates = items
        .where((it) => !selectedClassNames.contains(it.className))
        .take(3)
        .map((it) => it.displayName)
        .toList(growable: false);

    return AiScanResult(
      name: name,
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      ironMg: iron,
      folateMcg: folate,
      safetyStatus: safety,
      insightMessage: primary.nutrition.insightMessage,
      nutritionSource: source,
      portionLabel: label,
      isGenericFallback: selected.any((it) => it.nutrition.isGenericFallback),
      confidence: primary.confidence,
      alternateLabels: alternates,
      detectedItems: items,
      selectedClassNames: selectedClassNames,
      imagePath: imagePath,
    );
  }

  Map<String, dynamic> _mealPayloadFromAggregate(AiScanResult result) {
    final selected = result.selectedClassNames;
    final detected = result.detectedItems;
    final primary = selected.isNotEmpty ? selected.first : null;
    final primaryIndex = detected.indexWhere((d) => d.className == primary);

    return {
      'eaten_at': DateTime.now().toIso8601String(),
      'meal_type': null,
      'name': result.name,
      'calories': result.calories,
      'protein_g': result.proteinG,
      'carbs_g': result.carbsG,
      'fat_g': result.fatG,
      'safety_status': result.safetyStatus,
      'insight_message': null,
      'image_url': null,
      'source': 'scan',
      'meta': {
        'iron_mg': result.ironMg,
        'folate_mcg': result.folateMcg,
        'image_path': result.imagePath,
        'model': 'food_v1_onnx',
        'confidence': result.confidence,
        'class_id': primaryIndex >= 0 ? primaryIndex : null,
        'class_name': primary,
        'alternates': result.alternateLabels,
        'nutrition_source': result.nutritionSource,
        'portion_label': result.portionLabel,
        'is_generic_fallback': result.isGenericFallback,
        'selected_items': selected,
        'detections': [
          for (final d in detected)
            {
              'class_name': d.className,
              'display_name': d.displayName,
              'confidence': d.confidence,
            }
        ],
      },
    };
  }
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class AiScannerScreen extends ConsumerStatefulWidget {
  const AiScannerScreen({super.key});

  @override
  ConsumerState<AiScannerScreen> createState() => _AiScannerScreenState();
}

class _AiScannerScreenState extends ConsumerState<AiScannerScreen> {
  // Brand Colors
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

  void _openNutritionHistory() {
    if (!mounted) return;
    ref.read(aiScannerProvider.notifier).clearScan();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NutritionHistoryScreen()),
    );
  }

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
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;

      if (!mounted) return;
      await ref.read(aiScannerProvider.notifier).scanFood(image: picked);
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
      final XFile photo = await controller.takePicture();
      if (!mounted) return;
      await ref.read(aiScannerProvider.notifier).scanFood(image: photo);
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
    final scanState = ref.watch(aiScannerProvider);

    ref.listen<AsyncValue<AiScanResult?>>(aiScannerProvider, (prev, next) {
      if (next.isLoading) {
        _navigatedToHistoryAfterSave = false;
        return;
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

    return Scaffold(
      backgroundColor: slate900,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview or Fallback Background
          if (_isCameraInitialized && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAg10oy6GsR8NUgESRekc6aWMe6TPN0YMpsEsXbZrbe1s_GtL1I7JaZXKQ8bvbVya3xUIxVxNTpF2BSlKcL5NveABbZ5pzbue6EAz92u9JC11gdgJ8ibpD-BxUjDrSoA7KHHbgQJyR3gOXUtUVPG_eQ8cW8trH6f7D30GgVGpUXe5KR-x07QCvISjO5UEDSwoBVCIP3KlzV_7D7Q8T9s3SVQQyjhhBKVudOhTcZQJrDQdFu1bFQhMqMt9yHWTjDgag20TPdeDuuevOb',
              fit: BoxFit.cover,
            ),

          // 2. Vignette Gradient Overlay
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

          // 3. UI Elements
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTopBar(),

                // Viewfinder Frame (Hidden if showing result)
                if (scanState.value == null && !scanState.isLoading)
                  Expanded(child: _buildScannerFrame()),

                // Loading Spinner
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Center(
                        child: Text(
                          scanState.error.toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                // AI Result Card
                if (scanState.value != null && !scanState.isLoading)
                  _buildResultCard(context, ref, scanState.value!),

                // Bottom Capture Controls
                _buildBottomControls(scanState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlassButton(Icons.arrow_back_ios_new, () {
            final hasResult = ref.read(aiScannerProvider).value != null;
            if (hasResult) {
              ref.read(aiScannerProvider.notifier).clearScan();
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
            color: Colors.white.withOpacity(0.2),
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
                      color: Colors.white.withOpacity(0.5),
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

  Widget _buildResultCard(
    BuildContext context,
    WidgetRef ref,
    AiScanResult result,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50.withOpacity(0.5),
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
                          Icon(Icons.camera_alt, color: secondaryBlue, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'AI FOOD DETECTION',
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result.confidence > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${(result.confidence * 100).toStringAsFixed(0)}% match • Per ${result.portionLabel}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.blueGrey.shade500,
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
                      const SizedBox(height: 8),
                      MealMacroRow(
                        proteinG: result.proteinG,
                        carbsG: result.carbsG,
                        fatG: result.fatG,
                        fontSize: 13,
                      ),
                      if (result.detectedItems.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Detected items (tap to include)',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                                    .read(aiScannerProvider.notifier)
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
                      if (result.alternateLabels.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Also: ${result.alternateLabels.join(', ')}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.blueGrey.shade400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

          // Stats Grid
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
                    '${result.ironMg}',
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
                    result.safetyStatus,
                    '',
                    secondaryBlue,
                    isStatus: true,
                  ),
                ),
              ],
            ),
          ),

          // Progress Bar
          Padding(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.75,
                minHeight: 4,
                backgroundColor: Colors.blueGrey.shade100,
                color: secondaryBlue,
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(aiScannerProvider.notifier).logCurrentSelection();
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
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade100,
                      foregroundColor: Colors.blueGrey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.share),
                  ),
                ),
              ],
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
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBottomControls(AsyncValue<AiScanResult?> scanState) {
    final bool isScanning = scanState.isLoading;

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
            onTap: () {
              if (!isScanning) {
                _captureAndScan();
              }
            },
            child: Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
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
                          color: Colors.white.withOpacity(0.2),
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
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

