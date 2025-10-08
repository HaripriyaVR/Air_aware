import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/sensor_name_mapper.dart';
import '../config.dart';

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

  // ✅ Extract AQI, Status, Date, Time
  final String aqi = sensor['aqi']?.toString() ?? "N/A";
  final String status = sensor['status']?.toString() ?? "N/A";
  final String dateStr = sensor['date'] ?? '';
  final String timeStr = sensor['time'] ?? '';

  // ✅ Format Date
  String formattedDate = dateStr;
  try {
    final parts = dateStr.split(':');
    if (parts.length == 3) {
      final parsedDate = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      formattedDate = DateFormat('dd MMM yyyy').format(parsedDate);
    }
  } catch (e) {
    debugPrint("Date parsing error: $e");
  }

  final String sensorId = sensor['sensor_id'] ?? 'Unknown';
  final String displaySensor = SensorNameMapper.displayName(sensorId);

  // ✅ Units map for each parameter
  final Map<String, String> unitsMap = {
    'co': 'µg/m³',
    'co2': 'µg/m³',
    'so2': 'µg/m³',
    'no2': 'µg/m³',
    'o3': 'µg/m³',
    'pm2_5': 'µg/m³',
    'pm10': 'µg/m³',
    'temperature': '°C',
    'temp': '°C',
    'hum': '%',
    'pre': 'hPa',
    'default': 'µg/m³',
  };
  

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
          // Station title
          Text(
            displaySensor,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          // AQI and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("AQI: $aqi", style: const TextStyle(fontSize: 16)),
              Text(
                "Status: $status",
                style: TextStyle(
                  fontSize: 16,
                  color: status.toLowerCase() == "good"
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            "Last Update: $formattedDate $timeStr",
            style: const TextStyle(color: Colors.grey),
          ),
          const Divider(),

          // ✅ Readings with units
          ...readingsMap.entries.map((entry) {
            final key = entry.key.toLowerCase();
            final rawValue = entry.value;

            // Format numbers if possible
            String valueStr;
            if (rawValue is num) {
              valueStr = rawValue.toStringAsFixed(1); // 2 decimals
            } else {
              valueStr = rawValue.toString();
            }

            // Add unit
            final unit = unitsMap[key] ?? unitsMap['default'];
            final displayValue = "$valueStr $unit";

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key.toUpperCase()),
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            );
          }),
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
      appBar: AppBar(title: const Text("Devices"),backgroundColor:  Colors.teal),
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
    );
  }
}
