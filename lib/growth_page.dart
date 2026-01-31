import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'main.dart'; // Import models and storage service

class GrowthPage extends StatefulWidget {
  final Pet pet;

  const GrowthPage({super.key, required this.pet});

  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage> {
  List<GrowthRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await StorageService.getGrowthRecords(widget.pet.id);
    if (mounted) {
      setState(() {
        _records = records;
      });
    }
  }

  Future<void> _addRecord() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGrowthRecordSheet(petId: widget.pet.id),
    );
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.pet.name} 的成长日记'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPastelCream, Colors.white],
          ),
        ),
        child: _records.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 80),
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final record = _records[index];
                  return _buildRecordCard(record, index);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecord,
        icon: const Icon(Icons.add),
        label: const Text('记录体重'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monitor_weight_outlined, size: 80, color: kPrimaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            '还没有成长记录哦',
            style: TextStyle(color: kDarkText.withValues(alpha: 0.5), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '快来记录${widget.pet.name}的每一次变化吧！',
            style: TextStyle(color: kDarkText.withValues(alpha: 0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(GrowthRecord record, int index) {
    // Calculate weight change
    double? change;
    if (index < _records.length - 1) {
      final prev = _records[index + 1];
      change = record.weight - prev.weight;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kPastelBlue.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MM.dd').format(record.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kDarkText,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('yyyy').format(record.date),
                  style: TextStyle(
                    color: kDarkText.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${record.weight} kg',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kDarkText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (change != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: change > 0
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 12,
                              color: change > 0 ? Colors.red : Colors.green,
                            ),
                            Text(
                              '${change.abs().toStringAsFixed(1)}',
                              style: TextStyle(
                                color: change > 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (record.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      record.note,
                      style: TextStyle(color: kDarkText.withValues(alpha: 0.7)),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: kDarkText.withValues(alpha: 0.3)),
            onPressed: () => _deleteRecord(record),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(GrowthRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除?'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteGrowthRecord(record.id);
      _loadRecords();
    }
  }
}

class AddGrowthRecordSheet extends StatefulWidget {
  final String petId;
  const AddGrowthRecordSheet({super.key, required this.petId});

  @override
  State<AddGrowthRecordSheet> createState() => _AddGrowthRecordSheetState();
}

class _AddGrowthRecordSheetState extends State<AddGrowthRecordSheet> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '记录体重',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '体重 (kg)',
                    suffixText: 'kg',
                    prefixIcon: Icon(Icons.monitor_weight),
                  ),
                  autofocus: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 8),
                        Text(DateFormat('MM-dd').format(_selectedDate)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '备注 (可选)',
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text('保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的体重')));
      return;
    }

    final record = GrowthRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      petId: widget.petId,
      date: _selectedDate,
      weight: weight,
      note: _noteController.text,
    );

    await StorageService.addGrowthRecord(record);
    if (mounted) Navigator.pop(context);
  }
}
