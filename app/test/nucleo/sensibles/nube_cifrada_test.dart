// La nube cifrada de Hábitos (P5, E7 de la Fase 4): activar con la frase,
// cambiar de modo sin perder nada, añadir un equipo, reiniciar y detectar la
// época. Servidor simulado en memoria; frase real de 12 palabras.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitos_dominio/habitos_dominio.dart'
    show DocumentoSensible, ElementoDoc;
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/cripto.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/nube_cifrada.dart';
import 'package:gravity/nucleo/sensibles/nube_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';

const persona = 'ana';
const tipo = TipoSensible.diarioOracion;

class _Equipo {
  _Equipo(this.servidor) : almacen = AlmacenSeguroEnMemoria() {
    llaves = LlavesHabitos(almacen);
    sobres = AlmacenDeSobres(almacen);
    modos = ModosLocales(almacen);
    nube = NubeCifradaHabitos(
      llaves: llaves,
      sobres: sobres,
      modos: modos,
      almacen: almacen,
      servidor: servidor,
    );
  }

  final AdministracionNubeHabitosEnMemoria servidor;
  final AlmacenSeguroEnMemoria almacen;
  late final LlavesHabitos llaves;
  late final AlmacenDeSobres sobres;
  late final ModosLocales modos;
  late final NubeCifradaHabitos nube;

  /// Escribe un documento en el modo local, como lo haría Hábitos.
  Future<void> escribir(String clave, String texto) async {
    final modo = await modos.modo(persona, tipo);
    final lt = (await llaves.llaveDeTipo(persona, tipo, modo))!;
    final li = (await llaves.llaveDeIds(persona, modo))!;
    final id = LlavesHabitos.idOpaco(li, tipo, clave);
    final anterior = await sobres.leer(persona, id);
    await sobres.guardar(
      persona,
      cifrarDocumento(
        llaveDeTipo: lt,
        llaveDeIds: li,
        persona: persona,
        tipo: tipo,
        claveDoc: clave,
        documento: {
          'clave': clave,
          'doc': DocumentoSensible({
            texto: ElementoDoc(
              id: texto,
              clase: 'nota',
              modificadoEn: 1000,
              datos: {'texto': texto},
            ),
          }).aJson(),
        },
        revisionAnterior: anterior?.revision ?? 0,
      ),
    );
  }

  /// Los textos de todos los documentos que este equipo puede abrir.
  Future<List<String>> leerTodo() async {
    final modo = await modos.modo(persona, tipo);
    final lt = (await llaves.llaveDeTipo(persona, tipo, modo))!;
    return [
      for (final s in await sobres.todos(persona, tipo: tipo))
        ..._textos(
          descifrarDocumento(llaveDeTipo: lt, persona: persona, sobre: s),
        ),
    ];
  }
}

List<String> _textos(Map<String, Object?>? doc) {
  if (doc == null) return ['<no abre>'];
  return [
    for (final e in DocumentoSensible.deJson(
      (doc['doc']! as Map).cast<String, Object?>(),
    ).elementos.values)
      e.datos['texto']! as String,
  ];
}

