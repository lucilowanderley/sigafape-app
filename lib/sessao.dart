import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api/api.dart';
import 'tema.dart';
import 'util/nativo.dart';

const versaoApp = '1.4.1';

/// Endereço padrão do sistema; pode vir na compilação: --dart-define=SERVIDOR=https://...
const servidorPadrao = String.fromEnvironment('SERVIDOR', defaultValue: bool.fromEnvironment('DEMO') ? 'https://demonstracao.sigafape' : '');

/// Endereços do 8º BPM já cadastrados no app (Eu → Servidores): Wi-Fi da unidade e 4G (Tailscale Funnel, porta 8443).
const enderecosPadrao = [
  ('Wi-Fi da unidade', 'https://sigafape.8bpm.internal'),
  ('4G (internet)', 'https://sigafape.ide-pirarucu.ts.net:8443'),
];

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


  /// Endereços do sistema guardados no celular, na ordem em que o app tenta (opção C).
  List<Servidor> servidores = [];

  /// Resultado da última tentativa de cada endereço (ex.: "respondeu em 120 ms" ou o erro).
  final Map<String, String> situacao = {};
  final Set<String> respondeu = {};

  /// Nenhum endereço respondeu (ou nenhum foi cadastrado): o app mostra a tela "Sem conexão".
  bool semConexao = false;
  bool procurando = false;

  Future<void> iniciar() async {
    await Api.prepararCertificados();
    tema = Tema.porNome(await Nativo.ler('tema'));
    await _carregarServidores();
    api.token = await Nativo.lerSegredo('token');
    if (servidores.isEmpty) {
      semConexao = true;
    } else if (api.token != null) {
      final guardado = await Nativo.ler('usuario');
      if (guardado != null) usuario = jsonDecode(guardado) as Map<String, dynamic>;
      await _buscarUsuario();
    }
    carregando = false;
    notifyListeners();
  }

  /// Confere o login guardado; sem rede, procura outro endereço e tenta de novo.
  Future<void> _buscarUsuario({bool procurar = true}) async {
    try {
      usuario = (await api.get('me'))['data'] as Map<String, dynamic>?;
      await _guardarUsuario();
    } on ApiErro catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _limpar();
      } else if (e.status == 0 && procurar && await procurarServidor()) {
        await _buscarUsuario(procurar: false);
      }
    }
  }

  Future<void> entrar(String usuarioOuMatricula, String senha, {bool procurar = true}) async {
    api.token = null;
    final Map<String, dynamic> r;
    try {
      r = await api.post('login', {
        'usuario': usuarioOuMatricula.trim(),
        'senha': senha,
        'aparelho': await Nativo.aparelho(),
        'plataforma': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'versao_app': versaoApp,
      });
    } on ApiErro catch (e) {
      // Servidor fora do ar: tenta os outros endereços; se algum responder, repete o login.
      if (e.status == 0 && procurar && await procurarServidor()) return entrar(usuarioOuMatricula, senha, procurar: false);
      rethrow;
    }
    api.token = r['token'] as String;
    usuario = r['usuario'] as Map<String, dynamic>;
    await Nativo.gravarSegredo('token', api.token);
    await _guardarUsuario();
    avisoSaida = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- servidores

  /// Falso na demonstração e nos testes (que montam a própria lista).
  static bool usarEnderecosPadrao = !bool.fromEnvironment('DEMO');

  Future<void> _carregarServidores() async {
    final lista = await Nativo.ler('servidores');
    if (lista != null) {
      servidores = (jsonDecode(lista) as List).map((e) => Servidor.deJson(e as Map<String, dynamic>)).toList();
    }
    final atual = await Nativo.ler('servidor') ?? servidorPadrao;
    // Versão 1.0.0 guardava um endereço só: vira o primeiro da lista.
    if (servidores.isEmpty && atual.isNotEmpty) {
      servidores = [Servidor(nomeSugerido(atual), atual)];
      await _salvarServidores();
    }
    // Uma vez só: acrescenta os endereços padrão que faltam (se o policial apagar um depois, não volta).
    if (usarEnderecosPadrao && await Nativo.ler('enderecos_padrao') != '1') {
      for (final (nome, endereco) in enderecosPadrao) {
        if (!servidores.any((s) => s.endereco == endereco)) servidores.add(Servidor(nome, endereco));
      }
      await _salvarServidores();
      await Nativo.gravar('enderecos_padrao', '1');
    }
    api.servidor = servidores.any((s) => s.endereco == atual) ? atual : (servidores.isEmpty ? '' : servidores.first.endereco);
  }

  Future<void> _salvarServidores() => Nativo.gravar('servidores', jsonEncode(servidores.map((s) => s.json).toList()));

  Future<void> _usar(String endereco) async {
    api.servidor = endereco;
    await Nativo.gravar('servidor', endereco);
  }

  /// Tenta o endereço em uso e depois os outros, na ordem da lista. Usa o primeiro que responder.
  Future<bool> procurarServidor() async {
    procurando = true;
    notifyListeners();
    final ordem = [
      if (servidores.any((s) => s.endereco == api.servidor)) api.servidor,
      ...servidores.map((s) => s.endereco).where((e) => e != api.servidor),
    ];
    var achou = false;
    for (final e in ordem) {
      if (await testar(e)) {
        await _usar(e);
        achou = true;
        break;
      }
    }
    procurando = false;
    semConexao = !achou;
    notifyListeners();
    return achou;
  }

  /// Testa um endereço e guarda o resultado em [situacao].
  Future<bool> testar(String endereco) async {
    try {
      final ms = await api.sondar(endereco);
      situacao[endereco] = 'respondeu em $ms ms';
      respondeu.add(endereco);
      return true;
    } on ApiErro catch (e) {
      situacao[endereco] = dicaConexao(endereco, e);
      respondeu.remove(endereco);
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Testa e salva um endereço (novo ou editado). Se responder, passa a ser o endereço em uso.
  /// Devolve null se deu certo, ou a mensagem do problema.
  Future<String?> salvarServidor(String nome, String endereco, {Servidor? antigo}) async {
    final e = Api.normalizarServidor(endereco);
    if (e.isEmpty) return 'Informe o IP ou o nome do servidor.';
    if (!await testar(e)) return situacao[e];
    final novo = Servidor(nome.trim().isEmpty ? nomeSugerido(e) : nome.trim(), e);
    final i = antigo == null ? -1 : servidores.indexOf(antigo);
    if (i >= 0) {
      servidores[i] = novo;
    } else {
      servidores.add(novo);
    }
    servidores.removeWhere((s) => s.endereco == e && !identical(s, novo));
    await _salvarServidores();
    await _usar(e);
    semConexao = false;
    if (api.token != null && usuario == null) await _buscarUsuario(procurar: false);
    notifyListeners();
    return null;
  }

  Future<void> removerServidor(Servidor s) async {
    servidores.remove(s);
    await _salvarServidores();
    if (api.servidor == s.endereco) await _usar(servidores.isEmpty ? '' : servidores.first.endereco);
    notifyListeners();
  }

  Future<void> usarServidor(Servidor s) async {
    await _usar(s.endereco);
    semConexao = false;
    notifyListeners();
  }

  /// [para] já vem ajustado (índice depois de tirar o item da posição [de]).
  Future<void> reordenarServidores(int de, int para) async {
    final s = servidores.removeAt(de);
    servidores.insert(para, s);
    await _salvarServidores();
    notifyListeners();
  }

  /// "Tentar de novo" na tela Sem conexão: procura um endereço e, se achar, retoma o login guardado.
  Future<void> tentarDeNovo() async {
    if (await procurarServidor() && api.token != null) await _buscarUsuario(procurar: false);
    notifyListeners();
  }

  /// Foto 3x4 do Efetivo (baixada com o token; guardada só na memória do app).
  Uint8List? foto;
  String? _fotoDe;

  Future<void> carregarFoto() async {
    final url = usuario?['foto']?.toString();
    if (url == null || url.isEmpty) {
      if (foto != null) {
        foto = null;
        _fotoDe = null;
        notifyListeners();
      }
      return;
    }
    if (url == _fotoDe) return;
    try {
      // Usa o endereço em uso (o servidor pode ter montado o link com outro nome).
      final v = Uri.tryParse(url)?.queryParameters['v'];
      final (bytes, _) = await api.baixar('${api.servidor}/api/v1/foto${v != null ? '?v=$v' : ''}');
      foto = bytes;
      _fotoDe = url;
      notifyListeners();
    } catch (_) {
      // Sem foto: o cartão continua com as iniciais.
    }
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
    await Nativo.desligarAvisos();
    await Nativo.desligarLocalizacao();
    await Nativo.gravar('vistos', null);
    api.token = null;
    usuario = null;
    foto = null;
    _fotoDe = null;
    await Nativo.gravarSegredo('token', null);
    await Nativo.gravar('usuario', null);
  }
}

/// Um endereço do sistema salvo no celular.
class Servidor {
  Servidor(this.nome, this.endereco);

  final String nome;
  final String endereco;

  factory Servidor.deJson(Map<String, dynamic> j) => Servidor(j['nome']?.toString() ?? '', j['endereco']?.toString() ?? '');
  Map<String, String> get json => {'nome': nome, 'endereco': endereco};
}

/// Nome sugerido pelo tipo de endereço.
String nomeSugerido(String endereco) {
  final host = Uri.tryParse(endereco)?.host ?? endereco;
  final ip = RegExp(r'^(\d+)\.(\d+)\.\d+\.\d+$').firstMatch(host);
  if (ip != null) {
    final a = int.parse(ip.group(1)!), b = int.parse(ip.group(2)!);
    if (a == 100 && b >= 64 && b <= 127) return 'Tailscale (fora da unidade)';
    if (a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31)) return 'Wi-Fi da unidade';
    return 'IP público';
  }
  if (host.endsWith('.internal') || host.endsWith('.local') || host.endsWith('.intra') || !host.contains('.')) return 'Nome interno';
  return 'Endereço na internet';
}

/// Mensagem curta do problema, com uma dica pelo tipo de endereço.
String dicaConexao(String endereco, ApiErro e) {
  if (e.status != 0) return e.mensagem;
  final m = e.mensagem;
  if (m.contains('certificado')) return 'certificado HTTPS não reconhecido';
  final tipo = nomeSugerido(endereco);
  if (tipo.startsWith('Tailscale')) return 'sem resposta · o Tailscale está ligado?';
  if (tipo == 'Wi-Fi da unidade' || tipo == 'Nome interno') return 'sem resposta · está no Wi-Fi da unidade?';
  return 'sem resposta';
}
