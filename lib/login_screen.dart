import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'common.dart';
import 'data_store.dart';
import 'notification_service.dart';
import 'student_board.dart';
import 'teacher_board.dart';
import 'director_board.dart';
import 'admin_board.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
  }

  void _login() async {
    final userInput = _userController.text.trim();
    final pass = _passController.text.trim();

    if (userInput.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both credentials.')),
      );
      return;
    }

    // Local Super Admin Override (kept for convenience)
    if (userInput == 'minad' && pass == '321') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminBoardScreen()),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Data Normalization as requested: .trim() and .toLowerCase()
      final email = userInput.contains('@') ? userInput.toLowerCase() : '$userInput@harakat.com'.toLowerCase();
      
      await AuthService().signIn(email, pass);

      if (mounted) Navigator.pop(context); // Close loading
      // AuthWrapper will handle the rest
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInEntrance(
                    delay: 0.2,
                    child: Column(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF075E54).withOpacity(0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                                spreadRadius: 2,
                              )
                            ],
                            border: Border.all(
                              color: const Color(0xFF075E54).withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/app_logo_v2.png',
                                height: 120,
                                width: 120,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.school, size: 60, color: colorScheme.primary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'حركات الحياة',
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF075E54)),
                        ),
                        Text(
                          'HARAKAT AL-HAYAT',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  FadeInEntrance(
                    delay: 0.4,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 40, offset: const Offset(0, 20))
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _userController,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.person_outline_rounded, color: colorScheme.primary),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _passController,
                            obscureText: true,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: Icon(Icons.lock_outline_rounded, color: colorScheme.primary),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                              onPressed: _login,
                              child: const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
