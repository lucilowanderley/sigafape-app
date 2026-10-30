import 'package:flutter/material.dart';

import '../api/api.dart';
import '../tema.dart';
import '../util/formato.dart';
import '../widgets/comum.dart';

/// Campos da ficha agrupados como na tela "Minha ficha" da web (chaves = colunas do Efetivo).
const _grupos = <String, Map<String, String>>{
  'Funcional': {
    'name': 'Nome completo',
    'war_name': 'Nome de guerra',
    'rank': 'Posto/graduação',
    'code': 'Matrícula',
    'police_number': 'Número',
    'rg_pm': 'RG PM',
    'unit': 'Unidade',
    'post': 'Posto/setor',
    'position': 'Função',
    'situacao_texto': 'Situação',
    'duty_status_details': 'Detalhes da situação',
    'admission_date': 'Inclusão',
    'last_promotion_date': 'Última promoção',
    'behavior': 'Comportamento',
    'behavior_reference': 'Referência do comportamento',
  },
  'Contato': {'phone': 'Celular', 'phone_home': 'Telefone residencial', 'phone_message': 'Telefone para recado', 'email': 'E-mail'},
  'Endereço': {'address': 'Endereço', 'address_number': 'Número', 'district': 'Bairro', 'city': 'Cidade', 'zip': 'CEP', 'address_reference': 'Referência'},
  'Pessoal': {
    'birth_date': 'Nascimento',
    'birthplace': 'Naturalidade',
    'nationality': 'Nacionalidade',
    'sex': 'Sexo',
    'marital_status': 'Estado civil',
    'education': 'Escolaridade',
    'blood_type': 'Tipo sanguíneo',
    'height': 'Altura',
  },
  'Documentos': {
    'cpf': 'CPF',
    'rg_civil': 'RG civil',
    'voter_title': 'Título de eleitor',
    'voter_zone': 'Zona',
    'voter_section': 'Seção',
    'pasep': 'PASEP',
    'cnh': 'CNH',
    'cnh_category': 'Categoria da CNH',
    'cnh_issued_at': 'Emissão da CNH',
    'cnh_expires_at': 'Validade da CNH',
  },
  'Banco': {'bank_name': 'Banco', 'bank_branch': 'Agência', 'bank_account': 'Conta'},
  'Família': {'spouse_name': 'Cônjuge', 'children_names': 'Filhos', 'parents_names': 'Pais'},
  'Fardamento e armamento': {
    'uniform_sizes': 'Medidas do fardamento',
    'personal_weapon_registry': 'Registro da arma particular',
    'personal_weapon_model': 'Modelo da arma particular',
    'weapon_carry_permit': 'Porte',
  },
  'Assentamentos': {'certificates': 'Cursos', 'commendations': 'Elogios', 'medals': 'Medalhas', 'punishments': 'Punições', 'observations': 'Observações'},
  'Outra unidade': {'origin_unit': 'Unidade de origem', 'external_from': 'Vigência de', 'external_until': 'Vigência até', 'external_document': 'Documento'},
};

String? _valor(String chave, dynamic v) {
  if (v == null || (v is String && v.isEmpty)) return null;
  if (v is bool) return v ? 'Sim' : 'Não';
  if (v is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return dataCurta(v);
  return v.toString();
}

class TelaFicha extends StatelessWidget {
  const TelaFicha({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Topo(titulo: Text('Minha ficha')),
      body: Carregar<Map<String, dynamic>>(
        buscar: () => apiDe(context).get('ficha'),
        construir: (context, r) {
          final f = r['data'] as Map<String, dynamic>;
          final secoes = (r['secoes_atualizacao'] as Map?)?.cast<String, dynamic>() ?? {};
          final cnh = f['cnh_situacao'];
          return ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [
            if (cnh == 'vencida' || cnh == 'a_vencer')
              Cartao(
                bordaEsquerda: cnh == 'vencida' ? const Color(0xFFE53935) : const Color(0xFFB8860B),
                child: Text(cnh == 'vencida' ? 'Sua CNH está vencida (${dataCurta(f['cnh_expires_at'])}).' : 'Sua CNH vence em ${dataCurta(f['cnh_expires_at'])}.',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _TelaPedido(secoes: secoes))),
                icon: const Icon(Icons.edit_note),
                label: const Text('Pedir atualização ao RH'),
              ),
            ),
            for (final g in _grupos.entries)
              if (g.value.keys.any((k) => _valor(k, f[k]) != null)) ...[
                TituloSecao(g.key),
                Cartao(
                  child: Column(children: [
                    for (final campo in g.value.entries)
                      if (_valor(campo.key, f[campo.key]) != null) Info(campo.value, _valor(campo.key, f[campo.key])),
                  ]),
                ),
              ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Esta consulta fica registrada na auditoria do sistema.', textAlign: TextAlign.center, style: TextStyle(color: Cores.de(context).suave, fontSize: 12)),
            ),
          ]);
        },
      ),
    );
  }
}

/// Pedido de atualização da ficha: vira uma notificação para o RH na Central de Alertas.
class _TelaPedido extends StatefulWidget {
  const _TelaPedido({required this.secoes});
  final Map<String, dynamic> secoes;

  @override
  State<_TelaPedido> createState() => _TelaPedidoState();
}

class _TelaPedidoState extends State<_TelaPedido> {
  final _escolhidas = <String>{};
  final _detalhes = TextEditingController();
  bool _enviando = false;
  ApiErro? _erro;

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final r = await apiDe(context).post('ficha/atualizacao', {'secoes': _escolhidas.toList(), 'detalhes': _detalhes.text.trim()});
      if (!mounted) return;
      aviso(context, 'Pedido enviado ao RH (protocolo ${r['protocolo']}).');
      Navigator.pop(context);
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Cores.de(context);
    return Scaffold(
      appBar: const Topo(titulo: Text('Pedir atualização')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('O que mudou?', style: TextStyle(fontWeight: FontWeight.w800, color: c.texto, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final s in widget.secoes.entries)
            FilterChip(
              label: Text(s.value.toString()),
              selected: _escolhidas.contains(s.key),
              onSelected: (v) => setState(() => v ? _escolhidas.add(s.key) : _escolhidas.remove(s.key)),
            ),
        ]),
        if (_erro?.campo('secoes') != null) Text(_erro!.campo('secoes')!, style: const TextStyle(color: Color(0xFFB3261E))),
        const SizedBox(height: 16),
        TextField(
          controller: _detalhes,
          maxLines: 5,
          maxLength: 2000,
          decoration: InputDecoration(labelText: 'Detalhes (ex.: novo endereço, novo telefone)', errorText: _erro?.campo('detalhes'), alignLabelWithHint: true),
        ),
        Text('O RH recebe o pedido na Central de Alertas e avisa se precisar de algum documento.', style: TextStyle(color: c.suave, fontSize: 12.5)),
        if (_erro != null && _erro!.campo('secoes') == null && _erro!.campo('detalhes') == null)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text(_erro!.detalhe, style: const TextStyle(color: Color(0xFFB3261E)))),
        const SizedBox(height: 16),
        FilledButton(onPressed: _enviando || _escolhidas.isEmpty ? null : _enviar, child: const Text('ENVIAR AO RH')),
      ]),
    );
  }
}
