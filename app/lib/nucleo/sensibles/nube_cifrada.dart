/// La nube cifrada de Hábitos (P5 del dueño, E7 de la Fase 4; D13 y D21): lo
/// que hace falta para **activar** la nube con la frase de 12 palabras,
/// **cambiar el modo** de cada tipo, **añadir un equipo** con la frase,
/// **cambiar la frase**, **reiniciar la nube** y **detectar** que otro equipo
/// la reinició (`epoca_nube`).
///
/// No duplica nada: usa las llaves y la frase de `llaves_habitos.dart`, los
/// sobres de `sobres.dart`, los modos de `subida_diferida.dart` y las
/// funciones del servidor `hab_guardar_llave`, `hab_cambiar_modo` y
/// `hab_reiniciar_nube`. Nada sale del teléfono en claro: el servidor solo
/// recibe la llave maestra **envuelta** con la frase y sobres cifrados.
///
/// Cuidado con el orden: cada operación calcula **primero en memoria** lo que va
/// a escribir (volver a cifrar los sobres con la llave nueva) y solo cuando el
/// servidor aceptó lo guarda en el equipo. Así, si no hay señal a la mitad, el
/// equipo queda como estaba y no se pierde nada. Por omisión todo sigue en
/// `solo_telefono` (decisión del dueño: "solo teléfono por ahora"); nada aquí
/// cambia el modo sin que la persona lo pida.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:habitos_dominio/habitos_dominio.dart'
    show DocumentoSensible, fusionarDocumentos;

import '../seguridad/almacen_seguro.dart';
import '../sesion/errores_red.dart';
import 'cripto.dart';
import 'llaves_habitos.dart';
import 'sobres.dart';
import 'subida_diferida.dart' show ModosLocales;

/// Error con un mensaje listo para mostrar.
class ErrorNubeCifrada implements Exception {
  const ErrorNubeCifrada(this.mensaje);

  final String mensaje;

  static const sinConexion = ErrorNubeCifrada(
    'Sin conexión. Intenta de nuevo cuando haya señal; no se cambió nada.',
  );
  static const fraseIncorrecta = ErrorNubeCifrada(
    'Esa frase no corresponde. Revisa las 12 palabras y vuelve a intentar.',
  );
  static const fraseInvalida = ErrorNubeCifrada(
    'La frase no es válida. Revisa las 12 palabras.',
  );
  static const sinNube = ErrorNubeCifrada(
    'Aún no hay una nube cifrada activada con tu cuenta.',
  );
  static const sinLlaveEnEsteEquipo = ErrorNubeCifrada(
    'Este equipo no tiene la llave de la nube. Usa "Añadir este equipo" con '
    'tu frase.',
  );

  @override
  String toString() => 'ErrorNubeCifrada: $mensaje';
}

/// Lo que el servidor sabe de la nube de la persona.
class EstadoNubeServidor {
  const EstadoNubeServidor({
    required this.modos,
    required this.llave,
    required this.epoca,
  });

  final Map<TipoSensible, ModoSensible> modos;

  /// La llave maestra envuelta (`hab_llaves`), o `null` si no hay.
  final LlaveEnvuelta? llave;

  /// `hab_ajustes.epoca_nube`: sube cada vez que se borran sobres.
  final int epoca;

  ModoSensible modoDe(TipoSensible tipo) =>
      modos[tipo] ?? ModoSensible.soloTelefono;
}

/// El servidor de la nube cifrada (`hab_*`). Se simula en las pruebas.
abstract interface class AdministracionNubeHabitos {
  Future<EstadoNubeServidor> leerEstado();

  /// `hab_guardar_llave`: la primera envoltura es la versión 1; después sube
  /// de 1 en 1.
  Future<void> guardarLlave(LlaveEnvuelta llave);

  /// `hab_cambiar_modo`. Volver a `solo_telefono` exige [confirmarBorrado]
  /// (borra los sobres de la nube).
  Future<void> cambiarModo(
    TipoSensible tipo,
    ModoSensible modo, {
    bool confirmarBorrado = false,
  });

