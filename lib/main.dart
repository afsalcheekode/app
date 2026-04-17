import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:math';

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _LoginScreenState.initPrefs();
  runApp(const BridgeApp());
}

class BridgeApp extends StatelessWidget {
  const BridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bridge',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.unknown},
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075E54), // Premium dark blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// LOGIN SCREEN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  
  // Static list to store all teachers, schools, and students (shared across app)
  static List<Map<String, String>> _allTeachers = [
    {
      'name': 'Sample Teacher',
      'username': 'teacher',
      'password': '123',
      'class': '01',
      'subjects': 'Math, Science'
    }
  ];
  static List<Map<String, String>> _allSchools = [
    {'school': 'Sample School', 'username': 'manager', 'password': '123'}
  ];
  static List<Map<String, String>> _allStudents = [
    {
      'name': 'Sample Student',
      'username': 'student',
      'password': '123',
      'std': '01',
      'address': 'Sample Address',
      'parents': 'Sample Parents',
      'place': 'Sample Place',
      'phone': '1234567890',
      'blood': 'O+'
    }
  ];
  static List<Map<String, dynamic>> _allExams = [];
  static List<Map<String, dynamic>> _allMessages = [];
  static List<Map<String, dynamic>> _allGroups = []; // Class groups and staff groups
  static List<Map<String, dynamic>> _allGroupMembers = []; // Group memberships
  static List<Map<String, dynamic>> _allActivities = [];
  static List<Map<String, dynamic>> _allFairItems = [];
  static List<Map<String, dynamic>> _allResults = [];
  static List<Map<String, dynamic>> _allActivitySubmissions = []; // studentUsername -> activityId -> isDone, score
  static List<Map<String, dynamic>> _allFairPayments = []; // studentUsername -> fairId -> isPaid
  static List<Map<String, dynamic>> _allAttendance = []; // { studentUsername, date, periods: { "1": "P", ... } }
  static Map<String, dynamic> _allTimetables = {}; // class -> { dayIndex: [sub1, sub2, ...] }
  static List<String> _holidayDates = []; // ["2026-04-16", ...]
  static List<Map<String, dynamic>> _allMetrics = [];
  static List<String> _allClasses = ['01', '02', '03', '04', '05'];
  static Map<String, bool> _featureConfig = {
    'Students': true,
    'Activities': true,
    'Fairs': true,
    'Schedule': true,
    'Results': true,
    'Messages': true,
    'Groups': true,
    'Attendance': true,
  };
  
  static SharedPreferences? _prefs;

  static Future<void> initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadAllData();
  }

  static void _loadAllData() {
    if (_prefs == null) return;
    
    final schoolsStr = _prefs!.getString('all_schools');
    if (schoolsStr != null) {
      final List decoded = jsonDecode(schoolsStr);
      if (decoded.isNotEmpty) {
        _allSchools = decoded.map((s) => Map<String, String>.from(s)).toList();
      }
    }
    
    final teachersStr = _prefs!.getString('all_teachers');
    if (teachersStr != null) {
      final List decoded = jsonDecode(teachersStr);
      if (decoded.isNotEmpty) {
        _allTeachers = decoded.map((t) => Map<String, String>.from(t)).toList();
      }
    }
    
    final studentsStr = _prefs!.getString('all_students');
    if (studentsStr != null) {
      final List decoded = jsonDecode(studentsStr);
      if (decoded.isNotEmpty) {
        _allStudents = decoded.map((s) => Map<String, String>.from(s)).toList();
      }
    }

    final examsStr = _prefs!.getString('all_exams');
    if (examsStr != null) {
      final List decoded = jsonDecode(examsStr);
      _allExams = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    final messagesStr = _prefs!.getString('all_messages');
    if (messagesStr != null) {
      final List decoded = jsonDecode(messagesStr);
      _allMessages = decoded.map((m) => Map<String, dynamic>.from(m)).toList();
    }

    final groupsStr = _prefs!.getString('all_groups');
    if (groupsStr != null) {
      final List decoded = jsonDecode(groupsStr);
      _allGroups = decoded.map((g) => Map<String, dynamic>.from(g)).toList();
    }

    final groupMembersStr = _prefs!.getString('all_group_members');
    if (groupMembersStr != null) {
      final List decoded = jsonDecode(groupMembersStr);
      _allGroupMembers = decoded.map((gm) => Map<String, dynamic>.from(gm)).toList();
    }

    final activitiesStr = _prefs!.getString('all_activities');
    if (activitiesStr != null) {
      final List decoded = jsonDecode(activitiesStr);
      _allActivities = decoded.map((a) => Map<String, dynamic>.from(a)).toList();
    }

    final fairStr = _prefs!.getString('all_fair_items');
    if (fairStr != null) {
      final List decoded = jsonDecode(fairStr);
      _allFairItems = decoded.map((f) => Map<String, dynamic>.from(f)).toList();
    }

    final resultsStr = _prefs!.getString('all_results');
    if (resultsStr != null) {
      final List decoded = jsonDecode(resultsStr);
      _allResults = decoded.map((r) => Map<String, dynamic>.from(r)).toList();
    }

    final subStr = _prefs!.getString('all_activity_submissions');
    if (subStr != null) {
      final List decoded = jsonDecode(subStr);
      _allActivitySubmissions = decoded.map((s) => Map<String, dynamic>.from(s)).toList();
    }

    final payStr = _prefs!.getString('all_fair_payments');
    if (payStr != null) {
      final List decoded = jsonDecode(payStr);
      _allFairPayments = decoded.map((p) => Map<String, dynamic>.from(p)).toList();
    }

    final attStr = _prefs!.getString('all_attendance');
    if (attStr != null) {
      final List decoded = jsonDecode(attStr);
      _allAttendance = decoded.map((a) => Map<String, dynamic>.from(a)).toList();
    }

    final ttStr = _prefs!.getString('all_timetables');
    if (ttStr != null) {
      _allTimetables = jsonDecode(ttStr);
    }

    final holStr = _prefs!.getString('holiday_dates');
    if (holStr != null) {
      final List decoded = jsonDecode(holStr);
      _holidayDates = decoded.map((d) => d.toString()).toList();
    }

    // Migration: Ensure all activities have IDs
    bool activityChanged = false;
    for (var a in _allActivities) {
      if (a['id'] == null) {
        a['id'] = 'act_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
        activityChanged = true;
      }
    }
    
    // Migration: Ensure all fairs have IDs
    bool fairChanged = false;
    for (var f in _allFairItems) {
      if (f['id'] == null) {
        f['id'] = 'fair_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
        fairChanged = true;
      }
    }
    if (activityChanged || fairChanged) saveAllData();

    final classesStr = _prefs!.getString('all_classes');
    if (classesStr != null) {
      final List decoded = jsonDecode(classesStr);
      if (decoded.isNotEmpty) {
        _allClasses = decoded.map((c) => c.toString()).toList();
      }
    }

    final metricsStr = _prefs!.getString('all_metrics');
    if (metricsStr != null) {
      final List decodedList = jsonDecode(metricsStr);
      _allMetrics = decodedList.map((m) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(m);
        // Recover IconData and MaterialColor from stored values
        // Note: For simple recovery, we map back codepoints/values. 
        // This is a simplified reconstruction.
        return {
          'title': data['title'],
          'value': data['value'],
          'icon': IconData(data['icon'], fontFamily: 'MaterialIcons'),
          'color': _getColorFromValue(data['color']),
          'targetIndex': data['targetIndex'],
        };
      }).toList();
    }

    final configStr = _prefs!.getString('feature_config');
    if (configStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(configStr);
      _featureConfig = decoded.map((key, value) => MapEntry(key, value as bool));
    }
  }

  static MaterialColor _getColorFromValue(int value) {
    const colors = [Colors.teal, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.pink, Colors.teal, Colors.green];
    for (var c in colors) {
       if (c.value == value) return c;
    }
    return Colors.teal; // Default
  }

  static Future<void> saveAllData() async {
    if (_prefs == null) return;
    await _prefs!.setString('all_schools', jsonEncode(_allSchools));
    await _prefs!.setString('all_teachers', jsonEncode(_allTeachers));
    await _prefs!.setString('all_students', jsonEncode(_allStudents));
    await _prefs!.setString('all_exams', jsonEncode(_allExams));
    await _prefs!.setString('all_messages', jsonEncode(_allMessages));
    await _prefs!.setString('all_groups', jsonEncode(_allGroups));
    await _prefs!.setString('all_group_members', jsonEncode(_allGroupMembers));
    await _prefs!.setString('all_activities', jsonEncode(_allActivities));
    await _prefs!.setString('all_fair_items', jsonEncode(_allFairItems));
    await _prefs!.setString('all_results', jsonEncode(_allResults));
    await _prefs!.setString('all_attendance', jsonEncode(_allAttendance));
    await _prefs!.setString('all_timetables', jsonEncode(_allTimetables));
    await _prefs!.setString('holiday_dates', jsonEncode(_holidayDates));
    await _prefs!.setString('all_activity_submissions', jsonEncode(_allActivitySubmissions));
    await _prefs!.setString('all_fair_payments', jsonEncode(_allFairPayments));
    await _prefs!.setString('all_classes', jsonEncode(_allClasses));
    await _prefs!.setString('feature_config', jsonEncode(_featureConfig));
    
    // Convert metrics to serializable format (storing codepoints for icons, values for colors)
    final serializableMetrics = _allMetrics.map((m) => {
      'title': m['title'],
      'value': m['value'],
      'icon': m['icon'] is IconData ? (m['icon'] as IconData).codePoint : m['icon'],
      'color': m['color'] is MaterialColor ? (m['color'] as MaterialColor).value : m['color'],
      'targetIndex': m['targetIndex'],
    }).toList();
    await _prefs!.setString('all_metrics', jsonEncode(serializableMetrics));
  }

  void _login() {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both username and password.')),
      );
      return;
    }

    if (user == 'minad' && pass == '321') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminBoardScreen()),
      );
    } else {
      // Check if it's a teacher login
      Map<String, String>? teacher;
      try {
        teacher = _allTeachers.firstWhere(
          (t) => t['username'] == user && t['password'] == pass,
        );
      } catch (e) {
        // Teacher not found
      }
      
      if (teacher != null) {
        // Teacher login - navigate to teacher board with assigned class
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherBoardScreen(
              teacherName: teacher!['name'] ?? 'Teacher',
              assignedClass: teacher['class'] ?? '',
              subjects: teacher['subjects'] ?? '',
              teacherUsername: teacher['username'] ?? '',
            ),
          ),
        );
      } else {
        // Check student login
        Map<String, String>? student;
        try {
          student = _allStudents.firstWhere((s) => s['username'] == user && s['password'] == pass);
        } catch(e) {
          student = null;
        }
        if (student != null) {
          // Student login - navigate to student board
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StudentBoardScreen(
                studentName: student!['name'] ?? 'Student',
                studentClass: student['std'] ?? '',
                studentUsername: student['username'] ?? '',
                studentData: student,
              ),
            ),
          );
        } else {
          // Manager login
          Map<String, String>? school;
          try {
            school = _allSchools.firstWhere((s) => s['username'] == user && s['password'] == pass);
          } catch (e) {
            school = null;
          }

          if (school != null) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SchoolDashboardScreen(schoolName: school!['school'] ?? 'Unknown School')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials.')));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeInEntrance(
      child: Scaffold(
        backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Header
              FadeInEntrance(
                delay: 0.2,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.hub_rounded, size: 80, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'BRIDGE',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Color(0xFF075E54),
                      ),
                    ),
                    Text(
                      'LEARNING MANAGEMENT SYSTEM',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),

              // Glassmorphism Login Card
              FadeInEntrance(
                delay: 0.4,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 15))
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _userController,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.person_outline_rounded, color: colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _login,
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }
}

