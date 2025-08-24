import jwt from 'jsonwebtoken';
import Clinic from '../models/Clinic.js';
import Patient from '../models/Patient.js';

// Patient authentication middleware
// In auth.js - Update authenticate middleware to handle both clinic and patient tokens
export const authenticate = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if it's a clinic token
    if (decoded.role === 'clinic') {
      const clinic = await Clinic.findById(decoded.id).select('-password');
      if (!clinic) {
        return res.status(401).json({ error: 'Invalid token - clinic not found' });
      }
      req.clinic = clinic;
      req.user = clinic; // For backward compatibility
      return next();
    }
    
    // Check if it's a patient token
    if (decoded.role === 'patient') {
      const patient = await Patient.findById(decoded.id);
      if (!patient) {
        return res.status(401).json({ error: 'Invalid token - patient not found' });
      }
      req.patient = patient;
      req.user = patient; // For backward compatibility
      return next();
    }
    
    return res.status(401).json({ error: 'Invalid token role' });
    
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Keep the specialized middlewares for specific roles
export const authenticatePatient = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    if (decoded.role !== 'patient') {
      return res.status(401).json({ error: 'Patient access required' });
    }
    
    const patient = await Patient.findById(decoded.id);
    if (!patient) {
      return res.status(401).json({ error: 'Invalid token - patient not found' });
    }
    
    req.patient = patient;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

export const authorizeClinic = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    if (decoded.role !== 'clinic') {
      return res.status(401).json({ error: 'Clinic access required' });
    }
    
    const clinic = await Clinic.findById(decoded.id).select('-password');
    if (!clinic) {
      return res.status(401).json({ error: 'Invalid token - clinic not found' });
    }
    
    req.clinic = clinic;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
};