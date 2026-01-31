import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
  final EventType type;
  final DateTime dateTime;
  final String note;
  bool isDone;

  CareEvent({
    required this.id,
    required this.type,
    required this.dateTime,
    this.note = '',
    this.isDone = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'dateTime': dateTime.toIso8601String(),
      'note': note,
      'isDone': isDone,
    };
  }

  factory CareEvent.fromJson(Map<String, dynamic> json) {
    return CareEvent(
      id: json['id'],
      type: EventType.values[json['type']],
      dateTime: DateTime.parse(json['dateTime']),
      note: json['note'] ?? '',
      isDone: json['isDone'] ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// 🛠️ 数据服务 (Storage Service)
// ---------------------------------------------------------------------------

class StorageService {
  static const String kPetNameKey = 'pet_name';
  static const String kPetTypeKey = 'pet_type';
  static const String kEventsKey = 'care_events';

  /// 获取宠物名字
  static Future<String> getPetName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kPetNameKey) ?? '毛孩子';
  }

  /// 保存宠物名字
  static Future<void> savePetName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPetNameKey, name);
  }

  /// 获取宠物类型 (简单的字符串)
  static Future<String> getPetType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kPetTypeKey) ?? '狗狗';
  }

  /// 保存宠物类型
  static Future<void> savePetType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPetTypeKey, type);
  }

  /// 获取所有事项
  static Future<List<CareEvent>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? eventsString = prefs.getString(kEventsKey);
    if (eventsString == null) return [];

    final List<dynamic> jsonList = jsonDecode(eventsString);
    return jsonList.map((e) => CareEvent.fromJson(e)).toList();
  }

  /// 保存事项列表
  static Future<void> saveEvents(List<CareEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final String eventsString = jsonEncode(
      events.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(kEventsKey, eventsString);
  }

  /// 添加新事项
  static Future<void> addEvent(CareEvent event) async {
    final events = await getEvents();
    events.add(event);
    await saveEvents(events);
  }

  /// 更新事项 (例如切换完成状态)
  static Future<void> updateEvent(CareEvent updatedEvent) async {
    final events = await getEvents();
    final index = events.indexWhere((e) => e.id == updatedEvent.id);
    if (index != -1) {
      events[index] = updatedEvent;
      await saveEvents(events);
    }
  }
}

// ---------------------------------------------------------------------------
// 🚀 主入口 (Main Entry)
// ---------------------------------------------------------------------------

void main() {
  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          surface: kPastelCream, // Updated from background to surface
          // surface: Colors.white, // Removed conflicting surface
        ),
        scaffoldBackgroundColor: kPastelCream,
        fontFamily: null, // 使用系统默认字体，避免网络请求
        appBarTheme: const AppBarTheme(
          backgroundColor: kPastelCream,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: kDarkText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: kDarkText),
        ),
        // Updated to CardThemeData based on analyzer feedback
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const HomePage(),
    );
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
  String _petName = '...';
  String _petType = '...';
  List<CareEvent> _todayEvents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载数据：宠物信息 + 今日事项
  Future<void> _loadData() async {
    final name = await StorageService.getPetName();
    final type = await StorageService.getPetType();
    final allEvents = await StorageService.getEvents();

    // 筛选今日事项
    final now = DateTime.now();
    final todayEvents = allEvents.where((e) {
      return e.dateTime.year == now.year &&
          e.dateTime.month == now.month &&
          e.dateTime.day == now.day;
    }).toList();

    // 排序：未完成在前，然后按时间排序
    todayEvents.sort((a, b) {
      if (a.isDone != b.isDone) {
        return a.isDone ? 1 : -1; // 未完成在前
      }
      return a.dateTime.compareTo(b.dateTime);
    });

    if (mounted) {
      setState(() {
        _petName = name;
        _petType = type;
        _todayEvents = todayEvents;
      });
    }
  }

  /// 切换事项完成状态
  Future<void> _toggleEvent(CareEvent event) async {
    event.isDone = !event.isDone;
    await StorageService.updateEvent(event);
    _loadData(); // 重新加载以更新排序
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800), // 桌面端最大宽度限制
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('今日萌宠'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                      _loadData(); // 设置页返回后刷新
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _buildPetHeader()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '今日待办 (${_todayEvents.where((e) => !e.isDone).length})',
                    style: const TextStyle(
                      color: kDarkText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final event = _todayEvents[index];
                  return _buildEventCard(event);
                }, childCount: _todayEvents.length),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEventPage()),
          );
          _loadData(); // 添加页返回后刷新
        },
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  /// 宠物信息卡片
  Widget _buildPetHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), // Updated withValues
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kPastelYellow,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _petType.contains('猫')
                  ? Icons.pets
                  : Icons.cruelty_free, // 简单区分图标
              size: 40,
              color: kDarkText,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _petName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kDarkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_petType宝宝',
                style: TextStyle(
                  fontSize: 16,
                  color: kDarkText.withValues(alpha: 0.6), // Updated withValues
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 事项卡片
  Widget _buildEventCard(CareEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: event.isDone
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.white, // Updated withValues
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: event.type.color.withValues(
              alpha: 0.5,
            ), // Updated withValues
            shape: BoxShape.circle,
          ),
          child: Icon(event.type.icon, color: kDarkText, size: 24),
        ),
        title: Text(
          event.type.label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kDarkText,
            decoration: event.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('HH:mm').format(event.dateTime),
              style: TextStyle(
                color: kDarkText.withValues(alpha: 0.5),
              ), // Updated withValues
            ),
            if (event.note.isNotEmpty)
              Text(
                event.note,
                style: TextStyle(
                  color: kDarkText.withValues(alpha: 0.8),
                ), // Updated withValues
              ),
          ],
        ),
        trailing: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: event.isDone,
            activeColor: kPrimaryColor,
            shape: const CircleBorder(),
            onChanged: (val) => _toggleEvent(event),
          ),
        ),
        onTap: () => _toggleEvent(event),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ➕ 新增事项页 (Add Event Page)
// ---------------------------------------------------------------------------

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  EventType _selectedType = EventType.food;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _noteController = TextEditingController();

  Future<void> _saveEvent() async {
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final newEvent = CareEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _selectedType,
      dateTime: dateTime,
      note: _noteController.text,
    );

    await StorageService.addEvent(newEvent);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记一笔')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
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
                        if (date != null) setState(() => _selectedDate = date);
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
                        if (time != null) setState(() => _selectedTime = time);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

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

              const Spacer(),

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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
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
            Icon(
              icon,
              size: 20,
              color: kDarkText.withValues(alpha: 0.6),
            ), // Updated withValues
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
// ⚙️ 设置页 (Settings Page)
// ---------------------------------------------------------------------------

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentInfo();
  }

  Future<void> _loadCurrentInfo() async {
    final name = await StorageService.getPetName();
    final type = await StorageService.getPetType();
    setState(() {
      _nameController.text = name;
      _typeController.text = type;
    });
  }

  Future<void> _saveInfo() async {
    await StorageService.savePetName(_nameController.text);
    await StorageService.savePetType(_typeController.text);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存成功！')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildTextField('宠物名字', _nameController),
              const SizedBox(height: 24),
              _buildTextField('宠物类型 (如: 猫咪, 狗狗)', _typeController),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('保存修改', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
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
