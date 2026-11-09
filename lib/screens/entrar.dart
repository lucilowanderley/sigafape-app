import 'package:flutter/material.dart';

import '../api/api.dart';
import '../sessao.dart';
import '../tema.dart';
import '../widgets/comum.dart';
import 'servidores.dart';

class TelaEntrar extends StatefulWidget {
  const TelaEntrar({super.key});

  @override
  State<TelaEntrar> createState() => _TelaEntrarState();
}

class _TelaEntrarState extends State<TelaEntrar> {
  final _usuario = TextEditingController();
  final _senha = TextEditingController();
  bool _enviando = false, _ver = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final s = Escopo.ler(context);
    _erro = s.avisoSaida;
  }

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (_usuario.text.trim().isEmpty || _senha.text.isEmpty) {
      setState(() => _erro = 'Informe usuário (ou matrícula) e senha.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await Escopo.ler(context).entrar(_usuario.text, _senha.text);
    } on ApiErro catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro = e.detalhe;
          _senha.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final servidor = Escopo.de(context).servidor;
    final semHttps = servidor.startsWith('http://');
    return Scaffold(
      body: Stack(children: [
        Column(children: [
          Expanded(flex: 55, child: Container(color: c.entrada)),
          Expanded(flex: 45, child: Container(color: c.fundo)),
        ]),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  Image.asset('assets/img/brasao.png', height: 96),
                  const SizedBox(height: 8),
                  const Text('SIGAFAPE', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  Text('Operador de Campo', style: TextStyle(color: c.dourado, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 18),
                  Card(
                    elevation: 8,
                    shadowColor: Colors.black38,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: AutofillGroup(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _usuario,
                            enabled: !_enviando,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(labelText: 'Usuário ou matrícula'),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _senha,
                            enabled: !_enviando,
                            obscureText: !_ver,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              suffixIcon: IconButton(icon: Icon(_ver ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ver = !_ver)),
                            ),
                            onSubmitted: (_) => _entrar(),
                          ),
                          if (semHttps) ...[
                            const SizedBox(height: 8),
                            const Text('Atenção: endereço sem HTTPS. Use só para testes na rede interna.',
                                style: TextStyle(color: Color(0xFF9A4A07), fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                          if (_erro != null) ...[
                            const SizedBox(height: 12),
                            Text(_erro!, style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _enviando ? null : _entrar,
                            child: _enviando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('ENTRAR'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaServidores())),
                            icon: Icon(Icons.dns_outlined, size: 16, color: c.suave),
                            label: Text('Servidor: ${servidor.replaceFirst(RegExp(r'^https?://'), '')}', style: TextStyle(color: c.suave, fontSize: 12.5)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Versão $versaoApp', style: TextStyle(color: c.suave, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
