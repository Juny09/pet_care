import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_care_app/cloud_service.dart';
import 'package:pet_care_app/models.dart';
import 'package:pet_care_app/notification_service.dart';

class VaccinationPage extends StatefulWidget {
  final String? petId;
  const VaccinationPage({super.key, this.petId});

  @override
  State<VaccinationPage> createState() => _VaccinationPageState();
}

class _VaccinationPageState extends State<VaccinationPage> {
  List<Vaccination> _vaccinations = [];
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
      var query = CloudService.client!.from('vaccinations').select();
      
      if (widget.petId != null) {
        query = query.eq('pet_id', widget.petId!);
      }

      final response = await query.order('date_administered', ascending: false);
      final data = response as List;
      setState(() {
        _vaccinations = data.map((e) => Vaccination.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading vaccinations: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addVaccination() async {
    final nameController = TextEditingController();
    final vetController = TextEditingController();
    final noteController = TextEditingController();
    DateTime dateAdministered = DateTime.now();
    DateTime? nextDueDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加疫苗记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '疫苗名称'),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('接种日期: ${DateFormat('yyyy-MM-dd').format(dateAdministered)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: dateAdministered,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => dateAdministered = date);
                    }
                  },
                ),
                ListTile(
                  title: Text(nextDueDate == null 
                      ? '下次接种日期 (可选)' 
                      : '下次接种: ${DateFormat('yyyy-MM-dd').format(nextDueDate!)}'),
                  trailing: const Icon(Icons.event_repeat),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: nextDueDate ?? dateAdministered.add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2050),
                    );
                    if (date != null) {
                      setState(() => nextDueDate = date);
                    }
                  },
                ),
                TextField(
                  controller: vetController,
                  decoration: const InputDecoration(labelText: '兽医/诊所 (可选)'),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注 (可选)'),
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
                if (nameController.text.isEmpty) return;

                final petIdToUse = widget.petId ?? 'default_pet';

                final data = {
                  'pet_id': petIdToUse,
                  'vaccine_name': nameController.text,
                  'date_administered': dateAdministered.toIso8601String(),
                  'next_due_date': nextDueDate?.toIso8601String(),
                  'vet_name': vetController.text,
                  'notes': noteController.text,
                };

                await CloudService.client!.from('vaccinations').insert(data);
                
                // Schedule notification if next due date is set
                if (nextDueDate != null) {
                  // Schedule for 9 AM on the due date
                  final scheduledTime = DateTime(
                    nextDueDate!.year, 
                    nextDueDate!.month, 
                    nextDueDate!.day, 
                    9, 0, 0
                  );
                  
                  await NotificationService.scheduleNotification(
                    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    title: '疫苗接种提醒 💉',
                    body: '该带 ${widget.petId ?? "宠物"} 去打 ${nameController.text} 疫苗啦！',
                    scheduledTime: scheduledTime,
                  );
                }

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
      body: ListView.builder(
        itemCount: _vaccinations.length,
        itemBuilder: (context, index) {
          final vax = _vaccinations[index];
          final isOverdue = vax.nextDueDate != null && 
              vax.nextDueDate!.isBefore(DateTime.now());

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.vaccines, color: Colors.white),
              ),
              title: Text(vax.vaccineName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('接种: ${DateFormat('yyyy-MM-dd').format(vax.dateAdministered)}'),
                  if (vax.nextDueDate != null)
                    Text(
                      '下次: ${DateFormat('yyyy-MM-dd').format(vax.nextDueDate!)}',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (vax.vetName != null && vax.vetName!.isNotEmpty)
                    Text('医生: ${vax.vetName}'),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVaccination,
        child: const Icon(Icons.add),
      ),
    );
  }
}
