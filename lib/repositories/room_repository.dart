import '../database/database_helper.dart';
import '../models/hotel_area.dart';
import '../models/room.dart';
import '../models/room_history.dart';

class RoomRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<Room>> getAllRooms() {
    return _db.getAllRooms();
  }

  Future<List<Room>> getRoomsByArea(HotelArea area) async {
    final rooms = await _db.getAllRooms();

    return rooms.where((r) => r.area == area).toList();
  }

  Future<void> updateRoom(Room room) async {
    await _db.updateRoom(room);
  }

  Future<List<RoomHistory>> getRoomHistory(int roomId) async {
    return _db.getRoomHistory(roomId);
  }

  Future<void> addRoomHistory(RoomHistory history) async {
    await _db.addRoomHistory(history);
  }
}
