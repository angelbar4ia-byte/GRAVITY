import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/enviador_supabase.dart';

/// Servidor simulado: falla mientras [conSenal] es `false` y guarda por id
/// (como `ON CONFLICT (id) DO NOTHING`).
class EnviadorFalso implements Enviador {
  bool conSenal = false;
  bool lanzarExcepcion = false;
  final Set<String> rechazarTipos = {};

  /// Tipos a los que "les falta algo de lo que dependen" (23503).
  final Set<String> faltaDependencia = {};
  final Map<String, Map<String, Object?>> servidor = {};
  final List<String> intentos = [];
  Completer<void>? pausa;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    intentos.add(peticion.id);
    if (pausa != null) await pausa!.future;
    if (lanzarExcepcion) throw StateError('sin red');
    if (!conSenal) return ResultadoEnvio.reintentar;
    if (faltaDependencia.contains(peticion.tipo)) {
      throw const FaltaDependenciaEnvio('Falta la cuenta c1');
    }
    if (rechazarTipos.contains(peticion.tipo)) return ResultadoEnvio.rechazado;
    servidor.putIfAbsent(peticion.id, () => peticion.carga);
    return ResultadoEnvio.enviado;
  }
}

void main() {
  late BaseLocal base;
  late EnviadorFalso enviador;
  late DateTime ahora;
  late ColaSinConexion cola;
  var siguienteId = 0;

  setUp(() {
    base = BaseLocal.enMemoria();
    enviador = EnviadorFalso();
    ahora = DateTime(2026, 10, 20, 8);
    siguienteId = 0;
    cola = ColaSinConexion(
      base: base,
      enviador: enviador,
      reloj: () => ahora,
      generarId: () => 'id-${siguienteId++}',
    );
  });

  tearDown(() => base.close());

  test('encolar guarda con UUID, tipo, carga JSON y estado pendiente', () async {
    final real = ColaSinConexion(base: base, enviador: enviador);
    final id = await real.encolar(
      tipo: 'finanzas.gasto',
      carga: {'monto_centavos': 12550, 'nota': 'súper'},
    );
    expect(
      id,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
    final registros = await real.registros();
    expect(registros, hasLength(1));
    expect(registros.single.tipo, 'finanzas.gasto');
    expect(registros.single.carga, '{"monto_centavos":12550,"nota":"súper"}');
    expect(registros.single.estado, EstadoPendiente.pendiente);
    expect(registros.single.intentos, 0);
  });

  test('sin señal falla, y al volver la señal se sube (servidor simulado)', () async {
    await cola.encolar(tipo: 'habitos.marca', carga: {'hecho': true});

    final sinSenal = await cola.procesar();
    expect(sinSenal.enviados, 0);
    expect(sinSenal.reintentos, 1);
    expect(sinSenal.restantes, 1);
    expect(enviador.servidor, isEmpty);

    // Vuelve la señal, pero aún no pasa la espera: no se intenta.
    enviador.conSenal = true;
    final antes = await cola.procesar();
    expect(antes.enviados, 0);
    expect(enviador.intentos, hasLength(1));

    ahora = ahora.add(const Duration(seconds: 5));
    final despues = await cola.procesar();
    expect(despues.enviados, 1);
    expect(despues.restantes, 0);
    expect(enviador.servidor.keys, ['id-0']);
    final registro = (await cola.registros()).single;
    expect(registro.estado, EstadoPendiente.enviado);
    expect(registro.intentos, 2);
    expect(registro.ultimoError, isNull);
  });

  test('la espera crece con cada intento fallido', () async {
    await cola.encolar(tipo: 't', carga: {});
    for (final espera in const [5, 10, 20, 40]) {
      await cola.procesar();
      final registro = (await cola.registros()).single;
      expect(
        registro.siguienteIntento,
        ahora.add(Duration(seconds: espera)),
        reason: 'intento ${registro.intentos}',
      );
      ahora = registro.siguienteIntento!;
    }
    expect((await cola.registros()).single.intentos, 4);
  });

  test('PoliticaReintentos tiene tope', () {
    const politica = PoliticaReintentos(
      esperaInicial: Duration(seconds: 5),
      esperaMaxima: Duration(minutes: 1),
    );
    expect(politica.esperaTras(1), const Duration(seconds: 5));
    expect(politica.esperaTras(2), const Duration(seconds: 10));
    expect(politica.esperaTras(5), const Duration(seconds: 60));
    expect(politica.esperaTras(30), const Duration(minutes: 1));
  });

  test('idempotencia: el mismo id no se duplica ni se reenvía', () async {
    enviador.conSenal = true;
    await cola.encolar(tipo: 't', carga: {'v': 1}, id: 'uuid-fijo');
    await cola.encolar(tipo: 't', carga: {'v': 2}, id: 'uuid-fijo');
    expect(await cola.registros(), hasLength(1));
    expect(await cola.contarPendientes(), 1);

    await cola.procesar();
    await cola.procesar();
    expect(enviador.intentos, ['uuid-fijo']);
    expect(enviador.servidor['uuid-fijo'], {'v': 1});

    // Encolar de nuevo un id ya enviado tampoco lo revive.
    await cola.encolar(tipo: 't', carga: {'v': 3}, id: 'uuid-fijo');
    await cola.procesar();
    expect(enviador.intentos, ['uuid-fijo']);
  });

  test('envía en orden de creación y detiene la ronda si falla la red', () async {
    for (var i = 0; i < 3; i++) {
      await cola.encolar(tipo: 't', carga: {'n': i});
    }
    final resumen = await cola.procesar();
    expect(enviador.intentos, ['id-0']);
    expect(resumen.restantes, 3);

    enviador.conSenal = true;
    ahora = ahora.add(const Duration(minutes: 1));
    final segundo = await cola.procesar();
    expect(segundo.enviados, 3);
    expect(enviador.intentos, ['id-0', 'id-0', 'id-1', 'id-2']);
  });

  test('una excepción del enviador cuenta como reintento', () async {
    enviador.lanzarExcepcion = true;
    await cola.encolar(tipo: 't', carga: {});
    final resumen = await cola.procesar();
    expect(resumen.reintentos, 1);
    final registro = (await cola.registros()).single;
    expect(registro.estado, EstadoPendiente.pendiente);
    expect(registro.ultimoError, contains('sin red'));
  });

  test('lo rechazado no se reintenta y no detiene a los demás', () async {
    enviador
      ..conSenal = true
      ..rechazarTipos.add('malo');
    await cola.encolar(tipo: 'malo', carga: {});
    await cola.encolar(tipo: 'bueno', carga: {});
    final resumen = await cola.procesar();
    expect(resumen.rechazados, 1);
    expect(resumen.enviados, 1);
    expect(resumen.restantes, 0);
    final estados = [for (final r in await cola.registros()) r.estado];
    expect(estados, [EstadoPendiente.rechazado, EstadoPendiente.enviado]);
    await cola.procesar();
    expect(enviador.intentos, hasLength(2));
  });

  test('dos llamadas a procesar comparten la misma ronda', () async {
    enviador
      ..conSenal = true
      ..pausa = Completer<void>();
    await cola.encolar(tipo: 't', carga: {});
    final primera = cola.procesar();
    final segunda = cola.procesar();
    expect(identical(primera, segunda), isTrue);
    enviador.pausa!.complete();
    await primera;
    expect(enviador.intentos, ['id-0']);
  });

  test('vigilarPendientes avisa cuántos faltan', () async {
    final valores = <int>[];
    final suscripcion = cola.vigilarPendientes().listen(valores.add);
    await pumpEventQueue();
    await cola.encolar(tipo: 't', carga: {});
    await pumpEventQueue();
    enviador.conSenal = true;
    await cola.procesar();
    await pumpEventQueue();
    await suscripcion.cancel();
    expect(valores.first, 0);
    expect(valores, contains(1));
    expect(valores.last, 0);
  });

  test('limpiarEnviados borra solo lo enviado y viejo', () async {
    enviador.conSenal = true;
    await cola.encolar(tipo: 't', carga: {});
    await cola.procesar();
    enviador.conSenal = false;
    await cola.encolar(tipo: 't', carga: {});
    ahora = ahora.add(const Duration(days: 8));
    expect(await cola.limpiarEnviados(), 1);
    expect(await cola.registros(), hasLength(1));
  });

  test('clasificarErrorPostgrest', () {
    // Contrato del servidor: 23503 se reintenta; el resto de lo que valida el
    // servidor es permanente (requiere atención).
    expect(clasificarErrorPostgrest('23503'), ResultadoEnvio.reintentar);
    for (final codigo in ['23505', '23514', '22023', '55000', '42501']) {
      expect(clasificarErrorPostgrest(codigo), ResultadoEnvio.rechazado,
          reason: codigo);
    }
    expect(clasificarErrorPostgrest('22P02'), ResultadoEnvio.rechazado);
    expect(clasificarErrorPostgrest('PGRST301'), ResultadoEnvio.reintentar);
    expect(clasificarErrorPostgrest(null), ResultadoEnvio.reintentar);
    // Pasajeros: servidor caído u ocupado, conexión con la base, tiempo.
    for (final codigo in [
      '503', '502', '429', 'PGRST000', '57014', '57P01', '40001', '40P01',
      '08006', '53300',
    ]) {
      expect(clasificarErrorPostgrest(codigo), ResultadoEnvio.reintentar,
          reason: codigo);
    }
    // Permanentes: requieren atención (no se reintentan sin fin, M16).
    for (final codigo in ['PGRST204', '42703', '42P01', 'P0001', '400']) {
      expect(clasificarErrorPostgrest(codigo), ResultadoEnvio.rechazado,
          reason: codigo);
    }
  });

  group('falta de dependencia y orden de subida', () {
    test('FaltaDependenciaEnvio se reintenta y no detiene la ronda', () async {
      enviador
        ..conSenal = true
        ..faltaDependencia.add('depende');
      await cola.encolar(tipo: 'depende', carga: {});
      await cola.encolar(tipo: 'independiente', carga: {});
      final resumen = await cola.procesar();
      expect(resumen.reintentos, 1);
      expect(resumen.enviados, 1);
      expect(resumen.rechazados, 0);
      final registros = await cola.registros();
      expect(registros.first.estado, EstadoPendiente.pendiente);
      expect(registros.first.ultimoError, 'Falta la cuenta c1');
      expect(registros.first.siguienteIntento,
          ahora.add(const Duration(seconds: 5)));
      expect(registros.last.estado, EstadoPendiente.enviado);
    });

    test('un fallo de red sí detiene la ronda (a diferencia de la dependencia)',
        () async {
      enviador.lanzarExcepcion = true;
      await cola.encolar(tipo: 'a', carga: {});
      await cola.encolar(tipo: 'b', carga: {});
      await cola.procesar();
      expect(enviador.intentos, ['id-0']);
    });

    test('la dependencia tiene su propio límite de intentos', () async {
      final limitada = ColaSinConexion(
        base: base,
        enviador: enviador,
        reloj: () => ahora,
        intentosMaximos: 2,
        intentosMaximosPorDependencia: 4,
      );
      enviador
        ..conSenal = true
        ..faltaDependencia.add('depende');
      await limitada.encolar(tipo: 'depende', carga: {});
      for (var i = 0; i < 3; i++) {
        await limitada.procesar();
        ahora = ahora.add(const Duration(hours: 1));
      }
      expect((await limitada.registros()).single.estado,
          EstadoPendiente.pendiente);
      await limitada.procesar();
      final registro = (await limitada.registros()).single;
      expect(registro.estado, EstadoPendiente.rechazado);
      expect(registro.ultimoError, contains('Falló 4 veces'));
      expect(registro.ultimoError, contains('Falta la cuenta c1'));
    });

    test('sube primero el nivel menor y, dentro del nivel, por creación',
        () async {
      final ordenada = ColaSinConexion(
        base: base,
        enviador: enviador,
        reloj: () => ahora,
        generarId: () => 'id-${siguienteId++}',
        nivelDeSubida: (tipo) =>
            const {'cuenta': 0, 'movimiento': 1, 'conciliacion': 2}[tipo] ?? 0,
      );
      enviador.conSenal = true;
      await ordenada.encolar(tipo: 'conciliacion', carga: {}); // id-0
      await ordenada.encolar(tipo: 'movimiento', carga: {}); // id-1
      await ordenada.encolar(tipo: 'cuenta', carga: {}); // id-2
      await ordenada.encolar(tipo: 'movimiento', carga: {}); // id-3
      await ordenada.encolar(tipo: 'cuenta', carga: {}); // id-4
      await ordenada.procesar();
      expect(enviador.intentos, ['id-2', 'id-4', 'id-1', 'id-3', 'id-0']);
    });

    test('el nivel sale del enviador si es un EnviadorOrdenado', () async {
      final conNiveles = EnviadorConNiveles({'b': 0, 'a': 1});
      final ordenada = ColaSinConexion(
        base: base,
        enviador: conNiveles,
        reloj: () => ahora,
        generarId: () => 'id-${siguienteId++}',
      );
      await ordenada.encolar(tipo: 'a', carga: {}); // id-0
      await ordenada.encolar(tipo: 'b', carga: {}); // id-1
      await ordenada.encolar(tipo: 'sin_nivel', carga: {}); // id-2 (nivel 0)
      await ordenada.procesar();
      expect(conNiveles.enviados, ['id-1', 'id-2', 'id-0']);
    });

    test('sin niveles, el orden de creación de siempre', () async {
      enviador.conSenal = true;
      for (final tipo in ['z', 'a', 'm']) {
        await cola.encolar(tipo: tipo, carga: {});
      }
      await cola.procesar();
      expect(enviador.intentos, ['id-0', 'id-1', 'id-2']);
    });
  });

  group('I4: ligada a la persona y a la sesión', () {
    String? conSesion;
    String? registra;
    late ColaSinConexion ligada;

    setUp(() {
      conSesion = null;
      registra = 'persona-a';
      ligada = ColaSinConexion(
        base: base,
        enviador: enviador,
        reloj: () => ahora,
        generarId: () => 'id-${siguienteId++}',
        personaQueRegistra: () => registra,
        personaConSesion: () => conSesion,
      );
      enviador.conSenal = true;
    });

    test('cada registro guarda quién lo hizo', () async {
      await ligada.encolar(tipo: 't', carga: {});
      await ligada.encolar(tipo: 't', carga: {}, personaId: 'persona-b');
      expect([for (final r in await ligada.registros()) r.personaId], [
        'persona-a',
        'persona-b',
      ]);
    });

    test('sin sesión no envía nada ni cuenta intentos', () async {
      await ligada.encolar(tipo: 't', carga: {});
      final resumen = await ligada.procesar();
      expect(resumen.enviados, 0);
      expect(resumen.restantes, 1);
      expect(enviador.intentos, isEmpty);
      final registro = (await ligada.registros()).single;
      expect(registro.estado, EstadoPendiente.pendiente);
      expect(registro.intentos, 0);
    });

    test('con sesión solo envía lo de esa persona', () async {
      await ligada.encolar(tipo: 't', carga: {}); // persona-a
      registra = 'persona-b';
      await ligada.encolar(tipo: 't', carga: {});
      conSesion = 'persona-b';
      expect((await ligada.procesar()).enviados, 1);
      expect(enviador.intentos, ['id-1']);
      conSesion = 'persona-a';
      expect((await ligada.procesar()).enviados, 1);
      expect(enviador.intentos, ['id-1', 'id-0']);
    });

    test('"sin sesión" del enviador espera sin contar el intento', () async {
      final sinSesion = ColaSinConexion(
        base: base,
        enviador: const EnviadorSinSesion(),
        reloj: () => ahora,
      );
      await sinSesion.encolar(tipo: 't', carga: {});
      await sinSesion.procesar();
      final registro = (await sinSesion.registros()).single;
      expect(registro.estado, EstadoPendiente.pendiente);
      expect(registro.intentos, 0);
      expect(registro.siguienteIntento, isNull);
    });

    test('lo rechazado requiere atención: se ve, se reintenta o se descarta',
        () async {
      conSesion = 'persona-a';
      enviador.rechazarTipos.add('malo');
      await ligada.encolar(tipo: 'malo', carga: {'descripcion': 'Despensa'});
      await ligada.encolar(tipo: 'malo', carga: {}, personaId: 'persona-b');
      final avisos = <int>[];
      final suscripcion = ligada
          .vigilarAtencion(personaId: 'persona-a')
          .listen((lista) => avisos.add(lista.length));
      await pumpEventQueue();
      await ligada.procesar();
      await pumpEventQueue();
      expect(avisos.last, 1);
      // Cada quien ve solo lo suyo (D5).
      final deA = await ligada.requierenAtencion(personaId: 'persona-a');
      expect(deA.single.id, 'id-0');
      expect(deA.single.ultimoError, isNotNull);

      // Reintentar: vuelve a la cola y, si el servidor ya lo acepta, sube.
      enviador.rechazarTipos.clear();
      await ligada.reintentar('id-0');
      await ligada.procesar();
      expect(enviador.servidor.keys, contains('id-0'));
      await pumpEventQueue();
      expect(avisos.last, 0);

      // Descartar: deja de requerir atención y no se sube.
      registra = 'persona-a';
      enviador.rechazarTipos.add('malo');
      await ligada.encolar(tipo: 'malo', carga: {});
      await ligada.procesar();
      await ligada.descartar('id-2');
      expect(await ligada.requierenAtencion(personaId: 'persona-a'), isEmpty);
      expect(
        (await ligada.registros()).firstWhere((r) => r.id == 'id-2').estado,
        EstadoPendiente.descartado,
      );
      await suscripcion.cancel();
    });

    test('M16: tras muchos fallos sin respuesta clara, requiere atención',
        () async {
      final limitada = ColaSinConexion(
        base: base,
        enviador: enviador,
        reloj: () => ahora,
        intentosMaximos: 3,
      );
      enviador.lanzarExcepcion = true;
      await limitada.encolar(tipo: 't', carga: {});
      for (var i = 0; i < 3; i++) {
        await limitada.procesar();
        ahora = ahora.add(const Duration(hours: 1));
      }
      final registro = (await limitada.registros()).single;
      expect(registro.estado, EstadoPendiente.rechazado);
      expect(registro.ultimoError, contains('Falló 3 veces'));
    });

    test('un enviador puede rechazar diciendo por qué', () async {
      final conMotivo = ColaSinConexion(
        base: base,
        enviador: const EnviadorQueRechaza(),
        reloj: () => ahora,
      );
      await conMotivo.encolar(tipo: 't', carga: {});
      await conMotivo.procesar();
      final registro = (await conMotivo.registros()).single;
      expect(registro.estado, EstadoPendiente.rechazado);
      expect(registro.ultimoError, 'Sin permiso para guardarlo (42501).');
    });
  });
}

class EnviadorSinSesion implements Enviador {
  const EnviadorSinSesion();

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.sinSesion;
}

class EnviadorQueRechaza implements Enviador {
  const EnviadorQueRechaza();

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      throw const RechazoEnvio('Sin permiso para guardarlo (42501).');
}

class EnviadorConNiveles implements EnviadorOrdenado {
  EnviadorConNiveles(this.niveles);

  final Map<String, int> niveles;
  final List<String> enviados = [];

  @override
  int nivelDeSubida(String tipo) => niveles[tipo] ?? 0;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    enviados.add(peticion.id);
    return ResultadoEnvio.enviado;
  }
}
