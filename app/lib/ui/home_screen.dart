import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../core/ports.dart';
import '../core/updates.dart';
import '../l10n/app_localizations.dart';
import 'browser_signin.dart';
import 'design.dart';
import 'effects.dart';
import 'format.dart';
import 'motion.dart';
import 'port_dialog.dart';
import 'update_dialog.dart';
import 'widgets.dart';

/// The phone's home, rebuilt after the approved sample: the brand and its
/// tagline under the status bar, one big card that carries the protocol,
/// the state, the stopwatch, the exit's location and the live readings,
/// and at the bottom the slide-to-connect pill, the connection mode, and
/// the protocol's own tabs — the core's real transports (HTTP/1.1,
/// HTTP/2, HTTP/3), which save into the core's config the way the
/// settings page does. Nothing here links out: every control answers in
/// the app.
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
  /// The core's config, read once the page opens and after the page saves
  /// into it; the protocol's tabs read the transport from it.
  Map<String, Object?>? _config;

  /// The transport being saved right now ('h1', 'h2', 'h3'), so its tab
  /// wears a spinner until the core answers.
  String? _savingTransport;

  @override
  void initState() {
    super.initState();
    _readConfig();
  }

  Future<void> _readConfig() async {
    try {
      final config = await widget.core.settings();
      if (mounted) setState(() => _config = config);
    } catch (_) {
      // The page reads it again the next time it opens.
    }
  }

  /// Saves the protocol into the core's config, as the settings page does;
  /// then reads the config back, so the tabs wear what the core keeps.
  /// Errors reach the caller, which shows them.
  Future<void> _setTransport(String value) async {
    if (_savingTransport != null) return;
    setState(() => _savingTransport = value);
    try {
      await widget.core.editSettings((config) {
        final proxy =
            (config['proxy'] as Map<String, Object?>?) ??
            <String, Object?>{};
        proxy['transport'] = value;
        config['proxy'] = proxy;
      });
      if (mounted) _readConfig();
    } finally {
      if (mounted) setState(() => _savingTransport = null);
    }
  }

  /// The transport the config keeps: 'h1', 'h2' (the default) or 'h3'.
  String get _transport => switch (_str(_config?['proxy'], 'transport')) {
    'h1' => 'h1',
    'h3' => 'h3',
    _ => 'h2',
  };

  /// The IP version the config keeps, for the parameters' row.
  String get _ipVersion => switch (_str(_config?['proxy'], 'ip_version')) {
    'dual' => 'dual',
    'ipv6_first' => 'ipv6_first',
    'ipv4' => 'ipv4',
    'ipv6' => 'ipv6',
    _ => 'auto',
  };

  static String _str(Object? node, String key) {
    if (node is Map<String, Object?>) {
      final v = node[key];
      if (v is String) return v;
    }
    return '';
  }

  /// Turns the tunnel on or off; the core handles the phone's VPN and the
  /// computer's system proxy each its own way.
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
    // The state's words at the card's top: connected, connecting, waiting,
    // an error — or, resting, "ready to connect", the way the sample says it.
    final stateLabel = connected
        ? l.stateConnected
        : confirming
        ? l.stateConnecting
        : status.state.phase == Phase.error
        ? l.stateError
        : status.state.phase == Phase.waiting
        ? l.stateWaiting
        : l.readyToConnect;
    final press = status.proxyOn
        ? (AndroidCore.isTv ? l.tapToDisconnectTv : l.tapToDisconnectPhone)
        : (AndroidCore.isTv ? l.tapToConnectTv : l.tapToConnectPhone);
    final traffic = status.traffic;
    final pingMs = connected && test?.ok == true ? test!.responseMs : null;
    final dotColor = connected
        ? StatusColors.good
        : confirming
        ? StatusColors.busy
        : status.state.phase == Phase.error
        ? StatusColors.bad
        : Dali.onVar(context);
    // The exit's country and city, in the language.
    final place = homeLocation(l, status, connected: connected);
    final city = connected &&
            proxy != null &&
            !isRecommendedPlace(proxy.countryCode)
        ? (proxy.cityName.isNotEmpty ? proxy.cityName : (status.exit?.city ?? ''))
        : '';
    final title = city.isNotEmpty && city != place.name
        ? '${place.name}${l.localeName == 'fa' ? '، ' : ', '}$city'
        : place.name;
    // The public address under the location, only when the user asked for
    // it (the Show public IP setting): the home keeps the address to
    // itself otherwise, as the phone's home always has.
    final address = widget.settings.showPublicIp &&
            connected &&
            (status.exit?.ipv4.isNotEmpty ?? false)
        ? status.exit!.ipv4
        : '';
    // The tunnel's way: every app (VPN), or the apps set up for it.
    final modeText = status.proxyOn
        ? (status.computerUsesVpn || !canSwitch ? l.modeVpn : l.modeProxy)
        : (Platform.isAndroid && AndroidCore.mode.value == 'proxy'
        ? l.modeProxy
        : l.modeVpn);
    // The protocol the connection wears: the live one from the proxy, or
    // what the config keeps.
    final protocolText = (proxy?.transport.isNotEmpty ?? false)
        ? proxy!.transport
        : switch (_transport) {
            'h1' => l.transportH1,
            'h3' => l.transportH3,
            _ => l.transportH2,
          };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              // The page's aurora: two soft lights that drift slowly behind
              // everything, the blue at the top, the state's color near the
              // switch. Quiet enough to read as air, not as an object.
              if (repeatingEffectsOn(context)) ...[
                PositionedDirectional(
                  top: -80,
                  end: -70,
                  child: DriftingGlow(
                    color: Dali.primary,
                    size: 280,
                    alpha: dark ? 0.10 : 0.06,
                  ),
                ),
                PositionedDirectional(
                  bottom: 60,
                  start: -90,
                  child: DriftingGlow(
                    color: connected ? StatusColors.good : Dali.primary,
                    size: 320,
                    alpha: dark ? 0.08 : 0.04,
                    period: const Duration(seconds: 14),
                  ),
                ),
              ],
              SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  // The status bar's height, then the room to breathe; at
                  // the bottom, room for the floating navigation.
                  padding: EdgeInsets.fromLTRB(
                    18,
                    MediaQuery.paddingOf(context).top + 10,
                    18,
                    116,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The page arrives in one gentle wave: the brand,
                      // then the card, then the controls, each a step
                      // behind the one before it.
                      MotionEntrance(
                        offset: const Offset(0, 10),
                        duration: Motion.normal,
                        child: _header(context),
                      ),
                      const SizedBox(height: 18),
                      MotionEntrance(
                        offset: const Offset(0, 14),
                        duration: Motion.slow,
                        child: _connectionCard(
                          context,
                          protocolText: protocolText,
                          stateLabel: stateLabel,
                          dotColor: dotColor,
                          connected: connected,
                          confirming: confirming,
                          connectedAt: proxy?.startedAt,
                          hint: connected
                              ? (traffic != null
                                    ? ''
                                    : l.encryptedHint)
                              : (look.hint.isNotEmpty ? look.hint : press),
                          traffic: traffic,
                          place: place,
                          title: title,
                          address: address,
                          pingMs: pingMs,
                          modeText: modeText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _problems(
                        context,
                        status: status,
                        failure: failure,
                        noNetwork: noNetwork,
                        gaveUp: gaveUp,
                        mismatch: exitMismatchText(l, status),
                        connected: connected,
                      ),
                      _updateBanner(context),
                      _coreNotices(context, status),
                      _lowQuota(context),
                      // The controls sit at the bottom, where the thumb
                      // reaches them.
                      const Spacer(),
                      const SizedBox(height: 12),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 60),
                        offset: const Offset(0, 16),
                        duration: Motion.slow,
                        child: _SlidePill(
                        label: status.proxyOn
                            ? l.swipeToDisconnect
                            : l.swipeToConnect,
                        tooltip: press,
                        on: status.proxyOn,
                        busy: core.switchingProxy,
                        autofocus: Platform.isAndroid && AndroidCore.isTv,
                        downRate: traffic?.downRate ?? 0,
                        upRate: traffic?.upRate ?? 0,
                        onToggle: status.totalAccounts == 0
                            ? _openAccounts
                            : () => runShowingErrors(
                                context,
                                () => _toggle(status.proxyOn),
                              ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 120),
                        offset: const Offset(0, 14),
                        duration: Motion.slow,
                        child: _modeRow(context, modeText: modeText),
                      ),
                      const SizedBox(height: 10),
                      MotionEntrance(
                        delay: const Duration(milliseconds: 180),
                        offset: const Offset(0, 14),
                        duration: Motion.slow,
                        child: _protocolBar(context),
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
    );
  }

  /// The header, as the sample wears it: the brand in its own words —
  /// "Fali VPN" stays Latin in every language — the tagline under it in
  /// the user's words, and the version in its chip at the far end.
  Widget _header(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final version = appVersion == '0.0.0'
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Dali.hairline(context)),
            ),
            child: Text(
              ltr('v$appVersion'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Dali.onVar(context),
                fontWeight: FontWeight.w700,
                fontFeatures: const [],
                letterSpacing: 0.3,
              ),
            ),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The brand: never translated, never rewritten.
              Text(
                l.appTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                l.tagline,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Dali.onVar(context),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (version != null) ...[const SizedBox(width: 12), version],
      ],
    );
  }

  /// The big card: the protocol's badge and the state at one line, the
  /// stopwatch under them, the exit's location in its own inner card, and
  /// the three live readings at the feet. Nothing here is fixed in height:
  /// every card grows with its words.
  Widget _connectionCard(
    BuildContext context, {
    required String protocolText,
    required String stateLabel,
    required Color dotColor,
    required bool connected,
    required bool confirming,
    required DateTime? connectedAt,
    required String hint,
    required Traffic? traffic,
    required HomePlace place,
    required String title,
    required String address,
    required int? pingMs,
    required String modeText,
  }) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final card = theme.colorScheme.surfaceContainer;
    return Stack(
      children: [
        // A soft light under the card while the tunnel is up: the state's
        // color breathes out of the page.
        if (connected || confirming)
          Positioned.fill(
            child: IgnorePointer(
              child: DriftingGlow(
                color: connected ? StatusColors.good : StatusColors.busy,
                size: 320,
                alpha: dark ? 0.14 : 0.08,
                period: confirming
                    ? const Duration(seconds: 6)
                    : const Duration(seconds: 11),
              ),
            ),
          ),
        // The main card is the frosted pane: the page's lights blur under
        // it, the rim catches them at its top edge, and the energy field
        // breathes inside it while the tunnel is up.
        GlassCard(
          radius: 28,
          blur: true,
          color: card,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          shadow: [
            BoxShadow(
              color: (dark ? Colors.black : const Color(0xFF0B3B78))
                  .withValues(alpha: dark ? 0.5 : 0.08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
          child: Stack(
            children: [
              // The energy field: the state's own light breathing under
              // the glass, a calm wave the page rests on while the tunnel
              // is up — and while the switch is working for it.
              Positioned.fill(
                child: EnergyWaveField(
                  color: dotColor,
                  enabled: connected || confirming,
                  alpha: dark ? 0.10 : 0.07,
                ),
              ),
              // The card's room breathes with its words: a line that
              // appears (the address, a second line of the place's name)
              // grows in smoothly instead of jumping the card.
              AnimatedSize(
                duration: Motion.normal,
                curve: Motion.emphasized,
                alignment: Alignment.topCenter,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The protocol's badge at the reading's start, the state's
                  // dot and words at the end. Neither side is ever cut off:
                  // each shrinks to its room instead of losing its tail.
                  Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Dali.hairline(context)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          protocolText,
                          maxLines: 1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Dali.primary,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: SlideFadeSwitcher(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: dotColor.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              stateLabel,
                              key: ValueKey(stateLabel),
                              maxLines: 1,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Dali.onVar(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // The stopwatch at the reading's start; the state's word (or
              // the live traffic) rests at the other end, on its baseline.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _stopwatch(context, connected, connectedAt),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: SlideFadeSwitcher(
                      child: DefaultTextStyle(
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: Dali.onVar(context),
                        ),
                        child: traffic != null && connected
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _traffic(traffic),
                              )
                            : Text(
                                hint,
                                key: ValueKey(hint),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _serverCard(
                context,
                place: place,
                title: title,
                address: address,
                pingMs: pingMs,
                connected: connected,
              ),
              const SizedBox(height: 10),
              _readings(context, modeText: modeText),
                ],
              ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The stopwatch: still at 00:00:00 while the tunnel is off, running the
  /// moment it is up — the digits in their own language.
  Widget _stopwatch(BuildContext context, bool connected, DateTime? at) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final persian = l.localeName == 'fa';
    final style = theme.textTheme.headlineMedium?.copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      height: 1.1,
      color: connected
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurface.withValues(alpha: 0.72),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (connected && at != null) {
      return _fitStopwatch(
        ConnectedTimer(startedAt: at, style: style),
      );
    }
    return _fitStopwatch(
      Text(ltr(persian ? persianDigits('00:00:00') : '00:00:00'), style: style),
    );
  }

  /// The stopwatch never wraps, whatever the phone's text size: it shrinks
  /// to its room instead, so the digits stay one clean line.
  Widget _fitStopwatch(Widget child) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: child,
  );

  /// The live traffic, under the stopwatch: down and up, each with its
  /// arrow, in one quiet line.
  Widget _traffic(Traffic traffic) {
    final theme = Theme.of(context);
    Widget line(IconData icon, Color color, int value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          formatRate(value),
          style: theme.textTheme.labelMedium?.copyWith(
            color: Dali.onVar(context),
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(Icons.arrow_downward_rounded, Dali.primary, traffic.downRate),
        const SizedBox(width: 10),
        line(Icons.arrow_upward_rounded, StatusColors.good, traffic.upRate),
      ],
    );
  }

  /// The exit's location in its own inner card: the flag, how the location
  /// was chosen, its name (and city), the address under it, the delay in
  /// its pill, and the button that measures again. A tap opens the
  /// connection's details while connected, the servers otherwise; the
  /// refresh measures the delay again.
  Widget _serverCard(
    BuildContext context, {
    required HomePlace place,
    required String title,
    required String address,
    required int? pingMs,
    required bool connected,
  }) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return PressScale(
      onTap: connected
          ? widget.onOpenDetails
          : (widget.onOpenServers ?? () {}),
      amount: 0.985,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 8, 11),
        decoration: BoxDecoration(
          // The glass tint: the connection card's own light passes
          // through the exit's card, so the two read as one pane.
          color: theme.colorScheme.surfaceContainerHigh
              .withValues(alpha: GlassCard.fillAlpha(dark)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Dali.hairline(context)),
        ),
        child: Row(
          children: [
            DefaultTextStyle(
              style: const TextStyle(fontSize: 30),
              // The flag swaps with a small pop when the country changes.
              child: AnimatedSwitcher(
                duration: Motion.normal,
                switchInCurve: Motion.pop,
                switchOutCurve: Motion.emphasizedAccelerate,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: CountryFlag(
                  key: ValueKey(place.flag),
                  code: place.flag,
                  width: 40,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Dali.onVar(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      ltr(address),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Dali.onVar(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            // The delay in its pill; a dash while it is not known.
            PingChip(ms: pingMs, compact: true),
            IconButton(
              tooltip: l.testConnection,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  unawaited(widget.core.runTest().catchError((Object _) {})),
              icon: Icon(
                Icons.refresh_rounded,
                size: 21,
                color: Dali.onVar(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The three readings, as the sample's row of parameters, each real:
  /// the tunnel's way (VPN or proxy), the IP version the config keeps, and
  /// the local port. The first two open the connection's settings; the
  /// port asks for its new number itself.
  Widget _readings(BuildContext context, {required String modeText}) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final status = widget.core.status!;
    // The port, while the core says which one it waits on (a blocked
    // port, or one it was moved to); nothing while the tunnel runs.
    final port = '${portOf(status.state.address) ?? ''}';

    Widget stat(String label, String value) => Column(
      children: [
        Text(
          label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Dali.onVar(context),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          // The value shrinks to its box instead of being cut off, so the
          // longest translation reads whole.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [],
              ),
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh
            .withValues(alpha: GlassCard.fillAlpha(dark)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Dali.hairline(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: widget.onOpenConnection,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: stat(l.paramMode, modeText),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: widget.onOpenConnection,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: stat(
                  l.ipVersion,
                  // The value shows its short name ("Auto"): the whole
                  // sentence has no room in a third of the card, and the
                  // short one never squeezes.
                  _shortIpVersion(switch (_ipVersion) {
                    'dual' => l.ipVersionDual,
                    'ipv6_first' => l.ipVersionV6First,
                    'ipv4' => l.ipVersionV4,
                    'ipv6' => l.ipVersionV6,
                    _ => l.ipVersionAuto,
                  }),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: port.isEmpty ? null : () => _changePort(context),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: stat(l.paramPort, port.isEmpty ? '—' : ltr(port)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The value of a reading that has a long and a short form: the part
  /// before the parenthesis, so "Auto (IPv4, then IPv6)" reads "Auto" —
  /// the whole sentence has no room in a third of a card, and the short
  /// name never squeezes.
  String _shortIpVersion(String value) {
    final i = value.indexOf('(');
    return i > 0 ? value.substring(0, i).trim() : value;
  }

  /// Asks for the port and hands it to the core, as the problem card's
  /// own change-port does.
  Future<void> _changePort(BuildContext context) async {
    final core = widget.core;
    final status = core.status;
    if (status == null) return;
    final port = await showPortDialog(context, taken: status.state.address);
    if (port != null && context.mounted) {
      await runShowingErrors(context, () => core.setProxyPort(port));
    }
  }

  /// The tunnel's way, as the sample's toggle row: the icon tile, the
  /// mode's name and its value, and the chevron; a tap opens the
  /// connection's settings, where the way is really chosen.
  Widget _modeRow(BuildContext context, {required String modeText}) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PressScale(
      onTap: widget.onOpenConnection ?? () {},
      amount: 0.985,
      // Soft depth: the row swells out of the page, the light on its top
      // edge and the shade gathered under it.
      child: SoftDepth(
        color: theme.colorScheme.surfaceContainer,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 10, 11),
        child: Row(
          children: [
            IconTile(icon: Icons.vpn_lock_rounded, color: Dali.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.connectionMode,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Dali.wash(Dali.primary, theme.brightness == Brightness.dark),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                modeText,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Dali.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Dali.onVar(context),
            ),
          ],
        ),
      ),
    );
  }

  /// The protocol's tabs, as the sample's bar, but with the core's own
  /// transports — HTTP/1.1, HTTP/2, HTTP/3 — each saving into the core's
  /// config, exactly as the settings page saves it. The chosen one wears
  /// the blue; the one being saved wears a spinner.
  Widget _protocolBar(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = _transport;
    final options = [
      ('h1', l.transportH1),
      ('h2', l.transportH2),
      ('h3', l.transportH3),
    ];
    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Dali.hairline(context)),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: _ProtocolTab(
                label: label,
                selected: value == current,
                busy: _savingTransport == value,
                onTap: _savingTransport == null
                    ? () => runShowingErrors(
                        context,
                        () => _setTransport(value),
                      )
                    : null,
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
      // Mozilla refused the chosen location: the recommended one works,
      // on the same card, so the reason is not said twice.
      final refused = isLocationRefused(failure.code);
      cards.add(
        ProblemCard(
          text: failure.text,
          color: refused ? Dali.amber : StatusColors.bad,
          icon: refused
              ? Icons.travel_explore_rounded
              : Icons.error_outline_rounded,
          tooltip: failure.detail,
          actions: [
            if (refused)
              TextButton(
                onPressed: () =>
                    runShowingErrors(context, () => core.setLocation('')),
                child: Text(l.recommendedLocation),
              ),
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
      // The last connect was given up: why, with the recommended place's
      // answer when the location was the reason.
      final refused = isLocationRefused(status.connectFailure);
      cards.add(
        ProblemCard(
          text: failureCodeText(l, status.connectFailure),
          color: refused ? Dali.amber : StatusColors.bad,
          icon: refused
              ? Icons.travel_explore_rounded
              : Icons.error_outline_rounded,
          actions: [
            if (refused)
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
    if (cards.isEmpty) {
      // Still wrapped, so a banner that leaves closes its room smoothly
      // instead of jumping the cards under it.
      return MotionAppear(
        visible: false,
        child: const SizedBox.shrink(),
      );
    }
    return MotionAppear(
      visible: true,
      tag: cards.map((c) => (c as ProblemCard).text).join('|'),
      child: Column(
        children: [
          for (final (i, card) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.only(bottom: 2), child: card),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// A newer version: the amber banner with the update button; the
  /// phone's dialog comes from it, with the download inside the app —
  /// no browser, no page of any repository.
  Widget _updateBanner(BuildContext context) {
    final settings = widget.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([Updates.available, Updates.failure]),
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final release = Updates.available.value;
        final show =
            release != null && release.version != settings.dismissedUpdate;
        final failure = Updates.failure.value;
        return MotionAppear(
          visible: show,
          tag: release?.version ?? '',
          child: show
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
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
                          onPressed: () => showUpdateDialog(
                            context,
                            release: release,
                            core: widget.core,
                            settings: settings,
                          ),
                          icon: const Icon(
                            Icons.system_update_alt_rounded,
                            size: 18,
                          ),
                          label: Text(l.updateNow),
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
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  /// The core's notes (a command it ran), in amber cards with a close each.
  Widget _coreNotices(BuildContext context, CoreStatus status) {
    final shown = [
      for (final n in homeNotices(status.notices))
        if (!_dismissedNotices.contains(n.key) &&
            (n.kind == 'port' || n.kind == 'command'))
          n,
    ];
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return MotionAppear(
      visible: shown.isNotEmpty,
      tag: shown.map((n) => n.key).join('|'),
      child: shown.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: [
                for (final n in shown)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
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
                              l.noticeTimes(
                                n.count,
                                formatAgo(l, n.last!),
                              ),
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
            ),
    );
  }

  /// The notices this run of the app closed; the core lists them again
  /// when it has a newer one to tell.
  static final Set<String> _dismissedNotices = {};

  /// The account is running out: a word, a way to add another, a close
  /// that keeps it away for a day.
  Widget _lowQuota(BuildContext context) {
    final show = _quotaVisible();
    final usage = widget.core.status?.activeAccount?.usage;
    final l = AppLocalizations.of(context);
    String rounded(int bytes) => formatBytes(bytes).replaceAll('.0 ', ' ');
    return MotionAppear(
      visible: show && usage != null,
      tag: 'quota-${usage?.limitBytes}',
      child: show && usage != null
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
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
            )
          : const SizedBox.shrink(),
    );
  }
}

/// One tab of the protocol's bar: the transport's name, the blue pill
/// while it is the one, a spinner while its choice saves.
class _ProtocolTab extends StatelessWidget {
  const _ProtocolTab({
    required this.label,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tab = AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.emphasized,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: const BoxDecoration(),
      child: ScaleSwitcher(
        duration: Motion.fast,
        child: busy
            ? SizedBox.square(
                key: const ValueKey('busy'),
                dimension: 16,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                key: const ValueKey('label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? Colors.white
                      : Dali.onVar(context),
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [],
                ),
              ),
      ),
    );
    // Soft depth: the chosen transport swells out of the bar, the light
    // on its face and the shade pooled under it — the bar reads it as
    // the one.
    if (selected) {
      tab = SoftDepth(color: Dali.primary, child: tab);
    }
    return PressScale(onTap: onTap, amount: 0.94, child: tab);
  }
}

/// The slide-to-connect pill, after the sample: a white circle that slides
/// along the capsule — with the finger, or by a tap — and turns the tunnel
/// over as it passes the middle. While the tunnel is up the pill wears the
/// state's green, and its light breathes out of it.
class _SlidePill extends StatefulWidget {
  const _SlidePill({
    required this.label,
    required this.tooltip,
    required this.on,
    required this.busy,
    required this.onToggle,
    required this.downRate,
    required this.upRate,
    this.autofocus = false,
  });

  final String label;
  final String tooltip;
  final bool on;
  final bool busy;

  /// The connection's real rates, in bytes a second: the data flow's
  /// particles run by them, download in blue, upload in green.
  final int downRate;
  final int upRate;
  final VoidCallback onToggle;
  final bool autofocus;

  @override
  State<_SlidePill> createState() => _SlidePillState();
}

class _SlidePillState extends State<_SlidePill>
    with SingleTickerProviderStateMixin {
  /// The knob's travel, 0 at its resting end to 1 at the far end, while
  /// the finger holds it; settled back to 0 the moment the finger lifts.
  double _drag = 0;
  bool _dragging = false;
  bool _passed = false;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  void _move(DragUpdateDetails d) {
    final box = context.findRenderObject() as RenderBox;
    final room = (box.size.width - 84).clamp(60.0, 400.0);
    final dx = d.primaryDelta! * (_rtl ? -1 : 1);
    setState(() => _drag = ((_drag + dx / room)).clamp(0.0, 1.0));
    // The moment the halfway is crossed, the finger hears it: past it,
    // letting go turns the tunnel over.
    if (_drag > 0.45 != _passed) {
      _passed = _drag > 0.45;
      if (Motion.on(context)) HapticFeedback.selectionClick();
    }
  }

  void _end(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond.dx * (_rtl ? -1 : 1);
    final go = _drag > 0.45 || velocity > 700;
    setState(() {
      _drag = 0;
      _dragging = false;
      _passed = false;
    });
    if (go && !widget.busy) widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = widget.on ? StatusColors.good : Dali.primary;
    return Tooltip(
      message: widget.tooltip,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onToggle(),
          ),
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // No rings bloom behind the pill when the tunnel arrives: the
            // connection's own lights — the data flow inside the glass,
            // the card's energy field — are the whole celebration.
            PressScale(
              onTap: widget.busy ? null : widget.onToggle,
              amount: 0.97,
              haptic: true,
              child: ShimmerSweep(
                enabled: widget.busy,
                color: Colors.white,
                period: const Duration(milliseconds: 1300),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart:
                      widget.busy ? null : (_) => setState(() => _dragging = true),
                  onHorizontalDragUpdate: widget.busy ? null : _move,
                  onHorizontalDragEnd: widget.busy ? null : _end,
                  onHorizontalDragCancel: widget.busy
                      ? null
                      : () => setState(() {
                          _drag = 0;
                          _dragging = false;
                          _passed = false;
                        }),
                  // The pill itself is the frosted pane now: the page's
                  // lights blur under it, and the tunnel's own wires — the
                  // data flow — carry their light inside it while the
                  // connection is up.
                  child: GlassCard(
                    radius: 999,
                    blur: true,
                    color: theme.colorScheme.surfaceContainer,
                    shadow: [
                      BoxShadow(
                        color: (dark ? Colors.black : const Color(0xFF0B3B78))
                            .withValues(alpha: dark ? 0.5 : 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    padding: const EdgeInsets.all(7),
                    child: SizedBox(
                      height: 46,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // The data flow: download in blue arriving at
                          // the user, upload in green leaving for the
                          // world, each particle's pace the real rate's.
                          Positioned.fill(
                            child: DataFlowField(
                              downRate: widget.downRate,
                              upRate: widget.upRate,
                              enabled: widget.on && !widget.busy,
                              downColor: Dali.primary,
                              upColor: StatusColors.good,
                              rtl: _rtl,
                            ),
                          ),
                        // The words in the middle, the dots at the far
                        // end: the pill reads as a track, not a button.
                        // The words cross with a slide when the state
                        // turns over, so the swap never snaps.
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 64,
                          ),
                          child: SlideFadeSwitcher(
                            duration: Motion.normal,
                            child: Text(
                              widget.label,
                              key: ValueKey(widget.label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: widget.on
                                    ? StatusColors.good
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 14,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < 3; i++)
                                  AnimatedContainer(
                                    width: 7,
                                    height: 7,
                                    duration: Motion.normal,
                                    curve: Motion.emphasized,
                                    margin:
                                        const EdgeInsetsDirectional.symmetric(
                                          horizontal: 2.5,
                                        ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.on
                                          ? StatusColors.good.withValues(
                                              alpha: 0.45 + 0.18 * i,
                                            )
                                          : (i == 0 || _drag > (i + 1) / 3.2
                                          ? Dali.primary
                                          : Dali.onVar(context).withValues(
                                              alpha: 0.4,
                                            )),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // The knob: the white circle with its arrow, sliding
                        // with the finger and settling back when let go.
                        AnimatedAlign(
                          duration: _dragging
                              ? Duration.zero
                              : Motion.normal,
                          curve: Motion.pop,
                          alignment: AlignmentDirectional(
                            -1 + 2 * _drag,
                            0,
                          ),
                          child: AnimatedScale(
                            scale: _dragging ? 1.06 : 1,
                            duration: Motion.fast,
                            curve: Motion.pop,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(
                                      alpha: dark ? 0.45 : 0.35,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: ScaleSwitcher(
                                  duration: Motion.fast,
                                  child: widget.busy
                                      ? SizedBox.square(
                                          key: const ValueKey('spin'),
                                          dimension: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.6,
                                            color: color,
                                          ),
                                        )
                                      : Icon(
                                          widget.on
                                              ? Icons.lock_rounded
                                              : (_rtl
                                              ? Icons.arrow_back_rounded
                                              : Icons.arrow_forward_rounded),
                                          key: ValueKey(widget.on ? 'on' : 'off'),
                                          size: 22,
                                          color: color,
                                        ),
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
            ),
          ],
        ),
      ),
    );
  }
}


