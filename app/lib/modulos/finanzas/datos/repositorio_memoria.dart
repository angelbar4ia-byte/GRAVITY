/// Repositorio en memoria: para las pruebas y el modo demostración (sin
/// servidor). Repite las reglas del servidor que no dependen de cálculos
/// (libro solo agregar, borrar solo sin datos, cuentas de sistema al crear un
/// libro), para que la app se comporte igual.
library;

import 'dart:async';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:uuid/uuid.dart';

import 'demostracion.dart' show datosDeLibros;
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
    this.exigeConsultaMaestra = false,
    this.vigenciaConsulta = const Duration(minutes: 30),
    this.adultosActivosDelHogar,
    DateTime Function()? reloj,
  }) : _carga = CargaFinanzas(
         datos: datos ?? DatosFinanzas.vacio,
         personas: Map.of(personas),
         esMaestra: esMaestra,
         cuentaMaestra: cuentaMaestra,
         adultosConFinanzas: adultosConFinanzas,
       ),
       _generarId = generarId ?? const Uuid().v4,
       _reloj = reloj ?? DateTime.now;

  /// Persona que usa la app (para los libros que crea).
  final String? personaId;
  final String Function() _generarId;
  final DateTime Function() _reloj;

  /// En pruebas: hace como el servidor (I2). La cuenta maestra no recibe el
  /// contenido de un libro ajeno (solo la portada: libros y miembros) mientras
  /// no tenga una consulta registrada y vigente; sin ella el resultado viene
  /// **vacío**, sin error.
  final bool exigeConsultaMaestra;

  /// Cuánto vale una consulta registrada (30 minutos en el servidor).
  final Duration vigenciaConsulta;

  /// En pruebas: las personas que hoy son adultos con Finanzas del hogar (lo
  /// que sabe el servidor aunque la sesión no lo vea). Con esto, el permiso del
  /// suplente del libro de papá sale como en `fin_puede` (I4). Nulo = no se
  /// emula (se usa el espejo por fechas).
  Set<String>? adultosActivosDelHogar;

  /// En pruebas: hace que la configuración falle como sin conexión.
  bool simularSinConexion;

  CargaFinanzas _carga;
  final _cambios = StreamController<CargaFinanzas>.broadcast();

  /// Consultas de la cuenta maestra registradas (para las pruebas).
  final List<String> consultasMaestra = [];

  /// Cuándo se registró la última consulta de cada libro (libro → instante).
  final Map<String, DateTime> _consultas = {};

  /// Veces que se cargó (para las pruebas).
  int vecesCargado = 0;

  bool _consultaVigente(String libroId) {
    final t = _consultas[libroId];
    return t != null && _reloj().difference(t) < vigenciaConsulta;
  }

  /// Lo que ve la persona: con [exigeConsultaMaestra], la cuenta maestra sin
  /// consulta vigente solo ve la portada de los libros ajenos.
  CargaFinanzas get _vista {
    var carga = _carga;
    final yo = personaId;
    if (yo != null) {
      final hoy = Fecha.deDateTime(_reloj());
      if (exigeConsultaMaestra && carga.esMaestra) {
        final visibles = {
          for (final l in carga.datos.libros)
            if (permisoEnLibro(l, yo, hoy: hoy).leer || _consultaVigente(l.id))
              l.id,
        };
        carga = carga.copiar(datos: datosDeLibros(carga.datos, visibles));
      }
      final activos = adultosActivosDelHogar;
      if (activos != null) {
        carga = carga.copiar(
          permisosServidor: {
            for (final l in _carga.datos.libros)
              if (l.tipo == TipoLibro.representado &&
                  l.papelDe(yo, hoy) == PapelLibro.albaceaSuplente)
                l.id: () {
                  // `fin_puede`: el albacea cuenta si su cargo está abierto y
                  // sigue siendo adulto con Finanzas.
                  final hayAlbacea = l
                      .vigentes(hoy)
                      .any(
                        (m) =>
                            m.papel == PapelLibro.albacea &&
                            activos.contains(m.personaId),
                      );
                  return PermisoServidor(
                    escribir: l.activo && !hayAlbacea,
                    administrar: !hayAlbacea,
                  );
                }(),
          },
        );
      }
    }
    return carga;
  }

  @override
  CargaFinanzas get actual => _vista;

  @override
  Stream<CargaFinanzas> get cambios => _cambios.stream;

  @override
  Future<CargaFinanzas> cargar() async {
    vecesCargado++;
    return _vista;
  }

  DatosFinanzas get _d => _carga.datos;

  void _publicar(DatosFinanzas datos, {Map<String, String>? personas}) {
    _carga = _carga.copiar(datos: datos, personas: personas);
    if (!_cambios.isClosed) _cambios.add(_vista);
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
      // Solo activos y pasivos piden saldo cero; las de gasto e ingreso se
      // cierran o archivan con saldo (23/oct/2026).
      if (antes != null &&
          (c.estado == EstadoCuenta.cerrada ||
              c.estado == EstadoCuenta.archivada) &&
          antes.estado != c.estado &&
          (c.clase == ClaseCuenta.activo || c.clase == ClaseCuenta.pasivo)) {
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

  /// Lo que el servidor rechaza con 42501: cambiar un compartido que no es de
  /// quien lo hace.
  Libro _delAdministrador(String libroId) {
    final libro = _d.libro(libroId);
    if (libro == null || libro.tipo != TipoLibro.compartido) {
      throw const ErrorFinanzas('No existe ese libro compartido.');
    }
    if (personaId == null || !libro.esAdministrador(personaId!)) {
      throw const ErrorFinanzas('No tienes permiso para hacer eso en este libro.');
    }
    return libro;
  }

  void _cambiarLibro(String libroId, Libro Function(Libro) cambio) => _publicar(
    _d.copiar(
      libros: [for (final l in _d.libros) l.id == libroId ? cambio(l) : l],
    ),
  );

  @override
  Future<void> crearLibroCompartido({
    required String id,
    required String nombre,
    required List<String> otrosMiembros,
    VisibilidadLibro visibilidad = VisibilidadLibro.privada,
  }) async {
    _requiereConexion();
    if (_d.libro(id) != null) return;
    final yo = personaId;
    final hoy = Fecha.deDateTime(_reloj());
    final libro = Libro(
      id: id,
      nombre: nombre,
      tipo: TipoLibro.compartido,
      creadoPor: yo,
      visibilidad: visibilidad,
      miembros: [
        for (final p in {?yo, ...otrosMiembros})
          MiembroLibro(personaId: p, papel: PapelLibro.miembro, desde: hoy),
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
  Future<void> cambiarVisibilidadLibro(
    String libroId,
    VisibilidadLibro visibilidad,
  ) async {
    _requiereConexion();
    _delAdministrador(libroId);
    _cambiarLibro(libroId, (l) => l.copiar(visibilidad: visibilidad));
  }

  @override
  Future<void> archivarLibro(String libroId, {required bool archivado}) async {
    _requiereConexion();
    _delAdministrador(libroId);
    _cambiarLibro(libroId, (l) => l.copiar(activo: !archivado));
  }

  @override
  Future<void> agregarMiembro(String libroId, String persona) async {
    _requiereConexion();
    final libro = _delAdministrador(libroId);
    final hoy = Fecha.deDateTime(_reloj());
    if (libro.papelDe(persona, hoy) != null) return;
    _cambiarLibro(
      libroId,
      (l) => l.copiar(
        miembros: [
          ...l.miembros,
          MiembroLibro(personaId: persona, papel: PapelLibro.miembro, desde: hoy),
        ],
      ),
    );
  }

  @override
  Future<void> quitarMiembro(String libroId, String persona) async {
    _requiereConexion();
    final libro = _delAdministrador(libroId);
    final hoy = Fecha.deDateTime(_reloj());
    if (libro.papelDe(persona, hoy) == null) return;
    // Como el servidor: si quedan menos de 2, el libro pasa a privado y sigue
    // activo (2.ª ronda del 23/oct); el administrador no se saca a sí mismo.
    if (persona == personaId) {
      throw const ErrorFinanzas('Para dejar el libro usa "Salir del libro".');
    }
    _cambiarLibro(libroId, (l) => l.alSalirse(persona, hoy));
  }

  @override
  Future<void> salirDelLibro(String libroId) async {
    _requiereConexion();
    final yo = personaId;
    final libro = _d.libro(libroId);
    final hoy = Fecha.deDateTime(_reloj());
    if (yo == null || libro == null || libro.papelDe(yo, hoy) == null) {
      throw const ErrorFinanzas('No eres miembro de ese libro.');
    }
    if (!libro.puedeSalir(yo, hoy)) {
      throw const ErrorFinanzas(
        'Eres el último miembro: no puedes salirte. Para dejar de usar el '
        'libro, archívalo.',
      );
    }
    _cambiarLibro(libroId, (l) => l.alSalirse(yo, hoy));
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
  Future<bool> registrarConsultaMaestra(String libroId) async {
    final yo = personaId;
    final libro = _d.libro(libroId);
    if (yo != null &&
        libro != null &&
        libro.papelDe(yo, Fecha.deDateTime(_reloj())) != null) {
      return false; // lo propio no se registra
    }
    consultasMaestra.add(libroId);
    _consultas[libroId] = _reloj();
    return true;
  }

  Future<void> cerrar() => _cambios.close();
}
