import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/hotel_task.dart';

class TasksScreen extends StatefulWidget {
  final bool isOwner;
  const TasksScreen({super.key, required this.isOwner});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final db = DatabaseHelper.instance;
  String get me => widget.isOwner ? 'Owner' : 'Hausmaster';
  String tr(String de, String ru) => widget.isOwner ? de : ru;
  String status(TaskStatus s) => switch (s) {
    TaskStatus.open => tr('Neu', 'Новая'),
    TaskStatus.inProgress => tr('In Bearbeitung', 'В работе'),
    TaskStatus.done => tr('Erledigt', 'Выполнена'),
  };
  Color pc(TaskPriority p) => switch (p) {
    TaskPriority.normal => Colors.blue,
    TaskPriority.high => Colors.orange,
    TaskPriority.urgent => Colors.red,
  };
  Future<void> edit([HotelTask? t]) async {
    final title = TextEditingController(text: t?.title);
    final desc = TextEditingController(text: t?.description);
    final room = TextEditingController(text: t?.room);
    String ass = t?.assignedTo ?? (widget.isOwner ? 'Hausmaster' : 'Owner');
    TaskPriority pri = t?.priority ?? TaskPriority.normal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(
            t == null
                ? tr('Neue Aufgabe', 'Новая задача')
                : tr('Aufgabe', 'Задача'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: tr('Titel', 'Название'),
                  ),
                ),
                TextField(
                  controller: room,
                  decoration: InputDecoration(
                    labelText: tr('Zimmer / Ort', 'Комната / место'),
                  ),
                ),
                TextField(
                  controller: desc,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: tr('Beschreibung', 'Описание'),
                  ),
                ),
                DropdownButtonFormField(
                  value: ass,
                  decoration: InputDecoration(
                    labelText: tr('Zuständig', 'Исполнитель'),
                  ),
                  items: ['Owner', 'Hausmaster']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) => setD(() => ass = v!),
                ),
                DropdownButtonFormField(
                  value: pri,
                  decoration: InputDecoration(
                    labelText: tr('Priorität', 'Приоритет'),
                  ),
                  items: TaskPriority.values
                      .map(
                        (x) => DropdownMenuItem(
                          value: x,
                          child: Text(
                            x == TaskPriority.normal
                                ? tr('Normal', 'Обычный')
                                : x == TaskPriority.high
                                ? tr('Hoch', 'Высокий')
                                : tr('Dringend', 'Срочный'),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setD(() => pri = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('Abbrechen', 'Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('Speichern', 'Сохранить')),
            ),
          ],
        ),
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      final x =
          t ??
          HotelTask(title: title.text.trim(), assignedTo: ass, createdBy: me);
      x.title = title.text.trim();
      x.description = desc.text.trim();
      x.room = room.text.trim();
      x.assignedTo = ass;
      x.priority = pri;
      await db.saveTask(x);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Aufgaben', 'Задачи'))),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: Text(tr('Aufgabe', 'Задача')),
    ),
    body: StreamBuilder<List<HotelTask>>(
      stream: db.watchTasks(),
      builder: (context, s) {
        if (s.hasError)
          return Center(child: Text('${tr('Fehler', 'Ошибка')}: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final items = s.data!;
        if (items.isEmpty)
          return Center(
            child: Text(tr('Noch keine Aufgaben', 'Задач пока нет')),
          );
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (c, i) {
            final t = items[i];
            return Card(
              child: ListTile(
                onTap: () => edit(t),
                leading: Icon(
                  t.status == TaskStatus.done
                      ? Icons.check_circle
                      : Icons.assignment,
                  color: t.status == TaskStatus.done
                      ? Colors.green
                      : pc(t.priority),
                ),
                title: Text(
                  t.title,
                  style: TextStyle(
                    decoration: t.status == TaskStatus.done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  '${t.room.isEmpty ? tr('Ohne Zimmer', 'Без комнаты') : t.room} • ${t.assignedTo} • ${status(t.status)}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await db.deleteTask(t.id!);
                    } else {
                      t.status = TaskStatus.values.firstWhere(
                        (e) => e.name == v,
                      );
                      await db.saveTask(t);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Text(tr('Neu', 'Новая')),
                    ),
                    PopupMenuItem(
                      value: 'inProgress',
                      child: Text(tr('In Bearbeitung', 'В работе')),
                    ),
                    PopupMenuItem(
                      value: 'done',
                      child: Text(tr('Erledigt', 'Выполнена')),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(tr('Löschen', 'Удалить')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
