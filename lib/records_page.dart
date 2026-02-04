import 'package:flutter/material.dart';
import 'package:pet_care_app/finance/expense_page.dart';
import 'package:pet_care_app/health/health_page.dart';
import 'package:pet_care_app/inventory/inventory_page.dart';

// Constants
const Color kPrimaryColor = Color(0xFF6C63FF);
const Color kCardColor = Colors.white;

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记录 & 工具'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildRecordCard(
              context,
              icon: Icons.health_and_safety,
              title: '健康管理',
              subtitle: '体重、疫苗、就医',
              color: Colors.redAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HealthPage()),
                );
              },
            ),
            _buildRecordCard(
              context,
              icon: Icons.account_balance_wallet,
              title: '记账本',
              subtitle: '花销统计',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExpensePage()),
                );
              },
            ),
            _buildRecordCard(
              context,
              icon: Icons.inventory_2,
              title: '智能库存',
              subtitle: '口粮、用品管理',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InventoryPage()),
                );
              },
            ),
            // Placeholder for future features
            _buildRecordCard(
              context,
              icon: Icons.more_horiz,
              title: '更多功能',
              subtitle: '敬请期待',
              color: Colors.grey,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('更多功能开发中...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
