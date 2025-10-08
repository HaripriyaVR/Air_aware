import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewSupportPage extends StatelessWidget {
  const ViewSupportPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final support = FirebaseFirestore.instance.collection("support");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Support Tickets"),
        backgroundColor: Colors.teal,
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: support.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No support tickets found",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.deepPurple.shade100),
                dataRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                columnSpacing: 30,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                columns: const [
                  DataColumn(label: Text("Sl. No")),
                  DataColumn(label: Text("Email")),
                  DataColumn(label: Text("Case")),
                  DataColumn(label: Text("Submitted At")),
                ],
                rows: List.generate(docs.length, (index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text("${index + 1}")),
                    DataCell(Text(data["email"] ?? "N/A")),
                    DataCell(Text(data["case"] ?? "N/A")),
                    DataCell(Text(
                      data["timestamp"] != null
                          ? (data["timestamp"] as Timestamp).toDate().toString().substring(0, 16)
                          : "N/A",
                    )),
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