// ==========================================
// ADMIN BOARD SCREEN
// ==========================================
class AdminBoardScreen extends StatefulWidget {
  const AdminBoardScreen({super.key});

  @override
  State<AdminBoardScreen> createState() => _AdminBoardScreenState();
}

class _AdminBoardScreenState extends State<AdminBoardScreen> {
  // Use the global schools list
  List<Map<String, String>> get _schools => _LoginScreenState._allSchools;

  void _showAddSchoolSheet({int? index}) {
    final s = index != null ? _schools[index] : null;
    final nameCtrl = TextEditingController(text: s?['school'] ?? '');
    final managerCtrl = TextEditingController(text: s?['manager'] ?? '');
    final userCtrl = TextEditingController(text: s?['username'] ?? '');
    final passCtrl = TextEditingController(text: s?['password'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                index != null ? 'Edit School' : 'Add New School',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF075E54),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'School Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.school, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: managerCtrl,
                decoration: InputDecoration(
                  labelText: 'Manager Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userCtrl,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.account_circle, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    setState(() {
                      if (index != null) {
                        _schools[index] = {
                          'school': nameCtrl.text,
                          'manager': managerCtrl.text,
                          'username': userCtrl.text,
                          'password': passCtrl.text,
                        };
                      } else {
                        _schools.add({
                          'school': nameCtrl.text,
                          'manager': managerCtrl.text,
                          'username': userCtrl.text,
                          'password': passCtrl.text,
                        });
                      }
                      _LoginScreenState.saveAllData();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(index != null ? 'School updated successfully!' : 'School added successfully!')),
                    );
                  },
                  child: Text(
                    index != null ? 'Update School' : 'Add School',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return FadeInEntrance(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        toolbarHeight: 90,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        title: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'ADMIN',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w100,
                letterSpacing: 12,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            const Text(
              'Bridge',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Let's simplify our curriculum\nand make learning fun!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w200,
                  height: 1.5,
                  color: colorScheme.primary.withOpacity(0.08),
                ),
              ),
            ),
          ),
          _schools.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 72, color: colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Bridge Admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 4,
                      width: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _schools.length,
                  itemBuilder: (context, index) {
                    final s = _schools[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.school, color: Colors.white)),
                        title: Text(s['school'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Manager: ${s['manager']} | User: ${s['username']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.teal), onPressed: () => _showAddSchoolSheet(index: index)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() => _schools.removeAt(index));
                                _LoginScreenState.saveAllData();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
      bottomNavigationBar: InkWell(
        onTap: () => _showAddSchoolSheet(),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              )
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.domain_add, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Add School',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// ==========================================
// SCHOOL DASHBOARD SCREEN
// ==========================================
class SchoolDashboardScreen extends StatefulWidget {
  final String schoolName;
  const SchoolDashboardScreen({super.key, required this.schoolName});

  @override
  State<SchoolDashboardScreen> createState() => _SchoolDashboardScreenState();
}

// Update the global teacher list when manager adds/updates teachers
void _updateGlobalTeacherList(List<Map<String, String>> teachers) {
  _LoginScreenState._allTeachers = List.from(teachers);
  _LoginScreenState.saveAllData();
}

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen> {
  int _currentIndex = -1; // -1: Overview, 0: Std, 1: Teacher, 2: Exam, 3: Msg
  final ScrollController _navLeftController = ScrollController();
  final ScrollController _navRightController = ScrollController();

  @override
  void initState() {
    super.initState();
    _navLeftController.addListener(() {
      if (_navLeftController.offset != _navRightController.offset) {
        _navRightController.jumpTo(_navLeftController.offset);
      }
    });
    _navRightController.addListener(() {
      if (_navRightController.offset != _navLeftController.offset) {
        _navLeftController.jumpTo(_navRightController.offset);
      }
    });
  }

  @override
  void dispose() {
    _navLeftController.dispose();
    _navRightController.dispose();
    super.dispose();
  }

  // Use global static lists from _LoginScreenState for persistence
  List<String> get _classes => _LoginScreenState._allClasses;
  List<Map<String, String>> get _students => _LoginScreenState._allStudents;
  List<Map<String, String>> get _teachers => _LoginScreenState._allTeachers;
  List<Map<String, dynamic>> get _exams => _LoginScreenState._allExams;
  List<Map<String, dynamic>> get _messages => _LoginScreenState._allMessages;
  List<Map<String, dynamic>> get _groups => _LoginScreenState._allGroups;
  List<Map<String, dynamic>> get _groupMembers => _LoginScreenState._allGroupMembers;

  // Metrics for Overview page
  final List<Map<String, dynamic>> _metrics = [
    {'title': 'Classes', 'value': '3', 'icon': Icons.class_, 'color': Colors.teal, 'targetIndex': 0},
    {'title': 'Teachers', 'value': '50+', 'icon': Icons.badge, 'color': Colors.green, 'targetIndex': 1},
    {'title': 'Schedule', 'value': '5+', 'icon': Icons.calendar_month, 'color': Colors.orange, 'targetIndex': 2},
    {'title': 'Rewards', 'value': '100+', 'icon': Icons.emoji_events, 'color': Colors.purple, 'targetIndex': -1},
  ];

  String? _selectedClassInTab; // New state to handle drill-down

  // Credentials Helper Methods
  String _generatePassword() {
    final rnd = Random();
    String pass = '';
    // Generate a unique 4-digit random number
    do {
      pass = (1000 + rnd.nextInt(9000)).toString();
    } while (_students.any((s) => s['password'] == pass) || _teachers.any((t) => t['password'] == pass));
    return pass;
  }

  String _generateUsername(String name) {
    if (name.isEmpty) return 'user${Random().nextInt(1000)}';
    // Use the full name as username (teacher preference)
    return name.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').replaceAll(' ', '.');
  }

  void _showCredentialsDialog(String type, String username, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New $type added!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Here are the login credentials. Please note them down.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Username: '), SelectableText(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Password: '), SelectableText(password, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT')),
        ],
      ),
    );
  }

  void _showAddMessageDialog() {
    final receiverCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: receiverCtrl, decoration: const InputDecoration(labelText: 'Receivers (e.g. All Teachers)', prefixIcon: Icon(Icons.people))),
            TextField(controller: messageCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Message Body', prefixIcon: Icon(Icons.text_fields))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (messageCtrl.text.isEmpty) return;
              setState(() {
                _messages.add({
                  'receivers': receiverCtrl.text,
                  'text': messageCtrl.text,
                });
                _LoginScreenState.saveAllData();
              });
              Navigator.pop(context);
            },
            child: const Text('Send'),
          )
        ],
      )
    );
  }

  void _showAddStudentDialog({int? index, String? defaultClass}) {
    final s = index != null ? _students[index] : null;
    final nameCtrl = TextEditingController(text: s?['name'] ?? '');
    final addressCtrl = TextEditingController(text: s?['address'] ?? '');
    final parentsCtrl = TextEditingController(text: s?['parents'] ?? '');
    final placeCtrl = TextEditingController(text: s?['place'] ?? '');
    final phoneCtrl = TextEditingController(text: s?['phone'] ?? '');
    final bloodCtrl = TextEditingController(text: s?['blood'] ?? '');
    String? password = s?['password'] ?? (1000 + Random().nextInt(8999)).toString();
    final userCtrl = TextEditingController(text: s?['username'] ?? '');
    final passCtrl = TextEditingController(text: password);

    if (index == null) {
      nameCtrl.addListener(() {
        if (userCtrl.text.isEmpty || userCtrl.text == nameCtrl.text.toLowerCase().replaceAll(' ', '.')) {
          userCtrl.text = nameCtrl.text.toLowerCase().replaceAll(' ', '.');
        }
      });
    }
    String? selectedClass = s?['std'] ?? defaultClass ?? (_classes.isNotEmpty ? _classes.first : null);
    if ((selectedClass == null || !_classes.contains(selectedClass)) && _classes.isNotEmpty) {
      selectedClass = _classes.first;
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
                if (index != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('User: ', style: TextStyle(fontWeight: FontWeight.bold)), Text(s?['username'] ?? '')]),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Pass: ', style: TextStyle(fontWeight: FontWeight.bold)), Text(s?['password'] ?? '')]),
                      ],
                    ),
                  ),
                  const Divider(),
                ],
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Student Name *', prefixIcon: Icon(Icons.person))),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address *', prefixIcon: Icon(Icons.location_on))),
                TextField(controller: parentsCtrl, decoration: const InputDecoration(labelText: "Parent's Name *", prefixIcon: Icon(Icons.family_restroom))),
                TextField(controller: placeCtrl, decoration: const InputDecoration(labelText: 'Place *', prefixIcon: Icon(Icons.map))),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone))),
                TextField(controller: bloodCtrl, decoration: const InputDecoration(labelText: 'Blood Group', prefixIcon: Icon(Icons.bloodtype))),
                const Divider(height: 32),
                const Text('Login Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.account_circle))),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock))),
                if (_classes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    decoration: const InputDecoration(labelText: 'Std (Class)'),
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setStateDialog(() => selectedClass = val),
                  ),
                ] else
                   const Padding(padding: EdgeInsets.only(top: 8), child: Text('Add a class first!', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty || parentsCtrl.text.isEmpty || placeCtrl.text.isEmpty || phoneCtrl.text.isEmpty || userCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields (*)')));
                  return;
                }
                
                String username = userCtrl.text.trim();
                String password = passCtrl.text.trim();

                setState(() {
                  final Map<String, String> newData = {
                    'name': nameCtrl.text,
                    'address': addressCtrl.text,
                    'parents': parentsCtrl.text,
                    'place': placeCtrl.text,
                    'phone': phoneCtrl.text,
                    'blood': bloodCtrl.text,
                    'std': selectedClass ?? 'None',
                    'username': username,
                    'password': password,
                  };
                  if (index != null) {
                    _students[index] = newData;
                  } else {
                    _students.add(newData);
                    // Defer showing the dialog after the current dialog is closed
                    Future.delayed(const Duration(milliseconds: 100), () {
                       _showCredentialsDialog('Student', username, password);
                    });
                    
                    // Auto-enroll student in class group
                    final className = selectedClass ?? 'None';
                    // Find or create class group
                    var classGroup = _groups.where((g) => 
                      g['type'] == 'class' && g['class_name'] == className
                    ).firstOrNull;
                    
                    if (classGroup == null) {
                      // Create new class group
                      classGroup = {
                        'id': 'class_${className.toLowerCase().replaceAll(' ', '_')}',
                        'name': 'Class $className Group',
                        'type': 'class',
                        'class_name': className,
                        'created_by': widget.schoolName,
                        'created_at': DateTime.now().toIso8601String(),
                      };
                      _groups.add(classGroup as Map<String, String>);
                    }
                    
                    // Add student as group member
                    _groupMembers.add({
                      'group_id': classGroup['id']!,
                      'user_id': username,
                      'role': 'member',
                      'type': 'student',
                    });
                    _LoginScreenState.saveAllData();
                  }
                  _LoginScreenState.saveAllData();
                });
                Navigator.pop(context);
              },
              child: Text(index != null ? 'Update' : 'Add'),
            )
          ],
        )
      ),
    );
  }

  void _showAddTeacherDialog({int? index}) {
    final t = index != null ? _teachers[index] : null;
    final nameCtrl = TextEditingController(text: t?['name'] ?? '');
    String? selectedClass = t?['class'];
    if ((selectedClass == null || !_classes.contains(selectedClass)) && _classes.isNotEmpty) {
      selectedClass = _classes.first;
    }
    final subjectCtrl = TextEditingController(text: t?['subjects'] ?? '');
    final usernameCtrl = TextEditingController(text: t?['username'] ?? '');
    final passwordCtrl = TextEditingController(text: t?['password'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(index != null ? 'Edit Teacher' : 'Add Teacher',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
                ),
                if (_classes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Class',
                      prefixIcon: Icon(Icons.class_),
                      border: OutlineInputBorder(),
                    ),
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setStateDialog(() => selectedClass = val),
                  ),
                ] else
                   const Padding(
                     padding: EdgeInsets.only(top: 8),
                     child: Text('Add a class first in Students tab!', style: TextStyle(color: Colors.red, fontSize: 12)),
                   ),
                const SizedBox(height: 8),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subjects', prefixIcon: Icon(Icons.book)),
                ),
                if (index != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  ),
                  const SizedBox(height: 8),
                  // Editable username with copy button
                  TextField(
                    controller: usernameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.account_circle, color: Colors.green),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copy username',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: usernameCtrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Username copied!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.green.shade50,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Editable password with copy button
                  TextField(
                    controller: passwordCtrl,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock, color: Colors.green),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copy password',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: passwordCtrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password copied!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.green.shade50,
                    ),
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

                final username = index != null
                    ? (usernameCtrl.text.isNotEmpty ? usernameCtrl.text : (t?['username'] ?? _generateUsername(nameCtrl.text)))
                    : _generateUsername(nameCtrl.text);
                final password = index != null
                    ? (passwordCtrl.text.isNotEmpty ? passwordCtrl.text : (t?['password'] ?? _generatePassword()))
                    : _generatePassword();

                setState(() {
                  final newData = {
                    'name': nameCtrl.text,
                    'class': selectedClass ?? '',
                    'subjects': subjectCtrl.text,
                    'username': username,
                    'password': password,
                  };
                  if (index != null) {
                    _teachers[index] = newData;
                  } else {
                    _teachers.add(newData);
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _showCredentialsDialog('Teacher', username, password);
                    });
                    
                    // Auto-create class group for this teacher's class
                    final className = (selectedClass ?? '').trim();
                    if (className.isNotEmpty) {
                      setState(() {
                        // Check if group already exists
                        final existingGroup = _groups.where((g) => 
                          g['type'] == 'class' && g['class_name'] == className
                        ).firstOrNull;
                        
                        if (existingGroup == null) {
                          // Create new class group
                          final newGroup = {
                            'id': 'class_${className.toLowerCase().replaceAll(' ', '_')}',
                            'name': 'Class $className Group',
                            'type': 'class',
                            'class_name': className,
                            'created_by': widget.schoolName,
                            'created_at': DateTime.now().toIso8601String(),
                          };
                          _groups.add(newGroup);
                          
                          // Add teacher as group admin
                          _groupMembers.add({
                            'group_id': newGroup['id'],
                            'user_id': username,
                            'role': 'admin',
                            'type': 'teacher',
                          });
                        }
                      });
                      _LoginScreenState.saveAllData();
                    }
                    _LoginScreenState.saveAllData();
                  }
                  // Update global teacher list for login
                  _updateGlobalTeacherList(_teachers);
                });
                Navigator.pop(context);
              },
              child: Text(index != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExamDialog({int? index}) {
    final e = index != null ? _exams[index] : null;
    final nameCtrl = TextEditingController(text: e?['examName'] ?? '');
    String? selectedClass = e?['class'];
    if ((selectedClass == null || !_classes.contains(selectedClass)) && _classes.isNotEmpty) {
      selectedClass = _classes.first;
    }
    List<Map<String, String>> subjects = List<Map<String, String>>.from(
      (e?['subjects'] as List?)?.map((item) => Map<String, String>.from(item)) ?? []
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setFullState) => AlertDialog(
          title: Text(index != null ? 'Edit Exam' : 'Add Exam'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Exam Name', prefixIcon: Icon(Icons.assignment))),
                if (_classes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      prefixIcon: Icon(Icons.class_),
                      border: OutlineInputBorder(),
                    ),
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setFullState(() => selectedClass = val),
                  ),
                ] else
                   const Padding(
                     padding: EdgeInsets.only(top: 8),
                     child: Text('Add a class first in Students tab!', style: TextStyle(color: Colors.red, fontSize: 12)),
                   ),
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
                        title: const Text('Add Subject'),
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
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                setState(() {
                  final newData = {
                    'examName': nameCtrl.text,
                    'class': selectedClass,
                    'subjects': subjects,
                  };
                  if (index != null) {
                    _exams[index] = newData;
                  } else {
                    _exams.add(newData);
                  }
                  _LoginScreenState.saveAllData();
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

  void _showEditMetricDialog({int? index}) {
    final colorScheme = Theme.of(context).colorScheme;
    final m = index != null ? _metrics[index] : null;
    final titleCtrl = TextEditingController(text: m?['title'] ?? '');
    final valueCtrl = TextEditingController(text: m?['value'] ?? '');
    
    final List<IconData> icons = [Icons.school, Icons.badge, Icons.event, Icons.emoji_events, Icons.assignment, Icons.people, Icons.book, Icons.star, Icons.notifications, Icons.analytics];
    IconData selectedIcon = m?['icon'] ?? icons.first;
    
    final List<MaterialColor> colors = [Colors.teal, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.pink, Colors.teal, Colors.green];
    MaterialColor selectedColor = m?['color'] ?? colors.first;

    int selectedTarget = m?['targetIndex'] ?? -1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(index != null ? 'Edit Overview Card' : 'Add Overview Card', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Card Title', hintText: 'e.g. Students', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: valueCtrl, decoration: const InputDecoration(labelText: 'Display Value', hintText: 'e.g. 1000+', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                const Text('Target Page (On Tap)', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<int>(
                  value: selectedTarget,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: -1, child: Text('None (Just info)')),
                    DropdownMenuItem(value: 0, child: Text('Students Tab')),
                    DropdownMenuItem(value: 1, child: Text('Teachers Tab')),
                    DropdownMenuItem(value: 2, child: Text('Exams Tab')),
                    DropdownMenuItem(value: 3, child: Text('Messages Tab')),
                  ],
                  onChanged: (val) => setStateDialog(() => selectedTarget = val ?? -1),
                ),
                const SizedBox(height: 20),
                const Text('Pick an Icon', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: icons.map((icon) => GestureDetector(
                    onTap: () => setStateDialog(() => selectedIcon = icon),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: selectedIcon == icon ? colorScheme.primary.withOpacity(0.1) : Colors.grey.shade100,
                      child: Icon(icon, color: selectedIcon == icon ? colorScheme.primary : Colors.grey, size: 20),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                const Text('Theme Color', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: colors.map((color) => GestureDetector(
                    onTap: () => setStateDialog(() => selectedColor = color),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: color,
                      child: selectedColor == color ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            if (index != null)
              TextButton(
                onPressed: () {
                  setState(() => _metrics.removeAt(index));
                  Navigator.pop(context);
                },
                child: const Text('Delete Card', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
              onPressed: () {
                if (titleCtrl.text.isEmpty) return;
                setState(() {
                  final newData = {
                    'title': titleCtrl.text,
                    'value': valueCtrl.text,
                    'icon': selectedIcon,
                    'color': selectedColor,
                    'targetIndex': selectedTarget,
                  };
                  if (index != null) {
                    _metrics[index] = newData;
                  } else {
                    _metrics.add(newData);
                  }
                });
                Navigator.pop(context);
              },
              child: Text(index != null ? 'Save Changes' : 'Add Card'),
            )
          ],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        leading: _currentIndex != -1 ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _currentIndex = -1),
        ) : null,
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bridge',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.schoolName.toUpperCase()} MANAGER',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w200,
                letterSpacing: 4,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
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
        child: Row(
          children: [
            Expanded(
              child: ListView(
                controller: _navLeftController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                   _buildNavItem(Icons.dashboard, 'Overall', -1, colorScheme),
                   _buildNavItem(Icons.class_, 'Class', 0, colorScheme),
                   _buildNavItem(Icons.person, 'Teacher', 1, colorScheme),
                ],
              ),
            ),
            _buildCentralAddButton(colorScheme, () => _showEditMetricDialog()),
            Expanded(
              child: ListView(
                controller: _navRightController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                   _buildNavItem(Icons.calendar_month, 'Schedule', 2, colorScheme),
                   _buildNavItem(Icons.message, 'Msg', 3, colorScheme),
                   _buildNavItem(Icons.settings, 'Features', 4, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // To truly sync two controllers in Flutter easily:
  void _syncScrolls() {
    // In a production app, we'd use a more robust syncing mechanism, 
    // but the user wants 'single row' feel.
    // The most premium way is actually a single Row with a HOLE.
  }

  Widget _buildCentralAddButton(ColorScheme colorScheme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54, height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool isEnabled = true}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colorScheme.primary : (isEnabled ? Colors.grey : Colors.grey.withOpacity(0.2));
    
    return InkWell(
      onTap: isEnabled ? () {
        setState(() {
          if (_currentIndex == index) {
            _currentIndex = -1;
          } else {
            _currentIndex = index;
            _selectedClassInTab = null; 
          }
        });
      } : null,
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
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_currentIndex) {
      case 0: return _buildStudentsTab(colorScheme);
      case 1: return _buildTeachersTab(colorScheme);
      case 2: return _buildScheduleTab(colorScheme);
      case 3: return _buildMessagesTab(colorScheme);
      case 4: return _buildFeatureTab(colorScheme);
      case -1:
      default: return _buildOverview(colorScheme);
    }
  }

  Widget _buildFeatureTab(ColorScheme colorScheme) {
    final features = _LoginScreenState._featureConfig;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Feature Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: features.keys.map((f) {
              final isEnabled = features[f] ?? false;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isEnabled ? 1.0 : 0.4,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isEnabled ? Colors.green.shade50 : Colors.red.shade50,
                      child: Icon(
                        isEnabled ? Icons.check_circle : Icons.cancel,
                        color: isEnabled ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(f, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(isEnabled ? 'This feature is active' : 'This feature is hidden', style: TextStyle(color: Colors.grey.shade600)),
                    trailing: Switch(
                      value: isEnabled,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setState(() {
                           _LoginScreenState._featureConfig[f] = val;
                           _LoginScreenState.saveAllData();
                        });
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: _metrics.length,
            itemBuilder: (context, index) {
              final m = _metrics[index];
              return FadeInEntrance(
                delay: index * 0.1,
                child: _buildMetricCard(m['title'], m['value'], m['icon'], m['color'], m['targetIndex'], index),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, MaterialColor color, int targetIndex, int metricIndex) {
    return GestureDetector(
      onTap: () {
        if (targetIndex != -1) setState(() => _currentIndex = targetIndex);
      },
      onLongPress: () => _showEditMetricDialog(index: metricIndex),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: color.shade50,
                    radius: 24,
                    child: Icon(icon, color: color.shade700, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                onPressed: () => _showEditMetricDialog(index: metricIndex),
                tooltip: 'Edit / Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab(ColorScheme colorScheme) {
    if (_selectedClassInTab == null) {
      // Show Classes List
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Classes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final c = _classes[index];
                final count = _students.where((s) => s['std'] == c).length;
                    return FadeInEntrance(
                      delay: index * 0.05,
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.class_)),
                          title: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$count Students'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Class'),
                                    content: Text('Are you sure you want to delete Class $c? Students in this class will not be deleted but will no longer be grouped under this class.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      TextButton(onPressed: () {
                                        setState(() {
                                          _LoginScreenState._allClasses.remove(c);
                                          _LoginScreenState.saveAllData();
                                        });
                                        Navigator.pop(context);
                                      }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => setState(() => _selectedClassInTab = c),
                        ),
                      ),
                    );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                   final classCtrl = TextEditingController();
                   showDialog(
                     context: context,
                     builder: (context) => AlertDialog(
                       title: const Text('Add Class'),
                       content: TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'Class Name (e.g. Class 9)')),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                         TextButton(onPressed: () {
                           if (classCtrl.text.isNotEmpty) {
                             setState(() {
                               _LoginScreenState._allClasses.add(classCtrl.text);
                               _LoginScreenState.saveAllData();
                             });
                           }
                           Navigator.pop(context);
                         }, child: const Text('Add')),
                       ],
                     ),
                   );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Class', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
              ),
            ),
          ),
        ],
      );
    } else {
      // Show Students in the selected class
      final filteredStudents = _students.asMap().entries.where((e) => e.value['std'] == _selectedClassInTab).toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedClassInTab = null)),
                Text('$_selectedClassInTab - Students', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: filteredStudents.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 60, color: Colors.grey.shade400),
                    const Text('No students in this class.'),
                  ],
                ))
              : ListView.builder(
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final entry = filteredStudents[index];
                    final s = entry.value;
                    final realIndex = entry.key;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        onTap: () => _showAddStudentDialog(index: realIndex),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          child: Text(s['name']?[0] ?? 'S', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Parent: ${s['parents']} | Place: ${s['place']}'),
                            Text('Phone: ${s['phone']} | Blood: ${s['blood'] ??'N/A'}'),
                            Text('User: ${s['username']} | Pass: ${s['password']}', style: const TextStyle(fontSize: 10, color: Colors.teal)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() => _students.removeAt(realIndex));
                            _LoginScreenState.saveAllData();
                          },
                        ),
                      ),
                    );
                  },
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showAddStudentDialog(defaultClass: _selectedClassInTab),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Student to Class', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildTeachersTab(ColorScheme colorScheme) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Teachers List', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _teachers.isEmpty
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No teachers added yet.'),
                ],
              ))
            : ListView.builder(
                itemCount: _teachers.length,
                itemBuilder: (context, index) {
                  final t = _teachers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      onTap: () => _showAddTeacherDialog(index: index),
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Subjects: ${t['subjects']} | User: ${t['username']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _teachers.removeAt(index)),
                      ),
                    ),
                  );
                },
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showAddTeacherDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Teacher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab(ColorScheme colorScheme) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Class Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Color(0xFF0F172A))),
        ),
        Expanded(
          child: _exams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      const Text('Schedule is empty', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _exams.length,
                  itemBuilder: (context, index) {
                    final item = _exams[index];
                    final String type = item['type'] ?? 'Exam';
                    final bool isExam = type == 'Exam';
                    final List subs = item['subjects'] ?? [];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isExam ? Colors.orange.shade50 : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(isExam ? Icons.assignment : Icons.event, color: isExam ? Colors.orange.shade700 : Colors.teal.shade700),
                          ),
                          title: Text(item['title'] ?? item['examName'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                          subtitle: Text(isExam ? '${subs.length} Subjects' : '${item['dates']} • ${item['time']}', style: TextStyle(color: isExam ? Colors.orange.shade800 : Colors.teal.shade800, fontSize: 13, fontWeight: FontWeight.w700)),
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
                                    const SizedBox(height: 12),
                                    if (item['days']?.toString().isNotEmpty == true) 
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          const Text('Days: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                          Text(item['days'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
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

  Widget _buildMessagesTab(ColorScheme colorScheme) {
    // Group students by class, then show classes. Clicking class => students list => chat
    final classes = _classes;
    final allStudents = _students;
    final allTeachers = _teachers;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
          ),
          child: const Row(
            children: [
              Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        // Section: Teachers
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (allTeachers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Teachers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1.2)),
                ),
                ...allTeachers.map((t) => _buildContactTile(
                  context: context,
                  colorScheme: colorScheme,
                  avatar: t['name']?[0].toUpperCase() ?? 'T',
                  avatarColor: Colors.green,
                  name: t['name'] ?? '',
                  subtitle: 'Teacher • Class ${t['class']}',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DirectChatScreen(
                      peerId: t['username'] ?? '',
                      peerName: t['name'] ?? '',
                      peerDept: 'Class ${t['class']}',
                      peerColor: Colors.green,
                      myId: 'manager',
                      myName: 'Manager',
                      onBack: () => Navigator.pop(context),
                    ),

                  )),
                )),
              ],
              // By class
              ...classes.map((cls) {
                final clsStudents = allStudents.where((s) => s['std'] == cls).toList();
                if (clsStudents.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('Class $cls', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1.2)),
                    ),
                    ...clsStudents.map((s) => _buildContactTile(
                      context: context,
                      colorScheme: colorScheme,
                      avatar: s['name']?[0].toUpperCase() ?? 'S',
                      avatarColor: Colors.orange,
                      name: s['name'] ?? '',
                      subtitle: 'Student • Class $cls',
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DirectChatScreen(
                          peerId: s['username'] ?? '',
                          peerName: s['name'] ?? '',
                          peerDept: 'Class $cls',
                          peerColor: Colors.orange,
                          myId: 'manager',
                          myName: 'Manager',
                          onBack: () => Navigator.pop(context),
                        ),

                      )),
                    )),
                  ],
                );
              }),
              if (allStudents.isEmpty && allTeachers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No teachers or students added yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String avatar,
    required MaterialColor avatarColor,
    required String name,
    required String subtitle,
    required VoidCallback onTap,
    String? lastMessage,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: avatarColor.shade100,
              child: Text(avatar, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: avatarColor.shade700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage ?? subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }


}

