class ChatMessage {
  int? id;
  String sender;
  String text;
  String createdAt;
  bool read;

  ChatMessage({
    this.id,
    required this.sender,
    required this.text,
    String? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'],
    sender: m['sender'] ?? '',
    text: m['text'] ?? '',
    createdAt: m['createdAt'] ?? DateTime.now().toIso8601String(),
    read: m['read'] == true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'sender': sender,
    'text': text,
    'createdAt': createdAt,
    'read': read,
  };
}
