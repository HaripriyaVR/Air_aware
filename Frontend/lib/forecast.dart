/*
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForecastDataPage extends StatefulWidget {
  final Map<String, dynamic> forecastData;

  const ForecastDataPage({Key? key, required this.forecastData}) : super(key: key);

  @override
  State<ForecastDataPage> createState() => _ForecastDataPageState();
}

class _ForecastDataPageState extends State<ForecastDataPage> {
  int currentIndex = 0;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool loggedIn = prefs.getBool('isLoggedIn') ?? false;
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text("")),
        body: const Center(
          child: Text(
            "You must be logged in to view this page.",
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      );
    }

    final List<dynamic> forecastList = widget.forecastData['forecast'];

    if (forecastList.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No forecast data available')),
      );
    }

    final item = forecastList[currentIndex];

    return Scaffold(
      appBar: AppBar(title: const Text("AQI Forecast")),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['day'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.center,
                          maxY: _getMaxValue(item) + 20,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.black87,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${_getLabel(group.x)}\n${rod.toY.toStringAsFixed(1)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) => _bottomTitle(value),
                                reservedSize: 32,
                              ),
                            ),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: _buildBarGroups(item),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: currentIndex > 0 ? () => setState(() => currentIndex--) : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Previous"),
                ),
                ElevatedButton.icon(
                  onPressed: currentIndex < forecastList.length - 1
                      ? () => setState(() => currentIndex++)
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("Next"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, dynamic> item) {
    final pollutants = {
      'PM2.5': item['pm25_max'].toDouble(),
      'PM10': item['pm10_max'].toDouble(),
      'CO': item['co_max'].toDouble(),
      'NO2': item['no2_max'].toDouble(),
      'SO2': item['so2_max'].toDouble(),
      'O3': item['o3_max'].toDouble(),
      'NH3': item['nh3_max'].toDouble(),
    };

    int i = 0;
    return pollutants.entries.map((entry) {
      return BarChartGroupData(
        x: i++,
        barsSpace: 0,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            width: 18,
            gradient: const LinearGradient(
              colors: [Colors.teal, Colors.lightBlueAccent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _bottomTitle(double value) {
    const labels = ['PM2.5', 'PM10', 'CO', 'NO2', 'SO2', 'O3', 'NH3'];
    return SideTitleWidget(
      axisSide: AxisSide.bottom,
      child: Text(
        labels[value.toInt()],
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  double _getMaxValue(Map<String, dynamic> item) {
    return [
      item['pm25_max'],
      item['pm10_max'],
      item['co_max'],
      item['no2_max'],
      item['so2_max'],
      item['o3_max'],
      item['nh3_max'],
    ].map((e) => e.toDouble()).reduce((a, b) => a > b ? a : b);
  }

  String _getLabel(int index) {
    const labels = ['PM2.5', 'PM10', 'CO', 'NO2', 'SO2', 'O3', 'NH3'];
    return labels[index];
  }
}*/

