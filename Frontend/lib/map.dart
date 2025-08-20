/*import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'livegas.dart';
import 'profile.dart';
import 'utils/sensor_name_mapper.dart';


class SensorMapPage extends StatefulWidget {
  final String? phone;
  const SensorMapPage({super.key, this.phone});

  @override
  State<SensorMapPage> createState() => _SensorMapPageState();
}

class _SensorMapPageState extends State<SensorMapPage> {
  GoogleMapController? mapController;
  Location location = Location();
  LatLng? userLocation;
  bool isLoggedIn = false;
  String? phoneNumber;

  final List<Map<String, dynamic>> sensors = [
    {
      "id": "lora-v1",
      "lat": 10.178385739668958,
      "lng": 76.43052237497399,
    },
    {
      "id": "loradev2",
      "lat": 10.17095090340159,
      "lng": 76.42962876824544,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLoginState();
    _getUserLocation();
  }

  Future<void> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      phoneNumber = prefs.getString('phone');
    });
  }

  Future<void> _getUserLocation() async {
    final hasPermission = await location.hasPermission();
    if (hasPermission == PermissionStatus.denied) {
      await location.requestPermission();
    }

    final locData = await location.getLocation();
    setState(() {
      userLocation = LatLng(locData.latitude!, locData.longitude!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sensor Map"),
        
      ),
      body: userLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: userLocation!,
                zoom: 14,
              ),
              onMapCreated: (controller) {
                mapController = controller;
              },
              /*markers: {
                Marker(
                  markerId: const MarkerId("user"),
                  position: userLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(title: "You"),
                ),
                ...sensors.map((sensor) {
                  return Marker(
                    markerId: MarkerId(sensor["id"]),
                    position: LatLng(sensor["lat"], sensor["lng"]),
                    infoWindow: InfoWindow(title: sensor["id"]),
                  );
                }).toSet(),
              },*/
              markers: {
  Marker(
    markerId: const MarkerId("user"),
    position: userLocation!,
    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    infoWindow: const InfoWindow(title: "You"),
  ),
  ...sensors.map((sensor) {
    final String rawId = sensor["id"];
    final String displayName = SensorNameMapper.displayName(rawId); // ✅ mapped name
    return Marker(
      markerId: MarkerId(rawId),
      position: LatLng(sensor["lat"], sensor["lng"]),
      infoWindow: InfoWindow(title: displayName),
    );
  }).toSet(),
},

            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
          const BottomNavigationBarItem(icon: Icon(Icons.devices), label: "Devices"),
          if (isLoggedIn)
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          const BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => AQIDashboardPage(phone: widget.phone),
            ));
          } else if (index == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => LiveGasPage(phone: widget.phone),
            ));
          } else if (isLoggedIn && index == 3) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfilePage(phone: phoneNumber ?? "Unknown"),
            ));
          } else if (index == (isLoggedIn ? 4 : 3)) {
            // Show menu options
          }
        },
      ),
    );
  }
}*/
/*import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

import 'home.dart';
import 'livegas.dart';
import 'profile.dart';
import 'utils/sensor_name_mapper.dart';

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

  final List<Map<String, dynamic>> sensors = [
    {"id": "lora-v1", "lat": 10.178385739668958, "lng": 76.43052237497399},
    {"id": "loradev2", "lat": 10.17095090340159, "lng": 76.42962876824544},
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

  // Check if location services are enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled, you may show a dialog to the user
    return;
  }

  // Check permission
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever
    return;
  }

  // Get current position
  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  setState(() {
    userLocation = LatLng(position.latitude, position.longitude);
  });
}

  Future<void> _fetchSensorAQI() async {
    try {
      final response =
          await http.get(Uri.parse("http://172.29.255.104:5000/aqi"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          sensorAqi = data;
        });
      } else {
        debugPrint("❌ Failed to load AQI: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching AQI: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sensor Map")),
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
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(title: "You"),
                ),
                ...sensors.map((sensor) {
                  final String rawId = sensor["id"];
                  final String displayName =
                      SensorNameMapper.displayName(rawId);

                  final sensorData = sensorAqi[rawId];
                  final int? aqi = sensorData?['aqi'];
                  final String? status = sensorData?['status'];

                  return Marker(
                    markerId: MarkerId(rawId),
                    position: LatLng(sensor["lat"], sensor["lng"]),
                    infoWindow: InfoWindow(
                      title: displayName,
                      snippet: aqi != null
                          ? "AQI: $aqi ($status)"
                          : "Loading AQI...",
                    ),
                  );
                }).toSet(),
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.devices), label: "Devices"),
          if (isLoggedIn)
            const BottomNavigationBarItem(
                icon: Icon(Icons.person), label: "Profile"),
          const BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => AQIDashboardPage(phone: widget.phone)),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => LiveGasPage(phone: widget.phone)),
            );
          } else if (isLoggedIn && index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ProfilePage(phone: phoneNumber ?? "Unknown")),
            );
          } else if (index == (isLoggedIn ? 4 : 3)) {
            // TODO: Open menu bottom sheet
          }
        },
      ),
    );
  }
}*/
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'main_scaffold.dart';
import 'utils/sensor_name_mapper.dart';

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

  final List<Map<String, dynamic>> sensors = [
    {"id": "lora-v1", "lat": 10.178385739668958, "lng": 76.43052237497399},
    {"id": "loradev2", "lat": 10.17095090340159, "lng": 76.42962876824544},
  ];

  Map<String, dynamic> sensorAqi = {};
  int? userAqi; 
  String? userAqiStatus;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadLoginState();
    await _getUserLocation();
    await _fetchSensorAQI();
    if (userLocation != null) {
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
      final response =
          await http.get(Uri.parse("http://192.168.43.104:5000/aqi"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          sensorAqi = data;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching AQI: $e");
    }
  }

  Future<void> _fetchUserAQI(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse("http://192.168.43.104:5000/user-aqi?lat=$lat&lon=$lon"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userAqi = data["user_aqi"];
          userAqiStatus = data["status"];
        });
      } else {
        debugPrint("❌ Failed to fetch user AQI: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching user AQI: $e");
    }
  }

 @override
Widget build(BuildContext context) {
  return MainScaffold(
    phone: isLoggedIn ? phoneNumber : null,
    currentIndex: 1, // Map tab selected
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
              // ✅ User marker with AQI
              Marker(
                markerId: const MarkerId("user"),
                position: userLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure),
                infoWindow: InfoWindow(
                  title: "You",
                  snippet: isLoggedIn
                      ? (userAqi != null
                          ? "Your AQI: $userAqi ($userAqiStatus)"
                          : "Loading your AQI...")
                      : "Login to view your AQI",
                ),
              ),

              // ✅ Sensor markers
              ...sensors.map((sensor) {
                final String rawId = sensor["id"];
                final String displayName =
                    SensorNameMapper.displayName(rawId);

                final sensorData = sensorAqi[rawId];
                final int? aqi = sensorData?['aqi'];
                final String? status = sensorData?['status'];

                return Marker(
                  markerId: MarkerId(rawId),
                  position: LatLng(sensor["lat"], sensor["lng"]),
                  infoWindow: InfoWindow(
                    title: displayName,
                    snippet: aqi != null
                        ? "AQI: $aqi ($status)"
                        : "Loading AQI...",
                  ),
                );
              }).toSet(),
            },
          ),
  );
}
}