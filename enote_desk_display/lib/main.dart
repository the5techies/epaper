import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'controllers/device_controller.dart';
import 'controllers/todo_controller.dart';
import 'controllers/message_controller.dart';
import 'views/home_view.dart';
import 'controllers/settings_controller.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize services and controllers
// Initialize services and controllers
await Get.putAsync(() => FirebaseService().init());
Get.put(DeviceController());
Get.put(TodoController());
Get.put(MessageController());
Get.put(SettingsController());
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'E-Note Desk Display',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Color(0xFFF5F5DC), // Off-white
        fontFamily: 'Arial',
      ),
      home: HomeView(),
    );
  }
}