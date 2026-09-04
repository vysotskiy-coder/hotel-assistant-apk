import 'package:flutter/material.dart';

import '../models/hotel_area.dart';
import '../models/room.dart';
import '../repositories/room_repository.dart';
import 'room_details_screen.dart';

class RoomScreen extends StatefulWidget {
  final String? area;
  final RoomStatus? status;
  final String title;
  final bool isOwner;

  const RoomScreen({
    super.key,
    this.area,
    this.status,
    required this.title,
    required this.isOwner,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final RoomRepository _repository = RoomRepository();

  List<Room> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    List<Room> rooms;

    if (widget.area != null) {
      HotelArea area;

      switch (widget.area) {
        case 'mainHotel':
          area = HotelArea.mainHotel;
          break;

        case 'basement':
          area = HotelArea.basement;
          break;

        case 'apartment':
          area = HotelArea.apartment;
          break;

        case 'topApartment':
          area = HotelArea.topApartment;
          break;

        default:
          area = HotelArea.mainHotel;
      }

      rooms = await _repository.getRoomsByArea(area);
    } else {
      rooms = await _repository.getAllRooms();
    }

    if (widget.status != null) {
      rooms = rooms.where((r) => r.status == widget.status).toList();
    }

    debugPrint('Количество комнат: ${rooms.length}');

    for (final room in rooms) {
      debugPrint('${room.id}  ${room.area}  ${room.number}');
    }

    rooms.sort((a, b) {
      final areaCompare = a.area.index.compareTo(b.area.index);

      if (areaCompare != 0) {
        return areaCompare;
      }

      return a.number.compareTo(b.number);
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _rooms = rooms;
      _loading = false;
    });
  }

  Color _statusColor(RoomStatus status) {
    switch (status) {
      case RoomStatus.free:
        return Colors.green;

      case RoomStatus.occupied:
        return Colors.red;

      case RoomStatus.cleaning:
        return Colors.orange;

      case RoomStatus.checkout:
        return Colors.blue;

      case RoomStatus.repair:
        return Colors.grey;
    }
  }

  String _statusText(RoomStatus status) {
    switch (status) {
      case RoomStatus.free:
        return widget.isOwner ? 'Frei' : 'Свободна';

      case RoomStatus.occupied:
        return widget.isOwner ? 'Belegt' : 'Занята';

      case RoomStatus.cleaning:
        return widget.isOwner ? 'Reinigung' : 'Уборка';

      case RoomStatus.checkout:
        return widget.isOwner ? 'Abreise' : 'Выезд';

      case RoomStatus.repair:
        return widget.isOwner ? 'Reparatur' : 'Ремонт';
    }
  }

  String _areaIcon(HotelArea area) {
    switch (area) {
      case HotelArea.mainHotel:
        return '🏨';

      case HotelArea.basement:
        return '⬇️';

      case HotelArea.apartment:
        return '🏠';

      case HotelArea.topApartment:
        return '🏠';
    }
  }

  String _areaName(HotelArea area) {
    switch (area) {
      case HotelArea.mainHotel:
        return widget.isOwner ? 'Haupthotel' : 'Главный отель';

      case HotelArea.basement:
        return widget.isOwner ? 'Untergeschoss' : 'Подвал';

      case HotelArea.apartment:
        return widget.isOwner ? 'Ferienwohnung' : 'Квартира';

      case HotelArea.topApartment:
        return widget.isOwner ? 'Ferienwohnung oben' : 'Квартира сверху';
    }
  }

  Future<void> _openRoom(Room room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomDetailsScreen(room: room, isOwner: widget.isOwner),
      ),
    );

    await _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
          ? Center(
              child: Text(
                widget.isOwner ? 'Keine Zimmer gefunden' : 'Комнаты не найдены',
              ),
            )
          : ListView.builder(
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final room = _rooms[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(room.status),
                    ),
                    title: Row(
                      children: [
                        Text(
                          _areaIcon(room.area),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.isOwner
                                ? 'Zimmer ${room.number}'
                                : 'Комната ${room.number}',
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _areaName(room.area),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(_statusText(room.status)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openRoom(room),
                  ),
                );
              },
            ),
    );
  }
}
