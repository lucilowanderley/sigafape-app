import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/nativo.dart';
import 'comum.dart';

/// Janela de assinatura eletrônica: matrícula + senha, ou matrícula + digital/rosto quando ligados
/// neste aparelho (opção A, 2026-11-14). A senha nunca é guardada no aparelho.
/// [assinar] recebe as credenciais prontas para juntar ao corpo do pedido: {'matricula', 'senha'} ou
/// {'matricula', 'biometria': {chave, desafio, assinatura}}; erros 422 da assinatura aparecem no campo senha.
/// Devolve o resultado de [assinar], ou null se o policial cancelar.
Future<T?> pedirAssinatura<T>(
  BuildContext context, {
  required String titulo,
  required String descricao,
  required String botao,
  required Future<T> Function(Map<String, dynamic> credenciais) assinar,
}) {
  final matriculaPadrao = Escopo.ler(context).policial?['matricula']?.toString() ?? '';
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Cores.de(context).cartao,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _JanelaAssinatura<T>(titulo: titulo, descricao: descricao, botao: botao, assinar: assinar, matricula: matriculaPadrao),
  );
}

class _JanelaAssinatura<T> extends StatefulWidget {
  const _JanelaAssinatura({required this.titulo, required this.descricao, required this.botao, required this.assinar, required this.matricula});
  final String titulo, descricao, botao, matricula;
  final Future<T> Function(Map<String, dynamic> credenciais) assinar;

  @override
  State<_JanelaAssinatura<T>> createState() => _JanelaAssinaturaState<T>();
}

class _JanelaAssinaturaState<T> extends State<_JanelaAssinatura<T>> {
  late final _matricula = TextEditingController(text: widget.matricula);
  final _senha = TextEditingController();
  bool _enviando = false;
  bool _ver = false;
  String? _erroMatricula, _erroSenha, _erroGeral;

  @override
  void dispose() {
    _matricula.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _erroMatricula = _matricula.text.trim().isEmpty ? 'Informe sua matrícula.' : null;
      _erroSenha = _senha.text.isEmpty ? 'Informe sua senha.' : null;
      _erroGeral = null;
    });
    if (_erroMatricula != null || _erroSenha != null) return;
    setState(() => _enviando = true);
    await _assinar({'matricula': _matricula.text.trim(), 'senha': _senha.text});
  }

  Future<void> _enviarDigital() async {
    setState(() {
      _erroMatricula = _matricula.text.trim().isEmpty ? 'Informe sua matrícula.' : null;
      _erroSenha = _erroGeral = null;
    });
    if (_erroMatricula != null) return;
    setState(() => _enviando = true);
    final sessao = Escopo.ler(context);
    Map<String, dynamic>? prova;
    try {
      prova = await sessao.provaBiometrica(widget.titulo, subtitulo: 'Matrícula ${_matricula.text.trim()}');
    } on ApiErro catch (e) {
      setState(() { _enviando = false; _erroGeral = e.detalhe; });
      return;
    } on ErroLocal catch (e) {
      setState(() { _enviando = false; _erroGeral = e.mensagem; });
      return;
    }
    if (prova == null) {
      // "Usar senha": fica na janela, com o campo de senha
      setState(() => _enviando = false);
      return;
    }
    await _assinar({'matricula': _matricula.text.trim(), 'biometria': prova});
  }

  Future<void> _assinar(Map<String, dynamic> credenciais) async {
    try {
      final r = await widget.assinar(credenciais);
      if (mounted) Navigator.pop(context, r);
    } on ApiErro catch (e) {
      setState(() {
        _enviando = false;
        _erroMatricula = e.campo('matricula');
        _erroSenha = e.campo('senha');
        if (_erroMatricula == null && _erroSenha == null) _erroGeral = e.detalhe;
        _senha.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(widget.descricao, style: TextStyle(color: c.suave, fontSize: 14)),
        const SizedBox(height: 16),
        TextField(
          controller: _matricula,
          enabled: !_enviando,
          decoration: InputDecoration(labelText: 'Matrícula', errorText: _erroMatricula),
          textInputAction: TextInputAction.next,
        ),
        if (Escopo.de(context).biometriaLigada) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('assinar-digital'),
            onPressed: _enviando ? null : _enviarDigital,
            icon: const Icon(Icons.fingerprint, size: 22),
            label: Text('${widget.botao.toUpperCase()} COM DIGITAL'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Expanded(child: Divider()),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('ou com a senha', style: TextStyle(color: c.suave, fontSize: 13))),
            const Expanded(child: Divider()),
          ]),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _senha,
          enabled: !_enviando,
          obscureText: !_ver,
          autofocus: !Escopo.de(context).biometriaLigada,
          decoration: InputDecoration(
            labelText: 'Senha',
            errorText: _erroSenha,
            errorMaxLines: 3,
            suffixIcon: IconButton(icon: Icon(_ver ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ver = !_ver)),
          ),
          onSubmitted: (_) => _enviar(),
        ),
        if (_erroGeral != null) ...[
          const SizedBox(height: 10),
          Text(_erroGeral!, style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _enviando ? null : _enviar,
          icon: _enviando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_outline, size: 18),
          label: Text(widget.botao.toUpperCase()),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _enviando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
      ]),
    );
  }
}
