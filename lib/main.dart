import 'package:flutter/material.dart';
import 'data_store.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'director_board.dart';
import 'teacher_board.dart';
import 'student_board.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // FORCE FREE MODE: Completely bypass Firebase
  DataStore.isFirebaseReady = false;
  debugPrint("Running in FREE MODE (Offline/Mock)");

  await DataStore.initPrefs();
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
    final auth = AuthService();
    
    return StreamBuilder<dynamic>(
      stream: auth.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Mock User is always a Map in Free Mode
        final Map<String, dynamic> userData = user as Map<String, dynamic>;
        final String uid = userData['uid'].toString();

        // User is logged in, fetch role
        return FutureBuilder<dynamic>(
          future: auth.getUserData(uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final dynamic snapshotData = roleSnapshot.data;
            if (snapshotData == null) return const LoginScreen();

            // In Free Mode, this is always MockDocumentSnapshot
            final Map<String, dynamic>? data = (snapshotData is MockDocumentSnapshot)
                ? snapshotData.data()
                : null;

            if (data == null) {
              return const LoginScreen();
            }

            final role = data['role']?.toString().toLowerCase();
            final String username = data['username'] ?? 'user';
            
            if (role == 'director' || role == 'academic_director' || role == 'school') {
              return SchoolDashboardScreen(
                schoolName: data['schoolName'] ?? data['school'] ?? 'Academic Director',
                username: username,
              );
            } else if (role == 'teacher') {
              return TeacherBoardScreen(
                teacherName: data['name'] ?? 'Teacher',
                assignedClass: data['class'] ?? '',
                subjects: data['subjects'] ?? '',
                teacherUsername: username,
              );
            } else if (role == 'student') {
              return StudentBoardScreen(
                studentName: data['name'] ?? 'Student',
                studentClass: data['std'] ?? '',
                studentUsername: username,
                studentData: Map<String, String>.from(data.map((k, v) => MapEntry(k, v.toString()))),
              );
            }

            return const LoginScreen();
          },
        );
      },
    );
  }
}
