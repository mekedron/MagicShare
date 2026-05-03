---
sidebar_position: 1
slug: /intro
title: Introduction
---

# MagicShare

MagicShare is a fork of [LocalSend](https://github.com/localsend/localsend)
that adds **cloud-assisted device wake-up** and a **friction-free UX** on
top of LocalSend's proven peer-to-peer transfer protocol.

LocalSend already solves the hard part: secure, encrypted, cross-platform
transfers without third-party servers. MagicShare keeps all of that and
fixes the workflow problems that show up when you actually use it daily
across many devices — opening the receiving app every single time being
the biggest one.

## What it is for

If you regularly hop between several devices — phones, tablets, laptops on
different operating systems and different accounts — there is no good way
to just *get a thing onto another device*. Email is slow, custom QR
generators are painful, messengers pollute your chat history, and AirDrop
or Quick Share only work inside one ecosystem.

MagicShare is built around two everyday flows:

- **Open a link on another device.** Copy the URL, paste it into
  MagicShare, pick a target device, tap the notification on the other
  side — the link opens in the browser.
- **Drop a file onto another device.** Drag a file onto the MagicShare
  window (or a screen-corner hot zone), pick one or more of your devices,
  and the file is downloaded automatically on the other side.

## How it works

Each device installs MagicShare once and signs in with an **anonymous
Firebase account**. The device registers its identifier and push token
under that account.

When you send something:

1. MagicShare sends a **push notification** containing only encrypted
   metadata — the source device ID, the payload reference, and the target
   device name. No file content goes through the cloud.
2. The receiving device wakes up, decrypts the metadata, and uses the
   LocalSend protocol to pull the payload **directly** from the source
   device.
3. For files: the download starts and the user is prompted when it
   finishes. For links: the URL opens in the default browser.

The cloud is used only as a **wake-up channel and address book**. Payload
content stays peer-to-peer and end-to-end encrypted, exactly like
LocalSend today.

## Status

Early work in progress. The fork currently mirrors LocalSend; cloud-
assisted features are being designed and implemented. Expect breaking
changes.

For build instructions and the full project description, see the
[README](https://github.com/mekedron/MagicShare/blob/main/README.md) on
GitHub.
