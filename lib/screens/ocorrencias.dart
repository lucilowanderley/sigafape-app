import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../util/nativo.dart';
import '../widgets/comum.dart';

/// Naturezas mais comuns (o servidor manda a lista do COPOM em GET /ocorrencias).
const _naturezasPadrao = ['Furto', 'Roubo', 'Ameaça', 'Perturbação do sossego', 'Violência doméstica', 'Lesão corporal'];

String _situacaoCor(String? s) => switch (s) { 'aceita' => 'green', 'recusada' => 'red', 'cancelada' => 'gray', _ => 'gold' };

/// Minhas ocorrências e pedidos de apoio, com a resposta do COPOM.
class TelaMinhasOcorrencias extends StatefulWidget {
  const TelaMinhasOcorrencias({super.key});

  @override
  State<TelaMinhasOcorrencias> createState() => _TelaMinhasOcorrenciasState();
}

class _TelaMinhasOcorrenciasState extends State<TelaMinhasOcorrencias> {
  final _chave = GlobalKey<CarregarState<Map<String, dynamic>>>();

  Future<void> _nova(List<String> naturezas) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TelaNovaOcorrencia(naturezas: naturezas)));
    if (ok == true) _chave.currentState?.recarregar();
  }

  Future<void> _cancelar(Map<String, dynamic> o) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar o pedido?'),
        content: Text('${o['titulo']} · ${o['local']}\nO COPOM deixa de ver este pedido.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar pedido'))],
      ),
    );
    if (sim != true || !mounted) return;
    try {
      await apiDe(context).post('ocorrencias/${o['id']}/cancelar');
      if (mounted) aviso(context, 'Pedido cancelado.');
      _chave.currentState?.recarregar();
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Carregar<Map<String, dynamic>>(
      key: _chave,
      buscar: () => apiDe(context).get('ocorrencias'),
      construir: (context, r) {
        final lista = ((r['data'] as List?) ?? const []).cast<Map<String, dynamic>>();
        final nat = ((r['naturezas'] as List?) ?? const []).map((e) => e.toString()).toList();
        return Scaffold(
          appBar: const Topo(titulo: Text('Minhas ocorrências')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _nova(nat.isEmpty ? _naturezasPadrao : nat),
            backgroundColor: const Color(0xFFC0392B),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Abrir ocorrência'),
          ),
          body: RefreshIndicator(
            onRefresh: () async => _chave.currentState?.recarregar(),
            child: ListView(padding: const EdgeInsets.only(top: 12, bottom: 90), children: [
              if (lista.isEmpty) const Vazio('Nenhuma ocorrência ou pedido de apoio nos últimos 30 dias.', icone: Icons.local_police_outlined),
              for (final o in lista)
                Cartao(
                  bordaEsquerda: corSituacao(_situacaoCor(o['situacao']?.toString()), c.escuro).$2,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (o['tipo'] == 'apoio') const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.campaign, color: Color(0xFFC0392B), size: 20)),
                      Expanded(child: Text('${o['titulo']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                      Pilula(o['situacao_texto']?.toString() ?? '', cor: _situacaoCor(o['situacao']?.toString())),
                    ]),
                    const SizedBox(height: 3),
                    Text('${o['local']}', style: TextStyle(color: c.texto)),
                    Text('Enviada ${quandoCurto(o['criada_em'])}', style: TextStyle(color: c.suave, fontSize: 12.5)),
                    if (o['situacao'] == 'aceita')
                      Text(['Ocorrência nº ${o['ocorrencia'] ?? '—'}', if (o['equipe'] != null) 'equipe ${o['equipe']}', if (o['respondida_por'] != null) 'por ${o['respondida_por']}'].join(' · '),
                          style: const TextStyle(color: Color(0xFF1D8A45), fontWeight: FontWeight.w700, fontSize: 13)),
                    if (o['situacao'] == 'recusada')
                      Text('Motivo: ${o['resposta'] ?? 'não informado'}', style: const TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.w700, fontSize: 13)),
                    if (o['situacao'] == 'aceita' && o['resposta'] != null) Text('${o['resposta']}', style: TextStyle(color: c.suave, fontSize: 12.5)),
                    if (o['situacao'] == 'pendente')
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _cancelar(o), child: const Text('Cancelar pedido'))),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }
}

/// Abrir ocorrência: vai para o Painel 190, onde o COPOM aceita ou recusa.
class TelaNovaOcorrencia extends StatefulWidget {
  const TelaNovaOcorrencia({super.key, this.naturezas = _naturezasPadrao});
  final List<String> naturezas;

  @override
  State<TelaNovaOcorrencia> createState() => _TelaNovaOcorrenciaState();
}

class _TelaNovaOcorrenciaState extends State<TelaNovaOcorrencia> {
  final _natureza = TextEditingController();
  final _endereco = TextEditingController();
  final _bairro = TextEditingController();
  final _referencia = TextEditingController();
  final _relato = TextEditingController();
  Local? _local;
  bool _buscandoLocal = false, _enviando = false;
  String? _erroLocal;
  Map<String, List<String>> _erros = {};
  final List<Uint8List> _fotos = [];
  static const _maxFotos = 6;

  Future<void> _adicionarFoto() async {
    FocusScope.of(context).unfocus();
    final origem = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const Key('foto-camera'), leading: const Icon(Icons.photo_camera), title: const Text('Câmera'), subtitle: const Text('Tirar foto agora'), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(key: const Key('foto-galeria'), leading: const Icon(Icons.photo_library), title: const Text('Galeria'), subtitle: Text('Escolher até ${_maxFotos - _fotos.length}'), onTap: () => Navigator.pop(ctx, 'galeria')),
        ]),
      ),
    );
    if (origem == null) return;
    try {
      final novas = origem == 'camera' ? await Nativo.tirarFoto() : await Nativo.escolherFotos(_maxFotos - _fotos.length);
      if (!mounted || novas.isEmpty) return;
      final cabem = _maxFotos - _fotos.length;
      setState(() => _fotos.addAll(novas.take(cabem)));
      if (novas.length > cabem) aviso(context, 'Só cabem $_maxFotos fotos. As demais foram deixadas de fora.');
    } on ErroLocal catch (e) {
      if (mounted) aviso(context, e.mensagem, erro: true);
    }
  }

  Widget _gradeFotos(Cores c) {
    Widget casa(Widget filho) => ClipRRect(borderRadius: BorderRadius.circular(10), child: filho);
    final casas = <Widget>[
      for (var i = 0; i < _fotos.length; i++)
        Stack(key: Key('foto-$i'), fit: StackFit.expand, children: [
          casa(Image.memory(_fotos[i], fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => Container(color: c.linha, child: Icon(Icons.broken_image, color: c.suave)))),
          Positioned(
            right: 4,
            top: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                key: Key('remover-foto-$i'),
                customBorder: const CircleBorder(),
                onTap: _enviando ? null : () => setState(() => _fotos.removeAt(i)),
                child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close, color: Colors.white, size: 18, semanticLabel: 'Remover foto')),
              ),
            ),
          ),
        ]),
      for (var i = _fotos.length; i < _maxFotos; i++)
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: c.linha, width: 2)),
          child: InkWell(
            key: i == _fotos.length ? const Key('adicionar-foto') : null,
            borderRadius: BorderRadius.circular(10),
            onTap: _enviando ? null : _adicionarFoto,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_a_photo_outlined, color: c.suave),
              const SizedBox(height: 2),
              Text('Adicionar', style: TextStyle(color: c.suave, fontSize: 12)),
            ]),
          ),
        ),
    ];
    return GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, children: casas);
  }

  @override
  void dispose() {
    for (final c in [_natureza, _endereco, _bairro, _referencia, _relato]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _gps() async {
    setState(() {
      _buscandoLocal = true;
      _erroLocal = null;
    });
    try {
      final l = await Nativo.localizacao();
      if (mounted) setState(() => _local = l);
    } on ErroLocal catch (e) {
      if (mounted) setState(() => _erroLocal = e.mensagem);
    } finally {
      if (mounted) setState(() => _buscandoLocal = false);
    }
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _erros = {};
    });
    try {
      final r = await apiDe(context).post('ocorrencias', {
        'natureza': _natureza.text.trim(),
        'endereco': _endereco.text.trim(),
        'bairro': _bairro.text.trim(),
        'referencia': _referencia.text.trim(),
        'relato': _relato.text.trim(),
        if (_local != null) ...{'latitude': _local!.latitude, 'longitude': _local!.longitude, 'precisao': _local!.precisao},
        if (_fotos.isNotEmpty) 'fotos': [for (final f in _fotos) base64Encode(f)],
      }, Duration(seconds: 25 + 20 * _fotos.length));
      if (!mounted) return;
      aviso(context, r['message']?.toString() ?? 'Ocorrência enviada ao COPOM.');
      Navigator.pop(context, true);
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _erros = e.erros);
      if (e.erros.isEmpty) aviso(context, e.detalhe, erro: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _erro(String campo) => _erros[campo]?.first;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final escolhida = _natureza.text.trim();
    Widget rotulo(String t) => Padding(padding: const EdgeInsets.fromLTRB(2, 14, 0, 6), child: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: c.suave)));
    return Scaffold(
      appBar: const Topo(titulo: Text('Nova ocorrência')),
      body: ListView(key: const Key('form-ocorrencia'), padding: const EdgeInsets.fromLTRB(14, 4, 14, 24), children: [
        rotulo('NATUREZA *'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final n in widget.naturezas.take(8))
            ChoiceChip(
              label: Text(n),
              selected: escolhida == n,
              onSelected: _enviando ? null : (_) => setState(() => _natureza.text = n),
            ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _natureza,
          enabled: !_enviando,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: 'Ou digite a natureza', errorText: _erro('natureza')),
        ),
        rotulo('ONDE *'),
        TextField(
          controller: _endereco,
          enabled: !_enviando,
          decoration: InputDecoration(hintText: 'Rua, número', errorText: _erro('endereco'), errorMaxLines: 2),
        ),
        const SizedBox(height: 8),
        Material(
          color: c.destaque.withValues(alpha: c.escuro ? .22 : .10),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _buscandoLocal || _enviando ? null : _gps,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _buscandoLocal
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : Icon(_local == null ? Icons.my_location : Icons.location_on, color: c.destaque),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _buscandoLocal
                        ? 'Obtendo a sua localização…'
                        : _local == null
                            ? 'Usar minha localização (GPS)'
                            : 'Localização marcada${_local!.precisao != null ? ' · precisão ${_local!.precisao!.round()} m' : ''} · tocar para atualizar',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.destaque),
                  ),
                ),
              ]),
            ),
          ),
        ),
        if (_erroLocal != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_erroLocal!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12.5))),
        const SizedBox(height: 8),
        TextField(controller: _bairro, enabled: !_enviando, decoration: const InputDecoration(hintText: 'Bairro')),
        rotulo('PONTO DE REFERÊNCIA'),
        TextField(controller: _referencia, enabled: !_enviando, decoration: const InputDecoration(hintText: 'Ex.: em frente à farmácia')),
        rotulo('RELATO'),
        TextField(
          controller: _relato,
          enabled: !_enviando,
          minLines: 3,
          maxLines: 6,
          maxLength: 3000,
          decoration: const InputDecoration(hintText: 'O que está acontecendo, quantas pessoas, veículos, rumo de fuga…'),
        ),
        rotulo('FOTOS (${_fotos.length} DE $_maxFotos)'),
        _gradeFotos(c),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _erro('fotos') ?? _erros.entries.where((e) => e.key.startsWith('fotos.')).map((e) => e.value.first).firstOrNull ?? 'Toque em Adicionar para usar a câmera ou a galeria (pode escolher várias).',
            style: TextStyle(color: _erros.keys.any((k) => k.startsWith('fotos')) ? const Color(0xFFB3261E) : c.suave, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
          onPressed: _enviando ? null : _enviar,
          child: _enviando
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(_fotos.isEmpty ? 'ENVIAR AO COPOM' : 'ENVIAR AO COPOM (${_fotos.length} FOTO${_fotos.length > 1 ? 'S' : ''})'),
        ),
        const SizedBox(height: 8),
        Text('A ocorrência chega no Painel 190. Quando o COPOM aceitar ou recusar, você recebe um aviso no sino.', style: TextStyle(color: c.suave, fontSize: 12.5)),
      ]),
    );
  }
}

