import express from 'express';
import {
  registerPatient,
  getPatientProfile,
  updateFCMToken,
  getCurrentQueueStatus,
  cancelBooking,
  registerPatientAndAddToQueue,
  updatePatientInfo,
  getPatientQueueHistory
} from '../controllers/patientController.js';
import { authenticatePatient } from '../middleware/auth.js';
import Patient from '../models/Patient.js';
import redisClient from '../config/redis.js';
import Clinic from '../models/Clinic.js';
import Queue from '../models/Queue.js';

const router = express.Router();

// Public routes
router.post('/register', registerPatient);
// Add to patientRoutes.js
router.post('/register-and-queue', registerPatientAndAddToQueue);

router.put('/:patientId', updatePatientInfo);
router.get('/:patientId/history', getPatientQueueHistory);

// Protected routes
router.use(authenticatePatient);
router.get('/profile', getPatientProfile);
router.put('/fcm-token', updateFCMToken);
// router.get('/queue-status', getCurrentQueueStatus);
// Add to patientRoutes.js - protected route

// In patientRoutes.js - Update the queue-status endpoint
router.get('/queue-status', authenticatePatient, async (req, res) => {
  try {
    const patient = await Patient.findById(req.patient._id)
      .populate({
        path: 'currentQueue',
        populate: {
          path: 'clinic',
          select: 'name address operatingHours'
        }
      });

    if (!patient || !patient.currentQueue) {
      return res.status(404).json({ error: 'No active queue found' });
    }

    const queue = patient.currentQueue;
    
    // Get current serving number from Redis
    const currentNumber = parseInt(await redisClient.get(`clinic:${queue.clinic._id}:current`) || 0);
    const position = queue.number - currentNumber;

    // Calculate estimated wait time
    const clinic = await Clinic.findById(queue.clinic._id);
    const avgProcessTime = clinic?.averageProcessTime || 15;
    const waitTime = position > 0 ? position * avgProcessTime : 0;

    res.json({
      currentQueue: {
        _id: queue._id,
        number: queue.number,
        status: queue.status,
        bookedAt: queue.bookedAt,
        currentServing: currentNumber,
        positionInQueue: position > 0 ? position : 0,
        estimatedWait: waitTime,
        clinic: {
          _id: queue.clinic._id,
          name: queue.clinic.name,
          address: queue.clinic.address,
          operatingHours: queue.clinic.operatingHours
        }
      }
    });
  } catch (err) {
    console.error('Queue status error:', err);
    res.status(500).json({ error: err.message });
  }
});

router.delete('/cancel-booking', cancelBooking);
// Update patientRoutes.js


export default router;