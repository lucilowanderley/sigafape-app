import 'dart:io' show Platform;

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

  /// Posição de teste (testes e modo demonstração no computador).
  static Local? localDeTeste = const Local(-5.79448, -35.21100, 9);

  /// GPS do celular. Pede a permissão na primeira vez. Lança [ErroLocal] com a mensagem para o policial.
  static Future<Local> localizacao() async {
    if (semCanal) {
      final l = localDeTeste;
      if (l == null) throw const ErroLocal('Não foi possível obter a sua localização. Vá para um lugar aberto e tente de novo.');
      return l;
    }
    try {
      final m = await _canal.invokeMapMethod<String, dynamic>('localizacao');
      return Local((m!['latitude'] as num).toDouble(), (m['longitude'] as num).toDouble(), (m['precisao'] as num?)?.toDouble());
    } on PlatformException catch (e) {
      throw ErroLocal(switch (e.code) {
        'sem_permissao' => Platform.isIOS
            ? 'O app precisa da permissão de localização. Libere em Ajustes › SIGAFAPE › Localização.'
            : 'O app precisa da permissão de localização. Libere em Configurações › Apps › SIGAFAPE › Permissões.',
        'gps_desligado' => Platform.isIOS
            ? 'A localização do iPhone está desligada. Ligue em Ajustes › Privacidade e Segurança › Serviços de Localização.'
            : 'A localização do celular está desligada. Ligue o GPS e tente de novo.',
        _ => 'Não foi possível obter a sua localização. Vá para um lugar aberto e tente de novo.',
      });
    } on MissingPluginException {
      throw const ErroLocal('Localização indisponível neste aparelho.');
    }
  }
}

class Local {
  const Local(this.latitude, this.longitude, [this.precisao]);
  final double latitude, longitude;
  final double? precisao;
}

class ErroLocal implements Exception {
  const ErroLocal(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}
