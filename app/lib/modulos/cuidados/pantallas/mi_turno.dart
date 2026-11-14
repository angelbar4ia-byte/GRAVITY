/// Mi turno (teléfono): turno de hoy, entrega de turno y cambios urgentes.
/// Es la pantalla de entrada de la cuidadora y de la hermana (la hermana
/// entra directo a la entrega de turno, `DISENO_UX_UI.md`, sección 2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaMiTurno extends ConsumerWidget {
  const PantallaMiTurno({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Mi turno',
        cuerpo: !p.entra
            ? const SinAccesoCuidados()
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: const [
                  _TurnoDeHoy(),
                  _Entrega(),
                  _CambiosUrgentes(),
                  _Accesos(),
                ],
              ),
      ),
    );
  }
}

class _TurnoDeHoy extends ConsumerWidget {
  const _TurnoDeHoy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = ref.watch(relojDeCuidados);
    final t = Theme.of(context).textTheme;
    return TarjetaCuidados(
      titulo: 'Turno de hoy',
      icono: Icons.assignment_ind_outlined,
      hijos: [
        Text(diaLargo(hoy), style: t.bodyLarge),
        const SizedBox(height: 8),
        cuando(
          ref.watch(miTurnoHoyProvider),
          () => ref.invalidate(miTurnoHoyProvider),
          (turnos) => turnos.isEmpty
              ? Text('Hoy no hay turno asignado.', style: t.titleMedium)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final turno in turnos)
                      Text(
                        '${turno.tipo == TipoTurno.visita ? 'Visita' : 'Turno'}: ${turno.horario}',
                        style: t.headlineSmall,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        cuando(
          ref.watch(siguienteDosisProvider),
          () => ref.invalidate(siguienteDosisProvider),
          (d) => d == null
              ? const SizedBox.shrink()
              // Solo la hora: sin nombre del medicamento.
              : Text(
                  'Siguiente medicamento a las ${horaTexto(d.hora)}',
                  style: t.titleMedium,
                ),
        ),
      ],
    );
  }
}

class _Entrega extends ConsumerWidget {
  const _Entrega();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    final t = Theme.of(context).textTheme;
    return TarjetaCuidados(
      titulo: 'Entrega de turno',
      icono: Icons.swap_horiz,
      hijos: [
        cuando(
          ref.watch(ultimaEntregaProvider),
          () => ref.invalidate(ultimaEntregaProvider),
          (e) => e == null
              ? Text('Sin notas de quien estuvo antes.', style: t.bodyLarge)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'De ${e.deNombre} · ${horaTexto(e.creadaEn)}',
                      style: t.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(e.notas, style: t.titleMedium),
                  ],
                ),
        ),
        if (p.dejaEntrega) ...[
          const SizedBox(height: 12),
          BotonGrande(
            texto: 'Dejar notas para quien sigue',
            icono: Icons.edit_note,
            tonal: true,
            onPressed: () => _dejar(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _dejar(BuildContext context, WidgetRef ref) async {
    final texto = await pedirTexto(
      context,
      titulo: 'Notas para quien sigue',
      pista: '¿Qué debe saber quien sigue?',
      lineas: 4,
    );
    if (texto == null || !context.mounted) return;
    await ejecutarCuidados(
      context,
      ref,
      () => ref.read(servicioCuidadosProvider).dejarEntrega(texto),
      ok: 'Entrega guardada',
    );
  }
}

class _CambiosUrgentes extends ConsumerWidget {
  const _CambiosUrgentes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    if (!p.veCambiosUrgentes) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return cuando(
      ref.watch(cambiosUrgentesProvider),
      () => ref.invalidate(cambiosUrgentesProvider),
      (cambios) {
        final pendientes = [
          for (final c in cambios)
            if (!c.atendido) c,
        ];
        final atendidos = [
          for (final c in cambios)
            if (c.atendido) c,
        ].take(3);
        if (pendientes.isEmpty && atendidos.isEmpty) {
          return const SizedBox.shrink();
        }
        return TarjetaCuidados(
          titulo: 'Cambios urgentes',
          icono: Icons.priority_high,
          hijos: [
            for (final c in pendientes) ...[
              Text('Hay una indicación nueva', style: t.titleMedium),
              Text(c.texto, style: t.bodyLarge),
              const SizedBox(height: 8),
              if (p.atiendeCambioUrgente)
                BotonGrande(
                  texto: 'Enterada',
                  icono: Icons.check,
                  onPressed: () => ejecutarCuidados(
                    context,
                    ref,
                    () =>
                        ref.read(servicioCuidadosProvider).atenderCambio(c.id),
                    ok: 'Enterada',
                  ),
                ),
              const SizedBox(height: 12),
            ],
            for (final c in atendidos)
              Text(
                c.atendidoNombre == null || c.atendidoNombre!.isEmpty
                    ? 'Atendido a las ${horaTexto(c.atendidoEn!)}'
                    : 'Atendido por ${c.atendidoNombre} a las ${horaTexto(c.atendidoEn!)}',
                style: t.bodyMedium,
              ),
          ],
        );
      },
    );
  }
}

class _Accesos extends ConsumerWidget {
  const _Accesos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        spacing: 12,
        children: [
          BotonGrande(
            texto: 'Medicamentos',
            icono: Icons.medication_outlined,
            onPressed: () => context.go('${Rutas.cuidados}/medicamentos'),
          ),
          BotonGrande(
            texto: 'Instrucciones',
            icono: Icons.sticky_note_2_outlined,
            onPressed: () => context.go('${Rutas.cuidados}/instrucciones'),
          ),
          BotonGrande(
            texto: 'Comidas',
            icono: Icons.restaurant_outlined,
            onPressed: () => context.go('${Rutas.cuidados}/comidas'),
          ),
          if (p.veBitacora || p.veGastos)
            BotonGrande(
              texto: p.veBitacora ? 'Bitácora y gastos' : 'Gastos',
              icono: Icons.menu_book_outlined,
              onPressed: () => context.go('${Rutas.cuidados}/bitacora'),
            ),
          if (p.veResumen)
            BotonGrande(
              texto: 'Resumen del mes',
              icono: Icons.summarize_outlined,
              tonal: true,
              onPressed: () => context.go('${Rutas.cuidados}/resumen'),
            ),
          if (p.administra) ...[
            BotonGrande(
              texto: 'Cambio urgente',
              icono: Icons.priority_high,
              tonal: true,
              onPressed: () => context.go('${Rutas.cuidados}/urgente'),
            ),
            BotonGrande(
              texto: 'Turnos, citas y medicamentos',
              icono: Icons.calendar_month_outlined,
              tonal: true,
              onPressed: () => context.go('${Rutas.cuidados}/gestion'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pide un texto en una hoja con letra grande. `null` si se cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String pista,
  int lineas = 2,
  TextInputType? teclado,
}) {
  final c = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            minLines: lineas,
            maxLines: lineas + 2,
            keyboardType: teclado,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              hintText: pista,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          BotonGrande(
            texto: 'Guardar',
            onPressed: () => Navigator.pop(ctx, c.text),
          ),
        ],
      ),
    ),
  );
}