// ==========================================
// STUDENT BOARD SCREEN
// ==========================================
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

class _StudentBoardScreenState extends State<StudentBoardScreen> {
  int _currentIndex = 0; 
  
  // Use global static lists for persistence
  List<Map<String, String>> get _allStudents => _LoginScreenState._allStudents;
  List<Map<String, dynamic>> get _activities => _LoginScreenState._allActivities.where((a) => a['std'] == widget.studentClass).toList();
  List<Map<String, dynamic>> get _exams => _LoginScreenState._allExams.where((e) => e['class'] == widget.studentClass).toList();
  List<Map<String, dynamic>> get _results => _LoginScreenState._allResults.where((r) => r['studentName'] == widget.studentName).toList();
  List<Map<String, dynamic>> get _messages => _LoginScreenState._allMessages;
  List<Map<String, dynamic>> get _fairList => _LoginScreenState._allFairItems.where((f) => f['class'] == widget.studentClass || f['class'] == null).toList();
  List<Map<String, dynamic>> get _groups => _LoginScreenState._allGroups;
  List<Map<String, String>> get _teachers => _LoginScreenState._allTeachers;

  // Search controllers for historical data
  final TextEditingController _examSearchCtrl = TextEditingController();
  final TextEditingController _resultSearchCtrl = TextEditingController();
  
