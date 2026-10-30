import 'package:flutter/material.dart';

import '../api/api.dart';
import '../sessao.dart';
import '../tema.dart';

/// Dá acesso à Sessao em qualquer tela: Escopo.de(context).
class Escopo extends InheritedNotifier<Sessao> {
  const Escopo({super.key, required Sessao sessao, required super.child}) : super(notifier: sessao);

  static Sessao de(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Escopo>()!.notifier!;
  static Sessao ler(BuildContext context) => context.getInheritedWidgetOfExactType<Escopo>()!.notifier!;
}

Api apiDe(BuildContext context) => Escopo.ler(context).api;

void aviso(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: erro ? const Color(0xFFB3261E) : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Barra do topo com o degradê da cor escolhida.
class Topo extends StatelessWidget implements PreferredSizeWidget {
  const Topo({super.key, required this.titulo, this.acoes, this.abas, this.mostrarVoltar = true});

  final Widget titulo;
  final List<Widget>? acoes;
  final PreferredSizeWidget? abas;
  final bool mostrarVoltar;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (abas?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return AppBar(
      title: titulo,
      actions: acoes,
      bottom: abas,
      automaticallyImplyLeading: mostrarVoltar,
      flexibleSpace: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: c.topo))),
    );
  }
}

/// Título "SIGAFAPE · 8º BPM" usado no topo da tela inicial.
class Marca extends StatelessWidget {
  const Marca({super.key, this.unidade});
  final String? unidade;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Text.rich(TextSpan(children: [
      const TextSpan(text: 'SIGAFAPE'),
      if (unidade != null && unidade!.isNotEmpty) TextSpan(text: ' · $unidade', style: TextStyle(color: c.dourado)),
    ]));
  }
}

class Pilula extends StatelessWidget {
  const Pilula(this.texto, {super.key, this.cor});
  final String texto;
  final String? cor;

  @override
  Widget build(BuildContext context) {
    final (fundo, letra) = corSituacao(cor, Cores.de(context).escuro);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: letra, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(texto.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .7, color: Cores.de(context).suave)),
      );
}

class Vazio extends StatelessWidget {
  const Vazio(this.texto, {super.key, this.icone = Icons.inbox_outlined});
  final String texto;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(children: [
        Icon(icone, size: 48, color: c.suave),
        const SizedBox(height: 10),
        Text(texto, textAlign: TextAlign.center, style: TextStyle(color: c.suave, fontSize: 15)),
      ]),
    );
  }
}

class Falha extends StatelessWidget {
  const Falha(this.erro, {super.key, required this.tentar});
  final Object erro;
  final VoidCallback tentar;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_outlined, size: 48, color: c.suave),
        const SizedBox(height: 10),
        Text(erro is ApiErro ? (erro as ApiErro).mensagem : 'Não foi possível carregar.',
            textAlign: TextAlign.center, style: TextStyle(color: c.texto, fontSize: 15)),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: tentar, icon: const Icon(Icons.refresh), label: const Text('Tentar de novo')),
      ]),
    );
  }
}

/// Carrega dados da API e mostra carregando, erro (com "Tentar de novo") ou o conteúdo.
/// Arrastar para baixo atualiza. Use a chave global para recarregar de fora: chave.currentState?.recarregar().
class Carregar<T> extends StatefulWidget {
  const Carregar({super.key, required this.buscar, required this.construir});

  final Future<T> Function() buscar;
  final Widget Function(BuildContext context, T dados) construir;

  @override
  State<Carregar<T>> createState() => CarregarState<T>();
}

class CarregarState<T> extends State<Carregar<T>> {
  late Future<T> _futuro;
  T? _ultimo;

  @override
  void initState() {
    super.initState();
    _futuro = _buscar();
  }

  Future<T> _buscar() async {
    final d = await widget.buscar();
    _ultimo = d;
    return d;
  }

  Future<void> recarregar() async {
    final f = _buscar();
    setState(() {
      _futuro = f;
    });
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, s) {
        final dados = s.hasData ? s.data as T : _ultimo;
        Widget corpo;
        if (s.hasError && s.connectionState == ConnectionState.done) {
          corpo = ListView(children: [Falha(s.error!, tentar: recarregar)]);
        } else if (dados == null) {
          return const Center(child: CircularProgressIndicator());
        } else {
          corpo = widget.construir(context, dados);
        }
        return RefreshIndicator(onRefresh: recarregar, child: corpo);
      },
    );
  }
}

/// Linha de informação "Rótulo: valor" usada nos detalhes.
class Info extends StatelessWidget {
  const Info(this.rotulo, this.valor, {super.key});
  final String rotulo;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(rotulo, style: TextStyle(color: c.suave, fontSize: 13.5))),
        Expanded(child: Text(valor == null || valor!.isEmpty ? '—' : valor!, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Cartão branco (ou escuro) com cantos arredondados, usado nas listas.
class Cartao extends StatelessWidget {
  const Cartao({super.key, required this.child, this.aoTocar, this.margem = const EdgeInsets.fromLTRB(12, 0, 12, 8), this.bordaEsquerda});
  final Widget child;
  final VoidCallback? aoTocar;
  final EdgeInsets margem;
  final Color? bordaEsquerda;

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Padding(
      padding: margem,
      child: Material(
        color: c.cartao,
        elevation: c.escuro ? 0 : 1,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Container(
            decoration: bordaEsquerda == null ? null : BoxDecoration(border: Border(left: BorderSide(color: bordaEsquerda!, width: 5))),
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }
}

IconData iconeMaterial(String? tipo, String? categoria) {
  final cat = (categoria ?? '').toLowerCase();
  if (tipo == 'colete' || cat.contains('colete')) return Icons.shield_outlined;
  if (tipo == 'carregadores' || cat.contains('carregador')) return Icons.view_week_outlined;
  if (cat.contains('algema')) return Icons.link;
  if (cat.contains('rádio') || cat.contains('radio')) return Icons.settings_input_antenna;
  return Icons.gps_fixed;
}
