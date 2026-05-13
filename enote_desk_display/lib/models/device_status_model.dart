import 'package:intl/intl.dart';

class DeviceStatus {
  final int battery;
  final int wifiStrength;
  final String lastSeen;
  final bool isOnline;
  final String firmwareVersion;

  DeviceStatus({
    required this.battery,
    required this.wifiStrength,
    required this.lastSeen,
    required this.isOnline,
    required this.firmwareVersion,
  });

  // Convert Firebase data to DeviceStatus object
  factory DeviceStatus.fromMap(Map<dynamic, dynamic> map) {
    return DeviceStatus(
      battery: map['battery'] ?? 0,
      wifiStrength: map['wifiStrength'] ?? 0,
      lastSeen: map['lastSeen']?.toString() ?? '0',
      isOnline: map['isOnline'] ?? false,
      firmwareVersion: map['firmwareVersion'] ?? '1.0.0',
    );
  }

  // Get WiFi strength as text
  String get wifiStrengthText {
    if (wifiStrength > -50) return 'Excellent';
    if (wifiStrength > -60) return 'Good';
    if (wifiStrength > -70) return 'Fair';
    return 'Weak';
  }

  // Get connection status text
  String get statusText {
    return isOnline ? 'Connected' : 'Offline';
  }
  
  // Get last seen as readable text
  String get lastSeenText {
    try {
      // Parse ISO datetime string
      DateTime lastSeenDate = DateTime.parse(lastSeen);
      DateTime now = DateTime.now();
      Duration diff = now.difference(lastSeenDate);
      
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      
      // For older dates, show formatted date
      return DateFormat('MMM d, y').format(lastSeenDate);
    } catch (e) {
      return 'Unknown';
    }
  }
}