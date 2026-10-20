/// Elige el cascarón según el dispositivo (D4, D14).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/contratos/dispositivo.dart';
import '../dispositivo.dart';
import 'cascaron_laptop.dart';
import 'cascaron_tablet.dart';
import 'cascaron_telefono.dart';

class CascaronSegunDispositivo extends ConsumerWidget {
  const CascaronSegunDispositivo({
    super.key,
    required this.ubicacion,
    required this.child,
  });

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(tipoDispositivoProvider)) {
        TipoDispositivo.laptop => CascaronLaptop(child: child),
        TipoDispositivo.tablet => CascaronTablet(
          ubicacion: ubicacion,
          child: child,
        ),
        TipoDispositivo.telefono => CascaronTelefono(
          ubicacion: ubicacion,
          child: child,
        ),
      };
}
