import 'dart:io';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../core/core_controller.dart';
import '../core/updates.dart';
import '../l10n/app_localizations.dart';
import 'about_page.dart';
import 'accounts_page.dart';
import 'design.dart';
import 'details_screen.dart';
import 'floating_nav.dart';
import 'home_screen.dart';
import 'logs_page.dart';
import 'motion.dart';
import 'servers_screen.dart';
import 'settings_page.dart';
import 'speedtest_screen.dart';
import 'update_dialog.dart';
import 'widgets.dart';

/// The phone layout, built from the approved design: four tabs — Home,
/// Servers, Speed test, and Settings. The rest (accounts, each group of
/// settings, the logs, about, the connection's details) opens as a page
/// of its own with the system's back button. The tabs sit in a capsule
/// that floats above the bottom edge, and every change of page slides,
/// fades and settles.
class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.core,
    required this.settings,
    required this.banner,
    this.noCore,
  });

  final CoreController core;
  final AppSettings settings;

  /// Shown above the page when the core stopped answering.
  final Widget? banner;

  /// Shown in place of the pages until the core first answers.
  final Widget? noCore;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int _tab = 0;

  /// The versions the update dialog spoke of in this run: each is told
  /// once, until a newer one is found.
  static final _offeredUpdates = <String>{};

  @override
  void initState() {
    super.initState();
    // A newer version, found by the hourly look or kept from the last
    // run: the phone hears of it in the update's dialog, in its own
    // language, with the download inside the app. The computers keep
    // their own way: their core downloads and installs by itself.
    if (Platform.isAndroid) {
      Updates.available.addListener(_maybeOfferUpdate);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      Updates.available.removeListener(_maybeOfferUpdate);
    }
    super.dispose();
  }

  void _maybeOfferUpdate() {
    final release = Updates.available.value;
    final settings = widget.settings;
    if (release == null || release.version == settings.dismissedUpdate) return;
    if (!_offeredUpdates.add(release.version)) return;
    if (!mounted) return;
    showUpdateDialog(
      context,
      release: release,
      core: widget.core,
      settings: settings,
    );
  }

  /// Opens [page] under a top bar named [title]; it follows the core, and
  /// slides in from the reading direction's side. The title sits centered,
  /// as the approved design's pushed pages do.
  void _push(String title, Widget Function() page) {
    Navigator.of(context).push(
      FaliRoute<void>(
        builder: (context) => ListenableBuilder(
          listenable: widget.core,
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: Text(title), centerTitle: true),
            body: SafeArea(
              top: false,
              child: OwnTopBar(child: _readable(page())),
            ),
          ),
        ),
      ),
    );
  }

  /// [page] no wider than a line can be read on a tablet; the home page
  /// keeps the whole width for its colors and limits its own content.
  static Widget _readable(Widget page) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: page,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final core = widget.core;
    final settings = widget.settings;
    void openAccounts() => _push(
      l.navAccounts,
      () => AccountsPage(core: core, settings: settings),
    );
    void openConnection() => _push(
      l.sectionConnection,
      () => SettingsPage(
        core: core,
        settings: settings,
        section: SettingsSection.connection,
      ),
    );
    void openUpstreamProxy() => _push(
      l.upstreamProxy,
      () => SettingsPage(
        core: core,
        settings: settings,
        section: SettingsSection.upstreamProxy,
      ),
    );
    void openDetails() =>
        _push(l.connectionDetails, () => DetailsScreen(core: core));
    final page =
        widget.noCore ??
        (_tab == 0
            ? HomeScreen(
                core: core,
                settings: settings,
                onOpenDetails: openDetails,
                onOpenServers: () => setState(() => _tab = 1),
                onOpenAccounts: openAccounts,
                onOpenConnection: openConnection,
                onOpenUpstreamProxy: openUpstreamProxy,
              )
            : _readable(
                switch (_tab) {
                  1 => ServersScreen(core: core, settings: settings),
                  2 => SpeedTestScreen(core: core),
                  _ => _SettingsList(
                      core: core,
                      settings: settings,
                      openAccounts: openAccounts,
                      openServers: () => setState(() => _tab = 1),
                      push: _push,
                    ),
                },
              ));
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: SafeArea(
          // The home page's hero reaches under the status bar.
          top: _tab != 0 || widget.noCore != null || widget.banner != null,
          child: Column(
            children: [
              if (widget.banner != null)
                DropInBanner(visible: true, child: widget.banner!),
              Expanded(
                child: SlideFadeSwitcher(
                  child: KeyedSubtree(
                    // A tab change, not a traffic tick, is what slides.
                    key: ValueKey((_tab, widget.noCore != null)),
                    child: page,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _themed(
          context,
          // The dark home page has its own night colors.
          home:
              _tab == 0 &&
              widget.noCore == null &&
              Theme.of(context).brightness == Brightness.dark,
          child: FloatingNavBar(
            selectedIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
            destinations: [
              FloatingNavDestination(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: l.navHome,
              ),
              FloatingNavDestination(
                icon: Icons.public_outlined,
                selectedIcon: Icons.public_rounded,
                label: l.navServers,
              ),
              FloatingNavDestination(
                icon: Icons.speed_outlined,
                selectedIcon: Icons.speed_rounded,
                label: l.navSpeedTest,
              ),
              FloatingNavDestination(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                label: l.navSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The home page's midnight theme around [child] while home shows.
  Widget _themed(
    BuildContext context, {
    required bool home,
    required Widget child,
  }) => home
      ? Theme(data: midnightTheme(Theme.of(context)), child: child)
      : child;
}

/// The Settings tab, in the design language: the groups as cards, each
/// row with its icon tile, its name, and the chevron; every row opens its
/// own page.
class _SettingsList extends StatelessWidget {
  const _SettingsList({
    required this.core,
    required this.settings,
    required this.openAccounts,
    required this.openServers,
    required this.push,
  });

  final CoreController core;
  final AppSettings settings;
  final VoidCallback openAccounts;
  final VoidCallback openServers;
  final void Function(String title, Widget Function() page) push;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 116),
      children: [
        PageTitle(l.settingsTitle),
        const SizedBox(height: 6),
        // Language and theme first, what someone looks for before anything
        // else, with which country and account; then how the traffic goes,
        // what helps when Mozilla is blocked, and the app itself.
        _group(context, l.sectionGeneral, [
          _row(
            context,
            Icons.tune_rounded,
            Dali.primary,
            l.sectionGeneral,
            () => push(
              l.sectionGeneral,
              () => SettingsPage(
                core: core,
                settings: settings,
                section: SettingsSection.general,
              ),
            ),
          ),
          _row(
            context,
            Icons.public_rounded,
            StatusColors.good,
            l.navServers,
            openServers,
          ),
          _row(
            context,
            Icons.people_rounded,
            Dali.amber,
            l.navAccounts,
            openAccounts,
          ),
        ]),
        const SizedBox(height: 16),
        _group(context, l.groupNetwork, [
          _row(
            context,
            Icons.vpn_lock_rounded,
            Dali.primary,
            l.sectionConnection,
            () => push(
              l.sectionConnection,
              () => SettingsPage(
                core: core,
                settings: settings,
                section: SettingsSection.connection,
              ),
            ),
          ),
          _row(
            context,
            Icons.alt_route_rounded,
            StatusColors.good,
            l.sectionRouting,
            () => push(
              l.sectionRouting,
              () => SettingsPage(
                core: core,
                settings: settings,
                section: SettingsSection.routing,
              ),
            ),
          ),
          _row(
            context,
            Icons.dns_rounded,
            Dali.amber,
            l.sectionDns,
            () => push(
              l.sectionDns,
              () => SettingsPage(
                core: core,
                settings: settings,
                section: SettingsSection.dns,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _group(context, l.sectionBypass, [
          _row(
            context,
            Icons.cloud_rounded,
            Dali.primary,
            l.apiRelay,
            () => push(
              l.apiRelay,
              () => SettingsPage(
                core: core,
                settings: settings,
                section: SettingsSection.relay,
              ),
            ),
          ),
          _row(
            context,
            Icons.content_cut_rounded,
            StatusColors.good,
            l.tlsFragment,
            () => push(
              l.tlsFragment,
              () => SettingsPage(
                core: core,
                settings: settings,
                section: SettingsSection.fragment,
              ),
            ),
          ),
          _row(
            context,
            Icons.lan_rounded,
            Dali.amber,
            l.upstreamProxy,
            () => push(
              l.upstreamProxy,
              () => SettingsPage(
                core: core,
                settings: settings,
                section: SettingsSection.upstreamProxy,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _group(context, l.groupApp, [
          // The app's port and the web dashboard: computers only (a narrow
          // window shows this layout too).
          if (!Platform.isAndroid)
            _row(
              context,
              Icons.build_rounded,
              Dali.primary,
              l.sectionAdvanced,
              () => push(
                l.sectionAdvanced,
                () => SettingsPage(
                  core: core,
                  settings: settings,
                  section: SettingsSection.advanced,
                ),
              ),
            ),
          _row(
            context,
            Icons.receipt_long_rounded,
            StatusColors.good,
            l.navLogs,
            () => push(l.navLogs, () => LogsPage(core: core)),
          ),
          _row(
            context,
            Icons.info_rounded,
            Dali.amber,
            l.navAbout,
            () => push(
              l.navAbout,
              () => AboutPage(core: core, settings: settings),
            ),
          ),
        ]),
      ],
    );
  }

  /// One titled card of rows, divided by thin lines.
  Widget _group(BuildContext context, String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        DaliCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// One row: the icon in its tinted tile, the name, and the chevron that
  /// mirrors itself in right-to-left languages.
  Widget _row(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconTile(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Dali.onVar(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
