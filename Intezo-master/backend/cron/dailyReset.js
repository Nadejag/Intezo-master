import cron from 'node-cron';
import redisClient from '../config/redis.js';
import Clinic from '../models/Clinic.js';

// Run at midnight every day
cron.schedule('0 0 * * *', async () => {
  try {
    console.log('Running daily queue reset...');
    
    const clinics = await Clinic.find({});
    
    for (const clinic of clinics) {
      // Reset Redis counter for each clinic
      await redisClient.set(`clinic:${clinic._id}:current`, 0);
      console.log(`Reset clinic ${clinic.name} counter to 0`);
    }
    
    console.log('Daily reset completed');
  } catch (err) {
    console.error('Daily reset error:', err);
  }
});

export default cron;