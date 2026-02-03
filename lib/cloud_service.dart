import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// 云端服务类 (封装 Supabase)
import 'main.dart'; // Import Pet model

class CloudService {
  static const String kSupabaseUrlKey = 'supabase_url';
  static const String kSupabaseAnonKeyKey = 'supabase_key';
  static const String kUseCloudKey = 'use_cloud';

  // 用户提供的默认配置
  static const String _defaultUrl = 'https://cgahmjsszehiwrdpfftp.supabase.co';
  static const String _defaultKey =
      'sb_publishable_t0xcgza-0tIY0G0eXwQluA_LAqEaqTw';

  static SupabaseClient? _client;
  static bool _isInitialized = false;

  /// 获取客户端实例
  static SupabaseClient? get client => _client;

  /// 是否启用云端
  static bool get isEnabled => _isInitialized && _client != null;

  /// 初始化
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 优先使用保存的配置，如果没有则使用默认配置
    String url = prefs.getString(kSupabaseUrlKey) ?? _defaultUrl;
    String key = prefs.getString(kSupabaseAnonKeyKey) ?? _defaultKey;

    // 默认开启云端 (如果用户没有显式关闭)
    final useCloud = prefs.getBool(kUseCloudKey) ?? true;

    if (useCloud && url.isNotEmpty && key.isNotEmpty) {
      try {
        await Supabase.initialize(url: url.trim(), anonKey: key.trim());
        _client = Supabase.instance.client;
        _isInitialized = true;
        debugPrint('Supabase initialized successfully');
      } catch (e) {
        debugPrint('Supabase initialization failed: $e');
        _isInitialized = false;
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

  /// 上传文件到 Supabase Storage
  static Future<String?> uploadFile(
    String bucketName,
    String path,
    Uint8List bytes, {
    String? contentType,
  }) async {
    if (!isEnabled) return null;
    try {
      await _client!.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final publicUrl = _client!.storage.from(bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Upload file error: $e');
      return null;
    }
  }

  // --- 家庭/群组与日志功能 ---

  /// 获取当前用户邮箱
  static String get currentUserEmail {
    return _client?.auth.currentUser?.email ?? '本地用户';
  }

  /// 获取当前用户的 ID
  static String get currentUserId {
    return _client?.auth.currentUser?.id ?? 'local';
  }

  // 家庭列表缓存
  static List<Map<String, dynamic>> _myHouseholds = [];

  /// 获取我的家庭列表
  static Future<List<Map<String, dynamic>>> getMyHouseholds() async {
    if (!isEnabled) return [];
    try {
      // 1. 获取我加入的家庭
      final response = await _client!
          .from('household_members')
          .select('household_id, households(id, name, owner_id), role')
          .eq('user_id', currentUserId);

      final List<Map<String, dynamic>> households = [];

      // 添加“个人空间” (默认)
      households.add({
        'id': currentUserId,
        'name': '个人空间',
        'role': 'owner',
        'is_personal': true,
      });

      for (var item in response) {
        if (item['households'] != null) {
          final h = item['households'];
          households.add({
            'id': h['id'],
            'name': h['name'],
            'owner_id': h['owner_id'],
            'role': item['role'],
            'is_personal': false,
          });
        }
      }

      _myHouseholds = households;
      return households;
    } catch (e) {
      debugPrint('Get households error: $e');
      return [];
    }
  }

  /// 创建新家庭
  static Future<void> createHousehold(String name) async {
    if (!isEnabled) return;
    try {
      // 1. Insert household
      final household = await _client!
          .from('households')
          .insert({'name': name, 'owner_id': currentUserId})
          .select()
          .single();

      // 2. Add self as member (owner)
      await _client!.from('household_members').insert({
        'household_id': household['id'],
        'user_id': currentUserId,
        'role': 'owner',
      });
    } catch (e) {
      debugPrint('Create household error: $e');
      rethrow;
    }
  }

  /// 获取家庭成员
  static Future<List<Map<String, dynamic>>> getHouseholdMembers(
    String householdId,
  ) async {
    if (!isEnabled) return [];
    // 如果是个人空间，只返回自己
    if (householdId == currentUserId) {
      return [
        {'email': currentUserEmail, 'role': 'owner', 'user_id': currentUserId},
      ];
    }

    try {
      // 需要联表查询 users 信息，但 Supabase auth.users 不可直接 public select
      // 通常做法：创建一个 public_profiles 表同步 auth.users，或者只显示 user_id
      // 简便做法：我们假设 household_members 表里没有 email。
      // 为了显示 email，我们可以用 RPC 或者 Edge Function，或者在 household_members 里存一个 email 快照 (不推荐但简单)
      // 或者：由于这是 MVP，我们只显示 user_id，或者让用户自己备注。
      // **更优解**：Supabase 允许读取 auth.users 吗？默认不行。
      // 变通：我们在 household_members 里存一个 `user_email` 字段 (冗余)。

      // 这里先尝试获取，如果只有 id 就显示 id
      final response = await _client!
          .from('household_members')
          .select()
          .eq('household_id', householdId);

      // 由于无法直接获取 email，我们这里只能返回基本信息
      // 实际生产中应该有 profiles 表
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Get members error: $e');
      return [];
    }
  }

  /// 邀请成员 (通过 ID)
  static Future<void> inviteMember(String householdId, String userId) async {
    // TODO: 实际上应该通过 Email 邀请，这里简化为直接通过 ID 添加 (如果知道 ID)
    // 或者创建一个邀请码系统
    throw UnimplementedError('需要实现邀请逻辑');
  }

  /// 移除成员
  static Future<void> removeMember(String householdId, String userId) async {
    if (!isEnabled) return;
    await _client!.from('household_members').delete().match({
      'household_id': householdId,
      'user_id': userId,
    });
  }

  /// 退出家庭
  static Future<void> leaveHousehold(String householdId) async {
    await removeMember(householdId, currentUserId);
  }

  /// 获取宠物列表 (支持家庭 ID)
  static Future<List<Pet>> getPets({String? householdId}) async {
    if (!isEnabled) return [];
    try {
      // 如果没有指定家庭，默认查询个人空间 (family_id = user_id)
      final targetFamilyId = householdId ?? currentUserId;

      final response = await _client!
          .from('pets')
          .select()
          .eq('family_id', targetFamilyId); // 只查询特定家庭的宠物

      return (response as List).map((e) => Pet.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Get pets error: $e');
      return [];
    }
  }

  /// 添加宠物 (支持家庭 ID)
  static Future<void> addPet(Pet pet, {String? householdId}) async {
    if (!isEnabled) return;
    try {
      final targetFamilyId = householdId ?? currentUserId;

      await _client!.from('pets').insert({
        ...pet.toJson(),
        'family_id': targetFamilyId, // 绑定到指定家庭
      });
    } catch (e) {
      debugPrint('Add pet error: $e');
      rethrow;
    }
  }

  /// 移动宠物到另一个家庭 (修改 family_id)
  static Future<void> movePet(String petId, String targetFamilyId) async {
    if (!isEnabled) return;
    await _client!
        .from('pets')
        .update({'family_id': targetFamilyId})
        .eq('id', petId);
  }

  /// 获取当前用户的 Family ID (这里简单使用 user_id，或者从 user_metadata 获取)
  /// *已废弃*: 请使用 `currentHouseholdId` 状态管理
  static String get currentFamilyId {
    // 兼容旧代码，默认返回 user_id (个人空间)
    // 实际 UI 应该从 Provider/State 获取当前选中的 householdId
    return currentUserId;
  }

  /// 加入家庭 (设置 family_id)
  /// *已废弃*: 旧逻辑是直接改 metadata，新逻辑是往 household_members 插数据
  static Future<void> joinFamily(String familyId) async {
    if (_client == null) return;
    try {
      // 尝试往 household_members 插入自己
      // 注意：这需要 RLS 允许 (我们在 HOUSEHOLDS.sql 里允许了)
      await _client!.from('household_members').insert({
        'household_id': familyId,
        'user_id': currentUserId,
        'role': 'member',
      });
      debugPrint('Joined family: $familyId');
    } catch (e) {
      debugPrint('Join family error: $e');
      rethrow;
    }
  }

  /// 记录活动日志
  static Future<void> logActivity(String action, String details) async {
    if (!isEnabled) return;
    try {
      await _client!.from('activity_logs').insert({
        'user_id': _client!.auth.currentUser!.id,
        'user_email': currentUserEmail,
        'family_id': currentFamilyId,
        'action': action,
        'details': details,
      });
    } catch (e) {
      debugPrint('Log activity error: $e');
      // 日志记录失败不应阻断主流程，吞掉错误
    }
  }

  /// 获取活动日志
  static Future<List<Map<String, dynamic>>> getActivityLogs() async {
    if (!isEnabled) return [];
    try {
      final response = await _client!
          .from('activity_logs')
          .select()
          .eq('family_id', currentFamilyId) // 只看当前家庭的日志
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Get logs error: $e');
      return [];
    }
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
  final _familyIdController = TextEditingController(); // 加入家庭输入框
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

  Future<void> _joinFamily() async {
    if (_familyIdController.text.isEmpty) return;
    try {
      await CloudService.joinFamily(_familyIdController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('成功加入家庭组！请重启 App 刷新数据')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加入失败: $e')));
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
            if (CloudService.isEnabled &&
                CloudService.client?.auth.currentUser != null) ...[
              const Text(
                '家庭共享 (Family Sharing)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('我的家庭 ID: ${CloudService.currentFamilyId}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: CloudService.currentFamilyId),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID 已复制，发给家人即可邀请加入')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制我的家庭 ID'),
              ),
              const SizedBox(height: 16),
              const Text('加入别人的家庭:'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _familyIdController,
                      decoration: const InputDecoration(
                        hintText: '输入对方的家庭 ID',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _joinFamily,
                    child: const Text('加入'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(),
            ],
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
