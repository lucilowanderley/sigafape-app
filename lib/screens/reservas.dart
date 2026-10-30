import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../widgets/assinatura.dart';
import '../widgets/comum.dart';
import 'cautela.dart';

/// Reservas que registrei, com cancelamento e nova reserva assinada.
class TelaReservas extends StatefulWidget {
  const TelaReservas({super.key});

  @override
  State<TelaReservas> createState() => _TelaReservasState();
}

class _TelaReservasState extends State<TelaReservas> {
  final _chave = GlobalKey<CarregarState<List>>();

  Future<void> _cancelar(Map<String, dynamic> r) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r['material']} · retirada ${quandoCurto(r['retirada_prevista'])}'),
          const SizedBox(height: 12),
          TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo (opcional)'), maxLength: 255),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar reserva')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await apiDe(context).post('reservas/${r['id']}/cancelar', {'motivo': motivo.text.trim().isEmpty ? null : motivo.text.trim()});
      if (mounted) aviso(context, res['message']?.toString() ?? 'Reserva cancelada.');
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    }
    _chave.currentState?.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Topo(titulo: Text('Reservas'), mostrarVoltar: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final feita = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const TelaNovaReserva()));
          if (feita == true) _chave.currentState?.recarregar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova reserva'),
      ),
      body: Carregar<List>(
        key: _chave,
        buscar: () async => (await apiDe(context).get('reservas'))['data'] as List,
        construir: (context, lista) {
          final pendentes = lista.where((r) => r['status'] == 'reservada').toList();
          final outras = lista.where((r) => r['status'] != 'reservada').toList();
          return ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            const TituloSecao('Aguardando retirada'),
            if (pendentes.isEmpty) const Vazio('Nenhuma reserva aguardando retirada.', icone: Icons.event_available),
            for (final r in pendentes)
              Column(children: [
                LinhaCautela(c: r, mostrarReserva: true, aoTocar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaCautela(id: r['id'] as int)))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(children: [
                    Expanded(
                      child: Text('Confirme na armaria até ${hora(r['prazo_confirmacao'])}, senão a reserva cai.',
                          style: TextStyle(color: Cores.de(context).suave, fontSize: 12.5)),
                    ),
                    TextButton(onPressed: () => _cancelar(r), child: const Text('Cancelar')),
                  ]),
                ),
              ]),
            if (outras.isNotEmpty) const TituloSecao('Anteriores'),
            for (final r in outras)
              LinhaCautela(c: r, mostrarReserva: true, aoTocar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaCautela(id: r['id'] as int)))),
          ]);
        },
      ),
    );
  }
}

/// Nova reserva: escolher o material, a hora da retirada e a devolução, e assinar com matrícula + senha.
class TelaNovaReserva extends StatefulWidget {
  const TelaNovaReserva({super.key});

  @override
  State<TelaNovaReserva> createState() => _TelaNovaReservaState();
}

class _TelaNovaReservaState extends State<TelaNovaReserva> {
  final _busca = TextEditingController();
  final _obs = TextEditingController();
  Timer? _espera;
  List<Map<String, dynamic>> _materiais = [];
  int _tolerancia = 15;
  String _tipo = '';
  bool _buscando = false;
  Object? _erro;
  Map<String, dynamic>? _escolhido;
  DateTime _retirada = DateTime.now().add(const Duration(hours: 1));
  DateTime? _devolucao;

  @override
  void initState() {
    super.initState();
    _devolucao = DateTime(_retirada.year, _retirada.month, _retirada.day + 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busca.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _erro = null;
    });
    try {
      final r = await apiDe(context).get('reservas/materiais', {'busca': _busca.text.trim(), 'tipo': _tipo});
      setState(() {
        _materiais = (r['data'] as List).cast<Map<String, dynamic>>();
        _tolerancia = ((r['tolerancia_minutos'] as num?) ?? 15).toInt();
      });
    } catch (e) {
      setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _escolherRetirada() async {
    final dia = await showDatePicker(context: context, initialDate: _retirada, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
    if (dia == null || !mounted) return;
    final h = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_retirada));
    if (h == null) return;
    setState(() {
      _retirada = DateTime(dia.year, dia.month, dia.day, h.hour, h.minute);
      if (_devolucao != null && _devolucao!.isBefore(DateTime(dia.year, dia.month, dia.day))) _devolucao = DateTime(dia.year, dia.month, dia.day + 1);
    });
  }

  Future<void> _escolherDevolucao() async {
    final base = DateTime(_retirada.year, _retirada.month, _retirada.day);
    final dia = await showDatePicker(context: context, initialDate: _devolucao ?? base, firstDate: base, lastDate: base.add(const Duration(days: 90)));
    if (dia != null) setState(() => _devolucao = dia);
  }