void main() {
  late AdministracionNubeHabitosEnMemoria servidor;
  late _Equipo telefono;
  final frase = FraseDeRecuperacion.generar();

  setUp(() {
    servidor = AdministracionNubeHabitosEnMemoria();
    telefono = _Equipo(servidor);
  });

  /// Lo que "sube" la subida diferida: los sobres locales a la nube.
  Future<void> subir(_Equipo e) async {
    servidor.sobresPorTipo[tipo]!
      ..clear()
      ..addAll(await e.sobres.todos(persona, tipo: tipo));
  }

  group('estado inicial', () {
    test('todo solo teléfono y sin llave: nada sale', () async {
      final estado = await telefono.nube.estado(persona);
      expect(estado.modoDe(tipo), ModoSensible.soloTelefono);
      expect(estado.tieneLlave, isFalse);
      expect(estado.hayNubeEnServidor, isFalse);
      expect(servidor.llave, isNull);
    });
  });

  group('activar', () {
    test(
      'guarda la llave envuelta, pasa a nube y conserva lo escrito',
      () async {
        await telefono.escribir('dia:2026-11-01', 'oración uno');
        await telefono.escribir('dia:2026-11-02', 'oración dos');
        await telefono.nube.activar(persona, frase, tipos: {tipo});
        expect(servidor.modos[tipo], ModoSensible.nubeCifrada);
        expect(
          servidor.modos[TipoSensible.habitosSensibles],
          ModoSensible.soloTelefono,
        );
        expect(servidor.llave!.version, 1);
        expect(servidor.llave!.kdf, LlaveEnvuelta.kdfPbkdf2);
        expect(servidor.llave!.vueltas, 600000);
        expect(
          await telefono.modos.modo(persona, tipo),
          ModoSensible.nubeCifrada,
        );
        expect(await telefono.llaves.tieneLlaveMaestra(persona), isTrue);
        // Lo escrito sigue abriendo, ahora con la llave maestra.
        expect(
          await telefono.leerTodo(),
          unorderedEquals(['oración uno', 'oración dos']),
        );
        // La llave que guardó el servidor se abre con la frase.
        expect(await servidor.llave!.desenvolver(frase), isNotNull);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('una frase con una palabra cambiada no se acepta', () async {
      final mala = [...frase]..[3] = frase[3] == 'casa' ? 'mesa' : 'casa';
      if (FraseDeRecuperacion.esValida(mala)) return; // rarísimo
      await expectLater(
        telefono.nube.activar(persona, mala, tipos: {tipo}),
        throwsA(isA<ErrorNubeCifrada>()),
      );
      expect(servidor.llave, isNull);
    });

    test('sin señal no cambia nada en el equipo', () async {
      await telefono.escribir('dia:2026-11-01', 'uno');
      servidor.sinConexion = true;
      await expectLater(
        telefono.nube.activar(persona, frase, tipos: {tipo}),
        throwsA(ErrorNubeCifrada.sinConexion),
      );
      servidor.sinConexion = false;
      expect(
        await telefono.modos.modo(persona, tipo),
        ModoSensible.soloTelefono,
      );
      expect(await telefono.leerTodo(), ['uno']);
    });
  });

  group('añadir equipo', () {
    test('con la frase correcta abre lo de la nube; con otra, no', () async {
      await telefono.escribir('dia:2026-11-01', 'desde el teléfono');
      await telefono.nube.activar(persona, frase, tipos: {tipo});
      await subir(telefono);

      final laptop = _Equipo(servidor);
      final otra = FraseDeRecuperacion.generar();
      await expectLater(
        laptop.nube.anadirEquipo(persona, otra),
        throwsA(ErrorNubeCifrada.fraseIncorrecta),
      );
      expect(await laptop.llaves.tieneLlaveMaestra(persona), isFalse);

      await laptop.nube.anadirEquipo(persona, frase);
      expect(await laptop.modos.modo(persona, tipo), ModoSensible.nubeCifrada);
      expect(await laptop.leerTodo(), ['desde el teléfono']);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('sin nube activada lo dice', () async {
      await expectLater(
        telefono.nube.anadirEquipo(persona, frase),
        throwsA(ErrorNubeCifrada.sinNube),
      );
    });
  });

  group('volver a solo teléfono', () {
    test('trae lo que falta, borra la nube y no pierde nada', () async {
      await telefono.escribir('dia:2026-11-01', 'del teléfono');
      await telefono.nube.activar(persona, frase, tipos: {tipo});
      await subir(telefono);
      // La laptop escribe algo que el teléfono aún no tiene.
      final laptop = _Equipo(servidor);
      await laptop.nube.anadirEquipo(persona, frase);
      await laptop.escribir('dia:2026-11-02', 'de la laptop');
      await subir(laptop);

      await telefono.nube.volverASoloTelefono(persona, tipo);
      expect(servidor.modos[tipo], ModoSensible.soloTelefono);
      expect(servidor.sobresPorTipo[tipo], isEmpty);
      expect(
        await telefono.modos.modo(persona, tipo),
        ModoSensible.soloTelefono,
      );
      expect(
        await telefono.leerTodo(),
        unorderedEquals(['del teléfono', 'de la laptop']),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('sin señal no cambia nada (ni se pierde nada)', () async {
      await telefono.escribir('dia:2026-11-01', 'uno');
      await telefono.nube.activar(persona, frase, tipos: {tipo});
      servidor.sinConexion = true;
      await expectLater(
        telefono.nube.volverASoloTelefono(persona, tipo),
        throwsA(ErrorNubeCifrada.sinConexion),
      );
      servidor.sinConexion = false;
      expect(
        await telefono.modos.modo(persona, tipo),
        ModoSensible.nubeCifrada,
      );
      expect(await telefono.leerTodo(), ['uno']);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('cambiar y verificar la frase', () {
    test('la nueva abre, la vieja deja de servir y los datos siguen', () async {
      await telefono.escribir('dia:2026-11-01', 'uno');
      await telefono.nube.activar(persona, frase, tipos: {tipo});
      final nueva = FraseDeRecuperacion.generar();
      expect(await telefono.nube.verificarFrase(frase), isTrue);
      await telefono.nube.cambiarFrase(persona, nueva);
      expect(servidor.llave!.version, 2);
      expect(await telefono.nube.verificarFrase(nueva), isTrue);
      expect(await telefono.nube.verificarFrase(frase), isFalse);
      expect(await telefono.leerTodo(), ['uno']);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('sin la llave en este equipo no se puede cambiar', () async {
      await telefono.nube.activar(persona, frase, tipos: {tipo});
      final otro = _Equipo(servidor);
      await expectLater(
        otro.nube.cambiarFrase(persona, FraseDeRecuperacion.generar()),
        throwsA(ErrorNubeCifrada.sinLlaveEnEsteEquipo),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('reiniciar la nube', () {
    test('con la llave en el equipo, lo suyo se conserva en local', () async {
      await telefono.escribir('dia:2026-11-01', 'uno');
      await telefono.nube.activar(persona, frase, tipos: {tipo});
      await telefono.nube.reiniciar(persona);
      expect(servidor.llave, isNull);
      expect(servidor.modos[tipo], ModoSensible.soloTelefono);
      expect(
        await telefono.modos.modo(persona, tipo),
        ModoSensible.soloTelefono,
      );
      expect(await telefono.llaves.tieneLlaveMaestra(persona), isFalse);
      expect(await telefono.leerTodo(), ['uno']);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('sin llave (frase perdida) se descarta lo que no abre', () async {
      await telefono.escribir('dia:2026-11-01', 'uno');
      await telefono.nube.activar(persona, frase, tipos: {tipo});
      await subir(telefono);
      final laptop = _Equipo(servidor);
      await laptop.nube.anadirEquipo(persona, frase);
      // Se pierde la llave de la laptop (equipo sin la llave maestra).
      await laptop.almacen.borrar('hab.llave_maestra.$persona');
      laptop.llaves.olvidarEnMemoria();
      await laptop.nube.reiniciar(persona);
      expect(servidor.llave, isNull);
      expect(await laptop.modos.modo(persona, tipo), ModoSensible.soloTelefono);
      expect(await laptop.sobres.todos(persona, tipo: tipo), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('época', () {
    test(
      'otro equipo volvió a solo teléfono: este deja de creer en la nube',
      () async {
        await telefono.escribir('dia:2026-11-01', 'uno');
        await telefono.nube.activar(persona, frase, tipos: {tipo});
        await subir(telefono);
        final laptop = _Equipo(servidor);
        await laptop.nube.anadirEquipo(persona, frase);
        expect(await laptop.nube.revisarEpoca(persona), isFalse);

        await telefono.nube.volverASoloTelefono(persona, tipo);
        expect(await laptop.nube.revisarEpoca(persona), isTrue);
        expect(
          await laptop.modos.modo(persona, tipo),
          ModoSensible.soloTelefono,
        );
        expect(await laptop.sobres.todos(persona, tipo: tipo), isEmpty);
        expect(await laptop.nube.revisarEpoca(persona), isFalse);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('sin señal no hace nada', () async {
      servidor.sinConexion = true;
      expect(await telefono.nube.revisarEpoca(persona), isFalse);
    });
  });

  test('Uint8List de relleno para silenciar imports', () {
    expect(Uint8List(1), hasLength(1));
    expect(bytesAleatorios(4), hasLength(4));
  });
}
