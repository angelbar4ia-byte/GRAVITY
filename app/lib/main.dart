import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_gravity.dart';
import 'app/arranque.dart';
import 'nucleo/cola/proveedores_cola.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final contenedor = ProviderContainer(overrides: await prepararArranque());
  // Lo registrado sin señal se sube en cuanto vuelve (D7).
  contenedor.read(colaSinConexionProvider).iniciarAutomatico();
  runApp(
    UncontrolledProviderScope(container: contenedor, child: const AppGravity()),
  );
}
