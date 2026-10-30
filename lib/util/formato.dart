import 'package:intl/intl.dart';

/// Datas da API: ISO 8601 com fuso ("2026-10-30T14:00:00-03:00") ou só a data ("2026-10-30").
DateTime? lerData(dynamic v) {
  if (v == null || v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toLocal();
}

String dataCurta(dynamic v) {
  final d = lerData(v);
  return d == null ? '—' : DateFormat('dd/MM/yyyy').format(d);
}

String diaMes(dynamic v) {
  final d = lerData(v);
  return d == null ? '—' : DateFormat('dd/MM').format(d);
}

String hora(dynamic v) {
  final d = lerData(v);
  return d == null ? '—' : DateFormat('HH:mm').format(d);
}

String dataHora(dynamic v) {
  final d = lerData(v);
  return d == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(d);
}

/// "Hoje 19:00", "Amanhã 18:00" ou "sex 31/10 07:00".
String quandoCurto(dynamic v) {
  final d = lerData(v);
  if (d == null) return '—';
  final hoje = DateTime.now();
  final dia = DateTime(d.year, d.month, d.day);
  final diff = dia.difference(DateTime(hoje.year, hoje.month, hoje.day)).inDays;
  final h = DateFormat('HH:mm').format(d);
  if (diff == 0) return 'Hoje $h';
  if (diff == 1) return 'Amanhã $h';
  if (diff == -1) return 'Ontem $h';
  return '${DateFormat('EEE dd/MM', 'pt_BR').format(d)} $h';
}

String saudacao() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bom dia,';
  if (h < 18) return 'Boa tarde,';
  return 'Boa noite,';
}

String tamanhoArquivo(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
