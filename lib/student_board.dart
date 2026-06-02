import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'common.dart';
import 'data_store.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'chat_screen.dart';

class StudentBoardScreen extends StatefulWidget {
  final String studentName;
  final String studentClass;
  final String studentUsername;
  final Map<String, String> studentData;

  const StudentBoardScreen({
    super.key,
    required this.studentName,
    required this.studentClass,
    required this.studentUsername,
    required this.studentData,
  });

  @override
  State<StudentBoardScreen> createState() => _StudentBoardScreenState();
}

class _StudentBoardScreenState extends State<StudentBoardScreen> with NoticeCenterMixin {
  @override
  String get currentUsername => widget.studentUsername;

  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      
      setState(() {
        widget.studentData['photo'] = base64String;
      });

      // Update in DataStore
      final globalIndex = DataStore.allStudents.indexWhere((s) => s['username'] == widget.studentUsername);
      if (globalIndex != -1) {
        DataStore.allStudents[globalIndex]['photo'] = base64String;
        DataStore.saveAllData();
      }

      // Update in Firestore
      final query = await FirebaseFirestore.instance.collection('users')
          .where('username', isEqualTo: widget.studentUsername).get();
      if (query.docs.isNotEmpty) {
        query.docs.first.reference.update({'photo': base64String});
      }
    }
  }

  @override
  String get currentSchoolName => widget.studentData['schoolName'] ?? '';

  int _currentIndex = 0; 
  
  // Use global static lists for persistence
  String get _mySchool => currentSchoolName;
  List<Map<String, String>> get _allStudents => DataStore.allStudents.where((s) => s['schoolName'] == _mySchool).toList();
  List<Map<String, dynamic>> get _activities => DataStore.allActivities.where((a) => (a['std']?.toString() ?? '').split(',').map((e) => e.trim()).contains(widget.studentClass) && a['schoolName'] == _mySchool).toList();
  List<Map<String, dynamic>> get _exams => DataStore.allExams.where((e) => (e['class'] == null || (e['class']?.toString() ?? '').split(',').map((x) => x.trim()).contains(widget.studentClass)) && e['schoolName'] == _mySchool).toList();
  List<Map<String, dynamic>> get _results => DataStore.allResults.where((r) => r['studentName'] == widget.studentName && r['schoolName'] == _mySchool).toList();
  List<Map<String, dynamic>> get _messages => DataStore.allMessages.where((m) => m['schoolName'] == _mySchool).toList();
  List<Map<String, dynamic>> get _fairList => DataStore.allFairItems.where((f) => (f['class'] == null || (f['class']?.toString() ?? '').split(',').map((x) => x.trim()).contains(widget.studentClass)) && f['schoolName'] == _mySchool).toList();
  List<Map<String, dynamic>> get _groups => DataStore.allGroups.where((g) => g['schoolName'] == _mySchool).toList();
  List<Map<String, String>> get _teachers {
    return DataStore.allTeachers.where((t) => t['schoolName'] == _mySchool).toList();
  }

  // Search controllers for historical data
  final TextEditingController _examSearchCtrl = TextEditingController();
  final TextEditingController _resultSearchCtrl = TextEditingController();
  
  // States for messaging
  String? _activeChatPeerId;
  final ScrollController _chatScrollCtrl = ScrollController();
  final TextEditingController _chatMsgCtrl = TextEditingController();
  bool _chatEmojiOpen = false;

  bool get _isHifzStudent => DataStore.classDepts[widget.studentClass] == 'HIFZ' || widget.studentClass == '01';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    initNoticeCount();
    _currentIndex = DataStore.loadInt('student_dashboard_index', 0);
    // Auto-refresh every 3 seconds to ensure real-time sync with teacher board
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        updateNoticeCount();
        DataStore.checkForNewAndNotify(widget.studentUsername);
        setState(() {});
      }
    });
    _loadAllDataIfNecessary();
  }

  void _setTab(int index) {
    setState(() {
      _currentIndex = index;
      DataStore.saveInt('student_dashboard_index', index);
      if (index == 5 || index == 6) { // Messages or Groups
         DataStore.markMessagesAsRead(widget.studentUsername);
      }
    });
  }


  @override
  void dispose() {
    _refreshTimer?.cancel();
    _examSearchCtrl.dispose();
    _resultSearchCtrl.dispose();
    _chatScrollCtrl.dispose();
    _chatMsgCtrl.dispose();
    super.dispose();
  }

  void _loadAllDataIfNecessary() {
     // Trigger any initial logic
  }

  List<Map<String, dynamic>> get _metrics {
      final config = DataStore.featureConfig;
      final List<Map<String, dynamic>> all = [
        {'title': 'Activities', 'value': '${_activities.length}', 'icon': Icons.play_circle_fill, 'color': const Color(0xFF6366F1), 'targetIndex': 1, 'feature': 'Activities'},
        {'title': 'F.transactions', 'value': '${_fairList.length}', 'icon': Icons.star_rounded, 'color': const Color(0xFFEC4899), 'targetIndex': 2, 'feature': 'F.transactions'},
        {'title': 'Schedule', 'value': '${_exams.length}', 'icon': Icons.calendar_today_rounded, 'color': const Color(0xFFF59E0B), 'targetIndex': 3, 'feature': 'Schedule'},
        {'title': 'Results', 'value': '${_results.length}', 'icon': Icons.auto_graph_rounded, 'color': const Color(0xFF8B5CF6), 'targetIndex': 4, 'feature': 'Results'},
        {'title': 'Attendance', 'value': '', 'icon': Icons.fingerprint_rounded, 'color': const Color(0xFF06B6D4), 'targetIndex': 7, 'feature': 'Attendance'},
        {'title': 'Messages', 'value': 'P2P', 'icon': Icons.chat_bubble_rounded, 'color': const Color(0xFF10B981), 'targetIndex': 5, 'feature': 'Messages'},
        {'title': 'Announce', 'value': '${filteredBulletinCards.length}', 'icon': Icons.campaign_rounded, 'color': const Color(0xFF6366F1), 'targetIndex': 0, 'feature': 'Groups'},
        if (_isHifzStudent)
          {'title': 'Hifz Journal', 'value': '', 'icon': Icons.menu_book_rounded, 'color': const Color(0xFF075E54), 'targetIndex': 8, 'feature': 'HifzJournal'},
      ];
      return all.where((m) => config[m['feature']] ?? true || m['feature'] == 'HifzJournal').toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    
    final bool isDesktop = width > 1100;
    final bool isTablet = width > 650 && width <= 1100;

    if (isDesktop || isTablet) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Row(
          children: [
            isDesktop ? _buildDesktopSidebar(colorScheme) : _buildTabletRail(colorScheme),
            Expanded(
              child: Column(
                children: [
                  _buildDesktopAppBar(colorScheme),
                  Expanded(
                    child: FadeInEntrance(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          _buildHomeTab(colorScheme),
                          _buildActivitiesTab(colorScheme),
                          _buildFairTab(colorScheme),
                          _buildScheduleTab(colorScheme),
                          _buildResultTab(colorScheme),
                          _buildMessagesTab(colorScheme),
                          _buildGlobalGroupTab(colorScheme),
                          _buildAttendanceDetailForStudent(colorScheme),
                          _buildHifzDetailTab(colorScheme),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: _uploadPhoto,
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              backgroundImage: widget.studentData['photo'] != null && widget.studentData['photo']!.isNotEmpty
                  ? MemoryImage(base64Decode(widget.studentData['photo']!))
                  : null,
              child: widget.studentData['photo'] == null || widget.studentData['photo']!.isEmpty
                  ? Text(widget.studentName[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
          ),
        ),
        title: Column(
          children: [
            Text(widget.studentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Class ${widget.studentClass}', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),

      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(colorScheme),
          _buildActivitiesTab(colorScheme),
          _buildFairTab(colorScheme),
          _buildScheduleTab(colorScheme),
          _buildResultTab(colorScheme),
          _buildMessagesTab(colorScheme),
          _buildGlobalGroupTab(colorScheme),
          _buildAttendanceDetailForStudent(colorScheme),
          _buildHifzDetailTab(colorScheme),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildNavItem(Icons.home_rounded, 'Home', 0, colorScheme),
            _buildNavItem(Icons.play_circle_fill, 'Act', 1, colorScheme, isEnabled: DataStore.featureConfig['Activities'] ?? true),
            _buildNavItem(Icons.local_activity_rounded, 'F.transactions', 2, colorScheme, isEnabled: DataStore.featureConfig['F.transactions'] ?? true),
            _buildNavItem(Icons.calendar_month_rounded, 'Sched', 3, colorScheme, isEnabled: DataStore.featureConfig['Schedule'] ?? true),
            _buildNavItem(Icons.analytics_rounded, 'Res', 4, colorScheme, isEnabled: DataStore.featureConfig['Results'] ?? true),
            _buildNavItem(Icons.fingerprint_rounded, 'Attnd', 7, colorScheme, isEnabled: DataStore.featureConfig['Attendance'] ?? true),
            _buildNavItem(Icons.chat_bubble_rounded, 'Msg', 5, colorScheme, isEnabled: DataStore.featureConfig['Messages'] ?? true, hasBadge: DataStore.getUnreadMessageCount(widget.studentUsername) > 0),
            if (_isHifzStudent)
              _buildNavItem(Icons.menu_book_rounded, 'Hifz', 8, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(ColorScheme colorScheme) {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 60,
                  width: 60,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: colorScheme.primary.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: ClipOval(child: Image.asset('assets/images/app_logo_v2.png', fit: BoxFit.cover)),
                ),
                Image.asset('assets/images/app_name_arabic.png', height: 45),
                const SizedBox(height: 8),
                Text('STUDENT PORTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colorScheme.primary, letterSpacing: 2)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDesktopNavItem(Icons.home_rounded, 'Home', 0, colorScheme),
                _buildDesktopNavItem(Icons.play_circle_fill, 'Activities', 1, colorScheme),
                _buildDesktopNavItem(Icons.local_activity_rounded, 'F.transactions', 2, colorScheme),
                _buildDesktopNavItem(Icons.calendar_month_rounded, 'Schedule', 3, colorScheme),
                _buildDesktopNavItem(Icons.analytics_rounded, 'Results', 4, colorScheme),
                _buildDesktopNavItem(Icons.fingerprint_rounded, 'Attendance', 7, colorScheme),
                _buildDesktopNavItem(Icons.chat_bubble_rounded, 'Messages', 5, colorScheme, hasBadge: DataStore.getUnreadMessageCount(widget.studentUsername) > 0),
                if (_isHifzStudent) _buildDesktopNavItem(Icons.menu_book_rounded, 'Hifz Journal', 8, colorScheme),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            leading: GestureDetector(
              onTap: _uploadPhoto,
              child: CircleAvatar(
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                backgroundImage: widget.studentData['photo'] != null && widget.studentData['photo']!.isNotEmpty
                    ? MemoryImage(base64Decode(widget.studentData['photo']!))
                    : null,
                child: widget.studentData['photo'] == null || widget.studentData['photo']!.isEmpty
                    ? Text(widget.studentName[0], style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            title: Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Class ${widget.studentClass}', style: const TextStyle(fontSize: 10)),
            trailing: IconButton(icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.grey), onPressed: () => AuthService().signOut()),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletRail(ColorScheme colorScheme) {
    final config = DataStore.featureConfig;
    bool isEnabled(String f) => config[f] ?? true;

    final List<Map<String, dynamic>> items = [
      {'icon': const Icon(Icons.home_rounded), 'label': 'Home', 'targetIndex': 0},
    ];

    if (isEnabled('Activities')) items.add({'icon': const Icon(Icons.play_circle_fill), 'label': 'Activities', 'targetIndex': 1});
    if (isEnabled('F.transactions')) items.add({'icon': const Icon(Icons.local_activity_rounded), 'label': 'F.transactions', 'targetIndex': 2});
    if (isEnabled('Schedule')) items.add({'icon': const Icon(Icons.calendar_month_rounded), 'label': 'Schedule', 'targetIndex': 3});
    if (isEnabled('Results')) items.add({'icon': const Icon(Icons.analytics_rounded), 'label': 'Results', 'targetIndex': 4});
    if (isEnabled('Attendance')) items.add({'icon': const Icon(Icons.fingerprint_rounded), 'label': 'Attendance Report', 'targetIndex': 7});
    if (isEnabled('Messages')) {
      items.add({
        'icon': Stack(
          children: [
            const Icon(Icons.chat_bubble_rounded),
            if (DataStore.getUnreadMessageCount(widget.studentUsername) > 0)
              Positioned(right: 0, top: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
          ],
        ),
        'label': 'Messages',
        'targetIndex': 5,
      });
    }
    if (_isHifzStudent) items.add({'icon': const Icon(Icons.menu_book_rounded), 'label': 'Hifz', 'targetIndex': 8});

    int selectedRailIndex = items.indexWhere((item) => item['targetIndex'] == _currentIndex);
    if (selectedRailIndex == -1) selectedRailIndex = 0;

    return NavigationRail(
      selectedIndex: selectedRailIndex,
      onDestinationSelected: (int index) => _setTab(items[index]['targetIndex']),
      backgroundColor: Colors.white,
      labelType: NavigationRailLabelType.selected,
      selectedIconTheme: IconThemeData(color: colorScheme.primary),
      leading: Padding(
        padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
        child: GestureDetector(
          onTap: _uploadPhoto,
          child: CircleAvatar(
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            backgroundImage: widget.studentData['photo'] != null && widget.studentData['photo']!.isNotEmpty
                ? MemoryImage(base64Decode(widget.studentData['photo']!))
                : null,
            child: widget.studentData['photo'] == null || widget.studentData['photo']!.isEmpty
                ? Text(widget.studentName[0], style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))
                : null,
          ),
        ),
      ),
      destinations: items.map((item) {
        return NavigationRailDestination(
          icon: item['icon'] as Widget,
          label: Text(item['label'] as String),
        );
      }).toList(),
      trailing: Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.grey),
              onPressed: () => AuthService().signOut(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool hasBadge = false}) {
    final isSelected = _currentIndex == index;
    final isEnabled = DataStore.featureConfig[label == 'Home' ? 'Activities' : (label == 'Attendance' ? 'Attendance' : (label == 'Announce' ? 'Groups' : label))] ?? true;
    if (label == 'Home') { /* Always enabled */ } 
    else if (!isEnabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _setTab(index),

        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(icon, color: isSelected ? colorScheme.primary : const Color(0xFF64748B), size: 20),
                  if (hasBadge)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? colorScheme.primary : const Color(0xFF1E293B),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopAppBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          Text('Welcome, ${widget.studentName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('Class ${widget.studentClass}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12)),
          ),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool isEnabled = true, bool hasBadge = false}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colorScheme.primary : (isEnabled ? Colors.grey : Colors.grey.withOpacity(0.2));
    return InkWell(
      onTap: isEnabled ? () { _setTab(index); if (label == 'Msg' || label == 'Announce') DataStore.markMessagesAsRead(widget.studentUsername); } : null,

      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isEnabled ? 1.0 : 0.3,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(icon, color: color, size: 22),
                  if (hasBadge)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceDetailForStudent(ColorScheme colorScheme) {
    final myAttendance = DataStore.allAttendance.where((a) => a['studentUsername'] == widget.studentUsername).toList();
    final presentCount = myAttendance.where((a) => (a['periods'] as Map?)?['FN'] == 'P' || (a['periods'] as Map?)?['AN'] == 'P').length;
    final totalDays = myAttendance.length;
    final attendancePct = totalDays == 0 ? 0.0 : (presentCount / totalDays);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                const Text('My Attendance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttStatCard('Total Days', '$totalDays', Icons.calendar_today_rounded, Colors.blue),
                    _buildAttStatCard('Present', '$presentCount', Icons.check_circle_rounded, Colors.green),
                    _buildAttStatCard('Percent', '${(attendancePct * 100).toInt()}%', Icons.analytics_rounded, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          if (myAttendance.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note_rounded, size: 80, color: Colors.grey.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text('No records yet', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: myAttendance.length,
                itemBuilder: (context, index) {
                  final rec = myAttendance[index];
                  final pMap = rec['periods'] as Map? ?? {};
                  final fn = pMap['FN'] ?? '-';
                  final an = pMap['AN'] ?? '-';
                  final DateTime dt = DateTime.tryParse(rec['date'] ?? '') ?? DateTime.now();
                  final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  final String dayName = weekdays[dt.weekday - 1];
                  final String monthName = months[dt.month - 1];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(dayName, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('${dt.day}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 20)),
                                Text(monthName, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 10)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Daily Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _miniStatusBadge('Morning', fn, rec['leaveReason']),
                                    const SizedBox(width: 8),
                                    _miniStatusBadge('Afternoon', an, rec['leaveReason']),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(fn == 'P' && an == 'P' ? Icons.stars_rounded : Icons.check_circle_outline_rounded, 
                               color: fn == 'P' && an == 'P' ? Colors.amber : Colors.grey.withOpacity(0.3), size: 30),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _miniStatusBadge(String label, String status, String? reason) {
    Color color = status == 'P' ? Colors.green : (status == 'A' ? Colors.red : Colors.grey);
    return GestureDetector(
      onTap: () {
        if (status == 'A' && reason != null && reason.isNotEmpty) {
          showDialog(
            context: context,
            builder: (ctx) {
              final colorScheme = Theme.of(context).colorScheme;
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.sick_rounded, color: Colors.red, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text('Leave Reason', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text(label == 'FN' ? 'Morning Session' : (label == 'AN' ? 'Afternoon Session' : label), style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          reason,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF334155), height: 1.5, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $status',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            if (status == 'A' && reason != null && reason.isNotEmpty) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline_rounded, size: 10, color: color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _attendanceBadge(String label, String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade400;
    IconData icon = Icons.remove_circle_outline;
    if (status == 'P') { bg = Colors.green.shade50; fg = Colors.green; icon = Icons.check_circle_rounded; }
    if (status == 'A') { bg = Colors.red.shade50; fg = Colors.red; icon = Icons.cancel_rounded; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: fg.withOpacity(0.8), letterSpacing: 0.2)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(status == '-' ? '-' : status, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
                        Text(widget.studentName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 30),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
              const SizedBox(height: 32),

          const SizedBox(height: 32),
          const Text('Our Faculty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _teachers.isEmpty 
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: colorScheme.primary.withOpacity(0.5)),
                    const SizedBox(width: 12),
                    Text('No teachers have been added yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              )
            : SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _teachers.length,
                  itemBuilder: (context, index) {
                    final t = _teachers[index];
                    return GestureDetector(
                      onTap: () => _showTeacherProfile(t, colorScheme),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 16, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [colorScheme.primary.withOpacity(0.5), colorScheme.secondary.withOpacity(0.5)]),
                                  ),
                                  child: CircleAvatar(
                                    radius: 35,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    backgroundImage: (t['photo'] != null && t['photo']!.isNotEmpty)
                                        ? MemoryImage(base64Decode(t['photo']!))
                                        : const AssetImage('assets/male_avatar.png') as ImageProvider,
                                  ),
                                ),
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(t['name'] ?? 'Faculty', 
                                textAlign: TextAlign.center,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B))),
                            Text(t['designation'] ?? 'Teacher', 
                                textAlign: TextAlign.center,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                              child: Text('View Profile', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          const SizedBox(height: 24),
          _buildHifzSectionIfApplicable(colorScheme),
          
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: MediaQuery.of(context).size.width > 800 ? 1.5 : 2.2,
            ),
            itemCount: _metrics.length,
            itemBuilder: (context, index) {
              final m = _metrics[index];
              return _buildMetricCard(m['title'], m['value'], m['icon'], m['color'], index: m['targetIndex']);
            },
          ),

          const SizedBox(height: 32),
          const Text('Notice Board', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _buildBulletinList(colorScheme),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {int? index}) {
    return GestureDetector(
      onTap: index != null ? () => setState(() => _currentIndex = index) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value.isNotEmpty) ...[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: value.isEmpty ? 13 : 10,
                      fontWeight: FontWeight.bold,
                      color: value.isEmpty ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHifzOverviewCard(ColorScheme colorScheme) {
    final today = DateTime.now().toString().split(' ')[0];
    final progress = DataStore.allHifzProgress.where((p) => p['studentUsername'] == widget.studentUsername).toList();
    final latest = progress.isNotEmpty ? progress.last : {};

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: Color(0xFF075E54)),
                    SizedBox(width: 12),
                    Text('Today\'s Lesson', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 8),
                  child: const Text('View History', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          if (latest.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _hifzProgressRow('New Lesson', '${latest['todayFromSura']} ${latest['todayFromAya']} | ${latest['todayToSura']} ${latest['todayToAya']}', Colors.blue),
                  const SizedBox(height: 12),
                  _hifzProgressRow('Old Review', '${latest['oldFromSura']} ${latest['oldFromAya']} | ${latest['oldToSura']} ${latest['oldToAya']}', Colors.orange),
                  if (latest['oldPortionJuzh'] != null) ...[
                    const SizedBox(height: 12),
                    _hifzProgressRow('Old Portion Memorized', 'Juzh ${latest['oldPortionJuzh']}', Colors.deepOrange),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Juzh Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                            Text('Juzh ${latest['juzh']}/30', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF075E54))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (int.tryParse(latest['juzh']?.toString() ?? '0') ?? 0) / 30.0,
                            backgroundColor: Colors.white,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF075E54)),
                            minHeight: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No lesson recorded for today yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _hifzProgressRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.1))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(label == 'New Lesson' ? Icons.play_arrow_rounded : Icons.history_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHifzDetailTab(ColorScheme colorScheme) {
    final progress = DataStore.allHifzProgress.where((p) => p['studentUsername'] == widget.studentUsername).toList().reversed.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              IconButton(onPressed: () => setState(() => _currentIndex = 0), icon: const Icon(Icons.arrow_back_ios_new_rounded)),
              const SizedBox(width: 8),
              const Text('Lesson History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        Expanded(
          child: progress.isEmpty
              ? _emptyStateView(Icons.menu_book_rounded, 'No history found')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: progress.length,
                  itemBuilder: (context, index) {
                    final p = progress[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF64748B))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF075E54).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text('Juzh ${p['juzh']}', style: const TextStyle(color: Color(0xFF075E54), fontWeight: FontWeight.w900, fontSize: 11)),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          _hifzProgressRow('New Lesson', '${p['todayFromSura']} ${p['todayFromAya']} | ${p['todayToSura']} ${p['todayToAya']}', Colors.blue),
                          const SizedBox(height: 12),
                          _hifzProgressRow('Old Review', '${p['oldFromSura']} ${p['oldFromAya']} | ${p['oldToSura']} ${p['oldToAya']}', Colors.orange),
                          if (p['oldPortionJuzh'] != null) ...[
                            const SizedBox(height: 12),
                            _hifzProgressRow('Old Portion Memorized', 'Juzh ${p['oldPortionJuzh']}', Colors.deepOrange),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyStateView(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHifzSectionIfApplicable(ColorScheme colorScheme) {
    if (!_isHifzStudent) return const SizedBox.shrink();
    return _buildHifzOverviewCard(colorScheme);
  }

  Widget _buildBulletinList(ColorScheme colorScheme) {
    if (filteredBulletinCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
        child: const Column(
          children: [
             Icon(Icons.mark_chat_unread_outlined, size: 48, color: Colors.grey),
             SizedBox(height: 12),
             Text('No active cards from Academic Director', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredBulletinCards.length,
      itemBuilder: (context, index) {
        final b = filteredBulletinCards[index];
        return buildNoticeBoardCard(b, index);
      },
    );
  }



  Widget _buildActivitiesTab(ColorScheme colorScheme) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Assigned Activities', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Color(0xFF0F172A))),
        ),
        Expanded(
          child: _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_outline, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      const Text('No activities assigned yet.', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final a = _activities[index];
                    final submission = DataStore.allActivitySubmissions.firstWhere(
                      (s) => s['studentUsername'] == widget.studentUsername && s['activityId'] == a['id'],
                      orElse: () => {},
                    );
                    final bool isDone = submission['isCompleted'] == true;
                    final String score = submission['score'] ?? '0';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDone ? Colors.green.shade100 : Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDone ? Colors.green.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(isDone ? Icons.check_circle : Icons.play_circle_fill, color: isDone ? Colors.green : Colors.blue),
                            ),
                            title: Text(a['title'] ?? 'Untitled Activity', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${a['type']} | Due: ${a['date'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                if (isDone) 
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text('Score Received: $score / ${a['marks']}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isDone ? 'COMPLETED' : 'PENDING',
                                style: TextStyle(color: isDone ? Colors.green.shade700 : Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: ExpansionTile(
                              title: const Text('View Details & Upload', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a['description'] ?? 'No description provided', style: const TextStyle(color: Color(0xFF475569), height: 1.5)),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission successful! (Simulated)')));
                                          },
                                          icon: const Icon(Icons.upload_file),
                                          label: const Text('Upload Work', style: TextStyle(fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFairTab(ColorScheme colorScheme) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('F.transactions', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Color(0xFF0F172A))),
        ),
        Expanded(
          child: _fairList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_activity_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      const Text('No F.transactions added.', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _fairList.length,
                  itemBuilder: (context, index) {
                    final f = _fairList[index];
                    final payment = DataStore.allFairPayments.firstWhere(
                      (p) => p['studentUsername'] == widget.studentUsername && p['fairId'] == f['id'],
                      orElse: () => {},
                    );
                    final bool isPaid = payment['isPaid'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isPaid ? Colors.teal.shade100 : Colors.red.shade100),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isPaid ? Colors.teal.shade50 : Colors.pink.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.star, color: isPaid ? Colors.teal : Colors.pink),
                        ),
                        title: Text(f['title'] ?? 'F.transaction Item', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        subtitle: Text('${f['description']}\nDue: ${f['date'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('â‚¹${f['amount'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid ? Colors.teal.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPaid ? 'PAID' : 'UNPAID',
                                style: TextStyle(color: isPaid ? Colors.teal : Colors.red, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab(ColorScheme colorScheme) {
    final searchTerm = _examSearchCtrl.text.toLowerCase();
    final filtered = _exams.where((e) => 
      (e['title'] ?? e['examName'] ?? '').toLowerCase().contains(searchTerm)
    ).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Class Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              TextField(
                controller: _examSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search schedule items...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() {}),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No schedule items found.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final String type = item['type'] ?? 'Exam';
                    final bool isExam = type == 'Exam';
                    final List subs = item['subjects'] ?? [];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isExam ? Colors.orange.shade50 : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(isExam ? Icons.assignment : Icons.event, color: isExam ? Colors.orange.shade700 : Colors.teal.shade700),
                          ),
                          title: Text(item['title'] ?? item['examName'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A))),
                          subtitle: Text(isExam ? '${subs.length} Subjects' : '${item['date'] ?? item['dates'] ?? ''} | ${item['time'] ?? ''}', style: TextStyle(color: isExam ? Colors.orange.shade800 : Colors.teal.shade800, fontSize: 13, fontWeight: FontWeight.w700)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  if (!isExam && (item['description']?.toString().isNotEmpty == true)) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
                                      child: Text(item['description'], style: const TextStyle(height: 1.5, color: Color(0xFF0F766E), fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                  if (isExam) ...subs.map<Widget>((s) => Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.book, size: 16, color: Colors.orange),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF9A3412)))),
                                        Text('${s['date']} | ${s['time']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFC2410C))),
                                      ],
                                    ),
                                  )).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildResultTab(ColorScheme colorScheme) {
    final searchTerm = _resultSearchCtrl.text.toLowerCase();
    final filteredResults = _results.where((r) => 
      (r['examName'] ?? '').toLowerCase().contains(searchTerm)
    ).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Result Board', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              TextField(
                controller: _resultSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search results...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() {}),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredResults.isEmpty
              ? const Center(child: Text('No results announced yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredResults.length,
                  itemBuilder: (context, index) {
                    final r = filteredResults[index];
                    final List subjectRes = r['subjectResults'] ?? [];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(16)),
                              child: Icon(Icons.analytics, color: Colors.purple.shade700),
                            ),
                            title: Text(r['examName'] ?? 'Exam Result', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                            subtitle: Text('${subjectRes.length} Subjects Published', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Table(
                              border: TableBorder.all(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade50),
                                  children: const [
                                    Padding(padding: EdgeInsets.all(12), child: Text('Subject', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(12), child: Text('Scored', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(12), child: Text('Grade', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(12), child: Text('Status', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                                  ],
                                ),
                                ...subjectRes.map((s) {
                                  final double scored = double.tryParse(s['scoredMark']?.toString() ?? '0') ?? 0;
                                  final double total = double.tryParse(s['totalMarks']?.toString() ?? '100') ?? 100;
                                  final double pct = (scored / total) * 100;
                                  
                                  String grade = 'D'; String status = 'Failed'; Color statusColor = Colors.red;
                                  if (pct >= 90) { grade = 'A+'; status = 'Pass'; statusColor = Colors.green; }
                                  else if (pct >= 80) { grade = 'A'; status = 'Pass'; statusColor = Colors.green; }
                                  else if (pct >= 70) { grade = 'B+'; status = 'Pass'; statusColor = Colors.green; }
                                  else if (pct >= 60) { grade = 'B'; status = 'Pass'; statusColor = Colors.green; }
                                  else if (pct >= 50) { grade = 'C+'; status = 'Pass'; statusColor = Colors.green; }
                                  else if (pct >= 40) { grade = 'C'; status = 'Pass'; statusColor = Colors.green; }

                                  return TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(12), child: Text(s['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                      Padding(padding: const EdgeInsets.all(12), child: Text('${s['scoredMark']}/${s['totalMarks']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: const EdgeInsets.all(12), child: Text(grade, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                                      Padding(padding: const EdgeInsets.all(12), child: Text(status, style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 10))),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Important Announcements removed per user request
  // ignore: unused_element
  Widget _buildImportantBulletins_removed(ColorScheme colorScheme) {
    final bulletins = _exams.where((e) => e['type'] == 'Announcement').toList();
    if (bulletins.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Important Announcements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: bulletins.length,
            itemBuilder: (context, index) {
              final b = bulletins[index];
              final colors = [const Color(0xFF6366F1), const Color(0xFFEC4899), const Color(0xFF06B6D4), const Color(0xFF8B5CF6)];
              final cardColor = colors[index % colors.length];

              return Container(
                width: 300,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(b['title'] ?? 'Announcement', style: TextStyle(color: cardColor, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        Icon(Icons.campaign, color: cardColor),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: Text(b['description'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (b['date']?.toString().isNotEmpty == true) ...[
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(b['date'], style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                        ],
                        if (b['day']?.toString().isNotEmpty == true) ...[
                          Icon(Icons.wb_sunny, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(b['day'], style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMessagesTab(ColorScheme colorScheme) {
    // Collect all potential contacts (all students in class + all teachers + Academic Director)
    final List<Map<String, dynamic>> allContacts = [
      ..._teachers.map((t) => {
        "id": t['username'],
        "name": t['name'],
        "role": "Teacher",
        "dept": "Class ${t['class']}",
        "color": "0xFF009688",
      }),
    ];

    if (_activeChatPeerId != null) {
      final contact = allContacts.firstWhere((c) => c['id'] == _activeChatPeerId!, orElse: () => {});
      return DirectChatScreen(
        peerId: contact['id'] ?? '',
        peerName: contact['name'] ?? 'Unknown',
        peerDept: contact['dept'] ?? '',
        peerColor: Color(int.parse(contact['color'] ?? '0xFF9E9E9E')),
        myId: widget.studentUsername,
        myName: widget.studentName,
        onBack: () => setState(() => _activeChatPeerId = null),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
          ),
          child: const Row(
            children: [
              Icon(Icons.message, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text('Messages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: allContacts.length,
            itemBuilder: (context, index) {
              final c = allContacts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(int.parse(c['color'] ?? '0xFF9E9E9E')),
                  child: Text(c['name']![0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${c['role']} | ${c['dept']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _activeChatPeerId = c['id']),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showReactionPicker(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _reactionOption(msg, 'ðŸ‘'),
            _reactionOption(msg, 'â¤ï¸'),
            _reactionOption(msg, 'âœ…'),
          ],
        ),
      ),
    );
  }

  Widget _reactionOption(Map<String, dynamic> msg, String emoji) {
    Color bg = Colors.grey.shade100;
    if (emoji == 'ðŸ‘') bg = Colors.yellow.shade100;
    if (emoji == 'â¤ï¸') bg = Colors.red.shade100;
    if (emoji == 'âœ…') bg = Colors.green.shade100;

    return InkWell(
      onTap: () {
        _addReaction(msg, emoji);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  void _addReaction(Map<String, dynamic> msg, String emoji) {
    setState(() {
      final index = DataStore.allMessages.indexWhere((m) => m['timestamp'] == msg['timestamp'] && m['from'] == msg['from']);
      if (index != -1) {
        final Map<String, dynamic> reactions = Map<String, dynamic>.from(DataStore.allMessages[index]['reactions'] ?? {});
        reactions[widget.studentUsername] = emoji;
        DataStore.allMessages[index]['reactions'] = reactions;
        DataStore.saveAllData();
      }
    });
  }

  Widget _buildReactionBadge(Map<String, dynamic> msg) {
    final Map? reactions = msg['reactions'];
    if (reactions == null || reactions.isEmpty) return const SizedBox.shrink();
    
    // Count occurrences of each emoji
    final counts = <String, int>{};
    reactions.values.forEach((e) => counts[e] = (counts[e] ?? 0) + 1);
    
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: counts.entries.map((e) {
          Color bg = Colors.white;
          Color border = Colors.grey.shade200;
          if (e.key == 'ðŸ‘') { bg = Colors.yellow.shade50; border = Colors.yellow.shade200; }
          if (e.key == 'â¤ï¸') { bg = Colors.red.shade50; border = Colors.red.shade200; }
          if (e.key == 'âœ…') { bg = Colors.green.shade50; border = Colors.green.shade200; }

          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Text(e.key, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
                Text('${e.value}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGlobalGroupTab(ColorScheme colorScheme) {
    final globalMessages = _messages.where((msg) =>
      msg['group_id'] == 'staff_global' || msg['isStaffMessage'] == true
    ).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.05),
            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign, color: Colors.teal, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('School Announce', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Text('View announcements and react below', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: globalMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No school announcements yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: globalMessages.length,
                  itemBuilder: (context, index) {
                    final msg = globalMessages[index];
                    final isTeacher = msg['senderType'] == 'Teacher';
                    final isMe = msg['senderId'] == widget.studentUsername;
                    
                    return FadeInEntrance(
                      delay: index * 0.03,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isMe)
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isTeacher ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                child: Icon(isTeacher ? Icons.badge : Icons.school, color: isTeacher ? Colors.green : Colors.orange, size: 18),
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(msg['from'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isTeacher ? Colors.green : Colors.orange).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(isTeacher ? 'Teacher' : 'Student', style: TextStyle(fontSize: 10, color: isTeacher ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => _showReactionPicker(msg),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isMe ? colorScheme.primary : (isTeacher ? Colors.green.shade50 : Colors.orange.shade50),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(msg['text'] ?? '', style: TextStyle(fontSize: 14, color: isMe ? Colors.white : Colors.black)),
                                          _buildReactionBadge(msg),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_formatTimestamp(msg['timestamp']), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                       ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _sendGlobalReply(TextEditingController ctrl) {
    if (ctrl.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'from': widget.studentName,
        'to': 'All',
        'text': ctrl.text,
        'timestamp': DateTime.now().toIso8601String(),
        'isStaffMessage': true, // Keep it in the same global stream
        'senderId': widget.studentUsername,
        'senderType': 'Student',
        'group_id': 'staff_global',
      });
      DataStore.saveAllData();
      ctrl.clear();
    });
  }

  Widget _buildClassGroupTab(ColorScheme colorScheme) {
    // Get class group for this student's class
    final classGroup = _groups.where((g) =>
      g['type'] == 'class' && g['class_name'] == widget.studentClass
    ).firstOrNull;

    if (classGroup == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Class group not created yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      );
    }

    final groupMessages = _messages.where((msg) =>
      msg['group_id'] == classGroup['id']
    ).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
          ),
          child: Row(
            children: [
              const Icon(Icons.groups, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class ${widget.studentClass} Group',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('Class Discussion', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: groupMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No messages in class group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupMessages.length,
                  itemBuilder: (context, index) {
                    final msg = groupMessages[index];
                    final isClassTeacher = msg['senderType'] == 'Teacher';
                    
                    return FadeInEntrance(
                      delay: index * 0.03,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isClassTeacher ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                              child: Icon(
                                isClassTeacher ? Icons.badge : Icons.school,
                                color: isClassTeacher ? Colors.green : Colors.orange,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(msg['from'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (isClassTeacher) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Class Teacher',
                                            style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isClassTeacher ? Colors.green.shade50 : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _buildMessageTextWithMentions(msg['text'] ?? '', isClassTeacher ? Colors.green.shade900 : Colors.orange.shade900),
                                  ),

                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(msg['timestamp']),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildGroupMessageInput(classGroup['id'] as String),
      ],
    );
  }

  Widget _buildGroupMessageInput(String groupId) {
    final ctrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  hintText: 'Message class...',
                  border: InputBorder.none,
                ),
                onSubmitted: (val) => _sendGroupMessage(groupId, ctrl),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _sendGroupMessage(groupId, ctrl),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTextWithMentions(String text, Color textColor) {
    final List<String> mentions = ['@activities', '@f.transactions', '@exam', '@result'];
    final List<TextSpan> spans = [];
    
    text.split(' ').forEach((word) {
      if (mentions.contains(word.toLowerCase())) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()..onTap = () {
              int targetIndex = 0;
              if (word.toLowerCase() == '@activities') targetIndex = 1;
              if (word.toLowerCase() == '@f.transactions') targetIndex = 2;
              if (word.toLowerCase() == '@exam') targetIndex = 3;
              if (word.toLowerCase() == '@result') targetIndex = 4;
              setState(() => _currentIndex = targetIndex);
            },
          ),
        );
      } else {
        spans.add(TextSpan(text: '$word ', style: TextStyle(color: textColor, fontSize: 14)));
      }
    });

    return RichText(text: TextSpan(children: spans));
  }

  void _sendGroupMessage(String groupId, TextEditingController ctrl) {

    if (ctrl.text.trim().isEmpty) return;
    setState(() {
      DataStore.allMessages.add({
        'group_id': groupId,
        'convKey': groupId, // Consistent indexing
        'from': widget.studentName,
        'senderId': widget.studentUsername,
        'senderType': 'Student',
        'schoolName': widget.studentData['schoolName'],
        'text': ctrl.text,
        'timestamp': DateTime.now().toIso8601String(),
      });
      DataStore.saveAllData();
      ctrl.clear();
    });
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          return '${diff.inMinutes}m';
        }
        return '${diff.inHours}h';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d';
      } else {
        return '${dt.day}/${dt.month}';
      }
    } catch (e) {
      return '';
    }
  }
  void _showTeacherProfile(Map<String, String> t, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header with Photo
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: (t['photo'] != null && t['photo']!.isNotEmpty)
                          ? MemoryImage(base64Decode(t['photo']!))
                          : const AssetImage('assets/male_avatar.png') as ImageProvider,
                    ),
                  ),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 70),
            // Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  Text(t['name'] ?? 'Faculty Name', 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(t['designation'] ?? 'Faculty Member', 
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  const Divider(height: 40),
                  _profileInfoRow(Icons.badge_rounded, 'Full Name', t['fullName'] ?? 'N/A', colorScheme),
                  const SizedBox(height: 16),
                  _profileInfoRow(Icons.history_edu_rounded, 'Islamic Qualification', t['qual_islamic'] ?? 'N/A', colorScheme),
                  const SizedBox(height: 16),
                  _profileInfoRow(Icons.school_rounded, 'Academic Qualification', t['qual_academic'] ?? 'N/A', colorScheme),
                  const SizedBox(height: 16),
                  _profileInfoRow(Icons.class_rounded, 'Assigned Classes', t['class'] ?? 'N/A', colorScheme),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _setTab(5); // Switch to messages
                    },
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('Contact Teacher'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _profileInfoRow(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// TEACHER BOARD SCREEN
// ==========================================
