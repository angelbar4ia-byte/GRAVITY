// Ayudas para las pruebas por estilo (Fase 4). No es una prueba.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_pruebas.dart';

/// Monta [home] con el [estilo] y el [brillo] indicados (modo fijo, para que no
/// dependa de la hora).
Future<void> montarConEstilo(
  WidgetTester tester,
  Widget home, {
  required Estilo estilo,
  required Brightness brillo,
  bool altoContraste = false,
}) async {
  await montar(tester, home);
  final c = contenedorDe(tester, find.byWidget(home));
  c.read(estiloProvider.notifier).elegir(estilo);
  c
      .read(preferenciaClaroOscuroProvider.notifier)
      .cambiarModo(
        brillo == Brightness.dark
            ? ModoClaroOscuro.oscuro
            : ModoClaroOscuro.claro,
      );
  if (altoContraste) c.read(altoContrasteProvider.notifier).fijar(true);
  await tester.pump();
  await tester.pump(duracionCambioTema);
  // Deja terminar las animaciones de los botones y chips al nuevo tema.
  await tester.pump(const Duration(seconds: 1));
}

/// Pantalla de muestra con los gadgets que cada estilo debe poder dibujar.
Widget muestraDeGadgets() => SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TarjetaModulo(
          titulo: 'Finanzas · semana',
          accion: Semaforo(estado: EstadoSemaforo.verde),
          child: Text('Quedan'),
        ),
        const SizedBox(height: 12),
        const IndicadorConexion(estado: EstadoConexion.enLinea, pendientes: 3),
        const SizedBox(height: 12),
        CuadriculaBento(
          teselas: [
            TeselaBento(
              columnas: 4,
              child: TarjetaModulo(
                titulo: 'Hoy',
                child: Text('Nada pendiente'),
              ),
            ),
            const TeselaBento(
              child: TarjetaModulo(titulo: 'Hábitos', child: Text('3 de 5')),
            ),
            const TeselaBento(
              child: TarjetaModulo(titulo: 'Finanzas', child: Text('Bien')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RelojDelTurno.ejemplo(),
        const SizedBox(height: 12),
        CronometroCuidados.ejemplo(),
        const SizedBox(height: 12),
        ListaCompras.ejemplo(),
        const SizedBox(height: 12),
        MenuSemana.ejemplo(),
        const SizedBox(height: 12),
        Velocimetro.ejemplo(),
        const SizedBox(height: 12),
        SerieDescanso.ejemplo(),
        const SizedBox(height: 12),
        const NucleoGravity(tamano: 160),
      ],
    ),
  ),
);

/// La luminancia de [c] sobre un panel: texto y semáforo se prueban en las
/// superficies de [ValoresDiseno.superficiesConSemaforo].
String hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
