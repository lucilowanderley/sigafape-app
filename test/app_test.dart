import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigafape_app/api/api.dart';
import 'package:sigafape_app/demo.dart';
import 'package:sigafape_app/sessao.dart';
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
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

  testWidgets('servidor fora do ar: o login tenta o próximo endereço sozinho', (tester) async {
    final sessao = await abrirApp(tester, servidores: ['https://192.168.10.20', 'https://demonstracao.sigafape'], foraDoAr: {'192.168.10.20'});
    await entrar(tester);
    await esperar(tester);
    expect(sessao.logado, isTrue);
    expect(sessao.servidor, 'https://demonstracao.sigafape');
    expect(await Nativo.ler('servidor'), 'https://demonstracao.sigafape');
  });

  testWidgets('nenhum servidor responde: mostra Sem conexão e salva o endereço novo', (tester) async {
    final sessao = await abrirApp(tester, servidores: ['https://192.168.10.20', 'https://100.104.230.42'], foraDoAr: {'192.168.10.20', '100.104.230.42'});
    await entrar(tester);
    await esperar(tester);
    expect(find.text('Nenhum servidor respondeu'), findsOneWidget);
    expect(find.text('sem resposta · está no Wi-Fi da unidade?'), findsOneWidget);
    expect(find.text('sem resposta · o Tailscale está ligado?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'demonstracao.sigafape');
    await tester.tap(find.text('TESTAR E SALVAR'));
    await esperar(tester);
    expect(sessao.semConexao, isFalse);
    expect(sessao.servidores.map((s) => s.endereco), contains('https://demonstracao.sigafape'));
    expect(find.text('ENTRAR'), findsOneWidget);
  });

  testWidgets('primeira abertura sem endereço pede o servidor', (tester) async {
    await abrirApp(tester, servidores: const [], foraDoAr: {'192.168.0.99'});
    expect(find.text('Configurar servidor'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '192.168.0.99');
    await tester.tap(find.text('TESTAR E SALVAR'));
    await esperar(tester);
    expect(find.textContaining('sem resposta'), findsOneWidget);
    expect(find.text('Configurar servidor'), findsOneWidget);
  });

  test('nome sugerido pelo tipo de endereço', () {
    expect(nomeSugerido('https://192.168.10.20'), 'Wi-Fi da unidade');
    expect(nomeSugerido('https://100.104.230.42'), 'Tailscale (fora da unidade)');
    expect(nomeSugerido('https://sigafape.8bpm.internal'), 'Nome interno');
    expect(nomeSugerido('https://177.20.1.5'), 'IP público');
    expect(nomeSugerido('https://sigafape.tail1234.ts.net'), 'Endereço na internet');
  });

  testWidgets('ícone de apoio confirma e envia a localização ao COPOM', (tester) async {
    await abrirApp(tester);
    await entrar(tester);
    await tester.tap(find.byTooltip('Pedir apoio urgente'));
    await tester.pumpAndSettle();
    expect(find.text('Pedir apoio urgente?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido enviado'), findsNothing);

    await tester.tap(find.byTooltip('Pedir apoio urgente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONFIRMAR'));
    await esperar(tester);
    expect(find.text('Pedido enviado'), findsOneWidget);
    expect(find.textContaining('com a sua localização'), findsOneWidget);
  });

  testWidgets('apoio sem GPS avisa o policial', (tester) async {
    await abrirApp(tester);
    await entrar(tester);
    Nativo.localDeTeste = null;
    addTearDown(() => Nativo.localDeTeste = const Local(-5.79448, -35.21100, 9));
    await tester.tap(find.byTooltip('Pedir apoio urgente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONFIRMAR'));
    await esperar(tester);
    expect(find.textContaining('Não foi possível obter a sua localização'), findsOneWidget);
  });

  testWidgets('caderno ao lado do sino anota e lista', (tester) async {
    await abrirApp(tester);
    await entrar(tester);
    await tester.tap(find.byTooltip('Caderno'));
    await esperar(tester);
    expect(find.text('Placa suspeita QGH-2E41, Gol prata'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ponto base: praça da matriz');
    await tester.tap(find.byTooltip('Anotar'));
    await esperar(tester);
    expect(find.text('Ponto base: praça da matriz'), findsOneWidget);
  });

  testWidgets('abre ocorrência pelo cartão e vê em Minhas ocorrências', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await abrirApp(tester);
    await entrar(tester);
    await tester.tap(find.text('Abrir ocorrência'));
    await esperar(tester);
    await tester.tap(find.text('ENVIAR AO COPOM'));
    await esperar(tester);
    expect(find.text('Escolha a natureza.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Roubo'));
    await tester.enterText(find.widgetWithText(TextField, 'Rua, número'), 'Rua Coronel Martiniano, 410');
    await tester.tap(find.text('Usar minha localização (GPS)'));
    await esperar(tester);
    expect(find.textContaining('precisão 9 m'), findsOneWidget);
    await tester.tap(find.text('ENVIAR AO COPOM'));
    await esperar(tester);
    await esperar(tester);
    expect(find.text('1 aguardando'), findsOneWidget);

    await tester.tap(find.text('MINHAS OCORRÊNCIAS'));
    await esperar(tester);
    expect(find.text('Aguardando o COPOM'), findsOneWidget);
    expect(find.textContaining('Motivo: já atendida'), findsOneWidget);
  });

  testWidgets('sino do topo mostra o número e notificação nova vira aviso no celular', (tester) async {
    novidadesDeTeste.clear();
    Nativo.avisosDeTeste.clear();
    await abrirApp(tester);
    await entrar(tester);
    // 1 notificação urgente + 1 aviso do sino; os que já existiam ao entrar não viram aviso na barra
    final sino = find.descendant(of: find.widgetWithIcon(IconButton, Icons.notifications_active), matching: find.text('2'));
    expect(sino, findsOneWidget);
    expect(Nativo.avisosDeTeste, isEmpty);

    novidadesDeTeste.add({'chave': 'alerta-77', 'tipo': 'alerta', 'titulo': 'URGENTE · Reunião às 14h', 'texto': 'De P/3', 'prioridade': 'urgente', 'em': null});
    await aba(tester, 'Reservas'); // trocar de aba confere de novo
    expect(Nativo.avisosDeTeste, ['URGENTE · Reunião às 14h']);
    await aba(tester, 'Material');
    expect(Nativo.avisosDeTeste, hasLength(1)); // não avisa duas vezes
    await aba(tester, 'Início');
    expect(find.descendant(of: find.widgetWithIcon(IconButton, Icons.notifications_active), matching: find.text('3')), findsOneWidget);
    novidadesDeTeste.clear();
  });

  testWidgets('Meu serviço diz se está escalado e Assinar soma cautelas e notificações', (tester) async {
    await abrirApp(tester);
    await entrar(tester);
    expect(find.text('Escalado'), findsOneWidget);
    expect(find.textContaining('· Motorista'), findsOneWidget);
    expect(find.text('1 cautela · 1 notificação'), findsOneWidget);
    await tester.tap(find.text('ASSINAR'));
    await esperar(tester);
    expect(find.text('Assinaturas pendentes'), findsOneWidget);
    expect(find.textContaining('Fuzil IA2'), findsOneWidget);
    expect(find.text('Escala extra do feriado'), findsOneWidget);
  });
}
