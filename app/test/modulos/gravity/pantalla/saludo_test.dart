import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/pantalla/resumen_gravity.dart';
import 'package:gravity/modulos/gravity/pantalla/saludo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

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

    test('no menciona cuidados a quien no los ve (D5)', () {
      for (final rol in [Rol.familiar, Rol.coadministrador]) {
        final mensaje = mensajeDelNucleo(
          _a(19, 42),
          ResumenGravity.ejemplo.paraRol(rol),
        );
        expect(mensaje, isNot(contains('medicamento')), reason: rol.name);
        expect(mensaje, isNot(contains('cuidados')), reason: rol.name);
      }
    });

    test('a Casa solo le da el recordatorio genérico, con mayúscula', () {
      expect(
        mensajeDelNucleo(_a(19, 42), ResumenGravity.ejemplo.paraRol(Rol.casa)),
        'Buenas noches. A las 20:00 hay un recordatorio de cuidados.',
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

  group('ResumenGravity.paraRol', () {
    const ejemplo = ResumenGravity.ejemplo;

    test('el Dueño lo ve todo', () {
      final r = ejemplo.paraRol(Rol.dueno);
      expect(r.finanzas, same(ejemplo.finanzas));
      expect(r.cuidados, same(ejemplo.cuidados));
      expect(r.habitos, ejemplo.habitos);
      expect(r.agenda, ejemplo.agenda);
      expect(r.siguiente, same(ejemplo.siguiente));
      expect(r.avisos, ejemplo.avisos);
    });

    test('sin rol, nada', () {
      final r = ejemplo.paraRol(null);
      expect(r.finanzas, isNull);
      expect(r.cuidados, isNull);
      expect(r.siguiente, isNull);
      expect(r.habitos, isEmpty);
      expect(r.agenda, isEmpty);
      expect(r.avisos, isEmpty);
    });

    test('Finanzas solo para quien abre Finanzas', () {
      for (final rol in Rol.values) {
        expect(
          ejemplo.paraRol(rol).finanzas != null,
          puedeAbrir(rol, Modulo.finanzas),
          reason: rol.name,
        );
      }
    });

    test('cada aviso se filtra con su módulo', () {
      for (final rol in Rol.values) {
        for (final aviso in ejemplo.paraRol(rol).avisos) {
          expect(
            vistaResumen(rol, aviso.modulo),
            VistaResumen.completa,
            reason: '${rol.name}: ${aviso.texto}',
          );
        }
      }
      final familiar = ejemplo.paraRol(Rol.familiar).avisos;
      expect(
        familiar.map((a) => a.texto),
        isNot(contains(contains('tarjeta'))),
      );
    });

    test('Cuidados: solo quien lo lee; Casa, solo lo genérico', () {
      expect(ejemplo.paraRol(Rol.familiar).cuidados, isNull);
      expect(ejemplo.paraRol(Rol.cuidador).cuidados, isNotNull);
      // La vista sale de las funciones por rol del espejo de permisos.
      expect(vistaResumen(Rol.casa, Modulo.cuidados), VistaResumen.generica);
      expect(
        vistaResumen(Rol.cuidador, Modulo.cuidados),
        VistaResumen.completa,
      );
      final casa = ejemplo.paraRol(Rol.casa).cuidados!;
      expect(casa.turno, 'Turno de cuidados · hasta 20:00');
      expect(casa.pendientes.map((p) => p.texto), [
        'Recordatorio de cuidados 20:00',
      ]);
      expect(casa.avisoNucleo, 'a las 20:00 hay un recordatorio de cuidados');
    });

    test('consentimiento (D2): nada hasta que se dé', () {
      // Sin consentimiento registrado, el coadministrador no ve Cuidados.
      expect(ejemplo.paraRol(Rol.coadministrador).cuidados, isNull);
      expect(
        vistaResumen(Rol.coadministrador, Modulo.cuidados),
        VistaResumen.nada,
      );
      // Con consentimiento, solo si además el espejo de permisos le abre
      // Cuidados (Fase 5).
      expect(
        ejemplo
                .paraRol(Rol.coadministrador, conConsentimientoCuidados: true)
                .cuidados !=
            null,
        puedeAbrir(Rol.coadministrador, Modulo.cuidados),
      );
    });

    test('Casa no ve hábitos ni agenda personal', () {
      final r = ejemplo.paraRol(Rol.casa);
      expect(r.habitos, isEmpty);
      expect(r.agenda, isEmpty);
      expect(r.siguiente, isNull);
    });
  });

  group('modulosDeLaBarra', () {
    test('navegables del rol más Ajustes si lo abre', () {
      for (final rol in Rol.values) {
        expect(modulosDeLaBarra(rol), [
          ...modulosNavegables(rol),
          if (puedeAbrir(rol, Modulo.ajustes)) Modulo.ajustes,
        ], reason: rol.name);
      }
      expect(modulosDeLaBarra(Rol.familiar), isNot(contains(Modulo.finanzas)));
      expect(modulosDeLaBarra(Rol.familiar), isNot(contains(Modulo.cuidados)));
      expect(modulosDeLaBarra(Rol.casa), isNot(contains(Modulo.ajustes)));
      expect(modulosDeLaBarra(null), isEmpty);
    });
  });
}
