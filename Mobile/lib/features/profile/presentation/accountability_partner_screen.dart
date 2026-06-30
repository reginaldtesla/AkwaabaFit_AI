import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AccountabilityPartnerScreen extends StatefulWidget {
  const AccountabilityPartnerScreen({super.key});

  @override
  State<AccountabilityPartnerScreen> createState() =>
      _AccountabilityPartnerScreenState();
}

class _AccountabilityPartnerScreenState extends State<AccountabilityPartnerScreen> {
  final _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  final _storage = const FlutterSecureStorage();
  final _codeController = TextEditingController();

  String? _myCode;
  String? _partnerName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'sanctum_token');
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(
        '/accountability',
        options: Options(headers: await _headers()),
      );
      final data = res.data;
      if (data is Map) {
        _myCode = data['code']?.toString();
        final partner = data['partner'];
        if (partner is Map) {
          _partnerName = partner['name']?.toString();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _link() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    try {
      await _dio.post(
        '/accountability/link',
        data: {'partner_code': code},
        options: Options(headers: await _headers()),
      );
      _codeController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accountability partner linked')),
        );
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['message'] ?? 'Could not link').toString()
          : 'Could not link';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _unlink() async {
    await _dio.delete(
      '/accountability/partner',
      options: Options(headers: await _headers()),
    );
    setState(() => _partnerName = null);
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1A5D1A);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Accountability partner',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Share your code with family or a friend. You keep each other honest on meals, steps, and water.',
                  style: GoogleFonts.inter(color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 20),
                if (_myCode != null) ...[
                  Text('Your code', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _myCode!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _myCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                if (_partnerName != null) ...[
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.people)),
                    title: Text(_partnerName!),
                    subtitle: const Text('Linked partner'),
                    trailing: TextButton(onPressed: _unlink, child: const Text('Unlink')),
                  ),
                ] else ...[
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: "Partner's code",
                      hintText: 'Enter their 6-character code',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _link,
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('LINK PARTNER'),
                  ),
                ],
              ],
            ),
    );
  }
}
