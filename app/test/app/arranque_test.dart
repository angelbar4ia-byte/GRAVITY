import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/arranque.dart';
import 'package:gravity/app/dispositivo.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/configuracion/configuracion_entorno.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/firebase/firebase.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:intl/intl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sin llaves de Supabase arranca en modo demostración y en es_MX',
    () async {
      final overrides = await prepararArranque(
        configuracion: const ConfiguracionEntorno(dispositivoForzado: 'tablet'),
        abrirBase: BaseLocal.enMemoria,
      );
      final contenedor = ProviderContainer(overrides: overrides);
      addTearDown(() async {
        await contenedor.read(baseLocalProvider).close();
        contenedor.dispose();
      });

      expect(contenedor.read(servicioSesionProvider).esDemostracion, isTrue);
      expect(
        contenedor.read(almacenSeguroProvider),
        isA<AlmacenSeguroEnMemoria>(),
      );
      expect(contenedor.read(tipoDispositivoProvider), TipoDispositivo.tablet);
      // En las pruebas la plataforma es Android y no hay google-services.json:
      // Firebase queda apagado sin fallar.
      expect(
        contenedor.read(estadoFirebaseProvider),
        EstadoFirebase.sinConfiguracion,
      );
      expect(Intl.defaultLocale, 'es_MX');
      expect(DateFormat.MMMM().format(DateTime(2026, 10, 20)), 'octubre');
    },
  );

  test('ConfiguracionEntorno.tieneSupabase pide las dos llaves', () {
    expect(const ConfiguracionEntorno().tieneSupabase, isFalse);
    expect(
      const ConfiguracionEntorno(supabaseUrl: 'https://x.supabase.co')
          .tieneSupabase,
      isFalse,
    );
    expect(
      const ConfiguracionEntorno(
        supabaseUrl: 'https://x.supabase.co',
        supabaseLlavePublica: 'llave',
      ).tieneSupabase,
      isTrue,
    );
  });
}
