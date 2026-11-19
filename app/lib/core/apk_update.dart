import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_info.dart';
import 'android_core.dart';
import 'updates.dart' show downloadUrl;

/// The phases of the phone's own update: the newer version's APK downloads
/// inside the app, with a progress line like the app stores', and is then
/// handed to Android's installer. Nothing opens a browser, and the file's
/// home — the repository — is never named on the screen: the app speaks
/// only of the version, its size, and its notes.
enum ApkPhase {
  idle,
  connecting,
  downloading,
  installing,
  needsPermission,
  done,
  failed,
}

/// Where the download stands: the bytes that arrived, the file's size
/// when the server said it first, and the speed of the last moment.
class ApkState {
  const ApkState({
    required this.phase,
    this.received = 0,
    this.total = 0,
    this.speed = 0,
    this.error = '',
  });

  final ApkPhase phase;
  final int received;

  /// The whole file's size in bytes; 0 when the server said none.
  final int total;

  /// Bytes per second, measured over the last beat of the progress.
  final double speed;
  final String error;

  bool get busy =>
      phase == ApkPhase.connecting || phase == ApkPhase.downloading;

  /// The share that arrived, 0 to 1; 0 while the size is unknown.
  double get progress => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

  /// The same state, wearing [phase] and [error]; the numbers stay, so a
  /// pause of the progress keeps what arrived.
  ApkState withPhase(ApkPhase phase, {String error = ''}) =>
      ApkState(
        phase: phase,
        received: received,
        total: total,
        speed: speed,
        error: error,
      );
}

/// The phone's updater, behind the update dialog: it asks the file's size,
/// downloads the APK into the app's own folder, and gives it to Android's
/// installer through MainActivity (the FileProvider, and the leave to
/// install, which Android asks for once). A finished file stays, so the
/// next ask for the same version installs at once.
abstract final class ApkUpdate {
  /// The download's standing, watched by the dialog.
  static final state = ValueNotifier<ApkState>(
    const ApkState(phase: ApkPhase.idle),
  );

  static HttpClient? _client;
  static File? _file;

  /// The release whose file is on the disk (or on its way), so a second
  /// ask for the same version joins the first.
  static String? _version;

  /// The file's size, when the server says it before the download: the
  /// dialog shows it as the update's weight ("44.5 MB").
  static Future<int> sizeOf(Release release, {String? proxy}) async {
    final url = await downloadUrl(release);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..findProxy = (_) => proxy == null ? 'DIRECT' : 'PROXY $proxy; DIRECT';
    try {
      final head = await client
          .headUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      head.headers.set(HttpHeaders.userAgentHeader, 'fali-vpn/$appVersion');
      final res = await head.close().timeout(const Duration(seconds: 20));
      await res.drain<void>();
      final length = res.contentLength;
      return length > 0 ? length : 0;
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads [release]'s APK for this phone's processor, telling [state]
  /// as it goes. [proxy] ("host:port") carries the request through the
  /// VPN's own, for networks that block the file's home; it falls back to
  /// a direct connection. [dir] is the app's files folder (tests).
  static Future<void> download(
    Release release, {
    String? proxy,
    String? dir,
  }) async {
    if (_version == release.version && state.value.busy) return;
    _version = release.version;
    state.value = const ApkState(phase: ApkPhase.connecting);
    try {
      final url = await downloadUrl(release);
      final folder =
          dir ??
          '${await AndroidCore.filesDir()}${Platform.pathSeparator}update';
      final name = Uri.parse(url).pathSegments.last;
      final file = File('$folder${Platform.pathSeparator}$name');
      _file = file;
      await Directory(folder).create(recursive: true);

      // A whole file from an earlier run: skip the download.
      if (file.existsSync()) {
        final size = await sizeOf(release, proxy: proxy);
        if (size > 0 && file.lengthSync() == size) {
          state.value = ApkState(
            phase: ApkPhase.done,
            received: size,
            total: size,
          );
          return;
        }
        file.deleteSync();
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..findProxy = (_) => proxy == null ? 'DIRECT' : 'PROXY $proxy; DIRECT';
      _client = client;
      final get = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      get.headers.set(HttpHeaders.userAgentHeader, 'fali-vpn/$appVersion');
      final res = await get.close().timeout(const Duration(seconds: 20));
      if (res.statusCode >= 400) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final total = res.contentLength > 0 ? res.contentLength : 0;
      final sink = file.openWrite();
      var received = 0;
      var last = DateTime.now();
      var lastBytes = 0;
      var speed = 0.0;
      try {
        await for (final chunk in res) {
          received += chunk.length;
          sink.add(chunk);
          final now = DateTime.now();
          final dt = now.difference(last).inMilliseconds;
          if (dt >= 120) {
            // The speed over the last beat, smoothed, as the stores show.
            final instant =
                (received - lastBytes) * 1000 / (dt == 0 ? 1 : dt);
            speed = speed == 0 ? instant : speed * 0.6 + instant * 0.4;
            last = now;
            lastBytes = received;
            state.value = ApkState(
              phase: ApkPhase.downloading,
              received: received,
              total: total,
              speed: speed,
            );
          }
        }
        await sink.flush();
        await sink.close();
        state.value = ApkState(
          phase: ApkPhase.done,
          received: received,
          total: total > 0 ? total : received,
          speed: speed,
        );
      } catch (_) {
        await sink.close();
        rethrow;
      }
    } on Exception catch (e) {
      _client?.close(force: true);
      _client = null;
      state.value = state.value.withPhase(ApkPhase.failed, error: '$e');
    }
  }

  /// Hands the downloaded APK to Android's installer. False when Android
  /// wants the user's leave first: the state turns
  /// [ApkPhase.needsPermission], Android's own page opens, and answering
  /// it starts the install by itself (MainActivity's onActivityResult).
  static Future<bool> install() async {
    final file = _file;
    if (file == null || !file.existsSync()) {
      state.value = state.value.withPhase(
        ApkPhase.failed,
        error: 'no downloaded file',
      );
      return false;
    }
    state.value = state.value.withPhase(ApkPhase.installing);
    try {
      final answer = await AndroidCore.installUpdateApk(file.path);
      if (answer == 'permission') {
        state.value = state.value.withPhase(ApkPhase.needsPermission);
        return false;
      }
      return answer == 'started';
    } on Exception catch (e) {
      state.value = state.value.withPhase(ApkPhase.failed, error: '$e');
      return false;
    }
  }

  /// Forgets everything, for the next test.
  @visibleForTesting
  static void reset() {
    _client?.close(force: true);
    _client = null;
    _file = null;
    _version = null;
    state.value = const ApkState(phase: ApkPhase.idle);
  }
}
