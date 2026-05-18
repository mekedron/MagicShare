import { onCall } from 'firebase-functions/v2/https';
import { setGlobalOptions } from 'firebase-functions/v2/options';

import { instrument } from './logging';

setGlobalOptions({
  region: 'europe-west1',
  maxInstances: 10,
});

/**
 * Health probe. Used to verify the Cloud Functions deployment is reachable
 * and the emulator wires up correctly.
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
export { registerDevice, removeDevice, renameDevice, setDeviceIcon } from './devices';
export { notifyTransferIntent } from './transfer-notify';
export { createJoinToken, joinNetwork, previewJoinToken } from './pairing';
export { cleanupExpiredJoinTokens, cleanupInactiveAccounts } from './scheduled';
