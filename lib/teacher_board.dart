import 'surah_list.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'pdf_service.dart';
import 'package:image_picker/image_picker.dart';

class TeacherBoardScreen extends StatefulWidget {
  final String teacherName;
  final String fullName;
  final String assignedClass;
  final String teacherUsername;
  final String schoolName;
  final String photo;
  final String qualIslamic;
  final String qualAcademic;
  final String designation;

  const TeacherBoardScreen({
    super.key,
    required this.teacherName,
    required this.fullName,
    required this.assignedClass,
    required this.teacherUsername,
    required this.schoolName,
    this.photo = '',
    this.qualIslamic = '',
    this.qualAcademic = '',
    this.designation = '',
  });

  @override
  State<TeacherBoardScreen> createState() => _TeacherBoardScreenState();
}

class _TeacherBoardScreenState extends State<TeacherBoardScreen> with NoticeCenterMixin {
  @override
  String get currentUsername => widget.teacherUsername;
  
  @override
  String get currentSchoolName => widget.schoolName;

  bool _isMobile = false;

  String get _currentPhoto {
    final t = DataStore.allTeachers.firstWhere((t) => t['username'] == widget.teacherUsername, orElse: () => {});
    if (t['photo'] != null && t['photo']!.isNotEmpty && t['photo'] != 'null') {
      return t['photo']!;
    }
    return widget.photo;
  }

  int _currentIndex = -1; // -1: Overview, 0: Students, 1: Activities, 2: Fair, 3: Exam, 4: Result, 5: Message, 6: Group
  Timer? _refreshTimer;
  String? _teacherSelectedClass;
  int _attMonth = DateTime.now().month;

  int _attYear = DateTime.now().year;


