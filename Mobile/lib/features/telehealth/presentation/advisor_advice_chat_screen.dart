import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/telehealth/data/tele_dietetics_api.dart';
import 'package:mobile/features/telehealth/presentation/consultation_session_ui.dart';

class AdvisorAdviceChatScreen extends StatefulWidget {
  const AdvisorAdviceChatScreen({
    super.key,
    required this.consultationId,
    required this.clientName,
    required this.professionalName,
  });

  final int consultationId;
  final String clientName;
  final String professionalName;

  @override
  State<AdvisorAdviceChatScreen> createState() => _AdvisorAdviceChatScreenState();
}

class _AdvisorAdviceChatScreenState extends State<AdvisorAdviceChatScreen> {
  final _api = TeleDieteticsApi();
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  List<AdviceChatMessage> _messages = const [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _sending = false;
  bool _hasMore = false;
  bool _peerTyping = false;
  Timer? _poll;
  Timer? _deltaPoll;
  Timer? _tick;
  Timer? _typingDebounce;
  DateTime? _expiresAt;
  DateTime? _startsAt;
  String _phase = 'unpaid';
  DateTime _serverNow = DateTime.now();
  bool _active = false;
  bool _sessionLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
    _deltaPoll = Timer.periodic(const Duration(seconds: 2), (_) => _deltaSync());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _serverNow = _serverNow.add(const Duration(seconds: 1)));
      if (_phase == 'waiting' &&
          ConsultationSessionUi.untilStart(_startsAt, _serverNow) == Duration.zero) {
        unawaited(_load(silent: true));
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _deltaPoll?.cancel();
    _tick?.cancel();
    _typingDebounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    final before = _messages.first.id;
    try {
      final res = await _api.fetchAdvisorMessages(
        consultationId: widget.consultationId,
        beforeId: before,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        final existing = _messages.map((m) => m.id).toSet();
        final older = res.messages.where((m) => !existing.contains(m.id)).toList();
        _messages = [...older, ..._messages];
        _hasMore = res.hasMore;
        _peerTyping = res.peerTyping;
        _loadingOlder = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _deltaSync() async {
    if (_messages.isEmpty) return;
    final lastId = _messages.map((m) => m.id).reduce((a, b) => a > b ? a : b);
    if (lastId < 1) return;
    try {
      final d = await _api.fetchAdvisorMessagesDelta(consultationId: widget.consultationId, afterId: lastId);
      if (!mounted) return;
      setState(() {
        _peerTyping = d.peerTyping;
        _serverNow = d.serverNow;
        if (d.messages.isNotEmpty) {
          final ids = _messages.map((m) => m.id).toSet();
          _messages = [..._messages, ...d.messages.where((m) => !ids.contains(m.id))];
        }
      });
      unawaited(Future<void>.delayed(const Duration(milliseconds: 40), () {
        if (!_scroll.hasClients || !mounted) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }));
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await _api.fetchAdvisorMessages(consultationId: widget.consultationId);
      if (!mounted) return;
      setState(() {
        _messages = res.messages;
        _hasMore = res.hasMore;
        _peerTyping = res.peerTyping;
        _applySession(res);
        _loading = false;
        _sessionLoaded = true;
      });
      // Scroll to bottom after load.
      // ignore: discarded_futures
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applySession(AdviceChatFetch res) {
    _expiresAt = res.expiresAt;
    _startsAt = res.startsAt;
    _phase = res.phase;
    _active = res.active;
    _serverNow = res.serverNow;
  }

  ({
    String appBarSubtitle,
    String bannerText,
    Color bannerBg,
    Color bannerFg,
    bool canChat,
  })
      get _sessionUi =>
          ConsultationSessionUi.state(
            phase: _phase,
            startsAt: _startsAt,
            expiresAt: _expiresAt,
            serverNow: _serverNow,
            active: _active,
          );

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (!_sessionUi.canChat) return;
    try {
      setState(() => _sending = true);
      _controller.clear();
      await _api.sendAdvisorMessage(consultationId: widget.consultationId, body: text);
      await _load(silent: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF8FAFC);
    final surface = Colors.white;
    final textMain = const Color(0xFF0F172A);
    final muted = const Color(0xFF64748B);
    final primary = const Color(0xFF0FBD74);
    final ui = _sessionUi;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: textMain,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clientName,
              style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              _sessionLoaded ? ui.appBarSubtitle : 'Loading…',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_peerTyping)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: const Color(0xFFF1F5F9),
              child: Text(
                '${widget.clientName.isNotEmpty ? widget.clientName.split(' ').first : 'Client'} is typing…',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (_sessionLoaded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              color: ui.bannerBg,
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: ui.bannerFg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ui.bannerText,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ui.bannerFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_hasMore && i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Center(
                            child: TextButton(
                              onPressed: _loadingOlder ? null : _loadOlder,
                              child: _loadingOlder
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Load older messages'),
                            ),
                          ),
                        );
                      }
                      final idx = _hasMore ? i - 1 : i;
                      final m = _messages[idx];
                      final fromUser = m.fromUser;
                      final align = fromUser ? Alignment.centerLeft : Alignment.centerRight;
                      final color = fromUser ? Colors.white : primary.withValues(alpha: 0.10);
                      final border = fromUser ? const Color(0xFFE2E8F0) : primary.withValues(alpha: 0.30);
                      final isAdvisor = !fromUser;
                      return Align(
                        alignment: align,
                        child: Column(
                          crossAxisAlignment:
                              isAdvisor ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              constraints: const BoxConstraints(maxWidth: 320),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: Text(
                                m.body,
                                style: GoogleFonts.spaceGrotesk(color: textMain, fontSize: 14),
                              ),
                            ),
                            if (isAdvisor && m.readAt != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4, bottom: 2),
                                child: Text(
                                  'Read',
                                  style: GoogleFonts.spaceGrotesk(fontSize: 11, color: muted),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: ui.canChat && !_sending,
                      onChanged: (_) {
                        if (!ui.canChat || _sending) return;
                        _typingDebounce?.cancel();
                        _typingDebounce = Timer(const Duration(milliseconds: 450), () {
                          unawaited(
                            _api.sendAdvisorTypingPing(consultationId: widget.consultationId),
                          );
                        });
                      },
                      decoration: InputDecoration(
                        hintText: ui.canChat
                            ? 'Type a reply…'
                            : (_phase == 'waiting'
                                ? 'Session has not started yet'
                                : 'Session inactive'),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: (!ui.canChat || _sending) ? null : _send,
                    icon: Icon(Icons.send, color: (ui.canChat && !_sending) ? primary : muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

