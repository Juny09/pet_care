import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloud_service.dart';

class UpdateService {
  /// 检查更新
  /// [context] 用于显示对话框
  /// [silent] 如果为 true，且无更新时，不显示提示（用于启动时自动检查）
  static Future<void> checkUpdate(BuildContext context, {bool silent = false}) async {
    if (!CloudService.isEnabled) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先开启云端服务以检查更新')),
        );
      }
      return;
    }

    try {
      // 1. 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 2. 获取最新版本
      // 假设 Supabase 中有一个 'app_versions' 表
      // 字段: id, version (text), download_url (text), force_update (bool), release_notes (text)
      final response = await Supabase.instance.client
          .from('app_versions')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        if (!silent) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到版本信息')),
          );
        }
        return;
      }

      final String latestVersion = response['version'];
      final String downloadUrl = response['download_url'] ?? '';
      final String releaseNotes = response['release_notes'] ?? '';
      final bool forceUpdate = response['force_update'] ?? false;

      // 3. 比较版本
      if (_compareVersions(latestVersion, currentVersion) > 0) {
        // 有新版本
        if (context.mounted) {
          _showUpdateDialog(
            context,
            latestVersion,
            releaseNotes,
            downloadUrl,
            forceUpdate,
          );
        }
      } else {
        // 已是最新
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前已是最新版本')),
          );
        }
      }
    } catch (e) {
      debugPrint('Update check error: $e');
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('检查更新失败，请稍后重试')),
        );
      }
    }
  }

  /// 简单的版本比较
  /// 返回 1: v1 > v2
  /// 返回 -1: v1 < v2
  /// 返回 0: v1 == v2
  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map(int.tryParse).toList();
    final v2Parts = v2.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final p1 = (i < v1Parts.length) ? (v1Parts[i] ?? 0) : 0;
      final p2 = (i < v2Parts.length) ? (v2Parts[i] ?? 0) : 0;

      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String notes,
    String url,
    bool force,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !force, // 强制更新不可关闭
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 $version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('更新内容：'),
            const SizedBox(height: 8),
            Text(notes, style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('暂不更新'),
            ),
          ElevatedButton(
            onPressed: () async {
              if (url.isNotEmpty) {
                final uri = Uri.parse(url);
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    // Fallback attempt
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('无法打开更新链接: $e')),
                    );
                  }
                }
              } else {
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('下载链接为空')),
                    );
                  }
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }
}
