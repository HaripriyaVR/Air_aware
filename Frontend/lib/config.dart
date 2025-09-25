class AppConfig {
  // Toggle this when switching between emulator & real device
  static const bool useEmulator = false;

  static const String baseUrl = useEmulator
      ? "http://127.0.0.1:5000" // emulator (localhost)  // Emulator
<<<<<<< HEAD
      : "http://172.25.1.31:5000"; // Real Device (Wi-Fi)
=======
      : "http://192.168.43.104:5000"; // Real Device (Wi-Fi)
>>>>>>> 3cfc3c30554243525c9210056e8258a2a2358038

  static const String realtime = "$baseUrl/api/realtime";
  static const String forecast = "$baseUrl/api/forecast";
  static const String userAqi = "$baseUrl/api/user-aqi";
  static const String aqiSummary = "$baseUrl/api/aqi";
}
