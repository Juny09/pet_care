import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud_service.dart';
import 'models.dart';
import 'main.dart';
import 'health_page.dart';
import 'growth_page.dart';
import 'about_page.dart';

// ---------------------------------------------------------------------------
// 📂 记录页面 (Records Page) - 聚合健康、成长等入口
// ---------------------------------------------------------------------------
class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRecordItem(
            context,
            icon: Icons.medical_services_outlined,
            color: Colors.redAccent,
            title: '健康提醒',
            subtitle: '疫苗、驱虫记录',
            onTap: () async {
              final pets = await StorageService.getPets();
              if (pets.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先添加宠物')));
                return;
              }
              // 默认选择第一个宠物，实际应该让用户选
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HealthPage(pet: pets.first)),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildRecordItem(
            context,
            icon: Icons.monitor_weight_rounded,
            color: Colors.blueAccent,
            title: '成长记录',
            subtitle: '体重、体型变化',
            onTap: () async {
              final pets = await StorageService.getPets();
              if (pets.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先添加宠物')));
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GrowthPage(pet: pets.first)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 👤 个人中心页面 (Profile Page)
// ---------------------------------------------------------------------------
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!CloudService.isEnabled) return;
    
    setState(() => _isLoading = true);
    try {
      final user = CloudService.client?.auth.currentUser;
      if (user == null) return;
      _userId = user.id;

      final data = await CloudService.client!
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _nameController.text = data['display_name'] ?? '';
      }
    } catch (e) {
      debugPrint('Load profile error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!CloudService.isEnabled || _userId == null) return;

    setState(() => _isLoading = true);
    try {
      final updates = {
        'id': _userId,
        'display_name': _nameController.text,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await CloudService.client!.from('profiles').upsert(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('个人资料已更新')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudService.isEnabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('请先登录以管理个人资料'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CloudSettingsPage()),
                  );
                },
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. 头像和基本信息
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(CloudService.currentUserEmail ?? '', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 2. 昵称设置
          const Text('昵称 (用于评论和家庭显示)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: '请输入你的昵称',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading ? const CircularProgressIndicator() : const Text('保存昵称'),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),

          // 3. 其他设置入口
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('云端同步设置'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CloudSettingsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知铃声设置'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: 实现通知铃声设置
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('即将上线：自定义铃声功能')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于应用'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
