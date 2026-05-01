import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data_store.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Firebase Auth requires passwords to be at least 6 characters
  String _getFirebasePassword(String rawPassword) {
    String p = rawPassword.trim();
    if (p.length < 6) {
      return p.padRight(6, '_');
    }
    return p;
  }

  // Sign in with email & password
  Future<dynamic> signIn(String email, String password) async {
    try {
      debugPrint("--- REAL LOGIN ATTEMPT ---");
      
      String formattedEmail = email.trim().toLowerCase();
      if (!formattedEmail.contains('@')) {
        formattedEmail = '$formattedEmail@harakat.com';
      }
      
      // 1. Firebase Auth Sign In
      UserCredential result;
      final firebasePassword = _getFirebasePassword(password);
      try {
        result = await _auth.signInWithEmailAndPassword(
          email: formattedEmail,
          password: firebasePassword,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
          if (formattedEmail.contains('minad') || formattedEmail.contains('director')) {
            try {
              // Auto-create admin if it doesn't exist
              result = await _auth.createUserWithEmailAndPassword(
                email: formattedEmail,
                password: firebasePassword,
              );
            } catch (createError) {
              // If creation fails (e.g. email already exists, meaning it was just a wrong password)
              throw Exception("Invalid username or password.");
            }
          } else {
            throw Exception("Invalid username or password.");
          }
        } else {
          rethrow;
        }
      }
      
      User? user = result.user;
      if (user == null) throw Exception("User not found");

      // 2. Fetch User Metadata from Firestore
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      
      if (!doc.exists) {
        // Fallback for Director (if they are the one who set up the project)
        if (formattedEmail.contains('director') || formattedEmail.contains('minad')) {
           final adminData = {
             'role': formattedEmail.contains('minad') ? 'admin' : 'director',
             'username': formattedEmail.split('@')[0],
             'uid': user.uid,
             'name': formattedEmail.contains('minad') ? 'Super Admin' : 'Academic Director',
           };
           await _db.collection('users').doc(user.uid).set(adminData);
           DataStore.updateMockUser(adminData);
           return adminData;
        }
        throw Exception("User data not found in database.");
      }

      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      userData['uid'] = user.uid; // Ensure UID is included
      userData['email'] = formattedEmail; // Include email for robust role checking
      
      DataStore.updateMockUser(userData);
      return userData;

    } on FirebaseAuthException catch (e) {
      debugPrint("Login Error: ${e.code}");
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception("Invalid username or password.");
      }
      throw Exception(e.message ?? "Authentication failed.");
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    DataStore.updateMockUser(null);
  }

  // Register a new user (used by Director)
  // We use a secondary Firebase app instance to avoid logging out the current admin
  Future<void> registerUser(Map<String, dynamic> userData, String password) async {
    FirebaseApp? secondaryApp;
    try {
      final email = userData['username'].contains('@') 
          ? userData['username'] 
          : '${userData['username']}@harakat.com';
      
      // 1. Create a secondary app instance
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      
      FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      
      final firebasePassword = _getFirebasePassword(password);
      
      // 2. Create Auth Account in secondary app
      UserCredential result = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: firebasePassword,
      );
      
      if (result.user != null) {
        // 3. Store metadata in Firestore using primary app instance
        userData['uid'] = result.user!.uid;
        userData['role'] = userData['role'] ?? (userData.containsKey('std') ? 'student' : 'teacher');
        await _db.collection('users').doc(result.user!.uid).set(userData);
      }
    } catch (e) {
      debugPrint("Registration Error: $e");
      throw Exception("Failed to create secure account: ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      // 4. Clean up secondary app
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }
}
