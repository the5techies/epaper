import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/device_controller.dart';
import 'settings_view.dart';

class DeviceView extends StatelessWidget {
  final DeviceController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          // Show error state
          if (controller.hasError.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 64),
                  SizedBox(height: 20),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => controller.retryLoading(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF5F5DC),
                      foregroundColor: Colors.black,
                    ),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Show loading only initially
          if (controller.isLoading.value && controller.deviceStatus.value == null) {
            return Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Device Replica
                Container(
                  padding: EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5DC), // Off-white
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    controller.deviceName.value,
                    style: TextStyle(
                      fontFamily: 'Cursive',
                      fontSize: 24,
                      color: Colors.black,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                SizedBox(height: 30),
                
                // Device Status
                if (controller.deviceStatus.value != null) ...[
                  _buildStatusRow(
                    Icons.battery_charging_full,
                    'Battery',
                    '${controller.deviceStatus.value!.battery}%',
                  ),
                  SizedBox(height: 15),
                  _buildStatusRow(
                    Icons.wifi,
                    'WiFi',
                    controller.deviceStatus.value!.wifiStrengthText,
                  ),
                  SizedBox(height: 15),
                  _buildStatusRow(
                    Icons.circle,
                    'Status',
                    controller.deviceStatus.value!.statusText,
                    statusColor: controller.deviceStatus.value!.isOnline 
                        ? Colors.green 
                        : Colors.red,
                  ),
                ],
                
                SizedBox(height: 30),
                Divider(color: Colors.grey),
                SizedBox(height: 20),
                
                // Settings Option
                _buildListTile(
                  Icons.settings,
                  'Settings',
                  () {
                    // TODO: Navigate to settings screen
                    Get.to(() => SettingsView());
                  },
                ),
                
                SizedBox(height: 15),
                
                // About Device Option
                _buildListTile(
                  Icons.info_outline,
                  'About Device',
                  () {
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildStatusRow(IconData icon, String label, String value, {Color? statusColor}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        SizedBox(width: 15),
        Text(
          '$label:',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            color: statusColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  
  void _showAboutDialog(BuildContext context) {
    final device = controller.deviceStatus.value;
    if (device == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text('About Device', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Firmware: ${device.firmwareVersion}', 
              style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text('Model: EPP-T-V1.0', 
              style: TextStyle(color: Colors.white)),
            SizedBox(height: 8),
            Text('Device Status: ${device.lastSeenText}',
              style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Color(0xFFF5F5DC))),
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}