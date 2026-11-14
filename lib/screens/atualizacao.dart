import 'package:flutter/material.dart';

import '../sessao.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../util/nativo.dart';
import '../widgets/comum.dart';

/// Aviso de versão nova do app (opção A, 2026-11-13): faixa dourada no topo do Início até o policial
/// atualizar; tocar abre o que mudou e o botão de baixar o APK. Os dados vêm de GET /api/v1/app/versao.
class FaixaVersao extends StatelessWidget {
  const FaixaVersao({super.key, required this.dados});
  final Map<String, dynamic> dados;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: c.escuro ? const Color(0xFF3A3114) : const Color(0xFFFFF6DC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.dourado)),
        child: InkWell(
          key: const Key('faixa-versao'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaAtualizacao(dados: dados))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Icon(Icons.system_update, color: c.dourado),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Versão ${dados['versao']} disponível', style: TextStyle(fontWeight: FontWeight.w800, color: c.texto)),
                      Text('você está na $versaoApp', style: TextStyle(fontSize: 12.5, color: c.suave)),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaAtualizacao(dados: dados))),
                  child: const Text('Atualizar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TelaAtualizacao extends StatelessWidget {
  const TelaAtualizacao({super.key, required this.dados});
  final Map<String, dynamic> dados;

  static (Color, Color) _corTipo(String tipo, bool escuro) => switch (tipo) {
        'Novidade' => corSituacao('green', escuro),
        'Correção' => corSituacao('gold', escuro),
        _ => corSituacao('blue', escuro),
      };

  Future<void> _baixar(BuildContext context) async {
    final url = dados['apk_url']?.toString() ?? '';
    if (url.isEmpty || !await Nativo.abrirLink(url)) {
      if (context.mounted) aviso(context, 'Não foi possível abrir o link. Peça o app novo ao administrador.', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final mudancas = (dados['mudancas'] as List?) ?? const [];
    return Scaffold(
      appBar: Topo(titulo: const Text('Atualizar o app')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Cartao(
            margem: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text('Versão nova: ${dados['versao']} · você está na $versaoApp.\nDepois de baixar, abra o arquivo e toque em Instalar (atualiza por cima, sem perder nada).',
                style: TextStyle(color: c.texto)),
          ),
          for (final v in mudancas.cast<Map>())
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App ${v['versao']}${v['data'] != null ? ' · ${dataCurta(v['data'])}' : ''}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c.texto)),
                  const SizedBox(height: 6),
                  for (final i in ((v['itens'] as List?) ?? const []).cast<Map>())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(builder: (context) {
                            final (fundo, letra) = _corTipo(i['tipo']?.toString() ?? '', c.escuro);
                            return Container(
                              margin: const EdgeInsets.only(right: 8, top: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(4)),
                              child: Text(i['tipo']?.toString() ?? '', style: TextStyle(color: letra, fontSize: 11, fontWeight: FontWeight.w700)),
                            );
                          }),
                          Expanded(
                            child: Text.rich(TextSpan(children: [
                              if ((i['modulo']?.toString() ?? '').isNotEmpty) TextSpan(text: '${i['modulo']}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: i['titulo']?.toString() ?? ''),
                            ]), style: TextStyle(color: c.texto)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: FilledButton.icon(
              key: const Key('baixar-versao'),
              onPressed: () => _baixar(context),
              icon: const Icon(Icons.download),
              label: const Text('Baixar e instalar'),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Agora não')),
        ],
      ),
    );
  }
}
