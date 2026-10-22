/// Repositorio en memoria: para las pruebas y el modo demostración (sin
/// servidor). Repite las reglas del servidor que no dependen de cálculos
/// (libro solo agregar, borrar solo sin datos, cuentas de sistema al crear un
/// libro), para que la app se comporte igual.
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:uuid/uuid.dart';

import 'repositorio.dart';

class RepositorioFinanzasEnMemoria implements RepositorioFinanzas {
  RepositorioFinanzasEnMemoria({
    DatosFinanzas? datos,
    this.personaId,
    Map<String, String> personas = const {},
    bool esMaestra = false,
    String? cuentaMaestra,
    Set<String> adultosConFinanzas = const {},
    String Function()? generarId,
    this.simularSinConexion = false,
  }) : _carga = CargaFinanzas(
         datos: datos ?? DatosFinanzas.vacio,
         personas: Map.of(personas),
         esMaestra: esMaestra,
         cuentaMaestra: cuentaMaestra,
         adultosConFinanzas: adultosConFinanzas,
       ),
       _generarId = generarId ?? const Uuid().v4;

  /// Persona que usa la app (para los libros que crea).
  final String? personaId;
  final String Function() _generarId;

  /// En pruebas: hace que la configuración falle como sin conexión.
  bool simularSinConexion;

  CargaFinanzas _carga;
  final _cambios = StreamController<CargaFinanzas>.broadcast();

  /// Consultas de la cuenta maestra registradas (para las pruebas).
  final List<String> consultasMaestra = [];

  /// Veces que se cargó (para las pruebas).
  int vecesCargado = 0;

  @override
  CargaFinanzas get actual => _carga;

  @override
  Stream<CargaFinanzas> get cambios => _cambios.stream;

  @override
  Future<CargaFinanzas> cargar() async {
    vecesCargado++;
    return _carga;
  }

  DatosFinanzas get _d => _carga.datos;

  void _publicar(DatosFinanzas datos, {Map<String, String>? personas}) {
    _carga = _carga.copiar(datos: datos, personas: personas);
    if (!_cambios.isClosed) _cambios.add(_carga);
  }

  void _requiereConexion() {
    if (simularSinConexion) throw ErrorFinanzas.conexion;
  }

  static List<T> _reemplazar<T>(
    List<T> lista,
    T nuevo,
    bool Function(T) mismo,
  ) {
    var encontrado = false;
    final resultado = [
      for (final x in lista)
        if (mismo(x)) () {
          encontrado = true;
          return nuevo;
        }() else x,
    ];
    if (!encontrado) resultado.add(nuevo);
    return resultado;
  }

  // ------------------------------------------------------------------ libro

  @override
  Future<ResultadoEscritura> agregarMovimientos(
    List<Movimiento> movimientos,
  ) async {
    final libro = _d.nuevoLibroHogar();
    final nuevos = <Movimiento>[];
    for (final m in movimientos) {
      final existente = _d.movimientos.where((x) => x.id == m.id).firstOrNull;
      if (existente != null) {
        if (existente.mismoContenido(m)) continue;
        throw const ErrorFinanzas(
          'Ese movimiento ya existe con otro contenido: los movimientos no se '
          'editan, se anulan.',
        );
      }
      _validarLibros(m);
      try {
        libro.agregar(m);
      } on ErrorLibro catch (e) {
        throw ErrorFinanzas(e.mensaje);
      }
      nuevos.add(m);
    }
    if (nuevos.isNotEmpty) {
      _publicar(_d.copiar(movimientos: [..._d.movimientos, ...nuevos]));
    }
    return ResultadoEscritura.guardado;
  }

  /// Regla 5 del trigger: solo transferencias y pagos de deuda cruzan libros.
  void _validarLibros(Movimiento m) {
    final o = _d.cuenta(m.cuentaOrigenId)?.libroId;
    final d = _d.cuenta(m.cuentaDestinoId)?.libroId;
    if (o == null || d == null || o == d) return;
    var tipo = m.tipo;
    if (tipo == TipoMovimiento.anulacion && m.anulaA != null) {
      tipo =
          _d.movimientos.where((x) => x.id == m.anulaA).firstOrNull?.tipo ??
          tipo;
    }
    if (tipo != TipoMovimiento.transferencia &&
        tipo != TipoMovimiento.pagoDeuda) {
      throw const ErrorFinanzas(
        'Solo una transferencia o un pago de deuda va de un libro a otro.',
      );
    }
  }

  @override
  Future<ResultadoEscritura> agregarConciliacion(ConciliacionGuardada c) async {
    if (_d.conciliaciones.any((x) => x.id == c.id)) {
      return ResultadoEscritura.guardado;
    }
    _publicar(_d.copiar(conciliaciones: [..._d.conciliaciones, c]));
    return ResultadoEscritura.guardado;
  }

  @override
  Future<void> agregarImportacion(ImportacionGuardada importacion) async {
    if (_d.importaciones.any((x) => x.id == importacion.id)) return;
    _publicar(_d.copiar(importaciones: [..._d.importaciones, importacion]));
  }

