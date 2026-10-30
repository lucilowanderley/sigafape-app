import 'package:flutter/material.dart';

import '../tema.dart';
import '../util/formato.dart';
import '../widgets/comum.dart';
import 'cautela.dart';

/// Material: o que está comigo agora e o meu histórico de cautelas e reservas.
class TelaMaterial extends StatelessWidget {
  const TelaMaterial({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const Topo(
          titulo: Text('Material'),
          mostrarVoltar: false,
          abas: TabBar(tabs: [Tab(text: 'Comigo agora'), Tab(text: 'Histórico')]),
        ),
        body: const TabBarView(children: [_Comigo(), _Historico()]),
      ),
    );
  }
}

class _Comigo extends StatefulWidget {
  const _Comigo();

  @override
  State<_Comigo> createState() => _ComigoState();
}

class _ComigoState extends State<_Comigo> with AutomaticKeepAliveClientMixin {
  final _chave = GlobalKey<CarregarState<List>>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Carregar<List>(
      key: _chave,
      buscar: () async => (await apiDe(context).get('cautelas'))['data'] as List,
      construir: (context, lista) => ListView(padding: const EdgeInsets.only(top: 12, bottom: 16), children: [
        if (lista.isEmpty) const Vazio('Nenhum material cautelado com você agora.', icone: Icons.inventory_2_outlined),
        for (final c in lista)
          LinhaCautela(
            c: c as Map<String, dynamic>,
            aoTocar: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => TelaCautela(id: c['id'] as int)));
              _chave.currentState?.recarregar();
            },
          ),
      ]),
    );
  }
}

class _Historico extends StatefulWidget {
  const _Historico();

  @override
  State<_Historico> createState() => _HistoricoState();
}

class _HistoricoState extends State<_Historico> with AutomaticKeepAliveClientMixin {
  static const _situacoes = {
    '': 'Todas',
    'aberta': 'Abertas',
    'atrasada': 'Em atraso',
    'reservada': 'Reservadas',
    'encerrada': 'Encerradas',
    'cancelada': 'Canceladas',
    'expirada': 'Expiradas',
  };

  final _itens = <Map<String, dynamic>>[];
  String _status = '';
  int _pagina = 0, _paginas = 1;
  bool _carregando = false;
  Object? _erro;
  final _rolagem = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(() {
      if (_rolagem.position.pixels > _rolagem.position.maxScrollExtent - 300) _mais();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomecar());
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _recomecar() async {
    setState(() {
      _itens.clear();
      _pagina = 0;
      _paginas = 1;
      _erro = null;
    });
    await _mais();
  }

  Future<void> _mais() async {
    if (_carregando || _pagina >= _paginas) return;
    setState(() => _carregando = true);
    try {
      final r = await apiDe(context).get('historico', {'status': _status, 'page': _pagina + 1, 'por_pagina': 25});
      final pag = r['paginacao'] as Map<String, dynamic>;
      setState(() {
        _itens.addAll((r['data'] as List).cast<Map<String, dynamic>>());
        _pagina = (pag['pagina'] as num).toInt();
        _paginas = (pag['paginas'] as num).toInt();
      });
    } catch (e) {
      setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Cores.de(context);
    return RefreshIndicator(
      onRefresh: _recomecar,
      child: ListView(controller: _rolagem, padding: const EdgeInsets.only(bottom: 16), children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              for (final e in _situacoes.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: (_) {
                      _status = e.key;
                      _recomecar();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_erro != null && _itens.isEmpty) Falha(_erro!, tentar: _recomecar),
        if (_erro == null && !_carregando && _itens.isEmpty) const Vazio('Nada encontrado no seu histórico.', icone: Icons.history),
        for (final item in _itens)
          LinhaCautela(
            c: item,
            mostrarReserva: item['status'] == 'reservada',
            aoTocar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaCautela(id: item['id'] as int))),
          ),
        if (_carregando) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (!_carregando && _itens.isNotEmpty && _pagina >= _paginas)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Fim do histórico · ${_itens.length} registro(s) · atualizado ${hora(DateTime.now().toIso8601String())}', style: TextStyle(color: c.suave, fontSize: 12.5))),
          ),
      ]),
    );
  }
}
