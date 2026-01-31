import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart'; // Import for constants like kPrimaryColor

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // 当前版本号 - 每次发版记得更新这里
  static const String currentVersion = '1.0.2';

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      // 简单处理错误，实际项目可以使用 Toast
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于我们'),
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
          child: Column(
            children: [
              const SizedBox(height: 40),
              // App Logo
              Container(
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
              const SizedBox(height: 24),
              // App Name & Version
              const Text(
                '今日萌宠',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: kDarkText,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              const SizedBox(height: 40),
              // Introduction
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '「今日萌宠」是一款专为铲屎官打造的贴心助手。\n\n'
                  '我们致力于帮助你更轻松地记录毛孩子的日常生活，从喂食、喂药到洗澡、驱虫，每一个重要时刻都不错过。\n\n'
                  '新功能「成长日记」上线啦！快来记录爱宠的体重变化，见证TA的每一次成长。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: kDarkText.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const Spacer(),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _launchUrl('https://github.com/Juny09/pet_care/releases'),
                      icon: const Icon(Icons.system_update),
                      label: const Text('检查更新'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _launchUrl('https://github.com/Juny09/pet_care'),
                      icon: const Icon(Icons.code),
                      label: const Text('访问 GitHub 仓库'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kDarkText,
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(color: kDarkText.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Copyright
              Text(
                '© 2024 Pet Care App. All rights reserved.',
                style: TextStyle(
                  color: kDarkText.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
