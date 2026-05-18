import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/file_status.dart';
import 'package:common/model/file_type.dart';
import 'package:common/model/session_status.dart';
import 'package:common/util/sleep.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cross_file.dart';
import 'package:magicshare_app/model/send_mode.dart';
import 'package:magicshare_app/model/state/send/send_session_state.dart';
import 'package:magicshare_app/model/state/send/sending_file.dart';
import 'package:magicshare_app/pages/home_page.dart';
import 'package:magicshare_app/pages/progress_page.dart';
import 'package:magicshare_app/pages/send_page.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/merged_network_devices_provider.dart';
import 'package:magicshare_app/provider/device_info_provider.dart';
import 'package:magicshare_app/provider/http_provider.dart';
import 'package:magicshare_app/provider/progress_provider.dart';
import 'package:magicshare_app/provider/selection/selected_sending_files_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:magicshare_app/rust/api/http.dart' as rust_http;
import 'package:magicshare_app/rust/api/model.dart' as rust_model;
import 'package:magicshare_app/util/rust.dart';
import 'package:magicshare_app/widget/dialogs/pin_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:rhttp/rhttp.dart';
import 'package:routerino/routerino.dart';
import 'package:uri_content/uri_content.dart';
import 'package:uuid/uuid.dart';

/// Sender-side timeout for the wait-for-online popup. Matches the
/// notification body's "Tap to open" hint window — after 60 s the popup
/// flips into [SessionStatus.waitingForDeviceTimedOut], showing a Retry
/// button that restarts the timer and re-fires the FCM notification.
const Duration kWaitForOnlineTimeout = Duration(seconds: 60);

const _uuid = Uuid();
final _logger = Logger('Send');

/// This provider manages sending files to other devices.
///
/// In contrast to [serverProvider], this provider does not manage a server.
/// Instead, it only does HTTP requests to other servers.
final sendProvider = NotifierProvider<SendNotifier, Map<String, SendSessionState>>((ref) {
  return SendNotifier();
});

class SendNotifier extends Notifier<Map<String, SendSessionState>> {
  SendNotifier();

  /// In-flight wait-for-online subscriptions keyed by sessionId.
  final Map<String, _PendingWait> _pendingWaits = {};

  @override
  Map<String, SendSessionState> init() {
    return {};
  }

