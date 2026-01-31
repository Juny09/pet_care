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

/// 宠物模型
class Pet {
  final String id;
  final String name;
  final String type;

  Pet({required this.id, required this.name, required this.type});

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'type': type};
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(id: json['id'], name: json['name'], type: json['type']);
  }
}

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
  final String petId; // 关联的宠物ID
  final EventType type;
  final DateTime dateTime;
  final String note;
  bool isDone;

  CareEvent({
    required this.id,
    required this.petId,
    required this.type,
    required this.dateTime,
    this.note = '',
    this.isDone = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'type': type.index,
      'dateTime': dateTime.toIso8601String(),
      'note': note,
      'isDone': isDone,
    };
  }

  factory CareEvent.fromJson(Map<String, dynamic> json) {
    return CareEvent(
      id: json['id'],
      petId: json['petId'] ?? '', // 兼容旧数据
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
  static const String kPetsKey = 'pets_list';
  static const String kEventsKey = 'care_events';

  // 旧数据 key (用于迁移)
  static const String kOldPetNameKey = 'pet_name';
  static const String kOldPetTypeKey = 'pet_type';

  /// 获取所有宠物
  static Future<List<Pet>> getPets() async {
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
    final prefs = await SharedPreferences.getInstance();
    final String petsString = jsonEncode(pets.map((e) => e.toJson()).toList());
    await prefs.setString(kPetsKey, petsString);
  }

  /// 添加宠物
  static Future<void> addPet(Pet pet) async {
    final pets = await getPets();
    pets.add(pet);
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
  }

  /// 获取所有事项
  static Future<List<CareEvent>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? eventsString = prefs.getString(kEventsKey);
    if (eventsString == null) return [];

    final List<dynamic> jsonList = jsonDecode(eventsString);
    var events = jsonList.map((e) => CareEvent.fromJson(e)).toList();

    // 数据迁移：如果旧事件没有 petId，分配给第一个宠物
    final pets = await getPets();
    if (pets.isNotEmpty) {
      for (var event in events) {
        if (event.petId.isEmpty) {
          // 这里的注释解释了为什么不做实际修改，仅供理解
        }
      }
    }

    return events;
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
          surface: kPastelCream,
        ),
        scaffoldBackgroundColor: kPastelCream,
        fontFamily: null,
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
  List<Pet> _pets = [];
  String _currentPetId = '';
  List<CareEvent> _todayEvents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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

    // 筛选今日事项 & 当前宠物
    final now = DateTime.now();
    final todayEvents = allEvents.where((e) {
      final isToday =
          e.dateTime.year == now.year &&
          e.dateTime.month == now.month &&
          e.dateTime.day == now.day;

      // 兼容旧数据：如果 event.petId 为空，且当前是第一个宠物，也显示
      final isCurrentPet =
          e.petId == currentId ||
          (e.petId.isEmpty && currentId == pets.first.id);

      return isToday && isCurrentPet;
    }).toList();

    // 排序
    todayEvents.sort((a, b) {
      if (a.isDone != b.isDone) {
        return a.isDone ? 1 : -1;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
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
                          builder: (context) => const PetListPage(),
                        ),
                      );
                      _loadData(); // 返回后刷新
                    },
                  ),
                ],
              ),
              // 宠物切换列表
              SliverToBoxAdapter(child: _buildPetSelector()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '${_currentPet.name} 的待办 (${_todayEvents.where((e) => !e.isDone).length})',
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
          if (_currentPetId.isEmpty) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEventPage(petId: _currentPetId),
            ),
          );
          _loadData();
        },
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  /// 横向宠物选择器
  Widget _buildPetSelector() {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pets.length + 1, // +1 for Add button
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
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kDarkText.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.add, color: kDarkText),
              ),
            );
          }

          final pet = _pets[index];
          final isSelected = pet.id == _currentPetId;

          return GestureDetector(
            onTap: () {
              setState(() {
                _currentPetId = pet.id;
              });
              _loadData();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 80 : 60,
                    height: isSelected ? 80 : 60,
                    decoration: BoxDecoration(
                      color: isSelected ? kPastelYellow : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: kPrimaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                      border: isSelected
                          ? Border.all(color: kDarkText, width: 2)
                          : null,
                    ),
                    child: Icon(
                      pet.type.contains('猫') ? Icons.pets : Icons.cruelty_free,
                      size: isSelected ? 40 : 30,
                      color: kDarkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pet.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: kDarkText,
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

  /// 事项卡片
  Widget _buildEventCard(CareEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: event.isDone
            ? Colors.white.withValues(alpha: 0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: event.type.color.withValues(alpha: 0.5),
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
              style: TextStyle(color: kDarkText.withValues(alpha: 0.5)),
            ),
            if (event.note.isNotEmpty)
              Text(
                event.note,
                style: TextStyle(color: kDarkText.withValues(alpha: 0.8)),
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
  final String petId;
  const AddEventPage({super.key, required this.petId});

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
      petId: widget.petId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的毛孩子')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16),
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
                    child: Icon(
                      pet.type.contains('猫') ? Icons.pets : Icons.cruelty_free,
                      color: kDarkText,
                    ),
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
  final TextEditingController _typeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.pet != null) {
      _nameController.text = widget.pet!.name;
      _typeController.text = widget.pet!.type;
    } else {
      _typeController.text = '猫咪'; // 默认值
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;

    if (widget.pet != null) {
      // Update
      final updatedPet = Pet(
        id: widget.pet!.id,
        name: _nameController.text,
        type: _typeController.text,
      );
      await StorageService.updatePet(updatedPet);
    } else {
      // Add
      final newPet = Pet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        type: _typeController.text,
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
            children: [
              _buildTextField('名字', _nameController),
              const SizedBox(height: 24),
              _buildTextField('类型 (如: 猫咪, 狗狗)', _typeController),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
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
