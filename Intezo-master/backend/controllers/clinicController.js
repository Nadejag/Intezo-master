import Clinic from '../models/Clinic.js';
// Add these imports at the top
import Queue from '../models/Queue.js';
import mongoose from 'mongoose';
import redisClient from '../config/redis.js'; // Add this import
import Patient from '../models/Patient.js'; // Add this import
import { broadcastClinicStatus, triggerQueueUpdate } from './queueController.js'; // Add this import

// Add this function to track daily resets
const checkDailyReset = async (clinicId) => {
  try {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    
    const todayBookings = await Queue.countDocuments({
      clinic: clinicId,
      bookedAt: { $gte: todayStart }
    });

    // If no bookings today but Redis has old data, reset it
    if (todayBookings === 0) {
      const currentServing = parseInt(await redisClient.get(`clinic:${clinicId}:current`) || 0);
      if (currentServing > 0) {
        await redisClient.set(`clinic:${clinicId}:current`, 0);
        console.log(`Daily reset: Clinic ${clinicId} Redis counter reset to 0`);
      }
    }
  } catch (err) {
    console.error('Error in daily reset check:', err);
  }
};

// Get Clinic Profile
export const getClinic = async (req, res) => {
  try {
    const clinic = await Clinic.findById(req.clinic._id)
      .select('-password -__v');
    res.json(clinic);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// Update Clinic Profile
export const updateClinic = async (req, res) => {
  try {
    const updates = Object.keys(req.body);
    const allowedUpdates = ['name', 'phone', 'address', 'services', 'operatingHours'];
    const isValidOperation = updates.every(update => allowedUpdates.includes(update));

    if (!isValidOperation) {
      return res.status(400).json({ error: 'Invalid updates!' });
    }

    const clinic = await Clinic.findByIdAndUpdate(
      req.clinic._id,
      req.body,
      { new: true, runValidators: true }
    ).select('-password -__v');

    res.json(clinic);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

// Delete Clinic
export const deleteClinic = async (req, res) => {
  try {
    await Clinic.findByIdAndDelete(req.clinic._id);
    res.json({ message: 'Clinic deleted successfully' });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};
export const getQueueDashboard = async (req, res) => {
  try {
    const clinicId = req.clinic._id;
    const [currentQueue, upcoming] = await Promise.all([
      Queue.findOne({ clinic: clinicId, status: 'waiting' }).sort('number'),
      Queue.find({ clinic: clinicId, status: 'waiting' })
        .sort('number')
        .limit(5)
        .populate('patient', 'phone'),
    ]);

    res.json({
      current: currentQueue?.number || 0,
      upcoming,
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to load dashboard' });
  }
};

// In clinicController.js - Update the getQueueAnalytics function
export const getQueueAnalytics = async (req, res) => {
  try {
    const clinicId = req.clinic._id;
    
    // Get patients by status with full details
    const [waiting, served, cancelled] = await Promise.all([
      Queue.find({ 
        clinic: clinicId, 
        status: 'waiting' 
      })
      .populate('patient', 'name phone')
      .select('number status bookedAt patient')
      .sort({ number: 1 }),
      
      Queue.find({ 
        clinic: clinicId, 
        status: 'served' 
      })
      .populate('patient', 'name phone')
      .select('number status servedAt patient')
      .sort({ servedAt: -1 })
      .limit(50), // Limit to recent served patients
      
      Queue.find({ 
        clinic: clinicId, 
        status: 'cancelled' 
      })
      .populate('patient', 'name phone')
      .select('number status cancelledAt patient')
      .sort({ cancelledAt: -1 })
      .limit(50) // Limit to recent cancelled patients
    ]);

    res.json({
      waiting: waiting.map(q => ({
        _id: q._id,
        number: q.number,
        status: q.status,
        bookedAt: q.bookedAt,
        name: q.patient?.name,
        phone: q.patient?.phone
      })),
      served: served.map(q => ({
        _id: q._id,
        number: q.number,
        status: q.status,
        servedAt: q.servedAt,
        name: q.patient?.name,
        phone: q.patient?.phone
      })),
      cancelled: cancelled.map(q => ({
        _id: q._id,
        number: q.number,
        status: q.status,
        cancelledAt: q.cancelledAt,
        name: q.patient?.name,
        phone: q.patient?.phone
      }))
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Add these functions to clinicController.js

// Toggle clinic open/close status
export const toggleClinicStatus = async (req, res) => {
  try {
    const clinic = await Clinic.findById(req.clinic._id);
    
    if (!clinic) {
      return res.status(404).json({ error: 'Clinic not found' });
    }

    clinic.isOpen = !clinic.isOpen;
    clinic.lastStatusChange = new Date();
    
    if (clinic.isOpen) {
      await resetClinicQueue(req.clinic._id);
    }
    
    await clinic.save();
    
    // Broadcast the status change
    await broadcastClinicStatus(req.clinic._id, {
      isOpen: clinic.isOpen,
      lastStatusChange: clinic.lastStatusChange
    });
    
    res.json({ 
      success: true, 
      isOpen: clinic.isOpen,
      message: clinic.isOpen ? 'Clinic is now open' : 'Clinic is now closed'
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Reset clinic queue (set current number to 0)
// In clinicController.js - Update resetClinicQueue function
const resetClinicQueue = async (clinicId) => {
  try {
    console.log(`Resetting clinic queue for clinic: ${clinicId}`);
    
    // Reset Redis current number to 0
    await redisClient.set(`clinic:${clinicId}:current`, 0);
    console.log(`Redis counter reset to 0 for clinic: ${clinicId}`);
    
    // Also update any waiting queues to cancelled
    const updateResult = await Queue.updateMany(
      { 
        clinic: clinicId, 
        status: 'waiting' 
      },
      { 
        status: 'cancelled',
        cancelledAt: new Date()
      }
    );
    
    console.log(`Cancelled ${updateResult.modifiedCount} waiting queues`);

    // Clear patient currentQueue references for cancelled queues
    const waitingQueues = await Queue.find({
      clinic: clinicId,
      status: 'cancelled'
    });
    
    console.log(`Found ${waitingQueues.length} cancelled queues to process`);
    
    for (const queue of waitingQueues) {
      if (queue.patient) {
        await Patient.findByIdAndUpdate(
          queue.patient,
          { 
            $unset: { currentQueue: 1 },
            $addToSet: { queueHistory: queue._id }
          }
        );
        console.log(`Cleared currentQueue for patient: ${queue.patient}`);
      }
    }

    // IMPORTANT: Trigger queue update to notify all clients
    await triggerQueueUpdate(clinicId);
    console.log(`Queue update triggered for clinic: ${clinicId}`);
    
  } catch (err) {
    console.error('Error resetting clinic queue:', err);
    throw err;
  }
};

// Get clinic status
export const getClinicStatus = async (req, res) => {
  try {
    const clinic = await Clinic.findById(req.clinic._id)
      .select('isOpen operatingHours lastStatusChange name');
    
    if (!clinic) {
      return res.status(404).json({ error: 'Clinic not found' });
    }
    
    // Check daily reset
    await checkDailyReset(req.clinic._id);
    
    // Check if clinic should be automatically closed based on operating hours
    const now = new Date();
    const currentTime = now.toTimeString().slice(0, 5); // HH:MM format
    
    // Parse operating hours
    const [openingHour, openingMinute] = clinic.operatingHours.opening.split(':').map(Number);
    const [closingHour, closingMinute] = clinic.operatingHours.closing.split(':').map(Number);
    
    // Create date objects for comparison
    const openingTime = new Date();
    openingTime.setHours(openingHour, openingMinute, 0, 0);
    
    const closingTime = new Date();
    closingTime.setHours(closingHour, closingMinute, 0, 0);
    
    // Check if current time is outside operating hours
    const isWithinOperatingHours = now >= openingTime && now <= closingTime;
    
    // If clinic is open but outside operating hours, automatically close it
    if (clinic.isOpen && !isWithinOperatingHours) {
      clinic.isOpen = false;
      clinic.lastStatusChange = new Date();
      await clinic.save();
      
      // Also reset the queue
      await resetClinicQueue(req.clinic._id);
    }
    
    res.json({
      isOpen: clinic.isOpen,
      operatingHours: clinic.operatingHours,
      lastStatusChange: clinic.lastStatusChange,
      name: clinic.name,
      currentTime: currentTime,
      isWithinOperatingHours: isWithinOperatingHours
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Add this to clinicController.js or create a new debug controller
export const debugQueueStatus = async (req, res) => {
  try {
    const clinicId = req.clinic._id;
    
    const redisCurrent = await redisClient.get(`clinic:${clinicId}:current`);
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    
    const todayBookings = await Queue.find({
      clinic: clinicId,
      bookedAt: { $gte: todayStart },
      status: { $ne: 'cancelled' }
    }).sort({ number: -1 });
    
    const allBookings = await Queue.find({ clinic: clinicId }).sort({ number: -1 }).limit(5);
    
    res.json({
      redisCurrent: parseInt(redisCurrent || 0),
      todayBookingsCount: todayBookings.length,
      todayBookings: todayBookings.map(q => ({ number: q.number, status: q.status, bookedAt: q.bookedAt })),
      recentBookings: allBookings.map(q => ({ number: q.number, status: q.status, bookedAt: q.bookedAt })),
      clinicStatus: await Clinic.findById(clinicId).select('isOpen operatingHours')
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Get clinics for public access (no authentication required)
export const getClinicsPublic = async (req, res) => {
  try {
    const clinics = await Clinic.find({})
      .select('-password -__v -createdAt -updatedAt');
    
    res.json(clinics);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};