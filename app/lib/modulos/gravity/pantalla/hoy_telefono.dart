/// "Hoy" en el teléfono y en la tablet por persona (DISENO_UX_UI, sección 9,
/// boceto "Hoy del Dueño"): lo que sigue, los hábitos de hoy, las finanzas de la
/// semana con el monto oculto y cuidados. Cada tarjeta aparece solo si el rol
/// efectivo la puede ver (`resumenGravityProvider`, D5). La barra inferior la
/// pone el cascarón del teléfono.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import 'resumen_gravity.dart';

class PantallaHoyTelefono extends ConsumerWidget {
  const PantallaHoyTelefono({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final r = ref.watch(resumenGravityProvider);
    final e = v.espacio;
    final hueco = SizedBox(height: e * 1.5);
    final sinNada =
        r.siguiente == null &&
        r.habitos.isEmpty &&
        r.finanzas == null &&
        r.cuidados == null;
    return Scaffold(
      backgroundColor: v.fondo,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const _EncabezadoHoy(),
            SizedBox(height: e * 2),
            if (v.cuadricula)
              // Estilo Bento: las tarjetas van en cuadrícula (2 columnas en el
              // teléfono, 4 desde 600 dp), cada una del tamaño de su contenido.
              CuadriculaBento(
                teselas: [
                  if (r.siguiente != null)
                    TeselaBento(
                      columnas: 4,
                      child: _TarjetaSigue(siguiente: r.siguiente!),
                    ),
                  if (r.habitos.isNotEmpty)
                    const TeselaBento(child: _TarjetaHabitos()),
                  if (r.finanzas != null)
                    const TeselaBento(child: _TarjetaFinanzas()),
                  if (r.cuidados != null)
                    const TeselaBento(child: _TarjetaCuidados()),
                ],
              )
            else ...[
              if (r.siguiente != null) ...[
                _TarjetaSigue(siguiente: r.siguiente!),
                hueco,
              ],
              if (r.habitos.isNotEmpty) ...[const _TarjetaHabitos(), hueco],
              if (r.finanzas != null) ...[const _TarjetaFinanzas(), hueco],
              if (r.cuidados != null) const _TarjetaCuidados(),
            ],
            if (sinNada && r.sinDatos)
              const EstadoVacio(
                key: ValueKey('hoy-sin-datos'),
                icono: Icons.hourglass_empty,
                mensaje: 'Sin datos todavía',
                // Sin nombres de módulos: quien no ve uno no debe enterarse.
                detalle:
                    'Tu resumen del día se arma con lo que cada módulo '
                    'comparte, y aún no hay nada.',
              )
            else if (sinNada)
              const EstadoVacio(
                key: ValueKey('hoy-vacio'),
                icono: Icons.wb_sunny_outlined,
                mensaje: 'Nada pendiente por hoy',
              ),
          ],
        ),
      ),
    );
  }
}

class _EncabezadoHoy extends ConsumerWidget {
  const _EncabezadoHoy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final ahora = ref.watch(horaActualProvider);
    final privado = ref.watch(modoPrivadoProvider);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Hoy', style: v.titulo(tamano: 28)),
              ),
              const SizedBox(height: 2),
              Text(
                fechaLarga(ahora),
                key: const ValueKey('fecha-hoy'),
                style: v.lectura(tamano: 14, color: v.textoTenue),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('boton-modo-privado'),
          tooltip: privado ? 'Quitar modo privado' : 'Modo privado',
          isSelected: privado,
          onPressed: () => ref.read(modoPrivadoProvider.notifier).alternar(),
          style: IconButton.styleFrom(
            side: BorderSide(color: privado ? v.acento : v.borde),
            backgroundColor: privado
                ? Color.alphaBlend(v.acento.withValues(alpha: 0.16), v.panel)
                : v.panel,
          ),
          icon: const Icon(Icons.visibility_outlined),
          selectedIcon: const Icon(Icons.visibility_off_outlined),
        ),
        SizedBox(width: v.espacio),
        IconButton(
          key: const ValueKey('boton-hablar'),
          tooltip: 'Hablar con GRAVITY',
          onPressed: () => _avisoEjemplo(
            context,
            'La voz de GRAVITY llega en una fase posterior.',
          ),
          style: IconButton.styleFrom(
            backgroundColor: v.acento,
            foregroundColor: v.sobreAcento,
          ),
          icon: const Icon(Icons.mic_none),
        ),
      ],
    );
  }
}

class _TarjetaSigue extends StatelessWidget {
  const _TarjetaSigue({required this.siguiente});

