/// Widget raíz: router, tema y español de México.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bloqueo/capa_bloqueo.dart';
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
      builder: (context, child) =>
          CapaBloqueo(child: child ?? const SizedBox.shrink()),
    );
  }
}
