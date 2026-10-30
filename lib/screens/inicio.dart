import 'dart:async';

import 'package:flutter/material.dart';

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
  int _pendentes = 0;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contar();
    _relogio = Timer.periodic(const Duration(minutes: 2), (_) => _contar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relogio?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _contar();
  }

  /// Número no ícone de Alertas: notificações pendentes + avisos do sino não lidos.
  Future<void> _contar() async {
    try {
      final api = apiDe(context);
      final r = await Future.wait([api.get('alertas', {'por_pagina': 1}), api.get('avisos')]);
      if (mounted) setState(() => _pendentes = ((r[0]['pendentes'] as num?) ?? 0).toInt() + ((r[1]['nao_lidos'] as num?) ?? 0).toInt());
    } catch (_) {}
  }

  void _irPara(int aba) => setState(() => _aba = aba);

  @override
  Widget build(BuildContext context) {
    final telas = [
      TelaPainel(irPara: _irPara, aoAtualizar: _contar),
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
            icon: Badge(isLabelVisible: _pendentes > 0, label: Text('$_pendentes'), child: const Icon(Icons.notifications_outlined)),
            selectedIcon: Badge(isLabelVisible: _pendentes > 0, label: Text('$_pendentes'), child: const Icon(Icons.notifications)),
            label: 'Alertas',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Eu'),
        ],
      ),
    );
  }
}
