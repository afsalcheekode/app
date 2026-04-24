import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data_store.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _initStream();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  final StreamController<dynamic> _userController = StreamController<dynamic>.broadcast();
  StreamSubscription? _fbSubscription;
  StreamSubscription? _mockSubscription;

  void _initStream() {
    _fbSubscription?.cancel();
    _mockSubscription?.cancel();

    if (DataStore.isFirebaseReady) {
      _fbSubscription = _auth.authStateChanges().listen((user) {
        if (user != null) {
          _userController.add(user);
        } else {
          _userController.add(DataStore.mockUser);
        }
      });
    } else {
      _userController.add(DataStore.mockUser);
    }

    _mockSubscription = DataStore.mockAuthStream.listen((user) {
      _userController.add(user);
    });
  }

  // Stream of auth state changes
  Stream<dynamic> get userStream => _userController.stream;

  // Sign in with email & password
  Future<dynamic> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    
    if (DataStore.isFirebaseReady) {
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: cleanEmail.contains('@') ? cleanEmail : '$cleanEmail@harakat.com',
          password: password,
        );
        debugPrint("Firebase Login Successful");
        return credential.user;
      } catch (e) {
        debugPrint("Firebase Login Failed: $e. Trying Mock Fallback...");
      }
    }

    // Mock Login Logic (Fallback)
    Map<String, dynamic>? found;
    for (var t in DataStore.allTeachers) {
      if ((t['username'] == cleanEmail || t['username'] == email.split('@')[0]) && t['password'] == password) {
        found = {...t, 'role': 'teacher', 'uid': 'mock_teacher_${t['username']}'};
        break;
      }
    }
    if (found == null) {
      for (var s in DataStore.allStudents) {
        if ((s['username'] == cleanEmail || s['username'] == email.split('@')[0]) && s['password'] == password) {
          found = {...s, 'role': 'student', 'uid': 'mock_student_${s['username']}'};
          break;
        }
      }
    }
    if (found == null) {
      for (var d in DataStore.allSchools) {
        if ((d['username'] == cleanEmail || d['username'] == email.split('@')[0]) && d['password'] == password) {
          found = {...d, 'role': 'director', 'uid': 'mock_director_${d['username']}', 'schoolName': d['school'] ?? 'Unknown School'};
          break;
        }
      }
    }

    if (found != null) {
      debugPrint("Mock Login Successful for ${found['username']}");
      DataStore.updateMockUser(found);
      return found;
    } else {
      throw Exception("Invalid credentials");
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (DataStore.isFirebaseReady) {
      await _auth.signOut();
    }
    DataStore.updateMockUser(null);
  }

  // Get user data (role, name, etc.)
  Future<dynamic> getUserData(String uid) async {
    if (DataStore.isFirebaseReady && !uid.startsWith('mock_')) {
      return await _db.collection('users').doc(uid).get();
    }
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
