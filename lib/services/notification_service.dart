import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _dialogShowing = false;
  bool _notificationsEnabled = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _roomSubscription;

  bool _dashboardReady = false;
  final List<Map<String, dynamic>> _pendingRoomDialogs = [];

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    const channel = AndroidNotificationChannel(
      'hotel_assistant_channel',
      'Hotel Assistant',
      description: 'Hotel notifications',
      importance: Importance.max,
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen((message) async {
      // IMPORTANT:
      // FCM is initialized before login, but notifications are not allowed
      // until a user has successfully logged in.
      if (!_notificationsEnabled || FirebaseAuth.instance.currentUser == null) {
        return;
      }

      final notification = message.notification;

      if (notification == null) {
        return;
      }

      await showNotification(
        notification.title ?? 'Hotel Assistant',
        notification.body ?? '',
      );
    });

    _messaging.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;

      // Never register a token while logged out.
      if (user != null && _notificationsEnabled) {
        await _saveToken(user, token);
      }
    });
  }

  Future<void> registerCurrentUser({required bool isOwner}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    // Notifications become active ONLY after successful login.
    _notificationsEnabled = true;

    final token = await _messaging.getToken();

    if (token != null) {
      await _saveToken(user, token, isOwner: isOwner);
    }

    // A listener from a previous session must not block this login.
    if (_roomSubscription == null) {
      _startRoomListener();
    }

    await _checkStayDateNotifications(isOwner: isOwner);
  }

  /// Completely disables application notifications after logout.
  ///
  /// This also cancels the Firestore room listener and removes the local
  /// FCM token, so a logged-out device cannot continue receiving messages.
  Future<void> disableNotifications() async {
    _notificationsEnabled = false;

    await _roomSubscription?.cancel();
    _roomSubscription = null;

    _pendingRoomDialogs.clear();

    if (_dialogShowing) {
      _dialogShowing = false;
    }

    try {
      await _messaging.deleteToken();
    } catch (_) {
      // Token deletion failure must not prevent logout.
    }
  }

  Future<void> _checkStayDateNotifications({required bool isOwner}) async {
    if (!_notificationsEnabled) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String? normalizeDate(String value) {
      final text = value.trim();

      if (text.isEmpty) {
        return null;
      }

      DateTime? parsed;

      final dot = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(text);
      if (dot != null) {
        parsed = DateTime(
          int.parse(dot.group(3)!),
          int.parse(dot.group(2)!),
          int.parse(dot.group(1)!),
        );
      }

      final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
      if (slash != null) {
        parsed = DateTime(
          int.parse(slash.group(3)!),
          int.parse(slash.group(2)!),
          int.parse(slash.group(1)!),
        );
      }

      final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(text);
      if (iso != null) {
        parsed = DateTime(
          int.parse(iso.group(1)!),
          int.parse(iso.group(2)!),
          int.parse(iso.group(3)!),
        );
      }

      if (parsed == null) {
        return null;
      }

      final normalized =
          '${parsed.day.toString().padLeft(2, '0')}.'
          '${parsed.month.toString().padLeft(2, '0')}.'
          '${parsed.year}';

      return normalized;
    }

    final todayText =
        '${today.day.toString().padLeft(2, '0')}.'
        '${today.month.toString().padLeft(2, '0')}.'
        '${today.year}';

    final snapshot = await _db.collection('rooms').get();

    print('STAY CHECK: rooms=, today=');

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final room = (data['number'] ?? doc.id).toString();
      final guest = (data['guest'] ?? '').toString();
      final checkIn = (data['checkIn'] ?? '').toString();
      final checkOut = (data['checkOut'] ?? '').toString();
      final area = (data['area'] ?? 'mainHotel').toString();

      if (guest.trim().isEmpty) {
        continue;
      }

      final normalizedCheckIn = normalizeDate(checkIn);
      final normalizedCheckOut = normalizeDate(checkOut);

      final isCheckIn = normalizedCheckIn == todayText;
      final isCheckOut = normalizedCheckOut == todayText;

      if (isCheckIn) {
        final eventId = '${doc.id}_checkin_$todayText';

        final ackRef = _db
            .collection('users')
            .doc(user.uid)
            .collection('stay_notifications')
            .doc(eventId);

        final ack = await ackRef.get();

        if (!ack.exists) {
          await _showStayDateDialog(
            eventId: eventId,
            room: room,
            guest: guest,
            area: area,
            date: todayText,
            isCheckIn: true,
            isOwner: isOwner,
            acknowledgementRef: ackRef,
          );
        }
      }

      if (isCheckOut) {
        final eventId = '${doc.id}_checkout_$todayText';

        final ackRef = _db
            .collection('users')
            .doc(user.uid)
            .collection('stay_notifications')
            .doc(eventId);

        final ack = await ackRef.get();

        if (!ack.exists) {
          await _showStayDateDialog(
            eventId: eventId,
            room: room,
            guest: guest,
            area: area,
            date: todayText,
            isCheckIn: false,
            isOwner: isOwner,
            acknowledgementRef: ackRef,
          );
        }
      }
    }
  }

  Future<void> _showStayDateDialog({
    required String eventId,
    required String room,
    required String guest,
    required String area,
    required String date,
    required bool isCheckIn,
    required bool isOwner,
    required DocumentReference<Map<String, dynamic>> acknowledgementRef,
  }) async {
    if (!_notificationsEnabled || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    print('ROOM DIALOG: navigator=, dashboardReady=');

    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    if (_dialogShowing) {
      return;
    }

    _dialogShowing = true;

    try {
      final title = isOwner
          ? (isCheckIn ? 'ANREISE HEUTE' : 'ABREISE HEUTE')
          : (isCheckIn ? 'ЗАЕЗД СЕГОДНЯ' : 'ВЫЕЗД СЕГОДНЯ');

      final roomText = isOwner
          ? 'Zimmer ${room} — ${_areaDe(area)}'
          : 'Комната ${room} — ${_areaRu(area)}';

      final guestText = isOwner ? 'Gast: $guest' : 'Гость: $guest';

      final dateText = isOwner ? 'Datum: $date' : 'Дата: $date';

      final buttonText = isOwner ? 'BESTÄTIGEN' : 'ПОДТВЕРДИТЬ';

      final context = navigator.context;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.notifications_active),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(guestText, style: const TextStyle(fontSize: 17)),
                  const SizedBox(height: 8),
                  Text(dateText, style: const TextStyle(fontSize: 17)),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: Text(
                      buttonText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await acknowledgementRef.set({
                        'acknowledgedAt': FieldValue.serverTimestamp(),
                        'eventId': eventId,
                        'type': isCheckIn ? 'checkin' : 'checkout',
                        'date': date,
                      });

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _dialogShowing = false;
    }
  }

  Future<void> _saveToken(User user, String token, {bool? isOwner}) async {
    final ref = _db.collection('users').doc(user.uid);

    final old = await ref.get();
    final data = old.data();

    final role = isOwner == null
        ? (data?['role'] ?? 'unknown')
        : (isOwner ? 'Owner' : 'Hausmaster');

    await ref.set({
      'email': user.email,
      'role': role,
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _startRoomListener() {
    if (!_notificationsEnabled || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    if (_roomSubscription != null) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final currentRole = user.email == 't.ru.mp.e.ra.pe.rsc.m8.37@gmail.com'
        ? 'Owner'
        : 'Hausmaster';

    final knownEventIds = <String>{};
    bool listenerReady = false;

    _roomSubscription = _db
        .collection('room_events')
        .orderBy('changedAtLocal', descending: true)
        .snapshots()
        .listen(
          (snapshot) async {
            if (!_notificationsEnabled ||
                FirebaseAuth.instance.currentUser == null) {
              return;
            }

            if (!listenerReady) {
              for (final doc in snapshot.docs) {
                knownEventIds.add(doc.id);
              }

              listenerReady = true;
              return;
            }

            for (final change in snapshot.docChanges) {
              if (!_notificationsEnabled ||
                  FirebaseAuth.instance.currentUser == null) {
                return;
              }

              if (change.type != DocumentChangeType.added) {
                continue;
              }

              final event = change.doc;

              if (knownEventIds.contains(event.id)) {
                continue;
              }

              knownEventIds.add(event.id);

              final Map<String, dynamic> data =
                  event.data() ?? <String, dynamic>{};

              final changedBy = (data['changedBy'] ?? 'unknown').toString();

              if (changedBy == currentRole) {
                continue;
              }

              final room = (data['roomNumber'] ?? data['number'] ?? event.id)
                  .toString();

              final area = (data['area'] ?? 'mainHotel').toString();

              final oldStatus = (data['oldStatus'] ?? '').toString();

              final newStatus = (data['newStatus'] ?? '').toString();

              final changedAt = data['changedAtLocal'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(
                      data['changedAtLocal'] as int,
                    )
                  : DateTime.now();

              print('ROOM EVENT: ${event.id} -> queue notification/dialog');

              await _showRoomNotification(
                room: room,
                area: area,
                oldStatus: oldStatus,
                newStatus: newStatus,
                changedBy: changedBy,
                changedAt: changedAt,
                eventId: event.id,
              );

              _pendingRoomDialogs.add({
                'eventId': event.id,
                'room': room,
                'area': area,
                'oldStatus': oldStatus,
                'newStatus': newStatus,
                'changedBy': changedBy,
                'changedAt': changedAt,
                'isOwner': currentRole == 'Owner',
              });

              _showNextPendingRoomDialog();
            }
          },
          onError: (error) {
            // Listener errors are intentionally ignored here.
          },
        );
  }

  String _areaDe(String area) {
    switch (area) {
      case 'mainHotel':
        return 'Hauptgebäude';
      case 'basement':
        return 'Keller';
      case 'apartment':
        return 'Ferienwohnung';
      default:
        return area;
    }
  }

  String _areaRu(String area) {
    switch (area) {
      case 'mainHotel':
        return 'Главный отель';
      case 'basement':
        return 'Подвал';
      case 'apartment':
        return 'Апартаменты';
      default:
        return area;
    }
  }

  Future<void> _showRoomNotification({
    required String eventId,
    required String room,
    required String area,
    required String oldStatus,
    required String newStatus,
    required String changedBy,
    required DateTime changedAt,
  }) async {
    if (!_notificationsEnabled || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    final dateText =
        '${changedAt.day.toString().padLeft(2, '0')}.'
        '${changedAt.month.toString().padLeft(2, '0')}.'
        '${changedAt.year}';

    final timeText =
        '${changedAt.hour.toString().padLeft(2, '0')}:'
        '${changedAt.minute.toString().padLeft(2, '0')}';

    await _local.show(
      id,
      'Hotel Assistant',
      '🔔 Status geändert\n\n'
          'Zimmer $room — ${_areaDe(area)}\n\n'
          '${_statusIcon(oldStatus)} '
          '${_statusDe(oldStatus)} → '
          '${_statusIcon(newStatus)} '
          '${_statusDe(newStatus)}\n\n'
          '👤 $changedBy\n\n'
          '📅 $dateText   🕒 $timeText',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hotel_assistant_channel',
          'Hotel Assistant',
          channelDescription: 'Hotel notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'room_event:$eventId',
    );
  }

  Future<void> _showRoomDialog({
    required String eventId,
    required String room,
    required String area,
    required String oldStatus,
    required String newStatus,
    required String changedBy,
    required DateTime changedAt,
    required bool isOwner,
  }) async {
    if (!_notificationsEnabled || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final navigator = navigatorKey.currentState;

    print(
      'ROOM DIALOG: '
      'navigator=${navigator != null}, '
      'dashboardReady=$_dashboardReady',
    );

    // Если Dashboard или Navigator ещё не готовы,
    // сохраняем событие и покажем его после открытия Dashboard.
    if (navigator == null || !_dashboardReady) {
      _pendingRoomDialogs.add({
        'eventId': eventId,
        'room': room,
        'area': area,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'changedBy': changedBy,
        'changedAt': changedAt,
        'isOwner': isOwner,
      });
      return;
    }

    // Если окно уже открыто, сохраняем событие в очередь.
    if (_dialogShowing) {
      _pendingRoomDialogs.add({
        'eventId': eventId,
        'room': room,
        'area': area,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'changedBy': changedBy,
        'changedAt': changedAt,
        'isOwner': isOwner,
      });
      return;
    }

    _dialogShowing = true;

    final context = navigator.context;

    final dateText =
        '${changedAt.day.toString().padLeft(2, '0')}.'
        '${changedAt.month.toString().padLeft(2, '0')}.'
        '${changedAt.year}';

    final timeText =
        '${changedAt.hour.toString().padLeft(2, '0')}:'
        '${changedAt.minute.toString().padLeft(2, '0')}';

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.notifications_active),
                  SizedBox(width: 10),
                  Expanded(child: Text('Hotel Assistant')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOwner
                          ? 'ZIMMERSTATUS GEÄNDERT'
                          : 'ИЗМЕНЕНИЕ СТАТУСА КОМНАТЫ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isOwner
                          ? 'Zimmer $room — ${_areaDe(area)}'
                          : 'Комната $room — ${_areaRu(area)}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          _statusIcon(oldStatus),
                          style: const TextStyle(fontSize: 27),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOwner
                                ? _statusDe(oldStatus)
                                : _statusRu(oldStatus),
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                        const Icon(Icons.arrow_forward),
                        const SizedBox(width: 8),
                        Text(
                          _statusIcon(newStatus),
                          style: const TextStyle(fontSize: 27),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOwner
                                ? _statusDe(newStatus)
                                : _statusRu(newStatus),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text('👤 $changedBy', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      '📅 $dateText   🕒 $timeText',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: Text(
                      isOwner ? 'BESTÄTIGEN' : 'ПОДТВЕРДИТЬ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;

                      if (user == null) {
                        return;
                      }

                      await _db.collection('room_events').doc(eventId).set({
                        'acknowledgedBy': FieldValue.arrayUnion([user.uid]),
                        'acknowledgedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _dialogShowing = false;

      // Следующее уведомление показываем только после того,
      // как текущее окно полностью закрыто.
      Future.delayed(
        const Duration(milliseconds: 300),
        _showNextPendingRoomDialog,
      );
    }
  }

  void markDashboardReady() {
    _dashboardReady = true;

    // Даём завершиться переходу Login -> Dashboard.
    Future.delayed(
      const Duration(milliseconds: 700),
      _showNextPendingRoomDialog,
    );
  }

  void _showNextPendingRoomDialog() {
    if (!_dashboardReady || _dialogShowing || _pendingRoomDialogs.isEmpty) {
      return;
    }

    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      // Navigator ещё не готов. Попробуем ещё раз.
      Future.delayed(
        const Duration(milliseconds: 300),
        _showNextPendingRoomDialog,
      );
      return;
    }

    final next = _pendingRoomDialogs.removeAt(0);

    _showRoomDialog(
      eventId: next['eventId'] as String,
      room: next['room'] as String,
      area: next['area'] as String,
      oldStatus: next['oldStatus'] as String,
      newStatus: next['newStatus'] as String,
      changedBy: next['changedBy'] as String,
      changedAt: next['changedAt'] as DateTime,
      isOwner: next['isOwner'] as bool,
    );
  }

  Future<void> showNotification(String title, String body) async {
    if (!_notificationsEnabled || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    await _local.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hotel_assistant_channel',
          'Hotel Assistant',
          channelDescription: 'Hotel notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    if (!_notificationsEnabled || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final payload = response.payload;

    if (payload == null || !payload.startsWith('room_event:')) {
      return;
    }

    // Нажатие на системное уведомление открывает
    // такое же окно подтверждения.
    final eventId = payload.substring('room_event:'.length);

    final event = await _db.collection('room_events').doc(eventId).get();

    if (!event.exists) {
      return;
    }

    final data = event.data();

    if (data == null) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final room = (data['roomNumber'] ?? data['number'] ?? eventId).toString();

    final area = (data['area'] ?? 'mainHotel').toString();

    final oldStatus = (data['oldStatus'] ?? '').toString();

    final newStatus = (data['newStatus'] ?? '').toString();

    final changedBy = (data['changedBy'] ?? 'unknown').toString();

    final changedAt = data['changedAtLocal'] is int
        ? DateTime.fromMillisecondsSinceEpoch(data['changedAtLocal'] as int)
        : DateTime.now();

    await _showRoomDialog(
      eventId: eventId,
      room: room,
      area: area,
      oldStatus: oldStatus,
      newStatus: newStatus,
      changedBy: changedBy,
      changedAt: changedAt,
      isOwner: user.email == 't.ru.mp.e.ra.pe.rsc.m8.37@gmail.com',
    );
  }

  String _statusDe(String? status) {
    switch (status) {
      case 'free':
        return 'Frei';
      case 'occupied':
        return 'Belegt';
      case 'cleaning':
        return 'Reinigung';
      case 'checkout':
        return 'Abreise';
      case 'repair':
        return 'Reparatur';
      default:
        return status ?? '';
    }
  }

  String _statusRu(String? status) {
    switch (status) {
      case 'free':
        return 'Свободна';
      case 'occupied':
        return 'Занята';
      case 'cleaning':
        return 'Уборка';
      case 'checkout':
        return 'Выезд';
      case 'repair':
        return 'Ремонт';
      default:
        return status ?? '';
    }
  }

  String _statusIcon(String? status) {
    switch (status) {
      case 'free':
        return '🟢';
      case 'occupied':
        return '🔴';
      case 'cleaning':
        return '🟡';
      case 'checkout':
        return '🔵';
      case 'repair':
        return '🟠';
      default:
        return '⚪';
    }
  }
}
