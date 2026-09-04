import 'hotel_area.dart';

enum RoomStatus { free, occupied, cleaning, checkout, repair }

class Room {
  int? id;

  HotelArea area;
  int number;

  RoomStatus status;

  String guest;
  String checkIn;
  String checkOut;
  String comment;

  // Новые поля
  String lastChangedBy;
  String lastChangedAt;
  int unreadEvents;
  List<String> photos;

  Room({
    this.id,
    required this.area,
    required this.number,
    this.status = RoomStatus.free,
    this.guest = '',
    this.checkIn = '',
    this.checkOut = '',
    this.comment = '',
    this.lastChangedBy = '',
    this.lastChangedAt = '',
    this.unreadEvents = 0,
    this.photos = const [],
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'],
      area: HotelArea.values.firstWhere((e) => e.name == map['area']),
      number: map['number'],
      status: RoomStatus.values.firstWhere((e) => e.name == map['status']),
      guest: map['guest'] ?? '',
      checkIn: map['checkIn'] ?? '',
      checkOut: map['checkOut'] ?? '',
      comment: map['comment'] ?? '',
      lastChangedBy: map['lastChangedBy'] ?? '',
      lastChangedAt: map['lastChangedAt'] ?? '',
      unreadEvents: map['unreadEvents'] ?? 0,
      photos: List<String>.from(map['photos'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'area': area.name,
      'number': number,
      'status': status.name,
      'guest': guest,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'comment': comment,
      'lastChangedBy': lastChangedBy,
      'lastChangedAt': lastChangedAt,
      'unreadEvents': unreadEvents,
      'photos': photos,
    };
  }

  Room copyWith({
    int? id,
    HotelArea? area,
    int? number,
    RoomStatus? status,
    String? guest,
    String? checkIn,
    String? checkOut,
    String? comment,
    String? lastChangedBy,
    String? lastChangedAt,
    int? unreadEvents,
    List<String>? photos,
  }) {
    return Room(
      id: id ?? this.id,
      area: area ?? this.area,
      number: number ?? this.number,
      status: status ?? this.status,
      guest: guest ?? this.guest,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      comment: comment ?? this.comment,
      lastChangedBy: lastChangedBy ?? this.lastChangedBy,
      lastChangedAt: lastChangedAt ?? this.lastChangedAt,
      unreadEvents: unreadEvents ?? this.unreadEvents,
      photos: photos ?? this.photos,
    );
  }
}
