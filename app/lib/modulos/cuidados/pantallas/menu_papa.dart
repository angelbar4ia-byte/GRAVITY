/// Menú de Papá (teléfono), solo lectura (D23, F4-A5): la cuidadora lo ve aquí,
/// dentro de Cuidados, porque Alimentación no es una pestaña suya
/// (`accesoDirecto: false` en la matriz de permisos).
///
/// El menú, el perfil y las advertencias son los de Alimentación (mismo
/// servicio, misma fuente): esta pantalla solo le pone el marco de Cuidados y
/// el permiso de entrada. No se edita nada desde aquí, ni la comida ni los
/// suplementos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../alimentacion/alimentacion.dart' show MenuDePapaSoloLectura;
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaMenuDePapa extends ConsumerWidget {
  const PantallaMenuDePapa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Menú de Papá',
        cuerpo: !p.veMenuDePapa
            ? const SinAccesoCuidados()
            : const MenuDePapaSoloLectura(),
      ),
    );
  }
}
