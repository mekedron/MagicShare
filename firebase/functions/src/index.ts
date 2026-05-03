import { onCall } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import { instrument } from './logging';

setGlobalOptions({
  region: 'europe-west1',
  maxInstances: 10,
});

/**
 * Health probe. Used to verify the Cloud Functions deployment is reachable
 * and the emulator wires up correctly. Real callables (account, device,
 * pairing, sendWake, etc.) land in Epics 4 through 6.
 */
export const health = onCall(
  instrument('health', async () => {
    return {
      ok: true,
      service: 'magicshare-functions',
      version: '0.0.1',
    };
  }),
);

export { createAccount, deleteAccount } from './accounts';
export {
  registerDevice,
  removeDevice,
  renameDevice,
  setDeviceIcon,
  updateDevicePresence,
} from './devices';
export { sendWake } from './notifications';
export { createJoinToken, joinNetwork, previewJoinToken } from './pairing';
