enum TaskStatus { open, inProgress, done }

enum TaskPriority { normal, high, urgent }

class HotelTask {
  int? id;
  String title;
  String description;
  String room;
  String assignedTo;
  String createdBy;
  TaskStatus status;
  TaskPriority priority;
  String createdAt;

  HotelTask({
    this.id,
    required this.title,
    this.description = '',
    this.room = '',
    required this.assignedTo,
    required this.createdBy,
    this.status = TaskStatus.open,
    this.priority = TaskPriority.normal,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  factory HotelTask.fromMap(Map<String, dynamic> m) => HotelTask(
    id: m['id'],
    title: m['title'],
    description: m['description'] ?? '',
    room: m['room'] ?? '',
    assignedTo: m['assignedTo'],
    createdBy: m['createdBy'],
    status: TaskStatus.values.firstWhere((e) => e.name == m['status']),
    priority: TaskPriority.values.firstWhere((e) => e.name == m['priority']),
    createdAt: m['createdAt'],
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'room': room,
    'assignedTo': assignedTo,
    'createdBy': createdBy,
    'status': status.name,
    'priority': priority.name,
    'createdAt': createdAt,
  };
}
