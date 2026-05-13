class Todo {
  final String id;
  final String text;
  final bool completed;
  final int priority;
  final DateTime createdAt;
  final DateTime lastModified;

  Todo({
    required this.id,
    required this.text,
    required this.completed,
    required this.priority,
    required this.createdAt,
    required this.lastModified,
  });

  // Convert Firebase data to Todo object
  factory Todo.fromMap(String id, Map<dynamic, dynamic> map) {
    return Todo(
      id: id,
      text: map['text'] ?? '',
      completed: map['completed'] ?? false,
      priority: map['priority'] ?? 0,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastModified: DateTime.parse(map['lastModified'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Convert Todo object to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'completed': completed,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
    };
  }
}