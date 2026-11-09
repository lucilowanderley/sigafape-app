import 'package:flutter/material.dart';

import '../sessao.dart';
import '../tema.dart';
import '../widgets/comum.dart';

/// Ponto colorido da situação do endereço: verde respondeu, vermelho falhou, cinza não testado.
class _Ponto extends StatelessWidget {
  const _Ponto(this.sessao, this.endereco);
  final Sessao sessao;
  final String endereco;

  @override
  Widget build(BuildContext context) {
    final testado = sessao.situacao.containsKey(endereco);
    final cor = !testado ? const Color(0xFF9AA3B2) : (sessao.respondeu.contains(endereco) ? const Color(0xFF1D8A45) : const Color(0xFFC0392B));
    return Container(width: 11, height: 11, decoration: BoxDecoration(color: cor, shape: BoxShape.circle));
  }
}

/// Linha de um endereço salvo.
class _LinhaServidor extends StatelessWidget {
  const _LinhaServidor({super.key, required this.s, required this.sessao, this.aoTocar, this.fim});
  final Servidor s;
  final Sessao sessao;
  final VoidCallback? aoTocar;
  final Widget? fim;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final emUso = sessao.servidor == s.endereco && !sessao.semConexao;
    final sit = sessao.situacao[s.endereco];
    final falhou = sit != null && !sessao.respondeu.contains(s.endereco);
    return Cartao(
      aoTocar: aoTocar,
      bordaEsquerda: emUso ? c.destaque : null,
      child: Row(children: [
        _Ponto(sessao, s.endereco),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            Text([s.endereco, if (emUso) 'em uso'].join(' · '), style: TextStyle(color: c.suave, fontSize: 12.5)),
            if (sit != null)
              Text(sit, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: falhou ? const Color(0xFFC0392B) : const Color(0xFF1D8A45))),
          ]),
        ),
        ?fim,
      ]),
    );
  }
}

/// Eu → Servidores: endereços do sistema guardados no celular. O app tenta na ordem e usa o primeiro que responder.
class TelaServidores extends StatelessWidget {
  const TelaServidores({super.key});

