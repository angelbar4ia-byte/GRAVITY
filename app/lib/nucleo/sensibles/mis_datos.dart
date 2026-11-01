/// Respaldo local cifrado, exportar y borrar mis datos de Hábitos (Fase 3,
/// reglas 95 y 96, 4.3 punto 8). Son archivos propios de la persona y se
/// tratan como entrada hostil al importar (20 MB, texto plano, esquema fijo).
library;

import 'dart:convert';

import '../seguridad/almacen_seguro.dart';
import 'cripto.dart';
import 'llaves_habitos.dart';
import 'sobres.dart';
import 'subida_diferida.dart';

/// Límite de un archivo de respaldo o de exportación al importarlo.
const maximoBytesDeArchivo = 20 * 1024 * 1024;

// ------------------------------------------------------------------ respaldo

/// Respaldo local cifrado del modo `solo_telefono`: los sobres tal cual (ya
/// cifrados con la llave local) dentro de un archivo cifrado con una llave
/// derivada de la frase. El respaldo automático de Android no incluye el
/// almacén sensible; este archivo es la única copia fuera del teléfono.
abstract final class RespaldoLocal {
  static const formato = 'gravity-habitos-respaldo';
  static const version = 1;

  static List<int> _aad() => utf8.encode('gravity-hab-respaldo-v$version');

  /// El archivo (JSON) con [sobres] y la llave local [llaveLocal], cifrado con
  /// [frase]. La llave local va dentro: sin ella los sobres no se abren en otro
  /// teléfono.
  static Future<String> exportar({
    required List<Sobre> sobres,
    required List<int> llaveLocal,
    required List<String> frase,
    int vueltas = LlaveEnvuelta.vueltasPorOmision,
  }) async {
    final envoltura = await LlaveEnvuelta.envolver(
      llaveLocal,
      frase,
      vueltas: vueltas,
    );
    final cuerpo = jsonEncode({
      'sobres': [for (final s in sobres) s.aJson()],
    });
    final sal = desdeBase64Url(envoltura.sal);
    final llave = await pbkdf2EnAislado(utf8.encode(frase.join(' ')), sal, vueltas);
    final cifrado = SobreAes.cifrar(llave, utf8.encode(cuerpo), datosAsociados: _aad());
    llave.fillRange(0, llave.length, 0);
    return jsonEncode({
      'formato': formato,
      'v': version,
      'kdf': LlaveEnvuelta.kdfPbkdf2,
      'vueltas': vueltas,
      'sal': envoltura.sal,
      'llave_local': envoltura.llaveEnvuelta,
      'cifrado': cifrado,
    });
  }

  /// Lee un respaldo. Lanza [FormatException] con un motivo para mostrar si no
  /// es un respaldo válido, es muy grande o la frase no corresponde.
  static Future<({List<Sobre> sobres, List<int> llaveLocal})> importar(
    String texto,
    List<String> frase,
  ) async {
    if (utf8.encode(texto).length > maximoBytesDeArchivo) {
      throw const FormatException('El archivo pasa de 20 MB.');
    }
    final Map<String, Object?> json;
    try {
      json = (jsonDecode(texto) as Map).cast<String, Object?>();
    } catch (_) {
      throw const FormatException('No es un respaldo de GRAVITY.');
    }
    if (json['formato'] != formato || json['v'] != version) {
      throw const FormatException('No es un respaldo de GRAVITY (o es de otra versión).');
    }
    final vueltas = json['vueltas'];
    final sal = json['sal'];
    final llaveLocal = json['llave_local'];
    final cifrado = json['cifrado'];
    if (vueltas is! int ||
        vueltas < 1 ||
        vueltas > 5000000 ||
        sal is! String ||
        llaveLocal is! String ||
        cifrado is! String) {
      throw const FormatException('El respaldo está incompleto.');
    }
    final envoltura = LlaveEnvuelta(
      version: 1,
      kdf: LlaveEnvuelta.kdfPbkdf2,
      vueltas: vueltas,
      sal: sal,
      llaveEnvuelta: llaveLocal,
    );
    final local = await envoltura.desenvolver(frase);
    if (local == null) {
      throw const FormatException('La frase no corresponde a este respaldo.');
    }
    final llave = await pbkdf2EnAislado(utf8.encode(frase.join(' ')), desdeBase64Url(sal), vueltas);
    final claro = SobreAes.descifrar(llave, cifrado, datosAsociados: _aad());
    llave.fillRange(0, llave.length, 0);
    if (claro == null) {
      throw const FormatException('El respaldo está dañado.');
    }
    try {
      final cuerpo = (jsonDecode(utf8.decode(claro)) as Map).cast<String, Object?>();
      final sobres = [
        for (final s in cuerpo['sobres']! as List)
          Sobre.desdeJson((s as Map).cast<String, Object?>()) ??
              (throw const FormatException('Un sobre del respaldo no es válido.')),
      ];
      return (sobres: sobres, llaveLocal: local);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('El respaldo está dañado.');
    }
  }
}

