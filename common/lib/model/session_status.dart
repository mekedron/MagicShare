/// Status of one file transfer.
/// Both receiver and sender should share the same information.
enum SessionStatus {
  waiting, // wait for receiver response (wait for decline / accept)
  // MagicShare wait-for-online (cloud-only target). Status flips from
  // waitingForDevice → waiting (handshake) once the target appears on
  // LAN with an HTTP endpoint, or → waitingForDeviceTimedOut if it
  // never came online within the deadline. The Retry action resets
  // the deadline and refires the FCM notification; Cancel terminates.
  waitingForDevice,
  waitingForDeviceTimedOut,
  recipientBusy, // recipient is busy with another request (end of session)
  declined, // receiver declined the request (end of session)
  tooManyAttempts, // receiver declined the request (end of session)
  sending, // files are being sent
  finished, // all files sent (end of session)
  finishedWithErrors, // finished but some files could not be sent (end of session)
  canceledBySender, // cancellation by sender  (end of session)
  canceledByReceiver, // cancellation by receiver (end of session)
}
