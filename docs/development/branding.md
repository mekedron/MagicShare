# Branding

**Status:** Adopted
**Owner:** Product (Nikita)
**Last updated:** 2026-05-03

> Reference spec: [`cloud-sync-spec.md`](./cloud-sync-spec.md). Operating
> prompt: [`ai-agent.md`](./ai-agent.md). Work tracker:
> [`task-list.md`](./task-list.md).

This document fixes the canonical names and identifiers used throughout
the codebase. Anything user-visible or wire-visible to other MagicShare
peers uses these values. Anything that talks to the upstream LocalSend
project, the wire protocol, or interop ("compatible with LocalSend")
keeps the LocalSend name — see *Where LocalSend stays* below.

---

## Canonical identifiers

| Property                         | Value                                |
|----------------------------------|--------------------------------------|
| Display name                     | `MagicShare`                         |
| Dart package (root app)          | `magicshare_app`                     |
| Reverse-DNS application id       | `com.magicshare.app`                 |
| Android `applicationId`          | `com.magicshare.app`                 |
| Android Kotlin package           | `com.magicshare.app`                 |
| iOS bundle identifier            | `com.magicshare.app`                 |
| macOS bundle identifier          | `com.magicshare.app`                 |
| Windows MSIX `Identity Name`     | `com.magicshare.app`                 |
| Linux package name               | `magicshare`                         |
| `.desktop` file `Name=`          | `MagicShare`                         |
| Project marketing URL            | `https://github.com/mekedron/MagicShare` |
| Upstream attribution URL         | `https://localsend.org`              |

The Dart package for the shared library at `common/` keeps its existing
package name (`common`) — it is internal and not user-visible.

---

## Naming conventions

- **Class identifiers added on top of upstream UI** (top-level App,
  About card, group section, cloud providers): `MagicShare…` prefix
  where a name is needed (e.g. `MagicShareApp`).
- **Internal LocalSend identifiers used by upstream code** (protocol
  classes, device-info models, fingerprint constants, server names):
  unchanged. Renaming them would create needless churn against
  upstream and break interop expectations.
- **Localization keys**: existing keys keep their names (e.g.
  `appName`, `localSendIosShareToServer`) so upstream-derived strings
  stay diff-friendly. Only the *string values* change where the
  string is a brand mention.

---

## Where LocalSend stays

These references must remain `LocalSend` (or `localsend`):

- `LICENSE` and source-header copyright comments (legal attribution).
- `README.md` credits, the *fork of LocalSend* paragraph, the
  *Relationship to LocalSend* section.
- `docs-site/` landing copy and the LocalSend fork acknowledgement.
- Protocol-level mentions in code comments, on-the-wire JSON keys,
  and constant strings exchanged with stock LocalSend clients (e.g.
  `localsend.org` URLs in mDNS / API descriptors, the protocol
  fingerprint salts).
- Localized strings that say *"compatible with LocalSend"* or
  similar interop messaging.
- Submodule paths and external references to the upstream
  repository.

If you are unsure, ask: does this string mean "this product is
called X" (rebrand) or "this product talks to / is forked from
LocalSend" (keep)? When in doubt, keep.

---

## Pre-rebrand legacy values

Recorded for archaeology only — do not reintroduce.

| Property                   | Old value                            |
|----------------------------|--------------------------------------|
| Dart package (root app)    | `localsend_app`                      |
| Android `applicationId`    | `org.localsend.localsend_app`        |
| iOS bundle identifier      | `org.localsend.localsendApp`         |
| macOS bundle identifier    | `org.localsend.localsendApp`         |
| Linux package name         | `localsend`                          |
