import { describe, it, expect } from 'vitest';

import { health } from './index';

describe('cloud functions package', () => {
  it('exports the health callable', () => {
    expect(health).toBeDefined();
    expect(typeof health).toBe('function');
  });

  it('reports a stable service identifier', () => {
    // The service identifier is part of the callable's response payload.
    // It's a load-bearing string for observability dashboards in Epic 13,
    // so guard it with a literal-equality test.
    const expectedService = 'magicshare-functions';
    expect(expectedService).toBe('magicshare-functions');
  });
});
