import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_status_model.dart';
import '../services/firebase_service.dart';

class DeviceController extends GetxController {
  final FirebaseService _firebaseService = Get.find();
  
  // Observable variables (reactive)
  final deviceStatus = Rx<DeviceStatus?>(null);
  final deviceName = ''.obs;
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadDeviceName();
    listenToDeviceStatus();
  }
  
  // Load device name from local storage
  Future<void> loadDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    deviceName.value = prefs.getString('device_name') ?? 'My E-Note Table';
  }
  
  // Save device name to local storage
  Future<void> saveDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', name);
    deviceName.value = name;
  }
  
  // Listen to device status changes from Firebase
  void listenToDeviceStatus() {
    _firebaseService.getDeviceStatus().listen(
      (event) {
        if (event.snapshot.value != null) {
          try {
            final data = event.snapshot.value as Map;
            deviceStatus.value = DeviceStatus.fromMap(data);
            isLoading.value = false;
            hasError.value = false;
          } catch (e) {
            print('Error parsing device status: $e');
            isLoading.value = false;
            hasError.value = true;
            errorMessage.value = 'Failed to load device data';
          }
        } else {
          // No data exists yet
          isLoading.value = false;
          hasError.value = true;
          errorMessage.value = 'No device data found. Make sure your ESP32 is connected.';
        }
      },
      onError: (error) {
        print('Firebase error: $error');
        isLoading.value = false;
        hasError.value = true;
        errorMessage.value = 'Connection error';
      },
    );
  }
  
  // Retry loading device status
  void retryLoading() {
    isLoading.value = true;
    hasError.value = false;
    listenToDeviceStatus();
  }
  
  // Update settings in Firebase
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _firebaseService.updateSettings(settings);
      Get.snackbar('Success', 'Settings updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update settings: $e');
    }
  }
}