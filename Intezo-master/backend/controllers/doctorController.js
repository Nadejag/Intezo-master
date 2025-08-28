// controllers/doctorController.js
import Doctor from '../models/Doctor.js';
import Clinic from '../models/Clinic.js';
import Queue from '../models/Queue.js';
import redisClient from '../config/redis.js';

// Get all doctors for a clinic
export const getDoctors = async (req, res) => {
  try {
    const doctors = await Doctor.find({ clinic: req.clinic._id, isActive: true })
      .select('-__v')
      .sort({ name: 1 });
    
    res.json(doctors);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Get a specific doctor
export const getDoctor = async (req, res) => {
  try {
    const doctor = await Doctor.findOne({
      _id: req.params.id,
      clinic: req.clinic._id
    }).select('-__v');

    if (!doctor) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    res.json(doctor);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Add a new doctor
export const addDoctor = async (req, res) => {
  try {
    const {
      name,
      specialty,
      consultationFee,
      availableDays,
      availableHours
    } = req.body;

    const doctor = new Doctor({
      name,
      specialty,
      consultationFee: consultationFee || 0,
      availableDays: availableDays || ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      availableHours: availableHours || { start: '09:00', end: '17:00' },
      clinic: req.clinic._id
    });

    await doctor.save();

    res.status(201).json({
      message: 'Doctor added successfully',
      doctor: {
        _id: doctor._id,
        name: doctor.name,
        specialty: doctor.specialty,
        consultationFee: doctor.consultationFee,
        availableDays: doctor.availableDays,
        availableHours: doctor.availableHours
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Update doctor information
export const updateDoctor = async (req, res) => {
  try {
    const updates = Object.keys(req.body);
    const allowedUpdates = ['name', 'specialty', 'consultationFee', 'availableDays', 'availableHours', 'isActive'];
    const isValidOperation = updates.every(update => allowedUpdates.includes(update));

    if (!isValidOperation) {
      return res.status(400).json({ error: 'Invalid updates!' });
    }

    const doctor = await Doctor.findOneAndUpdate(
      { _id: req.params.id, clinic: req.clinic._id },
      req.body,
      { new: true, runValidators: true }
    ).select('-__v');

    if (!doctor) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    res.json({
      message: 'Doctor updated successfully',
      doctor
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Delete a doctor
export const deleteDoctor = async (req, res) => {
  try {
    const doctor = await Doctor.findOneAndDelete({
      _id: req.params.id,
      clinic: req.clinic._id
    });

    if (!doctor) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    res.json({ message: 'Doctor deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Get doctor's current queue status
// In doctorController.js - Add new functions for doctor queue management
export const toggleDoctorAvailability = async (req, res) => {
  try {
    const doctor = await Doctor.findOneAndUpdate(
      { _id: req.params.id, clinic: req.clinic._id },
      { 
        isAvailable: req.body.isAvailable,
        lastStatusChange: new Date()
      },
      { new: true }
    ).select('-__v');

    if (!doctor) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    // If making doctor unavailable, handle their queue
    if (!req.body.isAvailable) {
      // Reset doctor's current number in Redis
      await redisClient.set(`doctor:${doctor._id}:current`, 0);
      
      // Cancel all waiting patients for this doctor
      await Queue.updateMany(
        {
          doctor: doctor._id,
          status: 'waiting'
        },
        {
          status: 'cancelled',
          cancelledAt: new Date()
        }
      );

      // Clear patient currentQueue references
      const cancelledQueues = await Queue.find({
        doctor: doctor._id,
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
      await triggerQueueUpdate(doctor.clinic, doctor._id);
    }

    res.json({
      message: 'Doctor availability updated successfully',
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

// Update getDoctorQueueStatus to handle doctor-specific data
export const getDoctorQueueStatus = async (req, res) => {
  try {
    const doctorId = req.params.id;
    
    const [doctor, currentNumber, waitingPatients] = await Promise.all([
      Doctor.findById(doctorId),
      redisClient.get(`doctor:${doctorId}:current`) || 0,
      Queue.find({
        doctor: doctorId,
        status: 'waiting'
      })
      .populate('patient', 'name phone')
      .sort('number')
      .limit(10)
    ]);

    if (!doctor) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    const current = parseInt(currentNumber);
    const upcoming = waitingPatients.filter(q => q.number > current);

    res.json({
      doctor: {
        name: doctor.name,
        specialty: doctor.specialty,
        isAvailable: doctor.isAvailable
      },
      currentNumber: current,
      upcoming,
      totalWaiting: upcoming.length,
      isAvailable: doctor.isAvailable
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
// Get public doctors list for a clinic
export const getDoctorsPublic = async (req, res) => {
  try {
    const { clinicId } = req.params;
    
    const doctors = await Doctor.find({
      clinic: clinicId,
      isActive: true
    })
    .select('name specialty consultationFee availableDays availableHours')
    .sort({ name: 1 });

    res.json(doctors);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Add function to get doctor's current queue status
export const getDoctorCurrentQueue = async (req, res) => {
  try {
    const doctorId = req.params.id;
    const doctor = await Doctor.findById(doctorId);
    
    if (!doctor) {
      return res.status(404).json({ error: 'Doctor not found' });
    }

    const redisKey = `doctor:${doctorId}:current`;
    const currentNumber = parseInt(await redisClient.get(redisKey) || 0);

    const waitingPatients = await Queue.find({
      doctor: doctorId,
      status: 'waiting'
    })
    .populate('patient', 'name phone')
    .sort('number')
    .limit(10);

    const upcoming = waitingPatients.filter(q => q.number > currentNumber);

    res.json({
      doctor: {
        name: doctor.name,
        specialty: doctor.specialty,
        isAvailable: doctor.isAvailable
      },
      currentNumber,
      upcoming,
      totalWaiting: upcoming.length,
      hasNextPatient: upcoming.length > 0
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// In doctorController.js - Add function to handle next patient for doctor
// export const nextPatient = async (req, res) => {
//   try {
//     const doctorId = req.params.id;
//     const doctor = await Doctor.findById(doctorId);
    
//     if (!doctor) {
//       return res.status(404).json({ error: 'Doctor not found' });
//     }

//     if (!doctor.isAvailable) {
//       return res.status(400).json({ error: 'Doctor is not available' });
//     }

//     const redisKey = `doctor:${doctorId}:current`;
//     const currentServing = parseInt(await redisClient.get(redisKey) || 0);

//     // Find next patient for this doctor
//     const nextPatient = await Queue.findOne({
//       doctor: doctorId,
//       number: { $gt: currentServing },
//       status: 'waiting'
//     }).sort('number').populate('patient', 'name phone');

//     if (!nextPatient) {
//       return res.status(400).json({
//         error: 'No more patients to serve',
//         currentNumber: currentServing
//       });
//     }

//     // Update Redis to the new number
//     await redisClient.set(redisKey, nextPatient.number);

//     // Process served patients
//     const servedPatients = await Queue.find({
//       doctor: doctorId,
//       number: { $lte: nextPatient.number },
//       status: 'waiting'
//     });

//     // Update served patients
//     await Promise.all(servedPatients.map(async queue => {
//       queue.status = 'served';
//       queue.servedAt = new Date();
//       await queue.save();

//       if (queue.patient) {
//         await Patient.findByIdAndUpdate(
//           queue.patient._id,
//           {
//             $unset: { currentQueue: 1 },
//             $addToSet: { queueHistory: queue._id }
//           }
//         );
//       }
//     }));

//     // Get updated queue data
//     const [currentNumber, waitingPatients] = await Promise.all([
//       redisClient.get(redisKey) || 0,
//       Queue.find({
//         doctor: doctorId,
//         status: 'waiting'
//       })
//       .populate('patient', 'name phone')
//       .sort('number')
//       .limit(10)
//     ]);

//     const upcoming = waitingPatients.filter(q => q.number > parseInt(currentNumber));

//     // Broadcast update
//     await triggerQueueUpdate(doctor.clinic, doctorId, {
//       currentNumber: parseInt(currentNumber),
//       upcoming,
//       totalWaiting: upcoming.length,
//       hasNextPatient: upcoming.length > 0
//     });

//     res.json({
//       success: true,
//       currentNumber: parseInt(currentNumber),
//       nextPatient: nextPatient.patient,
//       totalServed: servedPatients.length
//     });

//   } catch (err) {
//     res.status(500).json({ error: err.message });
//   }
// };