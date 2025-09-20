import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';
import 'forecast.dart';
import 'package:intl/intl.dart';
import 'utils/sensor_name_mapper.dart';
import 'support.dart';
import 'config.dart';
import 'bottom_nav.dart';
import 'background_design.dart';
import 'side_panel.dart';
import 'otpsent.dart';

class LiveGasPage extends StatefulWidget {
  final String? phone;
  final String? preselectedSensorId;
  const LiveGasPage({super.key, this.phone, this.preselectedSensorId});

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
    if (widget.preselectedSensorId != null) {
    // reverse lookup stationMap
    final matchingStation = stationMap.entries.firstWhere(
      (entry) => entry.value == widget.preselectedSensorId,
      orElse: () => const MapEntry('', ''), // avoid crash
    );

    if (matchingStation.key.isNotEmpty) {
      selectedStation = matchingStation.key; // ✅ preselect correct station
    }
  }

  _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
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
/// ✅ Fetch data for all stations by calling /api/realtime?sensor_id=xxx
Future<void> _fetch() async {
  if (selectedStation == null) return; // No station selected, nothing to fetch

  final sensorId = stationMap[selectedStation]!;
  final url = "$_baseUrl$_endpoint?sensor_id=$sensorId";

  try {
    final res = await http.get(Uri.parse(url));

    if (!mounted) return; // Avoid setState if widget is disposed

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      setState(() {
        liveData[sensorId] = decoded['data'];
      });
    } else if (res.statusCode != 404) {
      // Only log non-404 errors
      debugPrint("HTTP ${res.statusCode} for $sensorId");
    }
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

  // Build Table rows
  final List<TableRow> rows = readingsMap.entries.map((entry) {
    final key = entry.key.toLowerCase();
    final rawValue = entry.value;

    String valueStr;
    if (rawValue is num) {
      valueStr = rawValue.toStringAsFixed(1);
    } else {
      valueStr = rawValue.toString();
    }

    final unit = unitsMap[key] ?? unitsMap['default']!;

    return TableRow(children: [
      // Parameter name
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.5),
        child: Text(
          entry.key.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      // Value (fixed width)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.5),
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 70, // ✅ fixed width for numbers
            child: Text(
              valueStr,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.teal,
              ),
            ),
          ),
        ),
      ),
      // Unit (smaller font)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Text(
          unit,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ),
    ]);
  }).toList();

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
          Table(
            columnWidths: const {
              0: FlexColumnWidth(0.5), // parameter
              1: IntrinsicColumnWidth(), // value fixed
              2: IntrinsicColumnWidth(), // unit
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: rows,
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
      
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text(""),
        centerTitle: true,
      ),
      drawer: SidePanel(
  isLoggedIn: isLoggedIn,
  phoneNumber: phoneNumber,
  onLogout: logout, // pass your logout function
),
      body: Stack(
        children: [
          const BackgroundDesign(),
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  children: [
                    const Text(
                      "Real Time Monitoring",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: stationMap.keys.map((station) {
                          final isSelected = selectedStation == station;
                          return SizedBox(
                            width: MediaQuery.of(context).size.width / 2.2,
                            height: 65,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isSelected ? Colors.green.shade600 : Colors.blue.shade50,
                                foregroundColor:
                                    isSelected ? Colors.white : Colors.blueGrey.shade800,
                                shadowColor: Colors.blue.shade200,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: isSelected ? 6 : 2,
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedStation = station;
                                });
                              },
                              child: Text(
                                station,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.blueGrey.shade900,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    selectedStation == null
                        ? const Center(
                            child: Text(
                              "Select a station to view data",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          )
                        : (selectedData != null
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: buildSensorCard(selectedData),
                              )
                            : const Center(
                                child: Text(
                                  "This station is under construction 🚧",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey),
                                ),
                              )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        isLoggedIn: isLoggedIn,
        phone: widget.phone,
        showMenu: _showMenuOptions,
        onIndexChanged: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AQIDashboardPage(phone: widget.phone),
              ),
            );
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
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