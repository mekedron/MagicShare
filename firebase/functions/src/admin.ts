import { getApps, initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore } from 'firebase-admin/firestore';

let cachedDb: Firestore | undefined;

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
    if (getApps().length === 0) {
      initializeApp();
    }
    cachedDb = getFirestore();
  }
  return cachedDb;
}
