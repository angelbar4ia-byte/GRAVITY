import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

void main() {
  test('la matriz cubre cada rol en cada módulo', () {
    for (final modulo in Modulo.values) {
      for (final rol in Rol.values) {
        expect(
          matrizPermisos[modulo]?[rol],
          isNotNull,
          reason: '$rol en $modulo',
        );
      }
    }
  });

  group('sección 5 de la especificación', () {
    test(
      'Dueño: total en finanzas, cuidados, alimentación, casa y ajustes',
      () {
        for (final modulo in [
          Modulo.finanzas,
          Modulo.cuidados,
          Modulo.alimentacion,
          Modulo.casa,
          Modulo.ajustes,
        ]) {
          for (final accion in Accion.values) {
            expect(puede(Rol.dueno, modulo, accion), isTrue, reason: '$modulo');
          }
        }
        expect(puede(Rol.dueno, Modulo.habitos, Accion.escribir), isTrue);
        expect(puede(Rol.dueno, Modulo.habitos, Accion.administrar), isFalse);
      },
    );

    test('D19: dueño y pareja llevan su propio libro de Finanzas', () {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        expect(permisoDe(rol, Modulo.finanzas).alcance, Alcance.propio);
        for (final accion in Accion.values) {
          expect(puede(rol, Modulo.finanzas, accion), isTrue, reason: '$rol');
        }
        expect(puedeAbrir(rol, Modulo.finanzas), isTrue);
      }
    });

    test('D18: GRAVITY es de cada quien, también para el dueño', () {
      expect(permisoDe(Rol.dueno, Modulo.gravity).alcance, Alcance.propio);
      expect(puede(Rol.dueno, Modulo.gravity, Accion.administrar), isTrue);
      for (final rol in [Rol.coadministrador, Rol.familiar, Rol.casa]) {
        expect(permisoDe(rol, Modulo.gravity).alcance, Alcance.propio);
      }
    });

    test('D18: la cuidadora solo usa su bandeja de solicitudes de GRAVITY', () {
      // Se resuelve por rol: cuidador × gravity × restringido (D17), no con
      // un alcance propio.
      final permiso = permisoDe(Rol.cuidador, Modulo.gravity);
      expect(permiso.alcance, Alcance.restringido);
      expect(permiso.alcance.enServidor, 'restringido');
      expect(soloBandejaDeSolicitudes(Rol.cuidador), isTrue);
      expect(puede(Rol.cuidador, Modulo.gravity, Accion.leer), isTrue);
      expect(puede(Rol.cuidador, Modulo.gravity, Accion.escribir), isTrue);
      expect(puede(Rol.cuidador, Modulo.gravity, Accion.administrar), isFalse);
      // No abre las pantallas de GRAVITY (ni conversa con él).
      expect(puedeAbrir(Rol.cuidador, Modulo.gravity), isFalse);
    });

    test('Coadministrador: lo demás como en la Fase 0', () {
      expect(
        puede(Rol.coadministrador, Modulo.alimentacion, Accion.administrar),
        isTrue,
      );
      expect(
        puede(Rol.coadministrador, Modulo.ajustes, Accion.administrar),
        isFalse,
      );
    });

    test('Familiar y Casa no ven dinero', () {
      for (final rol in [Rol.familiar, Rol.casa]) {
        for (final accion in Accion.values) {
          expect(puede(rol, Modulo.finanzas, accion), isFalse, reason: '$rol');
        }
        expect(puedeAbrir(rol, Modulo.finanzas), isFalse);
        expect(modulosNavegables(rol), isNot(contains(Modulo.finanzas)));
      }
    });

    test('Cuidador: en la navegación solo Cuidados', () {
      expect(modulosNavegables(Rol.cuidador), [Modulo.cuidados]);
      expect(puedeAbrir(Rol.cuidador, Modulo.gravity), isFalse);
      expect(puedeAbrir(Rol.cuidador, Modulo.habitos), isFalse);
      // Lo que registra (gastos de cuidado) y las comidas de papá se usan
      // desde Cuidados, no abriendo esos módulos.
      expect(puede(Rol.cuidador, Modulo.finanzas, Accion.escribir), isTrue);
      expect(puedeAbrir(Rol.cuidador, Modulo.finanzas), isFalse);
      expect(puede(Rol.cuidador, Modulo.alimentacion, Accion.leer), isTrue);
      expect(puedeAbrir(Rol.cuidador, Modulo.alimentacion), isFalse);
      expect(permisoDe(Rol.cuidador, Modulo.finanzas).desdeFase, 5);
    });

    test('Casa: recordatorios genéricos de cuidados y sin Ajustes', () {
      expect(permisoDe(Rol.casa, Modulo.cuidados).alcance, Alcance.restringido);
      expect(soloRecordatoriosGenericos(Rol.casa, Modulo.cuidados), isTrue);
      expect(puede(Rol.casa, Modulo.cuidados, Accion.escribir), isFalse);
      expect(puedeAbrir(Rol.casa, Modulo.ajustes), isFalse);
      // D23: Casa no ve Alimentación (la tablet pública no muestra el menú de Papá).
      expect(modulosNavegables(Rol.casa), [Modulo.cuidados, Modulo.casa]);
    });

    test('Familiar: hábitos propios, Alimentación (edita el menú de papá) y casa', () {
      expect(modulosNavegables(Rol.familiar), [
        Modulo.habitos,
        Modulo.alimentacion,
        Modulo.casa,
      ]);
      // D23 (ajuste 6/nov): el familiar edita el menú de Papá, no el de la pareja.
      expect(
        puede(Rol.familiar, Modulo.alimentacion, Accion.escribir),
        isTrue,
      );
    });
  });

  group('D17: solo los alcances del servidor; lo particular, por rol', () {
    test('cada celda con acciones usa total, propio o restringido', () {
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          final permiso = permisoDe(rol, modulo);
          if (permiso.acciones.isEmpty) {
            expect(permiso.alcance, Alcance.ninguno, reason: '$rol $modulo');
            expect(permiso.alcance.enServidor, isNull);
          } else {
            expect(
              permiso.alcance.enServidor,
              isIn(['total', 'propio', 'restringido']),
              reason: '$rol $modulo',
            );
          }
        }
      }
    });

    test('la bandeja de solicitudes es solo de la cuidadora', () {
      for (final rol in Rol.values) {
        expect(
          soloBandejaDeSolicitudes(rol),
          rol == Rol.cuidador,
          reason: '$rol',
        );
      }
    });

    test('Casa en Cuidados: solo recordatorios genéricos', () {
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          expect(
            soloRecordatoriosGenericos(rol, modulo),
            rol == Rol.casa && modulo == Modulo.cuidados,
            reason: '$rol $modulo',
          );
        }
      }
    });

    test('coadministrador en Cuidados: según consentimiento', () {
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          expect(
            dependeDelConsentimiento(rol, modulo),
            rol == Rol.coadministrador && modulo == Modulo.cuidados,
            reason: '$rol $modulo',
          );
        }
      }
    });

    test('el enum de alcances es exactamente el del servidor', () {
      expect(
        [for (final a in Alcance.values) a.enServidor],
        [null, 'total', 'propio', 'restringido'],
      );
    });

    test('lo restringido por rol: cada celda restringida dice sus acciones', () {
      // Una celda restringida nunca depende de las acciones por omisión (solo
      // leer): el subconjunto lo define el rol, y sus acciones van explícitas.
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          final permiso = permisoDe(rol, modulo);
          if (permiso.alcance != Alcance.restringido) continue;
          expect(permiso.acciones, isNotEmpty, reason: '$rol $modulo');
          expect(
            permiso.acciones,
            isNot(contains(Accion.administrar)),
            reason: '$rol $modulo',
          );
        }
      }
    });

    test('total solo para leer: Casa del familiar, del cuidador y de Casa', () {
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        final permiso = permisoDe(rol, Modulo.casa);
        expect(permiso.alcance, Alcance.total, reason: '$rol');
        expect(permiso.acciones, {Accion.leer}, reason: '$rol');
      }
    });
  });

  test('Desarrollador: solo el Dueño y solo en la laptop', () {
    for (final rol in Rol.values) {
      for (final dispositivo in TipoDispositivo.values) {
        expect(
          puedeVerDesarrollador(rol, dispositivo),
          rol == Rol.dueno && dispositivo == TipoDispositivo.laptop,
          reason: '$rol en $dispositivo',
        );
      }
    }
  });

  group('puedeSobre: lo suyo, lo ajeno y la cuenta maestra (D19)', () {
    test('con alcance propio, lo ajeno no se ve ni se toca', () {
      for (final accion in Accion.values) {
        expect(
          puedeSobre(Rol.dueno, Modulo.finanzas, accion, esDeLaPersona: true),
          isTrue,
        );
        expect(
          puedeSobre(Rol.dueno, Modulo.finanzas, accion, esDeLaPersona: false),
          isFalse,
          reason: '$accion',
        );
        expect(
          puedeSobre(Rol.dueno, Modulo.gravity, accion, esDeLaPersona: false),
          isFalse,
          reason: '$accion',
        );
      }
    });

    test('con alcance total, lo ajeno también', () {
      expect(
        puedeSobre(
          Rol.dueno,
          Modulo.cuidados,
          Accion.escribir,
          esDeLaPersona: false,
        ),
        isTrue,
      );
    });

    test('la cuenta maestra lee todo y nunca escribe en lo ajeno', () {
      for (final modulo in [Modulo.finanzas, Modulo.gravity, Modulo.cuidados]) {
        expect(
          puedeSobre(
            Rol.dueno,
            modulo,
            Accion.leer,
            esDeLaPersona: false,
            esMaestra: true,
          ),
          isTrue,
          reason: '$modulo',
        );
        for (final accion in [Accion.escribir, Accion.administrar]) {
          expect(
            puedeSobre(
              Rol.dueno,
              modulo,
              accion,
              esDeLaPersona: false,
              esMaestra: true,
            ),
            isFalse,
            reason: '$modulo $accion',
          );
        }
      }
      // Lo suyo, sí.
      expect(
        puedeSobre(
          Rol.dueno,
          Modulo.finanzas,
          Accion.escribir,
          esDeLaPersona: true,
          esMaestra: true,
        ),
        isTrue,
      );
    });
  });

  test('exigeAccion y accionExigida', () {
    expect(accionExigida(exigeAccion(Accion.escribir)), Accion.escribir);
    expect(accionExigida(const {}), isNull);
    expect(accionExigida(const {claveAccionDeRuta: 'escribir'}), isNull);
  });

  test('nombres en español', () {
    expect(nombreRol(Rol.dueno), 'Dueño');
    expect(nombreModulo(Modulo.habitos), 'Hábitos');
    expect(nombreModulo(Modulo.alimentacion), 'Alimentación');
  });
}
