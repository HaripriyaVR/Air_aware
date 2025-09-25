import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:universal_io/io.dart' as io;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:geolocator/geolocator.dart';
import '../config.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'utils/sensor_name_mapper.dart';
import 'package:flutter/rendering.dart';


class HealthProfilePage extends StatefulWidget {
  const HealthProfilePage({Key? key}) : super(key: key);

  @override
  State<HealthProfilePage> createState() => _HealthProfilePageState();
}

class _HealthProfilePageState extends State<HealthProfilePage> {
  String? phone;
  String name = '';
  int healthScore = 0;
  String riskLevel = '';
  Map<String, dynamic>? questionnaireAnswers;

  double? userAqi;
  String userAqiStatus = '';
  String currentLocationName = '';
  String nearestStation = "Nearest Station";
  String? sensorId;

  String combinedRisk = '';
  String recommendation = '';
  bool isLoading = true;
  bool _isDisposed = false;

  final GlobalKey _pdfKey = GlobalKey(); // ✅ Key for capturing UI

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
        if (!_isDisposed) setState(() => isLoading = false);
        return;
      }

      // Fetch user name
      final regSnap = await FirebaseFirestore.instance
          .collection('register')
          .where('phone', isEqualTo: phone)
          .get();
      if (regSnap.docs.isNotEmpty) {
        name = regSnap.docs.first.data()['name'] ?? '';
      }

      // Fetch health score & risk level + questionnaire
      final qSnap = await FirebaseFirestore.instance
          .collection('questionnaire')
          .where('phone', isEqualTo: phone)
          .get();

      if (qSnap.docs.isNotEmpty) {
        final data = qSnap.docs.first.data();
        healthScore = data['healthScore'] ?? 0;
        riskLevel = data['riskLevel'] ?? '';

        questionnaireAnswers = {};
        for (var key in data.keys) {
          if (!['phone', 'healthScore', 'riskLevel', 'riskColor', 'submittedAt','updatedAt']
              .contains(key)) {
            if (data[key] is List) {
              questionnaireAnswers![key] = (data[key] as List).join(", ");
            } else {
              questionnaireAnswers![key] = data[key].toString();
            }
          }
        }
      }

      Position position = await _determinePosition();
      double lat = position.latitude;
      double lon = position.longitude;

      currentLocationName = await getLocationNameFromLocationIQ(lat, lon);
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

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Location services are disabled.");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied.");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> getLocationNameFromLocationIQ(double lat, double lon) async {
    const String apiKey = 'pk.4008a8b89d2e64ea44232fbd4b3308b2';
    final url = Uri.parse(
        'https://us1.locationiq.com/v1/reverse?key=$apiKey&lat=$lat&lon=$lon&format=json');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};
        final String exactPlace = address['building'] ??
            address['amenity'] ??
            address['landmark'] ??
            address['suburb'] ??
            address['road'] ??
            '';
        final String city =
            address['city'] ?? address['town'] ?? address['village'] ?? '';
        final String district =
            address['county'] ?? address['state_district'] ?? '';
        final String state = address['state'] ?? '';
        String shortName = [exactPlace, city, district, state]
            .where((e) => e.isNotEmpty)
            .join(', ');
        return shortName.isNotEmpty
            ? shortName
            : data['display_name'] ?? '$lat, $lon';
      } else {
        return '$lat, $lon';
      }
    } catch (e) {
      return '$lat, $lon';
    }
  }

  Future<void> _fetchUserAQI(double lat, double lon) async {
    if (_isDisposed) return;

    final String baseUrl = AppConfig.baseUrl;
    const String endpoint = "/api/user-aqi";
    final url = Uri.parse("$baseUrl$endpoint?lat=$lat&lon=$lon");

    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('AQI request timed out'),
      );

      if (_isDisposed) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            userAqi = (data["user_aqi"] != null)
                ? data["user_aqi"].toDouble()
                : null;
            userAqiStatus = data["status"] ?? "Unknown";

            sensorId = data["closest_sensor"]?["sensor_id"];
            nearestStation = (sensorId != null)
                ? SensorNameMapper.displayName(sensorId!)
                : "Unknown Sensor";

            final distanceKm = data["closest_sensor"]?["distance_km"]?.toDouble();
            if (distanceKm != null) {
              nearestStation += " (${distanceKm.toStringAsFixed(1)} km)";
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            userAqi = null;
            userAqiStatus = "Unable to fetch AQI";
            nearestStation = "Unknown";
          });
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          userAqi = null;
          userAqiStatus = "Error fetching AQI data";
          nearestStation = "Unknown";
        });
      }
    }
  }

  String getCombinedRisk(int healthScore, int userAqi) {
    String healthRisk = healthScore <= 25
        ? "Low"
        : healthScore <= 50
            ? "Moderate"
            : healthScore <= 75
                ? "High"
                : "Critical";

    String aqiRisk = userAqi <= 50
        ? "Good"
        : userAqi <= 100
            ? "Moderate"
            : userAqi <= 150
                ? "Unhealthy for Sensitive Groups"
                : userAqi <= 200
                    ? "Unhealthy"
                    : userAqi <= 300
                        ? "Very Unhealthy"
                        : "Hazardous";

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

  String getRecommendation(String risk) {
    switch (risk) {
      case "Low":
        return "You are in good health and air quality is fine.";
      case "Moderate":
        return "Take precautions. Limit prolonged outdoor activity.";
      case "High":
        return "Reduce strenuous outdoor activities. Wear a mask.";
      case "Critical":
        return "Avoid outdoor exposure, use purifiers, seek medical help.";
    }
    return "";
  }

  

  Future<Uint8List> _capturePng() async {
    RenderRepaintBoundary boundary =
        _pdfKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _downloadReport() async {
    try {
      final pdf = pw.Document();
      final Uint8List capturedImage = await _capturePng();
      final pdfImage = pw.MemoryImage(capturedImage);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pdfImage));
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = io.File("${output.path}/Health_Report.pdf");
      await file.writeAsBytes(await pdf.save());
      OpenFilex.open(file.path);
    } catch (e) {
      debugPrint("Error generating PDF: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    final localCombined = (combinedRisk.isNotEmpty)
        ? combinedRisk
        : (userAqi != null
            ? getCombinedRisk(healthScore, userAqi!.toInt())
            : 'Unknown');
    final combinedRec = getRecommendation(localCombined);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Dashboard"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _downloadReport,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _pdfKey,
          child: Column(
            children: [
              // User Info Card at the top
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                margin: const EdgeInsets.only(bottom: 16),
                // decoration: BoxDecoration(
                //   color: Colors.white,
                //   borderRadius: BorderRadius.circular(20),
                //   boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                // ),
                child: Row(
                  children: [
                    // Profile image (placeholder if not available)
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.teal.shade100,
                      backgroundImage: AssetImage('assets/profile_placeholder.png'), // Replace with actual image if available
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            phone ?? 'No phone',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildAQICard(),
              const SizedBox(height: 16),
              _buildHealthAssessmentCard(),
              const SizedBox(height: 16),
              _buildCombinedRiskCard(localCombined, combinedRec),
            ],
          ),
        ),
      ),
    );
  }

  

  Widget _buildAQICard() {
  // Calculate percentage (safe between 0.0 and 1.0)
  double percent = (userAqi != null && userAqi! <= 500) ? (userAqi! / 500.0) : 0.0;

  // Map percentage to a color (Green -> Red)
  Color progressColor = Color.lerp(Colors.green, Colors.red, percent)!;

  return Container(
    
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.location_on, color: Colors.black),
          const SizedBox(width: 8),
          Expanded(
              child: Text(currentLocationName,
                  style: const TextStyle(color: Colors.black, fontSize: 16))),
        ]),
        const SizedBox(height: 12),
        Row(
          children: [
            CircularPercentIndicator(
              radius: 60,
              lineWidth: 10,
              percent: percent,
              center: Text(
                "${userAqi?.toStringAsFixed(0) ?? 'N/A'}",
                style: const TextStyle(color: Colors.black),
              ),
              progressColor: progressColor,
              backgroundColor: Colors.black12,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AQI Level: $userAqiStatus",
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  if (sensorId != null)
                    Text(
                      "You are near station: ${SensorNameMapper.displayName(sensorId!)}",
                      style: const TextStyle(color: Colors.black, fontSize: 14),
                    )
                  else
                    const Text(
                      "Nearest station: Unknown",
                      style: TextStyle(color: Colors.black, fontSize: 14),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


  String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

String capitalizeWords(String text) {
  return text.split(RegExp(r'[_\s]+')).map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1);
  }).join(' ');
}



  Widget _buildHealthAssessmentCard() {
  // Calculate percentage safely
    double percent = (healthScore.clamp(0, 100)) / 100.0;

    // Dynamic progress color (Green = good, Red = bad)
    Color progressColor = Color.lerp(Colors.green, Colors.red, percent)!;

    return Container(
     
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.black),
              SizedBox(width: 8),
              Text(
                "Health Assessment",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (questionnaireAnswers != null && questionnaireAnswers!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...questionnaireAnswers!.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.black54),
                        const SizedBox(width: 6),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "${capitalizeWords(e.key)}: ",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: capitalizeWords(e.value),
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.black26, thickness: 0.5),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircularPercentIndicator(
                radius: 60,
                lineWidth: 10,
                percent: percent,
                center: Text(
                  "$healthScore",
                  style: const TextStyle(color: Colors.black),
                ),
                progressColor: progressColor,
                backgroundColor: Colors.black12,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Risk Level: $riskLevel",
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedRiskCard(String localCombined, String combinedRec) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade300, Colors.red.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text("Combined Risk",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Text("Risk Level: $localCombined",
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 4),
          Text("Advice: $combinedRec",
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
