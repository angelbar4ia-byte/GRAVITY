// Respuestas del dueño del 23/oct/2026 (D14, D18 y D19; especificación de la
// Fase 1, 9.0 bis): cuenta maestra con login propio (solo lectura total),
// libros compartidos públicos o privados con administrador, "salir del libro"
// y libro archivado, y cuentas de gasto e ingreso que se archivan sin saldo
// cero. Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'hogar_ejemplo.dart';

void main() {
  final hoy = Fecha(2026, 10, 23);
  const bea = 'persona-bea';
  const cris = 'persona-cris';

  Libro compartido({
    VisibilidadLibro visibilidad = VisibilidadLibro.privada,
    bool activo = true,
    String? creadoPor = ana,
    List<MiembroLibro>? miembros,
  }) => Libro(
    id: 'compartido',
    nombre: 'Viaje',
    tipo: TipoLibro.compartido,
    creadoPor: creadoPor,
    visibilidad: visibilidad,
    activo: activo,
    miembros:
        miembros ??
        [
          MiembroLibro(personaId: ana, papel: PapelLibro.miembro, desde: Fecha(2026, 1, 1)),
          MiembroLibro(personaId: alex, papel: PapelLibro.miembro, desde: Fecha(2026, 2, 1)),
          MiembroLibro(personaId: bea, papel: PapelLibro.miembro, desde: Fecha(2026, 3, 1)),
        ],
  );

  group('Cuenta maestra con login propio: solo lectura total', () {
    test('la maestra que no es la dueña no escribe ni administra, tampoco lo suyo', () {
      final propio = permisoEnLibro(
        librosEjemplo.firstWhere((l) => l.id == libroAna),
        ana,
        hoy: hoy,
        esMaestra: true,
        soloLectura: true,
      );
      expect(
        (propio.leer, propio.escribir, propio.administrar),
        (true, false, false),
      );
      expect(propio.comoMaestra, isFalse, reason: 'es su libro, no una consulta');
    });

    test('en lo ajeno lee como maestra (con consulta) y tampoco escribe', () {
      final ajeno = permisoEnLibro(
        librosEjemplo.firstWhere((l) => l.id == libroAlex),
        ana,
        hoy: hoy,
        esMaestra: true,
        soloLectura: true,
      );
      expect(
        (ajeno.leer, ajeno.escribir, ajeno.administrar, ajeno.comoMaestra),
        (true, false, false, true),
      );
    });

    test('si el dueño es también la maestra, escribe en lo suyo y solo lee lo ajeno', () {
      final suyo = permisoEnLibro(
        librosEjemplo.firstWhere((l) => l.id == libroAna),
        ana,
        hoy: hoy,
        esMaestra: true,
      );
      final ajeno = permisoEnLibro(
        librosEjemplo.firstWhere((l) => l.id == libroAlex),
        ana,
        hoy: hoy,
        esMaestra: true,
      );
      expect((suyo.escribir, suyo.administrar), (true, true));
      expect((ajeno.escribir, ajeno.comoMaestra), (false, true));
    });
  });

  group('Libros compartidos: privados o públicos', () {
    test('privado por omisión: un adulto del hogar que no es miembro no lo ve', () {
      final libro = compartido();
      expect(libro.visibilidad, VisibilidadLibro.privada);
      final p = permisoEnLibro(libro, cris, hoy: hoy);
      expect(p.leer, isFalse);
    });

    test('la cuenta maestra lee uno privado como maestra (con consulta)', () {
      final p = permisoEnLibro(compartido(), maestra, hoy: hoy, esMaestra: true);
      expect((p.leer, p.escribir, p.comoMaestra, p.comoLector), (true, false, true, false));
    });

    test('público: los adultos con Finanzas lo leen sin escribir', () {
      final libro = compartido(visibilidad: VisibilidadLibro.publica);
      final p = permisoEnLibro(libro, cris, hoy: hoy);
      expect(
        (p.leer, p.escribir, p.administrar, p.comoLector, p.comoMaestra),
        (true, false, false, true, false),
      );
      expect(librosVisibles([libro], cris, hoy: hoy), [libro]);
    });

    test('público: un rol sin Finanzas no lo lee', () {
      final libro = compartido(visibilidad: VisibilidadLibro.publica);
      expect(permisoEnLibro(libro, cris, hoy: hoy, rolConFinanzas: false).leer, isFalse);
    });

    test('público: los miembros siguen escribiendo; el lector va al final del selector', () {
      final libro = compartido(visibilidad: VisibilidadLibro.publica);
      final miembro = permisoEnLibro(libro, alex, hoy: hoy);
      expect((miembro.escribir, miembro.comoLector), (true, false));
      final personal = librosEjemplo.firstWhere((l) => l.id == libroAlex);
      expect(
        librosVisibles([libro, personal], alex, hoy: hoy).map((l) => l.id),
        [libroAlex, 'compartido'],
      );
    });

    test('el administrador es quien lo creó', () {
      final libro = compartido();
      expect(libro.esAdministrador(ana), isTrue);
      expect(libro.esAdministrador(alex), isFalse);
      expect(
        librosEjemplo.firstWhere((l) => l.id == libroAna).esAdministrador(ana),
        isFalse,
        reason: 'solo hay administrador en los compartidos',
      );
    });
  });

  group('Salir del libro y libro archivado', () {
    test('cualquier miembro vigente puede salirse; quien no lo es, no', () {
      final libro = compartido();
      expect(libro.puedeSalir(alex, hoy), isTrue);
      expect(libro.puedeSalir(cris, hoy), isFalse);
      expect(
        librosEjemplo.firstWhere((l) => l.id == libroAna).puedeSalir(ana, hoy),
        isFalse,
        reason: 'un libro personal no se deja',
      );
    });

    test('con 3 miembros, al salirse uno quedan 2 y el libro sigue activo', () {
      final libro = compartido();
      expect(libro.seArchivaAlSalir(hoy), isFalse);
      final despues = libro.alSalirse(bea, hoy);
      expect(despues.activo, isTrue);
      expect(despues.vigentes(hoy).map((m) => m.personaId), [ana, alex]);
      expect(permisoEnLibro(despues, bea, hoy: hoy).leer, isFalse);
      expect(permisoEnLibro(despues, alex, hoy: hoy).escribir, isTrue);
    });

    test('con 2 miembros, al salirse uno el libro se archiva (solo lectura)', () {
      final libro = compartido(
        miembros: [
          MiembroLibro(personaId: ana, papel: PapelLibro.miembro, desde: Fecha(2026, 1, 1)),
          MiembroLibro(personaId: alex, papel: PapelLibro.miembro, desde: Fecha(2026, 2, 1)),
        ],
      );
      expect(libro.seArchivaAlSalir(hoy), isTrue);
      final despues = libro.alSalirse(alex, hoy);
      expect(despues.archivado, isTrue);
      expect(despues.activo, isFalse);
      final quedo = permisoEnLibro(despues, ana, hoy: hoy);
      expect(
        (quedo.leer, quedo.escribir),
        (true, false),
        reason: 'el que se queda lo lee pero ya no registra',
      );
    });

    test('un libro archivado: la maestra lo lee, nadie escribe, solo el administrador reactiva', () {
      final libro = compartido(activo: false);
      final admin = permisoEnLibro(libro, ana, hoy: hoy);
      final otro = permisoEnLibro(libro, alex, hoy: hoy);
      expect((admin.leer, admin.escribir, admin.administrar), (true, false, true));
      expect((otro.leer, otro.escribir, otro.administrar), (true, false, false));
      final m = permisoEnLibro(libro, maestra, hoy: hoy, esMaestra: true);
      expect((m.leer, m.escribir, m.comoMaestra), (true, false, true));
      expect(() => libro.validar(hoy), returnsNormally, reason: 'archivado puede tener menos de 2');
    });

    test('si el administrador se sale, el cargo pasa al miembro vigente más antiguo', () {
      final libro = compartido();
      final despues = libro.alSalirse(ana, hoy);
      expect(despues.creadoPor, alex, reason: 'alex entró antes que bea');
      expect(despues.esAdministrador(alex), isTrue);
      expect(despues.esAdministrador(ana), isFalse);
    });

    test('quien se sale un día ya no es vigente ese mismo día (hasta exclusivo)', () {
      final despues = compartido().alSalirse(bea, hoy);
      final fila = despues.miembros.firstWhere((m) => m.personaId == bea);
      expect(fila.hasta, hoy);
      expect(fila.vigenteEn(hoy), isFalse);
      expect(fila.vigenteEn(hoy.sumarDias(-1)), isTrue);
    });

    test('un compartido activo sigue pidiendo 2 o más miembros', () {
      final solo = compartido(
        miembros: const [MiembroLibro(personaId: ana, papel: PapelLibro.miembro)],
      );
      expect(() => solo.validar(hoy), throwsA(isA<ErrorLibros>()));
    });
  });

  group('Cuentas de gasto e ingreso: se archivan sin saldo cero', () {
    LibroMovimientos libroConGasto() {
      final libro = LibroMovimientos(
        cuentas: const [
          Cuenta(id: 'banco', nombre: 'Banco', tipo: TipoCuenta.banco),
          Cuenta(id: 'sueldo', nombre: 'Sueldo', tipo: TipoCuenta.origenIngreso),
          Cuenta(id: 'ropa', nombre: 'Ropa', tipo: TipoCuenta.deGasto),
          Cuenta(id: 'apertura', nombre: 'Apertura', tipo: TipoCuenta.apertura),
        ],
      );
      final ahora = DateTime.utc(2026, 10, 20, 12);
      Movimiento m(String id, TipoMovimiento tipo, String o, String d, int monto) =>
          Movimiento(
            id: id,
            tipo: tipo,
            fecha: Fecha(2026, 10, 20),
            registradoEn: ahora,
            cuentaOrigenId: o,
            cuentaDestinoId: d,
            monto: monto,
            realizadoPor: ana,
          );
      libro
        ..agregar(m('a', TipoMovimiento.apertura, 'apertura', 'banco', 100000))
        ..agregar(m('i', TipoMovimiento.ingreso, 'sueldo', 'banco', 50000))
        ..agregar(m('g', TipoMovimiento.gasto, 'banco', 'ropa', 30000));
      return libro;
    }

    test('una cuenta de gasto con saldo se archiva y ya no admite gastos nuevos', () {
      final libro = libroConGasto();
      expect(libro.saldo('ropa'), isNot(0));
      libro.cambiarEstadoCuenta('ropa', EstadoCuenta.archivada);
      expect(libro.cuenta('ropa').estado, EstadoCuenta.archivada);
      final nuevo = Movimiento(
        id: 'n',
        tipo: TipoMovimiento.gasto,
        fecha: Fecha(2026, 10, 21),
        registradoEn: DateTime.utc(2026, 10, 21, 12),
        cuentaOrigenId: 'banco',
        cuentaDestinoId: 'ropa',
        monto: 100,
        realizadoPor: ana,
      );
      expect(() => libro.agregar(nuevo), throwsA(isA<ErrorLibro>()));
    });

    test('una cuenta de ingreso con saldo se cierra', () {
      final libro = libroConGasto();
      expect(libro.saldo('sueldo'), isNot(0));
      libro.cambiarEstadoCuenta('sueldo', EstadoCuenta.cerrada);
      expect(libro.cuenta('sueldo').estado, EstadoCuenta.cerrada);
    });

    test('una cuenta de activos o pasivos sigue pidiendo saldo cero', () {
      final libro = libroConGasto();
      expect(
        () => libro.cambiarEstadoCuenta('banco', EstadoCuenta.cerrada),
        throwsA(isA<ErrorLibro>()),
      );
      expect(
        () => libro.cambiarEstadoCuenta('banco', EstadoCuenta.archivada),
        throwsA(isA<ErrorLibro>()),
      );
    });

    test('la anulación de un gasto anterior sí entra aunque su cuenta esté archivada', () {
      final libro = libroConGasto()
        ..cambiarEstadoCuenta('ropa', EstadoCuenta.archivada);
      libro.anular(
        'g',
        nuevoId: 'anula-g',
        motivo: 'Se capturó dos veces',
        registradoPor: ana,
        registradoEn: DateTime.utc(2026, 10, 22, 12),
      );
      expect(libro.saldo('ropa'), 0);
    });
  });
}
