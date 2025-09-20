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
import 'package:geocoding/geocoding.dart';

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

  // Move these inside the State class
  List<Map<String, dynamic>> filteredSensors = [];
  String searchQuery = "";

  final TextEditingController searchController = TextEditingController();
  bool _snackBarShown = false; // Add this to your state class

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

// 🔎 Search function
void _searchSensors(String query) async {
  setState(() {
    searchQuery = query.trim();
    if (query.isEmpty) {
      filteredSensors = [];
      _snackBarShown = false;
      return;
    }

    filteredSensors = sensors.where((sensor) {
      final displayName = SensorNameMapper.displayName(sensor["id"]);
      return displayName.toLowerCase().contains(query.toLowerCase());
    }).toList();
  });

  // If no sensors found → show place on map and notify only once
  if (filteredSensors.isEmpty && !_snackBarShown) {
    _snackBarShown = true;
    // Try to geocode the place name
    try {
      List<Location> locations = await locationFromAddress(searchQuery);
      if (locations.isNotEmpty && mapController != null) {
        final loc = locations.first;
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(loc.latitude, loc.longitude), 16),
        );
      }
    } catch (e) {
      // Geocoding failed, do nothing
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("sensors are not available here")),
      );
    }
  } else if (filteredSensors.isNotEmpty) {
    _snackBarShown = false;
  }
}

// 🎯 Focus on a selected sensor
void _focusOnSensor(Map<String, dynamic> sensor) {
  final position = LatLng(sensor["lat"], sensor["lng"]);
  mapController?.animateCamera(
    CameraUpdate.newLatLngZoom(position, 16),
  );
  setState(() {
    filteredSensors = []; // Hide dropdown
    searchQuery = ""; // 🔥 this hides the container
    searchController.clear(); // <-- Clear the search field
  });
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
        // backgroundColor: Colors.blue,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        elevation: 4, // shadow
        title: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchController, // <-- controller is bound here
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: "Search sensors...",
                    border: InputBorder.none,
                    isCollapsed: true, // tighter fit
                  ),
                  onChanged: _searchSensors,
                ),
              ),
            ],
          ),
        ),
      ),

      body: userLocation == null
    ? const Center(child: CircularProgressIndicator())
    : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: userLocation!,
              zoom: 14,
            ),
            onMapCreated: (controller) => mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: {
              // User marker
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
              // Sensor markers
              ...sensors.map((sensor) {
                final String rawId = sensor["id"];
                final String displayName = SensorNameMapper.displayName(rawId);

                final sensorData = sensorAqi[rawId];
                final dynamic aqiValue = sensorData?['aqi'];
                final int? aqi = (aqiValue is int) ? aqiValue : null;
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

          // 🔽 Dropdown suggestion box
          if ((filteredSensors != null && filteredSensors.isNotEmpty) || (searchQuery != null && searchQuery.isNotEmpty))
            Positioned(
              top: kToolbarHeight + 4,
              left: 12,
              right: 12,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Always show searched place
                    ListTile(
                      leading: const Icon(Icons.place, color: Colors.blue),
                      title: Text(searchQuery ?? ""),
                      onTap: () async {
                        // Always move map to searched place when tapped
                        try {
                          List<Location> locations = await locationFromAddress(searchQuery);
                          if (locations.isNotEmpty && mapController != null) {
                            final loc = locations.first;
                            mapController!.animateCamera(
                              CameraUpdate.newLatLngZoom(LatLng(loc.latitude, loc.longitude), 16),
                            );
                          }
                        } catch (e) {
                          // Geocoding failed, do nothing
                        }
                        // Show message only once (already handled in _searchSensors)
                      },
                    ),
                    // Show matching sensors
                    ...(filteredSensors ?? []).map((sensor) {
                      final displayName = SensorNameMapper.displayName(sensor["id"]);
                      return ListTile(
                        leading: const Icon(Icons.sensors),
                        title: Text(displayName),
                        onTap: () => _focusOnSensor(sensor),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
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