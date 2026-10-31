/// Repositorio de Finanzas con Supabase (D7).
///
/// - **Leer:** todas las tablas `fin_*` que la persona puede ver (la RLS
///   filtra por libro: `fin_puede`), más lo que está en la cola sin conexión.
/// - **Libro solo agregar** (movimientos, conciliaciones, importaciones): por
///   la cola sin conexión, con el UUID del dispositivo como llave (un
///   reintento no duplica). Así un gasto sin señal queda guardado en el
///   teléfono y sube al volver.
/// - **Configuración y plan:** directo al servidor (necesitan señal).
/// - **Copia mínima** en el almacenamiento seguro (cuentas, categorías,
///   libros y sobres) para registrar un gasto aunque la app abra sin señal.
library;

import 'dart:async';
import 'dart:convert';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:uuid/uuid.dart';

import '../../../nucleo/base_local/base_local.dart';
import '../../../nucleo/cola/cola_sin_conexion.dart';
import '../../../nucleo/contratos/roles.dart' show Modulo;
import '../../../nucleo/seguridad/limpieza_local.dart' show claveCopiaLocal;
import '../../../nucleo/seguridad/almacen_seguro.dart';
import 'filas.dart';
import 'filas_fase2.dart';
import 'fuente_tablas.dart';
import 'ids.dart';
import 'repositorio.dart';

/// Tipos de registro de la cola sin conexión y su tabla (contrato con
/// plataforma: `tablasColaFinanzas`).
abstract final class TiposCola {
  static const movimiento = 'finanzas.movimiento';
  static const conciliacion = 'finanzas.conciliacion';
  static const importacion = 'finanzas.importacion';
}

/// Tabla de Supabase de cada tipo de registro de la cola sin conexión. La
/// cola sube con `INSERT … ON CONFLICT (id) DO NOTHING` y la sesión de quien
/// registró. Solo van por la cola los libros **solo agregar**: movimientos,
/// conciliaciones e importaciones.
const Map<String, String> tablasDeLaColaFinanzas = {
  TiposCola.movimiento: TablasFinanzas.movimientos,
  TiposCola.conciliacion: TablasFinanzas.conciliaciones,
  TiposCola.importacion: TablasFinanzas.importaciones,
};

/// Copia mínima para trabajar sin señal (cifrada en el dispositivo).
///
/// Vive en el almacén seguro bajo `finanzas.copia.<persona>`
/// ([claveCopiaLocal]): la convención con la que la limpieza de plataforma la
/// borra al **salir**, al detectar una **baja** y al **quitar a la persona de
/// la tablet** (M5 de la revisión de la Fase 1; D5). No guarda saldos ni
/// movimientos.
class CopiaLocalFinanzas {
  CopiaLocalFinanzas(this._almacen, {required String personaId})
    : _clave = claveCopiaLocal(Modulo.finanzas, personaId);

  /// Borra la copia de [personaId] de [almacen]. Nunca lanza: una copia que
  /// no se puede borrar no impide salir ni quitar a nadie.
  static Future<void> borrarDe(AlmacenSeguro almacen, String personaId) =>
      CopiaLocalFinanzas(almacen, personaId: personaId).borrar();

  Future<void> borrar() async {
    try {
      await _almacen.borrar(_clave);
    } catch (_) {
      // Sin esto no pasa nada grave: la próxima carga con señal la reescribe.
    }
  }

  final AlmacenSeguro _almacen;
  final String _clave;

  /// Tablas que se copian: lo necesario para registrar un gasto.
  static const tablas = [
    TablasFinanzas.libros,
    TablasFinanzas.miembros,
    TablasFinanzas.cuentas,
    TablasFinanzas.categorias,
    TablasFinanzas.parametros,
    TablasFinanzas.sobres,
    // Fase 2: los recordatorios locales de vencimientos (regla 45) necesitan
    // las deudas, sus ocurrencias y los días inhábiles sin señal.
    TablasFinanzas.deudas,
    TablasFinanzas.ocurrencias,
    TablasFinanzas.diasInhabiles,
    TablasFinanzas.estadosCuenta,
  ];

