// UUID v5 (RFC 4122) y los ids estables de «Mi gimnasio»: la sesión de un día y
// una plantilla y cada serie dan SIEMPRE el mismo id (dos equipos convergen y
// el reintento no duplica).
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/gimnasio/ids_gimnasio.dart';
import 'package:gravity/nucleo/gimnasio/uuid_v5.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('uuidV5 contra vectores publicados', () {
    // Vectores de uuid5 de la RFC 4122 (sección 4.3 y apéndice C) tal como los
    // publican las implementaciones de referencia.
    test('DNS python.org', () {
      expect(
        uuidV5(EspacioUuid.dns, 'python.org'),
        '886313e1-3b8a-5372-9b90-0c9aee199e5d',
      );
    });

    test('DNS www.example.com', () {
      expect(
        uuidV5(EspacioUuid.dns, 'www.example.com'),
        '2ed6657d-e927-568b-95e1-2665a8aea6a2',
      );
    });

    test('URL http://www.example.com', () {
      expect(
        uuidV5(EspacioUuid.url, 'http://www.example.com'),
        '2d32a3f1-fac2-52a6-ac52-fe9e87e628ea',
      );
    });

    test('coincide con el paquete uuid que usa el resto de la app', () {
      for (final nombre in ['', 'a', 'sesion|p|2026-11-23|A', 'ñandú ✓']) {
        expect(
          uuidV5(EspacioUuid.url, nombre),
          const Uuid().v5(Namespace.url.value, nombre),
        );
      }
    });

    test('versión 5 y variante RFC 4122', () {
      final id = uuidV5(espacioIdsGimnasio, 'x');
      expect(esUuidDeVersion(id, 5), isTrue);
      expect(esUuidDeVersion(id, 4), isFalse);
    });

    test('caso malo: un espacio que no es UUID falla', () {
      expect(() => uuidV5('no-es-un-uuid', 'x'), throwsFormatException);
      expect(() => bytesDeUuid('1234'), throwsFormatException);
    });
  });

  group('IdsGimnasio', () {
    final lunes = DateTime(2026, 11, 23);

    test('la sesión: mismo día y plantilla, mismo id (da igual la hora)', () {
      final a = IdsGimnasio.sesion('persona-1', lunes, 'A');
      expect(
        IdsGimnasio.sesion('persona-1', DateTime(2026, 11, 23, 20, 15), 'A'),
        a,
      );
      expect(esUuidDeVersion(a, 5), isTrue);
    });

    test('otra persona, otro día u otra plantilla: otro id', () {
      final base = IdsGimnasio.sesion('persona-1', lunes, 'A');
      expect(IdsGimnasio.sesion('persona-2', lunes, 'A'), isNot(base));
      expect(
        IdsGimnasio.sesion('persona-1', DateTime(2026, 11, 24), 'A'),
        isNot(base),
      );
      expect(IdsGimnasio.sesion('persona-1', lunes, 'B'), isNot(base));
    });

    test(
      'la serie: la misma da el mismo id; el lado y el número la distinguen',
      () {
        final ses = IdsGimnasio.sesion('persona-1', lunes, 'C');
        final s = IdsGimnasio.serie(
          'persona-1',
          ses,
          'subida_banco',
          2,
          lado: 'izquierdo',
        );
        expect(
          IdsGimnasio.serie(
            'persona-1',
            ses,
            'subida_banco',
            2,
            lado: 'izquierdo',
          ),
          s,
        );
        expect(
          IdsGimnasio.serie(
            'persona-1',
            ses,
            'subida_banco',
            2,
            lado: 'derecho',
          ),
          isNot(s),
        );
        expect(
          IdsGimnasio.serie(
            'persona-1',
            ses,
            'subida_banco',
            3,
            lado: 'izquierdo',
          ),
          isNot(s),
        );
        expect(
          IdsGimnasio.serie('persona-1', ses, 'plancha', 2, lado: 'izquierdo'),
          isNot(s),
        );
        // Sin lado no es lo mismo que con lado.
        expect(
          IdsGimnasio.serie('persona-1', ses, 'subida_banco', 2),
          isNot(s),
        );
        expect(esUuidDeVersion(s, 5), isTrue);
      },
    );

    test('la banda es un UUID v4 distinto cada vez', () {
      final a = IdsGimnasio.banda();
      expect(esUuidDeVersion(a, 4), isTrue);
      expect(IdsGimnasio.banda(), isNot(a));
    });

    test('el espacio de nombres es de la versión 4 y no cambia', () {
      expect(espacioIdsGimnasio, '3c9d6f1e-7a2b-4d58-9e41-5b0c8a7d2f63');
      // Un id calculado hoy debe seguir siendo el mismo mañana.
      expect(
        IdsGimnasio.sesion('persona-1', lunes, 'A'),
        IdsGimnasio.sesion('persona-1', lunes, 'A'),
      );
    });
  });
}
