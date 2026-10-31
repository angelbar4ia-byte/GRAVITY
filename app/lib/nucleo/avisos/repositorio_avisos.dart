/// Acceso a los avisos y a los dispositivos de la persona (Supabase), detrás de
/// una interfaz. Fase 2, D20 (`docs/specs/fase-2-finanzas.md`, 4.2 y 4.3).
///
/// Los avisos los **crea el servidor** (o `fin_emitir_aviso`); la app solo los
/// lee —cada quien los suyos, por RLS— y cambia su estado con
/// `avisos_marcar`. Las funciones y columnas son las de la especificación; el
/// contrato final lo confirma backend.
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'aviso.dart';

/// Qué se hace con un aviso (`avisos_marcar`).
enum AccionAviso {
  leida('leida'),
  resuelta('resuelta'),
  posponerUnaHora('posponer_1h'),
  posponerManana('posponer_manana');

  const AccionAviso(this.valor);

  final String valor;
}

/// Qué clase de equipo es este (columna `dispositivos.tipo`).
enum TipoEquipoAvisos {
  telefono('telefono'),
  tabletPersonal('tablet_personal'),
  tabletPublica('tablet_publica'),
  laptop('laptop');

  const TipoEquipoAvisos(this.valor);

  final String valor;

  /// Solo el teléfono recibe push por omisión; la tablet personal es opcional y
  /// la pública, nunca (regla 44).
  bool get recibePushPorOmision => this == telefono;
}

abstract interface class RepositorioAvisos {
  /// Un aviso propio por id; `null` si no existe o no es de esta persona.
  Future<Aviso?> leer(String id);

  /// La bandeja: los últimos avisos de la persona, del más nuevo al más viejo.
  Future<List<Aviso>> bandeja({int limite = 100});

  /// La bandeja en vivo (Supabase Realtime; laptop).
  Stream<List<Aviso>> enVivo();

  Future<void> marcar(String avisoId, AccionAviso accion);

  Future<PreferenciasAvisos?> preferencias();

  Future<void> guardarPreferencias(PreferenciasAvisos preferencias);

  /// Da de alta (o reasigna a esta persona) el token del equipo.
  Future<void> registrarDispositivo({
    required String token,
    required String plataforma,
    required String nombre,
    required TipoEquipoAvisos tipo,
  });

  Future<void> quitarDispositivo(String token);
}

/// Con Supabase. No se puede probar sin servidor: las pruebas usan
/// [RepositorioAvisosEnMemoria].
class RepositorioAvisosSupabase implements RepositorioAvisos {
  RepositorioAvisosSupabase(this._cliente);

  /// El cliente con la sesión de quien está dentro (en la tablet, la de la
  /// persona que entró con su PIN).
  final SupabaseClient Function() _cliente;

  @override
  Future<Aviso?> leer(String id) async {
    final fila = await _cliente()
        .from('avisos')
        .select()
        .eq('id', id)
        .maybeSingle();
    return fila == null ? null : Aviso.desdeJson(fila.cast<String, Object?>());
  }

  @override
  Future<List<Aviso>> bandeja({int limite = 100}) async {
    final filas = await _cliente()
        .from('avisos')
        .select()
        .order('creado_en', ascending: false)
        .limit(limite);
    return [
      for (final fila in filas) Aviso.desdeJson(fila.cast<String, Object?>()),
    ];
  }

  @override
  Stream<List<Aviso>> enVivo() => _cliente()
      .from('avisos')
      .stream(primaryKey: ['id'])
      .order('creado_en', ascending: false)
      .limit(100)
      .map(
        (filas) => [
          for (final fila in filas) Aviso.desdeJson(fila.cast<String, Object?>()),
        ],
      );

  @override
  Future<void> marcar(String avisoId, AccionAviso accion) => _cliente().rpc(
    'avisos_marcar',
    params: {'p_aviso_id': avisoId, 'p_accion': accion.valor},
  );

  @override
  Future<PreferenciasAvisos?> preferencias() async {
    final fila = await _cliente().from('avisos_preferencias').select().maybeSingle();
    return fila == null
        ? null
        : PreferenciasAvisos.desdeJson(fila.cast<String, Object?>());
  }

  @override
  Future<void> guardarPreferencias(PreferenciasAvisos preferencias) async {
    final error = preferencias.error;
    if (error != null) throw ArgumentError(error);
    await _cliente().rpc(
      'avisos_actualizar_preferencias',
      params: {
        for (final e in preferencias.aJson().entries) 'p_${e.key}': e.value,
      },
    );
  }

  @override
  Future<void> registrarDispositivo({
    required String token,
    required String plataforma,
    required String nombre,
    required TipoEquipoAvisos tipo,
  }) => _cliente().rpc(
    'registrar_dispositivo',
    params: {
      'p_token': token,
      'p_plataforma': plataforma,
      'p_nombre': nombre,
      'p_tipo': tipo.valor,
    },
  );

  @override
  Future<void> quitarDispositivo(String token) =>
      _cliente().rpc('quitar_dispositivo', params: {'p_token': token});
}

/// En memoria: pruebas y modo demostración.
class RepositorioAvisosEnMemoria implements RepositorioAvisos {
  RepositorioAvisosEnMemoria({this.preferenciasIniciales});

  final Map<String, Aviso> avisos = {};
  PreferenciasAvisos? preferenciasIniciales;
  final _cambios = StreamController<List<Aviso>>.broadcast();

  /// Dispositivos registrados: token → tipo.
  final Map<String, TipoEquipoAvisos> dispositivos = {};
  final List<({String id, AccionAviso accion})> marcados = [];
  int lecturas = 0;

  /// Si no es nulo, `leer` falla con esto (sin señal).
  Object? falla;

  void agregar(Aviso aviso) {
    avisos[aviso.id] = aviso;
    _cambios.add(_ordenados());
  }

  List<Aviso> _ordenados() => avisos.values.toList()
    ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));

  @override
  Future<Aviso?> leer(String id) async {
    lecturas++;
    if (falla != null) throw falla!;
    return avisos[id];
  }

  @override
  Future<List<Aviso>> bandeja({int limite = 100}) async {
    if (falla != null) throw falla!;
    return _ordenados().take(limite).toList();
  }

  @override
  Stream<List<Aviso>> enVivo() async* {
    // Como Supabase Realtime: primero lo que hay, luego los cambios.
    yield _ordenados();
    yield* _cambios.stream;
  }

  @override
  Future<void> marcar(String avisoId, AccionAviso accion) async {
    marcados.add((id: avisoId, accion: accion));
    final aviso = avisos[avisoId];
    if (aviso == null) return;
    avisos[avisoId] = aviso.copiarCon(
      estado: switch (accion) {
        AccionAviso.leida => EstadoAviso.leida,
        AccionAviso.resuelta => EstadoAviso.resuelta,
        _ => EstadoAviso.pospuesta,
      },
    );
    _cambios.add(_ordenados());
  }

  @override
  Future<PreferenciasAvisos?> preferencias() async => preferenciasIniciales;

  @override
  Future<void> guardarPreferencias(PreferenciasAvisos preferencias) async {
    final error = preferencias.error;
    if (error != null) throw ArgumentError(error);
    preferenciasIniciales = preferencias;
  }

  @override
  Future<void> registrarDispositivo({
    required String token,
    required String plataforma,
    required String nombre,
    required TipoEquipoAvisos tipo,
  }) async => dispositivos[token] = tipo;

  @override
  Future<void> quitarDispositivo(String token) async =>
      dispositivos.remove(token);
}
