import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_care_app/cloud_service.dart';
import 'package:pet_care_app/models.dart';

class VetVisitPage extends StatefulWidget {
  final String? petId;
  const VetVisitPage({super.key, this.petId});

  @override
  State<VetVisitPage> createState() => _VetVisitPageState();
}

class _VetVisitPageState extends State<VetVisitPage> {
  List<VetVisit> _visits = [];
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
      var query = CloudService.client!.from('vet_visits').select();
      
      if (widget.petId != null) {
        query = query.eq('pet_id', widget.petId!);
      }

      final response = await query.order('visit_date', ascending: false);
      final data = response as List;
      setState(() {
        _visits = data.map((e) => VetVisit.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading vet visits: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addVisit() async {
    final clinicController = TextEditingController();
    final reasonController = TextEditingController();
    final diagnosisController = TextEditingController();
    final prescriptionController = TextEditingController();
    final costController = TextEditingController();
    final noteController = TextEditingController();
    DateTime visitDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加就医记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('日期: ${DateFormat('yyyy-MM-dd').format(visitDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: visitDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => visitDate = date);
                    }
                  },
                ),
                TextField(
                  controller: clinicController,
                  decoration: const InputDecoration(labelText: '诊所/医院名称'),
                ),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: '就诊原因'),
                ),
                TextField(
                  controller: diagnosisController,
                  decoration: const InputDecoration(labelText: '诊断结果'),
                ),
                TextField(
                  controller: prescriptionController,
                  decoration: const InputDecoration(labelText: '处方/用药'),
                  maxLines: 2,
                ),
                TextField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '费用',
                    prefixText: '¥ ',
                  ),
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
                if (clinicController.text.isEmpty && reasonController.text.isEmpty) return;

                final petIdToUse = widget.petId ?? 'default_pet';

                final data = {
                  'pet_id': petIdToUse,
                  'visit_date': visitDate.toIso8601String(),
                  'clinic_name': clinicController.text,
                  'reason': reasonController.text,
                  'diagnosis': diagnosisController.text,
                  'prescription': prescriptionController.text,
                  'cost': double.tryParse(costController.text),
                  'notes': noteController.text,
                };

                await CloudService.client!.from('vet_visits').insert(data);
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
        itemCount: _visits.length,
        itemBuilder: (context, index) {
          final visit = _visits[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExpansionTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.local_hospital, color: Colors.white),
              ),
              title: Text(visit.reason ?? '常规检查'),
              subtitle: Text('${DateFormat('yyyy-MM-dd').format(visit.visitDate)} @ ${visit.clinicName ?? "未知诊所"}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (visit.diagnosis != null && visit.diagnosis!.isNotEmpty)
                        _buildDetailRow('诊断', visit.diagnosis!),
                      if (visit.prescription != null && visit.prescription!.isNotEmpty)
                        _buildDetailRow('处方', visit.prescription!),
                      if (visit.cost != null)
                        _buildDetailRow('费用', '¥ ${visit.cost}'),
                      if (visit.notes != null && visit.notes!.isNotEmpty)
                        _buildDetailRow('备注', visit.notes!),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVisit,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
