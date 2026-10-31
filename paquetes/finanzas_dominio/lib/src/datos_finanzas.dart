import 'ahorro_datos.dart';
import 'calendario.dart';
import 'categorias.dart';
import 'configuracion.dart';
import 'libro.dart';
import 'libros.dart';
import 'plan_guardado.dart';
import 'semana.dart';

/// Todo lo de Finanzas que una persona puede ver en su hogar (lo que entrega
/// el servidor según sus permisos, más lo que está en la cola sin conexión).
/// Es inmutable: cada cambio crea otra copia con [copiar].
class DatosFinanzas {
  final List<Libro> libros;
  final List<ParametrosFinanzas> parametros;
  final List<Cuenta> cuentas;
  final List<Categoria> categorias;
  final List<Ingreso> ingresos;
  final List<Compromiso> compromisos;
  final List<Sobre> sobres;
  final List<Deuda> deudas;
  final List<DiaInhabil> diasInhabiles;
  final List<SemanaGuardada> semanas;
  final List<CierreGuardado> cierres;
  final List<Ocurrencia> ocurrencias;
  final List<ConciliacionGuardada> conciliaciones;
  final List<ImportacionGuardada> importaciones;
  final List<Movimiento> movimientos;
  final List<Msi> msi;
  final List<EstadoDeCuenta> estadosDeCuenta;
  final List<BolsaAhorro> bolsas;
  final List<AportacionAhorro> aportaciones;
  final List<RetiroAhorro> retiros;

  DatosFinanzas({
    List<Libro> libros = const [],
    List<ParametrosFinanzas> parametros = const [],
    List<Cuenta> cuentas = const [],
    List<Categoria> categorias = const [],
    List<Ingreso> ingresos = const [],
    List<Compromiso> compromisos = const [],
    List<Sobre> sobres = const [],
    List<Deuda> deudas = const [],
    List<DiaInhabil> diasInhabiles = const [],
    List<SemanaGuardada> semanas = const [],
    List<CierreGuardado> cierres = const [],
    List<Ocurrencia> ocurrencias = const [],
    List<ConciliacionGuardada> conciliaciones = const [],
    List<ImportacionGuardada> importaciones = const [],
    List<Movimiento> movimientos = const [],
    List<Msi> msi = const [],
    List<EstadoDeCuenta> estadosDeCuenta = const [],
    List<BolsaAhorro> bolsas = const [],
    List<AportacionAhorro> aportaciones = const [],
    List<RetiroAhorro> retiros = const [],
  }) : msi = List.unmodifiable(msi),
       estadosDeCuenta = List.unmodifiable(estadosDeCuenta),
       bolsas = List.unmodifiable(bolsas),
       aportaciones = List.unmodifiable(aportaciones),
       retiros = List.unmodifiable(retiros),
       libros = List.unmodifiable(libros),
       parametros = List.unmodifiable(parametros),
       cuentas = List.unmodifiable(cuentas),
       categorias = List.unmodifiable(categorias),
       ingresos = List.unmodifiable(ingresos),
       compromisos = List.unmodifiable(compromisos),
       sobres = List.unmodifiable(sobres),
       deudas = List.unmodifiable(deudas),
       diasInhabiles = List.unmodifiable(diasInhabiles),
       semanas = List.unmodifiable(semanas),
       cierres = List.unmodifiable(cierres),
       ocurrencias = List.unmodifiable(ocurrencias),
       conciliaciones = List.unmodifiable(conciliaciones),
       importaciones = List.unmodifiable(importaciones),
       movimientos = List.unmodifiable(movimientos);

  static final DatosFinanzas vacio = DatosFinanzas();

  DatosFinanzas copiar({
    List<Libro>? libros,
    List<ParametrosFinanzas>? parametros,
    List<Cuenta>? cuentas,
    List<Categoria>? categorias,
    List<Ingreso>? ingresos,
    List<Compromiso>? compromisos,
    List<Sobre>? sobres,
    List<Deuda>? deudas,
    List<DiaInhabil>? diasInhabiles,
    List<SemanaGuardada>? semanas,
    List<CierreGuardado>? cierres,
    List<Ocurrencia>? ocurrencias,
    List<ConciliacionGuardada>? conciliaciones,
    List<ImportacionGuardada>? importaciones,
    List<Movimiento>? movimientos,
    List<Msi>? msi,
    List<EstadoDeCuenta>? estadosDeCuenta,
    List<BolsaAhorro>? bolsas,
    List<AportacionAhorro>? aportaciones,
    List<RetiroAhorro>? retiros,
  }) => DatosFinanzas(
    msi: msi ?? this.msi,
    estadosDeCuenta: estadosDeCuenta ?? this.estadosDeCuenta,
    bolsas: bolsas ?? this.bolsas,
    aportaciones: aportaciones ?? this.aportaciones,
    retiros: retiros ?? this.retiros,
    libros: libros ?? this.libros,
    parametros: parametros ?? this.parametros,
    cuentas: cuentas ?? this.cuentas,
    categorias: categorias ?? this.categorias,
    ingresos: ingresos ?? this.ingresos,
    compromisos: compromisos ?? this.compromisos,
    sobres: sobres ?? this.sobres,
    deudas: deudas ?? this.deudas,
    diasInhabiles: diasInhabiles ?? this.diasInhabiles,
    semanas: semanas ?? this.semanas,
    cierres: cierres ?? this.cierres,
    ocurrencias: ocurrencias ?? this.ocurrencias,
    conciliaciones: conciliaciones ?? this.conciliaciones,
    importaciones: importaciones ?? this.importaciones,
    movimientos: movimientos ?? this.movimientos,
  );

