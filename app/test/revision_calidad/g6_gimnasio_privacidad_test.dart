// G6 · Revisión de cierre del gimnasio (docs/revisiones/fase-8-gimnasio.md).
//
// Privacidad de punta a punta (D3, D6, D13, D21, PG-03, CA-G-36): se hace una
// sesión COMPLETA con una molestia marcada con una cadena única y se busca esa
// cadena (y las palabras de salud) en TODO lo que el equipo persiste o envía:
// todas las tablas de la base local, la cola de subida, el almacén seguro, las
// preferencias, las notificaciones y lo que recibiría un servidor de verdad.
//
// Además:
// - G6-M2 (caracterización, decisión del dueño): `semana_tipo = 'foco'` SÍ
//   viaja al servidor; es la única huella del modo foco (hábito a eliminar) que
//   sale del equipo.
// - G6-A1 (hallazgo, etiquetado): el aviso de cercanía a dormir se dispara en
//   falso si la hora de dormir pasa de medianoche.
//
// Para excluir solo los hallazgos que fallan hasta que se corrijan:
//   flutter test --exclude-tags hallazgo
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/controlador_sesion.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/contrato_gimnasio.dart';
import 'package:gravity/nucleo/cola/enviador_supabase.dart';
import 'package:gravity/nucleo/gimnasio/repositorio_gimnasio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../nucleo/gimnasio/servidor_gimnasio_simulado.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/modo_foco.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:habitos_dominio/habitos_dominio.dart';

import '../modulos/habitos/gimnasio/ayuda_gimnasio_app.dart';

const marca = 'G6-MARCA-RODILLA-ZZ9';

/// Todo lo que la base local guarda, como texto (cada tabla, cada fila).
Future<String> volcarBase(Mundo m) async {
  final tablas = await m.base
      .customSelect(
        "select name from sqlite_master where type = 'table' "
        "and name not like 'sqlite_%'",
      )
      .get();
  final b = StringBuffer();
  for (final t in tablas) {
    final nombre = t.read<String>('name');
    final filas = await m.base.customSelect('select * from "$nombre"').get();
    for (final f in filas) {
      b.writeln('$nombre ${jsonEncode(f.data, toEncodable: (o) => '$o')}');
    }
  }
  return b.toString();
}

