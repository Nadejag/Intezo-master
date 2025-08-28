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

// Update registerPatientAndAddToQueue for doctor-specific booking
export const registerPatientAndAddToQueue = async (req, res) => {
  try {
    const { name, phone, clinicId, doctorId } = req.body;

     if (!doctorId) {
      return res.status(400).json({ error: 'Doctor ID is required' });
    }

    // Check if clinic is open
    const clinic = await Clinic.findById(clinicId);
    if (!clinic || !clinic.isOpen) {
      return res.status(400).json({ error: 'Clinic is currently closed' });
    }

    // Check if doctor is specified and available
    const doctor = await Doctor.findById(doctorId);
    if (!doctor || !doctor.isActive || !doctor.isAvailable) {
      return res.status(400).json({ error: 'Doctor is not available' });
    }

    // Check if patient already exists
    let patient = await Patient.findOne({ phone });
    if (!patient) {
      patient = new Patient({ name, phone });
      await patient.save();
    }

    // Check if patient has current waiting queue
    if (patient.currentQueue) {
      const currentQueue = await Queue.findById(patient.currentQueue);
      if (currentQueue && currentQueue.status === 'waiting') {
        return res.status(400).json({ error: 'Patient already in queue' });
      }
    }

    // Generate doctor-specific queue number
    const nextNumber = await Queue.getNextQueueNumber(clinicId, doctorId);

    // Create queue entry
    const queue = new Queue({
      clinic: clinicId,
      doctor: doctorId || null,
      patient: patient._id,
      number: nextNumber,
      status: 'waiting',
      bookedAt: new Date()
    });
    await queue.save();

    // Update patient's current queue
    patient.currentQueue = queue._id;
    await patient.save();

    // Initialize Redis counter if needed
    const redisKey = doctorId ? `doctor:${doctorId}:current` : `clinic:${clinicId}:current`;
    if (!(await redisClient.get(redisKey))) {
      await redisClient.set(redisKey, 0);
    }

    // Trigger queue update
    await triggerQueueUpdate(clinicId, doctorId);

    res.status(201).json({
      patient: {
        _id: patient._id,
        name: patient.name,
        phone: patient.phone
      },
      queueNumber: nextNumber,
      isDoctorQueue: !!doctorId,
      doctor: doctor ? { name: doctor.name, specialty: doctor.specialty } : null
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
    .populate('clinic', 'name address')
    .populate('doctor', 'name')
    .sort({ servedAt: -1, bookedAt: -1 })
    .select('number status bookedAt servedAt clinic doctor');

    res.json(history);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};