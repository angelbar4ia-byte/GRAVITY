/// Repositorio de Cuidados: interfaz y versión en memoria (pruebas y
/// demostración). La versión con Supabase está en `repositorio_supabase.dart`.
///
/// La versión en memoria **filtra como lo haría el servidor** para quien la
/// usa (RLS): la cuidadora y la hermana solo ven su bitácora y sus gastos; el
/// resumen de la hermana solo existe con autorización y sin lo de la pareja ni
/// del dueño. Aun así, la interfaz vuelve a revisar (defensa doble).
library;

import '../../../nucleo/contratos/roles.dart';
import '../casos_uso/horario_turnos.dart';
import 'modelos.dart';

abstract interface class RepositorioCuidados {
  Future<PerfilCuidados> perfil();

  Future<List<Turno>> turnos(DateTime desde, DateTime hasta);
  Future<void> guardarTurno(Turno t);

  Future<List<Medicamento>> medicamentos();
  Future<void> guardarMedicamento(Medicamento m);

  Future<List<Toma>> tomas(DateTime dia);
  Future<void> registrarToma(Toma t);

  Future<List<ComidaRegistro>> comidas(DateTime dia);
  Future<void> registrarComida(ComidaRegistro c);

  Future<List<EntradaBitacora>> bitacora();
  Future<void> agregarBitacora(EntradaBitacora e);

  Future<List<Entrega>> entregas();
  Future<void> dejarEntrega(Entrega e);

  Future<List<CambioUrgente>> cambiosUrgentes();
  Future<void> crearCambioUrgente(CambioUrgente c);
  Future<void> atenderCambioUrgente(
    String id, {
    required String personaId,
    required String nombre,
    required DateTime en,
  });

  Future<List<GastoCuidado>> gastos();
  Future<void> registrarGasto(GastoCuidado g);
  Future<void> resolverGasto(String id, EstadoGasto estado);

  /// `null` si no hay resumen (sin autorización o sin permiso).
  Future<ResumenMensual?> resumenMensual(DateTime mes);
}

/// Lo guardado "en el servidor" de la demostración; varios repositorios (uno
/// por persona) lo comparten.
class DatosCuidadosMemoria {
  final List<Turno> turnos = [];
  final List<Medicamento> medicamentos = [];
  final Map<String, Toma> tomas = {};
  final Map<String, ComidaRegistro> comidas = {};
  final List<EntradaBitacora> bitacora = [];
  final List<Entrega> entregas = [];
  final List<CambioUrgente> cambios = [];
  final List<GastoCuidado> gastos = [];
  final Map<String, List<LineaResumen>> resumenes = {};
}

class RepositorioCuidadosEnMemoria implements RepositorioCuidados {
  RepositorioCuidadosEnMemoria({
    DatosCuidadosMemoria? datos,
    this.personaId = 'persona-dueno',
    this.rol = Rol.dueno,
    this.perfilActual = const PerfilCuidados(),
  }) : datos = datos ?? DatosCuidadosMemoria();

  final DatosCuidadosMemoria datos;
  final String personaId;
  final Rol rol;
  final PerfilCuidados perfilActual;

  bool get _dueno => rol == Rol.dueno;
  bool get _cuidador => rol == Rol.cuidador;
  bool get _pareja => rol == Rol.coadministrador;
  bool get _entra => _dueno || _cuidador || (_pareja && perfilActual.consentimiento);

  void _exigir(bool ok) {
    if (!ok) throw ErrorCuidados.sinPermiso;
  }

  @override
  Future<PerfilCuidados> perfil() async => perfilActual;

