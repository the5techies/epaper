import 'package:get/get.dart';
import '../services/firebase_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsController extends GetxController {
  final FirebaseService _firebaseService = Get.find();
  
  // Observable variables
  final displayMode = 'calendar'.obs;
  final city = ''.obs;
  final latitude = ''.obs;
  final longitude = ''.obs;
  final temperatureUnit = 'celsius'.obs;
  final timezone = ''.obs;
  final updateInterval = 3600.obs; // in seconds
  final isLoading = true.obs;
  final isFetchingLocation = false.obs;
  
  // Comprehensive list of timezones with GMT offsets
  final List<Map<String, String>> timezones = [
    {'name': 'UTC (GMT +0:00)', 'value': 'UTC'},
    {'name': 'Pacific/Midway (GMT -11:00)', 'value': 'Pacific/Midway'},
    {'name': 'Pacific/Honolulu (GMT -10:00)', 'value': 'Pacific/Honolulu'},
    {'name': 'America/Anchorage (GMT -9:00)', 'value': 'America/Anchorage'},
    {'name': 'America/Los_Angeles (GMT -8:00)', 'value': 'America/Los_Angeles'},
    {'name': 'America/Denver (GMT -7:00)', 'value': 'America/Denver'},
    {'name': 'America/Chicago (GMT -6:00)', 'value': 'America/Chicago'},
    {'name': 'America/New_York (GMT -5:00)', 'value': 'America/New_York'},
    {'name': 'America/Caracas (GMT -4:00)', 'value': 'America/Caracas'},
    {'name': 'America/Argentina/Buenos_Aires (GMT -3:00)', 'value': 'America/Argentina/Buenos_Aires'},
    {'name': 'Atlantic/South_Georgia (GMT -2:00)', 'value': 'Atlantic/South_Georgia'},
    {'name': 'Atlantic/Cape_Verde (GMT -1:00)', 'value': 'Atlantic/Cape_Verde'},
    {'name': 'Europe/London (GMT +0:00)', 'value': 'Europe/London'},
    {'name': 'Europe/Paris (GMT +1:00)', 'value': 'Europe/Paris'},
    {'name': 'Europe/Berlin (GMT +1:00)', 'value': 'Europe/Berlin'},
    {'name': 'Europe/Athens (GMT +2:00)', 'value': 'Europe/Athens'},
    {'name': 'Africa/Cairo (GMT +2:00)', 'value': 'Africa/Cairo'},
    {'name': 'Europe/Moscow (GMT +3:00)', 'value': 'Europe/Moscow'},
    {'name': 'Asia/Dubai (GMT +4:00)', 'value': 'Asia/Dubai'},
    {'name': 'Asia/Karachi (GMT +5:00)', 'value': 'Asia/Karachi'},
    {'name': 'Asia/Kolkata (GMT +5:30)', 'value': 'Asia/Kolkata'},
    {'name': 'Asia/Dhaka (GMT +6:00)', 'value': 'Asia/Dhaka'},
    {'name': 'Asia/Bangkok (GMT +7:00)', 'value': 'Asia/Bangkok'},
    {'name': 'Asia/Singapore (GMT +8:00)', 'value': 'Asia/Singapore'},
    {'name': 'Asia/Shanghai (GMT +8:00)', 'value': 'Asia/Shanghai'},
    {'name': 'Asia/Hong_Kong (GMT +8:00)', 'value': 'Asia/Hong_Kong'},
    {'name': 'Asia/Tokyo (GMT +9:00)', 'value': 'Asia/Tokyo'},
    {'name': 'Asia/Seoul (GMT +9:00)', 'value': 'Asia/Seoul'},
    {'name': 'Australia/Adelaide (GMT +9:30)', 'value': 'Australia/Adelaide'},
    {'name': 'Australia/Sydney (GMT +10:00)', 'value': 'Australia/Sydney'},
    {'name': 'Australia/Brisbane (GMT +10:00)', 'value': 'Australia/Brisbane'},
    {'name': 'Pacific/Noumea (GMT +11:00)', 'value': 'Pacific/Noumea'},
    {'name': 'Pacific/Auckland (GMT +12:00)', 'value': 'Pacific/Auckland'},
    {'name': 'Pacific/Fiji (GMT +12:00)', 'value': 'Pacific/Fiji'},
    {'name': 'Pacific/Tongatapu (GMT +13:00)', 'value': 'Pacific/Tongatapu'},
  ];
  
  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }
  
  // Load settings from Firebase
  void loadSettings() {
    _firebaseService.getSettings().listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map;
        
        displayMode.value = data['displayMode'] ?? 'calendar';
        temperatureUnit.value = data['temperatureUnit'] ?? 'celsius';
        timezone.value = data['timezone'] ?? 'Asia/Kolkata';
        updateInterval.value = data['updateInterval'] ?? 3600;
        
        // Location
        if (data['location'] != null) {
          final location = data['location'] as Map;
          city.value = location['city'] ?? '';
          latitude.value = location['lat']?.toString() ?? '';
          longitude.value = location['lon']?.toString() ?? '';
        }
        
        isLoading.value = false;
      }
    });
  }
  
  // Fetch coordinates from city name
  Future<Map<String, String>?> fetchCoordinatesFromCity(String cityName) async {
    if (cityName.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter a city name');
      return null;
    }
    
    isFetchingLocation.value = true;
    
    try {
      // Using OpenStreetMap Nominatim API (free, no API key)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cityName)}&format=json&limit=1'
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ENoteDeskDisplay/1.0'},
      );
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        
        if (data.isNotEmpty) {
          final result = data[0];
          isFetchingLocation.value = false;
          return {
            'lat': result['lat'],
            'lon': result['lon'],
            'displayName': result['display_name'],
          };
        } else {
          isFetchingLocation.value = false;
          Get.snackbar('Not Found', 'City "$cityName" not found. Try a different name.');
          return null;
        }
      } else {
        isFetchingLocation.value = false;
        Get.snackbar('Error', 'Failed to fetch coordinates');
        return null;
      }
    } catch (e) {
      isFetchingLocation.value = false;
      Get.snackbar('Error', 'Network error: $e');
      return null;
    }
  }
  
  // Update display mode
  Future<void> updateDisplayMode(String mode) async {
    try {
      await _firebaseService.updateSettings({'displayMode': mode});
      displayMode.value = mode;
      Get.snackbar('Success', 'Display mode updated');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update: $e');
    }
  }
  
  // Update location
  Future<void> updateLocation(String newCity, String lat, String lon) async {
    try {
      await _firebaseService.updateSettings({
        'location': {
          'city': newCity,
          'lat': lat,
          'lon': lon,
        }
      });
      city.value = newCity;
      latitude.value = lat;
      longitude.value = lon;
      Get.snackbar('Success', 'Location updated');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update: $e');
    }
  }
  
  // Update temperature unit
  Future<void> updateTemperatureUnit(String unit) async {
    try {
      await _firebaseService.updateSettings({'temperatureUnit': unit});
      temperatureUnit.value = unit;
      Get.snackbar('Success', 'Temperature unit updated');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update: $e');
    }
  }
  
  // Update timezone
  Future<void> updateTimezone(String tz) async {
    try {
      await _firebaseService.updateSettings({'timezone': tz});
      timezone.value = tz;
      Get.snackbar('Success', 'Timezone updated');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update: $e');
    }
  }
  
  // Update interval
  Future<void> updateUpdateInterval(int seconds) async {
    try {
      await _firebaseService.updateSettings({'updateInterval': seconds});
      updateInterval.value = seconds;
      Get.snackbar('Success', 'Update interval changed');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update: $e');
    }
  }
  
  // Get update interval as readable text
  String getIntervalText() {
    final seconds = updateInterval.value;
    if (seconds < 60) return '$seconds seconds';
    if (seconds < 3600) return '${seconds ~/ 60} minutes';
    return '${seconds ~/ 3600} hours';
  }
  
  // Convert seconds to minutes or hours for display
  Map<String, dynamic> getIntervalForDisplay() {
    final seconds = updateInterval.value;
    if (seconds >= 3600 && seconds % 3600 == 0) {
      return {'value': seconds ~/ 3600, 'unit': 'hours'};
    } else {
      return {'value': seconds ~/ 60, 'unit': 'minutes'};
    }
  }
}