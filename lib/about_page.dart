import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart'; // Import for constants like kPrimaryColor

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const String currentVersion = '1.0.3';
  int _historyDays = 1; // 默认只显示今天 (1天)

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyDays = prefs.getInt('kCompletedHistoryDays') ?? 1;
    });
  }

  Future<void> _updateHistorySetting(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('kCompletedHistoryDays', days);
    setState(() {
      _historyDays = days;
    });
    // 通知首页刷新? 这里简单处理，用户返回首页时会重新加载数据 (如果是 push 进入的)
    // 或者我们可以使用 EventBus 或 Provider，但为了简单，我们在 Main.dart 的 onResume 或 loadData 中处理
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于与设置'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPastelCream, Colors.white],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 20),
              // App Logo
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 50,
                    color: kPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // App Name & Version
              const Center(
                child: Text(
                  '今日萌宠',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kDarkText,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Version $currentVersion',
                    style: TextStyle(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 设置部分
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kDarkText,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('已完成事项显示'),
                      subtitle: Text(
                          _historyDays == 1 ? '仅显示今天' : '保留最近 $_historyDays 天'),
                      trailing: DropdownButton<int>(
                        value: _historyDays,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('仅今天')),
                          DropdownMenuItem(value: 3, child: Text('最近3天')),
                          DropdownMenuItem(value: 7, child: Text('最近7天')),
                        ],
                        onChanged: (val) {
                          if (val != null) _updateHistorySetting(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              // Introduction
              const Text(
                '关于我们',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kDarkText,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '「今日萌宠」是一款专为铲屎官打造的贴心助手。\n\n'
                '我们致力于帮助你更轻松地记录毛孩子的日常生活，从喂食、喂药到洗澡、驱虫，每一个重要时刻都不错过。\n\n'
                '新功能「成长日记」上线啦！快来记录爱宠的体重变化，见证TA的每一次成长。',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: kDarkText,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
