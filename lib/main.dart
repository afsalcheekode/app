import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'data_store.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'director_board.dart' as director;
import 'teacher_board.dart' as teacher;
import 'student_board.dart' as student;
import 'admin_board.dart' as admin;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SchoolApp());
}

class SchoolApp extends StatefulWidget {
  const SchoolApp({super.key});

  @override
  State<SchoolApp> createState() => _SchoolAppState();
}

class _SchoolAppState extends State<SchoolApp> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await DataStore.initPrefs();
      // Assets are pre-cached after the UI is already visible
      if (mounted) {
        precacheImage(const AssetImage('assets/images/app_logo_v2.png'), context);
        precacheImage(const AssetImage('assets/images/app_name_arabic.png'), context);
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF075E54),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Image.asset('assets/images/app_logo_v2.png', height: 100),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  'LOADING BRIDGE...',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'حركات الحياة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075E54),
          primary: const Color(0xFF075E54),
          secondary: const Color(0xFF25D366),
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      initialData: DataStore.mockUser,
      stream: DataStore.mockAuthStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        debugPrint("Auth State: ${data == null ? 'Logged Out' : 'Logged In'}");

        if (data == null) {
          return const LoginScreen();
        }

        final String username = data['username'] ?? data['name'] ?? 'user';
        final String email = data['email']?.toString() ?? '';
        final role = data['role']?.toString().toLowerCase() ?? (email.contains('minad') || username == 'minad' ? 'admin' : 'unknown');
        debugPrint("User Role identified: $role for $username (email: $email)");
        
        if (role == 'admin' || email.contains('minad') || username == 'minad') {
          return const admin.AdminBoardScreen();
        } else if (role == 'director' || role == 'academic_director' || role == 'school') {
          return director.SchoolDashboardScreen(
            schoolName: data['schoolName'] ?? data['school'] ?? 'Academic Director',
            directorName: data['academic_director'] ?? data['manager'] ?? 'Director',
            username: username,
          );
        } else if (role == 'teacher') {
          return teacher.TeacherBoardScreen(
            teacherName: data['name'] ?? 'Teacher',
            assignedClass: data['class'] ?? '',
            subjects: data['subjects'] ?? '',
            teacherUsername: username,
            schoolName: data['schoolName'] ?? '',
            photo: data['photo']?.toString() ?? '',
            qualification: data['qualification']?.toString() ?? '',
            designation: data['designation']?.toString() ?? '',
          );
        } else if (role == 'student') {
          return student.StudentBoardScreen(
            studentName: data['name'] ?? 'Student',
            studentClass: data['std'] ?? '',
            studentUsername: username,
            studentData: Map<String, String>.from(data.map((k, v) => MapEntry(k, v.toString()))),
          );
        }

        debugPrint("Unknown Role: $role - Showing Login");
        return const LoginScreen();
      },
    );
  }
}
