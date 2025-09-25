import 'dart:convert';
import 'dart:math' show cos, sin, sqrt, atan2, pi;
import 'package:aqmapp/otpsent.dart';
import 'package:aqmapp/forecast.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile.dart';
import 'livegas.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/sensor_name_mapper.dart';
import 'support.dart';
import 'config.dart';
import 'admin/login.dart';
import 'bottom_nav.dart';
import 'background_design.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Example usage inside a widget


class AQIDashboardPage extends StatefulWidget {
  final String? phone;
  const AQIDashboardPage({super.key, this.phone});

  @override
  State<AQIDashboardPage> createState() => _AQIDashboardPageState();
}

class _AQIDashboardPageState extends State<AQIDashboardPage> {
  // ✅ Now dynamic
  static const String _endpoint = '/api/realtime'; // updated to API route
  bool isLoggedIn = false;
  String? phoneNumber;
  Position? currentLocation;
  int _selectedIndex = 0;
  String? userName; 

  final Map<String, Map<String, double>> _sensorLocations = {
    'lora-v1': {'lat': 10.178322, 'lon': 76.430891},
    'loradev2': {'lat': 10.18220, 'lon': 76.4285},
    'lora-v3': {'lat': 10.17325, 'lon': 76.42755} // Example coordinates for new sensor
  };
  
  Future<Map<String, dynamic>?>? _aqiFuture;
  Map<String, dynamic> sensorAqi = {};

  @override
  void initState() {
    super.initState();
    _aqiFuture = _fetchRealtimeAQI();
    _loadLoginState();
    _fetchSensorAQI();
  }

  Future<void> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      phoneNumber = prefs.getString('phone');
    });
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      isLoggedIn = false;
      phoneNumber = null;
    });

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<String?> _getUserNameByPhone(String phone) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('register')
      .where('phone', isEqualTo: phone)
      .limit(1)
      .get();

  if (snapshot.docs.isNotEmpty) {
    final data = snapshot.docs.first.data();
    // Safely get 'name'
    if (data.containsKey('name') && data['name'] != null) {
      return data['name'] as String;
    }
  }
  return null;
}

  Future<Position?> getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Location services are disabled.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Location permission not granted.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Location permission permanently denied.');
      return null;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    print('✅ Location fetched: ${position.latitude}, ${position.longitude}');
    return position;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  
  Future<String?> _getClosestSensor(Position pos) async {
  String? closest;
  double minDist = double.infinity;

  _sensorLocations.forEach((id, sensorPos) {
    final d = _distanceKm(
      pos.latitude,
      pos.longitude,
      sensorPos['lat']!,
      sensorPos['lon']!,
    );
    debugPrint(
      '[DISTANCE] Sensor: ${SensorNameMapper.displayName(id)} ($id), '
      'Distance: ${d.toStringAsFixed(3)} km',
    );
    if (d < minDist) {
      minDist = d;
      closest = id;
    }
  });

  debugPrint('[INFO] Closest sensor is ${SensorNameMapper.displayName(closest!)} '
             'at ${minDist.toStringAsFixed(3)} km');
  return closest; // ✅ Always return closest, no 2 km constraint
}



  Future<Map<String, dynamic>?> _fetchRealtimeAQI() async {
  try {
    Position? userLocation = currentLocation ?? await getUserLocation();
    if (userLocation == null) {
      debugPrint('[AQI] Could not get user location');
      return null;
    }

    if (currentLocation == null) {
      setState(() {
        currentLocation = userLocation;
      });
    }

    String? sensorId = await _getClosestSensor(userLocation);
    if (sensorId == null) {
      debugPrint('[AQI] No nearby sensors found');
      return null;
    }

    // ✅ Correct place to build URI and call API
    final uri = Uri.parse("${AppConfig.realtime}?sensor_id=$sensorId");
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      debugPrint('[AQI] API request failed: ${response.statusCode}');
      return null;
    }

    final data = jsonDecode(response.body);

    if (data["success"] != true) {
      debugPrint('[AQI] Backend error: ${data["message"]}');
      return null;
    }

    Map<String, dynamic> sensorData = Map<String, dynamic>.from(data["data"]);

    sensorData['sensorId'] = sensorId;
    sensorData['sensorName'] = SensorNameMapper.displayName(sensorId);

    Map<String, dynamic> readings = sensorData['readings'] as Map<String, dynamic>? ?? {};
    sensorData['temp'] = readings['temp']?.toString() ?? 'N/A';
    sensorData['hum'] = readings['hum']?.toString() ?? 'N/A';
    sensorData['pre'] = readings['pre']?.toString() ?? 'N/A';

    debugPrint('[AQI] Successfully fetched data → ${sensorData['sensorName']}');
    return sensorData;
  } catch (e) {
    debugPrint('[AQI] Error fetching AQI: $e');
    return null;
  }
}


