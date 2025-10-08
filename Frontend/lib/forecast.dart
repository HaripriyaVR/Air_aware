/*import 'dart:math' as math;
import 'package:aqmapp/otpsent.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'support.dart';
import 'bottom_nav.dart';
import 'utils/sensor_name_mapper.dart'; // ✅ import your mapper
import 'background_design.dart'; // ✅ import background design

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
         
          // DropdownButton<String>(
          //   value: selectedSensor,
          //   underline: const SizedBox(),
          //   items: sortedKeys.map((sensorKey) {
          //     return DropdownMenuItem<String>(
          //       value: sensorKey,
          //       child: Text(SensorNameMapper.displayName(sensorKey)),
          //     );
          //   }).toList(),
          //   onChanged: (val) {
          //     if (val != null) {
          //       setState(() {
          //         selectedSensor = val;
          //       });
          //     }
          //   },
          // ),
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
            const BackgroundDesign(), // ✅ background separated

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
              // ✅ Sensor selector
              // DropdownButton<String>(
              //   value: selectedSensor,
              //   underline: const SizedBox(),
              //   items: sortedKeys.map((sensorKey) {
              //     return DropdownMenuItem<String>(
              //       value: sensorKey,
              //       child: Text(SensorNameMapper.displayName(sensorKey)),
              //     );
              //   }).toList(),
              //   onChanged: (val) {
              //     if (val != null) {
              //       setState(() {
              //         selectedSensor = val;
              //       });
              //     }
              //   },
              // ),
              Container(
                width: double.infinity, // full screen width
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12), // rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: selectedSensor,
                  isExpanded: true, // makes it full width inside container
                  underline: const SizedBox(), // remove underline
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
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.3,
                  child: LineChart(
                    LineChartData(
                      // ...existing chart config...
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
                            interval: 4.5,
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
                      borderData: FlBorderData(show: false), // Remove border from chart
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
}*/
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../bottom_nav.dart';
import '../utils/sensor_name_mapper.dart';
import '../background_design.dart';

class ForecastDataPage extends StatefulWidget {
  final Map<String, dynamic> forecastData;
  final String? phone;

  const ForecastDataPage({Key? key, required this.forecastData, this.phone})
      : super(key: key);

  @override
  State<ForecastDataPage> createState() => _ForecastDataPageState();
}

