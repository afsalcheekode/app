import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'web_helper.dart' if (dart.library.html) 'web_helper_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  String _normalizeNumbers(String input) {
    const arabicNumbers = '٠١٢٣٤٥٦٧٨٩';
    const persianNumbers = '۰۱۲۳۴۵۶۷۸۹';
    const englishNumbers = '0123456789';

    String result = input;
    for (int i = 0; i < englishNumbers.length; i++) {
      result = result
          .replaceAll(arabicNumbers[i], englishNumbers[i])
          .replaceAll(persianNumbers[i], englishNumbers[i]);
    }
    return result;
  }

  bool _isLoading = false;

  void _login() async {
    final userInput = _normalizeNumbers(_userController.text)
        .trim()
        .replaceAll(RegExp(r'\s+'), '');
    final pass = _normalizeNumbers(_passController.text).trim();

    if (userInput.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both credentials.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!DataStore.isInitialized) {
        await DataStore.initPrefs();
      }

      String cleanInput =
          userInput.startsWith('@') ? userInput.substring(1) : userInput;
      final email = cleanInput.contains('@')
          ? cleanInput.toLowerCase()
          : '$cleanInput@harakat.com'.toLowerCase();
      await AuthService().signIn(email, pass);

      // Success is handled by AuthWrapper stream
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $errorMsg'),
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

    return Scaffold(
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
                              errorBuilder: (_, __, ___) => Icon(Icons.school,
                                  size: 60, color: colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Image.asset(
                        'assets/images/app_name_arabic.png',
                        height: 110,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                          'حركات الحياة',
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF075E54)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Rooted in Values, Winged for the Future.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF075E54).withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.2,
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
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 40,
                            offset: const Offset(0, 20))
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _userController,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          textDirection: TextDirection.ltr,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\x20-\x7E]')),
                          ],
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Username',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                            prefixIcon: Icon(Icons.person_outline_rounded,
                                color: colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          textInputAction: TextInputAction.done,
                          textDirection: TextDirection.ltr,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\x20-\x7E]')),
                          ],
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                            prefixIcon: Icon(Icons.lock_outline_rounded,
                                color: colorScheme.primary),
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
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Sign In',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5)),
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
    );
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }
}
