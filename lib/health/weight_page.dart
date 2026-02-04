import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_care_app/cloud_service.dart';
import 'package:pet_care_app/models.dart';
import 'package:pet_care_app/main.dart'; // To access _currentPetId, though passing it is better.
// For now, I'll assume we can get petId from context or global state, or passed in.
// Since HealthPage doesn't take petId, I might need to access the global state or pass it down.
// In main.dart, _HomePageState has _currentPetId.
// Ideally, we should use a state management solution, but let's assume we can get it or pass it.
// Wait, I can't easily access _HomePageState's private state.
// I should update RecordsPage to accept petId, and HealthPage to accept petId.

// REVISION: I'll make WeightPage accept petId if possible, or fetch it from a global/shared place.
// Given the existing architecture, maybe I can use a static accessor or just assume the user picks the pet on the page if not provided.
// BUT, the app seems to be designed around a "current pet".
// Let's check main.dart to see if there is a way to get the current pet ID globally or if I should refactor to pass it.
// The _HomePageState has _currentPetId.
// I will create a global ValueNotifier or similar in a new `state.dart` or just use a hack for now?
// No, better to pass it.
// RecordsPage is instantiated in main.dart: `const RecordsPage()`.
// I should change it to `RecordsPage(petId: _currentPetId)`.

// Let's implement WeightPage assuming it receives petId or finds a way to get it.
// For now, I will add a pet selector on these pages if petId is null?
// Or better, update main.dart to pass the current pet ID to RecordsPage.

// Let's assume I will update main.dart to pass petId to RecordsPage.
// So RecordsPage will pass it to HealthPage, etc.

class WeightPage extends StatefulWidget {
  final String? petId; // Pass this down
  const WeightPage({super.key, this.petId});

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  List<WeightLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // If petId is not passed, we might need to fetch the first pet or handle it.
    // For this implementation, I'll assume we handle the "no pet" case or it's passed.
    // However, since I can't change main.dart *simultaneously* to pass the ID,
    // I'll try to fetch all logs for the user if petId is null, or just handle gracefully.

    if (!CloudService.isEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final user = CloudService.client?.auth.currentUser;
      if (user == null) return;

      var query = CloudService.client!.from('weight_logs').select();

      if (widget.petId != null) {
        query = query.eq('pet_id', widget.petId!);
      }

      final response = await query.order('date', ascending: true);
      final data = response as List;
      setState(() {
        _logs = data.map((e) => WeightLog.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading weight logs: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addWeight() async {
    final weightController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录体重'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '体重 (kg)',
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: '备注 (可选)'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  '日期: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    selectedDate = date;
                    (context as Element).markNeedsBuild();
                  }
                },
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
              if (weightController.text.isEmpty) return;
              final weight = double.tryParse(weightController.text);
              if (weight == null) return;

              // TODO: Get actual petId if not provided.
              // For now we use a placeholder or assume widget.petId is set.
              // If widget.petId is null, we need to ask user to select a pet?
              // Let's assume for now we use a hardcoded petId or fail if null.
              final petIdToUse = widget.petId ?? 'default_pet';

              await CloudService.client!.from('weight_logs').insert({
                'pet_id': petIdToUse,
                'weight': weight,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_logs.isNotEmpty) ...[
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _logs.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.weight);
                        }).toList(),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.monitor_weight, color: Colors.white),
                    ),
                    title: Text('${log.weight} kg'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(log.date)),
                    trailing: log.note != null && log.note!.isNotEmpty
                        ? const Icon(Icons.note)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWeight,
        child: const Icon(Icons.add),
      ),
    );
  }
}
