import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'forecast.dart';
import 'utils/sensor_name_mapper.dart';
import 'support.dart';
import 'config.dart'; 
import 'bottom_nav.dart';

class SensorMapPage extends StatefulWidget {
  final String? phone;
  const SensorMapPage({super.key, this.phone});

  @override
  State<SensorMapPage> createState() => _SensorMapPageState();
}

class _SensorMapPageState extends State<SensorMapPage> {
  GoogleMapController? mapController;
  LatLng? userLocation;
  bool isLoggedIn = false;
  String? phoneNumber;
  int _selectedIndex = 1;

  double? userAqi;
  String? userAqiStatus;

  final List<Map<String, dynamic>> sensors = [
    {"id": "lora-v1", "lat": 10.178322, "lng": 76.430891},
    {"id": "loradev2", "lat": 10.18220, "lng": 76.4285},
    {"id": "lora-v3", "lat": 10.17325, "lng": 76.42755}, // New sensor

  ];

  Map<String, dynamic> sensorAqi = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadLoginState();
    await _getUserLocation();
    await _fetchSensorAQI();
    if (isLoggedIn && userLocation != null) {
      await _fetchUserAQI(userLocation!.latitude, userLocation!.longitude);
    }
  }

  Future<void> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      phoneNumber = prefs.getString('phone');
    });
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      userLocation = LatLng(position.latitude, position.longitude);
    });
  }


Future<void> _fetchSensorAQI() async {
  try {
    debugPrint("📡 Fetching sensor AQI from: ${AppConfig.aqiSummary}");
    final response = await http.get(Uri.parse(AppConfig.aqiSummary));

    debugPrint("📥 Response [${response.statusCode}]: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        sensorAqi = data["data"];
      });
      debugPrint("✅ Sensor AQI updated: $sensorAqi");
    } else {
      debugPrint("❌ Failed to load AQI: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("❌ Error fetching AQI: $e");
  }
}

Future<void> _fetchUserAQI(double lat, double lon) async {
  try {
    final url = Uri.parse("${AppConfig.userAqi}?lat=$lat&lon=$lon");
    debugPrint("📡 Fetching User AQI from: $url");

    final response = await http.get(url);

    debugPrint("📥 User AQI Response [${response.statusCode}]: ${response.body}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        userAqi = (data["user_aqi"] != null) ? data["user_aqi"].toDouble() : null;
        userAqiStatus = data["status"];
      });
      debugPrint("✅ User AQI updated: $userAqi ($userAqiStatus)");
    } else if (response.statusCode == 404) {
      setState(() {
        userAqi = null;
        userAqiStatus = "No AQI data available - too far from sensors";
      });
      debugPrint("⚠️ No AQI data available (404)");
    } else {
      setState(() {
        userAqi = null;
        userAqiStatus = "Unable to fetch AQI";
      });
      debugPrint("❌ Failed User AQI request: ${response.statusCode}");
    }
  } catch (e) {
    setState(() {
      userAqi = null;
      userAqiStatus = "Error fetching AQI";
    });
    debugPrint("❌ Error fetching User AQI: $e");
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: 
          const Text("Sensor Map", style: TextStyle(color: Colors.white)),
      ),
      body: userLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: userLocation!,
                zoom: 14,
              ),
              onMapCreated: (controller) => mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: {
                Marker(
                  markerId: const MarkerId("user"),
                  position: userLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: InfoWindow(
                    title: "You",
                    snippet: isLoggedIn
                        ? (userAqi != null
                            ? "AQI: $userAqi ($userAqiStatus)"
                            : userAqiStatus ?? "Fetching AQI...")
                        : "Login to view AQI",
                  ),
                ),
                ...sensors.map((sensor) {
                  final String rawId = sensor["id"];
                  final String displayName = SensorNameMapper.displayName(rawId);

                  final sensorData = sensorAqi[rawId];
                  final int? aqi = sensorData?['aqi'];
                  final String? status = sensorData?['status'];

                  return Marker(
                    markerId: MarkerId(rawId),
                    position: LatLng(sensor["lat"], sensor["lng"]),
                    infoWindow: InfoWindow(
                      title: displayName,
                      snippet: aqi != null ? "AQI: $aqi ($status)" : "Loading AQI...",
                    ),
                  );
                }).toSet(),
              },
            ),
      // 
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        isLoggedIn: isLoggedIn,
        phone: widget.phone,
        showMenu: _showMenuOptions,
        onIndexChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),//bottomNavigationBar
    );
  }

  void _showMenuOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('AQI Forecast'),
              onTap: () async {
                Navigator.pop(bottomSheetContext);
                try {
                  Map<String, dynamic> forecastData = await fetchForecast();
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForecastDataPage(forecastData: forecastData,),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load forecast: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Support'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportPage()),
                );
              },
            ),
          ],
        );
      },
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
}