import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../util/nativo.dart';
import '../widgets/assinatura.dart';
import '../widgets/comum.dart';
import 'cautela.dart';
import 'inspecoes.dart';

Color corPrioridade(String? p) => switch (p) {
      'urgentissima' => const Color(0xFFB71C1C),
      'urgente' => const Color(0xFFE53935),
      'atencao' => const Color(0xFFB8860B),
      _ => const Color(0xFF1F5FB4),
    };

/// Central de Alertas: notificações enviadas a mim e avisos automáticos do sino.
class TelaAlertas extends StatelessWidget {
  const TelaAlertas({super.key, required this.aoMudar});
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const Topo(
          titulo: Text('Alertas'),
          mostrarVoltar: false,
          abas: TabBar(tabs: [Tab(text: 'Notificações'), Tab(text: 'Avisos do sino')]),
        ),
        body: TabBarView(children: [_Notificacoes(aoMudar: aoMudar), _Avisos(aoMudar: aoMudar)]),
      ),
    );
  }
}

class _Notificacoes extends StatefulWidget {
  const _Notificacoes({required this.aoMudar});
  final VoidCallback aoMudar;

  @override
  State<_Notificacoes> createState() => _NotificacoesState();
}

class _NotificacoesState extends State<_Notificacoes> with AutomaticKeepAliveClientMixin {
  final _chave = GlobalKey<CarregarState<List>>();
  bool _todas = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Cores.de(context);
    return Carregar<List>(
      key: _chave,
      buscar: () async => (await apiDe(context).get('alertas', {'status': _todas ? 'todas' : null, 'por_pagina': 100}))['data'] as List,
      construir: (context, lista) => ListView(padding: const EdgeInsets.only(bottom: 16), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            ChoiceChip(label: const Text('Pendentes'), selected: !_todas, onSelected: (_) => setState(() => _mudar(false))),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Todas'), selected: _todas, onSelected: (_) => setState(() => _mudar(true))),
          ]),
        ),
        if (lista.isEmpty) Vazio(_todas ? 'Nenhuma notificação recebida.' : 'Nenhuma notificação pendente.', icone: Icons.mark_email_read_outlined),
        for (final a in lista)
          Cartao(
            bordaEsquerda: corPrioridade(a['prioridade']?.toString()),
            aoTocar: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => TelaAlerta(id: a['id'] as int)));
              _chave.currentState?.recarregar();
              widget.aoMudar();
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${(a['prioridade_texto'] ?? '').toString().toUpperCase()} · ${a['remetente'] ?? ''}',
                  style: TextStyle(color: corPrioridade(a['prioridade']?.toString()), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
              const SizedBox(height: 3),
              Text(a['assunto']?.toString() ?? '', style: TextStyle(fontWeight: a['pendente'] == true ? FontWeight.w900 : FontWeight.w600, fontSize: 15.5)),
              const SizedBox(height: 3),
              Text(
                [
                  dataHora(a['enviada_em']),
                  if (a['cancelada'] == true) 'cancelada',
                  if (a['pendente'] == true && a['exige_assinatura'] == true) 'exige ciência assinada',
                  if (a['ciencia_em'] != null) 'ciência ${dataHora(a['ciencia_em'])}',
                ].join(' · '),
                style: TextStyle(color: c.suave, fontSize: 12.5),
              ),
            ]),
          ),
      ]),
    );
  }

  void _mudar(bool todas) {
    _todas = todas;
    _chave.currentState?.recarregar();
  }
}

/// Uma notificação: texto, anexos e ciência (marcar como lida ou assinar).
class TelaAlerta extends StatefulWidget {
  const TelaAlerta({super.key, required this.id});
  final int id;

  @override
  State<TelaAlerta> createState() => _TelaAlertaState();
}

class _TelaAlertaState extends State<TelaAlerta> {
  final _chave = GlobalKey<CarregarState<Map<String, dynamic>>>();
  bool _enviando = false;

  Future<void> _lida() async {
    setState(() => _enviando = true);
    try {
      final r = await apiDe(context).post('alertas/${widget.id}/lida');
      if (mounted) aviso(context, r['message']?.toString() ?? 'Marcada como lida.');
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    }
    if (mounted) setState(() => _enviando = false);
    _chave.currentState?.recarregar();
  }

  Future<void> _assinar(Map<String, dynamic> a) async {
    final api = apiDe(context);
    final r = await pedirAssinatura<Map<String, dynamic>>(
      context,
      titulo: 'Dar ciência assinada',
      descricao: '"${a['assunto']}" · ${a['prioridade_texto']}. Digite sua matrícula e senha para assinar.',
      botao: 'Assinar ciência',
      assinar: (m, s) => api.post('alertas/${widget.id}/ciencia', {'matricula': m, 'senha': s}),
    );
    if (r == null || !mounted) return;
    aviso(context, 'Ciência assinada. Código ${r['codigo'] ?? ''}');
    _chave.currentState?.recarregar();
  }

