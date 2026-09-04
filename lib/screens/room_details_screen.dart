import 'package:flutter/material.dart';

import '../models/room.dart';
import '../repositories/room_repository.dart';

class RoomDetailsScreen extends StatefulWidget {
  final Room room;
  final bool isOwner;

  const RoomDetailsScreen({
    super.key,
    required this.room,
    required this.isOwner,
  });

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  final RoomRepository _repository = RoomRepository();

  late Room room;

  late TextEditingController guestController;
  late TextEditingController checkInController;
  late TextEditingController checkOutController;
  late TextEditingController commentController;

  @override
  void initState() {
    super.initState();

    room = widget.room;

    guestController = TextEditingController(text: room.guest);
    checkInController = TextEditingController(text: room.checkIn);
    checkOutController = TextEditingController(text: room.checkOut);
    commentController = TextEditingController(text: room.comment);
  }

  @override
  void dispose() {
    guestController.dispose();
    checkInController.dispose();
    checkOutController.dispose();
    commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    room.guest = guestController.text;
    room.checkIn = checkInController.text;
    room.checkOut = checkOutController.text;
    room.comment = commentController.text;

    final oldStatus = widget.room.status;

    await _repository.updateRoom(room);

    if (oldStatus != room.status) {
      // Пока ничего не делаем.
      // На следующем шаге здесь появится запись события
      // для уведомлений.
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('Änderungen gespeichert', 'Изменения сохранены')),
      ),
    );
  }

  String tr(String de, String ru) => widget.isOwner ? de : ru;
  String _statusText(RoomStatus s) => switch (s) {
    RoomStatus.free => tr('Frei', 'Свободна'),
    RoomStatus.occupied => tr('Belegt', 'Занята'),
    RoomStatus.cleaning => tr('Reinigung', 'Уборка'),
    RoomStatus.checkout => tr('Abreise', 'Выезд'),
    RoomStatus.repair => tr('Reparatur', 'Ремонт'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Zimmer ${room.number}', 'Комната ${room.number}')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<RoomStatus>(
            value: room.status,
            decoration: InputDecoration(labelText: tr('Status', 'Статус')),
            items: RoomStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(_statusText(status)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  room.status = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: guestController,
            decoration: InputDecoration(labelText: tr('Gast', 'Гость')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: checkInController,
            decoration: InputDecoration(labelText: tr('Anreise', 'Заезд')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: checkOutController,
            decoration: InputDecoration(labelText: tr('Abreise', 'Выезд')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: commentController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: tr('Kommentar', 'Комментарий'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(tr('Speichern', 'Сохранить')),
          ),
        ],
      ),
    );
  }
}
