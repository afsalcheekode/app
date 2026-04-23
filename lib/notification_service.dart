
import 'package:flutter/material.dart';

class NotificationService {
  static void showNotification({required String title, required String body}) {
    // Basic placeholder for now, could be integrated with flutter_local_notifications
    debugPrint('NOTIFICATION: $title - $body');
  }
}
