import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Erro devolvido pela API (ou de rede), com a mensagem pronta para mostrar ao policial.
class ApiErro implements Exception {
  ApiErro(this.mensagem, {this.status = 0, this.erros = const {}, this.trocarSenha = false});

  final String mensagem;
  final int status;
  final Map<String, List<String>> erros;
  final bool trocarSenha;

  /// Primeira mensagem de um campo (ex.: "senha" na assinatura).
  String? campo(String nome) => erros[nome]?.isNotEmpty == true ? erros[nome]!.first : null;

  /// Mensagem mais útil: a do primeiro campo com erro, ou a geral.
  String get detalhe => erros.values.where((l) => l.isNotEmpty).map((l) => l.first).firstOrNull ?? mensagem;

  @override
  String toString() => mensagem;
}

/// Cliente da API /api/v1 do SIGAFAPE.
class Api {
  Api({required this.servidor, this.token, this.aoExpirar, http.Client? cliente}) : _clienteFixo = cliente;

  /// Endereço do sistema, ex.: https://sigafape.pmrn.internal (sem /api/v1).
  String servidor;
  String? token;

  /// Chamado quando a API responde 401 (token vencido, revogado ou conta desativada).
  void Function()? aoExpirar;

  final http.Client? _clienteFixo;
  http.Client get _cliente => _clienteFixo ?? _clientePadrao;
  static http.Client _clientePadrao = http.Client();

  static const _limite = Duration(seconds: 25);

  /// Carrega a CA própria da rede interna (assets/certs/ca.pem), se existir, além das CAs do sistema.
  static Future<void> prepararCertificados() async {
    try {
      final pem = await rootBundle.load('assets/certs/ca.pem');
      final bytes = pem.buffer.asUint8List();
      if (bytes.length < 100) return; // arquivo vazio de exemplo
      final ctx = SecurityContext(withTrustedRoots: true)..setTrustedCertificatesBytes(bytes);
      _clientePadrao = IOClient(HttpClient(context: ctx)..connectionTimeout = const Duration(seconds: 15));
    } catch (_) {
      // Sem CA própria: usa só as do sistema.
    }
  }

  static String normalizarServidor(String s) {
    var v = s.trim();
    if (v.isEmpty) return v;
    if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'https://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (v.endsWith('/api/v1')) v = v.substring(0, v.length - 7);
    return v;
  }

  Uri _uri(String caminho, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
    });
    final base = Uri.parse('$servidor/api/v1/$caminho');
    return q.isEmpty ? base : base.replace(queryParameters: q);
  }

  Map<String, String> get _cabecalhos => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String caminho, [Map<String, dynamic>? query]) =>
      _enviar(() => _cliente.get(_uri(caminho, query), headers: _cabecalhos));

  /// GET num endereço completo (ex.: conferência pública /api/conferir/{código}), com o token do aparelho.
  Future<Map<String, dynamic>> getUrl(String url) => _enviar(() => _cliente.get(Uri.parse(url), headers: _cabecalhos));

  /// [limite] maior para envios pesados (ex.: ocorrência com fotos no 4G).
  Future<Map<String, dynamic>> post(String caminho, [Map<String, dynamic>? corpo, Duration limite = _limite]) =>
      _enviar(() => _cliente.post(_uri(caminho), headers: _cabecalhos, body: jsonEncode(corpo ?? {})), limite: limite);

  Future<Map<String, dynamic>> delete(String caminho) =>
      _enviar(() => _cliente.delete(_uri(caminho), headers: _cabecalhos));

  /// Baixa um arquivo (anexo de alerta) com o token do aparelho.
  Future<(Uint8List, String?)> baixar(String url) async {
    final r = await _rede(() => _cliente.get(Uri.parse(url), headers: {if (token != null) 'Authorization': 'Bearer $token'}));
    if (r.statusCode != 200) _erro(r);
    return (r.bodyBytes, r.headers['content-type']);
  }

  /// Confere se [base] responde como o SIGAFAPE (GET /api/v1/me sem token deve dar 401 em JSON).
  /// Devolve o tempo de resposta em milissegundos; lança ApiErro se não responder.
  Future<int> sondar(String base) async {
    final relogio = Stopwatch()..start();
    final r = await _rede(() => _cliente.get(Uri.parse('$base/api/v1/me'), headers: const {'Accept': 'application/json'}), limite: const Duration(seconds: 6));
    var json = false;
    try {
      json = jsonDecode(utf8.decode(r.bodyBytes)) is Map;
    } catch (_) {}
    if ((r.statusCode != 401 && r.statusCode != 200) || !json) {
      throw ApiErro('O endereço respondeu, mas não é o SIGAFAPE (código ${r.statusCode}).', status: r.statusCode);
    }
    return relogio.elapsedMilliseconds;
  }

  Future<http.Response> _rede(Future<http.Response> Function() fazer, {Duration limite = _limite}) async {
    try {
      return await fazer().timeout(limite);
    } on TimeoutException {
      throw ApiErro('O servidor demorou para responder. Verifique a conexão e tente de novo.');
    } on HandshakeException {
      throw ApiErro('Não foi possível confirmar o certificado do servidor (HTTPS). Fale com o administrador do sistema.');
    } on SocketException {
      throw ApiErro('Sem conexão com o servidor. Verifique a internet ou a rede da unidade.');
    } on http.ClientException {
      throw ApiErro('Sem conexão com o servidor. Verifique a internet ou a rede da unidade.');
    }
  }

  Future<Map<String, dynamic>> _enviar(Future<http.Response> Function() fazer, {Duration limite = _limite}) async {
    final r = await _rede(fazer, limite: limite);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return {};
      final dados = jsonDecode(utf8.decode(r.bodyBytes));
      return dados is Map<String, dynamic> ? dados : {'data': dados};
    }
    _erro(r);
  }

  Never _erro(http.Response r) {
    Map<String, dynamic> corpo = {};
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map<String, dynamic>) corpo = d;
    } catch (_) {}
    final erros = <String, List<String>>{};
    (corpo['errors'] as Map?)?.forEach((k, v) => erros[k.toString()] = (v as List).map((e) => e.toString()).toList());
    var msg = corpo['message']?.toString() ?? '';
    switch (r.statusCode) {
      case 401:
        aoExpirar?.call();
        msg = msg.isEmpty ? 'Sessão do app expirada. Entre novamente.' : msg;
      case 404:
        msg = msg.isEmpty ? 'Registro não encontrado.' : msg;
      case 429:
        msg = 'Muitas tentativas. Aguarde um minuto e tente de novo.';
      default:
        if (msg.isEmpty) msg = 'Erro no servidor (${r.statusCode}). Tente novamente.';
    }
    throw ApiErro(msg, status: r.statusCode, erros: erros, trocarSenha: corpo['trocar_senha'] == true);
  }
}
