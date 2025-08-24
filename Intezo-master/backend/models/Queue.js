import mongoose from 'mongoose';

const queueSchema = new mongoose.Schema({
  clinic: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Clinic', 
    required: true 
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
    enum: ['waiting', 'served', 'cancelled'], 
    default: 'waiting' 
  },
  bookedAt: { 
    type: Date, 
    default: Date.now 
  },
  status: {
    type: String,
    enum: ['waiting', 'served', 'missed', 'cancelled'],
    default: 'waiting'
  },
  servedAt: Date,
  missedAt: Date,
  cancelledAt: Date,
}, { timestamps: true });

// Indexes for faster queries
queueSchema.index({ clinic: 1, status: 1, number: 1 });
queueSchema.index({ patient: 1, clinic: 1 });

const Queue = mongoose.model('Queue', queueSchema);

export default Queue;