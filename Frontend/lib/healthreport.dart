
import 'dart:convert';
import 'dart:async';
import 'package:universal_io/io.dart' as io;             // <— replaces dart:io
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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';                   // <— added
import 'dart:typed_data';
import 'dart:ui' as ui;
// import 'dart:html' as html; // <— removed

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
  double? aqi;
  String aqiStatus = '';
  String combinedRisk = '';
  String recommendation = '';
  bool isLoading = true;
  bool _isDisposed = false;

  final GlobalKey _printKey = GlobalKey(); // For capturing screenshot

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

      // Fetch name
      final regSnap = await FirebaseFirestore.instance
          .collection('register')
          .where('phone', isEqualTo: phone)
          .get();
      if (regSnap.docs.isNotEmpty) {
        name = regSnap.docs.first.data()['name'] ?? '';
      }

      // Fetch health score
      final qSnap = await FirebaseFirestore.instance
          .collection('questionnaire')
          .where('phone', isEqualTo: phone)
          .get();
      if (qSnap.docs.isNotEmpty) {
        healthScore = qSnap.docs.first.data()['healthScore'] ?? 0;
        riskLevel = qSnap.docs.first.data()['riskLevel'] ?? '';
      }

      // Get location (ask permission as needed in your app)
      Location location = Location();
      LocationData locData = await location.getLocation();
      double lat = locData.latitude ?? 0;
      double lon = locData.longitude ?? 0;

      // Fetch AQI
      await fetchAQI(lat, lon);

      // keep combinedRisk & recommendation in state if we have aqi
      if (aqi != null) {
        combinedRisk = getCombinedRisk(healthScore, aqi!.toInt());
        recommendation = getRecommendation(combinedRisk);
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      if (!_isDisposed) setState(() => isLoading = false);
    }
  }

  Future<void> fetchAQI(double lat, double lon) async {
    if (_isDisposed) return;
    final url = Uri.parse('http://10.112.193.104:5000/user-aqi?lat=$lat&lon=$lon');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));
      if (_isDisposed) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            aqi = (data["user_aqi"] != null) ? data["user_aqi"].toDouble() : null;
            aqiStatus = data["status"] ?? '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            aqi = null;
            aqiStatus = "Unable to fetch AQI data";
          });
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          aqiStatus = "Error fetching AQI data";
        });
      }
    }
  }

  Map<String, String> getRiskLevel(int score) {
    if (score <= 25) {
      return {'level': 'Low', 'color': '#4CAF50'}; // Green
    } else if (score <= 50) {
      return {'level': 'Moderate', 'color': '#FF9800'}; // Orange
    } else if (score <= 75) {
      return {'level': 'High', 'color': '#F44336'}; // Red
    } else {
      return {'level': 'Critical', 'color': '#B71C1C'}; // Dark Red
    }
  }

  Map<String, dynamic> getAqiLevel(int aqiValue) {
    final List<Map<String, dynamic>> levels = [
      {"label": "Good", "color": Colors.green, "min": 0, "max": 50},
      {"label": "Satisfactory", "color": Colors.yellow, "min": 51, "max": 100},
      {"label": "Moderate", "color": Colors.orange, "min": 101, "max": 200},
      {"label": "Poor", "color": Colors.red, "min": 201, "max": 300},
      {"label": "Very Poor", "color": Colors.purple, "min": 301, "max": 400},
      {"label": "Severe", "color": Colors.brown, "min": 401, "max": 500},
    ];

    return levels.firstWhere(
      (level) =>
          aqiValue >= (level['min'] as num) &&
          aqiValue <= (level['max'] as num),
      orElse: () => {
        "label": "Unknown",
        "color": Colors.grey,
        "min": 0,
        "max": 0
      },
    );
  }

  String getHealthRecommendation(String risk) {
    switch (risk) {
      case "Low":
        return "Great health score! Keep up the healthy habits.";
      case "Moderate":
        return "Some improvements can be made in lifestyle and diet.";
      case "High":
        return "Consider medical advice and lifestyle adjustments.";
      case "Critical":
        return "Seek professional medical guidance immediately.";
      default:
        return "";
    }
  }

  String getAqiRecommendation(String level) {
    switch (level) {
      case "Good":
      case "Satisfactory":
        return "Air quality is fine. Enjoy outdoor activities.";
      case "Moderate":
        return "Sensitive groups should limit prolonged outdoor activity.";
      case "Poor":
        return "Avoid outdoor activities if possible.";
      case "Very Poor":
        return "Stay indoors, use air purifiers.";
      case "Severe":
        return "Serious health risk. Avoid exposure completely.";
      default:
        return "";
    }
  }

  String getCombinedRisk(int healthScore, int userAqi) {
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

    int combinedScore = {
      "Low": 1, "Moderate": 2, "High": 3, "Critical": 4
    }[healthRisk]! +
    {
      "Good": 1, "Moderate": 2, "Unhealthy for Sensitive Groups": 3,
      "Unhealthy": 4, "Very Unhealthy": 5, "Hazardous": 6
    }[aqiRisk]!;

    if (combinedScore <= 3) return "Low";
    if (combinedScore <= 6) return "Moderate";
    if (combinedScore <= 8) return "High";
    return "Critical";
  }

  String getRecommendation(String risk) {
    switch (risk) {
      case "Low":
        return "You are in good health and air quality is fine. Maintain your lifestyle.";
      case "Moderate":
        return "Some precautions are advised. Limit prolonged outdoor activity.";
      case "High":
        return "Reduce strenuous outdoor activities. Wear a mask if needed.";
      case "Critical":
        return "Avoid outdoor exposure, use air purifiers, and seek medical advice if unwell.";
      default:
        return "";
    }
  }

  // capture visible widget and download exact page as PDF (works web + mobile/desktop)
  Future<void> _downloadPDF() async {
    try {
      RenderRepaintBoundary boundary =
          _printKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      final imageWidget = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Center(
            child: pw.Image(imageWidget, fit: pw.BoxFit.contain),
          ),
        ),
      );

      final pdfBytes = await pdf.save();

      if (kIsWeb) {
        // Web: share/download without dart:html
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: "health_report.pdf",
        );
      } else {
        // Mobile/desktop: save & open
        final dir = await getApplicationDocumentsDirectory();
        final file = io.File("${dir.path}/health_report.pdf");
        await file.writeAsBytes(pdfBytes);
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      debugPrint("Error capturing PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final healthData = getRiskLevel(healthScore);
    final aqiData = (aqi != null) ? getAqiLevel(aqi!.toInt()) : {"label": "N/A", "color": Colors.grey};

    // compute local combined values in build (don't call setState here)
    final String localCombined = (combinedRisk.isNotEmpty)
        ? combinedRisk
        : (aqi != null ? getCombinedRisk(healthScore, aqi!.toInt()) : 'Unknown');
    final String combinedRec = getRecommendation(localCombined);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Report"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadPDF,
          )
        ],
      ),
      body: RepaintBoundary(
        key: _printKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(phone ?? "", style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 1) Health Score Section ---
                  Text("Health Score", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircularPercentIndicator(
                        radius: 60,
                        lineWidth: 10,
                        percent: (healthScore.clamp(0, 100)) / 100.0,
                        center: Text("$healthScore", style: const TextStyle(fontSize: 18)),
                        progressColor: Color(int.parse("0xFF${healthData['color']!.substring(1)}")),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Risk Level: ${healthData['level']}",
                              style: TextStyle(
                                color: Color(int.parse("0xFF${healthData['color']!.substring(1)}")),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(getHealthRecommendation(healthData['level']!), style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  // --- 2) AQI Section ---
                  const SizedBox(height: 8),
                  Text("User AQI", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircularPercentIndicator(
                        radius: 60,
                        lineWidth: 10,
                        percent: (aqi != null && aqi! <= 500) ? (aqi! / 500.0) : 0,
                        center: Text("${aqi?.toStringAsFixed(0) ?? 'N/A'}", style: const TextStyle(fontSize: 18)),
                        progressColor: aqiData['color'],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "AQI Level: ${aqiData['label']}",
                              style: TextStyle(
                                color: aqiData['color'],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(getAqiRecommendation(aqiData['label']), style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  // --- 3) Combined Risk Section ---
                  const SizedBox(height: 8),
                  Text("Combined Risk", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    localCombined,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: localCombined == "Critical"
                          ? Colors.red
                          : localCombined == "High"
                              ? Colors.orange
                              : localCombined == "Moderate"
                                  ? Colors.amber
                                  : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(combinedRec, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
      
    );
  }

}