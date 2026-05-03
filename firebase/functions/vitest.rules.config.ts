import { defineConfig } from 'vitest/config';

// Vitest config used only by `npm run test:rules`. The rules suite lives
// under `test/` and needs the Firestore emulator running, so we keep it
// separate from the default config that drives `npm test`.
export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    testTimeout: 15_000,
  },
});
