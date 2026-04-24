import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'common.dart';
import 'data_store.dart';
import 'notification_service.dart';
import 'login_screen.dart';
import 'auth_service.dart';

class AdminBoardScreen extends StatefulWidget {
  const AdminBoardScreen({super.key});

  @override
  State<AdminBoardScreen> createState() => _AdminBoardScreenState();
}

class _AdminBoardScreenState extends State<AdminBoardScreen> {
  // Use the global schools list
  List<Map<String, String>> get _schools => DataStore.allSchools;

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
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.account_circle, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
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
                  onPressed: () {
                    setState(() {
                      if (index != null) {
                        _schools[index] = {
                          'school': nameCtrl.text.trim(),
                          'academic_director': academicDirectorCtrl.text.trim(),
                          'username': userCtrl.text.trim().toLowerCase(),
                          'password': passCtrl.text.trim(),
                        };
                      } else {
                        _schools.add({
                          'school': nameCtrl.text.trim(),
                          'academic_director': academicDirectorCtrl.text.trim(),
                          'username': userCtrl.text.trim().toLowerCase(),
                          'password': passCtrl.text.trim(),
                        });
                      }
                      DataStore.saveAllData();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(index != null ? 'School updated successfully!' : 'School added successfully!')),
                    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
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
                                if (mounted) {
                                  Navigator.pop(context); // Close loading
                                  // Navigate to the dashboard
                                  Navigator.pushAndRemoveUntil(
                                    context, 
                                    MaterialPageRoute(builder: (_) => SchoolDashboardScreen(
                                      schoolName: school['school'] ?? 'School', 
                                      directorName: school['academic_director'] ?? 'Director',
                                      username: school['username']!,
                                    )),
                                    (route) => false
                                  );
                                }
                              } catch (e) {
                                if (mounted) Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Login failed: $e')),
                                );
                              }
                            },
                            child: Center(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                                  child: Icon(Icons.school_rounded, color: colorScheme.primary),
                                ),
                                title: Text(s['school'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  'Director: ${s['academic_director'] ?? 'Not Assigned'} | User: ${s['username']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
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
                                          if (mounted) {
                                            Navigator.pop(context); // Close loading
                                            Navigator.pushAndRemoveUntil(
                                              context, 
                                              MaterialPageRoute(builder: (_) => SchoolDashboardScreen(
                                                schoolName: s['school'] ?? 'School', 
                                                directorName: s['academic_director'] ?? 'Director',
                                                username: s['username']!,
                                              )),
                                              (route) => false
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
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
                                              TextButton(onPressed: () {
                                                setState(() => _schools.removeAt(index));
                                                DataStore.saveAllData();
                                                Navigator.pop(context);
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
                    'ADD NEW SCHOOL',
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
