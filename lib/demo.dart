import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Modo demonstração (--dart-define=DEMO=true) e testes: responde como a API /api/v1, sem servidor.
/// Login: qualquer usuário com a senha "demo". Assinaturas: matrícula 215.347-8 e senha "demo".
const modoDemo = bool.fromEnvironment('DEMO');

/// Endereços que a demonstração trata como fora do ar (testes e prints da tela Sem conexão).
final hostsForaDoAr = <String>{};

http.Client clienteDemo() {
  final hoje = DateTime.now();
  String iso(DateTime d) => '${d.toIso8601String().split('.').first}-03:00';
  String dia(DateTime d) => d.toIso8601String().substring(0, 10);
  final h19 = DateTime(hoje.year, hoje.month, hoje.day, 19);

  var recebimentoPendente = true;
  var alertaPendente = true;
  var avisos = 1;
  var notaId = 3;
  final notas = <Map<String, dynamic>>[
    {'id': 2, 'texto': 'Placa suspeita QGH-2E41, Gol prata', 'criada_em': iso(hoje.subtract(const Duration(minutes: 40)))},
    {'id': 1, 'texto': 'VTR 1-0817 abasteceu, volta 13:40', 'criada_em': iso(hoje.subtract(const Duration(hours: 1)))},
  ];
  var pedidoId = 40;
  final pedidos = <Map<String, dynamic>>[
    {'id': 39, 'tipo': 'ocorrencia', 'titulo': 'Furto', 'natureza': 'Furto', 'local': 'Praça da Matriz · Centro', 'situacao': 'aceita', 'situacao_texto': 'Aceita', 'resposta': null,
     'respondida_por': 'SD MARIA', 'ocorrencia': '${hoje.year}/00276', 'equipe': 'RP 12', 'criada_em': iso(hoje.subtract(const Duration(hours: 2)))},
    {'id': 38, 'tipo': 'ocorrencia', 'titulo': 'Perturbação do sossego', 'natureza': 'Perturbação do sossego', 'local': 'Rua 7 · Rocas', 'situacao': 'recusada', 'situacao_texto': 'Recusada',
     'resposta': 'já atendida pela ${hoje.year}/00270', 'respondida_por': 'SD MARIA', 'ocorrencia': null, 'equipe': null, 'criada_em': iso(hoje.subtract(const Duration(hours: 5)))},
  ];
  Map<String, dynamic> pedido(String tipo, Map c) {
    final p = {
      'id': pedidoId++, 'tipo': tipo, 'titulo': tipo == 'apoio' ? 'Apoio urgente' : c['natureza'], 'natureza': c['natureza'],
      'local': (c['endereco']?.toString().isNotEmpty ?? false) ? [c['endereco'], c['bairro']].where((e) => e != null && e.toString().isNotEmpty).join(' · ') : 'GPS ${c['latitude']}, ${c['longitude']}',
      'situacao': 'pendente', 'situacao_texto': 'Aguardando o COPOM', 'resposta': null, 'respondida_por': null, 'ocorrencia': null, 'equipe': null, 'criada_em': iso(DateTime.now()),
    };
    pedidos.insert(0, p);
    return p;
  }

  final usuario = {
    'id': 7, 'usuario': 'joao', 'nome': 'CB JOÃO BATISTA', 'perfil': 'Operador de Módulo', 'funcao': 'Operador de Campo', 'unidade': '8º BPM',
    'iniciais': 'JB', 'foto': 'https://demonstracao.sigafape/api/v1/foto?v=demo1', 'trocar_senha': false, 'vinculado': true,
    'policial': {'id': 31, 'nome': 'CB JOÃO BATISTA', 'nome_completo': 'JOÃO BATISTA DA SILVA', 'matricula': '215.347-8', 'unidade': '8º BPM · 1ª CIA', 'situacao': 'Pronto', 'de_outra_unidade': null},
  };

  Map<String, dynamic> cautela(int id, String material, String serie, {String status = 'aberta', bool urgente = false, bool permanente = false, String? categoria}) => {
        'id': id, 'status': status, 'situacao': status == 'reservada' ? 'Reservada' : (urgente && recebimentoPendente ? 'Urgência · recebimento pendente' : (status == 'encerrada' ? 'Encerrada' : 'Aberta')),
        'cor': status == 'reservada' ? 'gold' : (urgente && recebimentoPendente ? 'red' : (status == 'encerrada' ? 'green' : 'blue')),
        'tipo': categoria == 'Colete balístico' ? 'colete' : 'item', 'material': material, 'categoria': categoria ?? 'Pistola', 'numero_serie': serie, 'patrimonio': 'PM-0$id',
        'lote': null, 'retirada': dia(hoje), 'retirada_prevista': status == 'reservada' ? iso(h19.add(const Duration(days: 1, hours: -1))) : null,
        'prazo_confirmacao': status == 'reservada' ? iso(h19.add(const Duration(days: 1, hours: -1, minutes: 15))) : null,
        'devolucao_prevista': permanente ? null : dia(hoje.add(const Duration(days: 1))), 'permanente': permanente, 'ato_permanente': permanente ? 'BG nº 045/2026' : null,
        'devolvida_em': status == 'encerrada' ? dia(hoje.subtract(const Duration(days: 3))) : null, 'em_atraso': false, 'urgente': urgente, 'motivo_urgencia': urgente ? 'Ocorrência em andamento' : null,
        'aguarda_meu_recebimento': urgente && recebimentoPendente, 'municao': categoria == null ? '45 munições .40 S&W, 3 carregadores' : null, 'carregadores': categoria == null ? 'CR-01, CR-02, CR-03' : null,
        'cancelamento': null, 'observacoes': null,
        'assinaturas': [
          {'acao': 'cautela', 'descricao': 'Cautela', 'assinada_por': 'SD ARMEIRO', 'assinada_em': iso(hoje.subtract(const Duration(hours: 2))), 'codigo': 'A1B2-C3D4-E5F6-0718'},
        ],
      };
  List<Map<String, dynamic>> comigo() => [
        cautela(120, 'Pistola .40', 'SZA12345'),
        cautela(121, 'Colete N-III', 'CL-0442', permanente: true, categoria: 'Colete balístico'),
        cautela(122, 'Fuzil IA2', 'IA2-1', urgente: true, categoria: 'Fuzil'),
      ];
  final reserva = cautela(130, 'Pistola .40', 'SZA99881', status: 'reservada');
  final inspecao = {
    'id': 9, 'inspecao': {'id': 3, 'titulo': 'Trimestral', 'tipo': 'Periódica', 'prazo': dia(hoje.add(const Duration(days: 6))), 'encerrada': false},
    'tipo': 'item', 'material': 'Fuzil IA2', 'numero_serie': 'IA2-1', 'cautela_id': 122, 'situacao': 'convocado', 'convocado_em': iso(hoje),
    'apresentar_ate': iso(DateTime(hoje.year, hoje.month, hoje.day + 2, 18)), 'atrasado': false, 'resultado': null, 'resultado_texto': null, 'cor': null,
    'observacoes': null, 'inspecionado_em': null, 'inspecionado_por': null, 'codigo': null, 'codigo_minha_assinatura': null,
  };
  Map<String, dynamic> alerta({bool completo = false}) => {
        'id': 55, 'protocolo': 'ALT-2026-0123', 'assunto': 'Escala extra do feriado', 'tipo': 'escala', 'tipo_texto': 'Escala', 'prioridade': 'urgente', 'prioridade_texto': 'Urgente',
        'remetente': 'P/1 · 8º BPM', 'enviada_em': iso(hoje.subtract(const Duration(hours: 3))), 'prazo_ciencia': iso(hoje.add(const Duration(days: 1))), 'cancelada': false,
        'exige_assinatura': true, 'aberta_em': null, 'ciencia_em': alertaPendente ? null : iso(hoje), 'pendente': alertaPendente,
        if (completo) ...{
          'texto': 'Policiais da 1ª CIA escalados para o reforço do feriado de 02/11. Apresentação às 06:30 no pátio do batalhão, com fardamento operacional.',
          'referencia': 'Ofício 211/2026', 'numero_sei': null, 'anexos': [], 'codigo_ciencia': alertaPendente ? null : 'F00D-CAFE-1234-5678',
        },
      };

  http.Response json(Object corpo, [int status = 200]) => http.Response(jsonEncode(corpo), status, headers: {'content-type': 'application/json; charset=utf-8'});
  http.Response? assinaturaErrada(Map corpo) => corpo['senha'] == 'demo' && corpo['matricula'].toString().replaceAll(RegExp(r'\D'), '') == '2153478'
      ? null
      : json({'message': 'Assinatura recusada.', 'errors': {'senha': ['Matrícula ou senha incorreta. Restam 4 tentativas.']}}, 422);

  return MockClient((req) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (hostsForaDoAr.contains(req.url.host)) throw http.ClientException('Servidor não respondeu', req.url);
    final caminho = req.url.path.split('/api/v1/').last;
    final corpo = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
    switch ((req.method, caminho)) {
      case ('POST', 'login'):
        if (corpo['senha'] != 'demo') return json({'message': 'Usuário ou senha inválidos.', 'errors': {'usuario': ['Usuário ou senha inválidos.']}}, 422);
        return json({'token': '1|demo', 'tipo': 'Bearer', 'expira_em': iso(hoje.add(const Duration(days: 30))), 'usuario': usuario}, 201);
      case ('GET', 'me'):
        return json({'data': usuario});
      case ('POST', 'logout'):
        return json({'message': 'Você saiu do app neste aparelho.'});
      case ('GET', 'painel'):
        return json({
          'data': {
            'usuario': usuario, 'vinculado': true, 'alertas_pendentes': alertaPendente ? [alerta()] : [], 'avisos_nao_lidos': avisos,
            'servico_agora': null,
            'proximo_servico': {'inicio': iso(h19), 'fim': iso(h19.add(const Duration(hours: 12))), 'tipo': 'Escala', 'titulo': 'Patrulha', 'posto': 'Setor 2', 'funcao': 'Motorista', 'viatura': '8-1234'},
            'agenda': [
              {'inicio': iso(h19), 'fim': iso(h19.add(const Duration(hours: 12))), 'tipo': 'Escala', 'titulo': 'Patrulha', 'posto': 'Setor 2', 'funcao': 'Motorista', 'viatura': '8-1234'},
              {'inicio': iso(h19.add(const Duration(days: 3))), 'fim': iso(h19.add(const Duration(days: 3, hours: 12))), 'tipo': 'Operação', 'titulo': 'Operação Feriado Seguro', 'posto': 'Centro', 'funcao': null, 'viatura': null},
            ],
            'servicos_no_mes': 6, 'comigo': comigo(), 'recebimentos_pendentes': recebimentoPendente ? [comigo()[2]] : [], 'reservas': [reserva], 'depositos': [],
            'diarias': {'no_mes': 3, 'limite': 10, 'lista': [{'data': dia(hoje.subtract(const Duration(days: 5))), 'quantidade': 1, 'origem': 'Operação Feriado Seguro', 'situacao': 'Paga'}]},
            'viatura_em_uso': null, 'convocacoes_inspecao': [inspecao], 'patrimonio': [],
          },
        });
      case ('GET', 'cautelas'):
        return json({'data': comigo()});
      case ('GET', 'historico'):
        return json({'data': [...comigo(), reserva, cautela(101, 'Espingarda 12', 'ESP-77', status: 'encerrada', categoria: 'Espingarda')], 'situacoes': {}, 'paginacao': {'pagina': 1, 'paginas': 1, 'total': 5, 'por_pagina': 25}});
      case ('GET', 'inspecoes'):
        return json({'data': [inspecao]});
      case ('GET', 'reservas'):
        return json({'data': [reserva]});
      case ('GET', 'reservas/materiais'):
        return json({
          'data': [
            {'tipo': 'item', 'id': 15, 'nome': 'Pistola .40', 'categoria': 'Pistola', 'modelo': 'PT 840', 'calibre': '.40', 'tamanho': null, 'numero_serie': 'SZA55120', 'patrimonio': 'PM-0915', 'local': 'Armaria 1'},
            {'tipo': 'colete', 'id': 4, 'nome': 'Colete N-III', 'categoria': 'Colete balístico', 'modelo': 'NIII-A', 'calibre': null, 'tamanho': 'G', 'numero_serie': 'CL-0450', 'patrimonio': null, 'local': 'Armaria 1'},
          ],
          'tolerancia_minutos': 15,
        });
      case ('POST', 'reservas'):
        return assinaturaErrada(corpo) ?? json({'message': 'Reserva registrada e assinada.', 'data': reserva, 'assinatura': {'codigo': '1111-2222-3333-4444'}}, 201);
      case ('GET', 'alertas'):
        return json({'data': alertaPendente || req.url.queryParameters['status'] == 'todas' ? [alerta()] : [], 'pendentes': alertaPendente ? 1 : 0, 'paginacao': {'pagina': 1, 'paginas': 1, 'total': 1, 'por_pagina': 25}});
      case ('GET', 'alertas/55'):
        return json({'data': alerta(completo: true)});
      case ('POST', 'alertas/55/ciencia'):
        final erro = assinaturaErrada(corpo);
        if (erro != null) return erro;
        alertaPendente = false;
        return json({'message': 'Ciência assinada.', 'codigo': 'F00D-CAFE-1234-5678', 'data': alerta()});
      case ('GET', 'avisos'):
        return json({
          'data': avisos == 0 && req.url.queryParameters['todas'] == null
              ? []
              : [{'id': 'a1', 'tipo': 'cautela_urgencia', 'titulo': 'Cautela de urgência', 'texto': 'Assine o recebimento do Fuzil IA2.', 'cor': 'danger', 'cautela_id': 122, 'inspecao_id': null, 'criada_em': iso(hoje), 'lida_em': avisos == 0 ? iso(hoje) : null}],
          'nao_lidos': avisos,
        });
      case ('POST', 'avisos/lidos' || 'avisos/a1/lido'):
        avisos = 0;
        return json({'message': 'Aviso marcado como lido.'});
      case ('GET', 'aparelhos'):
        return json({'data': [{'id': 1, 'aparelho': 'Moto G84 · Android 14', 'plataforma': 'android', 'versao_app': '1.0.0', 'ultimo_ip': null, 'conectado_em': iso(hoje), 'ultimo_uso': iso(hoje), 'expira_em': iso(hoje.add(const Duration(days: 30))), 'este_aparelho': true}]});
      case ('GET', 'ficha'):
        return json({
          'data': {'id': 31, 'name': 'JOÃO BATISTA DA SILVA', 'war_name': 'BATISTA', 'rank': 'CB', 'code': '215.347-8', 'unit': '8º BPM · 1ª CIA', 'situacao_texto': 'Pronto', 'phone': '(84) 99999-0000', 'city': 'Natal', 'cnh_category': 'AB', 'cnh_expires_at': '2029-04-13', 'cnh_situacao': 'valida'},
          'secoes_atualizacao': {'contato': 'Telefone ou e-mail', 'endereco': 'Endereço', 'familia': 'Família e dependentes', 'outro': 'Outro'},
        });
      case ('GET', 'foto'):
        return http.Response.bytes(base64Decode(_fotoDemo), 200, headers: {'content-type': 'image/png'});
      case ('GET', 'caderno'):
        return json({'data': notas});
      case ('POST', 'caderno'):
        if ((corpo['texto'] ?? '').toString().trim().isEmpty) return json({'message': 'Escreva a anotação.', 'errors': {'texto': ['Escreva a anotação.']}}, 422);
        notas.insert(0, {'id': notaId++, 'texto': corpo['texto'], 'criada_em': iso(DateTime.now())});
        return json({'data': notas}, 201);
      case ('GET', 'ocorrencias'):
        return json({'data': pedidos, 'naturezas': ['Furto', 'Roubo', 'Ameaça', 'Perturbação do sossego', 'Violência doméstica', 'Lesão corporal', 'Tráfico de drogas', 'Acidente de trânsito']});
      case ('POST', 'ocorrencias'):
        final erros = <String, List<String>>{
          if ((corpo['natureza'] ?? '').toString().isEmpty) 'natureza': ['Escolha a natureza.'],
          if ((corpo['endereco'] ?? '').toString().isEmpty && corpo['latitude'] == null) 'endereco': ['Informe o endereço ou use a sua localização.'],
        };
        if (erros.isNotEmpty) return json({'message': erros.values.first.first, 'errors': erros}, 422);
        return json({'message': 'Ocorrência enviada ao COPOM. Você será avisado quando responderem.', 'data': pedido('ocorrencia', corpo)}, 201);
      case ('POST', 'apoio'):
        return json({'message': 'Pedido de apoio enviado ao COPOM com a sua localização.', 'data': pedido('apoio', corpo)}, 201);
      case ('POST', 'ficha/atualizacao'):
        return json({'message': 'Pedido enviado ao RH.', 'protocolo': 'ALT-2026-0124'}, 201);
    }
    if (req.method == 'DELETE' && caminho.startsWith('caderno/')) {
      notas.removeWhere((n) => n['id'].toString() == caminho.split('/')[1]);
      return json({'data': notas});
    }
    if (req.method == 'POST' && caminho.startsWith('ocorrencias/') && caminho.endsWith('/cancelar')) {
      final p = pedidos.firstWhere((p) => p['id'].toString() == caminho.split('/')[1]);
      p['situacao'] = 'cancelada';
      p['situacao_texto'] = 'Cancelada';
      return json({'message': 'Pedido cancelado.', 'data': p});
    }
    if (req.method == 'GET' && caminho.startsWith('cautelas/')) {
      final id = int.parse(caminho.split('/')[1]);
      return json({'data': comigo().followedBy([reserva]).firstWhere((c) => c['id'] == id, orElse: () => comigo().first)});
    }
    if (req.method == 'POST' && caminho.endsWith('/assinar-recebimento')) {
      final erro = assinaturaErrada(corpo);
      if (erro != null) return erro;
      recebimentoPendente = false;
      return json({'message': 'Recebimento assinado.', 'assinatura': {'codigo': '9A8B-7C6D-5E4F-3021'}, 'cautelas': [122]});
    }
    return json({'message': 'Registro não encontrado.'}, 404);
  });
}

