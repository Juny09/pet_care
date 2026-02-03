import 'dart:io'; // Add dart:io for Socket
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gmail_service.dart';
import 'main.dart'; // 为了使用 kPrimaryColor 等常量

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false; // 切换登录/注册模式
  bool _isPasswordVisible = false; // 控制密码可见性

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入邮箱和密码')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isRegistering) {
        // 注册
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('注册成功！请登录')));
          setState(() => _isRegistering = false);
        }
      } else {
        // 登录
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        // 登录成功会自动触发 main.dart 中的流监听，跳转首页
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message = e.message;
        if (message.contains('email rate limit exceeded')) {
          message = '邮件发送过于频繁，请稍后再试';
        } else if (message.contains('Invalid login credentials')) {
          message = '邮箱或密码错误';
        } else if (message.contains('User already registered')) {
          message = '该邮箱已被注册';
        } else if (message.contains('Error sending confirmation email')) {
          message = '发送验证邮件失败，请检查服务器配置或稍后再试';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = '发生错误，请稍后重试';
        final errStr = e.toString();
        if (errStr.contains('SocketException') ||
            errStr.contains('Failed host lookup')) {
          msg =
              '网络连接失败，请检查：\n1. 手机是否开启流量/WiFi\n2. 尝试关闭WiFi使用流量\n3. 检查是否禁止了App联网权限';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '知道了',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final emailController = TextEditingController();

    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入您的注册邮箱，我们将发送重置链接给您。'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, emailController.text.trim()),
            child: const Text('发送'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    try {
      // 如果是 Web 端，使用当前页面的 URL
      // 如果是 Mobile/Desktop，使用 Deep Link
      String? redirectTo;
      if (kIsWeb) {
        // 获取当前 URL 的 origin (e.g., http://localhost:8080)
        // 确保 Supabase 后台 Redirect URLs 包含此 URL
        redirectTo = Uri.base.origin;
      } else {
        redirectTo = 'io.supabase.petcare://login-callback/';
      }

      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重置链接已发送，请检查邮箱')));
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message = e.message;
        bool isRateLimit = false;

        if (message.contains('email rate limit exceeded') ||
            message.contains('429')) {
          message = '邮件发送过于频繁，是否切换到 Gmail 联系客服重置？';
          isRateLimit = true;
        } else if (message.contains('Invalid login credentials')) {
          message = '邮箱或密码错误';
        } else if (message.contains('User already registered')) {
          message = '该邮箱已被注册';
        } else if (message.contains('Error sending confirmation email')) {
          message = '发送验证邮件失败，请检查服务器配置或稍后再试';
        }

        if (isRateLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '去联系',
                onPressed: () {
                  GmailService.launchGmailFallback(email: email);
                },
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('发送失败，请稍后重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _runNetworkDiagnosis() async {
    setState(() => _isLoading = true);
    final sb = StringBuffer();
    sb.writeln('开始网络诊断...');

    try {
      // 1. Check Public Internet (Baidu/Google)
      sb.write('1. 连接互联网 (Baidu): ');
      try {
        final result = await InternetAddress.lookup('www.baidu.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          sb.writeln('成功 ✅ (${result[0].address})');
        } else {
          sb.writeln('失败 ❌ (DNS解析空)');
        }
      } catch (e) {
        sb.writeln('失败 ❌ ($e)');
      }

      // 2. Check Supabase
      sb.write('2. 连接服务器 (Supabase): ');
      try {
        // Parse host from URL
        // Access via internal configuration or hardcoded for diagnosis
        // SupabaseClient doesn't expose url directly in v2 public API easily without digging,
        // but we can try to access it via CloudService or just use the known constant.
        // Assuming CloudService has initialized it.
        const knownUrl = 'https://cgahmjsszehiwrdpfftp.supabase.co';
        final uri = Uri.parse(knownUrl);
        final result = await InternetAddress.lookup(uri.host);
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          sb.writeln('成功 ✅ (${result[0].address})');

          // Try TCP connect
          sb.write('   尝试建立连接... ');
          final socket = await Socket.connect(
            uri.host,
            443,
            timeout: const Duration(seconds: 5),
          );
          socket.destroy();
          sb.writeln('连接成功 ✅');
        } else {
          sb.writeln('失败 ❌ (DNS解析空)');
        }
      } catch (e) {
        sb.writeln('失败 ❌ ($e)');
      }
    } catch (e) {
      sb.writeln('诊断过程出错: $e');
    } finally {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('网络诊断报告'),
            content: SingleChildScrollView(child: Text(sb.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
              TextButton(
                onPressed: () {
                  // Copy to clipboard (optional)
                  Navigator.pop(ctx);
                },
                child: const Text('好的'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPastelCream,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 64, color: kPrimaryColor),
                const SizedBox(height: 16),
                Text(
                  _isRegistering ? '加入大家庭' : '欢迎回来',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kDarkText,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: '邮箱',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                ),
                if (!_isRegistering)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: Text(
                        '忘记密码？',
                        style: TextStyle(
                          color: kDarkText.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: _runNetworkDiagnosis,
                    icon: const Icon(
                      Icons.network_check,
                      size: 16,
                      color: Colors.grey,
                    ),
                    label: const Text(
                      '网络连接测试',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isRegistering ? '注 册' : '登 录',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                    });
                  },
                  child: Text(
                    _isRegistering ? '已有账号？去登录' : '没有账号？去注册',
                    style: TextStyle(color: kDarkText.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
