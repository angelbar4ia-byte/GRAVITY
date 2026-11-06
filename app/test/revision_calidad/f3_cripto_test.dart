// Revisión de calidad de la Fase 3 (docs/revisiones/fase-3.md): cifrado, frase y
// subida diferida de los datos sensibles de Hábitos.
//
// F3-2  (cerrado) La revisión de un sobre sube +1 en cada edición LOCAL, pero la
//       subida diferida solo encola la última: tras una primera subida, la
//       segunda lleva un salto de revisión y el servidor la rechaza (22023
//       "sube de 1 en 1"), que la cola trata como permanente. Se pierde la sincronía.
// F3-3  (hallazgo) El nombre del KDF del cliente ("pbkdf2-sha256") no está en la
//       lista del servidor ("pbkdf2-hmac-sha256" o "argon2id"): hab_guardar_llave
//       daría 23514.
// F3-6  (hallazgo, menor) La frase se escribe tal cual: una "á" descompuesta
//       (a + U+0301) o sin acento no se reconoce.
// Guardias (pasan): nonces únicos, sobre alterado o movido, lista sin marcas
// combinantes, 12 palabras, contraste con vectores.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/cripto.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/palabras_es.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

class _Enviador implements Enviador {
  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      ResultadoEnvio.enviado;
}

