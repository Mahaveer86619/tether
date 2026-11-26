import 'package:flutter_test/flutter_test.dart';
import 'package:tether/domain/entities/entities.dart';

void main() {
  final sent = DateTime(2026, 11, 26, 10);
  final entry = OutboxEntry(id: 'c1', session: 's1', text: 'hi', created: sent, state: OutboxState.sent, sentAt: sent);

  test('a message that is still queued while Claude works is waited for', () {
    expect(entry.unconfirmed(sent.add(const Duration(minutes: 5))), isFalse);
    expect(entry.unconfirmed(sent.add(const Duration(minutes: 11))), isTrue);
  });

  test('a message not shown once the session has stopped is not "queued": it is offered for a retry', () {
    expect(entry.unconfirmed(sent.add(const Duration(seconds: 20)), sessionBusy: false), isFalse);
    expect(entry.unconfirmed(sent.add(const Duration(seconds: 60)), sessionBusy: false), isTrue);
  });
}