class _ForecastDataPageState extends State<ForecastDataPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  int _selectedIndex = 3;

  // State for the new Tab Bar style
  int _selectedDayIndex = 0; // Starts at 0, representing the first shown entry

  final List<String> pollutantLabels = [
    "PM2.5",
    "PM10",
    "NO2",
    "O3",
    "SO2",
    "CO",
    "NH3"
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

  int selectedPollutantIndex = 0; // Renamed for clarity
  String selectedSensor = "lora-v1";

  String _getTomorrowWeekday() {
    DateTime today = DateTime.now();
    DateTime tomorrow = today.add(const Duration(days: 1));
    return DateFormat('EEEE').format(tomorrow);
  }

  @override
  void initState() {
    super.initState();
    if (widget.forecastData.isNotEmpty) {
      selectedSensor = widget.forecastData.keys.first;
    }
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
      // Logic for not logged in... (omitted for brevity)
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // Format a DateTime into label strings
  String _formatDateLabelFromDate(DateTime dt, {bool short = false}) {
    try {
      if (short) {
        return DateFormat('EEE').format(dt); // Mon, Tue
      }
      return DateFormat('EEE dd/MM').format(dt); // Mon 07/10
    } catch (_) {
      return dt.toIso8601String();
    }
  }

  // Returns only date portion (year,month,day) for safe compare
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // Try to parse a variety of incoming date string formats into a DateTime
  DateTime? _tryParseDateString(String raw) {
    raw = raw.trim();
    if (raw.isEmpty) return null;

    // 1) Try ISO
    try {
      return DateTime.parse(raw);
    } catch (_) {}

    final formats = ['EEE dd-MM', 'EEE dd/MM', 'dd-MM', 'dd/MM'];
    for (var fmt in formats) {
      try {
        // DateFormat.parseLoose may not exist in older intl versions;
        // parse() is the usual method — parseLoose used in original, keep parse() to be safe.
        return DateFormat(fmt).parse(raw);
      } catch (_) {}
    }

    // 3) If it's something like 'Fri' or 'Friday' -> return null (we'll compute nearest later)
    final weekdayMatch = RegExp(
      r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)',
      caseSensitive: false,
    );
    if (weekdayMatch.hasMatch(raw)) {
      // signal that we couldn't parse exact date but we detected a weekday
      return null;
    }

    // 4) Try extract numeric dd-mm anywhere
    final m = RegExp(r'(\d{1,2})[-/](\d{1,2})').firstMatch(raw);
    if (m != null) {
      final d = int.tryParse(m.group(1)!) ?? 1;
      final mth = int.tryParse(m.group(2)!) ?? 1;
      final now = DateTime.now();
      // Construct date in current year
      DateTime candidate = DateTime(now.year, mth, d);
      return candidate;
    }

    return null;
  }

  // Get next occurrence of weekday at or after start (weekday: DateTime.monday..sunday)
  DateTime _nextWeekdayFrom(DateTime start, int weekday) {
    final delta = (weekday - start.weekday) % 7;
    return start.add(Duration(days: delta));
  }

  // Build a normalized DateTime list for the provided raw forecast list.
  // If parsing fails for an entry it falls back to sequential dates starting from today
  List<DateTime> _computeDatesForRawList(List<Map<String, dynamic>> rawList) {
    final now = DateTime.now();
    final todayOnly = _dateOnly(now);
    List<DateTime> parsedDates = List<DateTime>.filled(rawList.length, todayOnly, growable: false);

    // First pass: try to parse each 'day' field
    for (int i = 0; i < rawList.length; i++) {
      final raw = (rawList[i]['day'] ?? '').toString();
      DateTime? candidate = _tryParseDateString(raw);

      if (candidate != null) {
        // If parsed with no year or odd year, normalize to current year (then push to next year if before today)
        candidate = DateTime(now.year, candidate.month, candidate.day);
        if (candidate.isBefore(todayOnly.subtract(const Duration(days: 1)))) {
          // If it's in the past, assume it's meant to be the next year occurrence
          candidate = DateTime(now.year + 1, candidate.month, candidate.day);
        }
        parsedDates[i] = candidate;
      } else {
        parsedDates[i] = DateTime(0); // marker for "not parsed"
      }
    }

    // Second pass: fill any entries that couldn't be parsed.
    // We assume the forecast is sequential day-by-day. Find a reasonable start:
    // If at least one parsed date exists, anchor to that and fill neighbors.
    final anyParsedIndex = parsedDates.indexWhere((d) => d.year != 0);
    if (anyParsedIndex != -1) {
      // fill backward and forward from the anchor
      for (int i = anyParsedIndex - 1; i >= 0; i--) {
        parsedDates[i] = _dateOnly(parsedDates[i + 1]).subtract(Duration(days: 1));
      }
      for (int i = anyParsedIndex + 1; i < parsedDates.length; i++) {
        parsedDates[i] = _dateOnly(parsedDates[i - 1]).add(Duration(days: 1));
      }
    } else {
      // No parsed dates at all: assume a contiguous sequence starting from today (index 0 = today)
      for (int i = 0; i < parsedDates.length; i++) {
        parsedDates[i] = todayOnly.add(Duration(days: i));
      }
    }

    return parsedDates;
  }

  void _showMenuOptions(BuildContext context) {
    // Menu logic (omitted for brevity)
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_isLoggedIn) {
      return Scaffold(
        body: Center(child: _isLoading ? const CircularProgressIndicator() : const SizedBox.shrink()),
      );
    }

    final sortedKeys = widget.forecastData.keys.toList()
      ..sort((a, b) => SensorNameMapper.displayName(a).compareTo(SensorNameMapper.displayName(b)));

    final sensorData = widget.forecastData[selectedSensor];
    if (sensorData == null || sensorData["forecast"] == null) {
      return Scaffold(
        appBar: _buildAppBar(sortedKeys),
        body: const Center(child: Text("No forecast data available for this sensor.")),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    List<Map<String, dynamic>> rawForecastList =
        (sensorData["forecast"] as List<dynamic>).cast<Map<String, dynamic>>();

    if (rawForecastList.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(sortedKeys),
        body: const Center(child: Text("Forecast data is empty.")),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    // Compute normalized dates for the raw list
    final rawDates = _computeDatesForRawList(rawForecastList);
    final todayOnly = _dateOnly(DateTime.now());

    // Decide whether the feed starts from today. If it does, we skip the first element so UI starts from tomorrow.
    int startIndex = 0;
    if (rawDates.isNotEmpty && _dateOnly(rawDates[0]).difference(todayOnly).inDays == 0) {
      // feed contains "today" at index 0 -> drop it so UI starts from tomorrow
      startIndex = 1;
    }

    // Create the final forecastList and corresponding entryDates that the UI will use.
    final safeStart = startIndex < rawForecastList.length ? startIndex : rawForecastList.length - 1;
    final forecastList = rawForecastList.sublist(safeStart);
    final entryDates = rawDates.sublist(safeStart);

    if (forecastList.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(sortedKeys),
        body: const Center(child: Text("Forecast data is too short (no 'tomorrow' entries).")),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    // Ensure selectedDayIndex is valid after sublist operations
    if (_selectedDayIndex >= forecastList.length) {
      _selectedDayIndex = 0;
    }

    final pollutant = pollutantLabels[selectedPollutantIndex];
    final key = pollutantKey[pollutant] ?? pollutantKey.values.first;

    // The logic below is for the pollutant **trend chart** across all days (based on forecastList)
    final List<double> trendValues = forecastList.map((d) => _toDouble(d[key])).toList();
    final List<String> trendLabels =
        entryDates.map((d) => _formatDateLabelFromDate(d, short: false)).toList();
    final List<String> trendShortLabels = entryDates.map((d) => _formatDateLabelFromDate(d, short: true)).toList();

    double minVal = trendValues.isNotEmpty ? trendValues.reduce(math.min) : 0;
    double maxVal = trendValues.isNotEmpty ? trendValues.reduce(math.max) : 10;
    if (minVal == maxVal) {
      minVal = math.max(0, minVal - 5);
      maxVal += 5;
    }
    minVal = _roundToNice(minVal, up: false);
    maxVal = _roundToNice(maxVal, up: true);
    double interval = ((maxVal - minVal) / 4).ceilToDouble();
    if (interval == 0) interval = 1.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(sortedKeys),
      // NEW BODY STRUCTURE
      body: _buildVerticalTabBody(
        forecastList,
        entryDates,
        trendValues,
        trendLabels,
        trendShortLabels,
        minVal,
        maxVal,
        interval,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  double _roundToNice(double value, {bool up = true}) {
    if (value == 0) return 1.0;
    final absValue = value.abs();
    final factor = math.pow(10, (math.log(absValue) / math.ln10).floor());

    if (up) {
      return ((value / factor).ceil() * factor).toDouble();
    } else {
      return ((value / factor).floor() * factor).toDouble();
    }
  }

  // --- UI COMPONENTS ---

  AppBar _buildAppBar(List<String> sortedKeys) {
    return AppBar(
      backgroundColor: Colors.teal, // Transparent app bar
      elevation: 0,
      // Use a clean, modern approach for the location dropdown
      title: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12), // Tighter radius for professionalism
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05), // Very subtle shadow
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, color: Colors.teal.shade600, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSensor,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.teal.shade700),
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade900, fontWeight: FontWeight.w700),
                    items: sortedKeys.map((sensorKey) {
                      return DropdownMenuItem<String>(
                        value: sensorKey,
                        child: Text(
                          SensorNameMapper.displayName(sensorKey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedSensor = val;
                          _selectedDayIndex = 0; // Reset tab when sensor changes
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalTabBody(
    List<Map<String, dynamic>> forecastList,
    List<DateTime> entryDates,
    List<double> trendValues,
    List<String> trendLabels,
    List<String> trendShortLabels,
    double minVal,
    double maxVal,
    double interval,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Stack(
      children: [
        const BackgroundDesign(),
        SafeArea(
          // Adjust padding top to account for transparent app bar content
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20, top: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Title
                  Text(
                    "Pollutant Forecast Overview",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Weekly maximum concentration analysis",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 🔹 Pollutant Selector (Segmented control style)
                  _buildPollutantSelector(),
                  const SizedBox(height: 18),

                  // 🔹 Horizontal Day Tabs (modern segmented style)
                  _buildDaySelector(forecastList, entryDates),

                  const SizedBox(height: 18),

                  // 🔹 Selected Day Summary (High-impact metric card)
                  _buildFocusedDailySummary(forecastList[_selectedDayIndex], entryDates[_selectedDayIndex]),

                  const SizedBox(height: 24),

                  // 🔹 Weekly Trend Chart (Professional graph card)
                  _buildTrendChartCard(
                    selectedSensor, // PASSING selectedSensor for chart title
                    trendValues,
                    trendLabels,
                    trendShortLabels,
                    minVal,
                    maxVal,
                    interval,
                    isSmallScreen: isSmallScreen,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPollutantSelector() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pollutantLabels.length,
        itemBuilder: (context, i) {
          final selected = i == selectedPollutantIndex;
          return Padding(
            padding: EdgeInsets.only(right: i < pollutantLabels.length - 1 ? 8.0 : 0),
            // Changed to InkWell/AnimatedContainer for a button/segment look
            child: InkWell(
              onTap: () => setState(() => selectedPollutantIndex = i),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.teal.shade700 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? Colors.teal.shade700 : Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.teal.shade200.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    pollutantLabels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Day Selector ---
  Widget _buildDaySelector(List<Map<String, dynamic>> forecastList, List<DateTime> entryDates) {
    return SizedBox(
      height: 75, // Increased height for better visual impact
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: forecastList.length,
        itemBuilder: (context, i) {
          final dt = entryDates[i];
          final weekdayLabel = DateFormat('EEE').format(dt).toUpperCase(); // e.g., MON
          final monthDay = DateFormat('dd').format(dt); // Just the day number
          final isSelected = i == _selectedDayIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => setState(() => _selectedDayIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 68,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.teal.shade700 : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.teal.shade200.withOpacity(0.6),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                          )
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekdayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthDay,
                      style: TextStyle(
                        fontSize: 24, // Larger day number
                        color: isSelected ? Colors.white : Colors.grey.shade900,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Focused Daily Summary Card (Refined) ---
  Widget _buildFocusedDailySummary(Map<String, dynamic> selectedDayData, DateTime selectedDate) {
    final selectedPollutant = pollutantLabels[selectedPollutantIndex];
    final selectedKey = pollutantKey[selectedPollutant]!;
    final value = _toDouble(selectedDayData[selectedKey]);
    final unit = selectedPollutant.contains("CO") ? "mg/m³" : "µg/m³";
    final fullDateLabel = DateFormat('EEEE, MMMM d').format(selectedDate); // e.g., Tuesday, October 7

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade50, width: 2), // Subtle color border
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade50.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Daily Maximum Forecast",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              fullDateLabel,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedPollutant,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          text: value.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 56, // Bold and prominent
                            fontWeight: FontWeight.w900,
                            color: Colors.teal.shade800,
                          ),
                          children: [
                            TextSpan(
                              text: ' $unit',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Icon area
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.teal.shade50,
                  ),
                  child: Icon(
                    Icons.auto_graph, // Professional charting icon
                    size: 32,
                    color: Colors.teal.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChartCard(
    String sensorKey, // NEW PARAMETER for dynamic title
    List<double> values,
    List<String> labels,
    List<String> shortLabels,
    double minVal,
    double maxVal,
    double interval, {
    bool isSmallScreen = false,
  }) {
    final currentPollutant = pollutantLabels[selectedPollutantIndex];
    final sensorName = SensorNameMapper.displayName(sensorKey); // Get the display name
    final screenHeight = MediaQuery.of(context).size.height;

    final double chartHeight = isSmallScreen ? 240 : (screenHeight * 0.3).clamp(280.0, 350.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100), // Very light border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Slightly more visible but soft shadow
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title text
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8.0),
              child: Text(
                "$sensorName: $currentPollutant Weekly Trend", // UPDATED TITLE
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                "Maximum daily levels predicted for the week ahead.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Chart area
            SizedBox(
              height: chartHeight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0, right: 10.0), // Padding right for Y-Axis labels
                child: BarChart(
                  _buildBarChartData(
                    values,
                    labels,
                    shortLabels,
                    minVal,
                    maxVal + interval, // give more headroom
                    interval,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _buildBarChartData(List<double> values, List<String> labels, List<String> shortLabels, double minVal, double maxVal, double interval) {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal,
      minY: minVal,
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36, // Increase size for bold font
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= shortLabels.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  shortLabels[idx].split(' ')[0], // Weekday only
                  style: TextStyle(
                    fontSize: 11,
                    color: idx == _selectedDayIndex ? Colors.teal.shade800 : Colors.grey.shade600,
                    fontWeight: idx == _selectedDayIndex ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: interval,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(value % interval == 0 ? 0 : 1), // Integer for main ticks, one decimal for others (if needed)
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.shade100, // Very subtle grid lines
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1), // Light baseline
          left: BorderSide.none,
          right: BorderSide.none,
          top: BorderSide.none,
        ),
      ),
      barGroups: values
          .asMap()
          .entries
          .map((e) {
            final isSelected = e.key == _selectedDayIndex;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value,
                  color: isSelected ? Colors.teal.shade700 : Colors.teal.shade400.withOpacity(0.8), // Richer selected color
                  width: 22, // Slightly wider bars
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8), // More rounded corners
                    topRight: Radius.circular(8),
                  ),
                  // Highlight the selected bar column with a background rod
                  backDrawRodData: BackgroundBarChartRodData(
                    show: isSelected, // Only show for the selected index
                    toY: maxVal, // Cover the entire Y range (maxVal passed in includes headroom)
                    color: Colors.teal.shade50.withOpacity(0.6), // Very light transparent teal
                  ),
                ),
              ],
              showingTooltipIndicators: [0],
            );
          })
          .toList(),
      barTouchData: BarTouchData(
        touchCallback: (event, response) {
          if (response?.spot != null && event.isInterestedForInteractions) {
            setState(() {
              _selectedDayIndex = response!.spot!.touchedBarGroupIndex;
            });
          }
        },
        touchTooltipData: BarTouchTooltipData(
          // Depending on fl_chart version, the tooltip background property name may differ.
          // Historically tooltipBgColor exists; newer versions may expect tooltipBgColor or tooltipBgColor property.
          // Here we keep tooltipBgColor — if analyzer complains, replace with your version's property name.
          tooltipBgColor: Colors.grey.shade900,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          tooltipBorder: BorderSide.none,
          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
            '${rod.toY.toStringAsFixed(1)}\n',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            children: [
              TextSpan(
                text: labels[group.x.toInt()],
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavBar(
      currentIndex: _selectedIndex,
      isLoggedIn: _isLoggedIn,
      phone: widget.phone,
      showMenu: _showMenuOptions,
      onIndexChanged: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }
}
