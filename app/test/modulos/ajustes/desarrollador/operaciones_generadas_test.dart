import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/ajustes/desarrollador/operacion_api.dart';
import 'package:gravity/modulos/ajustes/desarrollador/operaciones.g.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

const _comoRegenerar =
    'operaciones.g.dart no coincide con api/openapi.yaml. '
    'Corre en api/: npm install && npm run generar';

/// Raíz del repositorio: la primera carpeta hacia arriba con api/openapi.yaml.
Directory _raiz() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/api/openapi.yaml').existsSync()) return dir;
    final padre = dir.parent;
    if (padre.path == dir.path) {
      throw StateError(
        'No encontré api/openapi.yaml desde ${Directory.current.path}',
      );
    }
    dir = padre;
  }
}

/// La misma huella que api/generar_dart.mjs: FNV-1a de 32 bits sobre UTF-8,
/// con saltos de línea \n.
/// RPC de la base de datos que solo leen (no piden confirmación).
const _rpcDeLectura = {
  'misPermisos',
  'finPuede',
  'finPuedeHogar',
  'finEsMiembro',
  'esCuentaMaestra',
  'cuentaMaestra',
  'finLunes',
  'finSoloLectura',
  'finPuedeSalir',
  'finAdultosConFinanzas',
  // Fase 8 (migración 20261132): rango del periodo y aportación calculada; no
  // escriben (la aportación solo lee y suma).
  'finPeriodoRango',
  'finCasaAportacion',
  'finDeudasPuedeVer',
  'finSimularEstrategias',
  'finEstimarIntereses',
  // Migración 20261136: avance de un objetivo (solo lee y calcula).
  'finObjetivoAvance',
  // D24: preguntas sobre la vista temporal de Papá (no escriben).
  'finVistaPapaVigente',
  'finVistaVigenteHogar',
  'finVistaVigenteLibro',
  'avisosPorcentajeBase',
  'habActiva',
  'habHogarDe',
  // Migración 20261138: análisis del historial de compra (solo lectura).
  'aliHistorialCompras',
  'aliResumenHistorial',
  // Fase 5: preguntas y resúmenes de Cuidados (no escriben).
  'cuiPerfil',
  'cuiPuede',
  'cuiQuienEnTurno',
  'cuiResumenMensual',
  'cuiResumenPapa',
};

/// Libros solo-agregar de Finanzas: no tienen PATCH ni DELETE.
const _soloAgregar = {
  'fin_movimientos',
  'fin_conciliaciones',
  'fin_cierres',
  'fin_cierre_partidas',
  'fin_cierre_abonos',
  'fin_importaciones',
};

/// El texto de la ruta [ruta] en el YAML (todas sus operaciones y respuestas).
String _bloque(String yaml, String ruta) {
  final inicio = yaml.indexOf('\n  $ruta:\n');
  expect(inicio, isNonNegative, reason: 'No encontré $ruta en openapi.yaml');
  final siguiente = RegExp(r'\n  (?:/|\#)|\ncomponents:')
      .firstMatch(yaml.substring(inicio + 1));
  return yaml.substring(
    inicio,
    siguiente == null ? yaml.length : inicio + 1 + siguiente.start,
  );
}

/// El mismo texto con los espacios y saltos de línea colapsados, para buscar
/// frases sin depender de cómo se partió la línea en el YAML.
String _plano(String texto) => texto.replaceAll(RegExp(r'\s+'), ' ');

String _huella(String texto) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(texto.replaceAll('\r\n', '\n'))) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return 'fnv1a32:${h.toRadixString(16).padLeft(8, '0')}';
}

