import User from '../models/User.js';
import { sendPushNotification } from '../services/notification.js';

// Subscribe to queue updates
export const subscribeToQueue = async (req, res) => {
  const { clinicId, fcmToken } = req.body;
  const userId = req.user.userId;

  await User.findByIdAndUpdate(userId, { 
    $addToSet: { subscribedClinics: clinicId },
    fcmToken 
  });

  res.json({ success: true });
};

// Handle FCM notifications (called from services)
export const handleQueueNotification = async (clinicId, triggerNumber) => {
  const users = await User.find({
    subscribedClinics: clinicId,
    'queues.number': { $lte: triggerNumber + 5 }
  });

  await Promise.all(
    users.map(user => 
      sendPushNotification({
        to: user.fcmToken,
        title: 'Your turn is coming!',
        body: `Number ${triggerNumber} is being served`
      })
    )
  );
};