// Nothing squeezed anywhere: the whole phone is walked — every tab, the
// pushed pages — in the app's two languages, at the smallest phones, and
// the tester turns any RenderFlex overflow into an exception, which this
// test refuses. A card that loses its room fails here with the page's
// name, so "no text squeezed on any page" is enforced, not hoped for.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fali_vpn/app_settings.dart';
import 'package:fali_vpn/core/core_controller.dart';
import 'package:fali_vpn/core/models.dart';
import 'package:fali_vpn/ui/app.dart';

import 'widget_test.dart';

/// The core carrying the longest names a server list can hold, so the
/// cards are walked with their worst case, not their average.
class _LongApi extends FakeApi {
  @override
  Future<LocationList> locations() async => LocationList.fromJson({
    'locations': [
      {
        'code': 'US',
        'name': 'United States Minor Outlying Islands',
        'city': 'Washington, D.C. and the very long city line',
        'recommended': true,
        'ping_ms': 180,
      },
      {
        'code': 'DE',
        'name': 'Germany',
        'city': 'Frankfurt am Main an der besonders langen Straße',
        'ping_ms': 650,
      },
      {
        'code': 'JP',
        'name': 'Japan',
        'city': 'Tokyo',
        'locked': true,
        'ping_error': 'timeout',
      },
    ],
  });
}

/// Opens what [label] names and refuses anything the frame threw.
Future<void> _open(WidgetTester tester, String label) async {
  final f = find.text(label).last;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'opening "$label"');
}

/// Opens a pushed page by its row and returns with the system back, which
/// every page answers whatever its back bar looks like. The settings list
/// names its card and its row alike, so the row — the last one in the
/// tree — is the one that opens.
Future<void> _visit(WidgetTester tester, String label) async {
  final f = find.text(label);
  if (f.evaluate().isEmpty) return; // the page is not on this phone
  await tester.ensureVisible(f.last);
  await tester.pumpAndSettle();
  await tester.tap(f.last);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'page "$label"');
  expect(find.byType(AppBar), findsOneWidget, reason: 'page "$label" opened');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'back from "$label"');
}

Future<void> _walk(
  WidgetTester tester, {
  required Size size,
  required String language,
}) async {
  stillMotion(tester);
  // An overflow says WHERE it happened: dump the full report (the widget
  // that caused it, its file and line) before the walk's expects consume
  // the exception.
  final caught = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details, forceReport: true);
    caught?.call(details);
  };
  addTearDown(() => FlutterError.onError = caught);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final core = CoreController(
    () async => _LongApi(),
    pollInterval: const Duration(hours: 1),
  );
  final settings = AppSettings()..language = language;
  await tester.pumpWidget(VpnApp(core: core, settings: settings));
  core.start();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'home');

  // The exit card opens the connection's details; it may sit below the
  // fold on the short window. The page's own back bar is the back icon.
  final exit = find.textContaining(language == 'fa' ? 'هلند' : 'Netherlands');
  await tester.ensureVisible(exit.last);
  await tester.pumpAndSettle();
  await tester.tap(exit.last);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'connection details');
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'back from the details');

  // Every tab, ending on Settings so the pushed pages are one tap away.
  final tabs = language == 'fa'
      ? const ['سرورها', 'تست سرعت', 'تنظیمات']
      : const ['Servers', 'Speed test', 'Settings'];
  for (final tab in tabs) {
    await _open(tester, tab);
    expect(tester.takeException(), isNull, reason: 'tab "$tab"');
  }

  // Every settings section the list pushes — the dense rows live in
  // Connection and Advanced, so all of them are walked.
  final pages = language == 'fa'
      ? const [
          'عمومی',
          'اتصال',
          'مسیریابی',
          'DNS',
          'سرور رله',
          'فرگمنت TLS',
          'پروکسی بالادستی',
          'پیشرفته',
          'حساب‌ها',
          'لاگ‌ها',
          'درباره',
        ]
      : const [
          'General',
          'Connection',
          'Routing',
          'DNS',
          'Relay server',
          'TLS fragmentation',
          'Upstream proxy',
          'Advanced',
          'Accounts',
          'Logs',
          'About',
        ];
  for (final page in pages) {
    await _visit(tester, page);
  }

  await tester.pumpWidget(const SizedBox());
  core.dispose();
}

void main() {
  for (final (name, size) in [
    ('a small phone', const Size(360, 740)),
    ('the smallest phone', const Size(320, 620)),
  ]) {
    testWidgets('$name keeps every page un-squeezed in English', (tester) async {
      await _walk(tester, size: size, language: 'en');
    });
    testWidgets('$name keeps every page un-squeezed in Persian', (
      tester,
    ) async {
      await _walk(tester, size: size, language: 'fa');
    });
  }
}
