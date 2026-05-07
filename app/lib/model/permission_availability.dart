/// User-facing availability of an OS-gated permission.
///
/// The Settings → Permissions section maps each value to a row state:
/// - [granted] / [unsupported]: no action needed
/// - [denied]: surface a "Grant" button (will trigger the OS prompt)
/// - [permanentlyDenied] / [restricted]: surface "Open Settings" (the OS
///   will not re-prompt; only path forward is the system Settings app)
/// - [unknown]: section is still loading the initial status
enum PermissionAvailability {
  unknown,
  unsupported,
  granted,
  denied,
  permanentlyDenied,
  restricted;

  bool get isGranted => this == PermissionAvailability.granted;
  bool get canRequest => this == PermissionAvailability.denied || this == PermissionAvailability.unknown;
  bool get needsSettings => this == PermissionAvailability.permanentlyDenied || this == PermissionAvailability.restricted;
}
