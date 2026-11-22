// Gestor de modelos descargables (motor de voz, P3.2a-2): criterios 15, 17 a 26
// de `docs/specs/fase-8-motor-de-voz.md`, con un servidor simulado (que habla
// `Range`, `ETag` y se corta a la mitad), un disco real en una carpeta
// temporal y archivos de verdad con sus huellas calculadas aquí. Ninguna
// prueba abre una conexión de red.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/gravity/voz/descarga/gestor_en_disco.dart';
import 'package:gravity/modulos/gravity/voz/descarga/huella.dart';
import 'package:gravity/modulos/gravity/voz/descarga/puerta_de_descarga.dart';
import 'package:gravity/modulos/gravity/voz/descarga/puerta_de_descarga_falsa.dart';
import 'package:gravity/modulos/gravity/voz/descarga/sistema_de_archivos.dart';
import 'package:gravity/modulos/gravity/voz/modelos/catalogo.dart';
import 'package:gravity/modulos/gravity/voz/modelos/estado_modelo.dart';
import 'package:gravity/modulos/gravity/voz/modelos/lector_catalogo.dart';
import 'package:gravity/modulos/gravity/voz/tipos.dart';
import 'package:gravity/nucleo/conectividad/tipo_de_red.dart';

import '../ayuda_modelos.dart';

/// Un disco que se llena después de [hastaBytes] bytes escritos.
class DiscoQueSeLlena extends SistemaDeArchivosReal {
  DiscoQueSeLlena({required this.hastaBytes, this.codigo = 28});
  final int hastaBytes;
  final int codigo;
  int escritos = 0;

  @override
  Future<EscritorDeArchivo> abrirEscritura(
    String ruta, {
    bool anexar = false,
  }) async =>
      _Lleno(await super.abrirEscritura(ruta, anexar: anexar), this, ruta);
}

class _Lleno implements EscritorDeArchivo {
  _Lleno(this._real, this._disco, this._ruta);
  final EscritorDeArchivo _real;
  final DiscoQueSeLlena _disco;
  final String _ruta;

  @override
  void agregar(List<int> bytes) {
    if (_disco.escritos + bytes.length > _disco.hastaBytes) {
      throw FileSystemException(
        'No queda espacio',
        _ruta,
        OSError('', _disco.codigo),
      );
    }
    _disco.escritos += bytes.length;
    _real.agregar(bytes);
  }

  @override
  Future<void> vaciar() => _real.vaciar();

  @override
  Future<void> cerrar() => _real.cerrar();
}

/// Un disco que mide poco espacio libre.
class DiscoConPocoEspacio extends SistemaDeArchivosReal {
  const DiscoConPocoEspacio(this.libres);
  final int libres;

  @override
  Future<int?> bytesLibres(String ruta) async => libres;
}

/// Un disco que falla de otra forma (permisos).
class DiscoSinPermiso extends SistemaDeArchivosReal {
  const DiscoSinPermiso();

  @override
  Future<EscritorDeArchivo> abrirEscritura(
    String ruta, {
    bool anexar = false,
  }) async => throw FileSystemException('Sin permiso', ruta, OSError('', 13));
}

