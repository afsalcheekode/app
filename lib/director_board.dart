import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'common.dart';
import 'data_store.dart';
import 'notification_service.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  SCHOOL DASHBOARD SCREEN  (Academic Director)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class SchoolDashboardScreen extends StatefulWidget {
  final String schoolName;
  final String directorName;
  final String username;
  const SchoolDashboardScreen({super.key, required this.schoolName, required this.directorName, required this.username});

  @override
  State<SchoolDashboardScreen> createState() => _SchoolDashboardScreenState();
}

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen>
    with TickerProviderStateMixin {
  // 0=Home, 1=Teachers, 2=Departments, 3=Messages
  int _tabIndex = 0;
  late TabController _tabController;
  String? _selectedClassFilter;
  StreamSubscription? _sessionSubscription;

  // helper getters
  List<Map<String, String>> get _teachers => DataStore.allTeachers.where((t) => t['schoolName'] == widget.schoolName).toList();
  List<Map<String, String>> get _students => DataStore.allStudents.where((s) => s['schoolName'] == widget.schoolName).toList();
  List<Map<String, dynamic>> get _myCards => DataStore.allBulletinCards.where((b) => b['schoolName'] == widget.schoolName).toList();
  List<String>              get _classes  => DataStore.getClassesForSchool(widget.schoolName);
  Map<String, String>       get _classDepts {
    final depts = <String, String>{};
    for (var c in _classes) {
      depts[c] = DataStore.getDeptForClass(widget.schoolName, c);
    }
    return depts;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
    _setupSessionListener();
  }

  void _setupSessionListener() {
    final user = DataStore.mockUser;
    if (user != null && user['uid'] != null && user['sessionId'] != null) {
      _sessionSubscription = FirebaseFirestore.instance.collection('users').doc(user['uid']).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          final remoteSessionId = doc.data()?['sessionId'];
          if (remoteSessionId != null && remoteSessionId != user['sessionId']) {
            // Logout if session IDs don't match
            _sessionSubscription?.cancel();
            AuthService().signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('âš ï¸ Logged out: Account opened on another device.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              )
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  // â”€â”€ helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _generatePassword() {
    final rnd = Random();
    String pass = '';
    do {
      pass = (1000 + rnd.nextInt(9000)).toString();
    } while (_students.any((s) => s['password'] == pass) ||
             _teachers.any((t) => t['password'] == pass));
    return pass;
  }

  String _generateUsername(String name) {
    if (name.isEmpty) return 'user${Random().nextInt(1000)}';
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .replaceAll(' ', '.');
  }

  void _showCredentials(String type, String user, String pass) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$type Added âœ…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Save these credentials:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _credRow('Username', user),
            const SizedBox(height: 8),
            _credRow('Password', pass),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT')),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value) {
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied!'), duration: const Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  // â”€â”€ BUILD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.1),
            ),
            child: ClipOval(child: Image.asset('assets/images/app_logo_v2.png')),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.schoolName.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            Text(widget.directorName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            tooltip: 'Logout',
            onPressed: () => AuthService().signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: const Color(0xFF1E293B).withOpacity(0.7),
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.home_rounded, size: 20), text: 'Home'),
            Tab(icon: Icon(Icons.school_rounded, size: 20), text: 'Teacher'),
            Tab(icon: Icon(Icons.people_rounded, size: 20), text: 'Student'),
            Tab(icon: Icon(Icons.account_tree_rounded, size: 20), text: 'Dept'),
            Tab(icon: Icon(Icons.campaign_rounded, size: 20), text: 'Announce'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HomeTab(schoolName: widget.schoolName, students: _students, teachers: _teachers, classes: _classes, classDepts: _classDepts),
          _TeachersTab(
            teachers: _teachers,
            classes: _classes,
            generateUsername: _generateUsername,
            generatePassword: _generatePassword,
            showCredentials: _showCredentials,
            onRefresh: () => setState(() {}),
            schoolName: widget.schoolName,
          ),
          _StudentsManagementTab(
            students: _students,
            classes: _classes,
            generateUsername: _generateUsername,
            generatePassword: _generatePassword,
            showCredentials: _showCredentials,
            onRefresh: () => setState(() {}),
            schoolName: widget.schoolName,
          ),
          _DepartmentsTab(
            schoolName: widget.schoolName,
            classes: _classes,
            students: _students,
            classDepts: _classDepts,
            onRefresh: () => setState(() {}),
          ),
          _BroadcastTab(
            teachers: _teachers,
            students: _students,
            onRefresh: () => setState(() {}),
            currentUsername: widget.username,
            schoolName: widget.schoolName,
          ),
        ],
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  HOME TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _HomeTab extends StatelessWidget {
  final String schoolName;
  final List<Map<String, String>> students;
  final List<Map<String, String>> teachers;
  final List<String> classes;
  final Map<String, String> classDepts;

  const _HomeTab({
    required this.schoolName,
    required this.students,
    required this.teachers,
    required this.classes,
    required this.classDepts,
  });

  @override
  Widget build(BuildContext context) {
    const dawaColor = Color(0xFF6366F1);
    const hifzColor  = Color(0xFFF59E0B);

    final dawaClasses = classes.where((c) => (classDepts[c] ?? "DA'WA") == "DA'WA").toList();
    final hifzClasses  = classes.where((c) => (classDepts[c] ?? "DA'WA") == 'HIFZ').toList();
    final dawaStudents = students.where((s) => dawaClasses.contains(s['std'] ?? '')).length;
    final hifzStudents = students.where((s) => hifzClasses.contains(s['std'] ?? '')).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Welcome banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Management Hub'.toUpperCase(), 
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Text(schoolName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _miniStat('Students', '${students.length}', Icons.people_outline),
                          Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                          _miniStat('Teachers', '${teachers.length}', Icons.school_outlined),
                          Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
                          _miniStat('Classes', '${classes.length}', Icons.class_outlined),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text('Director Insights', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 800 ? 3.0 : 2.2,
            children: [
              _buildMetricCard('Total Students', '${students.length}', Icons.people_rounded, const Color(0xFF6366F1)),
              _buildMetricCard('Teachers', '${teachers.length}', Icons.school_rounded, const Color(0xFF10B981)),
              _buildMetricCard("DA'WA Dept", '$dawaStudents', Icons.account_tree_rounded, dawaColor),
              _buildMetricCard('HIFZ Dept', '$hifzStudents', Icons.menu_book_rounded, hifzColor),
            ],
          ),
          const SizedBox(height: 32),

          const Text('Departments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _buildDeptSection(
            dept: "DA'WA",
            deptClasses: dawaClasses,
            totalStudents: dawaStudents,
            color: dawaColor,
            icon: Icons.account_tree_rounded,
          ),
          const SizedBox(height: 20),

          _buildDeptSection(
            dept: 'HIFZ',
            deptClasses: hifzClasses,
            totalStudents: hifzStudents,
            color: hifzColor,
            icon: Icons.menu_book_rounded,
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 14),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
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
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                ),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeptSection({
    required String dept,
    required List<String> deptClasses,
    required int totalStudents,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.12))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dept,
                          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text(
                        '$totalStudents students Â· ${deptClasses.length} class${deptClasses.length == 1 ? '' : 'es'}',
                        style: TextStyle(color: color.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Per-class cards
          if (deptClasses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('No classes in $dept department.',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: deptClasses.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  mainAxisExtent: 100,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, i) {
                  final cls = deptClasses[i];
                  final count = students.where((s) => s['std'] == cls).length;
                  final classStudents = students.where((s) => s['std'] == cls).toList();
                  return InkWell(
                    onTap: () => _showClassStudents(context, cls, classStudents, color),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.22)),
                      ),
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.13),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.class_rounded, size: 18, color: color),
                        ),
                        const SizedBox(height: 6),
                        Text('Class $cls',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: color,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '$count student${count == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 11, color: color.withOpacity(0.65)),
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

  void _showClassStudents(BuildContext context, String className, List<Map<String, String>> classStudents, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.class_rounded, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text('Class $className Students', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: classStudents.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      const Text('No students currently enrolled in this class.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: classStudents.length,
                    itemBuilder: (context, index) {
                      final s = classStudents[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Text((s['name'] ?? '?')[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          subtitle: Text('ID: ${s['username']} | Pass: ${s['password']}', style: const TextStyle(fontSize: 11, letterSpacing: -0.2)),
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1))
          ),
        ],
      ),
    );
  }
}

Widget _emptyState(String msg, IconData icon) => Center(
  child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey.shade400, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    ),
  ),
);

// _StatCard removed, using _buildMetricCard instead.

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  TEACHERS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _TeachersTab extends StatefulWidget {
  final List<Map<String, String>> teachers;
  final List<String> classes;
  final String Function(String) generateUsername;
  final String Function() generatePassword;
  final void Function(String, String, String) showCredentials;
  final VoidCallback onRefresh;

  const _TeachersTab({
    required this.teachers,
    required this.classes,
    required this.generateUsername,
    required this.generatePassword,
    required this.showCredentials,
    required this.onRefresh,
    required this.schoolName,
  });

  final String schoolName;

  @override
  State<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<_TeachersTab> {
  void _openAddTeacher({int? index}) {
    final t = index != null ? widget.teachers[index] : null;
    final nameCtrl     = TextEditingController(text: t?['name'] ?? '');
    final fullNameCtrl = TextEditingController(text: t?['fullName'] ?? '');
    final usernameCtrl = TextEditingController(text: t?['username'] ?? '');
    final passwordCtrl = TextEditingController(text: t?['password'] ?? '');
    final qualIslamicCtrl = TextEditingController(text: t?['qual_islamic'] ?? '');
    final qualAcademicCtrl = TextEditingController(text: t?['qual_academic'] ?? '');
    final designationCtrl = TextEditingController(text: t?['designation'] ?? '');
    String? photoBase64 = t?['photo'];

    List<String> selectedClasses = [];
    if (t?['class'] != null && t!['class']!.isNotEmpty) {
      selectedClasses = t['class']!.split(',').map((e) => e.trim()).toList();
    } else if (index == null && widget.classes.isNotEmpty) {
      selectedClasses = [widget.classes.first];
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(index != null ? 'Edit Teacher' : 'Add Teacher',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Profile Name', Icons.person_rounded),
                const SizedBox(height: 12),
                _field(fullNameCtrl, 'Full Name', Icons.badge_rounded),
                const SizedBox(height: 12),
                _field(designationCtrl, 'Designation (e.g. Principal, Mudaris)', Icons.work_rounded),
                const SizedBox(height: 16),
                const Text('Qualifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6366F1))),
                const SizedBox(height: 8),
                _field(qualIslamicCtrl, '1. Islamic Qualification', Icons.history_edu_rounded),
                const SizedBox(height: 8),
                _field(qualAcademicCtrl, '2. Academic Qualification', Icons.school_rounded),
                const SizedBox(height: 16),
                const Text('Teacher Photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6366F1))),
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
                        setDs(() {
                          photoBase64 = base64Encode(bytes);
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                          backgroundImage: photoBase64 != null && photoBase64 != 'null' ? MemoryImage(base64Decode(photoBase64!)) : null,
                          child: photoBase64 == null ? const Icon(Icons.person_rounded, size: 50, color: Color(0xFF6366F1)) : null,
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
                const SizedBox(height: 16),
                if (widget.classes.isNotEmpty) ...[
                  const Text('Assign Classes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6366F1))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: widget.classes.map((c) {
                      final sel = selectedClasses.contains(c);
                      return FilterChip(
                        label: Text('Class $c'),
                        selected: sel,
                        selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF6366F1),
                        onSelected: (v) => setDs(() {
                          if (v) selectedClasses.add(c);
                          else selectedClasses.remove(c);
                        }),
                      );
                    }).toList(),
                  ),
                ] else
                  const Text('âš ï¸  Add classes in Departments first', style: TextStyle(color: Colors.red, fontSize: 12)),
                const Divider(height: 28),
                const Text('Credentials (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                _field(usernameCtrl, 'Username', Icons.account_circle_rounded),
                const SizedBox(height: 8),
                _field(passwordCtrl, 'Password', Icons.lock_rounded),
                const SizedBox(height: 4),
                const Text('Leave blank to auto-generate', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final username = index != null
                    ? (usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim().toLowerCase() : (t?['username'] ?? widget.generateUsername(name).toLowerCase()))
                    : (usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim().toLowerCase() : widget.generateUsername(name).toLowerCase());
                final password = index != null
                    ? (passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : (t?['password'] ?? widget.generatePassword()))
                    : (passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : widget.generatePassword());

                final Map<String, String> newData = Map<String, String>.from({
                  'name': name,
                  'fullName': fullNameCtrl.text.trim(),
                  'designation': designationCtrl.text.trim(),
                  'class': selectedClasses.join(', '),
                  'qual_islamic': qualIslamicCtrl.text.trim(),
                  'qual_academic': qualAcademicCtrl.text.trim(),
                  'photo': photoBase64 ?? '',
                  'username': username,
                  'password': password,
                  'schoolName': widget.schoolName,
                });

                if (index == null) {
                  try {
                    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                    await AuthService().registerUser({...newData, 'role': 'teacher'}, password);
                    Navigator.of(context, rootNavigator: true).pop(); // pop loading
                    Navigator.of(context, rootNavigator: true).pop(); // pop add dialog
                    setState(() {
                      DataStore.allTeachers.add(newData);
                      widget.teachers.add(newData);
                      DataStore.saveAllData();
                    });
                    widget.showCredentials('Teacher', username, password);
                  } catch (e) {
                    Navigator.of(context, rootNavigator: true).pop(); // pop loading
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red));
                    }
                    return;
                  }
                } else {
                  setState(() {
                    final oldData = widget.teachers[index];
                    final globalIndex = DataStore.allTeachers.indexWhere((t) => t['username'] == oldData['username']);
                    if (globalIndex != -1) DataStore.allTeachers[globalIndex] = newData;
                    widget.teachers[index] = newData;
                    DataStore.saveAllData();
                    
                    // Update in Firestore
                    FirebaseFirestore.instance.collection('users')
                        .where('username', isEqualTo: oldData['username'])
                        .get().then((query) {
                      if (query.docs.isNotEmpty) {
                        query.docs.first.reference.update(newData);
                      }
                    });
                    
                    final oldUsername = oldData['username']!;
                    final newUsername = newData['username']!;
                    if (oldUsername != newUsername) {
                      FirebaseFirestore.instance.collection('teacher_photos').doc(oldUsername).delete();
                    }
                    FirebaseFirestore.instance.collection('teacher_photos')
                        .doc(newUsername)
                        .set({'username': newUsername, 'photo': newData['photo'] ?? ''}, SetOptions(merge: true));
                  });
                  Navigator.pop(context);
                }
                widget.onRefresh();
              },
              child: Text(index != null ? 'Update' : 'Add Teacher'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  void _deleteTeacher(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Teacher'),
        content: Text('Delete ${widget.teachers[index]['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                final t = widget.teachers[index];
                DataStore.allTeachers.removeWhere((x) => x['username'] == t['username']);
                widget.teachers.removeAt(index);
                
                // Delete from Firestore
                FirebaseFirestore.instance.collection('users')
                    .where('username', isEqualTo: t['username'])
                    .get().then((query) {
                  if (query.docs.isNotEmpty) {
                    query.docs.first.reference.delete();
                  }
                });
              });
              DataStore.saveAllData();
              widget.onRefresh();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: widget.teachers.isEmpty
          ? _emptyState('No teachers yet. Tap + to add.', Icons.person_add_rounded)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.teachers.length,
              itemBuilder: (_, i) {
                final t = widget.teachers[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.12),
                      backgroundImage: (t['photo'] != null && t['photo']!.isNotEmpty && t['photo'] != 'null') ? MemoryImage(base64Decode(t['photo']!)) : null,
                      child: (t['photo'] == null || t['photo']!.isEmpty) ? Text(
                        (t['name'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ) : null,
                    ),
                    title: Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t['designation'] != null && t['designation']!.isNotEmpty)
                          Text('${t['designation']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                        if ((t['class'] ?? '').isNotEmpty)
                          Text('Classes: ${t['class']}', style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1))),
                        if ((t['fullName'] ?? '').isNotEmpty)
                          Text('Full Name: ${t['fullName']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('@${t['username'] ?? ''}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Color(0xFF6366F1), size: 20),
                          onPressed: () => _openAddTeacher(index: i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          onPressed: () => _deleteTeacher(i),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTeacher(),
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Teacher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
//  DEPARTMENTS TAB
// â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
class _DepartmentsTab extends StatefulWidget {
  final String schoolName;
  final List<String> classes;
  final List<Map<String, String>> students;
  final Map<String, String> classDepts;
  final VoidCallback onRefresh;

  const _DepartmentsTab({
    required this.schoolName,
    required this.classes,
    required this.students,
    required this.classDepts,
    required this.onRefresh,
  });

  @override
  State<_DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<_DepartmentsTab> {
  void _addClassDialog({String? dept}) {
    final ctrl = TextEditingController();
    String selectedDept = dept ?? 'DA\'WA';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Class', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: 'Class Name / Number',
                  prefixIcon: const Icon(Icons.class_rounded, color: Color(0xFF6366F1)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'e.g. 01, 1A, Grade 5',
                ),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft,
                  child: Text('Department', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              const SizedBox(height: 8),
              Row(
                children: ["DA'WA", 'HIFZ'].map((d) {
                  final sel = selectedDept == d;
                  final color = d == 'HIFZ' ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setDs(() => selectedDept = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: sel ? color : color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color, width: sel ? 2 : 1),
                          ),
                          child: Text(d, textAlign: TextAlign.center,
                              style: TextStyle(
                                color: sel ? Colors.white : color,
                                fontWeight: FontWeight.w800,
                              )),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                if (DataStore.getClassesForSchool(widget.schoolName).contains(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class already exists!')));
                  return;
                }
                setState(() {
                  DataStore.addClassForSchool(widget.schoolName, name);
                  DataStore.setDeptForClass(widget.schoolName, name, selectedDept);
                  DataStore.saveAllData();
                });
                widget.onRefresh();
                Navigator.pop(context);
              },
              child: const Text('Add Class'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteClass(String className) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text('Are you sure you want to delete Class $className? All students enrolled in this class will also be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                // 1. Delete all students in this class for this school
                final studentsToDelete = DataStore.allStudents.where((s) => s['std'] == className && s['schoolName'] == widget.schoolName).toList();
                for (final s in studentsToDelete) {
                  DataStore.allStudents.removeWhere((x) => x['username'] == s['username']);
                  widget.students.removeWhere((x) => x['username'] == s['username']);
                  
                  FirebaseFirestore.instance.collection('users')
                      .where('username', isEqualTo: s['username'])
                      .get().then((query) {
                    if (query.docs.isNotEmpty) {
                      query.docs.first.reference.delete();
                    }
                  });
                }

                // 2. Unassign this class from any teachers in this school
                for (var t in DataStore.allTeachers) {
                  if (t['schoolName'] != widget.schoolName) continue;
                  final cField = t['class'];
                  if (cField != null && cField.isNotEmpty) {
                    var classes = cField.split(',').map((e) => e.trim()).toList();
                    if (classes.contains(className)) {
                      classes.remove(className);
                      t['class'] = classes.join(', ');
                      
                      FirebaseFirestore.instance.collection('users')
                          .where('username', isEqualTo: t['username'])
                          .get().then((query) {
                        if (query.docs.isNotEmpty) {
                          query.docs.first.reference.update({'class': classes.join(', ')});
                        }
                      });
                    }
                  }
                }

                // 3. Delete the class itself
                DataStore.removeClassForSchool(widget.schoolName, className);
                DataStore.removeDeptForClass(widget.schoolName, className);
                DataStore.saveAllData();
              });
              widget.onRefresh();
              Navigator.pop(context);
            },
            child: const Text('Delete Class & Students'),
          ),
        ],
      ),
    );
  }

  void _editClassDialog(String oldClassName, String currentDept) {
    final ctrl = TextEditingController(text: oldClassName);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Class Name', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: 'Class Name / Number',
            prefixIcon: const Icon(Icons.edit_rounded, color: Color(0xFF6366F1)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isEmpty || newName == oldClassName) return;
              if (DataStore.getClassesForSchool(widget.schoolName).contains(newName)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class already exists!')));
                return;
              }

              setState(() {
                // 1. Update students
                final studentsToUpdate = DataStore.allStudents.where((s) => s['std'] == oldClassName && s['schoolName'] == widget.schoolName).toList();
                for (final s in studentsToUpdate) {
                  s['std'] = newName;
                  
                  FirebaseFirestore.instance.collection('users')
                      .where('username', isEqualTo: s['username'])
                      .get().then((query) {
                    if (query.docs.isNotEmpty) {
                      query.docs.first.reference.update({'std': newName});
                    }
                  });
                }

                // 2. Update teachers
                for (var t in DataStore.allTeachers) {
                  if (t['schoolName'] != widget.schoolName) continue;
                  final cField = t['class'];
                  if (cField != null && cField.isNotEmpty) {
                    var classes = cField.split(',').map((e) => e.trim()).toList();
                    if (classes.contains(oldClassName)) {
                      final idx = classes.indexOf(oldClassName);
                      classes[idx] = newName;
                      t['class'] = classes.join(', ');
                      
                      FirebaseFirestore.instance.collection('users')
                          .where('username', isEqualTo: t['username'])
                          .get().then((query) {
                        if (query.docs.isNotEmpty) {
                          query.docs.first.reference.update({'class': classes.join(', ')});
                        }
                      });
                    }
                  }
                }

                // 3. Update the class itself
                DataStore.removeClassForSchool(widget.schoolName, oldClassName);
                DataStore.removeDeptForClass(widget.schoolName, oldClassName);
                DataStore.addClassForSchool(widget.schoolName, newName);
                DataStore.setDeptForClass(widget.schoolName, newName, currentDept);
                
                // Update allClasses just in case
                if (DataStore.allClasses.contains(oldClassName) && 
                    !DataStore.classesBySchool.values.any((list) => list.contains(oldClassName))) {
                  DataStore.allClasses.remove(oldClassName);
                  DataStore.classDepts.remove(oldClassName);
                }
                if (!DataStore.allClasses.contains(newName)) {
                  DataStore.allClasses.add(newName);
                  DataStore.classDepts[newName] = currentDept;
                }
                
                DataStore.saveAllData();
              });
              widget.onRefresh();
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _changeDept(String className, String currentDept) {
    final newDept = currentDept == 'HIFZ' ? 'DA\'WA' : 'HIFZ';
    setState(() {
      DataStore.setDeptForClass(widget.schoolName, className, newDept);
      DataStore.saveAllData();
    });
    widget.onRefresh();
  }

  Widget _deptSection(String dept) {
    final color = dept == 'HIFZ' ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);
    final classes = widget.classes.where((c) => (widget.classDepts[c] ?? 'DA\'WA') == dept).toList();
    final studentCount = widget.students.where((s) => classes.contains(s['std'] ?? '')).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Department header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(dept == 'HIFZ' ? Icons.menu_book_rounded : Icons.account_tree_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dept, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('$studentCount students Â· ${classes.length} classes',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.25),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _addClassDialog(dept: dept),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.add, size: 16), SizedBox(width: 4), Text('Add Class')],
                  ),
                ),
              ],
            ),
          ),

          // Classes list
          if (classes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No classes in $dept. Tap "Add Class" to start.',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: classes.map((c) {
                  final count = widget.students.where((s) => s['std'] == c).length;
                  return Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Class $c',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
                              Text('$count students',
                                  style: TextStyle(fontSize: 11, color: color.withOpacity(0.6))),
                            ],
                          ),
                          const SizedBox(width: 8),
                          // Move to other dept
                          Tooltip(
                            message: 'Move to ${dept == 'HIFZ' ? 'DA\'WA' : 'HIFZ'}',
                            child: InkWell(
                              onTap: () => _changeDept(c, dept),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.swap_horiz_rounded, size: 18, color: color.withOpacity(0.6)),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _editClassDialog(c, dept),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.edit_rounded, size: 18, color: color.withOpacity(0.6)),
                            ),
                          ),
                          InkWell(
                            onTap: () => _deleteClass(c),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded, size: 18, color: Colors.red.withOpacity(0.6)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _deptSection("DA'WA"),
          _deptSection("HIFZ"),
        ],
      ),
    );
  }
}

