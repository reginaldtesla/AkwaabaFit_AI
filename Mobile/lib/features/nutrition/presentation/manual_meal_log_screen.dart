import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/nutrition/nutrition_refresh.dart';
import 'package:mobile/shared/nutrition/nutrition_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ManualMealLogScreen extends ConsumerStatefulWidget {
  const ManualMealLogScreen({super.key});

  @override
  ConsumerState<ManualMealLogScreen> createState() =>
      _ManualMealLogScreenState();
}

class _ManualMealLogScreenState extends ConsumerState<ManualMealLogScreen> {
  final _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  final _storage = const FlutterSecureStorage();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _recent = [];
  bool _loading = false;
  bool _saving = false;

  String _portion = 'regular';
  String _mealSource = 'chop_bar';
  String? _selectedClass;
  String? _selectedName;
  int _calories = 0;
  int _protein = 0;
  int _carbs = 0;
  int _fat = 0;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'sanctum_token');
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _loadRecent() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(
        '/nutrition/recent',
        options: Options(headers: await _authHeaders()),
      );
      final meals = res.data['meals'];
      if (meals is List) {
        _recent = meals.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final prep = _mealSource == 'home_cooked' ? 'home_cooked' : 'chop_bar';
      final res = await _dio.get(
        '/nutrition/foods/search',
        queryParameters: {'q': q, 'preparation': prep},
        options: Options(headers: await _authHeaders()),
      );
      final foods = res.data['foods'];
      if (foods is List) {
        _results = foods.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _selectFood(Map<String, dynamic> food) {
    setState(() {
      _selectedClass = food['className']?.toString();
      _selectedName = food['displayName']?.toString() ?? food['className']?.toString();
      _calories = _int(food['calories']);
      _protein = _int(food['proteinG']);
      _carbs = _int(food['carbsG']);
      _fat = _int(food['fatG']);
      _searchController.text = _selectedName ?? '';
      _results = [];
    });
  }

  void _selectRecent(Map<String, dynamic> meal) {
    setState(() {
      _selectedName = meal['name']?.toString();
      _calories = _int(meal['calories']);
      _protein = _int(meal['proteinG']);
      _carbs = _int(meal['carbsG']);
      _fat = _int(meal['fatG']);
      _portion = meal['portionSize']?.toString() ?? 'regular';
      _mealSource = meal['mealSource']?.toString() ?? 'chop_bar';
      final meta = meal['meta'];
      if (meta is Map) {
        _selectedClass = meta['class_name']?.toString() ?? meta['className']?.toString();
      }
      _searchController.text = _selectedName ?? '';
    });
  }

  Future<void> _save() async {
    final name = (_selectedName ?? _searchController.text).trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(nutritionRepositoryProvider).logMeal({
        'eaten_at': DateTime.now().toIso8601String(),
        'name': name,
        'calories': _calories,
        'protein_g': _protein,
        'carbs_g': _carbs,
        'fat_g': _fat,
        'source': 'manual',
        'portion_size': _portion,
        'meal_source': _mealSource,
        if (_selectedClass != null)
          'meta': {'class_name': _selectedClass},
      });
      ref.read(nutritionDashboardRefreshProvider.notifier).state++;
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal logged')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not log meal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1A5D1A);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Log meal manually',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Ghanaian dishes',
              hintText: 'banku, waakye, jollof…',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _search(_searchController.text),
              ),
            ),
            onSubmitted: _search,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _chip('Chop bar', _mealSource == 'chop_bar', () {
                setState(() => _mealSource = 'chop_bar');
              }),
              _chip('Home-cooked', _mealSource == 'home_cooked', () {
                setState(() => _mealSource = 'home_cooked');
              }),
            ],
          ),
          const SizedBox(height: 12),
          Text('Portion', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'small', label: Text('Small')),
              ButtonSegment(value: 'regular', label: Text('Regular')),
              ButtonSegment(value: 'large', label: Text('Large')),
            ],
            selected: {_portion},
            onSelectionChanged: (s) => setState(() => _portion = s.first),
          ),
          if (_loading) const LinearProgressIndicator(),
          ..._results.map((f) => ListTile(
                title: Text(f['displayName']?.toString() ?? ''),
                subtitle: Text('${_int(f['calories'])} kcal'),
                onTap: () => _selectFood(f),
              )),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Log again', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ..._recent.map((m) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(m['name']?.toString() ?? ''),
                  subtitle: Text('${_int(m['calories'])} kcal'),
                  onTap: () => _selectRecent(m),
                )),
          ],
          if (_selectedName != null) ...[
            const SizedBox(height: 16),
            Text(
              '$_selectedName · $_calories kcal · P $_protein g',
              style: GoogleFonts.inter(color: Colors.blueGrey.shade700),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: green,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('LOG MEAL'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
