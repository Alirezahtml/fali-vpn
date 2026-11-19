import 'package:fali_vpn/ui/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('flowStrength', () {
    test('nothing moving is no flow', () {
      expect(flowStrength(0), 0);
      expect(flowStrength(-100), 0);
    });

    test('it climbs with the real rate and never passes its top', () {
      final rates = <int>[1, 1024, 16 * 1024, 128 * 1024, 1 << 20, 4 << 20];
      var last = 0.0;
      for (final rate in rates) {
        final v = flowStrength(rate);
        expect(v, greaterThan(last), reason: 'rate $rate must read livelier');
        expect(v, lessThanOrEqualTo(1.0));
        last = v;
      }
      // Past the curve's shoulder every rate reads full.
      for (final rate in <int>[16 << 20, 64 << 20, 1 << 30, 1 << 40]) {
        expect(flowStrength(rate), 1.0, reason: 'rate $rate must read full');
      }
    });

    test('a busy tunnel reads full, a quiet one still breathes', () {
      expect(flowStrength(64 << 20), 1.0);
      expect(flowStrength(16 * 1024), greaterThan(0));
      expect(flowStrength(16 * 1024), lessThan(0.5));
    });
  });

  testWidgets('the glass card wears its rim and answers a tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassCard(
            radius: 26,
            onTap: () => taps++,
            child: const Text('pane'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pane'));
    expect(taps, 1);
  });

  testWidgets('the blurred glass card builds and keeps its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Text('under'),
              GlassCard(blur: true, child: const Text('over')),
            ],
          ),
        ),
      ),
    );
    expect(find.text('under'), findsOneWidget);
    expect(find.text('over'), findsOneWidget);
  });

  testWidgets('soft depth paints the face and follows a color change', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoftDepth(color: Colors.blue, child: const Text('button')),
        ),
      ),
    );
    final box = tester.widget<Container>(
      find.ancestor(of: find.text('button'), matching: find.byType(Container)),
    );
    final decoration = box.decoration as BoxDecoration;
    // The bulge: a gradient of three stops over the face's color.
    expect(decoration.gradient, isA<LinearGradient>());
    expect(decoration.boxShadow, isNotEmpty);

    // The face glides to the new color without a jump: the same slot in
    // the tree carries the new color, and the state animates to it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoftDepth(color: Colors.red, child: const Text('button')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final box2 = tester.widget<Container>(
      find.ancestor(of: find.text('button'), matching: find.byType(Container)),
    );
    final decoration2 = box2.decoration as BoxDecoration;
    expect(decoration2.gradient, isA<LinearGradient>());
    expect(decoration2.boxShadow, isNotEmpty);
  });

  testWidgets('the repeating fields rest while the effects may not run', (
    tester,
  ) async {
    // The tests run on the computer, where repeating effects stay off:
    // the fields answer with nothing, and no frame is spent.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EnergyWaveField(color: Colors.blue, enabled: true),
              DataFlowField(
                downRate: 1 << 20,
                upRate: 1 << 18,
                enabled: true,
                downColor: Colors.blue,
                upColor: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(EnergyWaveField), findsOneWidget);
    expect(find.byType(DataFlowField), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EnergyWaveField),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataFlowField),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
