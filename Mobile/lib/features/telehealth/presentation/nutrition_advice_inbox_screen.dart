import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/telehealth/data/tele_dietetics_api.dart';
import 'package:mobile/features/telehealth/presentation/nutrition_advice_chat_screen.dart';

class NutritionAdviceInboxScreen extends StatefulWidget {
  const NutritionAdviceInboxScreen({super.key});

  @override
  State<NutritionAdviceInboxScreen> createState() =>
      _NutritionAdviceInboxScreenState();
}

class _NutritionAdviceInboxScreenState extends State<NutritionAdviceInboxScreen> {
  final _api = TeleDieteticsApi();
  bool _loading = true;
  List<({int id, int advisorUserId, String professionalName, DateTime? scheduledAt, String paymentStatus})>
      _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    try {
      final list = await _api.listMyConsultations();
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
          'My advice sessions',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0FBD74),
        onRefresh: () => _load(showSpinner: false),
        child: _loading
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  );
                },
              )
            : _items.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: Center(
                            child: Text(
                              'No paid advice sessions yet.\nPull down to refresh.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(color: muted, fontSize: 15),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final it = _items[i];
                      final paid = it.paymentStatus == 'paid';
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        title: Text(
                          it.professionalName,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            color: textMain,
                          ),
                        ),
                        subtitle: Text(
                          paid ? 'Paid • Tap to chat' : 'Pending payment',
                          style: GoogleFonts.spaceGrotesk(color: muted),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: !paid
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => NutritionAdviceChatScreen(
                                      consultationId: it.id,
                                      professionalName: it.professionalName,
                                      advisorUserId: it.advisorUserId,
                                    ),
                                  ),
                                );
                              },
                      );
                    },
                  ),
      ),
    );
  }
}

