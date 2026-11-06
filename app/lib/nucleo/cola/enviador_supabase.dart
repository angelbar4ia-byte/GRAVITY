/// Enviador de la cola hacia Supabase: cada `tipo` va a una tabla. Inserta con
/// `ON CONFLICT (id) DO NOTHING`, así un reenvío no duplica y sirve también
/// para el libro solo-agregar (no necesita permiso de actualizar).
///
/// Sigue el contrato del servidor (`supabase/README.md`, «Contrato para la
/// app»):
///
/// - **Mismo id y mismo contenido:** no hace nada y no falla (0 filas).
///   **Mismo id con otro contenido** en un libro solo agregar: 23505, un
///   duplicado real que requiere atención.
/// - **23503** (falta algo de lo que depende) se reintenta, sin detener la
///   ronda ([FaltaDependenciaEnvio]).
/// - **23514, 22023, 55000 y 42501** son permanentes: requieren atención.
/// - **Columnas que pone el servidor** (`recibido_en`, `libro_origen_id`,
///   `libro_destino_id`, las generadas…): nunca se mandan
///   ([columnasQuePoneElServidor]).
/// - **Orden de subida** por dependencia ([nivelesDeSubidaFinanzas]).
/// - **Cambios de estado** (marcar la semana cerrada): `UPDATE` de solo esas
///   columnas, idempotente ([actualizaciones]).
///
/// Revisión de la Fase 0 (I4): sin sesión no envía (la petición saldría con la
/// llave pública y el servidor la negaría); los errores de red se reintentan,
/// y lo que el servidor no acepta queda en "requiere atención".
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../base_local/base_local.dart' show OrigenRegistro;
import '../sesion/errores_red.dart';
import 'cola_sin_conexion.dart';
import 'contrato_servidor.dart';

class EnviadorSupabase implements EnviadorOrdenado {
  /// Envía siempre con [cliente].
  EnviadorSupabase(
    SupabaseClient cliente, {
    required this.tablas,
    this.actualizaciones = const {},
    this.funciones = const {},
    this.alResponderFuncion,
    this.niveles = nivelesDeSubidaFinanzas,
    this.columnasDelServidor = columnasQuePoneElServidor,
  }) : _cliente = (() => cliente);

  /// Envía con el cliente que devuelva [cliente] en cada envío: en la tablet,
  /// el de la persona que entró con su PIN (I6).
  EnviadorSupabase.dinamico(
    SupabaseClient Function() cliente, {
    required this.tablas,
    this.actualizaciones = const {},
    this.funciones = const {},
    this.alResponderFuncion,
    this.niveles = nivelesDeSubidaFinanzas,
    this.columnasDelServidor = columnasQuePoneElServidor,
  }) : _cliente = cliente;

  final SupabaseClient Function() _cliente;

  /// Tabla de destino por tipo, p. ej. `{'finanzas.gasto': 'movimientos'}`.
  /// Cada módulo agrega la suya en su fase. Estos tipos **insertan** (con
  /// `ON CONFLICT (id) DO NOTHING`).
  final Map<String, String> tablas;

  /// Tipos que no insertan sino **cambian** una fila que ya está en el
  /// servidor, por `id`: tipo → tabla, p. ej.
  /// `{'finanzas.semana_cerrada': 'fin_semanas'}`. La carga lleva solo las
  /// columnas que cambian (`{'estado': 'cerrada'}`); el `id` del registro es el
  /// de la fila. Es idempotente: si la fila ya está así, no hace nada; si la
  /// fila aún no existe en el servidor, se reintenta (falta una dependencia).
  final Map<String, String> actualizaciones;

  /// Tipos que llaman a una **función** del servidor en lugar de escribir una
  /// tabla: tipo → función, p. ej. `{'habitos.sobres': 'hab_subir_sobres'}`. La
  /// carga son los parámetros de la función (`{'p_sobres': […]}`); deben ser
  /// idempotentes. Lo que responde la función (p. ej. los conflictos de
  /// `hab_subir_sobres`) va a [alResponderFuncion].
  final Map<String, String> funciones;

  /// Recibe lo que respondió una función de [funciones] (tipo y respuesta).
  final void Function(String tipo, Object? respuesta)? alResponderFuncion;

  /// Nivel de subida por tabla (ver [nivelesDeSubidaFinanzas]).
  final Map<String, int> niveles;

  /// Columnas que pone el servidor, por tabla: no se mandan.
  final Map<String, Set<String>> columnasDelServidor;

