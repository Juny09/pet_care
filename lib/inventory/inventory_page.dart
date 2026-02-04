import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_care_app/cloud_service.dart';
import 'package:pet_care_app/models.dart';
import 'package:pet_care_app/notification_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!CloudService.isEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final user = CloudService.client?.auth.currentUser;
      if (user == null) return;

      final response = await CloudService.client!
          .from('inventory')
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false);
      
      final data = response as List;
      setState(() {
        _items = data.map((e) => InventoryItem.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading inventory: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addItem({InventoryItem? item}) async {
    final nameController = TextEditingController(text: item?.itemName);
    final quantityController = TextEditingController(text: item?.quantity.toString());
    final unitController = TextEditingController(text: item?.unit ?? '个');
    final thresholdController = TextEditingController(text: item?.threshold?.toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? '添加物品' : '编辑物品'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '物品名称 (如: 狗粮)'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '数量'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: '单位 (如: kg, 袋)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: thresholdController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '低库存预警阈值',
                  helperText: '当数量低于此值时提醒',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || quantityController.text.isEmpty) return;

              final user = CloudService.client?.auth.currentUser;
              if (user == null) return;

              final quantity = double.tryParse(quantityController.text) ?? 0;
              final threshold = double.tryParse(thresholdController.text);

              final data = {
                'user_id': user.id,
                'item_name': nameController.text,
                'quantity': quantity,
                'unit': unitController.text,
                'threshold': threshold,
                'updated_at': DateTime.now().toIso8601String(),
              };

              if (item == null) {
                await CloudService.client!.from('inventory').insert(data);
              } else {
                await CloudService.client!
                    .from('inventory')
                    .update(data)
                    .eq('id', item.id);
              }
              
              Navigator.pop(context);
              _loadData();

              // Check threshold
              if (threshold != null && quantity <= threshold) {
                 await NotificationService.scheduleNotification(
                    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    title: '库存不足提醒 🥫',
                    body: '您的 ${nameController.text} 仅剩 $quantity ${unitController.text}，请及时补货！',
                    scheduledTime: DateTime.now().add(const Duration(seconds: 5)),
                  );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateQuantity(InventoryItem item, double change) async {
    final newQuantity = item.quantity + change;
    if (newQuantity < 0) return;

    try {
      await CloudService.client!
          .from('inventory')
          .update({
            'quantity': newQuantity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', item.id);
      
      _loadData(); // Refresh list
    } catch (e) {
      debugPrint('Error updating quantity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('智能库存'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isLow = item.threshold != null && item.quantity <= item.threshold!;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isLow ? Colors.redAccent : Colors.green,
                child: Icon(
                  isLow ? Icons.warning : Icons.check_circle,
                  color: Colors.white,
                ),
              ),
              title: Text(item.itemName),
              subtitle: Text('最后更新: ${DateFormat('MM-dd HH:mm').format(item.updatedAt)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _updateQuantity(item, -1),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${item.quantity.toStringAsFixed(1)} ${item.unit ?? ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isLow ? Colors.red : Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _updateQuantity(item, 1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () => _addItem(item: item),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItem(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
