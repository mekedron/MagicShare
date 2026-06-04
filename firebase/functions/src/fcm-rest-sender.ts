import { readFileSync } from 'fs';

import { type Message } from 'firebase-admin/messaging';
import { JWT } from 'google-auth-library';

/**
 * REST-based FCM sender used in the Firebase Functions emulator.
 *
 * The Firebase CLI emulator runtime intercepts firebase-admin's
 * `messaging().send()` and refuses to forward the request to real FCM
 * even when GOOGLE_APPLICATION_CREDENTIALS is set with a valid service
 * account. To make notifyTransferIntent actually deliver pushes during
 * local development, we mint our own OAuth token from the service
 * account JSON and POST directly to the FCM v1 REST API, bypassing
 * firebase-admin entirely.
 *
 * In deployed Cloud Functions, GOOGLE_APPLICATION_CREDENTIALS is not
 * set and firebase-admin works correctly with the metadata-server
 * credential — so this sender is only chosen when
 * `FUNCTIONS_EMULATOR=true`.
 */

let cached: { client: JWT; projectId: string } | undefined;

function getJwtClient(): { client: JWT; projectId: string } {
  if (cached) return cached;
  const path = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!path) {
    throw new Error(
      'restMessagingSender: GOOGLE_APPLICATION_CREDENTIALS is not set — ' +
        'the Functions emulator needs a service-account JSON to mint FCM tokens.',
    );
  }
  const sa = JSON.parse(readFileSync(path, 'utf8')) as {
    client_email: string;
    private_key: string;
    project_id: string;
  };
  cached = {
    client: new JWT({
      email: sa.client_email,
      key: sa.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    }),
    projectId: sa.project_id,
  };
  return cached;
}

export const restMessagingSender = {
  async send(msg: Message): Promise<string> {
    const { client, projectId } = getJwtClient();
    const tokenResp = await client.getAccessToken();
    const accessToken = tokenResp.token;
    if (!accessToken) {
      throw new Error('restMessagingSender: failed to mint FCM access token');
    }
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message: msg }),
    });
    if (!resp.ok) {
      const body = await resp.text();
      throw new Error(`FCM REST send failed: HTTP ${resp.status} — ${body}`);
    }
    const data = (await resp.json()) as { name: string };
    return data.name;
  },
};
