import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// 云端服务类 (封装 Supabase)
class CloudService {
  static const String kSupabaseUrlKey = 'supabase_url';
  static const String kSupabaseAnonKeyKey = 'supabase_key';
  static const String kUseCloudKey = 'use_cloud';

  static SupabaseClient? _client;
  static bool _isInitialized = false;

  /// 获取客户端实例
  static SupabaseClient? get client => _client;

  /// 是否启用云端
  static bool get isEnabled => _isInitialized && _client != null;

  /// 初始化
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(kSupabaseUrlKey);
    final key = prefs.getString(kSupabaseAnonKeyKey);
    final useCloud = prefs.getBool(kUseCloudKey) ?? false;

    if (useCloud &&
        url != null &&
        url.isNotEmpty &&
        key != null &&
        key.isNotEmpty) {
      try {
        await Supabase.initialize(url: url, anonKey: key);
        _client = Supabase.instance.client;
        _isInitialized = true;
        debugPrint('Supabase initialized successfully');
      } catch (e) {
        debugPrint('Supabase initialization failed: $e');
        _isInitialized = false;
        // 如果初始化失败，可能 key 错了，暂时降级为本地模式
      }
    }
  }

  /// 保存配置并重启
  static Future<void> saveConfig(String url, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSupabaseUrlKey, url.trim());
    await prefs.setString(kSupabaseAnonKeyKey, key.trim());
    await prefs.setBool(kUseCloudKey, true);
    // 注意：Supabase SDK 不支持热重载配置，通常需要重启 App 或重新初始化
    // 这里我们尝试重新初始化
    try {
      // 如果已经初始化过，dispose旧的? Supabase.instance.dispose() 暂无公开API
      // 简单处理：提示用户重启 App
    } catch (e) {
      debugPrint('Error saving config: $e');
    }
  }

  /// 关闭云端模式
  static Future<void> disableCloud() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kUseCloudKey, false);
    _isInitialized = false;
    _client = null;
  }
}

/// 云端设置页面
class CloudSettingsPage extends StatefulWidget {
  const CloudSettingsPage({super.key});

  @override
  State<CloudSettingsPage> createState() => _CloudSettingsPageState();
}

class _CloudSettingsPageState extends State<CloudSettingsPage> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _useCloud = false;

  // 从用户提供的连接字符串中提取的项目 ID
  static const String _defaultProjectId = 'cgahmjsszehiwrdpfftp';
  static const String _defaultUrl = 'https://$_defaultProjectId.supabase.co';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final savedUrl = prefs.getString(CloudService.kSupabaseUrlKey);
      _urlController.text = (savedUrl != null && savedUrl.isNotEmpty)
          ? savedUrl
          : _defaultUrl; // 自动填充推断出的 URL

      _keyController.text =
          prefs.getString(CloudService.kSupabaseAnonKeyKey) ?? '';
      _useCloud = prefs.getBool(CloudService.kUseCloudKey) ?? false;
    });
  }

  Future<void> _openSupabaseSettings() async {
    final Uri url = Uri.parse(
      'https://supabase.com/dashboard/project/$_defaultProjectId/settings/api',
    );
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开浏览器，请手动访问 Supabase 控制台')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_useCloud) {
      if (_urlController.text.isEmpty || _keyController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请填写完整的 URL 和 Key')));
        return;
      }
      await CloudService.saveConfig(_urlController.text, _keyController.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('配置已保存，请重启 App 以生效')));
      }
    } else {
      await CloudService.disableCloud();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已切换回本地模式，请重启 App')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('云端同步设置')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '开启云端同步后，你的数据将存储在 Supabase 云数据库中，实现多设备实时共享。',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('启用云端同步'),
            value: _useCloud,
            onChanged: (val) {
              setState(() {
                _useCloud = val;
              });
            },
          ),
          if (_useCloud) ...[
            const SizedBox(height: 24),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Supabase URL',
                hintText: 'https://xyz.supabase.co',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: 'Supabase Anon Key',
                hintText: 'eyJxh...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: '去获取 Key',
                  onPressed: _openSupabaseSettings,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openSupabaseSettings,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('点击这里去 Supabase 复制 Anon Key'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: const Text('保存并应用')),
            const SizedBox(height: 32),
            const Divider(),
            const Text(
              '如何获取配置？',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. 访问 supabase.com 并注册账号'),
            const Text('2. 创建一个新 Project'),
            const Text('3. 在 Project Settings -> API 中找到 URL 和 Anon Key'),
            const Text('4. 在 SQL Editor 中运行以下建表语句：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey[200],
              child: const SelectableText('''
-- 创建宠物表
create table public.pets (
  id text primary key,
  name text not null,
  type text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 创建事项表
create table public.events (
  id text primary key,
  pet_id text not null,
  type integer not null,
  date_time timestamp with time zone not null,
  note text,
  is_done boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 开启实时监听 (重要)
alter publication supabase_realtime add table pets;
alter publication supabase_realtime add table events;
              '''),
            ),
          ],
        ],
      ),
    );
  }
}
