import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/core_controller.dart';
import '../l10n/app_localizations.dart';
import 'design.dart';
import 'format.dart';
import 'speed_gauge.dart' show SpeedGauge;
import 'widgets.dart';

/// The speed test, built from the approved design: the dotted dial with
/// the reading, the wide blue start button, the last test's three boxes,
/// and the history. It downloads and uploads real bytes through the
/// tunnel (the VPN carries the app's traffic, so plain HTTP measures the
/// VPN's path) and keeps the last runs in a small file beside the core's
/// own data.
class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key, required this.core});

  final CoreController core;

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  static const _downUrl = 'https://speed.cloudflare.com/__down?bytes=31457280';
  static const _pingUrl = 'https://speed.cloudflare.com/__down?bytes=0';
  static const _downFallback = 'https://proof.ovh.net/files/100Mb.dat';
  static const _upUrl = 'https://speed.cloudflare.com/__up';
  static const _downBudget = Duration(seconds: 14);
  static const _upBudget = Duration(seconds: 8);
  static const _streams = 3;

  bool _running = false;
  double _down = 0;
  double _up = 0;
  int _ping = 0;
  bool _upPhase = false;
  String? _error;
  double _scale = 100;
  List<Map<String, Object?>> _history = [];
  List<HttpClient>? _clients;
  Timer? _ui;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _stop();
    _ui?.cancel();
    super.dispose();
  }

  /// The history lives beside the core's own files, where the app can
  /// write; without a data dir the history stays in memory for the visit.
  File? _historyFile() {
    final dir = widget.core.status?.dataDir ?? '';
    return dir.isEmpty
        ? null
        : File('$dir${Platform.pathSeparator}speed-history.json');
  }

  Future<void> _loadHistory() async {
    final f = _historyFile();
    if (f == null) return;
    try {
      final list = jsonDecode(await f.readAsString()) as List<Object?>;
      if (!mounted) return;
      setState(() {
        _history = [
          for (final e in list) Map<String, Object?>.from(e as Map),
        ];
      });
    } catch (_) {
      // No history yet, or a file that does not parse: the list stays empty.
    }
  }

  Future<void> _saveHistory() async {
    final f = _historyFile();
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode(_history.take(20).toList()));
    } catch (_) {
      // The test result still shows; only the file could not be written.
    }
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    final f = _historyFile();
    if (f != null) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  void _stop() {
    for (final c in _clients ?? const <HttpClient>[]) {
      c.close(force: true);
    }
    _clients = null;
    _ui?.cancel();
    _ui = null;
  }

  /// The time until Cloudflare answers at all: the tunnel's own delay.
  Future<int> _measurePing(HttpClient client) async {
    final watch = Stopwatch()..start();
    final req = await client
        .openUrl('GET', Uri.parse(_pingUrl))
        .timeout(const Duration(seconds: 6));
    await req.close().timeout(const Duration(seconds: 6));
    watch.stop();
    return watch.elapsedMilliseconds;
  }

  /// Sustained download for [_downBudget], from [_streams] parallel files.
  /// The rate shown is the bytes of the last couple of seconds, so the
  /// ramp-up and the finish tail do not bend the number.
  Future<double> _measureDown(HttpClient client) async {
    final total = ValueNotifier<int>(0);
    final samples = <(DateTime, int)>[(DateTime.now(), 0)];
    final deadline = DateTime.now().add(_downBudget);
    final requests = <Future<void>>[];

    Future<void> stream(String url) async {
      try {
        final req = await client.openUrl('GET', Uri.parse(url));
        final res = await req.close();
        await for (final chunk in res) {
          total.value += chunk.length;
          if (DateTime.now().isAfter(deadline)) {
            return;
          }
        }
      } catch (_) {
        // One stream failing leaves the others measuring.
      }
    }

    for (var i = 0; i < _streams; i++) {
      requests.add(stream(i == 1 ? _downFallback : _downUrl));
    }
    final done = Completer<void>();
    _ui = Timer.periodic(const Duration(milliseconds: 120), (_) {
      final now = DateTime.now();
      samples.add((now, total.value));
      if (now.isAfter(deadline) && !done.isCompleted) {
        done.complete();
      }
      if (!mounted) return;
      setState(() {
        _down = _sustained(samples) / 125000;
        // The dial's top grows ahead of the reading, so the arc
        // stays inside while the scale keeps meaning something.
        if (_down > _scale * 0.92) _scale = niceCeil(_down * 1.25);
      });
    });
    await Future.any([done.future, Future.wait(requests)]);
    _ui?.cancel();
    final value = _sustained(samples) / 125000;
    return value;
  }

  /// An upload: random bytes POSTed to Cloudflare's receiver, rate from
  /// the bytes actually sent.
  Future<double> _measureUp(HttpClient client) async {
    final bytes = Uint8List(6 * 1024 * 1024);
    final random = math.Random();
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    final watch = Stopwatch()..start();
    try {
      final req = await client
          .openUrl('POST', Uri.parse(_upUrl))
          .timeout(const Duration(seconds: 6));
      req.headers.contentType = ContentType.binary;
      final sent = req.addStream(Stream.value(bytes)).timeout(_upBudget);
      await req.close();
      await sent;
    } catch (_) {
      // A short upload is still an upload.
    }
    watch.stop();
    final seconds = math.max(watch.elapsedMilliseconds / 1000, 0.3);
    return bytes.length * 8 / 1e6 / seconds;
  }

  /// The bytes a second over the last little while of the samples.
  double _sustained(List<(DateTime, int)> samples) {
    if (samples.length < 2) return 0;
    final (now, nowBytes) = samples.last;
    var (past, pastBytes) = samples.first;
    for (final s in samples.reversed) {
      if (now.difference(s.$1).inMilliseconds >= 2000) {
        (past, pastBytes) = s;
        break;
      }
    }
    final seconds = now.difference(past).inMilliseconds / 1000;
    if (seconds < 0.2) return 0;
    return math.max(0, (nowBytes - pastBytes) / seconds);
  }

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    _clients = [client];
    setState(() {
      _running = true;
      _error = null;
      _down = 0;
      _up = 0;
      _ping = 0;
      _upPhase = false;
      _scale = 100;
    });
    try {
      _ping = await _measurePing(client);
      if (!mounted) return;
      setState(() {});
      final down = await _measureDown(client);
      if (!mounted) return;
      setState(() {
        _down = down;
        _scale = niceCeil(math.max(down * 1.2, 50));
        _upPhase = true;
      });
      final up = await _measureUp(client);
      if (!mounted) return;
      setState(() {
        _up = up;
        _history = [
          {
            'at': DateTime.now().toIso8601String(),
            'down': double.parse(down.toStringAsFixed(1)),
            'up': double.parse(up.toStringAsFixed(1)),
            'ping': _ping,
          },
          ..._history,
        ];
      });
      await _saveHistory();
    } catch (_) {
      if (mounted) setState(() => _error = l.speedFailed);
    } finally {
      _stop();
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final persian = l.localeName == 'fa';
    final shown = _upPhase ? _up : _down;
    final last = _history.isEmpty ? null : _history.first;
    final lastAt = last == null
        ? null
        : DateTime.tryParse(last['at'] as String? ?? '');
    String fig(num? v) => SpeedGauge.speedText(
      (v ?? 0).toDouble(),
      persian: persian,
    );
    final pingText = _running
        ? (_ping > 0 ? '${persianDigits('$_ping')}ms' : '—')
        : last == null
        ? '—'
        : (((last['ping'] as num?)?.toInt() ?? 0) > 0
              ? '${persianDigits('${(last['ping'] as num?)!.toInt()}')}ms'
              : '—');
    final upText = _running
        ? SpeedGauge.speedText(_up, persian: persian)
        : last == null
        ? '—'
        : fig(last['up'] as num?);
    final downText = _running
        ? SpeedGauge.speedText(_down, persian: persian)
        : last == null
        ? '—'
        : fig(last['down'] as num?);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 116),
      children: [
        PageTitle(l.navSpeedTest),
        const SizedBox(height: 4),
        Text(
          l.speedHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Dali.onVar(context),
          ),
        ),
        const SizedBox(height: 10),
        DaliCard(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Center(
            child: ArcDial(
              fraction: _scale > 0 ? shown / _scale : 0,
              valueText: SpeedGauge.speedText(shown, persian: persian),
              unitText: l.megabitUnit,
              caption: _running
                  ? (_upPhase ? l.uploadRate : l.downloadRate)
                  : l.measuredSoFar,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: StatusColors.bad,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(210, 56),
              shape: const StadiumBorder(),
            ),
            onPressed: _running ? _stop : () => _run(),
            child: _running
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(l.speedStop),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 22),
                      const SizedBox(width: 6),
                      Text(l.speedRun),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 22),
        SectionLabel(l.lastTestLabel),
        DaliCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lastAt == null ? '—' : formatAgo(l, lastAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Dali.onVar(context),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.speed_rounded,
                    size: 20,
                    color: Dali.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ValueBox(label: l.pingLabel, value: pingText)),
                  const SizedBox(width: 8),
                  Expanded(child: ValueBox(label: l.uploadRate, value: upText)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueBox(label: l.downloadRate, value: downText),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionLabel(
          l.speedHistory,
          trailing: _history.isEmpty
              ? null
              : TextButton(
                  onPressed: _running ? null : _clearHistory,
                  child: Text(l.speedClear),
                ),
        ),
        if (_history.isEmpty)
          DaliCard(
            child: Text(
              l.speedHistoryEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Dali.onVar(context),
              ),
            ),
          )
        else
          DaliCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (i, e) in _history.take(10).indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _HistoryRow(entry: e),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One past test: when it ran, and what it found, as small figures.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final persian = l.localeName == 'fa';
    final ping = (entry['ping'] as num?)?.toInt() ?? 0;
    final at = DateTime.tryParse(entry['at'] as String? ?? '');
    String fig(Object? v) =>
        SpeedGauge.speedText((v as num?)?.toDouble() ?? 0, persian: persian);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  at == null ? '—' : formatDateTime(l, at),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Dali.onVar(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${l.downloadRate} ${fig(entry['down'])} · '
                  '${l.uploadRate} ${fig(entry['up'])} · '
                  '${l.pingLabel} ${ping > 0 ? '${persianDigits('$ping')}ms' : '—'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Icon(Icons.speed_rounded, size: 20, color: Dali.primary),
        ],
      ),
    );
  }
}
