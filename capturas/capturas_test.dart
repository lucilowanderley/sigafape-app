// Gera prints das telas com a API de demonstração (não roda com os testes normais):
//   flutter test capturas/capturas_test.dart --update-goldens
// Os PNGs ficam em capturas/telas/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigafape_app/tema.dart';

import '../test/ajuda.dart';

Future<void> carregarFontes() async {
  final pasta = '${Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter'}/bin/cache/artifacts/material_fonts';
  ByteData ler(String n) => ByteData.sublistView(Uint8List.fromList(File('$pasta/$n').readAsBytesSync()));
  final roboto = FontLoader('Roboto');
  for (final n in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    roboto.addFont(Future.value(ler(n)));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ler('MaterialIcons-Regular.otf')))).load();
}

Future<void> foto(WidgetTester tester, String nome) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('telas/$nome.png'));
}

void main() {
  setUpAll(carregarFontes);

  void celular(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
  }

  for (final t in Tema.values) {
    testWidgets('telas ${t.name}', (tester) async {
      celular(tester);
      await abrirApp(tester, tema: t);
      await foto(tester, '${t.name}-1-entrar');
      await entrar(tester);
      await foto(tester, '${t.name}-2-inicio');
      await aba(tester, 'Material');
      await foto(tester, '${t.name}-3-material');
      await tester.tap(find.text('Fuzil IA2'));
      await esperar(tester);
      await tester.tap(find.text('ASSINAR RECEBIMENTO'));
      await tester.pumpAndSettle();
      await foto(tester, '${t.name}-4-assinar');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await aba(tester, 'Reservas');
      await foto(tester, '${t.name}-5-reservas');
      await aba(tester, 'Alertas');
      await foto(tester, '${t.name}-6-alertas');
      await aba(tester, 'Eu');
      await foto(tester, '${t.name}-7-eu');
    });
  }

  testWidgets('servidores', (tester) async {
    celular(tester);
    await abrirApp(tester, servidores: ['https://192.168.10.20', 'https://100.104.230.42'], foraDoAr: {'192.168.10.20', '100.104.230.42'});
    await entrar(tester);
    await esperar(tester);
    await foto(tester, 'servidor-1-sem-conexao');
    await tester.enterText(find.byType(TextField), 'demonstracao.sigafape');
    await tester.tap(find.text('TESTAR E SALVAR'));
    await esperar(tester);
    await entrar(tester);
    await aba(tester, 'Eu');
    await tester.tap(find.text('Servidores'));
    await tester.pumpAndSettle();
    await foto(tester, 'servidor-2-lista');
    await tester.tap(find.text('Adicionar endereço'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'IP ou nome do servidor'), 'sigafape.tail1234.ts.net');
    await tester.pumpAndSettle();
    await foto(tester, 'servidor-3-adicionar');
  });

  testWidgets('pedidos do campo', (tester) async {
    celular(tester);
    await abrirApp(tester);
    await entrar(tester);
    await foto(tester, 'campo-1-inicio');
    await tester.tap(find.byTooltip('Pedir apoio urgente'));
    await tester.pumpAndSettle();
    await foto(tester, 'campo-2-apoio-confirmar');
    await tester.tap(find.text('CONFIRMAR'));
    await esperar(tester);
    await foto(tester, 'campo-3-apoio-enviado');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Caderno'));
    await esperar(tester);
    await foto(tester, 'campo-4-caderno');
    await tester.tap(find.byType(BackButton));
    await esperar(tester);
    await tester.tap(find.text('Abrir ocorrência'));
    await esperar(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Roubo'));
    await tester.enterText(find.widgetWithText(TextField, 'Rua, número'), 'Rua Coronel Martiniano, 410');
    await tester.enterText(find.widgetWithText(TextField, 'Bairro'), 'Centro');
    await tester.tap(find.text('Usar minha localização (GPS)'));
    await esperar(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await foto(tester, 'campo-5-nova-ocorrencia');
    await tester.tap(find.byType(BackButton));
    await esperar(tester);
    await tester.tap(find.text('MINHAS OCORRÊNCIAS'));
    await esperar(tester);
    await foto(tester, 'campo-6-minhas-ocorrencias');
  });

  testWidgets('calculadora e inicio 1.3.0', (tester) async {
    celular(tester);
    await abrirApp(tester);
    await entrar(tester);
    await foto(tester, 'v13-1-inicio');
    await tester.ensureVisible(find.text('FERRAMENTAS'));
    await tester.pumpAndSettle();
    await foto(tester, 'v13-2-inicio-ferramentas');
    await tester.tap(find.text('FERRAMENTAS'));
    await esperar(tester);
    await foto(tester, 'v13-3-reserva');
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await foto(tester, 'v13-4-reserva-linha');
    await tester.tap(find.byType(BackButton));
    await esperar(tester);
    await tester.ensureVisible(find.text('ASSINAR'));
    await tester.tap(find.text('ASSINAR'));
    await esperar(tester);
    await foto(tester, 'v13-5-assinaturas');
  });
}
