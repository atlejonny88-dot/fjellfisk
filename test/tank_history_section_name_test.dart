import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fjellfisk/screens/tank_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sectionPath = 'facilities/f/sections/internal-section-id';

  Future<void> openHistory(
    WidgetTester tester,
    FakeFirebaseFirestore db,
  ) async {
    await db.collection('$sectionPath/tanks/t/logs').add({
      'date': Timestamp.fromDate(DateTime(2026, 9, 25)),
      'mortality': 1,
      'feedKg': 2,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: TankHistoryScreen(
          facilityId: 'f',
          sectionId: 'internal-section-id',
          tankId: 't',
          tankName: 'K2',
          firestore: db,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectHistory(WidgetTester tester, String name) {
    expect(find.text('Kar: K2\nBygg/seksjon: $name'), findsOneWidget);
    expect(find.textContaining('internal-section-id'), findsNothing);
    expect(find.text('25.09.2026'), findsOneWidget);
    expect(find.textContaining('Fôr: 2,0 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('shows the section name without changing old logs',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc(sectionPath).set({'name': '  Tunell  '});
    await openHistory(tester, db);
    expectHistory(tester, 'Tunell');
    await tester.tap(find.text('Nullstill filter'));
    await tester.pumpAndSettle();
    expectHistory(tester, 'Tunell');
    final log = (await db.collection('$sectionPath/tanks/t/logs').get())
        .docs
        .single
        .data();
    expect(log.keys, unorderedEquals(['date', 'mortality', 'feedKg']));
  });

  for (final name in [null, '', '   ', 123, <String, dynamic>{}]) {
    testWidgets('handles missing or invalid name: $name', (tester) async {
      final db = FakeFirebaseFirestore();
      await db.doc(sectionPath).set({if (name != null) 'name': name});
      await openHistory(tester, db);
      expectHistory(tester, 'Navn ikke tilgjengelig');
    });
  }

  testWidgets('logs still load when the section document is missing', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await openHistory(tester, db);
    expectHistory(tester, 'Navn ikke tilgjengelig');
  });

  testWidgets('denied section read does not hide history', (tester) async {
    final db = FakeFirebaseFirestore(securityRules: '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /facilities/{f}/sections/{s} {
      allow read: if false;
      match /tanks/{t}/logs/{log} {
        allow read, write: if true;
      }
    }
  }
}
''');
    await openHistory(tester, db);
    expectHistory(tester, 'Navn ikke tilgjengelig');
  });
}
