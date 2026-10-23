/// Registros que el servidor no aceptó (revisión de la Fase 0, I4): no se
/// pierden ni se reintentan solos; aquí la persona los ve y decide. Cada quien
/// ve solo los suyos (D5).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/base_local/base_local.dart';
import '../../nucleo/cola/proveedores_cola.dart';
import '../../nucleo/contratos/dispositivo.dart';
import '../dispositivo.dart';
import '../navegacion.dart';
import 'marco_pantalla.dart';

/// Aviso arriba de las pantallas cuando hay registros que requieren atención.
class AvisoRegistrosAtencion extends ConsumerWidget {
  const AvisoRegistrosAtencion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuantos = ref.watch(registrosConAtencionProvider).value?.length ?? 0;
    if (cuantos == 0) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final texto = cuantos == 1
        ? '1 registro no se pudo subir: requiere atención.'
        : '$cuantos registros no se pudieron subir: requieren atención.';
    return Material(
      key: const ValueKey('aviso-registros-atencion'),
      color: tema.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: ListTile(
          leading: Icon(
            Icons.cloud_off_outlined,
            color: tema.colorScheme.onErrorContainer,
          ),
          title: Text(
            texto,
            style: TextStyle(color: tema.colorScheme.onErrorContainer),
          ),
          trailing: TextButton(
            onPressed: () => context.go(RutasApp.pendientes),
            child: const Text('Revisar'),
          ),
        ),
      ),
    );
  }
}

/// Bandeja de salida de la tablet (D14, 23/oct/2026): lo registrado sin señal
/// queda aquí y se sube solo cuando hay señal, sin pedir el PIN otra vez. Solo
/// cuenta (nunca dice qué ni de quién): la tablet es compartida.
class AvisoBandejaDeSalida extends ConsumerWidget {
  const AvisoBandejaDeSalida({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(tipoDispositivoProvider) != TipoDispositivo.tablet) {
      return const SizedBox.shrink();
    }
    final estado = ref.watch(estadoBandejaProvider).value ?? EstadoBandeja.vacio;
    final caducados = ref.watch(caducadosDeLaBandejaProvider).value ?? 0;
    if (estado.porSubir == 0 && caducados == 0) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final lineas = <String>[
      if (estado.porSubir > 0)
        estado.porSubir == 1
            ? '1 por subir'
            : '${estado.porSubir} por subir',
      if (estado.seSubenSolos > 0)
        estado.seSubenSolos == estado.porSubir
            ? 'Se suben solos cuando haya señal; no hace falta el PIN.'
            : '${estado.seSubenSolos} se suben solos cuando haya señal.',
      if (estado.esperanElPin > 0)
        estado.esperanElPin == 1
            ? '1 espera a que su persona entre con su PIN.'
            : '${estado.esperanElPin} esperan a que su persona entre con su PIN.',
      if (caducados > 0)
        caducados == 1
            ? '1 caducó (7 días sin señal): quien lo registró lo ve al entrar con su PIN.'
            : '$caducados caducaron (7 días sin señal): quien los registró los ve al entrar con su PIN.',
    ];
    return Material(
      key: const ValueKey('aviso-bandeja-de-salida'),
      color: tema.colorScheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: ListTile(
          dense: true,
          leading: Icon(
            Icons.cloud_upload_outlined,
            color: tema.colorScheme.onSecondaryContainer,
          ),
          title: Text(
            lineas.first,
            style: TextStyle(color: tema.colorScheme.onSecondaryContainer),
          ),
          subtitle: lineas.length > 1
              ? Text(
                  lineas.skip(1).join(' '),
                  style: TextStyle(
                    color: tema.colorScheme.onSecondaryContainer,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Pone [AvisoRegistrosAtencion] y [AvisoBandejaDeSalida] encima de [child]
/// (solo se ven si hay algo).
class ConAvisoAtencion extends StatelessWidget {
  const ConAvisoAtencion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AvisoRegistrosAtencion(),
      const AvisoBandejaDeSalida(),
      Expanded(child: child),
    ],
  );
}

/// Lista de los registros que requieren atención, con Reintentar y Descartar.
class PantallaRegistrosAtencion extends ConsumerWidget {
  const PantallaRegistrosAtencion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registros =
        ref.watch(registrosConAtencionProvider).value ??
        const <RegistroPendiente>[];
    final cola = ref.read(colaSinConexionProvider);
    return MarcoPantalla(
      titulo: 'Por revisar',
      cuerpo: registros.isEmpty
          ? const Center(child: Text('Todo lo que registraste ya se subió.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'El servidor no aceptó estos registros. No se perdieron: '
                  'puedes intentar otra vez (p. ej., si cambió un permiso) o '
                  'descartarlos.',
                ),
                const SizedBox(height: 12),
                for (final registro in registros)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            descripcionRegistro(registro),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (registro.ultimoError != null)
                            Text(registro.ultimoError!),
                          OverflowBar(
                            alignment: MainAxisAlignment.end,
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => cola.descartar(registro.id),
                                child: const Text('Descartar'),
                              ),
                              FilledButton.tonal(
                                onPressed: () async {
                                  await cola.reintentar(registro.id);
                                  await cola.procesar();
                                },
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Texto corto del registro: su tipo y, si la trae, su descripción.
String descripcionRegistro(RegistroPendiente registro) {
  String? descripcion;
  try {
    final carga = jsonDecode(registro.carga);
    if (carga is Map && carga['descripcion'] is String) {
      descripcion = carga['descripcion'] as String;
    }
  } catch (_) {
    descripcion = null;
  }
  return descripcion == null
      ? registro.tipo
      : '${registro.tipo} · $descripcion';
}
