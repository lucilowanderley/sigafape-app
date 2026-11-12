import 'package:flutter/material.dart';
import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../widgets/comum.dart';

const _azul = Color(0xFF1F5FBF), _verde = Color(0xFF1D8A45), _laranja = Color(0xFFE07B12), _roxo = Color(0xFF7A5BD0);
const _semana = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// Diárias (opção A): resumo do mês, vagas abertas publicadas pelo P/3 com AGENDAR e minhas inscrições e diárias.
/// Em servidor antigo (sem vagas), mostra só as diárias lançadas no mês que vieram no painel.
class TelaDiarias extends StatefulWidget {
  const TelaDiarias({super.key, this.doPainel});
  final Map<String, dynamic>? doPainel;

  @override
  State<TelaDiarias> createState() => _TelaDiariasState();
}

class _TelaDiariasState extends State<TelaDiarias> {
  final _chave = GlobalKey<CarregarState<Map<String, dynamic>?>>();
  final Set<int> _enviando = {};

  Future<Map<String, dynamic>?> _buscar() async {
    try {
      return await apiDe(context).get('diarias');
    } on ApiErro catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<void> _agendar(Map v) async {
    final id = v['vaga_id'] as int;
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.event_available, color: _verde, size: 38),
        title: const Text('Agendar esta diária?'),
        content: Text('${v['titulo']}\n${_dataLonga(v['data'])} · ${v['horario']}\n${v['local'] ?? ''}\n\nA inscrição vai para o P/3 confirmar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: _verde), onPressed: () => Navigator.pop(ctx, true), child: const Text('AGENDAR')),
        ],
      ),
    );
    if (sim != true || !mounted) return;
    await _acao(id, () => apiDe(context).post('diarias/vagas/$id/agendar'));
  }

  Future<void> _cancelar(Map m) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar a inscrição?'),
        content: Text('${m['titulo']} · ${_dataLonga(m['data'])}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B)), onPressed: () => Navigator.pop(ctx, true), child: const Text('CANCELAR INSCRIÇÃO')),
        ],
      ),
    );
    if (sim != true || !mounted) return;
    await _acao(m['vaga_id'] as int, () => apiDe(context).post('diarias/inscricoes/${m['id']}/cancelar'));
  }

  Future<void> _acao(int vaga, Future<Map<String, dynamic>> Function() fazer) async {
    setState(() => _enviando.add(vaga));
    try {
      final r = await fazer();
      if (mounted) aviso(context, r['message']?.toString() ?? 'Pronto.');
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    } finally {
      if (mounted) setState(() => _enviando.remove(vaga));
      await _chave.currentState?.recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const Topo(titulo: Text('Diárias'), abas: TabBar(tabs: [Tab(text: 'Vagas abertas'), Tab(text: 'Minhas diárias')])),
        body: Carregar<Map<String, dynamic>?>(
          key: _chave,
          buscar: _buscar,
          construir: (context, d) {
            if (d == null) return TabBarView(children: [_antigo(context, vagas: true), _antigo(context)]);
            final resumo = (d['resumo'] as Map?) ?? const {};
            final vagas = ((d['vagas'] as List?) ?? const []).cast<Map>();
            final minhas = ((d['minhas'] as List?) ?? const []).cast<Map>();
            return TabBarView(children: [
              ListView(padding: const EdgeInsets.only(top: 10, bottom: 20), children: [
                _Resumo(resumo),
                _limite(context, resumo),
                TituloSecao(d['mes_texto']?.toString() ?? 'Vagas do mês'),
                if (vagas.isEmpty) const Vazio('Nenhuma vaga aberta agora. Quando o P/3 publicar, ela aparece aqui.'),
                for (final v in vagas) _vaga(context, v),
              ]),
              ListView(padding: const EdgeInsets.only(top: 10, bottom: 20), children: [
                _Resumo(resumo, compacto: true),
                const SizedBox(height: 6),
                if (minhas.isEmpty) const Vazio('Você ainda não tem diárias nem inscrições neste mês.'),
                for (final m in minhas) _minha(context, m),
              ]),
            ]);
          },
        ),
      ),
    );
  }

  Widget _limite(BuildContext context, Map resumo) {
    final c = Cores.de(context);
    final limite = resumo['limite'], posso = resumo['posso_tirar'];
    final texto = limite == null ? 'Sem limite de diárias por policial no mês.' : 'Limite do mês: $limite diárias · você pode agendar mais $posso';
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(texto, style: TextStyle(fontSize: 12.5, color: c.suave)));
  }

  Widget _vaga(BuildContext context, Map v) {
    final c = Cores.de(context);
    final minha = v['minha'] as Map?;
    final ocupado = _enviando.contains(v['vaga_id']);
    final livres = v['livres'] ?? 0;
    final qtd = (v['quantidade'] ?? 1) as int;
    Widget acao;
    if (ocupado) {
      acao = const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5));
    } else if (minha != null) {
      acao = Pilula(minha['situacao_texto']?.toString() ?? '', cor: minha['situacao'] == 'confirmada' ? 'green' : 'gold');
    } else {
      acao = FilledButton(
        key: Key('agendar-${v['vaga_id']}'),
        onPressed: livres > 0 ? () => _agendar(v) : null,
        style: FilledButton.styleFrom(backgroundColor: _verde, minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
        child: Text(livres > 0 ? 'AGENDAR' : 'LOTADA'),
      );
    }
    return Cartao(
      bordaEsquerda: minha == null ? _azul : (minha['situacao'] == 'confirmada' ? _verde : _laranja),
      child: Row(children: [
        _Dia(v['data']),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v['titulo']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text([v['horario'], v['local']].where((e) => e != null && e.toString().isNotEmpty).join(' · '), style: TextStyle(color: c.suave, fontSize: 12.5)),
            Text('$livres de ${v['vagas']} vagas livres${qtd > 1 ? ' · $qtd diárias' : ''}', style: TextStyle(color: c.suave, fontSize: 12.5)),
            if ((v['observacao'] ?? '').toString().isNotEmpty) Text(v['observacao'].toString(), style: TextStyle(color: c.suave, fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ),
        const SizedBox(width: 8),
        acao,
      ]),
    );
  }

  Widget _minha(BuildContext context, Map m) {
    final c = Cores.de(context);
    final s = m['situacao']?.toString();
    final cor = switch (s) { 'confirmada' => 'green', 'cumprida' => 'blue', 'inscrita' => 'gold', 'recusada' => 'red', _ => null };
    return Cartao(
      bordaEsquerda: switch (s) { 'confirmada' => _verde, 'cumprida' => _roxo, 'inscrita' => _laranja, 'recusada' => const Color(0xFFC0392B), _ => null },
      child: Row(children: [
        _Dia(m['data']),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m['titulo']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text([m['horario'], m['local'], '${m['quantidade'] ?? 1} diária(s)'].where((e) => e != null && e.toString().isNotEmpty).join(' · '), style: TextStyle(color: c.suave, fontSize: 12.5)),
            if ((m['resposta'] ?? '').toString().isNotEmpty) Text('${s == 'recusada' ? 'Motivo: ' : ''}${m['resposta']}', style: TextStyle(color: c.suave, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Pilula(m['situacao_texto']?.toString() ?? '', cor: cor),
          if (m['pode_cancelar'] == true)
            TextButton(
              key: Key('cancelar-${m['id']}'),
              onPressed: _enviando.contains(m['vaga_id']) ? null : () => _cancelar(m),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFC0392B), minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 6)),
              child: const Text('Cancelar'),
            ),
        ]),
      ]),
    );
  }

  /// Servidor sem vagas: as diárias lançadas no mês (como era antes).
  Widget _antigo(BuildContext context, {bool vagas = false}) {
    final d = widget.doPainel ?? const {};
    final lista = (d['lista'] as List?) ?? const [];
    return ListView(padding: const EdgeInsets.only(top: 12), children: [
      if (vagas) const Vazio('O agendamento de diárias pelo app ainda não está ligado no servidor.'),
      if (!vagas) ...[
        Cartao(child: Text('${d['no_mes'] ?? 0} diária(s) no mês${d['limite'] != null ? ' · limite ${d['limite']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        if (lista.isEmpty) const Vazio('Nenhuma diária lançada neste mês.'),
        for (final g in lista)
          Cartao(child: Row(children: [Expanded(child: Text('${dataCurta(g['data'])} · ${g['origem']}\n${g['quantidade']} diária(s)')), Pilula(g['situacao']?.toString() ?? '')])),
      ],
    ]);
  }
}

String _dataLonga(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '');
  if (d == null) return '';
  return '${_semana[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _Dia extends StatelessWidget {
  const _Dia(this.iso);
  final dynamic iso;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final d = DateTime.tryParse(iso?.toString() ?? '');
    return SizedBox(
      width: 40,
      child: Column(children: [
        Text(d == null ? '–' : '${d.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(d == null ? '' : _semana[d.weekday - 1], style: TextStyle(fontSize: 11, color: c.suave, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Os 4 números do mês: vagas abertas, posso tirar, me cadastrei, já tirei.
class _Resumo extends StatelessWidget {
  const _Resumo(this.r, {this.compacto = false});
  final Map r;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    Widget n(String chave, String v, String rotulo, Color cor, IconData i) => Expanded(
          child: Container(
            key: Key('resumo-$chave'),
            margin: const EdgeInsets.all(3),
            padding: EdgeInsets.symmetric(vertical: compacto ? 6 : 10, horizontal: 4),
            decoration: BoxDecoration(color: cor.withValues(alpha: .10), borderRadius: BorderRadius.circular(12), border: Border.all(color: cor.withValues(alpha: .35))),
            child: Column(children: [
              if (!compacto) Icon(i, color: cor, size: 20),
              Text(v, style: TextStyle(fontSize: compacto ? 18 : 22, fontWeight: FontWeight.w900, color: cor)),
              Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        n('previstas', '${r['previstas'] ?? 0}', 'Previstas\n(vagas abertas)', _azul, Icons.event_available),
        n('posso', r['posso_tirar'] == null ? '∞' : '${r['posso_tirar']}', 'Posso\ntirar', _verde, Icons.check_circle_outline),
        n('cadastrei', '${r['me_cadastrei'] ?? 0}', 'Me\ncadastrei', _laranja, Icons.how_to_reg),
        n('tirei', '${r['tirei'] ?? 0}', 'Já tirei\nno mês', _roxo, Icons.sell_outlined),
      ]),
    );
  }
}