  /// Starts a send session.
  ///
  /// Behaviour depends on whether [target] is reachable on LAN right now:
  ///
  /// - **LAN-reachable** ([Device.hasHttpEndpoint] is true): the upload
  ///   pipeline runs immediately.
  /// - **Cloud-only** ([target] is a synthesized device with no HTTP
  ///   endpoint — the user tapped a group device that's offline):
  ///   creates the session in [SessionStatus.waitingForDevice], opens
  ///   the SendPage immediately (regardless of [background]), fires
  ///   `notifyTransferIntent` to wake the receiver, and subscribes to
  ///   the merged-devices stream. When a LAN entry with the same
  ///   [stableTargetId] appears with an HTTP endpoint, the pipeline
  ///   resumes. The session times out into
  ///   [SessionStatus.waitingForDeviceTimedOut] after
  ///   [kWaitForOnlineTimeout] if the receiver never comes online.
  ///
  /// If [background] is true the session closes itself on success and no
  /// pages are opened. If [background] is false this method opens pages
  /// and waits for user input.
  Future<void> startSession({
    required Device target,
    required List<CrossFile> files,
    required bool background,
    String? stableTargetId,
  }) async {
    final sessionId = _uuid.v4();
    final filesMap = await _materializeFiles(files);
    final initialStatus = target.hasHttpEndpoint ? SessionStatus.waiting : SessionStatus.waitingForDevice;
    final initialDeadline = initialStatus == SessionStatus.waitingForDevice ? DateTime.now().add(kWaitForOnlineTimeout).millisecondsSinceEpoch : null;
    final sessionState = SendSessionState(
      sessionId: sessionId,
      remoteSessionId: null,
      background: background,
      status: initialStatus,
      target: target,
      files: filesMap,
      startTime: null,
      endTime: null,
      sendingTasks: [],
      errorMessage: null,
      stableTargetId: stableTargetId,
      waitDeadlineMs: initialDeadline,
    );
    state = state.updateSession(
      sessionId: sessionId,
      state: (_) => sessionState,
    );

    // Always push the popup immediately when not in background mode —
    // this is the user-visible "feedback that the tap was received"
    // regardless of whether the target is online or offline.
    if (!background) {
      // ignore: use_build_context_synchronously, unawaited_futures
      Routerino.context.push(
        () => SendPage(showAppBar: false, closeSessionOnClose: true, sessionId: sessionId),
        transition: RouterinoTransition.fade(),
      );
    }

    // Fire the transfer-intent push for every send to a cloud-known
    // device, regardless of online state. Spec: "every time when a
    // person initiates a file sending on a device which has a group
    // badge, you always send the web push notification." For online
    // targets the LAN Accept dialog still appears moments later —
    // these run in parallel; the visible notification is the
    // user-facing signal that a transfer is starting.
    if (stableTargetId != null && stableTargetId.isNotEmpty) {
      unawaited(_fireTransferNotification(sessionId));
    }

    if (target.hasHttpEndpoint) {
      await _runUploadPipeline(sessionId);
      return;
    }

    if (stableTargetId == null || stableTargetId.isEmpty) {
      _logger.warning(
        'startSession: cloud-only target has no stable id '
        '(alias=${target.alias}) — cannot wait for online',
      );
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          status: SessionStatus.finishedWithErrors,
          errorMessage: 'Cannot reach ${target.alias}: missing device fingerprint.',
        ),
      );
      return;
    }

    _startWaitForOnline(sessionId);
  }

  /// Refires the FCM notification and restarts the wait timer for a
  /// session currently in [SessionStatus.waitingForDeviceTimedOut].
  /// Idempotent / safe to call from the Retry button.
  void retryWaitingSession(String sessionId) {
    final s = state[sessionId];
    if (s == null) return;
    if (s.status != SessionStatus.waitingForDeviceTimedOut && s.status != SessionStatus.waitingForDevice) {
      return;
    }
    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(
        status: SessionStatus.waitingForDevice,
        waitDeadlineMs: DateTime.now().add(kWaitForOnlineTimeout).millisecondsSinceEpoch,
        errorMessage: null,
      ),
    );
    unawaited(_fireTransferNotification(sessionId));
    _startWaitForOnline(sessionId);
  }

  /// Cancels a session that is in the waiting-for-online phase. Wires
  /// into the same teardown path the normal Cancel button uses.
  void cancelWaitingSession(String sessionId) {
    _stopWait(sessionId);
    cancelSession(sessionId);
  }

  Future<Map<String, SendingFile>> _materializeFiles(List<CrossFile> files) async {
    return Map.fromEntries(
      await Future.wait(
        files.map((file) async {
          final id = _uuid.v4();
          return MapEntry(
            id,
            SendingFile(
              file: FileDto(
                id: id,
                fileName: file.name,
                size: file.size,
                fileType: file.fileType,
                hash: null,
                preview: files.length == 1 && files.first.fileType == FileType.text && files.first.bytes != null
                    ? utf8.decode(files.first.bytes!) // send simple message by embedding it into the preview
                    : null,
                metadata: file.lastModified != null || file.lastAccessed != null
                    ? FileMetadata(
                        lastModified: file.lastModified,
                        lastAccessed: file.lastAccessed,
                      )
                    : null,
              ),
              status: FileStatus.queue,
              token: null,
              thumbnail: file.thumbnail,
              asset: file.asset,
              path: file.path,
              bytes: file.bytes,
              errorMessage: null,
            ),
          );
        }),
      ),
    );
  }

  void _startWaitForOnline(String sessionId) {
    _stopWait(sessionId);

    final stableId = state[sessionId]?.stableTargetId;
    if (stableId == null) {
      _logger.warning('_startWaitForOnline: session $sessionId lost its stableTargetId');
      return;
    }

    final subscription = ref
        .stream(mergedNetworkDevicesProvider)
        .listen(
          (event) {
            _onMergedDevicesUpdate(sessionId, event.next);
          },
          onError: (Object error, StackTrace st) {
            _logger.warning('mergedNetworkDevicesProvider stream errored', error, st);
          },
        );
    final timer = Timer(kWaitForOnlineTimeout, () => _onWaitTimeout(sessionId));
    _pendingWaits[sessionId] = _PendingWait(subscription: subscription, timeoutTimer: timer);

    // Also check the current snapshot immediately — the target may
    // already be reachable from a prior multicast sweep that happened
    // before we even called startSession.
    final current = ref.read(mergedNetworkDevicesProvider);
    _onMergedDevicesUpdate(sessionId, current);
  }

  Future<void> _fireTransferNotification(String sessionId) async {
    final session = state[sessionId];
    if (session == null) {
      _logger.info('Skipping notifyTransferIntent: session $sessionId disappeared');
      return;
    }
    final account = ref.read(accountRepositoryProvider);
    if (account is! AccountReady) {
      _logger.info(
        'Skipping notifyTransferIntent for session $sessionId: '
        'cloud account is ${account.runtimeType} (need AccountReady)',
      );
      return;
    }
    final stableId = session.stableTargetId;
    if (stableId == null) {
      _logger.info(
        'Skipping notifyTransferIntent for session $sessionId: '
        'session has no stableTargetId (target is a non-group LAN peer)',
      );
      return;
    }
    // The stableTargetId is the cloud deviceId (set in send_tab_vm
    // from `merged.cloud!.deviceId`). Confirm the device still lives
    // in the user's cloud row list before firing the push.
    final merged = ref.read(mergedNetworkDevicesProvider);
    final entry = merged.firstWhereOrNull((d) => d.cloud?.deviceId == stableId);
    final targetDeviceId = entry?.cloud?.deviceId;
    if (targetDeviceId == null) {
      _logger.info(
        'Skipping notifyTransferIntent for session $sessionId: '
        'target with cloud deviceId=$stableId is no longer in the cloud '
        'device list (currently visible cloud ids: '
        '${merged.map((d) => d.cloud?.deviceId).whereType<String>().toList()})',
      );
      return;
    }
    final kind = _transferKindFor(session);
    _logger.info(
      'notifyTransferIntent → calling cloud function '
      '(source=${account.currentDeviceId}, target=$targetDeviceId, kind=${kind.wireName})',
    );
    try {
      final result = await ref
          .read(cloudFunctionsClientProvider)
          .notifyTransferIntent(
            sourceDeviceId: account.currentDeviceId,
            targetDeviceId: targetDeviceId,
            kind: kind,
          );
      _logger.info(
        'notifyTransferIntent ← ${result.channel.name} (delivered=${result.delivered}) '
        'for session $sessionId',
      );
    } on CloudException catch (e, st) {
      // Soft failure — the wait subscription is still in place and the
      // target may still come online via LAN.
      _logger.warning(
        'notifyTransferIntent FAILED: code=${e.code.name} message="${e.message}" details=${e.details}',
        e,
        st,
      );
    } catch (e, st) {
      _logger.warning('notifyTransferIntent threw unexpected error', e, st);
    }
  }

  NotifyTransferKind _transferKindFor(SendSessionState session) {
    final files = session.files.values.toList();
    if (files.isEmpty) return NotifyTransferKind.file;
    if (files.length > 1) return NotifyTransferKind.file;
    final type = files.single.file.fileType;
    return switch (type) {
      FileType.text => NotifyTransferKind.text,
      // A "URL" payload is sent as a text-mode file whose preview is the
      // URL — the receiver's auto-open in receive_controller covers
      // that. From the receiver's notification copy perspective it is a
      // link, so report it as such.
      FileType.image || FileType.video || FileType.pdf || FileType.apk || FileType.other => NotifyTransferKind.file,
    };
  }

  void _onMergedDevicesUpdate(String sessionId, List<MergedDevice> merged) {
    final session = state[sessionId];
    if (session == null) {
      _stopWait(sessionId);
      return;
    }
    if (session.status != SessionStatus.waitingForDevice) return;
    final stableId = session.stableTargetId;
    if (stableId == null) return;
    final match = merged.firstWhereOrNull(
      (d) => d.cloud?.deviceId == stableId && d.displayDevice.hasHttpEndpoint,
    );
    if (match == null) return;

    _logger.info(
      'Wait-for-online resolved for session $sessionId — '
      'target now reachable at ${match.displayDevice.firstHttpEndpoint?.ip}',
    );
    _stopWait(sessionId);
    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(
        status: SessionStatus.waiting,
        target: match.displayDevice,
        waitDeadlineMs: null,
      ),
    );
    unawaited(_runUploadPipeline(sessionId));
  }

  void _onWaitTimeout(String sessionId) {
    final session = state[sessionId];
    if (session == null) return;
    if (session.status != SessionStatus.waitingForDevice) return;
    _logger.info('Wait-for-online timed out for session $sessionId');
    final pending = _pendingWaits.remove(sessionId);
    pending?.timeoutTimer.cancel();
    unawaited(pending?.subscription.cancel());
    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(status: SessionStatus.waitingForDeviceTimedOut),
    );
  }

  void _stopWait(String sessionId) {
    final pending = _pendingWaits.remove(sessionId);
    if (pending == null) return;
    pending.timeoutTimer.cancel();
    unawaited(pending.subscription.cancel());
  }

  Future<void> _runUploadPipeline(String sessionId) async {
    final session = state[sessionId];
    if (session == null) {
      _logger.warning('_runUploadPipeline: session $sessionId disappeared');
      return;
    }
    final target = session.target;
    if (!target.hasHttpEndpoint) {
      _logger.warning(
        '_runUploadPipeline: target ${target.alias} unexpectedly has no HTTP endpoint',
      );
      return;
    }
    final client = ref.read(httpProvider).v2;

    final originDevice = ref.read(deviceFullInfoProvider);
    final originEndpoint = originDevice.firstHttpEndpoint;
    if (originEndpoint == null) {
      _logger.warning('_runUploadPipeline: local device has no HttpEndpoint');
      return;
    }
    final requestDto = rust_model.PrepareUploadRequestDto(
      info: rust_model.RegisterDto(
        alias: originDevice.alias,
        version: originDevice.version,
        deviceModel: originDevice.deviceModel,
        deviceType: originDevice.deviceType.toRust(),
        token: originEndpoint.certHash,
        port: originEndpoint.port,
        protocol: originEndpoint.https ? rust_model.ProtocolType.https : rust_model.ProtocolType.http,
        hasWebInterface: originDevice.download,
      ),
      files: {
        for (final entry in session.files.entries) entry.key: entry.value.file.toRust(),
      },
    );

    rust_http.PrepareUploadResult? response;
    bool invalidPin;
    bool pinFirstAttempt = true;
    String? pin;
    final targetEndpoint = target.firstHttpEndpoint!;
    _logger.info(
      'prepareUpload to ${target.alias} '
      '(${targetEndpoint.ip}:${targetEndpoint.port}, '
      'certHash=${targetEndpoint.certHash})',
    );
    do {
      invalidPin = false;
      try {
        response = await client.prepareUpload(
          protocol: target.getProtocolType(),
          ip: targetEndpoint.ip,
          port: targetEndpoint.port,
          payload: requestDto,
          // TODO
          publicKey: null,
          pin: pin,
        );
      } on rust_http.RsHttpClientError_StatusCode catch (e) {
        switch (e.status) {
          case 401:
            invalidPin = true;

            // wait until animation is finished
            await sleepAsync(500);

            pin = await showDialog<String>(
              context: Routerino.context, // ignore: use_build_context_synchronously
              builder: (_) => PinDialog(
                obscureText: true,
                showInvalidPin: !pinFirstAttempt,
              ),
            );

            pinFirstAttempt = false;

            if (pin == null) {
              state = state.updateSession(
                sessionId: sessionId,
                state: (s) => s?.copyWith(
                  status: SessionStatus.canceledBySender,
                ),
              );
              return;
            }
            break;
          case 403:
            state = state.updateSession(
              sessionId: sessionId,
              state: (s) => s?.copyWith(
                status: SessionStatus.declined,
              ),
            );
            return;
          case 409:
            state = state.updateSession(
              sessionId: sessionId,
              state: (s) => s?.copyWith(
                status: SessionStatus.recipientBusy,
              ),
            );
            return;
          case 429:
            state = state.updateSession(
              sessionId: sessionId,
              state: (s) => s?.copyWith(
                status: SessionStatus.tooManyAttempts,
              ),
            );
            return;
          case 412:
            // 412 Self-discovered. The receive-side rejects requests
            // whose sender fingerprint matches its own — i.e. the
            // request looped back to our own server. Common cause on
            // a dev host running an Android emulator: qemu's user-mode
            // NAT translates the emulator's multicast announce so the
            // host sees it arriving from the host's own IP, the merge
            // lists the emulator with that loopback address, and the
            // direct send POSTs to ourselves. The 412 guard caught it,
            // but the raw error text is unhelpful — surface a clearer
            // diagnostic instead.
            _logger.warning(
              'prepareUpload returned 412 Self-discovered to ${targetEndpoint.ip}:${targetEndpoint.port} — '
              "the target tile's IP matches one of our own (likely an "
              'Android-emulator multicast loopback)',
            );
            state = state.updateSession(
              sessionId: sessionId,
              state: (s) => s?.copyWith(
                status: SessionStatus.finishedWithErrors,
                errorMessage:
                    "Can't reach ${target.alias} — its LAN announce loops "
                    'back to this machine. This is a known limitation of '
                    'the Android emulator on the same host as the sender; '
                    'use a real device on the same Wi-Fi for file transfer.',
              ),
            );
            return;
          default:
            state = state.updateSession(
              sessionId: sessionId,
              state: (s) => s?.copyWith(
                status: SessionStatus.finishedWithErrors,
                errorMessage: e.humanErrorMessage,
              ),
            );
            return;
        }
      } catch (e) {
        state = state.updateSession(
          sessionId: sessionId,
          state: (s) => s?.copyWith(
            status: SessionStatus.finishedWithErrors,
            errorMessage: e.humanErrorMessage,
          ),
        );
        return;
      }
    } while (invalidPin);

    if (response == null) {
      return;
    }

    final Map<String, String> fileMap;
    if (response.statusCode == 204) {
      // Nothing selected
      // Interpret this as "Read and close"
      fileMap = {};
    } else {
      try {
        fileMap = response.response!.files;
        // The receiver's sessionId from the prepareUpload response.
        // We threaded it onto every upload URL, but until this fix the
        // variable was named `sessionId` — shadowing the local
        // `sessionId` used as the state-map key, so updateSession
        // indexed by the receiver's id (no entry there) and
        // remoteSessionId stayed null on the local entry. Result: the
        // upload URL was built without `?sessionId=...`, the receiver
        // returned 400 "Missing parameters", and the file never moved.
        final remoteSessionId = response.response!.sessionId;
        state = state.updateSession(
          sessionId: sessionId,
          state: (s) => s?.copyWith(
            remoteSessionId: remoteSessionId,
          ),
        );
      } catch (e) {
        state = state.updateSession(
          sessionId: sessionId,
          state: (s) => s?.copyWith(
            status: SessionStatus.finishedWithErrors,
            errorMessage: e.humanErrorMessage,
          ),
        );
        return;
      }
    }

    if (fileMap.isEmpty) {
      // receiver has nothing selected
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          status: SessionStatus.finished,
        ),
      );

      if (state[sessionId]?.background == false) {
        // ignore: use_build_context_synchronously, unawaited_futures
        Routerino.context.pushRootImmediately(() => const HomePage(initialTab: HomeTab.send, appStart: false));
      }

      closeSession(sessionId);
      return;
    }

    final sendingFiles = {
      for (final file in session.files.values)
        file.file.id: fileMap.containsKey(file.file.id) ? file.copyWith(token: fileMap[file.file.id]) : file.copyWith(status: FileStatus.skipped),
    };

    if (state[sessionId]?.background == false) {
      final background = ref.read(settingsProvider).sendMode == SendMode.multiple;

      // ignore: use_build_context_synchronously, unawaited_futures
      Routerino.context.pushAndRemoveUntil(
        removeUntil: HomePage,
        transition: RouterinoTransition.fade(),
        // immediately is not possible: https://github.com/flutter/flutter/issues/121910
        builder: () => ProgressPage(
          showAppBar: background,
          closeSessionOnClose: !background,
          sessionId: sessionId,
        ),
      );
    }

    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(
        status: SessionStatus.sending,
        files: sendingFiles,
      ),
    );

    await _sendLoop(ref, sessionId, target, sendingFiles);
  }

  Future<void> _sendLoop(Ref ref, String sessionId, Device target, Map<String, SendingFile> files) async {
    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(startTime: DateTime.now().millisecondsSinceEpoch),
    );

    final queue = Queue<SendingFile>()..addAll(files.values);
    final concurrency = ref.read(parentIsolateProvider).uploadIsolateCount;
    _logger.info('Sending files using $concurrency concurrent isolates');

    final futures = List.generate(concurrency, (index) async {
      while (true) {
        final file = switch (queue.isEmpty) {
          true => null,
          false => queue.removeFirst(),
        };

        if (file == null) {
          break;
        }

        await sendFile(
          sessionId: sessionId,
          isolateIndex: index,
          file: file,
          isRetry: false,
        );
      }
    });

    await Future.wait(futures);

    _finish(sessionId: sessionId);
  }

  void _finish({required String sessionId}) {
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return;
    }

    if (state[sessionId]!.status != SessionStatus.sending) {
      _logger.info('Transfer was canceled.');
    } else {
      final hasError = sessionState.files.values.any((file) => file.status == FileStatus.failed);
      if (!hasError && sessionState.background == true) {
        // close session because everything is fine and it is in background
        closeSession(sessionId);
        _logger.info('Transfer finished and session removed.');
      } else {
        // keep session alive when there are errors or currently in foreground
        state = state.updateSession(
          sessionId: sessionId,
          state: (s) => s?.copyWith(
            status: hasError ? SessionStatus.finishedWithErrors : SessionStatus.finished,
            endTime: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        if (hasError) {
          _logger.info('Transfer finished with errors.');
        } else {
          _logger.info('Transfer finished successfully.');
        }
      }
    }
  }

  final uriContent = UriContent();

  /// Sends a file.
  /// Returns true, if the next file should be sent.
  Future<bool> sendFile({
    required String sessionId,
    required int isolateIndex,
    required SendingFile file,
    required bool isRetry,
  }) async {
    final token = file.token;
    if (token == null) {
      return true;
    }

    final status = state[sessionId]?.status;
    const allowedStates = {SessionStatus.sending, SessionStatus.finishedWithErrors};
    if (status == null || !allowedStates.contains(status)) {
      return false;
    }

    final remoteSessionId = state[sessionId]!.remoteSessionId;
    final target = state[sessionId]!.target;

    if (isRetry) {
      _logger.info('Retrying ${file.file.fileName}');

      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          status: SessionStatus.sending,
          files: s.files.map((key, value) {
            if (key == file.file.id) {
              return MapEntry(key, value.copyWith(status: FileStatus.queue, errorMessage: null));
            }
            return MapEntry(key, value);
          }),
        ),
      );
    } else {
      _logger.info('Sending ${file.file.fileName}');
    }

    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.withFileStatus(file.file.id, FileStatus.sending, null),
    );

    final taskResult = ref
        .redux(parentIsolateProvider)
        .dispatchTakeResult(
          IsolateHttpUploadAction(
            isolateIndex: isolateIndex,
            remoteSessionId: remoteSessionId,
            remoteFileToken: token,
            fileId: file.file.id,
            filePath: file.path,
            fileBytes: file.bytes,
            mime: file.file.lookupMime(),
            fileSize: file.file.size,
            device: target,
          ),
        );

    String? fileError;
    try {
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          sendingTasks: [
            ...?s.sendingTasks,
            SendingTask(
              isolateIndex: isolateIndex,
              taskId: taskResult.taskId,
            ),
          ],
        ),
      );

      await for (final progress in taskResult.progress) {
        ref
            .notifier(progressProvider)
            .setProgress(
              sessionId: sessionId,
              fileId: file.file.id,
              progress: progress,
            );
      }

      // set progress to 100% when successfully finished
      ref
          .notifier(progressProvider)
          .setProgress(
            sessionId: sessionId,
            fileId: file.file.id,
            progress: 1,
          );
    } catch (e, st) {
      fileError = e.humanErrorMessage;
      _logger.warning('Error while sending file ${file.file.fileName}', e, st);
    } finally {
      state = state.updateSession(
        sessionId: sessionId,
        state: (s) => s?.copyWith(
          sendingTasks: s.sendingTasks?.where((task) => !(task.isolateIndex == isolateIndex && task.taskId == taskResult.taskId)).toList(),
        ),
      );
    }

    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.withFileStatus(file.file.id, fileError != null ? FileStatus.failed : FileStatus.finished, fileError),
    );

    if (isRetry) {
      final state = this.state[sessionId];
      if (state != null && state.files.values.map((e) => e.status).isFinishedOrError) {
        _finish(sessionId: sessionId);
        return false;
      }
    }

    return true;
  }

  /// Closes the send-session and sends a cancel event to the receiver.
  void cancelSession(String sessionId) {
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return;
    }
    final remoteSessionId = sessionState.remoteSessionId;

    _cancelRunningRequests(sessionState);

    if (remoteSessionId == null) {
      closeSession(sessionId);
      return;
    }

    // notify the receiver
    final target = sessionState.target;
    final endpoint = target.firstHttpEndpoint;
    if (endpoint == null) {
      _logger.warning('Cannot notify receiver: no HttpEndpoint on ${target.alias}');
    } else {
      try {
        ref
            .read(httpProvider)
            .v2
            // ignore: discarded_futures
            .cancel(
              protocol: target.getProtocolType(),
              ip: endpoint.ip,
              port: endpoint.port,
              sessionId: remoteSessionId,
            );
      } catch (e) {
        _logger.warning('Error while canceling session', e);
      }
    }

    // finally, close session locally
    closeSession(sessionId);
  }

  void cancelSessionByReceiver(String sessionId) {
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return;
    }
    _cancelRunningRequests(sessionState);

    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(
        status: SessionStatus.canceledByReceiver,
        endTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _cancelRunningRequests(SendSessionState state) {
    for (final task in state.sendingTasks ?? <SendingTask>[]) {
      ref
          .redux(parentIsolateProvider)
          .dispatch(
            IsolateHttpUploadCancelAction(
              isolateIndex: task.isolateIndex,
              taskId: task.taskId,
            ),
          );
    }
  }

  /// Closes the session
  void closeSession(String sessionId) {
    _stopWait(sessionId);
    final sessionState = state[sessionId];
    if (sessionState == null) {
      return;
    }
    state = state.removeSession(ref, sessionId);
    if (sessionState.status == SessionStatus.finished && ref.read(settingsProvider).sendMode == SendMode.single) {
      // clear selected files
      ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction());
    }
  }

  void clearAllSessions() {
    for (final id in _pendingWaits.keys.toList()) {
      _stopWait(id);
    }
    state = {};
    ref.notifier(progressProvider).removeAllSessions();
  }

  void setBackground(String sessionId, bool background) {
    state = state.updateSession(
      sessionId: sessionId,
      state: (s) => s?.copyWith(background: background),
    );
  }

  @override
  Future<void> dispose() async {
    for (final id in _pendingWaits.keys.toList()) {
      _stopWait(id);
    }
    super.dispose();
  }
}

