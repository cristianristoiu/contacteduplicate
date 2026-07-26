import 'package:contacte_duplicate/shared/widgets/contact_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(String name) {
    return MaterialApp(
      home: Scaffold(
        body: ContactAvatar(name: name),
      ),
    );
  }

  testWidgets('afiseaza fallback pentru nume gol', (tester) async {
    await tester.pumpWidget(buildSubject('   '));

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('foloseste primul si ultimul cuvant pentru initiale',
      (tester) async {
    await tester.pumpWidget(buildSubject('  Ion   Mihai Popescu  '));

    expect(find.text('IP'), findsOneWidget);
  });

  testWidgets('accepta caractere Unicode fara eroare', (tester) async {
    await tester.pumpWidget(buildSubject('Ștefan Țurcanu'));

    expect(find.text('ȘȚ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
