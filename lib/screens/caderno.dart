import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../widgets/comum.dart';

/// Caderno de anotações (o mesmo do Painel 190): anotações rápidas, só do policial, guardadas no servidor.
class TelaCaderno extends StatefulWidget {
  const TelaCaderno({super.key});

  @override
  State<TelaCaderno> createState() => _TelaCadernoState();
}

class _TelaCadernoState extends State<TelaCaderno> {
  final _texto = TextEditingController();
  List<Map<String, dynamic>>? _notas;
  ApiErro? _erro;
  bool _enviando = false;

  static const _linha = 40.0;
  static const _margem = 58.0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _lista(Map<String, dynamic> r) => ((r['data'] as List?) ?? const []).cast<Map<String, dynamic>>();

  Future<void> _carregar() async {
    try {
      final r = await apiDe(context).get('caderno');
      if (mounted) setState(() => _notas = _lista(r));
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e);
    }
  }

  Future<void> _anotar() async {
    final t = _texto.text.trim();
    if (t.isEmpty) return;
    setState(() => _enviando = true);
    try {
      final r = await apiDe(context).post('caderno', {'texto': t});
      _texto.clear();
      if (mounted) setState(() => _notas = _lista(r));
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _apagar(Map<String, dynamic> n) async {
    try {
      final r = await apiDe(context).delete('caderno/${n['id']}');
      if (mounted) setState(() => _notas = _lista(r));
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    }
  }

  String _quando(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final hoje = DateTime.now();
    return d.year == hoje.year && d.month == hoje.month && d.day == hoje.day ? hora(v) : '${dataCurta(v).substring(0, 5)} ${hora(v)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final papel = c.escuro ? const Color(0xFF26231B) : const Color(0xFFFFFDF3);
    final pauta = c.escuro ? const Color(0xFF3A3A30) : const Color(0xFFCFE0EE);
    final notas = _notas;
    return Scaffold(
      appBar: const Topo(titulo: Text('Caderno')),
      backgroundColor: papel,
      body: Column(children: [
        Expanded(
          child: _erro != null
              ? Falha(_erro!, tentar: () {
                  setState(() => _erro = null);
                  _carregar();
                })
              : notas == null
                  ? const Center(child: CircularProgressIndicator())
                  : CustomPaint(
                      painter: _Pauta(linha: _linha, margem: _margem, pauta: pauta),
                      child: notas.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(_margem + 8, 10, 16, 0),
                              child: Text('Nada anotado ainda. Escreva abaixo: placas, horários, nomes, pontos de referência…', style: TextStyle(color: c.suave, height: 1.7)),
                            )
                          : ListView.builder(
                              itemCount: notas.length,
                              itemExtent: _linha,
                              itemBuilder: (_, i) {
                                final n = notas[i];
                                return Dismissible(
                                  key: ValueKey(n['id']),
                                  direction: DismissDirection.endToStart,
                                  background: Container(color: const Color(0xFFC0392B), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete_outline, color: Colors.white)),
                                  onDismissed: (_) => _apagar(n),
                                  child: Row(children: [
                                    SizedBox(
                                      width: _margem,
                                      child: Text(_quando(n['criada_em']), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC0392B), fontSize: 11.5, fontFamily: 'Roboto', fontWeight: FontWeight.w600)),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 8, right: 12),
                                        child: Text(n['texto']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: c.texto)),
                                      ),
                                    ),
                                  ]),
                                );
                              },
                            ),
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _texto,
                enabled: !_enviando,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _anotar(),
                decoration: InputDecoration(
                  hintText: 'Anotar e enviar…',
                  counterText: '',
                  suffixIcon: IconButton(tooltip: 'Anotar', icon: const Icon(Icons.send), onPressed: _enviando ? null : _anotar),
                ),
              ),
              const SizedBox(height: 4),
              Text('Só você vê estas anotações. Arraste uma linha para a esquerda para apagar.', style: TextStyle(color: c.suave, fontSize: 11.5)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Pauta extends CustomPainter {
  _Pauta({required this.linha, required this.margem, required this.pauta});
  final double linha, margem;
  final Color pauta;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = pauta..strokeWidth = 1;
    for (var y = linha; y < size.height; y += linha) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    canvas.drawLine(Offset(margem, 0), Offset(margem, size.height), Paint()..color = const Color(0xFFF2A3A3)..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_Pauta old) => old.pauta != pauta;
}
