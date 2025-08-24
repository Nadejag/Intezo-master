import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

const clinicSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  phone: { type: String, required: true },
  address: { type: String, required: true },
  services: { type: [String], default: ['General Consultation'] },
  operatingHours: {
    opening: { type: String, default: '09:00' },
    closing: { type: String, default: '17:00' }
  },
  averageProcessTime: { type: Number, default: 15 }, // Minutes per patient
  maxActiveQueues: { type: Number, default: 50 }, // Limit simultaneous patients
  role: { type: String, default: 'clinic' },
  // Add these new fields
  isOpen: { type: Boolean, default: false },
  lastStatusChange: { type: Date, default: Date.now }
}, { timestamps: true });

// In Clinic.js model - Add this method
clinicSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// In Clinic.js model - Add this pre-save hook
clinicSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

export default mongoose.model('Clinic', clinicSchema);