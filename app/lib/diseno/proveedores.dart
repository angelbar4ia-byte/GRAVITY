/// Proveedores Riverpod del sistema de estilos: estilo, claro/oscuro,
/// personalidad, densidad, tema y modo privado.
///
/// Uso en el arranque (dueño: plataforma):
/// ```dart
/// MaterialApp.router(
///   theme: ref.watch(temaClaroProvider),
///   darkTheme: ref.watch(temaOscuroProvider),
///   themeMode: ref.watch(modoTemaProvider),
///   themeAnimationDuration: duracionCambioTema,
/// )
/// ```
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/contratos/roles.dart';
import 'almacen_apariencia.dart';
import 'estilo.dart';
import 'estilos/catalogo.dart';
import 'modo_claro_oscuro.dart';
import 'personalidad_modulo.dart';
import 'solar.dart';
import 'tema.dart';
import 'valores_diseno.dart';

// --- Reloj -------------------------------------------------------------------

/// Fuente de la hora. Se reemplaza en pruebas con [RelojFijo].
abstract interface class Reloj {
  DateTime ahora();
}

class RelojSistema implements Reloj {
  const RelojSistema();

  @override
  DateTime ahora() => DateTime.now();
}

class RelojFijo implements Reloj {
  const RelojFijo(this.momento);

  final DateTime momento;

  @override
  DateTime ahora() => momento;
}

final relojProvider = Provider<Reloj>((ref) => const RelojSistema());

/// Hora local actual; se actualiza al cambiar el minuto.
final horaActualProvider = NotifierProvider<HoraActual, DateTime>(
  HoraActual.new,
);

class HoraActual extends Notifier<DateTime> {
  Timer? _temporizador;

  @override
  DateTime build() {
    final reloj = ref.watch(relojProvider);
    ref.onDispose(() => _temporizador?.cancel());
    final ahora = reloj.ahora();
    _programar(reloj, ahora);
    return ahora;
  }

  void _programar(Reloj reloj, DateTime desde) {
    _temporizador?.cancel();
    final espera = Duration(
      seconds: 60 - desde.second,
      milliseconds: -desde.millisecond,
    );
    _temporizador = Timer(espera, () {
      final ahora = reloj.ahora();
      state = ahora;
      _programar(reloj, ahora);
    });
  }
}

// --- Capa 2: estilo ----------------------------------------------------------

// --- Apariencia por persona ---------------------------------------------------

/// Dónde se guarda la apariencia de cada persona. Plataforma lo reemplaza con
/// su almacén local; por omisión es en memoria (ver [AlmacenApariencia]).
final almacenAparienciaProvider = Provider<AlmacenApariencia>(
  (ref) => AlmacenAparienciaMemoria(),
);

/// Clave de la apariencia en pantalla: la persona que está frente a la
/// pantalla ([personaEnPantallaProvider]) o, sin persona, la de la tablet de
/// la casa. Al cambiar de persona, estilo, claro/oscuro y alto contraste se
/// vuelven a leer: cada quien ve su apariencia.
final claveAparienciaProvider = Provider<String>(
  (ref) => ref.watch(personaEnPantallaProvider) ?? claveHogar,
);

/// Estilos que se pueden elegir (Futurista, Swagger y Glass).
final estilosDisponiblesProvider = Provider<List<Estilo>>(
  (ref) => estilosIncluidos,
);

/// Estilo global. Cambiarlo no reinicia la app: los temas se recalculan.
final estiloProvider = NotifierProvider<EstiloActual, Estilo>(EstiloActual.new);

class EstiloActual extends Notifier<Estilo> {
  @override
  Estilo build() {
    final clave = ref.watch(claveAparienciaProvider);
    final id = ref
        .watch(almacenAparienciaProvider)
        .leer(clave, CampoApariencia.estilo);
    if (id == null) return estiloPorDefecto;
    return estiloPorId(id, catalogo: ref.read(estilosDisponiblesProvider));
  }

  /// Cambia el estilo de la persona en pantalla y lo guarda para ella.
  void elegir(Estilo estilo) {
    state = estilo;
    ref
        .read(almacenAparienciaProvider)
        .guardar(
          ref.read(claveAparienciaProvider),
          CampoApariencia.estilo,
          estilo.id,
        );
  }

  void elegirPorId(String id) =>
      elegir(estiloPorId(id, catalogo: ref.read(estilosDisponiblesProvider)));
}

// --- Capa 4: claro / oscuro --------------------------------------------------

/// Modo y horario de claro/oscuro (por defecto: automático, claro de 07:00 a 19:00).
final preferenciaClaroOscuroProvider =
    NotifierProvider<PreferenciaClaroOscuroActual, PreferenciaClaroOscuro>(
      PreferenciaClaroOscuroActual.new,
    );

