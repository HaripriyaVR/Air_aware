import 'dart:math' as math;
import 'package:aqmapp/otpsent.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'support.dart';
import 'bottom_nav.dart';
import 'utils/sensor_name_mapper.dart'; // ✅ import your mapper



class ForecastDataPage extends StatefulWidget {
  final Map<String, dynamic> forecastData;
  final String? phone; // Pass phone number for navigation

  const ForecastDataPage({Key? key, required this.forecastData, this.phone})
      : super(key: key);

  @override
  State<ForecastDataPage> createState() => _ForecastDataPageState();
}

class _ForecastDataPageState extends State<ForecastDataPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  int _selectedIndex = 3;

  final List<String> pollutantLabels = [
    "PM2.5", "PM10", "NO2", "O3", "SO2", "CO", "NH3"
  ];
  final Map<String, String> pollutantKey = {
    "PM2.5": "pm25_max",
    "PM10": "pm10_max",
    "NO2": "no2_max",
    "O3": "o3_max",
    "SO2": "so2_max",
    "CO": "co_max",
    "NH3": "nh3_max",
  };

  int selectedIndex = 1; // pollutant index
  String selectedSensor = "lora-v1"; // default sensor key

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool('isLoggedIn') ?? false;

    setState(() {
      _isLoggedIn = logged;
      _isLoading = false;
    });

    if (!logged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Please log in to view forecast data"),
            duration: Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        });
      });
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _formatLabel(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('EEE dd-MM').format(dt);
    } catch (_) {
      return rawDate;
    }
  }

  double _roundToNice(double value, {bool up = true}) {
    if (value == 0) return 0.0;
    final factor = math.pow(10, (math.log(value.abs()) / math.ln10).floor());
    return ((up ? (value / factor).ceil() : (value / factor).floor()) * factor)
        .toDouble();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isLoggedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }
     final sortedKeys = widget.forecastData.keys.toList()
  ..sort((a, b) => SensorNameMapper.displayName(a)
      .compareTo(SensorNameMapper.displayName(b)));

    // ✅ New: Handle multiple sensors
    final sensorData = widget.forecastData[selectedSensor];
    if (sensorData == null || sensorData["forecast"] == null) {
      return const Scaffold(body: Center(child: Text("No forecast data available")));
    }

    final List<Map<String, dynamic>> forecastList =
        (sensorData["forecast"] as List<dynamic>).cast<Map<String, dynamic>>();
    final key = pollutantKey[pollutantLabels[selectedIndex]] ?? pollutantKey.values.first;
    final List<double> values = forecastList.map((d) => _toDouble(d[key])).toList();
    final List<String> labels =
        forecastList.map((d) => _formatLabel(d['day'].toString())).toList();

    double minVal = values.reduce(math.min);
    double maxVal = values.reduce(math.max);
    if (minVal == maxVal) {
      minVal -= 1;
      maxVal += 1;
    }
    minVal = _roundToNice(minVal, up: false);
    maxVal = _roundToNice(maxVal, up: true);
    double interval = ((maxVal - minVal) / 4).ceilToDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        actions: [
          // ✅ Sensor selector
         
          DropdownButton<String>(
            value: selectedSensor,
            underline: const SizedBox(),
            items: sortedKeys.map((sensorKey) {
              return DropdownMenuItem<String>(
                value: sensorKey,
                child: Text(SensorNameMapper.displayName(sensorKey)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  selectedSensor = val;
                });
              }
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < 0) {
                // Swipe Left → Next pollutant
                setState(() {
                  if (selectedIndex < pollutantLabels.length - 1) {
                    selectedIndex++;
                  }
                });
              } else if (details.primaryVelocity! > 0) {
                // Swipe Right → Previous pollutant
                setState(() {
                  if (selectedIndex > 0) {
                    selectedIndex--;
                  }
                });
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                "Air Quality Analysis",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 16),

              // Pollutant Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(pollutantLabels.length, (i) {
                    final selected = i == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: ChoiceChip(
                        label: Text(
                          pollutantLabels[i],
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : Colors.blueGrey.shade700,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() => selectedIndex = i),
                        selectedColor: Colors.green.shade600,
                        backgroundColor: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Chart Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (values.length - 1).toDouble(),
                        minY: minVal,
                        maxY: maxVal,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: interval,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.blue.shade100,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              interval: interval,
                              getTitlesWidget: (value, meta) => Text(
                                value.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= labels.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  labels[idx],
                                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: values
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            isCurved: true,
                            color: Colors.blue.shade700,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.3),
                                  Colors.green.withOpacity(0.2),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Data Table Full Width
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.green.shade50),
                        columnSpacing: 40,
                        columns: const [
                          DataColumn(
                            label: Text(
                              "Date",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Value (µg/m³)",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        ],
                        rows: List.generate(labels.length, (i) {
                          return DataRow(
                            cells: [
                              DataCell(Text(labels[i], style: const TextStyle(fontSize: 13))),
                              DataCell(Text(values[i].toStringAsFixed(2),
                                  style: const TextStyle(fontSize: 13))),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),


      // // ✅ BottomNavigationBar (unchanged)
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        isLoggedIn: _isLoggedIn,
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
}