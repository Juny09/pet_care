import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud_service.dart';
import 'main.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// 💬 事项详情页 (Event Detail Page) - 包含评论功能
// ---------------------------------------------------------------------------

class EventDetailPage extends StatefulWidget {
  final CareEvent event;
  final Function(CareEvent) onEventUpdated;

  const EventDetailPage({
    super.key,
    required this.event,
    required this.onEventUpdated,
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _subscribeToComments();
  }

  // 监听评论更新
  void _subscribeToComments() {
    if (!CloudService.isEnabled) return;
    
    CloudService.client!
        .channel('public:comments:${widget.event.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: widget.event.id,
          ),
          callback: (payload) {
            _loadComments();
          },
        )
        .subscribe();
  }

  Future<void> _loadComments() async {
    if (!CloudService.isEnabled) return;

    setState(() => _isLoadingComments = true);
    try {
      // 联表查询: comments + profiles
      final data = await CloudService.client!
          .from('comments')
          .select('*, profiles:user_id(display_name)')
          .eq('event_id', widget.event.id)
          .order('created_at', ascending: true);

      final List<dynamic> list = data;
      if (mounted) {
        setState(() {
          _comments = list.map((e) => Comment.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Load comments error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (!CloudService.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先开启云端服务以使用留言功能')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final user = CloudService.client!.auth.currentUser;
      if (user == null) return;

      final newComment = {
        'event_id': widget.event.id,
        'user_id': user.id,
        'content': _commentController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      await CloudService.client!.from('comments').insert(newComment);
      _commentController.clear();
      // 列表会通过 realtime 更新，或者我们可以手动刷新
      _loadComments(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('事项详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEventPage(
                    petId: widget.event.petId,
                    eventToEdit: widget.event,
                  ),
                ),
              );
              // 刷新数据需要通知上层，这里简化处理，直接返回
              // 实际应该重新加载 event
              Navigator.pop(context); 
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 事项详情卡片
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.event.type.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.event.type.icon, color: kDarkText, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event.type.label,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: kDarkText,
                            ),
                          ),
                          Text(
                            DateFormat('yyyy年MM月dd日 HH:mm').format(widget.event.dateTime),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.event.note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    width: double.infinity,
                    child: Text(
                      widget.event.note,
                      style: const TextStyle(fontSize: 16, color: kDarkText),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (widget.event.createdBy != null)
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '创建者: ${widget.event.createdBy!.split('@').first}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // 2. 评论列表区
          Expanded(
            child: Container(
              color: const Color(0xFFFAFAFA),
              child: _isLoadingComments
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('暂无留言，说点什么吧~', style: TextStyle(color: Colors.grey[400])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final isMe = comment.userId == CloudService.client?.auth.currentUser?.id;
                            
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? kPrimaryColor.withValues(alpha: 0.2) : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          comment.userDisplayName ?? '家人',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: kPrimaryColor.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      comment.content,
                                      style: const TextStyle(color: kDarkText),
                                    ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        DateFormat('MM-dd HH:mm').format(comment.createdAt),
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),

          // 3. 评论输入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: '写留言...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _isSending ? null : _sendComment,
                    icon: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: kPrimaryColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
