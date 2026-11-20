import 'package:fali_vpn/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The MotionEntrance plays once, after its delay: the timer needs the
  // pump's clock moved ahead before the frames can run.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('the entrance arrives from its offset and rests at full',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MotionEntrance(
            offset: Offset(0, 40),
            child: SizedBox(width: 100, height: 50, key: ValueKey('card')),
          ),
        ),
      ),
    );
    // The first frame: still at its start, hidden at the offset.
    var top = tester.getTopLeft(find.byKey(const ValueKey('card'))).dy;
    expect(top, greaterThan(0));
    await settle(tester);
    top = tester.getTopLeft(find.byKey(const ValueKey('card'))).dy;
    expect(top, 0);
    // A rebuild is not a replay: the entrance stays where it rests.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MotionEntrance(
            offset: Offset(0, 40),
            child: SizedBox(width: 100, height: 50, key: ValueKey('card')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('card'))).dy, 0);
  });

  testWidgets('the stagger gives each neighbour its own beat',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MotionStagger(
            children: [
              Container(key: const ValueKey('a'), height: 30),
              Container(key: const ValueKey('b'), height: 30),
              Container(key: const ValueKey('c'), height: 30),
            ],
          ),
        ),
      ),
    );
    // All three are laid out at once, even while still transparent.
    expect(find.byKey(const ValueKey('a')), findsOneWidget);
    expect(find.byKey(const ValueKey('b')), findsOneWidget);
    expect(find.byKey(const ValueKey('c')), findsOneWidget);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MotionAppear opens and closes its room smoothly',
      (tester) async {
    Widget host({required bool visible}) => MaterialApp(
          home: Scaffold(
            body: MotionAppear(
              visible: visible,
              tag: 'banner',
              child: Container(
                key: const ValueKey('banner'),
                height: 60,
                alignment: Alignment.center,
                child: const Text('hello'),
              ),
            ),
          ),
        );
    await tester.pumpWidget(host(visible: true));
    await settle(tester);
    expect(tester.getSize(find.byKey(const ValueKey('banner'))).height, 60);
    // Leaving: the room closes, the child goes.
    await tester.pumpWidget(host(visible: false));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('banner')), findsNothing);
    // Coming back: the room opens and the child is there again.
    await tester.pumpWidget(host(visible: true));
    await settle(tester);
    expect(tester.getSize(find.byKey(const ValueKey('banner'))).height, 60);
  });

  testWidgets('a content change crosses with the tag, not a rebuild',
      (tester) async {
    Widget host(String word) => MaterialApp(
          home: Scaffold(
            body: MotionAppear(
              visible: true,
              tag: word,
              child: Text(word, key: ValueKey(word)),
            ),
          ),
        );
    await tester.pumpWidget(host('one'));
    await settle(tester);
    expect(find.text('one'), findsOneWidget);
    // The words swap: the old one hands over to the new one in flight.
    await tester.pumpWidget(host('two'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('two'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('two'), findsOneWidget);
    expect(find.text('one'), findsNothing);
  });
}
