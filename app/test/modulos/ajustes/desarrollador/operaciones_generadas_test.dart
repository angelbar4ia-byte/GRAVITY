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
        deFase1.contains(h.nombre) ? 1 : 0,
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
      expect(base, hasLength(2));
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
      const soloDueno = {'asignarCuentaMaestra', 'finCrearLibroRepresentado'};
      for (final o in finanzas) {
        expect(o.soloLocal, isTrue, reason: o.id);
        expect(o.fase, 1, reason: o.id);
        if (deTodos.contains(o.id)) {
          expect(o.roles, Rol.values.toSet(), reason: o.id);
        } else if (soloDueno.contains(o.id)) {
          expect(o.roles, {Rol.dueno}, reason: o.id);
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

      test('salirse, quitar a otro, archivar y reactivar coinciden con la '
          'migración', () {
        expect(
          respuestas,
          contains('Un libro compartido no baja de 2 miembros vigentes.'),
        );
        expect(
          respuestas,
          contains('activo = case when v_otros < 2 then false'),
        );
        expect(respuestas, contains('order by m.desde, m.id'));
        final miembros = _plano(_bloque(yaml, '/rest/v1/fin_libro_miembros'));
        expect(
          miembros,
          contains('**salirse** es un `PATCH` a la propia fila'),
        );
        expect(miembros, contains('`hasta` = ahora'));
        expect(miembros, contains('archiva el libro'));
        expect(miembros, contains('`fin_libros.activo` = `false`'));
        expect(miembros, contains('pasa al miembro vigente más antiguo'));
        expect(miembros, contains('ni con `upsert`'));
        expect(miembros, contains('403 (42501)'));
        expect(miembros, contains('400, 22023'));
        expect(miembros, contains('2 miembros vigentes'));
        final libros = _plano(_bloque(yaml, '/rest/v1/fin_libros'));
        expect(libros, contains('lo archiva (`activo: false`) o lo reactiva'));
        expect(libros, contains('archivado es de solo lectura'));
      });

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