// â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
//  BROADCAST / MESSAGES TAB
// â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
class _BroadcastTab extends StatefulWidget {
  final List<Map<String, String>> teachers;
  final List<Map<String, String>> students;
  final String currentUsername;
  final String schoolName;
  final VoidCallback onRefresh;

  const _BroadcastTab({
    required this.teachers,
    required this.students,
    required this.currentUsername,
    required this.schoolName,
    required this.onRefresh,
  });

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab> {
  final _msgCtrl = TextEditingController();
  String _target = 'All Members';
  bool _sending = false;
  bool _mirrorToNoticeBoard = true;

  final List<String> _options = ['All Members', 'All Teachers', 'All Students'];

  List<Map<String, dynamic>> get _sentBroadcasts => DataStore.allMessages
      .where((m) => m['senderId'] == widget.currentUsername && m['isBroadcast'] == true)
      .toList()
      .reversed
      .toList()
      .cast<Map<String, dynamic>>();

  Future<void> _send() async { // renamed to avoid conflict if any, but added Future
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);

    List<String> targetIds = [];
    if (_target == 'All Teachers' || _target == 'All Members') {
      targetIds.addAll(widget.teachers.map((t) => t['username'] ?? '').where((id) => id.isNotEmpty));
    }
    if (_target == 'All Students' || _target == 'All Members') {
      targetIds.addAll(widget.students.map((s) => s['username'] ?? '').where((id) => id.isNotEmpty));
    }

    final timestamp = DateTime.now().toIso8601String();
    for (final peerId in targetIds) {
      final roomId = [widget.currentUsername, peerId]..sort();
      DataStore.allMessages.add({
        'senderId': widget.currentUsername,
        'senderName': 'Academic Director',
        'receiverId': peerId,
        'convKey': roomId.join('::'),
        'text': text,
        'timestamp': timestamp,
        'isBroadcast': true,
        'broadcastTarget': _target,
        'schoolName': widget.schoolName,
      });
    }

    // Mirror to Notice Board
    if (_mirrorToNoticeBoard) {
      DataStore.allBulletinCards.insert(0, {
        'title': 'New Announcement',
        'text': text,
        'date': timestamp,
        'schoolName': widget.schoolName,
      });
    }

    DataStore.saveAllData();

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _sending = false;
      _msgCtrl.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âœ… Broadcast sent & posted to Notice Board'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Compose area
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Broadcast Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              const Text('Send a message and optionally post to Notice Board',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),

              // Target selector
              Row(
                children: _options.map((opt) {
                  final sel = _target == opt;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _target = opt),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            opt.replaceAll('All ', '').replaceAll('Members', 'All'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Text input
              TextField(
                controller: _msgCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your message here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 14),
              
              Row(
                children: [
                   Checkbox(
                    value: _mirrorToNoticeBoard,
                    onChanged: (v) => setState(() => _mirrorToNoticeBoard = v!),
                    activeColor: const Color(0xFF6366F1),
                  ),
                  const Text('Also post to Notice Board', style: TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                ],
              ),

              const SizedBox(height: 10),

              // Send button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text(
                    _sending ? 'Sending...' : 'Send Broadcast to $_target',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Notice Board Management
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notice Board Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                        Text('Manage persistent cards on home screens', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    IconButton.filled(
                      onPressed: _showAddCardDialog,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: DataStore.allBulletinCards.where((b) => b['schoolName'] == widget.schoolName).toList().isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.dashboard_customize_outlined, size: 48, color: Colors.grey.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              const Text('No cards active. Click + to add.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: DataStore.allBulletinCards.where((b) => b['schoolName'] == widget.schoolName).toList().length,
                          itemBuilder: (context, idx) {
                            final myFilteredCards = DataStore.allBulletinCards.where((b) => b['schoolName'] == widget.schoolName).toList();
                            final card = myFilteredCards[idx];
                            final List<Color> colors = [Colors.blue, Colors.indigo, Colors.purple, Colors.teal, Colors.orange];
                            final Color cardColor = colors[idx % colors.length];
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                border: Border.all(color: cardColor.withOpacity(0.1)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Container(width: 5, color: cardColor),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(card['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E293B))),
                                              const SizedBox(height: 2),
                                              Text(card['text'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(Icons.event_note_rounded, size: 12, color: cardColor),
                                                  const SizedBox(width: 4),
                                                  Text(_formatDateTime(card['date']), style: TextStyle(fontSize: 10, color: cardColor, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                          child: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                                        ),
                                        onPressed: () {
                                          setState(() => DataStore.allBulletinCards.remove(card));
                                          DataStore.saveAllData();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddCardDialog() {
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.add_card_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 12),
                Text('Add Notice Board Card', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Card Information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Card Title',
                      prefixIcon: const Icon(Icons.title_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Card Content',
                      prefixIcon: const Icon(Icons.description_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Schedule Notice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setDialogState(() => selectedTime = picked);
                            }
                          },
                          icon: const Icon(Icons.access_time_rounded, size: 16),
                          label: Text(selectedTime.format(context)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) {
                    final finalDate = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    setState(() {
                      DataStore.allBulletinCards.add({
                        'title': titleCtrl.text,
                        'text': textCtrl.text,
                        'date': finalDate.toIso8601String(),
                        'schoolName': widget.schoolName,
                      });
                    });
                    DataStore.saveAllData();
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('ADD CARD', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  String _formatDateTime(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(date.toString());
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      final day = dt.day.toString().padLeft(2, '0');
      
      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) hour = 12;
      else if (hour > 12) hour -= 12;
      
      return '$dayName, $day $monthName ${dt.year} - $hour:$minute $period';
    } catch (e) {
      return date.toString();
    }
  }
}

// â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
//  STUDENTS MANAGEMENT TAB
// â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• â• 
class _StudentsManagementTab extends StatefulWidget {
  final List<Map<String, String>> students;
  final List<String> classes;
  final String Function(String) generateUsername;
  final String Function() generatePassword;
  final void Function(String, String, String) showCredentials;
  final VoidCallback onRefresh;
  final String schoolName;

  const _StudentsManagementTab({
    required this.students,
    required this.classes,
    required this.generateUsername,
    required this.generatePassword,
    required this.showCredentials,
    required this.onRefresh,
    required this.schoolName,
  });

  @override
  State<_StudentsManagementTab> createState() => _StudentsManagementTabState();
}

class _StudentsManagementTabState extends State<_StudentsManagementTab> {
  String? _selectedClassFilter;

  void _openAddStudent({int? index}) {
    final s = index != null ? widget.students[index] : null;
    final nameCtrl = TextEditingController(text: s?['name'] ?? '');
    final userCtrl = TextEditingController(text: s?['username'] ?? '');
    final passCtrl = TextEditingController(text: s?['password'] ?? '');
    String selectedClass = s?['std'] ?? (widget.classes.isNotEmpty ? widget.classes.first : '');
    String? photoBase64 = s?['photo'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(index != null ? 'Edit Student' : 'Add Student', style: const TextStyle(fontWeight: FontWeight.w900)),
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
                        setDs(() {
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
                _field(nameCtrl, 'Full Name', Icons.person_rounded),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedClass.isEmpty && widget.classes.isNotEmpty ? widget.classes.first : selectedClass,
                  decoration: InputDecoration(
                    labelText: 'Class',
                    prefixIcon: const Icon(Icons.class_rounded, color: Color(0xFF6366F1)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                  onChanged: (v) => setDs(() => selectedClass = v!),
                ),
                const Divider(height: 28),
                const Text('Credentials (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                _field(userCtrl, 'Username', Icons.account_circle_rounded),
                const SizedBox(height: 8),
                _field(passCtrl, 'Password', Icons.lock_rounded),
                const SizedBox(height: 4),
                const Text('Leave blank to auto-generate', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                
                final username = userCtrl.text.trim().isNotEmpty 
                  ? userCtrl.text.trim().toLowerCase()
                  : (index != null ? (s?['username'] ?? widget.generateUsername(name).toLowerCase()) : widget.generateUsername(name).toLowerCase());
                
                final password = passCtrl.text.trim().isNotEmpty
                  ? passCtrl.text.trim()
                  : (index != null ? (s?['password'] ?? widget.generatePassword()) : widget.generatePassword());

                // Check collisions (for new students)
                if (index == null && DataStore.allStudents.any((s) => (s['username'] ?? '').toLowerCase() == username)) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username collision! Generated username already exists.')));
                   return;
                }

                final Map<String, String> newData = Map<String, String>.from({
                    'name': name,
                    'std': selectedClass,
                    'username': username,
                    'password': password,
                    'schoolName': widget.schoolName,
                    'academicYear': DataStore.selectedAcademicYear,
                    'photo': photoBase64 ?? '',
                });

                if (index == null) {
                  try {
                    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                    await AuthService().registerUser({...newData, 'role': 'student'}, password);
                    Navigator.of(context, rootNavigator: true).pop(); // pop loading
                    Navigator.of(context, rootNavigator: true).pop(); // pop dialog
                    setState(() {
                      DataStore.allStudents.add(newData);
                      widget.students.add(newData);
                      DataStore.saveAllData();
                    });
                    widget.showCredentials('Student', username, password);
                  } catch (e) {
                    Navigator.of(context, rootNavigator: true).pop(); // pop loading
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red));
                    }
                    return;
                  }
                } else {
                  setState(() {
                    final oldData = widget.students[index];
                    final globalIndex = DataStore.allStudents.indexWhere((s) => s['username'] == oldData['username']);
                    if (globalIndex != -1) {
                      DataStore.allStudents[globalIndex] = newData;
                    }
                    widget.students[index] = newData;
                    DataStore.saveAllData();
                    
                    // Update in Firestore
                    FirebaseFirestore.instance.collection('users')
                        .where('username', isEqualTo: oldData['username'])
                        .get().then((query) {
                      if (query.docs.isNotEmpty) {
                        query.docs.first.reference.update(newData);
                      }
                    });

                    final oldUsername = oldData['username']!;
                    final newUsername = newData['username']!;
                    if (oldUsername != newUsername) {
                      FirebaseFirestore.instance.collection('teacher_photos').doc(oldUsername).delete();
                    }
                    FirebaseFirestore.instance.collection('teacher_photos')
                        .doc(newUsername)
                        .set({'username': newUsername, 'photo': newData['photo'] ?? ''}, SetOptions(merge: true));
                  });
                  Navigator.pop(context); // pop dialog
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Student "$name" updated locally!'), backgroundColor: Colors.green)
                    );
                  }
                }
                widget.onRefresh();
              },
              child: Text(index != null ? 'Update' : 'Add Student'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedClassFilter == null 
      ? widget.students 
      : widget.students.where((s) => s['std'] == _selectedClassFilter).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddStudent(),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
      children: [
        // Filter bar
        Container(
          height: 60,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FilterChip(
                label: const Text('All Classes'),
                selected: _selectedClassFilter == null,
                onSelected: (_) => setState(() => _selectedClassFilter = null),
              ),
              const SizedBox(width: 8),
              ...widget.classes.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('Class $c'),
                  selected: _selectedClassFilter == c,
                  onSelected: (v) => setState(() => _selectedClassFilter = v ? c : null),
                ),
              )),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
            ? _emptyState('No students found.', Icons.person_off_rounded)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                        backgroundImage: (s['photo'] != null && s['photo']!.isNotEmpty && s['photo'] != 'null') ? MemoryImage(base64Decode(s['photo']!)) : null,
                        child: (s['photo'] == null || s['photo']!.isEmpty) ? Text((s['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)) : null,
                      ),
                      title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Class ${s['std']} | @${s['username']}', style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_rounded, color: Color(0xFF6366F1), size: 20), onPressed: () => _openAddStudent(index: widget.students.indexOf(s))),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), onPressed: () {
                             showDialog(context: context, builder: (_) => AlertDialog(
                                title: const Text('Delete Student'),
                                content: Text('Delete ${s['name']}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
                                     setState(() {
                                       DataStore.allStudents.removeWhere((x) => x['username'] == s['username']);
                                       widget.students.remove(s);
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
                                     widget.onRefresh();
                                     Navigator.pop(context);
                                  }, child: const Text('Delete')),
                                ],
                             ));
                          }),
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

  Widget _emptyState(String msg, IconData icon) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Colors.grey.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text(msg, style: const TextStyle(color: Colors.grey)),
      ],
    ),
  );
}

