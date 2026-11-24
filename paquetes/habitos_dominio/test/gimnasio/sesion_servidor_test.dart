import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

SesionRegistrada sesion({
  VentanaEntrenamiento? ventana,
  DateTime? inicio,
  DateTime? fin,
}) => SesionRegistrada(
  fecha: DateTime(2026, 12, 1),
  plantilla: 'A',
  version: VersionSesion.estandar,
  ventana: ventana,
  inicio: inicio,
  fin: fin,
);

void main() {
  group('fila de sesión para el servidor: ventana obligatoria', () {
    test('CASO MALO: ventana nula con inicio de mañana sale «manana»', () {
      final fila = sesion(inicio: DateTime(2026, 12, 1, 7, 30))
          .aJsonServidor(id: 'i');
      expect(fila['ventana'], 'manana');
    });

    test('CASO MALO: ventana nula con inicio de tarde sale «noche»', () {
      final fila = sesion(inicio: DateTime(2026, 12, 1, 19, 15))
          .aJsonServidor(id: 'i');
      expect(fila['ventana'], 'noche');
    });

    test(
      'CASO MALO: ventana flexible se deduce de la hora local de inicio',
      () {
        const f = VentanaEntrenamiento.flexible;
        expect(
          sesion(
            ventana: f,
            inicio: DateTime(2026, 12, 1, 11, 59),
          ).aJsonServidor(id: 'i')['ventana'],
          'manana',
        );
        expect(
          sesion(
            ventana: f,
            inicio: DateTime(2026, 12, 1, 12, 0),
          ).aJsonServidor(id: 'i')['ventana'],
          'noche',
        );
      },
    );

    test('CASO MALO: sin ventana ni inicio nunca sale nula: «noche»', () {
      for (final v in [null, VentanaEntrenamiento.flexible]) {
        final fila = sesion(ventana: v).aJsonServidor(id: 'i');
        expect(fila['ventana'], 'noche');
      }
    });

    test('una ventana de mañana o noche se respeta aunque la hora difiera', () {
      expect(
        sesion(
          ventana: VentanaEntrenamiento.manana,
          inicio: DateTime(2026, 12, 1, 20),
        ).aJsonServidor(id: 'i')['ventana'],
        'manana',
      );
      expect(
        sesion(
          ventana: VentanaEntrenamiento.noche,
          inicio: DateTime(2026, 12, 1, 7),
        ).aJsonServidor(id: 'i')['ventana'],
        'noche',
      );
    });

    test('en toda fila la ventana es manana o noche', () {
      for (final v in [null, ...VentanaEntrenamiento.values]) {
        for (final h in [null, 6, 12, 22]) {
          final fila = sesion(
            ventana: v,
            inicio: h == null ? null : DateTime(2026, 12, 1, h),
          ).aJsonServidor(id: 'i');
          expect(fila['ventana'], anyOf('manana', 'noche'));
        }
      }
    });
  });

  group('fila de sesión para el servidor: instantes en UTC', () {
    test('CASO MALO: un inicio local sale con zona (UTC), no sin zona', () {
      final local = DateTime(2026, 12, 1, 7, 30);
      final fin = DateTime(2026, 12, 1, 8, 30);
      final fila = sesion(inicio: local, fin: fin).aJsonServidor(id: 'i');
      expect(fila['inicio'], local.toUtc().toIso8601String());
      expect(fila['fin'], fin.toUtc().toIso8601String());
      expect(fila['inicio'] as String, endsWith('Z'));
      expect(fila['fin'] as String, endsWith('Z'));
    });

    test('un instante ya en UTC no cambia', () {
      final utc = DateTime.utc(2026, 12, 1, 13, 30);
      final fila = sesion(inicio: utc, fin: utc).aJsonServidor(id: 'i');
      expect(fila['inicio'], '2026-12-01T13:30:00.000Z');
      expect(fila['fin'], '2026-12-01T13:30:00.000Z');
    });

    test('inicio y fin ausentes siguen siendo nulos', () {
      final fila = sesion().aJsonServidor(id: 'i');
      expect(fila['inicio'], isNull);
      expect(fila['fin'], isNull);
    });

    test('inicio local y su equivalente UTC dan el mismo texto', () {
      final local = DateTime(2026, 12, 1, 7, 30);
      final a = sesion(inicio: local).aJsonServidor(id: 'i')['inicio'];
      final b = sesion(inicio: local.toUtc()).aJsonServidor(id: 'i')['inicio'];
      expect(a, b);
    });
  });
}
