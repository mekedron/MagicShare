import { defineConfig } from 'vitest/config';

// `npm test` only picks up unit tests under `src/`. The Firestore rules
// suite under `test/` needs the Firestore emulator running and is
// invoked separately via `npm run test:rules`, which wraps vitest with
// `firebase emulators:exec` and points it at the rules test file
// explicitly.
export default defineConfig({
  test: {
    include: ['src/**/*.test.ts'],
  },
});
