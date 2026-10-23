// Guardias D3 de la revisión de calidad de la Fase 1: el dinero (y los datos
// de papá) no llega a la IA en la nube, a las bocinas, al modo Casa ni a los
// roles que no corresponden. Hoy PASAN y deben seguir pasando. Revisan:
//
// 1. el código de la app no tiene ningún cliente de IA en la nube (la Fase 6
//    lo agrega en UN archivo y debe actualizar `_clientesDeIa` aquí);
// 2. toda herramienta de Finanzas o Cuidados es solo local y su resultado
//    nunca lleva texto para la IA, aunque la herramienta lo intente;
// 3. los textos que podría leer el modelo (nombre, descripción y palabras
//    clave de las herramientas) no llevan cifras;
// 4. Finanzas no escribe en logs, notificaciones ni portapapeles;
// 5. OpenAPI marca como "solo local" todo lo que toca Finanzas;
// 6. la barra de órdenes no ofrece dinero a familiar, cuidador ni Casa, y la
//    cuenta maestra no recibe nada que registre.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/ordenes/interprete_ordenes.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

Iterable<File> _archivos(String carpeta, {String extension = '.dart'}) {
  final dir = [Directory(carpeta), Directory('app/$carpeta')].firstWhere(
    (d) => d.existsSync(),
  );
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith(extension));
}

