import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';

class FirebaseService extends GetxService {
  late DatabaseReference _database;
  
  // Initialize Firebase connection
  Future<FirebaseService> init() async {
    _database = FirebaseDatabase.instance.ref('esp32_desk_display');
    print('✅ Firebase Service initialized');
    return this;
  }
  
  // Get reference to a specific path
  DatabaseReference getRef(String path) {
    return _database.child(path);
  }
  
  // DEVICE STATUS
  Stream<DatabaseEvent> getDeviceStatus() {
    return _database.child('device_status').onValue;
  }
  
  // TODOS
  Stream<DatabaseEvent> getTodos() {
    return _database.child('todos').onValue;
  }
  
  Future<void> addTodo(String text) async {
    final todosRef = _database.child('todos');
    final snapshot = await todosRef.get();
    int count = 1;
    
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      count = data.length + 1;
    }
    
    await todosRef.child('todo_$count').set({
      'text': text,
      'completed': false,
      'priority': count,
      'createdAt': DateTime.now().toIso8601String(),
      'lastModified': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> updateTodo(String todoId, Map<String, dynamic> updates) async {
    updates['lastModified'] = DateTime.now().toIso8601String();
    await _database.child('todos/$todoId').update(updates);
  }
  
  Future<void> deleteTodo(String todoId) async {
    await _database.child('todos/$todoId').remove();
  }
  
  Future<void> clearCompletedTodos() async {
    final snapshot = await _database.child('todos').get();
    if (snapshot.exists) {
      final todos = snapshot.value as Map;
      for (var entry in todos.entries) {
        final todo = entry.value as Map;
        if (todo['completed'] == true) {
          await _database.child('todos/${entry.key}').remove();
        }
      }
    }
  }
  
  // MESSAGES
  Stream<DatabaseEvent> getMessages() {
    return _database.child('customMessage').onValue;
  }
  
  Future<void> sendMessage(String message) async {
    await _database.child('customMessage').set({
      'message': message,
      'sentAt': DateTime.now().toIso8601String(),
      'seenAt': null,
      'seen': false,
      'expiresAt': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
      'active': true,
    });
  }
  
  // SETTINGS
  Stream<DatabaseEvent> getSettings() {
    return _database.child('settings').onValue;
  }
  
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    settings['lastModified'] = DateTime.now().toIso8601String();
    await _database.child('settings').update(settings);
  }
}