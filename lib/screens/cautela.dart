import 'package:flutter/material.dart';

import '../tema.dart';
import '../util/formato.dart';
import '../widgets/assinatura.dart';
import '../widgets/comum.dart';

/// Linha de uma cautela nas listas (material comigo, histórico, reservas).
class LinhaCautela extends StatelessWidget {
  const LinhaCautela({super.key, required this.c, this.aoTocar, this.mostrarReserva = false});
  final Map<String, dynamic> c;
  final VoidCallback? aoTocar;
  final bool mostrarReserva;

  @override
  Widget build(BuildContext context) {
    final cores = Cores.de(context);
    final detalhe = <String>[
      if (c['numero_serie'] != null) c['numero_serie'].toString(),
      if (mostrarReserva && c['retirada_prevista'] != null) 'retirada ${quandoCurto(c['retirada_prevista'])}',
      if (!mostrarReserva && c['permanente'] == true) 'permanente',
      if (!mostrarReserva && c['permanente'] != true && c['devolvida_em'] == null && c['devolucao_prevista'] != null) 'devolver ${dataCurta(c['devolucao_prevista'])}',
      if (c['devolvida_em'] != null) 'devolvida ${dataCurta(c['devolvida_em'])}',
      if (c['urgente'] == true) 'urgência',
    ];
    final aguarda = c['aguarda_meu_recebimento'] == true;
    return Cartao(
      aoTocar: aoTocar,
      child: Row(children: [
        Icon(iconeMaterial(c['tipo']?.toString(), c['categoria']?.toString()), size: 26, color: cores.texto),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['material']?.toString() ?? 'Material', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 2),
            Text(detalhe.join(' · '), style: TextStyle(color: cores.suave, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        aguarda ? const Pilula('Assinar', cor: 'gold') : Pilula(c['situacao']?.toString() ?? '', cor: c['permanente'] == true && c['status'] == 'aberta' ? 'green' : c['cor']?.toString()),
      ]),
    );
  }
}

/// Detalhe de uma cautela minha, com as assinaturas e, se for o caso, o botão de assinar o recebimento.
class TelaCautela extends StatefulWidget {
  const TelaCautela({super.key, required this.id});
  final int id;

  @override
  State<TelaCautela> createState() => _TelaCautelaState();
}

class _TelaCautelaState extends State<TelaCautela> {
  final _chave = GlobalKey<CarregarState<Map<String, dynamic>>>();

  Future<void> _assinar(Map<String, dynamic> c) async {
    final api = apiDe(context);
    final r = await pedirAssinatura<Map<String, dynamic>>(
      context,
      titulo: 'Assinar recebimento',
      descricao: '${c['material']}${c['numero_serie'] != null ? ' · série ${c['numero_serie']}' : ''} · cautela de urgência nº ${c['id']}'
          '${c['lote'] != null ? '. Assina todos os materiais pendentes do lote.' : ''}',
      botao: 'Assinar',
      assinar: (m, s) => api.post('cautelas/${c['id']}/assinar-recebimento', {'matricula': m, 'senha': s}),
    );
    if (r == null || !mounted) return;
    final cod = (r['assinatura'] as Map?)?['codigo'];
    aviso(context, '${r['message'] ?? 'Recebimento assinado.'}${cod != null ? ' Código $cod' : ''}');
    _chave.currentState?.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Topo(titulo: Text('Cautela nº ${widget.id}')),
      body: Carregar<Map<String, dynamic>>(
        key: _chave,
        buscar: () async => (await apiDe(context).get('cautelas/${widget.id}'))['data'] as Map<String, dynamic>,
        construir: (context, c) {
          final cores = Cores.de(context);
          final assinaturas = (c['assinaturas'] as List?) ?? const [];
          final canc = c['cancelamento'] as Map?;
          return ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [
            Cartao(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(iconeMaterial(c['tipo']?.toString(), c['categoria']?.toString()), size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c['material']?.toString() ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
                  Pilula(c['situacao']?.toString() ?? '', cor: c['cor']?.toString()),
                ]),
                const Divider(height: 22),
                Info('Categoria', c['categoria']?.toString()),
                Info('Nº de série', c['numero_serie']?.toString()),
                Info('Patrimônio', c['patrimonio']?.toString()),
                if (c['retirada_prevista'] != null) Info('Retirada prevista', dataHora(c['retirada_prevista'])),
                if (c['prazo_confirmacao'] != null) Info('Confirmar até', dataHora(c['prazo_confirmacao'])),
                Info('Retirada', dataCurta(c['retirada'])),
                if (c['permanente'] == true)
                  Info('Cautela permanente', c['ato_permanente']?.toString() ?? 'Sim')
                else
                  Info('Devolver até', dataCurta(c['devolucao_prevista'])),
                if (c['devolvida_em'] != null) Info('Devolvida em', dataCurta(c['devolvida_em'])),
                if (c['municao'] != null) Info('Munição', c['municao'].toString()),
                if (c['carregadores'] != null) Info('Carregadores', c['carregadores'].toString()),
                if (c['urgente'] == true) Info('Urgência', c['motivo_urgencia']?.toString() ?? 'Sim'),
                if (canc != null) Info('Cancelamento', '${dataHora(canc['em'])}${canc['automatico'] == true ? ' (automático)' : ''}${canc['motivo'] != null ? ' · ${canc['motivo']}' : ''}'),
                if (c['observacoes'] != null) Info('Observações', c['observacoes'].toString()),
              ]),
            ),
            if (c['aguarda_meu_recebimento'] == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: FilledButton.icon(onPressed: () => _assinar(c), icon: const Icon(Icons.draw_outlined), label: const Text('ASSINAR RECEBIMENTO')),
              ),
            const TituloSecao('Assinaturas'),
            if (assinaturas.isEmpty) const Vazio('Nenhuma assinatura registrada.', icone: Icons.draw_outlined),
            for (final s in assinaturas)
              Cartao(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['descricao']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${s['assinada_por'] ?? ''} · ${dataHora(s['assinada_em'])}', style: TextStyle(color: cores.suave, fontSize: 13)),
                  SelectableText('Código ${s['codigo'] ?? '—'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
