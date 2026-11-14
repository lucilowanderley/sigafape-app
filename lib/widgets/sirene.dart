import 'package:flutter/material.dart';

/// Ícone de sirene (botão de apoio urgente). O Material Icons não tem sirene, então é desenhado aqui:
/// cúpula, base e raios de luz, numa cor só (opção A escolhida em 2026-11-13).
class IconeSirene extends StatelessWidget {
  const IconeSirene({super.key, this.tamanho = 24, this.cor = Colors.white});
  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: tamanho,
        height: tamanho,
        child: CustomPaint(painter: _Sirene(cor)),
      );
}

class _Sirene extends CustomPainter {
  _Sirene(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    // Desenho em grade de 24 x 24, escalado para o tamanho pedido
    final s = size.width / 24;
    canvas.scale(s);
    final cheio = Paint()..color = cor;
    final traco = Paint()
      ..color = cor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Cúpula: retângulo com topo em meia-lua (de y = 8 a 18)
    final cupula = Path()
      ..moveTo(7, 18)
      ..lineTo(7, 13)
      ..arcToPoint(const Offset(17, 13), radius: const Radius.circular(5))
      ..lineTo(17, 18)
      ..close();
    canvas.drawPath(cupula, cheio);
    // Base
    canvas.drawRRect(RRect.fromLTRBR(5, 18.5, 19, 21, const Radius.circular(1)), cheio);
    // Raios de luz
    canvas.drawLine(const Offset(12, 2), const Offset(12, 5), traco);
    canvas.drawLine(const Offset(4.2, 5.2), const Offset(6.2, 7.2), traco);
    canvas.drawLine(const Offset(19.8, 5.2), const Offset(17.8, 7.2), traco);
    canvas.drawLine(const Offset(1.5, 12), const Offset(4.5, 12), traco);
    canvas.drawLine(const Offset(19.5, 12), const Offset(22.5, 12), traco);
  }

  @override
  bool shouldRepaint(_Sirene old) => old.cor != cor;
}
