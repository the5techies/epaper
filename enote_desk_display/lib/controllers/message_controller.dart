import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/message_model.dart';
import '../services/firebase_service.dart';

class MessageController extends GetxController {
  final FirebaseService _firebaseService = Get.find();
  
  // Observable variables
  final currentMessage = Rx<Message?>(null);
  final messageHistory = <Message>[].obs;
  final isLoading = true.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadMessageHistory();
    listenToMessages();
  }
  
  // Listen to message changes from Firebase
  void listenToMessages() {
    _firebaseService.getMessages().listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map;
        currentMessage.value = Message.fromMap(data);
        
        // Add to history only if active
        if (currentMessage.value != null && currentMessage.value!.active) {
          saveToHistory(currentMessage.value!);
        }
        
        // Update seen status in history if message exists
        if (currentMessage.value != null) {
          updateSeenStatusInHistory(currentMessage.value!);
        }
        
        isLoading.value = false;
      } else {
        currentMessage.value = null;
        isLoading.value = false;
      }
    });
  }
  
  // Save message to local history
  Future<void> saveToHistory(Message message) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('message_history') ?? [];
    
    // Check if already exists in observable list
    final exists = messageHistory.any((msg) => 
      msg.sentAt.toString() == message.sentAt.toString()
    );
    
    if (!exists) {
      // Add to local storage
      final messageMap = {
        'message': message.message,
        'sentAt': message.sentAt.toIso8601String(),
        'seenAt': message.seenAt?.toIso8601String(),
        'seen': message.seen,
        'expiresAt': message.expiresAt.toIso8601String(),
        'active': message.active,
      };
      
      history.insert(0, json.encode(messageMap));
      await prefs.setStringList('message_history', history);
      
      // Update observable list
      messageHistory.insert(0, message);
      print('✅ Message saved to history');
    }
  }
  
  // Update seen status for matching message in history
Future<void> updateSeenStatusInHistory(Message message) async {
  print('🔍 Checking seen status update for message: "${message.message.substring(0, min(20, message.message.length))}"');
  print('   Firebase seen status: ${message.seen}');
  
  // Find matching message in history by sentAt time
  for (int i = 0; i < messageHistory.length; i++) {
    print('   Comparing with history[$i] sentAt: ${messageHistory[i].sentAt} vs ${message.sentAt}');
    
    if (messageHistory[i].sentAt.toString() == message.sentAt.toString()) {
      print('   ✅ Found matching message! Current seen: ${messageHistory[i].seen}, New seen: ${message.seen}');
      
      // Update if seen status changed
      if (messageHistory[i].seen != message.seen) {
        print('   🔄 Updating seen status from ${messageHistory[i].seen} to ${message.seen}');
        
        // Create updated message
        final updatedMessage = Message(
          message: message.message,
          sentAt: message.sentAt,
          seenAt: message.seenAt,
          seen: message.seen,
          expiresAt: message.expiresAt,
          active: message.active,
        );
        
        messageHistory[i] = updatedMessage;
        
        // Force UI update
        messageHistory.refresh();
        
        // Save updated history to storage
        final prefs = await SharedPreferences.getInstance();
        final updatedHistory = messageHistory.map((msg) {
          return json.encode({
            'message': msg.message,
            'sentAt': msg.sentAt.toIso8601String(),
            'seenAt': msg.seenAt?.toIso8601String(),
            'seen': msg.seen,
            'expiresAt': msg.expiresAt.toIso8601String(),
            'active': msg.active,
          });
        }).toList();
        
        await prefs.setStringList('message_history', updatedHistory);
        print('   ✅ Updated seen status saved!');
        break;
      } else {
        print('   ⏭️ Seen status unchanged, skipping update');
      }
    }
  }
}
  
  // Load message history from local storage
  Future<void> loadMessageHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('message_history') ?? [];
    
    messageHistory.value = history.map((item) {
      final map = json.decode(item) as Map<String, dynamic>;
      return Message.fromMap(map);
    }).toList();
    
    print('✅ Loaded ${messageHistory.length} messages from storage');
  }
  
  // Delete message from history
  Future<void> deleteMessage(int index) async {
    if (index < 0 || index >= messageHistory.length) {
      print('❌ Invalid index: $index');
      return;
    }
    
    final message = messageHistory[index];
    print('🗑️ Deleting message at index $index: "${message.message}"');
    
    // If message is still active, delete from server
    if (message.active && !message.isExpired) {
      try {
        await _firebaseService.getRef('customMessage').update({
          'active': false,
        });
        print('✅ Deleted active message from server');
      } catch (e) {
        print('❌ Failed to delete from server: $e');
      }
    }
    
    // Remove from observable list FIRST
    messageHistory.removeAt(index);
    
    // Then save the updated list to storage
    final prefs = await SharedPreferences.getInstance();
    final updatedHistory = messageHistory.map((msg) {
      return json.encode({
        'message': msg.message,
        'sentAt': msg.sentAt.toIso8601String(),
        'seenAt': msg.seenAt?.toIso8601String(),
        'seen': msg.seen,
        'expiresAt': msg.expiresAt.toIso8601String(),
        'active': msg.active,
      });
    }).toList();
    
    await prefs.setStringList('message_history', updatedHistory);
    print('✅ Message deleted from storage. Remaining: ${messageHistory.length}');
    
    Get.snackbar('Success', 'Message deleted');
  }
  
  // Clear all message history
  Future<void> clearAllMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('message_history');
    
    messageHistory.clear();
    print('✅ All messages cleared');
    Get.snackbar('Success', 'All messages cleared');
  }
  
  // Send new message
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) {
      Get.snackbar('Error', 'Message cannot be empty');
      return;
    }
    
    if (message.length > 200) {
      Get.snackbar('Error', 'Message too long (max 200 characters)');
      return;
    }
    
    try {
      await _firebaseService.sendMessage(message.trim());
      Get.snackbar('Success', 'Message sent to device');
    } catch (e) {
      Get.snackbar('Error', 'Failed to send message: $e');
    }
  }
  
  // Get remaining characters
  int getRemainingChars(String message) {
    return 200 - message.length;
  }
}