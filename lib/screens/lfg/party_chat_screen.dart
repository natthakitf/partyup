import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../models/party_model.dart';
import '../../services/realtime_chat_service.dart';

class PartyChatScreen extends StatefulWidget {
  const PartyChatScreen({
    super.key,
    required this.party,
    required this.firebaseReady,
  });
  final PartyModel party;
  final bool firebaseReady;
  @override
  State<PartyChatScreen> createState() => _PartyChatScreenState();
}

class _PartyChatScreenState extends State<PartyChatScreen> {
  final _input = TextEditingController();
  final _service = RealtimeChatService();
  final List<Map<String, String>> _demo = [
    {'sender': 'mook#TH', 'message': 'หวัดดีทุกคน อีก 10 นาทีพร้อมนะ'},
    {'sender': 'minty', 'message': 'ขอเติมน้ำแป๊บนึงค่า 🎮'},
  ];

  Future<void> _send() async {
    final message = _input.text.trim();
    if (message.isEmpty) return;
    _input.clear();
    if (widget.firebaseReady) {
      try {
        await _service.sendMessage(widget.party.id, 'คุณ', message);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('ส่งข้อความไม่สำเร็จ: $e')));
        }
      }
    } else {
      setState(() => _demo.add({'sender': 'คุณ', 'message': message}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.party.gameName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.party.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF858894)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.firebaseReady
                      ? const Color(0xFFE5F4EC)
                      : const Color(0xFFFFF1DE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.firebaseReady ? 'LIVE' : 'DEMO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: widget.firebaseReady
                        ? const Color(0xFF32835A)
                        : const Color(0xFFB7782B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
            color: isDark ? const Color(0xFF211638) : const Color(0xFFECEAFF),
            child: Text(
              '${widget.party.currentPlayers}/${widget.party.maxPlayers} คน · ${widget.party.requiredRank} · ${widget.party.playTime}',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? const Color(0xFFD8C8FF)
                    : const Color(0xFF5144B7),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: widget.firebaseReady
                ? StreamBuilder<DatabaseEvent>(
                    stream: _service.getChatMessages(widget.party.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('เชื่อมต่อห้องแชทไม่ได้'),
                        );
                      }
                      final value = snapshot.data?.snapshot.value;
                      final messages = <Map<String, String>>[];
                      if (value is Map) {
                        for (final entry in value.values) {
                          if (entry is Map) {
                            messages.add({
                              'sender': entry['sender']?.toString() ?? 'Player',
                              'message': entry['message']?.toString() ?? '',
                            });
                          }
                        }
                      }
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'เริ่มทักทายเพื่อนในทีมได้เลย 👋',
                            style: TextStyle(color: Color(0xFF858894)),
                          ),
                        );
                      }
                      return _messageList(messages);
                    },
                  )
                : _messageList(_demo),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      autocorrect: true,
                      enableSuggestions: true,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: 'ส่งข้อความนัดหมาย...',
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xD9161B26)
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList(List<Map<String, String>> messages) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: messages.length,
    itemBuilder: (context, index) {
      final message = messages[index];
      final mine = message['sender'] == 'คุณ';
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  )
                : null,
            color: mine
                ? null
                : Theme.of(context).brightness == Brightness.dark
                ? const Color(0xD9161B26)
                : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: mine ? const Color(0x667C3AED) : const Color(0x18FFFFFF),
            ),
            boxShadow: mine
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: .22),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    message['sender'] ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                message['message'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: mine
                      ? Colors.white
                      : Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF5F5F7)
                      : const Color(0xFF191A22),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }
}
