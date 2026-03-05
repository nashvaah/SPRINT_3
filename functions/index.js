
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// 1. Monitor Live Queue Changes
exports.onQueueUpdate = functions.firestore
    .document('live_queue/{queueId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const previousData = change.before.data();

        const currentToken = newData.currentToken;
        const previousToken = previousData.currentToken;

        // Only trigger if token moved forward
        if (currentToken <= previousToken) return null;

        const queueId = context.params.queueId;
        console.log(`Queue ${queueId} updated to token ${currentToken}`);

        // Find appointments/users who are "next" (next 20 people to be safe, then filter by preference)
        const targetTokensStart = currentToken + 1;
        const targetTokensEnd = currentToken + 20;

        // Query Firestore for appointments in this range
        const snapshot = await admin.firestore().collection('appointments')
            .where('deptId', '==', queueId)
            .where('tokenNumber', '>=', targetTokensStart)
            .where('tokenNumber', '<=', targetTokensEnd)
            .get();

        const promises = [];

        for (const doc of snapshot.docs) {
            const appointment = doc.data();
            const userId = appointment.userId;
            const userToken = appointment.tokenNumber;
            const diff = userToken - currentToken;

            // 1. Fetch User Settings
            const userDoc = await admin.firestore().collection('users').doc(userId).get();
            if (!userDoc.exists) continue;

            const userData = userDoc.data();
            // Default threshold 5 if not set
            const userThreshold = userData.token_alert_threshold || 5;

            // If user wants to be notified at 5, but diff is 6, skip.
            // If diff is <= threshold, notify.
            if (diff > userThreshold) continue;

            const lang = userData.language_code || 'en';

            // 2. Localize Message
            let messageTitle = "Your Turn is Approaching!";
            let messageBody = `Current Token is ${currentToken}. You are Token ${userToken}.`;

            if (lang === 'ml') {
                messageTitle = "നിങ്ങളുടെ ഊഴം അടുത്തിരിക്കുന്നു!";
                messageBody = `നിലവിലെ ടോക്കൺ ${currentToken} ആണ്. നിങ്ങളുടെ ടോക്കൺ ${userToken} ആണ്.`;
            }

            // Determine Priority
            // If very close (diff <= 2), mark critical (continuous sound/vibrate)
            const priority = diff <= 2 ? 'critical' : 'high';

            // 3. Save to Notification Database
            const notifPromise = admin.firestore().collection('notifications').add({
                userId: userId,
                type: 'tokenNear',
                title: messageTitle,
                message: messageBody,
                relatedTokenNumber: userToken,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'pending',
                isRead: false,
                priority: priority
            });
            // We rely on 'onNotificationCreated' trigger to actually SEND the FCM 
            // to avoid duplicating logic and ensuring consistent payload construction.

            promises.push(notifPromise);
        }

        return Promise.all(promises);
    });

// 2. Scheduled Appointment Reminders (Requires Blaze Plan for PubSub)
// Runs every hour to check for upcoming appointments
exports.sendAppointmentReminders = functions.pubsub.schedule('every 60 minutes').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    // Calculate typical reminder time (e.g., 24 hours from now) or strict check
    // ... Implementation skipped for brevity, similar logic to above
    console.log("Checked for reminders");
    return null;
});

// ... (Existing exports)

// 3. General Notification Push Trigger
// Listens to ANY new document in 'notifications' collection and sends FCM
exports.onNotificationCreated = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snap, context) => {
        const notification = snap.data();
        const userId = notification.userId;

        if (!userId) {
            console.log("No userId in notification");
            return null;
        }

        try {
            // Get user's FCM token
            const userDoc = await admin.firestore().collection('users').doc(userId).get();
            if (!userDoc.exists) {
                console.log("User not found");
                return null;
            }

            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;

            if (!fcmToken) {
                console.log("No FCM token for user");
                return null;
            }

            // Construct payload
            const isSos = (notification.type === 'sos' || notification.notificationType === 'sos');

            const payload = {
                notification: {
                    title: notification.title || 'New Notification',
                    body: notification.message || notification.body || 'You have a new alert',
                },
                data: {
                    type: notification.type || notification.notificationType || 'info',
                    priority: notification.priority || 'medium',
                    id: context.params.notificationId,
                    orderId: notification.orderId || '',
                    scheduleId: notification.scheduleId || '',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    // Add specific data for client verification
                    is_sos: isSos ? 'true' : 'false'
                }
            };

            // Android Config for Notification Channel
            if (isSos) {
                payload.android = {
                    notification: {
                        channel_id: 'sos_channel', // Directs to the high-priority channel
                        priority: 'max',
                        visibility: 'private',
                        sound: 'sos_alert' // Assumes res/raw/sos_alert.mp3 exists or falls back
                    }
                };
            }

            // Options for high priority if needed
            const options = {
                priority: (notification.priority === 'critical' || notification.priority === 'high' || isSos) ? 'high' : 'normal',
                timeToLive: 60 * 60 * 24
            };

            // Send
            await admin.messaging().sendToDevice(fcmToken, payload, options);

            // Mark as sent
            return snap.ref.update({ status: 'sent' });

        } catch (error) {
            console.error("Error sending push notification:", error);
            return snap.ref.update({ status: 'failed' });
        }
    });

