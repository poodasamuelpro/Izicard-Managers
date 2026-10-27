import 'package:flutter_test/flutter_test.dart';

import '../lib/data/repositories/sync_repository.dart';

void main() {
  test(
    'résultat de synchronisation expose les compteurs et valeurs par défaut',
    () {
      const result = SyncResult(sent: 3, remaining: 2);

      expect(result.sent, 3);
      expect(result.remaining, 2);
      expect(result.rejected, 0);
      expect(result.blocked, isFalse);
    },
  );

  test('signale un lot bloqué par une session qui ne correspond pas', () {
    const result = SyncResult(sent: 0, remaining: 4, blocked: true);

    expect(result.sent, 0);
    expect(result.remaining, 4);
    expect(result.blocked, isTrue);
  });
}
