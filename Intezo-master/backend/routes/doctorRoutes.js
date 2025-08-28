// routes/doctorRoutes.js - Add new routes
import express from 'express';
import {
  getDoctors,
  getDoctor,
  addDoctor,
  updateDoctor,
  deleteDoctor,
  getDoctorQueueStatus,
  getDoctorsPublic,
  toggleDoctorAvailability,  // Add this import
} from '../controllers/doctorController.js';
import { authenticate, authorizeClinic } from '../middleware/auth.js';

const router = express.Router();

// Public routes
router.get('/public/:clinicId', getDoctorsPublic);

// Protected routes (clinic admin only)
router.use(authenticate, authorizeClinic);
router.get('/', getDoctors);
router.get('/:id', getDoctor);
router.post('/', addDoctor);
router.put('/:id', updateDoctor);
router.delete('/:id', deleteDoctor);
router.get('/:id/queue-status', getDoctorQueueStatus);
router.patch('/:id/availability', toggleDoctorAvailability);


export default router;