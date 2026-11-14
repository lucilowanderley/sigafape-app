import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sigafape_app/demo.dart';
import 'package:sigafape_app/main.dart';
import 'package:sigafape_app/sessao.dart';
import 'package:sigafape_app/tema.dart';
import 'package:sigafape_app/util/nativo.dart';

/// Abre o app com a API de demonstração (sem servidor e sem canal nativo).
/// [servidores]: endereços salvos no celular (o primeiro em uso); os de [foraDoAr] não respondem.
Future<Sessao> abrirApp(WidgetTester tester,
    {Tema tema = Tema.azul, List<String> servidores = const ['https://demonstracao.sigafape'], Set<String> foraDoAr = const {}, bool padroes = false}) async {
  Nativo.semCanal = true;
  Sessao.usarEnderecosPadrao = padroes;
  await Nativo.gravar('enderecos_padrao', null);
  hostsForaDoAr
    ..clear()
    ..addAll(foraDoAr);
  await initializeDateFormatting('pt_BR');
  await Nativo.gravar('tema', tema.name);
  await Nativo.gravar('servidores', jsonEncode([for (final s in servidores) {'nome': nomeSugerido(s), 'endereco': s}]));
  await Nativo.gravar('servidor', servidores.isEmpty ? null : servidores.first);
  await Nativo.gravarSegredo('token', null);
  for (final k in ['bio_chave', 'bio_nome', 'bio_matricula']) {
    await Nativo.gravar(k, null);
  }
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
