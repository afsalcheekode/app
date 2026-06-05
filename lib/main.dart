import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'data_store.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'director_board.dart' as director;
import 'teacher_board.dart' as teacher;
import 'student_board.dart' as student;
import 'admin_board.dart' as admin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await DataStore.initPrefs();
    
    // Run cleanup asynchronously so it doesn't block app startup
    Future.microtask(() async {
      try {
        if (DataStore.allSchools.length > 1 || DataStore.allSchools.any((s) => s['username'] != 'hsh.dtcr')) {
          DataStore.allSchools.removeWhere((s) => s['username'] != 'hsh.dtcr');
          await DataStore.saveAllData();
          
          final query = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'director').get();
          for (var doc in query.docs) {
            if (doc.data()['username'] != 'hsh.dtcr') {
              await doc.reference.delete();
            }
          }
          debugPrint("Cleanup of director accounts completed!");
        }
      } catch (e) {
        debugPrint("Cleanup error: $e");
      }
    });
  } catch (e) {
    debugPrint("Init Error: $e");
  }
  runApp(const SchoolApp());
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Precache images if possible
    precacheImage(const AssetImage('assets/images/app_logo_v2.png'), context);
    precacheImage(const AssetImage('assets/images/app_name_arabic.png'), context);

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
            fullName: data['fullName'] ?? '',
            assignedClass: data['class'] ?? '',
            teacherUsername: username,
            schoolName: data['schoolName'] ?? '',
            photo: data['photo']?.toString() ?? '',
            qualIslamic: data['qual_islamic']?.toString() ?? '',
            qualAcademic: data['qual_academic']?.toString() ?? '',
            designation: data['designation']?.toString() ?? '',
          );
        } else if (role == 'student') {
          return student.StudentBoardScreen(
            studentName: data['name'] ?? 'Student',
            studentClass: data['std'] ?? '',
            studentUsername: username,
            studentData: Map<String, String>.from(data.map((k, v) => MapEntry(k, v?.toString() ?? ''))),
          );
        }

        debugPrint("Unknown Role: $role - Showing Login");
        return const LoginScreen();
      },
    );
  }
}
