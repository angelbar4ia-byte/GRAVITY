/// Pantallas de la Fase 2 en la laptop: Deudas, Ahorro y fondo, y el
/// calendario de Vencimientos.
library;

import 'package:flutter/material.dart';

import '../fase2/vista_ahorro.dart';
import '../fase2/vista_deudas.dart';
import '../fase2/vista_simulador.dart';
import '../fase2/vista_tarjetas.dart';
import '../fase2/vista_vencimientos.dart';
import 'marco_laptop.dart';

class PantallaDeudas extends StatelessWidget {
  const PantallaDeudas({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.deudas,
    builder: (context, c) => VistaDeudas(contexto: c),
  );
}

class PantallaAhorro extends StatelessWidget {
  const PantallaAhorro({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.ahorro,
    builder: (context, c) => VistaAhorro(contexto: c),
  );
}

class PantallaVencimientos extends StatelessWidget {
  const PantallaVencimientos({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.vencimientos,
    builder: (context, c) => VistaVencimientos(contexto: c),
  );
}

class PantallaSimulador extends StatelessWidget {
  const PantallaSimulador({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.simulador,
    builder: (context, c) => VistaSimulador(contexto: c),
  );
}

class PantallaTarjetas extends StatelessWidget {
  const PantallaTarjetas({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.tarjetas,
    builder: (context, c) => VistaTarjetas(contexto: c),
  );
}