  // ---------------------------------------------------------- configuración

  @override
  Future<void> guardarCuentas(List<Cuenta> cuentas) async {
    _requiereConexion();
    var lista = _d.cuentas;
    for (final c in cuentas) {
      final antes = _d.cuenta(c.id);
      if (antes != null &&
          (c.estado == EstadoCuenta.cerrada ||
              c.estado == EstadoCuenta.archivada) &&
          antes.estado != c.estado) {
        final libro = _d.nuevoLibroHogar();
        if (libro.saldo(c.id, incluirPendientes: true) != 0) {
          throw const ErrorFinanzas(
            'Solo se cierra o archiva una cuenta con saldo cero.',
          );
        }
      }
      lista = _reemplazar(lista, c, (x) => x.id == c.id);
    }
    _publicar(_d.copiar(cuentas: lista));
  }

  @override
  Future<void> eliminarCuenta(String id) async {
    _requiereConexion();
    if (_d.movimientos.any(
      (m) => m.cuentaOrigenId == id || m.cuentaDestinoId == id,
    )) {
      throw const ErrorFinanzas(
        'La cuenta tiene movimientos: ciérrala o archívala.',
      );
    }
    _publicar(_d.copiar(cuentas: [..._d.cuentas.where((c) => c.id != id)]));
  }

  @override
  Future<void> guardarCategorias(List<Categoria> categorias) async {
    _requiereConexion();
    var lista = _d.categorias;
    for (final c in categorias) {
      lista = _reemplazar(lista, c, (x) => x.id == c.id);
    }
    _publicar(_d.copiar(categorias: lista));
  }

  @override
  Future<void> eliminarCategoria(String id) async {
    _requiereConexion();
    final conDatos =
        _d.categorias.any((c) => c.padreId == id) ||
        _d.movimientos.any((m) => m.categoriaId == id) ||
        _d.compromisos.any((c) => c.categoriaId == id) ||
        _d.cuentas.any((c) => c.categoriaId == id);
    if (conDatos) {
      throw const ErrorFinanzas(
        'La categoría tiene datos: archívala en lugar de eliminarla.',
      );
    }
    _publicar(
      _d.copiar(categorias: [..._d.categorias.where((c) => c.id != id)]),
    );
  }

  @override
  Future<void> guardarParametros(ParametrosFinanzas parametros) async {
    _requiereConexion();
    _publicar(
      _d.copiar(
        parametros: _reemplazar(
          _d.parametros,
          parametros,
          (p) => p.libroId == parametros.libroId,
        ),
      ),
    );
  }

  @override
  Future<void> guardarIngreso(Ingreso ingreso) async {
    _requiereConexion();
    _publicar(
      _d.copiar(
        ingresos: _reemplazar(_d.ingresos, ingreso, (i) => i.id == ingreso.id),
      ),
    );
  }

  @override
  Future<void> guardarCompromiso(Compromiso compromiso) async {
    _requiereConexion();
    _publicar(
      _d.copiar(
        compromisos: _reemplazar(
          _d.compromisos,
          compromiso,
          (c) => c.id == compromiso.id,
        ),
      ),
    );
  }

  @override
  Future<void> guardarSobre(Sobre sobre) async {
    _requiereConexion();
    _publicar(
      _d.copiar(sobres: _reemplazar(_d.sobres, sobre, (s) => s.id == sobre.id)),
    );
  }

  @override
  Future<void> guardarDeuda(Deuda deuda) async {
    _requiereConexion();
    _publicar(
      _d.copiar(deudas: _reemplazar(_d.deudas, deuda, (x) => x.id == deuda.id)),
    );
  }

  @override
  Future<void> guardarDiasInhabiles(List<DiaInhabil> dias) async {
    _requiereConexion();
    var lista = _d.diasInhabiles;
    for (final dia in dias) {
      final conId = dia.id == null ? dia.copiar(id: _generarId()) : dia;
      lista = _reemplazar(lista, conId, (x) => x.fecha == conId.fecha);
    }
    _publicar(_d.copiar(diasInhabiles: lista));
  }

  /// Las tres cuentas técnicas y los parámetros que el servidor crea con cada
  /// libro (`fin_libros_al_crear`).
  (List<Cuenta>, ParametrosFinanzas) _arranqueDeLibro(String libroId) {
    final ajustes = Cuenta(
      id: _generarId(),
      nombre: 'Ajustes',
      tipo: TipoCuenta.ajustes,
      libroId: libroId,
    );
    final apertura = Cuenta(
      id: _generarId(),
      nombre: 'Apertura',
      tipo: TipoCuenta.apertura,
      libroId: libroId,
    );
    final porClasificar = Cuenta(
      id: _generarId(),
      nombre: 'Por clasificar',
      tipo: TipoCuenta.porClasificar,
      libroId: libroId,
    );
    return (
      [ajustes, apertura, porClasificar],
      ParametrosFinanzas(
        libroId: libroId,
        cuentaAjustesId: ajustes.id,
        cuentaAperturaId: apertura.id,
        cuentaPorClasificarId: porClasificar.id,
      ),
    );
  }

