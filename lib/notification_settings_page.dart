import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  String _currentSound = 'default';
  bool _isLoading = true;

  final Map<String, String> _soundNames = {
    'default': '系统默认',
    'meow': '喵喵叫 (Meow)',
    'woof': '汪汪叫 (Woof)',
    'bell': '铃铛 (Bell)',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sound = await NotificationService.getCurrentSound();
    setState(() {
      _currentSound = sound;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings(String sound) async {
    await NotificationService.setSound(sound);
    setState(() {
      _currentSound = sound;
    });
    
    // Play a test notification (immediate) to preview sound? 
    // Actually, local_notifications doesn't have a "play sound" API, 
    // but we can schedule a notification 2 seconds later to test.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存。将在 2 秒后发送测试通知...')),
    );

    await NotificationService.scheduleNotification(
      id: 9999,
      title: '声音测试',
      body: '这就是 ${_soundNames[sound]} 的声音',
      scheduledTime: DateTime.now().add(const Duration(seconds: 2)),
      soundName: sound,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '提醒铃声',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...NotificationService.kAvailableSounds.map((sound) {
                  return RadioListTile<String>(
                    title: Text(_soundNames[sound] ?? sound),
                    value: sound,
                    groupValue: _currentSound,
                    onChanged: (value) {
                      if (value != null) {
                        _saveSettings(value);
                      }
                    },
                    secondary: const Icon(Icons.music_note),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '注意：自定义铃声需要在应用包内包含对应音频文件 (android/app/src/main/res/raw/xxx.mp3)。\n如果未听到声音，请检查文件是否存在或手机静音设置。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }
}
