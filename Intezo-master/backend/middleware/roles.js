import Clinic from '../models/Clinic.js';

// Middleware to authorize clinic admin
export const authorizeClinic = async (req, res, next) => {
  try {
    const clinic = await Clinic.findById(req.clinic._id);
    
    if (!clinic) {
      return res.status(404).json({ error: 'Clinic not found' });
    }

    // Check if the user has the required role
    if (clinic.role !== 'clinic') {
      return res.status(403).json({ error: 'Clinic admin access required' });
    }

    next();
  } catch (err) {
    console.error('Authorization error:', err);
    res.status(500).json({ error: 'Authorization failed' });
  }
};

// Middleware to authorize patient
export const authorizePatient = async (req, res, next) => {
  try {
    if (req.user.role !== 'patient') {
      return res.status(403).json({ error: 'Patient access required' });
    }
    next();
  } catch (err) {
    console.error('Authorization error:', err);
    res.status(500).json({ error: 'Authorization failed' });
  }
};