void main() {
  test(
    // Cerrado el 6/nov/2026: el servidor (migración 20261107) acepta cualquier
    // revisión MAYOR que la suya; solo hace falta que crezcan.
    'F3-2: dos subidas seguidas llevan revisiones crecientes (el servidor acepta una mayor)',
    () async {
      final almacen = AlmacenSeguroEnMemoria();
      final base = BaseLocal.enMemoria();
      addTearDown(base.close);
      var ahora = DateTime.utc(2026, 11, 2, 20);
      final cola = ColaSinConexion(
        base: base,
        enviador: _Enviador(),
        reloj: () => ahora,
      );
      final modos = ModosLocales(almacen);
      final llaves = LlavesHabitos(almacen);
      await llaves.guardarLlaveMaestra('ana', bytesAleatorios(32));
      await modos.fijar(
        'ana',
        TipoSensible.habitosSensibles,
        ModoSensible.nubeCifrada,
      );
      final docs = DocumentosSensibles(
        llaves: llaves,
        sobres: AlmacenDeSobres(almacen),
        modos: modos,
        persona: 'ana',
        ahora: () => ahora,
      );
      final subida = SubidaDiferidaDeSobres(
        sobres: AlmacenDeSobres(almacen),
        modos: modos,
        cola: cola,
        almacen: almacen,
        reloj: () => ahora,
      );
      Future<void> registrar(int n) => docs.poner(
        TipoSensible.habitosSensibles,
        'dia:2026-11-02',
        ElementoDoc(
          id: 'e$n',
          clase: 'consumo',
          modificadoEn: n,
          datos: const {'x': 1},
        ),
      );
      await registrar(1);
      expect(await subida.encolarPendientes('ana', forzar: true), 1);
      // Durante el día la persona registra tres consumos más (cada uno sube la revisión).
      await registrar(2);
      await registrar(3);
      await registrar(4);
      ahora = ahora.add(const Duration(hours: 7));
      expect(await subida.encolarPendientes('ana'), 1);
      final revisiones = <int>[];
      for (final r in await cola.registros()) {
        final carga = (jsonDecode(r.carga) as Map).cast<String, Object?>();
        for (final s in SubidaDiferidaDeSobres.sobresDeCarga(carga)) {
          revisiones.add(s['revision']! as int);
        }
      }
      revisiones.sort();
      expect(revisiones.length, 2);
      expect(
        revisiones.last,
        greaterThan(revisiones.first),
        reason: 'revisiones subidas: $revisiones (el servidor acepta una mayor)',
      );
    },
  );

  test('F3-3: el KDF que manda el cliente está en la lista del servidor', () {
    const aceptados = {'pbkdf2-hmac-sha256', 'argon2id'};
    expect(aceptados, contains(LlaveEnvuelta.kdfPbkdf2));
  });

  test('F3-6: la frase se reconoce con la "á" descompuesta (NFD)', () {
    final frase = FraseDeRecuperacion.desdeEntropia(List.filled(16, 0));
    // ábaco ×11 + abierto, escrito con a + U+0301 (teclados que no normalizan).
    final tecleada = frase.map((p) => p.replaceAll('á', 'á')).join(' ');
    expect(
      FraseDeRecuperacion.esValida(FraseDeRecuperacion.normalizar(tecleada)),
      isTrue,
    );
  });

  group('guardias', () {
    test(
      '3 000 cifrados del mismo texto: ni un nonce repetido ni un texto igual',
      () {
        final llave = bytesAleatorios(32);
        final nonces = <String>{};
        final textos = <String>{};
        for (var i = 0; i < 3000; i++) {
          final s = SobreAes.cifrarBytes(llave, utf8.encode('igual'));
          nonces.add(aBase64Url(s.sublist(1, 13)));
          textos.add(aBase64Url(s));
        }
        expect(nonces.length, 3000);
        expect(textos.length, 3000);
      },
    );

    test(
      'alterar cualquier byte del sobre, o moverlo de lugar, impide abrirlo',
      () {
        final llave = bytesAleatorios(32);
        final aad = datosAsociadosDeSobre(
          persona: 'p',
          tipo: 't',
          id: 'i',
          revision: 1,
        );
        final sobre = SobreAes.cifrarBytes(
          llave,
          utf8.encode('secreto'),
          datosAsociados: aad,
        );
        expect(
          SobreAes.descifrarBytes(llave, sobre, datosAsociados: aad),
          isNotNull,
        );
        for (var i = 0; i < sobre.length; i++) {
          final malo = sobre.sublist(0)..[i] ^= 0x01;
          expect(
            SobreAes.descifrarBytes(llave, malo, datosAsociados: aad),
            isNull,
            reason: 'byte $i',
          );
        }
        for (final otro in [
          datosAsociadosDeSobre(persona: 'q', tipo: 't', id: 'i', revision: 1),
          datosAsociadosDeSobre(persona: 'p', tipo: 'u', id: 'i', revision: 1),
          datosAsociadosDeSobre(persona: 'p', tipo: 't', id: 'j', revision: 1),
          datosAsociadosDeSobre(persona: 'p', tipo: 't', id: 'i', revision: 2),
          <int>[],
        ]) {
          expect(
            SobreAes.descifrarBytes(llave, sobre, datosAsociados: otro),
            isNull,
          );
        }
        expect(
          SobreAes.descifrarBytes(
            llave,
            sobre.sublist(0, 20),
            datosAsociados: aad,
          ),
          isNull,
        );
        expect(
          SobreAes.descifrarBytes(llave, Uint8List(0), datosAsociados: aad),
          isNull,
        );
      },
    );

    test('la lista de palabras no lleva espacios ni marcas combinantes y la frase tiene 12', () {
      for (final p in palabrasEs) {
        expect(p, equals(p.trim()));
        expect(p.contains(RegExp(r'[\s̀-ͯ]')), isFalse, reason: p);
      }
      for (var i = 0; i < 200; i++) {
        final f = FraseDeRecuperacion.generar();
        expect(f.length, 12);
        expect(FraseDeRecuperacion.esValida(f), isTrue);
      }
    });

    test('doce palabras válidas con la verificación cambiada no pasan', () {
      final f = FraseDeRecuperacion.desdeEntropia(List.filled(16, 0));
      expect(FraseDeRecuperacion.esValida(f), isTrue);
      final mala = [...f]..[11] = palabrasEs[7];
      expect(FraseDeRecuperacion.esValida(mala), isFalse);
      expect(FraseDeRecuperacion.esValida(List.filled(12, 'ábaco')), isFalse);
    });
  });
}
