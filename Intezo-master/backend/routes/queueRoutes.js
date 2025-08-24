import express from 'express';
import {
  bookNumber,
  cancelNumber,
  getCurrentQueue,
  updateCurrentNumber,
  getQueueDataForPublic
} from '../controllers/queueController.js';
import { authenticate, authenticatePatient, authorizeClinic } from '../middleware/auth.js';
import mongoose from 'mongoose';
// import { authorizeClinic } from '../middleware/roles.js'; // Fixed import path

const router = express.Router();

// Patient routes
router.get('/:clinicId', authenticate, getCurrentQueue);
router.get('/:clinicId', authenticatePatient, getCurrentQueue);
router.post('/book', authenticatePatient, bookNumber);
router.post('/cancel/:queueId', authenticate, cancelNumber);
router.post('/cancel/:queueId', authenticatePatient, cancelNumber);

// Clinic-admin routes
// Change from POST /update to POST /next
router.post('/next', authenticate, authorizeClinic, updateCurrentNumber);

// Add to queueRoutes.js
router.get('/public/:clinicId', async (req, res) => {
  try {
    const { clinicId } = req.params;
    
    if (!mongoose.Types.ObjectId.isValid(clinicId)) {
      return res.status(400).json({ error: 'Invalid clinic ID' });
    }

    console.log('Public queue request for clinic:', clinicId);
    
    const queueData = await getQueueDataForPublic(clinicId);
    
    console.log('Sending public queue data:', queueData);
    res.json(queueData);
  } catch (err) {
    console.error('Public queue endpoint error:', err);
    res.status(500).json({ 
      error: 'Failed to load queue info',
      details: process.env.NODE_ENV === 'development' ? err.message : null
    });
  }
});

export default router;