  @override
  Future<void> crearLibroCompartido({
    required String id,
    required String nombre,
    required List<String> otrosMiembros,
  }) async {
    _requiereConexion();
    if (_d.libro(id) != null) return;
    final yo = personaId;
    final libro = Libro(
      id: id,
      nombre: nombre,
      tipo: TipoLibro.compartido,
      miembros: [
        for (final p in {?yo, ...otrosMiembros})
          MiembroLibro(personaId: p, papel: PapelLibro.miembro),
      ],
    );
    final (cuentas, parametros) = _arranqueDeLibro(id);
    _publicar(
      _d.copiar(
        libros: [..._d.libros, libro],
        cuentas: [..._d.cuentas, ...cuentas],
        parametros: [..._d.parametros, parametros],
      ),
    );
  }

  @override
  Future<void> crearLibroRepresentado({
    required String id,
    required String nombreTitular,
    String? nombreLibro,
    String? suplenteId,
  }) async {
    _requiereConexion();
    if (_d.libro(id) != null) return;
    final titular = _generarId();
    final yo = personaId;
    final libro = Libro(
      id: id,
      nombre: (nombreLibro?.trim().isNotEmpty ?? false)
          ? nombreLibro!.trim()
          : nombreTitular.trim(),
      tipo: TipoLibro.representado,
      titularId: titular,
      miembros: [
        if (yo != null)
          MiembroLibro(personaId: yo, papel: PapelLibro.albacea),
        if (suplenteId != null)
          MiembroLibro(personaId: suplenteId, papel: PapelLibro.albaceaSuplente),
      ],
    );
    final (cuentas, parametros) = _arranqueDeLibro(id);
    _publicar(
      _d.copiar(
        libros: [..._d.libros, libro],
        cuentas: [..._d.cuentas, ...cuentas],
        parametros: [..._d.parametros, parametros],
      ),
      personas: {..._carga.personas, titular: nombreTitular.trim()},
    );
  }

  // ------------------------------------------------------------------ plan

  @override
  Future<void> guardarSemana(SemanaGuardada semana) async {
    _requiereConexion();
    final existente = _d.semanas.where((s) => s.id == semana.id).firstOrNull;
    if (existente != null && existente.estado == EstadoSemana.cerrada) {
      throw const ErrorFinanzas(
        'La semana está cerrada: se corrige con anulación y contraasiento.',
      );
    }
    if (_d.semanas.any(
      (s) =>
          s.id != semana.id &&
          s.libroId == semana.libroId &&
          s.semana == semana.semana,
    )) {
      throw const ErrorFinanzas('Esa semana ya está activada.');
    }
    _publicar(
      _d.copiar(
        semanas: _reemplazar(_d.semanas, semana, (s) => s.id == semana.id),
      ),
    );
  }

  @override
  Future<void> cambiarEstadoSemana(String semanaId, EstadoSemana estado) async {
    _requiereConexion();
    final s = _d.semanas.where((x) => x.id == semanaId).firstOrNull;
    if (s == null) throw const ErrorFinanzas('No existe esa semana.');
    if (estado == EstadoSemana.cerrada &&
        !_d.cierres.any((c) => c.semanaId == semanaId)) {
      throw const ErrorFinanzas('Antes de cerrar la semana guarda su cierre.');
    }
    _publicar(
      _d.copiar(
        semanas: [
          for (final x in _d.semanas)
            x.id == semanaId ? x.conEstado(estado) : x,
        ],
      ),
    );
  }

  @override
  Future<void> agregarCierre(
    CierreGuardado cierre, {
    required String libroId,
  }) async {
    _requiereConexion();
    if (_d.cierres.any((c) => c.id == cierre.id)) return;
    final s = _d.semanas.where((x) => x.id == cierre.semanaId).firstOrNull;
    if (s == null) throw const ErrorFinanzas('No existe esa semana.');
    if (s.estado == EstadoSemana.cerrada) {
      throw const ErrorFinanzas(
        'La semana ya está cerrada: reábrela para cerrarla otra vez.',
      );
    }
    // Como el servidor: la versión es `reaperturas + 1`.
    final version = s.versionDelSiguienteCierre;
    if (cierre.version != version) {
      throw ErrorFinanzas('La versión de este cierre es $version.');
    }
    _publicar(
      _d.copiar(
        cierres: [..._d.cierres, cierre],
        semanas: [
          for (final x in _d.semanas)
            x.id == s.id ? x.conEstado(EstadoSemana.cerrada) : x,
        ],
      ),
    );
  }

  @override
  Future<void> guardarOcurrencia(Ocurrencia ocurrencia) async {
    _requiereConexion();
    _publicar(
      _d.copiar(
        ocurrencias: _reemplazar(
          _d.ocurrencias,
          ocurrencia,
          (o) => o.id == ocurrencia.id,
        ),
      ),
    );
  }

  @override
  Future<void> registrarConsultaMaestra(String libroId) async {
    consultasMaestra.add(libroId);
  }

  Future<void> cerrar() => _cambios.close();
}
