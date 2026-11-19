import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../core/ports.dart';
import '../core/updates.dart';
import '../l10n/app_localizations.dart';
import 'browser_signin.dart';
import 'design.dart';
import 'format.dart';
import 'motion.dart';
import 'port_dialog.dart';
import 'widgets.dart';
import 'world_map.dart';

/// The phone's home, built from the approved design: the brand on top,
/// the three live chips (ping, upload, download), the state and the
/// stopwatch, the wide capsule power button, and the world map with the
/// active server's card at the bottom. The map opens the connection's
/// details; its flag opens the servers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.core,
    required this.settings,
    required this.onOpenDetails,
    this.onOpenServers,
    this.onOpenAccounts,
    this.onOpenConnection,
    this.onOpenUpstreamProxy,
  });

  final CoreController core;
  final AppSettings settings;
  final VoidCallback onOpenDetails;
  final VoidCallback? onOpenServers;
  final VoidCallback? onOpenAccounts;
  final VoidCallback? onOpenConnection;
  final VoidCallback? onOpenUpstreamProxy;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// The core handles the initial connection while an explicit attempt is
  /// pending.
  Future<void> _toggle(bool on) async {
    final core = widget.core;
    final status = core.status;
    final canSwitch =
        status != null &&
        status.systemProxySupported &&
        !status.connectPending &&
        status.connectFailure.isEmpty;
    if (canSwitch) {
      await core.setSystemProxy(on ? 'clear' : 'set');
    } else {
      await core.setOn(!on);
    }
    if (!on) _testAfterPowerOn(core);
  }

  void _testAfterPowerOn(CoreController core) {
    final status = core.status;
    if (status != null && status.proxyOn && !status.connectPending) {
      unawaited(core.runTest().catchError((Object _) {}));
    }
  }

  void _openAccounts() {
    if (widget.onOpenAccounts != null) {
      widget.onOpenAccounts!();
    } else {
      startAddAccount(context, widget.core, widget.settings);
    }
  }

  // --- The low-quota notice's bookkeeping, once per connection. ---
  static const _quotaLeft = 5 << 30;
  static const _quotaShowFor = Duration(seconds: 60);
  static const _quotaQuiet = Duration(hours: 24);
  static DateTime? _quotaShownFor;
  static bool _quotaStarted = false;
  static bool _quotaOver = false;
  Timer? _quotaMinute;

  bool get _quotaDue {
    final status = widget.core.status;
    final active = status?.activeAccount;
    final usage = active?.usage;
    if (status == null || !status.proxyOn || active == null || usage == null) {
      return false;
    }
    if (usage.unlimited || usage.limitBytes == 0) return false;
    if (usage.remainingBytes >= _quotaLeft) return false;
    // Another account that can take over: the app moves to it by itself.
    final others = widget.core.accounts?.accounts ?? const <Account>[];
    final spare = others.any(
      (a) =>
          a.id != active.id &&
          a.enabled &&
          a.status == AccountStatus.ready &&
          (a.usage?.unlimited == true ||
              (a.usage?.remainingBytes ?? 0) >= _quotaLeft),
    );
    if (spare) return false;
    final closed = widget.settings.lowQuotaDismissedAt;
    return closed == null ||
        DateTime.now().difference(closed) >= _quotaQuiet;
  }

  bool _quotaVisible() {
    if (!_quotaDue) return false;
    final connection = widget.core.status?.proxy?.startedAt;
    if (!_quotaStarted || _quotaShownFor != connection) {
      _quotaStarted = true;
      _quotaShownFor = connection;
      _quotaOver = false;
      _quotaMinute?.cancel();
      _quotaMinute = Timer(_quotaShowFor, () {
        _quotaOver = true;
        if (mounted) setState(() {});
      });
    }
    return !_quotaOver;
  }

  @override
  void dispose() {
    _quotaMinute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.core;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final status = core.status!;
    final canSwitch = status.systemProxySupported;
    final proxy = status.proxy;
    final running = status.state.phase == Phase.running;
    // The phone's VPN is "Connecting", in amber, until a test confirms it
    // works (the controller tests again meanwhile).
    final confirming =
        status.connectPending ||
        (status.proxyOn &&
            running &&
            !canSwitch &&
            !status.confirmedBy(core.lastTest));
    final test = status.isCurrentTest(core.lastTest) ? core.lastTest : null;
    final noNetwork = !status.connectPending && status.noNetwork && status.proxyOn;
    final failing =
        !status.connectPending &&
        confirming &&
        ((proxy?.wakeError.isNotEmpty ?? false) || test?.ok == false);
    // The real reason; a long press shows the core's own text.
    final failure = failing ? failureText(l, proxy, test) : null;
    // The last connect was given up: why, until the next one.
    final gaveUp = !status.proxyOn && status.connectFailure.isNotEmpty;
    final connected =
        status.proxyOn &&
        running &&
        (status.computerUsesVpn || !canSwitch) &&
        !confirming;
    final look = PhaseLook.of(l, status);
    final label = confirming ? l.stateConnecting : look.label;
    final place = homeLocation(l, status, connected: connected);
    final mismatch = exitMismatchText(l, status);
    final tv = Platform.isAndroid && AndroidCore.isTv;
    final press = status.proxyOn
        ? (tv ? l.tapToDisconnectTv : l.tapToDisconnectPhone)
        : (tv ? l.tapToConnectTv : l.tapToConnectPhone);
    final traffic = status.traffic;
    final pingMs = connected && test?.ok == true ? test!.responseMs : null;
    final city = connected
        ? (proxy?.cityName.isNotEmpty ?? false
              ? proxy!.cityName
              : (status.exit?.city ?? ''))
        : '';

    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Dali.bgDark, Color(0xFF0B111C)]
                : const [Dali.bgLight, Color(0xFFF0F5FE)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  // Room at the bottom for the floating navigation.
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 116),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _brand(context),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: StatChip(
                              icon: Icons.bolt_rounded,
                              color: Dali.amber,
                              label: l.pingLabel,
                              value: pingMs == null
                                  ? '—'
                                  : persianDigits('$pingMs'),
                              unit: 'ms',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: StatChip(
                              icon: Icons.arrow_upward_rounded,
                              color: StatusColors.good,
                              label: l.uploadRate,
                              value: formatRate(traffic?.upRate ?? 0),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: StatChip(
                              icon: Icons.arrow_downward_rounded,
                              color: Dali.primary,
                              label: l.downloadRate,
                              value: formatRate(traffic?.downRate ?? 0),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 18),
                      Center(
                        child: SlideFadeSwitcher(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: connected
                                      ? StatusColors.good
                                      : confirming
                                      ? Dali.amber
                                      : status.state.phase == Phase.error
                                      ? StatusColors.bad
                                      : Dali.onVar(context),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                label,
                                key: ValueKey(label),
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        connected
                            ? l.encryptedHint
                            : look.hint.isNotEmpty
                            ? look.hint
                            : press,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Dali.onVar(context),
                        ),
                      ),
                      if (connected && proxy?.startedAt != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          l.connectedFor,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Dali.onVar(context),
                          ),
                        ),
                        ConnectedTimer(
                          startedAt: proxy!.startedAt,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ] else
                        const SizedBox(height: 24),
                      const SizedBox(height: 16),
                      Center(
                        child: PowerCapsule(
                          label: status.proxyOn
                              ? l.disconnectAction
                              : l.connectAction,
                          on: status.proxyOn,
                          busy: core.switchingProxy,
                          autofocus: tv,
                          // No account yet: the accounts page, which
                          // explains them.
                          onPressed: status.totalAccounts == 0
                              ? _openAccounts
                              : () => runShowingErrors(
                                  context,
                                  () => _toggle(status.proxyOn),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _problems(
                        context,
                        status: status,
                        failure: failure,
                        noNetwork: noNetwork,
                        gaveUp: gaveUp,
                        mismatch: mismatch,
                        connected: connected,
                      ),
                      const Spacer(),
                      const SizedBox(height: 12),
                      _updateBanner(context),
                      _coreNotices(context, status),
                      _lowQuota(context),
                      const SizedBox(height: 14),
                      _mapCard(
                        context,
                        place: place,
                        connected: connected,
                        city: city,
                        pingMs: pingMs,
                        exitCode: status.exit?.countryCode.length == 2
                            ? status.exit!.countryCode
                            : place.flag.length == 2
                            ? place.flag
                            : '',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return page;
  }

  /// The brand: the logo in its dark tile and the name beside it.
  Widget _brand(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF10151F)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Dali.hairline(context)),
            ),
            child: const Center(child: AppLogo(size: 22)),
          ),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context).appTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// The home's problems and hints, each in its own tinted card.
  Widget _problems(
    BuildContext context, {
    required CoreStatus status,
    required ({String text, String detail, String code})? failure,
    required bool noNetwork,
    required bool gaveUp,
    required String? mismatch,
    required bool connected,
  }) {
    final l = AppLocalizations.of(context);
    final core = widget.core;
    final cards = <Widget>[];
    if (status.totalAccounts == 0) {
      cards.add(
        ProblemCard(
          text: l.waitingForAccount,
          color: Dali.amber,
          icon: Icons.info_outline_rounded,
          actions: [
            TextButton.icon(
              onPressed: _openAccounts,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(l.addAccount),
            ),
          ],
        ),
      );
    } else if (noNetwork) {
      cards.add(
        ProblemCard(
          text: l.noNetwork,
          color: StatusColors.bad,
          icon: Icons.wifi_off_rounded,
        ),
      );
    } else if (failure != null) {
      cards.add(
        ProblemCard(
          text: failure.text,
          color: StatusColors.bad,
          icon: Icons.error_outline_rounded,
          tooltip: failure.detail,
          actions: [
            if (failure.code == Failure.unreachable &&
                widget.onOpenConnection != null)
              TextButton(
                onPressed: widget.onOpenConnection,
                child: Text(l.sectionConnection),
              ),
            if (failure.code == Failure.upstreamProxy &&
                widget.onOpenUpstreamProxy != null)
              TextButton(
                onPressed: widget.onOpenUpstreamProxy,
                child: Text(l.upstreamProxy),
              ),
          ],
        ),
      );
    } else if (gaveUp) {
      cards.add(
        ProblemCard(
          text: failureCodeText(l, status.connectFailure),
          color: StatusColors.bad,
          icon: Icons.error_outline_rounded,
        ),
      );
    }
    // Mozilla refused the chosen location: the recommended one works.
    if (isLocationRefused(failure?.code ?? '') ||
        (gaveUp && isLocationRefused(status.connectFailure))) {
      cards.add(
        ProblemCard(
          text: failureCodeText(l, Failure.locationRefused),
          color: Dali.amber,
          icon: Icons.travel_explore_rounded,
          actions: [
            TextButton(
              onPressed: () =>
                  runShowingErrors(context, () => core.setLocation('')),
              child: Text(l.recommendedLocation),
            ),
          ],
        ),
      );
    }
    if (mismatch != null && connected) {
      cards.add(
        ProblemCard(
          text: mismatch,
          color: Dali.amber,
          icon: Icons.public_rounded,
        ),
      );
    }
    if (status.state.proxyPortBlocked) {
      cards.add(
        ProblemCard(
          text: l.proxyPortInUse('${portOf(status.state.address) ?? status.state.address}'),
          color: StatusColors.bad,
          icon: Icons.settings_ethernet_rounded,
          actions: [
            TextButton(
              onPressed: () async {
                final port = await showPortDialog(
                  context,
                  taken: status.state.address,
                );
                if (port != null && context.mounted) {
                  await runShowingErrors(
                    context,
                    () => core.setProxyPort(port),
                  );
                }
              },
              child: Text(l.changePort),
            ),
          ],
        ),
      );
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          card,
        ],
      ],
    );
  }

  /// A newer version: the amber banner with the download button; on the
  /// phone it opens the browser (Updates in the app off) or the installer.
  Widget _updateBanner(BuildContext context) {
    final settings = widget.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([Updates.available, Updates.failure]),
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final release = Updates.available.value;
        if (release == null || release.version == settings.dismissedUpdate) {
          return const SizedBox.shrink();
        }
        final failure = Updates.failure.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ProblemCard(
            text: failure != null
                ? l.updateFailed(release.version)
                : l.updateAvailable(release.version),
            color: Dali.amber,
            icon: Icons.system_update_rounded,
            tooltip: failure ?? '',
            actions: [
              if (failure == null && release.url.isNotEmpty)
                TextButton.icon(
                  onPressed: () => openDownload(context, release),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(l.download),
                ),
              IconButton(
                tooltip: l.close,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () =>
                    settings.update(dismissedUpdate: release.version),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The core's notes (a port the apps' traffic was refused, a command it
  /// ran), in amber cards with a close each.
  Widget _coreNotices(BuildContext context, CoreStatus status) {
    final shown = [
      for (final n in homeNotices(status.notices))
        if (!_dismissedNotices.contains(n.key) &&
            (n.kind == 'port' || n.kind == 'command'))
          n,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final n in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProblemCard(
              text: n.kind == 'port'
                  ? l.noticePort(n.detail)
                  : l.noticeCommand,
              color: Dali.amber,
              icon: Icons.info_rounded,
              actions: [
                if (n.last != null)
                  Text(
                    [
                      l.noticeTimes(n.count, formatAgo(l, n.last!)),
                      if (n.hosts.isNotEmpty) n.hosts.join(', '),
                    ].join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Dali.onVar(context),
                    ),
                  ),
                IconButton(
                  tooltip: l.dismiss,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () =>
                      setState(() => _dismissedNotices.add(n.key)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The notices this run of the app closed; the core lists them again
  /// when it has a newer one to tell.
  static final Set<String> _dismissedNotices = {};

  /// The account is running out: a word, a way to add another, a close
  /// that keeps it away for a day.
  Widget _lowQuota(BuildContext context) {
    if (!_quotaVisible()) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final usage = widget.core.status!.activeAccount!.usage!;
    String rounded(int bytes) => formatBytes(bytes).replaceAll('.0 ', ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProblemCard(
        text: l.lowQuotaNotice(rounded(usage.limitBytes)),
        color: Dali.amber,
        icon: Icons.data_usage_rounded,
        actions: [
          TextButton.icon(
            onPressed: () =>
                startAddAccount(context, widget.core, widget.settings),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(l.addAccount),
          ),
          IconButton(
            tooltip: l.close,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => widget.settings.update(
              lowQuotaDismissedAt: DateTime.now(),
            ),
          ),
        ],
      ),
    );
  }

  /// The world: the dotted map with the path from home to the server, and
  /// the server's glass card at its feet. A tap opens the details while
  /// connected, the servers otherwise.
  Widget _mapCard(
    BuildContext context, {
    required HomePlace place,
    required bool connected,
    required String city,
    required int? pingMs,
    required String exitCode,
  }) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final title = city.isNotEmpty && city != place.name
        ? '${place.name}${l.localeName == 'fa' ? '، ' : ', '}$city'
        : place.name;
    return MotionEntrance(
      offset: const Offset(0, 16),
      duration: Motion.slow,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: connected ? widget.onOpenDetails : widget.onOpenServers,
          borderRadius: BorderRadius.circular(26),
          child: Container(
            height: 172,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Dali.hairline(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 46),
                      child: WorldMap(
                        dotColor: Dali.onVar(context).withValues(
                          alpha: dark ? 0.55 : 0.5,
                        ),
                        homeColor: Dali.primary,
                        exitColor: connected
                            ? StatusColors.good
                            : Dali.primary,
                        exitCode: exitCode,
                        connected: connected,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: (dark
                                    ? Dali.surface2Dark
                                    : Colors.white)
                                .withValues(alpha: dark ? 0.72 : 0.78),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Dali.hairline(context)),
                          ),
                          child: Row(
                            children: [
                              DefaultTextStyle(
                                style: const TextStyle(fontSize: 26),
                                child: CountryFlag(
                                  code: place.flag,
                                  width: 34,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      connected
                                          ? l.serverActive
                                          : place.caption,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: Dali.onVar(context),
                                          ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (pingMs != null)
                                PingChip(ms: pingMs, compact: true),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_left_rounded,
                                size: 22,
                                color: Dali.onVar(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
