import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String kSoundPrefKey = 'notification_sound';

  // 预定义的铃声列表 (需要手动添加文件到 android/app/src/main/res/raw 和 ios/Runner/Resources)
  static const List<String> kAvailableSounds = [
    'default', // 系统默认
    'meow', // 喵喵叫
    'woof', // 汪汪叫
    'bell', // 铃铛
  ];

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

  /// 获取当前设置的铃声
  static Future<String> getCurrentSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kSoundPrefKey) ?? 'default';
  }

  /// 设置铃声
  static Future<void> setSound(String soundName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSoundPrefKey, soundName);
  }

  /// 调度通知
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? soundName, // 如果为 null，将使用用户设置的默认铃声
  }) async {
    // 如果时间已过，不再提醒
    if (scheduledTime.isBefore(DateTime.now())) return;

    // 获取铃声设置
    String currentSound = soundName ?? await getCurrentSound();
    if (currentSound == 'default') {
      currentSound = ''; // 空字符串表示使用系统默认
    }

    // Android: 自定义声音需要放在 android/app/src/main/res/raw/ 下
    // 假设 soundName = 'meow'，则文件应为 res/raw/meow.mp3
    final androidSound = currentSound.isNotEmpty
        ? RawResourceAndroidNotificationSound(currentSound)
        : null;

    // iOS: 自定义声音放在 Resources 下
    final iosSound = currentSound.isNotEmpty ? '$currentSound.aiff' : null;

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          currentSound.isNotEmpty
              ? 'pet_care_custom_$currentSound'
              : 'pet_care_channel',
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
