import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigafape_app/api/api.dart';
import 'package:sigafape_app/tema.dart';
import 'package:sigafape_app/util/nativo.dart';

import 'ajuda.dart';

void main() {
  testWidgets('senha errada mostra o erro e não entra', (tester) async {
    await abrirApp(tester);
    await entrar(tester, senha: 'errada');
    expect(find.text('Usuário ou senha inválidos.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('entra, mostra o painel e guarda o token cifrado', (tester) async {
    final sessao = await abrirApp(tester);
    await entrar(tester);
    expect(sessao.logado, isTrue);
    expect(await Nativo.lerSegredo('token'), '1|demo');
    expect(find.text('CB JOÃO BATISTA'), findsOneWidget);
    expect(find.text('COMIGO AGORA'), findsOneWidget);
    expect(find.text('INSPEÇÃO'), findsOneWidget);
  });

  testWidgets('assinatura do recebimento: senha errada fica no campo, certa assina', (tester) async {
    await abrirApp(tester);
    await entrar(tester);
    await aba(tester, 'Material');
    await tester.tap(find.text('Fuzil IA2'));
    await esperar(tester);
    await tester.tap(find.text('ASSINAR RECEBIMENTO'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Matrícula'), findsOneWidget);
    expect(find.text('215.347-8'), findsWidgets); // matrícula já preenchida

    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'errada');
    await tester.tap(find.text('ASSINAR'));
    await esperar(tester);
    expect(find.text('Matrícula ou senha incorreta. Restam 4 tentativas.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'demo');
    await tester.tap(find.text('ASSINAR'));
    await esperar(tester);
    await esperar(tester);
    expect(find.textContaining('Recebimento assinado.'), findsOneWidget);
    expect(find.text('ASSINAR RECEBIMENTO'), findsNothing);
  });

  testWidgets('alerta urgente exige ciência assinada', (tester) async {
    await abrirApp(tester);
    await entrar(tester);
    await aba(tester, 'Alertas');
    await tester.tap(find.text('Escala extra do feriado'));
    await esperar(tester);
    expect(find.text('MARCAR COMO LIDA'), findsNothing);
    await tester.tap(find.text('DAR CIÊNCIA ASSINADA'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'demo');
    await tester.tap(find.text('ASSINAR CIÊNCIA'));
    await esperar(tester);
    await esperar(tester);
    expect(find.textContaining('Código F00D-CAFE-1234-5678'), findsWidgets);
  });

  testWidgets('nova reserva assinada', (tester) async {
    await abrirApp(tester);
    await entrar(tester);
    await aba(tester, 'Reservas');
    await tester.tap(find.text('Nova reserva'));
    await esperar(tester);
    await tester.tap(find.text('Colete N-III'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ASSINAR E RESERVAR'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'demo');
    await tester.tap(find.text('ASSINAR E RESERVAR').last);
    await esperar(tester);
    await esperar(tester);
    expect(find.text('Aguardando retirada'.toUpperCase()), findsOneWidget);
  });

  testWidgets('trocar a cor do app e sair', (tester) async {
    final sessao = await abrirApp(tester);
    await entrar(tester);
    await aba(tester, 'Eu');
    await tester.tap(find.text('Escuro tático'));
    await tester.pumpAndSettle();
    expect(sessao.tema, Tema.escuro);
    expect(await Nativo.ler('tema'), 'escuro');

    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair deste aparelho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair').last);
    await esperar(tester);
    expect(sessao.logado, isFalse);
    expect(await Nativo.lerSegredo('token'), isNull);
    expect(find.text('ENTRAR'), findsOneWidget);
  });

  test('endereço do servidor é normalizado', () {
    expect(Api.normalizarServidor('sigafape.pmrn.internal/'), 'https://sigafape.pmrn.internal');
    expect(Api.normalizarServidor('http://192.168.0.10/api/v1'), 'http://192.168.0.10');
    expect(Api.normalizarServidor(' https://x.y '), 'https://x.y');
  });

  test('erro 422 traz a mensagem do campo', () {
    final e = ApiErro('Assinatura recusada.', status: 422, erros: {'senha': ['Senha incorreta.']});
    expect(e.campo('senha'), 'Senha incorreta.');
    expect(e.detalhe, 'Senha incorreta.');
    expect(e.campo('matricula'), isNull);
  });

  testWidgets('todas as cores montam o tema', (tester) async {
    for (final t in Tema.values) {
      final tema = temaMaterial(t);
      expect(tema.extension<Cores>(), isNotNull);
    }
    await tester.pumpWidget(MaterialApp(theme: temaMaterial(Tema.cinza), home: const SizedBox()));
  });
}
