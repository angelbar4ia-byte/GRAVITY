/// Pantallas de la Fase 2 en el teléfono y la tablet: deudas con la hoja
/// corta de pago, ahorro y vencimientos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/pantallas/marco_pantalla.dart';
import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../comunes.dart';
import '../fase2/vista_ahorro.dart';
import '../fase2/vista_deudas.dart';
import '../fase2/vista_vencimientos.dart';

class _Marco extends StatelessWidget {
  const _Marco({required this.titulo, required this.cuerpo});

  final String titulo;
  final Widget Function(BuildContext, dynamic) cuerpo;

  @override
  Widget build(BuildContext context) => TemaModulo(
    modulo: Modulo.finanzas,
    child: MarcoPantalla(
      titulo: titulo,
      acciones: const [BotonMontos()],
      cuerpo: ConDatosFinanzas(builder: cuerpo),
    ),
  );
}

class PantallaDeudasTelefono extends ConsumerWidget {
  const PantallaDeudasTelefono({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Marco(
    titulo: 'Deudas',
    cuerpo: (context, c) => VistaDeudas(contexto: c, telefono: true),
  );
}

class PantallaAhorroTelefono extends ConsumerWidget {
  const PantallaAhorroTelefono({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Marco(
    titulo: 'Ahorro y fondo',
    cuerpo: (context, c) => VistaAhorro(contexto: c, telefono: true),
  );
}

class PantallaVencimientosTelefono extends ConsumerWidget {
  const PantallaVencimientosTelefono({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Marco(
    titulo: 'Vencimientos',
    cuerpo: (context, c) => VistaVencimientos(contexto: c),
  );
}
