/// Marco y piezas comunes de las secciones de Ajustes.
library;

import 'package:flutter/material.dart';

import '../../app/pantallas/marco_pantalla.dart';
import '../../nucleo/contratos/rutas.dart';
import 'secciones_ajustes.dart';

/// Marco de las secciones de Ajustes (regresa a Ajustes).
class MarcoSeccion extends StatelessWidget {
  const MarcoSeccion({super.key, required this.seccion, required this.hijos});

  final SeccionAjustes seccion;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => MarcoPantalla(
    titulo: infoSecciones[seccion]!.titulo,
    rutaAnterior: Rutas.ajustes,
    cuerpo: ListView(padding: const EdgeInsets.all(16), children: hijos),
  );
}

/// Texto explicativo de una sección.
class NotaAjustes extends StatelessWidget {
  const NotaAjustes(this.texto, {super.key, this.icono = Icons.info_outline});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(leading: Icon(icono), title: Text(texto)),
  );
}
