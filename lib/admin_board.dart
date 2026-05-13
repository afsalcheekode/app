import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'common.dart';
import 'data_store.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'login_screen.dart';
import 'auth_service.dart';
import 'director_board.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBoardScreen extends StatefulWidget {
  const AdminBoardScreen({super.key});

  @override
  State<AdminBoardScreen> createState() => _AdminBoardScreenState();
}

class _AdminBoardScreenState extends State<AdminBoardScreen> {
  // Use the global schools list
  List<Map<String, String>> get _schools => DataStore.allSchools;

  void _showCredentials(String user, String pass) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Director Account Created âœ…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share these credentials with the Director:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _credRow('Username', user),
            const SizedBox(height: 8),
            _credRow('Password', pass),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('DONE')),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
          Expanded(child: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied!'), duration: const Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddSchoolSheet({int? index}) {
    final s = index != null ? _schools[index] : null;
    final nameCtrl = TextEditingController(text: s?['school'] ?? '');
    final academicDirectorCtrl = TextEditingController(text: s?['academic_director'] ?? '');
    final userCtrl = TextEditingController(text: s?['username'] ?? '');
    final passCtrl = TextEditingController(text: s?['password'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                index != null ? 'Edit School' : 'Add New School',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF075E54),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'School Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.school, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: academicDirectorCtrl,
                decoration: InputDecoration(
                  labelText: 'Academic Director Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userCtrl,
                decoration: InputDecoration(
                  labelText: 'Login Username (for logging in)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.account_circle, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                decoration: InputDecoration(
                  labelText: 'Login Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    final username = userCtrl.text.trim().toLowerCase();
                    final password = passCtrl.text.trim();
                    final schoolName = nameCtrl.text.trim();
                    final directorName = academicDirectorCtrl.text.trim();

                    if (username.isEmpty || password.isEmpty || schoolName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields.')),
                      );
                      return;
                    }

                    final oldUsername = s?['username'];
                    final oldPassword = s?['password'];

                    try {
                      final auth = AuthService();
                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                      
                      final Map<String, dynamic> userData = {
                        'role': 'director',
                        'schoolName': schoolName,
                        'academic_director': directorName,
                        'username': username,
                      };

                      if (index == null) {
                        // Create NEW director account
                        await auth.registerUser(userData, password);
                        
                        setState(() {
                          DataStore.allSchools.add({
                            'school': schoolName,
                            'academic_director': directorName,
                            'username': username,
                            'password': password,
                            'uid': userData['uid'] ?? '',
                          });
                          DataStore.saveAllData();
                        });
                      } else {
                        // Update EXISTING director account
                        if (oldUsername != null && oldPassword != null) {
                          // 1. Update password in Firebase Auth if changed
                          if (password != oldPassword) {
                            await auth.updateUserPassword(oldUsername, oldPassword, password);
                          }

                          // 2. Update Firestore metadata
                          final query = await FirebaseFirestore.instance.collection('users')
                              .where('username', isEqualTo: oldUsername)
                              .get();
                          
                          if (query.docs.isNotEmpty) {
                            await query.docs.first.reference.update(userData);
                          }
                        }

                        setState(() {
                          DataStore.allSchools[index] = {
                            'school': schoolName,
                            'academic_director': directorName,
                            'username': username,
                            'password': password,
                            'uid': s?['uid'] ?? '',
                          };
                          DataStore.saveAllData();
                        });
                      }
                      
                      Navigator.of(context, rootNavigator: true).pop(); // Pop loading
                      Navigator.of(context, rootNavigator: true).pop(); // Pop Add School dialog
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(index == null ? 'Director account created successfully!' : 'Director account updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        if (index == null) {
                          _showCredentials(username, password);
                        }
                      }
                    } catch (e) {
                      Navigator.of(context, rootNavigator: true).pop(); // Pop loading
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Operation failed: ${e.toString().replaceAll('Exception: ', '')}'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    index != null ? 'Update School' : 'Add School',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1000;
    final isTablet = width > 600 && width <= 1000;
    
    return FadeInEntrance(
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: colorScheme.primary,
          centerTitle: true,
          toolbarHeight: isDesktop ? 120 : 90,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(child: Image.asset('assets/images/app_logo_v2.png')),
            ),
          ),
          actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              AuthService().signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
        title: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'ADMIN',
              style: TextStyle(
                fontSize: isDesktop ? 80 : 64,
                fontWeight: FontWeight.w100,
                letterSpacing: 12,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Text(
              'Bridge',
              style: TextStyle(
                fontSize: isDesktop ? 40 : 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Let's simplify our curriculum\nand make learning fun!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 48 : 36,
                  fontWeight: FontWeight.w200,
                  height: 1.5,
                  color: colorScheme.primary.withOpacity(0.08),
                ),
              ),
            ),
          ),
          _schools.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 72, color: colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Bridge Admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 4,
                      width: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.secondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 100,
                    ),
                    itemCount: _schools.length,
                    itemBuilder: (context, index) {
                      final s = _schools[index];
                      return FadeInEntrance(
                        delay: index * 0.1,
                        child: Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.1),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              // Direct login shortcut for Admin
                              final auth = AuthService();
                              final school = _schools[index];
                              try {
                                showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                await auth.signIn(school['username']!, school['password']!);
                                Navigator.of(context, rootNavigator: true).pop(); // Close loading
                              } catch (e) {
                                Navigator.of(context, rootNavigator: true).pop(); // Close loading
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Login failed: $e')),
                                  );
                                }
                              }
                            },
                            child: Center(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: ClipOval(child: Image.asset('assets/images/app_logo_v2.png')),
                                ),
                                title: Text(s['school'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Director: ${s['academic_director'] ?? 'Not Assigned'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text('User: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        SelectableText(s['username'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Text('Pass: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        SelectableText(s['password'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.login_rounded, color: Colors.blue, size: 20),
                                      tooltip: 'Open Dashboard',
                                      onPressed: () async {
                                        final auth = AuthService();
                                        try {
                                          showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                          await auth.signIn(s['username']!, s['password']!);
                                          Navigator.of(context, rootNavigator: true).pop(); // Close loading
                                        } catch (e) {
                                          Navigator.of(context, rootNavigator: true).pop(); // Close loading
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.teal, size: 20), onPressed: () => _showAddSchoolSheet(index: index)),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete School'),
                                            content: Text('Are you sure you want to delete ${s['school']}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                              TextButton(onPressed: () async {
                                                try {
                                                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                                  
                                                  // 1. Delete from Firebase Auth and Firestore
                                                  await AuthService().deleteUser(s['username']!, s['password']!);
                                                  
                                                  // 2. Remove from local list
                                                  setState(() => _schools.removeAt(index));
                                                  DataStore.saveAllData();
                                                  
                                                  Navigator.of(context, rootNavigator: true).pop(); // Pop loading
                                                  Navigator.of(context, rootNavigator: true).pop(); // Pop confirmation dialog
                                                  
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Director account deleted successfully!'), backgroundColor: Colors.green),
                                                    );
                                                  }
                                                } catch (e) {
                                                  Navigator.of(context, rootNavigator: true).pop(); // Pop loading
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                                                    );
                                                  }
                                                }
                                              }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: InkWell(
          onTap: () => _showAddSchoolSheet(),
          child: Container(
            height: 75,
            margin: isDesktop ? const EdgeInsets.all(24) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isDesktop ? BorderRadius.circular(20) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.domain_add_rounded, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'DIRECTOR BOARD',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                      letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
}
}

// ==========================================
// SCHOOL DASHBOARD SCREEN
// ==========================================
