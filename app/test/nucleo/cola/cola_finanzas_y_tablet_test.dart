// Fase 1 y D14 (21/oct/2026):
// - La cola sube los registros de Finanzas a su tabla, idempotente por UUID
//   (`ON CONFLICT (id) DO NOTHING`), con el cliente de la persona activa.
// - En la tablet pública, lo de la casa registrado sin PIN (eligiendo el
//   nombre) se guarda con quién dijo ser y solo sale con la cuenta del equipo.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/arranque.dart';
import 'package:gravity/app/pantallas_externas.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/enviador_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'postgrest_simulado.dart'
    show PeticionRecibida, PostgrestSimulado, sesionJson;

void main() {
  group('Finanzas en la cola', () {
    test('tablasDeLaCola incluye las de Finanzas, con sus prefijos', () {
      expect(tablasColaFinanzas, isNotEmpty);
      for (final MapEntry(key: tipo, value: tabla) in tablasColaFinanzas.entries) {
        expect(tablasDeLaCola[tipo], tabla, reason: tipo);
        expect(tipo, startsWith('finanzas.'), reason: tipo);
        expect(tabla, startsWith('fin_'), reason: tipo);
      }
    });

    late HttpServer servidor;
    late List<PeticionRecibida> recibidas;
    final guardados = <String>{};

    setUp(() async {
      recibidas = [];
      guardados.clear();
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servidor.listen((peticion) async {
        final texto = await utf8.decodeStream(peticion);
        final encabezados = <String, String>{};
        peticion.headers.forEach(
          (nombre, valores) => encabezados[nombre] = valores.join(','),
        );
        final cuerpo = texto.isEmpty ? null : jsonDecode(texto);
        recibidas.add(
          PeticionRecibida(peticion.method, peticion.uri, encabezados, cuerpo),
        );
        // Como `ON CONFLICT (id) DO NOTHING`: un reenvío no duplica.
        if (cuerpo is Map) guardados.add(cuerpo['id'] as String);
        peticion.response.statusCode = HttpStatus.created;
        await peticion.response.close();
      });
    });

    tearDown(() => servidor.close(force: true));

    Future<SupabaseClient> clienteDe(String uid) async {
      final cliente = SupabaseClient(
        'http://127.0.0.1:${servidor.port}',
        'llave-publica-de-prueba',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(cliente.dispose);
      await cliente.auth.recoverSession(sesionJson(uid));
      expect(cliente.auth.currentSession, isNotNull);
      return cliente;
    }

    test(
      'cada tipo de Finanzas va a su tabla, sin duplicar y con el cliente '
      'de la persona activa',
      () async {
        final ana = await clienteDe('uid-ana');
        final beto = await clienteDe('uid-beto');
        var activo = ana;
        final base = BaseLocal.enMemoria();
        addTearDown(base.close);
        final cola = ColaSinConexion(
          base: base,
          enviador: EnviadorSupabase.dinamico(
            () => activo,
            tablas: tablasDeLaCola,
          ),
        );

        final tipos = tablasColaFinanzas.keys.toList();
        for (final tipo in tipos) {
          await cola.encolar(
            tipo: tipo,
            carga: {'monto_centavos': 18500, 'nota': 'Ejemplo'},
          );
        }
        expect((await cola.procesar()).enviados, tipos.length);
        for (var i = 0; i < tipos.length; i++) {
          final peticion = recibidas[i];
          expect(peticion.metodo, 'POST');
          expect(
            peticion.uri.path,
            '/rest/v1/${tablasColaFinanzas[tipos[i]]}',
          );
          expect(peticion.uri.queryParameters['on_conflict'], 'id');
          expect(
            peticion.encabezados['prefer'],
            contains('resolution=ignore-duplicates'),
          );
          expect(peticion.sujeto, 'uid-ana');
        }

        // El mismo id no se vuelve a enviar.
        expect((await cola.procesar()).enviados, 0);
        expect(recibidas, hasLength(tipos.length));

        // Reenviar a mano el mismo id (p. ej. tras perder la respuesta) no
        // duplica en el servidor: la llave es el UUID del dispositivo.
        final id = (await cola.registros()).first.id;
        final enviador = EnviadorSupabase(ana, tablas: tablasDeLaCola);
        await enviador.enviar(
          PeticionEnvio(
            id: id,
            tipo: tipos.first,
            carga: const {'monto_centavos': 18500},
            creadoEn: DateTime(2026, 10, 21),
            intento: 2,
          ),
        );
        expect(guardados, hasLength(tipos.length));

        // Cambia la persona activa (tablet): sale con su cliente.
        activo = beto;
        await cola.encolar(tipo: tipos.first, carga: const {'nota': 'Beto'});
        await cola.procesar();
        expect(recibidas.last.sujeto, 'uid-beto');
      },
    );
  });

  group('tablet pública: lo de la casa sin PIN (D14)', () {
    late BaseLocal base;
    late List<PeticionEnvio> enviadas;
    String? conSesion;
    const casa = 'persona-casa';
    const ana = 'persona-ana';
    var siguienteId = 0;

    late ColaSinConexion cola;

    setUp(() {
      base = BaseLocal.enMemoria();
      enviadas = [];
      conSesion = casa;
      cola = ColaSinConexion(
        base: base,
        enviador: _Enviador(enviadas),
        generarId: () => 'id-${siguienteId++}',
        personaQueRegistra: () => conSesion,
        personaConSesion: () => conSesion,
        cuentaDelEquipo: () => casa,
      );
    });

    tearDown(() => base.close());

    test('lo de la casa exige saber quién dijo ser', () {
      expect(
        () => cola.encolar(
          tipo: 'casa.lista',
          carga: const {},
          origen: OrigenRegistro.tabletCasa,
        ),
        throwsArgumentError,
      );
    });

    test('guarda quién dijo ser y el origen "tablet de la casa"', () async {
      final id = await cola.encolar(
        tipo: 'casa.lista',
        carga: const {'texto': 'Tortillas'},
        personaId: ana,
        origen: OrigenRegistro.tabletCasa,
      );
      final registro = (await cola.registros()).single;
      expect(registro.id, id);
      expect(registro.personaId, ana);
      expect(registro.origen, OrigenRegistro.tabletCasa);
    });

    test('sale solo con la cuenta del equipo, nunca con la sesión de Ana', () async {
      await cola.encolar(
        tipo: 'casa.lista',
        carga: const {},
        personaId: ana,
        origen: OrigenRegistro.tabletCasa,
      );
      await cola.encolar(tipo: 'finanzas.movimiento', carga: const {}, personaId: ana);

      // Ana entró con su PIN: sube su gasto, no lo que registró sin PIN.
      conSesion = ana;
      expect((await cola.procesar()).enviados, 1);
      expect(enviadas.single.tipo, 'finanzas.movimiento');
      expect(enviadas.single.origen, OrigenRegistro.propio);

      // De vuelta en el modo Casa: sube lo de la casa, con quién dijo ser.
      conSesion = casa;
      expect((await cola.procesar()).enviados, 1);
      expect(enviadas.last.tipo, 'casa.lista');
      expect(enviadas.last.personaId, ana);
      expect(enviadas.last.origen, OrigenRegistro.tabletCasa);
    });

    test('M3: el dinero no se registra con el origen "tablet de la casa"', () async {
      for (final tipo in [
        'finanzas.movimiento',
        'finanzas.conciliacion',
        'habitos.marca',
        'cuidados.medicamento',
      ]) {
        await expectLater(
          cola.encolar(
            tipo: tipo,
            carga: const {'monto_centavos': 5000},
            personaId: ana,
            origen: OrigenRegistro.tabletCasa,
          ),
          throwsArgumentError,
          reason: tipo,
        );
      }
      expect(await cola.registros(), isEmpty, reason: 'nada quedó guardado');

      // Con nombre y PIN (la sesión de la persona) sí se registra.
      await cola.encolar(
        tipo: 'finanzas.movimiento',
        carga: const {'monto_centavos': 5000},
        personaId: ana,
      );
      // Y lo de la casa, con solo el nombre.
      await cola.encolar(
        tipo: 'casa.lista',
        carga: const {'texto': 'Tortillas'},
        personaId: ana,
        origen: OrigenRegistro.tabletCasa,
      );
      expect(await cola.registros(), hasLength(2));
    });

    test('M3: un registro viejo de dinero con ese origen no sube', () async {
      final servidor = await PostgrestSimulado.iniciar();
      addTearDown(servidor.cerrar);
      final cliente = await servidor.cliente('uid-casa');
      addTearDown(cliente.dispose);
      // Como si quedara de antes de la regla: se guarda directo en la base.
      await base.into(base.pendientes).insert(
        PendientesCompanion.insert(
          id: 'viejo-1',
          tipo: 'finanzas.movimiento',
          carga: '{"monto_centavos": 5000}',
          creadoEn: DateTime(2026, 10, 22),
          estado: EstadoPendiente.pendiente,
          personaId: const Value(ana),
          origen: const Value(OrigenRegistro.tabletCasa),
        ),
      );
      final deLaCasa = ColaSinConexion(
        base: base,
        enviador: EnviadorSupabase(cliente, tablas: tablasDeLaCola),
        personaConSesion: () => casa,
        cuentaDelEquipo: () => casa,
      );
      final resumen = await deLaCasa.procesar();
      expect(resumen.rechazados, 1);
      expect(servidor.peticiones, isEmpty, reason: 'ni siquiera sale');
      final registro = (await deLaCasa.registros()).single;
      expect(registro.estado, EstadoPendiente.rechazado);
      expect(registro.ultimoError, contains('nombre y PIN'));
    });

    test('lo que requiere atención de la casa se ve en el modo Casa', () async {
      final rechaza = ColaSinConexion(
        base: base,
        enviador: const _Rechaza(),
        personaQueRegistra: () => conSesion,
        personaConSesion: () => conSesion,
        cuentaDelEquipo: () => casa,
      );
      await rechaza.encolar(
        tipo: 'casa.lista',
        carga: const {},
        personaId: ana,
        origen: OrigenRegistro.tabletCasa,
      );
      await rechaza.procesar();
      expect(
        await rechaza.requierenAtencion(personaId: casa, deLaTabletCasa: true),
        hasLength(1),
      );
      // A nombre de Ana pero sin su PIN: no aparece como algo suyo.
      expect(await rechaza.requierenAtencion(personaId: ana), isEmpty);
    });
  });
}

class _Enviador implements Enviador {
  _Enviador(this.enviadas);

  final List<PeticionEnvio> enviadas;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    enviadas.add(peticion);
    return ResultadoEnvio.enviado;
  }
}

class _Rechaza implements Enviador {
  const _Rechaza();

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.rechazado;
}
