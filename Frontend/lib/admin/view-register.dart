import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewUsersPage extends StatelessWidget {
  const ViewUsersPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection("register");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registered Users"),
        backgroundColor: Colors.indigo,
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: users.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No registered users found",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // allows scrolling if many columns
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.indigo.shade100),
                dataRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                columnSpacing: 30,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                columns: const [
                  DataColumn(label: Text("Sl. No")),
                  DataColumn(label: Text("Name")),
                  DataColumn(label: Text("Phone Number")),
                ],
                rows: List.generate(docs.length, (index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text("${index + 1}")),
                    DataCell(Text(data["name"] ?? "No Name")),
                    DataCell(Text(data["phone"] ?? "")),
                  ]);
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}
