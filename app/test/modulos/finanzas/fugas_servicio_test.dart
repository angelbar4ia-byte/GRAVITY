// Fase 8, bloque 6 (F8-6.10): fugas silenciosas y deuda buena o mala, capa de
// datos y casos de uso. Repositorio en memoria que imita al servidor (solo
// agregar, idempotente por id) y repositorio de Supabase contra una fuente
// falsa. Datos de ejemplo inventados; fecha de hoy: martes 20/oct/2026.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_fase2.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_fugas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/filas.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_fugas.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_fugas_supabase.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import 'ayuda_finanzas.dart';

const _libro = IdsDemostracion.libroDueno;
const _papa = IdsDemostracion.libroPapa;

class _Mundo {
  _Mundo(this.repo, this.base, this.fugas, this.servicio, this.sesionRol);

  final RepositorioFinanzasEnMemoria repo;
  final ServicioFinanzas base;
  final RepositorioFugasEnMemoria fugas;
  final ServicioFugas servicio;
  final Rol sesionRol;

  DatosFinanzas get datos => repo.datos;

  String subcategoria(String nombre) =>
      datos.categorias.firstWhere((c) => c.nombre == nombre).id;

  String banco([String libro = _libro]) =>
      datos.cuentasDe(libro).firstWhere((c) => c.tipo == TipoCuenta.banco).id;
}

_Mundo _mundo({
  Rol rol = Rol.dueno,
  bool maestra = false,
  RepositorioFugasEnMemoria? fugas,
}) {
  final sesion = sesionDe(rol, maestra: maestra);
  final repo = repositorioDe(sesion);
  final base = servicioDe(repo, sesion);
  final f = fugas ?? RepositorioFugasEnMemoria(reloj: () => ahoraDePrueba);
  final servicio = ServicioFugas(
    finanzas: base,
    repositorio: f,
    rol: sesion.rol,
    reloj: () => ahoraDePrueba,
  );
  return _Mundo(repo, base, f, servicio, rol);
}

/// Diez gastos de $45 en «Salidas» repartidos en las 4 semanas terminadas
/// (21/sep a 18/oct): una hormiga (DF-1).
Future<List<String>> _hormigas(_Mundo m, {String libro = _libro}) async {
  final motivo = libro == _papa ? 'Compras de Papá' : null;
  final dias = [
    Fecha(2026, 9, 22),
    Fecha(2026, 9, 24),
    Fecha(2026, 9, 29),
    Fecha(2026, 9, 30),
    Fecha(2026, 10, 1),
    Fecha(2026, 10, 6),
    Fecha(2026, 10, 8),
    Fecha(2026, 10, 13),
    Fecha(2026, 10, 15),
    Fecha(2026, 10, 17),
  ];
  final ids = <String>[];
  for (final d in dias) {
    final r = await m.base.registrarGasto(
      libroId: libro,
      cuentaOrigenId: m.banco(libro),
      lineas: [LineaGasto(monto: 4500, categoriaId: m.subcategoria('Salidas'))],
      fecha: d,
      motivo: motivo,
    );
    ids.add(r.movimientos.single.id);
  }
  return ids;
}

/// Tres cobros mensuales de $89 con «cargo automático» (DF-8).
Future<void> _suscripcion(
  _Mundo m, {
  String comercio = 'Streamix',
  String libro = _libro,
}) async {
  for (final f in [Fecha(2026, 8, 5), Fecha(2026, 9, 5), Fecha(2026, 10, 5)]) {
    await m.base.registrarGasto(
      libroId: libro,
      cuentaOrigenId: m.banco(libro),
      lineas: [
        LineaGasto(
          monto: 8900,
          categoriaId: m.subcategoria('Streaming y suscripciones'),
        ),
      ],
      fecha: f,
      comercio: comercio,
      cobroAutomatico: true,
      motivo: libro == _papa ? 'Cobros de Papá' : null,
    );
  }
}

String _clave(_Mundo m, TipoFuga t) => m.servicio
    .analizar(_libro)
    .resultado
    .todas
    .firstWhere((f) => f.fuga == t)
    .clave;