class PreferenciaClaroOscuroActual extends Notifier<PreferenciaClaroOscuro> {
  @override
  PreferenciaClaroOscuro build() => leerPreferenciaClaroOscuro(
    ref.watch(almacenAparienciaProvider),
    ref.watch(claveAparienciaProvider),
  );

  void cambiarModo(ModoClaroOscuro modo) => fijar(state.copyWith(modo: modo));

  void cambiarHorario(HorarioClaro horario) =>
      fijar(state.copyWith(horario: horario));

  void cambiarLugar(LugarSolar lugar) => fijar(state.copyWith(lugar: lugar));

  /// Cambia la preferencia de la persona en pantalla y la guarda para ella.
  void fijar(PreferenciaClaroOscuro preferencia) {
    state = preferencia;
    guardarPreferenciaClaroOscuro(
      ref.read(almacenAparienciaProvider),
      ref.read(claveAparienciaProvider),
      preferencia,
    );
  }
}

/// Alto contraste global (7:1, respuesta P6): todo el texto y los estados llegan
/// a [contrasteMinimoAlto] en cualquier estilo, y se apaga la decoración.
/// Es por persona. Cuidados y la bici ya van siempre así.
final altoContrasteProvider = NotifierProvider<AltoContrasteActual, bool>(
  AltoContrasteActual.new,
);

class AltoContrasteActual extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(almacenAparienciaProvider)
          .leer(
            ref.watch(claveAparienciaProvider),
            CampoApariencia.altoContraste,
          ) ==
      'true';

  void fijar(bool activo) {
    state = activo;
    ref
        .read(almacenAparienciaProvider)
        .guardar(
          ref.read(claveAparienciaProvider),
          CampoApariencia.altoContraste,
          activo ? 'true' : null,
        );
  }
}

/// Si en este momento toca la versión clara según el horario.
final esHorarioClaroProvider = Provider<bool>((ref) {
  final horario = ref.watch(
    preferenciaClaroOscuroProvider.select((p) => p.horario),
  );
  return horario.contiene(ref.watch(horaActualProvider));
});

/// Si en este momento es de día según el sol real del lugar de la persona.
final esDeDiaSolarProvider = Provider<bool>((ref) {
  final lugar = ref.watch(
    preferenciaClaroOscuroProvider.select((p) => p.lugar),
  );
  return esDeDiaSolar(ref.watch(horaActualProvider), lugar);
});

/// `ThemeMode` para `MaterialApp`.
final modoTemaProvider = Provider<ThemeMode>((ref) {
  final modo = ref.watch(preferenciaClaroOscuroProvider.select((p) => p.modo));
  return switch (modo) {
    ModoClaroOscuro.automaticoSolar =>
      ref.watch(esDeDiaSolarProvider) ? ThemeMode.light : ThemeMode.dark,
    ModoClaroOscuro.automaticoPorHora =>
      ref.watch(esHorarioClaroProvider) ? ThemeMode.light : ThemeMode.dark,
    ModoClaroOscuro.sistema => ThemeMode.system,
    ModoClaroOscuro.claro => ThemeMode.light,
    ModoClaroOscuro.oscuro => ThemeMode.dark,
  };
});

/// Brillo global ya resuelto (en modo sistema, el del sistema operativo).
Brightness brilloGlobal(BuildContext context, WidgetRef ref) =>
    switch (ref.watch(modoTemaProvider)) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };

// --- Capa 3: personalidad ----------------------------------------------------

/// Opción elegida por módulo en Ajustes › Apariencia (por defecto, automática).
final opcionesPersonalidadProvider =
    NotifierProvider<OpcionesPersonalidad, Map<Modulo, OpcionPersonalidad>>(
      OpcionesPersonalidad.new,
    );

class OpcionesPersonalidad extends Notifier<Map<Modulo, OpcionPersonalidad>> {
  @override
  Map<Modulo, OpcionPersonalidad> build() => const {};

  void fijar(Modulo modulo, OpcionPersonalidad opcion) =>
      state = {...state, modulo: opcion};
}

/// Personalidad de un módulo.
final personalidadProvider = Provider.family<PersonalidadModulo, Modulo>((
  ref,
  modulo,
) {
  final opcion = ref.watch(
    opcionesPersonalidadProvider.select(
      (m) => m[modulo] ?? OpcionPersonalidad.automatica,
    ),
  );
  return PersonalidadModulo.resolver(modulo, opcion: opcion);
});

