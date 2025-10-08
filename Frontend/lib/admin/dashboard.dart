import 'package:flutter/material.dart';
import 'view-register.dart';
import 'view-question.dart';
import 'view-support.dart';
import 'stations.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        "title": "Registered Users",
        "icon": Icons.people,
        "color": Colors.blue,
        "page": const ViewUsersPage()
      },
      {
        "title": "Questionnaire",
        "icon": Icons.assignment,
        "color": Colors.green,
        "page": const ViewAssessmentsPage()
      },
      {
        "title": "Support",
        "icon": Icons.support_agent,
        "color": Colors.orange,
        "page": const ViewSupportPage()
      },
      {
        "title": "Station Data",
        "icon": Icons.sensors,
        "color": Colors.purple,
        "page": const LiveGasPage()
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: options.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // two cards per row
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final item = options[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => item["page"] as Widget),
                );
              },
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: (item["color"] as Color).withOpacity(0.9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item["icon"] as IconData, size: 50, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      item["title"] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