  Future<void> _baixar(Map anexo) async {
    aviso(context, 'Baixando ${anexo['nome']}...');
    try {
      final (bytes, tipo) = await apiDe(context).baixar(anexo['baixar'].toString());
      final abriu = await Nativo.abrirArquivo(anexo['nome'].toString(), bytes, tipo?.split(';').first);
      if (!abriu && mounted) aviso(context, 'Nenhum app do celular abre este tipo de arquivo.', erro: true);
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Scaffold(
      appBar: const Topo(titulo: Text('Notificação')),
      body: Carregar<Map<String, dynamic>>(
        key: _chave,
        buscar: () async => (await apiDe(context).get('alertas/${widget.id}'))['data'] as Map<String, dynamic>,
        construir: (context, a) {
          final anexos = (a['anexos'] as List?) ?? const [];
          final pendente = a['pendente'] == true;
          return ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [
            Cartao(
              bordaEsquerda: corPrioridade(a['prioridade']?.toString()),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${(a['prioridade_texto'] ?? '').toString().toUpperCase()} · ${a['tipo_texto'] ?? ''}',
                    style: TextStyle(color: corPrioridade(a['prioridade']?.toString()), fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(a['assunto']?.toString() ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const Divider(height: 22),
                Info('Protocolo', a['protocolo']?.toString()),
                Info('De', a['remetente']?.toString()),
                Info('Enviada em', dataHora(a['enviada_em'])),
                if (a['prazo_ciencia'] != null) Info('Ciência até', dataHora(a['prazo_ciencia'])),
                if (a['referencia'] != null) Info('Referência', a['referencia'].toString()),
                if (a['numero_sei'] != null) Info('Nº SEI', a['numero_sei'].toString()),
                if (a['ciencia_em'] != null) Info('Ciência em', dataHora(a['ciencia_em'])),
                if (a['codigo_ciencia'] != null) Info('Código da ciência', a['codigo_ciencia'].toString()),
              ]),
            ),
            if (a['cancelada'] == true)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Pilula('Notificação cancelada pelo remetente', cor: 'gray')),
            Cartao(child: SelectableText(a['texto']?.toString() ?? '', style: TextStyle(fontSize: 15, height: 1.45, color: c.texto))),
            if (anexos.isNotEmpty) const TituloSecao('Anexos'),
            for (final f in anexos)
              Cartao(
                aoTocar: () => _baixar(f as Map),
                child: Row(children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${f['nome']}\n${tamanhoArquivo(((f['tamanho'] as num?) ?? 0).toInt())}')),
                  const Icon(Icons.download_outlined),
                ]),
              ),
            if (pendente && a['cancelada'] != true)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: a['exige_assinatura'] == true
                    ? FilledButton.icon(onPressed: () => _assinar(a), icon: const Icon(Icons.draw_outlined), label: const Text('DAR CIÊNCIA ASSINADA'))
                    : FilledButton.icon(onPressed: _enviando ? null : _lida, icon: const Icon(Icons.done_all), label: const Text('MARCAR COMO LIDA')),
              ),
          ]);
        },
      ),
    );
  }
}

class _Avisos extends StatefulWidget {
  const _Avisos({required this.aoMudar});
  final VoidCallback aoMudar;

  @override
  State<_Avisos> createState() => _AvisosState();
}

class _AvisosState extends State<_Avisos> with AutomaticKeepAliveClientMixin {
  final _chave = GlobalKey<CarregarState<List>>();
  bool _todos = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _abrir(Map a) async {
    final api = apiDe(context);
    if (a['lida_em'] == null) {
      try {
        await api.post('avisos/${a['id']}/lido');
      } catch (_) {}
      widget.aoMudar();
    }
    if (!mounted) return;
    if (a['cautela_id'] != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => TelaCautela(id: (a['cautela_id'] as num).toInt())));
    } else if (a['inspecao_id'] != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaInspecoes()));
    }
    _chave.currentState?.recarregar();
  }

  Future<void> _lerTodos() async {
    try {
      final r = await apiDe(context).post('avisos/lidos');
      if (mounted) aviso(context, r['message']?.toString() ?? 'Avisos marcados como lidos.');
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    }
    widget.aoMudar();
    _chave.currentState?.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Cores.de(context);
    return Carregar<List>(
      key: _chave,
      buscar: () async => (await apiDe(context).get('avisos', {'todas': _todos ? 1 : null}))['data'] as List,
      construir: (context, lista) => ListView(padding: const EdgeInsets.only(bottom: 16), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            ChoiceChip(label: const Text('Não lidos'), selected: !_todos, onSelected: (_) => _mudar(false)),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Todos'), selected: _todos, onSelected: (_) => _mudar(true)),
            const Spacer(),
            if (lista.any((a) => a['lida_em'] == null)) TextButton(onPressed: _lerTodos, child: const Text('Ler todos')),
          ]),
        ),
        if (lista.isEmpty) const Vazio('Nenhum aviso por aqui.', icone: Icons.notifications_none),
        for (final a in lista)
          Cartao(
            bordaEsquerda: a['lida_em'] == null ? corSituacao(a['cor']?.toString() == 'danger' ? 'red' : a['cor']?.toString(), c.escuro).$2 : null,
            aoTocar: () => _abrir(a as Map),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['titulo']?.toString() ?? 'Aviso', style: TextStyle(fontWeight: a['lida_em'] == null ? FontWeight.w900 : FontWeight.w600, fontSize: 15)),
              if (a['texto'] != null) ...[const SizedBox(height: 3), Text(a['texto'].toString())],
              const SizedBox(height: 3),
              Text(dataHora(a['criada_em']), style: TextStyle(color: c.suave, fontSize: 12)),
            ]),
          ),
      ]),
    );
  }

  void _mudar(bool todos) {
    setState(() => _todos = todos);
    _chave.currentState?.recarregar();
  }
}
