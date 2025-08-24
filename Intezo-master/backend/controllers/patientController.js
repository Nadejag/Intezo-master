import Patient from '../models/Patient.js';
import Queue from '../models/Queue.js';
import Clinic from '../models/Clinic.js';
import redisClient from '../config/redis.js';
import { sendNotification } from '../services/notificationService.js';
import { triggerQueueUpdate } from './queueController.js';

// Register a new patient
export const registerPatient = async (req, res) => {
  try {
    const { name, phone } = req.body;

    // Check if patient already exists
    const existingPatient = await Patient.findOne({ phone });
    if (existingPatient) {
      return res.status(400).json({ error: 'Patient already exists' });
    }

    const patient = new Patient({ name, phone });
    await patient.save();

    res.status(201).json({
      _id: patient._id,
      name: patient.name,
      phone: patient.phone
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Get patient profile
export const getPatientProfile = async (req, res) => {
  try {
    const patient = await Patient.findById(req.patient._id)
      .select('-createdAt -updatedAt -__v');
    
    res.json(patient);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Update FCM token for notifications
export const updateFCMToken = async (req, res) => {
  try {
    const { token } = req.body;
    
    const patient = await Patient.findByIdAndUpdate(
      req.patient._id,
      { fcmToken: token },
      { new: true }
    ).select('-createdAt -updatedAt -__v');

    res.json(patient);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Get current queue status for patient
export const getCurrentQueueStatus = async (req, res) => {
  try {
    const patient = await Patient.findById(req.patient._id).populate('currentQueue');
    
    if (!patient || !patient.currentQueue) {
      return res.status(404).json({ error: 'No active queue found' });
    }

    const queue = patient.currentQueue;
    const clinic = await Clinic.findById(queue.clinic);

    // Get current serving number from Redis
    const currentNumber = await redisClient.get(`clinic:${queue.clinic}:current`) || 0;
    const position = queue.number - currentNumber;

    // Calculate estimated wait time (15 mins per patient as default)
    const avgProcessTime = clinic?.averageProcessTime || 15;
    const waitTime = position > 0 ? position * avgProcessTime : 0;

    res.json({
      clinic: {
        name: clinic?.name,
        address: clinic?.address
      },
      queueNumber: queue.number,
      currentServing: currentNumber,
      positionInQueue: position > 0 ? position : 0,
      estimatedWait: waitTime,
      status: queue.status
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Cancel current booking
export const cancelBooking = async (req, res) => {
  try {
    const patient = await Patient.findById(req.patient._id).populate('currentQueue');
    
    if (!patient || !patient.currentQueue) {
      return res.status(400).json({ error: 'No active booking to cancel' });
    }

    const queue = patient.currentQueue;
    
    // Only allow cancellation if not already served
    if (queue.status !== 'waiting') {
      return res.status(400).json({ error: 'Cannot cancel already processed booking' });
    }

    // Update queue status
    queue.status = 'cancelled';
    await queue.save();

    // Remove from patient's current queue
    patient.currentQueue = null;
    await patient.save();

    // Notify clinic via Socket.IO
    const io = req.app.get('socketio');
    io.to(`clinic_${queue.clinic}`).emit('queue_cancelled', {
      queueId: queue._id,
      number: queue.number
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Add to patientController.js
// In patientController.js - Update registerPatientAndAddToQueue function
export const registerPatientAndAddToQueue = async (req, res) => {
  try {
    const { name, phone, clinicId } = req.body;

    // Check if clinic is open
    const clinic = await Clinic.findById(clinicId);
    if (!clinic || !clinic.isOpen) {
      return res.status(400).json({ error: 'Clinic is currently closed' });
    }

    // Check if patient already exists
    let patient = await Patient.findOne({ phone });
    
    if (!patient) {
      // Create new patient
      patient = new Patient({ name, phone });
      await patient.save();
    }

    // Check if this is the first booking since the clinic was last opened
    const lastStatusChange = clinic.lastStatusChange;
    const lastOpenedTime = new Date(lastStatusChange);
    
    // Find bookings since the clinic was last opened (not cancelled)
    const bookingsSinceReopen = await Queue.countDocuments({
      clinic: clinicId,
      bookedAt: { $gte: lastOpenedTime },
      status: { $ne: 'cancelled' }
    });

    console.log(`Bookings since clinic reopened at ${lastOpenedTime}: ${bookingsSinceReopen}`);

    let nextNumber;
    
    if (bookingsSinceReopen === 0) {
      // First booking since clinic reopened - start from 1
      nextNumber = 1;
      console.log(`First booking since clinic reopened - setting number to 1`);
      
      // Reset Redis counter to 0 for the new session
      await redisClient.set(`clinic:${clinicId}:current`, 0);
      console.log(`Reset Redis counter to 0 for new session`);
    } else {
      // Continue from the highest number + 1 since clinic reopened
      const lastQueueSinceReopen = await Queue.findOne({ 
        clinic: clinicId,
        bookedAt: { $gte: lastOpenedTime },
        status: { $ne: 'cancelled' }
      })
      .sort({ number: -1 })
      .select('number')
      .lean();

      if (lastQueueSinceReopen) {
        nextNumber = lastQueueSinceReopen.number + 1;
        console.log(`Continuing from last queue number since reopen: ${lastQueueSinceReopen.number} -> ${nextNumber}`);
      } else {
        // Fallback: get the highest number ever
        const lastQueueEver = await Queue.findOne({ clinic: clinicId })
          .sort({ number: -1 })
          .select('number')
          .lean();
        nextNumber = lastQueueEver ? lastQueueEver.number + 1 : 1;
        console.log(`Fallback to highest number ever: ${nextNumber}`);
      }
    }

    // Create queue entry
    const queue = new Queue({
      clinic: clinicId,
      patient: patient._id,
      number: nextNumber,
      status: 'waiting',
      bookedAt: new Date()
    });
    await queue.save();
    console.log(`Created queue entry with number: ${nextNumber}`);

    // Update patient's current queue
    patient.currentQueue = queue._id;
    await patient.save();

    // Trigger queue update
    await triggerQueueUpdate(clinicId);
    console.log(`Queue update triggered`);

    res.status(201).json({
      patient: {
        _id: patient._id,
        name: patient.name,
        phone: patient.phone
      },
      queueNumber: nextNumber
    });
  } catch (err) {
    console.error('Error in registerPatientAndAddToQueue:', err);
    res.status(500).json({ error: err.message });
  }
};

// Add to patientController.js
export const updatePatientInfo = async (req, res) => {
  try {
    const { patientId } = req.params;
    const { name, phone } = req.body;

    const patient = await Patient.findByIdAndUpdate(
      patientId,
      { name, phone },
      { new: true, runValidators: true }
    );

    if (!patient) {
      return res.status(404).json({ error: 'Patient not found' });
    }

    res.json(patient);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const getPatientQueueHistory = async (req, res) => {
  try {
    const { patientId } = req.params;

    const history = await Queue.find({
      patient: patientId,
      status: { $in: ['served', 'cancelled'] }
    })
    .populate('clinic', 'name')
    .sort({ servedAt: -1, bookedAt: -1 })
    .select('number status bookedAt servedAt clinic');

    res.json(history);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};