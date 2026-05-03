import { defineConfig } from 'vitest/config';

// Vitest config used only by `npm run test:functions`. The callable
// suites under `test/functions/` exercise the Cloud Functions logic
// against the Firestore emulator, so this config is wrapped by
// `firebase emulators:exec` and kept separate from the default
// `npm test` (which runs lightweight unit tests under `src/`).
export default defineConfig({
  test: {
    include: ['test/functions/**/*.test.ts'],
    testTimeout: 15_000,
    pool: 'forks',
    poolOptions: {
      forks: {
        singleFork: true,
      },
    },
  },
});
