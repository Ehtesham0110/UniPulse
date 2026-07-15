import { getFirebaseApp } from './firebase.js';

/**
 * Sends a push notification to a set of FCM device tokens.
 *
 * Production-ready shape: when Firebase Admin is configured, this calls
 * the real `firebase-admin/messaging` multicast API. When it isn't
 * (Development Mode — see apps/mobile's dev_mode.dart for the client-side
 * equivalent), it falls back to a mock provider that logs what *would*
 * have been sent and returns a synthetic success result, so the rest of
 * the notification pipeline (storage, audience resolution, the in-app
 * inbox) can be built and tested without a real Firebase project.
 *
 * Never throws — a push-delivery failure should never block the in-app
 * notification (the `NotificationRecipient` rows) from being created,
 * since that's the primary delivery mechanism this milestone builds; FCM
 * is a best-effort bonus on top of it.
 */
export async function sendPushNotification({ tokens, title, body, data }) {
  const uniqueTokens = [...new Set(tokens ?? [])].filter(Boolean);

  if (uniqueTokens.length === 0) {
    return { attempted: false, mocked: false, successCount: 0, failureCount: 0 };
  }

  let app;
  try {
    app = getFirebaseApp();
  } catch (error) {
    // Firebase Admin isn't configured (Development Mode) — mock provider.
    console.log(
      `[MOCK PUSH] "${title}" -> ${uniqueTokens.length} device(s): ${body}` +
        (data ? ` (data: ${JSON.stringify(data)})` : '')
    );
    return { attempted: true, mocked: true, successCount: uniqueTokens.length, failureCount: 0 };
  }

  try {
    const { getMessaging } = await import('firebase-admin/messaging');
    const response = await getMessaging(app).sendEachForMulticast({
      tokens: uniqueTokens,
      notification: { title, body },
      data: data ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) : undefined,
    });
    return {
      attempted: true,
      mocked: false,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('Push notification send failed:', error.message);
    return {
      attempted: true,
      mocked: false,
      successCount: 0,
      failureCount: uniqueTokens.length,
      error: error.message,
    };
  }
}