const _fotoDemo = 'iVBORw0KGgoAAAANSUhEUgAAAHgAAACWCAIAAACaSNt3AAACTElEQVR42u3dMW7cMBAF0HiQc6ZPk8OkSe9TuM8dcp6cIEawEme+yPdbA17y4XtMrVfy28fvP19kfQoBaNACGjRoAQ1aQIMGLaBBC2jQoAU0aAENGrSABi2gI/P1KQv9+ev9X1/68f1b/vrfkj+p9Anu49BDoV8gDueOg75IHMsdBH0jcSB37a289Ds/D3q1RYJ1ba8cYl0nKCdY1yHK49Z1jvLs69ZRux18dW8q7QudcNjqX4NGbwodcp3WvxKN3hE6p87969Fo0KAlGjptQDevSqONDtACGjRoBKBBSzJ05scP21al0UYHaEmHThvTnevR6E2hc0rdvBKN3hc6odT9a9DoraFnSz3y6nXUbgdft45q1uBP0vCM7tz57Lya/2XYs//xo07EqWO1QsKBMuV4t84i5FrUveCnQt/C7ekGy7k9r2MhuifQSN6pA7SABi2gQYMW0E/KA55N+p8X4uHXh4lXhre8gZfmngK99MbKBPR56LZ7V2e5x6AH71geER+ADrkpvJm7FTrwvvsN72E5/OkGHY3OJG6udlHuWWdR7lntqtHxLOKGMVKUe9ZflHt2UZR79lKUe3ZUlHv2VZR7dleUe/bob4ZNKXXu2WlR7tlvUe7ZtRmdPaPPrPOVvRflHgGjI3V0qPNrDhod2Wh1fllDo/Marc5XTDQ6+4JFVkGbGxdlNNroOBDa3Ljuo9FGx2nQ5sYt00OjjQ7QAho0aEeOnoOHRhsdoAU0aNAIQIMW0KBBC2jQcjf0I/4hREg+t9JoowO0gM7NX9Ji9B8rHMy+AAAAAElFTkSuQmCC';
