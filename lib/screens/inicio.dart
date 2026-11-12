import 'dart:async';

import 'package:flutter/material.dart';

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
    Nativo.ligarAvisos();
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
