import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/core/platform/open_external_url.dart';
import 'package:ai_limit_status/features/settings/data/app_updates.dart';
import 'package:flutter/material.dart';

class AppUpdatesCard extends StatefulWidget {
  const AppUpdatesCard({
    required this.installedVersion,
    required this.platform,
    super.key,
  });

  final Future<String> installedVersion;
  final AppUpdatePlatform platform;

  @override
  State<AppUpdatesCard> createState() => _AppUpdatesCardState();
}

class _AppUpdatesCardState extends State<AppUpdatesCard> {
  Future<AppUpdate?>? _check;
  bool _downloadFailed = false;

  void _checkForUpdates() {
    setState(() {
      _downloadFailed = false;
      _check = widget.installedVersion.then(
        (version) => checkForAppUpdate(version, widget.platform),
      );
    });
  }

  Future<void> _openDownload(Uri url) async {
    final check = _check;
    final opened = await openExternalUrl(url);
    if (mounted && identical(check, _check)) {
      setState(() => _downloadFailed = !opened);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.instance;
    return FutureBuilder<AppUpdate?>(
      future: _check,
      builder: (context, snapshot) {
        final checking = snapshot.connectionState == ConnectionState.waiting;
        final update = checking ? null : snapshot.data;
        final downloadUrl = update?.downloadUrl;
        final message = switch ((
          snapshot.connectionState,
          snapshot.hasError,
          update,
        )) {
          (ConnectionState.waiting, _, _) => strings.checkingForAppUpdates,
          (_, true, _) => strings.appUpdateCheckFailed,
          (_, _, (version: final version, downloadUrl: null)) =>
            strings.appUpdateInstallerUnavailable(version),
          (_, _, (version: final version, downloadUrl: _)) =>
            strings.appUpdateAvailable(version),
          (ConnectionState.done, _, null) => strings.appIsUpToDate,
          _ => null,
        };

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_alt_rounded),
                title: Text(strings.checkForAppUpdates),
                subtitle: message == null
                    ? null
                    : Semantics(liveRegion: true, child: Text(message)),
                trailing: const Icon(Icons.refresh_rounded),
                onTap: checking ? null : _checkForUpdates,
              ),
              if (downloadUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: OutlinedButton.icon(
                    onPressed: () => _openDownload(downloadUrl),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(switch (widget.platform) {
                      AppUpdatePlatform.macOS => strings.downloadMacUpdate,
                      AppUpdatePlatform.windows =>
                        strings.downloadWindowsUpdate,
                    }),
                  ),
                ),
              if (_downloadFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(strings.appUpdateDownloadFailed),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
