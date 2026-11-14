/// Repositorio de Alimentación con Supabase (Fase 7, D28), con el mismo patrón
/// que Cuidados: una [FuenteTablas] (la de Finanzas, no un cliente nuevo) con
/// el cliente de la persona activa. La RLS filtra en el servidor.
///
/// Vive en `app/` y no en el módulo porque la guardia D3 de Alimentación
/// (`f4_alimentacion_test.dart`) prohíbe que el módulo importe red o sesión:
/// el módulo solo conoce la interfaz [RepositorioAlimentacion].
///
/// Nombres reales del servidor (migraciones `20261108`, `20261126`, `20261127`):
///
/// Lectura (select):
/// - `ali_platillos` (id, nombre, ingredientes jsonb, duros), con la receta en
///   `ali_recetas` (platillo_id, titulo, porciones) y `ali_receta_pasos`
///   (receta_id, orden, texto).
/// - `ali_ingredientes`: **el precio vive aquí**: `precio_base_centavos`
///   (supuesto), `precio_real_centavos` y `precio_real_en` (solo los escribe la
///   compra). No existe `ali_precios`. Precios **por unidad**. El historial de
///   compras reales está en `ali_precios_historial`.
/// - `ali_menu`, `ali_compras_marcas`, `ali_suplementos`, `ali_compras` (la
///   lista del servidor) y `ali_ajustes` (libro de la casa).
/// - `ali_votaciones`, `ali_votacion_opciones`, `ali_opcion_platillos`,
///   `ali_votos` (y `personas` para los nombres, si la sesión puede leerlas).
///
/// La lista se escribe por RPC (`ali_agregar_a_lista`), no con INSERT en
/// `ali_compras`.
///
/// Escritura directa (insert/upsert/delete, solo lo que el servidor permite):
/// `ali_platillos`, `ali_recetas`, `ali_receta_pasos`, `ali_menu`,
/// `ali_compras_marcas`, `ali_suplementos` y el **precio base** de
/// `ali_ingredientes`. Precio real, dinero, votos y tomas **nunca** se
/// escriben directo: solo por RPC (`ali_marcar_comprada`, `ali_votar`,
/// `ali_proponer_*`, `ali_confirmar_toma`...).
library;

import 'package:uuid/uuid.dart';

import '../../modulos/alimentacion/casos_uso/importar_recetas.dart'
    show pasilloDeTexto;
import '../../modulos/alimentacion/datos/modelos.dart';
import '../../modulos/alimentacion/datos/repositorio.dart';
export '../../modulos/alimentacion/datos/repositorio.dart'
    show ErrorAlimentacionServidor;
import '../../modulos/alimentacion/datos/votacion.dart';
import '../../modulos/finanzas/datos/fuente_tablas.dart';
import '../../modulos/finanzas/datos/repositorio.dart' show ErrorFinanzas;

final _reUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
bool _esUuid(String s) => _reUuid.hasMatch(s);

