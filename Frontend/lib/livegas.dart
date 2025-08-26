
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'map.dart';
import 'profile.dart';
import 'forecast.dart';
import 'package:intl/intl.dart';
import 'utils/sensor_name_mapper.dart';
import 'support.dart';
import 'config.dart';

class LiveGasPage extends StatefulWidget {
  final String? phone;
  const LiveGasPage({super.key, this.phone});

  @override
  State<LiveGasPage> createState() => _LiveGasPageState();
}

class _LiveGasPageState extends State<LiveGasPage> {
  Map<String, dynamic> liveData = {};
  Timer? _timer;
  bool isLoggedIn = false;
  String? phoneNumber;
  String? selectedStation; // ✅ Selected station
  int _selectedIndex = 2;

  final String _baseUrl = AppConfig.baseUrl;  
static const String _endpoint = '/api/realtime';  


  // ✅ Station -> Sensor ID mapping
  final Map<String, String> stationMap = {
    "Station 1": "lora-v1",
    "Station 2": "loradev2",
    "Station 3": "lora-v3",
    "Station 4": "lora-v4",
    "Station 5": "lora-v5",
  };

  @override
  void initState() {
    super.initState();
    _loadLoginState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
  }

  Future<void> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      phoneNumber = prefs.getString('phone');
    });
  }

/// ✅ Fetch data for all stations by calling /api/realtime?sensor_id=xxx
Future<void> _fetch() async {
  try {
    Map<String, dynamic> newData = {};

    for (var entry in stationMap.entries) {
      final sensorId = entry.value;
      final url = "$_baseUrl$_endpoint?sensor_id=$sensorId";

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        //debugPrint("✅ Data for $sensorId: $decoded"); 
        newData[sensorId] = decoded['data'];
      } else {
        debugPrint("HTTP ${res.statusCode} for $sensorId");
      }
    }

    setState(() {
      liveData = newData;
    });
  } catch (e) {
    debugPrint("Fetch error: $e");
  }
}


  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
Widget buildSensorCard(Map<String, dynamic> sensor) {
  final readings = sensor['readings'];

  // ✅ Handle missing/invalid readings
  if (readings == null || readings is! Map<String, dynamic>) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 6,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "⚠️ No readings available",
          style: TextStyle(fontSize: 16, color: Colors.redAccent),
        ),
      ),
    );
  }

  final Map<String, dynamic> readingsMap = readings;

  // ✅ Date parsing
  String dateStr = sensor['date'] ?? '';
  String timeStr = sensor['time'] ?? '';

  DateTime? parsedDate;
  try {
    final parts = dateStr.split(':');
    if (parts.length == 3) {
      parsedDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }
  } catch (e) {
    debugPrint("Date parsing error: $e");
  }

  final String formattedDate = parsedDate != null
      ? DateFormat('dd MMM yyyy').format(parsedDate)
      : dateStr;

  final String sensorId = sensor['sensor_id'] ?? 'Unknown';
  final String displaySensor = SensorNameMapper.displayName(sensorId);

  // ✅ Card UI
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    elevation: 6,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displaySensor,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            "Last Update: $formattedDate $timeStr",
            style: const TextStyle(color: Colors.grey),
          ),
          const Divider(),
          ...readingsMap.entries.map(
            (entry) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key.toUpperCase()),
                Text(
                  entry.value.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
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




@override
  Widget build(BuildContext context) {
    String? selectedSensorId =
        selectedStation != null ? stationMap[selectedStation] : null;

    Map<String, dynamic>? selectedData =
        selectedSensorId != null ? liveData[selectedSensorId] : null;

    return Scaffold(
      appBar: AppBar(title: const Text("Devices")),
      body: Column(
        children: [
          // ✅ Station buttons
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stationMap.keys.map((station) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width / 2.3,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedStation == station
                          ? Colors.teal
                          : Colors.blueGrey.shade100,
                      foregroundColor: selectedStation == station
                          ? Colors.white
                          : Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      elevation: 4,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedStation = station;
                      });
                    },
                    child: Text(
                      station,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ✅ Show station data or "under construction"
          Expanded(
            child: selectedStation == null
                ? const Center(
                    child: Text("Select a station to view data",
                        style: TextStyle(fontSize: 16)))
                : (selectedData != null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [buildSensorCard(selectedData)],
                      )
                    : const Center(
                        child: Text("This station is under construction 🚧",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)))),
          ),
        ],
      ),
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
          if (index == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => AQIDashboardPage(phone: widget.phone),
            ));
          } else if (index == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => SensorMapPage(phone: widget.phone),
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
    Navigator.pop(bottomSheetContext); // Close the bottom sheet
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