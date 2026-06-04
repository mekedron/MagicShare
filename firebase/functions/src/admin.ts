import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { Auth, getAuth as getAdminAuth } from 'firebase-admin/auth';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { getMessaging as getAdminMessaging, type Messaging } from 'firebase-admin/messaging';

import { restMessagingSender } from './fcm-rest-sender';

let cachedDb: Firestore | undefined;
let cachedMessaging: Messaging | undefined;
let cachedAuth: Auth | undefined;

function ensureApp(): void {
  if (getApps().length === 0) {
    // Inside the Functions emulator the Firebase CLI injects a stub
    // credential that hijacks no-arg initializeApp() — Firestore /
    // Auth keep working against the emulator, but
    // getMessaging() uses the REST sender (see fcm-rest-sender.ts)
    // which signs its own JWT from the service account JSON. When
    // GOOGLE_APPLICATION_CREDENTIALS is set we load it explicitly so
    // any code path that does still rely on firebase-admin (e.g. a
    // future feature) sees the real credential. Deployed Cloud
    // Functions never set FUNCTIONS_EMULATOR, so they keep the
    // metadata-server credential.
    const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (process.env.FUNCTIONS_EMULATOR === 'true' && credPath) {
      initializeApp({ credential: cert(credPath) });
    } else {
      initializeApp();
    }
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
 * Returns the messaging sender used by `notifyTransferIntent`.
 *
 * In the Firebase Functions emulator we bypass firebase-admin and POST
 * directly to FCM v1 REST with our own JWT (see fcm-rest-sender.ts) —
 * the emulator runtime intercepts firebase-admin's `messaging().send()`
 * and refuses to talk to real FCM even with a valid service account.
 *
 * In deployed Cloud Functions, firebase-admin authenticates via the
 * metadata-server credential and works as documented.
 */
export function getMessaging(): Pick<Messaging, 'send'> {
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    return restMessagingSender;
  }
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
