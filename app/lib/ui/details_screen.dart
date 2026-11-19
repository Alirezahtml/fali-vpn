import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'design.dart';
import 'format.dart';
import 'motion.dart';
import 'speed_gauge.dart' show SpeedGauge;
import 'widgets.dart';

/// The connection's details, built from the approved design: the two IP
/// cards, the download dial, the upload and download rates, the
/// connection's rows (its age, the city, the delay), and the data moved.
class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.core});

  final CoreController core;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  /// The phone's own address on its network, read from its interfaces;
  /// the address websites see is the server's, and it is the other card.
  String _localIp = '';

  @override
  void initState() {
    super.initState();
    _readLocalIp();
  }

  Future<void> _readLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      if (!mounted) return;
      setState(() {
        _localIp = interfaces.isEmpty
            ? ''
            : interfaces.first.addresses.first.address;
      });
    } on SocketException {
      // No interfaces to name: the card stays empty.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final core = widget.core;
    final status = core.status!;
    final connected = status.proxyOn && status.state.phase == Phase.running;
    final proxy = status.proxy;
    final traffic = status.traffic;
    final test = status.isCurrentTest(core.lastTest) ? core.lastTest : null;
    final pingMs = connected && test?.ok == true ? test!.responseMs : null;
    final persian = l.localeName == 'fa';
    final downMbps = mbpsFrom(traffic?.downRate ?? 0);
    final scale = niceCeil(math.max(downMbps * 1.25, 1.0));
    final down = traffic?.down ?? 0;
    final up = traffic?.up ?? 0;
    final total = down + up;
    final city = proxy?.cityName.isNotEmpty ?? false
        ? proxy!.cityName
        : (status.exit?.city ?? '');
    final vpnIp = connected
        ? (status.exit?.ipv4.isNotEmpty ?? false
              ? status.exit!.ipv4
              : (status.exit?.ipv6 ?? ''))
        : '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        MotionStagger(
          offset: const Offset(0, 14),
          padBetween: 12,
          children: [
            // The two addresses in one card, the way the design draws it:
            // the phone's own, an arrow through a bright bead, and the one
            // the websites see (the server's), in the blue while
            // connected.
            DaliCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Expanded(child: _ipCard(context, l.localIp, _localIp, false)),
                  _hopArrow(context, connected),
                  Expanded(
                    child: _ipCard(context, l.vpnIp, vpnIp, connected),
                  ),
                ],
              ),
            ),
            DaliCard(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Column(
                children: [
                  ArcDial(
                    fraction: downMbps / scale,
                    valueText: SpeedGauge.speedText(downMbps, persian: persian),
                    unitText: l.megabitUnit,
                    caption: l.downloadRate,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: DaliCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        IconTile(
                          icon: Icons.arrow_downward_rounded,
                          color: Dali.primary,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.downloadRate,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Dali.onVar(context),
                                ),
                              ),
                              Text(
                                formatRate(traffic?.downRate ?? 0),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DaliCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        IconTile(
                          icon: Icons.arrow_upward_rounded,
                          color: StatusColors.good,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.uploadRate,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Dali.onVar(context),
                                ),
                              ),
                              Text(
                                formatRate(traffic?.upRate ?? 0),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            DaliCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  InfoRow(
                    label: l.connectedFor,
                    value: ConnectedTimer(
                      startedAt: proxy?.startedAt,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  InfoRow(
                    label: l.cityLabel,
                    value: Text(
                      city.isEmpty ? '—' : city,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  InfoRow(
                    label: l.pingLabel,
                    value: PingChip(ms: pingMs),
                  ),
                ],
              ),
            ),
            DaliCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.downloadRate,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Dali.onVar(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatBytes(down),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.uploadRate,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Dali.onVar(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatBytes(up),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LoadBar(
                    label: l.dataVolume,
                    value: formatBytes(total),
                    fraction: total > 0 ? down / total : 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// One address card: the name in the muted ink, the address under it;
  /// the VPN's card in the blue container while connected.
  Widget _ipCard(BuildContext context, String label, String value, bool accent) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent
            ? (dark ? const Color(0xFF284E7E) : const Color(0xFFD6E4FF))
            : Dali.surface2(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent
              ? Dali.primary.withValues(alpha: dark ? 0.55 : 0.35)
              : Dali.hairline(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent
                  ? (dark ? const Color(0xFFD6E4FF) : const Color(0xFF0B3B78))
                  : Dali.onVar(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '—' : ltr(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [],
            ),
          ),
        ],
      ),
    );
  }

  /// The arrow between the two addresses: a little bead that brightens
  /// while the VPN carries the traffic between them. It points from the
  /// phone's card to the server's card, whichever side each sits on in
  /// the page's reading direction.
  Widget _hopArrow(BuildContext context, bool connected) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected
                  ? Dali.wash(Dali.primary, theme.brightness == Brightness.dark)
                  : Dali.surface3(context),
            ),
            child: Icon(
              rtl
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              size: 15,
              color: connected ? Dali.primary : Dali.onVar(context),
            ),
          ),
        ],
      ),
    );
  }
}
