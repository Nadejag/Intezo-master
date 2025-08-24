import express from 'express';
import {
  getClinic,
  updateClinic,
  deleteClinic,
  getQueueAnalytics,
  toggleClinicStatus,  // Add this
  getClinicStatus,     // Add this
  debugQueueStatus,
  getClinicsPublic
} from '../controllers/clinicController.js';
import { authenticate, authorizeClinic } from '../middleware/auth.js';
import { loginClinic, registerClinic } from '../controllers/authController.js';
import Clinic from '../models/Clinic.js';

const router = express.Router();

// Public routes
router.post('/register', registerClinic);
router.post('/login', loginClinic);
router.get('/public', getClinicsPublic)

// In clinicRoutes.js - Add public status route
router.get('/:clinicId/status', async (req, res) => {
  try {
    const { clinicId } = req.params;
    const clinic = await Clinic.findById(clinicId)
      .select('isOpen operatingHours lastStatusChange name');

    if (!clinic) {
      return res.status(404).json({ error: 'Clinic not found' });
    }

    res.json({
      isOpen: clinic.isOpen,
      operatingHours: clinic.operatingHours,
      lastStatusChange: clinic.lastStatusChange,
      name: clinic.name
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Protected routes
router.use(authenticate, authorizeClinic);
router.get('/status', getClinicStatus);
router.get('/profile', getClinic);
router.put('/profile', updateClinic);
router.delete('/profile', deleteClinic);
router.get('/analytics', getQueueAnalytics);
// Add these new routes
router.post('/toggle-status', toggleClinicStatus);
router.get('/debug-queue', debugQueueStatus);

export default router;