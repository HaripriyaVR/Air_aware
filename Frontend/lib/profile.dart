/*import 'dart:async';
import 'package:aqmapp/forecast.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'questions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'main_scaffold.dart';
import 'healthreport.dart';
import 'config.dart';


class ProfilePage extends StatefulWidget {
  final String? phone;
  const ProfilePage({required this.phone, Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = '';
  double? aqi;
  String? aqiStatus;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    getUserLocationAndFetchAQI();
     
  }

  void fetchUserData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: widget.phone)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        userName = data['name'];
      });
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> getUserLocationAndFetchAQI() async {
    if (_isDisposed) return;

    try {
      print("[Profile] Checking location services...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("[Profile] Location services are disabled");
        throw Exception("Location services are disabled.");
      }

      print("[Profile] Checking location permission...");
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print("[Profile] Requesting location permission...");
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("[Profile] Location permission denied");
          throw Exception("Location permission denied.");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permission permanently denied.");
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!_isDisposed) {
        await fetchAQI(position.latitude, position.longitude);
      }
    } catch (e) {
      if (!_isDisposed) {
        print("Location error: $e");
      }
    }
  }

  Future<void> fetchAQI(double lat, double lon) async {
  if (_isDisposed) return;

  // ✅ Use AppConfig + API route
  final String baseUrl = AppConfig.baseUrl; 
  const String endpoint = "/api/user-aqi"; // ✅ API prefixed route
  final url = Uri.parse("$baseUrl$endpoint?lat=$lat&lon=$lon");

  print("[Profile] Attempting to fetch AQI from: ${url.toString()}");
  print("[Profile] Location coordinates: lat=$lat, lon=$lon");

  try {
    print("[Profile] Sending GET request...");
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
      },
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        print("[Profile] Request timed out after 30 seconds");
        throw TimeoutException('AQI request timed out');
      },
    );

    print("[Profile] Response status code: ${response.statusCode}");
    print("[Profile] Response headers: ${response.headers}");
    print("[Profile] Response body: ${response.body}");

    if (_isDisposed) return;

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          aqi = (data["user_aqi"] != null) ? data["user_aqi"].toDouble() : null;
          aqiStatus = data["status"];
        });
        print("[Profile] Successfully fetched AQI: $aqi ($aqiStatus)");
      }
    } else if (response.statusCode == 404) {
      print("[Profile] No AQI data available: ${response.body}");
      if (mounted) {
        setState(() {
          aqi = null;
          aqiStatus = "No AQI data available - You are too far from our sensors";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No AQI data available for your location. You must be within 2km of a sensor."),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } else {
      print("[Profile] Failed to fetch AQI: ${response.statusCode}");
      if (response.body.isNotEmpty) {
        print("[Profile] Response body: ${response.body}");
      }
      if (mounted) {
        setState(() {
          aqi = null;
          aqiStatus = "Unable to fetch AQI data";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch AQI data: HTTP ${response.statusCode}")),
        );
      }
    }
  } catch (e) {
    if (!_isDisposed) {
      print("[Profile] Error fetching AQI: $e");
      if (mounted) {
        setState(() {
          aqiStatus = "Error fetching AQI data";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching AQI data: ${e.toString()}")),
        );
      }
    }
  }
}


  Color getAqiColor(double aqi) {
    if (aqi <= 50) return Colors.green.shade100;
    if (aqi <= 100) return Colors.yellow.shade100;
    if (aqi <= 200) return Colors.orange.shade100;
    if (aqi <= 300) return Colors.red.shade100;
    if (aqi <= 400) return Colors.purple.shade100;
    return Colors.brown.shade100;
  }


@override
Widget build(BuildContext context) {
  return MainScaffold(
    phone: widget.phone,
    currentIndex: 3, // 👈 set this to the correct index for Profile in your BottomNavigationBar
    body: Scaffold(
      appBar: AppBar(
  title: const Icon(
    Icons.person, // 👈 Profile icon
    color: Colors.black,
    size: 28,
  ),
  centerTitle: true,
  backgroundColor: Colors.white,
  elevation: 0,
),

    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hi, $userName 👋",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (aqi != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: getAqiColor(aqi!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.air, size: 30, color: Colors.black),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your AQI: ${aqi!.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      if (aqiStatus != null)
                        Text(
                          'Status: $aqiStatus',
                          style: const TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          buildProfileCard(
            icon: Icons.edit,
            title: "Health Update",
            color: Colors.orange.shade100,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuestionnairePage(
                    phone: widget.phone,
                    isEditing: true,
                  ),
                ),
              );
            },
          ),
          buildProfileCard(
            icon: Icons.analytics,
            title: "Health Report",
            color: Colors.blue.shade100,
            onTap: () {
              if (widget.phone != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HealthProfilePage(),
                  ),
                );
              }
            },
          ),
          buildProfileCard(
  icon: Icons.trending_up,
  title: "Forecast Data",
  color: Colors.green.shade100,
  onTap: () async {
    try {
      // show a loading spinner while fetching
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // fetch forecast only on click
      final data = await fetchForecast();

      // close loading dialog
      Navigator.pop(context);

      // navigate with fetched forecast
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ForecastDataPage(
            forecastData: data,
            phone: widget.phone,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load forecast: $e")),
      );
    }
  },
),


        ],
      ),
    ),
    ),
  );
}

Future<Map<String, dynamic>> fetchForecast() async {
  final response = await http.get(
    Uri.parse('${AppConfig.baseUrl}/api/forecast'), // ✅ API route
  );

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);

    // Build a new map of forecasts for each sensor
    final Map<String, dynamic> forecasts = {};

    data.forEach((sensor, sensorData) {
      final List<dynamic> rawForecast = sensorData['forecast'] ?? [];

      final List<Map<String, dynamic>> filteredForecast = rawForecast
          .where((item) =>
              !(item['day'].toString().toLowerCase().contains('today') ||
                item['day'].toString().toLowerCase().contains('tomorrow')))
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();

      forecasts[sensor] = {
        'forecast': filteredForecast,
        'updated_at': sensorData['updated_at'],
      };
    });

    return forecasts;
  } else {
    throw Exception('Failed to fetch forecast data');
  }
}


Widget buildProfileCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      color: color,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.black),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}*/
import 'dart:async';
import 'package:aqmapp/forecast.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'questions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'main_scaffold.dart';
import 'healthreport.dart';
import 'config.dart';
import 'utils/sensor_name_mapper.dart';