/*import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';



class ForecastDataPage extends StatefulWidget {
  final Map<String, dynamic> forecastData;

  const ForecastDataPage({Key? key, required this.forecastData}) : super(key: key);

  @override
  State<ForecastDataPage> createState() => _ForecastDataPageState();
}

class _ForecastDataPageState extends State<ForecastDataPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  final List<String> pollutantLabels = ["PM2.5", "PM10", "NO2", "O3", "SO2", "CO", "NH3"];
  final Map<String, String> pollutantKey = {
    "PM2.5": "pm25_max",
    "PM10": "pm10_max",
    "NO2": "no2_max",
    "O3": "o3_max",
    "SO2": "so2_max",
    "CO": "co_max",
    "NH3": "nh3_max",
  };

  int selectedIndex = 1; // default to PM10

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool('isLoggedIn') ?? true;
    setState(() {
      _isLoggedIn = logged;
      _isLoading = false;
    });
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


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text("")),
        body: const Center(child: Text("You must be logged in to view this page.", style: TextStyle(color: Colors.red))),
      );
    }

    final raw = widget.forecastData['forecast'];
    if (raw == null || (raw is List && raw.isEmpty)) {
      return const Scaffold(body: Center(child: Text('No forecast data available')));
    }

    final List<Map<String, dynamic>> forecastList = (raw as List<dynamic>).cast<Map<String, dynamic>>();
    final key = pollutantKey[pollutantLabels[selectedIndex]] ?? pollutantKey.values.first;
    final List<double> values = forecastList.map((d) => _toDouble(d[key])).toList();
    final List<String> labels = forecastList.map((d) => _formatLabel(d['day'].toString())).toList();

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
      appBar: AppBar(title: const Text("4-Day Air Quality Forecast")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(pollutantLabels.length, (i) {
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: ChoiceChip(
                      label: Text(pollutantLabels[i]),
                      selected: selected,
                      onSelected: (_) => setState(() => selectedIndex = i),
                      selectedColor: Colors.deepPurple.shade100,
                      backgroundColor: Colors.grey.shade50,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
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
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: interval,
                        getTitlesWidget: (value, meta) =>
                            Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                          return Text(labels[idx], style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
              columns: const [
                DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Value (µg/m³)", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List.generate(labels.length, (i) {
                return DataRow(cells: [
                  DataCell(Text(labels[i])),
                  DataCell(Text(values[i].toStringAsFixed(2))),
                ]);
              }),
            ),
          ],
        ),
      ),
    );
  }
}*/
import 'dart:math' as math;
import 'package:aqmapp/otpsent.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';


class ForecastDataPage extends StatefulWidget {
  final Map<String, dynamic> forecastData;

  const ForecastDataPage({Key? key, required this.forecastData}) : super(key: key);

  @override
  State<ForecastDataPage> createState() => _ForecastDataPageState();
}

class _ForecastDataPageState extends State<ForecastDataPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  final List<String> pollutantLabels = ["PM2.5", "PM10", "NO2", "O3", "SO2", "CO", "NH3"];
  final Map<String, String> pollutantKey = {
    "PM2.5": "pm25_max",
    "PM10": "pm10_max",
    "NO2": "no2_max",
    "O3": "o3_max",
    "SO2": "so2_max",
    "CO": "co_max",
    "NH3": "nh3_max",
  };

  int selectedIndex = 1; // default to PM10

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final logged = prefs.getBool('isLoggedIn') ?? false;

    if (!logged) {
      // Not logged in → show popup & redirect
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
    } else {
      setState(() {
        _isLoggedIn = true;
      });
    }

    setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isLoggedIn) {
      // return empty container while redirecting
      return const Scaffold(body: SizedBox.shrink());
    }

    final raw = widget.forecastData['forecast'];
    if (raw == null || (raw is List && raw.isEmpty)) {
      return const Scaffold(body: Center(child: Text('No forecast data available')));
    }

    final List<Map<String, dynamic>> forecastList =
        (raw as List<dynamic>).cast<Map<String, dynamic>>();
    final key = pollutantKey[pollutantLabels[selectedIndex]] ?? pollutantKey.values.first;
    final List<double> values = forecastList.map((d) => _toDouble(d[key])).toList();
    final List<String> labels = forecastList.map((d) => _formatLabel(d['day'].toString())).toList();

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
      appBar: AppBar(title: const Text("4-Day Air Quality Forecast")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(pollutantLabels.length, (i) {
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: ChoiceChip(
                      label: Text(pollutantLabels[i]),
                      selected: selected,
                      onSelected: (_) => setState(() => selectedIndex = i),
                      selectedColor: Colors.deepPurple.shade100,
                      backgroundColor: Colors.grey.shade50,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
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
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: interval,
                        getTitlesWidget: (value, meta) =>
                            Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                          return Text(labels[idx], style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
              columns: const [
                DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Value (µg/m³)", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List.generate(labels.length, (i) {
                return DataRow(cells: [
                  DataCell(Text(labels[i])),
                  DataCell(Text(values[i].toStringAsFixed(2))),
                ]);
              }),
            ),
          ],
        ),
      ),
    );
  }
}
