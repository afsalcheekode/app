import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'common.dart';
import 'data_store.dart';
import 'notification_service.dart';

class DirectChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerDept;
  final Color peerColor;
  final String myId;
  final String myName;
  final VoidCallback onBack;

  const DirectChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerDept,
    required this.peerColor,
    required this.myId,
    required this.myName,
    required this.onBack,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _chatMsgCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  bool _chatEmojiOpen = false;

  final Map<String, List<String>> _emojiGroups = {
    'smilies': ['😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭'],
    'hands': ['👋', '🤚', '🖐', '✋', '🖖', '👌', '🤏', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏'],
  };

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh for incoming messages
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        // DataStore.checkForNewAndNotify(widget.myId);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _chatMsgCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  String _getRoomId() {
    if (widget.peerId.contains('class_group')) return widget.peerId;
    final pair = [widget.myId, widget.peerId];
    pair.sort();
    return pair.join('::');
  }

  @override
  Widget build(BuildContext context) {
    final roomId = _getRoomId();
    final messages = DataStore.allMessages
        .where((m) => m['convKey'] == roomId)
        .toList()
      ..sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: widget.peerColor,
              radius: 18,
              child: Text(widget.peerName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(widget.peerDept, style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _chatScrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final isMe = m['senderId'] == widget.myId;
                return _buildMessageBubble(m, isMe);
              },
            ),
          ),
          if (_chatEmojiOpen) _buildEmojiPanel(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> m, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(m['text'] ?? '', style: const TextStyle(fontSize: 15, color: Color(0xFF303030))),
            const SizedBox(height: 4),
            Text(_formatTime(m['timestamp']), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_chatEmojiOpen ? Icons.keyboard : Icons.sentiment_satisfied_alt, color: Colors.grey),
            onPressed: () => setState(() => _chatEmojiOpen = !_chatEmojiOpen),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _chatMsgCtrl,
                decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
                onTap: () => setState(() => _chatEmojiOpen = false),
                onSubmitted: (_) => _sendChatMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendChatMessage,
            child: const CircleAvatar(backgroundColor: Color(0xFF075E54), radius: 24, child: Icon(Icons.send, color: Colors.white, size: 20)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPanel() {
    return Container(
      height: 250,
      color: Colors.white,
      child: GridView.count(
        crossAxisCount: 8,
        children: _emojiGroups.values.expand((e) => e).map((e) => InkWell(
          onTap: () => setState(() => _chatMsgCtrl.text += e),
          child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
        )).toList(),
      ),
    );
  }

  void _sendChatMessage() {
    if (_chatMsgCtrl.text.trim().isEmpty) return;
    final roomId = _getRoomId();
    setState(() {
      DataStore.allMessages.add({
        'convKey': roomId,
        'senderId': widget.myId,
        'senderName': widget.myName,
        'receiverId': widget.peerId,
        'receiverName': widget.peerName,
        'text': _chatMsgCtrl.text,
        'timestamp': DateTime.now().toIso8601String(),
        'recipients': [widget.myId, widget.peerId],
      });
      DataStore.saveAllData();
      _chatMsgCtrl.clear();
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(_chatScrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts).toLocal();
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) { return ''; }
  }
}