  Future<Map<String, dynamic>?> leer() async {
    try {
      final texto = await _almacen.leer(_clave);
      if (texto == null) return null;
      return (jsonDecode(texto) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(Map<String, Object?> copia) async {
    try {
      await _almacen.escribir(_clave, jsonEncode(copia));
    } catch (_) {
      // Sin copia no se pierde nada: solo no se podrá abrir sin señal.
    }
  }
}

class RepositorioFinanzasSupabase implements RepositorioFinanzas {
  RepositorioFinanzasSupabase({
    required this.fuente,
    required this.cola,
    required this.hogarId,
    required this.personaId,
    this.copia,
    this.esperaSubida = const Duration(milliseconds: 1500),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final FuenteTablas fuente;
  final ColaSinConexion cola;
  final String hogarId;
  final String personaId;
  final CopiaLocalFinanzas? copia;

  /// Cuánto se espera a que suba un registro antes de decir "se sube al
  /// volver la señal".
  final Duration esperaSubida;

  final DateTime Function() _reloj;

  CargaFinanzas? _actual;
  final _cambios = StreamController<CargaFinanzas>.broadcast();

  @override
  CargaFinanzas? get actual => _actual;

  @override
  Stream<CargaFinanzas> get cambios => _cambios.stream;

  void _publicar(CargaFinanzas carga) {
    _actual = carga;
    if (!_cambios.isClosed) _cambios.add(carga);
  }

  CargaFinanzas get _carga =>
      _actual ?? CargaFinanzas(datos: DatosFinanzas.vacio);

  // ------------------------------------------------------------------ leer

  static const _tablasDeLectura = [
    TablasFinanzas.libros,
    TablasFinanzas.miembros,
    TablasFinanzas.parametros,
    TablasFinanzas.cuentas,
    TablasFinanzas.categorias,
    TablasFinanzas.ingresos,
    TablasFinanzas.vigencias,
    TablasFinanzas.compromisos,
    TablasFinanzas.sobres,
    TablasFinanzas.deudas,
    TablasFinanzas.diasInhabiles,
    TablasFinanzas.semanas,
    TablasFinanzas.partidasSemana,
    TablasFinanzas.abonosSemana,
    TablasFinanzas.cierres,
    TablasFinanzas.cierrePartidas,
    TablasFinanzas.cierreAbonos,
    TablasFinanzas.ocurrencias,
    TablasFinanzas.conciliaciones,
    TablasFinanzas.importaciones,
    TablasFinanzas.movimientos,
    TablasFinanzas.msi,
    TablasFinanzas.estadosCuenta,
    TablasFinanzas.bolsasAhorro,
    TablasFinanzas.aportacionesAhorro,
    TablasFinanzas.retirosAhorro,
  ];

  static List<Map<String, dynamic>> _de(
    Map<String, List<Map<String, dynamic>>> f,
    String tabla,
  ) => f[tabla] ?? const [];

  /// Arma los datos del dominio con las filas leídas.
  static DatosFinanzas armar(
    Map<String, List<Map<String, dynamic>>> f, {
    List<Movimiento> movimientosEnCola = const [],
    List<ConciliacionGuardada> conciliacionesEnCola = const [],
  }) {
    final miembros = _de(f, TablasFinanzas.miembros);
    final vigencias = _de(f, TablasFinanzas.vigencias);
    final partidas = _de(f, TablasFinanzas.partidasSemana);
    final abonos = _de(f, TablasFinanzas.abonosSemana);
    final cierrePartidas = _de(f, TablasFinanzas.cierrePartidas);
    final cierreAbonos = _de(f, TablasFinanzas.cierreAbonos);
    final movimientos = [
      for (final m in _de(f, TablasFinanzas.movimientos)) movimientoDeFila(m),
    ];
    final ids = {for (final m in movimientos) m.id};
    final conciliaciones = [
      for (final c in _de(f, TablasFinanzas.conciliaciones))
        conciliacionDeFila(c),
    ];
    final idsConc = {for (final c in conciliaciones) c.id};
    return DatosFinanzas(
      libros: [
        for (final l in _de(f, TablasFinanzas.libros)) libroDeFila(l, miembros),
      ],
      parametros: [
        for (final p in _de(f, TablasFinanzas.parametros)) parametrosDeFila(p),
      ],
      cuentas: [
        for (final c in _de(f, TablasFinanzas.cuentas)) cuentaDeFila(c),
      ],
      categorias: [
        for (final c in _de(f, TablasFinanzas.categorias)) categoriaDeFila(c),
      ],
      ingresos: [
        for (final i in _de(f, TablasFinanzas.ingresos))
          ingresoDeFila(i, vigencias),
      ],
      compromisos: [
        for (final c in _de(f, TablasFinanzas.compromisos)) compromisoDeFila(c),
      ],
      sobres: [for (final s in _de(f, TablasFinanzas.sobres)) sobreDeFila(s)],
      deudas: [for (final d in _de(f, TablasFinanzas.deudas)) deudaDeFila(d)],
      msi: [for (final m in _de(f, TablasFinanzas.msi)) msiDeFila(m)],
      estadosDeCuenta: [
        for (final e in _de(f, TablasFinanzas.estadosCuenta))
          estadoDeCuentaDeFila(e),
      ],
      bolsas: [
        for (final b in _de(f, TablasFinanzas.bolsasAhorro)) bolsaDeFila(b),
      ],
      aportaciones: [
        for (final a in _de(f, TablasFinanzas.aportacionesAhorro))
          aportacionDeFila(a),
      ],
      retiros: [
        for (final r in _de(f, TablasFinanzas.retirosAhorro)) retiroDeFila(r),
      ],
      diasInhabiles: [
        for (final d in _de(f, TablasFinanzas.diasInhabiles))
          diaInhabilDeFila(d),
      ],
      semanas: [
        for (final s in _de(f, TablasFinanzas.semanas))
          semanaDeFila(s, partidas, abonos),
      ],
      cierres: [
        for (final c in _de(f, TablasFinanzas.cierres))
          cierreDeFila(c, cierrePartidas, cierreAbonos),
      ],
      ocurrencias: [
        for (final o in _de(f, TablasFinanzas.ocurrencias)) ocurrenciaDeFila(o),
      ],
      conciliaciones: [
        ...conciliaciones,
        for (final c in conciliacionesEnCola)
          if (!idsConc.contains(c.id)) c,
      ],
      importaciones: [
        for (final i in _de(f, TablasFinanzas.importaciones))
          importacionDeFila(i),
      ],
      movimientos: [
        ...movimientos,
        for (final m in movimientosEnCola)
          if (!ids.contains(m.id)) m,
      ],
    );
  }

  /// Lo que está en la cola de este dispositivo y aún no sube.
  Future<(List<Movimiento>, List<ConciliacionGuardada>)> _enCola() async {
    final movimientos = <Movimiento>[];
    final conciliaciones = <ConciliacionGuardada>[];
    for (final r in await cola.registros()) {
      if (r.estado != EstadoPendiente.pendiente) continue;
      try {
        final carga = (jsonDecode(r.carga) as Map).cast<String, dynamic>();
        if (carga['hogar_id'] != hogarId) continue;
        if (r.tipo == TiposCola.movimiento) {
          movimientos.add(movimientoDeFila({...carga, 'id': r.id}));
        } else if (r.tipo == TiposCola.conciliacion) {
          conciliaciones.add(conciliacionDeFila({...carga, 'id': r.id}));
        }
      } catch (_) {
        // Un registro que no se entiende no detiene la carga.
      }
    }
    return (movimientos, conciliaciones);
  }

  /// Nombre de la cuenta maestra del hogar, si existe (`cuenta_maestra`, D19:
  /// cada quien ve que existe). Si no se puede leer, no detiene la carga.
  Future<String?> _cuentaMaestra() async {
    try {
      final r = await fuente.rpc(TablasFinanzas.cuentaMaestra, {
        'p_hogar_id': hogarId,
      });
      final filas = switch (r) {
        final List<Object?> l => l,
        final Map<Object?, Object?> m => [m],
        _ => const <Object?>[],
      };
      for (final f in filas) {
        if (f is Map) return '${f['nombre_visible'] ?? 'Otra persona'}';
      }
      return null;
    } on ErrorFinanzas catch (e) {
      if (e.sinConexion) rethrow;
      return null;
    }
  }

  /// Los adultos con Finanzas del hogar según `fin_adultos_con_finanzas`
  /// (`persona_id`, `nombre_visible`, `rol`): los puede ver **cualquier**
  /// adulto con Finanzas, no solo el dueño, para invitarlos a un compartido que
  /// administra. `null` si la función no responde (se queda con las membresías
  /// que la sesión alcanza a leer).
  Future<List<({String id, String nombre})>?> _adultos() async {
    try {
      final r = await fuente.rpc(TablasFinanzas.adultosConFinanzas, {
        'p_hogar_id': hogarId,
      });
      final filas = switch (r) {
        final List<Object?> l => l,
        final Map<Object?, Object?> m => [m],
        _ => const <Object?>[],
      };
      final adultos = [
        for (final f in filas)
          if (f is Map && f['persona_id'] != null)
            (id: '${f['persona_id']}', nombre: '${f['nombre_visible'] ?? ''}'),
      ];
      return adultos.isEmpty ? null : adultos;
    } on ErrorFinanzas catch (e) {
      if (e.sinConexion) rethrow;
      return null;
    }
  }

  /// Lo que el servidor deja hacer al **suplente** del libro de papá: escribe
  /// y administra solo si el albacea ya no es un adulto con Finanzas del hogar
  /// (I4). Quien no es el dueño no ve las membresías de los demás, así que se
  /// pregunta a `fin_puede` en lugar de adivinar. Solo para ese papel.
  Future<Map<String, PermisoServidor>> _permisosDelSuplente(
    DatosFinanzas datos,
  ) async {
    final hoy = Fecha.deDateTime(_reloj());
    final resultado = <String, PermisoServidor>{};
    for (final l in datos.libros) {
      if (l.tipo != TipoLibro.representado ||
          l.papelDe(personaId, hoy) != PapelLibro.albaceaSuplente) {
        continue;
      }
      try {
        final escribir = await fuente.rpc(TablasFinanzas.puede, {
          'p_libro_id': l.id,
          'p_accion': 'escribir',
        });
        final administrar = await fuente.rpc(TablasFinanzas.puede, {
          'p_libro_id': l.id,
          'p_accion': 'administrar',
        });
        resultado[l.id] = PermisoServidor(
          escribir: escribir == true,
          administrar: administrar == true,
        );
      } on ErrorFinanzas catch (e) {
        if (e.sinConexion) rethrow;
        // Sin respuesta, se queda con el espejo (fechas del libro).
      }
    }
    return resultado;
  }

  @override
  Future<CargaFinanzas> cargar() async {
    final (enColaMov, enColaConc) = await _enCola();
    try {
      final filas = <String, List<Map<String, dynamic>>>{};
      final lecturas = await Future.wait([
        for (final t in _tablasDeLectura) fuente.leer(t),
      ]);
      for (var i = 0; i < _tablasDeLectura.length; i++) {
        filas[_tablasDeLectura[i]] = lecturas[i];
      }
      final personas = await fuente.leer(
        'personas',
        columnas: 'id, nombre_visible',
      );
      final maestra = await fuente.rpc('es_cuenta_maestra', {
        'p_hogar_id': hogarId,
      });
      final membresias = await fuente.leer(
        'membresias',
        columnas: 'persona_id, rol, activa, hogar_id',
      );
      final datos = armar(
        filas,
        movimientosEnCola: enColaMov,
        conciliacionesEnCola: enColaConc,
      );
      final adultos = await _adultos();
      final carga = CargaFinanzas(
        cuentaMaestra: await _cuentaMaestra(),
        adultosConFinanzas: adultos != null
            ? {for (final a in adultos) a.id}
            : {
                for (final m in membresias)
                  if ('${m['hogar_id']}' == hogarId &&
                      m['activa'] != false &&
                      (m['rol'] == 'dueno' || m['rol'] == 'coadministrador'))
                    '${m['persona_id']}',
              },
        datos: datos,
        permisosServidor: await _permisosDelSuplente(datos),
        esMaestra: maestra == true,
        personas: {
          for (final a in adultos ?? const <({String id, String nombre})>[])
            if (a.nombre.isNotEmpty) a.id: a.nombre,
          for (final p in personas) '${p['id']}': '${p['nombre_visible']}',
        },
        movimientosEnCola: {for (final m in enColaMov) m.id},
      );
      _publicar(carga);
      unawaited(
        copia?.guardar({
          for (final t in CopiaLocalFinanzas.tablas) t: filas[t],
          'personas': carga.personas,
          'es_maestra': carga.esMaestra,
          'cuenta_maestra': carga.cuentaMaestra,
          'adultos': carga.adultosConFinanzas.toList(),
          'permisos_servidor': {
            for (final e in carga.permisosServidor.entries)
              e.key: e.value.aJson(),
          },
        }),
      );
      return carga;
    } on ErrorFinanzas catch (e) {
      if (!e.sinConexion) rethrow;
      final ultima = _actual;
      if (ultima != null) {
        final carga = ultima.copiar(desdeCopia: true);
        _publicar(carga);
        return carga;
      }
      final guardada = await copia?.leer();
      if (guardada == null) rethrow;
      final filas = {
        for (final t in CopiaLocalFinanzas.tablas)
          t: [
            for (final f in (guardada[t] as List<Object?>? ?? const []))
              (f! as Map).cast<String, dynamic>(),
          ],
      };
      final carga = CargaFinanzas(
        datos: armar(
          filas,
          movimientosEnCola: enColaMov,
          conciliacionesEnCola: enColaConc,
        ),
        esMaestra: guardada['es_maestra'] == true,
        cuentaMaestra: guardada['cuenta_maestra'] as String?,
        adultosConFinanzas: {
          for (final a in (guardada['adultos'] as List<Object?>? ?? const []))
            '$a',
        },
        personas: (guardada['personas'] as Map? ?? const {})
            .cast<String, String>(),
        permisosServidor: {
          for (final e in (guardada['permisos_servidor'] as Map? ?? const {}).entries)
            '${e.key}': PermisoServidor.deJson(e.value as Map),
        },
        desdeCopia: true,
        movimientosEnCola: {for (final m in enColaMov) m.id},
      );
      _publicar(carga);
      return carga;
    }
  }

  // ------------------------------------------------------------------ libro

  /// Intenta subir ahora; devuelve los [ids] que siguen en la cola.
  Future<Set<String>> _subir(Set<String> ids) async {
    try {
      await cola.procesar().timeout(esperaSubida);
    } on TimeoutException {
      return ids;
    } catch (_) {
      // La cola reintenta sola.
    }
    final pendientes = {
      for (final r in await cola.registros())
        if (r.estado == EstadoPendiente.pendiente && ids.contains(r.id)) r.id,
    };
    return pendientes;
  }

  @override
  Future<ResultadoEscritura> agregarMovimientos(
    List<Movimiento> movimientos,
  ) async {
    final carga = _carga;
    final libro = carga.datos.nuevoLibroHogar();
    final nuevos = <Movimiento>[];
    for (final m in movimientos) {
      final existente = carga.datos.movimientos
          .where((x) => x.id == m.id)
          .firstOrNull;
      if (existente != null && existente.mismoContenido(m)) continue;
      try {
        libro.agregar(m);
      } on ErrorLibro catch (e) {
        throw ErrorFinanzas(e.mensaje);
      }
      nuevos.add(m);
    }
    for (final m in nuevos) {
      await cola.encolar(
        tipo: TiposCola.movimiento,
        carga: filaMovimiento(m, hogarId: hogarId),
        id: m.id,
        personaId: personaId,
      );
    }
    final ids = {for (final m in nuevos) m.id};
    _publicar(
      carga.copiar(
        datos: carga.datos.copiar(
          movimientos: [...carga.datos.movimientos, ...nuevos],
        ),
        movimientosEnCola: {...carga.movimientosEnCola, ...ids},
      ),
    );
    final siguen = await _subir(ids);
    final ahora = _carga;
    _publicar(
      ahora.copiar(
        movimientosEnCola: {
          for (final id in ahora.movimientosEnCola)
            if (!ids.contains(id) || siguen.contains(id)) id,
        },
      ),
    );
    return siguen.isEmpty
        ? ResultadoEscritura.guardado
        : ResultadoEscritura.enCola;
  }

  @override
  Future<ResultadoEscritura> agregarConciliacion(ConciliacionGuardada c) async {
    await cola.encolar(
      tipo: TiposCola.conciliacion,
      carga: filaConciliacion(c, hogarId: hogarId),
      id: c.id,
      personaId: personaId,
    );
    final carga = _carga;
    _publicar(
      carga.copiar(
        datos: carga.datos.copiar(
          conciliaciones: [...carga.datos.conciliaciones, c],
        ),
      ),
    );
    final siguen = await _subir({c.id});
    return siguen.isEmpty
        ? ResultadoEscritura.guardado
        : ResultadoEscritura.enCola;
  }

  @override
  Future<void> agregarImportacion(ImportacionGuardada importacion) async {
    await cola.encolar(
      tipo: TiposCola.importacion,
      carga: filaImportacion(importacion, hogarId: hogarId),
      id: importacion.id,
      personaId: personaId,
    );
    final carga = _carga;
    _publicar(
      carga.copiar(
        datos: carga.datos.copiar(
          importaciones: [...carga.datos.importaciones, importacion],
        ),
      ),
    );
    await _subir({importacion.id});
  }

  // ---------------------------------------------------------- configuración

  /// Aplica un cambio local después de guardarlo en el servidor.
  void _local(DatosFinanzas Function(DatosFinanzas) cambio) {
    final carga = _carga;
    _publicar(carga.copiar(datos: cambio(carga.datos)));
  }

  static List<T> _reemplazar<T>(List<T> lista, T nuevo, bool Function(T) mismo) {
    final i = lista.indexWhere(mismo);
    if (i < 0) return [...lista, nuevo];
    return [...lista]..[i] = nuevo;
  }

  @override
  Future<void> guardarCuentas(List<Cuenta> cuentas) async {
    final List<Map<String, Object?>> filas;
    try {
      filas = [for (final c in cuentas) filaCuenta(c, hogarId: hogarId)];
    } on ArgumentError catch (e) {
      throw ErrorFinanzas('${e.message}');
    }
    await fuente.guardar(TablasFinanzas.cuentas, filas);
    _local((d) {
      var lista = d.cuentas;
      for (final c in cuentas) {
        lista = _reemplazar(lista, c, (x) => x.id == c.id);
      }
      return d.copiar(cuentas: lista);
    });
  }

  @override
  Future<void> eliminarCuenta(String id) async {
    await fuente.borrar(TablasFinanzas.cuentas, donde: {'id': id});
    _local((d) => d.copiar(cuentas: [...d.cuentas.where((c) => c.id != id)]));
  }

  @override
  Future<void> guardarCategorias(List<Categoria> categorias) async {
    // Primero los padres: la llave del padre debe existir.
    final ordenadas = [...categorias]..sort((a, b) => a.nivel - b.nivel);
    await fuente.guardar(TablasFinanzas.categorias, [
      for (final c in ordenadas) filaCategoria(c, hogarId: hogarId),
    ]);
    _local((d) {
      var lista = d.categorias;
      for (final c in categorias) {
        lista = _reemplazar(lista, c, (x) => x.id == c.id);
      }
      return d.copiar(categorias: lista);
    });
  }

  @override
  Future<void> eliminarCategoria(String id) async {
    await fuente.borrar(TablasFinanzas.categorias, donde: {'id': id});
    _local(
      (d) => d.copiar(categorias: [...d.categorias.where((c) => c.id != id)]),
    );
  }

  /// La fila de parámetros nace con el libro (la crea el servidor): aquí
  /// solo se cambia (UPDATE), sin las cuentas de sistema, que no cambian.
  @override
  Future<void> guardarParametros(ParametrosFinanzas parametros) async {
    await fuente.actualizar(
      TablasFinanzas.parametros,
      cambiosParametros(parametros),
      donde: {'libro_id': parametros.libroId},
    );
    _local(
      (d) => d.copiar(
        parametros: _reemplazar(
          d.parametros,
          parametros,
          (p) => p.libroId == parametros.libroId,
        ),
      ),
    );
  }

  @override
  Future<void> guardarIngreso(Ingreso ingreso) async {
    await fuente.guardar(TablasFinanzas.ingresos, [
      filaIngreso(ingreso, hogarId: hogarId),
    ]);
    // Primero se cierra la anterior (hasta) y después va la nueva: las
    // vigencias no se traslapan.
    final ordenadas = [...ingreso.vigencias]
      ..sort((a, b) => (a.hasta == null ? 1 : 0) - (b.hasta == null ? 1 : 0));
    for (final v in ordenadas) {
      await fuente.guardar(TablasFinanzas.vigencias, [
        filaVigencia(v, hogarId: hogarId, libroId: ingreso.libroId),
      ]);
    }
    _local(
      (d) => d.copiar(
        ingresos: _reemplazar(d.ingresos, ingreso, (i) => i.id == ingreso.id),
      ),
    );
  }

  @override
  Future<void> guardarCompromiso(Compromiso compromiso) async {
    await fuente.guardar(TablasFinanzas.compromisos, [
      filaCompromiso(compromiso, hogarId: hogarId),
    ]);
    _local(
      (d) => d.copiar(
        compromisos: _reemplazar(
          d.compromisos,
          compromiso,
          (c) => c.id == compromiso.id,
        ),
      ),
    );
  }

  @override
  Future<void> guardarSobre(Sobre sobre) async {
    await fuente.guardar(TablasFinanzas.sobres, [
      filaSobre(sobre, hogarId: hogarId),
    ]);
    _local(
      (d) => d.copiar(sobres: _reemplazar(d.sobres, sobre, (s) => s.id == sobre.id)),
    );
  }

  @override
  Future<void> guardarMsi(Msi msi) async {
    await fuente.guardar(TablasFinanzas.msi, [filaMsi(msi, hogarId: hogarId)]);
    _local((d) => d.copiar(msi: _reemplazar(d.msi, msi, (x) => x.id == msi.id)));
  }

  @override
  Future<void> agregarEstadoDeCuenta(EstadoDeCuenta estado) async {
    await fuente.guardar(TablasFinanzas.estadosCuenta, [
      filaEstadoDeCuenta(estado, hogarId: hogarId),
    ], ignorarDuplicados: true);
    _local(
      (d) => d.estadosDeCuenta.any((x) => x.id == estado.id)
          ? d
          : d.copiar(estadosDeCuenta: [...d.estadosDeCuenta, estado]),
    );
  }

  @override
  Future<void> guardarBolsa(BolsaAhorro bolsa) async {
    await fuente.guardar(TablasFinanzas.bolsasAhorro, [
      filaBolsa(bolsa, hogarId: hogarId),
    ]);
    _local(
      (d) => d.copiar(bolsas: _reemplazar(d.bolsas, bolsa, (x) => x.id == bolsa.id)),
    );
  }

  @override
  Future<void> guardarAportacion(AportacionAhorro aportacion) async {
    await fuente.guardar(TablasFinanzas.aportacionesAhorro, [
      filaAportacion(aportacion, hogarId: hogarId),
    ]);
    _local(
      (d) => d.copiar(
        aportaciones: _reemplazar(
          d.aportaciones,
          aportacion,
          (x) => x.id == aportacion.id,
        ),
      ),
    );
  }

  @override
  Future<void> agregarRetiro(RetiroAhorro retiro) async {
    await fuente.guardar(TablasFinanzas.retirosAhorro, [
      filaRetiro(retiro, hogarId: hogarId),
    ], ignorarDuplicados: true);
    _local(
      (d) => d.retiros.any((x) => x.id == retiro.id)
          ? d
          : d.copiar(retiros: [...d.retiros, retiro]),
    );
  }

  @override
  Future<void> guardarDeuda(Deuda deuda) async {
    await fuente.guardar(TablasFinanzas.deudas, [
      filaDeuda(deuda, hogarId: hogarId),
    ]);
    _local(
      (d) => d.copiar(deudas: _reemplazar(d.deudas, deuda, (x) => x.id == deuda.id)),
    );
  }

  @override
  Future<void> guardarDiasInhabiles(List<DiaInhabil> dias) async {
    final conId = [
      // Un día por fecha en el hogar (único `(hogar_id, fecha)`): el id sale
      // de la fecha, así precargar dos veces no choca.
      for (final d in dias)
        d.id == null
            ? d.copiar(id: idEstable(ClavesId.diaInhabil(hogarId, fechaIso(d.fecha))))
            : d,
    ];
    await fuente.guardar(TablasFinanzas.diasInhabiles, [
      for (final d in conId) filaDiaInhabil(d, hogarId: hogarId, id: d.id!),
    ]);
    _local((d) {
      var lista = d.diasInhabiles;
      for (final dia in conId) {
        lista = _reemplazar(lista, dia, (x) => x.fecha == dia.fecha);
      }
      return d.copiar(diasInhabiles: lista);
    });
  }

  @override
  Future<void> crearLibroCompartido({
    required String id,
    required String nombre,
    required List<String> otrosMiembros,
    VisibilidadLibro visibilidad = VisibilidadLibro.privada,
  }) async {
    // El servidor agrega a quien lo crea (su administrador, `creado_por`), las
    // cuentas técnicas y los parámetros (fin_libros_al_crear).
    await fuente.guardar(TablasFinanzas.libros, [
      filaLibro(
        Libro(
          id: id,
          nombre: nombre,
          tipo: TipoLibro.compartido,
          visibilidad: visibilidad,
        ),
        hogarId: hogarId,
      ),
    ], ignorarDuplicados: true);
    await fuente.guardar(TablasFinanzas.miembros, [
      for (final p in otrosMiembros)
        if (p != personaId)
          filaMiembro(
            id,
            MiembroLibro(personaId: p, papel: PapelLibro.miembro),
            hogarId: hogarId,
            id: idEstable(ClavesId.miembro(id, p, 'miembro')),
          ),
    ], ignorarDuplicados: true);
    await cargar();
  }

  @override
  Future<void> cambiarVisibilidadLibro(
    String libroId,
    VisibilidadLibro visibilidad,
  ) async {
    await fuente.actualizar(
      TablasFinanzas.libros,
      {'visibilidad': nombreEnum(visibilidad)},
      donde: {'id': libroId},
    );
    _local(
      (d) => d.copiar(
        libros: [
          for (final l in d.libros)
            l.id == libroId ? l.copiar(visibilidad: visibilidad) : l,
        ],
      ),
    );
  }

  @override
  Future<void> archivarLibro(String libroId, {required bool archivado}) async {
    await fuente.actualizar(
      TablasFinanzas.libros,
      {'activo': !archivado},
      donde: {'id': libroId},
    );
    _local(
      (d) => d.copiar(
        libros: [
          for (final l in d.libros)
            l.id == libroId ? l.copiar(activo: !archivado) : l,
        ],
      ),
    );
  }

  @override
  Future<void> agregarMiembro(String libroId, String personaId) async {
    final libro = _carga.datos.libro(libroId);
    // Quien ya estuvo y se salió vuelve con una fila nueva (el único vigente es
    // `(libro, persona)`); la primera vez, un id estable para que reintentar no
    // duplique.
    final yaEstuvo = libro?.miembros.any((m) => m.personaId == personaId) ?? false;
    final id = yaEstuvo
        ? const Uuid().v4()
        : idEstable(ClavesId.miembro(libroId, personaId, 'miembro'));
    await fuente.guardar(TablasFinanzas.miembros, [
      filaMiembro(
        libroId,
        MiembroLibro(personaId: personaId, papel: PapelLibro.miembro),
        hogarId: hogarId,
        id: id,
      ),
    ], ignorarDuplicados: true);
    await cargar();
  }

  /// `hasta = ahora` en la fila vigente de [persona]: deja de ser vigente al
  /// instante (el servidor compara `hasta > now()`).
  Future<void> _terminarMembresia(String libroId, String persona) =>
      fuente.actualizar(
        TablasFinanzas.miembros,
        {'hasta': horaIso(_reloj())},
        donde: {'libro_id': libroId, 'persona_id': persona, 'hasta': null},
      );

  @override
  Future<void> quitarMiembro(String libroId, String persona) async {
    await _terminarMembresia(libroId, persona);
    final hoy = Fecha.deDateTime(_reloj());
    _local(
      (d) => d.copiar(
        libros: [
          for (final l in d.libros)
            l.id == libroId ? l.alSalirse(persona, hoy) : l,
        ],
      ),
    );
    try {
      await cargar();
    } on ErrorFinanzas {
      // Se queda con lo local hasta la próxima carga.
    }
  }

  @override
  Future<void> salirDelLibro(String libroId) async {
    await _terminarMembresia(libroId, personaId);
    // Ya no tiene acceso: el libro sale de su lista (o queda como lector si es
    // público). Lo que cuenta es la próxima carga.
    final hoy = Fecha.deDateTime(_reloj());
    _local(
      (d) => d.copiar(
        libros: [
          for (final l in d.libros)
            l.id == libroId ? l.alSalirse(personaId, hoy) : l,
        ],
      ),
    );
    try {
      await cargar();
    } on ErrorFinanzas {
      // Se queda con lo local hasta la próxima carga.
    }
  }

  @override
  Future<void> crearLibroRepresentado({
    required String id,
    required String nombreTitular,
    String? nombreLibro,
    String? suplenteId,
  }) async {
    await fuente.rpc(TablasFinanzas.crearLibroRepresentado, {
      'p_hogar_id': hogarId,
      'p_nombre_titular': nombreTitular,
      'p_nombre_libro': nombreLibro,
      'p_libro_id': id,
    });
    final carga = await cargar();
    if (suplenteId == null) return;
    // El suplente entra por la función (el INSERT directo ya no pasa). Si un
    // intento anterior ya lo nombró, no se repite.
    final yaEs =
        carga.datos
            .libro(id)
            ?.vigentes(Fecha.deDateTime(_reloj()))
            .any(
              (m) =>
                  m.personaId == suplenteId &&
                  m.papel == PapelLibro.albaceaSuplente,
            ) ??
        false;
    if (!yaEs) {
      await nombrarAlbacea(
        libroId: id,
        personaId: suplenteId,
        papel: PapelLibro.albaceaSuplente,
      );
    }
  }

  @override
  Future<void> nombrarAlbacea({
    required String libroId,
    required String personaId,
    required PapelLibro papel,
  }) async {
    await fuente.rpc(TablasFinanzas.nombrarAlbacea, {
      'p_libro_id': libroId,
      'p_persona_id': personaId,
      'p_papel': nombreEnum(papel),
    });
    await cargar();
  }

  // ------------------------------------------------------------------ plan

  @override
  Future<void> guardarSemana(SemanaGuardada semana) async {
    await fuente.guardar(TablasFinanzas.semanas, [
      filaSemana(semana, hogarId: hogarId),
    ]);
    await fuente.guardar(TablasFinanzas.partidasSemana, [
      for (final p in semana.partidas)
        filaPartidaSemana(p, hogarId: hogarId, libroId: semana.libroId),
    ]);
    await fuente.guardar(TablasFinanzas.abonosSemana, [
      for (final a in semana.abonos)
        filaAbonoSemana(a, hogarId: hogarId, libroId: semana.libroId),
    ]);
    _local(
      (d) => d.copiar(
        semanas: _reemplazar(d.semanas, semana, (s) => s.id == semana.id),
      ),
    );
  }

  @override
  Future<void> cambiarEstadoSemana(String semanaId, EstadoSemana estado) async {
    await fuente.actualizar(
      TablasFinanzas.semanas,
      {'estado': nombreEnum(estado)},
      donde: {'id': semanaId},
    );
    _local(
      (d) => d.copiar(
        semanas: [
          for (final s in d.semanas) s.id == semanaId ? s.conEstado(estado) : s,
        ],
      ),
    );
  }

  /// Cierra la semana en el orden que exige el servidor: primero el cierre
  /// (versión `reaperturas + 1`) con sus renglones y después la semana a
  /// `cerrada`. Los renglones llevan ids estables; el cierre queda en la copia
  /// en cuanto se guarda, así un reintento (si falla el último paso) reusa el
  /// mismo cierre y no choca con nada.
  @override
  Future<void> agregarCierre(
    CierreGuardado cierre, {
    required String libroId,
  }) async {
    await fuente.guardar(TablasFinanzas.cierres, [
      filaCierre(cierre, hogarId: hogarId, libroId: libroId),
    ], ignorarDuplicados: true);
    await fuente.guardar(TablasFinanzas.cierrePartidas, [
      for (final p in cierre.partidas)
        filaCierrePartida(
          cierre.id,
          p,
          hogarId: hogarId,
          libroId: libroId,
          id: idEstable(ClavesId.cierrePartida(cierre.id, p.partidaId)),
        ),
    ], ignorarDuplicados: true);
    await fuente.guardar(TablasFinanzas.cierreAbonos, [
      for (final a in cierre.abonos)
        filaCierreAbono(
          cierre.id,
          a,
          hogarId: hogarId,
          libroId: libroId,
          id: idEstable(ClavesId.cierreAbono(cierre.id, a.deudaId)),
        ),
    ], ignorarDuplicados: true);
    _local(
      (d) => d.copiar(
        cierres: [...d.cierres.where((c) => c.id != cierre.id), cierre],
      ),
    );
    await fuente.actualizar(
      TablasFinanzas.semanas,
      {'estado': nombreEnum(EstadoSemana.cerrada)},
      donde: {'id': cierre.semanaId},
    );
    _local(
      (d) => d.copiar(
        semanas: [
          for (final s in d.semanas)
            s.id == cierre.semanaId ? s.conEstado(EstadoSemana.cerrada) : s,
        ],
      ),
    );
  }

  @override
  Future<void> guardarOcurrencia(Ocurrencia ocurrencia) async {
    await fuente.guardar(TablasFinanzas.ocurrencias, [
      filaOcurrencia(ocurrencia, hogarId: hogarId),
    ]);
    _local(
      (d) => d.copiar(
        ocurrencias: _reemplazar(
          d.ocurrencias,
          ocurrencia,
          (o) => o.id == ocurrencia.id,
        ),
      ),
    );
  }

  @override
  Future<bool> registrarConsultaMaestra(String libroId) async {
    final registrada = await fuente.rpc(TablasFinanzas.consultaMaestra, {
      'p_libro_id': libroId,
    });
    return registrada == true;
  }

  Future<void> cerrar() => _cambios.close();
}
