/// La sesión de gimnasio **retiene la tablet** (PG-17, spec 9.2, CA-G-38).
///
/// Una sesión dura de 30 a 60 minutos y la tablet vuelve al modo Casa (o a la
/// pantalla de bloqueo, en la personal) a los **2 minutos** sin uso (D14). Con
/// una **sesión de gimnasio en curso**, la tablet espera [retencionSesionGimnasio]
/// (**10 minutos**) desde el **último toque**: cada toque, también los de las
/// hojas y diálogos, reinicia la cuenta (el detector de inactividad ya cuenta
/// los toques de toda la app). Pasados los 10 minutos sin tocar, vuelve al
/// reposo como siempre y **la sesión queda guardada como `en_curso`** en el
/// equipo (se guarda al empezar, local primero) para retomarla con el PIN.
///
/// La pantalla de la sesión en curso (G5) avisa con [SesionGimnasioEnCurso]:
/// `iniciar(persona)` al empezar o retomar y `terminar()` al terminar, salir o
/// descartar. Al volver al reposo o cambiar de persona se limpia solo: la
/// retención es de **esa** persona y de **esa** pantalla.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cuánto espera la tablet, desde el último toque, con una sesión en curso.
const retencionSesionGimnasio = Duration(minutes: 10);

/// Persona (id) con una sesión de gimnasio en curso en esta tablet, o `null`.
class SesionGimnasioEnCurso extends Notifier<String?> {
  @override
  String? build() => null;

  /// La persona [personaId] está haciendo una sesión: la tablet espera 10
  /// minutos desde el último toque.
  void iniciar(String personaId) => state = personaId;

  /// La sesión terminó (o se salió de ella): vuelve el tiempo de siempre.
  void terminar() => state = null;
}

final sesionGimnasioEnCursoProvider =
    NotifierProvider<SesionGimnasioEnCurso, String?>(SesionGimnasioEnCurso.new);

/// Tiempo sin uso tras el que la tablet vuelve al reposo: el de la tablet
/// ([base], 2 minutos por omisión) o, con una sesión de gimnasio en curso de la
/// persona que está dentro, [retencionSesionGimnasio] si es mayor. Nunca menor
/// que [base]: si la persona configuró más tiempo, se respeta.
Duration tiempoSinUsoDeLaTablet({
  required Duration base,
  required bool sesionGimnasioEnCurso,
}) => sesionGimnasioEnCurso && retencionSesionGimnasio > base
    ? retencionSesionGimnasio
    : base;
