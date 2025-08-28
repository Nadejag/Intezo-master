import express from 'express';
import { 
  // sendPhoneOtp,
  // verifyOtp, 
  registerClinic, 
  patientLogin,
  logoutFromAllDevices
} from '../controllers/authController.js';
import { validatePhone } from '../middleware/validation.js';
import { authenticatePatient } from '../middleware/auth.js';

const router = express.Router();

// Public routes
// router.post('/send-otp', validatePhone, sendPhoneOtp);
// router.post('/verify-otp', verifyOtp);
router.post('/register/clinic', registerClinic);
router.post('/login/patient', patientLogin); // Add this route
router.post('/logout/all', authenticatePatient, logoutFromAllDevices);

export default router;