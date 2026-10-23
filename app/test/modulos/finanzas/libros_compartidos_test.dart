// Respuestas del dueño del 23/oct/2026 en la capa de casos de uso: libros
// compartidos públicos o privados con administrador, "salir del libro" y libro
// archivado; cuenta maestra de solo lectura total; cuentas de gasto e ingreso
// que se archivan con saldo; permiso del suplente de papá según el servidor.
// Datos de ejemplo inventados (hogar de Ana y Alex).
import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/datos/permisos_libro.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/sesion.dart' show Sesion;

import 'ayuda_finanzas.dart';

void main() {
  const libroDueno = IdsDemostracion.libroDueno;
  const libroPapa = IdsDemostracion.libroPapa;
  const casa = IdsDemostracion.libroCasa;
  final dueno = sesionDe(Rol.dueno);
  final pareja = sesionDe(Rol.coadministrador);
  final idDueno = IdsDemostracion.dueno;
  final idPareja = IdsDemostracion.pareja;
  const tercera = 'persona-tercera-ejemplo';

  /// Un hogar con un compartido de tres: el dueño lo creó, la pareja y una
  /// tercera persona son miembros.
  RepositorioFinanzasEnMemoria hogarDeTres(Sesion sesion) {
    final repo = repositorioDe(sesion);
    final datos = repo.datos;
    final nuevo = datos.libros
        .map(
          (l) => l.id == casa
              ? l.copiar(
                  miembros: [
                    ...l.miembros,
                    MiembroLibro(personaId: tercera, papel: PapelLibro.miembro),
                  ],
                )
              : l,
        )
        .toList();
    return RepositorioFinanzasEnMemoria(
      datos: datos.copiar(libros: nuevo),
      personaId: sesion.persona.id,
      personas: {...personasDeDemostracion(), tercera: 'Tercera (ejemplo)'},
      adultosConFinanzas: {idDueno, idPareja, tercera},
      reloj: () => ahoraDePrueba,
    );
  }

  group('Crear un libro compartido', () {
    test('es privado por omisión y quien lo crea es su administrador', () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final id = await servicioDe(repo, dueno).crearLibroCompartido('Vacaciones', [idPareja]);
      final libro = repo.datos.libro(id)!;
      expect(libro.visibilidad, VisibilidadLibro.privada);
      expect(libro.esAdministrador(idDueno), isTrue);
      expect(libro.esAdministrador(idPareja), isFalse);
      expect(libro.vigentes(hoyDePrueba).map((m) => m.personaId).toSet(), {idDueno, idPareja});
    });

    test('puede crearse pública', () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final id = await servicioDe(repo, dueno).crearLibroCompartido(
        'Gastos abiertos',
        [idPareja],
        visibilidad: VisibilidadLibro.publica,
      );
      expect(repo.datos.libro(id)!.visibilidad, VisibilidadLibro.publica);
    });

    test('un compartido de uno solo no se crea', () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      await expectLater(
        servicioDe(repo, dueno).crearLibroCompartido('Solo yo', const []),
        throwsA(isA<ErrorFinanzas>()),
      );
    });
  });

  group('Administrador del compartido', () {
    test('cambia la visibilidad; otro miembro no', () async {
      final repo = hogarDeTres(dueno);
      addTearDown(repo.cerrar);
      await servicioDe(repo, dueno).cambiarVisibilidadLibro(casa, VisibilidadLibro.publica);
      expect(repo.datos.libro(casa)!.visibilidad, VisibilidadLibro.publica);

      final repoPareja = hogarDeTres(pareja);
      addTearDown(repoPareja.cerrar);
      await expectLater(
        servicioDe(repoPareja, pareja).cambiarVisibilidadLibro(casa, VisibilidadLibro.privada),
        throwsA(isA<ErrorFinanzas>().having((e) => e.mensaje, 'mensaje', contains('Solo quien creó'))),
      );
    });

    test('agrega y saca miembros; no puede dejar menos de 2', () async {
      final repo = hogarDeTres(dueno);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      await servicio.quitarMiembroLibro(casa, tercera);
      expect(repo.datos.libro(casa)!.papelDe(tercera, hoyDePrueba), isNull);
      await expectLater(
        servicio.quitarMiembroLibro(casa, idPareja),
        throwsA(isA<ErrorFinanzas>().having((e) => e.mensaje, 'mensaje', contains('archívalo'))),
      );
      await servicio.agregarMiembroLibro(casa, tercera);
      expect(repo.datos.libro(casa)!.papelDe(tercera, hoyDePrueba), PapelLibro.miembro);
      await expectLater(
        servicio.agregarMiembroLibro(casa, tercera),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'ya es miembro',
      );
    });

    test('un miembro que no creó el libro no agrega ni saca a nadie', () async {
      final repo = hogarDeTres(pareja);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, pareja);
      await expectLater(servicio.agregarMiembroLibro(casa, 'otra'), throwsA(isA<ErrorFinanzas>()));
      await expectLater(servicio.quitarMiembroLibro(casa, tercera), throwsA(isA<ErrorFinanzas>()));
    });

    test('archiva y reactiva; archivado nadie registra', () async {
      final repo = hogarDeTres(dueno);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      final cuenta = repo.cuentaDe(casa, 'Banco de la casa');
      await servicio.archivarLibro(casa);
      expect(repo.datos.libro(casa)!.archivado, isTrue);
      await expectLater(
        servicio.registrarGasto(
          libroId: casa,
          cuentaOrigenId: cuenta.id,
          lineas: const [LineaGasto(monto: 1000)],
        ),
        throwsA(isA<ErrorFinanzas>().having((e) => e.mensaje, 'mensaje', contains('archivado'))),
      );
      // Lo leen sus miembros y solo su administrador lo reactiva.
      final comoPareja = servicioDe(repo, pareja).permiso(casa);
      expect((comoPareja.leer, comoPareja.escribir, comoPareja.administrar), (true, false, false));
      expect(servicio.permiso(casa).administrar, isTrue, reason: 'el administrador lo reactiva');
      await servicio.reactivarLibro(casa);
      expect(repo.datos.libro(casa)!.archivado, isFalse);
      await servicio.registrarGasto(
        libroId: casa,
        cuentaOrigenId: cuenta.id,
        lineas: const [LineaGasto(monto: 1000)],
      );
    });
  });

  group('Salir del libro', () {
    test('cualquier miembro se sale; con 3 miembros el libro sigue activo', () async {
      final repo = hogarDeTres(pareja);
      addTearDown(repo.cerrar);
      await servicioDe(repo, pareja).salirDelLibro(casa);
      final libro = repo.datos.libro(casa)!;
      expect(libro.papelDe(idPareja, hoyDePrueba), isNull);
      expect(libro.activo, isTrue);
      expect(libro.vigentes(hoyDePrueba), hasLength(2));
    });

    test('con 2 miembros, al salirse uno el libro se archiva', () async {
      final repo = repositorioDe(pareja);
      addTearDown(repo.cerrar);
      expect(repo.datos.libro(casa)!.vigentes(hoyDePrueba), hasLength(2));
      await servicioDe(repo, pareja).salirDelLibro(casa);
      final libro = repo.datos.libro(casa)!;
      expect(libro.archivado, isTrue);
      expect(libro.papelDe(idDueno, hoyDePrueba), PapelLibro.miembro,
          reason: 'el que se queda sigue leyéndolo');
    });

    test('si se sale el administrador, el cargo pasa al miembro más antiguo', () async {
      final repo = hogarDeTres(dueno);
      addTearDown(repo.cerrar);
      await servicioDe(repo, dueno).salirDelLibro(casa);
      final libro = repo.datos.libro(casa)!;
      expect(libro.esAdministrador(idDueno), isFalse);
      expect(libro.creadoPor, isNotNull);
      expect(libro.esAdministrador(libro.creadoPor!), isTrue);
    });

    test('quien no es miembro no se sale', () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      await expectLater(
        servicioDe(repo, dueno).salirDelLibro(libroPapa),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'el libro de papá no es un compartido',
      );
    });
  });

  group('Compartido público: lo leen los adultos del hogar, sin escribir', () {
    test('la pareja lo lee como lector aunque no sea miembro', () {
      final privado = Libro(
        id: 'otro',
        nombre: 'Del dueño',
        tipo: TipoLibro.compartido,
        creadoPor: idDueno,
        miembros: [
          MiembroLibro(personaId: idDueno, papel: PapelLibro.miembro),
          const MiembroLibro(personaId: tercera, papel: PapelLibro.miembro),
        ],
      );
      final publico = privado.copiar(visibilidad: VisibilidadLibro.publica);
      expect(permisoEnLibro(privado, idPareja, hoy: hoyDePrueba).leer, isFalse);
      final p = permisoEnLibro(publico, idPareja, hoy: hoyDePrueba);
      expect((p.leer, p.escribir, p.administrar, p.comoLector), (true, false, false, true));
    });
  });

  group('Cuenta maestra con login propio: solo lectura total', () {
    final maestra = sesionDe(Rol.coadministrador, maestra: true);

    test('no crea libros, categorías, días inhábiles ni cambia nada del hogar',
        () async {
      final repo = repositorioDe(maestra);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, maestra);
      await expectLater(
        servicio.crearLibroCompartido('Nuevo', [idDueno]),
        throwsA(isA<ErrorFinanzas>()),
      );
      await expectLater(servicio.crearCategoria(nombre: 'Algo'), throwsA(isA<ErrorFinanzas>()));
      await expectLater(servicio.precargarFestivos(2026), throwsA(isA<ErrorFinanzas>()));
      await expectLater(
        servicio.agregarDiaPropio(Fecha(2026, 12, 1), 'Día propio'),
        throwsA(isA<ErrorFinanzas>()),
      );
      final gasto = repo.datos.cuentas.firstWhere((c) => c.tipo == TipoCuenta.deGasto);
      await expectLater(
        servicio.cambiarEstadoCuenta(gasto.id, EstadoCuenta.archivada),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('tampoco registra en un libro propio', () async {
      final soloLectura = sesionParejaMaestra();
      final repo = repositorioDe(soloLectura);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, soloLectura);
      final banco = repo.datos.cuentasDe(IdsDemostracion.libroPareja).firstWhere(
        (c) => c.tipo == TipoCuenta.banco,
      );
      expect(servicio.permiso(IdsDemostracion.libroPareja).escribir, isFalse);
      await expectLater(
        servicio.registrarGasto(
          libroId: IdsDemostracion.libroPareja,
          cuentaOrigenId: banco.id,
          lineas: const [LineaGasto(monto: 100)],
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('si el dueño es también la maestra, escribe en lo suyo', () async {
      final duenoMaestro = sesionDuenoMaestro();
      final repo = repositorioDe(duenoMaestro);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, duenoMaestro);
      expect(servicio.permiso(libroDueno).escribir, isTrue);
      expect(servicio.permiso(IdsDemostracion.libroPareja).escribir, isFalse);
      expect(servicio.permiso(IdsDemostracion.libroPareja).comoMaestra, isTrue);
    });
  });

  group('Cuentas de gasto e ingreso: se archivan con saldo', () {
    test('una cuenta de ingreso con movimientos se archiva (activos no)',
        () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      final destino = repo.cuentaDe(libroDueno, 'Mi banco');
      await servicio.registrarIngresoExtra(
        libroId: libroDueno,
        monto: 250000,
        cuentaDestinoId: destino.id,
      );
      final origen = repo.datos
          .cuentasDe(libroDueno)
          .firstWhere((c) => c.nombre == 'Extras');
      final libro = repo.datos.nuevoLibroHogar();
      expect(libro.saldo(origen.id), isNot(0));
      await servicio.cambiarEstadoCuenta(origen.id, EstadoCuenta.archivada);
      expect(repo.datos.cuenta(origen.id)!.estado, EstadoCuenta.archivada);
      final banco = repo.datos
          .cuentasDe(libroDueno)
          .firstWhere((c) => c.tipo == TipoCuenta.banco && libro.saldo(c.id) != 0);
      await expectLater(
        servicio.cambiarEstadoCuenta(banco.id, EstadoCuenta.cerrada),
        throwsA(isA<ErrorFinanzas>().having((e) => e.mensaje, 'mensaje', contains('saldo cero'))),
      );
    });

    test('una cuenta de gasto del hogar con gasto se archiva (lo hace el dueño)',
        () async {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      final libro = repo.datos.nuevoLibroHogar();
      final gasto = repo.datos.cuentas.firstWhere(
        (c) => c.tipo == TipoCuenta.deGasto && libro.saldo(c.id) != 0,
      );
      await servicio.cambiarEstadoCuenta(gasto.id, EstadoCuenta.archivada);
      expect(repo.datos.cuenta(gasto.id)!.estado, EstadoCuenta.archivada);
    });
  });

  group('El suplente de papá escribe cuando el albacea ya no es adulto con '
      'Finanzas (el servidor lo dice)', () {
    test('con el albacea activo, el suplente solo lee', () async {
      final repo = repositorioDe(pareja, adultosActivosDelHogar: {idDueno, idPareja});
      addTearDown(repo.cerrar);
      final carga = repo.actual;
      expect(carga.permisosServidor[libroPapa]?.escribir, isFalse);
      final servicio = servicioDe(repo, pareja);
      expect(servicio.permiso(libroPapa).escribir, isFalse);
    });

    test('si el albacea se fue del hogar, el suplente escribe y administra',
        () async {
      final repo = repositorioDe(pareja, adultosActivosDelHogar: {idPareja});
      addTearDown(repo.cerrar);
      final carga = repo.actual;
      expect(carga.permisosServidor[libroPapa]?.escribir, isTrue);
      expect(carga.permisosServidor[libroPapa]?.administrar, isTrue);
      final libro = carga.datos.libro(libroPapa)!;
      final p = permisoDeCarga(carga, libro, idPareja, hoy: hoyDePrueba);
      expect((p.escribir, p.administrar, p.enNombreDe), (true, true, true));
      // Y puede registrar: en nombre de papá y con motivo.
      final servicio = servicioDe(repo, pareja);
      final banco = repo.datos.cuentasDe(libroPapa).firstWhere((c) => c.tipo == TipoCuenta.banco);
      final r = await servicio.registrarGasto(
        libroId: libroPapa,
        cuentaOrigenId: banco.id,
        lineas: const [LineaGasto(monto: 5000)],
        motivo: 'Farmacia',
      );
      expect(r.movimientos.single.enNombreDe, IdsDemostracion.papa);
      expect(r.movimientos.single.motivo, 'Farmacia');
    });

    test('el albacea activo escribe siempre, aunque nadie le pregunte al '
        'servidor', () {
      final repo = repositorioDe(dueno);
      addTearDown(repo.cerrar);
      final servicio = servicioDe(repo, dueno);
      expect(servicio.permiso(libroPapa).escribir, isTrue);
    });
  });
}
