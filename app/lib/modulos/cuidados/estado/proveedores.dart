/// Estado de Cuidados con Riverpod: el repositorio según la sesión, los
/// permisos y el servicio.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart' show Fecha, TipoLibro;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../app/sesion_efectiva.dart';
import '../../../diseno/proveedores.dart' show relojProvider;
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/sesion/proveedores_sesion.dart';
import '../../../nucleo/sesion/servicio_sesion_supabase.dart';
import '../../finanzas/casos_uso/gasto_cuidado.dart' as fin;
import '../../finanzas/datos/fuente_tablas.dart';
import '../../finanzas/datos/repositorio.dart' show RepositorioFinanzas;
import '../../finanzas/estado/proveedores.dart'
    show repositorioFinanzasProvider;
import '../casos_uso/horario_turnos.dart';
import '../casos_uso/permisos_cuidados.dart';
import '../casos_uso/servicio_cuidados.dart';
import '../datos/modelos.dart';
import '../datos/repositorio.dart';
import '../datos/repositorio_supabase.dart';

/// Supabase con la sesión real; demostración en memoria con datos inventados
/// (como la ve el rol de quien entró); sin sesión, vacío.
final repositorioCuidadosProvider = Provider<RepositorioCuidados>((ref) {
  final sesion = ref.watch(sesionEfectivaProvider);
  if (sesion == null) return RepositorioCuidadosEnMemoria();
  final servicio = ref.watch(servicioSesionProvider);
  final hogarId = sesion.hogarId;
  if (servicio is ServicioSesionSupabase && hogarId != null) {
    return RepositorioCuidadosSupabase(
      fuente: FuenteTablasSupabase(() => servicio.clienteActivo),
      hogarId: hogarId,
      personaId: sesion.persona.id,
      nombre: sesion.persona.nombre,
    );
  }
  final ahora = ref.read(relojProvider).ahora();
  final personas = PersonasDemoSesion.de(sesion.persona.id, sesion.rol);
  return RepositorioCuidadosEnMemoria(
    datos: datosDeEjemploCuidados(ahora, personas: personas),
    personaId: sesion.persona.id,
    rol: sesion.rol,
    perfilActual: const PerfilCuidados(),
  );
});

/// En la demostración, quien entró ocupa el lugar que le toca en el horario.
class PersonasDemoSesion {
  static PersonasTurno de(String id, Rol rol) => PersonasTurno(
    cuidadoraId: rol == Rol.cuidador ? id : personasDemo.cuidadoraId,
    cuidadoraNombre: personasDemo.cuidadoraNombre,
    hermanaId: personasDemo.hermanaId,
    hermanaNombre: personasDemo.hermanaNombre,
    duenoId: rol == Rol.dueno ? id : personasDemo.duenoId,
    duenoNombre: personasDemo.duenoNombre,
  );
}

final perfilCuidadosProvider = FutureProvider<PerfilCuidados>(
  (ref) => ref.watch(repositorioCuidadosProvider).perfil(),
);

final permisosCuidadosProvider = Provider<PermisosCuidados>((ref) {
  final s = ref.watch(sesionEfectivaProvider);
  final perfil =
      ref.watch(perfilCuidadosProvider).value ?? const PerfilCuidados();
  return PermisosCuidados(
    rol: s?.rol ?? Rol.casa,
    perfil: perfil,
    esMaestra: s?.esMaestra ?? false,
  );
});

final servicioCuidadosProvider = Provider<ServicioCuidados>((ref) {
  final s = ref.watch(sesionEfectivaProvider);
  final reloj = ref.watch(relojProvider);
  return ServicioCuidados(
    ref.watch(repositorioCuidadosProvider),
    permisos: ref.watch(permisosCuidadosProvider),
    personaId: s?.persona.id ?? '',
    nombre: s?.persona.nombre ?? '',
    ahora: reloj.ahora,
    alConfirmarGasto: s == null
        ? null
        : (g, {libroCompartidoId}) => pasarGastoAFinanzas(
            ref.read(repositorioFinanzasProvider),
            g,
            confirmadoPor: s.persona.id,
            libroCompartidoId: libroCompartidoId,
          ),
  );
});

