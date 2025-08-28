// models/Doctor.js - Update the schema
import mongoose from 'mongoose';

const doctorSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  specialty: {
    type: String,
    required: true
  },
  clinic: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Clinic',
    required: true
  },
  isActive: {
    type: Boolean,
    default: true
  },
  isAvailable: {  // Add this field for real-time availability
    type: Boolean,
    default: true
  },
  consultationFee: {
    type: Number,
    default: 0
  },
  availableDays: {
    type: [String],
    enum: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
    default: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
  },
  availableHours: {
    start: { type: String, default: '09:00' },
    end: { type: String, default: '17:00' }
  },
  currentQueueNumber: {  // Track doctor's current serving number
    type: Number,
    default: 0
  },
  lastStatusChange: {  // Track when doctor's status changed
    type: Date,
    default: Date.now
  }
}, { timestamps: true });

// Index for faster queries
doctorSchema.index({ clinic: 1, isActive: 1, isAvailable: 1 });

export default mongoose.model('Doctor', doctorSchema);