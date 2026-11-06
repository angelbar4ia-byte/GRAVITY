/// Cifras reales de Finanzas para "Hoy" y para "Mi semana" (Fase 4, E2;
/// `docs/specs/fase-4-finanzas-aporte.md`, 3.2).
///
/// Un resumen **por libro**, calculado con el dominio (`vistaSemana`, el mismo
/// cálculo de la pantalla Semana de la laptop) sobre los datos locales: nunca
/// sale del equipo ni va a la IA ni a las bocinas (D3). El filtro por rol y
/// por permiso se hace **al armar la lista**, no al pintar: solo entran los
/// libros que la persona lleva (titular, miembro o albacea vigente). No entran
/// los libros ajenos que lee la cuenta maestra (necesitan consulta registrada)
/// ni los públicos de otra persona (lector); un rol sin Finanzas (cuidadora,
/// Casa, familiar) no obtiene nada.
///
/// Los **montos** viajan como centavos pero se dibujan siempre con
/// [MontoOcultable]: con los montos ocultos no hay cifras ni en el texto ni en
/// el lector de pantalla.
///
/// Plataforma lo conecta a `datosResumenGravityProvider` leyendo
/// [resumenFinanzasHoyProvider] (ver el reporte de la Fase 4).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart' as dom;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/avisos/pantalla_bandeja_avisos.dart'
    show bandejaDeAvisosProvider;
import '../../../app/sesion_efectiva.dart';
import '../../../nucleo/avisos/catalogo_avisos.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/permisos/permisos.dart' as permisos;
import 'proveedores.dart';

/// Las cifras de la semana de un libro, con el mismo cálculo en todas las
/// pantallas (Hoy, Mi semana y Semana de la laptop dan lo mismo al centavo).
@immutable
class CifrasSemana {
  const CifrasSemana({
    required this.semana,
    required this.ingresoPlaneado,
    required this.ingresoReal,
    required this.presupuesto,
    required this.gastado,
    required this.deuda,
    required this.abonado,
    required this.remanentePlaneado,
    required this.remanenteReal,
    required this.semaforo,
    required this.sinDatos,
  });

  /// Las cifras de [v] (la vista de la semana que arma el dominio).
  factory CifrasSemana.de(dom.VistaSemana v) {
    final p = v.planSemanal;
    final r = v.real;
    final sinPlan = p.partidas.isEmpty && p.ingreso == 0 && p.abonos.isEmpty;
    return CifrasSemana(
      semana: v.semana,
      ingresoPlaneado: p.ingreso,
      ingresoReal: r.ingresoReal,
      presupuesto: p.presupuesto,
      gastado: r.gastoReal,
      deuda: p.deudaPlaneada,
      abonado: r.abonoReal,
      remanentePlaneado: p.remanente,
      remanenteReal: r.deficit > 0 ? -r.deficit : r.remanenteReal,
      semaforo: v.indicadores.remanente,
      sinDatos: sinPlan && r.gastoReal == 0 && r.ingresoReal == 0,
    );
  }

  final dom.Semana semana;
  final int ingresoPlaneado;
  final int ingresoReal;

  /// Presupuesto de la semana (egreso tipo 1) y lo gastado hasta hoy.
  final int presupuesto;
  final int gastado;

  /// Deuda planeada (egreso tipo 2) y lo abonado.
  final int deuda;
  final int abonado;
  final int remanentePlaneado;
  final int remanenteReal;
  final dom.Semaforo semaforo;

  /// No hay plan ni movimientos en la semana: se dice "Sin datos todavía".
  final bool sinDatos;

  /// Lo que queda del presupuesto de la semana (puede ser negativo).
  int get disponible => presupuesto - gastado;

  @override
  bool operator ==(Object other) =>
      other is CifrasSemana &&
      other.semana == semana &&
      other.ingresoPlaneado == ingresoPlaneado &&
      other.ingresoReal == ingresoReal &&
      other.presupuesto == presupuesto &&
      other.gastado == gastado &&
      other.deuda == deuda &&
      other.abonado == abonado &&
      other.remanentePlaneado == remanentePlaneado &&
      other.remanenteReal == remanenteReal &&
      other.semaforo == semaforo &&
      other.sinDatos == sinDatos;

  @override
  int get hashCode => Object.hash(
    semana,
    ingresoPlaneado,
    ingresoReal,
    presupuesto,
    gastado,
    deuda,
    abonado,
    remanentePlaneado,
    remanenteReal,
    semaforo,
    sinDatos,
  );
}

/// Resumen de la semana de **un** libro para "Hoy".
@immutable
class ResumenLibroHoy {
  const ResumenLibroHoy({
    required this.libroId,
    required this.nombre,
    required this.tipo,
    required this.cifras,
    this.alertasCriticas = 0,
  });

  final String libroId;
  final String nombre;
  final dom.TipoLibro tipo;
  final CifrasSemana cifras;

