// Datos sensibles de Hábitos (Fase 3, D13, D21): frase, llaves, sobres, subida
// diferida por la cola, respaldo local, exportar y borrar.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/cripto.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/mis_datos.dart';
import 'package:gravity/nucleo/sensibles/nube_habitos.dart';
import 'package:gravity/nucleo/sensibles/palabras_es.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'dart:math';

class _EnviadorNulo implements Enviador {
  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async => ResultadoEnvio.enviado;
}

void main() {
  late AlmacenSeguroEnMemoria almacen;
  setUp(() => almacen = AlmacenSeguroEnMemoria());

  group('frase de recuperación', () {
    test('la lista tiene 2048 palabras distintas', () {
      expect(palabrasEs, hasLength(2048));
      expect(palabrasEs.toSet(), hasLength(2048));
    });

    test('12 palabras de la lista, válidas y distintas cada vez', () {
      final a = FraseDeRecuperacion.generar();
      final b = FraseDeRecuperacion.generar();
      expect(a, hasLength(12));
      expect(a.every(palabrasEs.contains), isTrue);
      expect(FraseDeRecuperacion.esValida(a), isTrue);
      expect(a, isNot(b));
    });

    test('vector BIP-39: entropía de ceros → "ábaco ×11 + abierto"', () {
      final frase = FraseDeRecuperacion.desdeEntropia(List.filled(16, 0));
      expect(frase.take(11).every((w) => w == 'ábaco'), isTrue);
      expect(FraseDeRecuperacion.esValida(frase), isTrue);
    });

    test('detecta una palabra cambiada, de otra lista o de menos', () {
      final frase = FraseDeRecuperacion.generar();
      final cambiada = [...frase]..[3] = frase[3] == 'ábaco' ? 'abdomen' : 'ábaco';
      // Cambiar una palabra casi siempre rompe la verificación de 4 bits.
      var rotas = 0;
      for (final reemplazo in palabrasEs.take(64)) {
        final f = [...frase]..[0] = reemplazo;
        if (reemplazo != frase[0] && !FraseDeRecuperacion.esValida(f)) rotas++;
      }
      expect(rotas, greaterThan(40));
      expect(FraseDeRecuperacion.esValida([...frase]..[0] = 'zzzz'), isFalse);
      expect(FraseDeRecuperacion.esValida(frase.take(11).toList()), isFalse);
      expect(cambiada, hasLength(12));
    });

    test('normalizar y confirmar con 3 palabras al azar', () {
      expect(FraseDeRecuperacion.normalizar('  ÁBACO   Abdomen\nabeja '), ['ábaco', 'abdomen', 'abeja']);
      final frase = FraseDeRecuperacion.generar();
      final pos = FraseDeRecuperacion.posicionesDeConfirmacion(azar: Random(1));
      expect(pos, hasLength(3));
      expect(pos.toSet(), hasLength(3));
      expect(pos, [...pos]..sort());
      expect(FraseDeRecuperacion.confirma(frase, pos, [for (final p in pos) frase[p]]), isTrue);
      expect(
        FraseDeRecuperacion.confirma(frase, pos, [for (final p in pos) frase[(p + 1) % 12]]),
        isFalse,
      );
      expect(FraseDeRecuperacion.confirma(frase, pos, ['a']), isFalse);
    });
  });

  group('frase sin acentos, mayúsculas o descompuesta (F3-6)', () {
    test('las 2048 palabras son distintas aun sin acentos (nada se confunde)', () {
      expect(palabrasEs.map(FraseDeRecuperacion.claveDePalabra).toSet(), hasLength(2048));
    });

    test('se reconoce con la á descompuesta, sin acentos y en mayúsculas', () {
      final frase = FraseDeRecuperacion.desdeEntropia(List.filled(16, 0));
      final descompuesta = frase.map((p) => p.replaceAll('á', 'a\u0301')).join(' ');
      final sinAcentos = frase.map(FraseDeRecuperacion.claveDePalabra).join(' ');
      final mayusculas = frase.join(' ').toUpperCase();
      for (final tecleada in [descompuesta, sinAcentos, mayusculas, '  ${frase.join('   ')} \n']) {
        final n = FraseDeRecuperacion.normalizar(tecleada);
        expect(n, frase, reason: tecleada);
        expect(FraseDeRecuperacion.esValida(n), isTrue);
      }
    });

    test('la ñ descompuesta o sin tilde también, y la clave sale igual', () async {
      final conEnie = palabrasEs.firstWhere((p) => p.contains('ñ'));
      expect(FraseDeRecuperacion.canonica(conEnie.replaceAll('ñ', 'n\u0303')), conEnie);
      expect(FraseDeRecuperacion.canonica(conEnie.replaceAll('ñ', 'n')), conEnie);
      final frase = FraseDeRecuperacion.generar();
      final env = await LlaveEnvuelta.envolver(bytesAleatorios(32), frase, vueltas: 20);
      final escrita = FraseDeRecuperacion.normalizar(
        frase.map(FraseDeRecuperacion.claveDePalabra).join(' ').toUpperCase(),
      );
      expect(await env.desenvolver(escrita, minimo: 1), isNotNull);
    });

    test('lo que no es de la lista sigue sin validar', () {
      final frase = FraseDeRecuperacion.generar();
      expect(FraseDeRecuperacion.esValida(FraseDeRecuperacion.normalizar('${frase.take(11).join(' ')} zzzz')), isFalse);
    });
  });

  group('llave maestra envuelta', () {
    test('vueltas fuera de rango (100 000 a 2 000 000) se rechazan al abrir', () async {
      final maestra = bytesAleatorios(32);
      final frase = FraseDeRecuperacion.generar();
      final env = await LlaveEnvuelta.envolver(maestra, frase, vueltas: 100000);
      expect(await env.desenvolver(frase), maestra);
      for (final v in [0, 1, 99999, 2000001, 1 << 40]) {
        final mala = LlaveEnvuelta(
          version: env.version,
          kdf: env.kdf,
          vueltas: v,
          sal: env.sal,
          llaveEnvuelta: env.llaveEnvuelta,
        );
        expect(await mala.desenvolver(frase), isNull, reason: '$v');
      }
      expect(LlaveEnvuelta.vueltasEnRango(2000000), isTrue);
      expect(LlaveEnvuelta.vueltasEnRango(2000001), isFalse);
    });

    test('el nombre antiguo del KDF solo se lee; uno desconocido no abre', () async {
      final maestra = bytesAleatorios(32);
      final frase = FraseDeRecuperacion.generar();
      final env = await LlaveEnvuelta.envolver(maestra, frase, vueltas: 20);
      LlaveEnvuelta con(String kdf) => LlaveEnvuelta(
        version: env.version,
        kdf: kdf,
        vueltas: env.vueltas,
        sal: env.sal,
        llaveEnvuelta: env.llaveEnvuelta,
      );
      expect(await con(LlaveEnvuelta.kdfPbkdf2Antiguo).desenvolver(frase, minimo: 1), maestra);
      expect(await con('argon2id').desenvolver(frase, minimo: 1), isNull);
    });

    test('se abre con su frase y no con otra; la llave no sale en claro', () async {
      final maestra = bytesAleatorios(32);
      final frase = FraseDeRecuperacion.generar();
      final env = await LlaveEnvuelta.envolver(maestra, frase, vueltas: 50);
      expect(env.kdf, 'pbkdf2-hmac-sha256'); // el que admite el servidor
      expect(env.vueltas, 50);
      expect(env.llaveEnvuelta, isNot(contains(aBase64Url(maestra))));
      expect(await env.desenvolver(frase, minimo: 1), maestra);
      expect(await env.desenvolver(FraseDeRecuperacion.generar(), minimo: 1), isNull);
      final v = LlaveEnvuelta.desdeJson(
        (jsonDecode(jsonEncode(env.aJson())) as Map).cast<String, Object?>(),
      )!;
      expect(await v.desenvolver(frase, minimo: 1), maestra);
      expect(LlaveEnvuelta.desdeJson({'x': 1}), isNull);
    });

    test('por omisión son 600 000 vueltas (parámetros guardados para subirlas)', () {
      expect(LlaveEnvuelta.vueltasPorOmision, 600000);
    });

    test('la versión de la envoltura va en los datos asociados', () async {
      final maestra = bytesAleatorios(32);
      final frase = FraseDeRecuperacion.generar();
      final env = await LlaveEnvuelta.envolver(maestra, frase, vueltas: 20, version: 2);
      final cambiada = LlaveEnvuelta(
        version: 1,
        kdf: env.kdf,
        vueltas: env.vueltas,
        sal: env.sal,
        llaveEnvuelta: env.llaveEnvuelta,
      );
      expect(await cambiada.desenvolver(frase, minimo: 1), isNull);
    });
  });

  group('almacén de llaves', () {
    test('llave local: se crea una vez y se conserva; cada tipo tiene la suya', () async {
      final llaves = LlavesHabitos(almacen);
      final a = await llaves.llaveLocal('ana');
      expect(await llaves.llaveLocal('ana'), a);
      expect(await llaves.llaveLocal('beto'), isNot(a));
      final t1 = await llaves.llaveDeTipo('ana', TipoSensible.habitosSensibles, ModoSensible.soloTelefono);
      final t2 = await llaves.llaveDeTipo('ana', TipoSensible.diarioOracion, ModoSensible.soloTelefono);
      expect(t1, isNot(t2));
      expect(t1, isNot(a));
      // Persistida: otro objeto la lee igual.
      expect(await LlavesHabitos(almacen).llaveLocal('ana'), a);
    });

    test('en nube cifrada usa la llave maestra; sin ella, null', () async {
      final llaves = LlavesHabitos(almacen);
      expect(await llaves.llaveDeTipo('ana', TipoSensible.diarioOracion, ModoSensible.nubeCifrada), isNull);
      expect(await llaves.tieneLlaveMaestra('ana'), isFalse);
      final maestra = bytesAleatorios(32);
      await llaves.guardarLlaveMaestra('ana', maestra);
      expect(await llaves.tieneLlaveMaestra('ana'), isTrue);
      final nube = await llaves.llaveDeTipo('ana', TipoSensible.diarioOracion, ModoSensible.nubeCifrada);
      final local = await llaves.llaveDeTipo('ana', TipoSensible.diarioOracion, ModoSensible.soloTelefono);
      expect(nube, hkdfSha256(maestra, info: 'gravity-hab/v1/diario_oracion'));
      expect(nube, isNot(local));
    });

    test('la tablet pública nunca guarda ni usa llaves', () async {
      final llaves = LlavesHabitos(almacen, permitido: () => false);
      await expectLater(llaves.llaveLocal('ana'), throwsA(isA<LlaveNoPermitida>()));
      await expectLater(llaves.llaveMaestra('ana'), throwsA(isA<LlaveNoPermitida>()));
      await expectLater(
        llaves.guardarLlaveMaestra('ana', bytesAleatorios(32)),
        throwsA(isA<LlaveNoPermitida>()),
      );
      expect(almacen.datos, isEmpty);
    });

    test('tablet personal: con el PIN; sin él no abre, en el almacén no está en '
        'claro y al salir se olvida', () async {
      final llaves = LlavesHabitos(almacen, protegidaConPin: true);
      await expectLater(llaves.llaveLocal('ana'), throwsA(isA<LlaveBloqueada>()));
      // Copia: olvidarEnMemoria borra con ceros los bytes que guarda en memoria.
      final local = List<int>.of(await llaves.llaveLocal('ana', pin: '284651'));
      expect(almacen.datos.values.join(), isNot(contains(aBase64Url(Uint8List.fromList(local)))));
      // Dentro (en memoria) no pide más.
      expect(await llaves.llaveLocal('ana'), local);
      llaves.olvidarEnMemoria();
      await expectLater(llaves.llaveLocal('ana'), throwsA(isA<LlaveBloqueada>()));
      await expectLater(llaves.llaveLocal('ana', pin: '000000'), throwsA(isA<LlaveBloqueada>()));
      expect(await llaves.liberarConPin('ana', '000000'), isFalse);
      expect(await llaves.liberarConPin('ana', '284651'), isTrue);
      expect(await llaves.llaveLocal('ana'), local);
    });

    test('borrar quita las llaves del equipo', () async {
      final llaves = LlavesHabitos(almacen);
      await llaves.llaveLocal('ana');
      await llaves.guardarLlaveMaestra('ana', bytesAleatorios(32));
      await llaves.borrar('ana');
      expect(almacen.datos, isEmpty);
    });

    test('id opaco: estable por llave y clave, y no revela la fecha', () {
      final ids = bytesAleatorios(32);
      final a = LlavesHabitos.idOpaco(ids, TipoSensible.habitosSensibles, 'dia:2026-11-01');
      expect(a, LlavesHabitos.idOpaco(ids, TipoSensible.habitosSensibles, 'dia:2026-11-01'));
      expect(a, isNot(LlavesHabitos.idOpaco(ids, TipoSensible.habitosSensibles, 'dia:2026-11-02')));
      expect(a, isNot(LlavesHabitos.idOpaco(ids, TipoSensible.diarioOracion, 'dia:2026-11-01')));
      expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
      expect(a, isNot(contains('2026')));
    });
  });

  group('sobres', () {
    late LlavesHabitos llaves;
    setUp(() => llaves = LlavesHabitos(almacen));

    Future<Sobre> sobreDe(String dia, Map<String, Object?> doc, {int anterior = 0}) async {
      final tipo = TipoSensible.habitosSensibles;
      return cifrarDocumento(
        llaveDeTipo: (await llaves.llaveDeTipo('ana', tipo, ModoSensible.nubeCifrada))!,
        llaveDeIds: (await llaves.llaveDeIds('ana', ModoSensible.nubeCifrada))!,
        persona: 'ana',
        tipo: tipo,
        claveDoc: 'dia:$dia',
        documento: doc,
        revisionAnterior: anterior,
      );
    }

    setUp(() async => llaves.guardarLlaveMaestra('ana', bytesAleatorios(32)));

    test('cifrar y descifrar un documento; el texto claro no aparece', () async {
      final s = await sobreDe('2026-11-01', {'v': 1, 'elementos': {'a': {'clase': 'consumo', 'datos': 'cigarrillo x3'}}});
      expect(s.revision, 1);
      expect(jsonEncode(s.aJson()), isNot(contains('cigarrillo')));
      final llave = (await llaves.llaveDeTipo('ana', TipoSensible.habitosSensibles, ModoSensible.nubeCifrada))!;
      final doc = descifrarDocumento(llaveDeTipo: llave, persona: 'ana', sobre: s)!;
      expect((doc['elementos']! as Map)['a'], isNotNull);
      // Otra persona, otra revisión o un id distinto no lo abren.
      expect(descifrarDocumento(llaveDeTipo: llave, persona: 'beto', sobre: s), isNull);
      final movido = Sobre(id: s.id, tipo: s.tipo, revision: 2, cifrado: s.cifrado);
      expect(descifrarDocumento(llaveDeTipo: llave, persona: 'ana', sobre: movido), isNull);
    });

    test('la revisión sube de 1 en 1 y el tamaño tiene tope', () async {
      final s1 = await sobreDe('2026-11-01', {'x': 1});
      final s2 = await sobreDe('2026-11-01', {'x': 2}, anterior: s1.revision);
      expect((s1.revision, s2.revision, s2.id), (1, 2, s1.id));
      expect(
        () => sobreDe('2026-11-02', {'x': 'a' * 70000}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('el almacén guarda solo sobres, por persona y por tipo, y borra', () async {
      final store = AlmacenDeSobres(almacen);
      final s = await sobreDe('2026-11-01', {'secreto': 'sí'});
      await store.guardar('ana', s);
      expect((await store.leer('ana', s.id))!.cifrado, s.cifrado);
      expect(await store.leer('beto', s.id), isNull);
      expect(almacen.datos.values.join(), isNot(contains('secreto')));
      expect(await store.todos('ana'), hasLength(1));
      expect(await store.todos('ana', tipo: TipoSensible.diarioOracion), isEmpty);
      expect(await store.borrar('ana', tipo: TipoSensible.diarioOracion), 0);
      expect(await store.borrar('ana', tipo: TipoSensible.habitosSensibles), 1);
      expect(await store.todos('ana'), isEmpty);
    });
  });

  group('subida diferida por la cola', () {
    late BaseLocal base;
    late ColaSinConexion cola;
    late AlmacenDeSobres store;
    late ModosLocales modos;
    late LlavesHabitos llaves;
    late DateTime ahora;
    late SubidaDiferidaDeSobres subida;

    setUp(() async {
      base = BaseLocal.enMemoria();
      ahora = DateTime.utc(2026, 11, 1, 20);
      cola = ColaSinConexion(base: base, enviador: _EnviadorNulo(), reloj: () => ahora);
      store = AlmacenDeSobres(almacen);
      modos = ModosLocales(almacen);
      llaves = LlavesHabitos(almacen);
      await llaves.guardarLlaveMaestra('ana', bytesAleatorios(32));
      subida = SubidaDiferidaDeSobres(
        sobres: store,
        modos: modos,
        cola: cola,
        almacen: almacen,
        reloj: () => ahora,
      );
    });

    tearDown(() => base.close());

    Future<void> dia(int n, {TipoSensible tipo = TipoSensible.habitosSensibles}) async {
      final s = cifrarDocumento(
        llaveDeTipo: (await llaves.llaveDeTipo('ana', tipo, ModoSensible.nubeCifrada))!,
        llaveDeIds: (await llaves.llaveDeIds('ana', ModoSensible.nubeCifrada))!,
        persona: 'ana',
        tipo: tipo,
        claveDoc: 'dia:2026-10-${n.toString().padLeft(2, '0')}',
        documento: {'dia': n, 'texto': 'consumo secreto $n'},
      );
      await store.guardar('ana', s);
    }

    test('solo teléfono (por omisión): nada se encola, nunca', () async {
      await dia(1);
      expect(await modos.modo('ana', TipoSensible.habitosSensibles), ModoSensible.soloTelefono);
      expect(await subida.encolarPendientes('ana', forzar: true), 0);
      expect(await cola.registros(), isEmpty);
    });

    test('nube cifrada: encola sobres YA cifrados, sin texto claro, con el tipo '
        'de lo personal', () async {
      await modos.fijar('ana', TipoSensible.habitosSensibles, ModoSensible.nubeCifrada);
      await dia(1);
      await dia(2);
      expect(await subida.encolarPendientes('ana'), 2);
      final r = (await cola.registros()).single;
      expect(r.tipo, tipoColaSobres);
      expect(r.tipo, startsWith('habitos.'));
      expect(r.personaId, 'ana');
      expect(r.carga, isNot(contains('secreto')));
      expect(r.carga, isNot(contains('consumo')));
      final sobres = SubidaDiferidaDeSobres.sobresDeCarga(
        (jsonDecode(r.carga) as Map).cast<String, Object?>(),
      );
      expect(sobres, hasLength(2));
      expect(sobres.first.keys, containsAll(['id', 'tipo', 'revision', 'cifrado']));
      expect(funcionSubirSobres, 'hab_subir_sobres');
    });

    test('máximo una vez cada 6 horas; Sincronizar lo salta; no repite lo encolado',
        () async {
      await modos.fijar('ana', TipoSensible.habitosSensibles, ModoSensible.nubeCifrada);
      await dia(1);
      expect(await subida.encolarPendientes('ana'), 1);
      await dia(2);
      ahora = ahora.add(const Duration(hours: 5, minutes: 59));
      expect(await subida.encolarPendientes('ana'), 0, reason: 'aún no pasan 6 horas');
      expect(await subida.encolarPendientes('ana', forzar: true), 1, reason: 'Sincronizar');
      await dia(3);
      ahora = ahora.add(const Duration(hours: 6));
      expect(await subida.encolarPendientes('ana'), 1);
      ahora = ahora.add(const Duration(hours: 7));
      expect(await subida.encolarPendientes('ana'), 0, reason: 'no hay nada nuevo');
    });

    test('lotes de máximo 50 sobres', () async {
      await modos.fijar('ana', TipoSensible.diarioOracion, ModoSensible.nubeCifrada);
      for (var i = 1; i <= 120; i++) {
        final s = cifrarDocumento(
          llaveDeTipo: (await llaves.llaveDeTipo('ana', TipoSensible.diarioOracion, ModoSensible.nubeCifrada))!,
          llaveDeIds: (await llaves.llaveDeIds('ana', ModoSensible.nubeCifrada))!,
          persona: 'ana',
          tipo: TipoSensible.diarioOracion,
          claveDoc: 'dia:$i',
          documento: {'i': i},
        );
        await store.guardar('ana', s);
      }
      expect(await subida.encolarPendientes('ana', forzar: true), 120);
      final tamanos = [
        for (final r in await cola.registros())
          SubidaDiferidaDeSobres.sobresDeCarga((jsonDecode(r.carga) as Map).cast<String, Object?>()).length,
      ]..sort();
      expect(tamanos, [20, 50, 50]);
    });

    test('tocaSubir', () {
      final t = DateTime.utc(2026, 11, 1, 12);
      expect(tocaSubir(ahora: t, ultimaSubida: null), isTrue);
      expect(tocaSubir(ahora: t, ultimaSubida: t.subtract(const Duration(hours: 5))), isFalse);
      expect(tocaSubir(ahora: t, ultimaSubida: t.subtract(const Duration(hours: 6))), isTrue);
      expect(tocaSubir(ahora: t, ultimaSubida: t, forzar: true), isTrue);
    });

    test('modos: por omisión solo teléfono; se fija por persona y tipo', () async {
      await modos.fijar('ana', TipoSensible.diarioOracion, ModoSensible.nubeCifrada);
      expect(await modos.modo('ana', TipoSensible.diarioOracion), ModoSensible.nubeCifrada);
      expect(await modos.modo('ana', TipoSensible.habitosSensibles), ModoSensible.soloTelefono);
      expect(await modos.modo('beto', TipoSensible.diarioOracion), ModoSensible.soloTelefono);
    });
  });

  group('respaldo local cifrado', () {
    final frase = FraseDeRecuperacion.generar();

    test('exportar e importar con la frase; sin ella no', () async {
      final llaves = LlavesHabitos(almacen);
      final local = await llaves.llaveLocal('ana');
      final s = cifrarDocumento(
        llaveDeTipo: (await llaves.llaveDeTipo('ana', TipoSensible.diarioOracion, ModoSensible.soloTelefono))!,
        llaveDeIds: (await llaves.llaveDeIds('ana', ModoSensible.soloTelefono))!,
        persona: 'ana',
        tipo: TipoSensible.diarioOracion,
        claveDoc: 'dia:2026-11-01',
        documento: {'peticion': 'por mi familia'},
      );
      final archivo = await RespaldoLocal.exportar(
        sobres: [s],
        llaveLocal: local,
        frase: frase,
        vueltas: 50,
      );
      expect(archivo, isNot(contains('familia')));
      final leido = await RespaldoLocal.importar(archivo, frase, minimoVueltas: 1);
      expect(leido.sobres.single.cifrado, s.cifrado);
      expect(leido.llaveLocal, local);
      // Con la llave local recuperada se abre el sobre en otro teléfono.
      final llave = hkdfSha256(leido.llaveLocal, info: 'gravity-hab/v1/diario_oracion');
      expect(descifrarDocumento(llaveDeTipo: llave, persona: 'ana', sobre: leido.sobres.single), isNotNull);
      await expectLater(
        RespaldoLocal.importar(archivo, FraseDeRecuperacion.generar(), minimoVueltas: 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('un archivo hostil se rechaza con un motivo, sin lanzar otra cosa', () async {
      for (final malo in [
        '',
        'no es json',
        '[]',
        '{}',
        jsonEncode({'formato': 'otro', 'v': 1}),
        jsonEncode({'formato': RespaldoLocal.formato, 'v': 1, 'vueltas': -5, 'sal': 'a', 'llave_local': 'b', 'cifrado': 'c'}),
        jsonEncode({'formato': RespaldoLocal.formato, 'v': 1, 'vueltas': 999999999, 'sal': 'a', 'llave_local': 'b', 'cifrado': 'c'}),
        jsonEncode({'formato': RespaldoLocal.formato, 'v': 1, 'vueltas': 10, 'sal': 'a', 'llave_local': 'b', 'cifrado': 'c'}),
        'x' * (maximoBytesDeArchivo + 1),
      ]) {
        await expectLater(
          RespaldoLocal.importar(malo, frase),
          throwsA(isA<FormatException>()),
          reason: malo.length > 50 ? 'grande' : malo,
        );
      }
    });
  });

  group('exportar mis datos', () {
    final ahora = DateTime.utc(2026, 11, 1, 20);
    final fuente = _Fuente();

    test('sin sensibles: esquema propio y datos en claro, sin aviso', () async {
      final texto = await ExportacionHabitos.generar(fuente: fuente, ahora: ahora);
      final json = jsonDecode(texto) as Map;
      expect(json['esquema'], 'gravity-habitos');
      expect(json['v'], 1);
      expect((json['datos'] as Map)['objetivos'], isNotNull);
      expect(json.containsKey('sensibles'), isFalse);
      expect(json.containsKey('aviso'), isFalse);
    });

    test('con sensibles y sin frase: no sale nada reservado (F3-13)', () async {
      final texto = await ExportacionHabitos.generar(
        fuente: fuente,
        ahora: ahora,
        incluirSensibles: {TipoSensible.diarioOracion},
      );
      final json = jsonDecode(texto) as Map;
      expect(json.containsKey('sensibles'), isFalse);
      expect(json.containsKey('sensibles_protegidos'), isFalse);
      expect(texto, isNot(contains('oración secreta')));
    });

    test('con la frase: la parte sensible va cifrada y se recupera con ella', () async {
      final frase = FraseDeRecuperacion.generar();
      final texto = await ExportacionHabitos.generar(
        fuente: fuente,
        ahora: ahora,
        incluirSensibles: TipoSensible.values.toSet(),
        frase: frase,
        vueltas: 50,
      );
      expect(texto, isNot(contains('oración secreta')));
      expect(texto, isNot(contains('consumo secreto')));
      final json = jsonDecode(texto) as Map;
      expect(json.containsKey('sensibles'), isFalse);
      final p = (json['sensibles_protegidos'] as Map).cast<String, Object?>();
      final llave = await pbkdf2EnAislado(
        utf8.encode(frase.join(' ')),
        desdeBase64Url(p['sal']! as String),
        p['vueltas']! as int,
      );
      final claro = SobreAes.descifrar(
        llave,
        p['cifrado']! as String,
        datosAsociados: utf8.encode('gravity-habitos-exportacion-v1'),
      );
      expect(utf8.decode(claro!), contains('oración secreta'));
    });
  });

  group('borrar mis datos', () {
    late LlavesHabitos llaves;
    late AlmacenDeSobres store;
    late ModosLocales modos;
    late NubeDeHabitosEnMemoria nube;
    late BorradoDeMisDatos borrado;

    Future<void> sobre(TipoSensible tipo, String dia) async {
      final s = cifrarDocumento(
        llaveDeTipo: (await llaves.llaveDeTipo('ana', tipo, ModoSensible.soloTelefono))!,
        llaveDeIds: (await llaves.llaveDeIds('ana', ModoSensible.soloTelefono))!,
        persona: 'ana',
        tipo: tipo,
        claveDoc: 'dia:$dia',
        documento: {'x': 1},
      );
      await store.guardar('ana', s);
    }

    setUp(() async {
      llaves = LlavesHabitos(almacen);
      store = AlmacenDeSobres(almacen);
      modos = ModosLocales(almacen);
      nube = NubeDeHabitosEnMemoria();
      borrado = BorradoDeMisDatos(sobres: store, llaves: llaves, modos: modos, almacen: almacen, nube: nube);
      await sobre(TipoSensible.habitosSensibles, '1');
      await sobre(TipoSensible.diarioOracion, '2');
      await modos.fijar('ana', TipoSensible.diarioOracion, ModoSensible.nubeCifrada);
    });

    test('la palabra de confirmación', () {
      expect(BorradoDeMisDatos.confirma('BORRAR'), isTrue);
      expect(BorradoDeMisDatos.confirma(' BORRAR '), isTrue);
      expect(BorradoDeMisDatos.confirma('borrar'), isFalse);
      expect(BorradoDeMisDatos.confirma(''), isFalse);
    });

    test('sensibles borra solo ese tipo, en el equipo y en la nube', () async {
      await borrado.borrar('ana', AlcanceDeBorrado.sensibles);
      expect((await store.todos('ana')).map((s) => s.tipo), [TipoSensible.diarioOracion]);
      expect(nube.borrados, [AlcanceDeBorrado.sensibles]);
      expect(await llaves.tieneLlaveMaestra('ana'), isFalse);
      expect(almacen.datos.keys.any((k) => k.contains('llave_local')), isTrue, reason: 'la llave se queda');
    });

    test('diario borra el otro tipo', () async {
      await borrado.borrar('ana', AlcanceDeBorrado.diario);
      expect((await store.todos('ana')).map((s) => s.tipo), [TipoSensible.habitosSensibles]);
      expect(nube.borrados, [AlcanceDeBorrado.diario]);
    });

    test('todo borra sobres, llaves y modos del equipo', () async {
      await borrado.borrar('ana', AlcanceDeBorrado.todo);
      expect(await store.todos('ana'), isEmpty);
      expect(almacen.datos.keys.where((k) => k.startsWith('hab.')), isEmpty);
      expect(nube.borrados, [AlcanceDeBorrado.todo]);
      expect(await modos.modo('ana', TipoSensible.diarioOracion), ModoSensible.soloTelefono);
    });

    test('sin señal: lo local ya se borró y el error avisa que falta la nube', () async {
      nube.falla = Exception('sin red');
      await expectLater(borrado.borrar('ana', AlcanceDeBorrado.todo), throwsException);
      expect(await store.todos('ana'), isEmpty);
    });

    test('con cola: el borrado en la nube se encola, persiste y reintenta (sin '
        'señal no se pierde)', () async {
      final base = BaseLocal.enMemoria();
      addTearDown(base.close);
      final cola = ColaSinConexion(base: base, enviador: _EnviadorNulo());
      final conCola = BorradoDeMisDatos(
        sobres: store,
        llaves: llaves,
        modos: modos,
        almacen: almacen,
        nube: nube,
        cola: cola,
      );
      nube.falla = Exception('sin red'); // la cola no depende de esto
      await conCola.borrar('ana', AlcanceDeBorrado.diario);
      expect((await store.todos('ana')).map((s) => s.tipo), [TipoSensible.habitosSensibles]);
      final r = (await cola.registros()).single;
      expect(r.tipo, tipoColaBorrado);
      expect(r.personaId, 'ana');
      expect(jsonDecode(r.carga), {'p_alcance': 'diario'});
      expect(funcionBorrarMisDatos, 'hab_borrar_mis_datos');
      expect(nube.borrados, isEmpty, reason: 'lo llama la cola, no la pantalla');
    });

    test('lo de otra persona no se toca', () async {
      final otra = cifrarDocumento(
        llaveDeTipo: bytesAleatorios(32),
        llaveDeIds: bytesAleatorios(32),
        persona: 'beto',
        tipo: TipoSensible.diarioOracion,
        claveDoc: 'dia:9',
        documento: {'x': 1},
      );
      await store.guardar('beto', otra);
      await borrado.borrar('ana', AlcanceDeBorrado.todo);
      expect(await store.todos('beto'), hasLength(1));
    });
  });
}

class _Fuente implements FuenteDeDatosHabitos {
  @override
  Future<Map<String, Object?>> datosEnClaro() async => {
    'objetivos': [
      {'nombre': 'Caminar'},
    ],
  };

  @override
  Future<Map<String, Object?>> datosSensibles(TipoSensible tipo) async => {
    if (tipo == TipoSensible.diarioOracion) 'peticiones': ['oración secreta'],
    if (tipo == TipoSensible.habitosSensibles) 'registros': ['consumo secreto'],
  };
}