  @override
  Widget build(BuildContext context) {
    final sessao = Escopo.de(context);
    final c = Cores.de(context);
    return Scaffold(
      appBar: Topo(
        titulo: const Text('Servidores'),
        acoes: [
          if (sessao.servidores.isNotEmpty)
            TextButton(
              onPressed: sessao.procurando ? null : () async {
                for (final s in sessao.servidores) {
                  await sessao.testar(s.endereco);
                }
              },
              child: const Text('Testar todos', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editarServidor(context),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar endereço'),
      ),
      body: ListView(padding: const EdgeInsets.only(top: 12, bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text('O app tenta os endereços nesta ordem e usa o primeiro que responder. Só pede ajuda se nenhum funcionar. '
              'Para mudar a ordem, arraste pelas barrinhas à direita.', style: TextStyle(color: c.suave, fontSize: 13)),
        ),
        if (sessao.servidores.isEmpty) const Vazio('Nenhum endereço cadastrado.', icone: Icons.dns_outlined),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: sessao.reordenarServidores,
          children: [
            for (final (i, s) in sessao.servidores.indexed)
              _LinhaServidor(
                key: ValueKey(s.endereco),
                s: s,
                sessao: sessao,
                aoTocar: () => editarServidor(context, s),
                fim: ReorderableDragStartListener(index: i, child: Icon(Icons.drag_handle, color: c.suave)),
              ),
          ],
        ),
        if (sessao.servidores.any((s) => s.endereco.startsWith('http://')))
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Endereços com http:// mandam a senha sem criptografia. Use só para testes na rede interna, nunca pela internet.',
                style: TextStyle(color: Color(0xFF9A4A07), fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

/// Janela para adicionar ou editar um endereço: testa antes de salvar.
Future<void> editarServidor(BuildContext context, [Servidor? s]) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Cores.de(context).cartao,
    builder: (_) => _EditorServidor(antigo: s),
  );
}

class _EditorServidor extends StatefulWidget {
  const _EditorServidor({this.antigo});
  final Servidor? antigo;

  @override
  State<_EditorServidor> createState() => _EditorServidorState();
}

class _EditorServidorState extends State<_EditorServidor> {
  late final _nome = TextEditingController(text: widget.antigo?.nome ?? '');
  late final _endereco = TextEditingController(text: widget.antigo?.endereco ?? '');
  bool _enviando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await Escopo.ler(context).salvarServidor(_nome.text, _endereco.text, antigo: widget.antigo);
    if (!mounted) return;
    if (erro == null) {
      Navigator.pop(context);
      aviso(context, 'Servidor encontrado e salvo.');
    } else {
      setState(() {
        _enviando = false;
        _erro = erro;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = Escopo.de(context);
    final antigo = widget.antigo;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(antigo == null ? 'Adicionar endereço' : 'Editar endereço', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(
          controller: _endereco,
          enabled: !_enviando,
          autofocus: antigo == null,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'IP ou nome do servidor',
            hintText: '192.168.10.20 ou https://sigafape.8bpm.internal',
            helperText: 'Sem http:// o app usa https://',
            errorText: _erro,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nome,
          enabled: !_enviando,
          decoration: const InputDecoration(labelText: 'Apelido (opcional)', hintText: 'Wi-Fi da unidade, Tailscale...'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _enviando ? null : _salvar,
          child: _enviando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('TESTAR E SALVAR'),
        ),
        if (antigo != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _enviando
                    ? null
                    : () async {
                        await sessao.usarServidor(antigo);
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Usar este'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _enviando
                    ? null
                    : () async {
                        await sessao.removerServidor(antigo);
                        if (context.mounted) Navigator.pop(context);
                      },
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB3261E)),
                child: const Text('Excluir'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// Aparece sozinha quando nenhum endereço respondeu (ou nenhum foi cadastrado ainda).
class TelaSemConexao extends StatefulWidget {
  const TelaSemConexao({super.key});

  @override
  State<TelaSemConexao> createState() => _TelaSemConexaoState();
}

class _TelaSemConexaoState extends State<TelaSemConexao> {
  final _endereco = TextEditingController();
  bool _enviando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await Escopo.ler(context).salvarServidor('', _endereco.text);
    if (mounted) {
      setState(() {
        _enviando = false;
        _erro = erro;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = Escopo.de(context);
    final c = Cores.de(context);
    final primeiraVez = sessao.servidores.isEmpty;
    return Scaffold(
      appBar: Topo(titulo: Text(primeiraVez ? 'Configurar servidor' : 'Sem conexão'), mostrarVoltar: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 16, 0, 24), children: [
        Icon(primeiraVez ? Icons.dns_outlined : Icons.cloud_off_outlined, size: 56, color: primeiraVez ? c.destaque : const Color(0xFFC0392B)),
        const SizedBox(height: 8),
        Text(primeiraVez ? 'Informe o endereço do sistema' : 'Nenhum servidor respondeu',
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Text(
            primeiraVez ? 'Peça o IP ou o nome do servidor ao administrador do SIGAFAPE.' : 'Confira o Wi-Fi ou o Tailscale e tente de novo, ou informe outro endereço.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.suave, fontSize: 13.5),
          ),
        ),
        for (final s in sessao.servidores) _LinhaServidor(s: s, sessao: sessao),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _endereco,
              enabled: !_enviando,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: primeiraVez ? 'IP ou nome do servidor' : 'Novo endereço (IP ou nome)',
                hintText: '192.168.10.20 ou https://sigafape.8bpm.internal',
                errorText: _erro,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _salvar(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _enviando || sessao.procurando ? null : _salvar,
              child: _enviando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('TESTAR E SALVAR'),
            ),
            if (!primeiraVez) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: sessao.procurando || _enviando ? null : sessao.tentarDeNovo,
                icon: sessao.procurando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                label: Text(sessao.procurando ? 'Procurando...' : 'Tentar de novo'),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaServidores())),
                child: const Text('Gerenciar endereços'),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
