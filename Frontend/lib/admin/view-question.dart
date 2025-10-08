import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewAssessmentsPage extends StatelessWidget {
  const ViewAssessmentsPage({Key? key}) : super(key: key);

  Future<String> _fetchUserName(String phone) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("register")
          .where("phone", isEqualTo: phone)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return data["name"] ?? "Unknown";
      }
    } catch (e) {
      debugPrint("Error fetching name for $phone: $e");
    }
    return "Unknown";
  }

  @override
  Widget build(BuildContext context) {
    final assessments = FirebaseFirestore.instance.collection("questionnaire");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Assessments"),
        backgroundColor: Colors.teal,
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: assessments.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No assessment records found",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // ✅ Fix overflow
              child: FutureBuilder(
                future: Future.wait(
                  docs.map((doc) async {
                    final data = doc.data() as Map<String, dynamic>;
                    final phone = data["phone"] ?? "N/A";
                    final name = await _fetchUserName(phone);
                    return {
                      "name": name,
                      "healthScore": data["healthScore"]?.toString() ?? "N/A",
                      "riskLevel": data["riskLevel"] ?? "N/A",
                      "riskColor": data["riskColor"] ?? "#000000",
                    };
                  }),
                ),
                builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> futureSnapshot) {
                  if (!futureSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userDataList = futureSnapshot.data!;

                  return DataTable(
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
                      DataColumn(label: Text("Name")),
                      DataColumn(label: Text("Assessment")),
                      DataColumn(label: Text("Health Score")),
                      DataColumn(label: Text("Risk Level")),
                    ],
                    rows: List.generate(userDataList.length, (index) {
                      final user = userDataList[index];
                      return DataRow(
                        cells: [
                          DataCell(Text("${index + 1}")),
                          DataCell(Text(user["name"])),
                          const DataCell(Text("Completed")), // ✅ Fixed text
                          DataCell(Text(
                            user["healthScore"],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(
                                  int.parse(user["riskColor"].substring(1, 7), radix: 16) + 0xFF000000,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user["riskLevel"],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
