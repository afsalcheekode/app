import 'data_store.dart';
import 'dart:async';

class AuthService {
  // Stream of auth state changes (supports only Mock in Free Mode)
  Stream<dynamic> get userStream {
    return DataStore.mockAuthStream;
  }

  // Sign in with email & password (Mock Only)
  Future<dynamic> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    
    // Mock Login Logic
    Map<String, dynamic>? found;
    
    // Check Teachers
    for (var t in DataStore.allTeachers) {
      if ((t['username'] == cleanEmail || t['username'] == email.split('@')[0]) && t['password'] == password) {
        found = {...t, 'role': 'teacher', 'uid': 'mock_teacher_${t['username']}'};
        break;
      }
    }
    
    if (found == null) {
      // Check Students
      for (var s in DataStore.allStudents) {
        if ((s['username'] == cleanEmail || s['username'] == email.split('@')[0]) && s['password'] == password) {
          found = {...s, 'role': 'student', 'uid': 'mock_student_${s['username']}'};
          break;
        }
      }
    }
    
    if (found == null) {
      // Check Directors
      for (var d in DataStore.allSchools) {
        if ((d['username'] == cleanEmail || d['username'] == email.split('@')[0]) && d['password'] == password) {
          found = {...d, 'role': 'director', 'uid': 'mock_director_${d['username']}', 'schoolName': d['school'] ?? 'Unknown School'};
          break;
        }
      }
    }

    if (found != null) {
      DataStore.updateMockUser(found);
      return found;
    } else {
      throw Exception("Invalid credentials (Mock Mode)");
    }
  }

  // Sign out
  Future<void> signOut() async {
    DataStore.updateMockUser(null);
  }

  // Get user data (role, name, etc.)
  Future<dynamic> getUserData(String uid) async {
    // Return mock data from the stored user
    return MockDocumentSnapshot(DataStore.mockUser ?? {});
  }
}

// Simple helper to mimic DocumentSnapshot for mock data
class MockDocumentSnapshot {
  final Map<String, dynamic> _data;
  MockDocumentSnapshot(this._data);
  Map<String, dynamic>? data() => _data;
}
