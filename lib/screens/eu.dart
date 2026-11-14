import 'package:flutter/material.dart';

import '../api/api.dart';
import '../sessao.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../util/nativo.dart';
import '../widgets/comum.dart';
import 'ficha.dart';
import 'inspecoes.dart';
import 'servidores.dart';
import 'trocar_senha.dart';

/// Eu: minha ficha, inspeções, aparelhos conectados, aparência (cor do app), senha e sair.
class TelaEu extends StatelessWidget {
  const TelaEu({super.key});

  @override
  Widget build(BuildContext context) {
    final sessao = Escopo.de(context);
    final c = Cores.de(context);
    final u = sessao.usuario ?? {};
    final pol = sessao.policial;
    void abrir(Widget t) => Navigator.push(context, MaterialPageRoute(builder: (_) => t));
    Widget opcao(IconData i, String t, String? sub, VoidCallback f) => ListTile(
          leading: Icon(i, color: c.destaque),
          title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: sub == null ? null : Text(sub),
          trailing: Icon(Icons.chevron_right, color: c.suave),
          onTap: f,
        );
    return Scaffold(
      appBar: const Topo(titulo: Text('Eu'), mostrarVoltar: false),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Cartao(
          margem: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: c.dourado, child: Text(u['iniciais']?.toString() ?? '', style: TextStyle(color: c.entrada, fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pol?['nome']?.toString() ?? u['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                Text(['Usuário ${u['usuario']}', if (pol?['matricula'] != null) 'Mat. ${pol!['matricula']}'].join(' · '), style: TextStyle(color: c.suave, fontSize: 13)),
                Text(sessao.servidor.replaceFirst(RegExp(r'^https?://'), ''), style: TextStyle(color: c.suave, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            opcao(Icons.badge_outlined, 'Minha ficha', 'Dados funcionais e pessoais; pedir atualização ao RH', () => abrir(const TelaFicha())),
            opcao(Icons.verified_user_outlined, 'Inspeção do arsenal', 'Convocações e resultados', () => abrir(const TelaInspecoes())),
            opcao(Icons.devices_outlined, 'Aparelhos conectados', 'Desconecte um celular perdido', () => abrir(const _TelaAparelhos())),
            opcao(Icons.dns_outlined, 'Servidores', 'Wi-Fi da unidade, Tailscale e outros endereços', () => abrir(const TelaServidores())),
          ]),
        ),
        const TituloSecao('Aparência'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: RadioGroup<Tema>(
            groupValue: sessao.tema,
            onChanged: (t) => sessao.escolherTema(t!),
            child: Column(children: [
              for (final t in Tema.values)
                RadioListTile<Tema>(
                  value: t,
                  title: Text(t.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                  secondary: _Amostra(Cores.para(t)),
                ),
            ]),
          ),
        ),
        const TituloSecao('Segurança'),
        const _CartaoDigital(),
        const TituloSecao('Conta'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            opcao(Icons.key_outlined, 'Trocar senha', 'Os outros aparelhos saem do app', () => abrir(const TelaTrocarSenha())),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFB3261E)),
              title: const Text('Sair deste aparelho', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB3261E))),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sair do app?'),
                    content: Text(sessao.biometriaLigada ? 'Para entrar de novo, use a digital/rosto ou o usuário e a senha.' : 'Você vai precisar do usuário (ou matrícula) e da senha para entrar de novo.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
                    ],
                  ),
                );
                if (ok == true) await sessao.sair();
              },
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('SIGAFAPE · app do Operador de Campo · versão $versaoApp', textAlign: TextAlign.center, style: TextStyle(color: c.suave, fontSize: 12)),
        ),
      ]),
    );
  }
}

/// Entrar e assinar com digital ou rosto (opção A, 2026-11-14). Ligar pede a senha uma vez; a chave fica
/// no chip de segurança do celular e só o servidor guarda a parte pública.
class _CartaoDigital extends StatefulWidget {
  const _CartaoDigital();

  @override
  State<_CartaoDigital> createState() => _CartaoDigitalState();
}

