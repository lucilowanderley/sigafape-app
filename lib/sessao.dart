import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api/api.dart';
import 'tema.dart';
import 'util/nativo.dart';

const versaoApp = '1.0.0';

/// Endereço padrão do sistema; pode vir na compilação: --dart-define=SERVIDOR=https://...
const servidorPadrao = String.fromEnvironment('SERVIDOR', defaultValue: bool.fromEnvironment('DEMO') ? 'https://demonstracao.sigafape' : '');

/// Estado do app: servidor, token do aparelho, usuário logado e cor escolhida.
class Sessao extends ChangeNotifier {
  Sessao({http.Client? cliente}) {
    api = Api(servidor: servidorPadrao, aoExpirar: _expirou, cliente: cliente);
  }

  late final Api api;
  Map<String, dynamic>? usuario;
  Tema tema = Tema.azul;
  bool carregando = true;
  String? avisoSaida;

  bool get logado => api.token != null && usuario != null;
  bool get trocarSenha => usuario?['trocar_senha'] == true;
  Map<String, dynamic>? get policial => usuario?['policial'] as Map<String, dynamic>?;
  String get servidor => api.servidor;

  Future<void> iniciar() async {
    await Api.prepararCertificados();
    tema = Tema.porNome(await Nativo.ler('tema'));
    api.servidor = await Nativo.ler('servidor') ?? servidorPadrao;
    api.token = await Nativo.lerSegredo('token');
    if (api.token != null) {
      try {
        usuario = (await api.get('me'))['data'] as Map<String, dynamic>?;
        await _guardarUsuario();
      } on ApiErro catch (e) {
        if (e.status == 401 || e.status == 403) {
          await _limpar();
        } else {
          // Sem rede: mantém o token e tenta de novo quando o policial atualizar a tela.
          final guardado = await Nativo.ler('usuario');
          if (guardado != null) usuario = jsonDecode(guardado) as Map<String, dynamic>;
        }
      }
    }
    carregando = false;
    notifyListeners();
  }

  Future<void> entrar(String servidor, String usuarioOuMatricula, String senha) async {
    api.servidor = Api.normalizarServidor(servidor);
    api.token = null;
    final r = await api.post('login', {
      'usuario': usuarioOuMatricula.trim(),
      'senha': senha,
      'aparelho': await Nativo.aparelho(),
      'plataforma': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'versao_app': versaoApp,
    });
    api.token = r['token'] as String;
    usuario = r['usuario'] as Map<String, dynamic>;
    await Nativo.gravar('servidor', api.servidor);
    await Nativo.gravarSegredo('token', api.token);
    await _guardarUsuario();
    avisoSaida = null;
    notifyListeners();
  }

  Future<void> atualizarUsuario() async {
    usuario = (await api.get('me'))['data'] as Map<String, dynamic>?;
    await _guardarUsuario();
    notifyListeners();
  }

  Future<void> _guardarUsuario() => Nativo.gravar('usuario', usuario == null ? null : jsonEncode(usuario));

  Future<String> trocarMinhaSenha(String atual, String nova, String confirmacao) async {
    final r = await api.post('senha', {'senha_atual': atual, 'nova_senha': nova, 'nova_senha_confirmation': confirmacao});
    api.token = r['token'] as String;
    await Nativo.gravarSegredo('token', api.token);
    await atualizarUsuario();
    return r['message']?.toString() ?? 'Senha alterada.';
  }

  Future<void> sair() async {
    try {
      await api.post('logout');
    } catch (_) {
      // Mesmo sem rede, o app esquece o token neste aparelho.
    }
    await _limpar();
    notifyListeners();
  }

  Future<void> escolherTema(Tema t) async {
    tema = t;
    await Nativo.gravar('tema', t.name);
    notifyListeners();
  }

  void _expirou() {
    if (api.token == null) return;
    avisoSaida = 'Sua sessão no app expirou ou foi desconectada. Entre novamente.';
    _limpar().then((_) => notifyListeners());
  }

  Future<void> _limpar() async {
    api.token = null;
    usuario = null;
    await Nativo.gravarSegredo('token', null);
    await Nativo.gravar('usuario', null);
  }
}
