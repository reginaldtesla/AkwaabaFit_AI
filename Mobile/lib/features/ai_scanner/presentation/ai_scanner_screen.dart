import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

// =====================================================================
// 1. STATE MANAGEMENT & MOCK AI LOGIC
// =====================================================================

class AiScanResult {
  final String name;
  final int calories;
  final double ironMg;
  final int folateMcg;
  final String safetyStatus;

  AiScanResult({
    required this.name,
    required this.calories,
    required this.ironMg,
    required this.folateMcg,
    required this.safetyStatus,
  });
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
      // TODO: In production, use [image] (or captured camera image) and send to Laravel / or run TFLite offline.
      await Future.delayed(const Duration(seconds: 2));

      state = AsyncValue.data(
        AiScanResult(
          name: 'Grilled Salmon Salad',
          calories: 482,
          ironMg: 4.2,
          folateMcg: 112,
          safetyStatus: 'Bio-Optimal',
        ),
      );
    } catch (e) {
      state = AsyncValue.error('Failed to analyze image.', StackTrace.current);
    }
  }

  void clearScan() {
    state = const AsyncValue.data(null);
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

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(aiScannerProvider);

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
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),

                // AI Result Card
                if (scanState.value != null && !scanState.isLoading)
                  _buildResultCard(scanState.value!),

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

  Widget _buildResultCard(AiScanResult result) {
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Meal logged successfully!')),
                      );
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
                      'LOG MEAL',
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
                ref.read(aiScannerProvider.notifier).scanFood();
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

