import Queue from '../models/Queue.js';
import Clinic from '../models/Clinic.js';
import Patient from '../models/Patient.js';
import redisClient from '../config/redis.js';
import mongoose from 'mongoose';
import { sendNotification } from '../services/notificationService.js';
import pusher from '../config/pusher.js';

// In queueController.js, update triggerQueueUpdate function
export const triggerQueueUpdate = async (clinicId, data = null) => {
  try {
    // Get clinic status
    const clinic = await Clinic.findById(clinicId).select('isOpen operatingHours');

    const queueData = data || await getQueueDataForBroadcast(clinicId);

    // Add clinic status to broadcast data
    const broadcastData = {
      ...queueData,
      clinicStatus: {
        isOpen: clinic.isOpen,
        operatingHours: clinic.operatingHours
      }
    };

    await pusher.trigger(
      `presence-clinic-${clinicId}`,
      'queue-update',
      broadcastData
    );

    await pusher.trigger(
      `public-clinic-${clinicId}`,  // Public channel
      'queue-update',
      queueData
    );


    return broadcastData;
  } catch (err) {
    console.error('Pusher trigger error:', err);
    throw err;
  }
};

// Helper function to get queue data
const getQueueDataForBroadcast = async (clinicId) => {
  const [currentNumber, queueData] = await Promise.all([
    redisClient.get(`clinic:${clinicId}:current`) || 0,
    Queue.find({
      clinic: clinicId,
      status: 'waiting'
    })
      .sort('number')
      .limit(10)
      .populate('patient', 'name phone')
      .lean()
  ]);

  const waitTime = await calculateWaitTime(clinicId);

  return {
    currentNumber: parseInt(currentNumber),
    upcoming: queueData,
    totalWaiting: waitTime.waitingCount,
    avgWaitTime: waitTime.avgWaitPerPatient / 60000,
    hasNextPatient: queueData.length > 0
  };
};

// Calculate average wait time based on historical data
const calculateWaitTime = async (clinicId) => {
  const clinic = await Clinic.findById(clinicId);
  if (!clinic) throw new Error('Clinic not found');

  const avgProcessTime = clinic.averageProcessTime || 15; // Default 15 mins
  const currentNumber = parseInt(await redisClient.get(`clinic:${clinicId}:current`) || 0);

  const waitingCount = await Queue.countDocuments({
    clinic: clinicId,
    status: 'waiting',
    number: { $gt: currentNumber }
  });

  return {
    avgWaitPerPatient: avgProcessTime * 60000, // Convert to milliseconds
    totalWaitTime: waitingCount * avgProcessTime,
    waitingCount
  };
};

