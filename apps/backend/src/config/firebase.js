import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { env } from './env.js';

let app;

/**
 * Lazily initializes the Firebase Admin SDK using service-account
 * credentials from environment variables. Throws a clear error if the
 * credentials are missing instead of failing with an opaque Firebase error.
 *
 * Uses the modular firebase-admin API (v9+/v14 style: `firebase-admin/app`,
 * `firebase-admin/auth`) rather than the legacy `admin.credential.cert(...)`
 * namespaced API, which no longer exists on the default export in v14.
 */
export function getFirebaseApp() {
  if (app) return app;
  if (getApps().length > 0) {
    app = getApps()[0];
    return app;
  }

  if (!env.firebaseProjectId || !env.firebaseClientEmail || !env.firebasePrivateKey) {
    throw new Error(
      'Firebase Admin credentials are not configured. Set FIREBASE_PROJECT_ID, ' +
        'FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY in your .env file.'
    );
  }

  app = initializeApp({
    credential: cert({
      projectId: env.firebaseProjectId,
      clientEmail: env.firebaseClientEmail,
      privateKey: env.firebasePrivateKey,
    }),
  });

  return app;
}

/**
 * Verifies a Firebase ID token sent by the Flutter client after a
 * successful phone-number OTP sign-in. Returns the decoded token, which
 * includes the verified `phone_number` claim. This is the ONLY source of
 * truth for "who is this user" during login — we never trust a
 * client-supplied phone number directly.
 */
export async function verifyFirebaseIdToken(idToken) {
  const firebaseApp = getFirebaseApp();
  return getAuth(firebaseApp).verifyIdToken(idToken);
}
