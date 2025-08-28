import mongoose from "mongoose";

// models/Queue.js - Update the schema
const queueSchema = new mongoose.Schema({
  clinic: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Clinic', 
    required: true 
  },
  doctor: {  // Add this field
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Doctor',
    default: null
  },
  patient: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Patient',
    required: true 
  },
  number: { 
    type: Number, 
    required: true 
  },
  status: { 
    type: String, 
    enum: ['waiting', 'served', 'cancelled', 'missed'], 
    default: 'waiting' 
  },
  bookedAt: { 
    type: Date, 
    default: Date.now 
  },
  servedAt: Date,
  missedAt: Date,
  cancelledAt: Date,
}, { timestamps: true });

// Add this method to the Queue model
queueSchema.statics.getNextQueueNumber = async function(clinicId, doctorId) {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  
  const lastQueue = await this.findOne({
    clinic: clinicId,
    doctor: doctorId,
    bookedAt: { $gte: todayStart }
  }).sort({ number: -1 });

  return lastQueue ? lastQueue.number + 1 : 1;
};

// Update indexes
queueSchema.index({ clinic: 1, doctor: 1, status: 1, number: 1 });
queueSchema.index({ patient: 1, clinic: 1 });

export default mongoose.model('Queue', queueSchema);