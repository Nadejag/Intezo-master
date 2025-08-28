import Queue from '../models/Queue.js';
import Clinic from '../models/Clinic.js';
import Patient from '../models/Patient.js';
import redisClient from '../config/redis.js';
import mongoose from 'mongoose';
import { sendNotification } from '../services/notificationService.js';
import pusher from '../config/pusher.js';
import Doctor from '../models/Doctor.js';

// In queueController.js, update triggerQueueUpdate function
export const triggerQueueUpdate = async (clinicId, doctorId = null, data = null) => {
  try {
    // Get clinic status
    const clinic = await Clinic.findById(clinicId).select('isOpen operatingHours');

    const queueData = data || await getQueueDataForBroadcast(clinicId, doctorId);

    // Add clinic status to broadcast data
    const broadcastData = {
      ...queueData,
      clinicStatus: {
        isOpen: clinic.isOpen,
        operatingHours: clinic.operatingHours
      }
    };

    // Broadcast to appropriate channels based on whether it's doctor-specific
    if (doctorId) {
      await pusher.trigger(
        `presence-doctor-${doctorId}`,
        'queue-update',
        broadcastData
      );

      await pusher.trigger(
        `public-doctor-${doctorId}`,
        'queue-update',
        queueData
      );

      // await pusher.trigger(`public-clinic-${clinicId}`, 'queue-update', queueData);
      
    } else {
      await pusher.trigger(
        `presence-clinic-${clinicId}`,
        'queue-update',
        broadcastData
      );

      await pusher.trigger(
        `public-clinic-${clinicId}`,
        'queue-update',
        queueData
      );
    }

    return broadcastData;
  } catch (err) {
    console.error('Pusher trigger error:', err);
    throw err;
  }
};

// Helper function to get queue data
const getQueueDataForBroadcast = async (clinicId, doctorId = null) => {
  const redisKey = doctorId ? `doctor:${doctorId}:current` : `clinic:${clinicId}:current`;

  const [currentNumber, queueData] = await Promise.all([
    redisClient.get(redisKey) || 0,
    Queue.find({
      clinic: clinicId,
      doctor: doctorId || { $exists: false },
      status: 'waiting'
    })
      .sort('number')
      .limit(10)
      .populate('patient', 'name phone')
      .lean()
  ]);

  const waitTime = await calculateWaitTime(clinicId, doctorId);

  return {
    currentNumber: parseInt(currentNumber),
    upcoming: queueData,
    totalWaiting: waitTime.waitingCount,
    avgWaitTime: waitTime.avgWaitPerPatient / 60000,
    hasNextPatient: queueData.length > 0,
    isDoctorQueue: !!doctorId
  };
};

// Calculate average wait time based on historical data
const calculateWaitTime = async (clinicId, doctorId = null) => {
  const clinic = await Clinic.findById(clinicId);
  if (!clinic) throw new Error('Clinic not found');

  const redisKey = doctorId ? `doctor:${doctorId}:current` : `clinic:${clinicId}:current`;
  const currentNumber = parseInt(await redisClient.get(redisKey) || 0);

  const waitingCount = await Queue.countDocuments({
    clinic: clinicId,
    doctor: doctorId || { $exists: false },
    status: 'waiting',
    number: { $gt: currentNumber }
  });

  return {
    avgWaitPerPatient: clinic.averageProcessTime * 60000, // Convert to milliseconds
    totalWaitTime: waitingCount * clinic.averageProcessTime,
    waitingCount
  };
};

const generateDoctorQueueNumber = async (clinicId, doctorId) => {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  // Find the highest queue number for this doctor today
  const lastQueue = await Queue.findOne({
    clinic: clinicId,
    doctor: doctorId,
    bookedAt: { $gte: todayStart }
  }).sort({ number: -1 });

  return lastQueue ? lastQueue.number + 1 : 1;
};

// Replace the bookNumber function with doctor-specific logic
export const bookNumber = async (req, res) => {
  try {
    const { clinicId, patientId, doctorId } = req.body;

    // Doctor ID is now required
    if (!doctorId) {
      return res.status(400).json({ error: 'Doctor ID is required' });
    }

    // Validate doctor
    const doctor = await Doctor.findById(doctorId);
    if (!doctor || !doctor.isActive || !doctor.isAvailable) {
      return res.status(400).json({ error: 'Doctor is not available' });
    }

    // Check if clinic is open
    const clinic = await Clinic.findById(clinicId);
    if (!clinic || !clinic.isOpen) {
      return res.status(400).json({ error: 'Clinic is currently closed' });
    }

    // Get patient and validate
    const patient = await Patient.findById(patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });

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
      doctor: doctorId,
      patient: patientId,
      number: nextNumber,
      status: 'waiting',
      bookedAt: new Date()
    });
    await queue.save();

    // Update patient's current queue
    await Patient.findByIdAndUpdate(patientId, { currentQueue: queue._id });

    // Initialize Redis counter for doctor if not exists
    const redisKey = `doctor:${doctorId}:current`;
    if (!(await redisClient.get(redisKey))) {
      await redisClient.set(redisKey, 0);
    }

    // Calculate wait time
    const currentNumber = parseInt(await redisClient.get(redisKey) || 0);
    const waitingCount = await Queue.countDocuments({
      clinic: clinicId,
      doctor: doctorId,
      status: 'waiting',
      number: { $gt: currentNumber }
    });

    const avgWaitTime = clinic.averageProcessTime || 15;
    const totalWaitTime = waitingCount * avgWaitTime;

    // Broadcast update
    await triggerQueueUpdate(clinicId, doctorId);

    res.status(201).json({
      queueNumber: nextNumber,
      estimatedWait: totalWaitTime,
      doctor: { name: doctor.name, specialty: doctor.specialty }
    });

  } catch (err) {
    console.error('Error in bookNumber:', err);
    res.status(500).json({ error: err.message });
  }
};