  // ----------------------------------------------------------------- libros

  Libro? libro(String id) {
    for (final l in libros) {
      if (l.id == id) return l;
    }
    return null;
  }

  Map<String, String> get nombresDeLibros => {
    for (final l in libros) l.id: l.nombre,
  };

  /// Parámetros del libro (los de por omisión si no hay fila).
  ParametrosFinanzas parametrosDe(String libroId) {
    for (final p in parametros) {
      if (p.libroId == libroId) return p;
    }
    return ParametrosFinanzas(libroId: libroId);
  }

  // ---------------------------------------------------------------- cuentas

  Cuenta? cuenta(String id) {
    for (final c in cuentas) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Cuentas propias del libro (sin las del hogar).
  List<Cuenta> cuentasDe(String libroId) =>
      cuentas.where((c) => c.libroId == libroId).toList();

  /// Cuentas de gasto por rubro del hogar.
  List<Cuenta> get cuentasDeGasto =>
      cuentas.where((c) => c.tipo == TipoCuenta.deGasto).toList();

  late final ArbolCategorias arbol = ArbolCategorias(categorias);

  /// Días inhábiles activos del hogar.
  late final CalendarioDiasInhabiles calendario = CalendarioFijo.deDias(
    diasInhabiles,
  );

  /// Libro de todo lo visible del hogar. Las cuentas que no se ven (de libros
  /// ajenos) entran como cuentas virtuales de otro libro.
  late final LibroMovimientos libroHogar = nuevoLibroHogar();

  /// Una copia nueva del libro del hogar, para validar un movimiento antes de
  /// guardarlo (agregar la modifica).
  LibroMovimientos nuevoLibroHogar() {
    final conocidas = {for (final c in cuentas) c.id};
    final desconocidas = <String>{};
    for (final m in movimientos) {
      for (final id in [m.cuentaOrigenId, m.cuentaDestinoId]) {
        if (!conocidas.contains(id)) desconocidas.add(id);
      }
    }
    return LibroMovimientos.restaurar(
      cuentas: [
        ...cuentas,
        for (final id in desconocidas)
          Cuenta(id: id, nombre: 'Otro libro', tipo: TipoCuenta.otroLibro),
      ],
      movimientos: movimientos,
      validar: false,
    );
  }

  final Map<String, LibroMovimientos> _vistas = {};

  /// Vista del libro [libroId] (sus cuentas, las de gasto del hogar y las de
  /// otros libros como virtuales).
  LibroMovimientos vista(String libroId) => _vistas.putIfAbsent(
    libroId,
    () => vistaDelLibro(
      libroId: libroId,
      cuentas: cuentas,
      movimientos: movimientos,
      nombresDeLibros: nombresDeLibros,
    ),
  );

  // ---------------------------------------------------------- configuración

  List<Ingreso> ingresosDe(String libroId) =>
      ingresos.where((i) => i.libroId == libroId).toList();

  List<Compromiso> compromisosDe(String libroId) =>
      compromisos.where((c) => c.libroId == libroId).toList();

  List<Sobre> sobresDe(String libroId) =>
      sobres.where((s) => s.libroId == libroId).toList();

  List<BolsaAhorro> bolsasDe(String libroId) =>
      bolsas.where((b) => b.libroId == libroId && b.activa).toList();

  List<Msi> msiDe(String libroId) =>
      msi.where((m) => m.libroId == libroId && m.activo).toList();

  /// Último estado de cuenta de una deuda (el corte más reciente; a igual
  /// corte, el registrado después).
  EstadoDeCuenta? ultimoEstadoDeCuenta(String deudaId) {
    EstadoDeCuenta? mejor;
    for (final e in estadosDeCuenta) {
      if (e.deudaId != deudaId) continue;
      if (mejor == null ||
          e.fechaCorte.compareTo(mejor.fechaCorte) > 0 ||
          (e.fechaCorte == mejor.fechaCorte &&
              e.registradoEn.isAfter(mejor.registradoEn))) {
        mejor = e;
      }
    }
    return mejor;
  }

  List<Deuda> deudasDe(String libroId) =>
      deudas.where((d) => d.libroId == libroId).toList();

  /// `true` si el libro ya tiene algo para armar un presupuesto.
  bool configurado(String libroId) =>
      ingresos.any((i) => i.libroId == libroId) ||
      sobres.any((s) => s.libroId == libroId) ||
      compromisos.any((c) => c.libroId == libroId);

  // ------------------------------------------------------------------ plan

  SemanaGuardada? semanaGuardada(String libroId, Semana semana) {
    for (final s in semanas) {
      if (s.libroId == libroId && s.semana == semana) return s;
    }
    return null;
  }

  /// Cierres de una semana guardada, de la versión 1 en adelante.
  List<CierreGuardado> cierresDe(String semanaId) =>
      cierres.where((c) => c.semanaId == semanaId).toList()
        ..sort((a, b) => a.version.compareTo(b.version));

  CierreGuardado? ultimoCierre(String semanaId) {
    final lista = cierresDe(semanaId);
    return lista.isEmpty ? null : lista.last;
  }
}