  // States for messaging
  String? _activeChatPeerId;
  final ScrollController _chatScrollCtrl = ScrollController();
  final TextEditingController _chatMsgCtrl = TextEditingController();
  bool _chatEmojiOpen = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 3 seconds to ensure real-time sync with teacher board
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) setState(() {});
    });
    _loadAllDataIfNecessary();
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
      final config = _LoginScreenState._featureConfig;
      final List<Map<String, dynamic>> all = [
        {'title': 'Activities', 'value': '${_activities.length}', 'icon': Icons.play_circle_fill, 'color': Colors.green, 'targetIndex': 1, 'feature': 'Activities'},
        {'title': 'Fairs', 'value': '${_fairList.length}', 'icon': Icons.local_activity, 'color': Colors.pink, 'targetIndex': 2, 'feature': 'Fairs'},
        {'title': 'Schedule', 'value': '${_exams.length}', 'icon': Icons.calendar_month, 'color': Colors.orange, 'targetIndex': 3, 'feature': 'Schedule'},
        {'title': 'Results', 'value': '${_results.length}', 'icon': Icons.analytics, 'color': Colors.purple, 'targetIndex': 4, 'feature': 'Results'},
        {'title': 'Attendance', 'value': 'VIEW', 'icon': Icons.how_to_reg, 'color': Colors.blue, 'targetIndex': 7, 'feature': 'Attendance'},
        {'title': 'Messages', 'value': 'P2P', 'icon': Icons.message, 'color': Colors.teal, 'targetIndex': 5, 'feature': 'Messages'},
        {'title': 'Announce', 'value': 'CHAT', 'icon': Icons.campaign, 'color': Colors.indigo, 'targetIndex': 6, 'feature': 'Groups'},
      ];
      return all.where((m) => config[m['feature']] ?? true).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Class ${widget.studentClass}', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
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
            _buildNavItem(Icons.home, 'Home', 0, colorScheme),
            _buildNavItem(Icons.play_circle_fill, 'Act', 1, colorScheme, isEnabled: _LoginScreenState._featureConfig['Activities'] ?? true),
            _buildNavItem(Icons.local_activity, 'Fair', 2, colorScheme, isEnabled: _LoginScreenState._featureConfig['Fairs'] ?? true),
            _buildNavItem(Icons.calendar_month, 'Sched', 3, colorScheme, isEnabled: _LoginScreenState._featureConfig['Schedule'] ?? true),
            _buildNavItem(Icons.analytics, 'Res', 4, colorScheme, isEnabled: _LoginScreenState._featureConfig['Results'] ?? true),
            _buildNavItem(Icons.how_to_reg, 'Attnd', 7, colorScheme, isEnabled: _LoginScreenState._featureConfig['Attendance'] ?? true),
            _buildNavItem(Icons.message, 'Msg', 5, colorScheme, isEnabled: _LoginScreenState._featureConfig['Messages'] ?? true),
            _buildNavItem(Icons.campaign, 'Announce', 6, colorScheme, isEnabled: _LoginScreenState._featureConfig['Groups'] ?? true),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool isEnabled = true}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colorScheme.primary : (isEnabled ? Colors.grey : Colors.grey.withOpacity(0.2));
    return InkWell(
      onTap: isEnabled ? () => setState(() => _currentIndex = index) : null,
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
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceDetailForStudent(ColorScheme colorScheme) {
    final myAttendance = _LoginScreenState._allAttendance.where((a) => a['studentUsername'] == widget.studentUsername).toList();
    
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('My Attendance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        ),
        if (myAttendance.isEmpty)
          const Expanded(child: Center(child: Text('No attendance records found.')))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: myAttendance.length,
              itemBuilder: (context, index) {
                final rec = myAttendance[index];
                final pMap = rec['periods'] as Map? ?? {};
                final fn = pMap['FN'] ?? '-';
                final an = pMap['AN'] ?? '-';
                            final DateTime dt = DateTime.tryParse(rec['date'] ?? '') ?? DateTime.now();
                final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final String dayName = weekdays[dt.weekday - 1];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$dayName | ${rec['date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
                          ],
                        ),
                      ),
                      _attendanceBadge('Before Noon', fn),
                      const SizedBox(width: 8),
                      _attendanceBadge('After Noon', an),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
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
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard Overview', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Hello, ${widget.studentName}!', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Welcome back to Class ${widget.studentClass}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Academic Hub', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          GridView.builder(

            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: _metrics.length,
            itemBuilder: (context, index) {
              final m = _metrics[index];
              return FadeInEntrance(
                delay: index * 0.1,
                child: _buildMetricCard(m['title'], m['value'], m['icon'], m['color'], index: m['targetIndex']),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Recent Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          ...(_activities.take(3).map((a) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.play_circle_fill)),
              title: Text(a['title'] ?? 'Activity'),
              subtitle: Text(a['description'] ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _currentIndex = 1),
            ),
          ))),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, {int? index}) {
    return GestureDetector(
      onTap: index != null ? () => setState(() => _currentIndex = index) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 24,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
          ],
        ),
      ),
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
                    final submission = _LoginScreenState._allActivitySubmissions.firstWhere(
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
                            subtitle: Text('${a['type']} • Due: ${a['date'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                          if (isDone) 
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Score Received: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                    Text('$score / ${a['marks']}', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green.shade900, fontSize: 16)),
                                  ],
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
          child: Text('School Fairs', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Color(0xFF0F172A))),
        ),
        Expanded(
          child: _fairList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_activity_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      const Text('No fairs added.', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _fairList.length,
                  itemBuilder: (context, index) {
                    final f = _fairList[index];
                    final payment = _LoginScreenState._allFairPayments.firstWhere(
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
                        title: Text(f['title'] ?? 'Fair Item', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        subtitle: Text('${f['description']}\nDue: ${f['date'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${f['amount'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
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
                          subtitle: Text(isExam ? '${subs.length} Subjects' : '${item['dates']} • ${item['time']}', style: TextStyle(color: isExam ? Colors.orange.shade800 : Colors.teal.shade800, fontSize: 13, fontWeight: FontWeight.w700)),
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

  Widget _buildMessagesTab(ColorScheme colorScheme) {
    // Collect all potential contacts (all students in class + all teachers + manager)
    final List<Map<String, dynamic>> allContacts = [
      ..._teachers.map((t) => {
        "id": t['username'],
        "name": t['name'],
        "role": "Teacher",
        "dept": "Class ${t['class']}",
        "color": "0xFF009688",
      }),
      ..._allStudents.where((s) => s['std'] == widget.studentClass && s['username'] != widget.studentUsername).map((s) => {
        "id": s['username'],
        "name": s['name'],
        "role": "Student",
        "dept": "Peer",
        "color": "0xFFFF9800",
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
                subtitle: Text('${c['role']} • ${c['dept']}'),
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
            _reactionOption(msg, '👍'),
            _reactionOption(msg, '❤️'),
            _reactionOption(msg, '✅'),
          ],
        ),
      ),
    );
  }

  Widget _reactionOption(Map<String, dynamic> msg, String emoji) {
    Color bg = Colors.grey.shade100;
    if (emoji == '👍') bg = Colors.yellow.shade100;
    if (emoji == '❤️') bg = Colors.red.shade100;
    if (emoji == '✅') bg = Colors.green.shade100;

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
      final index = _LoginScreenState._allMessages.indexWhere((m) => m['timestamp'] == msg['timestamp'] && m['from'] == msg['from']);
      if (index != -1) {
        final Map<String, dynamic> reactions = Map<String, dynamic>.from(_LoginScreenState._allMessages[index]['reactions'] ?? {});
        reactions[widget.studentUsername] = emoji;
        _LoginScreenState._allMessages[index]['reactions'] = reactions;
        _LoginScreenState.saveAllData();
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
          if (e.key == '👍') { bg = Colors.yellow.shade50; border = Colors.yellow.shade200; }
          if (e.key == '❤️') { bg = Colors.red.shade50; border = Colors.red.shade200; }
          if (e.key == '✅') { bg = Colors.green.shade50; border = Colors.green.shade200; }

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
      _LoginScreenState.saveAllData();
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
    final List<String> mentions = ['@activities', '@fair', '@exam', '@result'];
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
              if (word.toLowerCase() == '@fair') targetIndex = 2;
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
      _LoginScreenState._allMessages.add({
        'group_id': groupId,
        'convKey': groupId, // Consistent indexing
        'from': widget.studentName,
        'senderId': widget.studentUsername,
        'senderType': 'Student',
        'text': ctrl.text,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _LoginScreenState.saveAllData();
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
}

// ==========================================
// TEACHER BOARD SCREEN
// ==========================================
class TeacherBoardScreen extends StatefulWidget {
  final String teacherName;
  final String assignedClass;
  final String subjects;
  final String teacherUsername;

  const TeacherBoardScreen({
    super.key,
    required this.teacherName,
    required this.assignedClass,
    required this.subjects,
    required this.teacherUsername,
  });

  @override
  State<TeacherBoardScreen> createState() => _TeacherBoardScreenState();
}

class _TeacherBoardScreenState extends State<TeacherBoardScreen> {
  int _currentIndex = -1; // -1: Overview, 0: Students, 1: Activities, 2: Fair, 3: Exam, 4: Result, 5: Message, 6: Group
  String? _teacherSelectedClass;

  @override
  void initState() {
    super.initState();
    _teacherSelectedClass = widget.assignedClass;
    

    // Auto-refresh every 3 seconds to ensure real-time sync
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
       if (mounted) setState(() {});
    });
    
    // Load data for assigned class
    _loadDataForAssignedClass();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Use global static lists for persistence
  List<String> get _classes => _LoginScreenState._allClasses;
  List<Map<String, String>> get _allStudents => _LoginScreenState._allStudents;
  List<Map<String, dynamic>> get _activities => _LoginScreenState._allActivities.where((a) => a['std'] == (_teacherSelectedClass ?? widget.assignedClass)).toList();
  List<Map<String, dynamic>> get _exams => _LoginScreenState._allExams.where((e) => e['class'] == (_teacherSelectedClass ?? widget.assignedClass)).toList();
  List<Map<String, dynamic>> get _results => _LoginScreenState._allResults.where((r) => 
    _students.any((s) => s['name'] == r['studentName'])
  ).toList();
  List<Map<String, dynamic>> get _messages => _LoginScreenState._allMessages;
  List<Map<String, dynamic>> get _fairList => _LoginScreenState._allFairItems.where((f) => f['class'] == (_teacherSelectedClass ?? widget.assignedClass) || f['class'] == null).toList();
  List<Map<String, dynamic>> get _groups => _LoginScreenState._allGroups;
  List<Map<String, dynamic>> get _groupMembers => _LoginScreenState._allGroupMembers;
  List<Map<String, String>> get _teachers => _LoginScreenState._allTeachers;

  List<Map<String, String>> get _students => _allStudents.where((s) => s['std'] == (_teacherSelectedClass ?? widget.assignedClass)).toList();
  
  // New data for Fair and Progress
  final List<String> _fairs = ['Science Fair 2024', 'Arts & Crafts', 'Coding Challenge', 'Math Olympiad'];
  final Map<String, List<Map<String, dynamic>>> _studentFairs = {}; // studentName -> list of fairs with status
  final Map<String, double> _studentProgress = {}; // studentName -> progress percentage

  // Metrics for Overview page (now dynamic getter)


  Timer? _refreshTimer;


  List<Map<String, dynamic>> get _metrics {
    final config = _LoginScreenState._featureConfig;
    final List<Map<String, dynamic>> allMetrics = [
      {'title': 'Students', 'value': '${_students.length}', 'icon': Icons.people, 'color': Colors.teal, 'targetIndex': 0, 'feature': 'Students'},
      {'title': 'Activities', 'value': '${_activities.length}', 'icon': Icons.play_circle_fill, 'color': Colors.green, 'targetIndex': 1, 'feature': 'Activities'},
      {'title': 'Fairs', 'value': '${_fairList.length}', 'icon': Icons.local_activity, 'color': Colors.pink, 'targetIndex': 2, 'feature': 'Fairs'},
      {'title': 'Schedule', 'value': '${_exams.length}', 'icon': Icons.calendar_month, 'color': Colors.orange, 'targetIndex': 3, 'feature': 'Schedule'},
      {'title': 'Results', 'value': '${_results.length}', 'icon': Icons.analytics, 'color': Colors.purple, 'targetIndex': 4, 'feature': 'Results'},
      {'title': 'Attendance', 'value': 'LOG', 'icon': Icons.how_to_reg, 'color': Colors.blue, 'targetIndex': 7, 'feature': 'Attendance'},
      {'title': 'Messages', 'value': '${_messages.length}', 'icon': Icons.message, 'color': Colors.teal, 'targetIndex': 5, 'feature': 'Messages'},
      {'title': 'Announce', 'value': '${_teachers.length + _allStudents.length}', 'icon': Icons.campaign, 'color': Colors.green, 'targetIndex': 6, 'feature': 'Groups'},
    ];
    return allMetrics.where((m) => config[m['feature']] ?? true).toList();
  }

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

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bridge',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            Text(
              'TEACHER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w200,
                letterSpacing: 4,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            Text(
              '${widget.teacherName} | Class: ${widget.assignedClass}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
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

  Widget _buildTeacherNavContent(ColorScheme colorScheme) {
    final List<Widget> allItems = [
      _buildNavItem(Icons.class_, 'Students', 0, colorScheme, isEnabled: _LoginScreenState._featureConfig['Students'] ?? true),
      _buildNavItem(Icons.play_circle_fill, 'Activities', 1, colorScheme, isEnabled: _LoginScreenState._featureConfig['Activities'] ?? true),
      _buildNavItem(Icons.local_activity, 'Fair', 2, colorScheme, isEnabled: _LoginScreenState._featureConfig['Fairs'] ?? true),
      _buildNavItem(Icons.calendar_month, 'Schedule', 3, colorScheme, isEnabled: _LoginScreenState._featureConfig['Schedule'] ?? true),
      _buildNavItem(Icons.analytics, 'Result', 4, colorScheme, isEnabled: _LoginScreenState._featureConfig['Results'] ?? true),
      _buildNavItem(Icons.how_to_reg, 'Attnd', 7, colorScheme, isEnabled: _LoginScreenState._featureConfig['Attendance'] ?? true),
      _buildNavItem(Icons.message, 'Msg', 5, colorScheme, isEnabled: _LoginScreenState._featureConfig['Messages'] ?? true),
      _buildNavItem(Icons.campaign, 'Announce', 6, colorScheme, isEnabled: _LoginScreenState._featureConfig['Groups'] ?? true),
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

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool isEnabled = true}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colorScheme.primary : (isEnabled ? Colors.grey : Colors.grey.withOpacity(0.2));
    return InkWell(
      onTap: isEnabled ? () {
        setState(() {
          if (_currentIndex == index) {
            _currentIndex = -1;
          } else {
            _currentIndex = index;
          }
        });
      } : null,
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
              Icon(icon, color: color, size: 22),
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
                  'std': widget.assignedClass,
                };
                if (index != null) {
                  final oldData = _activities[index];
                  final globalIdx = _LoginScreenState._allActivities.indexOf(oldData);
                  if (globalIdx != -1) _LoginScreenState._allActivities[globalIdx] = data;
                } else {
                  _LoginScreenState._allActivities.add(data);
                }
                setState(() {});
                _LoginScreenState.saveAllData();
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
        title: Text(index != null ? 'Edit Fair' : 'Add Fair'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Fair Name', prefixIcon: Icon(Icons.local_activity))),
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
                  'class': widget.assignedClass,
                };
                if (index != null) {
                  final oldData = _fairList[index];
                  final globalIdx = _LoginScreenState._allFairItems.indexOf(oldData);
                  if (globalIdx != -1) _LoginScreenState._allFairItems[globalIdx] = data;
                } else {
                  _LoginScreenState._allFairItems.add(data);
                }
                setState(() {});
                _LoginScreenState.saveAllData();
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
    final classCtrl = TextEditingController(text: widget.assignedClass);
    
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
                    'class': widget.assignedClass,
                    'description': descCtrl.text,
                    'days': daysCtrl.text,
                    'dates': datesCtrl.text,
                    'time': timeCtrl.text,
                    'subjects': selectedType == 'Exam' ? subjects : null,
                  };
                  if (index != null) {
                    final oldData = _exams[index];
                    final globalIdx = _LoginScreenState._allExams.indexOf(oldData);
                    if (globalIdx != -1) _LoginScreenState._allExams[globalIdx] = newData;
                  } else {
                    _LoginScreenState._allExams.add(newData);
                  }
                  setState(() {});
                  _LoginScreenState.saveAllData();
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
    final tempTotalMarkCtrl = TextEditingController(text: '100');
    final tempScoredMarkCtrl = TextEditingController();
    
    // Get all exams for this teacher's class
    List<Map<String, dynamic>> classExams = [];
    for (var exam in _exams) {
      if (exam['class'] == widget.assignedClass) {
        classExams.add(exam);
      }
    }

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
                    tempScoredMarkCtrl.clear();
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
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: tempSelectedSubject,
                                    decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.book)),
                                    items: getSubjectsForSelectedExam().where((s) => !subjectResults.any((r) => r['subject'] == s)).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                    onChanged: (val) => setStateDialog(() => tempSelectedSubject = val),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: tempTotalMarkCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Total', prefixIcon: Icon(Icons.star_outline)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: tempScoredMarkCtrl,
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) => setStateDialog((){}),
                                    decoration: const InputDecoration(labelText: 'Scored', prefixIcon: Icon(Icons.star)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: tempSelectedSubject == null || tempScoredMarkCtrl.text.isEmpty ? null : () {
                                setStateDialog(() {
                                  subjectResults.add({
                                    'subject': tempSelectedSubject,
                                    'totalMarks': tempTotalMarkCtrl.text,
                                    'scoredMark': tempScoredMarkCtrl.text,
                                  });
                                  tempSelectedSubject = null;
                                  tempScoredMarkCtrl.clear();
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
                  };
                  if (index != null) {
                    final oldData = _results[index];
                    final globalIdx = _LoginScreenState._allResults.indexOf(oldData);
                    if (globalIdx != -1) _LoginScreenState._allResults[globalIdx] = data;
                  } else {
                    _LoginScreenState._allResults.add(data);
                  }
                  setState(() {});
                  _LoginScreenState.saveAllData();
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
                    DropdownMenuItem(value: 'To Manager', child: Text('To Manager')),
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
                    'receivers': selectedType == 'To Manager' ? 'Manager' : (selectedReceiver ?? 'Class'),
                    'text': messageCtrl.text,
                  };
                  if (index != null) {
                    _messages[index] = data;
                  } else {
                    _messages.add(data);
                  }
                  setState(() {});
                  _LoginScreenState.saveAllData();
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
    final _name = nameCtrl ?? TextEditingController(text: s?['name'] ?? '');
    final _address = addressCtrl ?? TextEditingController(text: s?['address'] ?? '');
    final _parents = parentsCtrl ?? TextEditingController(text: s?['parents'] ?? '');
    final _place = placeCtrl ?? TextEditingController(text: s?['place'] ?? '');
    final _phone = phoneCtrl ?? TextEditingController(text: s?['phone'] ?? '');
    final _blood = bloodCtrl ?? TextEditingController(text: s?['blood'] ?? '');
    final _user = userCtrl ?? TextEditingController(text: s?['username'] ?? '');
    final _pass = passCtrl ?? TextEditingController(text: s?['password'] ?? (1000 + Random().nextInt(8999)).toString());

    if (index == null && userCtrl == null) {
      _name.addListener(() {
        if (_user.text.isEmpty || _user.text == _name.text.toLowerCase().replaceAll(' ', '.')) {
          _user.text = _name.text.toLowerCase().replaceAll(' ', '.');
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
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Student Name *', prefixIcon: Icon(Icons.person))),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address *', prefixIcon: Icon(Icons.location_on))),
                TextField(controller: _parents, decoration: const InputDecoration(labelText: "Parent's Name *", prefixIcon: Icon(Icons.family_restroom))),
                TextField(controller: _place, decoration: const InputDecoration(labelText: 'Place *', prefixIcon: Icon(Icons.map))),
                TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone))),
                TextField(controller: _blood, decoration: const InputDecoration(labelText: 'Blood Group', prefixIcon: Icon(Icons.bloodtype))),
                const Divider(height: 32),
                const Text('Login Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(controller: _user, decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.account_circle))),
                TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _teacherSelectedClass,
                  decoration: const InputDecoration(labelText: 'Select Class', prefixIcon: Icon(Icons.class_)),
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                  onChanged: (val) {
                    setStateDialog(() {
                       _teacherSelectedClass = val;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_name.text.isEmpty || _address.text.isEmpty || _user.text.isEmpty || _pass.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields (*)')));
                return;
              }
              
              // Find selected class from the form if handled differently, but here we can just use _teacherSelectedClass or add a local variable
              // For simplicity, let's use the current selected filter class as default
              
              setState(() {
                final studentData = {
                  'name': _name.text,
                  'address': _address.text,
                  'parents': _parents.text,
                  'place': _place.text,
                  'phone': _phone.text,
                  'blood': _blood.text,
                  'std': _teacherSelectedClass ?? widget.assignedClass,
                  'username': _user.text.trim(),
                  'password': _pass.text.trim(),
                };
                
                if (index != null) {
                  _allStudents[index] = studentData;
                } else {
                  _allStudents.add(studentData);
                  
                  // Auto-enroll student in class group
                  final className = widget.assignedClass;
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
                }
                setState(() {});
                _LoginScreenState.saveAllData();
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
        // Add Student logic
        final nameCtrl = TextEditingController();
        final addressCtrl = TextEditingController();
        final parentsCtrl = TextEditingController();
        final placeCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final bloodCtrl = TextEditingController();
        final userCtrl = TextEditingController();
        final passCtrl = TextEditingController(text: (1000 + Random().nextInt(8999)).toString());

        nameCtrl.addListener(() {
          if (userCtrl.text.isEmpty || userCtrl.text == nameCtrl.text.toLowerCase().replaceAll(' ', '.')) {
             userCtrl.text = nameCtrl.text.toLowerCase().replaceAll(' ', '.');
          }
        });

        _showStudentFormDialog(nameCtrl: nameCtrl, addressCtrl: addressCtrl, parentsCtrl: parentsCtrl, placeCtrl: placeCtrl, phoneCtrl: phoneCtrl, bloodCtrl: bloodCtrl, userCtrl: userCtrl, passCtrl: passCtrl);
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
                if (_LoginScreenState._featureConfig['Students'] ?? true) ListTile(leading: const Icon(Icons.person_add), title: const Text('Add Student'), onTap: () { Navigator.pop(context); setState(() { _currentIndex = 0; }); _showAddItemDialog(); }),
                if (_LoginScreenState._featureConfig['Activities'] ?? true) ListTile(leading: const Icon(Icons.play_circle_fill), title: const Text('Add Activity'), onTap: () { Navigator.pop(context); _showAddActivityDialog(); }),
                if (_LoginScreenState._featureConfig['Fairs'] ?? true) ListTile(leading: const Icon(Icons.local_activity), title: const Text('Add Fair'), onTap: () { Navigator.pop(context); _showAddFairDialog(); }),
                if (_LoginScreenState._featureConfig['Schedule'] ?? true) ListTile(leading: const Icon(Icons.calendar_month), title: const Text('Add to Schedule'), onTap: () { Navigator.pop(context); _showAddScheduleDialog(); }),
                if (_LoginScreenState._featureConfig['Results'] ?? true) ListTile(leading: const Icon(Icons.analytics), title: const Text('Add Result'), onTap: () { Navigator.pop(context); _showAddResultDialog(); }),
                if (_LoginScreenState._featureConfig['Messages'] ?? true) ListTile(leading: const Icon(Icons.message), title: const Text('Send Message'), onTap: () { Navigator.pop(context); _showSendMessageDialog(); }),
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
      case 6: return _buildGlobalGroupTab(colorScheme);
      case 7: return _buildAttendanceTab(colorScheme);
      case -1:
      default: return _buildOverview(colorScheme);
    }
  }

  Widget _buildOverview(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${widget.teacherName}!',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            'Assigned Class: ${widget.assignedClass} | Subjects: ${widget.subjects}',
            style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Overview',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: _metrics.length,
            itemBuilder: (context, index) {
              final m = _metrics[index];
              return FadeInEntrance(
                delay: index * 0.1,
                child: _buildMetricCard(
                  m['title'],
                  m['value'],
                  m['icon'],
                  m['color'],
                  m['targetIndex'],
                  index,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, MaterialColor color, int targetIndex, int metricIndex) {
    return GestureDetector(
      onTap: () {
        if (targetIndex != -1) setState(() => _currentIndex = targetIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: color.shade50,
                    radius: 24,
                    child: Icon(icon, color: color.shade700, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab(ColorScheme colorScheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _teacherSelectedClass,
                  decoration: const InputDecoration(labelText: 'Select Class', border: OutlineInputBorder()),
                  items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _teacherSelectedClass = val;
                      setState(() {});
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  if (_teacherSelectedClass == null) return;
                  final cls = _teacherSelectedClass!;
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Current Class'),
                      content: Text('Are you sure you want to delete Class $cls?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(onPressed: () {
                          setState(() {
                            _LoginScreenState._allClasses.remove(cls);
                            _LoginScreenState.saveAllData();
                            _teacherSelectedClass = _classes.isNotEmpty ? _classes.first : widget.assignedClass;
                          });
                          Navigator.pop(context);
                        }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final classCtrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Add New Class'),
                      content: TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'Class Name (e.g. 06)')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(onPressed: () {
                          if (classCtrl.text.isNotEmpty) {
                            setState(() {
                              _LoginScreenState._allClasses.add(classCtrl.text);
                              _LoginScreenState.saveAllData();
                              _teacherSelectedClass = classCtrl.text;
                            });
                          }
                          Navigator.pop(context);
                        }, child: const Text('Add')),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('New Class'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No students in Class $_teacherSelectedClass'),
                      const SizedBox(height: 8),
                      const Text('Click the "+" button to add students.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final s = _students[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        onTap: () => _showStudentDetails(s),
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          child: Text(s['name']?[0] ?? 'S', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Place: ${s['place']} | Phone: ${s['phone']}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              final studentIndex = _allStudents.indexOf(s);
                              _showStudentFormDialog(index: studentIndex);
                            } else if (val == 'msg') {
                              setState(() {
                                _currentIndex = 5; // Msg tab
                                _activeChatPeerId = s['username'];
                                _activeChatPeerName = s['name'];
                                _activeChatPeerColor = Colors.teal;
                                _activeChatPeerDept = 'Class ${widget.assignedClass}';
                              });
                            } else if (val == 'delete') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Student'),
                                  content: Text('Are you sure you want to delete ${s['name']}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                    TextButton(onPressed: () {
                                      setState(() {
                                        _allStudents.remove(s);
                                        _LoginScreenState.saveAllData();
                                      });
                                      Navigator.pop(context);
                                    }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.teal), title: Text('Edit'))),
                            const PopupMenuItem(value: 'msg', child: ListTile(leading: Icon(Icons.message, color: Colors.blue), title: Text('Message'))),
                            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'))),
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

  Widget _buildActivitiesTab(ColorScheme colorScheme) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Activities List'),
              Tab(text: 'Participation'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: List
                Column(
                  children: [
                    Expanded(
                      child: _activities.isEmpty
                          ? const Center(child: Text('No activities added yet.'))
                          : ListView.builder(
                              itemCount: _activities.length,
                              itemBuilder: (context, index) {
                                final a = _activities[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(Icons.play_circle_fill, color: Colors.green)),
                                    title: Text(a['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${a['type']} | Marks: ${a['marks']}'),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showAddActivityDialog(index: index);
                                        } else if (val == 'delete') {
                                          setState(() {
                                            _LoginScreenState._allActivities.remove(a);
                                            _LoginScreenState.saveAllData();
                                          });
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.teal), title: Text('Edit'))),
                                        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'))),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                // Tab 2: Participation
                ListView.builder(
                  itemCount: _activities.length,
                  itemBuilder: (context, aIndex) {
                    final a = _activities[aIndex];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
                        leading: const CircleAvatar(child: Icon(Icons.check_circle, color: Colors.green)),
                        title: Text(a['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Update student scores'),
                        children: _students.map((s) {
                          final subIdx = _LoginScreenState._allActivitySubmissions.indexWhere((sub) => 
                            sub['studentUsername'] == s['username'] && sub['activityId'] == a['id']
                          );
                          final Map<String, dynamic> submission = subIdx != -1 
                              ? _LoginScreenState._allActivitySubmissions[subIdx]
                              : {'isCompleted': false, 'score': '0'};
                              
                          return ListTile(
                            leading: CircleAvatar(radius: 14, child: Text(s['name']?[0] ?? 'S', style: const TextStyle(fontSize: 10))),
                            title: Text(s['name'] ?? ''),
                            subtitle: submission['isCompleted'] == true ? Text('Score: ${submission['score']}') : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: submission['isCompleted'] == true,
                                  onChanged: (val) {
                                    setState(() {
                                      _updateActivityStatus(s['username']!, s['name']!, a, val, submission['score']?.toString());
                                    });
                                  },
                                ),
                                if (submission['isCompleted'] == true) 
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, size: 20),
                                    onPressed: () {
                                      final scCtrl = TextEditingController(text: submission['score']?.toString());
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Enter Score'),
                                          content: TextField(controller: scCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Score')),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                            ElevatedButton(onPressed: () {
                                              setState(() {
                                                _updateActivityStatus(s['username']!, s['name']!, a, true, scCtrl.text);
                                              });
                                              Navigator.pop(ctx);
                                            }, child: const Text('Save')),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFairTab(ColorScheme colorScheme) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Fairs List'),
              Tab(text: 'Student Participation'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Fairs List
                Column(
                  children: [
                    Expanded(
                      child: _fairList.isEmpty
                          ? const Center(child: Text('No fairs added yet.'))
                          : ListView.builder(
                              itemCount: _fairList.length,
                              itemBuilder: (context, index) {
                                final f = _fairList[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.star, color: Colors.pink)),
                                    title: Text(f['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${f['description']}\nAmount: ${f['amount']} | Due: ${f['date']}'),
                                    isThreeLine: true,
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showAddFairDialog(index: index);
                                        } else if (val == 'delete') {
                                          setState(() {
                                            _LoginScreenState._allFairItems.remove(f);
                                            _LoginScreenState.saveAllData();
                                          });
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.teal), title: Text('Edit'))),
                                        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'))),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                // Tab 2: Student Participation (Original View)
                ListView.builder(
                  itemCount: _fairList.length,
                  itemBuilder: (context, fIndex) {
                    final f = _fairList[fIndex];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
                        leading: const CircleAvatar(child: Icon(Icons.star, color: Colors.pink)),
                        title: Text(f['title'] ?? 'Untitled Fair', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Update student payments'),
                        children: _students.map((s) {
                          final pIdx = _LoginScreenState._allFairPayments.indexWhere((p) => 
                            p['studentUsername'] == s['username'] && p['fairId'] == f['id']
                          );
                          final bool isPaid = pIdx != -1 && _LoginScreenState._allFairPayments[pIdx]['isPaid'] == true;
                          
                          return ListTile(
                            leading: CircleAvatar(radius: 14, child: Text(s['name']?[0] ?? 'S', style: const TextStyle(fontSize: 10))),
                            title: Text(s['name'] ?? ''),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDetails(Map<String, String> student) {
    final name = student['name'] ?? '';
    
    // Fetch data for the student
    final studentActivities = _activities; 
    final studentFairs = _fairList;
    final studentResults = _LoginScreenState._allResults.where((r) => r['studentName'] == name).toList();
    final studentExams = _exams;

    // Calculate progress
    final completedActivitiesCount = studentActivities.where((a) {
      return _LoginScreenState._allActivitySubmissions.any((s) => 
        s['studentUsername'] == student['username'] && 
        s['activityId'] == a['id'] && 
        s['isCompleted'] == true
      );
    }).length;
    final activityProgress = studentActivities.isEmpty ? 0.0 : completedActivitiesCount / studentActivities.length;

    final paidFairsCount = studentFairs.where((f) {
      return _LoginScreenState._allFairPayments.any((p) => 
        p['studentUsername'] == student['username'] && 
        p['fairId'] == f['id'] && 
        p['isPaid'] == true
      );
    }).length;
    final fairProgress = studentFairs.isEmpty ? 0.0 : paidFairsCount / studentFairs.length;

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
                        final bool isDone = _LoginScreenState._allActivitySubmissions.any((s) => 
                          s['studentUsername'] == student['username'] && 
                          s['activityId'] == a['id'] && 
                          s['isCompleted'] == true
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
                                    ? '${_LoginScreenState._allActivitySubmissions.firstWhere((s) => s['studentUsername'] == student['username'] && s['activityId'] == a['id'])['score'] ?? '0'}/${a['marks']} Marks' 
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
                      const Text('Fair Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...studentFairs.map((f) {
                        final bool isPaid = _LoginScreenState._allFairPayments.any((p) => 
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
                            title: Text(f['title'] ?? 'Untitled Fair', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      if (studentFairs.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No fairs added by teacher'))),
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
                              isExam ? '${subs.length} Subjects' : '${e['dates']} • ${e['time']}', 
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
                            CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Text(name.isNotEmpty ? name[0] : 'S', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal.shade700))),
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
                          _buildSectionChip('Activities', Icons.play_circle_fill, 1, selectedSection, (idx) => setModalState(() => selectedSection = idx)),
                          _buildSectionChip('Fairs', Icons.local_activity, 2, selectedSection, (idx) => setModalState(() => selectedSection = idx)),
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
    bool isDone = _LoginScreenState._allActivitySubmissions.any((s) => 
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
                    controller: TextEditingController(text: _LoginScreenState._allActivitySubmissions.firstWhere((s) => s['studentUsername'] == studentUser && s['activityId'] == activity['id'], orElse: () => {})['score']?.toString() ?? ''),
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
    final existingIdx = _LoginScreenState._allActivitySubmissions.indexWhere((s) => 
      s['studentUsername'] == studentUser && s['activityId'] == activity['id']
    );
    
    final Map<String, dynamic> submission = existingIdx != -1 
      ? Map<String, dynamic>.from(_LoginScreenState._allActivitySubmissions[existingIdx])
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
      _LoginScreenState._allActivitySubmissions[existingIdx] = submission;
    } else {
      _LoginScreenState._allActivitySubmissions.add(submission);
    }
    
    _LoginScreenState.saveAllData();
    
    // Recalculate progress
    final studentActs = _LoginScreenState._allActivities.where((a) => a['std'] == (activity['std'] ?? widget.assignedClass)).toList();
    if (studentActs.isNotEmpty) {
      final completedCount = _LoginScreenState._allActivitySubmissions.where((s) => 
        s['studentUsername'] == studentUser && 
        s['isCompleted'] == true &&
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
    bool isPaid = _LoginScreenState._allFairPayments.any((p) => 
      p['studentUsername'] == studentUser && 
      p['fairId'] == fair['id'] && 
      p['isPaid'] == true
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
                const Text('Fair Payment Details'),
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
    _LoginScreenState._allFairPayments.removeWhere((p) => 
      p['studentUsername'] == studentUser && p['fairId'] == fair['id']
    );
    _LoginScreenState._allFairPayments.add({
      'studentUsername': studentUser,
      'fairId': fair['id'],
      'isPaid': isPaid,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    _LoginScreenState.saveAllData();
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
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Class Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Color(0xFF0F172A))),
        ),
        Expanded(
          child: _exams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      const Text('Schedule is empty', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _exams.length,
                  itemBuilder: (context, index) {
                    final item = _exams[index];
                    final String type = item['type'] ?? 'Exam';
                    final bool isExam = type == 'Exam';
                    final List subs = item['subjects'] ?? [];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isExam ? Colors.orange.shade50 : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(isExam ? Icons.assignment : Icons.event, color: isExam ? Colors.orange.shade700 : Colors.teal.shade700),
                          ),
                          title: Text(item['title'] ?? item['examName'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                          subtitle: Text(isExam ? '${subs.length} Subjects • Class ${item['class']}' : '${item['dates']} • ${item['time']}', style: TextStyle(color: isExam ? Colors.orange.shade800 : Colors.teal.shade800, fontSize: 13, fontWeight: FontWeight.w700)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showAddScheduleDialog(index: index);
                              } else if (val == 'delete') {
                                setState(() {
                                  _LoginScreenState._allExams.remove(item);
                                  _LoginScreenState.saveAllData();
                                });
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.teal), title: Text('Edit'))),
                              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'))),
                            ],
                          ),
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
                                    const SizedBox(height: 12),
                                    if (item['days']?.toString().isNotEmpty == true) _buildScheduleDetail(Icons.calendar_today, 'Days', item['days']),
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
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Result Board', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Color(0xFF0F172A))),
        ),
        Expanded(
          child: examNames.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      const Text('No results published', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: examNames.length,
                  itemBuilder: (context, index) {
                    final examTitle = examNames[index];
                    final studentsInExam = groupedResults[examTitle]!;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.purple.shade100, width: 2),
                        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.purple.shade700, borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.assignment, color: Colors.white, size: 20),
                          ),
                          title: Text(
                            examTitle, 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1E293B))
                          ),
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
                                            final originalIdx = _LoginScreenState._allResults.indexOf(r);
                                            _showAddResultDialog(index: originalIdx);
                                          } else if (val == 'delete') {
                                            setState(() {
                                               _LoginScreenState._allResults.remove(r);
                                               _LoginScreenState.saveAllData();
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
                                              String grade = 'D'; String status = 'Failed'; Color statusColor = Colors.red;
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
    "Faces": ["😂", "🤣", "😊", "😍", "🥰", "🤔", "🧐", "😔", "😢", "😭", "😱", "😎", "🥳"],
    "Hands": ["👍", "👎", "✌️", "🖐️", "✋", "☝️", "👆", "👇", "👈", "👉", "🤝", "🙏"],
    "Nature": ["🌸", "🌹", "🌷", "🌻", "🌼", "🌺", "🥀", "💮", "🌱", "🌿", "🍃"],
    "React": ["❤️", "💯", "⏳", "⏰", "🎯", "💰", "🥅", "📞", "🚌", "🚗"],
    "Nums": ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "0️⃣"],
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
      _LoginScreenState._allMessages.add({
        ...messageData,
        'convKey': roomId,
        'receiverId': _activeChatPeerId,
        'receiverName': _activeChatPeerName,
        'recipients': [_activeChatPeerId, widget.teacherUsername],
      });
      _LoginScreenState.saveAllData();
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
    return _LoginScreenState._allMessages
        .where((m) => m['convKey'] == roomId)
        .toList()
      ..sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));
  }

  Widget _buildMessagesTab(ColorScheme colorScheme) {
    // Prepare contacts list
    final List<Map<String, dynamic>> allContacts = [
      {
        "id": "manager",

        "name": "Manager",
        "role": "Manager",
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
       
       final convMessages = _LoginScreenState._allMessages.where((m) => m['convKey'] == roomId).toList()
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
                    hintText: "Search students or manager...",
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
        if (e.key == '👍') { bg = Colors.yellow.shade50; border = Colors.yellow.shade200; }
        if (e.key == '❤️') { bg = Colors.red.shade50; border = Colors.red.shade200; }
        if (e.key == '✅') { bg = Colors.green.shade50; border = Colors.green.shade200; }

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
                    const Text('Teachers & Students • Announcements & Chat', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                  _LoginScreenState.saveAllData();
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
    final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
    return _LoginScreenState._holidayDates.contains(dateStr);
  }

  void _toggleHoliday() {
    final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
    setState(() {
      if (_LoginScreenState._holidayDates.contains(dateStr)) {
        _LoginScreenState._holidayDates.remove(dateStr);
      } else {
        _LoginScreenState._holidayDates.add(dateStr);
      }
      _LoginScreenState.saveAllData();
    });
  }


  Map<String, int> _getAttendanceStats() {
    int fnP = 0, fnA = 0, anP = 0, anA = 0;
    final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
    for (var student in widget.students) {
      final record = _LoginScreenState._allAttendance.firstWhere(
        (a) => a['studentUsername'] == student['username'] && a['date'] == dateStr,
        orElse: () => {},
      );
      if (record.isNotEmpty) {
        final pMap = Map<String, String>.from((record['periods'] as Map?) ?? {});
        if (pMap['FN'] == 'P') fnP++; else if (pMap['FN'] == 'A') fnA++;
        if (pMap['AN'] == 'P') anP++; else if (pMap['AN'] == 'A') anA++;
      }
    }
    return {'fnP': fnP, 'fnA': fnA, 'anP': anP, 'anA': anA};
  }

  Widget _statCard(String label, int present, int absent, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$present', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(width: 8),
                Text('P', style: TextStyle(fontSize: 10, color: Colors.teal.shade400, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.1)),
                const SizedBox(width: 12),
                Text('$absent', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(width: 8),
                Text('A', style: TextStyle(fontSize: 10, color: Colors.red.shade300, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
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
                            Text('Class ${widget.currentClass} • ${widget.students.length} Students', style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w700)),
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
            // Stats Banner
            Builder(
              builder: (context) {
                final stats = _getAttendanceStats();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      _statCard('Morning', stats['fnP']!, stats['fnA']!, Colors.blue),
                      const SizedBox(width: 12),
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
    final record = _LoginScreenState._allAttendance.firstWhere(
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

  void _updateStatus(String session, String newStatus) {
    setState(() {
      if (session == 'FN') _fnStatus = newStatus;
      else _anStatus = newStatus;
    });
    
    final index = _LoginScreenState._allAttendance.indexWhere(
      (a) => a['studentUsername'] == widget.student['username'] && a['date'] == widget.date
    );

    final record = index != -1 
      ? Map<String, dynamic>.from(_LoginScreenState._allAttendance[index])
      : {
          'studentUsername': widget.student['username'],
          'date': widget.date,
          'periods': <String, String>{},
          'leaveReason': '',
          'timetable': List<String>.from(widget.subjects),
        };

    final pMap = Map<String, String>.from((record['periods'] as Map?) ?? {});
    pMap[session] = newStatus;
    record['periods'] = pMap;

    if (index != -1) {
      _LoginScreenState._allAttendance[index] = record;
    } else {
      _LoginScreenState._allAttendance.add(record);
    }
    _LoginScreenState.saveAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(widget.student['name']?[0] ?? 'S', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.student['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B), letterSpacing: -0.3)),
                      Text(widget.student['username'] ?? '', style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    _updateStatus('FN', 'P');
                    _updateStatus('AN', 'P');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.done_all_rounded, size: 10, color: Colors.teal.shade600),
                        const SizedBox(width: 4),
                        Text('ALL P', style: TextStyle(color: Colors.teal.shade700, fontSize: 8, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _sessionUI('Morning', _fnStatus, (s) => _updateStatus('FN', s))),
                Container(width: 1, height: 36, color: Colors.grey.withOpacity(0.06), margin: const EdgeInsets.symmetric(horizontal: 12)),
                Expanded(child: _sessionUI('Afternoon', _anStatus, (s) => _updateStatus('AN', s))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionUI(String label, String status, Function(String) onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(label == 'Morning' ? Icons.wb_sunny_rounded : Icons.wb_twilight_rounded, size: 9, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(label.toUpperCase(), style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.grey.shade400)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _chipBtn('P', Colors.teal, status == 'P', () => onUpdate('P')),
            const SizedBox(width: 6),
            _chipBtn('A', Colors.red, status == 'A', () => onUpdate('A')),
          ],
        ),
      ],
    );
  }

  Widget _chipBtn(String l, Color c, bool active, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: active ? c : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? Colors.transparent : Colors.grey.withOpacity(0.08)),
        ),
        child: Center(
          child: Text(l, style: TextStyle(color: active ? Colors.white : Colors.grey.shade400, fontWeight: FontWeight.w900, fontSize: 11)),
        ),
      ),
    );
  }
}

// ==========================================
// DIRECT CHAT SCREEN (Unified WhatsApp style)
// ==========================================
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
      if (mounted) setState(() {});
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
    final messages = _LoginScreenState._allMessages
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
      _LoginScreenState._allMessages.add({
        'convKey': roomId,
        'senderId': widget.myId,
        'senderName': widget.myName,
        'receiverId': widget.peerId,
        'receiverName': widget.peerName,
        'text': _chatMsgCtrl.text,
        'timestamp': DateTime.now().toIso8601String(),
        'recipients': [widget.myId, widget.peerId],
      });
      _LoginScreenState.saveAllData();
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

// ==========================================
// CHAT DATA MODELS
// ==========================================
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // Manager, Teacher, Student
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
  final List<String>? participants; // For groups

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