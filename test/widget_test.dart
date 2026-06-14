import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:controle_validades/main.dart';

void main() {
  testWidgets('App renders splash screen and transitions to main',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Controle de Validades'), findsOneWidget);
    expect(find.text('Gerenciamento de Vencimentos'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Produtos'), findsWidgets);
    expect(find.text('Locais'), findsWidgets);
    expect(find.text('Cadastrar'), findsOneWidget);
    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar'), findsOneWidget);
    expect(find.text('Config'), findsOneWidget);
  });
}
