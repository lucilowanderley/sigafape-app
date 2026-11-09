import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'demo.dart';
import 'screens/entrar.dart';
import 'screens/inicio.dart';
import 'screens/servidores.dart';
import 'screens/trocar_senha.dart';
import 'sessao.dart';
import 'tema.dart';
import 'widgets/comum.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final sessao = Sessao(cliente: modoDemo ? clienteDemo() : null);
  runApp(AppSigafape(sessao: sessao));
  await sessao.iniciar();
}

class AppSigafape extends StatelessWidget {
  const AppSigafape({super.key, required this.sessao});
  final Sessao sessao;

  @override
  Widget build(BuildContext context) {
    return Escopo(
      sessao: sessao,
      child: ListenableBuilder(
        listenable: sessao,
        builder: (context, _) => MaterialApp(
          title: 'SIGAFAPE',
          debugShowCheckedModeBanner: false,
          theme: temaMaterial(sessao.tema),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: sessao.carregando
              ? const _Abertura()
              : sessao.semConexao
                  ? const TelaSemConexao()
                  : !sessao.logado
                  ? const TelaEntrar()
                  : sessao.trocarSenha
                      ? const TelaTrocarSenha(obrigatoria: true)
                      : const TelaInicio(),
        ),
      ),
    );
  }
}

class _Abertura extends StatelessWidget {
  const _Abertura();

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Scaffold(
      backgroundColor: c.entrada,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/img/brasao.png', height: 110),
          const SizedBox(height: 18),
          const Text('SIGAFAPE', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 24),
          CircularProgressIndicator(color: c.dourado),
        ]),
      ),
    );
  }
}
