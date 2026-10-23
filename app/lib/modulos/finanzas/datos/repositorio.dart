/// Repositorio de Finanzas: dónde se guarda y se lee todo lo del módulo.
///
/// - En producción, Supabase con el cliente de la persona activa
///   ([RepositorioFinanzasSupabase]); el libro de movimientos (solo agregar)
///   pasa por la cola sin conexión, idempotente por UUID.
/// - En pruebas y en el modo demostración, en memoria
///   ([RepositorioFinanzasEnMemoria]).
///
/// Los cálculos los hace `finanzas_dominio` con lo cargado (la copia del
/// dispositivo); el servidor guarda y valida (RLS y triggers).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

/// Lo que el servidor dice que la persona puede hacer en un libro
/// (`fin_puede`). Solo se pide donde el espejo del cliente no alcanza: el
/// **suplente** del libro de papá, que escribe cuando el albacea deja de ser un
/// adulto con Finanzas del hogar (baja o cambio de rol), algo que quien no es
/// el dueño no puede ver en las membresías (I4 de la revisión de la Fase 1).
class PermisoServidor {
  const PermisoServidor({required this.escribir, required this.administrar});

  final bool escribir;
  final bool administrar;

  Map<String, Object?> aJson() => {'escribir': escribir, 'administrar': administrar};

  static PermisoServidor deJson(Map<Object?, Object?> j) => PermisoServidor(
    escribir: j['escribir'] == true,
    administrar: j['administrar'] == true,
  );
}

/// Lo que se cargó del servidor, con el contexto de quién lo ve.
class CargaFinanzas {
  const CargaFinanzas({
    required this.datos,
    this.esMaestra = false,
    this.cuentaMaestra,
    this.personas = const {},
    this.adultosConFinanzas = const {},
    this.desdeCopia = false,
    this.movimientosEnCola = const {},
    this.permisosServidor = const {},
  });

  final DatosFinanzas datos;

  /// La persona es la cuenta maestra del hogar (D19): lee todo, no escribe
  /// en lo ajeno.
  final bool esMaestra;

  /// Nombre de quien tiene la cuenta maestra del hogar, si existe (D19:
  /// cada persona ve en Ajustes que existe).
  final String? cuentaMaestra;

  /// Nombre visible de cada persona que se puede ver (id → nombre).
  final Map<String, String> personas;

  /// Personas del hogar con un rol con Finanzas (dueño y coadministrador)
  /// que la sesión puede ver: las que pueden ser miembros de un libro
  /// compartido o suplentes del libro de papá. El dueño las ve todas; los
  /// demás, solo a sí mismos.
  final Set<String> adultosConFinanzas;

  /// `true` si no hubo conexión y se muestra lo último que se cargó.
  final bool desdeCopia;

  /// Movimientos registrados en este dispositivo que aún no suben.
  final Set<String> movimientosEnCola;

  /// Permiso que dio el servidor en los libros donde el espejo no alcanza
  /// (libro id → permiso). Vacío si no hace falta preguntar.
  final Map<String, PermisoServidor> permisosServidor;

  CargaFinanzas copiar({
    DatosFinanzas? datos,
    bool? esMaestra,
    Map<String, String>? personas,
    bool? desdeCopia,
    Set<String>? movimientosEnCola,
    Map<String, PermisoServidor>? permisosServidor,
  }) => CargaFinanzas(
    datos: datos ?? this.datos,
    esMaestra: esMaestra ?? this.esMaestra,
    cuentaMaestra: cuentaMaestra,
    personas: personas ?? this.personas,
    adultosConFinanzas: adultosConFinanzas,
    desdeCopia: desdeCopia ?? this.desdeCopia,
    movimientosEnCola: movimientosEnCola ?? this.movimientosEnCola,
    permisosServidor: permisosServidor ?? this.permisosServidor,
  );

  /// `true` si la persona es la cuenta maestra y el servidor no devolvió nada
  /// del libro ajeno [libroId]: un libro siempre tiene al menos sus cuentas
  /// técnicas (Ajustes, Apertura y Por clasificar), así que "vacío" quiere
  /// decir que la consulta registrada **venció** y la lectura quedó filtrada
  /// (I2 de la revisión de la Fase 1: el servidor no da error, filtra).
  bool libroSinContenido(String libroId) =>
      !datos.cuentas.any((c) => c.libroId == libroId) &&
      !datos.parametros.any((p) => p.libroId == libroId);

  String nombreDe(String? personaId) =>
      personaId == null ? '' : (personas[personaId] ?? 'Otra persona');
}

/// Cómo quedó un registro del libro.
enum ResultadoEscritura {
  /// Ya está en el servidor (o en la memoria, en demostración).
  guardado,

  /// Se guardó en el teléfono y sube al volver la señal.
  enCola,
}

/// Error con un mensaje listo para la interfaz.
class ErrorFinanzas implements Exception {
  const ErrorFinanzas(this.mensaje, {this.sinConexion = false});

  final String mensaje;

  /// No hubo conexión con el servidor.
  final bool sinConexion;