String _fechaSql(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _fecha(Object? v) => DateTime.parse(v! as String).toLocal();

/// "2026-11-02" como día local (sin zona).
DateTime _soloFecha(Object? v) {
  final p = DateTime.parse(v! as String);
  return DateTime(p.year, p.month, p.day);
}

double _num(Object? v) => v is num ? v.toDouble() : double.parse('$v');

class RepositorioAlimentacionSupabase implements RepositorioAlimentacion {
  RepositorioAlimentacionSupabase({
    required this.fuente,
    required this.hogarId,
    required this.personaId,
    this.nombre = '',
  });

  final FuenteTablas fuente;
  final String hogarId;
  final String personaId;

  /// Nombre de quien usa la app (para rotular lo suyo en la votación).
  final String nombre;

  static const _uuid = Uuid();

  // ------------------------------------------------------------- Utilidades

  Future<List<Map<String, dynamic>>> _leer(String tabla) => fuente.leer(tabla);

  Future<void> _guardar(
    String tabla,
    List<Map<String, Object?>> filas, {
    String conflicto = 'id',
    bool ignorarDuplicados = false,
  }) => fuente.guardar(
    tabla,
    filas,
    conflicto: conflicto,
    ignorarDuplicados: ignorarDuplicados,
  );

  /// Id de servidor (UUID) de un id de la app: lo que ya es UUID se queda; el
  /// resto (`imp-...`, `p-...`) da siempre el mismo UUID v5 por hogar.
  String _idServidor(String id) => _esUuid(id)
      ? id
      : _uuid.v5(Namespace.url.value, 'gravity:alimentacion:$hogarId:$id');

  Future<T> _votos<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ErrorFinanzas catch (e) {
      throw ErrorVotacion(
        e.sinConexion ? 'Sin conexión. Intenta de nuevo.' : e.mensaje,
      );
    }
  }

  // --------------------------------------------------------------- Platillos

  @override
  Future<List<Platillo>> platillos() async {
    final filas = await _leer('ali_platillos');
    final recetas = await _leer('ali_recetas');
    final pasos = await _leer('ali_receta_pasos');
    final recetaDe = {
      for (final r in recetas)
        if (r['platillo_id'] != null) '${r['platillo_id']}': r,
    };
    final pasosDe = <String, List<Map<String, dynamic>>>{};
    for (final p in pasos) {
      pasosDe.putIfAbsent('${p['receta_id']}', () => []).add(p);
    }
    return [
      for (final f in filas)
        _platillo(
          f,
          recetaDe['${f['id']}'],
          pasosDe['${recetaDe['${f['id']}']?['id']}'] ?? const [],
        ),
    ];
  }

  Platillo _platillo(
    Map<String, dynamic> f,
    Map<String, dynamic>? receta,
    List<Map<String, dynamic>> pasos,
  ) {
    final ordenados = [...pasos]
      ..sort((a, b) => (a['orden'] as num).compareTo(b['orden'] as num));
    final ings = f['ingredientes'];
    return Platillo(
      '${f['id']}',
      '${f['nombre']}',
      [
        if (ings is List)
          for (final i in ings.whereType<Map>())
            Ingrediente(
              '${i['nombre']}',
              _num(i['cantidad']),
              '${i['unidad']}',
              pasilloDeTexto('${i['seccion'] ?? ''}') ?? SeccionCompra.otros,
            ),
      ],
      duros: [
        if (f['duros'] is List)
          for (final d in f['duros'] as List) '$d',
      ],
      pasos: [for (final p in ordenados) '${p['texto']}'],
      porciones: (receta?['porciones'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Future<void> guardarPlatillos(List<Platillo> platillos) async {
    if (platillos.isEmpty) return;
    final existentes = await _leer('ali_platillos');
    final recetas = await _leer('ali_recetas');
    final porNombre = {
      for (final e in existentes)
        '${e['nombre']}'.trim().toLowerCase(): '${e['id']}',
    };
    for (final p in platillos) {
      // Un importado que ya existe por nombre reemplaza al del servidor.
      final id = _esUuid(p.id)
          ? p.id
          : (porNombre[p.nombre.trim().toLowerCase()] ?? _idServidor(p.id));
      await _guardar('ali_platillos', [
        {
          'id': id,
          'hogar_id': hogarId,
          'nombre': p.nombre,
          'ingredientes': [
            for (final i in p.ingredientes)
              {
                'nombre': i.nombre,
                'cantidad': i.cantidad,
                'unidad': i.unidad,
                'seccion': i.seccion.name,
              },
          ],
          'duros': p.duros,
        },
      ]);
      if (p.pasos.isEmpty && p.porciones == 1) continue;
      final previa = recetas.where((r) => '${r['platillo_id']}' == id);
      final recetaId = previa.isEmpty
          ? _idServidor('receta:$id')
          : '${previa.first['id']}';
      await _guardar('ali_recetas', [
        {
          'id': recetaId,
          'hogar_id': hogarId,
          'platillo_id': id,
          'titulo': p.nombre,
          'porciones': p.porciones,
        },
      ]);
      await fuente.borrar('ali_receta_pasos', donde: {'receta_id': recetaId});
      if (p.pasos.isNotEmpty) {
        await _guardar('ali_receta_pasos', [
          for (var i = 0; i < p.pasos.length; i++)
            {
              'id': _idServidor('paso:$recetaId:${i + 1}'),
              'hogar_id': hogarId,
              'receta_id': recetaId,
              'orden': i + 1,
              'texto': p.pasos[i],
            },
        ]);
      }
    }
  }

  // ----------------------------------------------------------------- Precios

  /// Precio vigente por `claveCompra`: el **real** (`precio_real_centavos`)
  /// reemplaza al **base** (`precio_base_centavos`). Sin ninguno, no hay clave.
  /// Los precios del servidor son por una unidad de la clave.
  @override
  Future<Map<String, PrecioIngrediente>> precios() async {
    final r = <String, PrecioIngrediente>{};
    for (final f in await _leer('ali_ingredientes')) {
      final real = f['precio_real_centavos'] as num?;
      final base = f['precio_base_centavos'] as num?;
      final vigente = real ?? base;
      if (vigente == null) continue;
      final clave = claveCompra('${f['nombre']}', '${f['unidad']}');
      r[clave] = PrecioIngrediente(
        clave: clave,
        centavos: vigente.toInt(),
        esBase: real == null,
      );
    }
    return r;
  }

  /// Solo el precio **base** se escribe directo. El real lo escribe el
  /// servidor al marcar la compra (`ali_marcar_comprada`, ver
  /// [registrarCompraReal]): aquí no se hace nada, y no es un error.
  @override
  Future<void> guardarPrecio(PrecioIngrediente precio) async {
    if (!precio.esBase) return;
    final partes = precio.clave.split('|');
    final nombre = partes.first;
    final unidad = partes.length > 1 ? partes.last : '';
    final centavos = (precio.centavos / precio.porCantidad).round();
    final previos = await _leer('ali_ingredientes');
    final i = previos.where(
      (f) =>
          claveCompra('${f['nombre']}', '${f['unidad']}') ==
          claveCompra(nombre, unidad),
    );
    await _guardar('ali_ingredientes', [
      {
        'id': i.isEmpty
            ? _idServidor('ingrediente:${precio.clave}')
            : i.first['id'],
        'hogar_id': hogarId,
        'nombre': i.isEmpty ? nombre : i.first['nombre'],
        'unidad': i.isEmpty ? unidad : i.first['unidad'],
        'precio_base_centavos': centavos,
      },
    ]);
  }

  /// Historial de compras reales (`ali_precios_historial`, solo agregar):
  /// precio por unidad de cada compra.
  @override
  Future<List<CompraPrecio>> historialCompras() async {
    final ings = {
      for (final f in await _leer('ali_ingredientes')) '${f['id']}': f,
    };
    return [
      for (final h in await _leer('ali_precios_historial'))
        if (ings['${h['ingrediente_id']}'] case final ing?)
          CompraPrecio(
            clave: claveCompra('${ing['nombre']}', '${ing['unidad']}'),
            nombre: '${ing['nombre']}',
            unidad: '${ing['unidad']}',
            totalCentavos: (h['precio_centavos'] as num).toInt(),
            cantidad: 1,
            fecha: _fecha(h['registrado_en']),
          ),
    ];
  }

  /// El historial lo escribe el servidor al marcar la compra con monto
  /// (`ali_precios_historial`): aquí no se hace nada.
  @override
  Future<void> guardarCompraPrecio(CompraPrecio compra) async {}

  // ------------------------------------------------- Tiendas e historial (F8)

  /// `ali_tiendas` (id, hogar_id, nombre): la lista de tiendas del hogar.
  @override
  Future<List<Tienda>> tiendas() async =>
      [
        for (final f in await _leer('ali_tiendas'))
          Tienda(
            id: '${f['id']}',
            nombre: '${f['nombre']}',
            activa: f['activa'] != false,
          ),
      ]..sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );

  /// Agrega a `ali_tiendas` (insert directo; la RLS del hogar decide quién).
  /// Con el mismo nombre (sin mayúsculas) devuelve la que ya estaba.
  @override
  Future<Tienda> agregarTienda(String nombre) async {
    final n = nombre.trim();
    if (n.isEmpty || n.length > maxCaracteresTienda) {
      throw const ErrorAlimentacionServidor(
        'El nombre de la tienda lleva de 1 a $maxCaracteresTienda caracteres.',
      );
    }
    try {
      for (final t in await tiendas()) {
        if (_norm(t.nombre) == _norm(n)) return t;
      }
      final id = _uuid.v4();
      await _guardar('ali_tiendas', [
        {'id': id, 'hogar_id': hogarId, 'nombre': n},
      ]);
      return Tienda(id: id, nombre: n);
    } on ErrorFinanzas catch (e) {
      throw ErrorAlimentacionServidor(
        e.sinConexion ? 'Sin conexión. Intenta de nuevo.' : e.mensaje,
      );
    }
  }

  /// `ali_editar_tienda(p_tienda, p_nombre)`: cambia el nombre (dueño y
  /// pareja; el servidor valida 1 a 60 y que no se repita).
  @override
  Future<Tienda> editarTienda(String id, String nombre) async {
    final n = nombre.trim();
    if (n.isEmpty || n.length > maxCaracteresTienda) {
      throw const ErrorAlimentacionServidor(
        'El nombre de la tienda lleva de 1 a $maxCaracteresTienda caracteres.',
      );
    }
    if (!_esUuid(id)) {
      throw const ErrorAlimentacionServidor('La tienda no existe.');
    }
    try {
      await _rpc('ali_editar_tienda', {'p_tienda': id, 'p_nombre': n});
      return Tienda(id: id, nombre: n);
    } on ErrorFinanzas catch (e) {
      throw _errorServidor(e);
    }
  }

  /// `ali_borrar_tienda(p_tienda)`: borra, o la desactiva si tiene compras
  /// (responde `desactivada`).
  @override
  Future<ResultadoBorradoTienda> borrarTienda(String id) async {
    if (!_esUuid(id)) {
      throw const ErrorAlimentacionServidor('La tienda no existe.');
    }
    try {
      final r = await _rpc('ali_borrar_tienda', {'p_tienda': id});
      final texto = (r is Map
              ? (r['resultado'] ?? r['estado'] ?? r['accion'])
              : r)
          .toString()
          .toLowerCase();
      return texto.contains('desactiv')
          ? ResultadoBorradoTienda.desactivada
          : ResultadoBorradoTienda.borrada;
    } on ErrorFinanzas catch (e) {
      throw _errorServidor(e);
    }
  }

  ErrorAlimentacionServidor _errorServidor(ErrorFinanzas e) =>
      ErrorAlimentacionServidor(
        e.sinConexion ? 'Sin conexión. Intenta de nuevo.' : e.mensaje,
      );

  /// `ali_regresar_compra(p_compra, p_motivo)`: la compra marcada vuelve a
  /// pendiente; la original queda revertida en el historial. Se busca la
  /// fila más reciente ya comprada de ese ingrediente en las cuentas del menú.
  @override
  Future<bool> regresarCompra({
    required MenuId menu,
    required DateTime lunes,
    required String clave,
    required String motivo,
  }) async {
    final m = motivo.trim();
    if (m.length < minCaracteresMotivoRegreso) {
      throw const ErrorAlimentacionServidor(
        'El motivo lleva al menos $minCaracteresMotivoRegreso caracteres.',
      );
    }
    try {
      final ings = {
        for (final f in await _leer('ali_ingredientes')) '${f['id']}': f,
      };
      final cuentas = _cuentasDe(menu);
      Map<String, dynamic>? elegida;
      for (final c in await _leer('ali_compras')) {
        final ing = ings['${c['ingrediente_id']}'];
        if (c['comprado'] != true ||
            ing == null ||
            !cuentas.contains(c['cuenta']) ||
            claveCompra('${ing['nombre']}', '${ing['unidad']}') != clave) {
          continue;
        }
        final a = '${c['comprado_en'] ?? ''}';
        final b = '${elegida?['comprado_en'] ?? ''}';
        if (elegida == null || a.compareTo(b) > 0) elegida = c;
      }
      if (elegida == null) {
        throw const ErrorAlimentacionServidor(
          'No encontramos esa compra en el servidor.',
        );
      }
      final r = await _rpc('ali_regresar_compra', {
        'p_compra': '${elegida['id']}',
        'p_motivo': m,
      });
      await marcar(menu, lunes, clave, false);
      final f = _filas(r);
      return (r is Map && r['solicitud_retirada'] == true) ||
          f.any((x) => x['solicitud_retirada'] == true);
    } on ErrorFinanzas catch (e) {
      throw _errorServidor(e);
    }
  }

  /// `ali_porciones_recomendadas(p_hogar_id, p_semana)`: filas
  /// `platillo_id`, `cuenta` (`dueno`/`pareja`) y `porciones`. Si el servidor
  /// no responde, no se muestran porciones.
  @override
  Future<List<PorcionPersona>> porcionesRecomendadas(DateTime lunes) async {
    try {
      final r = await _rpc('ali_porciones_recomendadas', {
        'p_hogar_id': hogarId,
        'p_semana': _fechaSql(lunes),
      });
      return [
        for (final f in _filas(r))
          if (f['platillo_id'] != null &&
              f['porciones'] is num &&
              (f['cuenta'] == 'dueno' || f['cuenta'] == 'pareja'))
            PorcionPersona(
              platilloId: '${f['platillo_id']}',
              cuenta: f['cuenta'] == 'dueno'
                  ? CuentaCompra.dueno
                  : CuentaCompra.pareja,
              porciones: (f['porciones'] as num).toDouble(),
            ),
      ];
    } on ErrorFinanzas {
      return const [];
    }
  }

  /// `ali_fijar_porcion(p_hogar_id, p_platillo, p_semana, p_cuenta, p_porciones)`:
  /// cambia solo la porción de [cuenta] en el menú compartido de la semana.
  @override
  Future<void> fijarPorcion({
    required String platilloId,
    required DateTime lunes,
    required CuentaCompra cuenta,
    required double porciones,
  }) async {
    try {
      await _rpc('ali_fijar_porcion', {
        'p_hogar_id': hogarId,
        'p_platillo': platilloId,
        'p_semana': _fechaSql(lunes),
        'p_cuenta': cuenta == CuentaCompra.dueno ? 'dueno' : 'pareja',
        'p_porciones': porciones,
      });
    } on ErrorFinanzas catch (e) {
      throw _errorServidor(e);
    }
  }

  /// `ali_historial_compras(p_hogar_id, p_cuenta)`: una fila por compra real
  /// (el servidor ya excluye el precio base). Se leen, con tolerancia a los
  /// nombres, `ingrediente`/`nombre`, `unidad`, `cantidad`,
  /// `monto_centavos`/`total_centavos`, `tienda_id`, `tienda`,
  /// `fecha`/`comprada_en`, `compra_id`, `revertida` (o `estado`) y `cuenta_pago`. Las filas sin monto o cantidad válidos se omiten.
  @override
  Future<List<CompraPrecio>> historialCompleto(CuentaCompra cuenta) async {
    try {
      final r = await _rpc('ali_historial_compras', {
        'p_hogar_id': hogarId,
        'p_cuenta': cuenta.name,
      });
      final tiendasPorId = {for (final t in await tiendas()) t.id: t.nombre};
      final out = <CompraPrecio>[];
      for (final f in _filas(r)) {
        final monto = f['monto_centavos'] ?? f['total_centavos'];
        final cant = f['cantidad'];
        final fecha = f['fecha'] ?? f['comprada_en'] ?? f['registrado_en'];
        if (monto is! num || cant is! num || fecha == null) continue;
        if (monto <= 0 || cant <= 0) continue;
        final nombre = '${f['ingrediente'] ?? f['nombre'] ?? ''}';
        final unidad = '${f['unidad'] ?? ''}';
        final tid = f['tienda_id'] == null ? null : '${f['tienda_id']}';
        out.add(
          CompraPrecio(
            clave: claveCompra(nombre, unidad),
            nombre: nombre,
            unidad: unidad,
            totalCentavos: monto.toInt(),
            cantidad: cant.toDouble(),
            fecha: _fecha(fecha),
            tiendaId: tid,
            tienda: tid == null
                ? null
                : ('${f['tienda'] ?? ''}'.isNotEmpty
                      ? '${f['tienda']}'
                      : tiendasPorId[tid]),
            compraId: f['compra_id'] == null ? null : '${f['compra_id']}',
            revertida:
                f['revertida'] == true ||
                '${f['estado'] ?? ''}'.toLowerCase() == 'revertida',
            cuentaPago: '${f['cuenta_pago'] ?? ''}'.isNotEmpty
                ? '${f['cuenta_pago']}'
                : null,
          ),
        );
      }
      return out;
    } on ErrorFinanzas catch (e) {
      throw ErrorAlimentacionServidor(
        e.sinConexion ? 'Sin conexión. Intenta de nuevo.' : e.mensaje,
      );
    }
  }

  /// Lectura de `ali_despensa` (cuenta, ingrediente_id, cantidad); la RLS
  /// deja ver solo la despensa que tu rol puede leer.
  @override
  Future<List<ItemDespensa>> despensa(CuentaCompra cuenta) async {
    final ings = {
      for (final f in await _leer('ali_ingredientes')) '${f['id']}': f,
    };
    return [
      for (final d in await _leer('ali_despensa'))
        if (d['cuenta'] == cuenta.name &&
            ings['${d['ingrediente_id']}'] != null &&
            _num(d['cantidad']) > 0)
          ItemDespensa(
            nombre: '${ings['${d['ingrediente_id']}']!['nombre']}',
            unidad: '${ings['${d['ingrediente_id']}']!['unidad']}',
            cantidad: _num(d['cantidad']),
          ),
    ];
  }

  /// Ingredientes del servidor con `codigo_barras` (la lectura normal de
  /// `ali_ingredientes` ya trae la columna), para la búsqueda del lector.
  @override
  Future<List<Ingrediente>> ingredientesConCodigo() async => [
    for (final f in await _leer('ali_ingredientes'))
      if ('${f['codigo_barras'] ?? ''}'.trim().isNotEmpty)
        Ingrediente(
          '${f['nombre']}',
          1,
          '${f['unidad']}',
          pasilloDeTexto('${f['pasillo'] ?? ''}') ?? SeccionCompra.otros,
          codigoBarras: '${f['codigo_barras']}'.trim(),
        ),
  ];

  /// `ali_guardar_codigo_barras(p_ingrediente, p_codigo)`: el código no se
  /// escribe directo. Se busca el ingrediente por nombre (o se crea sin
  /// precio) y el servidor valida formato (22023), permiso (42501) y que el
  /// código no sea de otro ingrediente del hogar (23505, "Ya existe: ..." en
  /// [FuenteTablas]). Devuelve `true`: quedó en el servidor.
  @override
  Future<bool> guardarIngredienteConCodigo(Ingrediente ingrediente) async {
    try {
      final id = await _ingredientePorNombreOCrea(
        ingrediente.nombre,
        ingrediente.unidad,
      );
      await _rpc('ali_guardar_codigo_barras', {
        'p_ingrediente': id,
        'p_codigo': ingrediente.codigoBarras?.trim(),
      });
      return true;
    } on ErrorFinanzas catch (e) {
      throw ErrorAlimentacionServidor(
        e.sinConexion
            ? 'Sin conexión. Intenta de nuevo.'
            : e.mensaje.startsWith('Ya existe')
            ? 'Ese código ya es de otro producto'
            : e.mensaje,
      );
    }
  }

  // ---------------------------------------------------------------- Votación

  Future<Map<String, String>> _nombres() async {
    final m = <String, String>{if (nombre.isNotEmpty) personaId: nombre};
    try {
      for (final f in await fuente.leer(
        'personas',
        columnas: 'id, nombre_visible',
      )) {
        final n = f['nombre_visible'];
        if (n is String && n.isNotEmpty) m['${f['id']}'] = n;
      }
    } catch (_) {
      // Sin permiso o sin señal: nombre genérico.
    }
    return m;
  }

  @override
  Future<VotacionPlan?> votacion(DateTime dia) async {
    final d = DateTime(dia.year, dia.month, dia.day);
    final candidatas = <Map<String, dynamic>>[];
    for (final v in await _leer('ali_votaciones')) {
      final para = v['para_el'];
      final delDia = para != null
          ? _soloFecha(para) == d
          : () {
              final c = _fecha(v['creada_en']);
              return DateTime(c.year, c.month, c.day) == d;
            }();
      if (delDia) candidatas.add(v);
    }
    if (candidatas.isEmpty) return null;
    // La del plan de la casa primero; después la más reciente.
    candidatas.sort((a, b) {
      final ca = a['cuenta'] == 'casa' ? 0 : 1;
      final cb = b['cuenta'] == 'casa' ? 0 : 1;
      if (ca != cb) return ca.compareTo(cb);
      return _fecha(b['creada_en']).compareTo(_fecha(a['creada_en']));
    });
    final v = candidatas.first;
    final id = '${v['id']}';
    final opciones = [
      for (final o in await _leer('ali_votacion_opciones'))
        if ('${o['votacion_id']}' == id) o,
    ]..sort((a, b) => (a['orden'] as num).compareTo(b['orden'] as num));
    final ids = {for (final o in opciones) '${o['id']}'};
    final platillosDe = <String, List<String>>{};
    for (final op in await _leer('ali_opcion_platillos')) {
      if (ids.contains('${op['opcion_id']}')) {
        platillosDe
            .putIfAbsent('${op['opcion_id']}', () => [])
            .add('${op['platillo_id']}');
      }
    }
    final votos = <String, String>{
      for (final x in await _leer('ali_votos'))
        if ('${x['votacion_id']}' == id)
          '${x['persona_id']}': '${x['opcion_id']}',
    };
    final nombres = await _nombres();
    final cerrada = v['estado'] == 'cerrada';
    return VotacionPlan(
      id: id,
      dia: d,
      abiertaEn: _fecha(v['creada_en']),
      propuestas: [
        for (final o in opciones)
          PropuestaMenu(
            id: '${o['id']}',
            autorId: '${o['propuesto_por']}',
            autorNombre:
                nombres['${o['propuesto_por']}'] ?? 'Alguien de la familia',
            titulo: '${o['titulo']}',
            platilloIds: platillosDe['${o['id']}'] ?? const [],
          ),
      ],
      votos: votos,
      ganadoraVoladoId: cerrada && v['ganadora_por_volado'] == true
          ? '${v['ganadora_id']}'
          : null,
    );
  }

  /// Traduce los cambios de la votación a RPC: propuesta nueva
  /// (`ali_proponer_menu` / `ali_proponer_alternativa`) y el voto de quien usa
  /// la app (`ali_votar`, que también cambia el voto). Nunca escribe en
  /// `ali_votos` ni `ali_votaciones`: los votos de otras personas los manda
  /// cada una desde su sesión.
  @override
  Future<void> guardarVotacion(VotacionPlan v) => _votos(() async {
    var actual = await votacion(v.dia);
    if (actual == null) {
      if (v.propuestas.isEmpty) return;
      await proponerMenu(
        titulo: v.propuestas.first.titulo,
        platillos: v.propuestas.first.platilloIds,
        paraEl: v.dia,
      );
    } else if (actual.propuestas.length < v.propuestas.length) {
      for (var i = actual.propuestas.length; i < v.propuestas.length; i++) {
        await proponerAlternativa(
          votacionId: actual.id,
          titulo: v.propuestas[i].titulo,
          platillos: v.propuestas[i].platilloIds,
        );
      }
    }
    final miVoto = v.votos[personaId];
    if (miVoto == null) return;
    final indice = v.propuestas.indexWhere((p) => p.id == miVoto);
    if (indice < 0) return;
    actual = await votacion(v.dia);
    if (actual == null || indice >= actual.propuestas.length) return;
    final opcion = actual.propuestas[indice].id;
    if (actual.votos[personaId] != opcion) {
      await votar(votacionId: actual.id, opcionId: opcion);
    }
  });

  @override
  Future<void> cerrarVotacionesVencidas(DateTime ahora) async {
    try {
      await cerrarVotaciones();
    } on ErrorFinanzas {
      // Sin señal o sin permiso: se vuelve a intentar al abrir el plan.
    }
  }

  // -------------------------------------------------------------- Presupuesto

  /// Sin un monto en la pregunta, se pregunta si queda algo (1 centavo).
  @override
  Future<bool?> hayPresupuesto() => hayPresupuestoPara(1);

  /// `ali_hay_presupuesto`: solo true o false, nunca cifras. `null` si el
  /// servidor no responde.
  @override
  Future<bool?> hayPresupuestoPara(int montoCentavos, {String? cuenta}) async {
    try {
      final r = await fuente.rpc('ali_hay_presupuesto', {
        'p_hogar_id': hogarId,
        'p_monto_centavos': montoCentavos,
        'p_cuenta': ?cuenta,
      });
      return r is bool ? r : null;
    } on ErrorFinanzas {
      return null;
    }
  }

  // -------------------------------------------------------------------- Menú

  String _menuSql(MenuId m) => m.name;

  @override
  Future<List<EntradaMenu>> menu(MenuId menu, DateTime lunes) async {
    final sem = _fechaSql(lunes);
    return [
      for (final f in await _leer('ali_menu'))
        if (f['menu'] == _menuSql(menu) &&
            '${f['semana']}'.startsWith(sem) &&
            f['platillo_id'] != null)
          EntradaMenu(
            dia: (f['dia'] as num).toInt(),
            tiempo: TiempoComida.values.firstWhere(
              (t) => t.name == f['tiempo'],
              orElse: () => TiempoComida.comida,
            ),
            platilloId: '${f['platillo_id']}',
          ),
    ];
  }

  @override
  Future<void> asignar(
    MenuId menu,
    DateTime lunes,
    int dia,
    TiempoComida tiempo,
    String? platilloId,
  ) async {
    final celda = {
      'hogar_id': hogarId,
      'menu': _menuSql(menu),
      'semana': _fechaSql(lunes),
      'dia': dia,
      'tiempo': tiempo.name,
    };
    if (platilloId == null) {
      await fuente.borrar('ali_menu', donde: celda);
      return;
    }
    await _guardar('ali_menu', [
      {...celda, 'platillo_id': _idServidor(platilloId)},
    ], conflicto: 'hogar_id,menu,semana,dia,tiempo');
  }

  // ----------------------------------------------------------------- Compras

  @override
  Future<Set<String>> comprados(MenuId menu, DateTime lunes) async {
    final sem = _fechaSql(lunes);
    return {
      for (final f in await _leer('ali_compras_marcas'))
        if (f['menu'] == _menuSql(menu) && '${f['semana']}'.startsWith(sem))
          '${f['clave']}',
    };
  }

  @override
  Future<void> marcar(
    MenuId menu,
    DateTime lunes,
    String clave,
    bool comprado,
  ) async {
    final fila = {
      'hogar_id': hogarId,
      'menu': _menuSql(menu),
      'semana': _fechaSql(lunes),
      'clave': clave,
    };
    if (comprado) {
      await _guardar(
        'ali_compras_marcas',
        [fila],
        conflicto: 'hogar_id,menu,semana,clave',
        ignorarDuplicados: true,
      );
    } else {
      await fuente.borrar('ali_compras_marcas', donde: fila);
    }
  }

  /// Cuentas de `ali_compras` que muestra cada menú.
  static Set<String> _cuentasDe(MenuId m) =>
      m == MenuId.papa ? {'papa'} : {'dueno', 'pareja', 'casa'};

  /// La lista del servidor (`ali_compras`) de la semana, con el pasillo del
  /// ingrediente. Se suma a lo que sale del menú.
  @override
  Future<List<CompraLista>> comprasLista(MenuId menu, DateTime lunes) async {
    final cuentas = _cuentasDe(menu);
    final ings = {
      for (final f in await _leer('ali_ingredientes')) '${f['id']}': f,
    };
    final fin = lunes.add(const Duration(days: 7));
    bool enSemana(Object? v) {
      if (v == null) return false;
      final d = _soloFecha(v);
      return !d.isBefore(lunes) && d.isBefore(fin);
    }

    return [
      for (final c in await _leer('ali_compras'))
        if (cuentas.contains(c['cuenta']) &&
            (c['para_el'] == null || enSemana(c['para_el'])) &&
            ings['${c['ingrediente_id']}'] != null)
          CompraLista(
            nombre: '${ings['${c['ingrediente_id']}']!['nombre']}',
            unidad: '${ings['${c['ingrediente_id']}']!['unidad']}',
            cantidad: _num(c['cantidad']),
            seccion:
                pasilloDeTexto(
                  '${ings['${c['ingrediente_id']}']!['pasillo'] ?? ''}',
                ) ??
                SeccionCompra.otros,
            comprada: c['comprado'] == true,
            pendienteAlbacea: c['estado_pago'] == 'solicitud',
          ),
    ];
  }

  /// Compra real: llama a `ali_marcar_comprada`. El servidor escribe el precio
  /// real, el historial, la despensa, la fila de `ali_compras` y el movimiento
  /// del libro correcto; esta clase no escribe en ninguna tabla de dinero.
  /// Solo prepara lo que es de la lista: el ingrediente y la fila de compra.
  ///
  /// Compra de Papá: sin cuenta de pago el servidor deja la solicitud al
  /// albacea (`ResultadoCompra.pendienteAlbacea`), no un error.
  @override
  Future<ResultadoCompra> registrarCompraReal({
    required MenuId menu,
    required DateTime lunes,
    required CompraPrecio compra,
    required PrecioIngrediente precio,
    required CuentaCompra cuenta,
    String? cuentaPagoId,
  }) async {
    // La tienda es obligatoria desde la Fase 8.
    final tiendaId = compra.tiendaId;
    if (tiendaId == null || !_esUuid(tiendaId)) {
      throw const ErrorAlimentacionServidor('Elige la tienda de la compra.');
    }
    try {
      final ingId = await _ingredienteDe(compra);
      final compraId = await _compraDe(
        cuenta: cuenta.name,
        ingredienteId: ingId,
        cantidad: compra.cantidad,
        lunes: lunes,
        unidadDe: compra.unidad,
      );
      final origen = await _cuentaDePago(cuenta, cuentaPagoId);
      final r = await marcarComprada(
        compraId: compraId,
        montoCentavos: compra.totalCentavos,
        cuentaOrigen: origen,
        tiendaId: tiendaId,
      );
      await marcar(menu, lunes, compra.clave, true);
      final estado = r is Map ? r['estado_pago'] : null;
      return ResultadoCompra(pendienteAlbacea: estado == 'solicitud');
    } on ErrorFinanzas catch (e) {
      throw ErrorAlimentacionServidor(
        e.sinConexion ? 'Sin conexión. Intenta de nuevo.' : e.mensaje,
      );
    }
  }

  static String _norm(String t) => t.trim().toLowerCase();

  FichaIngrediente _ficha(Map<String, dynamic> f) => FichaIngrediente(
    id: '${f['id']}',
    nombre: '${f['nombre']}',
    unidad: '${f['unidad']}',
    presentacion: '${f['presentacion'] ?? ''}',
  );

  @override
  Future<FichaIngrediente?> ingredientePorNombre(String nombre) async {
    for (final f in await _leer('ali_ingredientes')) {
      if (_norm('${f['nombre']}') == _norm(nombre)) return _ficha(f);
    }
    return null;
  }

  /// El ingrediente del servidor (por nombre: la unidad, la presentación y la
  /// marca no lo distinguen). Lo crea sin precio solo si falta.
  Future<String> _ingredientePorNombreOCrea(
    String nombre,
    String unidad,
  ) async {
    final ya = await ingredientePorNombre(nombre);
    if (ya != null) return ya.id;
    final id = _idServidor('ingrediente:${_norm(nombre)}');
    await _guardar('ali_ingredientes', [
      {
        'id': id,
        'hogar_id': hogarId,
        'nombre': nombre.trim(),
        'unidad': unidad.trim(),
      },
    ]);
    return id;
  }

  Future<String> _ingredienteDe(CompraPrecio compra) =>
      _ingredientePorNombreOCrea(compra.nombre, compra.unidad);

  /// `ali_agregar_a_lista`: dueño y pareja agregan por función del servidor,
  /// no con INSERT en `ali_compras`.
  @override
  Future<void> agregarALista({
    required String nombre,
    required String unidad,
    required double cantidad,
  }) async {
    try {
      final id = await _ingredientePorNombreOCrea(nombre, unidad);
      await _rpc('ali_agregar_a_lista', {
        'p_hogar_id': hogarId,
        'p_ingrediente': id,
        'p_cantidad': cantidad,
        'p_unidad': unidad.trim(),
      });
    } on ErrorFinanzas catch (e) {
      throw ErrorAlimentacionServidor(
        e.sinConexion ? 'Sin conexión. Intenta de nuevo.' : e.mensaje,
      );
    }
  }

  /// `ali_editar_presentacion`: cambia unidad y presentación del mismo
  /// ingrediente; nunca crea otro.
  @override
  Future<FichaIngrediente> editarPresentacion({
    required String ingredienteId,
    required String unidad,
    required String presentacion,
  }) async {
    try {
      await _rpc('ali_editar_presentacion', {
        'p_ingrediente': ingredienteId,
        'p_unidad': unidad.trim(),
        'p_presentacion': presentacion.trim(),
      });
      for (final f in await _leer('ali_ingredientes')) {
        if ('${f['id']}' == ingredienteId) {
          return FichaIngrediente(
            id: ingredienteId,
            nombre: '${f['nombre']}',
            unidad: unidad.trim(),
            presentacion: presentacion.trim(),
          );
        }
      }
      throw const ErrorAlimentacionServidor('El ingrediente no existe.');
    } on ErrorFinanzas catch (e) {
      throw ErrorAlimentacionServidor(
        e.sinConexion ? 'Sin conexión. Intenta de nuevo.' : e.mensaje,
      );
    }
  }

  /// La fila pendiente de `ali_compras` para ese ingrediente y cuenta, con la
  /// cantidad realmente comprada; si no hay, la pide.
  Future<String> _compraDe({
    required String cuenta,
    required String ingredienteId,
    required double cantidad,
    required DateTime lunes,
    required String unidadDe,
  }) async {
    final previas = [
      for (final c in await _leer('ali_compras'))
        if (c['cuenta'] == cuenta &&
            '${c['ingrediente_id']}' == ingredienteId &&
            c['comprado'] != true)
          c,
    ];
    if (previas.isNotEmpty) {
      final c = previas.first;
      if (_num(c['cantidad']) != cantidad) {
        await fuente.actualizar(
          'ali_compras',
          {'cantidad': cantidad},
          donde: {'id': c['id']},
        );
      }
      return '${c['id']}';
    }
    if (cuenta == 'papa' || cuenta == 'casa') {
      final id = await solicitarCompra(
        cuenta: cuenta,
        ingredienteId: ingredienteId,
        cantidad: cantidad,
        paraEl: lunes,
      );
      if (id == null) {
        throw const ErrorAlimentacionServidor(
          'El servidor no devolvió la compra.',
        );
      }
      return id;
    }
    // Dueño y pareja: la fila nace con la función del servidor, no con INSERT.
    await _rpc('ali_agregar_a_lista', {
      'p_hogar_id': hogarId,
      'p_ingrediente': ingredienteId,
      'p_cantidad': cantidad,
      'p_unidad': unidadDe,
    });
    for (final c in await _leer('ali_compras')) {
      if (c['cuenta'] == cuenta &&
          '${c['ingrediente_id']}' == ingredienteId &&
          c['comprado'] != true) {
        return '${c['id']}';
      }
    }
    throw const ErrorAlimentacionServidor('El servidor no devolvió la compra.');
  }

  /// Cuentas de pago ofrecidas para [cuenta]: `dueno` y `pareja`, las activas
  /// de su libro personal; `casa`, las del libro que el dueño eligió en
  /// `ali_ajustes`; `papa`, ninguna (la compra va al albacea). La de omisión es
  /// la primera de efectivo o banco por nombre. Solo ids y nombres, sin saldos.
  @override
  Future<List<CuentaPago>> cuentasDePago(CuentaCompra cuenta) async {
    if (cuenta == CuentaCompra.papa) return const [];
    String? libro;
    if (cuenta == CuentaCompra.casa) {
      for (final a in await _leer('ali_ajustes')) {
        if (a['libro_casa_id'] != null) libro = '${a['libro_casa_id']}';
      }
      if (libro == null) {
        throw const ErrorAlimentacionServidor(
          'El dueño aún no elige el libro compartido de las compras de la casa.',
        );
      }
    } else {
      for (final l in await fuente.leer('fin_libros')) {
        if (l['tipo'] == 'personal' && '${l['titular_id']}' == personaId) {
          libro = '${l['id']}';
        }
      }
    }
    return libro == null ? const [] : await _cuentasDelLibro(libro);
  }

  Future<List<CuentaPago>> _cuentasDelLibro(String libro) async {
    final filas = [
      for (final c in await fuente.leer('fin_cuentas'))
        if ('${c['libro_id']}' == libro &&
            (c['estado'] ?? 'activa') == 'activa' &&
            (c['clase'] == null ||
                c['clase'] == 'activo' ||
                c['clase'] == 'pasivo'))
          c,
    ]..sort((a, b) => '${a['nombre']}'.compareTo('${b['nombre']}'));
    final liquidas = filas.where(
      (c) => c['tipo'] == 'efectivo' || c['tipo'] == 'banco',
    );
    final omision = liquidas.isEmpty ? null : '${liquidas.first['id']}';
    return [
      for (final c in filas)
        CuentaPago(
          id: '${c['id']}',
          nombre: '${c['nombre']}',
          porOmision: '${c['id']}' == omision,
        ),
    ];
  }

  /// La cuenta de pago que pide `ali_marcar_comprada`: la que eligió la
  /// persona si está entre las que se ofrecen; si no, la de omisión. Papá va
  /// sin cuenta (solicitud al albacea). Si no hay cuenta, se avisa.
  Future<String?> _cuentaDePago(CuentaCompra cuenta, String? elegida) async {
    if (cuenta == CuentaCompra.papa) return elegida;
    final ofrecidas = await cuentasDePago(cuenta);
    if (elegida != null) {
      if (ofrecidas.any((c) => c.id == elegida)) return elegida;
      throw const ErrorAlimentacionServidor(
        'Esa cuenta no está entre las que puedes usar para esta compra.',
      );
    }
    final omision = ofrecidas.where((c) => c.porOmision);
    if (omision.isNotEmpty) return omision.first.id;
    throw const ErrorAlimentacionServidor(
      'No encontramos una cuenta de pago (efectivo o banco) en tu libro.',
    );
  }

  // ----------------------------------------------------------------- Albacea

  /// El libro de Papá (representado y activo) más antiguo, como el servidor.
  Future<String?> _libroDePapa() async {
    final libros = [
      for (final l in await fuente.leer('fin_libros'))
        if (l['tipo'] == 'representado' && l['activo'] != false) l,
    ]..sort((a, b) => '${a['creado_en']}'.compareTo('${b['creado_en']}'));
    return libros.isEmpty ? null : '${libros.first['id']}';
  }

  /// Solo el albacea vigente: la suplente no (aunque el servidor la deje
  /// escribir cuando el cargo queda vacío).
  @override
  Future<bool> esAlbacea() async {
    final libro = await _libroDePapa();
    if (libro == null) return false;
    final ahora = DateTime.now().toUtc();
    for (final m in await fuente.leer('fin_libro_miembros')) {
      if ('${m['libro_id']}' == libro &&
          '${m['persona_id']}' == personaId &&
          m['papel'] == 'albacea' &&
          (m['hasta'] == null ||
              DateTime.parse('${m['hasta']}').isAfter(ahora))) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<List<SolicitudPago>> solicitudesPendientes() async {
    if (!await esAlbacea()) return const [];
    final compras = {
      for (final c in await _leer('ali_compras')) '${c['id']}': c,
    };
    final ings = {
      for (final f in await _leer('ali_ingredientes')) '${f['id']}': f,
    };
    return [
      for (final s in await _leer('ali_solicitudes_pago'))
        if (s['estado'] == 'pendiente' && compras['${s['compra_id']}'] != null)
          SolicitudPago(
            id: '${s['id']}',
            ingrediente:
                '${ings['${compras['${s['compra_id']}']!['ingrediente_id']}']?['nombre'] ?? 'Compra'}',
            cantidad: _num(compras['${s['compra_id']}']!['cantidad']),
            unidad:
                '${ings['${compras['${s['compra_id']}']!['ingrediente_id']}']?['unidad'] ?? ''}',
            montoCentavos: (s['monto_centavos'] as num).toInt(),
          ),
    ];
  }

  /// Rechazadas de compras de esta persona que aún no se reenviaron (intento 1
  /// sin intento 2 posterior).
  @override
  Future<List<SolicitudPago>> solicitudesRechazadasMias() async {
    final filas = await _leer('ali_solicitudes_pago');
    final reenviadas = {
      for (final s in filas)
        if (s['intento'] == 2 && s['estado'] != 'revertida') '${s['compra_id']}',
    };
    final compras = {for (final c in await _leer('ali_compras')) '${c['id']}': c};
    final ings = {for (final f in await _leer('ali_ingredientes')) '${f['id']}': f};
    return [
      for (final s in filas)
        if (s['estado'] == 'rechazada' &&
            s['intento'] == 1 &&
            s['solicitada_por'] == personaId &&
            !reenviadas.contains('${s['compra_id']}') &&
            compras['${s['compra_id']}'] != null)
          SolicitudPago(
            id: '${s['id']}',
            ingrediente: '${ings['${compras['${s['compra_id']}']!['ingrediente_id']}']?['nombre'] ?? 'Compra'}',
            cantidad: _num(compras['${s['compra_id']}']!['cantidad']),
            unidad: '${ings['${compras['${s['compra_id']}']!['ingrediente_id']}']?['unidad'] ?? ''}',
            montoCentavos: (s['monto_centavos'] as num).toInt(),
          ),
    ];
  }

  /// `ali_reenviar_solicitud(p_solicitud, p_justificacion)`: una sola vez.
  @override
  Future<void> reenviarSolicitud({
    required String solicitudId,
    required String justificacion,
  }) async {
    try {
      await _rpc('ali_reenviar_solicitud', {
        'p_solicitud': solicitudId,
        'p_justificacion': justificacion,
      });
    } on ErrorFinanzas catch (e) {
      throw _errorServidor(e);
    }
  }

  @override
  Future<List<CuentaPago>> cuentasDelLibroDePapa() async {
    final libro = await _libroDePapa();
    if (libro == null || !await esAlbacea()) return const [];
    return _cuentasDelLibro(libro);
  }

  @override
  Future<void> resolverSolicitud({
    required String solicitudId,
    required bool aprobar,
    String? cuentaPagoId,
    String? motivo,
  }) async {
    try {
      await resolverSolicitudPago(
        solicitudId: solicitudId,
        aprobar: aprobar,
        cuentaOrigen: aprobar ? cuentaPagoId : null,
        motivo: aprobar ? null : motivo,
      );
    } on ErrorFinanzas catch (e) {
      throw ErrorAlimentacionServidor(
        e.sinConexion ? 'Sin conexión. Intenta de nuevo.' : e.mensaje,
      );
    }
  }

  // ------------------------------------------------------------- Suplementos

  @override
  Future<List<Suplemento>> suplementos(MenuId menu) async => [
    for (final f in await _leer('ali_suplementos'))
      if (f['menu'] == _menuSql(menu))
        Suplemento(
          id: '${f['id']}',
          nombre: '${f['nombre']}',
          dosis: '${f['dosis'] ?? ''}',
          horario: '${f['horario'] ?? ''}',
        ),
  ];

  @override
  Future<void> guardarSuplemento(MenuId menu, Suplemento s) =>
      _guardar('ali_suplementos', [
        {
          'id': _idServidor(s.id),
          'hogar_id': hogarId,
          'menu': _menuSql(menu),
          'nombre': s.nombre,
          'dosis': s.dosis,
          'horario': s.horario,
        },
      ]);

  @override
  Future<void> quitarSuplemento(MenuId menu, String id) =>
      fuente.borrar('ali_suplementos', donde: {'id': _idServidor(id)});

  // ======================================================================= RPC
  // Todo lo que toca dinero, precio real, votos o tomas va por aquí.

  Future<Object?> _rpc(String funcion, Map<String, Object?> parametros) =>
      fuente.rpc(funcion, parametros);

  List<Map<String, dynamic>> _filas(Object? r) => [
    if (r is List)
      for (final f in r.whereType<Map>()) Map<String, dynamic>.from(f),
  ];

  /// `ali_marcar_comprada`: marca la compra de la lista y, con [montoCentavos],
  /// fija el precio real, sube la despensa y registra el gasto (o la solicitud
  /// al albacea si es de Papá). Devuelve lo que responde el servidor.
  Future<Object?> marcarComprada({
    required String compraId,
    int? montoCentavos,
    String? cuentaOrigen,
    String? cuentaGasto,
    String? tiendaId,
  }) => _rpc('ali_marcar_comprada', {
    'p_compra': compraId,
    'p_monto_centavos': montoCentavos,
    'p_cuenta_origen': cuentaOrigen,
    'p_cuenta_gasto': cuentaGasto,
    'p_tienda': ?tiendaId,
  });

  /// `ali_solicitar_compra`: pide un ingrediente para la despensa de Papá
  /// (`papa`) o de la casa (`casa`). Devuelve el id de la compra.
  Future<String?> solicitarCompra({
    required String cuenta,
    required String ingredienteId,
    required double cantidad,
    DateTime? paraEl,
  }) async => await _rpc('ali_solicitar_compra', {
    'p_hogar_id': hogarId,
    'p_cuenta': cuenta,
    'p_ingrediente': ingredienteId,
    'p_cantidad': cantidad,
    'p_para_el': paraEl == null ? null : _fechaSql(paraEl),
  }) as String?;

  /// `ali_resolver_solicitud_pago`: el albacea aprueba (paga) o rechaza (con
  /// motivo) la compra de Papá.
  Future<Object?> resolverSolicitudPago({
    required String solicitudId,
    required bool aprobar,
    String? cuentaOrigen,
    String? cuentaGasto,
    String? motivo,
  }) => _rpc('ali_resolver_solicitud_pago', {
    'p_solicitud': solicitudId,
    'p_aprobar': aprobar,
    'p_cuenta_origen': cuentaOrigen,
    'p_cuenta_gasto': cuentaGasto,
    'p_motivo': motivo,
  });

  /// `ali_sobrantes`: lo no reservado de la despensa del otro (`dueno` o
  /// `pareja`). Solo dueño y pareja.
  Future<List<SobranteDespensa>> sobrantes(String cuenta) async => [
    for (final f in _filas(
      await _rpc('ali_sobrantes', {'p_hogar_id': hogarId, 'p_cuenta': cuenta}),
    ))
      SobranteDespensa(
        ingredienteId: '${f['ingrediente_id']}',
        nombre: '${f['nombre']}',
        unidad: '${f['unidad']}',
        pasillo: '${f['pasillo']}',
        cantidad: _num(f['sobrante']),
      ),
  ];

  /// `ali_menu_del_dia_papa`: solo nombres de platillos por tiempo. Es lo
  /// único que lee la cuenta Casa: no lee `ali_menu` ni `ali_platillos`
  /// directo. La app no manda la fecha de Casa; el servidor usa hoy.
  @override
  Future<List<ComidaDelDia>> menuDelDiaPapa([DateTime? fecha]) async => [
    for (final f in _filas(
      await _rpc('ali_menu_del_dia_papa', {
        'p_hogar_id': hogarId,
        'p_fecha': fecha == null ? null : _fechaSql(fecha),
      }),
    ))
      ComidaDelDia(
        TiempoComida.values.firstWhere(
          (t) => t.name == f['tiempo'],
          orElse: () => TiempoComida.comida,
        ),
        '${f['platillo']}',
      ),
  ];

  /// `ali_proponer_menu`: abre la votación del día. Devuelve su id.
  Future<String?> proponerMenu({
    required String titulo,
    List<String> platillos = const [],
    String cuenta = 'casa',
    DateTime? paraEl,
  }) async => await _rpc('ali_proponer_menu', {
    'p_hogar_id': hogarId,
    'p_titulo': titulo,
    'p_platillos': [
      for (final p in platillos)
        if (_esUuid(p)) p,
    ],
    'p_cuenta': cuenta,
    'p_para_el': paraEl == null ? null : _fechaSql(paraEl),
  }) as String?;

  /// `ali_proponer_alternativa`: la segunda propuesta, de otra persona.
  Future<Object?> proponerAlternativa({
    required String votacionId,
    required String titulo,
    List<String> platillos = const [],
  }) => _rpc('ali_proponer_alternativa', {
    'p_votacion': votacionId,
    'p_titulo': titulo,
    'p_platillos': [
      for (final p in platillos)
        if (_esUuid(p)) p,
    ],
  });

  /// `ali_votar`: vota o cambia el voto mientras la votación esté abierta.
  Future<Object?> votar({
    required String votacionId,
    required String opcionId,
  }) => _rpc('ali_votar', {'p_votacion': votacionId, 'p_opcion': opcionId});

  /// `ali_cerrar_votaciones` del hogar: cuántas cerró. Con empate el servidor
  /// decide por volado.
  Future<int> cerrarVotaciones() async {
    final r = await _rpc('ali_cerrar_votaciones', {'p_hogar_id': hogarId});
    return r is num ? r.toInt() : 0;
  }

  /// `ali_faltantes`: de la votación cerrada, lo necesario, lo disponible
  /// (nulo si tu cuenta no ve esa despensa) y lo que falta.
  Future<List<FaltanteMenu>> faltantes(String votacionId) async => [
    for (final f in _filas(
      await _rpc('ali_faltantes', {'p_votacion': votacionId}),
    ))
      FaltanteMenu(
        ingredienteId: '${f['ingrediente_id']}',
        nombre: '${f['nombre']}',
        unidad: '${f['unidad']}',
        necesario: _num(f['necesario']),
        disponible: f['disponible'] == null ? null : _num(f['disponible']),
        faltante: _num(f['faltante']),
      ),
  ];

  /// `ali_pedir_compra_faltantes`: pasa los faltantes a la lista (sin
  /// repetir). Devuelve cuántos agregó.
  Future<int> pedirCompraFaltantes(
    String votacionId, {
    List<String>? ingredientes,
  }) async {
    final r = await _rpc('ali_pedir_compra_faltantes', {
      'p_votacion': votacionId,
      'p_ingredientes': ingredientes,
    });
    return r is num ? r.toInt() : 0;
  }

  /// `ali_programar_toma` (suplementos de Papá). Devuelve el id de la toma.
  Future<String?> programarToma({
    required String suplementoId,
    required DateTime previstaEn,
  }) async => await _rpc('ali_programar_toma', {
    'p_suplemento': suplementoId,
    'p_prevista': previstaEn.toUtc().toIso8601String(),
  }) as String?;

  /// `ali_confirmar_toma`: dado o no dado, una sola vez.
  Future<Object?> confirmarToma({required String tomaId, required bool dado}) =>
      _rpc('ali_confirmar_toma', {'p_toma': tomaId, 'p_dado': dado});

  /// `ali_revisar_tomas` del hogar: pasa a `sin_confirmar` las tomas vencidas
  /// (gracia de 2 horas) y crea la solicitud de reposición.
  Future<Object?> revisarTomas({Duration gracia = const Duration(hours: 2)}) =>
      _rpc('ali_revisar_tomas', {
        'p_hogar_id': hogarId,
        'p_gracia': '${gracia.inMinutes} minutes',
      });

  /// `ali_resolver_reposicion`: atendida o descartada.
  Future<Object?> resolverReposicion({
    required String reposicionId,
    required bool atendida,
  }) => _rpc('ali_resolver_reposicion', {
    'p_reposicion': reposicionId,
    'p_atendida': atendida,
  });
}

/// Lo que sobra en la despensa del otro (cantidad menos reservado).
class SobranteDespensa {
  const SobranteDespensa({
    required this.ingredienteId,
    required this.nombre,
    required this.unidad,
    required this.pasillo,
    required this.cantidad,
  });
  final String ingredienteId;
  final String nombre;
  final String unidad;
  final String pasillo;
  final double cantidad;
}

/// Un ingrediente del menú ganador y cuánto falta (`ali_faltantes`).
class FaltanteMenu {
  const FaltanteMenu({
    required this.ingredienteId,
    required this.nombre,
    required this.unidad,
    required this.necesario,
    required this.disponible,
    required this.faltante,
  });
  final String ingredienteId;
  final String nombre;
  final String unidad;
  final double necesario;

  /// `null`: tu cuenta no ve esa despensa.
  final double? disponible;
  final double faltante;
}
