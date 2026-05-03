import { logger } from 'firebase-functions';
import { type CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { instrument } from './logging';

function fakeRequest<T>(data: T, uid?: string): CallableRequest<T> {
  return {
    data,
    auth: uid ? { uid, token: {} as never } : undefined,
    rawRequest: {} as never,
    acceptsStreaming: false,
  } as CallableRequest<T>;
}

describe('instrument', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns the handler result on success', async () => {
    const wrapped = instrument('testOp', async () => 42);
    expect(await wrapped(fakeRequest({}, 'uid-1'))).toBe(42);
  });

  it('logs an ok entry with op, callerUid, status, and latencyMs', async () => {
    const info = vi.spyOn(logger, 'info').mockImplementation(() => {});
    const wrapped = instrument('myOp', async () => ({ ok: true }));

    await wrapped(fakeRequest({}, 'uid-2'));

    expect(info).toHaveBeenCalledTimes(1);
    const [tag, fields] = info.mock.calls[0];
    expect(tag).toBe('cloud-fn:ok');
    expect(fields).toMatchObject({
      op: 'myOp',
      callerUid: 'uid-2',
      status: 'ok',
    });
    expect((fields as { latencyMs: number }).latencyMs).toBeGreaterThanOrEqual(0);
  });

  it("falls back to 'anonymous' when the request has no auth", async () => {
    const info = vi.spyOn(logger, 'info').mockImplementation(() => {});
    const wrapped = instrument('myOp', async () => 'ok');

    await wrapped(fakeRequest({}));

    expect(info.mock.calls[0]?.[1]).toMatchObject({ callerUid: 'anonymous' });
  });

  it('logs a warn entry with the HttpsError code and re-throws on failure', async () => {
    const warn = vi.spyOn(logger, 'warn').mockImplementation(() => {});
    const info = vi.spyOn(logger, 'info').mockImplementation(() => {});
    const boom = new HttpsError('permission-denied', 'nope');
    const wrapped = instrument('blowup', async () => {
      throw boom;
    });

    await expect(wrapped(fakeRequest({}, 'uid-3'))).rejects.toBe(boom);
    expect(warn).toHaveBeenCalledTimes(1);
    expect(info).not.toHaveBeenCalled();
    expect(warn.mock.calls[0]?.[1]).toMatchObject({
      op: 'blowup',
      callerUid: 'uid-3',
      status: 'error',
      errorCode: 'permission-denied',
    });
  });

  it("classifies non-HttpsError throws as 'internal' and re-throws", async () => {
    const warn = vi.spyOn(logger, 'warn').mockImplementation(() => {});
    const wrapped = instrument('crash', async () => {
      throw new Error('boom');
    });

    await expect(wrapped(fakeRequest({}, 'uid-4'))).rejects.toThrow('boom');
    expect(warn.mock.calls[0]?.[1]).toMatchObject({
      op: 'crash',
      callerUid: 'uid-4',
      status: 'error',
      errorCode: 'internal',
    });
  });
});
