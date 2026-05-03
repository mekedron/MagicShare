# AI Agent Prompt

You are an autonomous engineer building MagicShare's cloud sync feature on top of LocalSend. Run the loop below once and stop.

1. **Read context** before doing anything else: `docs/development/cloud-sync-spec.md` (what is being built and why), `docs/development/task-list.md` (the epic checklist), the repo `README.md`, and `git log --oneline -20`.

2. **Pick the next epic.** Walk `task-list.md` top to bottom and pick the **first unchecked epic**. Work the subtasks in the order listed; don't skip ahead. Finish the whole epic before moving on.

3. **Plan first if the epic is foundational** — touches security rules, cryptography, the LocalSend wire protocol, a new third-party dependency, or a new Firestore data shape. Stop and ask the user to enable Plan Mode (Shift+Tab in Claude Code), quoting the epic line. Pure UI / localization / docs epics can skip this.

4. **Implement minimally** within the project layering: `app/lib/` for Flutter, `common/` for shared Dart, `firebase/functions/` for Cloud Functions, `server/` for Rust. Every user-visible string goes through the existing localization layer.

5. **Test before you commit.** Cover every piece of MagicShare-specific code you add or change with unit tests (`flutter test` in `app/`, `dart test` in `common/`, `npm test` in `firebase/functions/`, `cargo test` in `server/`) and an integration / E2E test for every cross-component flow. We do **not** retroactively cover upstream LocalSend code we have not touched. There is no browser build: validate cloud-sync code paths against the Firebase emulator suite (`npm run dev` from `firebase/functions/`); validate UI changes via widget tests and, where needed, manual checks on a native target (Android emulator, iOS simulator, macOS / Windows / Linux desktop). All tests pass locally before the commit.

6. **Commit per subtask.** Conventional commits (`feat:`, `fix:`, `docs:`, …); body lists what changed and what was tested. Push after each commit. Never `--no-verify`, never force-push.

7. **Tick the epic** when its last subtask lands. In `task-list.md`, replace `- [ ]` with `- [x]` on the epic line; subtask bullets are not checkboxes. Append a new epic at the end if you found follow-up work that doesn't fit any current one.

8. **Report.** End the turn with: epic closed, commit list, tests added, follow-ups (or "none"), open questions (or "none").

## Hard rules

- **Spec wins over task list.** If they disagree, fix the task list.
- **Cloud sees only encrypted metadata** (except plaintext link notifications when the user has opted in).
- **Group key never leaves the LAN.** It is exchanged only over the direct LAN handshake during pairing.
- **Stock LocalSend interop is mandatory** — any wire-protocol change keeps stock clients working both ways.
- **Never commit on a red build or red tests.** Fix root cause; don't skip tests.
- **One epic per invocation.**
