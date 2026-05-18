import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/telehealth/data/tele_dietetics_api.dart';
import 'package:mobile/features/telehealth/presentation/advisor_advice_chat_screen.dart';

class AdvisorAdviceInboxScreen extends StatefulWidget {
  const AdvisorAdviceInboxScreen({super.key});

  @override
  State<AdvisorAdviceInboxScreen> createState() => _AdvisorAdviceInboxScreenState();
}

class _AdvisorAdviceInboxScreenState extends State<AdvisorAdviceInboxScreen> {
  final _api = TeleDieteticsApi();
  bool _loading = true;
  List<({int id, int userId, String clientName, String professionalName, String paymentStatus, DateTime? expiresAt})>
      _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _api.listAdvisorConsultations();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF8FAFC);
    final textMain = const Color(0xFF0F172A);
    final muted = const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: textMain,
        elevation: 0,
        title: Text(
          'Advisor inbox',
          style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'No sessions yet.',
                    style: GoogleFonts.spaceGrotesk(color: muted, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    final active = it.paymentStatus == 'paid';
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      title: Text(
                        it.clientName,
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: textMain),
                      ),
                      subtitle: Text(
                        active
                            ? 'Session #${it.id} • Paid • Tap to reply'
                            : 'Session #${it.id} • ${it.paymentStatus}',
                        style: GoogleFonts.spaceGrotesk(color: muted),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdvisorAdviceChatScreen(
                              consultationId: it.id,
                              clientName: it.clientName,
                              professionalName: it.professionalName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

