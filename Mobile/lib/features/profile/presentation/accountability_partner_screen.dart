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
  final _storage = const FlutterSecureStorage();
  final _codeController = TextEditingController();

  String? _myCode;
  String? _partnerName;
  String? _loadError;
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

  Dio _client(String token) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl
        : '${AppConfig.apiBaseUrl}/';
    return Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          ...AppConfig.apiHeaders,
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  String _messageFromDio(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      return (data['message'] ?? fallback).toString();
    }
    return fallback;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Please sign in again to load your code.';
        });
      }
      return;
    }

    try {
      final res = await _client(token).get('accountability');
      final data = res.data;
      if (data is Map) {
        final map = data.map((k, v) => MapEntry(k.toString(), v));
        _myCode = map['code']?.toString();
        final partner = map['partner'];
        _partnerName = partner is Map ? partner['name']?.toString() : null;
      }
      if (_myCode == null || _myCode!.isEmpty) {
        _loadError = 'Could not load your code. Pull down or tap Retry.';
      }
    } on DioException catch (e) {
      _loadError = _messageFromDio(e, 'Could not load your code.');
    } catch (_) {
      _loadError = 'Could not load your code.';
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _link() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return;

    try {
      await _client(token).post(
        'accountability/link',
        data: {'partner_code': code},
      );
      _codeController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accountability partner linked')),
        );
      }
    } on DioException catch (e) {
      final msg = _messageFromDio(e, 'Could not link');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _unlink() async {
    final token = await _storage.read(key: 'sanctum_token');
    if (token == null || token.isEmpty) return;

    try {
      await _client(token).delete('accountability/partner');
      if (mounted) setState(() => _partnerName = null);
    } on DioException catch (e) {
      final msg = _messageFromDio(e, 'Could not unlink');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Share your code with family or a friend. You keep each other honest on meals, steps, and water.',
                    style: GoogleFonts.inter(color: Colors.blueGrey.shade700),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your code',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_myCode != null && _myCode!.isNotEmpty) ...[
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
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loadError ?? 'Your code is not available yet.',
                            style: GoogleFonts.inter(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_partnerName != null) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.people)),
                      title: Text(_partnerName!),
                      subtitle: const Text('Linked partner'),
                      trailing: TextButton(
                        onPressed: _unlink,
                        child: const Text('Unlink'),
                      ),
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
      ),
    );
  }
}
