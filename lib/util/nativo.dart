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

  /// Avisos mostrados nos testes (o canal nativo não existe lá).
  static final List<String> avisosDeTeste = [];

  /// Mostra um aviso na barra do celular (som/vibração; urgente aparece por cima da tela).
  static Future<void> avisar(String chave, String titulo, String texto, String? prioridade) async {
    if (semCanal) {
      avisosDeTeste.add(titulo);
      return;
    }
    try {
      await _canal.invokeMethod('avisar', {'chave': chave, 'titulo': titulo, 'texto': texto, 'prioridade': prioridade});
    } catch (_) {}
  }

  /// Android 13+: pede a permissão de avisos. Também agenda a conferência em segundo plano (a cada 15 min).
  static Future<void> ligarAvisos() async {
    if (semCanal) return;
    try {
      await _canal.invokeMethod('permitirAvisos');
      await _canal.invokeMethod('agendarConferencia');
    } catch (_) {
      // iPhone ainda sem conferência em segundo plano.
    }
  }

  static Future<void> desligarAvisos() async {
    if (semCanal) return;
    try {
      await _canal.invokeMethod('cancelarConferencia');
    } catch (_) {}
  }

  /// Localização em segundo plano (aviso fixo na barra do Android). Pede a permissão se faltar.
  static bool localizacaoLigadaNoTeste = false;

  static Future<void> ligarLocalizacao() async {
    if (semCanal) {
      localizacaoLigadaNoTeste = true;
      return;
    }
    try {
      await _canal.invokeMethod('ligarLocalizacao');
    } catch (_) {}
  }

  static Future<void> desligarLocalizacao() async {
    if (semCanal) {
      localizacaoLigadaNoTeste = false;
      return;
    }
    try {
      await _canal.invokeMethod('desligarLocalizacao');
    } catch (_) {}
  }

  /// QR lido nos testes.
  static String? qrDeTeste;

  /// Abre a câmera (leitor de QR do Google Play Services) e devolve o texto do QR; null se cancelar.
  /// Lança [ErroLocal] com a mensagem quando o leitor não existe no aparelho.
  static Future<String?> lerQr() async {
    if (semCanal) return qrDeTeste;
    try {
      return await _canal.invokeMethod<String>('lerQr');
    } on PlatformException catch (e) {
      throw ErroLocal(e.code == 'sem_leitor'
          ? 'Este celular não tem o leitor de QR do Google. Digite o código que aparece embaixo do QR.'
          : 'Não foi possível abrir a câmera. Tente de novo.');
    } on MissingPluginException {
      throw const ErroLocal('Leitor de QR ainda não disponível neste aparelho. Digite o código.');
    }
  }

  /// Fotos devolvidas nos testes (sem o canal nativo).
  static List<Uint8List> fotosDeTeste = [];

  /// Abre a câmera e devolve a foto já reduzida (JPEG até 1600 px); lista vazia se cancelar.
  static Future<List<Uint8List>> tirarFoto() => _fotos('tirarFoto', const {}, 'Não foi possível abrir a câmera.');

  /// Abre a galeria (pode escolher várias, até [maximo]); devolve as fotos já reduzidas.
  static Future<List<Uint8List>> escolherFotos(int maximo) => _fotos('escolherFotos', {'maximo': maximo}, 'Não foi possível abrir a galeria.');

  static Future<List<Uint8List>> _fotos(String metodo, Map<String, Object> args, String falha) async {
    if (semCanal) return List.of(fotosDeTeste);
    try {
      final r = await _canal.invokeMethod<List<Object?>>(metodo, args);
      return [for (final f in r ?? const []) if (f is Uint8List) f];
    } on PlatformException {
      throw ErroLocal('$falha Tente de novo.');
    } on MissingPluginException {
      throw const ErroLocal('Fotos ainda não disponíveis nesta versão do app.');
    }
  }

  // ------------------------------------------------------------ digital/rosto (opção A, 2026-11-14)

  /// Testes: situação e assinatura simuladas (sem canal nativo).
  static String biometriaDeTeste = 'antigo';
  static bool biometriaCancelaDeTeste = false;

  /// "ok", "sem_cadastro", "sem_sensor" ou "antigo" (Android antes do 9 / iPhone por enquanto).
  static Future<String> biometriaSituacao() async {
    if (semCanal) return biometriaDeTeste;
    try {
      return await _canal.invokeMethod<String>('biometriaSituacao') ?? 'antigo';
    } catch (_) {
      return 'antigo';
    }
  }

  /// Cria a chave no chip de segurança e devolve a pública (base64).
  static Future<String> biometriaCriarChave() async {
    if (semCanal) return 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEteste';
    try {
      return (await _canal.invokeMethod<String>('biometriaCriar'))!;
    } on PlatformException catch (e) {
      throw ErroLocal('Não foi possível preparar a digital neste aparelho (${e.message ?? e.code}).');
    }
  }

  static Future<void> biometriaApagar() async {
    if (semCanal) return;
    try {
      await _canal.invokeMethod('biometriaApagar');
    } catch (_) {}
  }

  /// Pede a digital/rosto e assina [texto]. Devolve null se o policial cancelar ("Usar senha").
  /// Lança [ErroLocal] em erro; código 'invalidada' quando cadastraram outra digital no celular.
  static Future<String?> biometriaAssinar(String texto, {required String titulo, String subtitulo = ''}) async {
    if (semCanal) return biometriaCancelaDeTeste ? null : 'assinatura-de-teste';
    try {
      return await _canal.invokeMethod<String>('biometriaAssinar', {'texto': texto, 'titulo': titulo, 'subtitulo': subtitulo});
    } on PlatformException catch (e) {
      if (e.code == 'cancelado') return null;
      throw ErroBiometria(e.code, switch (e.code) {
        'invalidada' => 'Uma digital nova foi cadastrada neste celular. Por segurança, ligue a digital de novo em Eu → Segurança.',
        'sem_chave' => 'A digital não está ligada neste aparelho. Ligue em Eu → Segurança.',
        _ => e.message ?? 'A digital não foi confirmada.',
      });
    }
  }

  /// Abre um link no navegador (APK da versão nova do app). Devolve false se não conseguir.
  static Future<bool> abrirLink(String url) async {
    if (semCanal) return false;
    try {
      return await _canal.invokeMethod<bool>('abrirLink', {'url': url}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Motivo da última vez que o app fechou por erro (guardado pelo Android; apaga depois de ler).
  static Future<String?> ultimoErro() async {
    if (semCanal) return null;
    try {
      return await _canal.invokeMethod<String>('ultimoErro');
    } catch (_) {
      return null;
    }
  }

  /// Tela pedida ao tocar num aviso da barra (ex.: "alertas"), uma vez só.
  static Future<String?> abrirPedido() async {
    if (semCanal) return null;
    try {
      return await _canal.invokeMethod<String>('abrirPedido');
    } catch (_) {
      return null;
    }
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
        'sem_permissao' => 'O app precisa da permissão de localização. Libere em Configurações › Apps › SIGAFAPE › Permissões.',
        'gps_desligado' => 'A localização do celular está desligada. Ligue o GPS e tente de novo.',
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

/// Erro da digital/rosto: [codigo] 'invalidada' ou 'sem_chave' pede para ligar de novo.
class ErroBiometria extends ErroLocal {
  const ErroBiometria(this.codigo, super.mensagem);
  final String codigo;
  bool get religar => codigo == 'invalidada' || codigo == 'sem_chave';
}

