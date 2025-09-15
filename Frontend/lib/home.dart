import 'dart:convert';
import 'dart:math' show cos, sin, sqrt, atan2, pi;
import 'package:aqmapp/otpsent.dart';
import 'package:aqmapp/forecast.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile.dart';
import 'livegas.dart';
import 'map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/sensor_name_mapper.dart';
import 'support.dart';
import 'config.dart';
import 'admin/login.dart';

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

  final Map<String, Map<String, double>> _sensorLocations = {
    'lora-v1': {'lat': 10.178385739668958, 'lon': 76.43052237497399},
    'loradev2': {'lat': 10.17095090340159, 'lon': 76.42962876824544},
    'lora-v3': {'lat': 10.165, 'lon': 76.420} // Example coordinates for new sensor
  };
  
  Future<Map<String, dynamic>?>? _aqiFuture;

  @override
  void initState() {
    super.initState();
    _aqiFuture = _fetchRealtimeAQI();
    _loadLoginState();
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
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 1,
        title: const Text("", style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),

        // 👈 Left side Admin button
        leading: TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            );
          },
          icon: const Icon(Icons.admin_panel_settings, color: Colors.teal),
          label: const Text("", style: TextStyle(color: Colors.teal)),
        ),

        // 👉 Right side Login/Logout buttons
        actions: [
          if (!isLoggedIn)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.login, color: Colors.teal),
              label: const Text("Login", style: TextStyle(color: Colors.teal)),
            )
          else
            TextButton.icon(
              onPressed: () async {
                await logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Logged out")),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,
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

      // ✅ bottom nav bar is inside Scaffold
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
          const BottomNavigationBarItem(icon: Icon(Icons.devices), label: "Stations"),
          if (isLoggedIn)
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          const BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => SensorMapPage(phone: widget.phone),
            ));
          } else if (index == 2) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => LiveGasPage(phone: widget.phone),
            ));
          } else if (isLoggedIn && index == 3) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProfilePage(phone: phoneNumber ?? "Unknown"),
            ));
          } else if ((!isLoggedIn && index == 3) || index == 4) {
            _showMenuOptions(context);
          }
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text("Your Location",
            style: TextStyle(color: Colors.grey[700], fontSize: 14)),
        Text(displaySensor,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        // AQI Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.circle, size: 12, color: Colors.red),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Live AQI", style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _aqiColor(aqi).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$aqi',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _aqiColor(aqi),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text("Air Quality is", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _aqiColor(aqi).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _aqiColor(aqi),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),
        _buildAqiGradientBar(context, aqi),
        const SizedBox(height: 24),
        _buildWeatherCard(temp, hum, pre),
        const SizedBox(height: 20),
        Text("Last Update:  $time",
            style: const TextStyle(color: Colors.grey)),
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
          children: levels
              .map((e) => Text(e['label'] as String, style: const TextStyle(fontSize: 10)))
              .toList(),
        )
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
                        builder: (_) => ForecastDataPage(forecastData: forecastData),
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
