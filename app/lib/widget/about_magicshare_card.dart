import 'package:flutter/material.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/provider/version_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _localSendHomeUrl = 'https://localsend.org';
const _licenseUrl = 'https://github.com/mekedron/MagicShare/blob/main/LICENSE';

class AboutMagicShareCard extends StatelessWidget {
  final Future<void> Function(Uri url)? onOpenUrl;

  const AboutMagicShareCard({super.key, this.onOpenUrl});

  Future<void> _openUrl(Uri url) async {
    final opener = onOpenUrl;
    if (opener != null) {
      await opener(url);
      return;
    }
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final theme = Theme.of(context);
    final versionAsync = ref.watch(versionProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.aboutMagicShare.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            versionAsync.maybeWhen(
              data: (version) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(t.aboutMagicShare.version(version: version)),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(t.aboutMagicShare.forkNotice),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openUrl(Uri.parse(_localSendHomeUrl)),
                icon: const Icon(Icons.open_in_new),
                label: Text(t.aboutMagicShare.openLocalSend),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openUrl(Uri.parse(_licenseUrl)),
                icon: const Icon(Icons.description_outlined),
                label: Text(t.aboutMagicShare.viewLicense),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
