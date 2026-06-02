
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'data_store.dart';

// Mixin for central notice management
mixin NoticeCenterMixin<T extends StatefulWidget> on State<T> {
  int unreadNoticeCount = 0;
  String get currentUsername;
  String get currentSchoolName;

  List<Map<String, dynamic>> get filteredBulletinCards {
    return DataStore.allBulletinCards.where((b) => b['schoolName'] == currentSchoolName || b['schoolName'] == null).toList();
  }

  void initNoticeCount() {
    updateNoticeCount();
  }

  void updateNoticeCount() {
    int total = filteredBulletinCards.length;
    int lastSeen = DataStore.loadInt('last_seen_notice_count_$currentUsername', 0);
    int newCount = max(0, total - lastSeen);
    
    if (newCount != unreadNoticeCount) {
       setState(() => unreadNoticeCount = newCount);
    }
  }

  void showNoticeCenter(BuildContext context) async {
    await DataStore.saveInt('last_seen_notice_count_$currentUsername', filteredBulletinCards.length);
    setState(() => unreadNoticeCount = 0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('Notice Center', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: filteredBulletinCards.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Text('No new updates from the Academic Director.'))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: filteredBulletinCards.reversed.take(4).map((b) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), border: Border.all(color: Colors.grey.withOpacity(0.1)), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_outlined, color: Color(0xFF6366F1)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b['title'] ?? 'Notice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(b['desc'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(_formatFullDateTime(b['date']), style: TextStyle(fontSize: 9, color: Colors.indigo.withOpacity(0.6), fontWeight: FontWeight.bold)),
                          ],
                        )),
                      ],
                    ),
                  )).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget buildNotificationBell({bool isDark = false}) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: isDark ? Colors.white : const Color(0xFF1E293B), size: 28),
          onPressed: () => showNoticeCenter(context),
        ),
        if (unreadNoticeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.indigo : Colors.white, width: 2)),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$unreadNoticeCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }

  static const List<List<Color>> cardGradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo - Violet
    [Color(0xFFEC4899), Color(0xFFF43F5E)], // Rose - Pink
    [Color(0xFF10B981), Color(0xFF0D9488)], // Emerald - Teal
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber - Orange
    [Color(0xFF0EA5E9), Color(0xFF2563EB)], // Sky - Blue
  ];

  Widget buildNoticeBoardCard(Map<String, dynamic> b, ColorScheme colorScheme, {VoidCallback? onEdit}) {
    final gradient = [colorScheme.primary, colorScheme.secondary];
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Icon(Icons.campaign_rounded, color: colorScheme.primary, size: 30),
                const SizedBox(width: 12),
                Expanded(child: Text(b['title'] ?? 'Notice Details', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(_formatFullDateTime(b['date']), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text(b['desc'] ?? b['text'] ?? 'No description available.', style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF1E293B))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        );
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: Icon(Icons.campaign_outlined, size: 100, color: Colors.white.withOpacity(0.07)),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(b['title'] ?? 'Notice', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
                        if (onEdit != null)
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                            ),
                            onPressed: onEdit,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(b['desc'] ?? b['text'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 15, height: 1.6, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_filled_rounded, color: gradient[0], size: 18),
                          const SizedBox(width: 8),
                          Text(_formatFullDateTime(b['date']), style: TextStyle(color: gradient[0], fontSize: 13, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFullDateTime(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(date.toString());
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      final day = dt.day.toString().padLeft(2, '0');
      final year = dt.year;
      
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      
      if (hour == 0) hour = 12;
      else if (hour > 12) hour -= 12;
      
      return '$dayName, $day $monthName $year - $hour:$minute $period';
    } catch (e) {
      return date.toString();
    }
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String? receiverId;
  final String? receiverName;
  final String text;
  final DateTime timestamp;
  final bool isGroupMessage;
  final String? groupId;
  final String? groupName;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.receiverId,
    this.receiverName,
    required this.text,
    required this.timestamp,
    this.isGroupMessage = false,
    this.groupId,
    this.groupName,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isGroupMessage': isGroupMessage,
      'groupId': groupId,
      'groupName': groupName,
      'isRead': isRead,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? UniqueKey().toString(),
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderRole: map['senderRole'] ?? 'Student',
      receiverId: map['receiverId'],
      receiverName: map['receiverName'],
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null 
          ? DateTime.parse(map['timestamp']) 
          : DateTime.now(),
      isGroupMessage: map['isGroupMessage'] ?? false,
      groupId: map['groupId'],
      groupName: map['groupName'],
      isRead: map['isRead'] ?? false,
    );
  }
}

class ChatContact {
  final String id;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final List<String>? participants;

  ChatContact({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
    this.participants,
  });
}

class FadeInEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double delay;

  const FadeInEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = 0,
  });

  @override
  State<FadeInEntrance> createState() => _FadeInEntranceState();
}

class _FadeInEntranceState extends State<FadeInEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _offset = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
