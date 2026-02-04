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

  UserProfile({required this.id, this.displayName, this.avatarUrl});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'display_name': displayName, 'avatar_url': avatarUrl};
  }
}

// ---------------------------------------------------------------------------
// 📦 健康管理模型 (Health Models)
// ---------------------------------------------------------------------------

class WeightLog {
  final String id;
  final String petId;
  final double weight;
  final DateTime date;
  final String? note;

  WeightLog({
    required this.id,
    required this.petId,
    required this.weight,
    required this.date,
    this.note,
  });

  factory WeightLog.fromJson(Map<String, dynamic> json) {
    return WeightLog(
      id: json['id'],
      petId: json['pet_id'],
      weight: (json['weight'] as num).toDouble(),
      date: DateTime.parse(json['date']).toLocal(),
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'weight': weight,
      'date': date.toIso8601String(),
      'note': note,
    };
  }
}

class Vaccination {
  final String id;
  final String petId;
  final String vaccineName;
  final DateTime dateAdministered;
  final DateTime? nextDueDate;
  final String? vetName;
  final String? notes;

  Vaccination({
    required this.id,
    required this.petId,
    required this.vaccineName,
    required this.dateAdministered,
    this.nextDueDate,
    this.vetName,
    this.notes,
  });

  factory Vaccination.fromJson(Map<String, dynamic> json) {
    return Vaccination(
      id: json['id'],
      petId: json['pet_id'],
      vaccineName: json['vaccine_name'],
      dateAdministered: DateTime.parse(json['date_administered']).toLocal(),
      nextDueDate: json['next_due_date'] != null
          ? DateTime.parse(json['next_due_date']).toLocal()
          : null,
      vetName: json['vet_name'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'vaccine_name': vaccineName,
      'date_administered': dateAdministered.toIso8601String(),
      'next_due_date': nextDueDate?.toIso8601String(),
      'vet_name': vetName,
      'notes': notes,
    };
  }
}

class VetVisit {
  final String id;
  final String petId;
  final DateTime visitDate;
  final String? clinicName;
  final String? reason;
  final String? diagnosis;
  final String? prescription;
  final double? cost;
  final String? notes;

  VetVisit({
    required this.id,
    required this.petId,
    required this.visitDate,
    this.clinicName,
    this.reason,
    this.diagnosis,
    this.prescription,
    this.cost,
    this.notes,
  });

  factory VetVisit.fromJson(Map<String, dynamic> json) {
    return VetVisit(
      id: json['id'],
      petId: json['pet_id'],
      visitDate: DateTime.parse(json['visit_date']).toLocal(),
      clinicName: json['clinic_name'],
      reason: json['reason'],
      diagnosis: json['diagnosis'],
      prescription: json['prescription'],
      cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'visit_date': visitDate.toIso8601String(),
      'clinic_name': clinicName,
      'reason': reason,
      'diagnosis': diagnosis,
      'prescription': prescription,
      'cost': cost,
      'notes': notes,
    };
  }
}

// ---------------------------------------------------------------------------
// 📦 财务模型 (Finance Models)
// ---------------------------------------------------------------------------

class Expense {
  final String id;
  final String userId;
  final String? petId;
  final double amount;
  final String category;
  final DateTime date;
  final String? note;

  Expense({
    required this.id,
    required this.userId,
    this.petId,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      userId: json['user_id'],
      petId: json['pet_id'],
      amount: (json['amount'] as num).toDouble(),
      category: json['category'],
      date: DateTime.parse(json['date']).toLocal(),
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'pet_id': petId,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
    };
  }
}

// ---------------------------------------------------------------------------
// 📦 库存模型 (Inventory Models)
// ---------------------------------------------------------------------------

class InventoryItem {
  final String id;
  final String userId;
  final String itemName;
  final double quantity;
  final String? unit;
  final double? threshold;
  final DateTime updatedAt;

  InventoryItem({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.quantity,
    this.unit,
    this.threshold,
    required this.updatedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      userId: json['user_id'],
      itemName: json['item_name'],
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'],
      threshold: json['threshold'] != null
          ? (json['threshold'] as num).toDouble()
          : null,
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'threshold': threshold,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
