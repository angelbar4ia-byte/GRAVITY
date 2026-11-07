/// Comidas de Papá (teléfono): por tiempo, "Comió", "Comió poco" o "Rechazó".
/// Solo lectura para la hermana y la pareja.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaComidas extends ConsumerWidget {
  const PantallaComidas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Comidas',
        cuerpo: !p.veComidas
            ? const SinAccesoCuidados()
            : cuando(
                ref.watch(comidasHoyProvider),
                () => ref.invalidate(comidasHoyProvider),
                (hechas) => ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final tiempo in TiempoComidaPapa.values)
                      TarjetaCuidados(
                        titulo: tiempo.etiqueta,
                        hijos: [
                          Text(
                            '¿Cómo comió?',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          for (final r in ResultadoComida.values)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _OpcionComida(
                                tiempo: tiempo,
                                resultado: r,
                                elegido: hechas[tiempo]?.resultado == r,
                                puede: p.registraComida,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _OpcionComida extends ConsumerWidget {
  const _OpcionComida({
    required this.tiempo,
    required this.resultado,
    required this.elegido,
    required this.puede,
  });

  final TiempoComidaPapa tiempo;
  final ResultadoComida resultado;
  final bool elegido;
  final bool puede;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // El elegido se marca con icono y texto, no solo con color.
    final texto = elegido ? '${resultado.etiqueta} (registrado)' : resultado.etiqueta;
    final icono = elegido ? Icons.check_circle : Icons.radio_button_unchecked;
    void alTocar() => ejecutarCuidados(
      context,
      ref,
      () => ref.read(servicioCuidadosProvider).registrarComida(tiempo, resultado),
      ok: 'Registrado',
    );
    return BotonGrande(
      texto: texto,
      icono: icono,
      tonal: !elegido,
      onPressed: puede ? alTocar : null,
    );
  }
}
