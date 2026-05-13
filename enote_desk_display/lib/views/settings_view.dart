import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends StatelessWidget {
  final SettingsController controller = Get.put(SettingsController());
  final TextEditingController cityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Color(0xFFF5F5DC),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        // Set city text field value
        if (cityController.text.isEmpty && controller.city.value.isNotEmpty) {
          cityController.text = controller.city.value;
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Mode
              Text(
                'Display Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.displayMode.value,
                    isExpanded: true,
                    dropdownColor: Color(0xFF2A2A2A),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    items: [
                      DropdownMenuItem(value: 'calendar', child: Text('Calendar')),
                      DropdownMenuItem(value: 'todo', child: Text('Todo')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.updateDisplayMode(value);
                      }
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Weather Location
              Text(
                'Weather Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: cityController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter city name (e.g., Kottayam)',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF2A2A2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade800),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade800),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFF5F5DC)),
                  ),
                  suffixIcon: controller.isFetchingLocation.value
                      ? Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Color(0xFFF5F5DC)),
                            ),
                          ),
                        )
                      : Icon(Icons.search, color: Colors.grey),
                ),
                onSubmitted: (value) async {
                  if (value.isNotEmpty) {
                    final result = await controller.fetchCoordinatesFromCity(value);
                    if (result != null) {
                      await controller.updateLocation(
                        value,
                        result['lat']!,
                        result['lon']!,
                      );
                      // Extract just city name from display name if available
                      final displayName = result['displayName']!;
                      cityController.text = value;
                    }
                  }
                },
              ),
              
              SizedBox(height: 30),
              
              // Temperature Unit
              Text(
                'Temperature Unit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.temperatureUnit.value,
                    isExpanded: true,
                    dropdownColor: Color(0xFF2A2A2A),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    items: [
                      DropdownMenuItem(value: 'celsius', child: Text('Celsius (°C)')),
                      DropdownMenuItem(value: 'fahrenheit', child: Text('Fahrenheit (°F)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.updateTemperatureUnit(value);
                      }
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Timezone
              Text(
                'Timezone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.timezone.value,
                    isExpanded: true,
                    dropdownColor: Color(0xFF2A2A2A),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    items: controller.timezones.map((tz) {
                      return DropdownMenuItem(
                        value: tz['value'],
                        child: Text(tz['name']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        controller.updateTimezone(value);
                      }
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Update Interval
              Text(
                'Update Interval',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Current: ${controller.getIntervalText()}',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: controller.updateInterval.value,
                    isExpanded: true,
                    dropdownColor: Color(0xFF2A2A2A),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    items: [
                      DropdownMenuItem(value: 300, child: Text('5 minutes')),
                      DropdownMenuItem(value: 600, child: Text('10 minutes')),
                      DropdownMenuItem(value: 900, child: Text('15 minutes')),
                      DropdownMenuItem(value: 1800, child: Text('30 minutes')),
                      DropdownMenuItem(value: 3600, child: Text('1 hour')),
                      DropdownMenuItem(value: 7200, child: Text('2 hours')),
                      DropdownMenuItem(value: 14400, child: Text('4 hours')),
                      DropdownMenuItem(value: 21600, child: Text('6 hours')),
                      DropdownMenuItem(value: 43200, child: Text('12 hours')),
                      DropdownMenuItem(value: 86400, child: Text('24 hours')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.updateUpdateInterval(value);
                      }
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 30),
            ],
          ),
        );
      }),
    );
  }
}