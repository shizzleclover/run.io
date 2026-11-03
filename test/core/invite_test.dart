import 'package:flutter_test/flutter_test.dart';
import 'package:runio/core/invite.dart';
import 'package:runio/core/models.dart';

void main() {
  test('reads code and name from a whole invite', () {
    final text = crewInvite(
      const Crew(code: 'K7QD-9XRM', name: 'Agbowo Striders'),
    );
    final r = parseCrewInvite(text)!;
    expect(r.code, 'K7QD-9XRM');
    expect(r.name, 'Agbowo Striders');
  });

  test('accepts a bare code, any case, with or without the dash', () {
    expect(parseCrewInvite('k7qd-9xrm')!.code, 'K7QD-9XRM');
    expect(parseCrewInvite('K7QD9XRM')!.code, 'K7QD-9XRM');
    expect(parseCrewInvite('  K7QD-9XRM ')!.name, isNull);
  });

  test('handles curly quotes from phone keyboards', () {
    final r = parseCrewInvite(
      'Join my crew “UI Night Runners”. Crew code: AB23-CD45',
    )!;
    expect(r.name, 'UI Night Runners');
    expect(r.code, 'AB23-CD45');
  });

  test('no code, no crew', () {
    expect(parseCrewInvite('come run with us'), isNull);
    expect(parseCrewInvite(''), isNull);
  });
}
