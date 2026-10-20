import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/pantalla/resumen_gravity.dart';
import 'package:gravity/modulos/gravity/pantalla/saludo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

DateTime _a(int h, int m) => DateTime(2026, 10, 20, h, m);

void main() {
  group('saludoSegunHora', () {
    test('límites de mañana, tarde y noche', () {
      expect(saludoSegunHora(_a(4, 59)), 'Buenas noches');
      expect(saludoSegunHora(_a(5, 0)), 'Buenos días');
      expect(saludoSegunHora(_a(11, 59)), 'Buenos días');
      expect(saludoSegunHora(_a(12, 0)), 'Buenas tardes');
      expect(saludoSegunHora(_a(18, 59)), 'Buenas tardes');
      expect(saludoSegunHora(_a(19, 0)), 'Buenas noches');
    });
  });

  group('mensajeDelNucleo', () {
    test('como en el boceto', () {
      expect(
        mensajeDelNucleo(_a(19, 42), ResumenGravity.ejemplo),
        'Buenas noches. Te faltan 2 hábitos de hoy y a las 20:00 hay un '
        'medicamento en el turno.',
      );
    });

    test('con modo privado no menciona cuidados', () {
      expect(
        mensajeDelNucleo(_a(19, 42), ResumenGravity.ejemplo, privado: true),
        'Buenas noches. Te faltan 2 hábitos de hoy.',
      );
    });

    test('singular, al día y sin datos', () {
      const uno = ResumenGravity(
        habitos: [HabitoDeHoy('A', hecho: true), HabitoDeHoy('B')],
      );
      expect(
        mensajeDelNucleo(_a(9, 0), uno),
        'Buenos días. Te falta 1 hábito de hoy.',
      );
      const listo = ResumenGravity(habitos: [HabitoDeHoy('A', hecho: true)]);
      expect(
        mensajeDelNucleo(_a(13, 0), listo),
        'Buenas tardes. Vas al día con tus hábitos.',
      );
      expect(
        mensajeDelNucleo(_a(13, 0), const ResumenGravity()),
        'Buenas tardes.',
      );
    });
  });

  test('cada módulo tiene nombre y ruta', () {
    expect(rutaModulo(Modulo.finanzas), Rutas.finanzas);
    expect(rutaModulo(Modulo.gravity), Rutas.inicio);
    for (final m in Modulo.values) {
      expect(nombreModulo(m), isNotEmpty);
      expect(rutaModulo(m), startsWith('/'));
    }
  });

  test('datos de ejemplo coherentes', () {
    final f = ResumenGravity.ejemplo.finanzas!;
    expect(f.quedanCentavos, 133000);
    expect(f.usado, closeTo(0.62, 0.001));
    expect(ResumenGravity.ejemplo.habitosHechos, 3);
    expect(ResumenGravity.ejemplo.habitosTotal, 5);
  });
}
