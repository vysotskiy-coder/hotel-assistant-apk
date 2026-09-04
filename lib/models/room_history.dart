class RoomHistory {
  final String id;
  final int roomId;

  final String action;
  final String oldValue;
  final String newValue;

  final String changedBy;
  final String createdAt;

  RoomHistory({
    required this.id,
    required this.roomId,
    required this.action,
    required this.oldValue,
    required this.newValue,
    required this.changedBy,
    required this.createdAt,
  });

  factory RoomHistory.fromMap(Map<String, dynamic> map) {
    return RoomHistory(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? 0,
      action: map['action'] ?? '',
      oldValue: map['oldValue'] ?? '',
      newValue: map['newValue'] ?? '',
      changedBy: map['changedBy'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'action': action,
      'oldValue': oldValue,
      'newValue': newValue,
      'changedBy': changedBy,
      'createdAt': createdAt,
    };
  }
}
