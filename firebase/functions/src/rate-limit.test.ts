import { Timestamp } from 'firebase-admin/firestore';
import { describe, expect, it } from 'vitest';

import { consumeSendQuota, SEND_RATE_LIMIT_PER_HOUR } from './rate-limit';

const now = (ms: number): Timestamp => Timestamp.fromMillis(ms);

describe('consumeSendQuota', () => {
  it('appends `now` to an empty / undefined existing array', () => {
    const t = now(1_000_000);
    expect(consumeSendQuota(undefined, t)).toEqual([t]);
    expect(consumeSendQuota([], t)).toEqual([t]);
  });

  it('drops entries older than the 1-hour window', () => {
    const start = 10_000_000;
    const oneHour = 60 * 60 * 1000;
    const stale = now(start - oneHour - 1);
    const fresh = now(start - 30_000);
    const t = now(start);

    const result = consumeSendQuota([stale, fresh], t);

    expect(result).toEqual([fresh, t]);
  });

  it('keeps entries exactly at the boundary (>cutoff strictly)', () => {
    const start = 10_000_000;
    const oneHour = 60 * 60 * 1000;
    const cutoff = now(start - oneHour);
    const t = now(start);

    // The boundary is strict (`>` cutoff), so a sample exactly at
    // start-1h drops; a sample 1 ms newer survives.
    expect(consumeSendQuota([cutoff], t)).toEqual([t]);
    expect(consumeSendQuota([now(start - oneHour + 1)], t)).toEqual([now(start - oneHour + 1), t]);
  });

  it(`accepts up to ${SEND_RATE_LIMIT_PER_HOUR} sends in the window`, () => {
    const start = 10_000_000;
    // 29 fresh entries — adding now() should land us at exactly 30.
    const fresh = Array.from({ length: SEND_RATE_LIMIT_PER_HOUR - 1 }, (_, i) =>
      now(start - 60_000 - i),
    );
    const result = consumeSendQuota(fresh, now(start));
    expect(result).toHaveLength(SEND_RATE_LIMIT_PER_HOUR);
  });

  it(`rejects the (${SEND_RATE_LIMIT_PER_HOUR}+1)th send within the window`, () => {
    const start = 10_000_000;
    const fresh = Array.from({ length: SEND_RATE_LIMIT_PER_HOUR }, (_, i) =>
      now(start - 60_000 - i),
    );

    expect(() => consumeSendQuota(fresh, now(start))).toThrowError(/Send rate limit exceeded/);
    try {
      consumeSendQuota(fresh, now(start));
    } catch (error) {
      expect(error).toMatchObject({ code: 'resource-exhausted' });
    }
  });

  it('lets the caller back in once the oldest entry slides out of the window', () => {
    const start = 10_000_000;
    const oneHour = 60 * 60 * 1000;
    // A full window of 30 entries clustered at start-30..start-1 ms.
    const full = Array.from({ length: SEND_RATE_LIMIT_PER_HOUR }, (_, i) =>
      now(start - SEND_RATE_LIMIT_PER_HOUR + i),
    );
    // Now slide forward by an hour + 1 — every old entry falls off.
    const later = now(start + oneHour + 1);
    const result = consumeSendQuota(full, later);
    expect(result).toEqual([later]);
  });
});
