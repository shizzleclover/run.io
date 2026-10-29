import 'package:flutter_test/flutter_test.dart';
import 'package:runio/engine/decay.dart';

void main() {
  const rule = DecayRule();
  const today = 20000;
  final owners = {'a': 'me', 'b': 'me', 'c': 'me', 'd': 'rival'};
  final touched = {'a': today - 1, 'b': today - 20, 'c': today - 40, 'd': 0};

  test('stale is old but not yet lost, and only yours', () {
    expect(
      rule.stale(
        owners: owners,
        touched: touched,
        playerId: 'me',
        today: today,
      ),
      {'b'},
    );
  });

  test('expire drops your lost cells and nobody else\'s', () {
    final next = rule.expire(
      owners: owners,
      touched: touched,
      playerId: 'me',
      today: today,
    );
    expect(next, {'a': 'me', 'b': 'me', 'd': 'rival'});
  });

  test('cells with no touch date are treated as fresh', () {
    final next = rule.expire(
      owners: {'x': 'me'},
      touched: const {},
      playerId: 'me',
      today: today,
    );
    expect(next, {'x': 'me'});
  });
}
