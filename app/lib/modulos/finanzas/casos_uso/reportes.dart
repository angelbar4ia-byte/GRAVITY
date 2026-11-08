/// Reportes del libro de quien los pide (Fase 8, bloque 4; D3, D19).
///
/// Todo se calcula en el teléfono o la laptop con lo que la persona ya tiene
/// cargado de **su** libro (lo que dejó pasar la RLS); nada sale de la app ni
/// va a la IA ni a las bocinas (D3). Los cálculos de gasto por categoría están
/// en `finanzas_dominio` (`reportes.dart`).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../datos/patrimonio.dart';
import '../datos/transferencias.dart';
import '../pantallas/patrimonio/vista_patrimonio.dart'
    show apartadoSemanalDeBolsa;
import '../pantallas/transferencias/aportacion_casa.dart'
    show FilaAportacion, filasDeAportacion;
import 'simulador_deudas.dart';

export 'package:finanzas_dominio/finanzas_dominio.dart'
    show
        GastoDelMes,
        LineaGastoCategoria,
        RangoReporte,
        ReporteGastoCategoria,
        gastoPorCategoria,
        gastoPorMes;

// ------------------------------------------------------------ aportación

/// Lo aportado a una subcuenta de la casa por cada persona y su reparto de
/// referencia (en puntos base).
class LineaSubcuenta {
  const LineaSubcuenta({
    required this.subcuentaId,
    required this.nombre,
    required this.reparto,
    required this.aportadoDueno,
    required this.aportadoPareja,
    required this.aportadoOtros,
  });

  final String subcuentaId;
  final String nombre;
  final ReparteReferencia reparto;
  final int aportadoDueno;
  final int aportadoPareja;

  /// Aportaciones de quien no es ninguno de los dos (por ejemplo, Papá).
  final int aportadoOtros;

  int get aportadoTotal => aportadoDueno + aportadoPareja + aportadoOtros;
}

class ReporteAportacion {
  const ReporteAportacion({
    required this.rango,
    required this.totalGastoCasa,
    required this.personas,
    required this.subcuentas,
  });

  final RangoReporte rango;
  final int totalGastoCasa;

  /// Dueño, pareja y Papá con referencia y aportado.
  final List<FilaAportacion> personas;
  final List<LineaSubcuenta> subcuentas;
}

/// Aportación de la casa en [rango]: referencia y aportado por persona y por
/// subcuenta. Solo cuentan las transferencias **confirmadas** a la casa que
/// la persona ve ([transferencias]) y los gastos del libro [libroCasaId].
ReporteAportacion reporteDeAportacion({
  required DatosFinanzas datos,
  required String libroCasaId,
  required RangoReporte rango,
  required List<Transferencia> transferencias,
  required List<SubcuentaCasa> subcuentas,
  required Map<String, ReparteReferencia> referencias,
  required String duenoId,
  required String parejaId,
  required String Function(String?) nombreDe,
}) {
  final total = totalGastoCasa(datos, libroCasaId, rango.desde, rango.hasta);
  int de(Transferencia t, bool Function(String) quien) =>
      t.estado == EstadoTransferencia.confirmada &&
          t.ruta.esACasa &&
          rango.contiene(Fecha.deDateTime(t.creadaEn)) &&
          quien(t.origenId)
      ? t.montoCentavos
      : 0;
  final lineas = <LineaSubcuenta>[];
  for (final s in subcuentas) {
    final suyas = transferencias.where((t) => t.subcuentaId == s.id);
    lineas.add(
      LineaSubcuenta(
        subcuentaId: s.id,
        nombre: s.nombre,
        reparto: referencias[s.id] ?? ReparteReferencia.porOmision,
        aportadoDueno: suyas.fold(0, (a, t) => a + de(t, (o) => o == duenoId)),
        aportadoPareja: suyas.fold(
          0,
          (a, t) => a + de(t, (o) => o == parejaId),
        ),
        aportadoOtros: suyas.fold(
          0,
          (a, t) => a + de(t, (o) => o != duenoId && o != parejaId),
        ),
      ),
    );
  }
  return ReporteAportacion(
    rango: rango,
    totalGastoCasa: total,
    personas: filasDeAportacion(
      total: total,
      transferencias: transferencias,
      duenoId: duenoId,
      parejaId: parejaId,
      desde: rango.desde,
      hasta: rango.hasta,
      nombreDe: nombreDe,
    ),
    subcuentas: lineas,
  );
}

// ---------------------------------------------------------------- deudas

class ResumenDeudas {
  const ResumenDeudas({
    required this.deudas,
    required this.saldoTotal,
    required this.saldosConocidos,
    required this.resultados,
    required this.recomendada,
    required this.soloMinimos,
  });

  final List<DeudaSimulable> deudas;

  /// Suma de los saldos que se conocen; una deuda sin saldo no se estima.
  final int saldoTotal;
  final bool saldosConocidos;
  final List<ResultadoEstrategia> resultados;

  /// La de menores intereses entre las calculadas; `null` si falta un dato.
  final ResultadoEstrategia? recomendada;
  final ResultadoSoloMinimos soloMinimos;
}

/// Saldos, tasas y la estrategia recomendada del [libroId]. Con datos
/// faltantes no estima: lo dice cada estrategia (`faltaDato`).
ResumenDeudas resumenDeDeudas(DatosFinanzas datos, String libroId, Fecha hoy) {
  final deudas = deudasSimulables(datos, libroId, hoy);
  final resultados = deudas.isEmpty
      ? <ResultadoEstrategia>[]
      : simularTodas(deudas);
  return ResumenDeudas(
    deudas: deudas,
    saldoTotal: deudas.fold(0, (a, d) => a + (d.saldo ?? 0)),
    saldosConocidos: deudas.every((d) => d.saldo != null),
    resultados: resultados,
    recomendada: recomendar(resultados),
    soloMinimos: interesesConPagoMinimo(deudas),
  );
}

// ------------------------------------------------------------- objetivos

class AvanceDeUnObjetivo {
  const AvanceDeUnObjetivo(this.objetivo, this.avance);
  final Objetivo objetivo;
  final AvanceObjetivo avance;
}

/// Lo que falta y las semanas estimadas de cada objetivo. El objetivo **lee**
/// el apartado de ahorro (saldo de su bolsa y lo apartado por semana); no lo
/// copia. Solo cuenta lo del libro [libroId].
List<AvanceDeUnObjetivo> reporteDeObjetivos({
  required DatosFinanzas datos,
  required String libroId,
  required Fecha hoy,
  required List<Objetivo> objetivos,
}) {
  final guardada = datos.semanaGuardada(libroId, Semana.de(hoy));
  final bolsas = {for (final b in datos.bolsasDe(libroId)) b.id: b};
  return [
    for (final o in objetivos)
      if (o.libroId == libroId)
        AvanceDeUnObjetivo(
          o,
          avanceObjetivo(
            metaCentavos: o.metaCentavos,
            ahorrado: bolsas[o.bolsaId] == null
                ? 0
                : datos.vista(libroId).saldo(bolsas[o.bolsaId]!.cuentaId),
            apartadoSemanal: o.bolsaId == null
                ? 0
                : apartadoSemanalDeBolsa(
                    datos.aportaciones,
                    guardada?.id,
                    o.bolsaId!,
                  ),
            fechaMeta: o.fechaMeta,
            hoy: hoy,
          ),
        ),
  ];
}