// Book a queue number with improved numbering logic
// In queueController.js - Update the bookNumber function
export const bookNumber = async (req, res) => {
  try {
    const { clinicId, patientId } = req.body;

    // Check if clinic is open
    const clinic = await Clinic.findById(clinicId);
    if (!clinic || !clinic.isOpen) {
      return res.status(400).json({ error: 'Clinic is currently closed' });
    }

    // Check if within operating hours
    const now = new Date();
    const currentTime = now.toTimeString().slice(0, 5);
    const [openingHour, openingMinute] = clinic.operatingHours.opening.split(':').map(Number);
    const [closingHour, closingMinute] = clinic.operatingHours.closing.split(':').map(Number);

    const openingTime = new Date();
    openingTime.setHours(openingHour, openingMinute, 0, 0);

    const closingTime = new Date();
    closingTime.setHours(closingHour, closingMinute, 0, 0);

    if (now < openingTime || now > closingTime) {
      return res.status(400).json({ error: 'Clinic is outside operating hours' });
    }

    // Get patient and validate
    const patient = await Patient.findById(patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });
    if (patient.currentQueue) return res.status(400).json({ error: 'Patient already in queue' });

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

    // Create and save queue entry
    const queue = new Queue({
      clinic: clinicId,
      patient: patientId,
      number: nextNumber,
      status: 'waiting',
      bookedAt: new Date()
    });
    await queue.save();
    console.log(`Created queue entry with number: ${nextNumber}`);

    // Update patient's current queue
    await Patient.findByIdAndUpdate(patientId, { currentQueue: queue._id });

    // Calculate wait time
    const waitTime = await calculateWaitTime(clinicId);

    // Broadcast via Pusher
    await triggerQueueUpdate(clinicId);
    await pusher.trigger(
      `public-clinic-${clinicId}`,  // Use public channel
      'queue-update',
      await getQueueDataForBroadcast(clinicId)
    );
    console.log(`Queue update broadcasted`);

    // Send confirmation notification
    await sendNotification(patientId, 'Booking Confirmed', `Your queue number is ${nextNumber}`);

    res.status(201).json({
      ...queue.toObject(),
      estimatedWait: waitTime.totalWaitTime
    });

  } catch (err) {
    console.error('Error in bookNumber:', err);
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
// Update current serving number with improved logic
export const updateCurrentNumber = async (req, res) => {
  try {
    const { clinicId, action } = req.body; // Change from newNumber to action
    const currentServing = parseInt(await redisClient.get(`clinic:${clinicId}:current`) || 0);

    let newNumber;
    
    if (action === 'next') {
      // Find the next available patient number
      const nextPatient = await Queue.findOne({
        clinic: clinicId,
        number: { $gt: currentServing },
        status: 'waiting'
      }).sort('number');
      
      if (!nextPatient) {
        return res.status(400).json({
          error: 'No more patients to serve',
          currentNumber: currentServing
        });
      }
      
      newNumber = nextPatient.number;
    } else if (action === 'specific' && req.body.newNumber) {
      // Allow manual number selection if needed
      newNumber = parseInt(req.body.newNumber);
    } else {
      return res.status(400).json({ error: 'Invalid action' });
    }

    // Update Redis to the new number
    await redisClient.set(`clinic:${clinicId}:current`, newNumber);

    // Process served patients (all numbers up to and including the new number)
    const servedPatients = await Queue.find({
      clinic: clinicId,
      number: { $lte: newNumber },
      status: 'waiting'
    }).populate('patient');

    // Process missed patients (numbers between current and new that weren't served)
    const missedPatients = await Queue.find({
      clinic: clinicId,
      number: { $gt: currentServing, $lt: newNumber },
      status: 'waiting'
    }).populate('patient');

    // Update served patients
    await Promise.all(servedPatients.map(async queue => {
      queue.status = 'served';
      queue.servedAt = new Date();
      await queue.save();

      if (queue.patient) {
        await Patient.findByIdAndUpdate(
          queue.patient._id,
          {
            $unset: { currentQueue: 1 },
            $addToSet: { queueHistory: queue._id }
          }
        );
      }
    }));

    // Update missed patients
    await Promise.all(missedPatients.map(async queue => {
      queue.status = 'missed';
      queue.missedAt = new Date();
      await queue.save();

      if (queue.patient) {
        await Patient.findByIdAndUpdate(
          queue.patient._id,
          {
            $unset: { currentQueue: 1 },
            $addToSet: { queueHistory: queue._id }
          }
        );
      }
    }));

    // Get upcoming patients
    const upcoming = await Queue.find({
      clinic: clinicId,
      number: { $gt: newNumber },
      status: 'waiting'
    })
    .sort('number')
    .limit(5)
    .populate('patient', 'name phone');

    // Calculate wait times
    const waitTime = await calculateWaitTime(clinicId);

    // Broadcast via Pusher
    await triggerQueueUpdate(clinicId, {
      currentNumber: newNumber,
      upcoming,
      totalWaiting: waitTime.waitingCount,
      avgWaitTime: waitTime.avgWaitPerPatient / 60000,
      hasNextPatient: upcoming.length > 0
    });

    res.json({
      success: true,
      currentNumber: newNumber,
      upcoming,
      served: servedPatients.length,
      missed: missedPatients.length,
      waitTime: waitTime.totalWaitTime,
      hasNextPatient: upcoming.length > 0
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Get current queue state
export const getQueueDataForPublic = async (clinicId) => {
  try {
    console.log('Getting public queue data for clinic:', clinicId);

    const [currentNumber, queueData] = await Promise.all([
      redisClient.get(`clinic:${clinicId}:current`) || '0',
      Queue.find({
        clinic: clinicId,
        status: 'waiting'
      })
        .sort('number')
        .limit(10)
        .populate('patient', 'name phone')
        .lean()
    ]);

    console.log('Current number from Redis:', currentNumber);
    console.log('Queue data found:', queueData.length);

    const current = parseInt(currentNumber);

    // Calculate basic wait time estimation (15 minutes per patient as default)
    const waitingCount = await Queue.countDocuments({
      clinic: clinicId,
      status: 'waiting',
      number: { $gt: current }
    });

    const avgWaitTime = 15; // Default 15 minutes per patient
    const totalWaiting = waitingCount;

    return {
      current: current,
      upcoming: queueData,
      avgWaitTime: avgWaitTime,
      totalWaiting: totalWaiting,
      canCallNext: queueData.length > 0
    };
  } catch (err) {
    console.error('Error in getQueueDataForPublic:', err);
    throw err;
  }
};

// Update getCurrentQueue to handle both authenticated and public access
export const getCurrentQueue = async (req, res) => {
  try {
    const { clinicId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(clinicId)) {
      return res.status(400).json({ error: 'Invalid clinic ID' });
    }

    const queueData = await getQueueDataForPublic(clinicId);
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

    // Get updated queue data
    const [currentNumber, queueData] = await Promise.all([
      redisClient.get(`clinic:${queue.clinic._id}:current`) || 0,
      Queue.find({
        clinic: queue.clinic._id,
        status: 'waiting'
      })
        .sort('number')
        .limit(10)
        .populate('patient', 'name phone')
        .lean()
    ]);

    const waitTime = await calculateWaitTime(queue.clinic._id);

    // Broadcast via Redis pub/sub
    await triggerQueueUpdate(queue.clinic._id, {
      currentNumber: parseInt(currentNumber),
      upcoming: queueData,
      totalWaiting: waitTime.waitingCount,
      avgWaitTime: waitTime.avgWaitPerPatient / 60000,
      hasNextPatient: queueData.length > 0,
      cancelledNumber: queue.number
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