  @override
  Future<List<Turno>> turnos(DateTime desde, DateTime hasta) async {
    if (!_entra) return const [];
    return [
      for (final t in datos.turnos)
        if (t.inicio.isBefore(hasta) && t.fin.isAfter(desde))
          if (!_cuidador || t.tipo == TipoTurno.turno || t.personaId == personaId)
            t,
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  @override
  Future<void> guardarTurno(Turno t) async {
    _exigir(_dueno);
    datos.turnos
      ..removeWhere((x) => x.id == t.id)
      ..add(t);
  }

  @override
  Future<List<Medicamento>> medicamentos() async =>
      _entra ? [...datos.medicamentos] : const [];

  @override
  Future<void> guardarMedicamento(Medicamento m) async {
    _exigir(_dueno);
    final i = datos.medicamentos.indexWhere((x) => x.id == m.id);
    i < 0 ? datos.medicamentos.add(m) : datos.medicamentos[i] = m;
  }

  @override
  Future<List<Toma>> tomas(DateTime dia) async {
    if (!_entra) return const [];
    final d = soloFecha(dia);
    return [
      for (final t in datos.tomas.values)
        if (soloFecha(t.programada) == d) t,
    ];
  }

  @override
  Future<void> registrarToma(Toma t) async {
    _exigir(_dueno || (_cuidador && !perfilActual.esFamiliar));
    datos.tomas[t.id] = t;
  }

  @override
  Future<List<ComidaRegistro>> comidas(DateTime dia) async {
    if (!_entra) return const [];
    final d = soloFecha(dia);
    return [
      for (final c in datos.comidas.values)
        if (soloFecha(c.fecha) == d) c,
    ];
  }

  @override
  Future<void> registrarComida(ComidaRegistro c) async {
    _exigir(_dueno || (_cuidador && !perfilActual.esFamiliar));
    datos.comidas[c.id] = c;
  }

  @override
  Future<List<EntradaBitacora>> bitacora() async {
    if (!(_dueno || _cuidador)) return const [];
    return [
      for (final e in datos.bitacora)
        if (_dueno || e.autorId == personaId) e,
    ]..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  @override
  Future<void> agregarBitacora(EntradaBitacora e) async {
    _exigir(_dueno || _cuidador);
    datos.bitacora.add(e);
  }

  @override
  Future<List<Entrega>> entregas() async => !(_dueno || _cuidador)
      ? const []
      : ([...datos.entregas]..sort((a, b) => b.creadaEn.compareTo(a.creadaEn)));

  @override
  Future<void> dejarEntrega(Entrega e) async {
    _exigir(_dueno || _cuidador);
    datos.entregas.add(e);
  }

  @override
  Future<List<CambioUrgente>> cambiosUrgentes() async {
    if (!(_dueno || (_cuidador && !perfilActual.esFamiliar))) return const [];
    return [...datos.cambios]..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
  }

  @override
  Future<void> crearCambioUrgente(CambioUrgente c) async {
    _exigir(_dueno);
    datos.cambios.add(c);
  }

  @override
  Future<void> atenderCambioUrgente(
    String id, {
    required String personaId,
    required String nombre,
    required DateTime en,
  }) async {
    _exigir(_dueno || (_cuidador && !perfilActual.esFamiliar));
    final i = datos.cambios.indexWhere((c) => c.id == id);
    if (i >= 0 && !datos.cambios[i].atendido) {
      datos.cambios[i] = datos.cambios[i].atender(personaId, nombre, en);
    }
  }

  @override
  Future<List<GastoCuidado>> gastos() async {
    if (!(_dueno || _cuidador || _pareja)) return const [];
    return [
      for (final g in datos.gastos)
        if (_dueno || g.registradoPor == personaId) g,
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Future<void> registrarGasto(GastoCuidado g) async {
    _exigir(_dueno || _cuidador || _pareja);
    // Siempre entra pendiente de confirmación del dueño, a nombre de quien lo
    // registra.
    _exigir(g.registradoPor == personaId);
    datos.gastos.add(g.conEstado(EstadoGasto.pendiente));
  }

  @override
  Future<void> resolverGasto(String id, EstadoGasto estado) async {
    _exigir(_dueno);
    final i = datos.gastos.indexWhere((g) => g.id == id);
    if (i >= 0) datos.gastos[i] = datos.gastos[i].conEstado(estado);
  }

  @override
  Future<ResumenMensual?> resumenMensual(DateTime mes) async {
    final lineas = datos.resumenes[fechaClave(DateTime(mes.year, mes.month))];
    if (_dueno) {
      return ResumenMensual(
        mes: DateTime(mes.year, mes.month),
        lineas: [...?lineas],
      );
    }
    if (_cuidador && perfilActual.esFamiliar && perfilActual.resumenAutorizado) {
      return ResumenMensual(
        mes: DateTime(mes.year, mes.month),
        lineas: [...?lineas],
      ).paraFamiliar();
    }
    return null;
  }
}

/// Datos inventados para la demostración. Nada real (el repositorio es
/// público): nombres y cifras de ejemplo.
DatosCuidadosMemoria datosDeEjemploCuidados(
  DateTime ahora, {
  PersonasTurno personas = personasDemo,
}) {
  final d = DatosCuidadosMemoria();
  d.turnos.addAll(turnosDeLaSemana(lunesDe(ahora), personas));
  d.medicamentos.addAll(const [
    Medicamento(
      id: 'med-1',
      nombre: 'Medicamento A',
      dosis: '1 tableta',
      horas: ['08:00', '20:00'],
    ),
    Medicamento(
      id: 'med-2',
      nombre: 'Medicamento B',
      dosis: '1/2 tableta',
      horas: ['14:00'],
    ),
  ]);
  final mes = fechaClave(DateTime(ahora.year, ahora.month));
  d.resumenes[mes] = const [
    LineaResumen(concepto: 'Pago de la cuidadora', centavos: 1200000, titular: Titular.papa),
    LineaResumen(concepto: 'Pañales y aseo', centavos: 180000, titular: Titular.papa),
    LineaResumen(concepto: 'Servicios de la casa', centavos: 350000, titular: Titular.casa),
    LineaResumen(concepto: 'Gasto de la pareja', centavos: 90000, titular: Titular.pareja),
    LineaResumen(concepto: 'Gasto del dueño', centavos: 75000, titular: Titular.dueno),
  ];
  return d;
}

const personasDemo = PersonasTurno(
  cuidadoraId: 'persona-cuidadora',
  cuidadoraNombre: 'Cuidadora',
  hermanaId: 'persona-hermana',
  hermanaNombre: 'Hermana',
  duenoId: 'persona-dueno',
  duenoNombre: 'Dueño',
);