Future<void> _fetchSensorAQI() async {
  try {
    debugPrint("📡 Fetching sensor AQI from: ${AppConfig.aqiSummary}");
    final response = await http.get(Uri.parse(AppConfig.aqiSummary));

    debugPrint("📥 Response [${response.statusCode}]: ${response.body}");

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      if (json['success'] == true && json['data'] != null) {
        final Map<String, dynamic> rawData =
            Map<String, dynamic>.from(json['data']);

        // 🔹 Build a new map with both sensorId and stationName
        final Map<String, dynamic> mappedData = {};

        rawData.forEach((sensorId, sensorData) {
          final displayName = SensorNameMapper.displayName(sensorId);
          final updatedSensorData = Map<String, dynamic>.from(sensorData);

          updatedSensorData['sensorId'] = sensorId;
          updatedSensorData['sensorName'] = displayName;

          mappedData[sensorId] = updatedSensorData;
        });

        setState(() {
          sensorAqi = mappedData;
        });

        debugPrint("✅ Sensor AQI updated with station names: $sensorAqi");
      } else {
        debugPrint("❌ Backend error or missing data");
      }
    } else {
      debugPrint("❌ Failed to load AQI: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("❌ Error fetching AQI: $e");
  }
}



Future<void> _refresh() async {
  if (!mounted) return;
  setState(() {
    currentLocation = null;
    _aqiFuture = _fetchRealtimeAQI();
  });
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor:  Colors.teal,
      elevation: 1,
      centerTitle: true,
      title: const Text("Air Aware", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily:'poppins-light')),
      iconTheme: const IconThemeData(color: Colors.black),
      // 🔹 Remove leading admin button here
    ),

    // 🔹 Add the Drawer here
    drawer: _buildSidePanel(context),

      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Stack(
          children: [
            const BackgroundDesign(), // ✅ background separated

            // Page content
            Center(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _aqiFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    debugPrint('[AQI] Using dummy data');
                    return _buildDashboardUI(dummyData);
                  }
                  return _buildDashboardUI(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),


     
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
      ),
    );
  }

  /// ✅ All unpacking and UI lives here
