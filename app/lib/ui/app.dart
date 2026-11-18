import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'about_page.dart';
import 'accounts_page.dart';
import 'focus_ring.dart';
import 'format.dart';
import 'logs_page.dart';
import 'mobile_shell.dart';
import 'motion.dart';
import 'overview_page.dart';
import 'port_dialog.dart';
import 'servers_page.dart';
import 'settings_page.dart';
import 'welcome_page.dart';
import 'widgets.dart';

/// The app's theme, built to read like Google Pixel's Material You: the
/// electric blue accent over near-white blue-tinted surfaces by day and
/// deep navy ones at night, big 26-pixel rounded cards, pill buttons, and
/// the state colors of Google's palette. Vazirmatn for Persian and Arabic;
/// the system font (Segoe UI, Roboto) otherwise. Styles set here name the
/// font too, or they would fall back to the system font.
ThemeData _theme(Brightness brightness, Locale locale) {
  final dark = brightness == Brightness.dark;
  final font = languageFont(locale.languageCode);
  final scheme = ColorScheme.fromSeed(
    seedColor: PixelAccent.blue,
    brightness: brightness,
  ).copyWith(
          // The Pixel surfaces: near-white with a breath of blue by day,
          // deep navy at night.
          surface: dark ? const Color(0xFF0E1420) : const Color(0xFFF5F8FE),
          surfaceContainerLowest: dark ? const Color(0xFF0B111C) : Colors.white,
          surfaceContainerLow: dark ? const Color(0xFF121926) : const Color(0xFFF8FAFF),
          surfaceContainer: dark ? const Color(0xFF171E2C) : Colors.white,
          surfaceContainerHigh: dark ? const Color(0xFF1D2534) : const Color(0xFFEDF2FC),
          surfaceContainerHighest: dark ? const Color(0xFF242E40) : const Color(0xFFE2EAF8),
          onSurface: dark ? const Color(0xFFE6ECF6) : const Color(0xFF1A1D24),
          onSurfaceVariant: dark ? const Color(0xFF9AA6BC) : const Color(0xFF5B6474),
          primaryContainer: dark
              ? PixelAccent.darkContainer
              : PixelAccent.lightContainer,
          onPrimaryContainer: dark
              ? PixelAccent.darkOnContainer
              : PixelAccent.lightOnContainer,
        );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: font,
    splashFactory: InkSparkle.splashFactory,
    scaffoldBackgroundColor: scheme.surface,
    // A partial text theme: what it does not name keeps Material's
    // brightness-appropriate default. Google Sans's spirit: bold titles,
    // comfortable reading.
    textTheme: TextTheme(
      headlineMedium: TextStyle(fontFamily: font, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontFamily: font, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontFamily: font, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(fontFamily: font, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontFamily: font, height: 1.5),
      bodyMedium: TextStyle(fontFamily: font, height: 1.45),
      bodySmall: TextStyle(fontFamily: font, height: 1.4),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFF0B3B78).withValues(alpha: 0.05),
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 74,
      backgroundColor: dark ? Midnight.nav : scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: dark
          ? PixelAccent.darkContainer
          : PixelAccent.lightContainer,
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: scheme.onSurfaceVariant, size: 24),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: font,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    ),
    // Pages the Navigator pushes slide in Material's newest way: the old
    // page fades forward, the new one glides the rest of the way.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xFF10161F) : const Color(0xFFEFF3FB),
      indicatorColor: dark
          ? PixelAccent.darkContainer
          : PixelAccent.lightContainer,
      indicatorShape: const StadiumBorder(),
      // The menu's names semi-bold, the open page's bold.
      selectedLabelTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      selectedIconTheme: IconThemeData(
        size: 24,
        color: dark
            ? PixelAccent.darkOnContainer
            : PixelAccent.lightOnContainer,
      ),
      unselectedIconTheme: IconThemeData(
        size: 24,
        color: scheme.onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        // Pixel's buttons are full pills.
        shape: const StadiumBorder(),
        minimumSize: const Size(58, 46),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(58, 46),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: TextStyle(
          fontFamily: font,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: font,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh.withValues(alpha: dark ? 1 : 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: dark ? const Color(0xFF1A2130) : Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: (dark ? Colors.white : const Color(0xFF0B3B78)).withValues(
        alpha: dark ? 0.08 : 0.06,
      ),
      thickness: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    ),
  );
}

