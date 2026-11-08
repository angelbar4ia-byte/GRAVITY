// Objetivos, inversiones, bienes y previsión (Fase 8, bloque 3): avance del
// objetivo, origen capturado o verificado, rendimiento sin cálculo, vigencia
// por fecha de captura y reglas por cuenta (D19). Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    show Fecha, Libro, OrigenDato, permisoEnLibro;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/patrimonio.dart';
import 'package:gravity/modulos/finanzas/pantallas/patrimonio/vista_patrimonio.dart'
    show apartadoSemanalDeBolsa;
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/permisos/permisos.dart' as permisos;
import 'package:finanzas_dominio/finanzas_dominio.dart' show AportacionAhorro;

import 'ayuda_finanzas.dart';

void main() {
  final hoy = Fecha(2026, 11, 9);
  const libro = 'libro-1';

  group('avance del objetivo', () {
    test('cuánto falta y en cuántas semanas (redondeo hacia arriba)', () {
      final a = avanceObjetivo(
        metaCentavos: 1000000,
        ahorrado: 250000,
        apartadoSemanal: 20000,
        fechaMeta: hoy.sumarDias(365),
        hoy: hoy,
      );
      expect(a.falta, 750000);
      expect(a.semanasParaAlcanzar, 38); // 37.5 -> 38
      expect(a.alcanzado, isFalse);
      expect(a.llegaATiempo, isTrue); // 52 semanas disponibles
    });

    test('semanas exactas no suman una de más', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 0,
        apartadoSemanal: 10000,
        fechaMeta: hoy.sumarDias(70),
        hoy: hoy,
      );
      expect(a.semanasParaAlcanzar, 10);
      expect(a.semanasHastaFecha, 10);
      expect(a.llegaATiempo, isTrue);
    });

    test('con el apartado actual no llega a la fecha', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 0,
        apartadoSemanal: 5000,
        fechaMeta: hoy.sumarDias(70),
        hoy: hoy,
      );
      expect(a.semanasParaAlcanzar, 20);
      expect(a.llegaATiempo, isFalse);
    });

    test('sin apartado no se inventa una estimación', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 1000,
        apartadoSemanal: 0,
        fechaMeta: hoy.sumarDias(70),
        hoy: hoy,
      );
      expect(a.semanasParaAlcanzar, isNull);
      expect(a.llegaATiempo, isNull);
    });

    test('meta alcanzada: falta 0 y 0 semanas', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 120000,
        apartadoSemanal: 0,
        fechaMeta: hoy.sumarDias(-5),
        hoy: hoy,
      );
      expect(a.falta, 0);
      expect(a.semanasParaAlcanzar, 0);
      expect(a.alcanzado, isTrue);
    });

    test('el apartado se lee de las aportaciones existentes, no se copia', () {
      AportacionAhorro ap(
        String id,
        String bolsa,
        int sug, {
        int aportado = 0,
      }) => AportacionAhorro(
        id: id,
        libroId: libro,
        semanaId: 's1',
        bolsaId: bolsa,
        sugerido: sug,
        aportado: aportado,
      );
      final aportaciones = [
        ap('a', 'viaje', 12000),
        ap('b', 'viaje-otro', 99999),
        ap('c', 'casa', 5000, aportado: 7000),
      ];
      expect(apartadoSemanalDeBolsa(aportaciones, 's1', 'viaje'), 12000);
      expect(apartadoSemanalDeBolsa(aportaciones, 's1', 'casa'), 7000);
      expect(apartadoSemanalDeBolsa(aportaciones, null, 'viaje'), 0);
      expect(apartadoSemanalDeBolsa(aportaciones, 's2', 'viaje'), 0);
    });
  });

  group('inversiones', () {
    test('capturada a mano es "Capturado"; leída del PDF, "Verificado"', () {
      final a = inversionCapturada(
        id: 'i1',
        libroId: libro,
        nombre: 'Fondo de ejemplo',
        saldoCentavos: 500000,
        fechaCaptura: hoy,
      );
      final b = inversionLeidaDeEstado(
        id: 'i2',
        libroId: libro,
        estado: EstadoInversionLeido(
          nombre: 'Pagaré de ejemplo',
          saldoCentavos: 800000,
          fecha: hoy,
        ),
      );
      expect(a.origen, OrigenDato.capturado);
      expect(a.etiquetaOrigen, 'Capturado');
      expect(a.esVerificada, isFalse);
      expect(b.origen, OrigenDato.verificado);
      expect(b.etiquetaOrigen, 'Verificado');
    });

    test('lo capturado a mano nunca queda verificado', () {
      final i = inversionCapturada(
        id: 'i1',
        libroId: libro,
        nombre: 'X',
        saldoCentavos: 1,
        fechaCaptura: hoy,
      );
      expect(i.esVerificada, isFalse);
    });

    test('el rendimiento se muestra tal como se capturó, sin cálculo', () {
      final i = inversionCapturada(
        id: 'i1',
        libroId: libro,
        nombre: 'X',
        saldoCentavos: 1000000,
        fechaCaptura: hoy,
        rendimientoPuntosBase: puntosBaseDeTexto('5.5'),
      );
      expect(i.rendimientoPuntosBase, 550);
      expect(i.rendimientoTexto, '5.50 %');
      // Otro saldo u otra fecha no cambian el rendimiento: no se deriva.
      final otra = Inversion(
        id: i.id,
        libroId: libro,
        nombre: i.nombre,
        saldoCentavos: 9999999,
        fechaCaptura: hoy.sumarDias(30),
        rendimientoPuntosBase: i.rendimientoPuntosBase,
      );
      expect(otra.rendimientoTexto, '5.50 %');
    });

    test('sin rendimiento capturado no se inventa uno', () {
      final i = inversionCapturada(
        id: 'i1',
        libroId: libro,
        nombre: 'X',
        saldoCentavos: 1000000,
        fechaCaptura: hoy,
      );
      expect(i.rendimientoPuntosBase, isNull);
      expect(i.rendimientoTexto, isNull);
    });

    test('puntos base de texto', () {
      expect(puntosBaseDeTexto('5'), 500);
      expect(puntosBaseDeTexto('5,25 %'), 525);
      expect(puntosBaseDeTexto('12.05'), 1205);
      expect(puntosBaseDeTexto('5.555'), isNull);
      expect(puntosBaseDeTexto('abc'), isNull);
      expect(textoPuntosBase(5), '0.05');
    });

    test('lector de PDF no disponible: interfaz sin efecto', () async {
      const lector = LectorEstadoInversionNoDisponible();
      expect(lector.disponible, isFalse);
      expect(await lector.leer(), isNull);
    });

    test('el repositorio guarda y lee por libro', () async {
      final r = RepositorioPatrimonioEnMemoria();
      await r.guardarInversion(
        inversionCapturada(
          id: 'i1',
          libroId: libro,
          nombre: 'X',
          saldoCentavos: 1,
          fechaCaptura: hoy,
        ),
      );
      expect(await r.inversiones(libro), hasLength(1));
      expect(await r.inversiones('otro'), isEmpty);
    });
  });

  group('bienes y previsión', () {
    test('sin fecha de captura no es vigente', () {
      const sin = Bien(
        id: 'b1',
        libroId: libro,
        tipo: TipoBien.auto,
        nombre: 'Auto de ejemplo',
        valorCentavos: 20000000,
      );
      final con = Bien(
        id: 'b2',
        libroId: libro,
        tipo: TipoBien.casa,
        nombre: 'Casa de ejemplo',
        valorCentavos: 100000000,
        fechaCaptura: hoy,
      );
      expect(sin.vigente, isFalse);
      expect(con.vigente, isTrue);
    });

    test('una previsión sin fecha de captura no es vigente', () {
      const sin = Prevision(
        id: 'p1',
        libroId: libro,
        tipo: TipoPrevision.seguro,
        nombre: 'Seguro de ejemplo',
        valorCentavos: 100,
      );
      final con = Prevision(
        id: 'p2',
        libroId: libro,
        tipo: TipoPrevision.pension,
        nombre: 'Pensión de ejemplo',
        valorCentavos: 100,
        fechaCaptura: hoy,
      );
      expect(sin.vigente, isFalse);
      expect(con.vigente, isTrue);
    });
  });

  group('reglas por cuenta (D19)', () {
    final libros = datosDeDemostracion(hoy: hoyDePrueba).libros;
    Libro de(String id) => libros.firstWhere((l) => l.id == id);

    PermisoPatrimonio de_(
      Rol rol,
      String personaId,
      String libroId, {
      bool maestra = false,
    }) {
      final p = permisoEnLibro(
        de(libroId),
        personaId,
        hoy: hoyDePrueba,
        esMaestra: maestra,
        rolConFinanzas: permisos.puede(rol, Modulo.finanzas, Accion.leer),
      );
      return permisoPatrimonio(p, rol);
    }

    final dueno = IdsDemostracion.dueno;
    final pareja = IdsDemostracion.pareja;

    test('la titular ve y edita lo suyo', () {
      final p = de_(Rol.dueno, dueno, IdsDemostracion.libroDueno);
      expect((p.ver, p.editar), (true, true));
      final q = de_(Rol.coadministrador, pareja, IdsDemostracion.libroPareja);
      expect((q.ver, q.editar), (true, true));
    });

    test('el dueño como albacea de Papá ve y edita lo de Papá', () {
      final p = de_(Rol.dueno, dueno, IdsDemostracion.libroPapa);
      expect((p.ver, p.editar), (true, true));
    });

    test('el suplente de Papá solo lee mientras hay albacea', () {
      final p = de_(Rol.coadministrador, pareja, IdsDemostracion.libroPapa);
      expect((p.ver, p.editar), (true, false));
    });

    test('la pareja ve lo de la casa', () {
      final p = de_(Rol.coadministrador, pareja, IdsDemostracion.libroCasa);
      expect(p.ver, isTrue);
    });

    test('nadie ve lo personal de otro, ni como cuenta maestra', () {
      expect(
        de_(Rol.coadministrador, pareja, IdsDemostracion.libroDueno).ver,
        isFalse,
      );
      expect(
        de_(
          Rol.coadministrador,
          IdsDemostracion.pareja,
          IdsDemostracion.libroDueno,
          maestra: true,
        ).ver,
        isFalse,
      );
    });

    test('Casa, familiar y cuidadora no ven nada', () {
      for (final rol in [Rol.casa, Rol.familiar, Rol.cuidador]) {
        for (final id in [
          IdsDemostracion.libroCasa,
          IdsDemostracion.libroDueno,
          IdsDemostracion.libroPapa,
        ]) {
          // Aun siendo miembro del libro, el rol no tiene Finanzas.
          final p = de_(rol, dueno, id);
          expect((p.ver, p.editar), (false, false), reason: '$rol $id');
        }
      }
    });

    test('solo lectura total no edita', () {
      final p = permisoEnLibro(
        de(IdsDemostracion.libroDueno),
        dueno,
        hoy: hoyDePrueba,
      );
      expect(
        permisoPatrimonio(p, Rol.dueno, soloLectura: true).editar,
        isFalse,
      );
    });
  });
}
