// La cola llama funciones del servidor (hab_subir_sobres) sin tratar los
// sobres como filas del libro y sin escribir su contenido en los errores.
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/enviador_supabase.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'postgrest_simulado.dart';

void main() {
  late PostgrestSimulado servidor;
  late SupabaseClient cliente;
  late BaseLocal base;
  final ahora = DateTime(2026, 11, 1, 20);
  final respuestas = <(String, Object?)>[];

  ColaSinConexion cola() => ColaSinConexion(
    base: base,
    reloj: () => ahora,
    enviador: EnviadorSupabase(
      cliente,
      tablas: const {},
      funciones: const {tipoColaSobres: funcionSubirSobres},
      alResponderFuncion: (t, r) => respuestas.add((t, r)),
    ),
  );

  setUp(() async {
    servidor = await PostgrestSimulado.iniciar();
    cliente = await servidor.cliente('uid-ana');
    base = BaseLocal.enMemoria();
    respuestas.clear();
  });
  tearDown(() async {
    await base.close();
    await servidor.cerrar();
  });

  test('un lote de sobres llama a hab_subir_sobres con p_sobres y entrega la '
      'respuesta (conflictos)', () async {
    servidor.respuestasDeFunciones['hab_subir_sobres'] = {
      'conflictos': <Object?>[],
    };
    final c = cola();
    await c.encolar(
      tipo: tipoColaSobres,
      personaId: 'ana',
      carga: {
        'p_sobres': [
          {
            'id': 'a',
            'tipo': 'diario_oracion',
            'revision': 1,
            'cifrado': 'AAAA',
          },
        ],
      },
    );
    final r = await c.procesar();
    expect(r.enviados, 1);
    final p = servidor.peticiones.single;
    expect(p.uri.path, endsWith('/rpc/hab_subir_sobres'));
    expect((p.cuerpo as Map)['p_sobres'], hasLength(1));
    expect(respuestas.single.$1, tipoColaSobres);
    expect(respuestas.single.$2, {'conflictos': <Object?>[]});
  });

  test(
    'un rechazo del servidor no deja el contenido en el mensaje de error',
    () async {
      servidor.fallar(
        'hab_subir_sobres',
        const ErrorForzado(
          '42501',
          'permiso denegado AAAA-secreto',
          estado: 403,
        ),
      );
      final c = cola();
      await c.encolar(
        tipo: tipoColaSobres,
        personaId: 'ana',
        carga: {
          'p_sobres': [
            {
              'id': 'a',
              'tipo': 'diario_oracion',
              'revision': 1,
              'cifrado': 'AAAA-secreto',
            },
          ],
        },
      );
      final r = await c.procesar();
      expect(r.rechazados, 1);
      for (final reg in await c.registros()) {
        expect('${reg.ultimoError}', isNot(contains('secreto')));
      }
    },
  );
}
