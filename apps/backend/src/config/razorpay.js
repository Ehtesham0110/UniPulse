import Razorpay from 'razorpay';
import { env } from './env.js';

let client;

/**
 * Lazily initializes the Razorpay SDK client using API credentials from
 * environment variables. Throws a clear error if the credentials are
 * missing instead of failing with an opaque SDK error.
 */
export function getRazorpayClient() {
  if (client) return client;

  if (!env.razorpayKeyId || !env.razorpayKeySecret) {
    throw new Error(
      'Razorpay credentials are not configured. Set RAZORPAY_KEY_ID and ' +
        'RAZORPAY_KEY_SECRET in your .env file.'
    );
  }

  client = new Razorpay({ key_id: env.razorpayKeyId, key_secret: env.razorpayKeySecret });
  return client;
}
