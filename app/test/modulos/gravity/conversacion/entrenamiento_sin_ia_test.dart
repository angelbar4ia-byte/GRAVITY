// Guardia de la Fase 8, bloque 7 (docs/specs/fase-8-habitos-gimnasio.md, 1.4, 8.5,
// 9 y 11; D3, D6, D13): ningún dato de entrenamiento entra al contexto del
// asistente en la nube. Ni series, cargas, esfuerzo ni molestias, y ni siquiera
// el nombre «entrenamiento» sale del dispositivo: la orden «abre el
// entrenamiento» la resuelve la barra de órdenes, sin IA.
//
// Si alguna vez el dueño decide ofrecerle al asistente en la nube que abra la
// pantalla (solo el nombre, nunca datos), esta prueba debe cambiarse a
// propósito: falla para que esa decisión no se tome por accidente.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/conversacion/cliente_asistente.dart';
import 'package:gravity/modulos/gravity/conversacion/conversacion.dart';
import 'package:gravity/modulos/gravity/ordenes/orden_entrenamiento.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

/// Lo que se vigila: el tema y sus datos.
final RegExp _tema = RegExp(
  r'entrenamiento|entrenar|gimnasio|hab_ent|molestia|carga_pasos|series_hechas',
  caseSensitive: false,
);

/// Archivos de [ruta] (relativa a la raíz del repositorio) con [extension], sin
/// las pruebas.
List<File> _archivos(Directory raiz, String ruta, String extension) {
  final dir = Directory('${raiz.path}/$ruta');
  expect(dir.existsSync(), isTrue, reason: 'No existe $ruta');
  return [
    for (final e in dir.listSync(recursive: true))
      if (e is File &&
          e.path.endsWith(extension) &&
          !e.path.endsWith('_test$extension') &&
          !e.path.contains('/node_modules/'))
        e,
  ];
}

Directory _raiz() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/api/openapi.yaml').existsSync()) return dir;
    final padre = dir.parent;
    if (padre.path == dir.path) {
      throw StateError('No encontré la raíz del repositorio');
    }
    dir = padre;
  }
}

/// Cliente falso: guarda todo lo que recibiría el servidor.
final class _ClienteEspia implements ClienteAsistente {
  _ClienteEspia(this.respuesta);

  RespuestaAsistente respuesta;
  final List<
    ({String mensaje, String sesion, List<Map<String, String>> historial})
  >
  enviado = [];

  @override
  Future<RespuestaAsistente> preguntar({
    required String mensaje,
    required String sesion,
    List<TurnoConversacion> historial = const [],
  }) async {
    enviado.add((
      mensaje: mensaje,
      sesion: sesion,
      historial: [for (final t in historial) t.aJson()],
    ));
    return respuesta;
  }

  @override
  Future<Object?> sugerirRecetas(Map<String, Object?> contexto) async =>
      throw UnimplementedError();
}

