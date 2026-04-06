import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static List<Map<String, String>> _allTeachers = [];
  static List<Map<String, String>> _allSchools = [
    {'school': 'Sample School', 'username': 'manager', 'password': '123'}
  ];
  static List<Map<String, String>> _allStudents = [];
  static List<Map<String, dynamic>> _allExams = [];
  static List<Map<String, dynamic>> _allMessages = [];
  static List<Map<String, dynamic>> _allGroups = []; // Class groups and staff groups
  static List<Map<String, dynamic>> _allGroupMembers = []; // Group memberships
  static List<Map<String, dynamic>> _allActivities = [];
  static List<Map<String, dynamic>> _allFairItems = [];
  static List<Map<String, dynamic>> _allResults = [];
  static List<Map<String, dynamic>> _allMetrics = [];
  
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
      _allSchools = decoded.map((s) => Map<String, String>.from(s)).toList();
    }
    
    final teachersStr = _prefs!.getString('all_teachers');
    if (teachersStr != null) {
      final List decoded = jsonDecode(teachersStr);
      _allTeachers = decoded.map((t) => Map<String, String>.from(t)).toList();
    }
    
    final studentsStr = _prefs!.getString('all_students');
    if (studentsStr != null) {
      final List decoded = jsonDecode(studentsStr);
      _allStudents = decoded.map((s) => Map<String, String>.from(s)).toList();
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

    final fairStr = _prefs!.getString('all_fairs');
    if (fairStr != null) {
      final List decoded = jsonDecode(fairStr);
      _allFairItems = decoded.map((f) => Map<String, dynamic>.from(f)).toList();
    }

    final resultsStr = _prefs!.getString('all_results');
    if (resultsStr != null) {
      final List decoded = jsonDecode(resultsStr);
      _allResults = decoded.map((r) => Map<String, dynamic>.from(r)).toList();
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
    await _prefs!.setString('all_fairs', jsonEncode(_allFairItems));
    await _prefs!.setString('all_results', jsonEncode(_allResults));
    
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
        } catch(e) {}
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
          } catch (e) {}

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
              Icon(Icons.hub, size: 80, color: colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'BRIDGE',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Color(0xFF075E54),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Learning Management System',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 50),

              // Form
              TextField(
                controller: _userController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _login,
                  child: const Text(
                    'Login',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  // Use global static lists from _LoginScreenState for persistence
  final List<String> _classes = ['01', '02', '03', '04', '05'];
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
    {'title': 'Events', 'value': '5+', 'icon': Icons.event, 'color': Colors.orange, 'targetIndex': -1},
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
                if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty || parentsCtrl.text.isEmpty || placeCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                
                String username = s?['username'] ?? _generateUsername(nameCtrl.text);
                String password = s?['password'] ?? _generatePassword();

                setState(() {
                  final newData = {
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
                    setState(() {
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
                        _groups.add(classGroup);
                      }
                      
                      // Add student as group member
                      _groupMembers.add({
                        'group_id': classGroup!['id'],
                        'user_id': username,
                        'role': 'member',
                        'type': 'student',
                      });
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
      )
    );
  }

  void _showAddTeacherDialog({int? index}) {
    final t = index != null ? _teachers[index] : null;
    final nameCtrl = TextEditingController(text: t?['name'] ?? '');
    final classCtrl = TextEditingController(text: t?['class'] ?? '');
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
                const SizedBox(height: 8),
                TextField(
                  controller: classCtrl,
                  decoration: const InputDecoration(labelText: 'Class', prefixIcon: Icon(Icons.class_)),
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
                    'class': classCtrl.text,
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
                    final className = classCtrl.text.trim();
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
    final classCtrl = TextEditingController(text: e?['class'] ?? '');
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
                TextField(controller: classCtrl, decoration: const InputDecoration(labelText: 'Class', prefixIcon: Icon(Icons.class_))),
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
                    'class': classCtrl.text,
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

    return FadeInEntrance(
      child: Scaffold(
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
      floatingActionButton: _currentIndex == -1 
        ? FloatingActionButton(
            onPressed: () => _showEditMetricDialog(),
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          )
        : null,
      bottomNavigationBar: Container(
        height: 65,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.class_, 'Class', 0, colorScheme),
            _buildNavItem(Icons.person, 'Teacher', 1, colorScheme),
            _buildNavItem(Icons.assignment, 'Exam', 2, colorScheme),
            _buildNavItem(Icons.message, 'Msg', 3, colorScheme),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton(
              onPressed: () => _showAddMessageDialog(),
              backgroundColor: const Color(0xFF25D366), // WhatsApp Green
              child: const Icon(Icons.message, color: Colors.white),
            )
          : null,
    ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colorScheme.primary : Colors.grey;
    return InkWell(
      onTap: () {
        setState(() {
          if (_currentIndex == index) {
            _currentIndex = -1;
          } else {
            _currentIndex = index;
            _selectedClassInTab = null; // Reset drill-down when switching tabs
          }
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_currentIndex) {
      case 0: return _buildStudentsTab(colorScheme);
      case 1: return _buildTeachersTab(colorScheme);
      case 2: return _buildExamsTab(colorScheme);
      case 3: return _buildMessagesTab(colorScheme);
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
                          trailing: const Icon(Icons.chevron_right),
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
                             setState(() => _classes.add(classCtrl.text));
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

  Widget _buildExamsTab(ColorScheme colorScheme) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Exams List', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _exams.isEmpty
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No exams added yet.'),
                ],
              ))
            : ListView.builder(
                itemCount: _exams.length,
                itemBuilder: (context, index) {
                  final e = _exams[index];
                  final List subs = e['subjects'] ?? [];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExpansionTile(
                      leading: const CircleAvatar(child: Icon(Icons.assignment)),
                      title: Text(e['examName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Class: ${e['class']} | ${subs.length} Subjects'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.teal), onPressed: () => _showAddExamDialog(index: index)),
                          IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => setState(() => _exams.removeAt(index))),
                        ],
                      ),
                      children: subs.map<Widget>((s) => ListTile(
                        dense: true,
                        title: Text(s['name'] ?? ''),
                        subtitle: Text('${s['date']} | ${s['time']}'),
                      )).toList(),
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
              icon: const Icon(Icons.add),
              label: const Text('Add Exam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
            ),
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
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Expanded(
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
                      senderUsername: 'manager',
                      senderName: 'Manager',
                      senderRole: 'Manager',
                      receiverUsername: t['username'] ?? '',
                      receiverName: t['name'] ?? '',
                      receiverRole: 'Teacher',
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
                          senderUsername: 'manager',
                          senderName: 'Manager',
                          senderRole: 'Manager',
                          receiverUsername: s['username'] ?? '',
                          receiverName: s['name'] ?? '',
                          receiverRole: 'Student',
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

  Widget _buildAddMessageTab(ColorScheme colorScheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showAddMessageDialog(),
              icon: const Icon(Icons.message),
              label: const Text('Add Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// Conversations Tab Widget
class _ConversationsTab extends StatelessWidget {
  const _ConversationsTab();

  @override
  Widget build(BuildContext context) {
    // Access messages from context
    final messages = _LoginScreenState._allMessages;
    
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a new conversation by tapping the + button',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages.reversed.toList()[index];
        final isGroup = msg['isGroup'] ?? false;
        final isFromManager = msg['from'] == 'Manager';
        
        return FadeInEntrance(
          delay: index * 0.05,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: isFromManager ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isFromManager) ...[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: const Icon(Icons.person, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isFromManager 
                          ? Colors.teal.shade100 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isGroup)
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 14, color: Colors.purple),
                              const SizedBox(width: 4),
                              Text(
                                '${(msg['recipients'] as List?)?.length ?? 0} recipients',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                              ),
                            ],
                          ),
                        if (isGroup)
                          const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isFromManager ? Colors.teal.shade900 : Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTimestamp(msg['timestamp']),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                                if (isFromManager)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      isGroup ? Icons.done_all : Icons.done,
                                      size: 16,
                                      color: Colors.teal.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              isFromManager ? 'To: ${msg['to']}' : 'From: ${msg['from'] ?? 'Manager'}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isFromManager) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    child: const Icon(Icons.person, color: Colors.teal, size: 20),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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

// All Users Tab Widget
class _AllUsersTab extends StatelessWidget {
  const _AllUsersTab();

  @override
  Widget build(BuildContext context) {
    final students = _LoginScreenState._allStudents;
    final teachers = _LoginScreenState._allTeachers;
    final allUsers = [
      ...teachers.map((t) => {'name': t['name'], 'type': 'Teacher', 'class': t['class']}),
      ...students.map((s) => {'name': s['name'], 'type': 'Student', 'class': s['std']}),
    ];

    if (allUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Not yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'No teachers or students added yet',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Teachers (${teachers.length})'),
                Tab(text: 'Students (${students.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Teachers List
                teachers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Not yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const Text('No teachers added', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: teachers.length,
                        itemBuilder: (context, index) {
                          final t = teachers[index];
                          return FadeInEntrance(
                            delay: index * 0.03,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(0.1),
                                  child: const Icon(Icons.badge, color: Colors.green),
                                ),
                                title: Text(t['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Class: ${t['class']} | Subjects: ${t['subjects']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.message, color: Colors.teal),
                                  onPressed: () => setState(() {
                                    _currentIndex = 3; // Switch to Messaging tab
                                    // Optionally start a chat here if the manager chat UI supports it
                                  }),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                // Students List
                students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Not yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const Text('No students added', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final s = students[index];
                          return FadeInEntrance(
                            delay: index * 0.03,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.withOpacity(0.1),
                                  child: const Icon(Icons.school, color: Colors.orange),
                                ),
                                title: Text(s['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Class: ${s['std']} | Place: ${s['place']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.message, color: Colors.orange),
                                  onPressed: () => setState(() {
                                    _currentIndex = 3; // Switch to Messaging tab
                                  }),
                                ),
                              ),
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
  int _currentIndex = 0; // 0: Home, 1: Messages, 2: Class Group
  List<Map<String, dynamic>> get _messages => _LoginScreenState._allMessages;
  List<Map<String, dynamic>> get _groups => _LoginScreenState._allGroups;
  List<Map<String, dynamic>> get _groupMembers => _LoginScreenState._allGroupMembers;
  List<Map<String, String>> get _students => _LoginScreenState._allStudents;
  List<Map<String, String>> get _teachers => _LoginScreenState._allTeachers;

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
          _buildMessagesTab(colorScheme),
          _buildClassGroupTab(colorScheme),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.message_outlined), selectedIcon: Icon(Icons.message), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Class Group'),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () => _showStudentNewMessageDialog(colorScheme),
              backgroundColor: const Color(0xFF25D366), // WhatsApp Green
              child: const Icon(Icons.message, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHomeTab(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Welcome ${widget.studentName}!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Class ${widget.studentClass}', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildMessagesTab(ColorScheme colorScheme) {
    // Filter private messages for this student
    final myMessages = _messages.where((msg) {
      final recipients = msg['recipients'] as List? ?? [];
      return recipients.contains(widget.studentUsername);
    }).toList();

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
              const Icon(Icons.message, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Messages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${myMessages.length} conversations', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () => _showStudentNewMessageDialog(colorScheme),
                tooltip: 'Search Teachers',
              ),
            ],
          ),
        ),
        Expanded(
          child: myMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myMessages.length,
                  itemBuilder: (context, index) {
                    final msg = myMessages.reversed.toList()[index];
                    return FadeInEntrance(
                      delay: index * 0.05,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withOpacity(0.1),
                            child: const Icon(Icons.person, color: Colors.orange),
                          ),
                          title: Text(msg['from'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(msg['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(_formatTimestamp(msg['timestamp']), style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showStudentNewMessageDialog(ColorScheme colorScheme) {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> selectedRecipients = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Message', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search teachers...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setStateDialog(() {}),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SizedBox(
                    height: 300,
                    child: (() {
                      final searchTerm = searchCtrl.text.toLowerCase();
                      final filteredTeachers = _teachers.where((t) =>
                        t['name']!.toLowerCase().contains(searchTerm) ||
                        t['username']!.toLowerCase().contains(searchTerm)
                      ).toList();

                      if (filteredTeachers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No teachers found', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return ListView(
                        children: [
                          ...filteredTeachers.map((t) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withOpacity(0.1),
                              child: const Icon(Icons.badge, size: 20),
                            ),
                            title: Text(t['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Teacher - ${t['class']}'),
                            trailing: selectedRecipients.any((r) => r['username'] == t['username'])
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                            onTap: () {
                              if (!selectedRecipients.any((r) => r['username'] == t['username'])) {
                                setStateDialog(() {
                                  selectedRecipients.add({
                                    'name': t['name']!,
                                    'type': 'Teacher',
                                    'username': t['username']!,
                                  });
                                });
                              }
                            },
                          )),
                        ],
                      );
                    })(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: selectedRecipients.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _showStudentMessageComposerDialog(colorScheme, selectedRecipients);
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentMessageComposerDialog(ColorScheme colorScheme, List<Map<String, String>> recipients) {
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(recipients.length > 1 ? 'Group Message' : 'Send Message',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To: ${recipients.map((r) => r['name']).join(', ')}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Type your message...',
                  border: OutlineInputBorder(),
                  hintText: 'Enter message here',
                ),
                onChanged: (val) => setStateDialog(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: messageCtrl.text.isEmpty ? null : () {
                setState(() {
                  _messages.add({
                    'from': widget.studentName,
                    'to': recipients.map((r) => r['name']).join(', '),
                    'recipients': recipients.map((r) => r['username']).toList(),
                    'text': messageCtrl.text,
                    'timestamp': DateTime.now().toIso8601String(),
                    'isGroup': recipients.length > 1,
                    'senderType': 'Student',
                  });
                  _LoginScreenState.saveAllData();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Message sent to ${recipients.first['name']}!')),
                );
              },
            ),
          ],
        ),
      ),
    );
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
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isClassTeacher ? Colors.green.shade50 : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(msg['text'] ?? '', style: const TextStyle(fontSize: 14)),
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
      ],
    );
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
  int _currentIndex = -1; // -1: Overview, 0: Students, 1: Activities, 2: Fair, 3: Exam, 4: Result, 5: Message, 6: Staff Group

  // Use global static lists for persistence
  List<Map<String, String>> get _allStudents => _LoginScreenState._allStudents;
  List<Map<String, dynamic>> get _activities => _LoginScreenState._allActivities;
  List<Map<String, dynamic>> get _exams => _LoginScreenState._allExams;
  List<Map<String, dynamic>> get _results => _LoginScreenState._allResults;
  List<Map<String, dynamic>> get _messages => _LoginScreenState._allMessages;
  List<Map<String, dynamic>> get _fairList => _LoginScreenState._allFairItems;
  List<Map<String, dynamic>> get _groups => _LoginScreenState._allGroups;
  List<Map<String, dynamic>> get _groupMembers => _LoginScreenState._allGroupMembers;
  List<Map<String, String>> get _teachers => _LoginScreenState._allTeachers;

  List<Map<String, String>> get _students => _allStudents.where((s) => s['std'] == widget.assignedClass).toList();
  
  // New data for Fair and Progress
  final List<String> _fairs = ['Science Fair 2024', 'Arts & Crafts', 'Coding Challenge', 'Math Olympiad'];
  final Map<String, List<Map<String, dynamic>>> _studentFairs = {}; // studentName -> list of fairs with status
  final Map<String, double> _studentProgress = {}; // studentName -> progress percentage

  // Metrics for Overview page (mirroring manager's style)
  List<Map<String, dynamic>> _metrics = [];

  @override
  void initState() {
    super.initState();
    // Load data for assigned class only
    _loadDataForAssignedClass();
    // Initialize metrics cards (mirroring manager's style)
    _initializeMetrics();
  }

  void _initializeMetrics() {
    _metrics = [
      {'title': 'Students', 'value': '${_students.length}', 'icon': Icons.people, 'color': Colors.teal, 'targetIndex': 0},
      {'title': 'Activities', 'value': '${_activities.length}', 'icon': Icons.play_circle_fill, 'color': Colors.green, 'targetIndex': 1},
      {'title': 'Fairs', 'value': '${_fairList.length}', 'icon': Icons.local_activity, 'color': Colors.pink, 'targetIndex': 2},
      {'title': 'Exams', 'value': '${_exams.length}', 'icon': Icons.assignment, 'color': Colors.orange, 'targetIndex': 3},
      {'title': 'Results', 'value': '${_results.length}', 'icon': Icons.analytics, 'color': Colors.purple, 'targetIndex': 4},
      {'title': 'Messages', 'value': '${_messages.length}', 'icon': Icons.message, 'color': Colors.teal, 'targetIndex': 5},
      {'title': 'Staff Group', 'value': '${_teachers.length}', 'icon': Icons.groups, 'color': Colors.green, 'targetIndex': 6},
    ];
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

    return FadeInEntrance(
      child: Scaffold(
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
          height: 65,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.class_, 'Students', 0, colorScheme),
              _buildNavItem(Icons.play_circle_fill, 'Activities', 1, colorScheme),
              _buildNavItem(Icons.local_activity, 'Fair', 2, colorScheme),
              _buildNavItem(Icons.assignment, 'Exam', 3, colorScheme),
              _buildNavItem(Icons.analytics, 'Result', 4, colorScheme),
              _buildNavItem(Icons.message, 'Msg', 5, colorScheme),
              _buildNavItem(Icons.groups, 'Staff', 6, colorScheme),
              _buildAddButton(colorScheme),
            ],
          ),
        ),
        floatingActionButton: _currentIndex == 5
            ? FloatingActionButton(
                onPressed: () => _showSendMessageDialog(),
                backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                child: const Icon(Icons.chat, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, ColorScheme colorScheme) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? colorScheme.primary : Colors.grey;
    return InkWell(
      onTap: () {
        setState(() {
          if (_currentIndex == index) {
            _currentIndex = -1;
          } else {
            _currentIndex = index;
          }
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
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
                  'title': title,
                  'type': selectedType,
                  'description': descCtrl.text,
                  'marks': markCtrl.text,
                  'date': dateCtrl.text,
                };
                if (index != null) {
                  _activities[index] = data;
                } else {
                  _activities.add(data);
                }
                _initializeMetrics();
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
                  'title': nameCtrl.text,
                  'description': descCtrl.text,
                  'amount': amountCtrl.text,
                  'date': dateCtrl.text,
                };
                if (index != null) {
                  _fairList[index] = data;
                } else {
                  _fairList.add(data);
                }
                _initializeMetrics();
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

  void _showAddExamDialog({int? index}) {
    final e = index != null ? _exams[index] : null;
    final nameCtrl = TextEditingController(text: e?['examName'] ?? '');
    final classCtrl = TextEditingController(text: widget.assignedClass);
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
                TextField(controller: classCtrl, readOnly: true, decoration: const InputDecoration(labelText: 'Class', prefixIcon: Icon(Icons.class_))),
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
                    'class': classCtrl.text,
                    'subjects': subjects,
                  };
                  if (index != null) {
                    _exams[index] = newData;
                  } else {
                    _exams.add(newData);
                  }
                  _initializeMetrics();
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
                  for (var result in subjectResults) {
                    final data = {
                      'studentName': selectedStudent,
                      'examName': selectedExam,
                      'subject': result['subject'],
                      'totalMarks': result['totalMarks'],
                      'scoredMark': result['scoredMark'],
                    };
                    if (index != null) {
                      _results[index] = data;
                    } else {
                      _results.add(data);
                    }
                  }
                  _initializeMetrics();
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
                  _initializeMetrics();
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

  void _showAddItemDialog() {
    switch (_currentIndex) {
      case 0:
        // Add Student logic (Keep existing or update to CRUD)
        final nameCtrl = TextEditingController();
        final addressCtrl = TextEditingController();
        final parentsCtrl = TextEditingController();
        final placeCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final bloodCtrl = TextEditingController();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add Student'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Student Name *', prefixIcon: Icon(Icons.person))),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address *', prefixIcon: Icon(Icons.location_on))),
                  TextField(controller: parentsCtrl, decoration: const InputDecoration(labelText: "Parent's Name *", prefixIcon: Icon(Icons.family_restroom))),
                  TextField(controller: placeCtrl, decoration: const InputDecoration(labelText: 'Place *', prefixIcon: Icon(Icons.map))),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *', prefixIcon: Icon(Icons.phone))),
                  TextField(controller: bloodCtrl, decoration: const InputDecoration(labelText: 'Blood Group', prefixIcon: Icon(Icons.bloodtype))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty) return;
                  setState(() {
                    final newStudent = {
                      'name': nameCtrl.text,
                      'address': addressCtrl.text,
                      'parents': parentsCtrl.text,
                      'place': placeCtrl.text,
                      'phone': phoneCtrl.text,
                      'blood': bloodCtrl.text,
                      'std': widget.assignedClass,
                    };
                    _allStudents.add(newStudent); // Add to global list
                    _studentProgress[newStudent['name']!] = 0.0;
                    _studentFairs[newStudent['name']!] = _fairs.map((f) => {'title': f, 'done': false}).toList();
                    _initializeMetrics();
                    _LoginScreenState.saveAllData();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              )
            ],
          )
        );
        break;
      case 1:
        _showAddActivityDialog();
        break;
      case 2:
        _showAddFairDialog();
        break;
      case 3:
        _showAddExamDialog();
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
                ListTile(leading: const Icon(Icons.person_add), title: const Text('Add Student'), onTap: () { Navigator.pop(context); setState(() { _currentIndex = 0; }); _showAddItemDialog(); }),
                ListTile(leading: const Icon(Icons.play_circle_fill), title: const Text('Add Activity'), onTap: () { Navigator.pop(context); _showAddActivityDialog(); }),
                ListTile(leading: const Icon(Icons.local_activity), title: const Text('Add Fair'), onTap: () { Navigator.pop(context); _showAddFairDialog(); }),
                ListTile(leading: const Icon(Icons.assignment), title: const Text('Add Exam'), onTap: () { Navigator.pop(context); _showAddExamDialog(); }),
                ListTile(leading: const Icon(Icons.analytics), title: const Text('Add Result'), onTap: () { Navigator.pop(context); _showAddResultDialog(); }),
                ListTile(leading: const Icon(Icons.message), title: const Text('Send Message'), onTap: () { Navigator.pop(context); _showSendMessageDialog(); }),
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
      case 3: return _buildExamsTab(colorScheme);
      case 4: return _buildResultsTab(colorScheme);
      case 5: return _buildMessagesTab(colorScheme);
      case 6: return _buildStaffGroupTab(colorScheme);
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
    // Show students from assigned class (read-only)
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Students - Class ${widget.assignedClass}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                      const Text('No students in your class.\nManager needs to add students.'),
                      const SizedBox(height: 8),
                      Text('(Read-only view)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                        trailing: IconButton(
                          icon: const Icon(Icons.message, color: Colors.teal),
                          onPressed: () => setState(() {
                            _currentIndex = 5; // Msg tab
                            _activeChatPeerId = s['username'];
                            _activeChatPeerName = s['name'];
                            _activeChatPeerColor = Colors.teal;
                            _activeChatPeerDept = 'Class ${widget.assignedClass}';
                          }),
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
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Activities', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No activities added yet.'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade50,
                          child: const Icon(Icons.play_circle_fill, color: Colors.green),
                        ),
                        title: Text('${(activity['title']?.toString().isNotEmpty == true ? activity['title'] : 'Untitled Activity')} (${activity['type'] ?? 'Assignment'})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${(activity['description']?.toString().isNotEmpty == true ? activity['description'] : 'No description')}\nMarks: ${(activity['marks']?.toString().isNotEmpty == true ? activity['marks'] : 'TBD')} | Due: ${(activity['date']?.toString().isNotEmpty == true ? activity['date'] : 'TBD')}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.teal, size: 20), onPressed: () => _showAddActivityDialog(index: index)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() {
                              _activities.removeAt(index);
                              _initializeMetrics();
                              _LoginScreenState.saveAllData();
                            })),
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
                          ? Center(child: Text('No fairs added yet.'))
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
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(icon: const Icon(Icons.edit, color: Colors.teal, size: 20), onPressed: () => _showAddFairDialog(index: index)),
                                        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() {
                                          _fairList.removeAt(index);
                                          _initializeMetrics();
                                          _LoginScreenState.saveAllData();
                                        })),
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
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final s = _students[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.pink.shade50,
                          child: const Icon(Icons.person, color: Colors.pink),
                        ),
                        title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Progress: ${((_studentProgress[s['name']] ?? 0.0) * 100).toInt()}%'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showStudentDetails(s),
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
    final fairs = _studentFairs[name] ?? [];
    final progress = _studentProgress[name] ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topRight: Radius.circular(32), topLeft: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(radius: 36, backgroundColor: Colors.teal.shade100, child: Text(name[0], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 24),
              Text(name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              Text(student['address'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 32),
              const Text('Activities Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress, minHeight: 12, borderRadius: BorderRadius.circular(6), backgroundColor: Colors.grey.shade200, color: Colors.teal),
              const SizedBox(height: 8),
              Text('${(progress * 100).toInt()}% Completed', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              const Text('Fairs List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...fairs.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(f['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Icon(f['done'] ? Icons.check_circle : Icons.radio_button_unchecked, color: f['done'] ? Colors.green : Colors.grey),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamsTab(ColorScheme colorScheme) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Exams', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _exams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No exams added yet.'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _exams.length,
                  itemBuilder: (context, index) {
                    final exam = _exams[index];
                    final List subs = exam['subjects'] ?? [];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade50,
                          child: const Icon(Icons.assignment, color: Colors.orange),
                        ),
                        title: Text(exam['examName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Class: ${exam['class']} | ${subs.length} Subjects'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.teal, size: 20), onPressed: () => _showAddExamDialog(index: index)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() {
                              _exams.removeAt(index);
                              _initializeMetrics();
                              _LoginScreenState.saveAllData();
                            })),
                          ],
                        ),
                        children: subs.map<Widget>((s) => ListTile(
                          dense: true,
                          title: Text(s['name'] ?? ''),
                          subtitle: Text('${s['date']} | ${s['time']}'),
                        )).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildResultsTab(ColorScheme colorScheme) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Results', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('No results added yet.'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade50,
                          child: const Icon(Icons.analytics, color: Colors.purple),
                        ),
                        title: Text(result['studentName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Subject: ${result['subject']} | Marks: ${result['scoredMark']} / ${result['totalMarks']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.teal, size: 20), onPressed: () => _showAddResultDialog(index: index)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() {
                              _results.removeAt(index);
                              _initializeMetrics();
                              _LoginScreenState.saveAllData();
                            })),
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
    final myId = widget.teacherUsername;
    List<String> ids = [myId, peerId];
    ids.sort();
    return ids.join("_");
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
        'roomId': roomId,
        'peerId': _activeChatPeerId,
        'peerName': _activeChatPeerName,
      });
      _LoginScreenState.saveAllData();
    });

    _chatMsgCtrl.clear();
    if (_chatEmojiOpen) setState(() => _chatEmojiOpen = false);
    
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
        .where((m) => m['roomId'] == roomId)
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
        "status": "Active",
      }),
    ];

    final bool hasActiveChat = _activeChatPeerId != null;

    return Row(
      children: [
        // ========== LEFT SIDEBAR - CONTACTS LIST ==========
        if (!hasActiveChat)
          Expanded(
            child: _buildContactSidebar(colorScheme, allContacts),
          )
        else
          SizedBox(
            width: 300,
            child: _buildContactSidebar(colorScheme, allContacts),
          ),

        // ========== RIGHT CHAT PANEL ==========
        if (hasActiveChat)
          Expanded(
            child: _buildChatPanel(colorScheme),
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
                    final colorValue = int.parse(contact['color'] as String);
                    
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
                                  Text(
                                    "${contact['role']} • ${contact['status']}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
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
            ],
          ),
        ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _activeChatPeerId = null),
        ),
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
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png'),
                  opacity: 0.05,
                  repeat: ImageRepeat.repeat,
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
            Text(msg['text'] ?? '', style: const TextStyle(fontSize: 14)),
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


  Widget _buildStaffGroupTab(ColorScheme colorScheme) {
    final staffGroup = _groups.where((g) => g['type'] == 'staff').firstOrNull;
    final staffMessages = _messages.where((msg) =>
      msg['group_id'] == staffGroup?['id'] || msg['isStaffMessage'] == true
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
                    const Text('Teachers Staff Room', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('${_teachers.length} teachers • Discussions & Announcements', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_comment, color: Colors.white),
                onPressed: () => _showStaffMessageDialog(colorScheme),
                tooltip: 'Post to Staff Group',
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
                      Icon(Icons.groups_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No staff messages yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.green.withOpacity(0.2),
                              child: const Icon(Icons.badge, color: Colors.green, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(msg['from'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (isTeacher) ...[
                                        const SizedBox(width: 6),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text('Teacher', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(msg['text'] ?? '', style: const TextStyle(fontSize: 14)),
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

  void _showStaffMessageDialog(ColorScheme colorScheme) {
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Post to Staff Group', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will be visible to all teachers', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                    'to': 'All Teachers',
                    'text': messageCtrl.text,
                    'timestamp': DateTime.now().toIso8601String(),
                    'isStaffMessage': true,
                    'senderType': 'Teacher',
                    'group_id': 'staff_global',
                  });
                  _LoginScreenState.saveAllData();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message posted to staff group!')));
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
}

// ==========================================
// DIRECT CHAT SCREEN (WhatsApp style)
// ==========================================
class DirectChatScreen extends StatefulWidget {
  final String senderUsername;
  final String senderName;
  final String senderRole;
  final String receiverUsername;
  final String receiverName;
  final String receiverRole;

  const DirectChatScreen({
    super.key,
    required this.senderUsername,
    required this.senderName,
    required this.senderRole,
    required this.receiverUsername,
    required this.receiverName,
    required this.receiverRole,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // Conversation key: canonical (sorted) pair of usernames
  String get _convKey {
    final pair = [widget.senderUsername, widget.receiverUsername];
    pair.sort();
    return pair.join('::');
  }

  List<Map<String, dynamic>> get _convMessages => _LoginScreenState._allMessages
      .where((m) => m['convKey'] == _convKey)
      .toList()
    ..sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _LoginScreenState._allMessages.add({
        'convKey': _convKey,
        'from': widget.senderUsername,
        'fromName': widget.senderName,
        'fromRole': widget.senderRole,
        'to': widget.receiverUsername,
        'toName': widget.receiverName,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _LoginScreenState.saveAllData();
    });
    _msgCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final messages = _convMessages;
    final avatarColor = widget.receiverRole == 'Teacher'
        ? Colors.green
        : widget.receiverRole == 'Manager'
            ? Colors.teal
            : Colors.orange;

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // WhatsApp bg
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withOpacity(0.25),
              child: Text(
                widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(widget.receiverRole, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('Say hi to ${widget.receiverName}!', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMine = msg['from'] == widget.senderUsername;
                      return _buildBubble(msg, isMine);
                    },
                  ),
          ),
          // Input bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
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

  Widget _buildBubble(Map<String, dynamic> msg, bool isMine) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 6,
          left: isMine ? 60 : 0,
          right: isMine ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(msg['fromName'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF075E54))),
              ),
            Text(msg['text'] ?? '', style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 4),
            Text(_formatTime(msg['timestamp']), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
