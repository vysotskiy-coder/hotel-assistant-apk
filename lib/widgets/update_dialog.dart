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
  String? errorMessage;

  String t(String de, String ru) {
    return widget.isOwner ? de : ru;
  }

  Future<void> _update() async {
    setState(() {
      updating = true;
      progress = 0;
      errorMessage = null;
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

      if (!mounted) return;

      setState(() {
        updating = false;
      });
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();

      setState(() {
        updating = false;
        errorMessage = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            t(
              'Update konnte nicht gestartet werden:\n$message',
              'Не удалось запустить установку:\n$message',
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
        title: Text(
          t(
            'Neue Version verfügbar',
            'Доступно новое обновление',
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(
                  'Aktuelle Version: '
                  '${widget.info.currentVersion} '
                  '(Build ${widget.info.currentBuild})',
                  'Текущая версия: '
                  '${widget.info.currentVersion} '
                  '(Build ${widget.info.currentBuild})',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'Neue Version: '
                  '${widget.info.newVersion} '
                  '(Build ${widget.info.newBuild})',
                  'Новая версия: '
                  '${widget.info.newVersion} '
                  '(Build ${widget.info.newBuild})',
                ),
              ),
              if (widget.info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  t(
                    'Änderungen:',
                    'Изменения:',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(widget.info.releaseNotes),
              ],
              if (updating) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  value: progress,
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'APK wird heruntergeladen…',
                    'APK скачивается…',
                  ),
                ),
              ],
              if (errorMessage != null && !updating) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.info.forceUpdate && !updating)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                t(
                  'Später',
                  'Позже',
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: updating ? null : _update,
            icon: updating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.system_update,
                  ),
            label: Text(
              t(
                'Aktualisieren',
                'Обновить',
              ),
            ),
          ),
        ],
      ),
    );
  }
}