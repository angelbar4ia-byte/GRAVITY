// Bandeja de salida sin PIN en la tablet (D14, 23/oct/2026): un gasto
// registrado con nombre y PIN y sin señal se sube solo al haber señal, con el
// token de esa persona, sin pedir el PIN otra vez. La credencial se MUEVE entre
// el sobre del PIN y la bandeja (el refresh token rota: dos copias se
// estorban), y el simulador de Supabase vigila que nunca se use una vieja.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/bandeja_salida.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';

import '../cola/ayuda_bandeja.dart';

void main() {
  final dueno = sesionDeEjemplo(Rol.dueno);
  final pareja = sesionDeEjemplo(Rol.coadministrador);
  final casa = sesionDeEjemplo(Rol.casa);
  const pin = '2846';

  late AlmacenSeguroEnMemoria almacen;
  late ServicioSesionFalso servicio;
  late ServidorFalso servidor;
  late BaseLocal base;
  late DateTime ahora;
  late ProviderContainer contenedor;
  late ControladorTablet tablet;
  late ColaSinConexion cola;

  void ponerSenal(bool hay) {
    servidor.conSenal = hay;
    servicio.sinConexion = !hay;
    // Pasa un rato: la espera de los reintentos ya venció.
    if (hay) ahora = ahora.add(const Duration(minutes: 1));
  }

  setUp(() async {
    almacen = AlmacenSeguroEnMemoria();
    servidor = ServidorFalso();
    base = BaseLocal.enMemoria();
    ahora = DateTime.utc(2026, 10, 24, 10);
    servicio = ServicioSesionFalso(
      cuentas: {'casa@ejemplo.test': CuentaFalsa('clave', casa)},
      inicial: casa,
    )..rotacionEstricta = true;
    contenedor = ProviderContainer(
      overrides: [
        almacenSeguroProvider.overrideWithValue(almacen),
        servicioSesionProvider.overrideWithValue(servicio),
        biometriaProvider.overrideWithValue(BiometriaFalsa()),
        baseLocalProvider.overrideWithValue(base),
        relojSeguridadProvider.overrideWithValue(() => ahora),
        enviadorProvider.overrideWithValue(
          EnviadorDeSesion(servidor, () => servicio.personaEnServidor),
        ),
        bandejaDeLaTabletProvider.overrideWith(
          (ref) => BandejaDeLaTabletConCola(
            ref.watch(bandejaDeSalidaProvider),
            () => ref.read(colaSinConexionProvider),
          ),
        ),
        salidaSinPinProvider.overrideWith(
          (ref) => SalidaSinPinConSesiones(
            bandeja: ref.watch(bandejaDeSalidaProvider),
            abrir: servicio.abrirSesionAparte,
            enviadorDe: (aparte) =>
                EnviadorDeSesion(servidor, () => aparte.personaId),
          ),
        ),
      ],
    );
    addTearDown(() async {
      contenedor.dispose();
      await base.close();
    });
    tablet = contenedor.read(controladorTabletProvider.notifier);
    await tablet.listo;
    cola = contenedor.read(colaSinConexionProvider);
    for (final sesion in [dueno, pareja]) {
      await tablet.agregarUsuario(
        sesion,
        pin: pin,
        credencial: ServicioSesionFalso.credencialDe(sesion),
      );
    }
  });

  Future<void> entrar(Sesion sesion, {String elPin = pin}) async {
    expect(
      await tablet.entrarConPin(sesion.persona.id, elPin),
      ResultadoDesbloqueo.abierto,
    );
  }

  Future<void> salir() async {
    tablet.volverAlReposo();
    await tablet.cambiosEnServidor;
  }

  Future<void> registrarGasto({String id = 'gasto-1'}) => cola.encolar(
    tipo: 'finanzas.movimiento',
    carga: const {'monto_centavos': 18500},
    id: id,
  );

  Future<PermisoDeSubida?> permisoDe(Sesion sesion) =>
      contenedor.read(bandejaDeSalidaProvider).leer(sesion.persona.id);

  Future<Object?> sobreDelPin(Sesion sesion, [String elPin = pin]) =>
      RepositorioTablet(almacen).leerCredencial(sesion.persona.id, elPin);

  test('registra sin señal, sale, y sube solo con su token; vuelve a entrar sin '
      'que nada se pierda', () async {
    await entrar(dueno);
    ponerSenal(false);
    await registrarGasto();
    expect((await cola.procesar()).reintentos, 1);
    await salir();

    // Salió con algo por subir: la credencial pasó a la bandeja (se mueve).
    final permiso = (await permisoDe(dueno))!;
    expect(permiso.estado, EstadoPermiso.enEspera);
    expect(await sobreDelPin(dueno), isNull, reason: 'una sola copia viva');
    expect(servicio.personaEnServidor, casa.persona.id, reason: 'de vuelta a Hogar');

    // Vuelve la señal: lo sube la cola SOLA, sin PIN, con el token del dueño.
    ponerSenal(true);
    final resumen = await cola.procesar();
    expect(resumen.enviados, 1);
    expect(servidor.idsDe(dueno.persona.id), ['gasto-1']);
    expect(servidor.idsDe(casa.persona.id), isEmpty, reason: 'nunca con la cuenta Hogar');
    expect((await permisoDe(dueno))!.estado, EstadoPermiso.devuelto);
    expect(await cola.hayPendientesDe(dueno.persona.id), isFalse);

    // La próxima vez que entre con su PIN, todo vuelve al sobre del PIN.
    await entrar(dueno);
    expect(await permisoDe(dueno), isNull, reason: 'el permiso se borra al terminar');
    expect(await sobreDelPin(dueno), isNotNull);
    expect(servicio.usosDeCredencialVieja, 0, reason: 'nunca se usó una copia vieja');
    // Y puede seguir como siempre: salir sin pendientes deja la credencial en su sobre.
    await salir();
    expect(await permisoDe(dueno), isNull);
    expect(await sobreDelPin(dueno), isNotNull);
    await entrar(dueno);
    expect(servicio.usosDeCredencialVieja, 0);
  });

  test('sin nada pendiente no hay permiso: la credencial queda en el sobre del PIN',
      () async {
    await entrar(dueno);
    await registrarGasto();
    await cola.procesar(); // hay señal: sube con su propia sesión
    expect(servidor.idsDe(dueno.persona.id), ['gasto-1']);
    await salir();
    expect(await permisoDe(dueno), isNull);
    expect(await sobreDelPin(dueno), isNotNull);
  });

  test('lo de cada persona sube con su token, no con el de otra', () async {
    await entrar(dueno);
    ponerSenal(false);
    await registrarGasto(id: 'del-dueno');
    await cola.procesar();
    await salir();
    await entrar(pareja);
    await registrarGasto(id: 'de-la-pareja');
    await cola.procesar();
    await salir();
    expect((await permisoDe(dueno)), isNotNull);
    expect((await permisoDe(pareja)), isNotNull);

    ponerSenal(true);
    expect((await cola.procesar()).enviados, 2);
    expect(servidor.idsDe(dueno.persona.id), ['del-dueno']);
    expect(servidor.idsDe(pareja.persona.id), ['de-la-pareja']);
    expect(servidor.idsDe(casa.persona.id), isEmpty);
  });

  test('si vuelve a entrar antes de que haya señal, no pierde nada y sube con su '
      'propia sesión', () async {
    await entrar(dueno);
    ponerSenal(false);
    await registrarGasto();
    await cola.procesar();
    await salir();
    expect(await permisoDe(dueno), isNotNull);

    await entrar(dueno); // sigue sin señal
    expect(await permisoDe(dueno), isNull, reason: 'la credencial volvió al sobre del PIN');
    expect(await sobreDelPin(dueno), isNotNull);
    ponerSenal(true);
    expect((await cola.procesar()).enviados, 1);
    expect(servidor.idsDe(dueno.persona.id), ['gasto-1']);
    expect(servicio.vecesAbrirAparte, 0, reason: 'dentro, sube con su sesión');
    expect(servicio.usosDeCredencialVieja, 0);
  });

  test('quitar a la persona con algo por subir: se borra su permiso y lo pendiente '
      'queda en "requiere atención"', () async {
    await entrar(dueno);
    ponerSenal(false);
    await registrarGasto();
    await cola.procesar();
    await salir();
    expect(await permisoDe(dueno), isNotNull);

    await tablet.quitarUsuario(dueno.persona.id);
    expect(await permisoDe(dueno), isNull);
    final registro = (await cola.registros()).single;
    expect(registro.estado, EstadoPendiente.rechazado);
    expect(registro.ultimoError, motivoPersonaQuitada);
    ponerSenal(true);
    await cola.procesar();
    expect(servidor.recibidos, isEmpty);
  });

  test('cambiar el PIN con la credencial en la bandeja: el PIN nuevo la abre', () async {
    await entrar(dueno);
    ponerSenal(false);
    await registrarGasto();
    await cola.procesar();
    await salir();
    ponerSenal(true);
    await cola.procesar(); // sube y sella
    expect((await permisoDe(dueno))!.estado, EstadoPermiso.devuelto);

    expect(
      await tablet.cambiarPin(dueno.persona.id, pinActual: pin, pinNuevo: '7391'),
      ResultadoDesbloqueo.abierto,
    );
    expect(
      await tablet.entrarConPin(dueno.persona.id, pin),
      ResultadoDesbloqueo.pinIncorrecto,
    );
    await entrar(dueno, elPin: '7391');
    expect(await permisoDe(dueno), isNull);
    expect(await sobreDelPin(dueno, '7391'), isNotNull);
    expect(servicio.usosDeCredencialVieja, 0);
  });

  test('a los 7 días sin señal caduca: aviso, nada se pierde y la persona tendrá '
      'que volver a agregarse', () async {
    await entrar(dueno);
    ponerSenal(false);
    await registrarGasto();
    await cola.procesar();
    await salir();

    ahora = ahora.add(const Duration(days: 7, minutes: 1));
    await cola.procesar();
    expect(await permisoDe(dueno), isNull);
    expect(await cola.contarCaducadosDeLaBandeja(), 1);
    expect(
      await cola.requierenAtencion(personaId: dueno.persona.id),
      hasLength(1),
      reason: 'el gasto sigue ahí, para revisarlo',
    );
    // Su credencial ya no existe en ninguna parte: tendrá que agregarse otra vez.
    expect(
      await tablet.entrarConPin(dueno.persona.id, pin),
      ResultadoDesbloqueo.faltaCuenta,
    );
  });

  test('la credencial nunca está en claro en el almacén al salir sin pendientes',
      () async {
    await entrar(dueno);
    await salir();
    final todo = almacen.datos.entries.map((e) => '${e.key}=${e.value}').join('\n');
    expect(todo, isNot(contains('falsa:')));
    expect(todo, isNot(contains(pin)));
  });
}
