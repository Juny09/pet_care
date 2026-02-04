import 'package:flutter/material.dart';
import 'package:pet_care_app/health/vaccination_page.dart';
import 'package:pet_care_app/health/vet_visit_page.dart';
import 'package:pet_care_app/health/weight_page.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('健康管理'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.redAccent,
            tabs: [
              Tab(text: '体重记录'),
              Tab(text: '疫苗接种'),
              Tab(text: '就医记录'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            WeightPage(),
            VaccinationPage(),
            VetVisitPage(),
          ],
        ),
      ),
    );
  }
}