  /// `hab_reiniciar_nube`: borra sobres (y la llave si nada la usa) y vuelve a
  /// `solo_telefono`. [tipo] `null` = todos.
  Future<void> reiniciarNube([TipoSensible? tipo]);

  /// Los sobres de [tipo] que hay en la nube (solo existen en `nube_cifrada`).
  Future<List<Sobre>> sobresDeLaNube(TipoSensible tipo);
}

/// Foto de la nube en este equipo, para la pantalla.
class EstadoNubeEnEquipo {
  const EstadoNubeEnEquipo({
    required this.modos,
    required this.tieneLlave,
    this.servidor,
  });

  /// Modo local de cada tipo (lo que este equipo cree).
  final Map<TipoSensible, ModoSensible> modos;

  /// Este equipo guarda la llave maestra.
  final bool tieneLlave;

  /// Lo que dice el servidor; `null` sin señal.
  final EstadoNubeServidor? servidor;

  ModoSensible modoDe(TipoSensible tipo) =>
      modos[tipo] ?? ModoSensible.soloTelefono;

  bool get algunoEnNube => modos.values.any((m) => m == ModoSensible.nubeCifrada);

  /// El servidor tiene una llave de esta persona (alguien activó la nube).
  bool get hayNubeEnServidor => servidor?.llave != null;
}

class NubeCifradaHabitos {
  NubeCifradaHabitos({
    required this.llaves,
    required this.sobres,
    required this.modos,
    required this.almacen,
    required this.servidor,
  });

  final LlavesHabitos llaves;
  final AlmacenDeSobres sobres;
  final ModosLocales modos;
  final AlmacenSeguro almacen;
  final AdministracionNubeHabitos servidor;

  static String _claveEpoca(String persona) => 'hab.epoca_nube.$persona';

  // ------------------------------------------------------------------ estado

  /// Cómo está la nube en este equipo y, si hay señal, en el servidor.
  Future<EstadoNubeEnEquipo> estado(String persona) async {
    final locales = {
      for (final t in TipoSensible.values) t: await modos.modo(persona, t),
    };
    EstadoNubeServidor? remoto;
    try {
      remoto = await servidor.leerEstado();
    } catch (_) {
      remoto = null;
    }
    return EstadoNubeEnEquipo(
      modos: locales,
      tieneLlave: await llaves.tieneLlaveMaestra(persona),
      servidor: remoto,
    );
  }

