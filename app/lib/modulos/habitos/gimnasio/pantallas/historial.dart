/// E7 · Historial (sesiones y ejercicios) y E8 · Récords (7.1, 6.2 y 6.3).
///
/// Todo se **calcula** de las series guardadas: corregir o deshacer una serie
/// recalcula, y un día más flojo no quita un récord. El tipo de semana
/// (descarga, foco, reentrada) se anota para que una caída de carga no se lea
/// como retroceso.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/valores_diseno.dart';
import '../../../../nucleo/base_local/base_local.dart';
import '../../../../nucleo/gimnasio/repositorio_gimnasio.dart';
import '../casos_uso/servicio_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';

/// Texto de una carga: «Placa 4», una banda, o repeticiones o segundos.
String _valorDeSerie(SerieRegistrada s, Inventario inv) {
  if (s.cargaPasos != null) {
    final t = mostrarCargaPasos(s.cargaPasos!, inv).texto;
    return t[0].toUpperCase() + t.substring(1);
  }
  if (s.bandaId != null) {
    final b = inv.bandas.where((x) => x.id == s.bandaId).firstOrNull;
    if (b != null) return b.nombre;
  }
  if (s.segundos != null) return '${s.segundos} s';
  return '${s.reps ?? 0} repeticiones';
}

/// El valor que se dibuja en las barras de una serie (carga, o repeticiones o
/// segundos si no lleva carga).
double _valorNumerico(SerieRegistrada s, Inventario inv) {
  if (s.cargaPasos != null) return s.cargaPasos!.toDouble();
  if (s.bandaId != null) {
    final b = inv.bandas.where((x) => x.id == s.bandaId).firstOrNull;
    if (b != null) return b.orden.toDouble();
  }
  return (s.segundos ?? s.reps ?? 0).toDouble();
}