class ProfilePage extends StatefulWidget {
  final String? phone;
  const ProfilePage({required this.phone, Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = '';
  double? aqi;
  String? aqiStatus;
  String? closestSensor;
  double? sensorDistance;
  String? currentLocationName;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    getUserLocationAndFetchAQI();
  }

  void fetchUserData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: widget.phone)
        .get();

    if (snapshot.docs.isNotEmpty && !_isDisposed && mounted) {
      setState(() {
        userName = snapshot.docs.first.data()['name'];
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }


  // 1️⃣ Replace the reverse geocoding call inside your function:
Future<void> getUserLocationAndFetchAQI() async {
  if (_isDisposed) return;

  try {
    // ✅ Ensure location is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Location services are disabled.");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        throw Exception("Location denied.");
    }
    if (permission == LocationPermission.deniedForever)
      throw Exception("Location permanently denied.");

    // ✅ Get GPS coordinates
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // ✅ Reverse geocode with LocationIQ
    String locationName = await getLocationNameFromLocationIQ(
        position.latitude, position.longitude);

    if (mounted) {
      setState(() {
        currentLocationName = locationName;
      });
    }

    if (!_isDisposed) {
      await fetchAQI(position.latitude, position.longitude);
    }
  } catch (e) {
    if (!_isDisposed && mounted) {
      print("Location error: $e");
      setState(() {
        currentLocationName = "Unable to fetch location (${e.toString()})";
      });
    }
  }
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

      // 1️⃣ Exact Place — now covers more fields
      final String exactPlace = address['building'] ??
          address['amenity'] ??
          address['landmark'] ??
          address['shop'] ??
          address['place'] ??
          address['neighbourhood'] ??
          address['suburb'] ??
          address['residential'] ??
          address['road'] ??
          '';

      // 2️⃣ City / town / village
      final String city = address['city'] ??
          address['town'] ??
          address['village'] ??
          address['municipality'] ??
          address['hamlet'] ??
          '';

      // 3️⃣ District
      final String district = address['county'] ??
          address['state_district'] ??
          address['district'] ??
          address['region'] ??
          '';

      // 4️⃣ State
      final String state = address['state'] ?? '';

      // join parts skipping empty
      String shortName = [exactPlace, city, district, state]
          .where((e) => e.isNotEmpty)
          .join(', ');

      print("📍 Full Address: ${data['display_name']}");
      print("📍 Short Address: $shortName");

      return shortName.isNotEmpty
          ? shortName
          : data['display_name'] ?? '$lat, $lon';
    } else {
      print("⚠️ LocationIQ failed with status code ${response.statusCode}");
      return '$lat, $lon';
    }
  } catch (e) {
    print("❌ LocationIQ reverse geocoding failed: $e");
    return '$lat, $lon';
  }
}






  Future<void> fetchAQI(double lat, double lon) async {
    if (_isDisposed) return;

    final String baseUrl = AppConfig.baseUrl;
    const String endpoint = "/api/user-aqi";
    final url = Uri.parse("$baseUrl$endpoint?lat=$lat&lon=$lon");

    try {
      final response = await http.get(url, headers: {'Accept': 'application/json'}).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('AQI request timed out'),
          );

      if (_isDisposed) return;

    

// inside fetchAQI()
if (response.statusCode == 200) {
  final data = json.decode(response.body);
  if (mounted) {
    setState(() {
      aqi = (data["user_aqi"] != null) ? data["user_aqi"].toDouble() : null;
      aqiStatus = data["status"];

      // map sensor id to friendly station name
      final sensorId = data["closest_sensor"]?["sensor_id"];
      closestSensor = sensorId != null
          ? SensorNameMapper.displayName(sensorId)
          : null;

      sensorDistance = data["closest_sensor"]?["distance_km"]?.toDouble();
    });
  }
}
 else {
        if (mounted) {
          setState(() {
            aqi = null;
            aqiStatus = "Unable to fetch AQI data";
            closestSensor = null;
            sensorDistance = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Failed to fetch AQI data: HTTP ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          aqiStatus = "Error fetching AQI data";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching AQI data: ${e.toString()}")),
        );
      }
    }
  }

  Color getAqiColor(double aqi) {
    if (aqi <= 50) return Colors.green.shade100;
    if (aqi <= 100) return Colors.yellow.shade100;
    if (aqi <= 200) return Colors.orange.shade100;
    if (aqi <= 300) return Colors.red.shade100;
    if (aqi <= 400) return Colors.purple.shade100;
    return Colors.brown.shade100;
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      phone: widget.phone,
      currentIndex: 3,
      body: Scaffold(
        appBar: AppBar(
          title: const Icon(Icons.person, color: Colors.black, size: 28),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi, $userName 👋",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (currentLocationName != null)
                Text(
                  "📍 Your Location: $currentLocationName",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              const SizedBox(height: 10),
              if (aqi != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: getAqiColor(aqi!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.air, size: 30, color: Colors.black),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'User AQI: ${aqi!.toStringAsFixed(1)} ($aqiStatus)',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (closestSensor != null && sensorDistance != null)
                        Text(
                          'Closest sensor: $closestSensor (${sensorDistance!.toStringAsFixed(2)} km away)',
                          style: const TextStyle(fontSize: 14),
                        )
                      else
                        const Text(
                          'No sensor nearby — AQI estimated from nearest sensors',
                          style: TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ),
              buildProfileCard(
                icon: Icons.edit,
                title: "Health Update",
                color: Colors.orange.shade100,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestionnairePage(
                        phone: widget.phone,
                        isEditing: true,
                      ),
                    ),
                  );
                },
              ),
              buildProfileCard(
                icon: Icons.analytics,
                title: "Health Report",
                color: Colors.blue.shade100,
                onTap: () {
                  if (widget.phone != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HealthProfilePage(),
                      ),
                    );
                  }
                },
              ),
              buildProfileCard(
                icon: Icons.trending_up,
                title: "Forecast Data",
                color: Colors.green.shade100,
                onTap: () async {
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    final data = await fetchForecast();
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ForecastDataPage(
                          forecastData: data,
                          phone: widget.phone,
                        ),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to load forecast: $e")),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchForecast() async {
    final response =
        await http.get(Uri.parse('${AppConfig.baseUrl}/api/forecast'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final Map<String, dynamic> forecasts = {};

      data.forEach((sensor, sensorData) {
        final List<dynamic> rawForecast = sensorData['forecast'] ?? [];

        final List<Map<String, dynamic>> filteredForecast = rawForecast
            .where((item) =>
                !(item['day']
                        .toString()
                        .toLowerCase()
                        .contains('today') ||
                  item['day']
                      .toString()
                      .toLowerCase()
                      .contains('tomorrow')))
            .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item))
            .toList();

        forecasts[sensor] = {
          'forecast': filteredForecast,
          'updated_at': sensorData['updated_at'],
        };
      });

      return forecasts;
    } else {
      throw Exception('Failed to fetch forecast data');
    }
  }

  Widget buildProfileCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      color: color,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.black),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
