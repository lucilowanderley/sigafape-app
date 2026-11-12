import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../widgets/comum.dart';
import 'alertas.dart';
import 'caderno.dart';
import 'cautela.dart';
import 'inspecoes.dart';
import 'ocorrencias.dart';
import 'reserva.dart';

/// Tela inicial (opção A): cartão do policial e atalhos em grade, como o "Meu painel" da web.
class TelaPainel extends StatefulWidget {
  const TelaPainel({super.key, required this.irPara, required this.aoAtualizar, this.sino = 0});
  final void Function(int aba) irPara;
  final VoidCallback aoAtualizar;

  /// Notificações pendentes + avisos não lidos (número no sino do topo).
  final int sino;

  @override
  State<TelaPainel> createState() => _TelaPainelState();
}

class _TelaPainelState extends State<TelaPainel> {
  final _chave = GlobalKey<CarregarState<Map<String, dynamic>>>();

  Future<Map<String, dynamic>> _buscar() async {
    final api = apiDe(context);
    final sessao = Escopo.ler(context);
    final r = await api.get('painel');
    widget.aoAtualizar();
    final d = Map<String, dynamic>.from(r['data'] as Map<String, dynamic>);
    // Minhas ocorrências (servidor antigo sem a rota: o cartão fica sem número)
    try {
      final o = await api.get('ocorrencias');
      d['_ocorrencias'] = o['data'];
      d['_naturezas'] = o['naturezas'];
    } on ApiErro catch (_) {}
    await sessao.carregarFoto();
    return d;
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    _chave.currentState?.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = Escopo.de(context);
    final pol = sessao.policial;
    return Scaffold(
      appBar: Topo(
        titulo: Marca(unidade: pol?['unidade']?.toString() ?? sessao.usuario?['unidade']?.toString()),
        mostrarVoltar: false,
        acoes: [
          IconButton(
            tooltip: 'Caderno',
            icon: const Icon(Icons.edit_note),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaCaderno())),
          ),
          IconButton(
            tooltip: 'Alertas',
            icon: Badge(
              isLabelVisible: widget.sino > 0,
              label: Text(widget.sino > 99 ? '99+' : '${widget.sino}'),
              child: Icon(widget.sino > 0 ? Icons.notifications_active : Icons.notifications_outlined),
            ),
            onPressed: () => widget.irPara(3),
          ),
        ],
      ),
      body: Carregar<Map<String, dynamic>>(key: _chave, buscar: _buscar, construir: (context, d) => _conteudo(context, d)),
    );
  }

  Widget _conteudo(BuildContext context, Map<String, dynamic> d) {
    final c = Cores.de(context);
    final usuario = d['usuario'] as Map<String, dynamic>? ?? {};
    final pol = usuario['policial'] as Map<String, dynamic>?;
    if (d['vinculado'] != true) {
      return ListView(
        children: [
          _Heroi(usuario: usuario, policial: null),
          const Vazio('Sua conta ainda não está vinculada a um cadastro do Efetivo policial. Procure o RH ou o administrador do sistema.', icone: Icons.link_off),
        ],
      );
    }

    List lista(String k) => (d[k] as List?) ?? const [];
    final agora = d['servico_agora'] as Map<String, dynamic>?;
    final proximo = d['proximo_servico'] as Map<String, dynamic>?;
    final servico = agora ?? proximo;
    final comigo = lista('comigo');
    final pendentes = lista('recebimentos_pendentes');
    final reservas = lista('reservas');
    final convocacoes = lista('convocacoes_inspecao');
    final alertas = lista('alertas_pendentes');
    final avisos = ((d['avisos_nao_lidos'] as num?) ?? 0).toInt();
    final diarias = d['diarias'] as Map<String, dynamic>?;
    final viatura = d['viatura_em_uso'] as Map<String, dynamic>?;
    final urgentes = alertas.where((a) => a['prioridade'] == 'urgente' || a['prioridade'] == 'urgentissima').length;

    // Meu serviço: "Em serviço" (agora), "Escalado" (próximo serviço) ou "Sem escala"; período e função.
    String funcao(Map<String, dynamic> s) => [s['funcao'], s['titulo'] ?? s['tipo']].firstWhere((e) => e != null && e.toString().isNotEmpty, orElse: () => '').toString();
    String periodo(Map<String, dynamic> s) => '${quandoCurto(s['inicio'])}–${hora(s['fim'])}';
    String servicoDetalhe(Map<String, dynamic> s) =>
        [agora != null ? 'até ${hora(s['fim'])}' : periodo(s), funcao(s)].where((e) => e.isNotEmpty).join('\n');

    // Assinar: tudo que espera a minha assinatura (recebimento de cautela + ciência de notificação).
    final assinaturas = d['assinaturas'] as Map<String, dynamic>?;
    final assinarCautelas = ((assinaturas?['cautelas'] as num?) ?? pendentes.length).toInt();
    final assinarNotificacoes = ((assinaturas?['notificacoes'] as num?) ?? 0).toInt();
    final assinarTotal = ((assinaturas?['total'] as num?) ?? assinarCautelas + assinarNotificacoes).toInt();
    String plural(int n, String um, String varios) => '$n ${n == 1 ? um : varios}';
    final assinarDetalhe = assinarTotal == 0
        ? 'nada pendente'
        : [if (assinarCautelas > 0) plural(assinarCautelas, 'cautela', 'cautelas'), if (assinarNotificacoes > 0) plural(assinarNotificacoes, 'notificação', 'notificações')].join(' · ');

    final ocorrencias = (d['_ocorrencias'] as List?)?.cast<Map<String, dynamic>>();
    final aguardando = ocorrencias?.where((o) => o['situacao'] == 'pendente').length ?? 0;
    final ultima = ocorrencias?.isNotEmpty == true ? ocorrencias!.first : null;
    final naturezas = ((d['_naturezas'] as List?) ?? const []).map((e) => e.toString()).toList();

    final atalhos = <_Atalho>[
      _Atalho(
        const Color(0xFFC0392B),
        Icons.local_police_outlined,
        'NOVA',
        'Abrir ocorrência',
        'enviar ao COPOM',
        () => _abrir(naturezas.isEmpty ? const TelaNovaOcorrencia() : TelaNovaOcorrencia(naturezas: naturezas)),
        destaque: true,
      ),
      _Atalho(
        const Color(0xFF8E44AD),
        Icons.assignment_outlined,
        'MINHAS OCORRÊNCIAS',
        aguardando > 0 ? '$aguardando aguardando' : '${ocorrencias?.length ?? 0}',
        ultima == null ? 'últimos 30 dias' : '${ultima['situacao_texto']}',
        () => _abrir(const TelaMinhasOcorrencias()),
      ),
      _Atalho(
        const Color(0xFF1F5FB4),
        Icons.calendar_month_outlined,
        'MEU SERVIÇO',
        servico == null ? 'Sem escala' : (agora != null ? 'Em serviço' : 'Escalado'),
        servico == null ? '${d['servicos_no_mes'] ?? 0} serviço(s) no mês' : servicoDetalhe(servico),
        () => _abrir(_TelaAgenda(dados: d)),
      ),
      _Atalho(const Color(0xFF1D8A45), Icons.inventory_2_outlined, 'COMIGO AGORA', '${comigo.length}', comigo.length == 1 ? 'material' : 'materiais', () => widget.irPara(1)),
      _Atalho(
        const Color(0xFF0F7C8C),
        Icons.schedule,
        'RESERVAS',
        '${reservas.length}',
        reservas.isEmpty ? 'nenhuma pendente' : quandoCurto(reservas.first['retirada_prevista']),
        () => widget.irPara(2),
      ),
      _Atalho(
        const Color(0xFFC0392B),
        Icons.draw_outlined,
        'ASSINAR',
        '$assinarTotal',
        assinarDetalhe,
        () => _abrir(TelaAssinaturas(cautelas: pendentes.cast<Map<String, dynamic>>())),
      ),
      _Atalho(
        const Color(0xFFB8860B),
        Icons.verified_user_outlined,
        'INSPEÇÃO',
        convocacoes.isEmpty ? 'Em dia' : 'Até ${diaMes(convocacoes.first['apresentar_ate'])}',
        convocacoes.isEmpty ? 'sem convocação' : 'apresentar ${convocacoes.first['material'] ?? 'material'}',
        () => _abrir(const TelaInspecoes()),
      ),
      _Atalho(
        const Color(0xFFE06A17),
        Icons.notifications_outlined,
        'ALERTAS',
        '${alertas.length + avisos}',
        urgentes > 0 ? '$urgentes urgente${urgentes > 1 ? 's' : ''}' : 'para ciência',
        () => widget.irPara(3),
      ),
      if (diarias != null)
        _Atalho(
          const Color(0xFF7A5BD0),
          Icons.sell_outlined,
          'DIÁRIAS DO MÊS',
          '${diarias['no_mes'] ?? 0}${diarias['limite'] != null ? '/${diarias['limite']}' : ''}',
          '${(diarias['lista'] as List?)?.length ?? 0} lançamento(s)',
          () => _abrir(_TelaDiarias(diarias: diarias)),
        ),
      _Atalho(const Color(0xFFB8860B), Icons.calculate_outlined, 'FERRAMENTAS', 'Reserva', 'calcular minha data', () => _abrir(const TelaReserva())),
      _Atalho(const Color(0xFF16335F), Icons.badge_outlined, 'MEUS DADOS', 'Ficha', 'consultar', () => widget.irPara(4)),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _Heroi(usuario: usuario, policial: pol),
        if (viatura != null)
          Cartao(
            bordaEsquerda: const Color(0xFF7A5BD0),
            child: Row(
              children: [
                const Icon(Icons.directions_car_outlined),
                const SizedBox(width: 10),
                Expanded(child: Text('Viatura em uso: ${viatura['prefixo'] ?? ''} ${viatura['placa'] != null ? '(${viatura['placa']})' : ''} · saída ${hora(viatura['saida'])}')),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.18,
            children: atalhos.map((a) => _CartaoAtalho(a)).toList(),
          ),
        ),
        if (lista('depositos').isNotEmpty) ...[
          const TituloSecao('Depósitos na armaria'),
          for (final dep in lista('depositos'))
            Cartao(
              child: Text(
                '${dep['descricao'] ?? dep['tipo']} · ${dep['numero_serie'] ?? ''}\nDesde ${dataCurta(dep['depositado_em'])}${dep['retorno_previsto'] != null ? ' · retorno ${dataCurta(dep['retorno_previsto'])}' : ''}',
                style: TextStyle(color: c.texto),
              ),
            ),
        ],
        if (lista('patrimonio').isNotEmpty) ...[
          const TituloSecao('Patrimônio sob minha guarda'),
          for (final p in lista('patrimonio')) Cartao(child: Text('${p['nome']} · tomb. ${p['tombamento'] ?? '—'}${p['estado'] != null ? ' · ${p['estado']}' : ''}')),
        ],
      ],
    );
  }
}

