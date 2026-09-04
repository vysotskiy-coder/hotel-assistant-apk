class RoomPhoto {
  final String id;
  final int roomId;
  final String url;
  final String uploadedBy;
  final String createdAt;

  RoomPhoto({
    required this.id,
    required this.roomId,
    required this.url,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory RoomPhoto.fromMap(Map<String, dynamic> map) {
    return RoomPhoto(
      id: map['id'] ?? '',
      roomId: map['roomId'] ?? 0,
      url: map['url'] ?? '',
      uploadedBy: map['uploadedBy'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'url': url,
      'uploadedBy': uploadedBy,
      'createdAt': createdAt,
    };
  }
}
