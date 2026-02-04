import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// 📦 评论模型 (Comment Model)
// ---------------------------------------------------------------------------

class Comment {
  final String id;
  final String eventId;
  final String userId;
  final String content;
  final DateTime createdAt;
  
  // 关联字段 (View Model)
  final String? userDisplayName;
  final String? userEmail;

  Comment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.userDisplayName,
    this.userEmail,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      eventId: json['event_id'],
      userId: json['user_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      // 如果使用了联表查询，可能会有 profile 信息
      userDisplayName: json['profiles']?['display_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// ---------------------------------------------------------------------------
// 📦 用户资料模型 (Profile Model)
// ---------------------------------------------------------------------------

class UserProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
    };
  }
}