String _sinComentarios(String codigo) => codigo
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('1. el código de la app no tiene un cliente de IA en la nube', () {
    final patrones = RegExp(
      r'api\.anthropic|anthropic\.com|openai|generativelanguage|gemini|'
      r'chat/completions|functions\.invoke|FunctionsClient|\.functions\b',
      caseSensitive: false,
    );
    final hallazgos = <String>[];
    for (final f in _archivos('lib')) {
      final codigo = _sinComentarios(f.readAsStringSync());
      for (final m in patrones.allMatches(codigo)) {
        hallazgos.add('${f.path}: ${m.group(0)}');
      }
    }
    expect(
      hallazgos,
      isEmpty,
      reason:
          'Aparece un cliente de IA o una función de servidor (Fase 6): debe '
          'vivir en un solo archivo, sin recibir el resultado de ninguna '
          'herramienta de Finanzas o Cuidados (D3)',
    );
  });

  group('2. herramientas', () {
    test('toda herramienta de Finanzas y Cuidados es solo local', () {
      final registro = registroDeGravity();
      final delicadas = [
        for (final h in registro.todas)
          if (h.modulo == Modulo.finanzas || h.modulo == Modulo.cuidados) h,
      ];
      expect(delicadas, isNotEmpty);
      for (final h in delicadas) {
        expect(h.soloLocal, isTrue, reason: h.nombre);
      }
    });

    test('ningún resultado de esas herramientas lleva texto para la IA', () async {
      final registro = registroDeGravity();
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        for (final esMaestra in [false, true]) {
          final contexto = ContextoHerramienta(
            rol: rol,
            esMaestra: esMaestra,
            navegar: (_) {},
            abrirHoja: (_) {},
          );
          for (final h in registro.disponibles(rol: rol, esMaestra: esMaestra)) {
            if (h.modulo != Modulo.finanzas && h.modulo != Modulo.cuidados) continue;
            final resultado = await registro.ejecutar(h.nombre, const {}, contexto);
            expect(resultado.paraIa, isNull, reason: '${h.nombre} ($rol)');
            expect(resultado.soloLocal, isTrue, reason: '${h.nombre} ($rol)');
          }
        }
      }
    });

    test('nombre, descripción y palabras clave no llevan cifras ni montos', () {
      final cifras = RegExp(r'[\d$]');
      for (final h in registroDeGravity().todas) {
        if (h.modulo != Modulo.finanzas) continue;
        expect(cifras.hasMatch(h.nombre), isFalse, reason: h.nombre);
        expect(cifras.hasMatch(h.descripcion), isFalse, reason: h.descripcion);
        if (h is HerramientaNavegacion) {
          for (final p in h.palabrasClave) {
            expect(cifras.hasMatch(p), isFalse, reason: p);
          }
        }
      }
    });
  });

  test('4. Finanzas no escribe en logs, notificaciones ni portapapeles', () {
    final prohibidos = RegExp(
      r'\bprint\(|debugPrint\(|developer\.log|FirebaseMessaging|'
      r'Clipboard|SelectableText|share_plus|Share\.',
    );
    final hallazgos = <String>[];
    for (final f in _archivos('lib/modulos/finanzas')) {
      final codigo = _sinComentarios(f.readAsStringSync());
      for (final m in prohibidos.allMatches(codigo)) {
        hallazgos.add('${f.path}: ${m.group(0)}');
      }
    }
    expect(hallazgos, isEmpty);
  });

  test('5. OpenAPI marca como solo local todo lo que toca Finanzas', () {
    final archivo = [File('../api/openapi.yaml'), File('api/openapi.yaml')]
        .firstWhere((f) => f.existsSync());
    final texto = archivo.readAsStringSync();
    final bloques = RegExp(
      r'\n  (/[^\n:]+):\n(.*?)(?=\n  /[^\n:]+:\n|\ncomponents:|$)',
      dotAll: true,
    ).allMatches(texto);
    final delicados = RegExp(
      r'^/(herramientas/finanzas\.|rest/v1/(fin_|bitacora|rpc/(fin_|es_cuenta_maestra|cuenta_maestra|asignar_cuenta_maestra)))',
    );
    var revisados = 0;
    for (final b in bloques) {
      final ruta = b.group(1)!;
      if (!delicados.hasMatch(ruta)) continue;
      revisados++;
      final valores = RegExp(r'x-solo-local:\s*(\S+)')
          .allMatches(b.group(2)!)
          .map((m) => m.group(1))
          .toList();
      expect(valores, isNotEmpty, reason: ruta);
      expect(valores.every((v) => v == 'true'), isTrue, reason: '$ruta: $valores');
    }
    expect(revisados, greaterThan(30));
  });

  group('6. barra de órdenes', () {
    const palabras = [
      'presupuesto',
      'finanzas',
      'dinero',
      'registrar gasto',
      'gasto',
      'cuánto me queda',
      'mi semana',
      'remanente',
    ];

    test('familiar, cuidador y Casa no reciben nada de dinero', () {
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        final interprete = InterpreteOrdenes(rol: rol);
        for (final p in palabras) {
          final r = interprete.interpretar(p);
          final destinos = switch (r) {
            OrdenEntendida(:final destino) => [destino],
            OrdenParecida(:final opciones) => opciones,
            OrdenNoEntendida(:final disponibles) => disponibles,
            OrdenVacia() => const <HerramientaNavegacion>[],
          };
          for (final d in destinos) {
            expect(d.modulo, isNot(Modulo.finanzas), reason: '$rol: "$p" → ${d.nombre}');
          }
          for (final s in interprete.sugerir(p)) {
            expect(s.destino.modulo, isNot(Modulo.finanzas), reason: '$rol: "$p"');
          }
        }
      }
    });

    test('la cuenta maestra no recibe herramientas que escriban lo ajeno', () {
      final registro = registroDeGravity();
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        for (final h in registro.disponibles(rol: rol, esMaestra: true)) {
          if (h.pertenencia == Pertenencia.ajena) {
            expect(
              h.accion,
              Accion.leer,
              reason: '${h.nombre}: la maestra solo lee lo ajeno (D19)',
            );
          }
        }
      }
      // "Registrar gasto" abre la hoja de su PROPIO libro: la hoja misma no
      // deja registrar en uno ajeno (ver pantallas_test de Finanzas).
      expect(
        registro.buscar('finanzas.registrar_gasto', rol: Rol.coadministrador, esMaestra: true),
        isNotNull,
      );
    });
  });

  test('la matriz de la app: solo dueño y coadministrador abren Finanzas', () {
    for (final rol in Rol.values) {
      final deberia = rol == Rol.dueno || rol == Rol.coadministrador;
      expect(puedeAbrir(rol, Modulo.finanzas), deberia, reason: '$rol');
    }
  });
}
