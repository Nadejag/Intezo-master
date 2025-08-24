import Pusher from 'pusher';
import 'dotenv/config';

const appId = process.env.PUSHER_APP_ID;
const key = process.env.PUSHER_KEY;
const secret = process.env.PUSHER_SECRET;
const cluster = process.env.PUSHER_CLUSTER;

if (!appId || !key || !secret || !cluster) {
  console.error('PUSHER env missing:', {
    PUSHER_APP_ID: !!appId,
    PUSHER_KEY: !!key,
    PUSHER_SECRET: !!secret,
    PUSHER_CLUSTER: !!cluster
  });
  throw new Error('Pusher config error: missing PUSHER_APP_ID/PUSHER_KEY/PUSHER_SECRET/PUSHER_CLUSTER');
}

const pusher = new Pusher({
  appId: String(appId),
  key: String(key),
  secret: String(secret),
  cluster: String(cluster),
  useTLS: true
});

export default pusher;