class _CartaoDigitalState extends State<_CartaoDigital> {
  String? _situacao;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    Nativo.biometriaSituacao().then((s) {
      if (mounted) setState(() => _situacao = s);
    });
  }

  String get _explicacao => switch (_situacao) {
        'antigo' => 'Este celular tem Android anterior ao 9 e não permite.',
        'sem_sensor' => 'Este celular não tem leitor de digital ou rosto seguro.',
        'sem_cadastro' => 'Cadastre uma digital (ou o rosto) nas configurações do celular e volte aqui.',
        _ => 'Use a digital (ou o rosto, se o celular permitir) para entrar e para assinar com a sua matrícula. A senha continua valendo.',
      };

  Future<void> _alternar(bool ligar) async {
    final sessao = Escopo.ler(context);
    if (!ligar) {
      setState(() => _ocupado = true);
      await sessao.desligarBiometria();
      if (!mounted) return;
      setState(() => _ocupado = false);
      aviso(context, 'Digital/rosto desligados neste aparelho.');
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Cores.de(context).cartao,
      builder: (_) => const _JanelaLigarDigital(),
    );
    if (ok == true && mounted) aviso(context, 'Pronto: digital/rosto ligados. Já pode entrar e assinar com eles.');
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final sessao = Escopo.de(context);
    final pode = _situacao == 'ok';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: SwitchListTile(
        key: const Key('chave-digital'),
        secondary: Icon(Icons.fingerprint, color: c.destaque, size: 30),
        title: const Text('Entrar e assinar com digital ou rosto', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sessao.biometriaLigada ? 'Ligado neste aparelho. Trocar a senha desliga.' : _explicacao),
        value: sessao.biometriaLigada,
        onChanged: _ocupado || (!pode && !sessao.biometriaLigada) ? null : _alternar,
      ),
    );
  }
}

class _JanelaLigarDigital extends StatefulWidget {
  const _JanelaLigarDigital();

  @override
  State<_JanelaLigarDigital> createState() => _JanelaLigarDigitalState();
}

class _JanelaLigarDigitalState extends State<_JanelaLigarDigital> {
  final _senha = TextEditingController();
  bool _enviando = false, _ver = false;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _ligar() async {
    if (_senha.text.isEmpty) {
      setState(() => _erro = 'Informe sua senha.');
      return;
    }
    setState(() { _enviando = true; _erro = null; });
    try {
      await Escopo.ler(context).ligarBiometria(_senha.text);
      if (mounted) Navigator.pop(context, true);
    } on ApiErro catch (e) {
      if (mounted) setState(() { _enviando = false; _erro = e.detalhe; });
    } on ErroLocal catch (e) {
      if (mounted) setState(() { _enviando = false; _erro = e.mensagem; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Ligar digital ou rosto', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Confirme sua senha. Depois o celular pede a digital (ou o rosto) uma vez para testar. A senha não fica guardada no celular.',
            style: TextStyle(color: c.suave, fontSize: 14)),
        const SizedBox(height: 16),
        TextField(
          key: const Key('senha-digital'),
          controller: _senha,
          enabled: !_enviando,
          obscureText: !_ver,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Senha',
            errorText: _erro,
            errorMaxLines: 3,
            suffixIcon: IconButton(icon: Icon(_ver ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ver = !_ver)),
          ),
          onSubmitted: (_) => _ligar(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('ligar-digital'),
          onPressed: _enviando ? null : _ligar,
          icon: _enviando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fingerprint),
          label: const Text('LIGAR'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _enviando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
      ]),
    );
  }
}

class _Amostra extends StatelessWidget {
  const _Amostra(this.c);
  final Cores c;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(colors: [c.heroi.first, c.heroi.first, c.dourado], stops: const [0, .65, .65]),
          border: Border.all(color: Colors.black12),
        ),
      );
}

class _TelaAparelhos extends StatefulWidget {
  const _TelaAparelhos();

  @override
  State<_TelaAparelhos> createState() => _TelaAparelhosState();
}

class _TelaAparelhosState extends State<_TelaAparelhos> {
  final _chave = GlobalKey<CarregarState<List>>();

  Future<void> _desconectar(Map a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar aparelho?'),
        content: Text('"${a['aparelho']}" vai sair do app e precisará entrar de novo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desconectar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = await apiDe(context).delete('aparelhos/${a['id']}');
      if (mounted) aviso(context, r['message']?.toString() ?? 'Aparelho desconectado.');
    } on ApiErro catch (e) {
      if (mounted) aviso(context, e.detalhe, erro: true);
    }
    _chave.currentState?.recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Scaffold(
      appBar: const Topo(titulo: Text('Aparelhos conectados')),
      body: Carregar<List>(
        key: _chave,
        buscar: () async => (await apiDe(context).get('aparelhos'))['data'] as List,
        construir: (context, lista) => ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [
          for (final a in lista)
            Cartao(
              child: Row(children: [
                Icon(a['plataforma'] == 'ios' ? Icons.phone_iphone : Icons.phone_android, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['aparelho']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('Último uso ${dataHora(a['ultimo_uso'] ?? a['conectado_em'])}${a['versao_app'] != null ? ' · app ${a['versao_app']}' : ''}',
                        style: TextStyle(color: c.suave, fontSize: 12.5)),
                    if (a['expira_em'] != null) Text('Vale até ${dataCurta(a['expira_em'])}', style: TextStyle(color: c.suave, fontSize: 12.5)),
                  ]),
                ),
                a['este_aparelho'] == true
                    ? const Pilula('Este', cor: 'green')
                    : IconButton(tooltip: 'Desconectar', icon: const Icon(Icons.link_off), onPressed: () => _desconectar(a as Map)),
              ]),
            ),
        ]),
      ),
    );
  }
}