class _Heroi extends StatelessWidget {
  const _Heroi({required this.usuario, required this.policial});
  final Map<String, dynamic> usuario;
  final Map<String, dynamic>? policial;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final nome = policial?['nome'] ?? usuario['nome'] ?? '';
    final externo = policial?['de_outra_unidade'] as Map<String, dynamic>?;
    final foto = Escopo.de(context).foto;
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: c.heroi, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border(bottom: BorderSide(color: c.dourado, width: 4)),
          ),
          child: Row(
            children: [
              foto != null
                  ? Container(
                      width: 60,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.dourado, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(foto, fit: BoxFit.cover, gaplessPlayback: true, semanticLabel: 'Foto 3x4 do Efetivo'),
                    )
                  : CircleAvatar(
                      radius: 28,
                      backgroundColor: c.dourado,
                      child: Text(
                        usuario['iniciais']?.toString() ?? '',
                        style: TextStyle(color: c.entrada, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saudacao(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      nome.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19),
                    ),
                    if (policial != null) Text('Mat. ${policial!['matricula'] ?? '—'} · ${policial!['unidade'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (policial?['situacao'] != null) Pilula(policial!['situacao'].toString(), cor: policial!['situacao'] == 'Pronto' ? 'green' : 'gold'),
                        if (externo != null) Pilula('De ${externo['unidade_origem'] ?? 'outra unidade'} até ${dataCurta(externo['ate'])}', cor: 'blue'),
                      ],
                    ),
                  ],
                ),
              ),
              // Espaço para o ícone de apoio no canto inferior direito
              if (policial != null) const SizedBox(width: 30),
            ],
          ),
        ),
        if (policial != null)
          Positioned(
            right: 20,
            bottom: 22,
            child: Material(
              color: const Color(0xFFC0392B),
              shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => pedirApoio(context),
                child: const Tooltip(
                  message: 'Pedir apoio urgente',
                  child: Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(Icons.campaign, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Atalho {
  _Atalho(this.cor, this.icone, this.rotulo, this.valor, this.detalhe, this.aoTocar, {this.destaque = false});
  final Color cor;
  final IconData icone;
  final String rotulo, valor, detalhe;
  final VoidCallback aoTocar;
  final bool destaque;
}

class _CartaoAtalho extends StatelessWidget {
  const _CartaoAtalho(this.a);
  final _Atalho a;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Material(
      color: a.destaque ? Color.alphaBlend(a.cor.withValues(alpha: c.escuro ? .16 : .06), c.cartao) : c.cartao,
      elevation: c.escuro ? 0 : 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: a.aoTocar,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: a.cor, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: a.cor.withValues(alpha: c.escuro ? .22 : .13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.icone, color: a.cor, size: 20),
              ),
              const Spacer(),
              Text(
                a.rotulo,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .5, color: c.suave),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  a.valor,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: a.destaque ? a.cor : null),
                ),
              ),
              Text(
                a.detalhe,
                maxLines: a.detalhe.contains('\n') ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.suave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agenda de 30 dias (serviços, escalas, operações).
class _TelaAgenda extends StatelessWidget {
  const _TelaAgenda({required this.dados});
  final Map<String, dynamic> dados;

  @override
  Widget build(BuildContext context) {
    final agora = dados['servico_agora'] as Map<String, dynamic>?;
    final agenda = (dados['agenda'] as List?) ?? const [];
    Widget item(Map s, {bool emCurso = false}) => Cartao(
      bordaEsquerda: emCurso ? const Color(0xFF1D8A45) : const Color(0xFF1F5FB4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${emCurso ? 'AGORA · ' : ''}${quandoCurto(s['inicio'])} até ${hora(s['fim'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text([s['titulo'], s['tipo'], s['posto'], s['funcao'], if (s['viatura'] != null) 'VTR ${s['viatura']}'].where((e) => e != null && e.toString().isNotEmpty).join(' · ')),
        ],
      ),
    );
    return Scaffold(
      appBar: const Topo(titulo: Text('Meu serviço')),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        children: [
          if (agora != null) item(agora, emCurso: true),
          if (agenda.isEmpty && agora == null) const Vazio('Nenhum serviço nos próximos 30 dias.', icone: Icons.event_available),
          for (final s in agenda) item(s as Map),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${dados['servicos_no_mes'] ?? 0} serviço(s) neste mês.', style: TextStyle(color: Cores.de(context).suave)),
          ),
        ],
      ),
    );
  }
}

class _TelaDiarias extends StatelessWidget {
  const _TelaDiarias({required this.diarias});
  final Map<String, dynamic> diarias;

  @override
  Widget build(BuildContext context) {
    final lista = (diarias['lista'] as List?) ?? const [];
    return Scaffold(
      appBar: const Topo(titulo: Text('Diárias do mês')),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          Cartao(
            child: Text(
              '${diarias['no_mes'] ?? 0} diária(s) no mês${diarias['limite'] != null ? ' · limite ${diarias['limite']}' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          if (lista.isEmpty) const Vazio('Nenhuma diária lançada neste mês.'),
          for (final g in lista)
            Cartao(
              child: Row(
                children: [
                  Expanded(child: Text('${dataCurta(g['data'])} · ${g['origem']}\n${g['quantidade']} diária(s)')),
                  Pilula(g['situacao']?.toString() ?? ''),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tudo que espera a minha assinatura: recebimento de cautela de urgência e ciência assinada de notificação.
class TelaAssinaturas extends StatefulWidget {
  const TelaAssinaturas({super.key, required this.cautelas});
  final List<Map<String, dynamic>> cautelas;

  @override
  State<TelaAssinaturas> createState() => _TelaAssinaturasState();
}

class _TelaAssinaturasState extends State<TelaAssinaturas> {
  final _chave = GlobalKey<CarregarState<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>>();

  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _buscar() async {
    final api = apiDe(context);
    final r = await Future.wait([api.get('painel'), api.get('alertas', {'por_pagina': 100})]);
    final cautelas = (((r[0]['data'] as Map?)?['recebimentos_pendentes'] as List?) ?? widget.cautelas).cast<Map<String, dynamic>>();
    final notificacoes = ((r[1]['data'] as List?) ?? const []).cast<Map<String, dynamic>>().where((a) => a['pendente'] == true && a['exige_assinatura'] == true).toList();
    return (cautelas, notificacoes);
  }

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    _chave.currentState?.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Scaffold(
      appBar: const Topo(titulo: Text('Assinaturas pendentes')),
      body: Carregar<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
        key: _chave,
        buscar: _buscar,
        construir: (context, d) {
          final (cautelas, notificacoes) = d;
          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (cautelas.isEmpty && notificacoes.isEmpty) const Vazio('Nenhuma assinatura pendente.', icone: Icons.task_alt),
              if (cautelas.isNotEmpty) TituloSecao('Recebimento de cautela (${cautelas.length})'),
              for (final l in cautelas)
                Cartao(
                  bordaEsquerda: const Color(0xFFC0392B),
                  aoTocar: () => _abrir(TelaCautela(id: l['id'] as int)),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${l['material'] ?? ''} · ${l['numero_serie'] ?? ''}\n${l['motivo_urgencia'] ?? 'Cautela de urgência'}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Icon(Icons.chevron_right, color: c.suave),
                  ]),
                ),
              if (notificacoes.isNotEmpty) TituloSecao('Ciência de notificação (${notificacoes.length})'),
              for (final a in notificacoes)
                Cartao(
                  bordaEsquerda: corPrioridade(a['prioridade']?.toString()),
                  aoTocar: () => _abrir(TelaAlerta(id: a['id'] as int)),
                  child: Row(children: [
                    Icon(Icons.notifications_outlined, color: corPrioridade(a['prioridade']?.toString())),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${(a['prioridade_texto'] ?? '').toString().toUpperCase()} · ${a['remetente'] ?? ''}',
                            style: TextStyle(color: corPrioridade(a['prioridade']?.toString()), fontSize: 11.5, fontWeight: FontWeight.w800)),
                        Text(a['assunto']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (a['prazo_ciencia'] != null) Text('Prazo: ${dataHora(a['prazo_ciencia'])}', style: TextStyle(color: c.suave, fontSize: 12.5)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: c.suave),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}
