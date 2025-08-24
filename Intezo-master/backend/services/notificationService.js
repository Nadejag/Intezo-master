import admin from 'firebase-admin';
import Patient from '../models/Patient.js';
import Queue from '../models/Queue.js';
import firebaseCredentials from '../config/firebase-credentials.json' with { type: 'json' };

// Initialize Firebase Admin SDK - No need to parse since we imported as JSON
admin.initializeApp({
  credential: admin.credential.cert(firebaseCredentials)
});

// Send notification to patient
export const sendNotification = async (patientId, title, body) => {
  try {
    const patient = await Patient.findById(patientId);
    
    if (!patient || !patient.fcmToken) {
      return;
    }

    const message = {
      notification: {
        title,
        body
      },
      token: patient.fcmToken
    };

    await admin.messaging().send(message);
  } catch (err) {
    console.error('Notification error:', err);
  }
};

// Send queue update notifications
export const sendQueueUpdate = async (clinicId, currentNumber) => {
  try {
    // Find patients whose turn is coming up (within next 5)
    const upcomingPatients = await Queue.find({
      clinic: clinicId,
      number: { 
        $gt: currentNumber,
        $lte: currentNumber + 5 
      },
      status: 'waiting'
    }).populate('patient');

    for (const queue of upcomingPatients) {
      const position = queue.number - currentNumber;
      await sendNotification(
        queue.patient._id,
        'Queue Update',
        `Your turn is coming up! Position: ${position}`
      );
    }
  } catch (err) {
    console.error('Queue notification error:', err);
  }
};