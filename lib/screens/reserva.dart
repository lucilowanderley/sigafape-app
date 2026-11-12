import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../widgets/comum.dart';

/// Calculadora de reserva remunerada (LC 692/2021), igual à do Meu painel na web (visual B: data em destaque,
/// anel com o percentual cumprido e linha do tempo). A conta é feita pelo servidor; nada é gravado.
class TelaReserva extends StatefulWidget {
  const TelaReserva({super.key});

  @override
  State<TelaReserva> createState() => _TelaReservaState();
}

class _TelaReservaState extends State<TelaReserva> {
  DateTime? _ingresso;
  final _anos = TextEditingController(text: '0');
  final _meses = TextEditingController(text: '0');
  final _dias = TextEditingController(text: '0');
  String _origem = 'fa';
  int _licencas = 0;
  Map<String, dynamic>? _resultado;
  String? _aviso, _erro;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calcular(primeira: true));
  }

  @override
  void dispose() {
    _anos.dispose();
    _meses.dispose();
    _dias.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _calcular({bool primeira = false}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await apiDe(context).get('calculadora-reserva', {
        if (!primeira && _ingresso != null) 'ingresso': _iso(_ingresso!),
        if (!primeira) ...{'anos': _anos.text, 'meses': _meses.text, 'dias': _dias.text, 'origem': _origem, 'licencas': _licencas},
      });
      final campos = r['campos'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _ingresso = lerData(campos['ingresso']) ?? _ingresso;
        _resultado = r['resultado'] as Map<String, dynamic>?;
        _aviso = r['aviso']?.toString();
      });
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.detalhe);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _ingresso ?? DateTime(2010),
      firstDate: DateTime(1961),
      lastDate: DateTime.now(),
      helpText: 'Data de ingresso na PM',
    );
    if (d != null) setState(() => _ingresso = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    Widget numero(TextEditingController ctl, String rotulo) => Expanded(
          child: TextField(controller: ctl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: rotulo, isDense: true)),
        );
    final r = _resultado;
    return Scaffold(
      appBar: const Topo(titulo: Text('Calculadora de reserva')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Cartao(
            margem: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton.icon(
                onPressed: _escolherData,
                icon: const Icon(Icons.event),
                label: Text(_ingresso == null ? 'Data de ingresso na PM' : 'Ingresso: ${dataCurta(_iso(_ingresso!))}'),
              ),
              const SizedBox(height: 10),
              Text('Tempo anterior averbado', style: TextStyle(color: c.suave, fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 4),
              Row(children: [numero(_anos, 'Anos'), const SizedBox(width: 8), numero(_meses, 'Meses'), const SizedBox(width: 8), numero(_dias, 'Dias')]),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'fa', label: Text('Forças Armadas')), ButtonSegment(value: 'civil', label: Text('CLT / civil'))],
                selected: {_origem},
                onSelectionChanged: (v) => setState(() => _origem = v.first),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('Licenças especiais não gozadas')),
                SegmentedButton<int>(
                  segments: const [ButtonSegment(value: 0, label: Text('0')), ButtonSegment(value: 1, label: Text('1')), ButtonSegment(value: 2, label: Text('2'))],
                  selected: {_licencas},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => _licencas = v.first),
                ),
              ]),
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: _carregando ? null : () => _calcular(), icon: const Icon(Icons.calculate_outlined), label: const Text('CALCULAR')),
            ]),
          ),
          if (_carregando) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_erro != null) Cartao(bordaEsquerda: const Color(0xFFC0392B), child: Text(_erro!)),
          if (!_carregando && r == null && _aviso != null) Vazio(_aviso!, icone: Icons.event),
          if (!_carregando && r != null) ...[
            _Destaque(r: r),
            const TituloSecao('Linha do tempo'),
            Cartao(child: Column(children: [for (final p in ((r['linha_do_tempo'] as List?) ?? const [])) _Passo(p as Map<String, dynamic>)])),
            const TituloSecao('Como a data foi calculada'),
            Cartao(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['regra']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Tempo de serviço exigido: ${r['exigido_servico']}${r['pedagio'] != null ? ' (com pedágio de ${r['pedagio']})' : ''}'),
                if (r['exigido_militar'] != null) Text('Atividade militar exigida: ${r['exigido_militar']}'),
                Text('Hoje você tem ${r['servico_hoje']} de serviço.'),
                if (r['anterior_glosado'] != null) Text('Tempo civil acima de 5 anos não conta: ${r['anterior_glosado']} desconsiderados.'),
                if (r['idade_na_data'] != null) Text('Idade na data: ${r['idade_na_data']} anos.'),
                if (_aviso != null) ...[const SizedBox(height: 8), Text(_aviso!, style: TextStyle(color: c.suave, fontSize: 12.5))],
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Destaque extends StatelessWidget {
  const _Destaque({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final p = ((r['progresso'] as num?) ?? 0).toInt();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: c.heroi, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border(bottom: BorderSide(color: c.dourado, width: 4)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['ja_pode'] == true ? 'Requisitos cumpridos desde' : 'Sua reserva', style: const TextStyle(color: Colors.white70)),
            Text(dataCurta(r['data']), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            if (r['data_tabela'] != null)
              Text('Pela Tabela de Pedágio da PMRN: ${dataCurta(r['data_tabela'])}', style: TextStyle(color: c.dourado, fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text(r['ja_pode'] == true ? 'Você já pode pedir a reserva remunerada integral.' : 'Faltam ${r['faltam']}',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          height: 78,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(value: p / 100, strokeWidth: 8, color: c.dourado, backgroundColor: Colors.white24)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$p%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              const Text('cumprido', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo(this.p);
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final estado = p['estado'];
    final reserva = p['reserva'] == true;
    final cor = reserva ? c.dourado : (estado == 'hoje' ? const Color(0xFF1F5FB4) : (estado == 'feito' ? const Color(0xFF1D8A45) : c.suave));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(estado == 'feito' ? Icons.check_circle : (reserva ? Icons.flag : (estado == 'hoje' ? Icons.radio_button_checked : Icons.radio_button_unchecked)), color: cor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dataCurta(p['data']), style: TextStyle(color: c.suave, fontSize: 12, fontWeight: FontWeight.w700)),
            Text('${p['titulo']}${reserva ? ' · RESERVA' : ''}', style: TextStyle(fontWeight: FontWeight.w800, color: reserva ? cor : null)),
            Text(p['detalhe']?.toString() ?? '', style: TextStyle(color: c.suave, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}
