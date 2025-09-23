class AppConfig {
  // Toggle this when switching between emulator & real device
  static const bool useEmulator = false;

  static const String baseUrl = useEmulator
      ? "http://127.0.0.1:5000" // emulator (localhost)  // Emulator
<<<<<<< HEAD
      : "http://172.25.3.97:5000"; // Real Device (Wi-Fi)
=======
      : "http://192.168.43.104:5000"; // Real Device (Wi-Fi)
>>>>>>> df49f6bcfc10966c5be9df3c8dfaf5fe61e3f06a

  static const String realtime = "$baseUrl/api/realtime";
  static const String forecast = "$baseUrl/api/forecast";
  static const String userAqi = "$baseUrl/api/user-aqi";
  static const String aqiSummary = "$baseUrl/api/aqi";
}
