class Message {
  final String message;
  final DateTime sentAt;
  final DateTime? seenAt;
  final bool seen;
  final DateTime expiresAt;
  final bool active;

  Message({
    required this.message,
    required this.sentAt,
    this.seenAt,
    required this.seen,
    required this.expiresAt,
    required this.active,
  });

  // Convert Firebase data to Message object
  factory Message.fromMap(Map<dynamic, dynamic> map) {
    return Message(
      message: map['message'] ?? '',
      sentAt: DateTime.parse(map['sentAt'] ?? DateTime.now().toIso8601String()),
      seenAt: map['seenAt'] != null ? DateTime.parse(map['seenAt']) : null,
      seen: map['seen'] ?? false,
      expiresAt: DateTime.parse(map['expiresAt'] ?? DateTime.now().toIso8601String()),
      active: map['active'] ?? false,
    );
  }

  // Check if message is expired
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }
}