  Future<void> _reservar() async {
    final m = _escolhido!;
    final api = apiDe(context);
    final f = DateFormat('yyyy-MM-dd HH:mm');
    final r = await pedirAssinatura<Map<String, dynamic>>(
      context,
      titulo: 'Assinar reserva',
      descricao: '${m['nome']}${m['numero_serie'] != null ? ' · ${m['numero_serie']}' : ''} · retirada ${DateFormat('dd/MM HH:mm').format(_retirada)}. '
          'Se a armaria não confirmar em $_tolerancia min, a reserva cai.',
      botao: 'Assinar e reservar',
      assinar: (mat, senha) => api.post('reservas', {
        'tipo': m['tipo'],
        'material_id': m['id'],
        'retirada_prevista': f.format(_retirada),
        'devolucao_prevista': _devolucao == null ? null : DateFormat('yyyy-MM-dd').format(_devolucao!),
        'observacoes': _obs.text.trim().isEmpty ? null : _obs.text.trim(),
        'matricula': mat,
        'senha': senha,
      }),
    );
    if (r == null || !mounted) return;
    aviso(context, r['message']?.toString() ?? 'Reserva registrada.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final m = _escolhido;
    return Scaffold(
      appBar: const Topo(titulo: Text('Nova reserva')),
      body: m == null ? _lista(c) : _formulario(c, m),
    );
  }

  Widget _lista(Cores c) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _busca,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nome, nº de série ou patrimônio'),
            onChanged: (_) {
              _espera?.cancel();
              _espera = Timer(const Duration(milliseconds: 450), _buscar);
            },
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
            for (final e in {'': 'Tudo', 'item': 'Armas e equipamentos', 'colete': 'Coletes'}.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(e.value), selected: _tipo == e.key, onSelected: (_) {
                  _tipo = e.key;
                  _buscar();
                }),
              ),
          ]),
        ),
        if (_buscando) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _erro != null
              ? Falha(_erro!, tentar: _buscar)
              : ListView(padding: const EdgeInsets.only(bottom: 16), children: [
                  if (!_buscando && _materiais.isEmpty) const Vazio('Nenhum material disponível com essa busca.', icone: Icons.search_off),
                  for (final mat in _materiais)
                    Cartao(
                      aoTocar: () => setState(() => _escolhido = mat),
                      child: Row(children: [
                        Icon(iconeMaterial(mat['tipo']?.toString(), mat['categoria']?.toString()), size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(mat['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                            Text(
                              [mat['numero_serie'], mat['categoria'], mat['calibre'], mat['tamanho'], mat['local']].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
                              style: TextStyle(color: c.suave, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: c.suave),
                      ]),
                    ),
                ]),
        ),
      ]);

  Widget _formulario(Cores c, Map<String, dynamic> m) => ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [
        Cartao(
          child: Row(children: [
            Icon(iconeMaterial(m['tipo']?.toString(), m['categoria']?.toString()), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text('${m['numero_serie'] ?? ''} · disponível', style: TextStyle(color: c.suave, fontSize: 12.5)),
              ]),
            ),
            TextButton(onPressed: () => setState(() => _escolhido = null), child: const Text('Trocar')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 6),
            _Campo(rotulo: 'Retirada', valor: DateFormat("dd/MM/yyyy 'às' HH:mm").format(_retirada), icone: Icons.schedule, aoTocar: _escolherRetirada),
            const SizedBox(height: 10),
            _Campo(rotulo: 'Devolução', valor: _devolucao == null ? 'Não informada' : DateFormat('dd/MM/yyyy').format(_devolucao!), icone: Icons.event, aoTocar: _escolherDevolucao),
            const SizedBox(height: 10),
            TextField(controller: _obs, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações (ex.: serviço extra)')),
            Text('A reserva sai em seu nome. Se a armaria não confirmar a retirada até $_tolerancia minutos depois do horário, ela é cancelada automaticamente.',
                style: TextStyle(color: c.suave, fontSize: 12.5)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _reservar, icon: const Icon(Icons.lock_outline, size: 18), label: const Text('ASSINAR E RESERVAR')),
          ]),
        ),
      ]);
}

class _Campo extends StatelessWidget {
  const _Campo({required this.rotulo, required this.valor, required this.icone, required this.aoTocar});
  final String rotulo, valor;
  final IconData icone;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: rotulo, suffixIcon: Icon(icone)),
          child: Text(valor, style: const TextStyle(fontSize: 15.5)),
        ),
      );
}
