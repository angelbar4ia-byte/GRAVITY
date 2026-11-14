/// Widget raíz: router, tema y español de México.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diseno/componentes/fondo_estilo.dart';
import '../diseno/valores_diseno.dart';
import 'avisos/con_avisos.dart';
import 'bloqueo/capa_bloqueo.dart';
import 'montos/ocultar_montos_por_inactividad.dart';
import 'pantallas_externas.dart';
import 'router.dart';

const localeGravity = Locale('es', 'MX');
const localesSoportados = [localeGravity, Locale('es')];

class AppGravity extends ConsumerWidget {
  const AppGravity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = temaExterno(ref);
    return MaterialApp.router(
      title: 'GRAVITY',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: tema.claro,
      darkTheme: tema.oscuro,
      themeMode: tema.modo,
      themeAnimationDuration: tema.duracion,
      locale: localeGravity,
      supportedLocales: localesSoportados,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Bloqueo del teléfono con PIN o huella (I8), encima de todo.
      // El fondo del estilo (liso o degradado de vidrio) va debajo de todas
      // las pantallas de todos los módulos (D27). Las pantallas con su propio
      // fondo opaco lo tapan; las transparentes lo dejan ver.
      builder: (context, child) => ConAvisos(
        child: OcultarMontosPorInactividad(
          child: CapaBloqueo(
            child: _ConFondoDelEstilo(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// Pone el fondo del estilo detrás de todo y, en los estilos de vidrio, hace
/// transparente el fondo de cada pantalla para que se vea (en los estilos
/// lisos no cambia nada: el fondo ya es del mismo color).
class _ConFondoDelEstilo extends StatelessWidget {
  const _ConFondoDelEstilo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final conDegradado = ValoresDiseno.de(context).fondoFin != null;
    final tema = Theme.of(context);
    return FondoEstilo(
      child: conDegradado
          ? Theme(
              data: tema.copyWith(scaffoldBackgroundColor: Colors.transparent),
              child: child,
            )
          : child,
    );
  }
}
