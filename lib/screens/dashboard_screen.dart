import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/room.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'chat_screen.dart';
import 'issues_screen.dart';
import 'room_screen.dart';
import 'tasks_screen.dart';

class DashboardScreen extends StatefulWidget {
  final bool isOwner;

  const DashboardScreen({super.key, required this.isOwner});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String t(String de, String ru) => widget.isOwner ? de : ru;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NotificationService.instance.markDashboardReady();
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.instance.checkForUpdate();
    if (!mounted || info == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog(
        info: info,
        isOwner: widget.isOwner,
      ),
    );
  }

  int n(List<Room> rooms, RoomStatus status) {
    return rooms.where((room) => room.status == status).length;
  }

  void go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isOwner
              ? 'Hotel Assistant • Eigentümer'
              : 'Hotel Assistant • Hausmeister',
        ),
        actions: [
          IconButton(
            tooltip: t('Abmelden', 'Выйти'),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<Room>>(
        stream: DatabaseHelper.instance.watchRooms(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${t('Firebase-Fehler', 'Ошибка Firebase')}: '
                '${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                t('Hotelübersicht', 'Обзор отеля'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.30,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _stat(
                    context,
                    t('Frei', 'Свободно'),
                    n(rooms, RoomStatus.free),
                    Icons.check_circle,
                    Colors.green,
                    RoomStatus.free,
                  ),
                  _stat(
                    context,
                    t('Belegt', 'Занято'),
                    n(rooms, RoomStatus.occupied),
                    Icons.person,
                    Colors.red,
                    RoomStatus.occupied,
                  ),
                  _stat(
                    context,
                    t('Reinigung', 'Уборка'),
                    n(rooms, RoomStatus.cleaning),
                    Icons.cleaning_services,
                    Colors.orange,
                    RoomStatus.cleaning,
                  ),
                  _stat(
                    context,
                    t('Reparatur', 'Ремонт'),
                    n(rooms, RoomStatus.repair),
                    Icons.build,
                    Colors.grey,
                    RoomStatus.repair,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _tile(
                t('Haupthotel', 'Основной отель'),
                t('Zimmer 1–10', 'Комнаты 1–10'),
                Icons.hotel,
                () => go(
                  context,
                  RoomScreen(
                    area: 'mainHotel',
                    title: t('Haupthotel', 'Основной отель'),
                    isOwner: widget.isOwner,
                  ),
                ),
              ),

              _tile(
                t('Untergeschoss', 'Подвал'),
                t('Zimmer 1–5', 'Комнаты 1–5'),
                Icons.stairs,
                () => go(
                  context,
                  RoomScreen(
                    area: 'basement',
                    title: t('Untergeschoss', 'Подвал'),
                    isOwner: widget.isOwner,
                  ),
                ),
              ),

              _tile(
                t('Ferienwohnung', 'Квартира'),
                t('Gästewohnung', 'Гостевая квартира'),
                Icons.apartment,
                () => go(
                  context,
                  RoomScreen(
                    area: 'apartment',
                    title: t('Ferienwohnung', 'Квартира'),
                    isOwner: widget.isOwner,
                  ),
                ),
              ),

              _tile(
                t('Top Apartment', 'Верхние апартаменты'),
                t('Gästewohnung oben', 'Гостевая квартира сверху'),
                Icons.apartment,
                () => go(
                  context,
                  RoomScreen(
                    area: 'topApartment',
                    title: t('Top Apartment', 'Верхние апартаменты'),
                    isOwner: widget.isOwner,
                  ),
                ),
              ),

              const Divider(height: 28),

              _tile(
                t('Aufgaben', 'Задачи'),
                t(
                  'Aufgaben für Eigentümer und Hausmeister',
                  'Поручения владельца и хаусмастера',
                ),
                Icons.task_alt,
                () => go(context, TasksScreen(isOwner: widget.isOwner)),
              ),

              _tile(
                t('Störungen', 'Неисправности'),
                t('Defekte und Reparaturen', 'Поломки и ремонт'),
                Icons.handyman,
                () => go(context, IssuesScreen(isOwner: widget.isOwner)),
              ),

              _tile(
                t('Nachrichten', 'Сообщения'),
                t('Online-Kommunikation', 'Онлайн-общение'),
                Icons.chat,
                () => go(context, ChatScreen(isOwner: widget.isOwner)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String text,
    int value,
    IconData icon,
    Color color,
    RoomStatus status,
  ) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          go(
            context,
            RoomScreen(title: text, status: status, isOwner: widget.isOwner),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
