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

/// Pone [AvisoRegistrosAtencion] encima de [child] (solo se ve si hay algo).
class ConAvisoAtencion extends StatelessWidget {
  const ConAvisoAtencion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AvisoRegistrosAtencion(),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => cola.descartar(registro.id),
                                child: const Text('Descartar'),
                              ),
                              const SizedBox(width: 8),
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
