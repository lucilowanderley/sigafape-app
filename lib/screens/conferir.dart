import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../util/nativo.dart';
import '../widgets/comum.dart';

/// Código de 32 letras/números do QR da via assinada (URL .../api/conferir/{código} ou o código digitado).
String? codigoDoQr(String? texto) {
  if (texto == null) return null;
  final t = texto.trim();
  final m = RegExp(r'/api/conferir/([A-Za-z0-9]{32})').firstMatch(t);
  if (m != null) return m.group(1);
  return RegExp(r'^[A-Za-z0-9]{32}$').hasMatch(t) ? t : null;
}

/// Conferir assinatura (opção A, ícone de QR no topo do Início): lê o QR do documento pela câmera e mostra
/// se a assinatura é válida, quem assinou e quando. Usa o servidor em uso no app (Wi-Fi ou 4G).
class TelaConferir extends StatefulWidget {
  const TelaConferir({super.key, this.lerAoAbrir = true});
  final bool lerAoAbrir;

  @override
  State<TelaConferir> createState() => _TelaConferirState();
}

class _TelaConferirState extends State<TelaConferir> {
  final _codigo = TextEditingController();
  Map<String, dynamic>? _r;
  String? _erro;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    if (widget.lerAoAbrir) WidgetsBinding.instance.addPostFrameCallback((_) => _ler());
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _ler() async {
    try {
      final texto = await Nativo.lerQr();
      if (texto == null) return;
      final cod = codigoDoQr(texto);
      if (cod == null) {
        setState(() {
          _r = null;
          _erro = 'Este QR não é de um documento assinado no SIGAFAPE.';
        });
        return;
      }
      await _conferir(cod, texto);
    } on ErroLocal catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  Future<void> _conferir(String codigo, [String? urlDoQr]) async {
    final api = apiDe(context);
    setState(() {
      _carregando = true;
      _erro = null;
      _r = null;
    });
    Map<String, dynamic>? r;
    String? erro;
    // Primeiro pelo servidor em uso; se não responder, pelo endereço que está no QR
    for (final url in ['${api.servidor}/api/conferir/$codigo?formato=json', if (urlDoQr != null && urlDoQr.startsWith('http')) '${urlDoQr.split('?').first}?formato=json']) {
      try {
        r = await api.getUrl(url);
        break;
      } on ApiErro catch (e) {
        if (e.status == 404) {
          r = {'status': 'nao_encontrada', 'label': 'Assinatura não encontrada', 'detalhe': 'Este código não corresponde a nenhum documento assinado no SIGAFAPE.'};
          break;
        }
        erro = e.mensagem;
      }
    }
    if (!mounted) return;
    setState(() {
      _carregando = false;
      _r = r;
      _erro = r == null ? erro : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    final r = _r;
    final (cor, icone) = switch (r?['status']) {
      'valida' => (const Color(0xFF1D8A45), Icons.verified),
      'alterada' => (const Color(0xFFE06A17), Icons.warning_amber_rounded),
      _ => (const Color(0xFFC0392B), Icons.gpp_bad_outlined),
    };
    Widget linha(String rotulo, String? valor) => valor == null || valor.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(rotulo, style: TextStyle(color: c.suave, fontWeight: FontWeight.w700))),
              Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          );
    final assinante = r?['assinante'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: const Topo(titulo: Text('Conferir assinatura')),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        if (_carregando) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        if (_erro != null) Cartao(margem: const EdgeInsets.fromLTRB(12, 12, 12, 8), bordaEsquerda: const Color(0xFFC0392B), child: Text(_erro!)),
        if (r != null) ...[
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(icone, color: Colors.white, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['label']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  if (r['detalhe'] != null) Text(r['detalhe'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                ]),
              ),
            ]),
          ),
          if (r['status'] != 'nao_encontrada')
            Cartao(
              child: Column(children: [
                linha('Assinante', assinante?['nome']?.toString()),
                linha('Matrícula', assinante?['matricula']?.toString()),
                linha('Assinado em', r['assinado_em'] == null ? null : dataHora(r['assinado_em'].toString().replaceFirst(' ', 'T'))),
                linha('Documento', r['documento']?.toString()),
                linha('Via', r['tipo_via']?.toString()),
                linha('Protocolo', r['protocolo']?.toString()),
                linha('Código', r['codigo_assinatura']?.toString()),
                if (r['cancelada'] == true) linha('Atenção', 'a notificação foi cancelada'),
              ]),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: FilledButton.icon(onPressed: _carregando ? null : _ler, icon: const Icon(Icons.qr_code_scanner), label: Text(r == null ? 'LER QR DO DOCUMENTO' : 'LER OUTRO QR')),
        ),
        const TituloSecao('Ou digite o código'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: TextField(controller: _codigo, decoration: const InputDecoration(labelText: 'Código ou endereço do QR', isDense: true))),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _carregando
                  ? null
                  : () {
                      final cod = codigoDoQr(_codigo.text);
                      if (cod == null) {
                        setState(() => _erro = 'O código tem 32 letras e números (ou cole o endereço inteiro do QR).');
                      } else {
                        FocusScope.of(context).unfocus();
                        _conferir(cod, _codigo.text.trim());
                      }
                    },
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('CONFERIR'),
            ),
          ]),
        ),
      ]),
    );
  }
}
