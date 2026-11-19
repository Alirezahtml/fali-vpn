import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'android_core.dart';
import 'core_controller.dart';
import 'models.dart';
import 'remote_flags.dart';

/// The flag the VPN's notification wears (CoreService.kt). Android cannot
/// draw an SVG, so the flag's picture is rasterized here — the same SVG
/// the pages use, at the notification's size — and handed to the service,
/// which sets it as the notification's large icon. The notification shows
/// the country's flag instead of an emoji, drawn sharp; a phone whose
/// launcher does not show a large icon simply shows the standard
/// notification, and nothing else changes.
abstract final class NotificationFlags {
  /// How wide the bitmap is drawn: a launcher renders the large icon at
  /// roughly 40-56 dp, so 144 px covers a 3x screen with room to spare.
  static const _width = 144;

  /// The code last sent, so a poll that did not move sends nothing.
  static String? _sent;

  /// Whether a render is already running (a poll ahead waits for it).
  static bool _busy = false;

  /// Follows [core]: while the traffic runs, the flag follows the country
  /// it leaves from.
  static void watch(CoreController core) {
    core.addListener(() => unawaited(_refresh(core)));
  }

  static Future<void> _refresh(CoreController core) async {
    if (_busy) return;
    final status = core.status;
    final connected = status != null &&
        status.proxyOn &&
        status.state.phase == Phase.running;
    if (!connected) {
      _sent = null;
      return;
    }
    // The exit's country first; the chosen one while the exit is not known.
    final code = (status.exit?.countryCode.isNotEmpty ?? false)
        ? status.exit!.countryCode
        : status.proxy?.countryCode ?? '';
    final upper = code.toUpperCase();
    if (upper.length != 2 || upper == _sent) return;
    _busy = true;
    try {
      final png = await _render(upper);
      if (png == null) return;
      await AndroidCore.setNotificationFlag(upper, png);
      _sent = upper;
    } on Exception {
      // The flag waits for the next poll; the notification works without
      // it.
    } finally {
      _busy = false;
    }
  }

  /// The flag's picture as a PNG bitmap: the app's own SVG first, the
  /// core's second (a location Mozilla added later); null when neither
  /// has one.
  static Future<Uint8List?> _render(String code) async {
    final lower = code.toLowerCase();
    try {
      final BytesLoader loader;
      if (bundledFlags.contains(lower)) {
        loader = SvgAssetLoader('assets/flags/$lower.svg');
      } else {
        final bytes = await RemoteFlags.load(lower);
        if (bytes == null || bytes.isEmpty) return null;
        loader = SvgStringLoader(utf8.decode(bytes));
      }
      final info = await vg.loadPicture(loader, null);
      final height = (info.size.height <= 0 || info.size.width <= 0)
          ? _width * 3 ~/ 4
          : (_width * info.size.height / info.size.width).round();
      final image = await info.picture.toImage(_width, height);
      info.picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } on Exception {
      return null;
    }
  }
}
