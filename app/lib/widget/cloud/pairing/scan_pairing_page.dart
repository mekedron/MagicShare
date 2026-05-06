import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/pairing/pairing_payload.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/requests/join_network_new_device.dart';
import 'package:magicshare_app/widget/cloud/pairing/enter_pairing_code_page.dart';
import 'package:magicshare_app/widget/cloud/pairing/pairing_preview_dialog.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:routerino/routerino.dart';

final _logger = Logger('ScanPairingPage');

/// QR-scanner route for the joining-side pairing flow. Uses
/// `mobile_scanner` (Android, iOS, macOS). Cameraless or
/// permission-denied desktops fall back to [EnterPairingCodePage] via
/// the in-page *Camera unavailable — enter code instead* button.
class ScanPairingPage extends StatefulWidget {
  const ScanPairingPage({
    super.key,
    this.newDeviceIdentity,
    this.controllerOverride,
  });

  /// Pass the freshly-built local device identity for the
  /// welcome-card route. Existing-source-group joiners can leave
  /// this null.
  final JoinNetworkNewDevice? newDeviceIdentity;

  /// Test-only override for the underlying [MobileScannerController].
  final MobileScannerController? controllerOverride;

  @override
  State<ScanPairingPage> createState() => _ScanPairingPageState();
}

class _ScanPairingPageState extends State<ScanPairingPage> {
  late final MobileScannerController _controller;
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controllerOverride ??
        MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          formats: const [BarcodeFormat.qrCode],
        );
  }

  @override
  void dispose() {
    if (widget.controllerOverride == null) {
      // ignore: discarded_futures
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_consumed) return;
    final raw = capture.barcodes
        .firstWhere(
          (b) => b.rawValue != null && b.rawValue!.isNotEmpty,
          orElse: Barcode.new,
        )
        .rawValue;
    if (raw == null || raw.isEmpty) return;

    final payload = tryDecodePairingUri(raw);
    if (payload == null) {
      _logger.fine('Scanned QR is not a pairing payload — ignoring.');
      return;
    }
    _consumed = true;
    await _controller.stop();

    if (!mounted) return;
    final paired = await showPairingPreviewDialog(
      context,
      payload: payload,
      newDeviceIdentity: widget.newDeviceIdentity,
    );
    if (!mounted) return;
    if (paired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.settingsTab.deviceGroup.pairing.snackbars.joined)),
      );
      await Navigator.of(context).maybePop();
    } else {
      // User cancelled or pairing failed — let them try again on the
      // same scanner page.
      _consumed = false;
      await _controller.start();
    }
  }

  Future<void> _onManualFallback() async {
    await _controller.stop();
    if (!mounted) return;
    final result = await context.push(
      () => EnterPairingCodePage(newDeviceIdentity: widget.newDeviceIdentity),
    );
    final paired = result == true;
    if (!mounted) return;
    if (paired) {
      // Manual entry succeeded — also pop the scanner so the user
      // lands back at the device-group settings instead of looking
      // at a dormant camera surface.
      _consumed = true;
      await Navigator.of(context).maybePop();
      return;
    }
    // User cancelled or failed — resume scanning.
    if (!_consumed) {
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = t.settingsTab.deviceGroup.pairing.scanPage;
    return Scaffold(
      appBar: AppBar(title: Text(l.title)),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return _ScannerError(
                  message: error.errorCode == MobileScannerErrorCode.permissionDenied ? l.permissionDenied : l.instructions,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  l.instructions,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: Text(l.manualEntryButton),
                  onPressed: _onManualFallback,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
