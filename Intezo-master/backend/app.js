import express from 'express';
import http from 'http';
import mainRouter from './routes/index.js';
import { log } from 'console';
import mongoose from 'mongoose';
import 'dotenv/config';
import cors from 'cors';
import pusherAuth from './routes/pusherAuth.js';
import pusher from './config/pusher.js';
import redisClient from './config/redis.js';
import './cron/dailyReset.js';
import Clinic from './models/Clinic.js';
import Doctor from './models/Doctor.js';

const app = express();
const server = http.createServer(app);


// In app.js - Fix CORS configuration
app.use(cors({
  origin: process.env.FRONTEND_URL,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

// In app.js or a separate initialization file
await redisClient.connect();
// Add this to your server startup or a separate initialization script
const initializeQueueCounters = async () => {
  try {
    const clinics = await Clinic.find({});
    for (const clinic of clinics) {
      if (!await redisClient.exists(`clinic:${clinic._id}:current`)) {
        await redisClient.set(`clinic:${clinic._id}:current`, 0);
        await redisClient.set(`clinic:${clinic._id}:lastIssued`, 0);
      }
    }

    const doctors = await Doctor.find({});
    for (const doctor of doctors) {
      if (!await redisClient.exists(`doctor:${doctor._id}:current`)) {
        await redisClient.set(`doctor:${doctor._id}:current`, 0);
        await redisClient.set(`doctor:${doctor._id}:lastIssued`, 0);
      }
    }
  } catch (err) {
    console.error('Error initializing queue counters:', err);
  }
};

// Call this function when your server starts

// add urlencoded parser so Pusher auth (application/x-www-form-urlencoded) is parsed
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

mongoose.connect(process.env.MONGO_URL)
.then(() => {
  console.log("Database connected");
})
.catch(err => console.log(err));

initializeQueueCounters();
app.use('/api', mainRouter);
app.use('/pusher', pusherAuth);
const PORT = 3000;
server.listen(PORT, () => {
  log(`Server running on http://localhost:${PORT}`);
  log(`Socket.IO connected to the same server`);
});