// ---------------------------------------------------------------- exportar

/// Aviso que se muestra antes de compartir un archivo con datos sensibles.
const avisoDeArchivoSensible =
    'Este archivo contiene datos de salud y de oración; guárdalo en un lugar '
    'seguro y no lo envíes por mensajería.';

/// Lo que Hábitos entrega para exportar. Lo implementa el módulo de Hábitos
/// (descifra en memoria; esta capa nunca ve la forma de los datos).
abstract interface class FuenteDeDatosHabitos {
  /// Los datos no sensibles (objetivos, agenda, cumplimiento…).
  Future<Map<String, Object?>> datosEnClaro();

  /// Los datos de un tipo sensible, ya descifrados (solo en memoria).
  Future<Map<String, Object?>> datosSensibles(TipoSensible tipo);
}

abstract final class ExportacionHabitos {
  static const esquema = 'gravity-habitos';
  static const version = 1;

  /// El archivo `.json` con esquema propio. Los tipos sensibles de
  /// [incluirSensibles] van en una sección aparte, que con [frase] se cifra
  /// (la misma frase de recuperación) para que el archivo en claro no los lleve.
  static Future<String> generar({
    required FuenteDeDatosHabitos fuente,
    required DateTime ahora,
    Set<TipoSensible> incluirSensibles = const {},
    List<String>? frase,
    int vueltas = LlaveEnvuelta.vueltasPorOmision,
  }) async {
    final sensibles = <String, Object?>{
      for (final tipo in incluirSensibles) tipo.valor: await fuente.datosSensibles(tipo),
    };
    final salida = <String, Object?>{
      'esquema': esquema,
      'v': version,
      'generado_en': ahora.toUtc().toIso8601String(),
      'datos': await fuente.datosEnClaro(),
    };
    if (sensibles.isNotEmpty) {
      if (frase == null) {
        salida['sensibles'] = sensibles;
      } else {
        final sal = bytesAleatorios(16);
        final llave = await pbkdf2EnAislado(utf8.encode(frase.join(' ')), sal, vueltas);
        salida['sensibles_protegidos'] = {
          'kdf': LlaveEnvuelta.kdfPbkdf2,
          'vueltas': vueltas,
          'sal': aBase64Url(sal),
          'cifrado': SobreAes.cifrar(
            llave,
            utf8.encode(jsonEncode(sensibles)),
            datosAsociados: utf8.encode('gravity-habitos-exportacion-v$version'),
          ),
        };
        llave.fillRange(0, llave.length, 0);
      }
      salida['aviso'] = avisoDeArchivoSensible;
    }
    return const JsonEncoder.withIndent('  ').convert(salida);
  }
}

// ------------------------------------------------------------------- borrar

/// Qué se borra (`hab_borrar_mis_datos(p_alcance)`).
enum AlcanceDeBorrado {
  sensibles('sensibles'),
  diario('diario'),
  todo('todo');

  const AlcanceDeBorrado(this.valor);

  final String valor;

  Set<TipoSensible> get tipos => switch (this) {
    sensibles => {TipoSensible.habitosSensibles},
    diario => {TipoSensible.diarioOracion},
    todo => TipoSensible.values.toSet(),
  };
}

/// Palabra que hay que escribir para confirmar el borrado.
const palabraDeConfirmacion = 'BORRAR';

/// La parte del servidor del borrado.
abstract interface class NubeDeHabitos {
  Future<void> borrarMisDatos(AlcanceDeBorrado alcance);
}

class BorradoDeMisDatos {
  BorradoDeMisDatos({
    required this.sobres,
    required this.llaves,
    required this.modos,
    required this.almacen,
    this.nube,
  });

  final AlmacenDeSobres sobres;
  final LlavesHabitos llaves;
  final ModosLocales modos;
  final AlmacenSeguro almacen;
  final NubeDeHabitos? nube;

  /// ¿La persona escribió la palabra de confirmación?
  static bool confirma(String texto) => texto.trim() == palabraDeConfirmacion;

  /// Borra en el equipo (sobres, y con `todo` también llaves y modos) y en la
  /// nube (`hab_borrar_mis_datos`). El PIN y la palabra los pide la pantalla
  /// antes. Si la nube falla por falta de señal, **lo local ya se borró** y se
  /// lanza el error para que la pantalla avise que falta la nube.
  Future<void> borrar(String persona, AlcanceDeBorrado alcance) async {
    for (final tipo in alcance.tipos) {
      await sobres.borrar(persona, tipo: tipo);
    }
    if (alcance == AlcanceDeBorrado.todo) {
      await llaves.borrar(persona);
      await modos.borrar(persona);
      await sobres.olvidarEncolados(persona);
    }
    await nube?.borrarMisDatos(alcance);
  }
}
