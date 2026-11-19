import 'package:flutter/material.dart';

import '../app_info.dart';
import '../app_settings.dart';
import '../core/apk_update.dart';
import '../core/core_controller.dart';
import '../core/updates.dart';
import '../l10n/app_localizations.dart';
import 'design.dart';
import 'format.dart';
import 'motion.dart';
import 'widgets.dart' show StatusColors;

/// The update's dialog, in the shape of the approved sample: the round
/// mark, the version in green, the file's size and the current one, the
/// "What's new" of the release, and the big green button that downloads
/// and installs — with the download's progress line in the app stores'
/// manner (a rounded line, the percent, the bytes, the speed). Everything
/// speaks the app's language, and nothing on it names where the file
/// comes from: the download runs inside the app, and Android's installer
/// takes it at the end.
Future<void> showUpdateDialog(
  BuildContext context, {
  required Release release,
  required CoreController core,
  required AppSettings settings,
}) => showFaliDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => _UpdateDialog(
    release: release,
    core: core,
    settings: settings,
  ),
);

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.release,
    required this.core,
    required this.settings,
  });

  final Release release;
  final CoreController core;
  final AppSettings settings;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  /// The file's size, once the server said it; 0 while unknown.
  int _size = 0;

  @override
  void initState() {
    super.initState();
    _sizeOf();
  }

  /// Asks the file's weight first, so the dialog can show it before the
  /// download starts, the way the sample does.
  Future<void> _sizeOf() async {
    final size = await ApkUpdate.sizeOf(
      widget.release,
      proxy: updateProxy(widget.core.status),
    ).catchError((Object _) => 0);
    if (mounted) setState(() => _size = size);
  }

  /// The whole run: download the APK inside the app, then hand it to
  /// Android's installer; the dialog's ears ([ApkUpdate.state]) draw
  /// every step of it.
  Future<void> _downloadAndInstall() async {
    await ApkUpdate.download(
      widget.release,
      proxy: updateProxy(widget.core.status),
    );
    if (ApkUpdate.state.value.phase == ApkPhase.done) {
      final started = await ApkUpdate.install();
      // The installer is in front: the dialog steps aside.
      if (started && mounted) Navigator.of(context).pop();
    }
  }

  /// "Later": the version stays quiet until a newer one is found.
  void _later() {
    widget.settings.update(dismissedUpdate: widget.release.version);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: Listenable.merge([ApkUpdate.state, Updates.notes]),
      builder: (context, _) {
        final apk = ApkUpdate.state.value;
        final notes = Updates.notes.value;
        final busy = apk.busy || apk.phase == ApkPhase.installing;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Dali.hairline(context)),
                boxShadow: [
                  BoxShadow(
                    color: (dark ? Colors.black : const Color(0xFF0B3B78))
                        .withValues(alpha: dark ? 0.55 : 0.25),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The round mark, wearing the app's blue.
                  Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(Dali.primary, Colors.white, 0.22)!,
                            Dali.primary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Dali.primary.withValues(
                              alpha: dark ? 0.5 : 0.35,
                            ),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        size: 30,
                        color: Dali.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l.updateReadyTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // The version, in green, as the sample's own.
                  Text(
                    ltr('v${widget.release.version}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: StatusColors.good,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // The file's weight and the version now on the phone.
                  Row(
                    children: [
                      Expanded(
                        child: _fact(
                          context,
                          label: l.updateSizeLabel,
                          value: _size > 0 ? formatBytes(_size) : '—',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _fact(
                          context,
                          label: l.updateCurrentLabel,
                          value: appVersion == '0.0.0'
                              ? '—'
                              : ltr('v$appVersion'),
                        ),
                      ),
                    ],
                  ),
                  // What the version brings, in the app's language.
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Dali.surface2(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Dali.hairline(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.updateWhatsNew(widget.release.version),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 132),
                          child: SingleChildScrollView(
                            child: AnimatedSize(
                              duration: Motion.normal,
                              curve: Motion.emphasized,
                              alignment: AlignmentDirectional.topStart,
                              child: Text(
                                notes.isNotEmpty
                                    ? notes
                                    : l.updateWhatsNewGeneric,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Dali.onVar(context),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The state of the download, where the button stands.
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: Motion.normal,
                    switchInCurve: Motion.emphasizedDecelerate,
                    switchOutCurve: Motion.emphasizedAccelerate,
                    child: _action(context, apk, busy),
                  ),
                  if (apk.phase == ApkPhase.failed && apk.error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        apk.error,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Dali.onVar(context),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: busy ? null : _later,
                    child: Text(
                      l.updateLater,
                      style: TextStyle(
                        color: busy ? Dali.onVar(context) : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// One of the two facts under the version: the label above, the value
  /// below, both centered, on their own soft tile.
  Widget _fact(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: Dali.surface2(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Dali.hairline(context)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Dali.onVar(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [],
            ),
          ),
        ],
      ),
    );
  }

  /// What stands at the dialog's foot, by the download's state: the big
  /// green button at rest, the progress line while it runs, the leave to
  /// install when Android asks, and the retry after a failure.
  Widget _action(BuildContext context, ApkState apk, bool busy) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final persian = AppLocalizations.of(context).localeName == 'fa';
    String digits(String s) => persian ? persianDigits(s) : s;

    if (apk.phase == ApkPhase.needsPermission) {
      return Column(
        key: const ValueKey('perm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.updateAllowInstallHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Dali.onVar(context),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: StatusColors.good,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => ApkUpdate.install(),
            icon: const Icon(Icons.install_mobile_rounded, size: 19),
            label: Text(l.updateAllowInstall),
          ),
        ],
      );
    }

    if (apk.phase == ApkPhase.failed) {
      return Column(
        key: const ValueKey('fail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.updateDownloadFailed,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StatusColors.bad,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: StatusColors.good,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _downloadAndInstall,
            icon: const Icon(Icons.refresh_rounded, size: 19),
            label: Text(l.tryAgain),
          ),
        ],
      );
    }

    if (busy) {
      // The stores' progress line: a rounded bar, the percent at one end,
      // the bytes and the speed at the other.
      final percent = (apk.progress * 100).round();
      final received = formatBytes(apk.received);
      final total = apk.total > 0 ? formatBytes(apk.total) : '';
      final speed = apk.speed >= 1 ? formatRate(apk.speed.round()) : '';
      return Column(
        key: const ValueKey('busy'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: apk.phase == ApkPhase.downloading && apk.total > 0
                  ? apk.progress
                  : null,
              minHeight: 10,
              backgroundColor: Dali.surface3(context),
              color: StatusColors.good,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                apk.total > 0 ? digits('$percent%') : '…',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: StatusColors.good,
                  fontFeatures: const [],
                ),
              ),
              const Spacer(),
              Text(
                [
                  if (apk.received > 0)
                    total.isNotEmpty
                        ? l.updateProgressOf(received, total)
                        : received,
                  if (speed.isNotEmpty) speed,
                ].join(' · '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Dali.onVar(context),
                  fontFeatures: const [],
                ),
              ),
            ],
          ),
        ],
      );
    }

    // At rest: the big green button, as the sample's own.
    return FilledButton.icon(
      key: const ValueKey('go'),
      style: FilledButton.styleFrom(
        backgroundColor: StatusColors.good,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: _downloadAndInstall,
      icon: const Icon(Icons.download_rounded, size: 20),
      label: Text(
        l.updateDownloadInstall,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
