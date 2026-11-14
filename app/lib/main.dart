import 'package:flutter/foundation.dart' show kReleaseMode, debugPrint;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_gravity.dart';
import 'app/arranque.dart';
import 'nucleo/cola/proveedores_cola.dart';
import 'nucleo/rendimiento/medidor_arranque.dart';

Future<void> main() async {
  medidorDeArranque.marcar('main');
  WidgetsFlutterBinding.ensureInitialized();
  final contenedor = ProviderContainer(overrides: await prepararArranque());
  // Lo registrado sin señal se sube en cuanto vuelve (D7).
  contenedor.read(colaSinConexionProvider).iniciarAutomatico();
  medidorDeArranque.marcar('antes_de_runApp');
  runApp(
    UncontrolledProviderScope(container: contenedor, child: const AppGravity()),
  );
  // El primer cuadro es lo que la persona espera; el resumen sale en el
  // registro de depuración y perfil (no en release).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    medidorDeArranque.marcar(MedidorArranque.pasoPrimerCuadro);
    if (!kReleaseMode) debugPrint(medidorDeArranque.resumen());
  });
}
