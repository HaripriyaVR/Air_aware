import 'dart:async';
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
import 'utils/sensor_name_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'otpsent.dart';
import 'otpsent.dart';
import 'side_panel.dart';

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
  bool _isLoggedIn = false;
  String? _phone;
  String? gender;
bool _loadingGender = true;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _checkLoginState();
    fetchUserData(); 
    getUserLocationAndFetchAQI();
  }

  

// Combined fetch
void fetchUserData() async {
  if (widget.phone == null) {
    print("Phone is null, cannot fetch user data.");
    return;
  }

  try {
    // 1️⃣ Try questionnaire first
    final questionnaireSnap = await FirebaseFirestore.instance
        .collection('questionnaire')
        .where('phone', isEqualTo: widget.phone)
        .get();

    if (questionnaireSnap.docs.isNotEmpty && mounted) {
      final data = questionnaireSnap.docs.first.data();
      print("Fetched from questionnaire: name=${data['name']}, gender=${data['gender']}");

      setState(() {
        gender = data['gender'];
        userName = data['name'] ?? 'User';
        _loadingGender = false;
      });
      return; // ✅ Stop here if found
    } else {
      print("No questionnaire entry found for ${widget.phone}");
    }

    // 2️⃣ Fallback: fetch from register collection
    final registerSnap = await FirebaseFirestore.instance
        .collection('register')
        .where('phone', isEqualTo: widget.phone)
        .get();

    if (registerSnap.docs.isNotEmpty && mounted) {
      final fetchedName = registerSnap.docs.first.data()['name'];
      print("Fetched from register: name=$fetchedName");

      setState(() {
        userName = fetchedName;
        _loadingGender = false;
      });
    } else {
      print("No document found in register collection for ${widget.phone}");
      setState(() => _loadingGender = false);
    }
  } catch (e) {
    print("Error fetching user data: $e");
    setState(() => _loadingGender = false);
  }
}



  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
  
  Future<void> _checkLoginState() async {
  final prefs = await SharedPreferences.getInstance();
  final loggedIn = prefs.getBool('isLoggedIn') ?? false;
  final phone = prefs.getString('phone');

  if (!loggedIn && mounted) {
    // show dialog after frame renders
    Future.delayed(Duration.zero, () => _showLoginRequiredDialog());
  }

  if (mounted) {
    setState(() {
      _isLoggedIn = loggedIn;
      _phone = phone;
    });
  }
}

  Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  setState(() {
    _isLoggedIn = false;
    _phone = null;
  });

  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }
}

void _showLoginRequiredDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text("Login Required"),
      content: const Text("You need to log in to view your profile."),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // close the dialog
            // navigate to login page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()), // your login widget
            );
          },
          child: const Text("Go to Login"),
        ),
      ],
    ),
  );
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
  if (!_isLoggedIn) {
    // Show loading while redirecting
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return MainScaffold(
    phone: widget.phone,
    currentIndex: 3,
    body: Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: SidePanel(
        isLoggedIn: _isLoggedIn,
        phoneNumber: _phone,
        onLogout: logout,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
  child: Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black26, width: 2),
      image: DecorationImage(
        image: AssetImage(
          _loadingGender
              ? "assets/icon/male.png"  // placeholder until gender loads
              : (gender == 'Female'
                  ? "assets/icon/female.png"
                  : "assets/icon/male.png"),
        ),
        fit: BoxFit.cover,
      ),
    ),
  ),
),

            const SizedBox(height: 12),
            Text(
              "Hi, $userName 👋",
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (currentLocationName != null)
              Text(
                "📍 Your Location: $currentLocationName",
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
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
