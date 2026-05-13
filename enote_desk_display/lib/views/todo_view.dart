import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/todo_controller.dart';

class TodoView extends StatelessWidget {
  final TodoController controller = Get.find();
  final TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with Archive Button
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F5DC),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          'To-Do List',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.archive, color: Color(0xFFF5F5DC), size: 28),
                    onPressed: () => _showArchiveDialog(context),
                  ),
                ],
              ),
            ),
            
            // Todo List
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.todos.isEmpty) {
                  return Center(
                    child: Text(
                      'No tasks yet!\nAdd one below',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }
                
                if (controller.todos.isEmpty) {
                  return Center(
                    child: Text(
                      'No tasks yet!\nAdd one below',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  itemCount: controller.todos.length,
                  itemBuilder: (context, index) {
                    final todo = controller.todos[index];
                    return Dismissible(
                      key: Key(todo.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        controller.deleteTodo(todo.id);
                      },
                      child: InkWell(
                        onTap: () => controller.toggleTodo(todo),
                        onLongPress: () => _showEditDialog(context, todo),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade800),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  todo.text,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    decoration: todo.completed 
                                        ? TextDecoration.lineThrough 
                                        : null,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            
            // Clear Completed Button
            Obx(() {
              final hasCompleted = controller.todos.any((todo) => todo.completed);
              if (!hasCompleted) return SizedBox.shrink();
              
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextButton(
                  onPressed: () => _showClearDialog(context),
                  child: Text(
                    'Clear Completed',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            }),
            
            // Add Todo Input
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border(top: BorderSide(color: Colors.grey.shade800)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a new task...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Color(0xFFF5F5DC)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          controller.addTodo(value);
                          textController.clear();
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5DC),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: Colors.black),
                      onPressed: () {
                        if (textController.text.isNotEmpty) {
                          controller.addTodo(textController.text);
                          textController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showArchiveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Color(0xFF1E1E1E),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Archived Todos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: Obx(() {
                  if (controller.archivedTodos.isEmpty) {
                    return Center(
                      child: Text(
                        'No archived todos',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: controller.archivedTodos.length,
                    itemBuilder: (context, index) {
                      final todo = controller.archivedTodos[index];
                      return Dismissible(
                        key: Key('archive_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          controller.deleteArchivedTodo(index);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade800),
                            ),
                          ),
                          child: Text(
                            todo.text,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
              SizedBox(height: 10),
              Obx(() {
                if (controller.archivedTodos.isEmpty) return SizedBox.shrink();
                
                return TextButton(
                  onPressed: () {
                    Get.dialog(
                      AlertDialog(
                        backgroundColor: Color(0xFF1E1E1E),
                        title: Text('Clear All Archives?', style: TextStyle(color: Colors.white)),
                        content: Text(
                          'This will permanently delete all archived todos.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              controller.clearAllArchives();
                              Get.back();
                            },
                            child: Text('Clear All', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Clear All Archives',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(color: Color(0xFFF5F5DC)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showEditDialog(BuildContext context, todo) {
    final editController = TextEditingController(text: todo.text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text('Edit Todo', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Todo text',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF5F5DC)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              controller.updateTodo(todo, editController.text);
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: Color(0xFFF5F5DC))),
          ),
        ],
      ),
    );
  }
  
  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text('Clear Completed?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will remove all completed todos from the list.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              controller.clearCompleted();
              Navigator.pop(context);
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}