  final SiguienteActividad siguiente;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return TarjetaModulo(
      key: const ValueKey('tarjeta-sigue'),
      titulo: 'Sigue · ${siguiente.hora}',
      colorEtiqueta: v.acento,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            siguiente.titulo,
            style: v.lectura(
              tamano: 18,
              peso: FontWeight.w600,
              color: v.textoFuerte,
            ),
          ),
          if (siguiente.detalle != null) ...[
            SizedBox(height: e * 0.5),
            Text(
              siguiente.detalle!,
              style: v.lectura(tamano: 14, color: v.textoTenue),
            ),
          ],
          SizedBox(height: e * 1.5),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _avisoEjemplo(
                    context,
                    'Datos de ejemplo: marcar llega con Hábitos.',
                  ),
                  child: const Text('Hecho'),
                ),
              ),
              SizedBox(width: e),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _avisoEjemplo(
                    context,
                    'Datos de ejemplo: posponer llega con Hábitos.',
                  ),
                  child: const Text('Posponer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaHabitos extends ConsumerWidget {
  const _TarjetaHabitos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final r = ref.watch(resumenGravityProvider);
    final e = v.espacio;
    return TarjetaModulo(
      key: const ValueKey('tarjeta-habitos'),
      titulo: 'Hábitos de hoy',
      accion: Text(
        '${r.habitosHechos} de ${r.habitosTotal}',
        style: v.numero(tamano: 15, peso: FontWeight.w600, color: v.exito),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BarraProgreso(
            valor: r.habitosTotal == 0 ? 0 : r.habitosHechos / r.habitosTotal,
            color: v.exito,
            alto: 8,
          ),
          SizedBox(height: e * 1.5),
          Wrap(
            spacing: e * 0.75,
            runSpacing: e * 0.75,
            children: [for (final h in r.habitos) _ChipHabito(habito: h)],
          ),
        ],
      ),
    );
  }
}

class _ChipHabito extends StatelessWidget {
  const _ChipHabito({required this.habito});

  final HabitoDeHoy habito;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final hecho = habito.hecho;
    final color = hecho ? v.exito : v.textoTenue;
    return Semantics(
      label: '${habito.nombre}: ${hecho ? 'hecho' : 'pendiente'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hecho
              ? Color.alphaBlend(v.exito.withValues(alpha: 0.12), v.panel)
              : Color.lerp(v.panel, v.borde, 0.25),
          borderRadius: BorderRadius.circular(v.radioGrande),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                habito.nombre,
                style: v.lectura(
                  tamano: 13,
                  color: hecho ? v.textoFuerte : v.texto,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hecho) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaFinanzas extends ConsumerWidget {
  const _TarjetaFinanzas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final f = ref.watch(resumenGravityProvider).finanzas!;
    final ocultos = ref.watch(montosOcultosProvider);
    final privado = ref.watch(modoPrivadoProvider);
    final e = v.espacio;
    return TarjetaModulo(
      key: const ValueKey('tarjeta-finanzas'),
      titulo: 'Finanzas · semana',
      accion: Semaforo(estado: f.estado),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Quedan', style: v.lectura(tamano: 14, color: v.textoTenue)),
              SizedBox(width: e),
              Expanded(
                child: MontoOcultable(
                  key: const ValueKey('monto-quedan'),
                  centavos: f.quedanCentavos,
                  oculto: ocultos,
                  estilo: v.numero(
                    tamano: 22,
                    peso: FontWeight.w600,
                    color: v.acento,
                  ),
                  // Ocultos: pide verlos (PIN o huella). A la vista: los oculta.
                  alTocar: privado
                      ? null
                      : ocultos
                      ? () => ref.read(revelarMontosProvider)(context)
                      : () => ref
                            .read(montosVisiblesProvider.notifier)
                            .fijar(false),
                ),
              ),
            ],
          ),
          if (ocultos) ...[
            SizedBox(height: e * 0.5),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: MarcaMontosOcultos(),
            ),
          ],
          if (f.aviso != null) ...[
            SizedBox(height: e * 0.5),
            Text(f.aviso!, style: v.lectura(tamano: 14, color: v.textoTenue)),
          ],
        ],
      ),
    );
  }
}

class _TarjetaCuidados extends ConsumerWidget {
  const _TarjetaCuidados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final c = ref.watch(resumenGravityProvider).cuidados!;
    final privado = ref.watch(modoPrivadoProvider);
    final e = v.espacio;
    return TarjetaModulo(
      key: const ValueKey('tarjeta-cuidados'),
      titulo: 'Cuidados',
      child: privado
          ? Row(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: v.textoTenue,
                ),
                SizedBox(width: e),
                Expanded(
                  child: Text(
                    'Datos de cuidados ocultos (modo privado)',
                    style: v.lectura(tamano: 14, color: v.textoTenue),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(c.turno, style: v.lectura(tamano: 15)),
                for (final p in c.pendientes) ...[
                  SizedBox(height: e * 0.75),
                  Row(
                    children: [
                      Expanded(
                        child: Text(p.texto, style: v.lectura(tamano: 14)),
                      ),
                      Text(
                        p.estado,
                        style: v.lectura(
                          tamano: 14,
                          peso: FontWeight.w600,
                          color: p.atencion ? v.alerta : v.textoTenue,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

void _avisoEjemplo(BuildContext context, String texto) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