String _capitalizar(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

/// Las barras del historial de un ejercicio: lo mejor de cada semana.
List<BarraHistorialVista> barrasDeEjercicio(
  String ejercicioId,
  List<SesionRegistrada> historial,
  Inventario inv,
) {
  final porSemana = <DateTime, ({SerieRegistrada mejor, TipoSemana tipo})>{};
  for (final s in historial) {
    if (!s.esDeFuerza) continue;
    final lunes = lunesDe(s.fecha);
    for (final x in s.series) {
      if (x.ejercicioId != ejercicioId) continue;
      final actual = porSemana[lunes];
      if (actual == null ||
          _valorNumerico(x, inv) > _valorNumerico(actual.mejor, inv)) {
        porSemana[lunes] = (mejor: x, tipo: s.semanaTipo);
      }
    }
  }
  final semanas = porSemana.keys.toList()..sort();
  final maximo = semanas.isEmpty
      ? 0.0
      : semanas
            .map((l) => _valorNumerico(porSemana[l]!.mejor, inv))
            .reduce((a, b) => a > b ? a : b);
  return [
    for (final l in semanas)
      BarraHistorialVista(
        etiqueta: 'Semana del ${l.day}/${l.month}',
        valor: _valorNumerico(porSemana[l]!.mejor, inv),
        valorTexto: _valorDeSerie(porSemana[l]!.mejor, inv),
        tipoSemana: semanaVista(porSemana[l]!.tipo),
        esRecord:
            maximo > 0 && _valorNumerico(porSemana[l]!.mejor, inv) == maximo,
      ),
  ];
}

class PantallaHistorial extends ConsumerStatefulWidget {
  const PantallaHistorial({super.key});

  @override
  ConsumerState<PantallaHistorial> createState() => _EstadoHistorial();
}

class _EstadoHistorial extends ConsumerState<PantallaHistorial> {
  String? _ejercicio;
  bool _actualizando = false;

  @override
  Widget build(BuildContext context) {
    final servicio = ref.watch(servicioGimnasioProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.historial,
      acciones: [
        IconButton(
          key: const ValueKey('historial-actualizar'),
          tooltip: 'Actualizar desde el servidor',
          onPressed: servicio == null || _actualizando
              ? null
              : () async {
                  setState(() => _actualizando = true);
                  final ok = await servicio.bajarDelServidor();
                  ref.read(versionGimnasioProvider.notifier).state++;
                  if (!context.mounted) return;
                  setState(() => _actualizando = false);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(TextosGimnasio.sinConexionGenerico),
                      ),
                    );
                  }
                },
          icon: const Icon(Icons.sync),
        ),
      ],
      cuerpo: servicio == null
          ? const SinPersonaGimnasio()
          : vistaAsincrona<DatosGimnasio?>(
              ref.watch(datosGimnasioProvider),
              alReintentar: () => ref.invalidate(datosGimnasioProvider),
              listo: (d) =>
                  d == null ? const SinPersonaGimnasio() : _cuerpo(context, d, servicio),
            ),
    );
  }

  Widget _cuerpo(BuildContext context, DatosGimnasio d, ServicioGimnasio s) {
    final v = ValoresDiseno.de(context);
    final c = s.catalogo;
    // Los ejercicios con series hechas, para elegir cuál ver por semana.
    final ejercicios = <String>{
      for (final x in d.seriesFilas) x.ejercicioId,
    }.toList()..sort();
    final elegido =
        _ejercicio != null && ejercicios.contains(_ejercicio)
        ? _ejercicio
        : ejercicios.firstOrNull;
    final sesiones = [...d.sesionesFilas]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final porSesion = <String, int>{};
    for (final x in d.seriesFilas) {
      porSesion[x.sesionId] = (porSesion[x.sesionId] ?? 0) + 1;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (sesiones.isEmpty)
          const CuerpoEstadoGimnasio(
            estado: EstadoVistaGimnasio.vacio,
            mensajes: MensajesEstadoGimnasio(
              vacio: TextosHabitosGimnasio.sinHistorial,
              vacioDetalle: 'Cuando termines una sesión aparece aquí.',
            ),
          )
        else ...[
          if (elegido != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in ejercicios)
                  ChoiceChip(
                    label: Text(nombreDeEjercicio(c, e)),
                    selected: e == elegido,
                    onSelected: (_) => setState(() => _ejercicio = e),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            BarrasHistorial(
              titulo: nombreDeEjercicio(c, elegido),
              subtitulo: 'Lo mejor de cada semana',
              barras: barrasDeEjercicio(elegido, d.historial, d.inventario),
              resumenAccesible:
                  'Historial de ${nombreDeEjercicio(c, elegido)} por semana',
            ),
            SizedBox(height: v.espacio * 2),
          ],
          ListaSesionesHistorial(
            sesiones: [
              for (final f in sesiones.where((x) => x.estado != 'en_curso'))
                SesionHistorialVista(
                  fechaTexto: fechaCortaTexto(f.fecha),
                  plantillaTexto:
                      '${nombreDePlantilla(c, f.plantilla)} · '
                      '${textoVersionId(f.version).toLowerCase()}',
                  resumenTexto: _resumen(f, porSesion[f.id] ?? 0),
                  tipoSemana: semanaVistaDe(f.semanaTipo),
                  esfuerzoTexto: f.esfuerzo == null
                      ? null
                      : 'Esfuerzo ${f.esfuerzo} de 5',
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _resumen(GimSesionFila f, int hechas) {
    final planeadas = [
      for (final p in f.planComoLista) (p['series'] as int?) ?? 0,
    ].fold<int>(0, (a, b) => a + b);
    final min = f.fin?.difference(f.inicio).inMinutes.clamp(0, 600);
    final partes = [
      if (f.plantilla == 'R1' || f.plantilla == 'R2')
        'Regenerativa${f.estado == 'parcial' ? ' (una parte)' : ''}'
      else
        '$hechas de $planeadas series',
      if (min != null && min > 0) '$min min',
    ];
    return partes.join(' · ');
  }
}

// ------------------------------------------------------------------ récords

class PantallaRecords extends ConsumerWidget {
  const PantallaRecords({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicio = ref.watch(servicioGimnasioProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.records,
      cuerpo: servicio == null
          ? const SinPersonaGimnasio()
          : vistaAsincrona<DatosGimnasio?>(
              ref.watch(datosGimnasioProvider),
              alReintentar: () => ref.invalidate(datosGimnasioProvider),
              listo: (d) => d == null
                  ? const SinPersonaGimnasio()
                  : _CuerpoRecords(
                      datos: d,
                      catalogo: servicio.catalogo,
                      hoy: ref.watch(fechaDeHoyGimnasioProvider),
                    ),
            ),
    );
  }
}

class _CuerpoRecords extends StatelessWidget {
  const _CuerpoRecords({
    required this.datos,
    required this.catalogo,
    required this.hoy,
  });

  final DatosGimnasio datos;
  final Catalogo catalogo;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final records = calcularRecords(
      datos.historial,
      catalogo,
      bandas: datos.inventario.bandas,
    );
    final lista = <RecordVista>[];
    final ids = records.keys.toList()..sort();
    for (final id in ids) {
      final r = records[id]!;
      final ej = catalogo.ejercicioDeVariante(id);
      final nombre = ej?.nombre ?? id;
      final variante = catalogo.variante(id)?.nombre;
      void poner(TipoRecordVista tipo, String valor, DateTime? fecha) {
        lista.add(
          RecordVista(
            ejercicio: nombre,
            varianteTexto: variante,
            tipo: tipo,
            valorTexto: valor,
            fechaTexto: fecha == null
                ? null
                : '${fecha.day}/${fecha.month}',
            reciente: fecha != null && diasEntre(fecha, hoy) <= 7,
          ),
        );
      }

      if (r.mejorCargaPasos != null) {
        poner(
          TipoRecordVista.mejorCarga,
          _capitalizar(
            mostrarCargaPasos(r.mejorCargaPasos!, datos.inventario).texto,
          ),
          _cuando(id, (x) => x.cargaPasos == r.mejorCargaPasos),
        );
      } else if (r.mejoresReps != null) {
        poner(
          TipoRecordVista.mejoresRepeticiones,
          '${r.mejoresReps} repeticiones',
          _cuando(id, (x) => x.reps == r.mejoresReps),
        );
      }
      if (r.mejorSegundos != null) {
        poner(
          TipoRecordVista.mejorTiempo,
          '${r.mejorSegundos} s',
          _cuando(id, (x) => x.segundos == r.mejorSegundos),
        );
      }
      if (r.mejorBandaOrden != null) {
        final b = datos.inventario.bandas
            .where((x) => x.orden == r.mejorBandaOrden)
            .firstOrNull;
        poner(
          TipoRecordVista.mejorBanda,
          b?.nombre ?? 'Banda ${r.mejorBandaOrden}',
          _cuando(id, (x) => x.bandaId == b?.id),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (lista.isEmpty)
          const CuerpoEstadoGimnasio(
            estado: EstadoVistaGimnasio.vacio,
            mensajes: MensajesEstadoGimnasio(
              vacio: TextosHabitosGimnasio.sinRecords,
            ),
          )
        else
          ListaRecords(records: lista),
      ],
    );
  }

  /// La primera vez que se logró ese valor en esa variante.
  DateTime? _cuando(String varianteId, bool Function(SerieRegistrada) esa) {
    for (final s in datos.historial) {
      for (final x in s.series) {
        if (x.varianteId == varianteId && esa(x)) return soloDia(s.fecha);
      }
    }
    return null;
  }
}
