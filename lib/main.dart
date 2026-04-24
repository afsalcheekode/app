import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'data_store.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'director_board.dart' as director;
import 'teacher_board.dart' as teacher;
import 'student_board.dart' as student;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("App Starting...");
  
  try {
    debugPrint("Initializing Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      debugPrint("Firebase Initialization Timed Out");
      throw Exception("Firebase Timeout");
    });
    DataStore.isFirebaseReady = true;
    debugPrint("Firebase Initialized Successfully");
  } catch (e) {
    debugPrint("Firebase Initialization Failed or Timed Out: $e");
    DataStore.isFirebaseReady = false;
  }

  debugPrint("Initializing DataStore...");
  await DataStore.initPrefs();
  debugPrint("Initialization Complete. Running App.");
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
      initialData: DataStore.mockUser,
      stream: auth.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        debugPrint("Auth State: ${user == null ? 'Logged Out' : 'Logged In'}");

        if (user == null) {
          return const LoginScreen();
        }

        String uid;
        if (user is Map) {
          uid = user['uid'].toString();
        } else {
          // Firebase User
          uid = (user as dynamic).uid;
        }

        // User is logged in, fetch role
        return FutureBuilder<dynamic>(
          future: auth.getUserData(uid).timeout(const Duration(seconds: 15), onTimeout: () {
             debugPrint("GetUserData Timed Out for $uid");
             return null; 
          }),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Loading User Profile...", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            if (roleSnapshot.hasError) {
              debugPrint("Role Fetch Error: ${roleSnapshot.error}");
              return const LoginScreen();
            }

            final dynamic snapshotData = roleSnapshot.data;
            if (snapshotData == null) {
              debugPrint("No User Data Found for $uid");
              return const LoginScreen();
            }

            // In Free Mode, this is always MockDocumentSnapshot
            // In Firebase mode, it's a DocumentSnapshot
            Map<String, dynamic>? data;
            if (snapshotData is MockDocumentSnapshot) {
              data = snapshotData.data();
            } else {
              data = (snapshotData as dynamic).data();
            }

            if (data == null) {
              debugPrint("User Data Map is Null for $uid");
              return const LoginScreen();
            }

            final role = data['role']?.toString().toLowerCase();
            final String username = data['username'] ?? data['name'] ?? 'user';
            debugPrint("User Role identified: $role for $username");
            
            if (role == 'director' || role == 'academic_director' || role == 'school') {
              return director.SchoolDashboardScreen(
                schoolName: data!['schoolName'] ?? data['school'] ?? 'Academic Director',
                directorName: data['academic_director'] ?? data['manager'] ?? 'Director',
                username: username,
              );
            } else if (role == 'teacher') {
              return teacher.TeacherBoardScreen(
                teacherName: data!['name'] ?? 'Teacher',
                assignedClass: data['class'] ?? '',
                subjects: data['subjects'] ?? '',
                teacherUsername: username,
              );
            } else if (role == 'student') {
              return student.StudentBoardScreen(
                studentName: data!['name'] ?? 'Student',
                studentClass: data['std'] ?? '',
                studentUsername: username,
                studentData: Map<String, String>.from(data.map((k, v) => MapEntry(k, v.toString()))),
              );
            }

            debugPrint("Unknown Role: $role");
            return const LoginScreen();
          },
        );
      },
    );
  }
}
