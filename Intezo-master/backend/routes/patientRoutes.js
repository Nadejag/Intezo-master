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
import Doctor from '../models/Doctor.js'; // Add this import

const router = express.Router();

// Public routes
router.post('/register', registerPatient);
router.post('/register-and-queue', registerPatientAndAddToQueue);
router.put('/:patientId', updatePatientInfo);
router.get('/:patientId/history', getPatientQueueHistory);

// Add doctor-specific booking route
router.post('/book-doctor', authenticatePatient, async (req, res) => {
  try {
    const { clinicId, doctorId } = req.body;
    
    const result = await bookNumber({
      body: {
        clinicId,
        patientId: req.patient._id,
        doctorId
      }
    }, res);

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Protected routes
router.use(authenticatePatient);
router.get('/profile', getPatientProfile);
router.put('/fcm-token', updateFCMToken);

// Update queue-status endpoint to handle doctor-specific queues
router.get('/queue-status', authenticatePatient, async (req, res) => {
  try {
    const patient = await Patient.findById(req.patient._id)
      .populate({
        path: 'currentQueue',
        populate: [
          {
            path: 'clinic',
            select: 'name address operatingHours'
          },
          {
            path: 'doctor',
            select: 'name specialty'
          }
        ]
      });

    if (!patient || !patient.currentQueue) {
      return res.status(404).json({ error: 'No active queue found' });
    }

    const queue = patient.currentQueue;
    
    if (!queue.doctor) {
      return res.status(400).json({ error: 'Queue is not associated with a doctor' });
    }
    
    // Get current serving number from Redis for the doctor
    const currentNumber = parseInt(await redisClient.get(`doctor:${queue.doctor._id}:current`) || 0);
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
        },
        doctor: {
          _id: queue.doctor._id,
          name: queue.doctor.name,
          specialty: queue.doctor.specialty
        }
      }
    });
  } catch (err) {
    console.error('Queue status error:', err);
    res.status(500).json({ error: err.message });
  }
});

router.delete('/cancel-booking', cancelBooking);

export default router;