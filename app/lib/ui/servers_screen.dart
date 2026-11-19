import 'dart:async';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'browser_signin.dart';
import 'design.dart';
import 'format.dart';
import 'motion.dart';
import 'widgets.dart';

/// The servers page, built from the approved design: the round search
/// field, the automatic choices, the recently connected, the quick picks
/// (the quickest delays), and every country, each in its own card with
/// its delay pill and its connect button. A tap on the button chooses the
/// location (`proxy.country`: empty for Mozilla's recommended location,
/// `fastest` for the lowest real delay, otherwise a country).
class ServersScreen extends StatefulWidget {
  const ServersScreen({
    super.key,
    required this.core,
    required this.settings,
  });

  final CoreController core;
  final AppSettings settings;

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

/// How old measured delays are before the page measures them again when
/// it opens.
const _pingStale = Duration(minutes: 10);

class _ServersScreenState extends State<ServersScreen> {
  List<Location>? _locations;
  DateTime? _pingedAt;
  String _country = '';
  String _query = '';
  bool _testing = false;

  /// The choice being saved ('' recommended, 'fastest', or a code).
  String? _busy;
  String? _summary;

  CoreController get _core => widget.core;

  /// No account yet: the delays cannot be measured (Mozilla's servers
  /// answer only an account's pass), so the page says to add one instead.
  bool get _noAccounts => _core.status?.totalAccounts == 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _core.call((api) => api.locations());
      final config = await _core.settings();
      if (!mounted) return;
      setState(() {
        _locations = list.locations;
        _pingedAt = list.pingedAt;
        if (config['proxy'] case {'country': final String country}) {
          _country = country;
        }
      });
      // Delays measured a while ago, or never: measured again at once (the
      // core does it also while the proxy is off).
      final at = _pingedAt;
      if (!_noAccounts &&
          (at == null || DateTime.now().difference(at) > _pingStale)) {
        unawaited(_test());
      }
    } on CoreApiException catch (e) {
      if (mounted) showError(context, e.message);
    } on CoreUnavailable {
      // The shell shows it.
    }
  }

  /// The countries the user connected through, newest first; [code] joins
  /// the top and the list is cut to six.
  void _remember(String code) {
    if (code.isEmpty || code == 'fastest') return;
    final next = [
      code,
      for (final c in widget.settings.recentServers)
        if (c != code) c,
    ].take(6).toList();
    widget.settings.update(recentServers: next);
  }

  Future<void> _choose(String country) async {
    if (_busy != null || _country.toLowerCase() == country.toLowerCase()) {
      return;
    }
    setState(() => _busy = country);
    final ok = await runShowingErrors(
      context,
      () => _core.setLocation(country),
    );
    if (!mounted) return;
    setState(() {
      _busy = null;
      if (ok) _country = country;
    });
    if (ok) _remember(country);
  }

  Future<void> _test() async {
    final l = AppLocalizations.of(context);
    final codes = [
      for (final loc in _locations ?? const <Location>[]) loc.code,
    ];
    setState(() {
      _testing = true;
      _summary = null;
    });
    try {
      final result = await _core.call((api) => api.pingLocations(codes));
      final tested = {for (final loc in result.locations) loc.code: loc};
      if (!mounted) return;
      setState(() {
        _locations = [
          for (final loc in _locations ?? const <Location>[])
            tested[loc.code] ?? loc,
        ];
        _pingedAt = result.pingedAt ?? DateTime.now();
        final answered = result.locations.where((loc) => loc.answered).length;
        _summary = l.delaySummary(answered, result.locations.length);
      });
    } on CoreApiException {
      // The core's own words are for the log; the user gets what to do.
      if (mounted) showError(context, l.delayTestFailed);
    } on CoreUnavailable catch (e) {
      if (mounted) showError(context, describeProblem(l, e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Every country, without Mozilla's recommended location (its own
  /// choice is above), quickest first, then by name in the app's
  /// language.
  List<Location> _countries(AppLocalizations l) {
    final list = [
      for (final loc in _locations ?? const <Location>[])
        if (!isRecommendedPlace(loc.code)) loc,
    ];
    list.sort((a, b) {
      final da = a.answered ? a.pingMs : 1 << 30;
      final db = b.answered ? b.pingMs : 1 << 30;
      if (da != db) return da.compareTo(db);
      return nameSortKey(
        l.localeName,
        locationName(l, a.code, a.name),
      ).compareTo(nameSortKey(l.localeName, locationName(l, b.code, b.name)));
    });
    return list;
  }

  /// Whether [loc] matches the search box, by name, city, or code.
  bool _matches(AppLocalizations l, Location loc) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return locationName(l, loc.code, loc.name).toLowerCase().contains(q) ||
        loc.city.toLowerCase().contains(q) ||
        loc.code.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chosen = _country.toLowerCase();
    final all = _countries(l);
    final visible = all.where((loc) => _matches(l, loc)).toList();
    // The quick picks: the four quickest that answered, out of what the
    // search leaves, without the chosen one.
    final quick = [
      for (final loc in visible)
        if (loc.answered && loc.code.toLowerCase() != chosen) loc,
    ].take(4).toList();
    final quickCodes = {for (final loc in quick) loc.code};
    final rest = [
      for (final loc in visible) if (!quickCodes.contains(loc.code)) loc,
    ];
    final recents = [
      for (final code in widget.settings.recentServers)
        for (final loc in all)
          if (loc.code == code) loc,
    ];
    final delayLine =
        _summary ??
        (_pingedAt == null ? null : l.testedAgo(formatAgo(l, _pingedAt!)));
    final noAccounts = _noAccounts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 116),
      children: [
        PageTitle(l.navServers),
        const SizedBox(height: 6),
        SearchField(
          hint: l.searchServers,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (noAccounts) ...[
          const SizedBox(height: 14),
          NoAccountsPanel(
            onAdd: () => startAddAccount(context, _core, widget.settings),
          ),
        ],
        const SizedBox(height: 16),
        SectionLabel(
          l.autoSection,
          trailing: _testButton(context),
        ),
        // The two automatic choices, each on its own full-width card: side
        // by side they squeezed their names into half a card and cut them
        // off ("Reco…"); one per row, every name reads whole.
        MotionStagger(
          offset: const Offset(0, 10),
          padBetween: 8,
          children: [
            ChoiceTile(
              icon: Icons.auto_awesome_rounded,
              name: l.modeRecommended,
              subtitle: l.modeRecommendedHint,
              selected: chosen == '',
              busy: _busy == '',
              onTap: () => _choose(''),
            ),
            ChoiceTile(
              icon: Icons.bolt_rounded,
              name: l.modeFastest,
              subtitle: l.modeFastestHint,
              selected: chosen == 'fastest',
              busy: _busy == 'fastest',
              onTap: () => _choose('fastest'),
            ),
          ],
        ),
        if (recents.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionLabel(l.recentServers),
          MotionStagger(
            offset: const Offset(0, 12),
            padBetween: 8,
            children: [
              for (final loc in recents.take(4))
                _serverTile(context, loc, selected: chosen == loc.code.toLowerCase()),
            ],
          ),
        ],
        if (quick.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionLabel(l.quickPicks),
          MotionStagger(
            offset: const Offset(0, 12),
            padBetween: 8,
            children: [
              for (final loc in quick)
                _serverTile(context, loc, selected: chosen == loc.code.toLowerCase()),
            ],
          ),
        ],
        const SizedBox(height: 20),
        SectionLabel(
          l.allCountries,
          trailing: delayLine == null
              ? null
              : Text(
                  delayLine,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Dali.onVar(context),
                  ),
                ),
        ),
        if (_locations == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rest.isEmpty && quick.isEmpty)
          DaliCard(
            child: Text(
              _query.trim().isEmpty ? l.noServers : l.noSearchResults,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Dali.onVar(context),
              ),
            ),
          )
        else
          MotionStagger(
            offset: const Offset(0, 12),
            padBetween: 8,
            children: [
              for (final loc in rest)
                _serverTile(context, loc, selected: chosen == loc.code.toLowerCase()),
            ],
          ),
      ],
    );
  }

  /// The delay test, at the automatic section's side.
  Widget _testButton(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IconButton(
      tooltip: _testing ? l.testingDelay : l.testDelay,
      onPressed: !_testing && _locations != null && !_noAccounts
          ? _test
          : null,
      icon: _testing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.speed_rounded, size: 20),
      color: Dali.onVar(context),
    );
  }

  /// One country's card, wired to choose it.
  Widget _serverTile(BuildContext context, Location loc, {required bool selected}) {
    final l = AppLocalizations.of(context);
    final code = loc.code.toLowerCase();
    return ServerTile(
      leading: CountryFlag(code: loc.code, width: 40),
      name: locationName(l, loc.code, loc.name),
      subtitle: loc.city.isNotEmpty && loc.city != loc.name ? loc.city : null,
      ms: loc.answered ? loc.pingMs : null,
      testing: _testing,
      selected: selected,
      busy: _busy?.toLowerCase() == code,
      connectLabel: l.connectAction,
      connectedLabel: l.stateConnected,
      onTap: () => _choose(loc.code),
    );
  }
}
