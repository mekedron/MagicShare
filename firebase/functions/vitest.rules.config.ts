import { defineConfig } from 'vitest/config';

// Vitest config used only by `npm run test:rules`. The rules suite lives
// under `test/` and needs the Firestore emulator running, so we keep it
// separate from the default config that drives `npm test` and from the
// callable suites picked up by `vitest.functions.config.ts`.
export default defineConfig({
  test: {
    include: ['test/*.rules.test.ts'],
    testTimeout: 15_000,
  },
});