void main() {
  final raiz = _raiz();
  final yaml = File('${raiz.path}/api/openapi.yaml').readAsStringSync();
  final operaciones = [for (final g in gruposOperaciones) ...g.operaciones];

  test('la huella del archivo generado coincide con openapi.yaml', () {
    expect(_huella('abc'), 'fnv1a32:1a47e90b', reason: 'FNV-1a de referencia');
    expect(huellaEspecificacion, _huella(yaml), reason: _comoRegenerar);
  });

  test('la copia para Swagger UI (especificacion.js) también está al día', () {
    final js = File('${raiz.path}/api/swagger/especificacion.js')
        .readAsStringSync();
    final huellaJs = RegExp(r'// huella: (fnv1a32:[0-9a-f]{8})')
        .firstMatch(js)
        ?.group(1);
    expect(huellaJs, _huella(yaml), reason: _comoRegenerar);
  });

  test('las operaciones generadas son las de openapi.yaml', () {
    final ids = RegExp(
      r'^\s+operationId:\s*(\S+)\s*$',
      multiLine: true,
    ).allMatches(yaml).map((m) => m.group(1)).toList();
    expect(operaciones.map((o) => o.id).toList()..sort(), ids..sort());
    for (final o in operaciones) {
      expect(yaml, contains('\n  ${o.ruta}:\n'), reason: o.ruta);
      expect(o.roles, isNotEmpty, reason: o.id);
      expect(o.resumen, isNotEmpty, reason: o.id);
    }
    expect(gruposOperaciones.map((g) => g.nombre), [
      'Herramientas de GRAVITY',
      'Base de datos',
      'Base de datos · Finanzas',
      'Base de datos · Hábitos',
      'Base de datos · Cuidados',
      'Funciones del servidor',
      'Puente de casa',
    ]);
  });

  test('cada herramienta registrada está documentada igual (D1, D16)', () {
    final porRuta = {for (final o in operaciones) o.ruta: o};
    final registradas = registroDeGravity().todas;
    final deFase1 = herramientasFase1().map((h) => h.nombre).toSet();
    for (final h in registradas) {
      final o = porRuta['/herramientas/${h.nombre}'];
      expect(o, isNotNull, reason: '${h.nombre} no está en openapi.yaml');
      expect(o!.metodo, MetodoHttp.post, reason: h.nombre);
      expect(o.roles, h.roles, reason: '${h.nombre}: x-roles');
      expect(o.escribe, h.escribe, reason: '${h.nombre}: x-escribe');
      expect(o.soloLocal, h.soloLocal, reason: '${h.nombre}: x-solo-local');
      expect(
        o.fase,
        h.nombre.startsWith('finanzas.') &&
                const {
                  'finanzas.resumen_semana',
                  'finanzas.proximos_pagos',
                  'finanzas.ahorro_avance',
                }.contains(h.nombre)
            ? 2
            : herramientasFase3().any((x) => x.nombre == h.nombre)
            ? 3
            : deFase1.contains(h.nombre)
            ? 1
            : 0,
        reason: '${h.nombre}: x-fase',
      );
    }
    final documentadas = operaciones
        .where(
          (o) => o.ruta.startsWith('/herramientas/') && !o.ruta.contains('{'),
        )
        .map((o) => o.ruta.substring('/herramientas/'.length));
    expect(
      documentadas.toSet(),
      registradas.map((h) => h.nombre).toSet(),
      reason: 'openapi.yaml documenta una herramienta que no existe',
    );
  });

  test(
    'en la base de datos todo escribe con confirmación y nada va a la IA',
    () {
      final base = gruposOperaciones.where(
        (g) => g.nombre.startsWith('Base de datos'),
      );
      expect(base, hasLength(4));
      for (final o in base.expand((g) => g.operaciones)) {
        expect(o.soloLocal, isTrue, reason: o.id);
        final esLectura =
            o.metodo == MetodoHttp.get || _rpcDeLectura.contains(o.id);
        expect(o.escribe, !esLectura, reason: o.id);
      }
    },
  );

  group('Finanzas (Fase 1, D3, D19)', () {
    final finanzas = gruposOperaciones
        .firstWhere((g) => g.nombre == 'Base de datos · Finanzas')
        .operaciones;
    final migracion = File(
      '${raiz.path}/supabase/migrations/20261021000000_finanzas_mvp1.sql',
    ).readAsStringSync();

    test('la muestra de la Fase 0 ya no existe', () {
      expect(migracion, contains('drop table public.finanzas_muestra'));
      expect(yaml, isNot(contains('finanzas_muestra')));
      expect(operaciones.where((o) => o.ruta.contains('muestra')), isEmpty);
    });

    test('cada tabla y vista fin_* de la migración está documentada', () {
      final tablas = RegExp(r'create (?:table|view) public\.(fin_\w+)')
          .allMatches(migracion)
          .map((m) => m.group(1)!)
          .toSet();
      expect(tablas, hasLength(23));
      final rutas = finanzas.map((o) => o.ruta).toSet();
      for (final tabla in tablas) {
        expect(rutas, contains('/rest/v1/$tabla'), reason: tabla);
      }
    });

    test('las funciones de Finanzas y de la cuenta maestra están documentadas '
        'y existen en la migración', () {
      const funciones = {
        'fin_puede': 'finPuede',
        'fin_puede_hogar': 'finPuedeHogar',
        'fin_es_miembro': 'finEsMiembro',
        'es_cuenta_maestra': 'esCuentaMaestra',
        'fin_registrar_consulta_maestra': 'finRegistrarConsultaMaestra',
        'cuenta_maestra': 'cuentaMaestra',
        'asignar_cuenta_maestra': 'asignarCuentaMaestra',
        'fin_crear_libro_representado': 'finCrearLibroRepresentado',
        'fin_lunes': 'finLunes',
      };
      final porRuta = {for (final o in finanzas) o.ruta: o};
      for (final MapEntry(key: funcion, value: id) in funciones.entries) {
        expect(
          migracion,
          contains('create function public.$funcion('),
          reason: funcion,
        );
        final o = porRuta['/rest/v1/rpc/$funcion'];
        expect(o, isNotNull, reason: funcion);
        expect(o!.id, id);
        expect(o.metodo, MetodoHttp.post, reason: funcion);
      }
    });

    test('nada de Finanzas va a la IA (D3) y solo es de dueño y pareja', () {
      const deTodos = {'esCuentaMaestra', 'cuentaMaestra'};
      const soloDueno = {
        'asignarCuentaMaestra',
        'finCrearLibroRepresentado',
        'finNombrarAlbacea',
        'finResponderVista',
        // Fase 8 (migración 20261133): «Solo el dueño fija la referencia».
        'finCasaFijarReferencia',
      };
      // D24 (fase 4): el familiar pide y consulta la vista temporal de Papá;
      // el dueño la autoriza. Es la única excepción a «solo dueño y pareja».
      const soloFamiliar = {
        'finPedirVistaPapa',
        'finVistaPapaVigente',
        'finVistaVigenteHogar',
        'finVistaVigenteLibro',
        'finRegistrarConsultaVista',
      };
      for (final o in finanzas) {
        expect(o.soloLocal, isTrue, reason: o.id);
        // 8 = ampliaciones de Finanzas (transferencias y casa, migraciones
        // 20261132 y 20261133; docs/specs/fase-8-finanzas-ampliaciones.md).
        expect(o.fase, anyOf(1, 2, 4, 8), reason: o.id);
        if (deTodos.contains(o.id)) {
          expect(o.roles, Rol.values.toSet(), reason: o.id);
        } else if (soloDueno.contains(o.id)) {
          expect(o.roles, {Rol.dueno}, reason: o.id);
        } else if (o.id == 'leerFinVistasSolicitadas') {
          // El familiar lee las suyas y el dueño las del hogar (D24).
          expect(o.roles, {Rol.dueno, Rol.familiar}, reason: o.id);
        } else if (soloFamiliar.contains(o.id)) {
          expect(o.roles, {Rol.familiar}, reason: o.id);
        } else {
          expect(o.roles, {Rol.dueno, Rol.coadministrador}, reason: o.id);
        }
      }
    });

    group('salvaguardas de 20261023000000_finanzas_salvaguardas.sql', () {
      final salvaguardas = File(
        '${raiz.path}/supabase/migrations/'
        '20261023000000_finanzas_salvaguardas.sql',
      ).readAsStringSync();

      test('I2: la consulta de la cuenta maestra (boolean, 30 minutos, vacío '
          'sin error) coincide con la migración', () {
        expect(salvaguardas, contains("interval '30 minutes'"));
        expect(salvaguardas, contains("'finanzas.consulta_maestra'"));
        final consulta = _bloque(
          yaml,
          '/rest/v1/rpc/fin_registrar_consulta_maestra',
        );
        expect(consulta, contains('30 minutos'));
        expect(consulta, contains('sin error'));
        expect(consulta, contains('type: boolean'));
        expect(consulta, contains('`false`'));
        expect(consulta, contains('finanzas.consulta_maestra'));
        expect(consulta, contains('42501'));
        // La portada (libros y miembros) se ve sin consulta; el contenido no.
        for (final ruta in ['fin_libros', 'fin_libro_miembros']) {
          expect(
            _plano(_bloque(yaml, '/rest/v1/$ruta')),
            contains('sin consulta'),
            reason: ruta,
          );
        }
        for (final ruta in [
          'fin_movimientos',
          'fin_cuentas',
          'fin_semanas',
          'fin_cierres',
          'fin_v_saldos',
        ]) {
          expect(
            _plano(_bloque(yaml, '/rest/v1/$ruta')),
            contains('ve vacío'),
            reason: ruta,
          );
        }
      });

      test('I5: la bitácora reserva al servidor las acciones finanzas* y las '
          'tablas fin_* para todo rol de la app', () {
        expect(salvaguardas, contains("accion !~* '^\\s*finanzas'"));
        expect(salvaguardas, contains('fin_'));
        final bitacora = _bloque(yaml, '/rest/v1/bitacora');
        expect(bitacora, contains('empiece por\n        `finanzas`'));
        expect(bitacora, contains('`fin_*`'));
        expect(bitacora, contains('42501'));
        expect(bitacora, contains("pattern: '^finanzas'"));
        // Las tres acciones que deja el servidor, con su ejemplo de lectura.
        for (final accion in [
          'finanzas.consulta_maestra',
          'finanzas.maestra_asignada',
          'finanzas.salida_libro_representado',
        ]) {
          expect(salvaguardas, contains("'$accion'"), reason: accion);
          expect(bitacora, contains('accion: $accion'), reason: accion);
          expect(yaml, contains('- $accion'), reason: accion);
        }
      });

      test('I3: el libro de Papá exige en_nombre_de y motivo (23514) y la '
          'salida a un libro personal deja su entrada', () {
        expect(salvaguardas, contains("errcode = '23514'"));
        expect(salvaguardas, contains('en_nombre_de'));
        expect(salvaguardas, contains("'finanzas.salida_libro_representado'"));
        final movimientos = _bloque(yaml, '/rest/v1/fin_movimientos');
        expect(movimientos, contains('`en_nombre_de`'));
        expect(movimientos, contains('`motivo`'));
        expect(movimientos, contains('23514'));
        expect(movimientos, contains('finanzas.salida_libro_representado'));
        expect(movimientos, contains('salida:'));
      });

      test('M10: asignar la cuenta maestra deja finanzas.maestra_asignada', () {
        expect(salvaguardas, contains("'finanzas.maestra_asignada'"));
        final asignar = _bloque(yaml, '/rest/v1/rpc/asignar_cuenta_maestra');
        expect(asignar, contains('finanzas.maestra_asignada'));
        expect(asignar, contains('anterior_persona_id'));
        expect(asignar, contains('nueva_persona_id'));
      });

      test('I1: los miembros de un libro compartido (42501 y 22023)', () {
        expect(
          salvaguardas,
          contains('Un libro compartido no baja de 2 miembros'),
        );
        final miembros = _bloque(yaml, '/rest/v1/fin_libro_miembros');
        expect(miembros, contains('42501'));
        expect(miembros, contains('22023'));
        expect(miembros, contains('2 miembros vigentes'));
      });

      test('M6: la maestra que no es la dueña no cambia la configuración del '
          'hogar', () {
        expect(salvaguardas, contains("<> 'dueno'"));
        for (final ruta in [
          'fin_categorias',
          'fin_cuentas',
          'fin_dias_inhabiles',
          'fin_importaciones',
          'rpc/fin_puede_hogar',
        ]) {
          expect(
            _bloque(yaml, '/rest/v1/$ruta'),
            contains('(M6)'),
            reason: ruta,
          );
        }
      });

      test('ninguna función nueva es llamable desde la API: las internas no '
          'tienen operación', () {
        final revoke = RegExp(
          r'revoke execute on function([^;]*?)\s+from public, anon, '
          r'authenticated, service_role;',
          dotAll: true,
        ).firstMatch(salvaguardas)!.group(1)!;
        final internas = RegExp(r'public\.(\w+)\(')
            .allMatches(revoke)
            .map((m) => m.group(1)!)
            .toSet();
        expect(internas, {
          'fin_vigencia_consulta_maestra',
          'fin_adulto_con_finanzas',
          'fin_libro_miembros_proteger',
          'fin_movimientos_representado',
          'fin_movimientos_salida_representado',
        });
        // Las que crea esta migración (no `or replace`) son todas internas.
        final nuevas = RegExp(r'create function public\.(\w+)\(')
            .allMatches(salvaguardas)
            .map((m) => m.group(1)!)
            .toSet();
        expect(nuevas, internas);
        for (final nombre in internas) {
          expect(yaml, isNot(contains('/rpc/$nombre')), reason: nombre);
          expect(
            operaciones.map((o) => o.ruta),
            isNot(contains('/rest/v1/rpc/$nombre')),
            reason: nombre,
          );
        }
      });
    });

    group('respuestas del dueño de 20261024000000_finanzas_respuestas_dueno.sql', () {
      final respuestas = File(
        '${raiz.path}/supabase/migrations/'
        '20261024000000_finanzas_respuestas_dueno.sql',
      ).readAsStringSync();

      /// Nombres de funciones (`public.x(`) de las sentencias que empiezan con
      /// [inicio] y terminan en [fin].
      Set<String> funciones(String inicio, String fin) => {
        for (final m in RegExp(
          '$inicio([^;]*?)$fin',
          dotAll: true,
        ).allMatches(respuestas))
          for (final f in RegExp(r'public\.(\w+)\(').allMatches(m.group(1)!))
            f.group(1)!,
      };

      test('fin_libros.visibilidad: privada por omisión, solo compartidos; '
          'creado_por no lo manda la app', () {
        expect(
          respuestas,
          contains("check (visibilidad in ('privada', 'publica'))"),
        );
        expect(respuestas, contains("default 'privada'"));
        expect(
          respuestas,
          contains("tipo = 'compartido' or visibilidad = 'privada'"),
        );
        // creado_por no está en los privilegios de INSERT ni de UPDATE.
        final privilegios = RegExp(
          r'grant insert \(([^)]*)\),\s*update \(([^)]*)\)\s*on public\.fin_libros',
        ).firstMatch(respuestas)!;
        for (final i in [1, 2]) {
          expect(privilegios.group(i), contains('visibilidad'));
          expect(privilegios.group(i), isNot(contains('creado_por')));
        }
        expect(
          respuestas,
          contains(
            "'El administrador de un libro lo cambia solo el servidor.'",
          ),
        );

        final libros = _plano(_bloque(yaml, '/rest/v1/fin_libros'));
        expect(libros, contains('`visibilidad`'));
        expect(libros, contains('`publica`'));
        expect(libros, contains('`privada`'));
        expect(libros, contains('mandar `creado_por` responde 403 (42501)'));
        expect(libros, contains('solo quien lo creó cambia la `visibilidad`'));
        final esquema = _plano(yaml);
        expect(esquema, contains('enum: [privada, publica] default: privada'));
        expect(esquema, contains('El administrador del libro (quien lo creó)'));
      });

      test(
        'quitar a otro, reactivar y el relevo siguen la migración (la salida '
        'la cambió 20261025)',
        () {
          // El orden del relevo es el de la migración; el efecto de salirse con
          // menos de 2 miembros lo reemplazó 20261025000000 (ver su grupo).
          expect(respuestas, contains('order by m.desde, m.id'));
          final miembros = _plano(_bloque(yaml, '/rest/v1/fin_libro_miembros'));
          expect(
            miembros,
            contains('**salirse** es un `PATCH` a la propia fila'),
          );
          expect(miembros, contains('`hasta` = ahora'));
          expect(miembros, contains('pasa al miembro vigente más antiguo'));
          expect(miembros, contains('ni con `upsert`'));
          expect(miembros, contains('403 (42501)'));
          expect(miembros, contains('400, 22023'));
          expect(miembros, contains('2 miembros vigentes'));
          final libros = _plano(_bloque(yaml, '/rest/v1/fin_libros'));
          expect(
            libros,
            contains('lo archiva (`activo: false`) o lo reactiva'),
          );
          expect(libros, contains('archivado es de solo lectura'));
        },
      );

      test('un libro archivado rechaza movimientos', () {
        expect(respuestas, contains('-- archivado: solo lectura'));
        final movimientos = _plano(_bloque(yaml, '/rest/v1/fin_movimientos'));
        expect(
          movimientos,
          contains(
            'Un libro archivado (`fin_libros.activo` = `false`) rechaza',
          ),
        );
        expect(movimientos, contains('403 (42501)'));
        expect(
          _plano(_bloque(yaml, '/rest/v1/rpc/fin_puede')),
          contains('(archivado = solo lectura)'),
        );
      });

      test('crear_invitacion(..., p_es_maestra) e invitaciones.es_maestra', () {
        expect(respuestas, contains('p_es_maestra boolean default false'));
        expect(
          respuestas,
          contains("check (not es_maestra or rol = 'coadministrador')"),
        );
        expect(
          respuestas,
          contains('La cuenta maestra se invita con el rol coadministrador.'),
        );
        expect(
          respuestas,
          contains('Ese correo ya es de un miembro del hogar'),
        );
        final invitar = _plano(_bloque(yaml, '/rest/v1/rpc/crear_invitacion'));
        expect(invitar, contains('p_es_maestra:'));
        expect(invitar, contains('type: boolean default: false'));
        expect(invitar, contains('`p_es_maestra: true`'));
        expect(invitar, contains('El rol debe ser `coadministrador`'));
        expect(
          invitar,
          contains('no puede ser el de un miembro vigente del hogar'),
        );
        expect(invitar, contains('400, 22023'));
        expect(
          _plano(_bloque(yaml, '/rest/v1/invitaciones')),
          contains('es_maestra'),
        );
        expect(
          _plano(yaml),
          contains(
            'es_maestra: type: boolean default: false description: >- Invitación a la cuenta maestra',
          ),
        );
        final aceptar = _plano(
          _bloque(yaml, '/rest/v1/rpc/aceptar_invitacion'),
        );
        expect(aceptar, contains('finanzas.maestra_asignada'));
        expect(aceptar, contains('invitada_por'));
        final acciones = RegExp(r"'(finanzas\.[a-z_]+)'")
            .allMatches(respuestas)
            .map((m) => m.group(1)!)
            .toSet();
        // Las únicas acciones que escribe (o lee) esta migración ya estaban
        // documentadas: no agrega acciones de bitácora nuevas.
        expect(acciones, {
          'finanzas.consulta_maestra',
          'finanzas.maestra_asignada',
        });
        for (final accion in acciones) {
          expect(_plano(_bloque(yaml, '/rest/v1/bitacora')), contains(accion));
        }
      });

      test('la maestra que no es la dueña es de solo lectura total y no lleva '
          'libro', () {
        expect(
          respuestas,
          contains("public.rol_en_hogar(p_hogar_id) <> 'dueno'"),
        );
        expect(
          respuestas,
          contains('La cuenta maestra es solo lectura: no lleva libros.'),
        );
        expect(respuestas, contains('not public.fin_solo_lectura(hogar_id)'));
        final solo = _bloque(yaml, '/rest/v1/rpc/fin_solo_lectura');
        expect(solo, contains('operationId: finSoloLectura'));
        expect(solo, contains('x-solo-local: true'));
        final puede = _plano(_bloque(yaml, '/rest/v1/rpc/fin_puede'));
        expect(
          puede,
          contains(
            'La cuenta maestra que no es la dueña nunca escribe ni administra',
          ),
        );
        expect(
          _plano(_bloque(yaml, '/rest/v1/fin_libros')),
          contains('no crea libros (solo lectura total, 403, 42501)'),
        );
        expect(
          _plano(_bloque(yaml, '/rest/v1/fin_libro_miembros')),
          contains('no puede ser miembro de ningún libro (400, 22023'),
        );
        final asignar = _plano(
          _bloque(yaml, '/rest/v1/rpc/asignar_cuenta_maestra'),
        );
        expect(respuestas, contains('no puede llevar un libro propio'));
        expect(asignar, contains('que no lleve libro propio'));
        expect(asignar, contains('400 (22023'));
      });

      test('cuentas de periodo se archivan con saldo; archivar una categoría '
          'archiva su cuenta de gasto', () {
        expect(respuestas, contains("old.clase in ('activo', 'pasivo')"));
        expect(
          respuestas,
          contains('create function public.fin_categorias_archivar_cuenta()'),
        );
        final cuentas = _plano(_bloque(yaml, '/rest/v1/fin_cuentas'));
        expect(cuentas, contains('solo en las cuentas de activo y pasivo'));
        expect(cuentas, contains('400, 22023'));
        expect(cuentas, isNot(contains('55000).')));
        expect(
          _plano(_bloque(yaml, '/rest/v1/fin_categorias')),
          contains('Archivar una categoría archiva su cuenta de gasto'),
        );
        expect(
          _plano(_bloque(yaml, '/rest/v1/fin_movimientos')),
          contains('cuentas de gasto o ingreso archivadas'),
        );
      });

      test('las funciones que las reglas llaman son operaciones; las de '
          'triggers, no', () {
        final llamables = funciones(
          r'grant execute on function',
          r'to authenticated',
        );
        expect(llamables, {
          'crear_invitacion',
          'fin_solo_lectura',
          'fin_puede_salir',
        });
        final retiradas = funciones(
          r'revoke execute on function',
          r'from public, anon, authenticated, service_role',
        );
        final internas = retiradas.difference(llamables);
        expect(internas, {
          'fin_libro_miembros_sin_maestra',
          'fin_libros_proteger',
          'fin_categorias_archivar_cuenta',
        });
        final rutas = operaciones.map((o) => o.ruta).toSet();
        for (final nombre in llamables) {
          expect(rutas, contains('/rest/v1/rpc/$nombre'), reason: nombre);
        }
        for (final nombre in internas) {
          expect(
            rutas,
            isNot(contains('/rest/v1/rpc/$nombre')),
            reason: nombre,
          );
          expect(yaml, isNot(contains('/rpc/$nombre')), reason: nombre);
        }
      });
    });

    group('compartidos privados de 20261025000000_finanzas_compartidos_privados.sql', () {
      final privados = File(
        '${raiz.path}/supabase/migrations/'
        '20261025000000_finanzas_compartidos_privados.sql',
      ).readAsStringSync();

      test('salirse con menos de 2 miembros deja el libro activo y privado; '
          'ya no se archiva solo', () {
        // La migración: privado y sin tocar `activo`.
        expect(
          privados,
          contains("visibilidad = case when v_otros < 2 then 'privada'"),
        );
        expect(privados, isNot(contains('activo = case')));
        expect(privados, contains('NUNCA se archiva solo'));
        expect(privados, contains('order by m.desde, m.id'));

        final miembros = _plano(_bloque(yaml, '/rest/v1/fin_libro_miembros'));
        expect(miembros, contains('el libro **no se archiva**'));
        expect(
          miembros,
          contains('sigue `activo` y pasa a `visibilidad` = `privada`'),
        );
        expect(
          miembros,
          contains('el miembro que queda es el administrador (`creado_por`)'),
        );
        expect(
          miembros,
          contains('`creado_por` pasa al miembro vigente más antiguo'),
        );
        expect(
          miembros,
          contains(
            'cambio de `fin_libros` que hace el servidor queda en la bitácora',
          ),
        );
        // Y lo que se documentó antes del cambio ya no está.
        final todo = _plano(yaml);
        for (final viejo in [
          'el servidor archiva el libro',
          'lo archivan solos',
          'Un libro compartido no baja de 2 miembros vigentes"; para dejar de usarlo',
          'salirse siempre se puede',
        ]) {
          expect(todo, isNot(contains(viejo)), reason: viejo);
        }
        final libros = _plano(_bloque(yaml, '/rest/v1/fin_libros'));
        expect(
          libros,
          contains('Archivar es solo la decisión explícita del administrador'),
        );
        expect(libros, contains('nunca ocurre solo'));
        expect(libros, contains('Reactivarlo no exige 2 miembros'));
        expect(
          todo,
          contains(
            '`false` = archivado por su administrador (nunca ocurre solo)',
          ),
        );
        expect(
          todo,
          contains(
            'Pasa sola a `privada` cuando quedan menos de 2 miembros vigentes.',
          ),
        );
      });

      test('el último miembro no puede salirse (22023) ni lo saca nadie', () {
        expect(
          privados,
          contains(
            'El último miembro de un libro compartido no puede salirse.',
          ),
        );
        expect(privados, contains("errcode = '22023'"));
        expect(privados, contains('if v_otros = 0 then'));
        final miembros = _plano(_bloque(yaml, '/rest/v1/fin_libro_miembros'));
        expect(
          miembros,
          contains('El **último miembro vigente no puede salirse**'),
        );
        expect(
          miembros,
          contains(
            '"El último miembro de un libro compartido no puede salirse"',
          ),
        );
        expect(miembros, contains('400, 22023'));
        // La RPC de "puedo salirme" avisa que el servidor aún puede rechazarlo.
        final puedeSalir = _plano(
          _bloque(yaml, '/rest/v1/rpc/fin_puede_salir'),
        );
        expect(puedeSalir, contains('Si es el último miembro vigente'));
        expect(puedeSalir, contains('22023'));
      });

      test(
        'quitar a otro dejando menos de 2 ya no da 22023: pasa a privado',
        () {
          // La migración trata igual salirse que ser sacado (ya no hay un
          // `elsif v_otros < 2 then raise` solo para el que saca a otro).
          expect(privados, isNot(contains('elsif v_otros < 2')));
          expect(
            privados,
            contains('Quitar a otro dejando menos de 2 se trata igual'),
          );
          final miembros = _plano(_bloque(yaml, '/rest/v1/fin_libro_miembros'));
          expect(
            miembros,
            contains(
              'Si al salir (o al sacar a alguien) quedan menos de 2 miembros vigentes',
            ),
          );
          expect(miembros, isNot(contains('nunca deja menos de 2')));
        },
      );

      test('fin_adultos_con_finanzas(hogar) -> (persona_id, nombre_visible, '
          'rol): solo authenticated, sin la maestra no dueña', () {
        expect(
          privados,
          contains(
            'create function public.fin_adultos_con_finanzas(p_hogar_id uuid)',
          ),
        );
        expect(
          privados,
          contains(
            'returns table (persona_id uuid, nombre_visible text, rol text)',
          ),
        );
        expect(
          privados,
          contains("and not (m.es_maestra and m.rol <> 'dueno')"),
        );
        expect(
          privados,
          contains(
            'revoke execute on function public.fin_adultos_con_finanzas(uuid) from public, anon, authenticated, service_role;',
          ),
        );
        expect(
          privados,
          contains(
            'grant execute on function public.fin_adultos_con_finanzas(uuid) to authenticated;',
          ),
        );
        final adultos = operaciones.singleWhere(
          (o) => o.ruta == '/rest/v1/rpc/fin_adultos_con_finanzas',
        );
        expect(adultos.id, 'finAdultosConFinanzas');
        expect(adultos.metodo, MetodoHttp.post);
        expect(adultos.roles, {Rol.dueno, Rol.coadministrador});
        expect(adultos.escribe, isFalse);
        expect(adultos.soloLocal, isTrue);
        expect(adultos.fase, 1);
        final bloque = _plano(
          _bloque(yaml, '/rest/v1/rpc/fin_adultos_con_finanzas'),
        );
        expect(
          bloque,
          contains('Nunca devuelve familiar, cuidador ni Casa, ni a Papá'),
        );
        expect(bloque, contains('ni la cuenta maestra que no es la dueña'));
        expect(bloque, contains('cero filas, sin error'));
        expect(
          bloque,
          contains(
            '`#/components/schemas/FinAdultoConFinanzas`'.replaceAll('`', "'"),
          ),
        );
        // El esquema de la fila.
        final esquema = _plano(yaml);
        expect(
          esquema,
          contains(
            'FinAdultoConFinanzas: type: object description: Una fila de `fin_adultos_con_finanzas`. properties: persona_id: \$ref: \'#/components/schemas/Uuid\' nombre_visible: type: string maxLength: 80 rol: type: string enum: [dueno, coadministrador]',
          ),
        );
      });

      test('toda función fin_* que las migraciones conceden a authenticated '
          'tiene operación', () {
        final migraciones = Directory('${raiz.path}/supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'));
        final llamables = <String>{
          for (final f in migraciones)
            for (final m in RegExp(
              r'grant execute on function([^;]*?)\bto authenticated',
              dotAll: true,
            ).allMatches(f.readAsStringSync()))
              for (final fn in RegExp(
                r'public\.(fin_\w+)\(',
              ).allMatches(m.group(1)!))
                fn.group(1)!,
        };
        expect(
          llamables,
          containsAll(<String>{
            'fin_puede',
            'fin_puede_hogar',
            'fin_es_miembro',
            'fin_lunes',
            'fin_registrar_consulta_maestra',
            'fin_crear_libro_representado',
            'fin_solo_lectura',
            'fin_puede_salir',
            'fin_adultos_con_finanzas',
            'fin_nombrar_albacea',
            'fin_emitir_aviso',
          }),
        );
        final rutas = operaciones.map((o) => o.ruta).toSet();
        for (final nombre in llamables) {
          expect(rutas, contains('/rest/v1/rpc/$nombre'), reason: nombre);
        }
      });
    });

    group(
      'endurecimiento de 20261026000000_finanzas_endurecimiento_1b.sql',
      () {
        final endurecimiento = File(
          '${raiz.path}/supabase/migrations/'
          '20261026000000_finanzas_endurecimiento_1b.sql',
        ).readAsStringSync();

        test(
          'N1: el tope de la bitácora (54000, 4 KB, 500 en 24 horas) coincide '
          'con la migración',
          () {
            expect(endurecimiento, contains("errcode = '54000'"));
            expect(
              endurecimiento,
              contains('c_max_entradas constant integer := 500'),
            );
            expect(
              endurecimiento,
              contains('c_max_bytes    constant integer := 4096'),
            );
            expect(endurecimiento, contains("interval '24 hours'"));
            expect(
              endurecimiento,
              contains("if current_user <> 'authenticated' then"),
            );
            final bitacora = _plano(_bloque(yaml, '/rest/v1/bitacora'));
            expect(bitacora, contains('4 KB'));
            expect(bitacora, contains('500 entradas propias en 24 horas'));
            expect(bitacora, contains('54000'));
            expect(bitacora, contains('la sentencia entera se deshace'));
            expect(bitacora, contains('lo deja en "requiere atención"'));
            expect(bitacora, contains('familiar, cuidador y la cuenta Hogar'));
            expect(bitacora, contains("'500':"));
            expect(bitacora, contains("code: '54000'"));
            // Los códigos de error de Finanzas lo mencionan.
            expect(_plano(yaml), contains('`54000` límite'));
          },
        );

        test(
          'N2: el motivo exige 3 caracteres visibles (23514) en movimientos, '
          'conciliaciones y esquemas',
          () {
            expect(endurecimiento, contains(">= 3"));
            expect(
              endurecimiento,
              contains(
                'create function public.fin_motivo_valido(p_motivo text)',
              ),
            );
            expect(
              endurecimiento,
              contains(
                'create trigger fin_c_motivo before insert on public.fin_movimientos',
              ),
            );
            expect(
              endurecimiento,
              contains(
                'create trigger fin_c_motivo before insert on public.fin_conciliaciones',
              ),
            );
            expect(endurecimiento, contains("errcode = '23514'"));
            final movimientos = _plano(
              _bloque(yaml, '/rest/v1/fin_movimientos'),
            );
            expect(
              movimientos,
              contains('necesita al menos 3 caracteres visibles'),
            );
            expect(
              movimientos,
              contains('espacios Unicode y caracteres invisibles no cuentan'),
            );
            expect(movimientos, contains('23514'));
            final conciliaciones = _plano(
              _bloque(yaml, '/rest/v1/fin_conciliaciones'),
            );
            expect(conciliaciones, contains('al menos 3 caracteres visibles'));
            expect(conciliaciones, contains('23514'));
            final todo = _plano(yaml);
            expect(
              todo,
              contains(
                'al menos 3 caracteres visibles, sin contar espacios, saltos de línea ni caracteres invisibles (23514, N2)',
              ),
            );
          },
        );

        test('N3: toda salida del libro de papá hacia otro libro deja su '
            'entrada', () {
          final inicio = endurecimiento.indexOf(
            'create or replace function public.fin_movimientos_salida_representado()',
          );
          final cuerpo = endurecimiento.substring(
            inicio,
            endurecimiento.indexOf(
              r'$$;',
              endurecimiento.indexOf(r'as $$', inicio),
            ),
          );
          expect(cuerpo, contains("o.tipo = 'representado'"));
          expect(
            cuerpo,
            contains('new.libro_origen_id <> new.libro_destino_id'),
          );
          // Ya no se pide que el destino sea un libro personal.
          expect(cuerpo, isNot(contains("'personal'")));
          final todo = _plano(yaml);
          expect(
            todo,
            contains('hacia cualquier otro libro, personal o compartido'),
          );
          expect(todo, isNot(contains('hacia un libro personal deja')));
          expect(todo, isNot(contains('hacia un libro personal; `detalle`')));
          expect(
            _plano(_bloque(yaml, '/rest/v1/fin_movimientos')),
            contains('no es una salida de libro'),
          );
        });

        test(
          'N4: fin_nombrar_albacea (solo el dueño) y su entrada de bitácora',
          () {
            expect(
              endurecimiento,
              contains('create function public.fin_nombrar_albacea('),
            );
            expect(endurecimiento, contains("p_papel text default 'albacea'"));
            expect(endurecimiento, contains('returns uuid'));
            expect(endurecimiento, contains("'finanzas.albacea_nombrado'"));
            expect(
              endurecimiento,
              contains("'anterior_persona_id', v_anterior"),
            );
            expect(
              endurecimiento,
              contains(
                'grant execute on function public.fin_nombrar_albacea(uuid, uuid, text) to authenticated;',
              ),
            );
            final albacea = operaciones.singleWhere(
              (o) => o.ruta == '/rest/v1/rpc/fin_nombrar_albacea',
            );
            expect(albacea.id, 'finNombrarAlbacea');
            expect(albacea.metodo, MetodoHttp.post);
            expect(albacea.roles, {Rol.dueno});
            expect(albacea.escribe, isTrue);
            expect(albacea.soloLocal, isTrue);
            expect(albacea.fase, 1);
            final bloque = _bloque(yaml, '/rest/v1/rpc/fin_nombrar_albacea');
            final plano = _plano(bloque);
            expect(plano, contains('required: [p_libro_id, p_persona_id]'));
            expect(
              plano,
              contains('enum: [albacea, albacea_suplente] default: albacea'),
            );
            expect(plano, contains('403 (42501), exista o no el libro'));
            expect(plano, contains('Responde 400 (22023)'));
            expect(plano, contains('`finanzas.albacea_nombrado`'));
            expect(plano, contains('`anterior_persona_id`'));
            expect(plano, contains("'#/components/schemas/Uuid'"));
            // La acción de bitácora está en el esquema, el ejemplo y la descripción.
            final bitacora = _plano(_bloque(yaml, '/rest/v1/bitacora'));
            expect(bitacora, contains('`finanzas.albacea_nombrado`'));
            expect(_plano(yaml), contains('- finanzas.albacea_nombrado'));
          },
        );

        test('N5: el administrador que deja de ser adulto con Finanzas pasa el '
            'cargo y, con menos de 2, el libro queda privado', () {
          expect(
            endurecimiento,
            contains('create trigger fin_z_relevo_administrador'),
          );
          expect(
            endurecimiento,
            contains('after update of rol, activa, hasta on public.membresias'),
          );
          expect(
            endurecimiento,
            contains(
              "visibilidad = case when cardinality(v_vigentes) < 2 then 'privada'",
            ),
          );
          expect(endurecimiento, isNot(contains('activo = case')));
          final todo = _plano(yaml);
          expect(
            todo,
            contains(
              'deja de ser adulto con Finanzas del hogar por una baja o un cambio de rol, N5',
            ),
          );
          expect(
            _plano(_bloque(yaml, '/rest/v1/membresias')),
            contains('lo deja privado (N5); nunca lo archiva'),
          );
        });

        test('las funciones internas de la migración no tienen operación', () {
          final retiradas =
              RegExp(
                    r'revoke execute on function([^;]*?)from public, anon, authenticated, service_role;',
                    dotAll: true,
                  )
                  .allMatches(endurecimiento)
                  .expand(
                    (m) =>
                        RegExp(r'public\.(\w+)\(')
                            .allMatches(m.group(1)!)
                            .map((f) => f.group(1)!),
                  )
                  .toSet();
          // La única que la app llama la concede aparte (grant ... to authenticated).
          retiradas.remove('fin_nombrar_albacea');
          expect(retiradas, {
            'bitacora_tope_por_persona',
            'fin_motivo_valido',
            'fin_motivo_validar',
            'fin_libro_asegurar_administrador',
            'fin_membresia_relevo_administrador',
          });
          for (final nombre in retiradas) {
            expect(yaml, isNot(contains('/rpc/$nombre')), reason: nombre);
          }
        });

        test('toda acción finanzas.* que escriben las migraciones está '
            'documentada en la bitácora', () {
          final migraciones = Directory('${raiz.path}/supabase/migrations')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.sql'));
          final acciones = <String>{
            for (final f in migraciones)
              for (final m in RegExp(
                r"'(finanzas\.[a-z_]+)'",
              ).allMatches(f.readAsStringSync()))
                m.group(1)!,
          };
          expect(
            acciones,
            containsAll(<String>{
              'finanzas.consulta_maestra',
              'finanzas.maestra_asignada',
              'finanzas.salida_libro_representado',
              'finanzas.albacea_nombrado',
              'finanzas.consulta_vista',
            }),
          );
          final bitacora = _plano(_bloque(yaml, '/rest/v1/bitacora'));
          for (final accion in acciones) {
            expect(bitacora, contains(accion), reason: accion);
            expect(_plano(yaml), contains('- $accion'), reason: accion);
          }
        });
      },
    );

    group('Fase 2: finanzas_fase2, avisos y avisos_ajustes', () {
      String leer(String n) =>
          File('${raiz.path}/supabase/migrations/$n').readAsStringSync();
      final fase2 = leer('20261101000000_finanzas_fase2.sql');
      final avisos = leer('20261102000000_avisos.sql');
      final ajustes = leer('20261103000000_avisos_ajustes.sql');
      final todo = _plano(yaml);

      test('las tablas y vistas que lee la app están documentadas; las del '
          'servidor, no', () {
        final rutas = operaciones.map((o) => o.ruta).toSet();
        for (final t in [
          'fin_msi',
          'fin_estados_cuenta',
          'fin_bolsas_ahorro',
          'fin_aportaciones_ahorro',
          'fin_retiros_ahorro',
          'fin_v_deuda_resumen',
          'fin_v_bolsa_saldo',
          'fin_v_estados_cuenta_vigentes',
          'avisos',
          'avisos_preferencias',
        ]) {
          expect(rutas, contains('/rest/v1/$t'), reason: t);
        }
        // Lo que la app no lee (solo service_role): sin operación.
        for (final t in ['avisos_entregas', 'avisos_sistema']) {
          expect(rutas, isNot(contains('/rest/v1/$t')), reason: t);
        }
        expect(
          avisos,
          contains(
            'grant select on public.avisos_preferencias, public.avisos to authenticated;',
          ),
        );
      });

      test('solo agregar: estados de cuenta y retiros no tienen PATCH ni '
          'DELETE', () {
        for (final t in ['fin_estados_cuenta', 'fin_retiros_ahorro']) {
          final metodos = operaciones
              .where((o) => o.ruta == '/rest/v1/$t')
              .map((o) => o.metodo)
              .toSet();
          expect(metodos, {MetodoHttp.get, MetodoHttp.post}, reason: t);
        }
        expect(fase2, contains('registrado_en'));
      });

      test('las RPC concedidas a authenticated tienen operación y los '
          'códigos y catálogos coinciden', () {
        final rutas = operaciones.map((o) => o.ruta).toSet();
        for (final f in [
          'fin_emitir_aviso',
          'avisos_marcar',
          'avisos_actualizar_preferencias',
          'registrar_dispositivo',
          'quitar_dispositivo',
          'avisos_porcentaje_base',
        ]) {
          expect(rutas, contains('/rest/v1/rpc/$f'), reason: f);
        }
        expect(avisos, contains('grant execute on function'));
        expect(
          ajustes,
          contains(
            'grant execute on function public.avisos_porcentaje_base() to authenticated;',
          ),
        );
        // Catálogo cerrado de 19 tipos y los 8 métodos de ahorro.
        final tipos = RegExp(r"'([a-z_0-9]+)'")
            .allMatches(
              avisos.substring(
                avisos.indexOf('tipo           text not null check (tipo in ('),
                avisos.indexOf('severidad      text not null'),
              ),
            )
            .map((m) => m.group(1)!)
            .toSet();
        expect(tipos, hasLength(19));
        for (final t in tipos) {
          expect(todo, contains(t), reason: t);
        }
        for (final m in [
          'pagate_primero',
          'monto_fijo',
          'meta_fecha',
          'reto_52_semanas',
          'redondeo',
          'sobrante_semanal',
          'sobre_categoria',
          'porcentaje_extras',
        ]) {
          expect(fase2, contains("'$m'"), reason: m);
          expect(todo, contains(m), reason: m);
        }
        expect(todo, contains('60 avisos al día'));
        expect(todo, contains('solo de `service_role`'));
        expect(todo, contains('403 (42501)'));
      });

      test('dispositivos: ya no hay POST ni token por PATCH; el porcentaje de '
          'la base es solo del dueño', () {
        expect(
          avisos,
          contains('revoke insert on public.dispositivos from authenticated;'),
        );
        expect(
          avisos,
          contains(
            'grant update (nombre, ultimo_uso, recibe_avisos) on public.dispositivos to authenticated;',
          ),
        );
        final disp = operaciones
            .where((o) => o.ruta == '/rest/v1/dispositivos')
            .map((o) => o.metodo)
            .toSet();
        expect(disp, {MetodoHttp.get, MetodoHttp.patch, MetodoHttp.delete});
        final base = operaciones.singleWhere(
          (o) => o.ruta == '/rest/v1/rpc/avisos_porcentaje_base',
        );
        expect(base.roles, {Rol.dueno});
        expect(base.escribe, isFalse);
        expect(ajustes, contains("errcode = '42501'"));
        expect(
          operaciones.map((o) => o.ruta),
          isNot(contains('/functions/v1/avisos')),
        );
      });
    });

    group('Fase 3: Hábitos (habitos y habitos_sensibles)', () {
      String leer(String n) =>
          File('${raiz.path}/supabase/migrations/$n').readAsStringSync();
      final habitos = leer('20261105000000_habitos.sql');
      final sensibles = leer('20261106000000_habitos_sensibles.sql');
      final grupoHab = gruposOperaciones.firstWhere(
        (g) => g.nombre == 'Base de datos · Hábitos',
      );

      test('todas las tablas hab_* que lee la app están documentadas, solo '
          'para dueño, coadministrador y familiar, y solo locales', () {
        final tablas = RegExp(r'create table public\.(hab_\w+)')
            .allMatches('$habitos$sensibles')
            .map((m) => m.group(1)!)
            .toSet();
        expect(tablas, hasLength(13));
        final rutas = operaciones.map((o) => o.ruta).toSet();
        for (final t in tablas) {
          expect(rutas, contains('/rest/v1/$t'), reason: t);
        }
        for (final o in grupoHab.operaciones) {
          expect(o.soloLocal, isTrue, reason: o.id);
          expect(o.fase, 3, reason: o.id);
          expect(o.roles, {
            Rol.dueno,
            Rol.coadministrador,
            Rol.familiar,
          }, reason: o.id);
        }
      });

      test('sobres y llaves: solo se leen; se escriben con las RPC', () {
        for (final t in ['hab_sobres', 'hab_llaves', 'hab_modos']) {
          final metodos = operaciones
              .where((o) => o.ruta == '/rest/v1/$t')
              .map((o) => o.metodo)
              .toSet();
          expect(metodos, {MetodoHttp.get}, reason: t);
        }
        expect(
          sensibles,
          contains(
            'grant select on public.hab_sobres, public.hab_llaves to authenticated;',
          ),
        );
        expect(sensibles, contains('AES-256-GCM'));
      });

      test('toda función hab_* concedida a authenticated tiene operación y '
          'las internas no', () {
        final llamables = <String>{
          for (final f in [habitos, sensibles])
            for (final m in RegExp(
              r'grant execute on function([^;]*?)\bto authenticated',
              dotAll: true,
            ).allMatches(f))
              for (final fn in RegExp(
                r'public\.(hab_\w+)\(',
              ).allMatches(m.group(1)!))
                fn.group(1)!,
        };
        expect(llamables, {
          'hab_activa',
          'hab_hogar_de',
          'hab_crear_plan_lectura',
          'hab_guardar_llave',
          'hab_cambiar_modo',
          'hab_subir_sobres',
          'hab_reiniciar_nube',
          'hab_borrar_mis_datos',
        });
        final rutas = operaciones.map((o) => o.ruta).toSet();
        for (final f in llamables) {
          expect(rutas, contains('/rest/v1/rpc/$f'), reason: f);
        }
        for (final f in [
          'hab_nota',
          'hab_exigir_activa',
          'hab_borrar_datos_de',
          'hab_limpiar',
          'hab_propio',
          'hab_iniciar_persona',
          'hab_iniciar',
          'hab_miembro_activo',
        ]) {
          expect(rutas, isNot(contains('/rest/v1/rpc/$f')), reason: f);
        }
      });

      test('constancias sin contenido: el prefijo habitos* es del servidor y '
          'está documentado', () {
        final acciones = RegExp(r"'(habitos\.[a-z_]+)'")
            .allMatches('$habitos$sensibles')
            .map((m) => m.group(1)!)
            .toSet();
        expect(acciones, {
          'habitos.activar_cifrado',
          'habitos.cambiar_modo',
          'habitos.reiniciar_nube',
          'habitos.borrar_datos',
        });
        final etiqueta = _plano(yaml);
        for (final a in acciones) {
          expect(etiqueta, contains('`$a`'), reason: a);
        }
        expect(habitos, contains("accion !~* '^\\s*habitos'"));
        final bitacora = _plano(_bloque(yaml, '/rest/v1/bitacora'));
        expect(bitacora, contains("pattern: '^habitos'"));
        expect(bitacora, contains('`habitos`'));
      });

      test('códigos y límites coinciden con la migración', () {
        expect(sensibles, contains("errcode = '55000'"));
        expect(sensibles, contains('Hasta 50 sobres por llamada.'));
        expect(sensibles, contains('26214400'));
        final todo = _plano(yaml);
        expect(todo, contains('Hasta 50 sobres por llamada'));
        expect(todo, contains('25 MB por persona'));
        expect(todo, contains('exige la llave guardada (500, 55000)'));
        final sub = _plano(_bloque(yaml, '/rest/v1/rpc/hab_subir_sobres'));
        expect(sub, contains('64 KB (23514)'));
        expect(sub, contains('conflicto que se devuelve'));
      });
    });

    test('los libros solo-agregar no se cambian ni se borran', () {
      for (final tabla in _soloAgregar) {
        final metodos = finanzas
            .where((o) => o.ruta == '/rest/v1/$tabla')
            .map((o) => o.metodo)
            .toSet();
        expect(metodos, {MetodoHttp.get, MetodoHttp.post}, reason: tabla);
      }
      // Solo categorías y cuentas (sin datos) se borran.
      expect(
        finanzas
            .where((o) => o.metodo == MetodoHttp.delete)
            .map((o) => o.ruta)
            .toSet(),
        {'/rest/v1/fin_categorias', '/rest/v1/fin_cuentas'},
      );
    });

    test('el movimiento: registrado_en obligatorio; lo del servidor, de solo '
        'lectura; los códigos de error documentados', () {
      final movimiento = RegExp(r'\n    FinMovimiento:\n(?:      .*\n|\n)*')
          .firstMatch(yaml)!
          .group(0)!;
      for (final columna in [
        'recibido_en',
        'libro_origen_id',
        'libro_destino_id',
      ]) {
        expect(
          RegExp(
            '        $columna:\n(?:          .*\n)*?          readOnly: true',
          ).hasMatch(movimiento),
          isTrue,
          reason: columna,
        );
      }
      final registrar = RegExp(
        r'operationId: registrarMovimiento\n(?:      .*\n|        .*\n)*',
      ).firstMatch(yaml)!.group(0)!;
      expect(
        RegExp(r'required: \[[^\]]*\bregistrado_en\b').hasMatch(registrar),
        isTrue,
      );
      for (final codigo in [
        '23503',
        '23505',
        '23514',
        '22023',
        '55000',
        '42501',
      ]) {
        expect(yaml, contains('`$codigo`'), reason: codigo);
      }
    });
  });
}
