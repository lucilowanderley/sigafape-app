import 'package:flutter/material.dart';

import '../tema.dart';
import '../util/formato.dart';
import '../widgets/comum.dart';

/// Inspeção do arsenal: meu material cautelado nas inspeções abertas e nas dos últimos 90 dias.
/// O material é apresentado na armaria; a inspeção e a assinatura são feitas lá.
class TelaInspecoes extends StatelessWidget {
  const TelaInspecoes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Topo(titulo: Text('Inspeção do arsenal')),
      body: Carregar<List>(
        buscar: () async => (await apiDe(context).get('inspecoes'))['data'] as List,
        construir: (context, lista) {
          final c = Cores.de(context);
          return ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text('Quando for convocado, apresente o material na armaria até o prazo. A inspeção e a sua assinatura são feitas lá.',
                  style: TextStyle(color: c.suave, fontSize: 13)),
            ),
            if (lista.isEmpty) const Vazio('Nenhuma inspeção com material seu nos últimos 90 dias.', icone: Icons.verified_user_outlined),
            for (final i in lista) _item(context, c, i as Map<String, dynamic>),
          ]);
        },
      ),
    );
  }

  Widget _item(BuildContext context, Cores c, Map<String, dynamic> i) {
    final insp = i['inspecao'] as Map<String, dynamic>? ?? {};
    final convocado = i['situacao'] == 'convocado';
    final (texto, cor) = switch (i['situacao']) {
      'inspecionado' => (i['resultado_texto']?.toString() ?? 'Inspecionado', i['resultado'] == 'apto' ? 'green' : (i['resultado'] == 'inapto' ? 'red' : 'gold')),
      'convocado' => (i['atrasado'] == true ? 'Atrasado' : 'Convocado', i['atrasado'] == true ? 'red' : 'gold'),
      _ => ('Aguardando convocação', 'gray'),
    };
    return Cartao(
      bordaEsquerda: convocado ? (i['atrasado'] == true ? const Color(0xFFE53935) : const Color(0xFFB8860B)) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(iconeMaterial(i['tipo']?.toString(), null), size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text('${i['material'] ?? 'Material'} · ${i['numero_serie'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
          Pilula(texto, cor: cor),
        ]),
        const SizedBox(height: 6),
        Text('${insp['titulo'] ?? 'Inspeção'} · ${insp['tipo'] ?? ''}${insp['encerrada'] == true ? ' · encerrada' : ''}', style: TextStyle(color: c.suave, fontSize: 13)),
        if (convocado) Text('Apresentar na armaria até ${dataHora(i['apresentar_ate'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (i['situacao'] == 'inspecionado') ...[
          Text('Inspecionado em ${dataHora(i['inspecionado_em'])}${i['inspecionado_por'] != null ? ' por ${i['inspecionado_por']}' : ''}', style: const TextStyle(fontSize: 13)),
          if (i['observacoes'] != null) Text('Obs.: ${i['observacoes']}', style: const TextStyle(fontSize: 13)),
          if (i['codigo'] != null) SelectableText('Código da inspeção ${i['codigo']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
          if (i['codigo_minha_assinatura'] != null) SelectableText('Minha assinatura ${i['codigo_minha_assinatura']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
        ],
      ]),
    );
  }
}
