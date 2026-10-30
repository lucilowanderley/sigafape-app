import 'package:flutter/material.dart';

/// As 3 cores do app (opção A): o policial escolhe em Eu → Aparência.
enum Tema {
  azul('Azul e dourado'),
  escuro('Escuro tático'),
  cinza('Cinza e marrom claro');

  const Tema(this.nome);
  final String nome;

  static Tema porNome(String? n) => Tema.values.firstWhere((t) => t.name == n, orElse: () => Tema.azul);
}

/// Cores próprias do SIGAFAPE, além das do Material.
@immutable
class Cores extends ThemeExtension<Cores> {
  const Cores({
    required this.fundo,
    required this.cartao,
    required this.texto,
    required this.suave,
    required this.linha,
    required this.destaque,
    required this.sobreDestaque,
    required this.dourado,
    required this.topo,
    required this.heroi,
    required this.entrada,
    required this.escuro,
  });

  final Color fundo, cartao, texto, suave, linha, destaque, sobreDestaque, dourado, entrada;
  final List<Color> topo, heroi;
  final bool escuro;

  static Cores de(BuildContext context) => Theme.of(context).extension<Cores>()!;

  static Cores para(Tema t) => switch (t) {
        Tema.azul => const Cores(
            fundo: Color(0xFFEEF1F5),
            cartao: Colors.white,
            texto: Color(0xFF16233A),
            suave: Color(0xFF5D6B82),
            linha: Color(0xFFD3DAE5),
            destaque: Color(0xFF0B2A55),
            sobreDestaque: Colors.white,
            dourado: Color(0xFFE2B33C),
            topo: [Color(0xFF071A36), Color(0xFF16335F)],
            heroi: [Color(0xFF0B2246), Color(0xFF16335F)],
            entrada: Color(0xFF0B2246),
            escuro: false,
          ),
        Tema.escuro => const Cores(
            fundo: Color(0xFF0E1116),
            cartao: Color(0xFF181D25),
            texto: Color(0xFFE8ECF2),
            suave: Color(0xFF8D97A8),
            linha: Color(0xFF2A313D),
            destaque: Color(0xFFD4A63A),
            sobreDestaque: Color(0xFF10141A),
            dourado: Color(0xFFD4A63A),
            topo: [Color(0xFF12161D), Color(0xFF12161D)],
            heroi: [Color(0xFF1C2A1F), Color(0xFF2A2A1C)],
            entrada: Color(0xFF141A14),
            escuro: true,
          ),
        Tema.cinza => const Cores(
            fundo: Color(0xFFF2F0ED),
            cartao: Colors.white,
            texto: Color(0xFF2B2A28),
            suave: Color(0xFF6F6A64),
            linha: Color(0xFFDCD6CF),
            destaque: Color(0xFF8A6A4B),
            sobreDestaque: Colors.white,
            dourado: Color(0xFFC9A27C),
            topo: [Color(0xFF3F4246), Color(0xFF5A5E63)],
            heroi: [Color(0xFF4A4D52), Color(0xFF6B6F75)],
            entrada: Color(0xFF4A4D52),
            escuro: false,
          ),
      };

  @override
  Cores copyWith() => this;

  @override
  Cores lerp(ThemeExtension<Cores>? other, double t) => t < .5 ? this : (other as Cores? ?? this);
}

ThemeData temaMaterial(Tema t) {
  final c = Cores.para(t);
  final esquema = ColorScheme.fromSeed(
    seedColor: c.destaque,
    brightness: c.escuro ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: c.destaque,
    onPrimary: c.sobreDestaque,
    surface: c.cartao,
    onSurface: c.texto,
    outline: c.linha,
  );
  final borda = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.linha, width: 1.5));
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: esquema,
    scaffoldBackgroundColor: c.fundo,
    extensions: [c],
    dividerColor: c.linha,
    appBarTheme: AppBarTheme(
      backgroundColor: c.topo.first,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: c.cartao,
      elevation: c.escuro ? 0 : 1,
      shadowColor: Colors.black12,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.escuro ? const Color(0xFF12161D) : Colors.white,
      border: borda,
      enabledBorder: borda,
      focusedBorder: borda.copyWith(borderSide: BorderSide(color: c.destaque, width: 2)),
      labelStyle: TextStyle(color: c.suave),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.destaque,
        foregroundColor: c.sobreDestaque,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: .3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.texto,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: c.linha, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.escuro ? const Color(0xFF12161D) : Colors.white,
      indicatorColor: c.destaque.withValues(alpha: .15),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.destaque : c.suave)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.destaque : c.suave,
          )),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: c.dourado,
      labelStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(fontFamily: 'Roboto'),
    ),
  );
}

/// Cores de situação usadas pela API ("cor": blue, green, red, gold, gray...).
(Color fundo, Color texto) corSituacao(String? cor, bool escuro) {
  final pares = <String, (Color, Color)>{
    'blue': escuro ? (const Color(0xFF14263F), const Color(0xFF8FB7F0)) : (const Color(0xFFDDE8F7), const Color(0xFF163F7A)),
    'green': escuro ? (const Color(0xFF173823), const Color(0xFF7FDC9A)) : (const Color(0xFFDFF3E4), const Color(0xFF1D6B35)),
    'red': escuro ? (const Color(0xFF3F1717), const Color(0xFFFF9A9A)) : (const Color(0xFFFBDCDC), const Color(0xFFA01818)),
    'gold': escuro ? (const Color(0xFF3D2A0C), const Color(0xFFF0B75A)) : (const Color(0xFFFDE8D4), const Color(0xFF9A4A07)),
    'orange': escuro ? (const Color(0xFF3D2A0C), const Color(0xFFF0B75A)) : (const Color(0xFFFDE8D4), const Color(0xFF9A4A07)),
  };
  return pares[cor] ?? (escuro ? (const Color(0xFF262C36), const Color(0xFFB8C0CC)) : (const Color(0xFFE6E9EE), const Color(0xFF4A5568)));
}
