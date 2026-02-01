import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloud_service.dart';
import 'notification_service.dart';
import 'login_page.dart';
import 'password_reset_page.dart';

import 'activity_log_page.dart';
import 'growth_page.dart';
import 'health_page.dart';
import 'about_page.dart';

// ---------------------------------------------------------------------------
// 🎨 配色方案 (Color Palette)
// ---------------------------------------------------------------------------
const Color kPastelYellow = Color(0xFFFFF9C4); // 浅黄
const Color kPastelPink = Color(0xFFFFCCBC); // 浅粉/橙
const Color kPastelGreen = Color(0xFFC8E6C9); // 浅绿
const Color kPastelBlue = Color(0xFFBBDEFB); // 浅蓝
const Color kPastelCream = Color(0xFFFFFDE7); // 米白 (背景)
const Color kDarkText = Color(0xFF5D4037); // 深褐 (文字)
const Color kPrimaryColor = Color(0xFFFFAB91); // 主色调 (深粉橙)

// ---------------------------------------------------------------------------
// 📦 数据模型 (Data Models)
// ---------------------------------------------------------------------------

/// 宠物模型
class Pet {
  final String id;
  final String name;
  final String type;
  final int? iconCodePoint; // 新增：自定义图标代码

  Pet({
    required this.id,
    required this.name,
    required this.type,
    this.iconCodePoint,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'iconCodePoint': iconCodePoint,
    };
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      iconCodePoint: json['iconCodePoint'],
    );
  }
}

/// 宠物类型定义
class PetTypeDefinition {
  final String label;
  final IconData icon;
  final Color color;

  const PetTypeDefinition(this.label, this.icon, this.color);
}

const List<PetTypeDefinition> kPetTypes = [
  PetTypeDefinition('狗狗', Icons.pets, kPastelYellow),
  PetTypeDefinition('猫咪', Icons.cruelty_free, kPastelPink),
  PetTypeDefinition('兔子', Icons.grass, kPastelGreen),
  PetTypeDefinition('仓鼠', Icons.home, kPastelBlue),
  PetTypeDefinition('鸟儿', Icons.flutter_dash, kPastelYellow),
  PetTypeDefinition('鱼儿', Icons.pool, kPastelBlue),
  PetTypeDefinition('其他', Icons.auto_awesome, kPastelGreen),
];

/// 事项类型枚举
enum EventType {
  food, // 喂食
  medicine, // 喂药
  bath, // 洗澡
  other, // 其他
}

/// 事项类型扩展：获取名称和图标
extension EventTypeExtension on EventType {
  String get label {
    switch (this) {
      case EventType.food:
        return '喂食';
      case EventType.medicine:
        return '喂药';
      case EventType.bath:
        return '洗澡';
      case EventType.other:
        return '其他';
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.food:
        return Icons.restaurant;
      case EventType.medicine:
        return Icons.medication;
      case EventType.bath:
        return Icons.bathtub;
      case EventType.other:
        return Icons.star;
    }
  }

  Color get color {
    switch (this) {
      case EventType.food:
        return kPastelYellow;
      case EventType.medicine:
        return kPastelPink;
      case EventType.bath:
        return kPastelBlue;
      case EventType.other:
        return kPastelGreen;
    }
  }
}

/// 护理事项模型
class CareEvent {
  final String id;
  final String petId;
  final EventType type;
  final DateTime dateTime;
  final String note;
  bool isDone;
  final String? createdBy; // 新增：记录创建者

  CareEvent({
    required this.id,
    required this.petId,
    required this.type,
    required this.dateTime,
    this.note = '',
    this.isDone = false,
    this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'type': type.index,
      'dateTime': dateTime.toIso8601String(),
      'note': note,
      'isDone': isDone,
      'createdBy': createdBy,
    };
  }

  factory CareEvent.fromJson(Map<String, dynamic> json) {
    return CareEvent(
      id: json['id'],
      petId: json['petId'] ?? '',
      type: EventType.values[json['type']],
      dateTime: DateTime.parse(json['dateTime']),
      note: json['note'] ?? '',
      isDone: json['isDone'] ?? false,
      createdBy: json['createdBy'],
    );
  }
}

/// 成长记录模型
class GrowthRecord {
  final String id;
  final String petId;
  final DateTime date;
  final double weight; // kg
  final String? photoPath;
  final String note;

  GrowthRecord({
    required this.id,
    required this.petId,
    required this.date,
    required this.weight,
    this.photoPath,
    this.note = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'date': date.toIso8601String(),
      'weight': weight,
      'photoPath': photoPath,
      'note': note,
    };
  }