/// Ícone de apoio do cartão azul: confirma, pega o GPS e envia o pedido urgente ao Painel 190.
Future<void> pedirApoio(BuildContext context) async {
  final sim = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.campaign, color: Color(0xFFC0392B), size: 40),
      title: const Text('Pedir apoio urgente?'),
      content: const Text('O COPOM recebe agora um pedido URGENTE de apoio operacional com a sua localização marcada no mapa do Painel 190.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B), foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('CONFIRMAR'),
        ),
      ],
    ),
  );
  if (sim != true || !context.mounted) return;
  final api = apiDe(context);
  final fechar = _espera(context, 'Obtendo a sua localização…');
  try {
    final l = await Nativo.localizacao();
    final r = await api.post('apoio', {'latitude': l.latitude, 'longitude': l.longitude, 'precisao': l.precisao});
    fechar();
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF1D8A45), size: 40),
          title: const Text('Pedido enviado'),
          content: Text('${r['message'] ?? 'Pedido de apoio enviado ao COPOM.'}\nAcompanhe em Minhas ocorrências.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  } on ErroLocal catch (e) {
    fechar();
    if (context.mounted) aviso(context, e.mensagem, erro: true);
  } on ApiErro catch (e) {
    fechar();
    if (context.mounted) aviso(context, e.detalhe, erro: true);
  }
}

VoidCallback _espera(BuildContext context, String texto) {
  final nav = Navigator.of(context);
  var aberto = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 16), Expanded(child: Text(texto))])),
    ),
  ).then((_) => aberto = false);
  return () {
    if (aberto) nav.pop();
    aberto = false;
  };
}
