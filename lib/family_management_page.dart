import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cloud_service.dart';
import 'main.dart'; // for kPrimaryColor

class FamilyManagementPage extends StatefulWidget {
  const FamilyManagementPage({super.key});

  @override
  State<FamilyManagementPage> createState() => _FamilyManagementPageState();
}

class _FamilyManagementPageState extends State<FamilyManagementPage> {
  List<Map<String, dynamic>> _households = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHouseholds();
  }

  Future<void> _loadHouseholds() async {
    setState(() => _isLoading = true);
    final list = await CloudService.getMyHouseholds();
    if (mounted) {
      setState(() {
        _households = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _createHousehold() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建新家庭'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '家庭名称',
            hintText: '例如：快乐一家人',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await CloudService.createHousehold(controller.text);
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadHouseholds();
                  }
                } catch (e) {
                  // handle error
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的家庭')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _households.length,
              itemBuilder: (context, index) {
                final h = _households[index];
                final isPersonal = h['is_personal'] == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPersonal ? Colors.blue[100] : kPastelYellow,
                      child: Icon(
                        isPersonal ? Icons.person : Icons.home,
                        color: kDarkText,
                      ),
                    ),
                    title: Text(h['name']),
                    subtitle: Text(isPersonal ? '仅自己可见' : 'ID: ${h['id']}'),
                    trailing: isPersonal
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HouseholdDetailPage(
                                    householdId: h['id'],
                                    householdName: h['name'],
                                    isOwner: h['role'] == 'owner',
                                  ),
                                ),
                              ).then((_) => _loadHouseholds());
                            },
                          ),
                    onTap: () {
                      // Return selected household info
                      Navigator.pop(context, {'id': h['id'], 'name': h['name']});
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createHousehold,
        child: const Icon(Icons.add),
        tooltip: '创建新家庭',
      ),
    );
  }
}

class HouseholdDetailPage extends StatefulWidget {
  final String householdId;
  final String householdName;
  final bool isOwner;

  const HouseholdDetailPage({
    super.key,
    required this.householdId,
    required this.householdName,
    required this.isOwner,
  });

  @override
  State<HouseholdDetailPage> createState() => _HouseholdDetailPageState();
}

class _HouseholdDetailPageState extends State<HouseholdDetailPage> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final list = await CloudService.getHouseholdMembers(widget.householdId);
    if (mounted) {
      setState(() {
        _members = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeMember(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认移除?'),
        content: const Text('移除后该成员将无法访问此家庭的数据。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CloudService.removeMember(widget.householdId, userId);
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.householdName)),
      body: Column(
        children: [
          // Header with Invite
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                const Text('家庭 ID (点击复制)', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.householdId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ID 已复制')),
                    );
                  },
                  child: Text(
                    widget.householdId,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.isOwner)
                  const Text('作为创建者，你可以管理成员。', style: TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final m = _members[index];
                      final isMe = m['user_id'] == CloudService.currentUserId;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(isMe ? '我' : '成员 ${m['user_id'].substring(0, 4)}...'),
                        subtitle: Text(m['role'] ?? 'member'),
                        trailing: (widget.isOwner && !isMe)
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _removeMember(m['user_id']),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          if (!widget.isOwner)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () async {
                   // Leave
                   await CloudService.leaveHousehold(widget.householdId);
                   if (mounted) Navigator.pop(context);
                },
                child: const Text('退出该家庭'),
              ),
            ),
        ],
      ),
    );
  }
}
