import 'dart:async';

import 'package:fjellfisk/services/registration_round.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> tank(String id, int count, {bool note = false}) => {
        'id': id,
        'fishCount': count,
        if (note) 'activeNote': {'text': 'Kontroller filter'},
      };

  test('stable order keeps reviewed tanks last without mutating input', () {
    final round = RegistrationRound();
    final tanks = [
      tank('1', 20),
      tank('empty', 0),
      tank('2', 30),
      tank('note', 0, note: true),
      tank('3', 40)
    ];
    round.markReviewed('f', 's', '1');
    expect(round.ordered('f', 's', tanks).map((t) => t['id']),
        ['2', '3', 'note', 'empty', '1']);
    expect(tanks.first['id'], '1');
    round.markReviewed('f', 's', '2');
    expect(round.ordered('f', 's', tanks).map((t) => t['id']),
        ['3', 'note', 'empty', '1', '2']);
  });

  test('next excludes empty, current and reviewed tanks and finishes round',
      () {
    final round = RegistrationRound();
    final tanks = [tank('1', 20), tank('empty', 0), tank('2', 30)];
    round.markReviewed('f', 's', '1');
    expect(round.next('f', 's', '1', tanks)?['id'], '2');
    round.markReviewed('f', 's', '2');
    expect(round.next('f', 's', '2', tanks), isNull);
    expect(round.next('f', 's', 'x', []), isNull);
  });

  test('progress is scoped to facility, section and signed-in session', () {
    final round = RegistrationRound()..setUser('alice');
    round.markReviewed('f', 's', '1');
    round.setUser('alice');
    expect(round.isReviewed('f', 's', '1'), isTrue);
    expect(round.isReviewed('f', 'other', '1'), isFalse);
    expect(round.isReviewed('other', 's', '1'), isFalse);
    round.setUser(null);
    round.setUser('alice');
    expect(round.isReviewed('f', 's', '1'), isFalse);
  });

  test('double tap runs only one write and completes only after commit',
      () async {
    final save = RegistrationSave();
    final committed = Completer<void>();
    var writes = 0;
    final first = save.run(() async {
      writes++;
      await committed.future;
    });
    expect(save.busy, isTrue);
    expect(save.hasSaved, isFalse);
    expect(
        await save.run(() async {
          writes++;
        }),
        isFalse);
    expect(writes, 1);
    committed.complete();
    expect(await first, isTrue);
    expect(save.hasSaved, isTrue);
    expect(save.busy, isFalse);
    save.dispose();
  });

  test('failed save does not advance round and allows a successful retry',
      () async {
    final save = RegistrationSave();
    final round = RegistrationRound();
    Future<void> attempt(bool fail) async {
      final result = await save.run(() async {
        if (fail) throw StateError('Write rejected');
        round.markReviewed('f', 's', '1');
      });
      expect(result, isTrue);
    }

    await expectLater(attempt(true), throwsStateError);
    expect(save.busy, isFalse);
    expect(save.hasSaved, isFalse);
    expect(round.isReviewed('f', 's', '1'), isFalse);
    await attempt(false);
    expect(round.isReviewed('f', 's', '1'), isTrue);
    save.dispose();
  });
}