  @override
  int nivelDeSubida(String tipo) {
    final cambia = actualizaciones[tipo];
    if (cambia != null) {
      return niveles[claveDeActualizacion(cambia)] ?? niveles[cambia] ?? 0;
    }
    final tabla = tablas[tipo];
    return tabla == null ? 0 : (niveles[tabla] ?? 0);
  }

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    final cliente = _cliente();
    if (cliente.auth.currentSession == null) return ResultadoEnvio.sinSesion;
    final funcion = funciones[peticion.tipo];
    if (funcion != null) return _llamarFuncion(cliente, funcion, peticion);
    final cambia = actualizaciones[peticion.tipo];
    final tabla = cambia ?? tablas[peticion.tipo];
    if (tabla == null) {
      throw RechazoEnvio(
        'La app no sabe a dónde subir "${peticion.tipo}" (falta su tabla).',
      );
    }
    // D14: el dinero (y lo personal) nunca sale con el origen "tablet de la
    // casa" (solo el nombre, sin PIN); `encolar` ya lo impide, y esto cubre un
    // registro viejo o un tipo mal declarado.
    if (peticion.origen == OrigenRegistro.tabletCasa &&
        (tabla.startsWith('fin_') || esTipoPersonal(peticion.tipo))) {
      throw const RechazoEnvio(
        'Lo personal pide nombre y PIN: no se sube desde la tablet de la casa '
        'solo con el nombre (D14).',
      );
    }
    try {
      if (cambia != null) {
        await _actualizar(cliente, tabla, peticion);
      } else {
        await _insertar(cliente, tabla, peticion);
      }
      return ResultadoEnvio.enviado;
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw FaltaDependenciaEnvio(_motivoDeDependencia(error));
      }
      final resultado = clasificarErrorPostgrest(error.code);
      if (resultado == ResultadoEnvio.rechazado) {
        throw RechazoEnvio(motivoDeRechazo(error));
      }
      return resultado;
    } on FaltaDependenciaEnvio {
      rethrow;
    } on RechazoEnvio {
      rethrow;
    } catch (error) {
      // Sin red: la cola reintenta con espera creciente. Cualquier otro error
      // (no es de red) requiere atención.
      if (esErrorDeRed(error)) rethrow;
      throw RechazoEnvio('Error al subir: $error');
    }
  }

  /// Llama a una función del servidor (`rpc`) con la carga como parámetros.
  /// Los datos de Hábitos jamás se tratan como filas del libro, y nada de la
  /// carga se escribe en los mensajes de error.
  Future<ResultadoEnvio> _llamarFuncion(
    SupabaseClient cliente,
    String funcion,
    PeticionEnvio peticion,
  ) async {
    if (peticion.origen == OrigenRegistro.tabletCasa) {
      throw const RechazoEnvio(
        'Lo personal pide nombre y PIN: no se sube desde la tablet de la casa '
        'solo con el nombre (D14).',
      );
    }
    try {
      final respuesta = await cliente.rpc(funcion, params: peticion.carga);
      alResponderFuncion?.call(peticion.tipo, respuesta);
      return ResultadoEnvio.enviado;
    } on PostgrestException catch (error) {
      final resultado = clasificarErrorPostgrest(error.code);
      if (resultado == ResultadoEnvio.rechazado) {
        throw RechazoEnvio(
          'El servidor no aceptó el lote (${error.code ?? 'sin código'}).',
        );
      }
      return resultado;
    } catch (error) {
      if (esErrorDeRed(error)) rethrow;
      throw const RechazoEnvio('No se pudo subir el lote.');
    }
  }

  /// `INSERT … ON CONFLICT (id) DO NOTHING`, sin las columnas del servidor.
  Future<void> _insertar(
    SupabaseClient cliente,
    String tabla,
    PeticionEnvio peticion,
  ) async {
    final fila = {
      ...sinColumnasDelServidor(
        tabla,
        peticion.carga,
        columnas: columnasDelServidor,
      ),
      'id': peticion.id,
    };
    // Si faltara, el servidor pondría la hora de cada intento y un reenvío
    // tras una respuesta perdida sería "otro contenido" (23505). La hora en
    // que se registró es la del dispositivo y no cambia entre reintentos.
    for (final MapEntry(:key, :value)
        in (_valoresPorOmision[tabla] ?? const {}).entries) {
      fila[key] ??= value(peticion);
    }
    await cliente
        .from(tabla)
        .upsert(fila, onConflict: 'id', ignoreDuplicates: true);
  }

  /// `UPDATE tabla SET <cambios> WHERE id = … AND <alguna columna distinta>`.
  /// El filtro hace idempotente el reenvío: el servidor no deja "cerrar" una
  /// semana ya cerrada (55000), y tras una respuesta perdida eso no es un
  /// error. Con 0 filas se distingue "ya estaba así" de "la fila no existe".
  Future<void> _actualizar(
    SupabaseClient cliente,
    String tabla,
    PeticionEnvio peticion,
  ) async {
    final cambios = sinColumnasDelServidor(
      tabla,
      peticion.carga,
      columnas: columnasDelServidor,
    )..remove('id');
    if (cambios.isEmpty) {
      throw const RechazoEnvio('El cambio no dice qué columnas actualizar.');
    }
    final distintos = [
      for (final MapEntry(:key, :value) in cambios.entries)
        value == null ? '$key.not.is.null' : '$key.neq.${_literal(value)}',
    ].join(',');
    final cambiadas = await cliente
        .from(tabla)
        .update(cambios)
        .eq('id', peticion.id)
        .or(distintos)
        .select('id');
    if (cambiadas.isNotEmpty) return;

    var yaEstaAsi = cliente.from(tabla).select('id').eq('id', peticion.id);
    for (final MapEntry(:key, :value) in cambios.entries) {
      yaEstaAsi = value == null
          ? yaEstaAsi.isFilter(key, null)
          : yaEstaAsi.eq(key, value);
    }
    if ((await yaEstaAsi).isEmpty) {
      throw FaltaDependenciaEnvio(
        'La fila ${peticion.id} de $tabla aún no existe en el servidor '
        '(¿falta que suba?).',
      );
    }
  }

  /// Valor de un filtro de PostgREST (`columna.neq.valor`): entre comillas si
  /// lleva caracteres que separan.
  static String _literal(Object valor) {
    final texto = '$valor';
    if (!RegExp(r'[,()":\\]').hasMatch(texto)) return texto;
    final escapado = texto.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escapado"';
  }

  static Object? _registradoEn(PeticionEnvio peticion) =>
      peticion.creadoEn.toUtc().toIso8601String();

  /// Columnas con valor del dispositivo si la carga no las trae.
  static const Map<String, Map<String, Object? Function(PeticionEnvio)>>
  _valoresPorOmision = {
    'fin_movimientos': {'registrado_en': _registradoEn},
  };

  /// Por qué el servidor no aceptó un registro (queda en "requiere atención").
  static String motivoDeRechazo(PostgrestException error) =>
      switch (error.code) {
        '42501' => 'Sin permiso para guardarlo (42501).',
        '23505' =>
          'Ya existe un registro con ese identificador y otro contenido '
              '(duplicado, 23505): ${error.message}',
        '23514' =>
          'Los datos no cumplen una regla de la tabla (23514): '
              '${error.message}',
        '22023' =>
          'El servidor no acepta esa combinación (22023): ${error.message}',
        '55000' => 'El estado actual no lo permite (55000): ${error.message}',
        final codigo =>
          'El servidor no lo aceptó (${codigo ?? 'sin código'}): '
              '${error.message}',
      };

  static String _motivoDeDependencia(PostgrestException error) =>
      'Falta algo de lo que depende (23503); se reintenta: ${error.message}';
}