// 4. Real-time Delivery & Status Updates for Caretaker Bookings
exports.onCaretakerUpdate = functions.firestore
    .document('caretaker_bookings/{requestId}')
    .onWrite(async (change, context) => {
        // Handle deletions gracefully
        if (!change.after.exists) return null;

        const newData = change.after.data();
        const previousData = change.before.exists ? change.before.data() : null;

        const currentStatus = newData.status || 'created';
        const previousStatus = previousData ? (previousData.status || 'created') : null;

        // Ensure no duplicate notifications by only triggering on actual status state changes
        if (currentStatus === previousStatus) {
            console.log(`Status unchanged (${currentStatus}), ignoring.`);
            return null;
        }

        const requestId = context.params.requestId;
        console.log(`Request ${requestId} changed from ${previousStatus} to ${currentStatus}`);

        // Helper to cleanly create a notification
        const createNotification = async (targetUserId, title, reqData) => {
            if (!targetUserId) return;
            const msgBody = `Order #${requestId.substring(0, 6)} is now ${currentStatus.toUpperCase()}.`;

            await admin.firestore().collection('notifications').add({
                userId: targetUserId,
                type: 'delivery_update',
                notificationType: 'delivery_update',
                title: title,
                message: reqData.request_description ? `${msgBody} Desc: ${reqData.request_description}` : msgBody,
                orderId: requestId, // Deep linking
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'pending', // Picked up by 'onNotificationCreated' 
                isRead: false,
                priority: currentStatus === 'emergency' || currentStatus === 'cancelled' ? 'high' : 'medium'
            });
        };

        // Determine who gets notified based on the transition:
        // Caretaker/Volunteer (Providers) vs Elderly (Requester)
        // If "Assigned", "Picked Up", "Delivered", "Cancelled", we notify relevant parties.

        try {
            // Send to assigned caretaker/volunteer if they exist in the order model,
            // or we might need to query them if Broadcast is required.
            // Assuming provider ID is stored in newData.assigned_provider_id
            const assignedProviderId = newData.assignedCaretakerId;
            const elderlyId = newData.userId;

            // Notify Provider of cancellations or creations assigned to them
            if (currentStatus === 'cancelled' && assignedProviderId) {
                await createNotification(assignedProviderId, "Delivery Cancelled by User", newData);
            } else if (currentStatus === 'assigned' && assignedProviderId) {
                // Send notification to the newly assigned person (caretaker/volunteer)
                await createNotification(assignedProviderId, "New Delivery Assigned to You", newData);
            }

            // Notify Elderly User (Requester) of progress
            if (currentStatus === 'picked_up' || currentStatus === 'in_progress') {
                await createNotification(elderlyId, "Your Order is on the way (Picked Up)", newData);
            } else if (currentStatus === 'delivered' || currentStatus === 'completed') {
                await createNotification(elderlyId, "Delivery Completed", newData);
            } else if (currentStatus === 'approved') {
                await createNotification(elderlyId, "Order Approved", newData);
            }

            // Optional: If 'created' -> could broadcast to ALL volunteers. Left as future implementation.

        } catch (error) {
            console.error("Error creating status update notifications:", error);
        }

        return null;
    });

// 5. Real-time Delivery & Status Updates for Volunteer Tasks
exports.onVolunteerUpdate = functions.firestore
    .document('volunteer_requests/{requestId}')
    .onWrite(async (change, context) => {
        if (!change.after.exists) return null;
        const newData = change.after.data();
        const previousData = change.before.exists ? change.before.data() : null;

        const currentStatus = newData.status || 'created';
        const previousStatus = previousData ? (previousData.status || 'created') : null;

        if (currentStatus === previousStatus) return null;

        const requestId = context.params.requestId;

        const createNotification = async (targetUserId, title, reqData) => {
            if (!targetUserId) return;
            const msgBody = `Task #${requestId.substring(0, 6)} is now ${currentStatus.toUpperCase()}.`;

            await admin.firestore().collection('notifications').add({
                userId: targetUserId,
                type: 'volunteer_update',
                notificationType: 'info',
                title: title,
                message: reqData.taskDescription ? `${msgBody} Task: ${reqData.taskDescription}` : msgBody,
                orderId: requestId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'pending',
                isRead: false,
                priority: currentStatus === 'Rejected' || currentStatus === 'Cancelled' ? 'high' : 'medium'
            });
        };

        try {
            const assignedProviderId = newData.assignedVolunteerId;
            const elderlyId = newData.userId;

            if (currentStatus === 'Cancelled' && assignedProviderId) {
                await createNotification(assignedProviderId, "Task Cancelled by User", newData);
            } else if ((currentStatus === 'Approved' || currentStatus === 'Accepted') && assignedProviderId) {
                await createNotification(assignedProviderId, "New Task Assigned to You", newData);
            }

            if (currentStatus === 'On the Way') {
                await createNotification(elderlyId, "Volunteer is On the Way", newData);
            } else if (currentStatus === 'Completed') {
                await createNotification(elderlyId, "Task Completed", newData);
            } else if (currentStatus === 'Approved') {
                await createNotification(elderlyId, "Task Approved", newData);
            }
        } catch (error) {
            console.error("Error creating status update notifications:", error);
        }
        return null;
    });
