import 'dart:convert';

import 'api/api.dart';
import 'util/nativo.dart';

/// Contagens do sino e das assinaturas pendentes.
class Contagem {
  const Contagem({this.alertas = 0, this.avisos = 0, this.assinaturas = 0});
  final int alertas, avisos, assinaturas;

  /// Número no sino: notificações pendentes + avisos não lidos.
  int get sino => alertas + avisos;
}

/// Confere as novidades (GET /api/v1/novidades) e mostra na barra do celular as que ainda não foram avisadas.
/// A lista "vistos" é a mesma usada pela conferência em segundo plano do Android, então nada é avisado duas vezes.
Future<Contagem> conferirNovidades(Api api) async {
  Map<String, dynamic> r;
  try {
    r = await api.get('novidades');
  } on ApiErro catch (e) {
    if (e.status != 404) rethrow;
    // Servidor ainda sem /novidades: conta como antes, sem avisos na barra.
    final v = await Future.wait([api.get('alertas', {'por_pagina': 1}), api.get('avisos')]);
    return Contagem(alertas: ((v[0]['pendentes'] as num?) ?? 0).toInt(), avisos: ((v[1]['nao_lidos'] as num?) ?? 0).toInt());
  }
  final itens = ((r['itens'] as List?) ?? const []).cast<Map<String, dynamic>>();
  final guardado = await Nativo.ler('vistos');
  final vistos = <String>{};
  if (guardado != null) {
    try {
      vistos.addAll((jsonDecode(guardado) as List).map((e) => e.toString()));
    } catch (_) {}
  }
  for (final i in itens) {
    final chave = i['chave']?.toString() ?? '';
    // Primeira conferência depois de entrar: só marca como visto (o número no sino já mostra).
    if (chave.isEmpty || guardado == null || vistos.contains(chave)) continue;
    await Nativo.avisar(chave, i['titulo']?.toString() ?? 'SIGAFAPE', i['texto']?.toString() ?? '', i['prioridade']?.toString());
  }
  await Nativo.gravar('vistos', jsonEncode(itens.map((i) => i['chave']).whereType<String>().toList()));
  return Contagem(
    alertas: ((r['alertas_pendentes'] as num?) ?? 0).toInt(),
    avisos: ((r['avisos_nao_lidos'] as num?) ?? 0).toInt(),
    assinaturas: ((r['assinaturas_pendentes'] as num?) ?? 0).toInt(),
  );
}
