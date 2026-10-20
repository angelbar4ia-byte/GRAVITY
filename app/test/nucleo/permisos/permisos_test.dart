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
    test('Dueño: total en finanzas, cuidados, alimentación, casa y ajustes', () {
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
    });

    test('Coadministrador: finanzas solo de lectura', () {
      expect(puede(Rol.coadministrador, Modulo.finanzas, Accion.leer), isTrue);
      expect(
        puede(Rol.coadministrador, Modulo.finanzas, Accion.escribir),
        isFalse,
      );
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
      expect(permisoDe(Rol.casa, Modulo.cuidados).alcance, Alcance.generico);
      expect(puede(Rol.casa, Modulo.cuidados, Accion.escribir), isFalse);
      expect(puedeAbrir(Rol.casa, Modulo.ajustes), isFalse);
      expect(modulosNavegables(Rol.casa), [
        Modulo.cuidados,
        Modulo.alimentacion,
        Modulo.casa,
      ]);
    });

    test('Familiar: hábitos propios, su parte de alimentación y casa', () {
      expect(modulosNavegables(Rol.familiar), [
        Modulo.habitos,
        Modulo.alimentacion,
        Modulo.casa,
      ]);
      expect(puede(Rol.familiar, Modulo.alimentacion, Accion.escribir), isFalse);
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

  test('nombres en español', () {
    expect(nombreRol(Rol.dueno), 'Dueño');
    expect(nombreModulo(Modulo.habitos), 'Hábitos');
    expect(nombreModulo(Modulo.alimentacion), 'Alimentación');
  });
}
