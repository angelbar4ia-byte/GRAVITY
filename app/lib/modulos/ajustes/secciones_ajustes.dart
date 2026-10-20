/// Secciones de Ajustes (`DISENO_UX_UI.md`, sección 13) y quién las ve.
library;

import 'package:flutter/material.dart';

import '../../nucleo/contratos/dispositivo.dart';
import '../../nucleo/contratos/roles.dart';
import '../../nucleo/contratos/rutas.dart';
import '../../nucleo/permisos/permisos.dart';

enum SeccionAjustes {
  apariencia,
  voz,
  personas,
  privacidad,
  copias,
  notificaciones,
  desarrollador,
}

class InfoSeccionAjustes {
  const InfoSeccionAjustes({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.segmento,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;

  /// Segmento de la ruta debajo de `/ajustes`.
  final String segmento;
}

const Map<SeccionAjustes, InfoSeccionAjustes> infoSecciones = {
  SeccionAjustes.apariencia: InfoSeccionAjustes(
    titulo: 'Apariencia',
    descripcion: 'Estilo, claro u oscuro y personalidad por módulo',
    icono: Icons.palette_outlined,
    segmento: 'apariencia',
  ),
  SeccionAjustes.voz: InfoSeccionAjustes(
    titulo: 'Voz',
    descripcion: 'Voz de GRAVITY y respuestas habladas',
    icono: Icons.record_voice_over_outlined,
    segmento: 'voz',
  ),
  SeccionAjustes.personas: InfoSeccionAjustes(
    titulo: 'Personas y roles',
    descripcion: 'Quién usa la app, qué ve cada rol y la tablet de la casa',
    icono: Icons.people_alt_outlined,
    segmento: 'personas',
  ),
  SeccionAjustes.privacidad: InfoSeccionAjustes(
    titulo: 'Privacidad',
    descripcion: 'Modo privado y datos sensibles',
    icono: Icons.lock_outline,
    segmento: 'privacidad',
  ),
  SeccionAjustes.copias: InfoSeccionAjustes(
    titulo: 'Copias de seguridad',
    descripcion: 'Copia diaria desde la laptop y restauración',
    icono: Icons.backup_outlined,
    segmento: 'copias',
  ),
  SeccionAjustes.notificaciones: InfoSeccionAjustes(
    titulo: 'Notificaciones',
    descripcion: 'Avisos al teléfono y a la pulsera',
    icono: Icons.notifications_outlined,
    segmento: 'notificaciones',
  ),
  SeccionAjustes.desarrollador: InfoSeccionAjustes(
    titulo: 'Desarrollador',
    descripcion: 'APIs del sistema con Swagger UI',
    icono: Icons.code,
    segmento: 'desarrollador',
  ),
};

/// Ruta completa de la sección.
String rutaSeccion(SeccionAjustes seccion) => seccion ==
        SeccionAjustes.desarrollador
    ? Rutas.desarrollador
    : '${Rutas.ajustes}/${infoSecciones[seccion]!.segmento}';

/// Sección a la que pertenece [ubicacion], o `null`.
SeccionAjustes? seccionDeRuta(String ubicacion) {
  for (final seccion in SeccionAjustes.values) {
    final ruta = rutaSeccion(seccion);
    if (ubicacion == ruta || ubicacion.startsWith('$ruta/')) return seccion;
  }
  return null;
}

/// `true` si [rol] ve la sección en [dispositivo].
bool seccionDisponible(
  SeccionAjustes seccion,
  Rol rol,
  TipoDispositivo dispositivo,
) {
  if (!puedeAbrir(rol, Modulo.ajustes)) return false;
  return switch (seccion) {
    SeccionAjustes.personas ||
    SeccionAjustes.copias => puede(rol, Modulo.ajustes, Accion.administrar),
    SeccionAjustes.desarrollador => puedeVerDesarrollador(rol, dispositivo),
    _ => true,
  };
}

/// Secciones que ve [rol] en [dispositivo], en orden.
List<SeccionAjustes> seccionesVisibles(Rol rol, TipoDispositivo dispositivo) =>
    [
      for (final seccion in SeccionAjustes.values)
        if (seccionDisponible(seccion, rol, dispositivo)) seccion,
    ];
