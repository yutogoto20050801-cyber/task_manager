import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'database_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await notifications.initialize(settings);

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin =
        notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> scheduleTaskNotification(
    Map<String, dynamic> task,
  ) async {
    if (task['isDone'] == 1) return;
    // If the task has explicit reminders, schedule those instead.
    try {
      final reminders = await DatabaseHelper.instance.getRemindersForTask(task['id']);
      if (reminders.isNotEmpty) {
        await scheduleRemindersForTask(task);
        return;
      }
    } catch (_) {}

    final deadline = DateFormat('yyyy-MM-dd HH:mm').parse(task['deadline']);

    final daysBefore = task['notificationDaysBefore'] ?? 1;

    if (daysBefore == -1) return;

    final notifyDateTime = deadline.subtract(Duration(days: daysBefore));

    if (notifyDateTime.isBefore(DateTime.now())) return;

    await notifications.zonedSchedule(
      task['notificationId'],
      '締め切りが近いよ',
      '${task['title']} の締め切りは明日だよ',
      tz.TZDateTime.from(notifyDateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel',
          'Task Notification',
          channelDescription: '課題の締め切り通知',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleRemindersForTask(
    Map<String, dynamic> task,
  ) async {
    if (task['isDone'] == 1) return;

    final deadline = DateFormat('yyyy-MM-dd HH:mm').parse(task['deadline']);

    final reminders = await DatabaseHelper.instance.getRemindersForTask(task['id']);

    for (var rem in reminders) {
      if ((rem['enabled'] ?? 1) != 1) continue;

      int daysBefore = rem['daysBefore'] ?? 1;

      DateTime notifyDate = deadline.subtract(Duration(days: daysBefore));

      // If time specified as "HH:mm", apply it.
      if (rem['time'] != null && rem['time'].toString().contains(':')) {
        try {
          final parts = rem['time'].toString().split(':');
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          notifyDate = DateTime(notifyDate.year, notifyDate.month, notifyDate.day, h, m);
        } catch (_) {}
      } else {
        // default time 09:00
        notifyDate = DateTime(notifyDate.year, notifyDate.month, notifyDate.day, 9, 0);
      }

      if (notifyDate.isBefore(DateTime.now())) continue;

      int nid = rem['notificationId'] ?? (task['id'] * 1000 + (rem['id'] ?? DateTime.now().millisecondsSinceEpoch % 1000));

      // Persist generated notificationId if missing
      if (rem['notificationId'] == null) {
        final updated = Map<String, dynamic>.from(rem);
        updated['notificationId'] = nid;
        await DatabaseHelper.instance.updateReminder(updated);
      }

      await notifications.zonedSchedule(
        nid,
        '締め切りが近いよ',
        '${task['title']} の締め切りは${daysBefore}日前です',
        tz.TZDateTime.from(notifyDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Notification',
            channelDescription: '課題の締め切り通知',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelRemindersForTask(
    Map<String, dynamic> task,
  ) async {
    final reminders = await DatabaseHelper.instance.getRemindersForTask(task['id']);
    for (var rem in reminders) {
      if (rem['notificationId'] != null) {
        try {
          await notifications.cancel(rem['notificationId']);
        } catch (_) {}
      }
    }
  }

  static Future<void> cancelTaskNotification(
    Map<String, dynamic> task,
  ) async {
    await notifications.cancel(task['notificationId']);
  }
}