void main() {
  group('Movimientos: comercio y cargo automático (4)', () {
    test('el gasto lleva el comercio limpio y la marca; el comercio vacío '
        'queda nulo', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final r = await m.base.registrarGasto(
        libroId: _libro,
        cuentaOrigenId: m.banco(),
        lineas: const [LineaGasto(monto: 8900)],
        comercio: '  Streamix   Plus ',
        cobroAutomatico: true,
      );
      final mov = r.movimientos.single;
      expect(mov.comercio, 'Streamix Plus');
      expect(mov.cobroAutomatico, isTrue);
      final sin = await m.base.registrarGasto(
        libroId: _libro,
        cuentaOrigenId: m.banco(),
        lineas: const [LineaGasto(monto: 100)],
        comercio: '   ',
      );
      expect(sin.movimientos.single.comercio, isNull);
      expect(sin.movimientos.single.cobroAutomatico, isFalse);
      expect(
        () => m.base.registrarGasto(
          libroId: _libro,
          cuentaOrigenId: m.banco(),
          lineas: const [LineaGasto(monto: 100)],
          comercio: 'x' * 81,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('la fila lleva comercio y cobro_automatico solo si se llenaron, y '
        'se lee de vuelta', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final con = (await m.base.registrarGasto(
        libroId: _libro,
        cuentaOrigenId: m.banco(),
        lineas: const [LineaGasto(monto: 8900)],
        comercio: 'Streamix',
        cobroAutomatico: true,
      )).movimientos.single;
      final sin = (await m.base.registrarGasto(
        libroId: _libro,
        cuentaOrigenId: m.banco(),
        lineas: const [LineaGasto(monto: 8900)],
      )).movimientos.single;
      final filaCon = filaMovimiento(con, hogarId: 'h');
      final filaSin = filaMovimiento(sin, hogarId: 'h');
      expect(filaCon['comercio'], 'Streamix');
      expect(filaCon['cobro_automatico'], isTrue);
      expect(filaSin.containsKey('comercio'), isFalse);
      expect(filaSin.containsKey('cobro_automatico'), isFalse);
      final leido = movimientoDeFila({...filaCon});
      expect(leido.comercio, 'Streamix');
      expect(leido.cobroAutomatico, isTrue);
      expect(movimientoDeFila({...filaSin}).comercio, isNull);
    });
  });

  group('Fugas: permisos por rol (D5, D19)', () {
    test('el dueño ve y responde; la pareja ve su libro; el familiar, el '
        'cuidador y Casa no ven nada', () async {
      final dueno = _mundo();
      addTearDown(dueno.repo.cerrar);
      expect(dueno.servicio.puedeVer(_libro), isTrue);
      expect(dueno.servicio.puedeResponder(_libro), isTrue);
      expect(dueno.servicio.puedeDeclarar(_libro), isTrue);

      final pareja = _mundo(rol: Rol.coadministrador);
      addTearDown(pareja.repo.cerrar);
      expect(pareja.servicio.puedeVer(IdsDemostracion.libroPareja), isTrue);
      // No ve el libro personal del dueño.
      expect(pareja.servicio.puedeVer(_libro), isFalse);

      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        final m = _mundo(rol: rol);
        addTearDown(m.repo.cerrar);
        for (final l in [_libro, IdsDemostracion.libroPareja, _papa]) {
          expect(m.servicio.puedeVer(l), isFalse, reason: '$rol $l');
          expect(m.servicio.puedeResponder(l), isFalse);
          expect(m.servicio.analizar(l).hayAlgo, isFalse);
          expect(m.servicio.calidadDeDeudas(l), isEmpty);
        }
        await expectLater(
          m.servicio.responder(
            libroId: _libro,
            clave: 'x',
            pregunta: PreguntaFuga.reconoce,
            respuesta: RespuestaPersona.si,
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
        expect(m.fugas.escrituras, 0);
      }
    });

    test('la tablet pública no ve nada aunque el rol sea el del dueño', () {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final publica = ServicioFugas(
        finanzas: m.base,
        repositorio: m.fugas,
        rol: Rol.dueno,
        esTabletPublica: true,
      );
      expect(publica.puedeVer(_libro), isFalse);
      expect(publica.analizar(_libro).hayAlgo, isFalse);
    });

    test(
      'la cuenta maestra solo lee: ve, no responde ni cambia nada',
      () async {
        final m = _mundo(rol: Rol.coadministrador, maestra: true);
        addTearDown(m.repo.cerrar);
        // Lee un libro ajeno (con consulta registrada) y no escribe.
        expect(m.servicio.puedeVer(_libro), isTrue);
        expect(m.servicio.puedeResponder(_libro), isFalse);
        expect(m.servicio.puedeDeclarar(_libro), isFalse);
        await expectLater(
          m.servicio.responder(
            libroId: _libro,
            clave: 'x',
            pregunta: PreguntaFuga.reconoce,
            respuesta: RespuestaPersona.si,
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
        expect(m.fugas.escrituras, 0);
      },
    );

    test('en el libro de Papá las decisiones llevan motivo; el albacea '
        'puede ver y responder', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      expect(m.servicio.puedeVer(_papa), isTrue);
      await _suscripcion(m, libro: _papa, comercio: 'Streamix');
      final clave = m.servicio
          .analizar(_papa)
          .resultado
          .todas
          .firstWhere((f) => f.fuga == TipoFuga.fantasma)
          .clave;
      // Cancelar sin motivo: rechazado, y no queda nada guardado.
      await expectLater(
        m.servicio.cancelar(libroId: _papa, clave: clave, fecha: hoyDePrueba),
        throwsA(isA<ErrorFinanzas>()),
      );
      expect(m.fugas.actuales.patrones, isEmpty);
      await m.servicio.cancelar(
        libroId: _papa,
        clave: clave,
        fecha: hoyDePrueba,
        folio: 'ABC-123',
        motivo: 'Lo pidió Papá por teléfono',
      );
      expect(m.fugas.actuales.patrones.single.folio, 'ABC-123');
    });
  });

  group('Fugas: cálculo local con lo cargado', () {
    test('una hormiga: el número de compras y el total salen del MISMO '
        'conjunto de gastos (H-04)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final ids = await _hormigas(m);
      final a = m.servicio.analizar(_libro);
      final hormigas = a.deTipo(TipoFuga.hormiga);
      expect(hormigas, hasLength(1));
      final h = hormigas.single;
      expect(h.gastoIds.toSet(), ids.toSet());
      expect(h.gastoIds, hasLength(10));
      expect(h.totalCentavos, 45000);
      expect(a.total(TipoFuga.hormiga).totalCentavos, 45000);
      expect(a.comprasDe(h), 10);
    });

    test('anular un gasto cambia las fugas de inmediato (DF-12)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final r = await _hormigas(m);
      for (final id in r.take(3)) {
        await m.base.anular(id, motivo: 'Lo registré dos veces');
      }
      expect(m.servicio.analizar(_libro).deTipo(TipoFuga.hormiga), isEmpty);
    });

    test('lo de otro libro no se mezcla', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _hormigas(m, libro: _papa);
      expect(m.servicio.analizar(_libro).deTipo(TipoFuga.hormiga), isEmpty);
      expect(m.servicio.analizar(_papa).deTipo(TipoFuga.hormiga), isNotEmpty);
    });

    test('un cobro automático nuevo nace «por reconocer»: no cuenta y no '
        'acusa; con «Después» cuatro veces sigue igual (DF-10)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _suscripcion(m);
      final a = m.servicio.analizar(_libro);
      expect(a.porReconocer, hasLength(1));
      expect(a.deTipo(TipoFuga.fantasma), isEmpty);
      expect(a.total(TipoFuga.fantasma).totalCentavos, 0);
      final clave = a.porReconocer.single.clave;
      for (var i = 0; i < 4; i++) {
        await m.servicio.responder(
          libroId: _libro,
          clave: clave,
          pregunta: PreguntaFuga.reconoce,
          respuesta: RespuestaPersona.despues,
        );
      }
      final b = m.servicio.analizar(_libro);
      expect(b.porReconocer, hasLength(1));
      expect(b.deTipo(TipoFuga.fantasma), isEmpty);
    });

    test('«No lo conocía» confirma el fantasma; «Sí, lo conozco» lo '
        'reconoce y entra a preguntar el uso', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _suscripcion(m);
      final clave = m.servicio.analizar(_libro).porReconocer.single.clave;
      await m.servicio.responder(
        libroId: _libro,
        clave: clave,
        pregunta: PreguntaFuga.reconoce,
        respuesta: RespuestaPersona.no,
      );
      var a = m.servicio.analizar(_libro);
      expect(a.deTipo(TipoFuga.fantasma), hasLength(1));
      expect(a.porReconocer, isEmpty);
      // Corregir la respuesta: queda una fila nueva que reemplaza a la
      // anterior (en el mismo periodo).
      await m.servicio.responder(
        libroId: _libro,
        clave: clave,
        pregunta: PreguntaFuga.reconoce,
        respuesta: RespuestaPersona.si,
      );
      a = m.servicio.analizar(_libro);
      expect(a.deTipo(TipoFuga.fantasma), isEmpty);
      expect(a.resultado.de(clave)!.preguntarUso, isTrue);
      // El patrón existe una sola vez con id estable.
      expect(m.fugas.actuales.patrones, hasLength(1));
      expect(
        m.fugas.actuales.patrones.single.id,
        ServicioFugas.idPatron(_libro, clave),
      );
    });

    test('«Ya no me sirve» deja un zombi (Z1) con la acción de la baja '
        'formal', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _suscripcion(m);
      final clave = m.servicio.analizar(_libro).porReconocer.single.clave;
      await m.servicio.responder(
        libroId: _libro,
        clave: clave,
        pregunta: PreguntaFuga.reconoce,
        respuesta: RespuestaPersona.si,
      );
      await m.servicio.responder(
        libroId: _libro,
        clave: clave,
        pregunta: PreguntaFuga.yaNoSirve,
        respuesta: RespuestaPersona.si,
      );
      final z = m.servicio.analizar(_libro).deTipo(TipoFuga.zombie);
      expect(z, hasLength(1));
      expect(z.single.regla, 'Z1');
    });

    test('la revisión mensual trae como máximo 7 preguntas', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      for (var i = 0; i < 9; i++) {
        await _suscripcion(m, comercio: 'Servicio $i');
      }
      final a = m.servicio.analizar(_libro);
      expect(a.porReconocer.length, greaterThan(7));
      expect(a.preguntas.length, 7);
    });
  });

  group('«No es así» y cancelar', () {
    test('contradecir a la regla exige motivo; con motivo la persona gana '
        'y el patrón queda protegido (DF-18)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _hormigas(m);
      final clave = _clave(m, TipoFuga.hormiga);
      await expectLater(
        m.servicio.clasificar(
          libroId: _libro,
          clave: clave,
          fuga: TipoFuga.ninguna,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      expect(m.fugas.actuales.clasificaciones, isEmpty);
      await m.servicio.clasificar(
        libroId: _libro,
        clave: clave,
        fuga: TipoFuga.ninguna,
        motivo: 'Lo uso para trabajar',
      );
      expect(m.servicio.analizar(_libro).deTipo(TipoFuga.hormiga), isEmpty);
      final p = m.fugas.actuales.patrones.single;
      expect(p.protegido, isTrue);
      final c = m.fugas.actuales.clasificaciones.single;
      expect(c.fugaRegla, TipoFuga.hormiga);
      expect(c.motivo, 'Lo uso para trabajar');
    });

    test('«Es de otro tipo» reemplaza la clasificación vigente sin borrar '
        'la anterior', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _hormigas(m);
      final clave = _clave(m, TipoFuga.hormiga);
      await m.servicio.clasificar(
        libroId: _libro,
        clave: clave,
        fuga: TipoFuga.ninguna,
        motivo: 'Lo uso para trabajar',
      );
      await m.servicio.clasificar(
        libroId: _libro,
        clave: clave,
        fuga: TipoFuga.zombie,
        motivo: 'Ya no lo necesito',
      );
      // Solo la última es vigente.
      expect(m.fugas.actuales.clasificaciones, hasLength(1));
      expect(m.fugas.actuales.clasificaciones.single.fuga, TipoFuga.zombie);
      expect(m.servicio.analizar(_libro).deTipo(TipoFuga.zombie), hasLength(1));
    });

    test('«Lo necesito pero quiero revisarlo» no pide motivo y deja el cobro '
        'en vigilancia', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _hormigas(m);
      final clave = _clave(m, TipoFuga.hormiga);
      await m.servicio.clasificar(
        libroId: _libro,
        clave: clave,
        fuga: TipoFuga.ninguna,
        vigilar: true,
      );
      final a = m.servicio.analizar(_libro);
      expect(a.deTipo(TipoFuga.hormiga), isEmpty);
      expect(a.resultado.de(clave)!.estado, EstadoFuga.enVigilancia);
      expect(m.fugas.actuales.patrones.single.vigilar, isTrue);
    });

    test('cancelar: folio válido, sin folio («cancelado sin folio») y folio '
        'o fecha inválidos se rechazan (DF-26)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _suscripcion(m);
      final clave = m.servicio.analizar(_libro).porReconocer.single.clave;
      for (final malo in ['ABC 123', 'x' * 41, 'A_1']) {
        await expectLater(
          m.servicio.cancelar(
            libroId: _libro,
            clave: clave,
            fecha: hoyDePrueba,
            folio: malo,
          ),
          throwsA(isA<ErrorFinanzas>()),
          reason: malo,
        );
      }
      await expectLater(
        m.servicio.cancelar(
          libroId: _libro,
          clave: clave,
          fecha: hoyDePrueba.sumarDias(3),
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      expect(m.fugas.actuales.patrones, isEmpty);
      // Sin folio: queda pendiente de completar.
      await m.servicio.cancelar(
        libroId: _libro,
        clave: clave,
        fecha: Fecha(2026, 10, 10),
      );
      expect(
        m.servicio.estadoDeCancelacion(_libro, clave),
        EstadoCancelacion.canceladoSinFolio,
      );
      final a = m.servicio.analizar(_libro);
      expect(
        a.resultado.de(clave)!.marcas,
        contains(MarcaFuga.canceladoSinFolio),
      );
      // Se completa con el folio: queda una respuesta nueva.
      await m.servicio.cancelar(
        libroId: _libro,
        clave: clave,
        fecha: Fecha(2026, 10, 10),
        folio: 'ABC-123',
      );
      expect(
        m.servicio.estadoDeCancelacion(_libro, clave),
        EstadoCancelacion.cancelado,
      );
      expect(
        m.servicio.analizar(_libro).resultado.de(clave)!.marcas,
        isNot(contains(MarcaFuga.canceladoSinFolio)),
      );
    });

    test('un cobro tras la cancelación vuelve como fantasma «cobrado tras '
        'cancelar» (DF-17)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _suscripcion(m);
      final clave = m.servicio.analizar(_libro).porReconocer.single.clave;
      await m.servicio.cancelar(
        libroId: _libro,
        clave: clave,
        fecha: Fecha(2026, 9, 10),
        folio: 'ABC-123',
      );
      final f = m.servicio.analizar(_libro).deTipo(TipoFuga.fantasma);
      expect(f, hasLength(1));
      expect(f.single.marcas, contains(MarcaFuga.cobradoTrasCancelar));
    });

    test('sin señal las escrituras avisan y no dejan nada a medias', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _suscripcion(m);
      final clave = m.servicio.analizar(_libro).porReconocer.single.clave;
      m.fugas.falla = ErrorFinanzas.conexion;
      await expectLater(
        m.servicio.responder(
          libroId: _libro,
          clave: clave,
          pregunta: PreguntaFuga.reconoce,
          respuesta: RespuestaPersona.no,
        ),
        throwsA(
          isA<ErrorFinanzas>().having(
            (e) => e.sinConexion,
            'sinConexion',
            true,
          ),
        ),
      );
      expect(m.fugas.actuales.respuestas, isEmpty);
      expect(m.servicio.analizar(_libro).deTipo(TipoFuga.fantasma), isEmpty);
    });
  });

  group('Avisos (D20): sin cifras ni comercios, claves estables', () {
    test('por reconocer y revisión mensual salen una sola vez', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _suscripcion(m, comercio: 'Streamix');
      final antes = m.repo.avisosEmitidos.length;
      final n = await m.servicio.emitirAvisos(_libro);
      expect(n, 2);
      final nuevos = m.repo.avisosEmitidos.skip(antes).toList();
      expect(nuevos.map((a) => a.tipo).toSet(), {
        TiposAvisoFugas.fugaPorReconocer,
        TiposAvisoFugas.fugaRevisionMensual,
      });
      final porReconocer = nuevos.firstWhere(
        (a) => a.tipo == TiposAvisoFugas.fugaPorReconocer,
      );
      expect(porReconocer.objetoTipo, 'patron');
      expect(
        porReconocer.objetoId,
        m.fugas.actuales.patrones.single.id,
        reason: 'el patrón se crea (idempotente) para colgarle el aviso',
      );
      for (final a in nuevos) {
        expect(a.clave, matches(RegExp(r'^[a-z0-9_:.-]+$')));
        expect(a.clave, isNot(contains('streamix')));
        expect(a.clave, isNot(contains(r'$')));
      }
      // Otra vez: nada nuevo (ni local ni en el servidor).
      expect(await m.servicio.emitirAvisos(_libro), 0);
      expect(m.repo.avisosEmitidos.length, antes + 2);
    });

    test('sin permiso de escribir no se emite nada', () async {
      final m = _mundo(rol: Rol.coadministrador, maestra: true);
      addTearDown(m.repo.cerrar);
      expect(await m.servicio.emitirAvisos(_libro), 0);
      expect(m.repo.avisosEmitidos, isEmpty);
    });

    test('sin señal no emite ni lanza', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      await _suscripcion(m);
      m.repo.simularSinConexion = true;
      expect(await m.servicio.emitirAvisos(_libro), 0);
    });
  });

  group('Deuda buena o mala', () {
    Future<Msi> msi(
      _Mundo m, {
      int total = 120000,
      int meses = 12,
      String comercio = 'Laptop',
    }) => ServicioDeudasAhorro(m.base).crearMsi(
      libroId: _libro,
      comercio: comercio,
      total: total,
      meses: meses,
      fechaCompra: Fecha(2026, 10, 19),
      diaPago: 28,
    );

    test(
      'sin propósito declarado: «Por declarar», no se juzga (DD-12)',
      () async {
        final m = _mundo();
        addTearDown(m.repo.cerrar);
        final compra = await msi(m);
        final lista = m.servicio.calidadDeDeudas(_libro);
        final d = lista.firstWhere((x) => x.deuda.id == compra.deudaId);

        expect(d.mostrado, EstadoCalidad.porDeclarar);
        expect(d.esMsi, isTrue);
      },
    );

    test('declarar el propósito (herramienta de trabajo) lo vuelve buena; '
        'el objetivo sin cifras y el precio de contado se validan', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final compra = await msi(m);
      await expectLater(
        m.servicio.declararProposito(
          libroId: _libro,
          deudaId: compra.deudaId,
          declaracion: const DeclaracionDeuda(
            proposito: PropositoDeuda.generaIngreso,
            objetivoTexto: 'Mi laptop de 2026',
          ),
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      await expectLater(
        m.servicio.declararProposito(
          libroId: _libro,
          deudaId: compra.deudaId,
          declaracion: const DeclaracionDeuda(
            proposito: PropositoDeuda.generaIngreso,
          ),
          precioContadoCentavos: 0,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
      expect(m.fugas.actuales.propositos, isEmpty);
      await m.servicio.declararProposito(
        libroId: _libro,
        deudaId: compra.deudaId,
        declaracion: const DeclaracionDeuda(
          proposito: PropositoDeuda.generaIngreso,
          objetivoTexto: 'Herramienta de trabajo',
          vidaUtilMeses: 48,
        ),
      );
      final d = m.servicio
          .calidadDeDeudas(_libro)
          .firstWhere((x) => x.deuda.id == compra.deudaId);
      expect(d.declaracion!.proposito, PropositoDeuda.generaIngreso);
      expect(d.calidad.estado, isNot(EstadoCalidad.porDeclarar));
      expect(d.calidad.bloquea, isFalse);
    });

    test('propósito «consumo» o un objetivo que ya no existe: se vuelve '
        'mala; aun así sigue sin bloquear nada (DD-19)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final compra = await msi(m);
      await m.servicio.declararProposito(
        libroId: _libro,
        deudaId: compra.deudaId,
        declaracion: const DeclaracionDeuda(proposito: PropositoDeuda.consumo),
      );
      final d = m.servicio
          .calidadDeDeudas(_libro)
          .firstWhere((x) => x.deuda.id == compra.deudaId);
      expect(d.mostrado, EstadoCalidad.seVolvioMala);
      expect(d.calidad.sugerencias, isNotEmpty);
      // Registrar otra compra a meses se puede, sin confirmación extra.
      final otra = await msi(m, comercio: 'Otra');
      expect(otra.deudaId, isNotEmpty);
    });

    test('la vista previa de un MSI nuevo muestra el efecto y nunca '
        'bloquea (DD-17)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final vacia = m.servicio.vistaPreviaMsi(_libro, 100000);
      expect(vacia.activos, 1);
      expect(vacia.bloquea, isFalse);
      await msi(m);
      final despues = m.servicio.vistaPreviaMsi(_libro, 100000);
      expect(despues.activos, 2);
      expect(despues.bloquea, isFalse);
      final r = m.servicio.resumenMsi(_libro);
      expect(r.activos, 1);
      expect(r.mensualidadesCentavos, 10000);
    });

    test('el semáforo se registra al cambiar y avisa una sola vez al '
        'empeorar; una mejora espera dos semanas (histéresis)', () async {
      final m = _mundo();
      addTearDown(m.repo.cerrar);
      final compra = await msi(m);
      // Por declarar: gris, sin aviso.
      expect(await m.servicio.emitirAvisos(_libro), 0);
      expect(m.fugas.actuales.semaforoDe(compra.deudaId)!.nivel, 'gris');
      // Consumo: roja, con un aviso crítico sin cifras.
      await m.servicio.declararProposito(
        libroId: _libro,
        deudaId: compra.deudaId,
        declaracion: const DeclaracionDeuda(proposito: PropositoDeuda.consumo),
      );
      final antes = m.repo.avisosEmitidos.length;
      expect(await m.servicio.emitirAvisos(_libro), 1);
      final a = m.repo.avisosEmitidos.last;
      expect(a.tipo, TiposAvisoFugas.deudaSeVolvioMala);
      expect(a.objetoTipo, 'deuda');
      expect(a.objetoId, compra.deudaId);
      expect(a.clave, startsWith('deuda:${compra.deudaId}:rojo:'));
      expect(m.repo.avisosEmitidos.length, antes + 1);
      expect(m.fugas.actuales.semaforoDe(compra.deudaId)!.nivel, 'rojo');
      // Mejora (ahora para algo que dura): esta semana ya se evaluó, sigue
      // en rojo; no se vuelve a avisar.
      await m.servicio.declararProposito(
        libroId: _libro,
        deudaId: compra.deudaId,
        declaracion: const DeclaracionDeuda(
          proposito: PropositoDeuda.bienDuradero,
          vidaUtilMeses: 48,
        ),
      );
      final d = m.servicio
          .calidadDeDeudas(_libro)
          .firstWhere((x) => x.deuda.id == compra.deudaId);
      expect(d.mostrado, EstadoCalidad.seVolvioMala);
      expect(d.mejoraEnEspera, isTrue);
      expect(await m.servicio.emitirAvisos(_libro), 0);
    });
  });

  group('RepositorioFugasSupabase contra una fuente falsa', () {
    test('escribe por las RPC con sus parámetros y lee las vistas', () async {
      final f = FuenteTablasEnMemoria();
      final repo = RepositorioFugasSupabase(fuente: f);
      addTearDown(repo.cerrar);
      f.funciones[TablasFugas.crearPatron] = (p) => p['p_id'];
      f.funciones[TablasFugas.registrarSemaforo] = (_) => true;
      final id = await repo.crearPatron(
        id: 'p1',
        libroId: _libro,
        clave: 'streamix|cat',
        cadencia: CadenciaCobro.mensual,
        automatico: true,
        comercioNorm: 'streamix',
        categoriaId: 'c1',
      );
      expect(id, 'p1');
      expect(f.llamadas.single.$1, 'fin_patron_crear');
      expect(f.llamadas.single.$2, {
        'p_id': 'p1',
        'p_libro': _libro,
        'p_comercio_norm': 'streamix',
        'p_categoria': 'c1',
        'p_cadencia': 'mensual',
        'p_automatico': true,
        'p_clave': 'streamix|cat',
        'p_origen': 'detectado',
        'p_compromiso': null,
      });
      await repo.responder(
        id: 'r1',
        patronId: 'p1',
        pregunta: PreguntaFuga.yaNoSirve,
        respuesta: RespuestaPersona.si,
        periodoLunes: Fecha(2026, 10, 19),
      );
      final r = f.llamadas.last;
      expect(r.$1, 'fin_fuga_responder');
      expect(r.$2['p_pregunta'], 'ya_no_sirve');
      expect(r.$2['p_respuesta'], 'si');
      expect(r.$2['p_periodo_lunes'], '2026-10-19');
      await repo.clasificar(
        id: 'c1',
        patronId: 'p1',
        fuga: TipoFuga.ninguna,
        fugaRegla: TipoFuga.hormiga,
        motivo: 'Lo uso para trabajar',
        regla: 'PERSONA',
      );
      final c = f.llamadas.last;
      expect(c.$1, 'fin_fuga_clasificar');
      expect(c.$2['p_fuga'], 'ninguna');
      expect(c.$2['p_fuga_regla'], 'hormiga');
      expect(c.$2['p_regla'], isNull, reason: 'PERSONA no cabe en 1 a 3');
      await repo.cancelar(
        id: 'k1',
        patronId: 'p1',
        fecha: Fecha(2026, 10, 10),
        folio: 'ABC-123',
      );
      expect(f.llamadas.last.$1, 'fin_patron_cancelar');
      expect(f.llamadas.last.$2['p_folio'], 'ABC-123');
      await repo.declararProposito(
        id: 'd1',
        libroId: _libro,
        deudaId: 'deuda1',
        declaracion: const DeclaracionDeuda(
          proposito: PropositoDeuda.generaIngreso,
          objetivoTexto: 'Herramienta',
          vidaUtilMeses: 48,
          estado: EstadoObjetivo.cumplido,
        ),
        precioContadoCentavos: 1000000,
      );
      final d = f.llamadas.last;
      expect(d.$1, 'fin_deuda_declarar');
      expect(d.$2['p_proposito'], 'genera_ingreso');
      expect(d.$2['p_estado'], 'cumplido');
      expect(d.$2['p_precio_contado_centavos'], 1000000);
      final agrego = await repo.registrarSemaforo(
        id: 's1',
        libroId: _libro,
        deudaId: 'deuda1',
        lunes: Fecha(2026, 10, 19),
        nivel: 'ambar',
        senales: const ['B4b', 'M5'],
        bajasSeguidas: 1,
      );
      expect(agrego, isTrue);
      expect(f.llamadas.last.$2['p_senales'], ['B4b', 'M5']);
      expect(repo.actuales.semaforoDe('deuda1')!.nivel, 'ambar');
    });

    test('lee las vistas y arma lo vigente; sin pagos al corte capturados '
        'quedan «sin dato», no «pagó cero»', () async {
      final f = FuenteTablasEnMemoria();
      final repo = RepositorioFugasSupabase(fuente: f);
      addTearDown(repo.cerrar);
      f.tabla(TablasFugas.patrones).add({
        'id': 'p1',
        'libro_id': _libro,
        'clave': 'streamix|cat',
        'comercio_norm': 'streamix',
        'categoria_id': 'c1',
        'cadencia': 'mensual',
        'automatico': true,
        'origen': 'detectado',
      });
      f.tabla(TablasFugas.patronesEstado).add({
        'patron_id': 'p1',
        'protegido': false,
        'vigilar': true,
        'cancelado_en': '2026-10-10',
        'folio_cancelacion': null,
        'cancelado_sin_folio': true,
      });
      f.tabla(TablasFugas.clasificaciones).add({
        'id': 'c1',
        'libro_id': _libro,
        'patron_id': 'p1',
        'fuga': 'ninguna',
        'origen': 'persona',
        'fuga_regla': 'hormiga',
        'vigilar': true,
        'decidido_en': '2026-10-01T10:00:00Z',
      });
      f.tabla(TablasFugas.respuestas).add({
        'id': 'r1',
        'libro_id': _libro,
        'patron_id': 'p1',
        'pregunta': 'ya_no_sirve',
        'respuesta': 'si',
        'periodo_lunes': '2026-10-19',
        'registrado_en': '2026-10-20T10:00:00Z',
      });
      f.tabla(TablasFugas.propositos).add({
        'id': 'd1',
        'libro_id': _libro,
        'deuda_id': 'deuda1',
        'proposito': 'genera_ingreso',
        'objetivo_texto': 'Herramienta',
        'vida_util_meses': 48,
        'estado_objetivo': 'vigente',
        'uso_poco': false,
        'precio_contado_centavos': 1000000,
        'declarado_en': '2026-10-01T10:00:00Z',
      });
      f.tabla(TablasFugas.semaforo).add({
        'libro_id': _libro,
        'deuda_id': 'deuda1',
        'lunes': '2026-10-19',
        'nivel': 'rojo',
        'senales': ['M2'],
        'bajas_seguidas': 1,
        'calculado_en': '2026-10-20T10:00:00Z',
      });
      f.tabla(TablasFugas.parametros).add({
        'libro_id': _libro,
        'tope_hormiga_centavos': 20000,
        'msi_rojo_pb': 2500,
      });
      f.tabla(TablasFugas.estadosCuenta).addAll([
        {'id': 'e1', 'pagos_al_corte_centavos': null},
        {'id': 'e2', 'pagos_al_corte_centavos': 0},
      ]);
      await repo.cargar();
      final d = repo.actuales;
      final p = d.patrones.single;
      expect(p.vigilar, isTrue);
      expect(p.canceladoSinFolio, isTrue);
      expect(p.canceladoEn, Fecha(2026, 10, 10));
      expect(d.clasificaciones.single.vigilar, isTrue);
      expect(d.respuestas.single.pregunta, PreguntaFuga.yaNoSirve);
      expect(d.propositoDe('deuda1')!.precioContadoCentavos, 1000000);
      expect(d.semaforoDe('deuda1')!.senales, ['M2']);
      expect(d.parametrosDe(_libro).topeHormigaCentavos, 20000);
      expect(d.parametrosDe(_libro).msiRojoPb, 2500);
      expect(
        d.parametrosDe(_libro).hormigaMinGastos,
        ParametrosFugas.porDefecto.hormigaMinGastos,
      );
      expect(d.pagosAlCorte['e1'], isNull);
      expect(d.pagosAlCorte.containsKey('e1'), isTrue);
      expect(d.pagosAlCorte['e2'], 0);
    });

    test('sin señal las escrituras lanzan y no cambian nada', () async {
      final f = FuenteTablasEnMemoria()..sinSenal = true;
      final repo = RepositorioFugasSupabase(fuente: f);
      addTearDown(repo.cerrar);
      await expectLater(
        repo.responder(
          id: 'r1',
          patronId: 'p1',
          pregunta: PreguntaFuga.reconoce,
          respuesta: RespuestaPersona.si,
          periodoLunes: Fecha(2026, 10, 19),
        ),
        throwsA(
          isA<ErrorFinanzas>().having(
            (e) => e.sinConexion,
            'sinConexion',
            true,
          ),
        ),
      );
      await expectLater(repo.cargar(), throwsA(isA<ErrorFinanzas>()));
      expect(repo.actuales.respuestas, isEmpty);
    });
  });
}