  factory GrowthRecord.fromJson(Map<String, dynamic> json) {
    return GrowthRecord(
      id: json['id'],
      petId: json['petId'],
      date: DateTime.parse(json['date']),
      weight: (json['weight'] as num).toDouble(),
      photoPath: json['photoPath'],
      note: json['note'] ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// 🛠️ 数据服务 (Storage Service)
// ---------------------------------------------------------------------------

class StorageService {
  static const String kPetsKey = 'pets_list';
  static const String kEventsKey = 'care_events';
  static const String kGrowthKey = 'growth_records';

  // 旧数据 key (用于迁移)
  static const String kOldPetNameKey = 'pet_name';
  static const String kOldPetTypeKey = 'pet_type';

  /// 获取所有宠物
  static Future<List<Pet>> getPets() async {
    // 优先从云端获取
    if (CloudService.isEnabled) {
      try {
        final data = await CloudService.client!
            .from('pets')
            .select()
            .eq('family_id', CloudService.currentFamilyId) // 过滤家庭
            .order('created_at', ascending: true);
        final List<dynamic> list = data;
        return list.map((e) => Pet.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Cloud fetch error: $e');
        // Fallback to local? For now, return empty or handle error
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final String? petsString = prefs.getString(kPetsKey);

    if (petsString == null) {
      // 尝试从旧数据迁移
      final oldName = prefs.getString(kOldPetNameKey);
      final oldType = prefs.getString(kOldPetTypeKey);

      if (oldName != null && oldType != null) {
        final defaultPet = Pet(id: 'default_pet', name: oldName, type: oldType);
        await savePets([defaultPet]);
        return [defaultPet];
      }

      // 如果没有旧数据，创建一个默认宠物
      final defaultPet = Pet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '毛孩子',
        type: '狗狗',
      );
      await savePets([defaultPet]);
      return [defaultPet];
    }

    final List<dynamic> jsonList = jsonDecode(petsString);
    return jsonList.map((e) => Pet.fromJson(e)).toList();
  }

  /// 保存宠物列表
  static Future<void> savePets(List<Pet> pets) async {
    // 本地保存
    final prefs = await SharedPreferences.getInstance();
    final String petsString = jsonEncode(pets.map((e) => e.toJson()).toList());
    await prefs.setString(kPetsKey, petsString);

    // 云端同步
    if (CloudService.isEnabled) {
      try {
        // 全量同步策略：upsert
        for (var pet in pets) {
          final data = pet.toJson();
          // 临时移除 iconCodePoint，防止因数据库缺少该列导致报错
          // 待数据库添加 column "iconCodePoint" 后可移除此行
          data.remove('iconCodePoint');
          data['family_id'] = CloudService.currentFamilyId; // 关联到家庭
          await CloudService.client!.from('pets').upsert(data);
        }
        // 注意：删除操作需要单独处理，这里暂不处理删除同步的复杂逻辑
      } catch (e) {
        debugPrint('Cloud save error: $e');
      }
    }
  }

  /// 添加宠物
  static Future<void> addPet(Pet pet) async {
    final pets = await getPets();
    pets.add(pet);
    // 这里调用 savePets 会处理云端同步
    await savePets(pets);
  }

  /// 更新宠物
  static Future<void> updatePet(Pet updatedPet) async {
    final pets = await getPets();
    final index = pets.indexWhere((p) => p.id == updatedPet.id);
    if (index != -1) {
      pets[index] = updatedPet;
      await savePets(pets);
    }
  }

  /// 删除宠物
  static Future<void> deletePet(String petId) async {
    final pets = await getPets();
    pets.removeWhere((p) => p.id == petId);
    if (pets.isEmpty) {
      // 至少保留一个
      pets.add(
        Pet(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '毛孩子',
          type: '狗狗',
        ),
      );
    }
    await savePets(pets);

    // 云端删除
    if (CloudService.isEnabled) {
      try {
        await CloudService.client!.from('pets').delete().eq('id', petId);
      } catch (e) {
        debugPrint('Cloud delete error: $e');
      }
    }
  }

  /// 获取所有事项
  static Future<List<CareEvent>> getEvents() async {
    // 云端优先
    if (CloudService.isEnabled) {
      try {
        // 只获取最近30天的记录，避免数据量过大? 暂时全部获取
        final data = await CloudService.client!
            .from('events')
            .select()
            .eq('family_id', CloudService.currentFamilyId) // 过滤家庭
            .order('date_time', ascending: false);
        final List<dynamic> list = data;
        return list.map((e) {
          // Supabase 返回的 key 是下划线风格? 不，我们存的时候用的 toJson 是驼峰?
          // 修正：我们应该在 toJson/fromJson 处理风格，或者让 Supabase 存 JSONB
          // 但为了简单，我们让 Supabase 存普通字段。
          // 我们的 toJson: {'id': id, 'petId': petId ...}
          // Supabase 建表时字段名如果是 snake_case，我们需要映射。
          // 假设建表时用了 "pet_id", "date_time", "is_done"。

          // 简单起见，我们在 CloudService 建表 SQL 里用 snake_case，
          // 这里做映射。
          return CareEvent(
            id: e['id'],
            petId: e['pet_id'] ?? e['petId'] ?? '',
            type: EventType.values[e['type']],
            dateTime: DateTime.parse(e['date_time'] ?? e['dateTime']),
            note: e['note'] ?? '',
            isDone: e['is_done'] ?? e['isDone'] ?? false,
            createdBy: e['created_by'],
          );
        }).toList();
      } catch (e) {
        debugPrint('Cloud events fetch error: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final String? eventsString = prefs.getString(kEventsKey);
    if (eventsString == null) return [];

    final List<dynamic> jsonList = jsonDecode(eventsString);
    var events = jsonList.map((e) => CareEvent.fromJson(e)).toList();

    // 数据迁移
    final pets = await getPets();
    if (pets.isNotEmpty) {
      for (var event in events) {
        if (event.petId.isEmpty) {
          // compatible
        }
      }
    }

    return events;
  }

  /// 保存事项列表
  static Future<void> saveEvents(List<CareEvent> events) async {
    // 本地保存
    final prefs = await SharedPreferences.getInstance();
    final String eventsString = jsonEncode(
      events.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(kEventsKey, eventsString);
  }

  /// 添加新事项
  static Future<void> addEvent(CareEvent event) async {
    // 1. 本地保存
    final events = await getEvents(); // 注意：如果开启云端，这里拿到的是云端数据
    events.add(event);
    await saveEvents(events); // 本地存一份备份

    // 2. 云端保存
    if (CloudService.isEnabled) {
      try {
        // 映射字段到 snake_case
        final data = {
          'id': event.id,
          'pet_id': event.petId,
          'type': event.type.index,
          'date_time': event.dateTime.toIso8601String(),
          'note': event.note,
          'is_done': event.isDone,
          'created_by': event.createdBy,
          'family_id': CloudService.currentFamilyId, // 关联到家庭
        };
        await CloudService.client!.from('events').insert(data);

        // 记录日志
        await CloudService.logActivity(
          '添加事项',
          '添加了 ${event.type.label} (${DateFormat('MM-dd HH:mm').format(event.dateTime)})',
        );
      } catch (e) {
        debugPrint('Cloud add event error: $e');
      }
    }
  }

  /// 更新事项
  static Future<void> updateEvent(CareEvent updatedEvent) async {
    // 1. 本地
    final events = await getEvents();
    final index = events.indexWhere((e) => e.id == updatedEvent.id);
    if (index != -1) {
      events[index] = updatedEvent;
      await saveEvents(events);
    }

    // 2. 云端
    if (CloudService.isEnabled) {
      try {
        final data = {
          'id': updatedEvent.id,
          'pet_id': updatedEvent.petId,
          'type': updatedEvent.type.index,
          'date_time': updatedEvent.dateTime.toIso8601String(),
          'note': updatedEvent.note,
          'is_done': updatedEvent.isDone,
          // created_by 不更新
          'family_id': CloudService.currentFamilyId,
        };
        await CloudService.client!.from('events').upsert(data);

        // 记录日志 (如果只是 toggle)
        await CloudService.logActivity(
          updatedEvent.isDone ? '完成事项' : '更新事项',
          '更新了 ${updatedEvent.type.label}',
        );
      } catch (e) {
        debugPrint('Cloud update event error: $e');
      }
    }
  }

  /// 删除事项 (Public)
  static Future<void> deleteEvent(CareEvent event) async {
    // 1. 本地删除
    final events = await getEvents();
    events.removeWhere((e) => e.id == event.id);
    await saveEvents(events);

    // 2. 云端删除
    if (CloudService.isEnabled) {
      try {
        await CloudService.client!.from('events').delete().eq('id', event.id);

        // 尝试取消关联的通知
        final notificationId =
            int.tryParse(event.id.substring(event.id.length - 9)) ?? 0;
        await NotificationService.cancelNotification(notificationId);

        // 记录日志
        await CloudService.logActivity(
          '删除事项',
          '删除了 ${event.type.label} (${DateFormat('MM-dd HH:mm').format(event.dateTime)})',
        );
      } catch (e) {
        debugPrint('Cloud delete event error: $e');
      }
    }
  }

  // --- 成长记录 (Growth Records) ---

  /// 获取成长记录
  static Future<List<GrowthRecord>> getGrowthRecords(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? str = prefs.getString(kGrowthKey);
    if (str == null) return [];

    final List<dynamic> list = jsonDecode(str);
    final all = list.map((e) => GrowthRecord.fromJson(e)).toList();
    // 降序排列 (最新的在前面)
    return all.where((e) => e.petId == petId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 添加成长记录
  static Future<void> addGrowthRecord(GrowthRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final String? str = prefs.getString(kGrowthKey);
    List<GrowthRecord> all = [];
    if (str != null) {
      final List<dynamic> list = jsonDecode(str);
      all = list.map((e) => GrowthRecord.fromJson(e)).toList();
    }
    all.add(record);
    await prefs.setString(
      kGrowthKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  /// 删除成长记录
  static Future<void> deleteGrowthRecord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? str = prefs.getString(kGrowthKey);
    if (str == null) return;

    final List<dynamic> list = jsonDecode(str);
    List<GrowthRecord> all = list.map((e) => GrowthRecord.fromJson(e)).toList();
    all.removeWhere((e) => e.id == id);
    await prefs.setString(
      kGrowthKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  // --- 数据导出/导入功能 ---

  /// 导出所有数据为 JSON 字符串
  static Future<String> exportData() async {
    final pets = await getPets();
    final events = await getEvents();

    final Map<String, dynamic> data = {
      'pets': pets.map((p) => p.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    return jsonEncode(data);
  }

  /// 导入数据 (覆盖模式)
  static Future<void> importData(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (data.containsKey('pets')) {
        final List<dynamic> petsJson = data['pets'];
        final pets = petsJson.map((e) => Pet.fromJson(e)).toList();
        await savePets(pets);
      }

      if (data.containsKey('events')) {
        final List<dynamic> eventsJson = data['events'];
        final events = eventsJson.map((e) => CareEvent.fromJson(e)).toList();
        await saveEvents(events);
      }
    } catch (e) {
      throw Exception('数据格式错误，无法导入');
    }
  }
}

// ---------------------------------------------------------------------------
// 🚀 主入口 (Main Entry)
// ---------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init(); // 初始化通知
  await CloudService.init();
  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '今日萌宠',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          surface: kPastelCream,
          background: kPastelCream,
        ),
        scaffoldBackgroundColor: kPastelCream,
        fontFamily: null, // 使用默认字体，但在TextStyle中加粗增强可读性
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // 透明背景，配合渐变背景使用
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: kDarkText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: kDarkText),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shadowColor: kPrimaryColor.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        // 增强输入框样式
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// 认证包装器：根据云端配置和登录状态决定显示哪个页面
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showLogin = false;
  bool _showPasswordReset = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();

    // 监听 Auth 状态变化
    if (CloudService.isEnabled) {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          setState(() {
            _showPasswordReset = true;
          });
        } else {
          _checkAuth();
        }
      });
    }
  }

  void _checkAuth() {
    setState(() {
      if (!CloudService.isEnabled) {
        _showLogin = false; // 本地模式不需要登录
      } else {
        // 云端模式，检查是否有用户
        final user = Supabase.instance.client.auth.currentUser;
        _showLogin = user == null;
        if (user == null) {
          _showPasswordReset = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showPasswordReset) {
      return const PasswordResetPage();
    }
    if (_showLogin) {
      return const LoginPage();
    }
    return const HomePage();
  }
}

// ---------------------------------------------------------------------------
// 🏠 首页 (Home Page)
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Pet> _pets = [];
  String _currentPetId = '';
  List<CareEvent> _todayEvents = [];
  bool _expandCompleted = false; // 控制是否展开已完成事项

  @override
  void initState() {
    super.initState();
    _loadData();
    _initRealtimeSubscription();
  }

  void _initRealtimeSubscription() {
    if (CloudService.isEnabled) {
      // 监听事项表变更
      CloudService.client!
          .channel('public:events')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'events',
            callback: (payload) {
              debugPrint('Realtime update received: ${payload.toString()}');
              _loadData();
            },
          )
          .subscribe();

      // 监听宠物表变更
      CloudService.client!
          .channel('public:pets')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'pets',
            callback: (payload) {
              _loadData();
            },
          )
          .subscribe();

      // 监听活动日志变更
      CloudService.client!
          .channel('public:activity_logs')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'activity_logs',
            callback: (payload) {
              // 可以在这里加个红点提示，暂时只打印
              debugPrint('New activity log');
            },
          )
          .subscribe();
    }
  }

  /// 加载数据
  Future<void> _loadData() async {
    final pets = await StorageService.getPets();
    if (pets.isEmpty) return; // Should not happen due to StorageService logic

    // 确保有选中的宠物
    String currentId = _currentPetId;
    if (currentId.isEmpty || !pets.any((p) => p.id == currentId)) {
      currentId = pets.first.id;
    }

    final allEvents = await StorageService.getEvents();

    // 获取历史设置
    final prefs = await SharedPreferences.getInstance();
    final int historyDays = prefs.getInt('kCompletedHistoryDays') ?? 1;

    // 筛选事项 & 当前宠物
    final now = DateTime.now();
    // 计算历史截止日期 (今天 - historyDays + 1)
    // 比如 historyDays=1，截止日期就是今天0点
    // historyDays=3，截止日期就是前天0点
    final historyCutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: historyDays - 1));

    // 今日0点，用于区分"未完成"任务是否过期
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayEvents = allEvents.where((e) {
      // 兼容旧数据：如果 event.petId 为空，且当前是第一个宠物，也显示
      final isCurrentPet =
          e.petId == currentId ||
          (e.petId.isEmpty && currentId == pets.first.id);

      if (!isCurrentPet) return false;

      // 如果未完成：显示所有（包括过期未完成的）
      if (!e.isDone) return true;

      // 如果已完成：根据设置显示最近几天的
      // e.dateTime 必须 >= historyCutoff
      return e.dateTime.isAfter(historyCutoff) ||
          e.dateTime.isAtSameMomentAs(historyCutoff);
    }).toList();

    // 排序
    todayEvents.sort((a, b) {
      if (a.isDone != b.isDone) {
        return a.isDone ? 1 : -1; // 未完成在前
      }
      return a.dateTime.compareTo(b.dateTime);
    });

    if (mounted) {
      setState(() {
        _pets = pets;
        _currentPetId = currentId;
        _todayEvents = todayEvents;
      });
    }
  }

  /// 切换事项完成状态
  Future<void> _toggleEvent(CareEvent event) async {
    event.isDone = !event.isDone;
    await StorageService.updateEvent(event);
    _loadData();
  }

  Pet get _currentPet => _pets.firstWhere(
    (p) => p.id == _currentPetId,
    orElse: () => Pet(id: 'temp', name: '加载中...', type: ''),
  );

  /// 根据类型获取图标
  IconData _getPetIcon(Pet pet) {
    // 如果有自定义图标，优先使用
    if (pet.iconCodePoint != null) {
      return IconData(pet.iconCodePoint!, fontFamily: 'MaterialIcons');
    }
    // 否则使用默认类型映射
    final def = kPetTypes.firstWhere(
      (t) => t.label == pet.type,
      orElse: () => kPetTypes.last, // default to other
    );
    return def.icon;
  }

  /// 生成并分享今日日报文本
  void _shareDailySummary() {
    if (_todayEvents.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('今天还没有记录哦，快去记一笔吧！')));
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final buffer = StringBuffer();
    buffer.writeln('📅 $dateStr ${_currentPet.name}的日报');
    buffer.writeln('----------------');

    for (var event in _todayEvents) {
      final timeStr = DateFormat('HH:mm').format(event.dateTime);
      final status = event.isDone ? '✅' : '⬜';
      buffer.writeln('$status $timeStr ${event.type.label}');
      if (event.note.isNotEmpty) {
        buffer.writeln('   📝 ${event.note}');
      }
    }
    buffer.writeln('----------------');
    buffer.writeln('来自「今日萌宠」App 🐾');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('日报已复制到剪贴板，快去发给家人吧！')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('今日萌宠'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享今日日报',
            onPressed: _shareDailySummary,
          ),
          IconButton(
            icon: const Icon(Icons.medical_services_outlined),
            tooltip: '健康提醒',
            onPressed: () {
              if (_currentPetId.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HealthPage(pet: _currentPet),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.monitor_weight_rounded),
            tooltip: '成长记录',
            onPressed: () {
              if (_currentPetId.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GrowthPage(pet: _currentPet),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '活动日志',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActivityLogPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: '云端同步设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CloudSettingsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PetListPage()),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPastelCream, Colors.white],
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 110)),

                // 1. 今日概览卡片
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _buildSummaryCard(),
                  ),
                ),

                // 2. 宠物选择器
                SliverToBoxAdapter(child: _buildPetSelector()),

                // 3. 标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.checklist_rounded,
                          color: kPrimaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPet.name} 的待办',
                          style: const TextStyle(
                            color: kDarkText,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_todayEvents.where((e) => !e.isDone).length} 待完成',
                            style: const TextStyle(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. 列表
                if (_todayEvents.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final event = _todayEvents[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildEventCard(event),
                      );
                    }, childCount: _todayEvents.length),
                  ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_currentPetId.isEmpty) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEventPage(petId: _currentPetId),
            ),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final pendingCount = _todayEvents.where((e) => !e.isDone).length;
    final doneCount = _todayEvents.where((e) => e.isDone).length;
    final total = _todayEvents.length;
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryColor, Color(0xFFFFCCBC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                '早安，铲屎官！',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            pendingCount == 0 && total > 0
                ? '太棒了！今日任务全部完成 🎉'
                : '今天还有 $pendingCount 个任务等着你哦 💪',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.task_alt,
            size: 64,
            color: kPrimaryColor.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '今天还没有安排事项',
            style: TextStyle(
              color: kDarkText.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_currentPetId.isEmpty) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEventPage(petId: _currentPetId),
                ),
              );
              _loadData();
            },
            child: const Text('去添加'),
          ),
        ],
      ),
    );
  }

  /// 横向宠物选择器
  Widget _buildPetSelector() {
    return Container(
      height: 140, // 增加高度以容纳更大的卡片
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _pets.length + 1,
        itemBuilder: (context, index) {
          if (index == _pets.length) {
            // Add Button
            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PetEditPage()),
                );
                _loadData();
              },
              child: Container(
                width: 80,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: kDarkText.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: kDarkText, size: 32),
                    SizedBox(height: 4),
                    Text(
                      '添加',
                      style: TextStyle(color: kDarkText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          final pet = _pets[index];
          final isSelected = pet.id == _currentPetId;
          final icon = _getPetIcon(pet);

          return GestureDetector(
            onTap: () {
              setState(() {
                _currentPetId = pet.id;
              });
              _loadData();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 100 : 80,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? kPrimaryColor.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: isSelected ? 12 : 4,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isSelected
                    ? null
                    : Border.all(
                        color: kDarkText.withValues(alpha: 0.05),
                        width: 1,
                      ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : kPastelYellow.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: isSelected ? Colors.white : kDarkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : kDarkText,
                      fontSize: isSelected ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 删除事项
  Future<void> _deleteEvent(CareEvent event) async {
    // 1. 本地删除
    final events = await StorageService.getEvents();
    events.removeWhere((e) => e.id == event.id);
    await StorageService.saveEvents(events);

    // 2. 云端删除
    if (CloudService.isEnabled) {
      try {
        await CloudService.client!.from('events').delete().eq('id', event.id);

        // 记录日志
        await CloudService.logActivity(
          '删除事项',
          '删除了 ${event.type.label} (${DateFormat('MM-dd HH:mm').format(event.dateTime)})',
        );
      } catch (e) {
        debugPrint('Cloud delete event error: $e');
      }
    }

    _loadData();
  }

  /// 事项卡片
  Widget _buildEventCard(CareEvent event) {
    final isDone = event.isDone;

    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '删除',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除?'),
            content: const Text('删除后无法恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteEvent(event),
      child: GestureDetector(
        onLongPress: () async {
          // 长按显示删除菜单
          final result = await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(
              MediaQuery.of(context).size.width, // Right
              0, // Top (will be adjusted)
              0,
              0,
            ),
            items: [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
          if (result == 'delete') {
            // Confirm delete
            if (mounted) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认删除?'),
                  content: const Text('删除后无法恢复。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        '删除',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                _deleteEvent(event);
              }
            }
          } else if (result == 'edit') {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddEventPage(petId: event.petId, eventToEdit: event),
              ),
            );
            _loadData();
          }
        },
        onTap: () async {
          // 点击进入编辑页
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEventPage(
                petId: event.petId,
                eventToEdit: event, // 传入已有事件进行编辑
              ),
            ),
          );
          _loadData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDone ? Colors.white.withValues(alpha: 0.8) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDone
                ? []
                : [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: isDone
                ? Border.all(color: Colors.grey.withValues(alpha: 0.2))
                : null,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Color Bar
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: isDone ? Colors.grey[300] : event.type.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDone
                                ? Colors.grey[100]
                                : event.type.color.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            event.type.icon,
                            color: isDone ? Colors.grey : kDarkText,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                event.type.label,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDone ? Colors.grey : kDarkText,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('HH:mm').format(event.dateTime),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (event.note.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        event.note,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Checkbox
                        Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: isDone,
                            activeColor: kPrimaryColor,
                            shape: const CircleBorder(),
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                            onChanged: (val) => _toggleEvent(event),
                          ),
                        ),
                      ],
                    ),
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

// ---------------------------------------------------------------------------
// ➕ 新增事项页 (Add Event Page)
// ---------------------------------------------------------------------------

class AddEventPage extends StatefulWidget {
  final String petId;
  final CareEvent? eventToEdit; // 新增：用于编辑

  const AddEventPage({super.key, required this.petId, this.eventToEdit});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  EventType _selectedType = EventType.food;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _noteController = TextEditingController();
  bool _enableReminder = false;

  @override
  void initState() {
    super.initState();
    if (widget.eventToEdit != null) {
      // 初始化编辑数据
      final e = widget.eventToEdit!;
      _selectedType = e.type;
      _selectedDate = e.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(e.dateTime);
      _noteController.text = e.note;
      // 编辑时不自动开启提醒，或者根据业务逻辑决定
    }
  }

  Future<void> _saveEvent() async {
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (widget.eventToEdit != null) {
      // Update existing
      final updatedEvent = CareEvent(
        id: widget.eventToEdit!.id,
        petId: widget.petId,
        type: _selectedType,
        dateTime: dateTime,
        note: _noteController.text,
        isDone: widget.eventToEdit!.isDone,
        createdBy: widget.eventToEdit!.createdBy,
      );

      await StorageService.updateEvent(updatedEvent);

      // 更新提醒
      if (_enableReminder) {
        final notificationId =
            int.tryParse(
              widget.eventToEdit!.id.substring(
                widget.eventToEdit!.id.length - 9,
              ),
            ) ??
            0;
        await NotificationService.scheduleNotification(
          id: notificationId,
          title: '该给毛孩子${_selectedType.label}啦！',
          body: '时间到了：${DateFormat('HH:mm').format(dateTime)}',
          scheduledTime: dateTime,
        );
      }
    } else {
      // Create new
      final eventId = DateTime.now().millisecondsSinceEpoch.toString();
      final newEvent = CareEvent(
        id: eventId,
        petId: widget.petId,
        type: _selectedType,
        dateTime: dateTime,
        note: _noteController.text,
        createdBy: CloudService.currentUserEmail,
      );

      await StorageService.addEvent(newEvent);

      if (_enableReminder) {
        final notificationId =
            int.tryParse(eventId.substring(eventId.length - 9)) ?? 0;
        await NotificationService.scheduleNotification(
          id: notificationId,
          title: '该给毛孩子${_selectedType.label}啦！',
          body: '时间到了：${DateFormat('HH:mm').format(dateTime)}',
          scheduledTime: dateTime,
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.eventToEdit != null ? '编辑事项' : '记一笔')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 类型选择
                const Text(
                  '事项类型',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: EventType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? type.color : Colors.white,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: kDarkText, width: 2)
                                  : null,
                            ),
                            child: Icon(type.icon, size: 28, color: kDarkText),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: kDarkText,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // 2. 时间选择
                const Text(
                  '时间',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeButton(
                        icon: Icons.calendar_today,
                        text: DateFormat('MM月dd日').format(_selectedDate),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null)
                            setState(() => _selectedDate = date);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeButton(
                        icon: Icons.access_time,
                        text: _selectedTime.format(context),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (time != null)
                            setState(() => _selectedTime = time);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // 2.5 提醒开关
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '开启提醒',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_enableReminder ? '到时间会发送通知提醒你' : '不提醒'),
                  value: _enableReminder,
                  activeColor: kPrimaryColor,
                  onChanged: (val) {
                    setState(() {
                      _enableReminder = val;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 3. 备注
                const Text(
                  '备注 (可选)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText: '写点什么...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 48),

                // 4. 保存按钮
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '保 存',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: kDarkText.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🐾 宠物列表管理页 (Pet List Page)
// ---------------------------------------------------------------------------

class PetListPage extends StatefulWidget {
  const PetListPage({super.key});

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  List<Pet> _pets = [];

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final pets = await StorageService.getPets();
    setState(() {
      _pets = pets;
    });
  }

  Future<void> _deletePet(String id) async {
    await StorageService.deletePet(id);
    _loadPets();
  }

  IconData _getPetIcon(String type) {
    final def = kPetTypes.firstWhere(
      (t) => t.label == type,
      orElse: () => kPetTypes.last,
    );
    return def.icon;
  }

  // --- 数据导出/导入 UI ---

  Future<void> _checkUpdate() async {
    final url = Uri.parse('https://github.com/Juny09/pet_care/releases');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开更新页面')));
      }
    }
  }

  Future<void> _showExportDialog() async {
    final jsonStr = await StorageService.exportData();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备份数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请复制以下代码，发送给家人或保存到备忘录：'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              height: 150,
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
              Navigator.pop(ctx);
            },
            child: const Text('复制全部'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请粘贴备份代码（注意：这会覆盖当前所有数据）：'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '粘贴 {"pets":...}',
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (controller.text.isEmpty) return;
                await StorageService.importData(controller.text);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('数据恢复成功！')));
                  _loadPets(); // 刷新列表
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('数据格式错误，请检查')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认覆盖'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的毛孩子')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: _pets.length,
                  itemBuilder: (context, index) {
                    final pet = _pets[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: kPastelYellow,
                          child: Icon(_getPetIcon(pet.type), color: kDarkText),
                        ),
                        title: Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(pet.type),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: kDarkText),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PetEditPage(pet: pet),
                                  ),
                                );
                                _loadPets();
                              },
                            ),
                            if (_pets.length > 1) // 至少保留一个
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _showDeleteConfirm(pet.id),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 数据管理区域
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '更多功能',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              // 检查更新按钮 -> 改为 关于我们
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('关于我们'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showExportDialog,
                      icon: const Icon(Icons.upload),
                      label: const Text('备份/导出'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showImportDialog,
                      icon: const Icon(Icons.download),
                      label: const Text('恢复/导入'),
                    ),
                  ),
                ],
              ),
              // 如果已登录，显示退出登录
              if (CloudService.isEnabled &&
                  Supabase.instance.client.auth.currentUser != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (mounted) Navigator.pop(context); // 退出设置页
                  },
                  child: const Text(
                    '退出登录',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PetEditPage()),
          );
          _loadPets();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除?'),
        content: const Text('删除后该宠物的所有记录将无法找回（逻辑上暂未级联删除事件）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePet(id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ✏️ 宠物编辑页 (Pet Edit Page)
// ---------------------------------------------------------------------------

class PetEditPage extends StatefulWidget {
  final Pet? pet;
  const PetEditPage({super.key, this.pet});

  @override
  State<PetEditPage> createState() => _PetEditPageState();
}

class _PetEditPageState extends State<PetEditPage> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedType = kPetTypes.first.label;

  // 新增：自定义类型逻辑
  final TextEditingController _customTypeController = TextEditingController();
  int? _selectedIconCodePoint;

  bool get _isOtherType => _selectedType == '其他';

  @override
  void initState() {
    super.initState();
    if (widget.pet != null) {
      _nameController.text = widget.pet!.name;
      _selectedType = widget.pet!.type;
      _selectedIconCodePoint = widget.pet!.iconCodePoint;

      // 如果类型不在预定义列表中，说明是自定义类型
      final isPredefined = kPetTypes.any((t) => t.label == _selectedType);
      if (!isPredefined) {
        // 视为“其他”并填入自定义名称
        _customTypeController.text = _selectedType;
        _selectedType = '其他';
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;

    // 确定最终类型
    String finalType = _selectedType;
    if (_isOtherType && _customTypeController.text.isNotEmpty) {
      finalType = _customTypeController.text;
    }

    // 确定最终图标
    // 如果是预定义类型，且用户没有手动选图标(或者逻辑上我们强制预定义类型用默认图标)，
    // 但为了灵活性，我们允许用户修改。
    // 简单起见：如果是“其他”，必须选图标（或有默认）。
    // 如果是预定义，使用预定义图标（除非我们想做更复杂）。
    // 这里逻辑：如果不是其他，iconCodePoint 为 null (使用默认)。如果是其他，iconCodePoint 必须有值。
    int? finalIconCodePoint = _selectedIconCodePoint;
    if (!_isOtherType) {
      finalIconCodePoint = null; // 重置为默认
    } else if (finalIconCodePoint == null) {
      // 如果是其他但没选图标，给个默认星星
      finalIconCodePoint = Icons.star.codePoint;
    }

    if (widget.pet != null) {
      // Update
      final updatedPet = Pet(
        id: widget.pet!.id,
        name: _nameController.text,
        type: finalType,
        iconCodePoint: finalIconCodePoint,
      );
      await StorageService.updatePet(updatedPet);
    } else {
      // Add
      final newPet = Pet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        type: finalType,
        iconCodePoint: finalIconCodePoint,
      );
      await StorageService.addPet(newPet);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pet != null ? '编辑毛孩子' : '新毛孩子')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField('名字', _nameController),
              const SizedBox(height: 32),
              const Text(
                '类型',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildTypeSelector(),

              if (_isOtherType) ...[
                const SizedBox(height: 24),
                const Text(
                  '自定义类型',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customTypeController,
                  decoration: InputDecoration(
                    hintText: '例如：乌龟、鹦鹉...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '选择图标',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildIconGrid(),
              ],

              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('保 存', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: kPetTypes.map((typeDef) {
        final isSelected = _selectedType == typeDef.label;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedType = typeDef.label;
            // 如果切回普通类型，清除自定义状态
            if (typeDef.label != '其他') {
              _customTypeController.clear();
              _selectedIconCodePoint = null;
            } else {
              // 默认选中一个图标
              if (_selectedIconCodePoint == null) {
                _selectedIconCodePoint = Icons.auto_awesome.codePoint;
              }
            }
          }),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? typeDef.color : Colors.white,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: kDarkText, width: 2)
                      : null,
                ),
                child: Icon(typeDef.icon, size: 28, color: kDarkText),
              ),
              const SizedBox(height: 8),
              Text(
                typeDef.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: kDarkText,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 图标选择网格
  Widget _buildIconGrid() {
    final icons = [
      Icons.auto_awesome,
      Icons.star,
      Icons.favorite,
      Icons.pets,
      Icons.bug_report,
      Icons.emoji_nature,
      Icons.forest,
      Icons.grass,
      Icons.local_florist,
      Icons.wb_sunny,
      Icons.nightlight_round,
      Icons.water_drop,
      Icons.air,
      Icons.cookie,
      Icons.cake,
      Icons.sports_baseball,
      Icons.music_note,
      Icons.palette,
      Icons.flight,
      Icons.rocket_launch,
      Icons.diamond,
      Icons.spa,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: icons.map((icon) {
        final isSelected = _selectedIconCodePoint == icon.codePoint;
        return GestureDetector(
          onTap: () => setState(() => _selectedIconCodePoint = icon.codePoint),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? kPrimaryColor.withValues(alpha: 0.3)
                  : Colors.white,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: kPrimaryColor, width: 2)
                  : null,
            ),
            child: Icon(icon, color: kDarkText, size: 24),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
