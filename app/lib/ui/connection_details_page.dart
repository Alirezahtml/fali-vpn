import 'package:flutter/material.dart';

import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'motion.dart';
import 'speed_gauge.dart';
import 'widgets.dart';
import 'world_map.dart';

/// The connection details: the map with the live path on it, the gauge of
/// the speed now, and the figures of this connection — the exit IP, the
/// country it is in, the network it belongs to, and how long it has run.
class ConnectionDetailsPage extends StatefulWidget {
  const ConnectionDetailsPage({super.key, required this.core});

  final CoreController core;

  @override
  State<ConnectionDetailsPage> createState() => _ConnectionDetailsPageState();
}

class _ConnectionDetailsPageState extends State<ConnectionDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: widget.core,
      builder: (context, _) {
        final status = widget.core.status;
        final proxy = status?.proxy;
        final exit = status?.exit;
        final traffic = status?.traffic;
        final connected = status?.state.phase == Phase.running &&
            (status?.proxyOn ?? false);
        final country = proxy?.countryName ?? '';
        final city = proxy?.cityName ?? '';
        final exitCode = proxy?.countryCode ?? '';
        return ListView(
          padding: pagePadding(context),
          children: [
            PageTitle(l.detailsTitle),
            MotionEntrance(
              offset: const Offset(0, 14),
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 168,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: WorldMap(
                          dotColor: scheme.onSurfaceVariant.withValues(alpha: 0.30),
                          homeColor: scheme.tertiary,
                          exitColor: scheme.primary,
                          exitCode: exitCode,
                          connected: connected,
                        ),
                      ),
                      if (country.isNotEmpty)
                        Positioned.directional(
                          textDirection: Directionality.of(context),
                          start: 10,
                          bottom: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CountryFlag(code: exitCode, width: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    city.isNotEmpty && city != country
                                        ? '$country، $city'
                                        : country,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            MotionEntrance(
              offset: const Offset(0, 14),
              delay: Motion.staggerStep,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: SpeedGauge(
                    mbps: (traffic?.downRate ?? 0) / 125000,
                    maxMbps: 1000,
                    label: l.downloadRate,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            MotionEntrance(
              offset: const Offset(0, 14),
              delay: Motion.staggerStep * 2,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.timer_outlined,
                        title: l.connectedFor,
                        child: ConnectedTimer(
                          startedAt: proxy?.startedAt,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (exit?.ipv4.isNotEmpty ?? false)
                        _InfoRow(
                          icon: Icons.vpn_lock_rounded,
                          title: l.exitIp,
                          child: SelectableText(
                            ltr(exit!.ipv4),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      if (exit?.ipv6.isNotEmpty ?? false)
                        _InfoRow(
                          icon: Icons.alternate_email_rounded,
                          title: l.exitIp6,
                          child: SelectableText(
                            ltr(exit!.ipv6),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      if (exit?.countryName.isNotEmpty ?? false)
                        _InfoRow(
                          icon: Icons.public_rounded,
                          title: l.exitPlace,
                          child: Row(
                            children: [
                              CountryFlag(
                                code: exit!.countryCode,
                                width: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                exit.city.isNotEmpty && exit.city != exit.countryName
                                    ? '${exit.countryName}، ${exit.city}'
                                    : exit.countryName,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      if (exit?.network.isNotEmpty ?? false)
                        _InfoRow(
                          icon: Icons.lan_rounded,
                          title: l.exitNetwork,
                          child: Flexible(
                            child: Text(
                              exit!.network,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if ((proxy?.transport.isNotEmpty ?? false))
                        _InfoRow(
                          icon: Icons.settings_ethernet_rounded,
                          title: l.protocol,
                          child: Text(
                            proxy!.transport,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

/// One figure of the connection: an icon, its name, and its value.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          IconBadge(icon, color: scheme.primary),
          const SizedBox(width: 14),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(child: child),
        ],
      ),
    );
  }
}
