import 'package:flutter/services.dart';

/// Funções nativas do app (MainActivity.kt no Android, AppDelegate.swift no iOS).
/// Feito sem plugins de terceiros para o app aceitar o Android 6.0.
class Nativo {
  static const _canal = MethodChannel('sigafape/nativo');

  /// Usado nos testes, onde não há canal nativo.
  static final Map<String, String> _memoria = {};
  static bool semCanal = false;

  static Future<String?> ler(String chave) async {
    if (semCanal) return _memoria['p_$chave'];
    return _canal.invokeMethod<String>('ler', {'chave': chave});
  }

  static Future<void> gravar(String chave, String? valor) async {
    if (semCanal) {
      valor == null ? _memoria.remove('p_$chave') : _memoria['p_$chave'] = valor;
      return;
    }
    await _canal.invokeMethod('gravar', {'chave': chave, 'valor': valor});
  }

  /// Guardado cifrado com chave do Android Keystore (ou no Keychain do iOS).
  static Future<String?> lerSegredo(String chave) async {
    if (semCanal) return _memoria['s_$chave'];
    return _canal.invokeMethod<String>('lerSegredo', {'chave': chave});
  }

  static Future<void> gravarSegredo(String chave, String? valor) async {
    if (semCanal) {
      valor == null ? _memoria.remove('s_$chave') : _memoria['s_$chave'] = valor;
      return;
    }
    await _canal.invokeMethod('gravarSegredo', {'chave': chave, 'valor': valor});
  }

  static Future<String> aparelho() async {
    if (semCanal) return 'Aparelho de teste';
    try {
      return await _canal.invokeMethod<String>('aparelho') ?? 'Celular';
    } catch (_) {
      return 'Celular';
    }
  }

  /// Abre um anexo baixado em outro app do celular. Falso se nenhum app abrir o arquivo.
  static Future<bool> abrirArquivo(String nome, Uint8List bytes, String? tipo) async {
    if (semCanal) return false;
    return await _canal.invokeMethod<bool>('abrirArquivo', {'nome': nome, 'bytes': bytes, 'tipo': tipo}) ?? false;
  }
}