void main() {
  late Mundo m;
  setUp(() => m = Mundo());
  tearDown(() => m.cerrar());

  group('G6 · una molestia no sale del equipo en una sesión completa', () {
    late ServidorGimnasioSimulado servidor;
    late SupabaseClient cliente;
    late ColaSinConexion cola;
    late RepositorioGimnasio repo;
    late ServicioGimnasio servicio;

    setUp(() async {
      servidor = await ServidorGimnasioSimulado.iniciar();
      cliente = await servidor.cliente(persona);
      cola = ColaSinConexion(
        base: m.base,
        enviador: EnviadorSupabase(
          cliente,
          tablas: const {},
          upserts: destinosUpsertGimnasio,
          borrados: borradosGimnasio,
        ),
        reloj: () => m.ahoraActual,
      );
      repo = RepositorioGimnasio(m.base, cola: cola, reloj: () => m.ahoraActual);
      servicio = ServicioGimnasio(
        repo: repo,
        persona: persona,
        agenda: m.agenda,
        registros: m.registros,
        molestias: m.molestias,
        ahora: () => m.ahoraActual,
      );
    });

    tearDown(() async {
      await cola.cerrar();
      await cliente.dispose();
      await servidor.cerrar();
    });

    test(
      'ni la nota, ni la zona, ni la palabra «molestia» llegan a base, cola, '
      'almacén, avisos ni a lo que recibe el servidor',
      () async {
        await m.molestias.guardar(
          Molestia(
            id: 'm1',
            zona: Zonas.rodilla,
            intensidad: 2,
            desde: DateTime.utc(2026, 11, 20),
            nota: marca,
          ),
        );
        // Lunes A y martes C (la rodilla sí carga la C).
        for (final dia in [DateTime(2026, 11, 30), DateTime(2026, 12, 1)]) {
          final d = await servicio.cargar();
          final h = await servicio.entrenamientoDe(dia, datos: d);
          final fila = await servicio.iniciarSesion(h);
          final c = ControladorSesion(
            servicio: servicio,
            hoy: h,
            fila: fila,
            datos: d,
            ahora: () => m.ahoraActual,
          );
          await c.inicializar();
          c.listo();
          // Cambiar de ejercicio «por precaución»: el motivo local es
          // «molestia»; lo que viaja debe ser «otra».
          final alts = c.actual.alternativas;
          if (alts.isNotEmpty) {
            await c.cambiarEjercicio(
              alts.first,
              motivo: MotivoCambioLocal.molestia,
            );
          }
          await c.hecha();
          await c.hecha();
          await c.terminar(completa: false, esfuerzo: 4, energia: 3);
          c.dispose();
        }

        // Antes de subir: base local y cola.
        final base = await volcarBase(m);
        final enCola = (await cola.registros())
            .map((p) => '${p.tipo} ${p.carga}')
            .join('\n');
        expect(enCola, contains('habitos.gim_serie'));
        expect(enCola, contains('habitos.gim_sesion'));
        // Se sube todo al servidor simulado y se mira lo que RECIBIÓ.
        await cola.procesar();
        final recibido = servidor.peticiones
            .map((p) => '${p.metodo} ${p.uri} ${jsonEncode(p.cuerpo)}')
            .join('\n');
        expect(recibido, contains('hab_ent_series'));
        expect(recibido, contains('"motivo_cambio":"otra"'));
        final almacen = m.almacen.datos.entries
            .map((e) => '${e.key}=${e.value}')
            .join('\n');

        final todo = '$base\n$enCola\n$recibido\n$almacen'.toLowerCase();
        expect(todo, isNot(contains(marca.toLowerCase())),
            reason: 'la nota de la molestia salió del almacén cifrado');
        for (final prohibida in ['molest', 'rodilla', 'dolor', 'zona']) {
          for (final (donde, texto) in [
            ('la base local', base),
            ('la cola de subida', enCola),
            ('lo que recibe el servidor', recibido),
          ]) {
            expect(
              texto.toLowerCase(),
              isNot(contains(prohibida)),
              reason: '$donde habla de «$prohibida»',
            );
          }
        }
        // El almacén seguro guarda el sobre cifrado: la nota no está en claro.
        expect(almacen.toLowerCase(), isNot(contains(marca.toLowerCase())));
        // Ninguna petición fue a una tabla o función de molestias.
        for (final p in servidor.peticiones) {
          expect(p.uri.path, isNot(contains('molest')));
          expect(p.uri.path, isNot(contains('hab_sobres')));
        }
      },
    );

    test('las notificaciones del descanso no llevan nombres, cargas ni dígitos',
        () {
      expect(TextoAvisoGimnasio.descanso.length, lessThanOrEqualTo(40));
      expect(RegExp(r'\d').hasMatch(TextoAvisoGimnasio.descanso), isFalse);
    });
  });

  group('G6-M2 · el modo foco deja una huella en el servidor', () {
    test(
      'una sesión en semana de foco sube semana_tipo = foco (decisión del dueño '
      'pendiente: la fecha del foco sale de un hábito a eliminar)',
      () async {
        final enFoco = Mundo(
          foco: ModoFocoDeRangos([
            RangoFoco(DateTime.utc(2026, 11, 28), DateTime.utc(2026, 12, 4)),
          ]),
        );
        addTearDown(enFoco.cerrar);
        final d = await enFoco.servicio.cargar();
        final h = await enFoco.servicio.entrenamientoDe(
          DateTime(2026, 11, 30),
          datos: d,
        );
        final fila = await enFoco.servicio.iniciarSesion(h);
        expect(fila.semanaTipo, 'foco');
        // Lo que se encola y se sube es exactamente esta fila.
        expect(fila.aMapaServidor()['semana_tipo'], 'foco');
      },
    );
  });

  group('G6-A1 · aviso de dormir con la hora pasada de medianoche', () {
    test(
      'dormir a las 00:30: una sesión que termina a las 20:15 NO debe avisar',
      () {
        final aviso = avisoDormir(finMin: 20 * 60 + 15, dormirMin: 30);
        expect(
          aviso,
          isNull,
          reason:
              'quedan más de 4 horas hasta dormir (00:30 del día siguiente); '
              'hoy devuelve ${aviso?.minutosAntesDeDormir} min',
        );
      },
      tags: 'hallazgo',
    );

    test('control: con dormir a las 22:00 el aviso sale como en la especificación',
        () {
      expect(avisoDormir(finMin: 20 * 60 + 15, dormirMin: 22 * 60), isNull);
      expect(
        avisoDormir(finMin: 21 * 60 + 30, dormirMin: 22 * 60)
            ?.minutosAntesDeDormir,
        30,
      );
    });
  });

  test('el equipo del teléfono admite molestias; la laptop y la pública no', () {
    final lap = Mundo(equipo: TipoEquipoAvisos.laptop);
    addTearDown(lap.cerrar);
    expect(lap.molestias.equipoLasAdmite(), isFalse);
  });
}
