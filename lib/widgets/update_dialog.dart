import 'package:flutter/material.dart';

import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final bool isOwner;

  const UpdateDialog({
    super.key,
    required this.info,
    required this.isOwner,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool updating = false;
  double? progress;

  String t(String de, String ru) => widget.isOwner ? de : ru;

  Future<void> _update() async {
    setState(() {
      updating = true;
      progress = 0;
    });

    try {
      await UpdateService.instance.downloadAndInstall(
        widget.info.apkUrl,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            progress = total > 0 ? received / total : null;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Update konnte nicht installiert werden. Prüfe die APK-URL und die Android-Berechtigung.',
              'Обновление не удалось установить. Проверьте ссылку на APK и разрешение Android на установку.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.forceUpdate && !updating,
      child: AlertDialog(
        title: Text(t('Neue Version verfügbar', 'Доступно новое обновление')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(
              'Aktuelle Version: ${widget.info.currentVersion} (Build ${widget.info.currentBuild})',
              'Текущая версия: ${widget.info.currentVersion} (Build ${widget.info.currentBuild})',
            )),
            const SizedBox(height: 8),
            Text(t(
              'Neue Version: ${widget.info.newVersion} (Build ${widget.info.newBuild})',
              'Новая версия: ${widget.info.newVersion} (Build ${widget.info.newBuild})',
            )),
            if (widget.info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(t('Änderungen:', 'Изменения:'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(widget.info.releaseNotes),
            ],
            if (updating) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(t('APK wird heruntergeladen…', 'APK скачивается…')),
            ],
          ],
        ),
        actions: [
          if (!widget.info.forceUpdate && !updating)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('Später', 'Позже')),
            ),
          FilledButton.icon(
            onPressed: updating ? null : _update,
            icon: updating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update),
            label: Text(t('Aktualisieren', 'Обновить')),
          ),
        ],
      ),
    );
  }
}
