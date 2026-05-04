import { getApps, initializeApp } from 'firebase-admin/app';
import { Auth, getAuth as getAdminAuth } from 'firebase-admin/auth';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { getMessaging as getAdminMessaging, type Messaging } from 'firebase-admin/messaging';

let cachedDb: Firestore | undefined;
let cachedMessaging: Messaging | undefined;
let cachedAuth: Auth | undefined;

function ensureApp(): void {
  if (getApps().length === 0) {
    initializeApp();
  }
}

/**
 * Returns the singleton admin Firestore client. Lazily initializes the
 * default Firebase Admin app on first call so unit tests, the emulator
 * runtime, and the deployed Cloud Functions runtime all share one
 * instance and one connection pool.
 *
 * When `FIRESTORE_EMULATOR_HOST` is set (by `firebase emulators:exec`
 * or the local dev script), the admin SDK auto-routes to the emulator
 * instead of production.
 */
export function getDb(): Firestore {
  if (!cachedDb) {
    ensureApp();
    cachedDb = getFirestore();
  }
  return cachedDb;
}

/**
 * Returns the singleton admin Messaging client used by `sendWake` and
 * `sendLinkNotification` to publish FCM messages. Tests inject a stub
 * conforming to `MessagingSender` directly into the `*Logic` functions
 * instead of going through this getter, so the production code path
 * never reaches FCM in the emulator.
 */
export function getMessaging(): Messaging {
  if (!cachedMessaging) {
    ensureApp();
    cachedMessaging = getAdminMessaging();
  }
  return cachedMessaging;
}

/**
 * Returns the singleton admin Auth client used by `joinNetwork` to mint
 * a Firebase custom token for the target account so the joining device
 * can re-auth post-pair. Tests inject a stub minter directly into
 * `joinNetworkLogic` instead of going through this getter.
 */
export function getAuth(): Auth {
  if (!cachedAuth) {
    ensureApp();
    cachedAuth = getAdminAuth();
  }
  return cachedAuth;
}