Widget _buildDashboardUI(Map<String, dynamic> data) {
  final int aqi = data['aqi'] ?? 0;
  final String status = data['status'] ?? "Unknown";
  final String sensorId = data['sensorId'] ?? "Unknown Sensor";
  final String displaySensor = SensorNameMapper.displayName(sensorId);

  final String time = data['time'] ?? "N/A";
  final String temp = data['temp']?.toString() ?? "N/A";
  final String hum = data['hum']?.toString() ?? "N/A";
  final String pre = data['pre']?.toString() ?? "N/A";

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // ------------------home page content design start here-------------------------------
        children: [
          const Text(
                    "Your Location :",
                    style: TextStyle(color: Colors.black54,fontSize: 16, fontFamily:'poppins'),
                  ),
                Text(
                    displaySensor,
                    style: const TextStyle( fontSize: 20, fontFamily:'poppins',fontWeight: FontWeight.bold)
                    ),
          const SizedBox(height: 20),
           // AQI Status + Value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("Air Quality is", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  Container(
                    width: 142,
                    height: 52,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, 
                      vertical: 6
                    ),
                    decoration: BoxDecoration(
                      color: _aqiColor(aqi),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        // color: _aqiColor(aqi),
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 10),
                      SizedBox(width: 4),
                      Text("Live AQI"),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$aqi',
                    style: TextStyle(
                      fontSize: 68,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          

          const SizedBox(height: 24),
          _buildAqiGradientBar(context, aqi),
          const SizedBox(height: 24),
          _buildWeatherCard(temp, hum, pre),
          const SizedBox(height: 20),
          Center(
  child: Text(
    "Last Update:  $time",
    style: const TextStyle(color: Colors.grey),
  ),
),
          const SizedBox(height: 20),
        _buildStationRanking(context),
        const SizedBox(height: 20),
        buildInfoCardsSection(),
        ],
      ),
  );
}



  Widget _buildAqiGradientBar(BuildContext context, int aqi) {
  final levels = [
    {"label": "Good", "color": Colors.green, "min": 0.0, "max": 50.0},
    {"label": "Satisfactory", "color": Colors.yellow, "min": 51.0, "max": 100.0},
    {"label": "Moderate", "color": Colors.orange, "min": 101.0, "max": 200.0},
    {"label": "Poor", "color": Colors.red, "min": 201.0, "max": 300.0},
    {"label": "Very Poor", "color": Colors.purple, "min": 301.0, "max": 400.0},
    {"label": "Severe", "color": Colors.brown, "min": 401.0, "max": 500.0},
  ];

  const double totalRange = 500.0;
  final double barWidth = MediaQuery.of(context).size.width - 32;

  List<Color> colors = [];
  List<double> stops = [];
  double accumulated = 0.0;

  for (var level in levels) {
    final double min = level['min'] as double;
    final double max = level['max'] as double;
    final double span = max - min;

    colors.add(level['color'] as Color);
    stops.add(accumulated / totalRange);
    accumulated += span;
  }

  stops.add(1.0);
  colors.add(colors.last);

  double arrowLeft = 0.0;
  double aqiDouble = aqi.toDouble();
  accumulated = 0.0;

  for (var level in levels) {
    final double min = level['min'] as double;
    final double max = level['max'] as double;

    if (aqiDouble >= min && aqiDouble <= max) {
      double ratioInSegment = (aqiDouble - min) / (max - min);
      arrowLeft = (accumulated + ratioInSegment * (max - min)) / totalRange * barWidth;
      break;
    }
    accumulated += (max - min);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Stack(
        children: [
          Container(
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: colors,
                stops: stops,
              ),
            ),
          ),
          Positioned(
            left: arrowLeft.clamp(0, barWidth - 20),
            top: -4,
            child: const Icon(Icons.arrow_drop_down, size: 24, color: Colors.black),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: levels.map((e) {
          final double min = e['min'] as double;
          final double max = e['max'] as double;
          return Column(
            children: [
              Text(
                e['label'] as String,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              ),
              Text(
                '${min.toInt()}–${max.toInt()}',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          );
        }).toList(),
      ),
    ],
  );
}

  Widget _buildWeatherCard(String temp, String hum, String pre) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _weatherItem(Icons.thermostat, "$temp°C", "Temperature"),
            _weatherItem(Icons.water_drop, "$hum%", "Humidity"),
            _weatherItem(Icons.speed, "$pre hPa", "Pressure"),
          ],
        ),
      ),
    );
  }

  Widget _weatherItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.blueGrey),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  String extractParenthesis(String input) {
  final match = RegExp(r'\((.*?)\)').firstMatch(input);
  return match != null ? match.group(1)! : input;
}

  Widget _buildStationRanking(BuildContext context) {
  if (sensorAqi.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'No station AQI data available',
        style: TextStyle(fontSize: 16, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  final stations = sensorAqi.values.toList()
    ..sort((a, b) => (a['aqi'] as int).compareTo(b['aqi'] as int));

  return Padding(
    padding: const EdgeInsets.all(12.0),
    child: Column(
      children: [
        const Text(
          'Stations Ranking',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.grey.shade200,
                child: Row(
                  children: const [
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Text(
                          'Rank',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 12), // header padding
                          child: Text(
                            'Station',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          'AQI',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              // Data rows
              ...List.generate(stations.length, (index) {
                final station = stations[index];
                final sensorId = station['sensorId'];
                final rawStationName = station['sensorName'] ?? 'Unknown Station';
                final stationName = extractParenthesis(rawStationName);
                final aqi = station['aqi'] ?? 'N/A';

                Color aqiColor;
                if (aqi is int) {
                  if (aqi <= 50) {
                    aqiColor = Colors.green;
                  } else if (aqi <= 100) {
                    aqiColor = Colors.yellow.shade700;
                  } else if (aqi <= 200) {
                    aqiColor = Colors.orange;
                  } else if (aqi <= 300) {
                    aqiColor = Colors.red;
                  } else {
                    aqiColor = Colors.purple;
                  }
                } else {
                  aqiColor = Colors.grey;
                }

                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LiveGasPage(
                              phone: widget.phone,
                              preselectedSensorId: sensorId,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Center(child: Text('${index + 1}')),
                            ),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Text(
                                    stationName,
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Text(
                                  '$aqi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: aqiColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    ),
  );
}
Widget _buildInfoCard({
  required IconData icon,
  required String title,
  String? subtitle,
  required String description,
  Color? color,
}) {
  return Card(
    elevation: 4,
    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            decoration: BoxDecoration(
              color: (color ?? Colors.teal).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: color ?? Colors.teal, size: 28),
          ),
          const SizedBox(width: 16),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// --- All Cards Together in One Widget ---
Widget buildInfoCardsSection() {
  return Column(
    children: [
      _buildInfoCard(
        icon: Icons.sensors,
        title: "Sensors",
        subtitle: "For Air Quality Detection",
        description:
            "Our network of air quality sensors continuously monitors pollutants such as PM2.5, PM10, temperature, humidity, and pressure. "
            ,
        color: Colors.teal,
      ),
      _buildInfoCard(
        icon: Icons.health_and_safety,
        title: "Health Assessment",
        subtitle: "Your Personalized Risk",
        description:
            "The assessment helps understand your exposure to air pollution and provides personalized recommendations.",
        color: Colors.orange,
      ),
      _buildInfoCard(
        icon: Icons.dashboard_customize,
        title: "Dashboard",
        subtitle: "Analyzing and Visualizing Data",
        description:
            "The dashboard collects, processes, and visualizes air-quality data, with the backend handling storage and the frontend providing graphs and insights.",
        color: Colors.blue,
      ),
    ],
  );
}
Widget _buildSidePanel(BuildContext context) {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
       // Drawer Header
UserAccountsDrawerHeader(
  accountName: FutureBuilder<String?>(
    future: _getUserNameByPhone(phoneNumber ?? ''),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Text('Loading...');
      } else if (snapshot.hasError) {
        return const Text('Error loading name');
      } else if (snapshot.hasData && snapshot.data != null) {
        return Text(
          'Welcome ${snapshot.data!}', // 👈 Welcome + username
          style: const TextStyle(fontWeight: FontWeight.bold),
        );
      } else {
        return const Text(
          'Guest User',
          style: TextStyle(fontWeight: FontWeight.bold),
        );
      }
    },
  ),
  // 👇 Instead of phone, show nothing (or a tagline)
  accountEmail: const Text(
    '', // leave blank or add a tagline
    style: TextStyle(fontSize: 0), // or remove entirely
  ),
  currentAccountPicture: const CircleAvatar(
    backgroundColor: Colors.white,
    child: Icon(Icons.person, size: 40, color: Colors.teal),
  ),
  decoration: const BoxDecoration(color: Colors.teal),
),



        // Admin Login
        ListTile(
          leading: const Icon(Icons.admin_panel_settings, color: Colors.teal),
          title: const Text("Admin"),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            );
          },
        ),

        // Manage Account
        ListTile(
          leading: const Icon(Icons.manage_accounts, color: Colors.teal),
          title: const Text("Manage Account"),
          onTap: () {
            Navigator.pop(context);
            if (isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ProfilePage(phone: phoneNumber ?? "Unknown")),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please log in to manage your account.'),
              ));
            }
          },
        ),

        // Settings
        ListTile(
          leading: const Icon(Icons.settings, color: Colors.teal),
          title: const Text("Settings"),
          onTap: () {
            Navigator.pop(context);
            // Navigate to Settings page (create one if not existing)
          },
        ),

        // Help & Support
        ListTile(
          leading: const Icon(Icons.help_outline, color: Colors.teal),
          title: const Text("Help & Support"),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportPage()),
            );
          },
        ),

        const Divider(),

        // Login / Logout dynamically
        if (isLoggedIn)
          // Logout Option
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () async {
              Navigator.pop(context);
              await logout();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Logged out successfully")));
            },
          )
        else
          // Login Option
          ListTile(
            leading: const Icon(Icons.login, color: Colors.teal),
            title: const Text("Login"),
            onTap: () {
              Navigator.pop(context);
              // Navigate to your Login Page (replace with your own login widget)
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
      ],
    ),
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
      Uri.parse('${AppConfig.baseUrl}/api/forecast'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

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

  Color _aqiColor(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 200) return Colors.orange;
    if (aqi <= 300) return Colors.red;
    if (aqi <= 400) return Colors.purple;
    return Colors.brown;
  }
}

/// Dummy data for fallback
const dummyData = {
  "aqi": 120,
  "status": "Moderate",
  "sensorId": "sensor_1",
  "date": "2025-09-08",
  "time": "12:00 PM",
  "temp": 28,
  "hum": 65,
  "pre": 1012,
  "readings": {"pm25": 80, "pm10": 150}
};
