import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class DataStore {
  static SharedPreferences? _prefs;
  static bool isInitialized = false;
  static bool hasFetchedFromFirestore = false;
  static Map<String, dynamic>? mockUser;
  static final _mockAuthStreamController =
      StreamController<Map<String, dynamic>?>.broadcast();
  static Stream<Map<String, dynamic>?> get mockAuthStream =>
      _mockAuthStreamController.stream;

  static void updateMockUser(Map<String, dynamic>? user) {
    debugPrint(
        "DataStore: Updating Mock User to -> ${user == null ? 'null' : user['username']}");
    mockUser = user;
    if (_prefs != null) {
      if (user != null) {
        _prefs!.setString('mock_user', jsonEncode(user));
      } else {
        _prefs!.remove('mock_user');
      }
    }
    _mockAuthStreamController.add(user);
  }

  // Static list to store all teachers, schools, and students (shared across app)
  static List<Map<String, String>> allTeachers = [];
  static List<Map<String, String>> allSchools = [
    {
      'school': 'Hayathul Islam',
      'username': 'hsh.dtcr',
      'password': '24395262',
      'academic_director': 'Hafiz Shafeeq Hashimi'
    }
  ];
  static List<Map<String, String>> allStudents = [];
  static List<Map<String, dynamic>> allExams = [];
  static List<Map<String, dynamic>> allMessages = [];
  static List<Map<String, dynamic>> allGroups = [];
  static List<Map<String, dynamic>> allGroupMembers = [];
  static List<Map<String, dynamic>> allActivities = [];
  static List<Map<String, dynamic>> allFairItems = [];
  static List<Map<String, dynamic>> allResults = [];
  static List<Map<String, dynamic>> allActivitySubmissions = [];
  static List<Map<String, dynamic>> allFairPayments = [];
  static List<Map<String, dynamic>> allAttendance = [];
  static List<Map<String, dynamic>> allHifzProgress = [];
  static Map<String, dynamic> allTimetables = {};
  static List<String> holidayDates = [];
  static List<Map<String, dynamic>> allMetrics = [];
  static List<Map<String, dynamic>> allBulletinCards = [];
  static List<String> allClasses = ['01', '02', '03', '04', '05'];
  static List<String> academicYears = ['2024-2025'];
  static String selectedAcademicYear = '2024-2025';
  static Map<String, bool> featureConfig = {
    'Students': true,
    'Activities': true,
    'F.transactions': true,
    'Schedule': true,
    'Results': true,
    'Messages': true,
    'Groups': true,
    'Attendance': true,
  };
  static Map<String, String> classDepts = {};

  static Future<void> saveInt(String key, int val) async =>
      await _prefs?.setInt(key, val);
  static int loadInt(String key, int def) => _prefs?.getInt(key) ?? def;
  static Future<void> saveString(String key, String val) async =>
      await _prefs?.setString(key, val);
  static String? loadString(String key) => _prefs?.getString(key);

  static int getUnreadMessageCount(String username) {
    if (allMessages.isEmpty) return 0;
    int totalForMe = allMessages.where((m) {
      final recipients = m['recipients'] as List?;
      return (m['receiverId'] == username ||
              recipients?.contains(username) == true) &&
          m['senderId'] != username;
    }).length;
    int lastSeen = loadInt('last_seen_msg_count_$username', 0);
    return max(0, totalForMe - lastSeen);
  }

  static void markMessagesAsRead(String username) async {
    int totalForMe = allMessages.where((m) {
      final recipients = m['recipients'] as List?;
      return (m['receiverId'] == username ||
              recipients?.contains(username) == true) &&
          m['senderId'] != username;
    }).length;
    await saveInt('last_seen_msg_count_$username', totalForMe);
  }

  static Map<String, int> _lastNotifiedMsgCount = {};

  static void checkForNewAndNotify(String username) {
    int currentCount = getUnreadMessageCount(username);
    int lastNotified = _lastNotifiedMsgCount[username] ?? 0;
    if (currentCount > lastNotified) {
      NotificationService.showNotification(
        title: 'New Message',
        body: 'You have $currentCount unread message(s)',
      );
    }
    _lastNotifiedMsgCount[username] = currentCount;
  }

  static Map<String, int> getAttendanceStats(
      String username, int? month, int? year) {
    int total = 0;
    int present = 0;
    for (var a in allAttendance) {
      if (a['studentUsername'] != username) continue;
      if (a['academicYear'] != selectedAcademicYear && year == null) continue;

      final date = DateTime.tryParse(a['date'] ?? '');
      if (date == null) continue;
      if (month != null && date.month != month) continue;
      if (year != null && date.year != year) continue;
      final periods = Map<String, String>.from(a['periods'] ?? {});
      if (periods.isNotEmpty) {
        total++;
        if (periods.values.contains('P')) present++;
      }
    }
    return {'total': total, 'present': present};
  }

  static Map<String, int> getAcademicYearStats(
      String username, String academicYear) {
    int total = 0;
    int present = 0;
    for (var a in allAttendance) {
      if (a['studentUsername'] == username &&
          a['academicYear'] == academicYear) {
        final periods = Map<String, String>.from(a['periods'] ?? {});
        if (periods.isNotEmpty) {
          total++;
          if (periods.values.contains('P')) present++;
        }
      }
    }
    return {'total': total, 'present': present};
  }

  static IconData getIconDataFromCodePoint(int codePoint) {
    const icons = {
      0xe54d: Icons.school,
      0xe0e1: Icons.badge,
      0xe23a: Icons.event,
      0xe211: Icons.emoji_events,
      0xe0a1: Icons.assignment,
      0xe491: Icons.people,
      0xe0ef: Icons.book,
      0xe5f9: Icons.star,
      0xe440: Icons.notifications,
      0xe060: Icons.analytics,
      0xe163: Icons.class_,
      0xe0bb: Icons.calendar_month,
    };
    return icons[codePoint] ?? Icons.help_outline;
  }

  static MaterialColor getColorFromValueActual(int value) {
    const colors = [
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.pink,
      Colors.teal,
      Colors.green
    ];
    for (var c in colors) {
      if (c.value == value) return c;
    }
    return Colors.teal;
  }

  static Future<void>? _initFuture;

  static Future<void> initPrefs() async {
    if (isInitialized) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _doInit();
    return _initFuture;
  }

  static Future<void> _doInit() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadAllData();
      isInitialized = true;

      // Global Purge V2: Clean Slate for hsh01 and others
      // if (_prefs!.getBool('global_purge_v2') != true) {
      // await _globalPurge();
      //  await _prefs!.setBool('global_purge_v2', true);
      // }

      // Start real-time Firestore sync
      startRealTimeSync();
      debugPrint("DataStore: Local data loaded, real-time sync started");

      // RECOVERY LOGIC: Restore vanished teachers and students from Auth/users collection
      FirebaseFirestore.instance.collection('users').get().then((snap) {
        bool changed = false;
        for (var doc in snap.docs) {
          final data = doc.data();
          if (data['role'] == 'teacher') {
             if (!allTeachers.any((t) => t['username'] == data['username'])) {
                final tMap = <String, String>{};
                data.forEach((k,v) => tMap[k] = v?.toString() ?? '');
                allTeachers.add(tMap);
                changed = true;
             }
          }
          if (data['role'] == 'student') {
             if (!allStudents.any((s) => s['username'] == data['username'])) {
                final sMap = <String, String>{};
                data.forEach((k,v) => sMap[k] = v?.toString() ?? '');
                allStudents.add(sMap);
                changed = true;
             }
          }
        }
        if (changed) {
          hasFetchedFromFirestore = true;
          saveAllData();
          debugPrint("DataStore: Recovered vanished users and synced to database.");
        }
      }).catchError((e) => debugPrint("Recovery error: $e"));

    } catch (e) {
      debugPrint("Error in initPrefs: $e");
    } finally {
      _initFuture = null;
    }
  }

  static void _loadAllData() {
    if (_prefs == null) return;

    final schoolsStr = _prefs!.getString('all_schools');
    if (schoolsStr != null) {
      try {
        final List decoded = jsonDecode(schoolsStr);
        // Even if empty, we should update it to reflect the saved state
        allSchools = decoded.map((s) => Map<String, String>.from(s)).toList();
      } catch (e) {
        debugPrint("Error decoding schools: $e");
      }
    }

    final teachersStr = _prefs!.getString('all_teachers');
    if (teachersStr != null) {
      final List decoded = jsonDecode(teachersStr);
      allTeachers = decoded.map((t) => Map<String, String>.from(t)).toList();
    }

    final studentsStr = _prefs!.getString('all_students');
    if (studentsStr != null) {
      final List decoded = jsonDecode(studentsStr);
      allStudents = decoded.map((s) => Map<String, String>.from(s)).toList();
    }

    // Cleanup: Remove legacy sample data if it exists in loaded data
    int tCount = allTeachers.length;
    int sCount = allStudents.length;
    allTeachers.removeWhere(
        (t) => t['name'] == 'Sample Teacher' || t['username'] == 'teacher');
    allStudents.removeWhere(
        (s) => s['name'] == 'Sample Student' || s['username'] == 'student');
    allSchools.removeWhere(
        (s) => s['username'] == 'hsh.director'); // Remove old username version

    if (allTeachers.length != tCount || allStudents.length != sCount) {
      debugPrint("DataStore: Legacy samples purged, syncing to Firestore...");
      // We'll call saveAllData later in _doInit once isInitialized is true
    }

    final examsStr = _prefs!.getString('all_exams');
    if (examsStr != null) {
      final List decoded = jsonDecode(examsStr);
      allExams = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    // Inject System Update Notification if not present
    bool exists =
        allExams.any((e) => e['title'] == 'System Enhancement Summary');
    if (!exists) {
      allExams.add({
        'type': 'Announcement',
        'title': 'System Enhancement Summary',
        'description':
            'Director Board updated with Broadcast system, quick-action shortcuts, and colorful announcement cards for all users. Check the sidebar for new commands.',
        'date':
            '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}',
        'day': 'Product Update',
        'time': 'NEW',
        'class': null,
        'academicYear': selectedAcademicYear,
      });
    }

    final messagesStr = _prefs!.getString('all_messages');
    if (messagesStr != null) {
      final List decoded = jsonDecode(messagesStr);
      allMessages = decoded.map((m) => Map<String, dynamic>.from(m)).toList();
    }

    final groupsStr = _prefs!.getString('all_groups');
    if (groupsStr != null) {
      final List decoded = jsonDecode(groupsStr);
      allGroups = decoded.map((g) => Map<String, dynamic>.from(g)).toList();
    }

    final gmStr = _prefs!.getString('all_group_members');
    if (gmStr != null) {
      final List decoded = jsonDecode(gmStr);
      allGroupMembers =
          decoded.map((g) => Map<String, dynamic>.from(g)).toList();
    }

    final activitiesStr = _prefs!.getString('all_activities');
    if (activitiesStr != null) {
      final List decoded = jsonDecode(activitiesStr);
      allActivities = decoded.map((a) => Map<String, dynamic>.from(a)).toList();
    }

    final fairStr = _prefs!.getString('all_fair_items');
    if (fairStr != null) {
      final List decoded = jsonDecode(fairStr);
      allFairItems = decoded.map((f) => Map<String, dynamic>.from(f)).toList();
    }

    final resStr = _prefs!.getString('all_results');
    if (resStr != null) {
      final List decoded = jsonDecode(resStr);
      allResults = decoded.map((r) => Map<String, dynamic>.from(r)).toList();
    }

    final subStr = _prefs!.getString('all_activity_submissions');
    if (subStr != null) {
      final List decoded = jsonDecode(subStr);
      allActivitySubmissions =
          decoded.map((s) => Map<String, dynamic>.from(s)).toList();
    }

    final payStr = _prefs!.getString('all_fair_payments');
    if (payStr != null) {
      final List decoded = jsonDecode(payStr);
      allFairPayments =
          decoded.map((p) => Map<String, dynamic>.from(p)).toList();
    }

    final attStr = _prefs!.getString('all_attendance');
    if (attStr != null) {
      final List decoded = jsonDecode(attStr);
      allAttendance = decoded.map((p) => Map<String, dynamic>.from(p)).toList();
    }

    final hifzStr = _prefs!.getString('all_hifz_progress');
    if (hifzStr != null) {
      final List decoded = jsonDecode(hifzStr);
      allHifzProgress =
          decoded.map((h) => Map<String, dynamic>.from(h)).toList();
    }

    final ttStr = _prefs!.getString('all_timetables');
    if (ttStr != null) {
      allTimetables = Map<String, dynamic>.from(jsonDecode(ttStr));
    }

    final holStr = _prefs!.getString('holiday_dates');
    if (holStr != null) {
      final List decoded = jsonDecode(holStr);
      holidayDates = decoded.map((h) => h.toString()).toList();
    }

    final ayStr = _prefs!.getString('academic_years');
    if (ayStr != null) {
      final List decoded = jsonDecode(ayStr);
      academicYears = decoded.map((a) => a.toString()).toList();
    }

    final curAyStr = _prefs!.getString('selected_academic_year');
    if (curAyStr != null) {
      selectedAcademicYear = curAyStr;
    }

    final classesStr = _prefs!.getString('all_classes');
    if (classesStr != null) {
      final List decoded = jsonDecode(classesStr);
      allClasses = decoded.map((c) => c.toString()).toList();
    }

    final deptsStr = _prefs!.getString('all_class_depts');
    if (deptsStr != null) {
      classDepts = Map<String, String>.from(jsonDecode(deptsStr));
    }
    // Migration: Ensure all classes have a department
    bool deptsChanged = false;
    for (var c in allClasses) {
      if (classDepts[c] == null) {
        classDepts[c] = 'DA\'WA'; // Default
        deptsChanged = true;
      }
    }
    if (deptsChanged) saveAllData();

    final metricsStr = _prefs!.getString('all_metrics');
    if (metricsStr != null) {
      final List decodedList = jsonDecode(metricsStr);
      allMetrics = decodedList.map((m) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(m);
        return data;
      }).toList();
    }

    final configStr = _prefs!.getString('feature_config');
    if (configStr != null) {
      final Map<String, dynamic> decoded = jsonDecode(configStr);
      featureConfig = Map<String, bool>.from(decoded);
    }

    final userStr = _prefs!.getString('mock_user');
    if (userStr != null) {
      mockUser = jsonDecode(userStr);
      _mockAuthStreamController.add(mockUser);
    }
  }

  static Future<void> saveAllData() async {
    if (_prefs == null) return;
    await _prefs!.setString('all_schools', jsonEncode(allSchools));
    await _prefs!.setString('all_teachers', jsonEncode(allTeachers));
    await _prefs!.setString('all_students', jsonEncode(allStudents));
    await _prefs!.setString('all_exams', jsonEncode(allExams));
    await _prefs!.setString('all_messages', jsonEncode(allMessages));
    await _prefs!.setString('all_groups', jsonEncode(allGroups));
    await _prefs!.setString('all_group_members', jsonEncode(allGroupMembers));
    await _prefs!.setString('all_activities', jsonEncode(allActivities));
    await _prefs!.setString('all_fair_items', jsonEncode(allFairItems));
    await _prefs!.setString('all_results', jsonEncode(allResults));
    await _prefs!.setString(
        'all_activity_submissions', jsonEncode(allActivitySubmissions));
    await _prefs!.setString('all_fair_payments', jsonEncode(allFairPayments));
    await _prefs!.setString('all_attendance', jsonEncode(allAttendance));
    await _prefs!.setString('all_hifz_progress', jsonEncode(allHifzProgress));
    await _prefs!.setString('all_timetables', jsonEncode(allTimetables));
    await _prefs!.setString('holiday_dates', jsonEncode(holidayDates));
    await _prefs!.setString('academic_years', jsonEncode(academicYears));
    await _prefs!.setString('selected_academic_year', selectedAcademicYear);
    await _prefs!.setString('all_classes', jsonEncode(allClasses));
    await _prefs!.setString('all_metrics', jsonEncode(allMetrics));
    await _prefs!.setString('feature_config', jsonEncode(featureConfig));
    await _prefs!.setString('all_class_depts', jsonEncode(classDepts));
    if (mockUser != null) {
      await _prefs!.setString('mock_user', jsonEncode(mockUser));
    } else {
      await _prefs!.remove('mock_user');
    }

    // Background push to Firestore
    syncWithFirestore(isPushOnly: true);
  }

  static Future<void> _globalPurge() async {
    debugPrint("DataStore: Performing GLOBAL PURGE...");
    allTeachers = [];
    allStudents = [];
    allExams = [];
    allMessages = [];
    allGroups = [];
    allGroupMembers = [];
    allActivities = [];
    allFairItems = [];
    allResults = [];
    allAttendance = [];
    allHifzProgress = [];
    allBulletinCards = [];
    allMetrics = [];

    // Keep only the primary director school
    allSchools = [
      {
        'school': 'Hayathul Islam',
        'username': 'hsh.dtcr',
        'password': '24395262',
        'academic_director': 'Hafiz Shafeeq Hashimi'
      }
    ];

    await saveAllData();
    debugPrint("DataStore: Global purge complete and synced.");
  }

  static StreamSubscription? _syncSubscription;
  static StreamSubscription? _photoSubscription;
  static void startRealTimeSync() {
    _syncSubscription?.cancel();
    _photoSubscription?.cancel();
    final db = FirebaseFirestore.instance;
    _syncSubscription = db
        .collection('app_data')
        .doc('central_store')
        .snapshots()
        .listen((doc) {
      hasFetchedFromFirestore = true;
      if (doc.exists) {
        final data = doc.data()!;
        bool changed = false;

        // Only update local lists if remote data exists to prevent wiping local on new setup
        if (data['allTeachers'] != null) {
          allTeachers = List<Map<String, String>>.from(
              (data['allTeachers'] as List)
                  .map((i) => Map<String, String>.from(i)));
          changed = true;
        }
        if (data['allStudents'] != null) {
          allStudents = List<Map<String, String>>.from(
              (data['allStudents'] as List)
                  .map((i) => Map<String, String>.from(i)));
          changed = true;
        }
        if (data['allSchools'] != null) {
          allSchools = List<Map<String, String>>.from(
              (data['allSchools'] as List)
                  .map((i) => Map<String, String>.from(i)));
          changed = true;
        }
        if (data['allExams'] != null) {
          allExams = List<Map<String, dynamic>>.from(data['allExams']);
          changed = true;
        }
        if (data['allMessages'] != null) {
          allMessages = List<Map<String, dynamic>>.from(data['allMessages']);
          changed = true;
        }
        if (data['allActivities'] != null) {
          allActivities =
              List<Map<String, dynamic>>.from(data['allActivities']);
          changed = true;
        }
        if (data['allFairItems'] != null) {
          allFairItems = List<Map<String, dynamic>>.from(data['allFairItems']);
          changed = true;
        }
        if (data['allResults'] != null) {
          allResults = List<Map<String, dynamic>>.from(data['allResults']);
          changed = true;
        }
        if (data['allActivitySubmissions'] != null) {
          allActivitySubmissions =
              List<Map<String, dynamic>>.from(data['allActivitySubmissions']);
          changed = true;
        }
        if (data['allFairPayments'] != null) {
          allFairPayments =
              List<Map<String, dynamic>>.from(data['allFairPayments']);
          changed = true;
        }
        if (data['allGroups'] != null) {
          allGroups = List<Map<String, dynamic>>.from(data['allGroups']);
          changed = true;
        }
        if (data['allGroupMembers'] != null) {
          allGroupMembers =
              List<Map<String, dynamic>>.from(data['allGroupMembers']);
          changed = true;
        }
        if (data['allAttendance'] != null) {
          allAttendance =
              List<Map<String, dynamic>>.from(data['allAttendance']);
          changed = true;
        }
        if (data['allHifzProgress'] != null) {
          allHifzProgress =
              List<Map<String, dynamic>>.from(data['allHifzProgress']);
          changed = true;
        }
        if (data['allClasses'] != null) {
          allClasses = List<String>.from(data['allClasses']);
          changed = true;
        }
        if (data['classDepts'] != null) {
          classDepts = Map<String, String>.from(data['classDepts']);
          changed = true;
        }
        if (data['allTimetables'] != null) {
          allTimetables = Map<String, dynamic>.from(data['allTimetables']);
          changed = true;
        }
        if (data['academicYears'] != null) {
          academicYears = List<String>.from(data['academicYears']);
          changed = true;
        }
        if (data['selectedAcademicYear'] != null) {
          selectedAcademicYear = data['selectedAcademicYear'];
          changed = true;
        }
        if (data['holidayDates'] != null) {
          holidayDates = List<String>.from(data['holidayDates']);
          changed = true;
        }
        if (data['allMetrics'] != null) {
          allMetrics = List<Map<String, dynamic>>.from(data['allMetrics']);
          changed = true;
        }
        if (data['allBulletinCards'] != null) {
          allBulletinCards =
              List<Map<String, dynamic>>.from(data['allBulletinCards']);
          changed = true;
        }
        if (data['featureConfig'] != null) {
          featureConfig = Map<String, bool>.from(data['featureConfig']);
          changed = true;
        }

        if (changed) {
          _saveLocallyOnly();
          _mockAuthStreamController.add(mockUser);
        }
      }
    });

    _photoSubscription = db.collection('teacher_photos').snapshots().listen((snapshot) {
      bool photoChanged = false;
      for (final doc in snapshot.docs) {
        final username = doc.data()['username'] as String? ?? '';
        final photo = doc.data()['photo'] as String? ?? '';
        final idx = allTeachers.indexWhere((t) => t['username'] == username);
        if (idx != -1 && allTeachers[idx]['photo'] != photo) {
          allTeachers[idx]['photo'] = photo;
          photoChanged = true;
        }
      }
      if (photoChanged) {
        _saveLocallyOnly();
        _mockAuthStreamController.add(mockUser);
      }
    });
  }

  static Future<void> syncWithFirestore({bool isPushOnly = false}) async {
    if (!hasFetchedFromFirestore) {
      debugPrint("DataStore: Skipping syncWithFirestore because data has not been fetched yet to prevent overwriting.");
      return;
    }
    try {
      final db = FirebaseFirestore.instance;

      // Strip photos from teachers for central_store to avoid 1MB limit
      final teachersNoPhoto = allTeachers.map((t) {
        final copy = Map<String, String>.from(t);
        copy.remove('photo');
        return copy;
      }).toList();

      // Push main data without photos
      await db.collection('app_data').doc('central_store').set({
        'allTeachers': teachersNoPhoto,
        'allStudents': allStudents,
        'allSchools': allSchools,
        'allExams': allExams,
        'allMessages': allMessages,
        'allActivities': allActivities,
        'allFairItems': allFairItems,
        'allResults': allResults,
        'allActivitySubmissions': allActivitySubmissions,
        'allFairPayments': allFairPayments,
        'allGroups': allGroups,
        'allGroupMembers': allGroupMembers,
        'allAttendance': allAttendance,
        'allHifzProgress': allHifzProgress,
        'allClasses': allClasses,
        'classDepts': classDepts,
        'allTimetables': allTimetables,
        'academicYears': academicYears,
        'selectedAcademicYear': selectedAcademicYear,
        'holidayDates': holidayDates,
        'allMetrics': allMetrics,
        'allBulletinCards': allBulletinCards,
        'featureConfig': featureConfig,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Push photos separately per teacher
      for (final t in allTeachers) {
        final username = t['username'] ?? '';
        final photo = t['photo'] ?? '';
        if (username.isNotEmpty) {
          await db.collection('teacher_photos').doc(username).set(
            {'photo': photo, 'username': username},
            SetOptions(merge: true),
          );
        }
      }
    } catch (e) {
      debugPrint("Firestore Sync Error: $e");
    }
  }

  static void _saveLocallyOnly() {
    if (_prefs == null) return;
    _prefs!.setString('all_schools', jsonEncode(allSchools));
    _prefs!.setString('all_teachers', jsonEncode(allTeachers));
    _prefs!.setString('all_students', jsonEncode(allStudents));
    _prefs!.setString('all_exams', jsonEncode(allExams));
    _prefs!.setString('all_messages', jsonEncode(allMessages));
    _prefs!.setString('all_groups', jsonEncode(allGroups));
    _prefs!.setString('all_group_members', jsonEncode(allGroupMembers));
    _prefs!.setString('all_activities', jsonEncode(allActivities));
    _prefs!.setString('all_fair_items', jsonEncode(allFairItems));
    _prefs!.setString('all_results', jsonEncode(allResults));
    _prefs!.setString(
        'all_activity_submissions', jsonEncode(allActivitySubmissions));
    _prefs!.setString('all_fair_payments', jsonEncode(allFairPayments));
    _prefs!.setString('all_attendance', jsonEncode(allAttendance));
    _prefs!.setString('all_hifz_progress', jsonEncode(allHifzProgress));
    _prefs!.setString('all_timetables', jsonEncode(allTimetables));
    _prefs!.setString('holiday_dates', jsonEncode(holidayDates));
    _prefs!.setString('academic_years', jsonEncode(academicYears));
    _prefs!.setString('selected_academic_year', selectedAcademicYear);
    _prefs!.setString('all_classes', jsonEncode(allClasses));
    _prefs!.setString('all_class_depts', jsonEncode(classDepts));
    _prefs!.setString('all_bulletin_cards', jsonEncode(allBulletinCards));
    _prefs!.setString('all_metrics', jsonEncode(allMetrics));
    _prefs!.setString('feature_config', jsonEncode(featureConfig));
  }
}
