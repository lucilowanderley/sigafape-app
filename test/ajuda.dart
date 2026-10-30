import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sigafape_app/demo.dart';
import 'package:sigafape_app/main.dart';
import 'package:sigafape_app/sessao.dart';
import 'package:sigafape_app/tema.dart';
import 'package:sigafape_app/util/nativo.dart';

/// Abre o app com a API de demonstração (sem servidor e sem canal nativo).
Future<Sessao> abrirApp(WidgetTester tester, {Tema tema = Tema.azul}) async {
  Nativo.semCanal = true;
  await initializeDateFormatting('pt_BR');
  await Nativo.gravar('tema', tema.name);
  await Nativo.gravar('servidor', 'https://demonstracao.sigafape');
  await Nativo.gravarSegredo('token', null);
  final sessao = Sessao(cliente: clienteDemo());
  await tester.pumpWidget(AppSigafape(sessao: sessao));
  await tester.runAsync(sessao.iniciar);
  await tester.pumpAndSettle();
  return sessao;
}

/// Espera as chamadas da API de demonstração (que têm um pequeno atraso).
Future<void> esperar(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pumpAndSettle();
}

Future<void> entrar(WidgetTester tester, {String senha = 'demo'}) async {
  await tester.enterText(find.widgetWithText(TextField, 'Usuário ou matrícula'), '215.347-8');
  await tester.enterText(find.widgetWithText(TextField, 'Senha'), senha);
  await tester.tap(find.text('ENTRAR'));
  await esperar(tester);
  await esperar(tester);
}

Future<void> aba(WidgetTester tester, String nome) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(nome)));
  await esperar(tester);
}
