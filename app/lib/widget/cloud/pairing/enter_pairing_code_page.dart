import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magicshare_app/cloud/pairing/pairing_payload.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/requests/join_network_new_device.dart';
import 'package:magicshare_app/widget/cloud/pairing/pairing_preview_dialog.dart';

/// Manual-entry alternative to the QR scanner. Cameraless desktops
/// and headless servers route here from the *Camera unavailable —
/// enter code instead* fallback. The decode chain is identical to
/// the scanner: the typed Crockford-Base32 payload feeds the same
/// `tryDecodePairingManualCode` and the same [PairingPreviewDialog].
class EnterPairingCodePage extends StatefulWidget {
  const EnterPairingCodePage({
    super.key,
    this.newDeviceIdentity,
  });

  /// Pass the freshly-built local device identity for the
  /// welcome-card route. Existing-source-group joiners can leave
  /// this null.
  final JoinNetworkNewDevice? newDeviceIdentity;

  @override
  State<EnterPairingCodePage> createState() => _EnterPairingCodePageState();
}

class _EnterPairingCodePageState extends State<EnterPairingCodePage> {
  final _controller = TextEditingController();
  String? _inlineError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onPaste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      _controller.text = text.trim();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _inlineError = null;
    });
  }

  Future<void> _onSubmit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final payload = tryDecodePairingManualCode(raw);
    if (payload == null) {
      setState(
        () => _inlineError = t.settingsTab.deviceGroup.pairing.manualEntryPage.errors.typo,
      );
      return;
    }
    setState(() => _inlineError = null);

    final paired = await showPairingPreviewDialog(
      context,
      payload: payload,
      newDeviceIdentity: widget.newDeviceIdentity,
    );
    if (!paired || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.settingsTab.deviceGroup.pairing.snackbars.joined)),
    );
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = t.settingsTab.deviceGroup.pairing.manualEntryPage;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.hint, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.label,
                border: const OutlineInputBorder(),
                errorText: _inlineError,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              maxLines: 2,
              minLines: 2,
              onChanged: (_) {
                if (_inlineError != null) {
                  setState(() => _inlineError = null);
                }
              },
              onSubmitted: (_) => _onSubmit(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _onPaste,
                  icon: const Icon(Icons.content_paste),
                  label: Text(l.paste),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _onSubmit,
                  child: Text(l.submit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
