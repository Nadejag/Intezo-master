import express from 'express';
import clinicRoutes from './clinicRoutes.js';
import queueRoutes from './queueRoutes.js';
import patientRoutes from './patientRoutes.js';
import authRoutes from './authRoutes.js';
import doctorRoutes from './doctorRoutes.js'; // Add this import


const router = express.Router();

router.use('/clinics', clinicRoutes);
router.use('/queues', queueRoutes);
router.use('/patients', patientRoutes);
router.use('/auth', authRoutes);
router.use('/doctors', doctorRoutes); // Add this line

export default router;