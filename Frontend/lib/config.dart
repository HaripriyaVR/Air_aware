class AppConfig {
  // Toggle this when switching between emulator & real device
  static const bool useEmulator = false;

  static const String baseUrl = useEmulator
      ? "http://10.0.2.2:5000" // emulator (localhost)  // Emulator
      : "http://172.17.249.104:5000"; // Real Device (Wi-Fi)

  static const String realtime = "$baseUrl/api/realtime";
  static const String forecast = "$baseUrl/api/forecast";
  static const String userAqi = "$baseUrl/api/user-aqi";
  static const String aqiSummary = "$baseUrl/api/aqi";
}
