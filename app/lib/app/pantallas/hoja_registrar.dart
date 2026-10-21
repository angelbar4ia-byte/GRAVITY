/// Botón (+) del teléfono: registrar un gasto, un ingreso extra, un hábito o
/// un consumo, y el SOS (`DISENO_UX_UI.md`, sección 9). Solo las opciones
/// que permite el rol; cada una abre su registro (`registro_rapido.dart`).
library;

import 'package:flutter/material.dart';

import '../../nucleo/contratos/roles.dart';
import '../navegacion.dart';
import 'registro_rapido.dart';

Future<void> mostrarHojaRegistrar(BuildContext context, Rol rol) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => HojaRegistrar(rol: rol),
    );

class HojaRegistrar extends StatelessWidget {
  const HojaRegistrar({super.key, required this.rol});

  final Rol rol;

  @override
  Widget build(BuildContext context) {
    final opciones = opcionesRegistrar(rol);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Registrar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final opcion in opciones)
            ListTile(
              leading: Icon(opcion.icono),
              title: Text(opcion.etiqueta),
              minTileHeight: 56,
              onTap: () {
                // La hoja de la opción se abre desde donde se abrió esta
                // (sigue montado tras cerrarla).
                final origen = Navigator.of(context).context;
                Navigator.of(context).pop();
                abrirRegistro(origen, opcion);
              },
            ),
        ],
      ),
    );
  }
}
