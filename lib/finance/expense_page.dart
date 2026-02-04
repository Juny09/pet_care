import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_care_app/cloud_service.dart';
import 'package:pet_care_app/models.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  
  // Chart data
  Map<String, double> _categoryTotals = {};

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
          .from('expenses')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: false);
      
      final data = response as List;
      final expenses = data.map((e) => Expense.fromJson(e)).toList();
      
      // Calculate totals
      final totals = <String, double>{};
      for (var e in expenses) {
        totals[e.category] = (totals[e.category] ?? 0) + e.amount;
      }

      setState(() {
        _expenses = expenses;
        _categoryTotals = totals;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addExpense() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedCategory = 'Food';
    DateTime selectedDate = DateTime.now();

    final categories = ['Food', 'Toys', 'Vet', 'Grooming', 'Other'];
    final categoryLabels = {
      'Food': '食物',
      'Toys': '玩具',
      'Vet': '医疗',
      'Grooming': '美容',
      'Other': '其他',
    };

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('记一笔'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '金额',
                    prefixText: '¥ ',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(categoryLabels[c]!),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedCategory = v);
                  },
                  decoration: const InputDecoration(labelText: '分类'),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('日期: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注'),
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
                if (amountController.text.isEmpty) return;
                final amount = double.tryParse(amountController.text);
                if (amount == null) return;

                final user = CloudService.client?.auth.currentUser;
                if (user == null) return;

                await CloudService.client!.from('expenses').insert({
                  'user_id': user.id,
                  'amount': amount,
                  'category': selectedCategory,
                  'date': selectedDate.toIso8601String(),
                  'note': noteController.text,
                });
                
                Navigator.pop(context);
                _loadData();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('记账本'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_categoryTotals.isNotEmpty)
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: _categoryTotals.entries.map((e) {
                          final color = _getColorForCategory(e.key);
                          return PieChartSectionData(
                            color: color,
                            value: e.value,
                            title: '',
                            radius: 50,
                          );
                        }).toList(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _categoryTotals.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getColorForCategory(e.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${_getLabelForCategory(e.key)}: ¥${e.value.toStringAsFixed(1)}'),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (context, index) {
                final expense = _expenses[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getColorForCategory(expense.category).withOpacity(0.2),
                    child: Icon(
                      _getIconForCategory(expense.category),
                      color: _getColorForCategory(expense.category),
                    ),
                  ),
                  title: Text(_getLabelForCategory(expense.category)),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(expense.date)),
                  trailing: Text(
                    '¥ ${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Food': return Colors.orange;
      case 'Toys': return Colors.purple;
      case 'Vet': return Colors.red;
      case 'Grooming': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Food': return Icons.restaurant;
      case 'Toys': return Icons.toys;
      case 'Vet': return Icons.local_hospital;
      case 'Grooming': return Icons.content_cut;
      default: return Icons.category;
    }
  }

  String _getLabelForCategory(String category) {
    switch (category) {
      case 'Food': return '食物';
      case 'Toys': return '玩具';
      case 'Vet': return '医疗';
      case 'Grooming': return '美容';
      default: return '其他';
    }
  }
}
