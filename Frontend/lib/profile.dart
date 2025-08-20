
/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'questions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class ProfilePage extends StatefulWidget {
  final String phone;
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

  Future<void> getUserLocationAndFetchAQI() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled.");
      }

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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await fetchAQI(position.latitude, position.longitude);
    } catch (e) {
      print("Location error: $e");
    }
  }

  Future<void> fetchAQI(double lat, double lon) async {
    final url = Uri.parse('http://localhost:5000/user-aqi?lat=$lat&lon=$lon'); // <-- Replace with your backend IP

    try {
      final response = await http.get(url); // Use GET request

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          aqi = (data["user_aqi"] != null) ? data["user_aqi"].toDouble() : null;
          aqiStatus = data["status"];
        });
      } else {
        print("Failed to fetch AQI: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching AQI: $e");
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Padding(
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
              onTap: () {},
            ),
            buildProfileCard(
              icon: Icons.group_add,
              title: "Add Family",
              color: Colors.green.shade100,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
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
// profile.dart
import 'dart:async';
//import 'package:aqmapp/health_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'questions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'main_scaffold.dart';
import 'healthreport.dart';

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

    // Use your actual deployed backend URL here
    final url = Uri.parse('http://192.168.43.104:5000/user-aqi?lat=$lat&lon=$lon');
    print("[Profile] Attempting to fetch AQI from: ${url.toString()}");
    print("[Profile] Location coordinates: lat=$lat, lon=$lon");

    try {
      print("[Profile] Sending GET request...");
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      ).timeout(
        const Duration(seconds: 30),  // Increased timeout
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
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
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
            icon: Icons.group_add,
            title: "Add Family",
            color: Colors.green.shade100,
            onTap: () {},
          ),
        ],
      ),
    ),
    ),
  );
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
