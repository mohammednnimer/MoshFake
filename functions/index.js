const admin = require("firebase-admin");

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");

admin.initializeApp();

/**
 * Send FCM notification when a new call document is created
 */
exports.sendCallNotification = onDocumentCreated(
    "notifications/{notificationId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const data = snapshot.data();

      if (data.type !== "incoming_call") {
        return;
      }

      const {targetToken, callerName, callerId} = data;

      if (!targetToken) {
        console.log("No FCM token found for target user");
        return;
      }

      const message = {
        notification: {
          title: "Incoming Call",
          body: `${callerName} is calling...`,
        },
        data: {
          type: "incoming_call",
          callerName,
          callerId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "calls_channel",
            priority: "max",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              "sound": "default",
              "content-available": 1,
              "category": "CALL_CATEGORY",
            },
          },
        },
        token: targetToken,
      };

      try {
        await admin.messaging().send(message);
        console.log("Notification sent successfully");

        await snapshot.ref.delete();
      } catch (error) {
        console.error("Error sending notification:", error);
      }
    },
);

/**
 * Clean up old signaling data (older than 5 minutes)
 */
exports.cleanupSignaling = onSchedule("every 5 minutes", async () => {
  const fiveMinutesAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 5 * 60 * 1000),
  );

  const oldSignalingDocs = await admin
      .firestore()
      .collection("signaling")
      .where("timestamp", "<", fiveMinutesAgo)
      .get();

  const batch = admin.firestore().batch();
  oldSignalingDocs.docs.forEach((doc) => batch.delete(doc.ref));

  await batch.commit();
  console.log(`Cleaned up ${oldSignalingDocs.size} signaling documents`);
});

/**
 * Clean up old ended calls (older than 24 hours)
 */
exports.cleanupOldCalls = onSchedule("every 24 hours", async () => {
  const oneDayAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000),
  );

  const oldCalls = await admin
      .firestore()
      .collection("calls")
      .where("status", "==", "ended")
      .where("endedAt", "<", oneDayAgo)
      .get();

  const batch = admin.firestore().batch();
  oldCalls.docs.forEach((doc) => batch.delete(doc.ref));

  await batch.commit();
  console.log(`Cleaned up ${oldCalls.size} old call records`);
});
