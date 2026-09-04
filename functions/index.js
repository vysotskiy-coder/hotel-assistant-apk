const {
  onDocumentWritten,
  onDocumentCreated,
} = require('firebase-functions/v2/firestore');

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();

// ============================================================
// Отправка уведомления другому пользователю
// ============================================================

async function sendToOtherUser(
  changedBy,
  deTitle,
  deBody,
  ruTitle,
  ruBody,
  data = {}
) {
  console.log('----------------------------------------');
  console.log('Push notification');
  console.log('changedBy:', changedBy);
  console.log('data:', data);

  const snap = await db.collection('users').get();

  if (snap.empty) {
    console.log('В коллекции users нет пользователей.');
    return;
  }

  const jobs = [];

  for (const doc of snap.docs) {
    const user = doc.data();

    console.log(
      'User:',
      doc.id,
      'role:',
      user.role,
      'token:',
      user.fcmToken ? 'YES' : 'NO'
    );

    // Нет FCM token
    if (!user.fcmToken) {
      continue;
    }

    // Не отправляем уведомление самому отправителю
    if (user.role === changedBy) {
      console.log('Skip sender:', user.role);
      continue;
    }

    const isOwner = user.role === 'Owner';

    const message = {
      token: user.fcmToken,

      notification: {
        title: isOwner ? deTitle : ruTitle,
        body: isOwner ? deBody : ruBody,
      },

      data: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [
          key,
          String(value ?? ''),
        ])
      ),

      android: {
        priority: 'high',

        notification: {
          channelId: 'hotel_assistant_channel',
          sound: 'default',
        },
      },
    };

    console.log('Sending push to:', user.role);

    jobs.push(
      getMessaging()
        .send(message)
        .then((response) => {
          console.log(
            'FCM sent successfully:',
            user.role,
            response
          );
        })
        .catch((error) => {
          console.error(
            'FCM send failed:',
            user.role,
            error.code,
            error.message
          );
        })
    );
  }

  await Promise.all(jobs);

  console.log('Push processing finished.');
  console.log('----------------------------------------');
}

// ============================================================
// ROOM
// ============================================================

exports.roomChanged = onDocumentWritten(
  "rooms/{roomId}",
  async (event) => {
    if (!event.data?.after?.exists) return;

    const before = event.data.before?.exists
      ? event.data.before.data()
      : {};

    const after = event.data.after.data();

    const room =
      after.number ??
      event.params.roomId;

    let deBody = "";
    let ruBody = "";

    //--------------------------------------------------
    // Статус
    //--------------------------------------------------

    if (before.status !== after.status) {
      deBody =
        `Zimmer ${room}\nStatus:\n${before.status ?? "-"} → ${after.status}`;

      ruBody =
        `Комната ${room}\nСтатус:\n${before.status ?? "-"} → ${after.status}`;
    }

    //--------------------------------------------------
    // Гость
    //--------------------------------------------------

    else if (before.guest !== after.guest) {
      deBody =
        `Zimmer ${room}\nGast:\n${before.guest || "-"} → ${after.guest || "-"}`;

      ruBody =
        `Комната ${room}\nГость:\n${before.guest || "-"} → ${after.guest || "-"}`;
    }

    //--------------------------------------------------
    // Заезд
    //--------------------------------------------------

    else if (before.checkIn !== after.checkIn) {
      deBody =
        `Zimmer ${room}\nCheck In:\n${before.checkIn || "-"} → ${after.checkIn || "-"}`;

      ruBody =
        `Комната ${room}\nЗаезд:\n${before.checkIn || "-"} → ${after.checkIn || "-"}`;
    }

    //--------------------------------------------------
    // Выезд
    //--------------------------------------------------

    else if (before.checkOut !== after.checkOut) {
      deBody =
        `Zimmer ${room}\nCheck Out:\n${before.checkOut || "-"} → ${after.checkOut || "-"}`;

      ruBody =
        `Комната ${room}\nВыезд:\n${before.checkOut || "-"} → ${after.checkOut || "-"}`;
    }

    //--------------------------------------------------
    // Комментарий
    //--------------------------------------------------

    else if (before.comment !== after.comment) {
      deBody =
        `Zimmer ${room}\nKommentar geändert`;

      ruBody =
        `Комната ${room}\nКомментарий изменён`;
    }

    //--------------------------------------------------
    // Нет изменений
    //--------------------------------------------------

    else {
      return;
    }

    await sendToOtherUser(
      after.changedBy,

      "Zimmer geändert",
      deBody,

      "Комната изменена",
      ruBody,

      {
        type: "room",
        id: event.params.roomId,
      }
    );
  }
);

// ============================================================
// TASK
// ============================================================

exports.taskChanged = onDocumentWritten(
  'tasks/{taskId}',
  async (event) => {
    if (!event.data?.after?.exists) {
      return;
    }

    const task = event.data.after.data();

    const isNew =
      !event.data.before?.exists;

    await sendToOtherUser(
      task.changedBy,

      isNew
        ? 'Neue Aufgabe'
        : 'Aufgabe geändert',

      task.title ||
        'Eine Aufgabe wurde aktualisiert.',

      isNew
        ? 'Новая задача'
        : 'Задача изменена',

      task.title ||
        'Задача была обновлена.',

      {
        type: 'task',
        id: event.params.taskId,
      }
    );
  }
);

// ============================================================
// ISSUE
// ============================================================

exports.issueChanged = onDocumentWritten(
  'issues/{issueId}',
  async (event) => {
    if (!event.data?.after?.exists) {
      return;
    }

    const issue =
      event.data.after.data();

    await sendToOtherUser(
      issue.changedBy,

      'Technisches Problem',
      issue.title ||
        issue.description ||
        'Ein Problem wurde aktualisiert.',

      'Техническая проблема',
      issue.title ||
        issue.description ||
        'Проблема была обновлена.',

      {
        type: 'issue',
        id: event.params.issueId,
      }
    );
  }
);

// ============================================================
// CHAT MESSAGE
// ============================================================

exports.messageCreated = onDocumentCreated(
  'messages/{messageId}',
  async (event) => {
    const message =
      event.data?.data();

    if (!message) {
      console.log('Message data отсутствует.');
      return;
    }

    const sender =
      message.changedBy ||
      message.sender ||
      'unknown';

    const text =
      message.text ||
      'Новое сообщение';

    console.log(
      'New chat message:',
      sender,
      text
    );

    await sendToOtherUser(
      sender,

      'Neue Nachricht',
      text,

      'Новое сообщение',
      text,

      {
        type: 'message',
        id: event.params.messageId,
        sender: sender,
      }
    );
  }
);