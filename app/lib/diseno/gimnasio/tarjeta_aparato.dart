/// Tarjeta de **aparato** del inventario (E2, 3.2 y 4.2): el aparato, sus
/// puestos, los datos que faltan por confirmar y si cuenta para armar sesiones.
/// Todo estado lleva icono y palabras; lo que no está confirmado lo dice y no
/// se presenta como cierto.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../tema.dart';
import '../valores_diseno.dart';
import 'piezas_gimnasio.dart';
import 'textos_gimnasio.dart';
import 'tipos_gimnasio.dart';

/// Un puesto de un aparato («Polea alta») y si se puede usar hoy.
@immutable
class PuestoVista {
  const PuestoVista({
    required this.nombre,
    this.disponibilidad = DisponibilidadAparato.disponible,
    this.alCambiar,
  });

  final String nombre;
  final DisponibilidadAparato disponibilidad;

  /// Cambia disponible y no disponible; sin esto la fila no se toca.
  final VoidCallback? alCambiar;
}

/// Un dato del aparato con su estado de confirmación (3.2): «Placas de la
/// pila», «Kilos por placa», «Tipo de polea».
@immutable
class DatoAparatoVista {
  const DatoAparatoVista({
    required this.etiqueta,
    this.valorTexto,
    this.confirmacion = EstadoConfirmacionDato.confirmar,
  });

  final String etiqueta;

  /// «68 kg aprox.», «6 placas»; `null` mientras falta.
  final String? valorTexto;
  final EstadoConfirmacionDato confirmacion;
}

/// La tarjeta de un aparato, puesto suelto, accesorio o equipo futuro.
class TarjetaAparato extends StatelessWidget {
  const TarjetaAparato({
    super.key,
    required this.nombre,
    this.icono = Icons.fitness_center,
    this.categoriaTexto = 'Aparato',
    this.detalle,
    this.disponibilidad = DisponibilidadAparato.disponible,
    this.puestos = const [],
    this.datos = const [],
    this.alCambiarDisponibilidad,
    this.alConfirmar,
    this.estado = EstadoVistaGimnasio.listo,
    this.mensajes = const MensajesEstadoGimnasio(
      vacio: 'No hay aparatos en tu inventario.',
      vacioDetalle: 'Agrega lo que tienes para armar sesiones con eso.',
      textoAccionVacia: 'Agregar un aparato',
      cargando: 'Cargando tu inventario…',
      sinConexion: 'Sin conexión. Se muestra el inventario guardado aquí.',
      error: 'No se pudo cargar el inventario. Puedes intentarlo otra vez.',
    ),
    this.alReintentar,
    this.alAccionVacia,
  });

  /// El nombre completo («Estación multifuncional Marcy MWM-7119»): se escribe
  /// entero, en varias líneas si hace falta, nunca recortado.
  final String nombre;
  final IconData icono;

  /// La etiqueta corta de la tarjeta («Estación», «Banco», «Bandas»).
  final String categoriaTexto;

  /// Una línea de apoyo («3 bandas activas»).
  final String? detalle;
  final DisponibilidadAparato disponibilidad;
  final List<PuestoVista> puestos;
  final List<DatoAparatoVista> datos;

  /// Marca el aparato como disponible o no disponible (roto, ocupado, prestado).
  final VoidCallback? alCambiarDisponibilidad;

  /// Abre «Confirmar en el aparato» (F-E5); solo se ofrece si falta algo.
  final VoidCallback? alConfirmar;
  final EstadoVistaGimnasio estado;
  final MensajesEstadoGimnasio mensajes;
  final VoidCallback? alReintentar;
  final VoidCallback? alAccionVacia;

