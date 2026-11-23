import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas.dart';

EleccionVersion elegir(
  String p,
  int hueco, {
  PerfilGimnasio perfil = const PerfilGimnasio(),
}) => elegirVersion(
  catalogo: cat,
  plantillaId: p,
  inventario: inventarioBase(),
  hoy: dia(2026, 12, 3),
  huecoMin: hueco,
  perfil: perfil,
);

void main() {
  group('CA-G-11 elegir versión (duración + 10 min de margen)', () {
    test('C con 75 min elige larga (63.1 + 10 = 73.1)', () {
      final e = elegir('C', 75);
      expect(e.version, VersionSesion.larga);
      expect(minutosConDecimal(e.duracionSeg), '63.1');
    });

    test('C con 70 min elige estándar (45.8 + 10 = 55.8)', () {
      final e = elegir('C', 70);
      expect(e.version, VersionSesion.estandar);
      expect(minutosConDecimal(e.duracionSeg), '45.8');
    });

    test('A con 40 min elige corta (29.3 + 10 = 39.3)', () {
      final e = elegir('A', 40);
      expect(e.version, VersionSesion.corta);
      expect(minutosConDecimal(e.duracionSeg), '29.3');
    });

    test(
      'CASO MALO: A con 38 min no cabe ninguna y propone mover el bloque o la '
      'regenerativa (no hay cuarta versión)',
      () {
        final e = elegir('A', 38);
        expect(e.version, isNull);
        expect(e.cabe, isFalse);
        expect(e.acciones, [
          AccionSinHueco.moverBloque,
          AccionSinHueco.regenerativa,
        ]);
        expect(e.duraciones.keys, unorderedEquals(VersionSesion.values));
      },
    );

    test('el límite exacto: 73 min no alcanza la larga de C, 74 sí', () {
      expect(elegir('C', 73).version, VersionSesion.estandar);
      expect(elegir('C', 74).version, VersionSesion.larga);
    });

    test('con versión preferida solo se prueba esa', () {
      final e = elegir(
        'C',
        200,
        perfil: const PerfilGimnasio(versionPreferida: VersionSesion.corta),
      );
      expect(e.version, VersionSesion.corta);
      final no = elegir(
        'C',
        40,
        perfil: const PerfilGimnasio(versionPreferida: VersionSesion.larga),
      );
      expect(no.version, isNull);
    });
  });
}
