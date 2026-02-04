import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    // 默认时区，这里简单处理，实际可获取本地时区
    // tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    // Fix for flutter_local_notifications 20.0.0
    // Use named parameters
    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  /// 调度通知
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? soundName, // 可选：自定义铃声文件名 (不含扩展名)
  }) async {
    // 如果时间已过，不再提醒
    if (scheduledTime.isBefore(DateTime.now())) return;

    // Android: 自定义声音需要放在 android/app/src/main/res/raw/ 下
    // 假设 soundName = 'meow'，则文件应为 res/raw/meow.mp3
    final androidSound = soundName != null
        ? RawResourceAndroidNotificationSound(soundName)
        : null;

    // iOS: 自定义声音放在 Resources 下
    final iosSound = soundName != null ? '$soundName.aiff' : null;

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          soundName != null ? 'pet_care_custom_$soundName' : 'pet_care_channel',
          'Pet Care Reminders',
          channelDescription: 'Reminders for pet care events',
          importance: Importance.max,
          priority: Priority.high,
          sound: androidSound,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(sound: iosSound),
        macOS: DarwinNotificationDetails(sound: iosSound),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// 取消通知
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
}
