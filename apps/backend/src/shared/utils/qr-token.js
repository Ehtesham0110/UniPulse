import crypto from 'node:crypto';
import { env } from '../../config/env.js';

/**
 * QR tokens are deterministic (HMAC-signed registrationId) rather than
 * random, so the server can regenerate the exact same token for a
 * registration on demand — e.g. to redisplay it in "My Events" — without
 * ever needing to persist the raw token itself. Only its SHA-256 hash is
 * stored on the Registration document (`qrTokenHash`), consistent with
 * how it was already being stored before this milestone; only how the
 * raw token is generated has changed (previously: `crypto.randomBytes`,
 * which could never be regenerated once issued — that made it impossible
 * to display a registration's QR again later, which this milestone
 * requires).
 */
export function buildQrToken(registrationId) {
  const id = registrationId.toString();
  const signature = crypto.createHmac('sha256', env.qrSigningSecret).update(id).digest('hex');
  const token = `${id}.${signature}`;
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  return { token, tokenHash };
}

/**
 * Extracts and verifies the registrationId embedded in a scanned QR
 * token. Returns the registrationId string if the signature is valid,
 * or null if the token is malformed or tampered with.
 */
export function extractRegistrationId(scannedToken) {
  if (!scannedToken || typeof scannedToken !== 'string') return null;
  const separatorIndex = scannedToken.lastIndexOf('.');
  if (separatorIndex === -1) return null;

  const registrationId = scannedToken.slice(0, separatorIndex);
  const signature = scannedToken.slice(separatorIndex + 1);
  if (!registrationId || !signature) return null;

  const expectedSignature = crypto
    .createHmac('sha256', env.qrSigningSecret)
    .update(registrationId)
    .digest('hex');

  const expectedBuffer = Buffer.from(expectedSignature, 'hex');
  const actualBuffer = Buffer.from(signature, 'hex');
  if (expectedBuffer.length !== actualBuffer.length) return null;
  if (!crypto.timingSafeEqual(expectedBuffer, actualBuffer)) return null;

  return registrationId;
}
