import 'package:url_launcher/url_launcher.dart';

class GmailService {
  /// 当 Supabase 邮件发送失败时，调用此方法手动打开 Gmail 发送请求
  static Future<void> launchGmailFallback({
    required String email,
    String subject = 'Reset Password Request',
    String body = 'I am requesting a password reset for my account.',
  }) async {
    // 1. 尝试直接打开 Gmail App (Android/iOS)
    final Uri gmailUri = Uri(
      scheme: 'mailto',
      path: 'support@petcare.com', // 替换为你的客服邮箱
      query: _encodeQueryParameters({
        'subject': '$subject - $email',
        'body': 'My account email is: $email\n\nPlease help me reset my password.',
      }),
    );

    if (await canLaunchUrl(gmailUri)) {
      await launchUrl(gmailUri);
    } else {
      // 2. 如果无法打开邮件应用，尝试打开网页版 Gmail
      // 注意：无法直接预填内容到网页版 Gmail compose 页面，只能打开 Gmail 首页
      final Uri webGmailUri = Uri.parse('https://mail.google.com/');
      if (await canLaunchUrl(webGmailUri)) {
        await launchUrl(webGmailUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch Gmail');
      }
    }
  }

  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
