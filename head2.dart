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

