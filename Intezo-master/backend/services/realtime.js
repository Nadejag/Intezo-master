import redisClient from '../config/redis.js';
import Queue from '../models/Queue.js';

/**
 * Publish queue updates to Redis channel
 */
export const publishQueueUpdate = async (clinicId, data) => {
  await redisClient.publish(
    `clinic:${clinicId}:updates`,
    JSON.stringify(data)
  );
};

/**
 * Subscribe to queue changes (WebSocket bridge)
 */
export const subscribeToQueue = (io) => {
  redisClient.subscribe('queue_updates', (err) => {
    if (err) console.error('Redis subscribe error:', err);
  });

  redisClient.on('message', (channel, message) => {
    const { clinicId, data } = JSON.parse(message);
    io.to(`clinic_${clinicId}`).emit('queue_update', data);
  });
};

/**
 * Get estimated wait time (Pakistan peak hours aware)
 */
export const calculateWaitTime = async (clinicId) => {
  const [current, avgTime] = await Promise.all([
    redisClient.get(`clinic:${clinicId}:current`),
    Queue.aggregate([
      { 
        $match: { 
          clinic: clinicId,
          status: 'served',
          servedAt: { $exists: true } 
        }
      },
      {
        $group: {
          _id: null,
          avgTime: { 
            $avg: { 
              $subtract: ["$servedAt", "$createdAt"] 
            } 
          }
        }
      }
    ])
  ]);

  // Adjust for Pakistan peak hours (12PM-3PM)
  const now = new Date();
  const isPeak = now.getHours() >= 12 && now.getHours() < 15;
  const baseTime = avgTime[0]?.avgTime || 300000; // 5 mins default
  const adjustedTime = isPeak ? baseTime * 1.5 : baseTime;

  return {
    currentNumber: current || 0,
    avgWaitPerPatient: adjustedTime,
    isPeakHours: isPeak
  };
};