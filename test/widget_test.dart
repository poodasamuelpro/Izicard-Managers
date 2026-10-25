import 'package:flutter_test/flutter_test.dart';
import 'package:izicard_managers/main.dart';

void main() {
  testWidgets('affiche le tableau de bord', (tester) async {
    await tester.pumpWidget(const IzicardManagersApp());
    expect(find.text('Izicard Managers'), findsOneWidget);
    expect(find.text('Bienvenue dans Izicard Managers'), findsOneWidget);
  });
}
