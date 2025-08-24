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

// add urlencoded parser so Pusher auth (application/x-www-form-urlencoded) is parsed
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

mongoose.connect(process.env.MONGO_URL)
  .then(() => {
    console.log("Database connected");
  })
  .catch(err => console.log(err));

app.use('/api', mainRouter);
app.use('/pusher', pusherAuth);
const PORT = 3000;
server.listen(PORT, () => {
  log(`Server running on http://localhost:${PORT}`);
  log(`Socket.IO connected to the same server`);
});