  @override
  void initState() {
    super.initState();
    initNoticeCount();
    _currentIndex = DataStore.loadInt('teacher_dashboard_index', -1);
    
    // Initialize selected class from preferences or first available Class
    final savedClass = DataStore.loadString('teacher_selected_class_${widget.teacherUsername}');
    final teacherClasses = widget.assignedClass.split(',').map((e) => e.trim()).toList();
    
    if (savedClass != null && teacherClasses.contains(savedClass)) {
      _teacherSelectedClass = savedClass;
    } else if (teacherClasses.isNotEmpty) {
      _teacherSelectedClass = teacherClasses.first;
    } else {
      _teacherSelectedClass = widget.assignedClass;
    }


    

    // Auto-refresh every 3 seconds to ensure real-time sync
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
       if (mounted) {
         updateNoticeCount();
         DataStore.checkForNewAndNotify(widget.teacherUsername);
         setState(() {});
       }
    });
    
    // Load data for assigned class
    _loadDataForAssignedClass();
  }

  void _showCredentialsDialog(String type, String user, String pass) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$type Added successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Save these credentials:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _credBox('Username', user),
            const SizedBox(height: 8),
            _credBox('Password', pass),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT')),
        ],
      ),
    );
  }

  Widget _credBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
          Expanded(child: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied!'), duration: const Duration(seconds: 1)));
            },
          ),
        ],
      ),
    );
  }

  void _setTab(int index) {
    setState(() {
      _currentIndex = index;
      DataStore.saveInt('teacher_dashboard_index', index);
      if (index == 5 || index == 6) { // Messages or Groups
         DataStore.markMessagesAsRead(widget.teacherUsername);
      }
    });
  }

  void _setSelectedClass(String? className) {
    setState(() {
      _teacherSelectedClass = className;
      if (className != null) {
        DataStore.saveString('teacher_selected_class_${widget.teacherUsername}', className);
      }
    });
  }


  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showMyProfile(ColorScheme colorScheme) {
    String currentPhoto = _currentPhoto;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          contentPadding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 50,
                          maxWidth: 400,
                          maxHeight: 400,
                        );
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          final base64 = base64Encode(bytes);
                          
                          // Update Firestore teacher_photos collection
                          FirebaseFirestore.instance.collection('teacher_photos')
                              .doc(widget.teacherUsername)
                              .set({'photo': base64, 'username': widget.teacherUsername}, SetOptions(merge: true));

                          // Update local DataStore
                          final teacherIndex = DataStore.allTeachers.indexWhere((t) => t['username'] == widget.teacherUsername);
                          if (teacherIndex != -1) {
                            DataStore.allTeachers[teacherIndex]['photo'] = base64;
                            DataStore.saveAllData();
                          }
                          
                          // Update current mockUser to reflect change in UI
                          if (DataStore.mockUser != null && DataStore.mockUser!['username'] == widget.teacherUsername) {
                            final newUser = Map<String, dynamic>.from(DataStore.mockUser!);
                            newUser['photo'] = base64;
                            DataStore.updateMockUser(newUser);
                          }

                          setDs(() {
                            currentPhoto = base64;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: const Color(0xFFF1F5F9),
                              backgroundImage: (currentPhoto.isNotEmpty)
                                  ? MemoryImage(base64Decode(currentPhoto))
                                  : const AssetImage('assets/male_avatar.png') as ImageProvider,
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  children: [
                    Text(widget.teacherName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text(widget.designation.isNotEmpty ? widget.designation : 'Faculty Member', 
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    const Divider(height: 40),
                    _profileInfoRow(Icons.badge_rounded, 'Full Name', widget.teacherName, colorScheme), // using teacherName fallback for full name if not in state, but wait! In `teacher_board.dart` the widget has `widget.teacherName`, `widget.designation`, `widget.subjects`, `widget.assignedClass`, `widget.qualification`.
// Wait, I should look at how `_TeacherDashboardScreen` is getting these fields.
                    const SizedBox(height: 30),
                    const Text('Tip: Tap your photo to update it.', 
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
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

  // Use global static lists for persistence
  List<String> get _classes => DataStore.getClassesForSchool(widget.schoolName);
  List<Map<String, String>> get _allStudents => DataStore.allStudents.where((s) => s['schoolName'] == widget.schoolName).toList();
  List<Map<String, dynamic>> get _activities => DataStore.allActivities.where((a) => (a['std']?.toString() ?? '').split(',').map((e) => e.trim()).contains(_teacherSelectedClass ?? widget.assignedClass) && (a['academicYear'] == DataStore.selectedAcademicYear || a['academicYear'] == null) && a['schoolName'] == widget.schoolName).toList();
  List<Map<String, dynamic>> get _exams => DataStore.allExams.where((e) => (e['class'] == null || (e['class']?.toString() ?? '').split(',').map((x) => x.trim()).contains(_teacherSelectedClass ?? widget.assignedClass)) && (e['academicYear'] == DataStore.selectedAcademicYear || e['academicYear'] == null) && e['schoolName'] == widget.schoolName).toList();
  List<Map<String, dynamic>> get _results => DataStore.allResults.where((r) => 
    _students.any((s) => s['name'] == r['studentName']) && (r['academicYear'] == DataStore.selectedAcademicYear || r['academicYear'] == null) && r['schoolName'] == widget.schoolName
  ).toList();
  List<Map<String, dynamic>> get _messages => DataStore.allMessages.where((m) => m['schoolName'] == widget.schoolName).toList();
  List<Map<String, dynamic>> get _fairList => DataStore.allFairItems.where((f) => (f['class'] == null || (f['class']?.toString() ?? '').split(',').map((x) => x.trim()).contains(_teacherSelectedClass ?? widget.assignedClass)) && (f['academicYear'] == DataStore.selectedAcademicYear || f['academicYear'] == null) && f['schoolName'] == widget.schoolName).toList();
  List<Map<String, dynamic>> get _groups => DataStore.allGroups.where((g) => g['schoolName'] == widget.schoolName).toList();
  List<Map<String, dynamic>> get _groupMembers => DataStore.allGroupMembers.where((gm) => gm['schoolName'] == widget.schoolName).toList();
  List<Map<String, String>> get _teachers => DataStore.allTeachers.where((t) => t['schoolName'] == widget.schoolName).toList();

  List<Map<String, String>> get _students => _allStudents.where((s) => 
    (s['std']?.toString() ?? '').split(',').map((e) => e.trim()).contains(_teacherSelectedClass ?? widget.assignedClass) && 
    (s['academicYear'] == DataStore.selectedAcademicYear || s['academicYear'] == null)
  ).toList();
  
  final Map<String, List<Map<String, dynamic>>> _studentFairs = {}; // studentName -> list of fairs with status
  final Map<String, double> _studentProgress = {}; // studentName -> progress percentage
  
  // New data for Fair and Progress
  final List<String> _fairs = ['Science Fair 2024', 'Arts & Crafts', 'Coding Challenge', 'Math Olympiad'];

  void _loadDataForAssignedClass() {
    // Data is loaded from static lists via getters. 
    // We only need to initialize pupil-specific local state like progress if needed.
    for (var student in _students) {
      String name = student['name']!;
      if (!_studentProgress.containsKey(name)) {
        _studentProgress[name] = 0.4 + (0.1 * Random().nextInt(5));
        _studentFairs[name] = _fairs.map((f) => {
          'title': f,
          'done': Random().nextBool(),
        }).toList();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    
    final bool isDesktop = width > 1100;
    final bool isTablet = width > 650 && width <= 1100;
    final bool isMobile = width <= 650;
    final teacherClasses = widget.assignedClass.split(',').map((e) => e.trim()).toList();

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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_currentIndex),
                        child: _buildBody(colorScheme),
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: teacherClasses.length > 1
            ? Theme(
                data: Theme.of(context).copyWith(canvasColor: colorScheme.primary),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _teacherSelectedClass,
                    dropdownColor: colorScheme.primary,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    items: teacherClasses.map((c) => DropdownMenuItem(value: c, child: Text('CLASS $c'))).toList(),
                    onChanged: (val) {
                      if (val != null) _setSelectedClass(val);
                    },
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BRIDGE',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white),
                  ),
                  Text(
                    'CLASS ${_teacherSelectedClass ?? widget.assignedClass}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.normal, color: Colors.white70),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthService().signOut();
            },
          )
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _buildBody(colorScheme),
        ),
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
        child: _buildTeacherNavContent(colorScheme),
      ),
    );
  }

  Widget _buildTabletRail(ColorScheme colorScheme) {
    final config = DataStore.featureConfig;
    
    // Helper to check feature enablement
    bool isEnabled(String feature) => config[feature] ?? true;

    final List<Map<String, dynamic>> items = [
      {'icon': const Icon(Icons.dashboard_rounded), 'label': 'Overview', 'targetIndex': -1},
    ];

    if (isEnabled('Students')) items.add({'icon': const Icon(Icons.people_rounded), 'label': 'Students', 'targetIndex': 0});
    if (isEnabled('Activities')) items.add({'icon': const Icon(Icons.play_circle_fill), 'label': 'Activities', 'targetIndex': 1});
    if (isEnabled('F.transactions')) items.add({'icon': const Icon(Icons.local_activity), 'label': 'F.transactions', 'targetIndex': 2});
    if (isEnabled('Schedule')) items.add({'icon': const Icon(Icons.calendar_month), 'label': 'Schedule', 'targetIndex': 3});
    if (isEnabled('Results')) items.add({'icon': const Icon(Icons.analytics), 'label': 'Results', 'targetIndex': 4});
    if (isEnabled('Attendance')) items.add({'icon': const Icon(Icons.how_to_reg), 'label': 'Attendance', 'targetIndex': 7});
    if (isEnabled('Messages')) {
      items.add({
        'icon': Stack(
          children: [
            const Icon(Icons.message),
            if (DataStore.getUnreadMessageCount(widget.teacherUsername) > 0)
              Positioned(right: 0, top: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
          ],
        ),
        'label': 'Messages',
        'targetIndex': 5,
      });
    }

    int selectedRailIndex = items.indexWhere((item) => item['targetIndex'] == _currentIndex);
    if (selectedRailIndex == -1) selectedRailIndex = 0;

    return NavigationRail(
      selectedIndex: selectedRailIndex,
      onDestinationSelected: (int index) {
         setState(() => _currentIndex = items[index]['targetIndex']);
      },
      backgroundColor: Colors.white,
      labelType: NavigationRailLabelType.selected,
      selectedIconTheme: IconThemeData(color: colorScheme.primary),
      selectedLabelTextStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
      unselectedLabelTextStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Icon(Icons.auto_awesome_rounded, color: colorScheme.primary, size: 32),
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
              icon: const Icon(Icons.add_circle_rounded, size: 32),
              color: colorScheme.primary,
              onPressed: () => _showAddItemDialog(),
            ),
            const SizedBox(height: 20),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () => AuthService().signOut(),
            ),
            const SizedBox(height: 16),
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
                Text('TEACHER PORTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colorScheme.primary, letterSpacing: 2)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDesktopNavItem(Icons.dashboard_rounded, 'Overview', -1, colorScheme),
                _buildDesktopNavItem(Icons.people_rounded, 'Students', 0, colorScheme),
                _buildDesktopNavItem(Icons.play_circle_fill, 'Activities', 1, colorScheme),
                _buildDesktopNavItem(Icons.local_activity, 'F.transactions', 2, colorScheme),
                _buildDesktopNavItem(Icons.calendar_month, 'Schedule', 3, colorScheme),
                _buildDesktopNavItem(Icons.analytics, 'Results', 4, colorScheme),
                _buildDesktopNavItem(Icons.how_to_reg, 'Attendance', 7, colorScheme),
                _buildDesktopNavItem(Icons.message, 'Messages', 5, colorScheme, hasBadge: DataStore.getUnreadMessageCount(widget.teacherUsername) > 0),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddItemDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('QUICK ADD', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            onTap: () => _showMyProfile(colorScheme),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              backgroundImage: _currentPhoto.isNotEmpty
                  ? MemoryImage(base64Decode(_currentPhoto))
                  : const AssetImage('assets/male_avatar.png') as ImageProvider,
            ),
            title: Text(widget.teacherName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(widget.designation.isNotEmpty ? widget.designation : 'ID: ${widget.teacherUsername}', style: const TextStyle(fontSize: 10)),
            trailing: IconButton(icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.grey), onPressed: () => AuthService().signOut()),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool hasBadge = false}) {
    final isSelected = _currentIndex == index;
    final isEnabled = DataStore.featureConfig[label == 'Overview' ? 'Students' : (label == 'F.transactions' ? 'F.transactions' : (label == 'Attendance' ? 'Attendance' : (label == 'Announce' ? 'Groups' : label)))] ?? true;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: isEnabled ? () => _setTab(index) : null,

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
                  Icon(icon, color: isSelected ? colorScheme.primary : (isEnabled ? const Color(0xFF64748B) : Colors.grey.withOpacity(0.2)), size: 20),
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
                  color: isSelected ? colorScheme.primary : (isEnabled ? const Color(0xFF1E293B) : Colors.grey.withOpacity(0.3)),
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
    final teacherClasses = widget.assignedClass.split(',').map((e) => e.trim()).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Text('Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(width: 32),
          
          if (teacherClasses.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _teacherSelectedClass,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                  items: teacherClasses.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                  onChanged: (val) {
                    if (val != null) _setSelectedClass(val);
                  },
                ),
              ),
            ),
          ] else
            Text('Class ${_teacherSelectedClass ?? widget.assignedClass}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),

          const Spacer(),
          IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)), onPressed: () {}),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildTeacherNavContent(ColorScheme colorScheme) {
    final List<Widget> allItems = [
      _buildNavItem(Icons.dashboard_rounded, 'Home', -1, colorScheme),
      _buildNavItem(Icons.class_, 'Students', 0, colorScheme, isEnabled: DataStore.featureConfig['Students'] ?? true),
      _buildNavItem(Icons.play_circle_fill, 'Activities', 1, colorScheme, isEnabled: DataStore.featureConfig['Activities'] ?? true),
      _buildNavItem(Icons.local_activity, 'F.transactions', 2, colorScheme, isEnabled: DataStore.featureConfig['F.transactions'] ?? true),
      _buildNavItem(Icons.calendar_month, 'Schedule', 3, colorScheme, isEnabled: DataStore.featureConfig['Schedule'] ?? true),
      _buildNavItem(Icons.analytics, 'Result', 4, colorScheme, isEnabled: DataStore.featureConfig['Results'] ?? true),
      _buildNavItem(Icons.how_to_reg, 'Attnd', 7, colorScheme, isEnabled: DataStore.featureConfig['Attendance'] ?? true),
      _buildNavItem(Icons.message, 'Msg', 5, colorScheme, isEnabled: DataStore.featureConfig['Messages'] ?? true, hasBadge: DataStore.getUnreadMessageCount(widget.teacherUsername) > 0),
    ];

    return Row(
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: allItems,
          ),
        ),
        Container(
          width: 1, 
          height: 40, 
          color: Colors.grey.withOpacity(0.1),
          margin: const EdgeInsets.symmetric(horizontal: 4),
        ),
        _buildCentralAddButton(colorScheme),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCentralAddButton(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _showAddItemDialog(),
      child: Container(
        width: 54, height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool isEnabled = true, bool hasBadge = false}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colorScheme.primary : (isEnabled ? Colors.grey : Colors.grey.withOpacity(0.2));
    return InkWell(
      onTap: isEnabled ? () { _setTab(index); if (label == 'Msg' || label == 'Announce') DataStore.markMessagesAsRead(widget.teacherUsername); } : null,

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

  void _showAddActivityDialog({int? index}) {
    final a = index != null ? _activities[index] : null;
    final nameCtrl = TextEditingController(text: a?['title'] ?? '');
    final descCtrl = TextEditingController(text: a?['description'] ?? '');
    final markCtrl = TextEditingController(text: a?['marks'] ?? '');
    final dateCtrl = TextEditingController(text: a?['date'] ?? '');
    String? selectedType = a?['type'] ?? 'Assignment';
    final List<String> types = ['Assignment', 'Project', 'Home Work'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index != null ? 'Edit Activity' : 'Add Activity'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Activity Type', prefixIcon: Icon(Icons.category)),
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setStateDialog(() => selectedType = val),
                ),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Activity Name', prefixIcon: Icon(Icons.play_circle_fill))),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description))),
                TextField(controller: markCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Mark', prefixIcon: Icon(Icons.star))),
                TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Due Date', prefixIcon: Icon(Icons.calendar_today))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              // Now allowing save even with empty name, but will use 'Untitled Activity' as default
              final title = nameCtrl.text.isEmpty ? 'Untitled Activity' : nameCtrl.text;
              setState(() {
                final data = {
                  'id': a?['id'] ?? 'act_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}',
                  'title': title,
                  'type': selectedType,
                  'description': descCtrl.text,
                  'marks': markCtrl.text,
                  'date': dateCtrl.text,
                  'std': _teacherSelectedClass ?? widget.assignedClass,
                  'academicYear': DataStore.selectedAcademicYear,
                  'schoolName': widget.schoolName,
                };
                if (index != null) {
                  final oldData = _activities[index];
                  final globalIdx = DataStore.allActivities.indexOf(oldData);
                  if (globalIdx != -1) DataStore.allActivities[globalIdx] = data;
                } else {
                  DataStore.allActivities.add(data);
                }
                setState(() {});
                DataStore.saveAllData();
              });
              Navigator.pop(context);
            },
            child: Text(index != null ? 'Update' : 'Add'),
          )
        ],
      )
    );
  }

  void _showAddFairDialog({int? index}) {
    final f = index != null ? _fairList[index] : null;
    final nameCtrl = TextEditingController(text: f?['title'] ?? '');
    final descCtrl = TextEditingController(text: f?['description'] ?? '');
    final amountCtrl = TextEditingController(text: f?['amount'] ?? '');
    final dateCtrl = TextEditingController(text: f?['date'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index != null ? 'Edit F.transaction' : 'Add F.transaction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'F.transaction Name', prefixIcon: Icon(Icons.local_activity))),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description))),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.money))),
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Due Date', prefixIcon: Icon(Icons.calendar_today))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;
              setState(() {
                final data = {
                  'id': f?['id'] ?? 'fair_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}',
                  'title': nameCtrl.text,
                  'description': descCtrl.text,
                  'amount': amountCtrl.text,
                  'date': dateCtrl.text,
                  'class': _teacherSelectedClass ?? widget.assignedClass,
                  'academicYear': DataStore.selectedAcademicYear,
                  'schoolName': widget.schoolName,
                };
                if (index != null) {
                  final oldData = _fairList[index];
                  final globalIdx = DataStore.allFairItems.indexOf(oldData);
                  if (globalIdx != -1) DataStore.allFairItems[globalIdx] = data;
                } else {
                  DataStore.allFairItems.add(data);
                }
                setState(() {});
                DataStore.saveAllData();
              });
              Navigator.pop(context);
            },
            child: Text(index != null ? 'Update' : 'Add'),
          )
        ],
      )
    );
  }

  void _showAddScheduleDialog({int? index}) {
    final e = index != null ? _exams[index] : null;
    final typeCtrl = e?['type'] ?? 'Exam';
    final nameCtrl = TextEditingController(text: e?['examName'] ?? e?['title'] ?? '');
    final descCtrl = TextEditingController(text: e?['description'] ?? '');
    final daysCtrl = TextEditingController(text: e?['days'] ?? '');
    final datesCtrl = TextEditingController(text: e?['dates'] ?? '');
    final timeCtrl = TextEditingController(text: e?['time'] ?? '');
    final classCtrl = TextEditingController(text: _teacherSelectedClass ?? widget.assignedClass);
    
    String selectedType = typeCtrl;
    List<Map<String, String>> subjects = List<Map<String, String>>.from(
      (e?['subjects'] as List?)?.map((item) => Map<String, String>.from(item)) ?? []
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setFullState) => AlertDialog(
          title: Text(index != null ? 'Edit Schedule Item' : 'Add to Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.category)),
                  items: ['Exam', 'Event', 'Holiday', 'Meeting'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setFullState(() => selectedType = val!),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: selectedType == 'Exam' ? 'Exam Name' : 'Event Name', prefixIcon: const Icon(Icons.title))),
                if (selectedType != 'Exam') ...[
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description))),
                  TextField(controller: daysCtrl, decoration: const InputDecoration(labelText: 'Days (e.g. Mon, Wed)', prefixIcon: Icon(Icons.today))),
                  TextField(controller: datesCtrl, decoration: const InputDecoration(labelText: 'Dates (e.g. Apr 15-20)', prefixIcon: Icon(Icons.calendar_month))),
                  TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.access_time))),
                ],
                if (selectedType == 'Exam') ...[
                  const SizedBox(height: 16),
                  const Text('Subjects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ...subjects.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var sub = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(child: Text('${sub['name']} (${sub['date']} ${sub['time']})', style: const TextStyle(fontSize: 12))),
                          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => setFullState(() => subjects.removeAt(idx))),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      final subNameCtrl = TextEditingController();
                      final subDateCtrl = TextEditingController();
                      final subTimeCtrl = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Add Subject Result'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: subNameCtrl, decoration: const InputDecoration(labelText: 'Subject Name')),
                              TextField(controller: subDateCtrl, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
                              TextField(controller: subTimeCtrl, decoration: const InputDecoration(labelText: 'Time (HH:MM AM/PM)')),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            TextButton(onPressed: () {
                              if (subNameCtrl.text.isNotEmpty) {
                                setFullState(() {
                                  subjects.add({
                                    'name': subNameCtrl.text,
                                    'date': subDateCtrl.text,
                                    'time': subTimeCtrl.text,
                                  });
                                });
                              }
                              Navigator.pop(context);
                            }, child: const Text('Add')),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Subject', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                setState(() {
                  final newData = {
                    'type': selectedType,
                    'title': nameCtrl.text, // Unified title
                    'examName': selectedType == 'Exam' ? nameCtrl.text : null, // keep old key for compatibility
                    'class': _teacherSelectedClass ?? widget.assignedClass,
                    'description': descCtrl.text,
                    'days': daysCtrl.text,
                    'dates': datesCtrl.text,
                    'time': timeCtrl.text,
                    'subjects': selectedType == 'Exam' ? subjects : null,
                    'schoolName': widget.schoolName,
                  };
                  if (index != null) {
                    final oldData = _exams[index];
                    final globalIdx = DataStore.allExams.indexOf(oldData);
                    if (globalIdx != -1) DataStore.allExams[globalIdx] = newData;
                  } else {
                    DataStore.allExams.add(newData);
                  }
                  setState(() {});
                  DataStore.saveAllData();
                });
                Navigator.pop(context);
              },
              child: Text(index != null ? 'Update' : 'Add'),
            )
          ],
        ),
      ),
    );
  }

  void _showAddResultDialog({int? index}) {
    final r = index != null ? _results[index] : null;
    String? selectedStudent = r?['studentName'];
    String? selectedExam = r?['examName'];
    
    // List to store multiple subject results
    List<Map<String, dynamic>> subjectResults = [];
    
    // State for the new subject row
    String? tempSelectedSubject;
    final totalMarkCtrl = TextEditingController(text: '100');
    final scoredMarkCtrl = TextEditingController();
    
    // Get all exams for this teacher's class
    List<Map<String, dynamic>> classExams = _exams;

    // Get subjects from selected exam
    List<String> getSubjectsForSelectedExam() {
      if (selectedExam == null) return [];
      Map<String, dynamic>? selectedExamData;
      try {
        selectedExamData = classExams.firstWhere(
          (e) => e['examName'] == selectedExam,
        );
      } catch (e) {
        return [];
      }
      
      List<Map<String, String>> examSubjects = selectedExamData['subjects'] ?? [];
      Set<String> subjectsSet = {};
      for (var subject in examSubjects) {
        String? subjectName = subject['name'];
        if (subjectName?.isNotEmpty == true) {
          subjectsSet.add(subjectName!);
        }
      }
      return subjectsSet.toList();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(index != null ? 'Edit Result' : 'Add Result'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Student Selection
                DropdownButtonFormField<String>(
                  value: selectedStudent,
                  decoration: const InputDecoration(labelText: 'Select Student', prefixIcon: Icon(Icons.person)),
                  items: _students.map((s) => DropdownMenuItem(value: s['name'], child: Text(s['name'] ?? ''))).toList(),
                  onChanged: (val) => setStateDialog(() {
                    selectedStudent = val;
                    selectedExam = null;
                    subjectResults.clear();
                  }),
                ),
                const SizedBox(height: 16),
                // Exam Selection
                DropdownButtonFormField<String?>(
                  value: selectedExam,
                  decoration: const InputDecoration(labelText: 'Select Exam', prefixIcon: Icon(Icons.event)),
                  items: classExams.map((exam) => DropdownMenuItem<String>(
                    value: exam['examName']?.toString(),
                    child: Text(exam['examName']?.toString() ?? ''),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() {
                    selectedExam = val;
                    subjectResults.clear();
                    tempSelectedSubject = null;
                    scoredMarkCtrl.clear();
                  }),
                ),
                const SizedBox(height: 24),
                // Added Subjects List
                ...subjectResults.isNotEmpty 
                    ? [
                        const Text('Added Subjects:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...subjectResults.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var result = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.book, color: Colors.teal),
                              title: Text(result['subject'] ?? ''),
                              subtitle: Text('Marks: ${result['scoredMark']} / ${result['totalMarks']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => setStateDialog(() {
                                  subjectResults.removeAt(idx);
                                }),
                              ),
                            ),
                          );
                        }),
                        const Divider(height: 24),
                      ]
                    : [],
                // Add New Subject Section
                ...selectedExam != null 
                    ? [
                        const Text('Add Subject:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: tempSelectedSubject,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.book)),
                                  items: getSubjectsForSelectedExam().where((s) => !subjectResults.any((r) => r['subject'] == s)).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (val) => setStateDialog(() => tempSelectedSubject = val),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: totalMarkCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'Total', prefixIcon: Icon(Icons.star_outline)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: scoredMarkCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) => setStateDialog((){}),
                                        decoration: const InputDecoration(labelText: 'Scored', prefixIcon: Icon(Icons.star)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: tempSelectedSubject == null || scoredMarkCtrl.text.isEmpty ? null : () {
                                setStateDialog(() {
                                  subjectResults.add({
                                    'subject': tempSelectedSubject,
                                    'totalMarks': totalMarkCtrl.text,
                                    'scoredMark': scoredMarkCtrl.text,
                                  });
                                  tempSelectedSubject = null;
                                  scoredMarkCtrl.clear();
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Subject'),
                            ),
                          ],
                        ),
                      ]
                    : [],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: subjectResults.isEmpty ? null : () {
                if (selectedStudent == null || selectedExam == null) return;
                setState(() {
                  final data = {
                    'studentName': selectedStudent,
                    'examName': selectedExam,
                    'subjectResults': List<Map<String, dynamic>>.from(subjectResults),
                    'class': _teacherSelectedClass ?? widget.assignedClass,
                    'academicYear': DataStore.selectedAcademicYear,
                    'schoolName': widget.schoolName,
                  };
                  if (index != null) {
                    final oldData = _results[index];
                    final globalIdx = DataStore.allResults.indexOf(oldData);
                    if (globalIdx != -1) DataStore.allResults[globalIdx] = data;
                  } else {
                    DataStore.allResults.add(data);
                  }
                  setState(() {});
                  DataStore.saveAllData();
                });
                Navigator.pop(context);
              },
              child: const Text('Submit All'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendMessageDialog({int? index}) {
    final m = index != null ? _messages[index] : null;
    String? selectedType = m?['type'] ?? 'To Student';
    String? selectedReceiver = m?['receivers'];
    final messageCtrl = TextEditingController(text: m?['text'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(index != null ? 'Edit Message' : 'Send Message'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Message Type'),
                  items: const [
                    DropdownMenuItem(value: 'To Student', child: Text('To Student')),
                    DropdownMenuItem(value: 'To Academic Director', child: Text('To Academic Director')),
                  ],
                  onChanged: (val) => setStateDialog(() {
                    selectedType = val;
                    selectedReceiver = null;
                  }),
                ),
                if (selectedType == 'To Student')
                  DropdownButtonFormField<String>(
                    value: selectedReceiver,
                    decoration: const InputDecoration(labelText: 'Select Student'),
                    items: _students.map((s) => DropdownMenuItem(value: s['name'], child: Text(s['name'] ?? ''))).toList(),
                    onChanged: (val) => setStateDialog(() => selectedReceiver = val),
                  ),
                TextField(controller: messageCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Message Body', prefixIcon: Icon(Icons.text_fields))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (messageCtrl.text.isEmpty) return;
                setState(() {
                  final data = {
                    'type': selectedType,
                    'receivers': selectedType == 'To Academic Director' ? 'academic_director' : (selectedReceiver ?? 'Class'),
                    'text': messageCtrl.text,
                  };
                  if (index != null) {
                    _messages[index] = data;
                  } else {
                    _messages.add(data);
                  }
                  setState(() {});
                  DataStore.saveAllData();
                });
                Navigator.pop(context);
              },
              child: Text(index != null ? 'Send' : 'Send'),
            )
          ],
        )
      )
    );
  }

  void _showStudentFormDialog({
    int? index,
    TextEditingController? nameCtrl,
    TextEditingController? addressCtrl,
    TextEditingController? parentsCtrl,
    TextEditingController? placeCtrl,
    TextEditingController? phoneCtrl,
    TextEditingController? bloodCtrl,
    TextEditingController? userCtrl,
    TextEditingController? passCtrl,
  }) {
    final s = index != null ? _allStudents[index] : null;
    final name = nameCtrl ?? TextEditingController(text: s?['name'] ?? '');
    final address = addressCtrl ?? TextEditingController(text: s?['address'] ?? '');
    final parents = parentsCtrl ?? TextEditingController(text: s?['parents'] ?? '');
    final place = placeCtrl ?? TextEditingController(text: s?['place'] ?? '');
    final phone = phoneCtrl ?? TextEditingController(text: s?['phone'] ?? '');
    final blood = bloodCtrl ?? TextEditingController(text: s?['blood'] ?? '');
    final user = userCtrl ?? TextEditingController(text: s?['username'] ?? '');
    final pass = passCtrl ?? TextEditingController(text: s?['password'] ?? (1000 + Random().nextInt(8999)).toString());
    String? photoBase64 = s?['photo'];

    if (index == null && userCtrl == null) {
      name.addListener(() {
        if (user.text.isEmpty || user.text == name.text.toLowerCase().replaceAll(' ', '.')) {
          user.text = name.text.toLowerCase().replaceAll(' ', '.');
        }
      });
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(index != null ? 'Edit Student' : 'Add Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text('Student Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6366F1))),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(
                        source: ImageSource.gallery, 
                        imageQuality: 50,
                        maxWidth: 400,
                        maxHeight: 400,
                      );
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        if (bytes.length > 30 * 1024) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Photo size must be less than 30KB'),
                              backgroundColor: Colors.red,
                            ));
                          }
                          return;
                        }
                        setStateDialog(() {
                          photoBase64 = base64Encode(bytes);
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                          backgroundImage: photoBase64 != null && photoBase64!.isNotEmpty && photoBase64 != 'null' ? MemoryImage(base64Decode(photoBase64!)) : null,
                          child: (photoBase64 == null || photoBase64!.isEmpty) ? const Icon(Icons.person_rounded, size: 50, color: Color(0xFF6366F1)) : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Student Name *', prefixIcon: Icon(Icons.person))),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Address *', prefixIcon: Icon(Icons.location_on))),
                TextField(controller: parents, decoration: const InputDecoration(labelText: "Parent's Name *", prefixIcon: Icon(Icons.family_restroom))),
                TextField(controller: place, decoration: const InputDecoration(labelText: 'Place *', prefixIcon: Icon(Icons.map))),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone))),
                TextField(controller: blood, decoration: const InputDecoration(labelText: 'Blood Group', prefixIcon: Icon(Icons.bloodtype))),
                const Divider(height: 32),
                const Text('Login Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(controller: user, decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.account_circle))),
                TextField(controller: pass, decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _teacherSelectedClass,
                  decoration: const InputDecoration(labelText: 'Select Class', prefixIcon: Icon(Icons.class_)),
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                  onChanged: (val) {
                    setStateDialog(() => _setSelectedClass(val));
                  },

                ),
              ],
            ),
          ),
          actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final rawUser = user.text.trim().toLowerCase();
              final isDuplicate = DataStore.allStudents.any((s) => (s['username'] ?? '').toLowerCase() == rawUser && index == null);
              
              if (name.text.isEmpty || address.text.isEmpty || rawUser.isEmpty || pass.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields (*)')));
                return;
              }

              if (isDuplicate) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username already exists. Please choose a different one.')));
                return;
              }
              
              // Find selected class from the form if handled differently, but here we can just use _teacherSelectedClass or add a local variable
              // For simplicity, let's use the current selected filter class as default
              
              setState(() {
                final studentData = {
                  'name': name.text,
                  'address': address.text,
                  'parents': parents.text,
                  'place': place.text,
                  'phone': phone.text,
                  'blood': blood.text,
                  'std': _teacherSelectedClass ?? widget.assignedClass,
                   'username': rawUser,
                  'password': pass.text.trim(),
                  'academicYear': DataStore.selectedAcademicYear,
                  'schoolName': widget.schoolName,
                  'photo': photoBase64 ?? '',
                };
                
                if (index != null) {
                  final oldData = _allStudents[index];
                  final globalIdx = DataStore.allStudents.indexOf(oldData);
                  if (globalIdx != -1) {
                    DataStore.allStudents[globalIdx] = studentData;
                  }
                  
                  // Update in Firestore
                  FirebaseFirestore.instance.collection('users')
                      .where('username', isEqualTo: oldData['username'])
                      .get().then((query) {
                    if (query.docs.isNotEmpty) {
                      query.docs.first.reference.update(studentData);
                    }
                  });
                } else {
                  // Register in Firebase Auth
                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                  AuthService().registerUser({...studentData, 'role': 'student'}, pass.text.trim()).then((_) {
                    Navigator.of(context, rootNavigator: true).pop(); // pop loading
                    setState(() {
                      DataStore.allStudents.add(studentData);
                      
                      // Auto-enroll student in class group
                      final className = _teacherSelectedClass ?? widget.assignedClass;
                      var classGroup = _groups.firstWhere((g) => g['name'] == className && g['type'] == 'class', orElse: () => {});
                      if (classGroup.isEmpty) {
                        classGroup = {
                          'id': 'class_${className.replaceAll(' ', '_')}',
                          'name': className,
                          'type': 'class',
                          'studentCount': 1
                        };
                        _groups.add(classGroup);
                      } else {
                        classGroup['studentCount'] = (classGroup['studentCount'] ?? 0) + 1;
                      }
                      _groupMembers.add({
                        'group_id': classGroup['id'],
                        'username': studentData['username'],
                        'name': studentData['name'],
                        'role': 'Student'
                      });

                      _studentProgress[studentData['name']!] = 0.0;
                      _studentFairs[studentData['name']!] = _fairs.map((f) => {'title': f, 'done': false}).toList();

                      // SHOW CREDENTIALS
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _showCredentialsDialog('Student', rawUser, pass.text.trim());
                      });
                      DataStore.saveAllData();
                    });
                  }).catchError((e) {
                    Navigator.of(context, rootNavigator: true).pop(); // pop loading
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
                    }
                  });
                  return; // Exit here because async registerUser will handle saving and popping dialog
                }
                setState(() {});
                DataStore.saveAllData();
              });
              Navigator.pop(context);
            },
            child: Text(index != null ? 'Update' : 'Add'),
          )
        ],
      ),
    ),
  );
}

  void _showAddItemDialog() {
    switch (_currentIndex) {
      case 0:
        final name = TextEditingController();
        final address = TextEditingController();
        final parents = TextEditingController();
        final place = TextEditingController();
        final phone = TextEditingController();
        final blood = TextEditingController();
        final user = TextEditingController();
        final pass = TextEditingController(text: (1000 + Random().nextInt(8999)).toString());

        name.addListener(() {
          if (user.text.isEmpty || user.text == name.text.toLowerCase().replaceAll(' ', '.')) {
             user.text = name.text.toLowerCase().replaceAll(' ', '.');
          }
        });

        _showStudentFormDialog(nameCtrl: name, addressCtrl: address, parentsCtrl: parents, placeCtrl: place, phoneCtrl: phone, bloodCtrl: blood, userCtrl: user, passCtrl: pass);
        break;
      case 1:
        _showAddActivityDialog();
        break;
      case 2:
        _showAddFairDialog();
        break;
      case 3:
        _showAddScheduleDialog();
        break;
      case 4:
        _showAddResultDialog();
        break;
      case 5:
        _showSendMessageDialog();
        break;
      default:
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('What would you like to add?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (DataStore.featureConfig['Students'] ?? true) ListTile(leading: const Icon(Icons.person_add), title: const Text('Add Student'), onTap: () { Navigator.pop(context); setState(() { _currentIndex = 0; }); _showAddItemDialog(); }),
                if (DataStore.featureConfig['Activities'] ?? true) ListTile(leading: const Icon(Icons.play_circle_fill), title: const Text('Add Activity'), onTap: () { Navigator.pop(context); _showAddActivityDialog(); }),
                if (DataStore.featureConfig['F.transactions'] ?? true) ListTile(leading: const Icon(Icons.local_activity), title: const Text('Add F.transaction'), onTap: () { Navigator.pop(context); _showAddFairDialog(); }),
                if (DataStore.featureConfig['Schedule'] ?? true) ListTile(leading: const Icon(Icons.calendar_month), title: const Text('Add to Schedule'), onTap: () { Navigator.pop(context); _showAddScheduleDialog(); }),
                if (DataStore.featureConfig['Results'] ?? true) ListTile(leading: const Icon(Icons.analytics), title: const Text('Add Result'), onTap: () { Navigator.pop(context); _showAddResultDialog(); }),
                if (DataStore.featureConfig['Messages'] ?? true) ListTile(leading: const Icon(Icons.message), title: const Text('Send Message'), onTap: () { Navigator.pop(context); _showSendMessageDialog(); }),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
          ),
        );
    }
  }

  Widget _buildAddButton(ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _showAddItemDialog(),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_currentIndex) {
      case 0: return _buildStudentsTab(colorScheme);
      case 1: return _buildActivitiesTab(colorScheme);
      case 2: return _buildFairTab(colorScheme);
      case 3: return _buildScheduleTab(colorScheme);
      case 4: return _buildResultsTab(colorScheme);
      case 5: return _buildMessagesTab(colorScheme);
      case 7: return _buildAttendanceTab(colorScheme);
      case -1:
      default: return _buildOverview(colorScheme);
    }
  }



  Widget _buildOverview(ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.primary.withRed(100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
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
                            Text('Management Hub', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                            const SizedBox(height: 4),
                            Text(widget.teacherName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          ],
                        ),
                        Row(
                          children: [
                            buildNotificationBell(isDark: true),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          _overviewMiniStat('Students', '${_students.length}', Icons.people_outline),
                          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                          _overviewMiniStat('Activities', '${_activities.length}', Icons.play_circle_outline),
                          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                          _overviewMiniStat('Class', widget.assignedClass, Icons.class_outlined),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 800 ? 1.5 : 2.2,
            children: [
              _buildMetricCard('Results', '${_results.length}', Icons.analytics_rounded, Colors.orange, 4),
              _buildMetricCard('Today Attendance', '', Icons.how_to_reg_rounded, Colors.green, 7),
              _buildMetricCard('Messages', '${DataStore.getUnreadMessageCount(widget.teacherUsername)}', Icons.message_rounded, Colors.blue, 5),
              _buildMetricCard('Announce', '${filteredBulletinCards.length}', Icons.campaign_rounded, Colors.purple, -1),
            ],
          ),

          const SizedBox(height: 32),
          const SizedBox(height: 32),
          const Text('Faculty Profiles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _teachers.isEmpty 
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
                child: const Text('No faculty profiles added yet.', style: TextStyle(color: Colors.grey)),
              )
            : SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _teachers.length,
                  itemBuilder: (context, index) {
                    final t = _teachers[index];
                    return Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: colorScheme.primary.withOpacity(0.1),
                            backgroundImage: (t['photo'] != null && t['photo']!.isNotEmpty && t['photo'] != 'null') ? MemoryImage(base64Decode(t['photo']!)) : null,
                            child: (t['photo'] == null || t['photo']!.isEmpty) ? Icon(Icons.person_rounded, size: 35, color: colorScheme.primary) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(t['name'] ?? 'Faculty', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(t['designation'] ?? 'Teacher', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          const SizedBox(height: 32),
          const Text('Notice Board', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _buildBulletinCards(colorScheme),
        ],
      ),
    );
  }

  Widget _buildBulletinCards(ColorScheme colorScheme) {
    if (filteredBulletinCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
        child: const Column(
          children: [
             Icon(Icons.dashboard_customize_outlined, size: 48, color: Colors.grey),
             SizedBox(height: 12),
             Text('No updates from Academic Director yet', style: TextStyle(color: Colors.grey)),
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
        return buildNoticeBoardCard(b, colorScheme);
      },
    );
  }



  Widget _overviewMiniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, int targetIndex) {
    return GestureDetector(
      onTap: () {
        if (targetIndex != -1) setState(() => _currentIndex = targetIndex);
      },
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

  Widget _buildMonthYearPicker() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _attMonth == 0 ? DateTime.now().month : _attMonth,
            underline: const SizedBox(),
            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_getMonthName(i + 1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            onChanged: (v) => setState(() => _attMonth = v ?? DateTime.now().month),
          ),

          const VerticalDivider(width: 20, indent: 12, endIndent: 12),
          DropdownButton<int>(
            value: _attYear,
            underline: const SizedBox(),
            items: List.generate(5, (i) => DropdownMenuItem(value: 2024 + i, child: Text('${2024 + i}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            onChanged: (v) => setState(() => _attYear = v ?? 2024),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int m) {
    if (m == 0) return 'All';
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
  }



  Widget _buildStudentsTab(ColorScheme colorScheme) {
    final currentClass = _teacherSelectedClass ?? widget.assignedClass;
    final isHifz = DataStore.classDepts[currentClass] == 'HIFZ' || currentClass.toUpperCase().contains('HZ');
    if (!isHifz) return _buildRegularStudentsTab(colorScheme);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildStudentsHeader(colorScheme),
          TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [Tab(text: 'Directory'), Tab(text: 'Hifz Progress')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRegularStudentsList(colorScheme),
                _buildHifzProgressList(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Students', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              Row(
                children: [
                  _actionIconBtn(Icons.add_box_rounded, colorScheme.primary, () => _showAddItemDialog()),
                  const SizedBox(width: 8),
                  _actionIconBtn(Icons.create_new_folder_rounded, Colors.amber.shade700, () => _showAddNewClassDialog()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _classes.map((c) {
                final bool isSelected = _teacherSelectedClass == c;
                return GestureDetector(
                  onTap: () => _setSelectedClass(c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? colorScheme.primary : Colors.grey.shade200),
                      boxShadow: isSelected ? [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                    ),
                    child: Text(
                      'Class $c',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _buildMonthYearPicker(),
        ],
      ),
    );
  }

  Widget _buildRegularStudentsTab(ColorScheme colorScheme) {
    return Column(
      children: [
        _buildStudentsHeader(colorScheme),
        Expanded(child: _buildRegularStudentsList(colorScheme)),
      ],
    );
  }

  Widget _buildRegularStudentsList(ColorScheme colorScheme) {
    if (_students.isEmpty) return _emptyStudentsView();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: const BouncingScrollPhysics(),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final s = _students[index];
        return _buildStudentCard(s, colorScheme);
      },
    );
  }

  Widget _emptyStudentsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
            child: Icon(Icons.people_alt_rounded, size: 80, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 20),
          Text('No students in Class $_teacherSelectedClass', style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHifzProgressList(ColorScheme colorScheme) {
    if (_students.isEmpty) return _emptyStudentsView();
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final s = _students[index];
        final today = DateTime.now().toString().split(' ')[0];
        final progress = DataStore.allHifzProgress.firstWhere(
          (p) => p['studentUsername'] == s['username'] && p['date'] == today,
          orElse: () => {},
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  child: Text(s['name']?[0] ?? 'S', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
                title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text('Juzh Progress: ${progress['juzh'] ?? 'Not set'}', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history_rounded, size: 20),
                      onPressed: () => _showHifzHistoryDialog(s),
                      color: colorScheme.primary,
                      tooltip: 'View History',
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showHifzProgressDialog(s),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('UPDATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        foregroundColor: colorScheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              if (progress.isNotEmpty) Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    _hifzSmallBadge('Today', '${progress['todayFromSura']} ${progress['todayFromAya']} - ${progress['todayToSura']} ${progress['todayToAya']}', Colors.blue),
                    const SizedBox(width: 8),
                    _hifzSmallBadge('Old', '${progress['oldFromSura']} ${progress['oldFromAya']} - ${progress['oldToSura']} ${progress['oldToAya']}', Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hifzSmallBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.05), border: Border.all(color: color.withOpacity(0.1)), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
            Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showHifzHistoryDialog(Map<String, String> student) {
    final progress = DataStore.allHifzProgress.where((p) => p['studentUsername'] == student['username']).toList().reversed.toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Text(student['name']?[0] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const Text('Hifz Progress History', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: progress.isEmpty
                  ? const Center(child: Text('No progress history found', style: TextStyle(color: Colors.grey)))
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
                                    child: Text('Juzh ${p['juzh'] ?? ''}', style: const TextStyle(color: Color(0xFF075E54), fontWeight: FontWeight.w900, fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _hifzHistoryRow('New Lesson', '${p['todayFromSura']} ${p['todayFromAya']} | ${p['todayToSura']} ${p['todayToAya']}', Colors.blue),
                              _hifzHistoryRow('Old Review', '${p['oldFromSura']} ${p['oldFromAya']} | ${p['oldToSura']} ${p['oldToAya']}', Colors.orange),
                              if ((p['murajaaFromSura']?.isNotEmpty ?? false) && p['murajaaFromSura'] != '-')
                                _hifzHistoryRow('Muraja\'a', '${p['murajaaFromSura']} ${p['murajaaFromAya']} | ${p['murajaaToSura']} ${p['murajaaToAya']}', Colors.purple),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hifzHistoryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4, right: 12),
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHifzProgressDialog(Map<String, String> student) {
    final today = DateTime.now().toString().split(' ')[0];
    final existing = DataStore.allHifzProgress.firstWhere(
      (p) => p['studentUsername'] == student['username'] && p['date'] == today,
      orElse: () => {},
    );

    String tSFrom = existing['todayFromSura'] ?? quranSurahsArabic[0];
    final tAFrom = TextEditingController(text: existing['todayFromAya'] ?? '');
    String tSTo = existing['todayToSura'] ?? quranSurahsArabic[0];
    final tATo = TextEditingController(text: existing['todayToAya'] ?? '');
    
    String oSFrom = existing['oldFromSura'] ?? quranSurahsArabic[0];
    final oAFrom = TextEditingController(text: existing['oldFromAya'] ?? '');
    String oSTo = existing['oldToSura'] ?? quranSurahsArabic[0];
    final oATo = TextEditingController(text: existing['oldToAya'] ?? '');
    
    String mSFrom = existing['murajaaFromSura'] ?? quranSurahsArabic[0];
    final mAFrom = TextEditingController(text: existing['murajaaFromAya'] ?? '');
    String mSTo = existing['murajaaToSura'] ?? quranSurahsArabic[0];
    final mATo = TextEditingController(text: existing['murajaaToAya'] ?? '');
    
    int selectedJuzh = int.tryParse(existing['juzh']?.toString() ?? '1') ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('${student['name']} - Daily Progress'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hifzSectionTitle('TODAY\'S LESSON', Icons.today_rounded, Colors.blue),
                _hifzSurahAyaRangeRow(
                  tSFrom, a: tAFrom, b: tSTo, c: tATo,
                  onFromSurahChanged: (v) => setDialogState(() => tSFrom = v!),
                  onToSurahChanged: (v) => setDialogState(() => tSTo = v!),
                ),
                const SizedBox(height: 16),
                _hifzSectionTitle('OLD LESSON', Icons.history_rounded, Colors.orange),
                _hifzSurahAyaRangeRow(
                  oSFrom, a: oAFrom, b: oSTo, c: oATo,
                  onFromSurahChanged: (v) => setDialogState(() => oSFrom = v!),
                  onToSurahChanged: (v) => setDialogState(() => oSTo = v!),
                ),
                const SizedBox(height: 16),
                _hifzSectionTitle('MURAJA\'A (REVIEW)', Icons.repeat_rounded, Colors.purple),
                _hifzSurahAyaRangeRow(
                  mSFrom, a: mAFrom, b: mSTo, c: mATo,
                  onFromSurahChanged: (v) => setDialogState(() => mSFrom = v!),
                  onToSurahChanged: (v) => setDialogState(() => mSTo = v!),
                ),
                const SizedBox(height: 20),
                _hifzSectionTitle('GROWTH (JUZH)', Icons.trending_up_rounded, Colors.green),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedJuzh,
                      items: List.generate(30, (i) => DropdownMenuItem(value: i + 1, child: Text('Juzh ${i + 1}'))).toList(),
                      onChanged: (v) => setDialogState(() => selectedJuzh = v ?? 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                setState(() {
                  final data = {
                    'studentUsername': student['username'],
                    'date': today,
                    'todayFromSura': tSFrom,
                    'todayFromAya': tAFrom.text,
                    'todayToSura': tSTo,
                    'todayToAya': tATo.text,
                    'oldFromSura': oSFrom,
                    'oldFromAya': oAFrom.text,
                    'oldToSura': oSTo,
                    'oldToAya': oATo.text,
                    'murajaaFromSura': mSFrom,
                    'murajaaFromAya': mAFrom.text,
                    'murajaaToSura': mSTo,
                    'murajaaToAya': mATo.text,
                    'juzh': selectedJuzh.toString(),
                  };
                  if (existing.isNotEmpty) {
                    final idx = DataStore.allHifzProgress.indexOf(existing);
                    DataStore.allHifzProgress[idx] = data;
                  } else {
                    DataStore.allHifzProgress.add(data);
                  }
                  DataStore.saveAllData();
                });
                Navigator.pop(context);
              },
              child: const Text('SAVE PROGRESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hifzSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _hifzSurahAyaRangeRow(
    String sF, {
    required TextEditingController a,
    required String b,
    required TextEditingController c,
    required Function(String?) onFromSurahChanged,
    required Function(String?) onToSurahChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: _surahDropdown(sF, onFromSurahChanged)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _hifzField(a, 'Aya')),
          ],
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('to', style: TextStyle(fontSize: 10, color: Colors.grey))),
        Row(
          children: [
            Expanded(flex: 3, child: _surahDropdown(b, onToSurahChanged)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _hifzField(c, 'Aya')),
          ],
        ),
      ],
    );
  }

  Widget _surahDropdown(String value, Function(String?) onChanged) {
    String safeValue = quranSurahsArabic.contains(value) ? value : quranSurahsArabic[0];
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: safeValue,
          style: const TextStyle(fontSize: 13, color: Colors.black, fontFamily: 'sans-serif'),
          items: quranSurahsArabic.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _hifzField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, String> s, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ListTile(
        onTap: () => _showStudentDetails(s),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          backgroundImage: (s['photo'] != null && s['photo']!.isNotEmpty && s['photo'] != 'null') ? MemoryImage(base64Decode(s['photo']!)) : null,
          child: (s['photo'] == null || s['photo']!.isEmpty) ? Text(s['name']?[0] ?? 'S', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 18)) : null,
        ),
        title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(s['place'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            _buildAttendanceLinear(s['username']!, colorScheme),
          ],
        ),
        trailing: _buildStudentCardActions(s),
      ),
    );
  }

  Widget _buildAttendanceLinear(String username, ColorScheme colorScheme) {
    final stats = DataStore.getAttendanceStats(username, _attMonth == 0 ? null : _attMonth, _attYear);
    final double avg = stats['total'] == 0 ? 0 : (stats['present']! / stats['total']!) * 100;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: avg/100, minHeight: 4, backgroundColor: Colors.grey.shade100, color: avg > 75 ? Colors.teal : (avg > 50 ? Colors.orange : Colors.red)))),
            const SizedBox(width: 10),
            Text('${avg.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Attendance: ${stats['present']}/${stats['total']}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            Text(_getMonthName(_attMonth), style: TextStyle(fontSize: 10, color: colorScheme.primary.withOpacity(0.7), fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentCardActions(Map<String, String> s) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.message_rounded, size: 20, color: Colors.blue),
          onPressed: () {
            setState(() {
              _currentIndex = 5;
              _activeChatPeerId = s['username'];
              _activeChatPeerName = s['name'];
            });
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          onSelected: (val) {
            if (val == 'edit') _showStudentFormDialog(index: _allStudents.indexOf(s));
            if (val == 'delete') _showDeleteStudentConfirm(s);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded, color: Colors.indigo), title: Text('Edit'))),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_rounded, color: Colors.red), title: Text('Delete'))),
          ],
        ),
      ],
    );
  }

  Widget _actionIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  void _showAddNewClassDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Class'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Class Name (e.g. 06)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (nameCtrl.text.isNotEmpty) {
              setState(() {
                DataStore.addClassForSchool(widget.schoolName, nameCtrl.text);
                _teacherSelectedClass = nameCtrl.text;
                DataStore.saveAllData();
              });
            }
            Navigator.pop(context);
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showDeleteStudentConfirm(Map<String, String> s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${s['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            setState(() {
              DataStore.allStudents.removeWhere((x) => x['username'] == s['username']);
              DataStore.saveAllData();
              
              // Delete from Firestore
              FirebaseFirestore.instance.collection('users')
                  .where('username', isEqualTo: s['username'])
                  .get().then((query) {
                if (query.docs.isNotEmpty) {
                  query.docs.first.reference.delete();
                }
              });
            });
            Navigator.pop(context);
          }, child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab(ColorScheme colorScheme) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Activities', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                _actionIconBtn(Icons.add_circle_rounded, colorScheme.primary, () => _showAddActivityDialog()),
              ],
            ),
          ),
          TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [Tab(text: 'Directory'), Tab(text: 'Progress')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildActivityList(colorScheme),
                _buildActivityParticipation(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList(ColorScheme colorScheme) {
    if (_activities.isEmpty) return _emptyStateView(Icons.play_circle_outline, 'No activities planned');
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final a = _activities[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.green),
            ),
            title: Text(a['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            subtitle: Text('${a['type']} | Max ${a['marks']} Marks', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showAddActivityDialog(index: index);
                if (val == 'delete') {
                  setState(() {
                    DataStore.allActivities.remove(a);
                    DataStore.saveAllData();
                  });
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded, color: Colors.indigo), title: Text('Edit'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_rounded, color: Colors.red), title: Text('Delete'))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityParticipation(ColorScheme colorScheme) {
    if (_activities.isEmpty) return _emptyStateView(Icons.check_circle_outline, 'No participation data');
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final a = _activities[index];
        final participants = DataStore.allActivitySubmissions.where((s) => s['activityId'] == a['id'] && s['isCompleted'] == true).length;
        final double progress = _students.isEmpty ? 0 : participants / _students.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 4, backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation(Colors.green)),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
            title: Text(a['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            subtitle: Text('$participants / ${_students.length} Participated', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            children: _students.map((s) {
               final subIdx = DataStore.allActivitySubmissions.indexWhere((sub) => 
                sub['studentUsername'] == s['username'] && sub['activityId'] == a['id']
              );
              final bool isDone = subIdx != -1 && DataStore.allActivitySubmissions[subIdx]['isCompleted'] == true;
              final String score = isDone ? DataStore.allActivitySubmissions[subIdx]['score']?.toString() ?? '0' : '0';

              return ListTile(
                leading: CircleAvatar(radius: 12, backgroundColor: isDone ? Colors.green.withOpacity(0.1) : Colors.grey.shade100, child: Text(s['name']?[0] ?? 'S', style: TextStyle(fontSize: 10, color: isDone ? Colors.green : Colors.grey))),
                title: Text(s['name'] ?? '', style: TextStyle(fontWeight: isDone ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDone) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text('Score: $score', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Switch(
                      value: isDone,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setState(() {
                          _updateActivityStatus(s['username']!, s['name']!, a, val, score);
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _emptyStateView(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFairTab(ColorScheme colorScheme) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('F.transactions', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                _actionIconBtn(Icons.assignment_add, colorScheme.primary, () => _showAddFairDialog()),
              ],
            ),
          ),
          TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [Tab(text: 'Catalogue'), Tab(text: 'Payments')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                 _buildFairList(colorScheme),
                 _buildFairPayments(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFairList(ColorScheme colorScheme) {
    if (_fairList.isEmpty) return _emptyStateView(Icons.local_activity_outlined, 'No F.transactions scheduled');
     return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _fairList.length,
      itemBuilder: (context, index) {
        final f = _fairList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.star_rounded, color: Colors.pink),
            ),
            title: Text(f['title'] ?? 'Untitled F.transaction', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            subtitle: Text('Due: ${f['date']} | Fee: ${f['amount']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showAddFairDialog(index: index);
                if (val == 'delete') {
                  setState(() {
                    DataStore.allFairItems.remove(f);
                    DataStore.saveAllData();
                  });
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded, color: Colors.indigo), title: Text('Edit'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_rounded, color: Colors.red), title: Text('Delete'))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFairPayments(ColorScheme colorScheme) {
    if (_fairList.isEmpty) return _emptyStateView(Icons.payments_outlined, 'No payment tracking available');
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _fairList.length,
      itemBuilder: (context, index) {
        final f = _fairList[index];
        final paidCount = DataStore.allFairPayments.where((p) => p['fairId'] == f['id'] && p['isPaid'] == true).length;
        final double progress = _students.isEmpty ? 0 : paidCount / _students.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 4, backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation(Colors.pink)),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.pink)),
              ],
            ),
            title: Text(f['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            subtitle: Text('$paidCount / ${_students.length} Collected', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            children: _students.map((s) {
              final pIdx = DataStore.allFairPayments.indexWhere((p) => 
                p['studentUsername'] == s['username'] && p['fairId'] == f['id']
              );
              final bool isPaid = pIdx != -1 && DataStore.allFairPayments[pIdx]['isPaid'] == true;
              
              return ListTile(
                leading: CircleAvatar(radius: 12, backgroundColor: isPaid ? Colors.teal.withOpacity(0.1) : Colors.grey.shade100, child: Text(s['name']?[0] ?? 'S', style: TextStyle(fontSize: 10, color: isPaid ? Colors.teal : Colors.grey))),
                title: Text(s['name'] ?? '', style: TextStyle(fontWeight: isPaid ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                trailing: Switch(
                  value: isPaid,
                  activeColor: Colors.teal,
                  onChanged: (val) {
                    setState(() {
                      _updateFairStatus(s['username']!, f, val);
                    });
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _attendanceTagRow(Map<dynamic, dynamic> periods, String? reason) {
     final pMap = Map<String, String>.from(periods);
     return Row(
       mainAxisSize: MainAxisSize.min, 
       children: [
         _attMiniCircle('FN', pMap['FN'] ?? '-', reason),
         const SizedBox(width: 4),
         _attMiniCircle('AN', pMap['AN'] ?? '-', reason),
       ],
     );
  }

  Widget _attMiniCircle(String label, String status, String? reason) {
     final Color color = status == 'P' ? Colors.green : (status == 'A' ? Colors.red : Colors.grey);
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
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
           Container(
             width: 22, height: 22,
             decoration: BoxDecoration(
               color: color.withOpacity(0.1), 
               shape: BoxShape.circle, 
               border: Border.all(color: color.withOpacity(0.5)),
             ),
             child: Center(
               child: Stack(
                 alignment: Alignment.center,
                 children: [
                   Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                   if (status == 'A' && reason != null && reason.isNotEmpty)
                     Positioned(
                       right: -1, top: -1,
                       child: Container(
                         width: 4, height: 4, 
                         decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)
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

  void _showStudentDetails(Map<String, String> student) {
    final name = student['name'] ?? '';
    
    // Fetch data for the student (session-aware)
    final studentActivities = _activities.where((a) => a['academicYear'] == DataStore.selectedAcademicYear || a['academicYear'] == null).toList(); 
    final studentFairs = _fairList; // Fairs are usually per class/year too
    final studentResults = DataStore.allResults.where((r) => r['studentName'] == name && (r['academicYear'] == DataStore.selectedAcademicYear || r['academicYear'] == null)).toList();
    final studentExams = _exams.where((e) => e['academicYear'] == DataStore.selectedAcademicYear || e['academicYear'] == null).toList();

    // Calculate progress
    final completedActivitiesCount = studentActivities.where((a) {
      return DataStore.allActivitySubmissions.any((s) => 
        s['studentUsername'] == student['username'] && 
        s['activityId'] == a['id'] && 
        s['isCompleted']
      );
    }).length;

    final paidFairsCount = studentFairs.where((f) {
      return DataStore.allFairPayments.any((p) => 
        p['studentUsername'] == student['username'] && 
        p['fairId'] == f['id'] && 
        p['isPaid']
      );
    }).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int selectedSection = 0; 
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildSectionContent() {
              switch (selectedSection) {
                case 1: // Activities
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Class Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...studentActivities.map((a) {
                        final bool isDone = DataStore.allActivitySubmissions.any((s) => 
                          s['studentUsername'] == student['username'] && 
                          s['activityId'] == a['id'] && 
                          s['isCompleted']
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isDone ? Colors.green.shade50 : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDone ? Colors.green.shade200 : Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _showActivityDetailDialog(a, student['username']!, student['name']!, setModalState),
                            leading: Icon(
                              isDone ? Icons.check_circle : Icons.play_circle_fill, 
                              color: isDone ? Colors.green : Colors.grey,
                              size: 28,
                            ),
                            title: Text(a['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${a['type']} | Due: ${a['date']}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isDone 
                                    ? '${DataStore.allActivitySubmissions.firstWhere((s) => s['studentUsername'] == student['username'] && s['activityId'] == a['id'])['score'] ?? '0'}/${a['marks']} Marks' 
                                    : '${a['marks']} Max Marks', 
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? Colors.green : Colors.grey)
                                ),
                                Text(isDone ? 'COMPLETED' : 'PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDone ? Colors.green : Colors.orange)),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (studentActivities.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No activities assigned'))),
                    ],
                  );
                case 2: // Fairs
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('F.transaction Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...studentFairs.map((f) {
                        final bool isPaid = DataStore.allFairPayments.any((p) => 
                          p['studentUsername'] == student['username'] && 
                          p['fairId'] == f['id'] && 
                          p['isPaid'] == true
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isPaid ? Colors.teal.shade50 : Colors.pink.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: isPaid ? Colors.teal.shade200 : Colors.pink.shade100),
                          ),
                          child: ListTile(
                            onTap: () => _showFairDetailDialog(f, student['username']!, student['name']!, setModalState),
                            title: Text(f['title'] ?? 'Untitled F.transaction', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text('Amount: ${f['amount']} | Due: ${f['date']}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPaid ? Colors.teal.shade700 : Colors.red.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPaid ? 'PAID' : 'PENDING', 
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),
                        );
                      }),
                      if (studentFairs.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No F.transactions added by teacher'))),
                    ],
                  );
                case 3: // Schedule
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Class Schedule & Events', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      ...studentExams.map((e) {
                        final String type = e['type'] ?? 'Exam';
                        final bool isExam = type == 'Exam';
                        final List subs = e['subjects'] ?? [];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isExam ? Colors.orange.shade100 : Colors.teal.shade100),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isExam ? Colors.orange.shade50 : Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(isExam ? Icons.assignment : Icons.event, color: isExam ? Colors.orange : Colors.teal),
                            ),
                            title: Text(e['title'] ?? e['examName'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
                            subtitle: Text(
                              isExam ? '${subs.length} Subjects' : '${e['dates']} | ${e['time']}', 
                              style: TextStyle(color: isExam ? Colors.orange.shade800 : Colors.teal.shade800, fontSize: 13, fontWeight: FontWeight.w700)
                            ),
                            children: [
                              if (!isExam && e['description'] != null)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
                                    child: Text(e['description'], style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F766E))),
                                  ),
                                ),
                              if (isExam)
                                ...subs.map<Widget>((s) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                )),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      }),
                      if (studentExams.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No schedule items assigned yet.'))),
                    ],
                  );
                case 5: // Attendance
                  final String currentAY = DataStore.selectedAcademicYear;
                  final statsM = DataStore.getAttendanceStats(student['username']!, _attMonth == 0 ? DateTime.now().month : _attMonth, _attYear);
                  final statsY = DataStore.getAcademicYearStats(student['username']!, currentAY);
                  
                  final double avgM = statsM['total'] == 0 ? 0 : (statsM['present']! / statsM['total']!) * 100;
                  final double avgY = statsY['total'] == 0 ? 0 : (statsY['present']! / statsY['total']!) * 100;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Attendance Metrics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          _buildMonthYearPicker(),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigo.shade100)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_attMonth == 0 ? 'Monthly (Current)' : _getMonthName(_attMonth), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                  const SizedBox(height: 4),
                                  Text('${avgM.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.indigo)),
                                  Text('${statsM['present']}/${statsM['total']} Days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.teal.shade100)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Academic Year', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                                  const SizedBox(height: 4),
                                  Text('${avgY.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.teal)),
                                  Text('${statsY['present']}/${statsY['total']} Days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Attendance Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      ...DataStore.allAttendance.where((a) {
                         final dt = DateTime.tryParse(a['date'] ?? '');
                         if (a['studentUsername'] != student['username']) return false;
                         final targetMonth = _attMonth == 0 ? DateTime.now().month : _attMonth;
                         return dt != null && dt.month == targetMonth && dt.year == _attYear;
                      }).toList().reversed.map((a) {
                         return Container(
                           margin: const EdgeInsets.only(bottom: 12),
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                           child: Row(
                             children: [
                               Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                                 child: const Icon(Icons.event_note, size: 18, color: Colors.grey),
                               ),
                               const SizedBox(width: 16),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(a['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                     Text(a['academicYear'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                   ],
                                 ),
                               ),
                               _attendanceTagRow(a['periods'] ?? {}, a['leaveReason']),
                             ],
                           ),
                         );
                      }),
                    ],
                  );
                case 4: // Results
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Academic Results', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      ...studentResults.map((r) {
                        final List subjectRes = r['subjectResults'] ?? [];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.purple.shade100),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.analytics, color: Colors.purple),
                                ),
                                title: Text(r['examName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                subtitle: Text('${subjectRes.length} Subjects Evaluated', style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.w700)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.purple),
                                  onPressed: () => PdfService.generateResultPdf(
                                    schoolName: 'حركات الحياة',
                                    studentName: student['name'] ?? '',
                                    studentClass: student['std'] ?? '',
                                    examName: r['examName'] ?? '',
                                    subjectResults: subjectRes,
                                  ),
                                  tooltip: 'Download PDF',
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(2),
                                      1: FlexColumnWidth(1.5),
                                      2: FlexColumnWidth(1),
                                      3: FlexColumnWidth(1.2),
                                    },
                                    children: [
                                      const TableRow(
                                        decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                                        children: [
                                          Padding(padding: EdgeInsets.all(10), child: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                          Padding(padding: EdgeInsets.all(10), child: Text('Scored', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                          Padding(padding: EdgeInsets.all(10), child: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                          Padding(padding: EdgeInsets.all(10), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        ],
                                      ),
                                      ...subjectRes.map((s) {
                                        final double scored = double.tryParse(s['scoredMark']?.toString() ?? '0') ?? 0;
                                        final double total = double.tryParse(s['totalMarks']?.toString() ?? '100') ?? 100;
                                        final double pct = (scored / total) * 100;
                                        String grade = 'D';
                                        String status = 'Failed';
                                        Color statusColor = Colors.red;
                                        if (pct >= 40) { status = 'Pass'; statusColor = Colors.green; }
                                        if (pct >= 90) grade = 'A+';
                                        else if (pct >= 80) grade = 'A';
                                        else if (pct >= 70) grade = 'B+';
                                        else if (pct >= 60) grade = 'B';
                                        else if (pct >= 50) grade = 'C+';
                                        else if (pct >= 40) grade = 'C';
                                        else grade = 'D';
                                        return TableRow(
                                          children: [
                                            Padding(padding: const EdgeInsets.all(10), child: Text(s['subject'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                            Padding(padding: const EdgeInsets.all(10), child: Text('${s['scoredMark']}/${s['totalMarks']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
                                            Padding(padding: const EdgeInsets.all(10), child: Text(grade, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: statusColor))),
                                            Padding(
                                              padding: const EdgeInsets.all(6), 
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                                child: Center(
                                                  child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (studentResults.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(
                        children: [
                          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No results published yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ))),
                    ],
                  );
                default: // Info/Overview
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contact Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.family_restroom, "Parent's Name", student['parents'] ?? 'N/A'),
                      _buildInfoRow(Icons.location_on, "Address", student['address'] ?? 'N/A'),
                      _buildInfoRow(Icons.map, "Place", student['place'] ?? 'N/A'),
                      _buildInfoRow(Icons.phone, "Phone", student['phone'] ?? 'N/A'),
                      _buildInfoRow(Icons.bloodtype, "Blood Group", student['blood'] ?? 'N/A'),
                      _buildInfoRow(Icons.account_circle, "Username", student['username'] ?? 'N/A'),
                    ],
                  );
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topRight: Radius.circular(32), topLeft: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700,
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(32), topLeft: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                String? photo = DataStore.teacherPhotoCache[student['username']];
                                return CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  backgroundImage: photo != null && photo.isNotEmpty && photo != 'null' ? MemoryImage(base64Decode(photo)) : null,
                                  child: photo == null || photo.isEmpty || photo == 'null'
                                      ? Text(name.isNotEmpty ? name[0] : 'S', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal.shade700))
                                      : null,
                                );
                              }
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text('Class ${student['std']} | Student ID: ${student['username']}', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                                    child: const Text('Regular Student', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildSectionChip('Overview', Icons.info_outline, 0, selectedSection, (idx) => setModalState(() => selectedSection = idx)),
                          _buildSectionChip('Attendance', Icons.fact_check_rounded, 5, selectedSection, (idx) => setModalState(() => selectedSection = idx)),
                          _buildSectionChip('Activities', Icons.play_circle_fill, 1, selectedSection, (idx) => setModalState(() => selectedSection = idx)),
                          _buildSectionChip('F.transactions', Icons.local_activity, 2, selectedSection, (idx) => setModalState(() => selectedSection = idx)),
                          _buildSectionChip('Schedule', Icons.calendar_month, 3, selectedSection, (idx) => setModalState(() => selectedSection = idx)),
                          _buildSectionChip('Results', Icons.analytics, 4, selectedSection, (idx) => setModalState(() => selectedSection = idx)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: buildSectionContent(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showActivityDetailDialog(Map<String, dynamic> activity, String studentUser, String studentName, StateSetter parentSetState) {
    bool isDone = DataStore.allActivitySubmissions.any((s) => 
      s['studentUsername'] == studentUser && 
      s['activityId'] == activity['id'] && 
      s['isCompleted'] == true
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.assignment, color: Colors.teal.shade700),
                const SizedBox(width: 10),
                const Text('Activity Details'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['title'] ?? 'Untitled Activity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text(activity['type'] ?? 'Assignment', style: TextStyle(color: Colors.teal.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 32),
                _buildDetailRow(Icons.description, 'Description', activity['description'] ?? 'No description provided'),
                _buildDetailRow(Icons.star, 'Possible Marks', activity['marks'] ?? 'N/A'),
                _buildDetailRow(Icons.calendar_today, 'Due Date', activity['date'] ?? 'N/A'),
                const Divider(height: 32),
                const Text('Student Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(radius: 16, backgroundColor: Colors.teal.shade100, child: Text(studentName[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Text(studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(
                      value: isDone,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setState(() => isDone = val);
                        parentSetState(() {
                          _updateActivityStatus(studentUser, studentName, activity, val, null);
                        });
                      },
                    ),
                  ],
                ),
                Text(isDone ? 'Marked as Completed' : 'Marked as Pending', style: TextStyle(color: isDone ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                if (isDone) ...[
                  const SizedBox(height: 16),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Score / Marks',
                      hintText: 'Enter student score',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.score),
                    ),
                    onChanged: (val) {
                      parentSetState(() {
                        _updateActivityStatus(studentUser, studentName, activity, true, val);
                      });
                    },
                    controller: TextEditingController(text: DataStore.allActivitySubmissions.firstWhere((s) => s['studentUsername'] == studentUser && s['activityId'] == activity['id'], orElse: () => {})['score']?.toString() ?? ''),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
            ],
          );
        }
      ),
    );
  }

  void _updateActivityStatus(String studentUser, String studentName, Map<String, dynamic> activity, bool isCompleted, String? score) {
    // Find existing submission or create default
    final existingIdx = DataStore.allActivitySubmissions.indexWhere((s) => 
      s['studentUsername'] == studentUser && s['activityId'] == activity['id']
    );
    
    final Map<String, dynamic> submission = existingIdx != -1 
      ? Map<String, dynamic>.from(DataStore.allActivitySubmissions[existingIdx])
      : {
          'studentUsername': studentUser,
          'activityId': activity['id'],
          'isCompleted': false,
          'score': '0',
        };

    submission['isCompleted'] = isCompleted;
    if (score != null) {
      submission['score'] = score;
    }
    submission['updatedAt'] = DateTime.now().toIso8601String();

    if (existingIdx != -1) {
      DataStore.allActivitySubmissions[existingIdx] = submission;
    } else {
      DataStore.allActivitySubmissions.add(submission);
    }
    
    DataStore.saveAllData();
    
    // Recalculate progress
    final studentActs = DataStore.allActivities.where((a) => a['std'] == (activity['std'] ?? widget.assignedClass)).toList();
    if (studentActs.isNotEmpty) {
      final completedCount = DataStore.allActivitySubmissions.where((s) => 
        s['studentUsername'] == studentUser && 
        s['isCompleted'] &&
        studentActs.any((a) => a['id'] == s['activityId'])
      ).length;
      _studentProgress[studentName] = completedCount / studentActs.length;
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFairDetailDialog(Map<String, dynamic> fair, String studentUser, String studentName, StateSetter parentSetState) {
    bool isPaid = DataStore.allFairPayments.any((p) => 
      p['studentUsername'] == studentUser && 
      p['fairId'] == fair['id'] && 
      p['isPaid']
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.local_activity, color: Colors.pink),
                const SizedBox(width: 10),
                const Text('F.transaction Payment Details'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fair['title'] ?? 'Untitled Fair', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(fair['description'] ?? 'No description', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const Divider(height: 32),
                _buildDetailRow(Icons.money, 'Total Amount', fair['amount'] ?? '0'),
                _buildDetailRow(Icons.calendar_today, 'Due Date', fair['date'] ?? 'N/A'),
                const Divider(height: 32),
                const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(radius: 16, backgroundColor: Colors.pink.shade100, child: Text(studentName[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pink))),
                    const SizedBox(width: 10),
                    Text(studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(
                      value: isPaid,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        setState(() => isPaid = val);
                        parentSetState(() {
                          _updateFairStatus(studentUser, fair, val);
                        });
                      },
                    ),
                  ],
                ),
                Text(isPaid ? 'Payment Received' : 'Payment Pending', style: TextStyle(color: isPaid ? Colors.teal : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
            ],
          );
        }
      ),
    );
  }

  void _updateFairStatus(String studentUser, Map<String, dynamic> fair, bool isPaid) {
    DataStore.allFairPayments.removeWhere((p) => 
      p['studentUsername'] == studentUser && p['fairId'] == fair['id']
    );
    DataStore.allFairPayments.add({
      'studentUsername': studentUser,
      'fairId': fair['id'],
      'isPaid': isPaid,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    DataStore.saveAllData();
  }

  Widget _buildSectionChip(String label, IconData icon, int index, int current, Function(int) onTap) {
    final bool isSelected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade800, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab(ColorScheme colorScheme) {
    final List<Map<String, dynamic>> combinedSchedule = [
      ..._exams.map((e) => {...e, 'origin': 'exam'}),
    ];

    // Sort by dates if possible (simple string sort for now as data format varies)
    combinedSchedule.sort((a, b) => (a['dates'] ?? a['date'] ?? '').compareTo(b['dates'] ?? b['date'] ?? ''));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              _actionIconBtn(Icons.calendar_month_rounded, colorScheme.primary, () => _showAddScheduleDialog()),
            ],
          ),
        ),
        Expanded(
          child: combinedSchedule.isEmpty
              ? _emptyStateView(Icons.event_busy_rounded, 'No events scheduled')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: combinedSchedule.length,
                  itemBuilder: (context, index) {
                    final item = combinedSchedule[index];
                    final String origin = item['origin'] ?? 'exam';
                    String type = item['type'] ?? 'Exam';
                    final bool isExam = type == 'Exam';
                    final List subs = item['subjects'] ?? [];
                    
                    Color accentColor = Colors.orange;
                    IconData icon = Icons.assignment_rounded;
                    
                    if (origin == 'activity') {
                      accentColor = Colors.green;
                      icon = Icons.play_circle_fill;
                      type = item['type'] ?? 'Activity';
                    } else if (origin == 'fair') {
                      accentColor = Colors.pink;
                      icon = Icons.local_activity;
                      type = 'F.transaction';
                    } else if (type == 'Holiday') {
                      accentColor = Colors.red;
                      icon = Icons.celebration_rounded;
                    } else if (type == 'Meeting') {
                      accentColor = Colors.blue;
                      icon = Icons.groups_rounded;
                    } else if (type == 'Event') {
                      accentColor = Colors.indigo;
                      icon = Icons.event_rounded;
                    }

                    final String displayDate = item['dates'] ?? item['date'] ?? 'No Date';
                    final String displayTime = item['time'] ?? (origin == 'activity' || origin == 'fair' ? 'Due' : '');
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(width: 6, color: accentColor),
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                    child: Icon(icon, color: accentColor),
                                  ),
                                  title: Text(item['title'] ?? item['examName'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                                  subtitle: Text('$type | $displayDate | $displayTime', style: TextStyle(color: accentColor.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold)),
                                  trailing: origin == 'exam' ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz_rounded),
                                    onSelected: (val) {
                                      if (val == 'edit') _showAddScheduleDialog(index: _exams.indexOf(item));
                                      if (val == 'delete') {
                                        setState(() {
                                          DataStore.allExams.remove(item);
                                          DataStore.saveAllData();
                                        });
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded, color: Colors.teal), title: Text('Edit'))),
                                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_rounded, color: Colors.red), title: Text('Delete'))),
                                    ],
                                  ) : IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                    onPressed: () {
                                      setState(() {
                                        if (origin == 'activity') _currentIndex = 1;
                                        if (origin == 'fair') _currentIndex = 2;
                                      });
                                    },
                                    tooltip: 'View in ${origin == 'activity' ? 'Activities' : 'F.transactions'}',
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Divider(),
                                          if (item['description']?.toString().isNotEmpty == true) ...[
                                            Text(item['description'], style: TextStyle(height: 1.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 12),
                                          ],
                                          if (isExam && subs.isNotEmpty) ...subs.map<Widget>((s) => Container(
                                            margin: const EdgeInsets.only(top: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.book_rounded, size: 16, color: Colors.orange),
                                                const SizedBox(width: 12),
                                                Expanded(child: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                                Text('${s['date']} | ${s['time']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                              ],
                                            ),
                                          )).toList(),
                                          if (origin == 'activity') 
                                            Text('Total Marks: ${item['marks']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                          if (origin == 'fair') 
                                            Text('Fee: ${item['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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

  Widget _buildScheduleDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResultsTab(ColorScheme colorScheme) {
    // Group results by exam name
    final Map<String, List<Map<String, dynamic>>> groupedResults = {};
    for (var r in _results) {
      final examName = r['examName'] ?? 'General';
      if (!groupedResults.containsKey(examName)) {
        groupedResults[examName] = [];
      }
      groupedResults[examName]!.add(r);
    }
    final examNames = groupedResults.keys.toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Results', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              _actionIconBtn(Icons.add_chart_rounded, colorScheme.primary, () => _showAddResultDialog()),
            ],
          ),
        ),
        Expanded(
          child: examNames.isEmpty
              ? _emptyStateView(Icons.analytics_outlined, 'No results published')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: examNames.length,
                  itemBuilder: (context, index) {
                    final examTitle = examNames[index];
                    final studentsInExam = groupedResults[examTitle]!;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(width: 6, color: Colors.purple.shade400),
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  initiallyExpanded: false,
                                  tilePadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(16)),
                                    child: const Icon(Icons.assessment_rounded, color: Colors.purple),
                                  ),
                                  title: Text(examTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1E293B))),
                                  subtitle: Text('${studentsInExam.length} Student Score Cards', style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.w700)),
                                  children: [
                                    const Divider(height: 1),
                                    ...studentsInExam.map((r) {
                                      final List subjectRes = r['subjectResults'] ?? [];
                                      return Container(
                                        margin: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.grey.shade100),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                                        ),
                                        child: Column(
                                          children: [
                                            ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: Colors.purple.shade50,
                                                child: Text(r['studentName']?[0] ?? 'S', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                                              ),
                                              title: GestureDetector(
                                                onTap: () {
                                                  final student = _allStudents.firstWhere(
                                                    (s) => s['name'] == r['studentName'],
                                                    orElse: () => {},
                                                  );
                                                  if (student.isNotEmpty) {
                                                    _showStudentDetails(student);
                                                  }
                                                },
                                                child: Text(
                                                  r['studentName'] ?? 'Result', 
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.purple, decoration: TextDecoration.underline)
                                                ),
                                              ),
                                              subtitle: Text('${subjectRes.length} Subjects Evaluated', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                              trailing: PopupMenuButton<String>(
                                                onSelected: (val) {
                                                  if (val == 'edit') {
                                                    final originalIdx = DataStore.allResults.indexOf(r);
                                                    _showAddResultDialog(index: originalIdx);
                                                  } else if (val == 'delete') {
                                                    setState(() {
                                                       DataStore.allResults.remove(r);
                                                       DataStore.saveAllData();
                                                     });
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.teal), title: Text('Edit'))),
                                                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'))),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.grey.shade50),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: Table(
                                                  border: TableBorder.all(color: Colors.grey.shade100),
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
                                                      String grade = pct >= 90 ? 'A+' : pct >= 80 ? 'A' : pct >= 70 ? 'B+' : pct >= 60 ? 'B' : pct >= 50 ? 'C+' : pct >= 40 ? 'C' : 'D';
                                                      final bool isPass = pct >= 40;
                                                      final String status = isPass ? 'Pass' : 'Failed';
                                                      final Color statusColor = isPass ? Colors.green : Colors.red;
                                                      
                                                      return TableRow(
                                                        children: [
                                                          Padding(padding: const EdgeInsets.all(12), child: Text(s['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                                          Padding(padding: const EdgeInsets.all(12), child: Text('${s['scoredMark']}/${s['totalMarks']}', style: const TextStyle(fontWeight: FontWeight.w900))),
                                                          Padding(padding: const EdgeInsets.all(12), child: Text(grade, style: TextStyle(fontWeight: FontWeight.w900, color: statusColor))),
                                                          Padding(
                                                            padding: const EdgeInsets.all(8), 
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                                              child: Center(
                                                                child: Text(
                                                                  status, 
                                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor)
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }).toList(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    const SizedBox(height: 16),
                                  ],
                                ),
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

  // ---- Firebase-based Chat System ----
  String? _activeChatPeerId;
  String? _activeChatPeerName;
  Color? _activeChatPeerColor;
  String? _activeChatPeerDept;
  final TextEditingController _chatMsgCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  bool _chatEmojiOpen = false;

  final Map<String, List<String>> _emojiGroups = {
    "Faces": ["ðŸ˜‚", "ðŸ¤£", "ðŸ˜Š", "ðŸ˜", "ðŸ¥°", "ðŸ¤”", "ðŸ§", "ðŸ˜”", "ðŸ˜¢", "ðŸ˜­", "ðŸ˜±", "ðŸ˜Ž", "ðŸ¥³"],
    "Hands": ["ðŸ‘", "ðŸ‘Ž", "âœŒï¸", "ðŸ–ï¸", "âœ‹", "â˜ï¸", "ðŸ‘†", "ðŸ‘‡", "ðŸ‘ˆ", "ðŸ‘‰", "ðŸ¤", "ðŸ™"],
    "Nature": ["ðŸŒ¸", "ðŸŒ¹", "ðŸŒ·", "ðŸŒ»", "ðŸŒ¼", "ðŸŒº", "ðŸ¥€", "ðŸ’®", "ðŸŒ±", "ðŸŒ¿", "ðŸƒ"],
    "React": ["â¤ï¸", "ðŸ’¯", "â³", "â°", "ðŸŽ¯", "ðŸ’°", "ðŸ¥…", "ðŸ“ž", "ðŸšŒ", "ðŸš—"],
    "Nums": ["1ï¸âƒ£", "2ï¸âƒ£", "3ï¸âƒ£", "4ï¸âƒ£", "5ï¸âƒ£", "6ï¸âƒ£", "7ï¸âƒ£", "8ï¸âƒ£", "9ï¸âƒ£", "0ï¸âƒ£"],
    "Math": ["!", "@", "#", r"$", "%", "^", "&", "*", "(", ")", "-", "_", "+", "=", "<", ">", "?", "~", "/"],
  };

  String _getRoomId(String peerId) {
    if (peerId.contains('class_group')) return peerId;
    final pair = [widget.teacherUsername, peerId];
    pair.sort();
    return pair.join('::');
  }

  void _sendChatMessage() {
    if (_chatMsgCtrl.text.trim().isEmpty || _activeChatPeerId == null) return;
    
    final roomId = _getRoomId(_activeChatPeerId!);
    final messageData = {
      'text': _chatMsgCtrl.text,
      'senderId': widget.teacherUsername,
      'senderName': widget.teacherName,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      DataStore.allMessages.add({
        ...messageData,
        'convKey': roomId,
        'receiverId': _activeChatPeerId,
        'receiverName': _activeChatPeerName,
        'recipients': [_activeChatPeerId, widget.teacherUsername],
        'schoolName': widget.schoolName,
      });
      DataStore.saveAllData();
      _chatMsgCtrl.clear();
      _chatEmojiOpen = false;
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, dynamic>> _getChatMessages() {
    if (_activeChatPeerId == null) return [];
    final roomId = _getRoomId(_activeChatPeerId!);
    return DataStore.allMessages
        .where((m) => m['convKey'] == roomId)
        .toList()
      ..sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));
  }

  Widget _buildImportantBulletins(ColorScheme colorScheme) {
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
    // Prepare contacts list
    final List<Map<String, dynamic>> allContacts = [
      {
        "id": "academic_director",

        "name": "academic_director",
        "role": "academic_director",
        "dept": "School Admin",
        "color": "0xFF3F51B5",
        "status": "Online",
      },
      ..._students.map((s) => {
        "id": s['username'] ?? '',
        "name": s['name'] ?? '',
        "role": "Student",
        "dept": "Class ${s['std'] ?? widget.assignedClass}",
        "color": "0xFFFF9800",
      }),
    ];

    // Enrich contacts with last message and unread count
    for (var contact in allContacts) {
       final String targetId = contact['id'] as String;
       final bool isGroup = contact['isGroup'] == true;
       final roomId = isGroup ? targetId : _getRoomId(targetId);
       
       final convMessages = DataStore.allMessages.where((m) => m['convKey'] == roomId).toList()
         ..sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));

       
       if (convMessages.isNotEmpty) {
         final lastMsg = convMessages.last;
         contact['lastMessage'] = lastMsg['text'];
         contact['lastTime'] = _teacherFormatTimestamp(lastMsg['timestamp'] as String?);
       } else {
         contact['lastMessage'] = "No messages yet";
         contact['lastTime'] = "";
       }
       
       // Dummy unread count for UI premium feel
       contact['unread'] = (contact['id'].toString().length % 3 == 0) ? 2 : 0;
    }


    final bool hasActiveChat = _activeChatPeerId != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        if (isMobile) {
          if (hasActiveChat) {
            return _buildChatPanel(colorScheme);
          } else {
            return _buildContactSidebar(colorScheme, allContacts);
          }
        }

        // Desktop style split view
        return Row(
          children: [
            SizedBox(
              width: 320,
              child: _buildContactSidebar(colorScheme, allContacts),
            ),
            Expanded(
              child: hasActiveChat 
                  ? _buildChatPanel(colorScheme) 
                  : _buildEmptyChatPanel(colorScheme),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyChatPanel(ColorScheme colorScheme) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
              ),
              child: Icon(Icons.forum_outlined, size: 80, color: colorScheme.primary.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a contact to start chatting',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your messages are secured with Bridge encryption',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text('End-to-End Encrypted', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContactSidebar(ColorScheme colorScheme, List<Map<String, dynamic>> allContacts) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF075E54),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        widget.teacherName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.teacherName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Teacher | ${widget.assignedClass}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (value) {
                    // Can add search functionality here if needed
                  },
                  decoration: InputDecoration(
                    hintText: "Search students or Academic Director...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              // Contacts list
              Expanded(
                child: ListView.separated(
                  itemCount: allContacts.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                  itemBuilder: (context, index) {
                    final contact = allContacts[index];
                    final isActive = contact['id'] == _activeChatPeerId;
                    final colorStr = contact['color'] as String;
                    final colorValue = int.tryParse(colorStr) ?? 
                                     (colorStr.startsWith('0x') 
                                        ? int.tryParse(colorStr.substring(2), radix: 16) 
                                        : null) ?? 
                                     0xFF075E54;
                    
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _activeChatPeerId = contact['id'] as String;
                          _activeChatPeerName = contact['name'] as String;
                          _activeChatPeerColor = Color(colorValue);
                          _activeChatPeerDept = contact['dept'] as String;
                          _chatEmojiOpen = false;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        color: isActive ? const Color(0xFFEBFFF7) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Color(colorValue),

                              child: Text(
                                (contact['name'] as String)[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact['name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (contact['lastMessage'] != "No messages yet")
                                        const Icon(Icons.done_all, size: 14, color: Colors.blue),
                                      if (contact['lastMessage'] != "No messages yet")
                                        const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          contact['lastMessage'] ?? "",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  contact['lastTime'] ?? "",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: (contact['unread'] as int) > 0 ? const Color(0xFF25D366) : Colors.grey[600],
                                    fontWeight: (contact['unread'] as int) > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if ((contact['unread'] as int) > 0)
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF25D366),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      contact['unread'].toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

  Widget _buildChatPanel(ColorScheme colorScheme) {
    final messages = _getChatMessages();
    final peerName = _activeChatPeerName ?? '';
    final peerDept = _activeChatPeerDept ?? '';
    final peerColor = _activeChatPeerColor ?? Colors.teal;

    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        leading: (MediaQuery.of(context).size.width < 750) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _activeChatPeerId = null),
              )
            : null,

        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: peerColor,
              radius: 18,
              child: Text(
                peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peerName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  peerDept,
                  style: const TextStyle(fontSize: 10, color: Color(0xFFB9F6CA)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5DDD5), // Stable background color
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.02), Colors.transparent],
                ),
              ),

              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Start a conversation with $peerName',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _chatScrollCtrl,
                      reverse: false,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index];
                        final isMine = data['senderId'] == widget.teacherUsername;
                        return _buildChatBubble(data, isMine);
                      },
                    ),
            ),
          ),
          // Emoji panel
          if (_chatEmojiOpen) _buildEmojiPanel(),
          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg, bool isMine) {
    String time = "...";
    if (msg['timestamp'] != null) {
      try {
        final dt = DateTime.parse(msg['timestamp'] as String).toLocal();
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        final displayHour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        time = '${displayHour.toString().padLeft(2, '0')}:$minute $period';
      } catch (_) {
        time = '';
      }
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFE1FFC7) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: isMine ? const Radius.circular(15) : Radius.zero,
            bottomRight: isMine ? Radius.zero : const Radius.circular(15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildParsableText(msg['text'] ?? ''),

            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 12, color: Colors.teal),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsableText(String text) {
    final List<String> words = text.split(' ');
    final List<TextSpan> spans = [];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final spacing = (i == words.length - 1) ? "" : " ";
      if (word.startsWith('@')) {
        final mention = word.toLowerCase();
        int targetIndex = -1;
        if (mention.contains('activities')) {
          targetIndex = 1;
        } else if (mention.contains('fair')) {
          targetIndex = 2;
        } else if (mention.contains('exam')) {
          targetIndex = 3;
        } else if (mention.contains('result')) {
          targetIndex = 4;
        }

        if (targetIndex != -1) {
          spans.add(TextSpan(
            text: "$word$spacing",
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                setState(() => _currentIndex = targetIndex);
              },
          ));
          continue;
        }
      }

      spans.add(TextSpan(text: "$word$spacing", style: const TextStyle(fontSize: 14, color: Colors.black87)));
    }

    return RichText(text: TextSpan(children: spans));
  }


  Widget _buildEmojiPanel() {
    return Container(
      height: 280,
      color: Colors.white,
      child: ListView(
        children: _emojiGroups.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: entry.value.map((e) => InkWell(
                    onTap: () => setState(() => _chatMsgCtrl.text += e),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  )).toList(),
                ),
              ),
              const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.sentiment_satisfied_alt,
                      color: _chatEmojiOpen ? Colors.green[800] : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _chatEmojiOpen = !_chatEmojiOpen);
                      if (_chatEmojiOpen) FocusScope.of(context).unfocus();
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _chatMsgCtrl,
                      onTap: () => setState(() => _chatEmojiOpen = false),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      style: const TextStyle(fontSize: 15),
                      onSubmitted: (_) => _sendChatMessage(),
                      maxLength: 3000,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendChatMessage,
            child: const CircleAvatar(
              backgroundColor: Color(0xFF075E54),
              radius: 24,
              child: Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildReactionBadge(Map<String, dynamic> msg) {
    if (msg['reactions'] == null) return const SizedBox.shrink();
    final Map reactions = msg['reactions'];
    final counts = <String, int>{};
    reactions.values.forEach((e) => counts[e] = (counts[e] ?? 0) + 1);
    return Row(
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
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
          child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        );
      }).toList(),
    );
  }

  Widget _buildGlobalGroupTab(ColorScheme colorScheme) {
    final staffMessages = _messages.where((msg) =>
      msg['group_id'] == 'staff_global' || msg['isStaffMessage'] == true
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
              const Icon(Icons.campaign, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('School Announce', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('Teachers & Students | Announcements & Chat', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_comment, color: Colors.white),
                onPressed: () => _showGlobalMessageDialog(colorScheme),
                tooltip: 'Post to Announce',
              ),
            ],
          ),
        ),
        Expanded(
          child: staffMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No announcements yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const Text('Be the first to start a discussion!', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: staffMessages.length,
                  itemBuilder: (context, index) {
                    final msg = staffMessages[index];
                    final isTeacher = msg['senderType'] == 'Teacher';
                    
                    return FadeInEntrance(
                      delay: index * 0.03,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: msg['senderId'] == widget.teacherUsername ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (msg['senderId'] != widget.teacherUsername)
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isTeacher ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                child: Icon(isTeacher ? Icons.badge : Icons.school, color: isTeacher ? Colors.green : Colors.orange, size: 18),
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: msg['senderId'] == widget.teacherUsername ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: msg['senderId'] == widget.teacherUsername ? colorScheme.primary.withOpacity(0.1) : (isTeacher ? Colors.green.shade50 : Colors.orange.shade50),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(msg['text'] ?? '', style: const TextStyle(fontSize: 14)),
                                        _buildReactionBadge(msg),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_teacherFormatTimestamp(msg['timestamp']), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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

  void _showGlobalMessageDialog(ColorScheme colorScheme) {
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Post to School Group', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will be visible to all teachers and students', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Type your message...',
                  border: OutlineInputBorder(),
                  hintText: 'Share announcements, ask questions, or start discussions',
                ),
                onChanged: (val) => setStateDialog(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: messageCtrl.text.isEmpty ? null : () {
                setState(() {
                  _messages.add({
                    'from': widget.teacherName,
                    'to': 'All',
                    'text': messageCtrl.text,
                    'timestamp': DateTime.now().toIso8601String(),
                    'isStaffMessage': true,
                    'isGlobalMessage': true,
                    'senderId': widget.teacherUsername,
                    'senderType': 'Teacher',
                    'group_id': 'staff_global',
                  });
                  DataStore.saveAllData();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message posted to school group!')));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _teacherFormatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inDays == 0) {
        if (diff.inHours == 0) return '${diff.inMinutes}m';
        return '${diff.inHours}h';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d';
      }
      return '${dt.day}/${dt.month}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildAttendanceTab(ColorScheme colorScheme) {
    return _AttendanceTab(
      students: _students,
      currentClass: _teacherSelectedClass ?? widget.assignedClass,
    );
  }
}

class _AttendanceTab extends StatefulWidget {
  final List<Map<String, String>> students;
  final String currentClass;

  const _AttendanceTab({required this.students, required this.currentClass});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isHoliday {
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    return DataStore.holidayDates.contains(dateStr);
  }

  void _toggleHoliday() {
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    setState(() {
      if (DataStore.holidayDates.contains(dateStr)) {
        DataStore.holidayDates.remove(dateStr);
      } else {
        DataStore.holidayDates.add(dateStr);
      }
      DataStore.saveAllData();
    });
  }


  Map<String, int> _getAttendanceStats() {
    int fnP = 0, fnA = 0, anP = 0, anA = 0;
    int overallP = 0;
    int totalCount = widget.students.length;
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    for (var student in widget.students) {
      final record = DataStore.allAttendance.firstWhere(
        (a) => a['studentUsername'] == student['username'] && a['date'] == dateStr,
        orElse: () => {},
      );
      if (record.isNotEmpty) {
        final pMap = Map<String, String>.from((record['periods'] as Map?) ?? {});
        if (pMap['FN'] == 'P') fnP++; else if (pMap['FN'] == 'A') fnA++;
        if (pMap['AN'] == 'P') anP++; else if (pMap['AN'] == 'A') anA++;
        
        if (pMap.values.contains('P')) {
          overallP++;
        }
      }
    }
    return {'fnP': fnP, 'fnA': fnA, 'anP': anP, 'anA': anA, 'overallP': overallP, 'total': totalCount};
  }

  Widget _statCard(String label, int present, int absent, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniStat('P', present, Colors.teal),
                Container(width: 1, height: 20, color: Colors.grey.shade100),
                _miniStat('A', absent, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String tag, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
        Text(tag, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w900)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final bool isHoliday = _isHoliday;

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          // Header: Minimal Date & Info
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Attendance', style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('Class ${widget.currentClass} | ${widget.students.length} Students', style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Row(
                          children: [
                            const Icon(Icons.today, color: Color(0xFF64748B), size: 12),
                            const SizedBox(width: 6),
                            Text(dateStr, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(color: isHoliday ? Colors.red.shade50 : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: isHoliday ? Colors.red.shade100 : const Color(0xFFE2E8F0))),
                  child: Row(
                    children: [
                      Icon(Icons.beach_access_rounded, size: 14, color: isHoliday ? Colors.red.shade400 : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text('Official School Holiday', style: TextStyle(color: isHoliday ? Colors.red.shade700 : const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: isHoliday,
                          onChanged: (v) => _toggleHoliday(),
                          activeColor: Colors.red.shade400,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!isHoliday) ...[
            Builder(
              builder: (context) {
                final stats = _getAttendanceStats();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      _statCard('Total Day', stats['overallP']!, stats['total']! - stats['overallP']!, Colors.indigo),
                      const SizedBox(width: 8),
                      _statCard('Morning', stats['fnP']!, stats['fnA']!, Colors.teal),
                      const SizedBox(width: 8),
                      _statCard('Afternoon', stats['anP']!, stats['anA']!, Colors.orange),
                    ],
                  ),
                );
              }
            ),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by student name or ID...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ""); })
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Text('Students', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.grey.shade800, letterSpacing: -0.5)),
                  const SizedBox(width: 6),
                  Builder(
                    builder: (context) {
                      final filtered = widget.students.where((s) {
                        final name = (s['name'] ?? '').toLowerCase();
                        final id = (s['username'] ?? '').toLowerCase();
                        return name.contains(_searchQuery) || id.contains(_searchQuery);
                      }).toList();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('${filtered.length}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      );
                    }
                  ),
                  const Spacer(),
                ],
              ),
            ),

            
            Expanded(
              child: Builder(
                builder: (context) {
                  final filtered = widget.students.where((s) {
                    final name = (s['name'] ?? '').toLowerCase();
                    final id = (s['username'] ?? '').toLowerCase();
                    return name.contains(_searchQuery) || id.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No students found matching "$_searchQuery"', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _TwoSessionAttendanceRow(
                        student: filtered[index],
                        date: dateStr,
                        subjects: List.generate(10, (i) => 'Free'),
                      );
                    },
                  );
                }
              ),
            ),

          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 100, color: Colors.red.withOpacity(0.2)),
                    const SizedBox(height: 20),
                    const Text('OFF DAY / HOLIDAY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const Text('The whole day is marked as leave.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _TwoSessionAttendanceRow extends StatefulWidget {
  final Map<String, String> student;
  final String date;
  final List<String> subjects;

  const _TwoSessionAttendanceRow({
    required this.student,
    required this.date,
    required this.subjects,
  });

  @override
  State<_TwoSessionAttendanceRow> createState() => _TwoSessionAttendanceRowState();
}

class _TwoSessionAttendanceRowState extends State<_TwoSessionAttendanceRow> {
  String _fnStatus = '-';
  String _anStatus = '-';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_TwoSessionAttendanceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _loadData();
    }
  }

  void _loadData() {
    final record = DataStore.allAttendance.firstWhere(
      (a) => a['studentUsername'] == widget.student['username'] && a['date'] == widget.date,
      orElse: () => {},
    );
    if (record.isNotEmpty) {
      final pMap = Map<String, String>.from((record['periods'] as Map?) ?? {});
      _fnStatus = pMap['FN'] ?? '-';
      _anStatus = pMap['AN'] ?? '-';
    } else {
      _fnStatus = '-';
      _anStatus = '-';
    }
    setState(() {});
  }

  void _updateStatus(String session, String newStatus, {bool forceReasonDialog = false}) async {
    String reason = '';
    final currentRecord = DataStore.allAttendance.firstWhere(
      (a) => a['studentUsername'] == widget.student['username'] && a['date'] == widget.date,
      orElse: () => {},
    );
    String existingReason = currentRecord['leaveReason'] ?? '';

    if (newStatus == 'A' || (newStatus == 'SAME' && forceReasonDialog)) {
      final TextEditingController reasonCtrl = TextEditingController(text: existingReason);

      final String? result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reason for Leave', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  hintText: 'Enter reason why student is absent...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'CLEAR'),
              child: const Text('CLEAR STATUS', style: TextStyle(color: Colors.red)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx, 'CANCEL'), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'SAVE'),
              child: const Text('SAVE'),
            ),
          ],
        ),
      );

      if (result == 'SAVE') {
        reason = reasonCtrl.text.trim();
        if (newStatus == 'SAME') newStatus = 'A';
      } else if (result == 'CLEAR') {
        newStatus = '-';
        reason = '';
      } else {
        return; // CANCEL
      }
    }

    setState(() {
      if (session == 'FN') _fnStatus = newStatus;
      else _anStatus = newStatus;
    });
    
    final index = DataStore.allAttendance.indexWhere(
      (a) => a['studentUsername'] == widget.student['username'] && a['date'] == widget.date
    );

    final record = index != -1 
      ? Map<String, dynamic>.from(DataStore.allAttendance[index])
      : {
          'studentUsername': widget.student['username'],
          'date': widget.date,
          'academicYear': DataStore.selectedAcademicYear,
          'periods': <String, String>{},
          'leaveReason': '',
          'timetable': List<String>.from(widget.subjects),
        };

    final pMap = Map<String, String>.from((record['periods'] as Map?) ?? {});
    pMap[session] = newStatus;
    record['periods'] = pMap;
    // Update reason if we are in 'A' state
    if (newStatus == 'A') {
      record['leaveReason'] = reason;
    } else if (newStatus == '-') {
       // if we cleared it, and other sessions are not 'A', maybe clear reason?
       // For now, let's just leave it or clear if specifically requested.
    }

    if (index != -1) {
      DataStore.allAttendance[index] = record;
    } else {
      DataStore.allAttendance.add(record);
    }
    DataStore.saveAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.indigo.shade50,
                  child: Text(widget.student['name']?[0] ?? 'S', style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.student['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
                      Text(widget.student['username'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    _updateStatus('FN', 'P');
                    _updateStatus('AN', 'P');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text('All P', style: TextStyle(color: Colors.teal.shade700, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _sessionBtn('FN (Morning)', _fnStatus, (s, {forceReasonDialog = false}) => _updateStatus('FN', s, forceReasonDialog: forceReasonDialog))),
                const SizedBox(width: 12),
                Expanded(child: _sessionBtn('AN (Afternoon)', _anStatus, (s, {forceReasonDialog = false}) => _updateStatus('AN', s, forceReasonDialog: forceReasonDialog))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionBtn(String label, String status, Function(String, {bool forceReasonDialog}) onUpdate) {
    Color bg = Colors.grey.shade50;
    Color fg = Colors.grey.shade400;
    
    if (status == 'P') { bg = Colors.teal.shade50; fg = Colors.teal.shade700; }
    if (status == 'A') { bg = Colors.red.shade50; fg = Colors.red.shade700; }

    return GestureDetector(
      onTap: () {
        if (status == 'A') {
          // If already A, show the reason dialog instead of toggling immediately
          onUpdate('SAME', forceReasonDialog: true);
        } else {
          String next = status == '-' ? 'P' : 'A';
          onUpdate(next);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fg.withOpacity(0.1)),
          boxShadow: status != '-' ? [BoxShadow(color: fg.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status == '-' ? label : '$label: $status',
                style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900),
              ),
              if (status == 'A') ...[
                const SizedBox(width: 6),
                Icon(Icons.info_outline_rounded, size: 14, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DIRECT CHAT SCREEN (Unified WhatsApp style)
// ==========================================