  Future<T> _conServidor<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ErrorNubeCifrada {
      rethrow;
    } catch (error) {
      if (esErrorDeRed(error)) throw ErrorNubeCifrada.sinConexion;
      rethrow;
    }
  }

  // ----------------------------------------------------------------- activar

  /// Activa la nube para [tipos] con la [frase] ya confirmada: crea (o reúsa)
  /// la llave maestra, la envuelve con la frase, la guarda en el servidor,
  /// vuelve a cifrar con ella lo que hay en este equipo y pasa los tipos a
  /// `nube_cifrada`. La subida de los sobres la hace la subida diferida (o
  /// *Sincronizar*).
  ///
  /// [pin]: en la laptop y la tablet personal las llaves viven cifradas con el
  /// PIN de la persona (D21).
  Future<void> activar(
    String persona,
    List<String> frase, {
    Set<TipoSensible> tipos = const {
      TipoSensible.habitosSensibles,
      TipoSensible.diarioOracion,
    },
    String? pin,
  }) async {
    if (!FraseDeRecuperacion.esValida(frase)) {
      throw ErrorNubeCifrada.fraseInvalida;
    }
    final remoto = await _conServidor(servidor.leerEstado);
    if (remoto.llave != null && !await llaves.tieneLlaveMaestra(persona)) {
      // Ya hay una llave de otro equipo: se añade este con la frase, no se
      // crea otra (los datos de la nube dejarían de abrir).
      throw const ErrorNubeCifrada(
        'Ya activaste la nube en otro equipo. Usa "Añadir este equipo" con '
        'tu frase.',
      );
    }
    final existente = await llaves.llaveMaestra(persona, pin: pin);
    final maestra = existente ?? bytesAleatorios(32);
    final envuelta = remoto.llave != null
        ? remoto.llave!
        : await LlaveEnvuelta.envolver(maestra, frase);

    // 1. En memoria: los sobres de cada tipo, vueltos a cifrar con la maestra.
    final nuevos = <TipoSensible, List<Sobre>>{};
    for (final tipo in tipos) {
      if (await modos.modo(persona, tipo) == ModoSensible.nubeCifrada) continue;
      nuevos[tipo] = await _resellar(
        persona,
        tipo,
        de: _Llaves(
          await llaves.llaveDeTipo(
            persona,
            tipo,
            ModoSensible.soloTelefono,
            pin: pin,
          ),
          await llaves.llaveDeIds(persona, ModoSensible.soloTelefono, pin: pin),
        ),
        a: _Llaves(
          hkdfSha256(maestra, info: 'gravity-hab/v1/${tipo.valor}'),
          hkdfSha256(maestra, info: 'gravity-hab/v1/ids'),
        ),
        llaveVersion: envuelta.version,
      );
    }

    // 2. El servidor: la llave envuelta y los modos.
    await _conServidor(() async {
      if (remoto.llave == null) await servidor.guardarLlave(envuelta);
      for (final tipo in nuevos.keys) {
        await servidor.cambiarModo(tipo, ModoSensible.nubeCifrada);
      }
    });

    // 3. Ya aceptado: se guarda en el equipo.
    await llaves.guardarLlaveMaestra(persona, maestra, pin: pin);
    for (final e in nuevos.entries) {
      await _reemplazar(persona, e.key, e.value);
      await modos.fijar(persona, e.key, ModoSensible.nubeCifrada);
    }
    await sobres.olvidarEncolados(persona);
    await _guardarEpoca(persona);
  }

  // ------------------------------------------------------------ volver a local

  /// Vuelve [tipo] a `solo_telefono`: primero trae de la nube lo que falte en
  /// este equipo, después vuelve a cifrar todo con la llave local y por último
  /// borra la copia de la nube (`hab_cambiar_modo` con confirmación). Si algo
  /// falla antes de que el servidor acepte, no cambia nada.
  Future<void> volverASoloTelefono(String persona, TipoSensible tipo, {String? pin}) async {
    if (await modos.modo(persona, tipo) != ModoSensible.nubeCifrada) return;
    final maestra = await llaves.llaveMaestra(persona, pin: pin);
    if (maestra == null) throw ErrorNubeCifrada.sinLlaveEnEsteEquipo;

    // 1. Traer de la nube lo que falte (el teléfono es la copia completa).
    final locales = await _traerDeLaNube(persona, tipo, maestra);

    // 2. En memoria: todo vuelto a cifrar con la llave local.
    final local = await llaves.llaveLocal(persona, pin: pin);
    final nuevos = await _resellar(
      persona,
      tipo,
      de: _Llaves(
        hkdfSha256(maestra, info: 'gravity-hab/v1/${tipo.valor}'),
        hkdfSha256(maestra, info: 'gravity-hab/v1/ids'),
      ),
      a: _Llaves(
        hkdfSha256(local, info: 'gravity-hab/v1/${tipo.valor}'),
        hkdfSha256(local, info: 'gravity-hab/v1/ids'),
      ),
      origen: locales,
    );

    // 3. El servidor borra su copia.
    await _conServidor(
      () => servidor.cambiarModo(
        tipo,
        ModoSensible.soloTelefono,
        confirmarBorrado: true,
      ),
    );

    // 4. Se guarda en el equipo.
    await _reemplazar(persona, tipo, nuevos);
    await modos.fijar(persona, tipo, ModoSensible.soloTelefono);
    await sobres.olvidarEncolados(persona);
    await _guardarEpoca(persona);
  }

  // -------------------------------------------------------------- añadir equipo

  /// Añade este equipo a la nube que ya activó la persona en otro: con la
  /// [frase] desenvuelve la llave maestra, la guarda y trae los sobres.
  Future<void> anadirEquipo(
    String persona,
    List<String> frase, {
    String? pin,
  }) async {
    if (!FraseDeRecuperacion.esValida(frase)) {
      throw ErrorNubeCifrada.fraseInvalida;
    }
    final remoto = await _conServidor(servidor.leerEstado);
    final envuelta = remoto.llave;
    if (envuelta == null) throw ErrorNubeCifrada.sinNube;
    final maestra = await envuelta.desenvolver(frase);
    if (maestra == null) throw ErrorNubeCifrada.fraseIncorrecta;
    await llaves.guardarLlaveMaestra(persona, maestra, pin: pin);
    for (final tipo in TipoSensible.values) {
      final modo = remoto.modoDe(tipo);
      await modos.fijar(persona, tipo, modo);
      if (modo != ModoSensible.nubeCifrada) continue;
      final traidos = await _traerDeLaNube(persona, tipo, maestra);
      // Se guardan tal cual (misma llave y mismos ids que en la nube).
      for (final s in traidos) {
        await sobres.guardar(persona, s);
      }
    }
    await sobres.olvidarEncolados(persona);
    await _guardarEpoca(persona, remoto.epoca);
  }

  // ------------------------------------------------------------- cambiar frase

  /// Cambia la frase: vuelve a envolver **la misma** llave maestra con la
  /// [fraseNueva]; los datos no se vuelven a cifrar. Hace falta la llave en
  /// este equipo.
  Future<void> cambiarFrase(
    String persona,
    List<String> fraseNueva, {
    String? pin,
  }) async {
    if (!FraseDeRecuperacion.esValida(fraseNueva)) {
      throw ErrorNubeCifrada.fraseInvalida;
    }
    final maestra = await llaves.llaveMaestra(persona, pin: pin);
    if (maestra == null) throw ErrorNubeCifrada.sinLlaveEnEsteEquipo;
    final remoto = await _conServidor(servidor.leerEstado);
    final version = (remoto.llave?.version ?? 0) + 1;
    final envuelta = await LlaveEnvuelta.envolver(
      maestra,
      fraseNueva,
      version: version,
    );
    await _conServidor(() => servidor.guardarLlave(envuelta));
  }

  /// "Verificar mi frase": `true` si [frase] abre la llave envuelta del
  /// servidor (no la guarda ni cambia nada).
  Future<bool> verificarFrase(List<String> frase) async {
    if (!FraseDeRecuperacion.esValida(frase)) return false;
    final remoto = await _conServidor(servidor.leerEstado);
    final envuelta = remoto.llave;
    if (envuelta == null) return false;
    return await envuelta.desenvolver(frase) != null;
  }

  // ----------------------------------------------------------------- reiniciar

  /// "Reiniciar la nube" (perdí la frase): el servidor borra los sobres (y la
  /// llave, si nada más la usa) y todo vuelve a `solo_telefono`. Si este
  /// equipo conserva la llave maestra, lo suyo se vuelve a cifrar con la llave
  /// local y **no se pierde**; si no, lo que no se puede abrir se descarta.
  Future<void> reiniciar(String persona, {TipoSensible? tipo, String? pin}) async {
    final tipos = tipo == null ? TipoSensible.values : [tipo];
    final maestra = await llaves.tieneLlaveMaestra(persona)
        ? await llaves.llaveMaestra(persona, pin: pin)
        : null;
    final local = await llaves.llaveLocal(persona, pin: pin);

    // En memoria: lo que se puede conservar.
    final conservar = <TipoSensible, List<Sobre>>{};
    for (final t in tipos) {
      if (maestra != null &&
          await modos.modo(persona, t) == ModoSensible.nubeCifrada) {
        conservar[t] = await _resellar(
          persona,
          t,
          de: _Llaves(
            hkdfSha256(maestra, info: 'gravity-hab/v1/${t.valor}'),
            hkdfSha256(maestra, info: 'gravity-hab/v1/ids'),
          ),
          a: _Llaves(
            hkdfSha256(local, info: 'gravity-hab/v1/${t.valor}'),
            hkdfSha256(local, info: 'gravity-hab/v1/ids'),
          ),
        );
      } else {
        conservar[t] = const [];
      }
    }
    await _conServidor(() => servidor.reiniciarNube(tipo));
    for (final t in tipos) {
      await _reemplazar(persona, t, conservar[t]!);
      await modos.fijar(persona, t, ModoSensible.soloTelefono);
    }
    // La llave sirve a ambos tipos: se olvida cuando ninguno queda en la nube.
    final quedaAlguno = [
      for (final t in TipoSensible.values) await modos.modo(persona, t),
    ].any((m) => m == ModoSensible.nubeCifrada);
    if (!quedaAlguno) await _olvidarLlaveMaestra(persona);
    await sobres.olvidarEncolados(persona);
    await _guardarEpoca(persona);
  }

  // -------------------------------------------------------------------- época

  /// Compara la época del servidor con la que vio este equipo. Si subió, otro
  /// equipo cambió de modo o reinició la nube: este equipo deja de creer que
  /// los tipos que ya no están en la nube lo están, y borra su copia de lo que
  /// no puede seguir abriendo. Devuelve `true` si cambió algo.
  Future<bool> revisarEpoca(String persona) async {
    final EstadoNubeServidor remoto;
    try {
      remoto = await servidor.leerEstado();
    } catch (_) {
      return false; // sin señal: se revisa la próxima vez
    }
    final guardada = int.tryParse(await almacen.leer(_claveEpoca(persona)) ?? '');
    if (guardada == null) {
      await _guardarEpoca(persona, remoto.epoca);
      return false;
    }
    if (remoto.epoca <= guardada) return false;
    var cambio = false;
    for (final t in TipoSensible.values) {
      final local = await modos.modo(persona, t);
      if (local == ModoSensible.nubeCifrada &&
          remoto.modoDe(t) != ModoSensible.nubeCifrada) {
        // Otro equipo volvió este tipo a "solo teléfono" o reinició la nube:
        // la copia de este equipo cifrada con la llave maestra ya no sirve.
        await sobres.borrar(persona, tipo: t);
        await modos.fijar(persona, t, ModoSensible.soloTelefono);
        cambio = true;
      }
    }
    final quedaAlguno = [
      for (final t in TipoSensible.values) await modos.modo(persona, t),
    ].any((m) => m == ModoSensible.nubeCifrada);
    if (!quedaAlguno && remoto.llave == null) {
      await _olvidarLlaveMaestra(persona);
    }
    await _guardarEpoca(persona, remoto.epoca);
    return cambio;
  }

  // ------------------------------------------------------------------ interno

  Future<void> _guardarEpoca(String persona, [int? epoca]) async {
    try {
      final valor = epoca ?? (await servidor.leerEstado()).epoca;
      await almacen.escribir(_claveEpoca(persona), '$valor');
    } catch (_) {
      // Sin señal: se vuelve a fijar la próxima vez que se revise.
    }
  }

  Future<void> _olvidarLlaveMaestra(String persona) async {
    // Solo la llave maestra: la local se queda (es la de `solo_telefono`).
    await almacen.borrar('hab.llave_maestra.$persona');
    llaves.olvidarEnMemoria();
  }

  /// Cambia los sobres de [tipo] de este equipo por [nuevos].
  Future<void> _reemplazar(
    String persona,
    TipoSensible tipo,
    List<Sobre> nuevos,
  ) async {
    await sobres.borrar(persona, tipo: tipo);
    for (final s in nuevos) {
      await sobres.guardar(persona, s);
    }
  }

  /// Abre cada sobre con las llaves [de] y lo vuelve a cifrar con las llaves
  /// [a] (otro id opaco). Lanza si alguno no abre: nunca se pierde un documento
  /// en silencio. [origen] son los sobres a convertir (por omisión, los del
  /// equipo).
  Future<List<Sobre>> _resellar(
    String persona,
    TipoSensible tipo, {
    required _Llaves de,
    required _Llaves a,
    List<Sobre>? origen,
    int llaveVersion = 1,
  }) async {
    final deTipo = de.tipo;
    final aTipo = a.tipo;
    if (deTipo == null || aTipo == null || de.ids == null || a.ids == null) {
      throw ErrorNubeCifrada.sinLlaveEnEsteEquipo;
    }
    final lista = origen ?? await sobres.todos(persona, tipo: tipo);
    final nuevos = <Sobre>[];
    for (final sobre in lista) {
      final doc = descifrarDocumento(
        llaveDeTipo: Uint8List.fromList(deTipo),
        persona: persona,
        sobre: sobre,
      );
      final clave = doc?['clave'];
      if (doc == null || clave is! String) {
        throw const ErrorNubeCifrada(
          'No pude abrir uno de tus documentos con la llave de este equipo, '
          'así que no cambié nada. Tus datos siguen como estaban.',
        );
      }
      nuevos.add(
        cifrarDocumento(
          llaveDeTipo: Uint8List.fromList(aTipo),
          llaveDeIds: Uint8List.fromList(a.ids!),
          persona: persona,
          tipo: tipo,
          claveDoc: clave,
          documento: doc,
          revisionAnterior: sobre.revision,
          llaveVersion: llaveVersion,
        ),
      );
    }
    return nuevos;
  }

  /// Los sobres locales de [tipo] ya fusionados con los de la nube (cifrados
  /// con la llave maestra). No guarda nada.
  Future<List<Sobre>> _traerDeLaNube(
    String persona,
    TipoSensible tipo,
    Uint8List maestra,
  ) async {
    final remotos = await _conServidor(() => servidor.sobresDeLaNube(tipo));
    final llaveTipo = Uint8List.fromList(
      hkdfSha256(maestra, info: 'gravity-hab/v1/${tipo.valor}'),
    );
    final llaveIds = Uint8List.fromList(
      hkdfSha256(maestra, info: 'gravity-hab/v1/ids'),
    );
    final porId = {
      for (final s in await sobres.todos(persona, tipo: tipo)) s.id: s,
    };
    for (final remoto in remotos) {
      final docRemoto = descifrarDocumento(
        llaveDeTipo: llaveTipo,
        persona: persona,
        sobre: remoto,
      );
      if (docRemoto == null) continue; // otra llave o dañado: se omite
      final local = porId[remoto.id];
      if (local == null) {
        porId[remoto.id] = remoto;
        continue;
      }
      final docLocal = descifrarDocumento(
        llaveDeTipo: llaveTipo,
        persona: persona,
        sobre: local,
      );
      if (docLocal == null) {
        porId[remoto.id] = remoto;
        continue;
      }
      final fusion = fusionarDocumentos(
        DocumentoSensible.deJson(
          (docLocal['doc']! as Map).cast<String, Object?>(),
        ),
        DocumentoSensible.deJson(
          (docRemoto['doc']! as Map).cast<String, Object?>(),
        ),
      );
      final fusionJson = fusion.aJson();
      final localJson = (docLocal['doc']! as Map).cast<String, Object?>();
      if (jsonEncode(fusionJson) == jsonEncode(localJson) &&
          local.revision >= remoto.revision) {
        continue;
      }
      porId[remoto.id] = cifrarDocumento(
        llaveDeTipo: llaveTipo,
        llaveDeIds: llaveIds,
        persona: persona,
        tipo: tipo,
        claveDoc: docLocal['clave']! as String,
        documento: {'clave': docLocal['clave'], 'doc': fusionJson},
        revisionAnterior: local.revision > remoto.revision
            ? local.revision
            : remoto.revision,
        llaveVersion: local.llaveVersion,
      );
    }
    return porId.values.toList();
  }
}

class _Llaves {
  const _Llaves(this.tipo, this.ids);

  final List<int>? tipo;
  final List<int>? ids;
}
