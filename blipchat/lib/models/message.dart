class Message {
  final String id;
  final String username;
  final String content;
  final DateTime timestamp;
  final bool isLocal;

  Message({
    required this.id,
    required this.username,
    required this.content,
    required this.timestamp,
    this.isLocal = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isLocal': isLocal,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      username: json['username'],
      content: json['content'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      isLocal: json['isLocal'] ?? false,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, username: $username, content: $content, timestamp: $timestamp, isLocal: $isLocal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}