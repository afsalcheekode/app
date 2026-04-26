import 'data_store.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Sign in with email & password
  Future<dynamic> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();
    final usernameOnly = cleanEmail.split('@')[0];
    
    debugPrint("--- LOGIN ATTEMPT ---");
    debugPrint("Input User: $cleanEmail, Input Pass: $cleanPass");
    debugPrint("Total Schools: ${DataStore.allSchools.length}");
    
    // Mock Login Logic
    Map<String, dynamic>? found;

    // 0. Super Admin Check
    if ((cleanEmail == 'minad' || usernameOnly == 'minad') && cleanPass == '321') {
      found = {
        'role': 'admin',
        'username': 'minad',
        'name': 'Super Admin',
        'uid': 'mock_admin_minad'
      };
      debugPrint("SUCCESS: Super Admin Logged In");
    }
    
    // 1. Check Schools (Highest Priority)
    if (found == null) {
      for (var d in DataStore.allSchools) {
        final storedUser = (d['username'] ?? '').trim().toLowerCase();
        final storedPass = (d['password'] ?? '').trim();
        
        bool userMatch = (storedUser == cleanEmail || storedUser == usernameOnly);
        bool passMatch = (storedPass == cleanPass);
        
        if (userMatch && passMatch) {
          found = {
            ...d, 
            'role': 'director', 
            'uid': 'mock_director_${d['username']}', 
            'schoolName': d['school'] ?? 'Unknown School',
            'academic_director': d['academic_director'] ?? d['manager'] ?? 'Director',
          };
          debugPrint("SUCCESS: Found School ${d['username']}");
          break;
        }
      }
    }
    
    // 2. Check Teachers
    if (found == null) {
      for (var t in DataStore.allTeachers) {
        final storedUser = (t['username'] ?? '').trim().toLowerCase();
        final storedPass = (t['password'] ?? '').trim();
        if ((storedUser == cleanEmail || storedUser == usernameOnly) && storedPass == cleanPass) {
          found = {...t, 'role': 'teacher', 'uid': 'mock_teacher_${t['username']}'};
          debugPrint("SUCCESS: Found Teacher ${t['username']}");
          break;
        }
      }
    }
    
    // 3. Check Students
    if (found == null) {
      for (var s in DataStore.allStudents) {
        final storedUser = (s['username'] ?? '').trim().toLowerCase();
        final storedPass = (s['password'] ?? '').trim();
        if ((storedUser == cleanEmail || storedUser == usernameOnly) && storedPass == cleanPass) {
          found = {...s, 'role': 'student', 'uid': 'mock_student_${s['username']}'};
          debugPrint("SUCCESS: Found Student ${s['username']}");
          break;
        }
      }
    }

    if (found != null) {
      DataStore.updateMockUser(found);
      return found;
    } else {
      debugPrint("FAILURE: No matching account found for $cleanEmail");
      String errorMsg = "Invalid username or password.";
      if (DataStore.allSchools.any((d) => (d['username'] ?? '').toLowerCase() == usernameOnly)) {
        errorMsg = "School found, but password incorrect.";
      }
      throw Exception(errorMsg);
    }
  }

  // Sign out
  Future<void> signOut() async {
    DataStore.updateMockUser(null);
  }

  // Get user data (role, name, etc.)
  Future<dynamic> getUserData(String uid) async {
    return MockDocumentSnapshot(DataStore.mockUser ?? {});
  }
}

// Simple helper to mimic DocumentSnapshot for mock data
class MockDocumentSnapshot {
  final Map<String, dynamic> _data;
  MockDocumentSnapshot(this._data);
  Map<String, dynamic>? data() => _data;
}
