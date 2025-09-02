import 'dart:convert';
import 'dart:async';
import 'package:universal_io/io.dart' as io; // replaces dart:io
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import '../config.dart';



class HealthProfilePage extends StatefulWidget {
  const HealthProfilePage({Key? key}) : super(key: key);

  @override
  State<HealthProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<HealthProfilePage> {
  String? phone;
  String name = '';
  int healthScore = 0;
  String riskLevel = '';

  // ✅ Correct AQI fields
  double? userAqi;
  String userAqiStatus = '';

  String combinedRisk = '';
  String recommendation = '';
  bool isLoading = true;
  bool _isDisposed = false;

  final GlobalKey _printKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      phone = prefs.getString('phone');

      if (phone == null) {
        setState(() => isLoading = false);
        return;
      }

      // 🔹 Fetch name
      final regSnap = await FirebaseFirestore.instance
          .collection('register')
          .where('phone', isEqualTo: phone)
          .get();
      if (regSnap.docs.isNotEmpty) {
        name = regSnap.docs.first.data()['name'] ?? '';
      }

      // 🔹 Fetch health score
      final qSnap = await FirebaseFirestore.instance
          .collection('questionnaire')
          .where('phone', isEqualTo: phone)
          .get();
      if (qSnap.docs.isNotEmpty) {
        healthScore = qSnap.docs.first.data()['healthScore'] ?? 0;
        riskLevel = qSnap.docs.first.data()['riskLevel'] ?? '';
      }

      // 🔹 Get location
      Location location = Location();
      LocationData locData = await location.getLocation();
      double lat = locData.latitude ?? 0;
      double lon = locData.longitude ?? 0;

      // 🔹 Fetch user AQI instead of generic AQI
      await _fetchUserAQI(lat, lon);

      if (userAqi != null) {
        combinedRisk = getCombinedRisk(healthScore, userAqi!.toInt());
        recommendation = getRecommendation(combinedRisk);
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      if (!_isDisposed) setState(() => isLoading = false);
    }
  }

  /// ✅ Fetch AQI for user location
  Future<void> _fetchUserAQI(double lat, double lon) async {
    try {
      final url = Uri.parse("${AppConfig.userAqi}?lat=$lat&lon=$lon");
      debugPrint("📡 Fetching User AQI from: $url");

      final response = await http.get(url);
      debugPrint("📥 User AQI Response [${response.statusCode}]: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userAqi = (data["user_aqi"] != null)
              ? data["user_aqi"].toDouble()
              : null;
          userAqiStatus = data["status"] ?? '';
        });
        debugPrint("✅ User AQI updated: $userAqi ($userAqiStatus)");
      } else {
        setState(() {
          userAqi = null;
          userAqiStatus = "Unable to fetch AQI";
        });
      }
    } catch (e) {
      setState(() {
        userAqi = null;
        userAqiStatus = "Error fetching AQI";
      });
      debugPrint("❌ Error fetching User AQI: $e");
    }
  }
  // inside _ProfilePageState

Future<void> _downloadPdf() async {
  try {
    final pdf = pw.Document();

    final String localCombined = (combinedRisk.isNotEmpty)
        ? combinedRisk
        : (userAqi != null ? getCombinedRisk(healthScore, userAqi!.toInt()) : 'Unknown');

    final String combinedRec = getRecommendation(localCombined);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Health Report",
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text("Name: $name"),
              pw.Text("Phone: ${phone ?? ''}"),
              pw.SizedBox(height: 20),
              pw.Text("Health Score: $healthScore"),
              pw.Text("Health Risk Level: $riskLevel"),
              pw.SizedBox(height: 20),
              pw.Text("User AQI: ${userAqi?.toStringAsFixed(0) ?? 'N/A'}"),
              pw.Text("AQI Status: $userAqiStatus"),
              pw.SizedBox(height: 20),
              pw.Text("Combined Risk: $localCombined"),
              pw.Text("Recommendation: $combinedRec"),
            ],
          ),
        ),
      ),
    );

    final outputDir = await getApplicationDocumentsDirectory();
    final file = io.File("${outputDir.path}/health_report.pdf");

    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);
  } catch (e) {
    debugPrint("❌ Error generating PDF: $e");
  }
}


  // --- Helpers for health/aqi/risk ---
  Map<String, String> getRiskLevel(int score) { /* unchanged */ 
    if (score <= 25) return {'level': 'Low', 'color': '#4CAF50'};
    else if (score <= 50) return {'level': 'Moderate', 'color': '#FF9800'};
    else if (score <= 75) return {'level': 'High', 'color': '#F44336'};
    return {'level': 'Critical', 'color': '#B71C1C'};
  }

  Map<String, dynamic> getAqiLevel(int aqiValue) { /* unchanged */ 
    final List<Map<String, dynamic>> levels = [
      {"label": "Good", "color": Colors.green, "min": 0, "max": 50},
      {"label": "Satisfactory", "color": Colors.yellow, "min": 51, "max": 100},
      {"label": "Moderate", "color": Colors.orange, "min": 101, "max": 200},
      {"label": "Poor", "color": Colors.red, "min": 201, "max": 300},
      {"label": "Very Poor", "color": Colors.purple, "min": 301, "max": 400},
      {"label": "Severe", "color": Colors.brown, "min": 401, "max": 500},
    ];
    return levels.firstWhere(
      (l) => aqiValue >= l['min'] && aqiValue <= l['max'],
      orElse: () => {"label": "Unknown", "color": Colors.grey},
    );
  }

  String getCombinedRisk(int healthScore, int userAqi) { /* unchanged */ 
    String healthRisk;
    if (healthScore <= 25) healthRisk = "Low";
    else if (healthScore <= 50) healthRisk = "Moderate";
    else if (healthScore <= 75) healthRisk = "High";
    else healthRisk = "Critical";

    String aqiRisk;
    if (userAqi <= 50) aqiRisk = "Good";
    else if (userAqi <= 100) aqiRisk = "Moderate";
    else if (userAqi <= 150) aqiRisk = "Unhealthy for Sensitive Groups";
    else if (userAqi <= 200) aqiRisk = "Unhealthy";
    else if (userAqi <= 300) aqiRisk = "Very Unhealthy";
    else aqiRisk = "Hazardous";

    int combinedScore =
        {"Low": 1, "Moderate": 2, "High": 3, "Critical": 4}[healthRisk]! +
        {
          "Good": 1,
          "Moderate": 2,
          "Unhealthy for Sensitive Groups": 3,
          "Unhealthy": 4,
          "Very Unhealthy": 5,
          "Hazardous": 6
        }[aqiRisk]!;

    if (combinedScore <= 3) return "Low";
    if (combinedScore <= 6) return "Moderate";
    if (combinedScore <= 8) return "High";
    return "Critical";
  }

  String getRecommendation(String risk) { /* unchanged */ 
    switch (risk) {
      case "Low": return "You are in good health and air quality is fine.";
      case "Moderate": return "Take precautions. Limit prolonged outdoor activity.";
      case "High": return "Reduce strenuous outdoor activities. Wear a mask.";
      case "Critical": return "Avoid outdoor exposure, use purifiers, seek medical help.";
    }
    return "";
  }

 

