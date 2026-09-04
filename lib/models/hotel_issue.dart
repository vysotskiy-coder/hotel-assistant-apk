class HotelIssue {
  int? id;
  String title;
  String place;
  String description;
  bool resolved;
  String createdAt;
  HotelIssue({
    this.id,
    required this.title,
    this.place = '',
    this.description = '',
    this.resolved = false,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();
  factory HotelIssue.fromMap(Map<String, dynamic> m) => HotelIssue(
    id: m['id'],
    title: m['title'],
    place: m['place'] ?? '',
    description: m['description'] ?? '',
    resolved: m['resolved'] is bool
        ? m['resolved'] as bool
        : (m['resolved'] ?? 0) == 1,
    createdAt: m['createdAt'],
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'place': place,
    'description': description,
    'resolved': resolved,
    'createdAt': createdAt,
  };
}
