// lib/utils/sensor_name_mapper.dart
class SensorNameMapper {
  static const Map<String, String> _mapping = {
    "lora-v1": "Station 1(ASIET Campus)",
    "loradev2": "Station 2(Mattoor Junction)",
    "lora-v3": "Station 3(Airport Road)",
  };

  static String displayName(String sensorName) {
    return _mapping[sensorName] ?? sensorName; // fallback to original if not found
  }
}