/// Personalidad de un submódulo (usa la opción de su módulo).
final personalidadSubmoduloProvider =
    Provider.family<PersonalidadModulo, Submodulo>((ref, submodulo) {
      final opcion = ref.watch(
        opcionesPersonalidadProvider.select(
          (m) => m[submodulo.modulo] ?? OpcionPersonalidad.automatica,
        ),
      );
      return PersonalidadModulo.resolver(
        submodulo.modulo,
        submodulo: submodulo,
        opcion: opcion,
      );
    });

// --- Densidad por dispositivo -----------------------------------------------

/// Densidad base del dispositivo. Plataforma la reemplaza en el arranque:
/// `densidadBaseProvider.overrideWithValue(densidadPara(TipoDispositivo.laptop))`.
final densidadBaseProvider = Provider<Densidad>((ref) => Densidad.comoda);

// --- Temas de la app ---------------------------------------------------------

/// Tema claro de la app (estilo global con la personalidad de GRAVITY).
final temaClaroProvider = Provider<ThemeData>(
  (ref) => temaPara(
    estilo: ref.watch(estiloProvider),
    brillo: Brightness.light,
    personalidad: ref.watch(personalidadProvider(Modulo.gravity)),
    densidadBase: ref.watch(densidadBaseProvider),
    altoContrasteGlobal: ref.watch(altoContrasteProvider),
  ),
);

/// Tema oscuro de la app.
final temaOscuroProvider = Provider<ThemeData>(
  (ref) => temaPara(
    estilo: ref.watch(estiloProvider),
    brillo: Brightness.dark,
    personalidad: ref.watch(personalidadProvider(Modulo.gravity)),
    densidadBase: ref.watch(densidadBaseProvider),
    altoContrasteGlobal: ref.watch(altoContrasteProvider),
  ),
);

// --- Privacidad en pantalla --------------------------------------------------

/// Quién está frente a la pantalla: la persona de la sesión o, en la tablet, la
/// que entró con PIN (o el modo Casa). Al cambiar, [modoPrivadoProvider] y
/// [montosVisiblesProvider] vuelven a su estado inicial: los montos que mostró
/// una persona no quedan visibles para la siguiente.
///
/// El sistema de diseño no conoce la sesión; plataforma lo conecta en el
/// arranque con la persona efectiva:
/// `personaEnPantallaProvider.overrideWith((ref) => ref.watch(sesionEfectivaProvider)?.persona.id)`.
final personaEnPantallaProvider = Provider<String?>((ref) => null);

/// Modo privado (secciones 7 y 21): oculta montos **y** datos de cuidados, por
/// si alguien está viendo. Atajo en la laptop: Ctrl + Shift + O. Se quita al
/// cambiar de persona ([personaEnPantallaProvider]).
final modoPrivadoProvider = NotifierProvider<ModoPrivado, bool>(
  ModoPrivado.new,
);

class ModoPrivado extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(personaEnPantallaProvider);
    return false;
  }

  void alternar() => fijar(!state);

  /// Al activarlo, los montos que se habían mostrado se vuelven a ocultar.
  void fijar(bool activo) {
    state = activo;
    if (activo) ref.read(montosVisiblesProvider.notifier).fijar(false);
  }
}

/// Si el usuario pidió ver los montos ("Mostrar"). Empieza en falso: como en
/// los bocetos, los montos se abren ocultos y se muestran con un toque. Vuelve
/// a ocultarlos al cambiar de persona ([personaEnPantallaProvider]).
final montosVisiblesProvider = NotifierProvider<MontosVisibles, bool>(
  MontosVisibles.new,
);

class MontosVisibles extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(personaEnPantallaProvider);
    return false;
  }

  void alternar() => state = !state;

  void fijar(bool visibles) => state = visibles;
}

/// Cómo se pide ver los montos cuando están ocultos (decisión del 23/oct: tras
/// unos minutos sin uso se ocultan solos y **volver a verlos pide el PIN**, o la
/// huella en el teléfono). Devuelve `true` si se mostraron.
///
/// El sistema de diseño no conoce el PIN ni la huella: plataforma lo conecta en
/// el arranque con su flujo (`revelarMontos`). Por omisión (modo demostración y
/// pruebas) los muestra sin pedir nada.
typedef RevelarMontos = Future<bool> Function(BuildContext context);

final revelarMontosProvider = Provider<RevelarMontos>(
  (ref) => (context) async {
    ref.read(montosVisiblesProvider.notifier).fijar(true);
    return true;
  },
);

/// Si los montos se dibujan ocultos: con modo privado, siempre.
final montosOcultosProvider = Provider<bool>(
  (ref) => ref.watch(modoPrivadoProvider) || !ref.watch(montosVisiblesProvider),
);