// Add this function to handle doctor status toggling
export const toggleDoctorStatus = async (req, res) => {
  try {
    const { doctorId } = req.params;
    const { isAvailable } = req.body;

    const doctor = await Doctor.findByIdAndUpdate(
      doctorId,
      {
        isAvailable,
        lastStatusChange: new Date()
      },
      { new: true }
    );

    if (!doctor) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    // If doctor is being made unavailable, handle their current queue
    if (!isAvailable) {
      // Reset doctor's queue
      await redisClient.set(`doctor:${doctorId}:current`, 0);

      // Cancel all waiting patients for this doctor
      await Queue.updateMany(
        {
          doctor: doctorId,
          status: 'waiting'
        },
        {
          status: 'cancelled',
          cancelledAt: new Date()
        }
      );

      // Clear patient currentQueue references
      const cancelledQueues = await Queue.find({
        doctor: doctorId,
        status: 'cancelled'
      });

      for (const queue of cancelledQueues) {
        if (queue.patient) {
          await Patient.findByIdAndUpdate(
            queue.patient,
            {
              $unset: { currentQueue: 1 },
              $addToSet: { queueHistory: queue._id }
            }
          );
        }
      }

      // Trigger queue update
      await triggerQueueUpdate(doctor.clinic, doctorId);
    }

    res.json({
      success: true,
      doctor: {
        _id: doctor._id,
        name: doctor.name,
        isAvailable: doctor.isAvailable,
        lastStatusChange: doctor.lastStatusChange
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Helper function to find the next available patient number
const findNextAvailableNumber = async (clinicId, currentNumber) => {
  const nextPatient = await Queue.findOne({
    clinic: clinicId,
    number: { $gt: currentNumber },
    status: 'waiting'
  }).sort('number');

  return nextPatient ? nextPatient.number : null;
};

// In queueController.js - Optimized version
export const updateCurrentNumber = async (req, res) => {
  try {
    const { doctorId, action } = req.body;

    if (!doctorId) {
      return res.status(400).json({ error: 'Doctor ID is required' });
    }

    const doctor = await Doctor.findById(doctorId);
    if (!doctor) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    const redisKey = `doctor:${doctorId}:current`;
    const currentServing = parseInt(await redisClient.get(redisKey) || 0);

    let newNumber;

    if (action === 'next') {
      const nextPatient = await Queue.findOne({
        clinic: doctor.clinic,
        doctor: doctorId,
        number: { $gt: currentServing },
        status: 'waiting'
      }).sort('number').select('number').lean();

      if (!nextPatient) {
        return res.status(400).json({
          error: 'No more patients to serve',
          currentNumber: currentServing
        });
      }

      newNumber = nextPatient.number;
      await redisClient.set(redisKey, newNumber);
    } else if (action === 'specific' && req.body.newNumber) {
      newNumber = parseInt(req.body.newNumber);
      await redisClient.set(redisKey, newNumber);
    } else {
      return res.status(400).json({ error: 'Invalid action' });
    }

    // Process served patients
    await processServedPatients(doctor.clinic, doctorId, newNumber);

    // Get upcoming patients
    const upcoming = await Queue.find({
      clinic: doctor.clinic,
      doctor: doctorId,
      number: { $gt: newNumber },
      status: 'waiting'
    })
      .sort('number')
      .limit(5)
      .populate('patient', 'name phone');

    // Calculate wait time
    const waitingCount = await Queue.countDocuments({
      clinic: doctor.clinic,
      doctor: doctorId,
      status: 'waiting',
      number: { $gt: newNumber }
    });

    const clinic = await Clinic.findById(doctor.clinic);
    const avgWaitTime = clinic?.averageProcessTime || 15;
    const totalWaitTime = waitingCount * avgWaitTime;

    // Broadcast update
    await triggerQueueUpdate(doctor.clinic, doctorId);

    res.json({
      success: true,
      currentNumber: newNumber,
      upcoming,
      waitTime: totalWaitTime,
      hasNextPatient: upcoming.length > 0
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Helper function to process served patients asynchronously
async function processServedPatients(clinicId, doctorId, newNumber) {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const servedQuery = {
      clinic: clinicId,
      doctor: doctorId || { $exists: false },
      number: { $lte: newNumber },
      status: 'waiting'
    };

    // Update served patients
    const servedPatients = await Queue.updateMany(
      servedQuery,
      {
        status: 'served',
        servedAt: new Date()
      }
    ).session(session);

    // Update patient records
    const servedQueues = await Queue.find(servedQuery)
      .populate('patient')
      .session(session);

    for (const queue of servedQueues) {
      if (queue.patient) {
        await Patient.findByIdAndUpdate(
          queue.patient._id,
          {
            $unset: { currentQueue: 1 },
            $addToSet: { queueHistory: queue._id }
          },
          { session }
        );
      }
    }

    await session.commitTransaction();
    session.endSession();

  } catch (error) {
    await session.abortTransaction();
    session.endSession();
    console.error('Error processing served patients:', error);
  }
}


// controllers/queueController.js - Update getQueueDataForPublic
export const getQueueDataForPublic = async (clinicId, doctorId = null) => {
  try {
    if (!doctorId) {
      throw new Error('Doctor ID is required');
    }

    const redisKey = `doctor:${doctorId}:current`;
    const currentNumber = await redisClient.get(redisKey) || '0';

    const queueData = await Queue.find({
      clinic: clinicId,
      doctor: doctorId,
      status: 'waiting'
    })
      .sort('number')
      .limit(10)
      .populate('patient', 'name phone')
      .lean();

    const current = parseInt(currentNumber);

    // Calculate wait time
    const waitingCount = await Queue.countDocuments({
      clinic: clinicId,
      doctor: doctorId,
      status: 'waiting',
      number: { $gt: current }
    });

    const clinic = await Clinic.findById(clinicId);
    const avgWaitTime = clinic?.averageProcessTime || 15;
    const totalWaiting = waitingCount;

    return {
      current: current,
      upcoming: queueData,
      avgWaitTime: avgWaitTime,
      totalWaiting: totalWaiting,
      canCallNext: queueData.length > 0,
      isDoctorQueue: true
    };
  } catch (err) {
    console.error('Error in getQueueDataForPublic:', err);
    throw err;
  }
};

// Update getCurrentQueue to handle doctor-specific queues
// Update getCurrentQueue to handle doctor-specific queues
export const getCurrentQueue = async (req, res) => {
  try {
    const { clinicId, doctorId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(clinicId)) {
      return res.status(400).json({ error: 'Invalid clinic ID' });
    }

    if (!mongoose.Types.ObjectId.isValid(doctorId)) {
      return res.status(400).json({ error: 'Invalid doctor ID' });
    }

    const queueData = await getQueueDataForPublic(clinicId, doctorId);
    res.json(queueData);
  } catch (err) {
    console.error('Queue error:', err);
    res.status(500).json({
      error: 'Failed to load queue',
      details: process.env.NODE_ENV === 'development' ? err.message : null
    });
  }
};


// Cancel a queue number
// Update cancelNumber function to handle doctor-specific queues
export const cancelNumber = async (req, res) => {
  try {
    const { queueId } = req.params;
    const patientId = req.user._id;

    const queue = await Queue.findOneAndUpdate(
      {
        _id: queueId,
        patient: patientId,
        status: 'waiting'
      },
      { status: 'cancelled', cancelledAt: new Date() },
      { new: true }
    ).populate('clinic');

    if (!queue) {
      return res.status(404).json({
        error: 'Queue not found or already processed'
      });
    }

    // Update patient record
    await Patient.findByIdAndUpdate(patientId, {
      $unset: { currentQueue: 1 },
      $addToSet: { queueHistory: queue._id }
    });

    // Determine the appropriate Redis key
    const redisKey = queue.doctor ? `doctor:${queue.doctor}:current` : `clinic:${queue.clinic._id}:current`;

    // Get updated queue data
    const [currentNumber, queueData] = await Promise.all([
      redisClient.get(redisKey) || 0,
      Queue.find({
        clinic: queue.clinic._id,
        doctor: queue.doctor || { $exists: false },
        status: 'waiting'
      })
        .sort('number')
        .limit(10)
        .populate('patient', 'name phone')
        .lean()
    ]);

    const waitTime = await calculateWaitTime(queue.clinic._id, queue.doctor || null);

    // Broadcast via Pusher
    await triggerQueueUpdate(queue.clinic._id, queue.doctor || null, {
      currentNumber: parseInt(currentNumber),
      upcoming: queueData,
      totalWaiting: waitTime.waitingCount,
      avgWaitTime: waitTime.avgWaitPerPatient / 60000,
      hasNextPatient: queueData.length > 0,
      cancelledNumber: queue.number,
      isDoctorQueue: !!queue.doctor
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const broadcastClinicStatus = async (clinicId, statusData) => {
  try {
    await pusher.trigger(
      `presence-clinic-${clinicId}`,
      'clinic-status-update',
      statusData
    );
    console.log(`Clinic status broadcast for clinic: ${clinicId}`);
  } catch (err) {
    console.error('Error broadcasting clinic status:', err);
  }
};