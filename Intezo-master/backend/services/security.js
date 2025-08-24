import jwt from 'jsonwebtoken';
import User from '../models/User.js';

/**
 * Generate JWT token (Pakistan timezone aware)
 */
export const generateToken = (userId, role) => {
  return jwt.sign(
    { 
      userId, 
      role,
      iat: Math.floor(Date.now() / 1000) - 300 // 5 mins clock skew for PK
    },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
};

/**
 * Rate limiter for OTP requests (Prevent SMS bombing)
 */
export const checkRateLimit = async (ip, phone) => {
  const key = `rate_limit:${ip}:${phone}`;
  const attempts = await redisClient.get(key) || 0;
  
  if (attempts >= 3) {
    throw new Error('Too many OTP requests');
  }

  await redisClient.set(key, attempts + 1, 'EX', 3600); // 1 hour expiry
};