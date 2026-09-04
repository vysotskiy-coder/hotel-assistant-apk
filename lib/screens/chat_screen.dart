import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  final bool isOwner;

  const ChatScreen({super.key, required this.isOwner});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final db = DatabaseHelper.instance;

  final c = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  String get me => widget.isOwner ? 'Owner' : 'Hausmaster';

  String tr(String de, String ru) => widget.isOwner ? de : ru;

  // =========================================================
  // SEND
  // =========================================================

  Future<void> send() async {
    final text = c.text.trim();

    if (text.isEmpty) return;

    c.clear();

    await db.addMessage(ChatMessage(sender: me, text: text, read: false));

    _scrollToBottom();
  }

  // =========================================================
  // TIME
  // =========================================================

  String formatTime(String value) {
    try {
      final date = DateTime.parse(value).toLocal();

      final hour = date.hour.toString().padLeft(2, '0');

      final minute = date.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  // =========================================================
  // SCROLL
  // =========================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // =========================================================
  // READ MESSAGES
  // =========================================================

  void _markMessagesRead(List<ChatMessage> messages) {
    for (final message in messages) {
      if (message.sender != me && message.read == false) {
        db.markMessageAsRead(message);
      }
    }
  }

  @override
  void dispose() {
    c.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Nachrichten', 'Сообщения'))),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: db.watchMessages(),

              builder: (context, s) {
                if (s.hasError) {
                  return Center(
                    child: Text('${tr('Fehler', 'Ошибка')}: ${s.error}'),
                  );
                }

                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = s.data!;

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      tr('Noch keine Nachrichten', 'Сообщений пока нет'),
                    ),
                  );
                }

                _markMessagesRead(messages);

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,

                  padding: const EdgeInsets.all(12),

                  itemCount: messages.length,

                  itemBuilder: (context, i) {
                    final message = messages[i];

                    final own = message.sender == me;

                    return Align(
                      alignment: own
                          ? Alignment.centerRight
                          : Alignment.centerLeft,

                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),

                        margin: const EdgeInsets.symmetric(vertical: 3),

                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),

                        decoration: BoxDecoration(
                          color: own
                              ? const Color(0xFFD9FDD3)
                              : Theme.of(context).cardColor,

                          borderRadius: BorderRadius.circular(12),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            if (!own)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  message.sender,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),

                            Text(
                              message.text,
                              style: const TextStyle(fontSize: 16),
                            ),

                            const SizedBox(height: 3),

                            Row(
                              mainAxisSize: MainAxisSize.min,

                              mainAxisAlignment: MainAxisAlignment.end,

                              children: [
                                Text(
                                  formatTime(message.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),

                                if (own) ...[
                                  const SizedBox(width: 4),

                                  Text(
                                    message.read ? '✓✓' : '✓',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,

                                      color: message.read
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),

              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: c,

                      textCapitalization: TextCapitalization.sentences,

                      onSubmitted: (_) => send(),

                      decoration: InputDecoration(
                        hintText: tr('Nachricht...', 'Сообщение...'),

                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton.filled(
                    onPressed: send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
