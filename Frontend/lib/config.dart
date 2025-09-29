class AppConfig {
  // Toggle this when switching between emulator & real device
  static const bool useEmulator = false;

  static const String baseUrl = useEmulator
      ? "http://127.0.0.1:5000" // emulator (localhost)  // Emulator
<<<<<<< HEAD
      : "http://172.25.0.104:5000"; // Real Device (Wi-Fi)
=======
      : "http://172.19.213.104:5000"; // Real Device (Wi-Fi)
>>>>>>> a6cf69174c86e62fc520e7628a5052f21d892706

  static const String realtime = "$baseUrl/api/realtime";
  static const String forecast = "$baseUrl/api/forecast";
  static const String userAqi = "$baseUrl/api/user-aqi";
  static const String aqiSummary = "$baseUrl/api/aqi";
}
