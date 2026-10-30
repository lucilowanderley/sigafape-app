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
}
