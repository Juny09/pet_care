import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'cloud_service.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await CloudService.getActivityLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('活动日志 (Monitor)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('暂无活动记录'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final action = log['action'] ?? '未知操作';
                    final details = log['details'] ?? '';
                    final userEmail = log['user_email'] ?? '未知用户';
                    final timeStr = log['created_at'] != null
                        ? DateFormat('MM-dd HH:mm').format(
                            DateTime.parse(log['created_at']).toLocal())
                        : '';

                    IconData icon;
                    Color color;
                    if (action.contains('添加')) {
                      icon = Icons.add_circle_outline;
                      color = Colors.green;
                    } else if (action.contains('完成')) {
                      icon = Icons.check_circle_outline;
                      color = Colors.blue;
                    } else if (action.contains('删除')) {
                      icon = Icons.delete_outline;
                      color = Colors.red;
                    } else {
                      icon = Icons.info_outline;
                      color = Colors.grey;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(action),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (details.isNotEmpty) Text(details),
                          const SizedBox(height: 4),
                          Text(
                            '操作人: $userEmail  时间: $timeStr',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
