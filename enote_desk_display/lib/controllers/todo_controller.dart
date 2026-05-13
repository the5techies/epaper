import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/todo_model.dart';
import '../services/firebase_service.dart';

class TodoController extends GetxController {
  final FirebaseService _firebaseService = Get.find();
  
  // Observable list of todos
  final todos = <Todo>[].obs;
  final archivedTodos = <Todo>[].obs;
  final isLoading = true.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadArchivedTodos();
    listenToTodos();
    checkAndArchiveOldTodos();
  }
  
  // Listen to todos changes from Firebase
  void listenToTodos() {
    _firebaseService.getTodos().listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map;
        final todoList = <Todo>[];
        
        data.forEach((key, value) {
          todoList.add(Todo.fromMap(key, value));
        });
        
        // Sort by priority
        todoList.sort((a, b) => a.priority.compareTo(b.priority));
        todos.value = todoList;
        isLoading.value = false;
      } else {
        todos.value = [];
        isLoading.value = false;
      }
    });
  }
  
  // Check and archive old completed todos (>24 hours)
  Future<void> checkAndArchiveOldTodos() async {
    final now = DateTime.now();
    final todosToArchive = <Todo>[];
    
    for (var todo in todos) {
      if (todo.completed) {
        final age = now.difference(todo.lastModified);
        if (age.inHours >= 24) {
          todosToArchive.add(todo);
        }
      }
    }
    
    // Archive and delete from server
    for (var todo in todosToArchive) {
      await archiveTodo(todo);
      await _firebaseService.deleteTodo(todo.id);
    }
    
    if (todosToArchive.isNotEmpty) {
      print('✅ Archived ${todosToArchive.length} old completed todos');
    }
  }
  
  // Archive todo to local storage
  Future<void> archiveTodo(Todo todo) async {
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList('archived_todos') ?? [];
    
    archived.add(json.encode(todo.toMap()));
    await prefs.setStringList('archived_todos', archived);
    
    // Update local list
    archivedTodos.add(todo);
  }
  
  // Load archived todos from local storage
  Future<void> loadArchivedTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList('archived_todos') ?? [];
    
    archivedTodos.value = archived.map((item) {
      final map = json.decode(item) as Map<String, dynamic>;
      return Todo.fromMap('archived_${archived.indexOf(item)}', map);
    }).toList();
  }
  
  // Delete individual archived todo
  Future<void> deleteArchivedTodo(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList('archived_todos') ?? [];
    
    archived.removeAt(index);
    await prefs.setStringList('archived_todos', archived);
    
    archivedTodos.removeAt(index);
    Get.snackbar('Success', 'Archived todo deleted');
  }
  
  // Clear all archived todos
  Future<void> clearAllArchives() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('archived_todos');
    
    archivedTodos.clear();
    Get.snackbar('Success', 'All archives cleared');
  }
  
  // Add new todo
  Future<void> addTodo(String text) async {
    if (text.trim().isEmpty) {
      Get.snackbar('Error', 'Todo text cannot be empty');
      return;
    }
    
    try {
      await _firebaseService.addTodo(text.trim());
      Get.snackbar('Success', 'Todo added successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to add todo: $e');
    }
  }
  
  // Toggle todo completion
  Future<void> toggleTodo(Todo todo) async {
    try {
      await _firebaseService.updateTodo(todo.id, {
        'completed': !todo.completed,
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to update todo: $e');
    }
  }
  
  // Update todo text
  Future<void> updateTodo(Todo todo, String newText) async {
    if (newText.trim().isEmpty) {
      Get.snackbar('Error', 'Todo text cannot be empty');
      return;
    }
    
    try {
      await _firebaseService.updateTodo(todo.id, {
        'text': newText.trim(),
      });
      Get.snackbar('Success', 'Todo updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update todo: $e');
    }
  }
  
  // Delete todo
  Future<void> deleteTodo(String todoId) async {
    try {
      await _firebaseService.deleteTodo(todoId);
      Get.snackbar('Success', 'Todo deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete todo: $e');
    }
  }
  
  // Clear all completed todos
  Future<void> clearCompleted() async {
    try {
      await _firebaseService.clearCompletedTodos();
      Get.snackbar('Success', 'Completed todos cleared');
    } catch (e) {
      Get.snackbar('Error', 'Failed to clear todos: $e');
    }
  }
}