class _PendingWait {
  _PendingWait({required this.subscription, required this.timeoutTimer});
  final StreamSubscription<dynamic> subscription;
  final Timer timeoutTimer;
}

extension on Map<String, SendSessionState> {
  Map<String, SendSessionState> updateSession({
    required String sessionId,
    required SendSessionState? Function(SendSessionState? old) state,
  }) {
    final newState = state(this[sessionId]);
    if (newState == null) {
      // no change
      return this;
    }
    return {
      ...this,
      sessionId: newState,
    };
  }

  Map<String, SendSessionState> removeSession(Ref ref, String sessionId) {
    ref.notifier(progressProvider).removeSession(sessionId);
    return {...this}..remove(sessionId);
  }
}

extension on SendSessionState {
  SendSessionState withFileStatus(String fileId, FileStatus status, String? errorMessage) {
    return copyWith(
      files: {...files}
        ..update(
          fileId,
          (file) => file.copyWith(
            status: status,
            errorMessage: errorMessage,
          ),
        ),
    );
  }
}

extension on Object {
  String get humanErrorMessage {
    final e = this;
    final (statusCode, message) = switch (this) {
      RhttpStatusCodeException(:final statusCode, :final body) => (statusCode, _parseErrorMessage(body)),
      _ => (null, e.toString()),
    };

    if (statusCode != null && message != null) {
      return '[$statusCode] $message';
    }

    return e.toString();
  }
}

String? _parseErrorMessage(Object? body) {
  if (body is! String) {
    return null;
  }

  try {
    return (jsonDecode(body) as Map)['message'];
  } catch (_) {
    return null;
  }
}