/// Pasa a Finanzas un gasto de cuidado ya confirmado en el servidor. El libro
/// de Papá se busca por su libro representado; Finanzas no duplica si se
/// repite (id estable).
Future<void> pasarGastoAFinanzas(
  RepositorioFinanzas repo,
  GastoCuidado g, {
  required String confirmadoPor,
  String? libroCompartidoId,
}) async {
  final datos = (repo.actual ?? await repo.cargar()).datos;
  final papa = datos.libros
      .where((l) => l.tipo == TipoLibro.representado && !l.archivado)
      .map((l) => l.titularId)
      .firstOrNull;
  await fin.confirmarGastoCuidado(
    fin.GastoCuidado(
      id: g.id,
      fecha: Fecha.deDateTime(g.fecha),
      centavos: g.centavos,
      registradoPor: g.registradoPor,
      concepto: g.concepto,
      esDePapa: g.ambito == AmbitoGasto.cuidado,
      personaBajoCuidadoId: papa,
      estado: fin.EstadoGastoCuidado.confirmado,
    ),
    repo,
    confirmadoPor: confirmadoPor,
    libroCompartidoId: g.ambito == AmbitoGasto.casa ? libroCompartidoId : null,
  );
}

/// Un libro compartido donde puede ir un gasto de la casa.
class LibroParaGasto {
  const LibroParaGasto(this.id, this.nombre);
  final String id;
  final String nombre;
}

/// Libros compartidos vigentes de [personaId] según Finanzas (no archivados y
/// con su membresía vigente en [hoy]). Lo único que se ofrece al confirmar un
/// gasto de la casa.
Future<List<LibroParaGasto>> librosCompartidosVigentes(
  RepositorioFinanzas repo,
  String personaId,
  DateTime hoy,
) async {
  final datos = (repo.actual ?? await repo.cargar()).datos;
  final dia = Fecha.deDateTime(hoy);
  return [
    for (final l in datos.libros)
      if (l.tipo == TipoLibro.compartido &&
          !l.archivado &&
          l.miembros.any((m) => m.personaId == personaId && m.vigenteEn(dia)))
        LibroParaGasto(l.id, l.nombre),
  ];
}

final librosCompartidosProvider = FutureProvider<List<LibroParaGasto>>((
  ref,
) async {
  final s = ref.watch(sesionEfectivaProvider);
  if (s == null) return const [];
  return librosCompartidosVigentes(
    ref.watch(repositorioFinanzasProvider),
    s.persona.id,
    ref.read(relojProvider).ahora(),
  );
});

/// Contador para volver a pedir los datos tras cada cambio.
final versionCuidadosProvider = StateProvider<int>((_) => 0);

void refrescarCuidados(WidgetRef ref) =>
    ref.read(versionCuidadosProvider.notifier).state++;

FutureProvider<T> _datos<T>(Future<T> Function(ServicioCuidados s) f) =>
    FutureProvider<T>((ref) {
      ref.watch(versionCuidadosProvider);
      return f(ref.watch(servicioCuidadosProvider));
    });

final miTurnoHoyProvider = _datos((s) => s.miTurnoHoy());
final deTurnoProvider = _datos((s) => s.deTurno());
final turnosSemanaProvider = _datos((s) => s.turnosDeLaSemana());
final ultimaEntregaProvider = _datos((s) => s.ultimaEntrega());
final cambiosUrgentesProvider = _datos((s) => s.cambiosUrgentes());
final medicamentosProvider = _datos((s) => s.medicamentos());
final dosisHoyProvider = _datos((s) => s.dosisDelDia());
final siguienteDosisProvider = _datos((s) => s.siguienteDosis());
final comidasHoyProvider = _datos((s) => s.comidasDeHoy());
final horariosComidaProvider = _datos((s) => s.horariosComida());
final bitacoraProvider = _datos((s) => s.bitacora());
final instruccionesRecibidasProvider = _datos(
  (s) => s.instruccionesRecibidas(),
);
final consentimientosProvider = _datos((s) => s.estadoConsentimientos());

/// Conteos del día de Papá; `null` si esta persona no tiene la pantalla.
final resumenDiaProvider = FutureProvider<ResumenPapa?>((ref) {
  ref.watch(versionCuidadosProvider);
  if (!ref.watch(permisosCuidadosProvider).veResumenDelDia) {
    return Future.value();
  }
  return ref.watch(servicioCuidadosProvider).resumenDelDia();
});
final citasProvider = _datos((s) => s.citas());
final gastosProvider = _datos((s) => s.gastos());

/// Mes que se está viendo en el resumen.
final mesResumenProvider = StateProvider<DateTime>((ref) {
  final h = ref.read(relojProvider).ahora();
  return DateTime(h.year, h.month);
});

final resumenMensualProvider = FutureProvider<ResumenMensual?>((ref) {
  ref.watch(versionCuidadosProvider);
  return ref
      .watch(servicioCuidadosProvider)
      .resumen(ref.watch(mesResumenProvider));
});

/// Ahora, según el reloj de la app (el simulado en las pruebas).
final relojDeCuidados = Provider<DateTime>(
  (ref) => ref.watch(relojProvider).ahora(),
);