  /// Avisos críticos abiertos de este libro (sin montos: solo el número).
  final int alertasCriticas;

  /// Texto de las alertas, sin cifras de dinero.
  String get textoAlertas => switch (alertasCriticas) {
    0 => 'Sin alertas críticas',
    1 => '1 alerta crítica',
    final n => '$n alertas críticas',
  };
}

/// Qué tiene la tarjeta de Finanzas de "Hoy".
enum EstadoResumenHoy {
  /// El rol no ve Finanzas o no lleva ningún libro: la tarjeta no aparece.
  sinAcceso,
  cargando,

  /// No se pudo leer Finanzas (sin señal y sin copia): "Sin datos todavía",
  /// nunca un cero inventado.
  noDisponible,
  conLibros,
}

@immutable
class ResumenFinanzasHoy {
  const ResumenFinanzasHoy(this.estado, [this.libros = const []]);

  static const sinAcceso = ResumenFinanzasHoy(EstadoResumenHoy.sinAcceso);
  static const cargando = ResumenFinanzasHoy(EstadoResumenHoy.cargando);
  static const noDisponible = ResumenFinanzasHoy(EstadoResumenHoy.noDisponible);

  final EstadoResumenHoy estado;
  final List<ResumenLibroHoy> libros;

  /// La tarjeta se dibuja (con cifras, cargando o con "Sin datos todavía").
  bool get visible => estado != EstadoResumenHoy.sinAcceso;

  /// Ningún libro tiene plan ni movimientos esta semana.
  bool get sinDatos =>
      estado == EstadoResumenHoy.noDisponible ||
      (estado == EstadoResumenHoy.conLibros &&
          libros.every((l) => l.cifras.sinDatos));

  /// El peor semáforo entre los libros (para un resumen de una sola línea).
  dom.Semaforo? get peorSemaforo {
    dom.Semaforo? peor;
    for (final l in libros) {
      if (l.cifras.sinDatos) continue;
      final s = l.cifras.semaforo;
      if (peor == null || s.index > peor.index) peor = s;
    }
    return peor;
  }

  /// Alertas críticas abiertas de todos los libros.
  int get alertasCriticas =>
      libros.fold(0, (total, l) => total + l.alertasCriticas);
}

/// Resumen de Finanzas por libro, filtrado por rol y permiso.
///
/// No pide nada nuevo al servidor: usa lo cargado de Finanzas (la copia
/// local si no hay señal). Se recalcula solo al cambiar los datos, el día, la
/// persona o los avisos.
final resumenFinanzasHoyProvider = Provider<ResumenFinanzasHoy>((ref) {
  final rol = ref.watch(rolEfectivoProvider);
  if (rol == null || !permisos.puedeAbrir(rol, Modulo.finanzas)) {
    return ResumenFinanzasHoy.sinAcceso;
  }
  final contexto = ref.watch(contextoFinanzasProvider);
  if (contexto.isLoading && !contexto.hasValue) return ResumenFinanzasHoy.cargando;
  final c = contexto.value;
  if (c == null) return ResumenFinanzasHoy.noDisponible;

  final avisos = ref.watch(bandejaDeAvisosProvider).value ?? const [];
  final semana = dom.Semana.de(c.hoy);
  final libros = <ResumenLibroHoy>[];
  for (final libro in c.libros) {
    if (libro.archivado) continue;
    final permiso = c.permisoEn(libro);
    // Solo lo que la persona lleva: ni lo que lee como cuenta maestra (pide
    // consulta registrada) ni lo público de otra persona.
    if (!permiso.leer || permiso.comoMaestra || permiso.comoLector) continue;
    final vista = dom.vistaSemana(c.datos, libro.id, semana, hoy: c.hoy);
    final criticas = avisos
        .where(
          (a) =>
              a.libroId == libro.id &&
              a.severidad == SeveridadAviso.critica &&
              a.estado.abierto,
        )
        .length;
    libros.add(
      ResumenLibroHoy(
        libroId: libro.id,
        nombre: libro.nombre,
        tipo: libro.tipo,
        cifras: CifrasSemana.de(vista),
        alertasCriticas: criticas,
      ),
    );
  }
  if (libros.isEmpty) return ResumenFinanzasHoy.sinAcceso;
  return ResumenFinanzasHoy(EstadoResumenHoy.conLibros, libros);
});

/// Cifras de la semana de hoy del libro activo (las de "Mi semana"), o `null`
/// si aún no hay libro que leer. Es el mismo [CifrasSemana] que usa "Hoy".
final cifrasMiSemanaProvider = Provider<CifrasSemana?>((ref) {
  final c = ref.watch(contextoFinanzasProvider).value;
  if (c == null || c.libro == null || !c.permiso.leer) return null;
  final semana = ref.watch(semanaElegidaProvider) ?? dom.Semana.de(c.hoy);
  return CifrasSemana.de(
    dom.vistaSemana(c.datos, c.libroId, semana, hoy: c.hoy),
  );
});
