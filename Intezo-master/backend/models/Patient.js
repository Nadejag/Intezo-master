import mongoose from 'mongoose';

const patientSchema = new mongoose.Schema({
  name: { 
    type: String, 
    required: true 
  },
  phone: {
    type: String,
    required: true,
    unique: true,
    validate: {
      validator: function(v) {
        return /^(\+92|92|0)?3\d{9}$/.test(v); // Pakistani phone number validation
      },
      message: props => `${props.value} is not a valid PK phone number!`
    }
  },
  fcmToken: {
    type: String,
    default: null
  },
  currentQueue: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Queue',
    default: null
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  currentQueue: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Queue',
    default: null
  },
  queueHistory: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Queue'
  }]
}, { timestamps: true });

// Middleware to manage queue status changes
patientSchema.pre('save', async function(next) {
  if (this.isModified('currentQueue')) {
    try {
      // If currentQueue is being set to null, add to history
      if (!this.currentQueue && this._originalCurrentQueue) {
        this.queueHistory.addToSet(this._originalCurrentQueue);
      }
    } catch (err) {
      return next(err);
    }
  }
  next();
});

// Virtual for tracking original value
patientSchema.virtual('_originalCurrentQueue').get(function() {
  return this._originalCurrentQueue;
}).set(function(v) {
  this._originalCurrentQueue = v;
});

export default mongoose.model('Patient', patientSchema);