import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../novidades.dart';
import '../util/nativo.dart';
import '../widgets/comum.dart';
import 'alertas.dart';
import 'eu.dart';
import 'material_comigo.dart';
import 'painel.dart';
import 'reservas.dart';

/// Abas do app: Início, Material, Reservas, Alertas e Eu.
class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key});

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> with WidgetsBindingObserver {
  int _aba = 0;
  Contagem _contagem = const Contagem();
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ligarServicos();
    _erroAnterior();
    _contar();
    _abrirPedido();
    // Com o app aberto confere a cada minuto; fechado, o Android confere a cada 15 minutos.
    _relogio = Timer.periodic(const Duration(minutes: 1), (_) => _contar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relogio?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _contar();
      _abrirPedido();
    }
  }

  /// Número no sino (topo do Início e aba Alertas): notificações pendentes + avisos do sino não lidos.
  /// Também mostra na barra do celular o que chegou de novo.
  Future<void> _contar() async {
    try {
      final c = await conferirNovidades(apiDe(context));
      if (mounted) setState(() => _contagem = c);
    } catch (_) {}
  }

  /// Se o app fechou sozinho da última vez, mostra o motivo para o usuário copiar e mandar ao suporte.
  Future<void> _erroAnterior() async {
    final erro = await Nativo.ultimoErro();
    if (erro == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O app fechou sozinho da última vez'),
        content: SingleChildScrollView(child: SelectableText(erro, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'))),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: erro));
              Navigator.pop(ctx);
              aviso(context, 'Texto copiado. Envie ao suporte do SIGAFAPE.');
            },
            child: const Text('COPIAR'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Avisos do Android e, se o sistema usa, o envio da posição em segundo plano (um pedido de permissão por vez).
  Future<void> _ligarServicos() async {
    final api = apiDe(context);
    await Nativo.ligarAvisos();
    try {
      final r = await api.get('posicao');
      if (r['ativo'] == true) {
        await Nativo.ligarLocalizacao();
      } else {
        await Nativo.desligarLocalizacao();
      }
    } catch (_) {
      // Servidor ainda sem /posicao, ou sem rede: tenta na próxima abertura.
    }
  }

  /// Tocou num aviso da barra do Android: abre a aba Alertas.
  Future<void> _abrirPedido() async {
    if (await Nativo.abrirPedido() == 'alertas' && mounted) _irPara(3);
  }

  void _irPara(int aba) => setState(() => _aba = aba);

  @override
  Widget build(BuildContext context) {
    final pendentes = _contagem.sino;
    final telas = [
      TelaPainel(irPara: _irPara, aoAtualizar: _contar, sino: _contagem.sino),
      const TelaMaterial(),
      const TelaReservas(),
      TelaAlertas(aoMudar: _contar),
      const TelaEu(),
    ];
    return Scaffold(
      body: IndexedStack(index: _aba, children: telas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) {
          _irPara(i);
          _contar();
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          const NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Material'),
          const NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Reservas'),
          NavigationDestination(
            icon: Badge(isLabelVisible: pendentes > 0, label: Text('$pendentes'), child: const Icon(Icons.notifications_outlined)),
            selectedIcon: Badge(isLabelVisible: pendentes > 0, label: Text('$pendentes'), child: const Icon(Icons.notifications)),
            label: 'Alertas',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Eu'),
        ],
      ),
    );
  }
}