@override
Widget build(BuildContext context) {
  if (isLoading) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.teal, // ✅ Use a fixed color if you want
        ),
      ),
    );
  }

  final healthData = getRiskLevel(healthScore);
  final aqiData = (userAqi != null)
      ? getAqiLevel(userAqi!.toInt())
      : {"label": "N/A", "color": Colors.grey};

  final String localCombined = (combinedRisk.isNotEmpty)
      ? combinedRisk
      : (userAqi != null
          ? getCombinedRisk(healthScore, userAqi!.toInt())
          : 'Unknown');

  final String combinedRec = getRecommendation(localCombined);

  return Scaffold(
    appBar: AppBar(
      title: const Text("Health Report"),
      backgroundColor: Colors.teal,
      actions: [
        IconButton(
          icon: const Icon(Icons.download),
          tooltip: "Download Report",
          onPressed: () async {
            final pdf = pw.Document();

            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (pw.Context context) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Health Report",
                          style: pw.TextStyle(
                              fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 16),
                      pw.Text("Name: $name"),
                      pw.Text("Phone: ${phone ?? ''}"),
                      pw.SizedBox(height: 16),
                      pw.Text("Health Score: $healthScore"),
                      pw.Text("Health Risk Level: ${healthData['level']}"),
                      pw.SizedBox(height: 16),
                      pw.Text("User AQI: ${userAqi?.toStringAsFixed(0) ?? 'N/A'}"),
                      pw.Text("AQI Level: ${aqiData['label']}"),
                      pw.SizedBox(height: 16),
                      pw.Text("Combined Risk: $localCombined"),
                      pw.Text("Recommendation: $combinedRec"),
                    ],
                  );
                },
              ),
            );

            // ✅ Save or share the PDF
            await Printing.sharePdf(
              bytes: await pdf.save(),
              filename: "health_report.pdf",
            );
          },
        ),
      ],
    ),
    body: RepaintBoundary(
      key: _printKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- User Info ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(phone ?? "", style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 20),

                // --- Health Score ---
                Text("Health Score",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    CircularPercentIndicator(
                      radius: 60,
                      lineWidth: 10,
                      percent: (healthScore.clamp(0, 100)) / 100.0,
                      center: Text("$healthScore"),
                      progressColor: Color(
                          int.parse("0xFF${healthData['color']!.substring(1)}")),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text("Risk Level: ${healthData['level']}"),
                    ),
                  ],
                ),
                const Divider(),

                // --- User AQI ---
                Text("User AQI",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    CircularPercentIndicator(
                      radius: 60,
                      lineWidth: 10,
                      percent: (userAqi != null && userAqi! <= 500)
                          ? (userAqi! / 500.0)
                          : 0,
                      center: Text("${userAqi?.toStringAsFixed(0) ?? 'N/A'}"),
                      progressColor: aqiData['color'],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text("AQI Level: ${aqiData['label']}"),
                    ),
                  ],
                ),
                const Divider(),

                // --- Combined Risk ---
                Text("Combined Risk: $localCombined"),
                Text(combinedRec),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}