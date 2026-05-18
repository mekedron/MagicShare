import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/state/send/sending_file.dart';
import 'package:magicshare_app/model/state/server/receive_session_state.dart';

part 'send_session_state.mapper.dart';

@MappableClass()
class SendSessionState with SendSessionStateMappable implements SessionState {
  final String sessionId;
  final String? remoteSessionId; // v2
  final bool background;

  @override
  final SessionStatus status;

  final Device target;
  final Map<String, SendingFile> files; // file id as key

  @override
  final int? startTime;

  @override
  final int? endTime;

  final List<SendingTask>? sendingTasks; // used to cancel tasks
  final String? errorMessage;

  /// MagicShare wait-for-online: stable identity (cert hash, falls back
  /// to signaling token / cloud deviceId) of the device the user
  /// originally tapped. Non-null only while `status` is
  /// [SessionStatus.waitingForDevice] or
  /// [SessionStatus.waitingForDeviceTimedOut] — the send pipeline uses
  /// this to spot the same physical device reappearing on LAN with a
  /// usable HTTP endpoint and resume the transfer.
  final String? stableTargetId;

  /// Epoch-ms deadline for the current wait window. Cleared once the
  /// session leaves the waiting branch. The popup renders a countdown
  /// against this.
  final int? waitDeadlineMs;

  const SendSessionState({
    required this.sessionId,
    required this.remoteSessionId,
    required this.background,
    required this.status,
    required this.target,
    required this.files,
    required this.startTime,
    required this.endTime,
    required this.sendingTasks,
    required this.errorMessage,
    this.stableTargetId,
    this.waitDeadlineMs,
  });

  /// Custom toString() to avoid printing the bytes.
  /// The default toString() does not respect the overridden toString() of
  /// SendingFile.
  @override
  String toString() {
    return 'SendSessionState(sessionId: $sessionId, remoteSessionId: $remoteSessionId, '
        'background: $background, status: $status, target: $target, files: $files, '
        'startTime: $startTime, endTime: $endTime, sendingTasks: $sendingTasks, '
        'errorMessage: $errorMessage, stableTargetId: $stableTargetId, '
        'waitDeadlineMs: $waitDeadlineMs)';
  }
}

class SendingTask {
  final int isolateIndex;
  final int taskId;

  SendingTask({
    required this.isolateIndex,
    required this.taskId,
  });
}