void main() {
  final raiz = _raiz();

  group('El catálogo y el código del asistente en la nube', () {
    test('catalogo.json (lo único que el modelo puede elegir) no menciona el '
        'entrenamiento', () {
      final texto = File(
        '${raiz.path}/supabase/functions/gravity-asistente/catalogo.json',
      ).readAsStringSync();
      expect(
        _tema.hasMatch(texto),
        isFalse,
        reason: _tema.firstMatch(texto)?.group(0),
      );
      final nombres = [
        for (final h in (jsonDecode(texto)['herramientas'] as List))
          (h as Map)['nombre'] as String,
      ];
      expect(
        nombres,
        isNot(contains(herramientaAbrirEntrenamientoHabitos.nombre)),
      );
    });

    test('la función gravity-asistente (contexto, proveedores, herramientas) '
        'no sabe del entrenamiento', () {
      final fuentes = _archivos(
        raiz,
        'supabase/functions/gravity-asistente',
        '.ts',
      );
      expect(fuentes, isNotEmpty);
      for (final f in fuentes) {
        final texto = f.readAsStringSync();
        expect(
          _tema.hasMatch(texto),
          isFalse,
          reason: '${f.path}: ${_tema.firstMatch(texto)?.group(0)}',
        );
      }
    });

    test('lo que la app manda a la función no sale del cliente de la '
        'conversación (mensaje, sesión y turnos de la persona y del '
        'asistente)', () {
      final cliente = File(
        '${raiz.path}/app/lib/modulos/gravity/conversacion/cliente_asistente.dart',
      ).readAsStringSync();
      // El cuerpo de la llamada: solo estas claves.
      final cuerpos = RegExp(
        r"body:\s*\{([^}]*)\}",
        dotAll: true,
      ).allMatches(cliente).map((m) => m.group(1)!).join('\n');
      for (final clave in ['mensaje', 'sesion', 'historial']) {
        expect(cuerpos, contains("'$clave'"), reason: clave);
      }
      expect(_tema.hasMatch(cliente), isFalse);
    });
  });

  group('El código de la app que habla con la IA', () {
    test('la conversación no importa ni nombra nada de Hábitos, del gimnasio '
        'ni de sus datos', () {
      final prohibido = RegExp(
        r"""import\s+['"][^'"]*(modulos/habitos|habitos_dominio|nucleo/gimnasio|datos/gimnasio|entrenamiento)[^'"]*['"]""",
      );
      final fuentes = _archivos(
        raiz,
        'app/lib/modulos/gravity/conversacion',
        '.dart',
      );
      expect(fuentes, isNotEmpty);
      for (final f in fuentes) {
        final texto = f.readAsStringSync();
        expect(prohibido.hasMatch(texto), isFalse, reason: f.path);
        expect(
          _tema.hasMatch(texto),
          isFalse,
          reason: '${f.path}: ${_tema.firstMatch(texto)?.group(0)}',
        );
      }
    });

    test('la orden del entrenamiento solo depende de los contratos y de las '
        'herramientas: ni el cliente de la IA, ni Supabase, ni los datos', () {
      final texto = File(
        '${raiz.path}/app/lib/modulos/gravity/ordenes/orden_entrenamiento.dart',
      ).readAsStringSync();
      final imports = RegExp(
        r"^import\s+'([^']+)';",
        multiLine: true,
      ).allMatches(texto).map((m) => m.group(1)!).toSet();
      expect(imports, {
        '../../../nucleo/contratos/roles.dart',
        '../../../nucleo/contratos/rutas.dart',
        '../../../nucleo/herramientas/herramientas.dart',
      });
      // Solo el código: los comentarios pueden nombrar el catálogo del servidor.
      final codigo = texto
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final prohibido in ['supabase', 'http', 'cliente_asistente']) {
        expect(codigo, isNot(contains(prohibido)), reason: prohibido);
      }
    });

    test('el intérprete y la barra de órdenes no usan el cliente de la IA', () {
      for (final nombre in [
        'interprete_ordenes.dart',
        'barra_ordenes.dart',
        'texto_ordenes.dart',
      ]) {
        final texto = File(
          '${raiz.path}/app/lib/modulos/gravity/ordenes/$nombre',
        ).readAsStringSync();
        expect(texto, isNot(contains('cliente_asistente')), reason: nombre);
        expect(
          texto,
          isNot(contains('clienteAsistenteProvider')),
          reason: nombre,
        );
        expect(texto, isNot(contains('supabase')), reason: nombre);
      }
    });
  });

  group('Lo que viaja en una conversación', () {
    test('si el asistente elige la orden del entrenamiento, se ejecuta en el '
        'dispositivo y nada de ella se manda al servidor después', () async {
      final cliente = _ClienteEspia(
        // Un modelo que, aun sin tenerla en su catálogo, nombra la herramienta.
        const RespuestaAsistente(
          texto: 'Abriendo.',
          herramienta: 'habitos.abrir_entrenamiento',
        ),
      );
      final c = ProviderContainer(
        overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
      );
      addTearDown(c.dispose);
      final registro = registroDeOrdenes();
      final abiertas = <String>[];
      final consultas = <String>[];
      final resultados = <ResultadoHerramienta>[];

      await c
          .read(conversacionAsistenteProvider.notifier)
          .enviar(
            'qué toca hoy',
            ejecutar: (herramienta) async {
              final r = await registro.ejecutar(
                herramienta,
                const {},
                ContextoHerramienta(
                  rol: Rol.familiar,
                  navegar: abiertas.add,
                  consultaLocal: (n) async {
                    consultas.add(n);
                    return 'Hoy toca A: 3 series de 10 con 40 kg (texto local)';
                  },
                ),
              );
              resultados.add(r);
              return r.contenido;
            },
          );
      cliente.respuesta = const RespuestaAsistente(texto: 'Listo.');
      await c.read(conversacionAsistenteProvider.notifier).enviar('gracias');

      expect(abiertas, [destinoEntrenamiento]);
      expect(consultas, isEmpty, reason: 'no se leyó nada del entrenamiento');
      expect(resultados.single.paraIa, isNull);
      expect(resultados.single.soloLocal, isTrue);

      // Lo que vio el servidor: solo lo que dijo la persona y el asistente.
      expect(cliente.enviado, hasLength(2));
      final visto = jsonEncode([
        for (final e in cliente.enviado) ...[e.mensaje, e.historial],
      ]);
      expect(visto, contains('qué toca hoy'));
      expect(visto, contains('Abriendo.'));
      expect(visto, isNot(contains('series')));
      expect(visto, isNot(contains('kg')));
      expect(visto, isNot(contains('local')));
      expect(cliente.enviado[1].historial.map((t) => t['texto']), [
        'qué toca hoy',
        'Abriendo.',
      ]);
      // El texto que dejó la herramienta sí está, pero solo en pantalla.
      expect(
        c.read(conversacionAsistenteProvider).mensajes.map((m) => m.autor),
        contains(AutorMensaje.local),
      );
    });

    test('un mensaje de la persona va tal cual: lo que ella escribe no se '
        'completa con datos del entrenamiento', () async {
      final cliente = _ClienteEspia(const RespuestaAsistente(texto: 'Hola.'));
      final c = ProviderContainer(
        overrides: [clienteAsistenteProvider.overrideWithValue(cliente)],
      );
      addTearDown(c.dispose);
      await c.read(conversacionAsistenteProvider.notifier).enviar('hola');
      expect(cliente.enviado.single.mensaje, 'hola');
      expect(cliente.enviado.single.historial, isEmpty);
    });
  });

  group('Toda herramienta del entrenamiento es solo local', () {
    test('las que traiga cualquier catálogo (el de la barra y el '
        'registrado) cumplen D3 y D13, para todos los roles', () async {
      final todas = {
        for (final h in [...catalogoDeOrdenes(), ...registroDeGravity().todas])
          if (_tema.hasMatch(h.nombre) || _tema.hasMatch(h.descripcion))
            h.nombre: h,
      };
      expect(todas, contains(herramientaAbrirEntrenamientoHabitos.nombre));
      for (final h in todas.values) {
        expect(h.modulo, Modulo.habitos, reason: h.nombre);
        expect(h.soloLocal, isTrue, reason: h.nombre);
        expect(h.escribe, isFalse, reason: h.nombre);
        expect(h.guardaEnHistorial, isFalse, reason: h.nombre);
        // Ninguna lee series, cargas ni molestias: solo navega.
        expect(
          h is HerramientaNavegacion && !h.consulta && h.hoja == null,
          isTrue,
          reason: h.nombre,
        );
        for (final rol in h.roles) {
          final r = await RegistroHerramientas([h]).ejecutar(
            h.nombre,
            const {},
            ContextoHerramienta(rol: rol, navegar: (_) {}),
          );
          expect(r.paraIa, isNull, reason: '${h.nombre} / ${rol.name}');
        }
      }
    });
  });
}
