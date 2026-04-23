import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:math';

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _LoginScreenState.initPrefs();
  await NotificationService.init();
  runApp(const BridgeApp());
}

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings);
    _isInitialized = true;
  }

  static Future<void> showNotification({required String title, required String body}) async {
    if (kIsWeb) {
      // Basic Web Notification fallback if possible
      return;
    }
    if (!_isInitialized) await init();
    const android = AndroidNotificationDetails(
      'bridge_channel',
      'Bridge Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _notifications.show(DateTime.now().millisecond, title, body, details);
  }
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
          seedColor: const Color(0xFF6366F1), // Modern Indigo
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFFEC4899), // Pink/Rose accent
          surface: const Color(0xFFF8FAFC),
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
  static List<Map<String, dynamic>> _allBulletinCards = [];
  static List<String> _allClasses = ['01', '02', '03', '04', '05'];
  static List<String> _academicYears = ['2024-2025'];
  static String _selectedAcademicYear = '2024-2025';
  static Map<String, bool> _featureConfig = {
    'Students': true,
    'Activities': true,
    'F.transactions': true,
    'Schedule': true,
    'Results': true,
    'Messages': true,
    'Groups': true,
    'Attendance': true,
  };
  static Map<String, String> _classDepts = {}; // className -> 'DA\'WA' or 'HIFZ'
  static SharedPreferences? _prefs;

  static Future<void> saveInt(String key, int val) async => await _prefs?.setInt(key, val);
  static int loadInt(String key, int def) => _prefs?.getInt(key) ?? def;
  static Future<void> saveString(String key, String val) async => await _prefs?.setString(key, val);
  static String? loadString(String key) => _prefs?.getString(key);
  
  static int getUnreadMessageCount(String username) {
    if (_allMessages.isEmpty) return 0;
    int totalForMe = _allMessages.where((m) {
      final recipients = m['recipients'] as List?;
      return (m['receiverId'] == username || recipients?.contains(username) == true) && m['senderId'] != username;
    }).length;
    int lastSeen = loadInt('last_seen_msg_count_$username', 0);
    return max(0, totalForMe - lastSeen);
  }
  
  static void markMessagesAsRead(String username) async {
    int totalForMe = _allMessages.where((m) {
       final recipients = m['recipients'] as List?;
       return (m['receiverId'] == username || recipients?.contains(username) == true) && m['senderId'] != username;
    }).length;
    await saveInt('last_seen_msg_count_$username', totalForMe);
  }

  
  static Map<String, int> _lastNotifiedMsgCount = {};

  static void checkForNewAndNotify(String username) {
     int currentCount = getUnreadMessageCount(username);
     int lastNotified = _lastNotifiedMsgCount[username] ?? 0;
     if (currentCount > lastNotified) {
        NotificationService.showNotification(
          title: 'New Message',
          body: 'You have $currentCount unread message(s)',
        );
     }
     _lastNotifiedMsgCount[username] = currentCount;
  }

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

    // Inject System Update Notification if not present
    bool exists = _allExams.any((e) => e['title'] == 'System Enhancement Summary');
    if (!exists) {
      _allExams.add({
        'type': 'Announcement',
        'title': 'System Enhancement Summary',
        'description': 'Director Board updated with Broadcast system, quick-action shortcuts, and colorful announcement cards for all users. Check the sidebar for new commands.',
        'date': '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}',
        'day': 'Product Update',
        'time': 'NEW',
        'class': null,
        'academicYear': _selectedAcademicYear,
      });
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
      _allAttendance = decoded.map((a) {
        final map = Map<String, dynamic>.from(a);
        if (map['academicYear'] == null) map['academicYear'] = '2024-2025'; // Basic migration
        
        // Padded Date Migration (Ensure yyyy-mm-dd for parsing)
        if (map['date'] != null && map['date'].toString().contains('-')) {
          final parts = map['date'].toString().split('-');
          if (parts.length == 3) {
            final y = parts[0];
            final m = parts[1].padLeft(2, '0');
            final d = parts[2].padLeft(2, '0');
            map['date'] = "$y-$m-$d";
          }
        }
        return map;
      }).toList();
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

    final deptsStr = _prefs!.getString('all_class_depts');
    if (deptsStr != null) {
      _classDepts = Map<String, String>.from(jsonDecode(deptsStr));
    }
    // Migration: Ensure all classes have a department
    bool deptsChanged = false;
    for (var c in _allClasses) {
      if (_classDepts[c] == null) {
        _classDepts[c] = 'DA\'WA'; // Default
        deptsChanged = true;
      }
    }
    if (deptsChanged) saveAllData();

    if (metricsStr != null) {
      final List decodedList = jsonDecode(metricsStr);
      _allMetrics = decodedList.map((m) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(m);
        return {
          'title': data['title'],
          'value': data['value'],
          'icon': _getIconDataFromCodePoint(data['icon']),
          'color': _getColorFromValueActual(data['color']),
          'targetIndex': data['targetIndex'],
        };
      }).toList();
    }

    final configStr = _prefs!.getString('feature_config');
    if (configStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(configStr);
      _featureConfig = decoded.map((key, value) => MapEntry(key, value as bool));
    }

    final bulletinStr = _prefs!.getString('all_bulletin_cards');
    if (bulletinStr != null) {
      final List decoded = jsonDecode(bulletinStr);
      _allBulletinCards = decoded.map((b) => Map<String, dynamic>.from(b)).toList();
    }

    if (_allMetrics.isEmpty) {
      _allMetrics = [
        {'title': 'Classes', 'value': '3', 'icon': Icons.class_, 'color': Colors.teal, 'targetIndex': 0},
        {'title': 'Teachers', 'value': '50+', 'icon': Icons.badge, 'color': Colors.green, 'targetIndex': 1},
        {'title': 'Schedule', 'value': '5+', 'icon': Icons.calendar_month, 'color': Colors.orange, 'targetIndex': 2},
        {'title': 'Rewards', 'value': '100+', 'icon': Icons.emoji_events, 'color': Colors.purple, 'targetIndex': -1},
      ];
    }
  }


  static IconData _getIconDataFromCodePoint(int codePoint) {
    const icons = {
       0xe54d: Icons.school,
       0xe0e1: Icons.badge,
       0xe23a: Icons.event,
       0xe211: Icons.emoji_events,
       0xe0a1: Icons.assignment,
       0xe491: Icons.people,
       0xe0ef: Icons.book,
       0xe5f9: Icons.star,
       0xe440: Icons.notifications,
       0xe060: Icons.analytics,
       0xe163: Icons.class_,
       0xe0bb: Icons.calendar_month,
    };
    return icons[codePoint] ?? Icons.help_outline;
  }
  
  static Map<String, int> getAttendanceStats(String username, int? month, int? year) {
    int total = 0;
    int present = 0;
    for (var a in _allAttendance) {
      if (a['studentUsername'] != username) continue;
      // Filter by current academic year by default if no specific year provided
      if (a['academicYear'] != _selectedAcademicYear && year == null) continue; 
      
      final date = DateTime.tryParse(a['date'] ?? '');
      if (date == null) continue;
      if (month != null && date.month != month) continue;
      if (year != null && date.year != year) continue;
      final periods = Map<String, String>.from(a['periods'] ?? {});
      if (periods.isNotEmpty) {
        total++;
        if (periods.values.contains('P')) present++;
      }
    }
    return {'total': total, 'present': present};
  }

  static Map<String, int> getAcademicYearStats(String username, String academicYear) {
    int total = 0;
    int present = 0;
    for (var a in _allAttendance) {
      if (a['studentUsername'] == username && a['academicYear'] == academicYear) {
        final periods = Map<String, String>.from(a['periods'] ?? {});
        if (periods.isNotEmpty) {
          total++;
          if (periods.values.contains('P')) present++;
        }
      }
    }
    return {'total': total, 'present': present};
  }

  static MaterialColor _getColorFromValueActual(int value) {

    const colors = [Colors.teal, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.pink, Colors.teal, Colors.green];
    for (var c in colors) {
       if (c.value == value) return c;
    }
    return Colors.teal; // Default
  }

  static void saveAllData() {
    _saveAllToPrefs();
  }

  static Future<void> _saveAllToPrefs() async {
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
    await _prefs!.setString('all_activity_submissions', jsonEncode(_allActivitySubmissions));
    await _prefs!.setString('all_fair_payments', jsonEncode(_allFairPayments));
    await _prefs!.setString('all_classes', jsonEncode(_allClasses));
    await _prefs!.setString('all_class_depts', jsonEncode(_classDepts));
    await _prefs!.setString('academic_years', jsonEncode(_academicYears));
    await _prefs!.setString('selected_academic_year', _selectedAcademicYear);
    await _prefs!.setString('all_bulletin_cards', jsonEncode(_allBulletinCards));
    
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
          // Academic Director login
          Map<String, String>? school;
          try {
            school = _allSchools.firstWhere((s) => s['username'] == user && s['password'] == pass);
          } catch (e) {
            school = null;
          }

          if (school != null) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SchoolDashboardScreen(schoolName: school!['school'] ?? 'Unknown School', username: school['username'] ?? 'manager')));
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Header
                FadeInEntrance(
                  delay: 0.2,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, size: 60, color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                        ).createShader(bounds),
                        child: const Text(
                          'BRIDGE',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        'NEXT-GEN LEARNING PLATFORM',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
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
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 40, offset: const Offset(0, 20))
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _userController,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          onSubmitted: (_) => _login(),
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
                          onSubmitted: (_) => _login(),
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
                  labelText: 'Academic Director Name',
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1000;
    final isTablet = width > 600 && width <= 1000;
    
    return FadeInEntrance(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        toolbarHeight: isDesktop ? 120 : 90,
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
                fontSize: isDesktop ? 80 : 64,
                fontWeight: FontWeight.w100,
                letterSpacing: 12,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Text(
              'Bridge',
              style: TextStyle(
                fontSize: isDesktop ? 40 : 32,
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
                  fontSize: isDesktop ? 48 : 36,
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
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 100,
                    ),
                    itemCount: _schools.length,
                    itemBuilder: (context, index) {
                      final s = _schools[index];
                      return FadeInEntrance(
                        delay: index * 0.1,
                        child: Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.1),
                          child: Center(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primary.withOpacity(0.1),
                                child: Icon(Icons.school_rounded, color: colorScheme.primary),
                              ),
                              title: Text(s['school'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Manager: ${s['manager']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.teal, size: 20), onPressed: () => _showAddSchoolSheet(index: index)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete School'),
                                          content: Text('Are you sure you want to delete ${s['school']}?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                            TextButton(onPressed: () {
                                              setState(() => _schools.removeAt(index));
                                              _LoginScreenState.saveAllData();
                                              Navigator.pop(context);
                                            }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: InkWell(
          onTap: () => _showAddSchoolSheet(),
          child: Container(
            height: 75,
            margin: isDesktop ? const EdgeInsets.all(24) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isDesktop ? BorderRadius.circular(20) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.domain_add_rounded, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'ADD NEW SCHOOL',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                      letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
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
  final String username;
  const SchoolDashboardScreen({super.key, required this.schoolName, required this.username});

  @override
  State<SchoolDashboardScreen> createState() => _SchoolDashboardScreenState();
}

mixin NoticeCenterMixin<T extends StatefulWidget> on State<T> {
  int _unreadNoticeCount = 0;
  String get currentUsername;

  void initNoticeCount() {
    _updateNoticeCount();
  }

  void _updateNoticeCount() {
    int total = _LoginScreenState._allBulletinCards.length;
    int lastSeen = _LoginScreenState.loadInt('last_seen_notice_count_$currentUsername', 0);
    int newCount = max(0, total - lastSeen);
    
    if (newCount != _unreadNoticeCount) {
       setState(() => _unreadNoticeCount = newCount);
    }
  }

  void showNoticeCenter(BuildContext context) async {
    await _LoginScreenState.saveInt('last_seen_notice_count_$currentUsername', _LoginScreenState._allBulletinCards.length);
    setState(() => _unreadNoticeCount = 0);
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
          child: _LoginScreenState._allBulletinCards.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Text('No new updates from the manager.'))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _LoginScreenState._allBulletinCards.reversed.take(4).map((b) => Container(
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
        if (_unreadNoticeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.indigo : Colors.white, width: 2)),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$_unreadNoticeCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }

  static const List<List<Color>> _cardGradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo - Violet
    [Color(0xFFEC4899), Color(0xFFF43F5E)], // Rose - Pink
    [Color(0xFF10B981), Color(0xFF0D9488)], // Emerald - Teal
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber - Orange
    [Color(0xFF0EA5E9), Color(0xFF2563EB)], // Sky - Blue
  ];

  Widget buildNoticeBoardCard(Map<String, dynamic> b, int index, {VoidCallback? onEdit}) {
    final gradient = _cardGradients[index % _cardGradients.length];
    return Container(
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
                  Text(b['desc'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 15, height: 1.6, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          children: [
                            const Icon(Icons.person_pin, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(b['publisher'] ?? 'Manager', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(b['date'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Update the global teacher list when manager adds/updates teachers
void _updateGlobalTeacherList(List<Map<String, String>> teachers) {

  _LoginScreenState._allTeachers = List.from(teachers);
  _LoginScreenState.saveAllData();
}

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen> with NoticeCenterMixin {
  @override
  String get currentUsername => widget.username;
  int _currentIndex = -1; // -1: Overview, 0: Std, 1: Teacher, 2: Exam, 3: Msg
  int _classDetailTabIndex = 0; // 0: Students, 1: Activities, 2: Transactions, 3: Results, 4: Annals
  int _attMonth = DateTime.now().month;

  int _attYear = DateTime.now().year;

  final ScrollController _navLeftController = ScrollController();
  final ScrollController _navRightController = ScrollController();

  @override
  void initState() {
    super.initState();
    initNoticeCount();
    _currentIndex = _LoginScreenState.loadInt('school_dashboard_index', 0);



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
  List<Map<String, dynamic>> get _metrics => _LoginScreenState._allMetrics;


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
    final messageCtrl = TextEditingController();
    String selectedBroadCast = 'All Members'; // All Teachers, All Students, All Members

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Broadcast Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedBroadCast,
                decoration: const InputDecoration(labelText: 'Receivers', prefixIcon: Icon(Icons.people)),
                items: ['All Teachers', 'All Students', 'All Members']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setDialogState(() => selectedBroadCast = val!),
              ),
              const SizedBox(height: 16),
              TextField(controller: messageCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Message Body', prefixIcon: Icon(Icons.text_fields))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (messageCtrl.text.isEmpty) return;
                
                setState(() {
                  List<String> targetIds = [];
                  if (selectedBroadCast == 'All Teachers' || selectedBroadCast == 'All Members') {
                    targetIds.addAll(_teachers.map((t) => t['username'] ?? '').where((id) => id.isNotEmpty));
                  }
                  if (selectedBroadCast == 'All Students' || selectedBroadCast == 'All Members') {
                    targetIds.addAll(_students.map((s) => s['username'] ?? '').where((id) => id.isNotEmpty));
                  }

                  for (var peerId in targetIds) {
                    final roomId = ['manager', peerId]..sort();
                    final convKey = roomId.join('::');
                    
                    _LoginScreenState._allMessages.add({
                      'senderId': 'manager',
                      'senderName': 'Academic Director',
                      'receiverId': peerId,
                      'convKey': convKey,
                      'text': messageCtrl.text,
                      'timestamp': DateTime.now().toIso8601String(),
                      'isBroadcast': true,
                    });
                  }
                  _LoginScreenState.saveAllData();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Broadcast sent to $selectedBroadCast')));
              },
              child: const Text('Send'),
            )
          ],
        ),
      ),
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
    
    // Support multi-class
    List<String> selectedClasses = [];
    if (t?['class'] != null && t!['class']!.isNotEmpty) {
      selectedClasses = t['class']!.split(',').map((e) => e.trim()).toList();
    } else if (index == null && _classes.isNotEmpty) {
      selectedClasses = [_classes.first];
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
                if (_classes.isNotEmpty) ...[
                  const Text('Assign Classes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _classes.map((c) {
                      final isSelected = selectedClasses.contains(c);
                      return FilterChip(
                        label: Text(c),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                        onSelected: (val) {
                          setStateDialog(() {
                            if (val) selectedClasses.add(c);
                            else selectedClasses.remove(c);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ] else
                   const Padding(
                     padding: EdgeInsets.only(top: 8),
                     child: Text('Add a class first in Students tab!', style: TextStyle(color: Colors.red, fontSize: 12)),
                   ),
                const SizedBox(height: 16),
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
                    'class': selectedClasses.join(', '),
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
    final nameCtrl = TextEditingController(text: e?['examName'] ?? e?['title'] ?? '');
    final descCtrl = TextEditingController(text: e?['description'] ?? '');
    final dateCtrl = TextEditingController(text: e?['date'] ?? e?['dates'] ?? '');
    final dayCtrl = TextEditingController(text: e?['day'] ?? e?['days'] ?? '');
    final timeCtrl = TextEditingController(text: e?['time'] ?? '');
    String selectedType = e?['type'] ?? 'Exam';
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
          title: Text(index != null ? 'Edit Schedule Item' : 'Add Schedule Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.category)),
                  items: ['Exam', 'Announcement'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setFullState(() => selectedType = val!),
                ),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: selectedType == 'Exam' ? 'Exam Name' : 'Announcement Title', prefixIcon: Icon(selectedType == 'Exam' ? Icons.assignment : Icons.campaign))),
                const SizedBox(height: 16),
                if (selectedType == 'Announcement') ...[
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)), maxLines: 2),
                  const SizedBox(height: 16),
                  TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date (optional)', prefixIcon: Icon(Icons.calendar_today))),
                  const SizedBox(height: 16),
                  TextField(controller: dayCtrl, decoration: const InputDecoration(labelText: 'Day (optional)', prefixIcon: Icon(Icons.wb_sunny))),
                  const SizedBox(height: 16),
                  TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time (optional)', prefixIcon: Icon(Icons.access_time))),
                ],
                if (_classes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    decoration: const InputDecoration(
                      labelText: 'Apply to Class',
                      prefixIcon: Icon(Icons.class_),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Global / All Classes')),
                      ..._classes.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (val) => setFullState(() => selectedClass = val),
                  ),
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            if (index != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _exams.removeAt(index);
                    _LoginScreenState.saveAllData();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                setState(() {
                  final newData = {
                    'type': selectedType,
                    'title': nameCtrl.text,
                    'examName': nameCtrl.text,
                    'description': descCtrl.text,
                    'dates': dateCtrl.text,
                    'date': dateCtrl.text,
                    'days': dayCtrl.text,
                    'day': dayCtrl.text,
                    'time': timeCtrl.text,
                    'class': selectedClass,
                    'subjects': subjects,
                    'academicYear': _LoginScreenState._selectedAcademicYear,
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

  void _showAcademicYearDialog() {
    final yearCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.history_edu_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('Manage Sessions', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add a new academic year period (e.g., 2024-2025). All new attendance, activities, and results will be linked to the active session.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: yearCtrl,
              decoration: InputDecoration(
                labelText: 'Session Name',
                hintText: '2025-2026',
                prefixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Existing Sessions:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: _LoginScreenState._academicYears.map((y) => ListTile(
                  dense: true,
                  title: Text(y, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: y != _LoginScreenState._selectedAcademicYear ? IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: () {
                    setState(() { _LoginScreenState._academicYears.remove(y); _LoginScreenState.saveAllData(); });
                    Navigator.pop(context); _showAcademicYearDialog();
                  }) : const Icon(Icons.check_circle, color: Colors.green, size: 16),
                )).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (yearCtrl.text.isNotEmpty) {
                setState(() {
                  if (!_LoginScreenState._academicYears.contains(yearCtrl.text)) {
                    _LoginScreenState._academicYears.add(yearCtrl.text);
                  }
                  _LoginScreenState._selectedAcademicYear = yearCtrl.text;
                  _LoginScreenState.saveAllData();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add & Set Active'),
          ),
        ],
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
                  _LoginScreenState.saveAllData();
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
                  _LoginScreenState.saveAllData();
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
    final width = MediaQuery.of(context).size.width;
    
    final bool isDesktop = width > 1100;
    final bool isTablet = width > 650 && width <= 1100;
    final bool isMobile = width <= 650;

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
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        leading: _currentIndex != -1 ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _currentIndex = 3),
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.schoolName.toUpperCase()} ACADEMIC DIRECTOR',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w200,
                letterSpacing: 4,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_rounded),
            onPressed: () => _showAcademicYearDialog(),
            tooltip: 'Manage Sessions',
          ),
          buildNotificationBell(isDark: true),
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
                   _buildNavItem(Icons.grid_view_rounded, 'Class', 0, colorScheme),
                   _buildNavItem(Icons.badge_rounded, 'Teacher', 1, colorScheme),
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
                   _buildNavItem(Icons.calendar_today_rounded, 'Sched', 2, colorScheme),
                   _buildNavItem(Icons.chat_bubble_rounded, 'Msg', 3, colorScheme, hasBadge: _LoginScreenState.getUnreadMessageCount(widget.username) > 0),
                   _buildNavItem(Icons.tune_rounded, 'Feat', 4, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletRail(ColorScheme colorScheme) {
    return NavigationRail(
      selectedIndex: _currentIndex + 1, // mapping -1 to 0
      onDestinationSelected: (int index) {
        _setTab(index - 1);
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
      destinations: [
        const NavigationRailDestination(icon: Icon(Icons.grid_view_rounded), label: Text('Classes')),
        const NavigationRailDestination(icon: Icon(Icons.badge_rounded), label: Text('Teachers')),
        const NavigationRailDestination(icon: Icon(Icons.calendar_today_rounded), label: Text('Schedule')),
        NavigationRailDestination(
          icon: Stack(
            children: [
              const Icon(Icons.chat_bubble_rounded),
              if (_LoginScreenState.getUnreadMessageCount(widget.username) > 0)
                Positioned(right: 0, top: 0, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
            ],
          ),
          label: const Text('Messages'),
        ),
        const NavigationRailDestination(icon: Icon(Icons.tune_rounded), label: Text('Features')),
      ],
      trailing: Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, size: 32),
              color: colorScheme.primary,
              onPressed: () => _showEditMetricDialog(),
            ),
            const SizedBox(height: 20),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
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
                const Text('ANTIGRAVITY', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                Text('ACADEMIC DIRECTOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colorScheme.primary, letterSpacing: 2)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDesktopNavItem(Icons.category_rounded, 'Departments', 0, colorScheme),
                _buildDesktopNavItem(Icons.person_rounded, 'Teachers', 1, colorScheme),
                _buildDesktopNavItem(Icons.calendar_month, 'Schedule', 2, colorScheme),
                _buildDesktopNavItem(Icons.message_rounded, 'Messages', 3, colorScheme, hasBadge: _LoginScreenState.getUnreadMessageCount(widget.username) > 0),
                _buildDesktopNavItem(Icons.settings_suggest_rounded, 'Feature Config', 4, colorScheme),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showAddMessageDialog(),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('  + BROADCAST', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showAddExamDialog(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('  ADD SCHEDULE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary, width: 2),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const Spacer(),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            leading: CircleAvatar(backgroundColor: colorScheme.primary.withOpacity(0.1), child: Text(widget.schoolName[0], style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))),
            title: Text(widget.schoolName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Administrator', style: TextStyle(fontSize: 10)),
            trailing: IconButton(icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.grey), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool hasBadge = false}) {
    final isSelected = _currentIndex == index;
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Director Control', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text('Academic Director', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_edu, size: 14, color: Colors.indigo),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _LoginScreenState._selectedAcademicYear,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 14),
                  items: _LoginScreenState._academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E293B))))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() { _LoginScreenState._selectedAcademicYear = v; _LoginScreenState.saveAllData(); });
                  },
                ),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.add_circle_outline, size: 14, color: Colors.indigo), onPressed: () => _showAcademicYearDialog(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          buildNotificationBell(),
          const SizedBox(width: 8),

          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)), onPressed: () {}),
        ],
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

  void _setTab(int index) {
    setState(() {
      _currentIndex = index;
      _LoginScreenState.saveInt('school_dashboard_index', index);
      _selectedClassInTab = null; 
      if (index == 3) {
        _LoginScreenState.markMessagesAsRead(widget.username);
      }
    });
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme, {bool isEnabled = true, bool hasBadge = false}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colorScheme.primary : (isEnabled ? Colors.grey : Colors.grey.withOpacity(0.2));
    
    return InkWell(
      onTap: isEnabled ? () {
        _setTab(index);
        if (label == 'Messages' || label == 'Announce') {
           _LoginScreenState.markMessagesAsRead(widget.username);
        }
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
              Stack(
                children: [
                  Icon(icon, color: color, size: 24),
                  if (hasBadge)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    ),
                ],
              ),
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
      case 7: return _buildAttendanceOverview(colorScheme);
      default: return _buildStudentsTab(colorScheme);
    }
  }

  Widget _buildAttendanceOverview(ColorScheme colorScheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Global Attendance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              _buildMonthYearPicker(),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildDeptAttendanceSection('DA\'WA', colorScheme),
              const SizedBox(height: 32),
              _buildDeptAttendanceSection('HIFZ', colorScheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeptAttendanceSection(String dept, ColorScheme colorScheme) {
    final deptClasses = _classes.where((c) => _LoginScreenState._classDepts[c] == dept).toList();
    if (deptClasses.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: dept == 'DA\'WA' ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
          child: Text(dept, style: TextStyle(color: dept == 'DA\'WA' ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 16),
        ...deptClasses.map((className) {
          final classStudents = _LoginScreenState._allStudents.where((s) => s['std'] == className).toList();
          int totalP = 0, totalT = 0;
          for (var s in classStudents) {
            final stats = _LoginScreenState.getAttendanceStats(s['username']!, _attMonth == 0 ? null : _attMonth, _attYear);
            totalP += stats['present']!;
            totalT += stats['total']!;
          }
          final double avg = totalT == 0 ? 0 : (totalP / totalT) * 100;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: ExpansionTile(
              leading: CircleAvatar(backgroundColor: colorScheme.primary.withOpacity(0.1), child: Text(className, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))),
              title: Text('Class $className', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              subtitle: Text('${classStudents.length} Students • ${avg.toStringAsFixed(1)}% Avg. Attendance', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              children: classStudents.map((s) {
                final sStats = _LoginScreenState.getAttendanceStats(s['username']!, _attMonth == 0 ? null : _attMonth, _attYear);
                return ListTile(
                  title: Text(s['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Text('${sStats['present']}/${sStats['total']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text('Class: $className', style: const TextStyle(fontSize: 10)),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMonthYearPicker() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
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



  void _showAddBulletinDialog({int? index}) {
    final b = index != null ? _LoginScreenState._allBulletinCards[index] : null;
    final titleCtrl = TextEditingController(text: b?['title']);
    final descCtrl = TextEditingController(text: b?['desc']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index == null ? 'Add Bulletin Card' : 'Edit Bulletin Card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Card Title')),
            TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Matter / Content')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (index != null) TextButton(onPressed: () { _LoginScreenState._allBulletinCards.removeAt(index); _LoginScreenState.saveAllData(); Navigator.pop(context); setState(() {}); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ElevatedButton(
            onPressed: () {
              final data = {
                'title': titleCtrl.text,
                'desc': descCtrl.text,
                'date': "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}",
                'publisher': 'Manager',
              };
              if (index == null) _LoginScreenState._allBulletinCards.add(data);
              else _LoginScreenState._allBulletinCards[index] = data;
              _LoginScreenState.saveAllData();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: colorScheme.primary.withOpacity(0.1))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Academic Session', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(_LoginScreenState._selectedAcademicYear, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: colorScheme.primary)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showAcademicYearDialog(),
                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Manage Sessions'),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // Removed unused Overview cards


  Widget _buildStudentsTab(ColorScheme colorScheme) {
    if (_selectedClassInTab == null) {
      // Show Departments List
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Departments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildImportantBulletins(colorScheme),
                const SizedBox(height: 24),
                _buildDepartmentGroup('DA\'WA', colorScheme),
                const SizedBox(height: 32),
                _buildDepartmentGroup('HIFZ', colorScheme),
                const SizedBox(height: 100), // padding for FAB
              ],
            ),
          ),
        ],
      );
    } else {
      // Show Class Detail View
      final filteredStudents = _students.asMap().entries.where((e) => e.value['std'] == _selectedClassInTab).toList();
      
      return Column(
        children: [
          // Class Header & Sub-Nav
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), 
                      onPressed: () => setState(() {
                        _selectedClassInTab = null;
                        _classDetailTabIndex = 0;
                      })
                    ),
                    const SizedBox(width: 8),
                    Text('Class $_selectedClassInTab', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    const Spacer(),
                    if (_classDetailTabIndex == 0) _buildMonthYearPicker(),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildClassSubNavItem(0, Icons.people_rounded, 'Students'),
                      _buildClassSubNavItem(1, Icons.play_circle_fill, 'Activities'),
                      _buildClassSubNavItem(2, Icons.local_activity, 'Transactions'),
                      _buildClassSubNavItem(3, Icons.analytics, 'Results'),
                      _buildClassSubNavItem(4, Icons.campaign, 'Announcements'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildClassSubView(colorScheme, filteredStudents),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildClassSubNavItem(int index, IconData icon, String label) {
    final isSelected = _classDetailTabIndex == index;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade500;
    return InkWell(
      onTap: () => setState(() => _classDetailTabIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? color : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSubView(ColorScheme colorScheme, List<MapEntry<int, Map<String, String>>> filteredStudents) {
    switch (_classDetailTabIndex) {
      case 0: // Students
        return _buildClassStudentsList(colorScheme, filteredStudents);
      case 1: // Activities
        return _buildClassActivitiesList(colorScheme);
      case 2: // Transactions
        return _buildClassTransactionsList(colorScheme);
      case 3: // Results
        return _buildClassResultsList(colorScheme);
      case 4: // Announcements
        return _buildClassAnnouncementsList(colorScheme);
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  Widget _buildClassStudentsList(ColorScheme colorScheme, List<MapEntry<int, Map<String, String>>> filteredStudents) {
    return Column(
      children: [
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
                key: const ValueKey('student_list_sub'),
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
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final stats = _LoginScreenState.getAttendanceStats(s['username']!, _attMonth == 0 ? null : _attMonth, _attYear);
                              final double avg = stats['total'] == 0 ? 0 : (stats['present']! / stats['total']!) * 100;
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: avg/100, minHeight: 6, backgroundColor: Colors.grey.shade100, color: avg > 75 ? Colors.teal : (avg > 50 ? Colors.orange : Colors.red)))),
                                      const SizedBox(width: 10),
                                      Text('${avg.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Attendance: ${stats['present']}/${stats['total']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                      Text(_getMonthName(_attMonth), style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ],
                              );
                            }
                          ),
                          const SizedBox(height: 8),
                          Text('User: ${s['username']} | Pass: ${s['password']}', style: const TextStyle(fontSize: 10, color: Colors.teal)),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _LoginScreenState._allStudents.removeAt(realIndex));
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

  Widget _buildClassActivitiesList(ColorScheme colorScheme) {
    final activities = _LoginScreenState._allActivities.asMap().entries
        .where((e) => e.value['std'] == _selectedClassInTab).toList();
    return Column(
      children: [
        Expanded(
          child: activities.isEmpty
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 60, color: Colors.grey.shade300),
                  const Text('No activities for this class'),
                ],
              ))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final entry = activities[index];
                  final a = entry.value;
                  final realIdx = entry.key;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _showAddActivityDialog(index: realIdx, defaultClass: _selectedClassInTab),
                      leading: Icon(Icons.play_circle_fill, color: colorScheme.primary),
                      title: Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${a['type']} | Due: ${a['date']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${a['marks']} Marks', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () {
                             setState(() => _LoginScreenState._allActivities.removeAt(realIdx));
                             _LoginScreenState.saveAllData();
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showAddActivityDialog(defaultClass: _selectedClassInTab),
              icon: const Icon(Icons.add),
              label: const Text('Add Activity'),
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassTransactionsList(ColorScheme colorScheme) {
    final fairs = _LoginScreenState._allFairItems.asMap().entries
        .where((e) => e.value['class'] == _selectedClassInTab || e.value['class'] == null).toList();
    return Column(
      children: [
        Expanded(
          child: fairs.isEmpty
            ? Center(child: Text('No transactions/fairs for this class'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: fairs.length,
                itemBuilder: (context, index) {
                  final entry = fairs[index];
                  final f = entry.value;
                  final realIdx = entry.key;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _showAddFairDialog(index: realIdx, defaultClass: _selectedClassInTab),
                      leading: Icon(Icons.local_activity, color: Colors.orange),
                      title: Text(f['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Amount: ₹${f['amount'] ?? '0'}'),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () {
                         setState(() => _LoginScreenState._allFairItems.removeAt(realIdx));
                         _LoginScreenState.saveAllData();
                      }),
                    ),
                  );
                },
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showAddFairDialog(defaultClass: _selectedClassInTab),
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction Item'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassResultsList(ColorScheme colorScheme) {
    final results = _LoginScreenState._allResults.asMap().entries
        .where((e) => _students.any((s) => s['name'] == e.value['studentName'] && s['std'] == _selectedClassInTab)).toList();
    return Column(
      children: [
        Expanded(
          child: results.isEmpty
            ? Center(child: Text('No results published for this class'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final entry = results[index];
                  final r = entry.value;
                  final realIdx = entry.key;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _showAddResultDialog(index: realIdx, defaultClass: _selectedClassInTab),
                      leading: Icon(Icons.analytics, color: Colors.green),
                      title: Text(r['studentName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${r['examName']} | Score: ${r['score']}'),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () {
                         setState(() => _LoginScreenState._allResults.removeAt(realIdx));
                         _LoginScreenState.saveAllData();
                      }),
                    ),
                  );
                },
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showAddResultDialog(defaultClass: _selectedClassInTab),
              icon: const Icon(Icons.add),
              label: const Text('Publish Result'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassAnnouncementsList(ColorScheme colorScheme) {
    final exams = _LoginScreenState._allExams.asMap().entries
        .where((e) => e.value['class'] == _selectedClassInTab || e.value['class'] == null).toList();
    return Column(
      children: [
        Expanded(
          child: exams.isEmpty
            ? Center(child: Text('No announcements for this class'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: exams.length,
                itemBuilder: (context, index) {
                  final entry = exams[index];
                  final e = entry.value;
                  final realIdx = entry.key;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _showAddClassAnnouncementDialog(index: realIdx, defaultClass: _selectedClassInTab),
                      leading: Icon(Icons.campaign, color: Colors.purple),
                      title: Text(e['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(e['date'] ?? ''),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () {
                         setState(() => _LoginScreenState._allExams.removeAt(realIdx));
                         _LoginScreenState.saveAllData();
                      }),
                    ),
                  );
                },
              ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showAddClassAnnouncementDialog(defaultClass: _selectedClassInTab),
              icon: const Icon(Icons.add),
              label: const Text('New Announcement'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
  }

  Widget _buildDepartmentGroup(String dept, ColorScheme colorScheme) {
    final deptClasses = _classes.where((c) => _LoginScreenState._classDepts[c] == dept).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: dept == 'DA\'WA' ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dept,
                style: TextStyle(
                  color: dept == 'DA\'WA' ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddClassToDeptDialog(dept),
              icon: const Icon(Icons.add_circle, size: 20),
              label: const Text('Add Class', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (deptClasses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid)),
            child: Center(child: Text('No classes added to $dept yet', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : (MediaQuery.of(context).size.width > 800 ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 3,
            ),
            itemCount: deptClasses.length,
            itemBuilder: (context, index) {
              final c = deptClasses[index];
              final count = _students.where((s) => s['std'] == c).length;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedClassInTab = c),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.book_rounded, color: colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(c, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                              Text('$count Students', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                          onPressed: () => _showDeleteClassConfirm(c),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 14),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showAddClassToDeptDialog(String dept) {
    final classCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add Class to $dept'),
        content: TextField(
          controller: classCtrl,
          decoration: InputDecoration(
            labelText: 'Class Name',
            hintText: 'e.g. Class 06',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (classCtrl.text.isNotEmpty) {
                setState(() {
                  _LoginScreenState._allClasses.add(classCtrl.text);
                  _LoginScreenState._classDepts[classCtrl.text] = dept;
                  _LoginScreenState.saveAllData();
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Create Class'),
          ),
        ],
      ),
    );
  }

  void _showDeleteClassConfirm(String className) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Class?'),
        content: Text('Are you sure you want to remove Class $className? Student records will be preserved but they will lose their class assignment.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep it')),
          TextButton(
            onPressed: () {
              setState(() {
                _LoginScreenState._allClasses.remove(className);
                _LoginScreenState.saveAllData();
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showAddExamDialog(index: index),
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        label: const Text('Edit'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Item?'),
                                              content: const Text('Are you sure you want to remove this schedule item?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _LoginScreenState._allExams.removeAt(index);
                                                      _LoginScreenState.saveAllData();
                                                    });
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showAddExamDialog(),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Schedule Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildImportantBulletins(ColorScheme colorScheme) {
    final bulletins = _exams.where((e) => e['type'] == 'Announcement').toList();
    if (bulletins.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Important Announcements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
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
                  gradient: LinearGradient(colors: [cardColor, cardColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: cardColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(b['title'] ?? 'Announcement', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.campaign, color: Colors.white70),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: Text(b['description'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (b['date']?.toString().isNotEmpty == true) ...[
                          const Icon(Icons.calendar_today, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(b['date'], style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                        ],
                        if (b['day']?.toString().isNotEmpty == true) ...[
                          const Icon(Icons.wb_sunny, size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(b['day'], style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ],
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

