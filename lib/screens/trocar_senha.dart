import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../widgets/comum.dart';

/// Troca da própria senha. Obrigatória no primeiro acesso, quando o administrador exigir.
class TelaTrocarSenha extends StatefulWidget {
  const TelaTrocarSenha({super.key, this.obrigatoria = false});
  final bool obrigatoria;

  @override
  State<TelaTrocarSenha> createState() => _TelaTrocarSenhaState();
}

class _TelaTrocarSenhaState extends State<TelaTrocarSenha> {
  final _atual = TextEditingController(), _nova = TextEditingController(), _confirma = TextEditingController();
  bool _enviando = false;
  ApiErro? _erro;

  Future<void> _salvar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final sessao = Escopo.ler(context);
    try {
      final msg = await sessao.trocarMinhaSenha(_atual.text, _nova.text, _confirma.text);
      if (!mounted) return;
      aviso(context, msg);
      if (!widget.obrigatoria) Navigator.pop(context);
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Scaffold(
      appBar: Topo(
        titulo: const Text('Trocar senha'),
        mostrarVoltar: !widget.obrigatoria,
        acoes: widget.obrigatoria ? [TextButton(onPressed: () => Escopo.ler(context).sair(), child: const Text('Sair', style: TextStyle(color: Colors.white)))] : null,
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.obrigatoria)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('Antes de continuar, troque a senha que você recebeu por uma só sua.', style: TextStyle(color: c.texto, fontSize: 15)),
          ),
        Text('A nova senha precisa ter 8 caracteres ou mais, com letras e números. Os outros aparelhos conectados com o seu login vão sair do app.',
            style: TextStyle(color: c.suave, fontSize: 13.5)),
        const SizedBox(height: 16),
        TextField(controller: _atual, obscureText: true, decoration: InputDecoration(labelText: 'Senha atual', errorText: _erro?.campo('senha_atual'))),
        const SizedBox(height: 12),
        TextField(controller: _nova, obscureText: true, decoration: InputDecoration(labelText: 'Nova senha', errorText: _erro?.campo('nova_senha'), errorMaxLines: 3)),
        const SizedBox(height: 12),
        TextField(controller: _confirma, obscureText: true, decoration: const InputDecoration(labelText: 'Repita a nova senha'), onSubmitted: (_) => _salvar()),
        if (_erro != null && _erro!.campo('senha_atual') == null && _erro!.campo('nova_senha') == null) ...[
          const SizedBox(height: 12),
          Text(_erro!.detalhe, style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _enviando ? null : _salvar, child: const Text('SALVAR NOVA SENHA')),
      ]),
    );
  }
}
