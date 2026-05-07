---
sidebar_position: 1
slug: /intro
title: Introduction
---

# MagicShare

MagicShare is a fork of [LocalSend](https://github.com/localsend/localsend).

LocalSend already does the hard part — secure, encrypted, peer-to-peer
file and link transfers across platforms. MagicShare adds **device
groups**: a way to associate the devices you own and notify them, so
you don't have to discover them on the LAN every time.

## The first feature: Device groups

A device group is a set of devices owned by the same user. Joining a
group is anonymous — there is no email, password, or profile. Under the
hood it is a single anonymous [Firebase Authentication](https://firebase.google.com/docs/auth)
account, shared between the devices in the group.

Once a device is in a group it can:

- See the other devices in the same group, with names and icons.
- Send a push notification to any other device in the same group via
  Firebase Cloud Messaging.

That is the entire scope of v1. File and link transfers continue to
work over the LocalSend protocol unchanged.

## How a device joins a group

1. **First device:** opens *Settings → Device group → Create group*.
   The app signs in anonymously, registers the device under that
   account, and persists the credentials.
2. **Second device:** opens *Settings → Device group → Join group* and
   either scans a QR code shown on the first device or types a short
   text code. The app then signs in to the same anonymous account and
   registers itself.

A group can hold any number of devices. Each device can leave the
group, rename itself, change its icon, or send a test push to any
other device. The group "owner" can also delete the group entirely or
remove other devices from it.

## Status

Early work in progress. The fork currently mirrors LocalSend; the
device-groups feature is being implemented from scratch on a clean
slate. Expect breaking changes.

For build instructions and the full project description, see the
[README](https://github.com/mekedron/MagicShare/blob/main/README.md) on
GitHub.
