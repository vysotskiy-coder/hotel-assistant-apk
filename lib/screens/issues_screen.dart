import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/hotel_issue.dart';

class IssuesScreen extends StatefulWidget {
  final bool isOwner;
  const IssuesScreen({super.key, required this.isOwner});
  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  String tr(String de, String ru) => widget.isOwner ? de : ru;
  final db = DatabaseHelper.instance;
  Future<void> add() async {
    final t = TextEditingController(),
        p = TextEditingController(),
        d = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Neue Störung', 'Новая неисправность')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: t,
                decoration: InputDecoration(
                  labelText: tr('Was ist defekt?', 'Что сломано?'),
                ),
              ),
              TextField(
                controller: p,
                decoration: InputDecoration(
                  labelText: tr('Zimmer / Ort', 'Комната / место'),
                ),
              ),
              TextField(
                controller: d,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: tr('Kommentar', 'Комментарий'),
                ),
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
            child: Text(tr('Hinzufügen', 'Добавить')),
          ),
        ],
      ),
    );
    if (ok == true && t.text.trim().isNotEmpty)
      await db.saveIssue(
        HotelIssue(
          title: t.text.trim(),
          place: p.text.trim(),
          description: d.text.trim(),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Störungen', 'Неисправности'))),
    floatingActionButton: FloatingActionButton(
      onPressed: add,
      child: const Icon(Icons.add),
    ),
    body: StreamBuilder<List<HotelIssue>>(
      stream: db.watchIssues(),
      builder: (context, s) {
        if (s.hasError)
          return Center(child: Text('${tr('Fehler', 'Ошибка')}: ${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final x = s.data!;
        return x.isEmpty
            ? Center(child: Text(tr('Keine Störungen', 'Неисправностей нет')))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: x.length,
                itemBuilder: (c, i) {
                  final a = x[i];
                  return Card(
                    child: CheckboxListTile(
                      value: a.resolved,
                      onChanged: (v) async {
                        a.resolved = v ?? false;
                        await db.saveIssue(a);
                      },
                      title: Text(a.title),
                      subtitle: Text(
                        '${a.place}${a.description.isEmpty ? '' : '\n${a.description}'}',
                      ),
                      secondary: Icon(
                        a.resolved ? Icons.build_circle : Icons.warning_amber,
                        color: a.resolved ? Colors.green : Colors.orange,
                      ),
                    ),
                  );
                },
              );
      },
    ),
  );
}
