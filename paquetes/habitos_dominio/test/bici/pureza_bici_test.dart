import 'dart:io';

import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

import 'ayudas_bici.dart';

/// El dominio de la bicicleta es Dart puro, sin ubicación en ningún tipo de
/// nube (CA-B-18, CA-B-25 en lo de dominio), sin IA (CA-B-27) y sin
/// dependencias (CA-B-26).
void main() {
  final archivos = Directory('lib/src/bici')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String sinComentarios(String src) =>
      src.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

  test('hay archivos de la bicicleta que revisar', () {
    expect(archivos.length, greaterThanOrEqualTo(14));
  });

  test('sin Flutter, I/O, red, reloj, azar ni IA', () {
    final prohibidos = <String, Pattern>{
      'dart:io': RegExp(r"import\s+'dart:io'"),
      'dart:ui': RegExp(r"import\s+'dart:ui'"),
      'dart:html': RegExp(r"import\s+'dart:html'"),
      'dart:isolate': RegExp(r"import\s+'dart:isolate'"),
      'paquete externo': RegExp(r"import\s+'package:(?!habitos_dominio)"),
      'flutter': 'package:flutter',
      'http': RegExp(r'package:(http|dio)'),
      'reloj': RegExp(r'DateTime\.now\(|Stopwatch|Timer\(|Future\.delayed'),
      'azar': RegExp(r'\bRandom\b'),
      'IA': RegExp(
        r'gravity-asistente|asistente\.dart|Gemini|OpenAI',
        caseSensitive: false,
      ),
      'Health Connect': RegExp(
        r'health_connect|HealthConnect',
        caseSensitive: false,
      ),
      'GPS': RegExp(r'geolocator|foreground_task|wakelock|flutter_map'),
    };
    for (final f in archivos) {
      final src = f.readAsStringSync();
      for (final e in prohibidos.entries) {
        expect(
          src.contains(e.value),
          isFalse,
          reason: '${f.path} usa ${e.key}',
        );
      }
    }
  });

  test('no hay doubles: distancias en metros y tiempos en minutos enteros', () {
    for (final f in archivos) {
      expect(
        RegExp(r'\bdouble\b').hasMatch(f.readAsStringSync()),
        isFalse,
        reason: f.path,
      );
    }
  });

  test('el pubspec del paquete sigue sin dependencias', () {
    final y = File('pubspec.yaml').readAsStringSync();
    final deps = RegExp(
      r'^dependencies:\s*\n((?:  .*\n|\n)*)',
      multiLine: true,
    ).firstMatch(y)!.group(1)!.trim();
    expect(deps, isEmpty);
  });

  test('ningún campo del código modela ubicación, ruta ni contacto', () {
    // Nombres de campo y de columna prohibidos (el texto de las pantallas sí
    // puede decir «contacto»; los comentarios se ignoran).
    final campos = RegExp(
      r'\b(latitud|longitud|lat_e5|lon_e5|traza|trazo|domicilio|telefono|'
      r'rutaId|ruta_id|nombreRuta|enlaceRuta|contactoNombre|contactoTelefono)'
      r'\b',
      caseSensitive: false,
    );
    for (final f in archivos) {
      final src = sinComentarios(f.readAsStringSync());
      expect(campos.hasMatch(src), isFalse, reason: f.path);
    }
  });

  group('las filas de nube no tienen campos de ubicación (CA-B-18)', () {
    final prohibidas = [
      'lat',
      'lon',
      'traza',
      'trazo',
      'ruta',
      'enlace_ruta',
      'domicilio',
      'contacto',
      'telefono',
      'tel',
      'ubicacion',
      'gps',
    ];

    void sinUbicacion(String que, Map<String, Object?> fila) {
      for (final k in fila.keys) {
        for (final p in prohibidas) {
          expect(
            k == p || k.startsWith('${p}_') || k.endsWith('_$p'),
            isFalse,
            reason: '$que tiene la columna «$k»',
          );
        }
      }
    }

    test('salida, bicicleta, mantenimiento, perfil y lista de música', () {
      sinUbicacion(
        'salida',
        Salida(id: 's', fecha: sabado5dic, clima: ClimaSalida.frio).aJson(),
      );
      sinUbicacion('bicicleta', biciA.aJson());
      sinUbicacion(
        'mantenimiento',
        hecho('m', TareaMantenimiento.lubricarCadena, sabado5dic).aJson(),
      );
      sinUbicacion('perfil', const PerfilBici().aJson());
      sinUbicacion(
        'música',
        const ListaMusica(
          id: 'l',
          nombre: 'Ruta',
          actividad: ActividadMusica.bicicleta,
          app: AppMusica.otra,
          enlace: 'https://ejemplo.mx/lista',
        ).aJson(),
      );
    });

    test('la salida NO se enlaza con ninguna ruta (PB-04)', () {
      final k = Salida(id: 's', fecha: sabado5dic).aJson().keys.toList();
      expect(k, [
        'id',
        'fecha',
        'n',
        'bloque_id',
        'bicicleta_id',
        'inicio',
        'duracion_min',
        'distancia_m',
        'desnivel_m',
        'superficie',
        'esfuerzo',
        'clima',
        'acompanado',
        'estado',
        'motivo',
      ]);
    });

    test('el perfil son las columnas de hab_bici_perfil (sin intervalos de '
        'agua ni comida: son de la V2)', () {
      expect(const PerfilBici().aJson().keys, [
        'bicicleta_activa_id',
        'duracion_prevista_min',
        'margen_revision_min',
        'carga_piernas',
        'tope_aumento_pct',
        'preparacion',
        'aviso_visto_en',
      ]);
      expect(const PerfilBici().aJson()['carga_piernas'], 'normal');
      expect(
        const PerfilBici(
          reglas: ReglasBicicleta(cargaPiernas: CargaPiernas.porEsfuerzo),
        ).aJson()['carga_piernas'],
        'por_esfuerzo',
      );
    });

    test('la preparación guardada tampoco lleva ubicación', () {
      final j = const PreparacionPersonal()
          .conPropio('Cargar la cámara')
          .aJson();
      expect(j.keys, ['catalogo', 'propios']);
    });
  });

  group('rangos de las columnas (CA-B-17, en el dominio)', () {
    List<String> malos(Salida s) => [for (final e in s.validar()) e.codigo];

    Salida con({
      int n = 1,
      int? duracion,
      int? distancia,
      int? desnivel,
      int? esfuerzo,
      int? inicio,
    }) => Salida(
      id: 's',
      fecha: sabado5dic,
      n: n,
      duracionMin: duracion,
      distanciaM: distancia,
      desnivelM: desnivel,
      esfuerzo: esfuerzo,
      inicioMin: inicio,
    );

    test('los límites exactos entran y uno más allá no', () {
      expect(malos(con(esfuerzo: 1)), isEmpty);
      expect(malos(con(esfuerzo: 5)), isEmpty);
      expect(malos(con(esfuerzo: 0)), ['esfuerzo_fuera_de_rango']);
      expect(malos(con(esfuerzo: 6)), ['esfuerzo_fuera_de_rango']);
      expect(malos(con(distancia: 0)), isEmpty);
      expect(malos(con(distancia: 1000000)), isEmpty);
      expect(malos(con(distancia: 1000001)), ['distancia_fuera_de_rango']);
      expect(malos(con(distancia: -1)), ['distancia_fuera_de_rango']);
      expect(malos(con(duracion: 1)), isEmpty);
      expect(malos(con(duracion: 1440)), isEmpty);
      expect(malos(con(duracion: 0)), ['duracion_fuera_de_rango']);
      expect(malos(con(duracion: 1441)), ['duracion_fuera_de_rango']);
      expect(malos(con(n: 3)), isEmpty);
      expect(malos(con(n: 0)), ['n_fuera_de_rango']);
      expect(malos(con(n: 4)), ['n_fuera_de_rango']);
      expect(malos(con(desnivel: 20000)), isEmpty);
      expect(malos(con(desnivel: 20001)), ['desnivel_fuera_de_rango']);
      expect(malos(con(inicio: 1440)), ['inicio_fuera_del_dia']);
    });

    test('las listas cerradas tienen los ids del servidor', () {
      expect(SuperficieSalida.values.map((s) => s.id), [
        'calle',
        'terreno',
        'mixta',
      ]);
      expect(EstadoSalida.values.map((s) => s.id), [
        'hecha',
        'parcial',
        'omitida',
      ]);
      expect(MotivoOmision.values.map((s) => s.id), [
        'clima',
        'seguridad',
        'otra',
      ]);
      expect(CargaPiernas.values.map((s) => s.id), [
        'normal',
        'ligera',
        'por_esfuerzo',
      ]);
      expect(TareaMantenimiento.values.map((s) => s.id), [
        'lubricar_cadena',
        'limpiar_transmision',
        'revisar_frenos_llantas',
        'revision_general',
        'lectura_odometro',
        'otra',
      ]);
      expect(SuperficieSalida.deId('aire'), isNull);
      expect(CargaPiernas.deId('por_esfuerzo'), CargaPiernas.porEsfuerzo);
    });

    test('la hora de inicio sube como hora (time)', () {
      expect(con(inicio: 8 * 60).aJson()['inicio'], '08:00');
      expect(con().aJson()['inicio'], isNull);
      expect(con().aJson()['fecha'], '2026-12-05');
    });

    test('las reglas por omisión están dentro de sus rangos', () {
      expect(const ReglasBicicleta().validar(), isEmpty);
      expect(const PerfilBici().validar(), isEmpty);
      expect(const PerfilBici().debeMostrarAviso, isTrue);
      expect(
        const ReglasBicicleta(duracionPrevistaMin: 29).validar(),
        isNotEmpty,
      );
      expect(
        const ReglasBicicleta(margenRevisionMin: 241).validar(),
        isNotEmpty,
      );
      expect(
        const ReglasBicicleta(numeroEmergencias: ' ').validar(),
        isNotEmpty,
      );
    });
  });
}
