import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/room_history.dart';

class RoomHistoryScreen extends StatelessWidget {
  final List<RoomHistory> history;
  final bool isOwner;

  const RoomHistoryScreen({
    super.key,
    required this.history,
    required this.isOwner,
  });

  String tr(String de, String ru) => isOwner ? de : ru;

  String formatDate(String value) {
    try {
      final dt = DateTime.parse(value);
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Zimmerverlauf', 'История комнаты'))),
      body: history.isEmpty
          ? Center(
              child: Text(tr('Noch keine Änderungen', 'История пока пуста')),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              child: Icon(Icons.history, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.action,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Text("${tr("Было", "Было")}: ${item.oldValue}"),

                        const SizedBox(height: 5),

                        Text("${tr("Стало", "Стало")}: ${item.newValue}"),

                        const Divider(height: 24),

                        Row(
                          children: [
                            const Icon(Icons.person, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.changedBy)),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(formatDate(item.createdAt))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
