const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onAdminNotificationCreate = functions
    .region("asia-southeast1") // đổi nếu project bạn dùng region khác
    .firestore.document("AdminNotifications/{docId}")
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const { title, body, topic, senderId } = data;

        if (!title || !body || !topic) {
            console.error("Thiếu dữ liệu bắt buộc:", data);
            return null;
        }

        try {
            // 1. Ghi bản chuẩn vào Notifications -> chuông trong Dashboard đọc cái này
            await admin.firestore().collection("Notifications").add({
                title: title,
                content: body,        // đổi tên body -> content cho khớp Dashboard
                type: topic,          // 'new_exam' hoặc 'admin_alerts'
                senderId: senderId || null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                readBy: [],
                deletedBy: [],
            });

            // 2. Bắn push notification thật tới topic
            await admin.messaging().send({
                topic: topic,
                notification: {
                    title: title,
                    body: body,
                },
                android: {
                    priority: "high",
                    notification: {
                        sound: "default",
                        channelId: "default_channel",
                    },
                },
                apns: {
                    payload: {
                        aps: { sound: "default" },
                    },
                },
            });

            console.log(`Đã xử lý xong: "${title}" -> topic "${topic}"`);
            return null;
        } catch (error) {
            console.error("Lỗi khi xử lý AdminNotification:", error);
            return null;
        }
    });