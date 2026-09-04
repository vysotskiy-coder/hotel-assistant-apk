import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/hotel_area.dart';
import '../models/room.dart';
import '../models/hotel_task.dart';
import '../models/hotel_issue.dart';
import '../models/chat_message.dart';
import '../models/room_history.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final instance = DatabaseHelper._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _changedBy {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    if (email == 't.ru.mp.e.ra.pe.rsc.m8.37@gmail.com') {
      return 'Owner';
    }

    if (email == 'po.pu.l.o.usv.mbx.m.k@gmail.com') {
      return 'Hausmaster';
    }

    return 'unknown';
  }

  // =========================================================
  // ROOMS
  // =========================================================

  Future<void> initializeRooms() async {
    final meta = _db.collection('system').doc('initialization');

    final snap = await meta.get();

    final topApartmentRef = _db.collection('rooms').doc('1017');

    final topApartmentSnapshot = await topApartmentRef.get();

    if (!topApartmentSnapshot.exists) {
      await topApartmentRef.set(
        Room(id: 1017, area: HotelArea.topApartment, number: 1).toMap(),
      );
    }
    if (snap.exists) return;

    final batch = _db.batch();

    int id = 1000;

    final rooms = <Room>[
      for (int i = 1; i <= 10; i++)
        Room(id: ++id, area: HotelArea.mainHotel, number: i),

      for (int i = 1; i <= 5; i++)
        Room(id: ++id, area: HotelArea.basement, number: i),

      Room(id: ++id, area: HotelArea.apartment, number: 1),
    ];

    for (final room in rooms) {
      batch.set(_db.collection('rooms').doc('${room.id}'), room.toMap());
    }

    batch.set(meta, {'createdAt': FieldValue.serverTimestamp(), 'version': 1});

    await batch.commit();
  }

  Future<List<Room>> getAllRooms() async {
    final q = await _db.collection('rooms').get();

    final list = q.docs
        .map((d) => Room.fromMap({...d.data(), 'id': int.tryParse(d.id)}))
        .toList();

    list.sort((a, b) {
      final c = a.area.index.compareTo(b.area.index);

      return c != 0 ? c : a.number.compareTo(b.number);
    });

    return list;
  }

  Stream<List<Room>> watchRooms() =>
      _db.collection('rooms').snapshots().map((q) {
        final list = q.docs
            .map((d) => Room.fromMap({...d.data(), 'id': int.tryParse(d.id)}))
            .toList();

        list.sort((a, b) {
          final c = a.area.index.compareTo(b.area.index);

          return c != 0 ? c : a.number.compareTo(b.number);
        });

        return list;
      });

  Future updateRoom(Room r) async {
    final roomRef = _db.collection('rooms').doc('${r.id}');

    final oldSnapshot = await roomRef.get();

    final oldData = oldSnapshot.data();

    final oldStatus = oldData?['status'];

    await roomRef.set({
      ...r.toMap(),
      'changedBy': _changedBy,
      'changedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (oldStatus != r.status.name) {
      await _db.collection('room_events').add({
        'roomId': r.id,
        'roomNumber': r.number,
        'area': r.area.name,
        'oldStatus': oldStatus,
        'newStatus': r.status.name,
        'changedBy': _changedBy,

        // Серверное время
        'createdAt': FieldValue.serverTimestamp(),

        // Локальная дата и время устройства
        'changedAtLocal': DateTime.now().millisecondsSinceEpoch,
      });
    }

    return 1;
  }

  // =========================================================
  // TASKS
  // =========================================================

  Stream<List<HotelTask>> watchTasks() =>
      _db.collection('tasks').snapshots().map((q) {
        final list = q.docs
            .map(
              (d) => HotelTask.fromMap({...d.data(), 'id': int.tryParse(d.id)}),
            )
            .toList();

        list.sort((a, b) {
          if (a.status == TaskStatus.done && b.status != TaskStatus.done) {
            return 1;
          }

          if (a.status != TaskStatus.done && b.status == TaskStatus.done) {
            return -1;
          }

          return b.createdAt.compareTo(a.createdAt);
        });

        return list;
      });

  Future<List<HotelTask>> getTasks() => watchTasks().first;

  Future<int> saveTask(HotelTask t) async {
    t.id ??= DateTime.now().microsecondsSinceEpoch;

    await _db.collection('tasks').doc('${t.id}').set({
      ...t.toMap(),
      'changedBy': _changedBy,
    });

    return t.id!;
  }

  Future<int> deleteTask(int id) async {
    await _db.collection('tasks').doc('$id').delete();

    return 1;
  }

  // =========================================================
  // ISSUES
  // =========================================================

  Stream<List<HotelIssue>> watchIssues() =>
      _db.collection('issues').snapshots().map((q) {
        final list = q.docs
            .map(
              (d) =>
                  HotelIssue.fromMap({...d.data(), 'id': int.tryParse(d.id)}),
            )
            .toList();

        list.sort((a, b) {
          if (a.resolved != b.resolved) {
            return a.resolved ? 1 : -1;
          }

          return b.createdAt.compareTo(a.createdAt);
        });

        return list;
      });

  Future<List<HotelIssue>> getIssues() => watchIssues().first;

  Future<int> saveIssue(HotelIssue i) async {
    i.id ??= DateTime.now().microsecondsSinceEpoch;

    await _db.collection('issues').doc('${i.id}').set({
      ...i.toMap(),
      'changedBy': _changedBy,
    });

    return i.id!;
  }

  // =========================================================
  // CHAT
  // =========================================================

  Stream<List<ChatMessage>> watchMessages() =>
      _db.collection('messages').snapshots().map((q) {
        final list = q.docs
            .map(
              (d) =>
                  ChatMessage.fromMap({...d.data(), 'id': int.tryParse(d.id)}),
            )
            .toList();

        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return list;
      });

  Future<List<ChatMessage>> getMessages() => watchMessages().first;

  Future<int> addMessage(ChatMessage m) async {
    m.id ??= DateTime.now().microsecondsSinceEpoch;

    await _db.collection('messages').doc('${m.id}').set({
      ...m.toMap(),
      'changedBy': _changedBy,
    });

    return m.id!;
  }

  // =========================================================
  // MARK MESSAGE AS READ
  // =========================================================

  Future<void> markMessageAsRead(ChatMessage message) async {
    if (message.id == null) return;

    if (message.read) return;

    await _db.collection('messages').doc('${message.id}').update({
      'read': true,
    });
  }

  // =========================================================
  // MARK ALL RECEIVED MESSAGES AS READ
  // =========================================================

  Future<void> markIncomingMessagesAsRead(String currentUser) async {
    final q = await _db
        .collection('messages')
        .where('read', isEqualTo: false)
        .get();

    if (q.docs.isEmpty) return;

    final batch = _db.batch();

    bool hasChanges = false;

    for (final doc in q.docs) {
      final data = doc.data();

      final sender = data['sender'] ?? '';

      if (sender != currentUser) {
        batch.update(doc.reference, {'read': true});

        hasChanges = true;
      }
    }

    if (hasChanges) {
      await batch.commit();
    }
  }
  // =========================================================
  // ROOM HISTORY
  // =========================================================

  Future<void> addRoomHistory(RoomHistory history) async {
    await _db.collection('room_history').doc(history.id).set(history.toMap());
  }

  Future<List<RoomHistory>> getRoomHistory(int roomId) async {
    final q = await _db
        .collection('room_history')
        .where('roomId', isEqualTo: roomId)
        .get();

    final list = q.docs.map((e) => RoomHistory.fromMap(e.data())).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return list;
  }
}
