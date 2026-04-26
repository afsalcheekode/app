import 'package:flutter/material.dart';
import 'data_store.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'director_board.dart' as director;
import 'teacher_board.dart' as teacher;
import 'student_board.dart' as student;
import 'admin_board.dart' as admin;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("App Starting (Offline Mode)...");
  
  debugPrint("Initializing DataStore in background...");
  DataStore.initPrefs();
  
  runApp(const SchoolApp());
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
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

        final role = data['role']?.toString().toLowerCase();
        final String username = data['username'] ?? data['name'] ?? 'user';
        debugPrint("User Role identified: $role for $username");
        
        if (role == 'director' || role == 'academic_director' || role == 'school') {
          return director.SchoolDashboardScreen(
            schoolName: data['schoolName'] ?? data['school'] ?? 'Academic Director',
            directorName: data['academic_director'] ?? data['manager'] ?? 'Director',
            username: username,
          );
        } else if (role == 'admin') {
          return const admin.AdminBoardScreen();
        } else if (role == 'teacher') {
          return teacher.TeacherBoardScreen(
            teacherName: data['name'] ?? 'Teacher',
            assignedClass: data['class'] ?? '',
            subjects: data['subjects'] ?? '',
            teacherUsername: username,
            schoolName: data['schoolName'] ?? '',
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