void main() {
  late Directory dir;
  late ContenidoDePrueba contenido;
  late CatalogoDeVoces catalogo;
  late PuertaDeDescargaFalsa servidor;
  late FuenteTipoDeRedFalsa red;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gravity_voz_');
    contenido = ContenidoDePrueba();
    catalogo = contenido.catalogo();
    servidor = contenido.servidor();
    red = FuenteTipoDeRedFalsa(TipoDeRed.wifi);
  });

  tearDown(() async {
    await red.cerrar();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  GestorDeModelosEnDisco crear({
    SistemaDeArchivos archivos = const SistemaDeArchivosReal(),
    PuertaDeDescarga? puerta,
    CatalogoDeVoces? cat,
    int paso = 1024,
    CalculadoraDeHuella huella = huellaSha256,
  }) => GestorDeModelosEnDisco(
    catalogo: cat ?? catalogo,
    raiz: () async => dir.path,
    red: red,
    puerta: puerta ?? servidor,
    archivos: archivos,
    huella: huella,
    pasoDeProgreso: paso,
  );

  /// Corre una descarga hasta el final: lo que emitió y cómo terminó.
  Future<({List<ProgresoDescarga> progreso, Object? error})> correr(
    Stream<ProgresoDescarga> flujo,
  ) async {
    final progreso = <ProgresoDescarga>[];
    Object? error;
    try {
      await for (final p in flujo) {
        progreso.add(p);
      }
    } on Object catch (e) {
      error = e;
    }
    return (progreso: progreso, error: error);
  }

  String ruta(String relativa) => '${dir.path}/$relativa';
  bool existe(String relativa) =>
      FileSystemEntity.typeSync(ruta(relativa)) !=
      FileSystemEntityType.notFound;

  group('criterios 17 y 18: ninguna conexión sin permiso', () {
    test(
      'crear el gestor y preguntar por el estado no abre ninguna conexión',
      () async {
        final g = crear();
        expect(await g.estado('ana'), EstadoModelo.noDescargado);
        expect(await g.bytesOcupados(), 0);
        expect(servidor.peticiones, isEmpty);
      },
    );

    test(
      'con datos móviles y sin permiso: SinWifi, sin abrir ninguna conexión',
      () async {
        red.poner(TipoDeRed.datosMoviles);
        final g = crear();
        final r = await correr(g.descargar('ana'));
        expect(r.error, isA<SinWifi>());
        expect(servidor.peticiones, isEmpty);
        expect(await g.estado('ana'), EstadoModelo.noDescargado);
        expect(existe('ana.descarga'), isFalse);
      },
    );

    test(
      'con datos móviles y con permiso (de esa descarga) sí descarga',
      () async {
        red.poner(TipoDeRed.datosMoviles);
        final g = crear();
        final r = await correr(g.descargar('ana', permitirDatosMoviles: true));
        expect(r.error, isNull);
        expect(await g.estado('ana'), EstadoModelo.instalado);
      },
    );

    test(
      'el permiso no se recuerda: la siguiente descarga vuelve a pedirlo',
      () async {
        red.poner(TipoDeRed.datosMoviles);
        final g = crear();
        await correr(g.descargar('ana', permitirDatosMoviles: true));
        final r = await correr(g.descargar('beto'));
        expect(r.error, isA<SinWifi>());
      },
    );

    test('una red de la que no se sabe si cuesta datos (VPN, Bluetooth) también pide permiso', () async {
      red.poner(TipoDeRed.otra);
      final r = await correr(crear().descargar('ana'));
      expect(r.error, isA<SinWifi>());
      expect(servidor.peticiones, isEmpty);
    });

    test('sin red: SinRed, sin abrir nada', () async {
      red.poner(TipoDeRed.sinRed);
      final r = await correr(
        crear().descargar('ana', permitirDatosMoviles: true),
      );
      expect(r.error, isA<SinRed>());
      expect(servidor.peticiones, isEmpty);
    });

    test('Wi-Fi y Ethernet descargan sin preguntar', () async {
      for (final tipo in [TipoDeRed.wifi, TipoDeRed.ethernet]) {
        red.poner(tipo);
        final g = crear();
        final r = await correr(g.descargar('ana'));
        expect(r.error, isNull, reason: '$tipo');
        await g.borrar('ana');
      }
    });

    test('si no hay conexión al pedir (el servidor no responde), SinRed y se conserva lo que había', () async {
      servidor.falloAlPedir = const SocketException('sin ruta');
      final g = crear();
      final r = await correr(g.descargar('ana'));
      expect(r.error, isA<SinRed>());
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
    });

    test('un modelo que no está en el catálogo falla sin tocar nada', () async {
      final g = crear();
      final r = await correr(g.descargar('no-existe'));
      expect(r.error, isA<FalloDeSintesis>());
      expect(servidor.peticiones, isEmpty);
    });
  });

  group('descarga e instalación', () {
    test('baja los tres archivos en orden y los instala', () async {
      final g = crear();
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
      expect(await g.estado('ana'), EstadoModelo.instalado);
      for (final e in contenido.archivos['ana']!.entries) {
        expect(File(ruta('ana/${e.key}')).readAsBytesSync(), e.value);
      }
      expect(existe('ana.descarga'), isFalse, reason: 'no quedan restos');
      expect(existe('ana/instalado.json'), isTrue);
      expect(servidor.peticiones.map((p) => p.direccion.pathSegments.last), [
        'ana.onnx',
        'tokens.txt',
        'lexicon-en-us.txt',
      ]);
    });

    test('con la huella por omisión (en un Isolate) también instala', () async {
      final g = GestorDeModelosEnDisco(
        catalogo: catalogo,
        raiz: () async => dir.path,
        red: red,
        puerta: servidor,
      );
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
      expect(await g.estado('ana'), EstadoModelo.instalado);
    });

    test(
      'las rutas para cargar se arman solo con los nombres del catálogo',
      () async {
        final g = crear();
        expect(await g.rutasParaCargar('ana'), isNull);
        await correr(g.descargar('ana'));
        final rutas = (await g.rutasParaCargar('ana'))!;
        expect(rutas.modelo, ruta('ana/ana.onnx'));
        expect(rutas.tokens, ruta('ana/tokens.txt'));
        expect(rutas.lexicon, ruta('ana/lexicon-en-us.txt'));
        expect(File(rutas.modelo).existsSync(), isTrue);
      },
    );

    test('criterio 19: el progreso es creciente, cuenta todo el modelo y termina en el total', () async {
      final g = crear();
      final r = await correr(g.descargar('ana'));
      final total = catalogo.porId('ana')!.bytes;
      expect(r.progreso, isNotEmpty);
      expect(r.progreso.every((p) => p.total == total), isTrue);
      for (var i = 1; i < r.progreso.length; i++) {
        expect(
          r.progreso[i].bytes,
          greaterThanOrEqualTo(r.progreso[i - 1].bytes),
          reason: 'evento $i',
        );
      }
      expect(r.progreso.last.bytes, total);
      expect(r.progreso.last.fraccion, 1.0);
      // Pasa de un archivo al siguiente sin volver a empezar la cuenta.
      expect(r.progreso.map((p) => p.archivo).toSet(), {
        'ana.onnx',
        'tokens.txt',
        'lexicon-en-us.txt',
      });
    });

    test(
      'pedir la misma descarga mientras corre devuelve el mismo trabajo',
      () async {
        final g = crear();
        final a = correr(g.descargar('ana'));
        final b = correr(g.descargar('ana'));
        expect(g.seguir('ana'), isNotNull);
        final ra = await a;
        final rb = await b;
        expect(ra.error, isNull);
        expect(rb.error, isNull);
        expect(servidor.pedidasDe(contenido.direccion('ana', 'ana.onnx')), 1);
        expect(g.seguir('ana'), isNull);
      },
    );

    test(
      'un oyente que llega tarde recibe el último avance y el final',
      () async {
        final g = crear();
        final primero = correr(g.descargar('ana'));
        await Future<void>.delayed(Duration.zero);
        final tarde = await correr(g.seguir('ana') ?? const Stream.empty());
        await primero;
        expect(tarde.progreso, isNotEmpty);
      },
    );

    test('estado mientras baja: descargando', () async {
      final g = crear();
      servidor.pausaDelCuerpo = Completer<void>();
      final r = correr(g.descargar('ana'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await g.estado('ana'), EstadoModelo.descargando);
      servidor.pausaDelCuerpo!.complete();
      await r;
      expect(await g.estado('ana'), EstadoModelo.instalado);
    });

    test('si ya está instalado no pide nada', () async {
      final g = crear();
      await correr(g.descargar('ana'));
      servidor.peticiones.clear();
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
      expect(servidor.peticiones, isEmpty);
      expect(r.progreso.last.bytes, catalogo.porId('ana')!.bytes);
    });

    test('avisa en `cambios` cuando empieza y cuando termina', () async {
      final g = crear();
      var avisos = 0;
      final sub = g.cambios.listen((_) => avisos++);
      await correr(g.descargar('ana'));
      await Future<void>.delayed(Duration.zero);
      expect(avisos, greaterThanOrEqualTo(2));
      await sub.cancel();
    });
  });

  group('criterio 15: la descarga no envía datos de la persona', () {
    test('cada petición lleva solo cabeceras de la lista y la dirección exacta del catálogo', () async {
      final g = crear();
      servidor.cortarDespuesDe[contenido.direccion('ana', 'ana.onnx')] = 9000;
      await correr(g.descargar('ana'));
      await correr(g.descargar('ana')); // la reanudación también
      expect(servidor.peticiones, isNotEmpty);
      final direcciones = {
        for (final a in catalogo.porId('ana')!.archivos) a.url.toString(),
      };
      for (final p in servidor.peticiones) {
        expect(
          p.cabeceras.keys.toSet().difference(cabecerasPermitidas),
          isEmpty,
          reason: 'cabeceras: ${p.cabeceras.keys}',
        );
        expect(p.cabeceras['user-agent'], userAgentDeDescarga);
        expect(p.cabeceras['accept-encoding'], 'identity');
        for (final prohibida in [
          'authorization',
          'cookie',
          'x-api-key',
          'apikey',
        ]) {
          expect(
            p.cabeceras.containsKey(prohibida),
            isFalse,
            reason: prohibida,
          );
        }
        expect(direcciones, contains(p.direccion.toString()));
        expect(p.direccion.hasQuery, isFalse);
      }
    });

    test('el User-Agent es genérico: no dice versión, equipo ni persona', () {
      expect(userAgentDeDescarga, 'GRAVITY-voces/1');
      expect(RegExp(r'\d+\.\d+').hasMatch(userAgentDeDescarga), isFalse);
    });
  });

  group('criterios 20 y 21: reanudar', () {
    test('criterio 20: cortada a la mitad, reanuda con Range desde los bytes guardados', () async {
      final g = crear();
      final onnx = contenido.direccion('ana', 'ana.onnx');
      servidor.cortarDespuesDe[onnx] = 12000;
      final r1 = await correr(g.descargar('ana'));
      expect(r1.error, isA<DescargaInterrumpida>());
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      final guardados = File(ruta('ana.descarga/ana.onnx.parcial'))
          .lengthSync();
      expect(guardados, 12000);
      expect(await g.bytesDescargados('ana'), 12000);
      servidor.peticiones.clear();

      final r2 = await correr(g.descargar('ana'));
      expect(r2.error, isNull);
      final reanudada = servidor.peticiones.first;
      expect(reanudada.direccion.toString(), onnx);
      expect(reanudada.cabeceras['range'], 'bytes=12000-');
      expect(reanudada.cabeceras['if-range'], isNotNull);
      expect(await g.estado('ana'), EstadoModelo.instalado);
      expect(
        File(ruta('ana/ana.onnx')).readAsBytesSync(),
        contenido.archivos['ana']!['ana.onnx'],
        reason: 'la huella debe ser la correcta',
      );
      // El progreso arranca donde iba, no en cero.
      expect(r2.progreso.first.bytes, greaterThanOrEqualTo(12000));
    });

    test('lo ya guardado y verificado no se pide otra vez', () async {
      final g = crear();
      final lexicon = contenido.direccion('ana', 'lexicon-en-us.txt');
      servidor.cortarDespuesDe[lexicon] = 2000;
      final r1 = await correr(g.descargar('ana'));
      expect(r1.error, isA<DescargaInterrumpida>());
      servidor.peticiones.clear();
      final r2 = await correr(g.descargar('ana'));
      expect(r2.error, isNull);
      expect(servidor.pedidasDe(contenido.direccion('ana', 'ana.onnx')), 0);
      expect(servidor.pedidasDe(contenido.direccion('ana', 'tokens.txt')), 0);
      expect(servidor.pedidasDe(lexicon), 1);
      expect(servidor.peticiones.single.cabeceras['range'], 'bytes=2000-');
      expect(await g.estado('ana'), EstadoModelo.instalado);
    });

    test('criterio 21: un servidor que ignora Range y manda todo reinicia el archivo, sin concatenar', () async {
      final g = crear();
      final onnx = contenido.direccion('ana', 'ana.onnx');
      servidor.cortarDespuesDe[onnx] = 10000;
      await correr(g.descargar('ana'));
      servidor.ignorarRange = true;
      servidor.peticiones.clear();
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
      expect(servidor.peticiones.first.cabeceras['range'], 'bytes=10000-');
      expect(
        File(ruta('ana/ana.onnx')).readAsBytesSync(),
        contenido.archivos['ana']!['ana.onnx'],
        reason: 'sin concatenar: debe ser exactamente el archivo',
      );
      expect(await g.estado('ana'), EstadoModelo.instalado);
    });

    test(
      'si el archivo cambió en el servidor (otro ETag) se baja completo',
      () async {
        final g = crear();
        final onnx = contenido.direccion('ana', 'ana.onnx');
        servidor.cortarDespuesDe[onnx] = 8000;
        await correr(g.descargar('ana'));
        // If-Range no coincide: la falsa contesta 200 completo.
        final estado = File(ruta('ana.descarga/estado.json'));
        estado.writeAsStringSync(
          estado.readAsStringSync().replaceAll(
            RegExp(r'"ana\.onnx":"[^"]*"'),
            '"ana.onnx":"\\"otro\\""',
          ),
        );
        final r = await correr(g.descargar('ana'));
        expect(r.error, isNull);
        expect(
          File(ruta('ana/ana.onnx')).readAsBytesSync(),
          contenido.archivos['ana']!['ana.onnx'],
        );
      },
    );

    test(
      'sin ETag no se puede reanudar con seguridad: se empieza de nuevo',
      () async {
        servidor.sinEtag = true;
        final g = crear();
        servidor.cortarDespuesDe[contenido.direccion('ana', 'ana.onnx')] = 8000;
        await correr(g.descargar('ana'));
        servidor.peticiones.clear();
        final r = await correr(g.descargar('ana'));
        expect(r.error, isNull);
        expect(
          servidor.peticiones.first.cabeceras.containsKey('range'),
          isFalse,
        );
        expect(await g.estado('ana'), EstadoModelo.instalado);
      },
    );

    test(
      'un parcial más grande de lo que dice el catálogo se descarta',
      () async {
        final g = crear();
        File(ruta('ana.descarga/ana.onnx.parcial'))
          ..createSync(recursive: true)
          ..writeAsBytesSync(List.filled(99999, 1));
        final r = await correr(g.descargar('ana'));
        expect(r.error, isNull);
        expect(
          File(ruta('ana/ana.onnx')).readAsBytesSync(),
          contenido.archivos['ana']!['ana.onnx'],
        );
      },
    );

    test('un parcial que ya está completo solo se verifica', () async {
      final g = crear();
      File(ruta('ana.descarga/tokens.txt.parcial'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(contenido.archivos['ana']!['tokens.txt']!);
      File(ruta('ana.descarga/estado.json')).writeAsStringSync(
        '{"revision":"rev1","etags":{"tokens.txt":"\\"x\\""},"verificados":[]}',
      );
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
      expect(servidor.pedidasDe(contenido.direccion('ana', 'tokens.txt')), 0);
      expect(await g.estado('ana'), EstadoModelo.instalado);
    });

    test(
      'una descarga a medias de otra revisión del catálogo se tira',
      () async {
        final g = crear();
        File(ruta('ana.descarga/ana.onnx.parcial'))
          ..createSync(recursive: true)
          ..writeAsBytesSync(List.filled(500, 1));
        File(ruta('ana.descarga/estado.json')).writeAsStringSync(
          '{"revision":"rev0","etags":{"ana.onnx":"\\"x\\""},"verificados":[]}',
        );
        final r = await correr(g.descargar('ana'));
        expect(r.error, isNull);
        expect(
          servidor.peticiones.first.cabeceras.containsKey('range'),
          isFalse,
        );
      },
    );
  });

  group('criterio 22: huella incorrecta', () {
    test('bytes distintos: HuellaIncorrecta, y se borran el archivo y la carpeta de descarga', () async {
      final g = crear();
      servidor.alterar.add(contenido.direccion('ana', 'tokens.txt'));
      final r = await correr(g.descargar('ana'));
      expect(r.error, isA<HuellaIncorrecta>());
      expect((r.error! as HuellaIncorrecta).archivo, 'tokens.txt');
      expect(existe('ana.descarga'), isFalse);
      expect(existe('ana'), isFalse);
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      expect(
        await g.rutasParaCargar('ana'),
        isNull,
        reason: 'no hay nada que cargar',
      );
      expect(await g.bytesOcupados(), 0);
    });

    test(
      'no hay reintento automático: el archivo malo se pidió una sola vez',
      () async {
        final g = crear();
        final malo = contenido.direccion('ana', 'ana.onnx');
        servidor.alterar.add(malo);
        await correr(g.descargar('ana'));
        expect(servidor.pedidasDe(malo), 1);
      },
    );

    test(
      'si lo malo es el primer archivo, no se baja ninguno de los demás',
      () async {
        final g = crear();
        servidor.alterar.add(contenido.direccion('ana', 'ana.onnx'));
        await correr(g.descargar('ana'));
        expect(servidor.peticiones, hasLength(1));
      },
    );

    test(
      'un archivo de otro tamaño en el servidor se rechaza sin bajarlo',
      () async {
        final g = crear();
        final tokens = contenido.direccion('ana', 'tokens.txt');
        servidor.contenido[tokens] = List.filled(9999, 3);
        final r = await correr(g.descargar('ana'));
        expect(r.error, isA<HuellaIncorrecta>());
        expect(existe('ana.descarga'), isFalse);
      },
    );

    test('después de una huella mala se puede volver a intentar con el servidor arreglado', () async {
      final g = crear();
      final malo = contenido.direccion('ana', 'lexicon-en-us.txt');
      servidor.alterar.add(malo);
      await correr(g.descargar('ana'));
      servidor.alterar.clear();
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
      expect(await g.estado('ana'), EstadoModelo.instalado);
    });
  });

  group('criterio 23: instalación atómica', () {
    test(
      'interrumpida entre archivos: nunca instalado y no se carga',
      () async {
        final g = crear();
        servidor.codigoFijo[contenido.direccion('ana', 'lexicon-en-us.txt')] =
            500;
        final r = await correr(g.descargar('ana'));
        expect(r.error, isA<DescargaInterrumpida>());
        expect(await g.estado('ana'), EstadoModelo.noDescargado);
        expect(existe('ana'), isFalse, reason: 'la carpeta final no existe');
        expect(
          existe('ana.descarga/ana.onnx'),
          isTrue,
          reason: 'lo verificado se conserva',
        );
        expect(await g.rutasParaCargar('ana'), isNull);
        expect(await g.bytesDescargados('ana'), 30000 + 120);
      },
    );

    test('un modelo a medias nunca aparece como instalado aunque tenga todos los archivos', () async {
      final g = crear();
      // Todos los archivos listos en la carpeta de descarga, pero sin
      // `instalado.json` ni renombrar: no es un modelo.
      for (final e in contenido.archivos['ana']!.entries) {
        File(ruta('ana.descarga/${e.key}'))
          ..createSync(recursive: true)
          ..writeAsBytesSync(e.value);
      }
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      expect(await g.rutasParaCargar('ana'), isNull);
    });

    test(
      'una carpeta final sin instalado.json no es un modelo instalado',
      () async {
        final g = crear();
        for (final e in contenido.archivos['ana']!.entries) {
          File(ruta('ana/${e.key}'))
            ..createSync(recursive: true)
            ..writeAsBytesSync(e.value);
        }
        expect(await g.estado('ana'), EstadoModelo.noDescargado);
      },
    );

    test('404 en un archivo: NoDisponibleAun, y al estar el archivo se reanuda sin repetir los demás', () async {
      final g = crear();
      final lexicon = contenido.direccion('ana', 'lexicon-en-us.txt');
      final guardado = servidor.contenido.remove(lexicon)!;
      final r = await correr(g.descargar('ana'));
      expect(r.error, isA<NoDisponibleAun>());
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      servidor.contenido[lexicon] = guardado;
      servidor.peticiones.clear();
      final r2 = await correr(g.descargar('ana'));
      expect(r2.error, isNull);
      expect(servidor.pedidasDe(contenido.direccion('ana', 'ana.onnx')), 0);
      expect(await g.estado('ana'), EstadoModelo.instalado);
    });

    test('si no hay nada en el alojamiento (404 en todo): NoDisponibleAun y no se deja nada', () async {
      final g = crear(puerta: PuertaDeDescargaFalsa({}));
      final r = await correr(g.descargar('ana'));
      expect(r.error, isA<NoDisponibleAun>());
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      expect(await g.rutasParaCargar('ana'), isNull);
    });

    test('Supabase contesta 400 o 403 cuando el archivo o el bucket no existen: también NoDisponibleAun', () async {
      for (final codigo in [400, 403, 404, 410]) {
        final s = contenido.servidor();
        s.codigoFijo[contenido.direccion('ana', 'ana.onnx')] = codigo;
        final r = await correr(crear(puerta: s).descargar('ana'));
        expect(r.error, isA<NoDisponibleAun>(), reason: '$codigo');
      }
    });

    test('un error 500 del servidor es una descarga interrumpida, no "no disponible"', () async {
      servidor.codigoFijo[contenido.direccion('ana', 'ana.onnx')] = 503;
      final r = await correr(crear().descargar('ana'));
      expect(r.error, isA<DescargaInterrumpida>());
    });
  });

  group('criterio 24: disco lleno', () {
    test('SinEspacio, sin carpeta a medias y con el estado anterior', () async {
      for (final codigo in [28, 112, 39, 122]) {
        final d = Directory.systemTemp.createTempSync('gravity_voz_lleno_');
        addTearDown(() => d.deleteSync(recursive: true));
        final g = GestorDeModelosEnDisco(
          catalogo: catalogo,
          raiz: () async => d.path,
          red: red,
          puerta: servidor,
          archivos: DiscoQueSeLlena(hastaBytes: 20000, codigo: codigo),
          huella: huellaSha256,
          pasoDeProgreso: 1024,
        );
        final r = await correr(g.descargar('ana'));
        expect(r.error, isA<SinEspacio>(), reason: 'código $codigo');
        expect((r.error! as SinEspacio).bytesNecesarios, greaterThan(0));
        expect(Directory('${d.path}/ana.descarga').existsSync(), isFalse);
        expect(Directory('${d.path}/ana').existsSync(), isFalse);
        expect(await g.estado('ana'), EstadoModelo.noDescargado);
        expect(
          await g.bytesOcupados(),
          0,
          reason: 'se libera lo que se había escrito',
        );
      }
    });

    test(
      'un error del disco que no es de espacio no se confunde con SinEspacio',
      () async {
        final r = await correr(
          crear(archivos: const DiscoSinPermiso()).descargar('ana'),
        );
        expect(r.error, isA<FalloDeSintesis>());
        expect(r.error, isNot(isA<SinEspacio>()));
      },
    );

    test('si el sistema sabe cuánto espacio hay y no alcanza, avisa antes de abrir ninguna conexión', () async {
      final g = crear(archivos: const DiscoConPocoEspacio(5000));
      final r = await correr(g.descargar('ana'));
      expect(r.error, isA<SinEspacio>());
      expect(
        (r.error! as SinEspacio).bytesNecesarios,
        catalogo.porId('ana')!.bytes - 5000,
      );
      expect(servidor.peticiones, isEmpty);
      expect(existe('ana.descarga'), isFalse);
    });

    test('con espacio de sobra descarga normal', () async {
      final g = crear(
        archivos: DiscoConPocoEspacio(catalogo.porId('ana')!.bytes),
      );
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
    });
  });

  group('cancelar', () {
    test('conserva lo descargado para reanudar y no es un error', () async {
      final g = crear();
      final progreso = <ProgresoDescarga>[];
      Object? error;
      final fin = Completer<void>();
      var cancelado = false;
      g
          .descargar('ana')
          .listen(
            (p) {
              progreso.add(p);
              if (!cancelado && p.bytes >= 8000) {
                cancelado = true;
                unawaited(g.cancelar('ana'));
              }
            },
            onError: (Object e) => error = e,
            onDone: fin.complete,
          );
      await fin.future;
      expect(error, isNull);
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      expect(await g.bytesDescargados('ana'), greaterThanOrEqualTo(8000));
      expect(existe('ana'), isFalse);
      servidor.peticiones.clear();
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
      expect(
        servidor.peticiones.first.cabeceras['range'],
        startsWith('bytes='),
      );
      expect(
        File(ruta('ana/ana.onnx')).readAsBytesSync(),
        contenido.archivos['ana']!['ana.onnx'],
      );
    });

    test('cancelar sin descarga en curso no hace nada', () async {
      await crear().cancelar('ana');
    });
  });

  group('criterio 25: borrar', () {
    test('libera el espacio, el modelo vuelve a noDescargado y no hay nada que cargar', () async {
      final g = crear();
      await correr(g.descargar('ana'));
      await correr(g.descargar('beto'));
      final antes = await g.bytesOcupados();
      final deAna = await g.bytesOcupadosPor('ana');
      expect(deAna, greaterThanOrEqualTo(catalogo.porId('ana')!.bytes));
      final liberados = await g.borrar('ana');
      expect(liberados, deAna);
      expect(await g.bytesOcupados(), antes - deAna);
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      expect(
        await g.estado('beto'),
        EstadoModelo.instalado,
        reason: 'no toca a los demás',
      );
      expect(await g.rutasParaCargar('ana'), isNull);
      expect(existe('ana'), isFalse);
    });

    test(
      'antes de borrar avisa a quien debe parar la voz y soltar el modelo',
      () async {
        final g = crear();
        await correr(g.descargar('ana'));
        final vistos = <String>[];
        final quitar = g.antesDeBorrar((id) async {
          // Todavía está en disco cuando se llama.
          vistos.add('$id:${await g.estado(id)}');
        });
        await g.borrar('ana');
        expect(vistos, ['ana:EstadoModelo.instalado']);
        quitar();
        await correr(g.descargar('ana'));
        await g.borrar('ana');
        expect(vistos, hasLength(1), reason: 'el aviso se quitó');
      },
    );

    test('un aviso que falla no impide borrar', () async {
      final g = crear();
      await correr(g.descargar('ana'));
      g.antesDeBorrar((_) async => throw StateError('falla'));
      await g.borrar('ana');
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
    });

    test('borra también una descarga a medias', () async {
      final g = crear();
      servidor.cortarDespuesDe[contenido.direccion('ana', 'ana.onnx')] = 7000;
      await correr(g.descargar('ana'));
      expect(await g.bytesOcupados(), greaterThan(0));
      final liberados = await g.borrar('ana');
      expect(liberados, greaterThanOrEqualTo(7000));
      expect(await g.bytesOcupados(), 0);
      expect(await g.bytesDescargados('ana'), 0);
    });

    test('borrar mientras descarga la cancela y borra', () async {
      final g = crear();
      servidor.pausaDelCuerpo = Completer<void>();
      final r = correr(g.descargar('ana'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await g.borrar('ana');
      if (!servidor.pausaDelCuerpo!.isCompleted) {
        servidor.pausaDelCuerpo!.complete();
      }
      await r;
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      expect(existe('ana'), isFalse);
      expect(existe('ana.descarga'), isFalse);
    });
  });

  group('criterio 26: marca de carga y modelo dañado', () {
    Future<GestorDeModelosEnDisco> instalado() async {
      final g = crear();
      await correr(g.descargar('ana'));
      return g;
    }

    test(
      'si la marca de carga sigue ahí, el modelo queda corrupto y no se carga',
      () async {
        final g = await instalado();
        expect(await g.estado('ana'), EstadoModelo.instalado);
        await g.iniciarCarga('ana');
        expect(await g.estado('ana'), EstadoModelo.corrupto);
        expect(await g.rutasParaCargar('ana'), isNull);
      },
    );

    test('al terminar la carga se borra la marca', () async {
      final g = await instalado();
      await g.iniciarCarga('ana');
      await g.terminarCarga('ana');
      expect(await g.estado('ana'), EstadoModelo.instalado);
    });

    test('la marca sobrevive a un reinicio: otro gestor sobre la misma carpeta ve corrupto', () async {
      final g = await instalado();
      await g.iniciarCarga('ana');
      final tras = crear();
      expect(await tras.estado('ana'), EstadoModelo.corrupto);
      // Hasta que se reintente o se borre.
      expect(await tras.reintentar('ana'), EstadoModelo.instalado);
      expect(await tras.rutasParaCargar('ana'), isNotNull);
    });

    test('o se borra', () async {
      final g = await instalado();
      await g.iniciarCarga('ana');
      await g.borrar('ana');
      expect(await g.estado('ana'), EstadoModelo.noDescargado);
      await correr(g.descargar('ana'));
      expect(
        await g.estado('ana'),
        EstadoModelo.instalado,
        reason: 'sin marcas viejas',
      );
    });

    test(
      'marcarCorrupto deja el modelo dañado hasta que se reintente',
      () async {
        final g = await instalado();
        await g.marcarCorrupto('ana');
        expect(await g.estado('ana'), EstadoModelo.corrupto);
        expect(await g.reintentar('ana'), EstadoModelo.instalado);
      },
    );

    test(
      'reintentar vuelve a comprobar: con un archivo alterado sigue corrupto',
      () async {
        final g = await instalado();
        final f = File(ruta('ana/ana.onnx'));
        final bytes = f.readAsBytesSync();
        bytes[100] ^= 0xFF;
        f.writeAsBytesSync(bytes);
        expect(
          await g.estado('ana'),
          EstadoModelo.instalado,
          reason: 'al arrancar solo se miden tamaños',
        );
        await g.marcarCorrupto('ana');
        expect(await g.reintentar('ana'), EstadoModelo.corrupto);
      },
    );

    test('comprobar recalcula la huella de cada archivo', () async {
      final g = await instalado();
      expect(await g.comprobar('ana'), isTrue);
      expect(await g.estado('ana'), EstadoModelo.instalado);
      final f = File(ruta('ana/tokens.txt'));
      final bytes = f.readAsBytesSync();
      bytes[3] ^= 0x01;
      f.writeAsBytesSync(bytes);
      expect(await g.comprobar('ana'), isFalse);
      expect(await g.estado('ana'), EstadoModelo.corrupto);
    });

    test('un archivo que ya no pesa lo que dice el catálogo deja el modelo corrupto', () async {
      final g = await instalado();
      File(ruta('ana/ana.onnx')).writeAsBytesSync([1, 2, 3]);
      expect(await g.estado('ana'), EstadoModelo.corrupto);
      expect(await g.rutasParaCargar('ana'), isNull);
    });

    test('un archivo que falta deja el modelo corrupto', () async {
      final g = await instalado();
      File(ruta('ana/lexicon-en-us.txt')).deleteSync();
      expect(await g.estado('ana'), EstadoModelo.corrupto);
    });

    test('descargar de nuevo reemplaza un modelo dañado', () async {
      final g = await instalado();
      File(ruta('ana/ana.onnx')).writeAsBytesSync([1, 2, 3]);
      final r = await correr(g.descargar('ana'));
      expect(r.error, isNull);
      expect(await g.estado('ana'), EstadoModelo.instalado);
      expect(
        File(ruta('ana/ana.onnx')).readAsBytesSync(),
        contenido.archivos['ana']!['ana.onnx'],
      );
    });

    test(
      'una marca suelta sin carpeta no deja al modelo en un limbo',
      () async {
        final g = crear();
        await g.marcarCorrupto('ana');
        expect(await g.estado('ana'), EstadoModelo.noDescargado);
        await correr(g.descargar('ana'));
        expect(await g.estado('ana'), EstadoModelo.instalado);
      },
    );
  });

  group('el catálogo cambia', () {
    test('si la revisión o las huellas son otras, la copia vieja ya no cuenta como instalada', () async {
      final g = await (() async {
        final g = crear();
        await correr(g.descargar('ana'));
        return g;
      })();
      expect(await g.estado('ana'), EstadoModelo.instalado);
      final mapa = contenido.comoMapa();
      final modelos = mapa['modelos']! as List;
      ((modelos.first as Map)['fuente'] as Map)['revision'] = 'rev2';
      for (final a in (modelos.first as Map)['archivos'] as List) {
        a['url'] = (a['url'] as String).replaceFirst('/rev1/', '/rev2/');
      }
      final otro = crear(cat: leerCatalogoDe(mapa));
      expect(await otro.estado('ana'), EstadoModelo.noDescargado);
    });
  });

  group(
    'criterio 16: ni errores ni registros llevan direcciones, rutas ni textos',
    () {
      test('toString de cada error de descarga es corto y sin direcciones', () {
        final errores = <ErrorVoz>[
          const SinWifi(),
          const SinRed(),
          const SinEspacio(1234),
          const HuellaIncorrecta('ana.onnx'),
          const DescargaInterrumpida(10, 20),
          const NoDisponibleAun(),
        ];
        for (final e in errores) {
          final t = e.toString();
          expect(t, isNot(contains('http')));
          expect(t, isNot(contains('ejemplo.test')));
          expect(t, isNot(contains('://')));
          expect(t, isNot(contains(r'\')));
          expect(t.length, lessThan(40));
        }
      });

      test('lo que se registra durante descargas fallidas no trae direcciones ni rutas', () async {
        final registro = <String>[];
        final anterior = debugPrint;
        debugPrint = (String? m, {int? wrapWidth}) => registro.add(m ?? '');
        addTearDown(() => debugPrint = anterior);
        final casos = <void Function()>[
          () => servidor.falloAlPedir = const SocketException(
            'https://voces.ejemplo.test/secreto',
          ),
          () {
            servidor.falloAlPedir = null;
            servidor.cortarDespuesDe[contenido.direccion('ana', 'ana.onnx')] =
                5000;
          },
          () => servidor.alterar.add(contenido.direccion('beto', 'tokens.txt')),
        ];
        final g = crear();
        for (final preparar in casos) {
          preparar();
          await correr(g.descargar('ana'));
          await correr(g.descargar('beto'));
        }
        final todo = registro.join('\n');
        expect(todo, isNot(contains('ejemplo.test')));
        expect(todo, isNot(contains('secreto')));
        expect(todo, isNot(contains(dir.path)));
      });
    },
  );
}

/// Un catálogo armado desde un mapa (para cambiar una revisión).
CatalogoDeVoces leerCatalogoDe(Map<String, Object?> mapa) =>
    leerCatalogo(jsonEncode(mapa));
