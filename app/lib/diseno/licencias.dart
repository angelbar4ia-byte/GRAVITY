/// Registro de las licencias de las fuentes incluidas (SIL Open Font License 1.1)
/// para que aparezcan en la pantalla de licencias de la app.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Fuentes incluidas y la ruta de su licencia dentro de los recursos.
const Map<String, String> licenciasFuentes = {
  'Chakra Petch': 'assets/fonts/ChakraPetch/OFL.txt',
  'IBM Plex Sans': 'assets/fonts/IBMPlexSans/OFL.txt',
  'IBM Plex Mono': 'assets/fonts/IBMPlexMono/OFL.txt',
};

var _registradas = false;

/// Agrega las licencias de las fuentes al `LicenseRegistry`. Se llama una vez
/// en `main()`; llamarla de nuevo no hace nada.
void registrarLicenciasFuentes() {
  if (_registradas) return;
  _registradas = true;
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: fuente, value: ruta) in licenciasFuentes.entries) {
      final texto = await rootBundle.loadString(ruta);
      yield LicenseEntryWithLineBreaks([fuente], texto);
    }
  });
}
