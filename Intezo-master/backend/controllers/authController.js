import Clinic from '../models/Clinic.js';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import Patient from '../models/Patient.js';


// Add this to your existing authController.js
export const patientLogin = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    // Find patient by phone number
    const patient = await Patient.findOne({ phone });

    if (!patient) {
      return res.status(404).json({ error: 'Patient not found' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { id: patient._id, role: 'patient' },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      patient: {
        _id: patient._id,
        name: patient.name,
        phone: patient.phone
      }
    });
  } catch (err) {
    console.error('Patient login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
};
// Enhanced error handling and validation
const generateToken = (clinic) => {
  return jwt.sign(
    { 
      id: clinic._id, 
      email: clinic.email,
      role: clinic.role 
    },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
};

// In authController.js - Update the registerClinic function
export const registerClinic = async (req, res) => {
  try {
    const { name, email, password, phone, address, services, operatingHours } = req.body;

    // Check if clinic already exists
    const existingClinic = await Clinic.findOne({
      $or: [{ email }, { phone }]
    });

    if (existingClinic) {
      // Figure out which field caused the conflict
      const conflictField = existingClinic.email === email ? 'email' : 'phone';
      return res.status(400).json({ error: `Clinic already exists with this ${conflictField}` });
    }


    // Create new clinic with all provided data
    const clinic = new Clinic({
      name,
      email,
      password,
      phone,
      address,
      services: services || ['General Consultation'], // Use provided services or default
      operatingHours: operatingHours || { // Use provided operating hours or default
        opening: '09:00',
        closing: '17:00'
      }
    });

    await clinic.save();

    // Generate token
    const token = generateToken(clinic);

    res.status(201).json({
      message: 'Clinic registered successfully',
      token,
      clinic: {
        _id: clinic._id,
        name: clinic.name,
        email: clinic.email,
        phone: clinic.phone,
        address: clinic.address,
        services: clinic.services,
        operatingHours: clinic.operatingHours,
        role: clinic.role
      }
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
};

export const loginClinic = async (req, res) => {
  try {
    console.log('Login request body:', req.body); // Debug log

    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const clinic = await Clinic.findOne({ email });
    if (!clinic) {
      console.log('No clinic found for email:', email); // Debug log
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const isMatch = await bcrypt.compare(password, clinic.password);
    if (!isMatch) {
      console.log('Password mismatch for email:', email); // Debug log
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { id: clinic._id, role: clinic.role },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    console.log('Login successful for:', email); // Debug log
    res.json({
      token,
      clinic: {
        _id: clinic._id,
        name: clinic.name,
        email: clinic.email,
        phone: clinic.phone,
        address: clinic.address
      }
    });
  } catch (err) {
    console.error('Login controller error:', err);
    res.status(500).json({ error: 'Login failed', details: err.message });
  }
};