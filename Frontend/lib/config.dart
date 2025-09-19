class AppConfig {
  // Toggle this when switching between emulator & real device
  static const bool useEmulator = false;

  static const String baseUrl = useEmulator
      ? "http://127.0.0.1:5000" // emulator (localhost)  // Emulator
<<<<<<< HEAD
      : "http://172.25.1.44:5000"; // Real Device (Wi-Fi)
=======
      : "http://172.25.1.113:5000"; // Real Device (Wi-Fi)
>>>>>>> cea4e1571716730db2aadbe7cce51a880bb5f0de

  static const String realtime = "$baseUrl/api/realtime";
  static const String forecast = "$baseUrl/api/forecast";
  static const String userAqi = "$baseUrl/api/user-aqi";
  static const String aqiSummary = "$baseUrl/api/aqi";
}
