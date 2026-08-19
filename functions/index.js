const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Se ejecuta cada minuto
exports.sendScheduledNotifications = functions
  .runWith({ timeoutSeconds: 540, memory: "256MB" })
  .pubsub.schedule("every 1 minutes")
  .onRun(async () => {
    const now = new Date();
    const nowMin = now.getHours() * 60 + now.getMinutes();
    const todayWeekday = now.getDay() === 0 ? 6 : now.getDay() - 1;

    console.log(`⏰ Revisando: ${now.toLocaleString()}`);

    const users = await db.collection("users").get();

    for (const userDoc of users.docs) {
      const uid = userDoc.id;
      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) continue;

      // ── Recordatorios ──────────────────────────────────────
      const reminders = await db.collection("users").doc(uid)
        .collection("reminders")
        .where("active", "==", true)
        .where("triggered", "==", false)
        .get();

      for (const doc of reminders.docs) {
        const data = doc.data();
        const reminderTime = data.dateTime.toDate();
        const diff = now - reminderTime;

        if (diff >= 0 && diff < 60000) {
          try {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: `🔔 ${data.title}`,
                body: data.note || "Tienes un recordatorio",
              },
              android: {
                priority: "high",
                notification: { channelId: "reminders_channel" },
              },
            });
            await doc.ref.update({ triggered: true });
            console.log(`✅ Recordatorio: ${data.title}`);
          } catch (e) {
            console.error(`❌ Error enviando a ${uid}:`, e.message);
          }
        }
      }

      // ── Tareas ─────────────────────────────────────────────
      const tasks = await db.collection("users").doc(uid)
        .collection("tasks")
        .where("completed", "==", false)
        .get();

      for (const doc of tasks.docs) {
        const data = doc.data();
        if (!data.dueDate) continue;
        const dueDate = data.dueDate.toDate();

        // 1 hora antes
        const oneHourBefore = new Date(dueDate - 3600000);
        const diff1h = now - oneHourBefore;
        if (diff1h >= 0 && diff1h < 60000) {
          try {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: "⏰ Tarea en 1 hora",
                body: data.title,
              },
              android: {
                priority: "high",
                notification: { channelId: "reminders_channel" },
              },
            });
          } catch (e) { console.error(e.message); }
        }

        // Exacta
        const diffExact = now - dueDate;
        if (diffExact >= 0 && diffExact < 60000) {
          try {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: "🚨 Tarea vencida",
                body: data.title,
              },
              android: {
                priority: "high",
                notification: { channelId: "reminders_channel" },
              },
            });
          } catch (e) { console.error(e.message); }
        }
      }

      // ── Hábitos ────────────────────────────────────────────
      const habits = await db.collection("users").doc(uid)
        .collection("habits")
        .where("active", "==", true)
        .get();

      for (const doc of habits.docs) {
        const data = doc.data();
        const days = data.days || [0,1,2,3,4,5,6];
        if (!days.includes(todayWeekday)) continue;

        const startH = data.startHour ?? 8;
        const startM = data.startMinute ?? 0;
        const habitMin = startH * 60 + startM;

        if (nowMin === habitMin) {
          try {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: `${data.icon ?? "💪"} Hora de tu hábito`,
                body: data.title,
              },
              android: {
                priority: "high",
                notification: { channelId: "reminders_channel" },
              },
            });
            console.log(`✅ Hábito: ${data.title}`);
          } catch (e) { console.error(e.message); }
        }
      }
    }

    return null;
  });