  /// Si algún dato falta por confirmar.
  bool get faltaConfirmar =>
      datos.any((d) => d.confirmacion == EstadoConfirmacionDato.confirmar);

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    if (estado != EstadoVistaGimnasio.listo) {
      return TarjetaModulo(
        titulo: 'Inventario',
        icono: icono,
        child: CuerpoEstadoGimnasio(
          estado: estado,
          mensajes: mensajes,
          alReintentar: alReintentar,
          alAccionVacia: alAccionVacia,
        ),
      );
    }
    final colorEstado = switch (disponibilidad) {
      DisponibilidadAparato.disponible => v.exito,
      DisponibilidadAparato.noDisponible => v.alerta,
      DisponibilidadAparato.futuro => v.textoTenue,
    };
    final resumen = [
      nombre,
      disponibilidad.texto,
      if (faltaConfirmar) TextosGimnasio.confirmarEnElAparato,
    ].join('. ');
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: resumen,
      child: TarjetaModulo(
        titulo: categoriaTexto,
        icono: icono,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: e * 1.5,
              runSpacing: e,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  nombre,
                  style: v.lectura(
                    tamano: 18,
                    peso: FontWeight.w700,
                    color: v.textoFuerte,
                  ),
                ),
                MarcaGimnasio(
                  texto: disponibilidad.texto,
                  icono: disponibilidad.icono,
                  color: colorEstado,
                ),
              ],
            ),
            SizedBox(height: e),
            if (detalle != null)
              Padding(
                padding: EdgeInsets.only(bottom: e),
                child: Text(
                  detalle!,
                  style: v.lectura(tamano: 14, color: v.textoTenue),
                ),
              ),
            if (disponibilidad == DisponibilidadAparato.futuro)
              Padding(
                padding: EdgeInsets.only(bottom: e),
                child: Text(
                  TextosGimnasio.equipoFuturoNota,
                  style: v.lectura(tamano: 14, color: v.textoTenue),
                ),
              ),
            for (final p in puestos) _FilaPuesto(puesto: p),
            if (datos.isNotEmpty) ...[
              if (puestos.isNotEmpty) SizedBox(height: e),
              for (final d in datos) _FilaDato(dato: d),
            ],
            if (faltaConfirmar && alConfirmar != null) ...[
              SizedBox(height: e * 1.5),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: alConfirmar,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text(TextosGimnasio.confirmarEnElAparato),
                ),
              ),
            ],
            if (alCambiarDisponibilidad != null &&
                disponibilidad != DisponibilidadAparato.futuro) ...[
              SizedBox(height: e),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: alCambiarDisponibilidad,
                  icon: Icon(
                    disponibilidad == DisponibilidadAparato.disponible
                        ? Icons.block
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
                  label: Text(
                    disponibilidad == DisponibilidadAparato.disponible
                        ? TextosGimnasio.marcarNoDisponible
                        : TextosGimnasio.marcarDisponible,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaPuesto extends StatelessWidget {
  const _FilaPuesto({required this.puesto});

  final PuestoVista puesto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final d = puesto.disponibilidad;
    final color = switch (d) {
      DisponibilidadAparato.disponible => v.exito,
      DisponibilidadAparato.noDisponible => v.alerta,
      DisponibilidadAparato.futuro => v.textoTenue,
    };
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilMinima),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: e * 0.5),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(d.icono, size: 20, color: color)),
            SizedBox(width: e * 1.25),
            Expanded(
              child: Wrap(
                spacing: e,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    puesto.nombre,
                    style: v.lectura(
                      tamano: 15,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                  Text(
                    d.texto,
                    style: v.lectura(tamano: 13.5, color: v.textoTenue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final alCambiar = puesto.alCambiar;
    return Semantics(
      container: true,
      label: '${puesto.nombre}, ${d.texto.toLowerCase()}',
      button: alCambiar != null,
      onTap: alCambiar,
      excludeSemantics: true,
      child: alCambiar == null
          ? contenido
          : InkWell(onTap: alCambiar, child: contenido),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.dato});

  final DatoAparatoVista dato;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final c = dato.confirmacion;
    final color = switch (c) {
      EstadoConfirmacionDato.confirmado => v.exito,
      EstadoConfirmacionDato.confirmar => v.alerta,
      EstadoConfirmacionDato.delDiseno => v.textoTenue,
    };
    return Semantics(
      container: true,
      label: '${dato.etiqueta}: ${dato.valorTexto ?? 'sin dato'}. ${c.texto}',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: e * 0.75),
        child: Wrap(
          spacing: e * 1.5,
          runSpacing: e * 0.5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              dato.etiqueta,
              style: v.lectura(tamano: 14, color: v.textoTenue),
            ),
            Text(
              dato.valorTexto ?? '—',
              style: v.numero(
                tamano: 15,
                peso: FontWeight.w600,
                color: v.textoFuerte,
              ),
            ),
            MarcaGimnasio(texto: c.texto, icono: c.icono, color: color),
          ],
        ),
      ),
    );
  }
}
