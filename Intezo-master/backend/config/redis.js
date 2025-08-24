import { createClient } from 'redis';
// Remove the immediate connection and make it lazy
const redisClient = createClient({
  url: process.env.REDIS_URL
});

redisClient.on('error', (err) => {
  console.error('Redis Client Error', err);
});

// Don't connect immediately, let the app handle connection
// await redisClient.connect(); // Remove this line

export default redisClient;