  static const conexion = ErrorFinanzas(
    'Sin conexión: este cambio necesita señal. Inténtalo de nuevo cuando '
    'vuelva.',
    sinConexion: true,
  );

  @override
  String toString() => mensaje;
}

/// Todo lo que la app lee y escribe de Finanzas.
abstract interface class RepositorioFinanzas {
  /// Lo último cargado (o `null` si aún no se carga).
  CargaFinanzas? get actual;

  /// Avisa cada vez que cambia lo cargado (después de cargar o escribir).
  Stream<CargaFinanzas> get cambios;

  /// Carga todo lo que la persona puede ver. Sin conexión, devuelve lo último
  /// cargado (marcado [CargaFinanzas.desdeCopia]) o lanza [ErrorFinanzas].
  Future<CargaFinanzas> cargar();

  // --------------------------------------------- libro (solo agregar, cola)

  /// Agrega movimientos al libro. Nunca se editan ni se borran: se corrigen
  /// con anulación. Mismo id y mismo contenido no duplica.
  Future<ResultadoEscritura> agregarMovimientos(List<Movimiento> movimientos);

  /// Guarda una conciliación (con su ajuste ya agregado, si lo hubo).
  Future<ResultadoEscritura> agregarConciliacion(ConciliacionGuardada c);

  Future<void> agregarImportacion(ImportacionGuardada importacion);

  // ------------------------------------------ configuración (necesita señal)

  Future<void> guardarCuentas(List<Cuenta> cuentas);

  /// Borra una cuenta **sin movimientos** (con movimientos se cierra o se
  /// archiva).
  Future<void> eliminarCuenta(String id);

  Future<void> guardarCategorias(List<Categoria> categorias);

  /// Borra una categoría **sin datos** (con datos se archiva).
  Future<void> eliminarCategoria(String id);

  Future<void> guardarParametros(ParametrosFinanzas parametros);

  /// Guarda el ingreso con sus vigencias.
  Future<void> guardarIngreso(Ingreso ingreso);

  Future<void> guardarCompromiso(Compromiso compromiso);

  Future<void> guardarSobre(Sobre sobre);

  Future<void> guardarDeuda(Deuda deuda);

  Future<void> guardarDiasInhabiles(List<DiaInhabil> dias);

  /// Crea un libro compartido con sus miembros (quien lo crea es miembro y su
  /// **administrador**). [visibilidad]: privada por omisión; pública = los
  /// adultos con Finanzas del hogar la leen.
  Future<void> crearLibroCompartido({
    required String id,
    required String nombre,
    required List<String> otrosMiembros,
    VisibilidadLibro visibilidad = VisibilidadLibro.privada,
  });

  /// Cambia la visibilidad de un compartido (solo su administrador).
  Future<void> cambiarVisibilidadLibro(String libroId, VisibilidadLibro v);

  /// Archiva (`activo = false`, solo lectura para todos) o reactiva un
  /// compartido (solo su administrador).
  Future<void> archivarLibro(String libroId, {required bool archivado});

  /// Agrega a [personaId] como miembro de un compartido (solo su
  /// administrador).
  Future<void> agregarMiembro(String libroId, String personaId);

  /// Saca a [personaId] de un compartido: su fila deja de ser vigente ahora
  /// (solo su administrador). Si quedan menos de 2 miembros, el presupuesto
  /// pasa a **privado** y sigue activo (2.ª ronda del 23/oct/2026).
  Future<void> quitarMiembro(String libroId, String personaId);

  /// La persona de la sesión se sale del libro: cualquier miembro puede, en
  /// cualquier momento, menos el **último**. Si quedan menos de 2 miembros, el
  /// presupuesto pasa a **privado** y sigue activo (quien queda es el
  /// administrador); si era el administrador, el cargo pasa al miembro más
  /// antiguo. La hora de salida es la del teléfono.
  Future<void> salirDelLibro(String libroId);

  /// Crea el libro de una persona representada (papá): quien lo crea queda
  /// como albacea; [suplenteId], si se da, como suplente.
  Future<void> crearLibroRepresentado({
    required String id,
    required String nombreTitular,
    String? nombreLibro,
    String? suplenteId,
  });

  // --------------------------------------------------------- plan semanal

  /// Guarda la foto de la semana activada con sus partidas y abonos.
  Future<void> guardarSemana(SemanaGuardada semana);

  /// Cambia el estado de la semana (cerrar después de guardar el cierre, o
  /// reabrir con confirmación).
  Future<void> cambiarEstadoSemana(String semanaId, EstadoSemana estado);

  /// Guarda el cierre (solo agregar) y cierra la semana.
  Future<void> agregarCierre(CierreGuardado cierre, {required String libroId});

  Future<void> guardarOcurrencia(Ocurrencia ocurrencia);

  /// Deja en la bitácora que la cuenta maestra abrió un libro ajeno y **habilita
  /// su lectura 30 minutos** (`fin_registrar_consulta_maestra`, I2). Hay que
  /// llamarla **antes** de pedir los datos de ese libro. Devuelve `false` si el
  /// libro es de la propia persona (no se registra nada).
  Future<bool> registrarConsultaMaestra(String libroId);
}