/// Decide si un error de PostgREST se reintenta o se rechaza (requiere
/// atención). Solo se reintenta lo pasajero.
///
/// El contrato del servidor: **23503** (falta algo de lo que depende) se
/// reintenta; **23505** (mismo id con otro contenido: un duplicado real),
/// **23514** (regla de la tabla), **22023** (regla de negocio), **55000**
/// (estado) y **42501** (sin permiso) son permanentes. Ninguno de estos
/// últimos es de las clases que se reintentan (08, 40001, 40P01, 53, 57).
ResultadoEnvio clasificarErrorPostgrest(String? codigo) {
  if (codigo == null) return ResultadoEnvio.reintentar;
  // Llave foránea: quizá el registro del que depende aún no sube.
  if (codigo == '23503') return ResultadoEnvio.reintentar;
  // Token vencido o inválido (PGRST301 a 303): se renueva y se reintenta.
  if (codigo.startsWith('PGRST3')) return ResultadoEnvio.reintentar;
  // Sin conexión con la base (PGRST000 a 003), servidor ocupado o caído.
  if (codigo.startsWith('PGRST0')) return ResultadoEnvio.reintentar;
  // Estado HTTP sin cuerpo de PostgREST (3 cifras; los de PostgreSQL son 5).
  final http = codigo.length == 3 ? int.tryParse(codigo) : null;
  if (http != null && (http >= 500 || http == 408 || http == 429)) {
    return ResultadoEnvio.reintentar;
  }
  // PostgreSQL: conexión (08…), conflicto de serialización o bloqueo
  // (40001, 40P01), recursos (53…) o intervención del operador (57…: tiempo
  // agotado, servidor arrancando o apagándose).
  if (codigo.startsWith('08') ||
      codigo == '40001' ||
      codigo == '40P01' ||
      codigo.startsWith('53') ||
      codigo.startsWith('57')) {
    return ResultadoEnvio.reintentar;
  }
  // Integridad (23505, 23514…), datos inválidos (22…), estado (55000), sin
  // permiso por RLS o columna (42501), columna o tabla desconocida (42…,
  // PGRST2…) y demás: requiere atención.
  return ResultadoEnvio.rechazado;
}