class VpnApp extends StatelessWidget {
  const VpnApp({
    super.key,
    required this.core,
    required this.settings,
    this.navigatorKey,
  });

  final CoreController core;
  final AppSettings settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) =>
          AppSettings.localeOf(AppSettings.languageForList(locales)),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The theme depends on the resolved language for its font.
      builder: (context, child) {
        final locale = Localizations.localeOf(context);
        final dark = switch (settings.themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        return Theme(
          data: _theme(dark ? Brightness.dark : Brightness.light, locale),
          // A clear ring around what a remote or the keyboard chose.
          child: FocusRing(
            atStart: Platform.isAndroid && AndroidCore.isTv,
            child: child!,
          ),
        );
      },
      home: Shell(core: core, settings: settings),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.core, required this.settings});

  final CoreController core;
  final AppSettings settings;

  @override
  State<Shell> createState() => _ShellState();
}

enum _Page { overview, servers, accounts, settings, logs, about }

class _ShellState extends State<Shell> {
  _Page _page = _Page.overview;

  /// The settings section the home page opened (Connection), until another
  /// page is chosen.
  SettingsSection? _settingsOpening;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.core,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final core = widget.core;
      final status = core.status;
      final needsAttention = (core.accounts?.accounts ?? const [])
          .where((a) => a.enabled && a.needsSignIn)
          .length;
      if (widget.settings.firstRun && status != null) {
        return WelcomePage(core: core, settings: widget.settings);
      }
      final pages = [
        _Page.overview,
        _Page.servers,
        _Page.accounts,
        _Page.settings,
        _Page.logs,
        _Page.about,
      ];
      final page = pages.contains(_page) ? _page : _Page.overview;
      Widget accountsIcon(IconData icon) => Badge(
        isLabelVisible: needsAttention > 0,
        label: Text('$needsAttention'),
        child: Icon(icon),
      );
      // Each page's icons and name, for the side menu and the bottom bar.
      final items = [
        for (final page in pages)
          switch (page) {
            _Page.overview => (
              const Icon(Icons.dashboard_outlined),
              const Icon(Icons.dashboard_rounded),
              l.navOverview,
            ),
            _Page.servers => (
              const Icon(Icons.public_outlined),
              const Icon(Icons.public_rounded),
              l.navServers,
            ),
            _Page.accounts => (
              accountsIcon(Icons.people_outline_rounded),
              accountsIcon(Icons.people_rounded),
              l.navAccounts,
            ),
            _Page.settings => (
              const Icon(Icons.settings_outlined),
              const Icon(Icons.settings_rounded),
              l.navSettings,
            ),
            _Page.logs => (
              const Icon(Icons.receipt_long_outlined),
              const Icon(Icons.receipt_long_rounded),
              l.navLogs,
            ),
            _Page.about => (
              const Icon(Icons.info_outline_rounded),
              const Icon(Icons.info_rounded),
              l.navAbout,
            ),
          },
      ];
      final content = Column(
        children: [
          DropInBanner(
            visible: core.unavailable != null && status != null,
            child: const _LostBanner(),
          ),
          Expanded(
            child: status == null
                ? _NoCore(core: core)
                : SlideFadeSwitcher(
                    child: KeyedSubtree(
                      // The key: a page change, not a traffic tick, swaps
                      // with the slide.
                      key: ValueKey((page, _settingsOpening)),
                      child: switch (page) {
                        // Its cards open the pages beside it.
                        _Page.overview => OverviewPage(
                          core: core,
                          settings: widget.settings,
                          onOpenServers: () =>
                              setState(() => _page = _Page.servers),
                          onOpenAccounts: () =>
                              setState(() => _page = _Page.accounts),
                          onOpenConnection: () => setState(() {
                            _page = _Page.settings;
                            _settingsOpening = SettingsSection.connection;
                          }),
                          onOpenUpstreamProxy: () => setState(() {
                            _page = _Page.settings;
                            _settingsOpening = SettingsSection.upstreamProxy;
                          }),
                        ),
                        _Page.servers => ServersPage(
                          core: core,
                          settings: widget.settings,
                        ),
                        _Page.accounts => AccountsPage(
                          core: core,
                          settings: widget.settings,
                        ),
                        _Page.settings => SettingsPage(
                          key: ValueKey(_settingsOpening),
                          core: core,
                          settings: widget.settings,
                          opening: _settingsOpening,
                          onOpenLogs: () =>
                              setState(() => _page = _Page.logs),
                        ),
                        _Page.logs => LogsPage(
                          core: core,
                          settings: widget.settings,
                        ),
                        _Page.about => AboutPage(core: core),
                      },
                    ),
                  ),
          ),
        ],
      );
      void select(int i) => setState(() {
        _page = pages[i];
        _settingsOpening = null;
      });
      // Android (a phone, or a tablet in either orientation) and a narrow
      // window: the phone layout, Home and Settings. The computer layout
      // offers computer-only choices, such as Windows' system proxy.
      if (Platform.isAndroid || MediaQuery.sizeOf(context).width < 640) {
        return MobileShell(
          core: core,
          settings: widget.settings,
          banner: core.unavailable != null && status != null
              ? const _LostBanner()
              : null,
          noCore: status == null ? _NoCore(core: core) : null,
        );
      }
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: pages.indexOf(page),
              onDestinationSelected: select,
              // Icons with their names beside them.
              extended: true,
              minExtendedWidth: 190,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Row(
                  children: [
                    const AppLogo(size: 34),
                    const SizedBox(width: 10),
                    Text(
                      l.appTitle,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (final (icon, selected, label) in items)
                  NavigationRailDestination(
                    icon: icon,
                    selectedIcon: selected,
                    label: Text(label),
                  ),
              ],
              // The traffic at the bottom of the menu; in a short window the
              // pages above it scroll rather than run under it.
              trailing: _TrafficPanel(traffic: status?.traffic),
              trailingAtBottom: true,
              scrollable: true,
            ),
            // A maximized window: the pages stay as wide as reads well; the
            // home page, centered by itself, keeps its colors to the edges.
            Expanded(
              child: page == _Page.overview || status == null
                  ? content
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: content,
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

/// The side menu's traffic: the speed now and the total since the core
/// started, through Mozilla, up and down.
class _TrafficPanel extends StatelessWidget {
  const _TrafficPanel({required this.traffic});

  final Traffic? traffic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = traffic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: SizedBox(
        width: 166,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TrafficCard(
              title: l.liveTraffic,
              up: formatRate(t?.upRate ?? 0),
              down: formatRate(t?.downRate ?? 0),
            ),
            const SizedBox(height: 8),
            _TrafficCard(
              title: l.totalTraffic,
              up: formatBytes(t?.up ?? 0),
              down: formatBytes(t?.down ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({
    required this.title,
    required this.up,
    required this.down,
  });

  final String title;
  final String up;
  final String down;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget line(IconData icon, Color color, String text) => Row(
      children: [
        Icon(icon, size: 14, color: color),
        const Spacer(),
        Text(text, style: value),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          line(Icons.arrow_upward_rounded, StatusColors.good, up),
          line(Icons.arrow_downward_rounded, theme.colorScheme.primary, down),
        ],
      ),
    );
  }
}

class _LostBanner extends StatelessWidget {
  const _LostBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: StatusColors.bad.withValues(alpha: 0.14),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.link_off_rounded, size: 18, color: StatusColors.bad),
        const SizedBox(width: 10),
        Expanded(child: Text(AppLocalizations.of(context).coreLost)),
      ],
    ),
  );
}

class _NoCore extends StatelessWidget {
  const _NoCore({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problem = core.unavailable;
    final portTaken =
        problem != null &&
        (problem.problem == CoreProblem.portInUse ||
            problem.problem == CoreProblem.refused);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (problem == null || problem.problem == CoreProblem.starting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.startingCore, style: theme.textTheme.titleMedium),
            ] else ...[
              Icon(
                Icons.power_off_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(l.cantReachCore, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                describeProblem(l, problem),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (portTaken && core.moveStoppedCore != null)
                    FilledButton.icon(
                      onPressed: () async {
                        final port = await showPortDialog(
                          context,
                          taken: problem.detail,
                        );
                        if (port != null && context.mounted) {
                          await runShowingErrors(
                            context,
                            () => core.setAppPort(port),
                          );
                        }
                      },
                      icon: const Icon(Icons.settings_ethernet_rounded),
                      label: Text(l.changePort),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: core.retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l.retry),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
