// Revisión de calidad de la Fase 1b (docs/revisiones/fase-1b.md): la bandeja
// de salida sin PIN (D14, 23/oct/2026) puesta a prueba por un adversario.
//
// Las pruebas con la etiqueta `hallazgo` FALLAN HOY A PROPÓSITO y demuestran
// un hallazgo; las demás son guardias que pasan y deben seguir pasando.
//
//  B1  Cerrar la sesión de la tablet (Hogar) deja la credencial en claro de
//      otras personas en el almacén, y como la caducidad solo corre con una
//      sesión abierta, ya no caduca a los 7 días.
//  B2  Un error pasajero que no es de red (p. ej. 429, límite de peticiones)
//      se toma por "credencial vencida": se borra el permiso y lo pendiente
//      pasa a "requiere atención".
//  B3  Una subida que no termina (servidor que no contesta) retiene el candado
//      de la persona para siempre: no puede entrar con su PIN, ni quitarla.
//  B4  Caducar el permiso borra la copia local pero no revoca la sesión en el
//      servidor: una copia robada sigue sirviendo.
//  B5  Volver a agregar a una persona con un permiso en espera deja el permiso
//      viejo, y al entrar pisa la credencial nueva con la vieja.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/bandeja_salida.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/biometria.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/controlador_tablet.dart';
import 'package:gravity/nucleo/tablet/usuarios_tablet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../nucleo/cola/ayuda_bandeja.dart';
import 'ayuda_gotrue.dart';

/// Un enviador que nunca contesta (el servidor se quedó colgado).
class _Colgado implements Enviador {
  _Colgado(this.espera);

  final Completer<ResultadoEnvio> espera;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) => espera.future;
}

void main() {
  final dueno = sesionDeEjemplo(Rol.dueno);
  final casa = sesionDeEjemplo(Rol.casa);
  const pin = '284651';

  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;
  late BandejaDeSalida bandeja;
  late BaseLocal base;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    ahora = DateTime.utc(2026, 10, 24, 10);
    bandeja = BandejaDeSalida(almacen, reloj: () => ahora);
    base = BaseLocal.enMemoria();
  });

  tearDown(() => base.close());

  Future<void> delegar(String credencial) => bandeja.delegar(
    dueno.persona.id,
    credencial,
    LlavePin.derivar(pin, iteraciones: 10),
  );

  Future<void> pendiente(ColaSinConexion cola, {String id = 'gasto-1'}) =>
      cola.encolar(
        tipo: 'finanzas.movimiento',
        carga: const {'monto_centavos': 18500},
        id: id,
        personaId: dueno.persona.id,
      );

  // ---------------------------------------------------------------- B1
  group('B1: sin sesión de la tablet no hay caducidad', () {
    test(
      'cerrada la sesión de Hogar, a los 8 días la credencial sigue en claro',
      () async {
        final servicio = ServicioSesionFalso(inicial: casa)..rotacionEstricta = true;
        final servidor = ServidorFalso();
        // Hogar salió (o su sesión se cerró): nadie tiene la sesión del servidor.
        String? sesionDelServidor = casa.persona.id;
        final cola = ColaSinConexion(
          base: base,
          enviador: EnviadorDeSesion(servidor, () => sesionDelServidor),
          reloj: () => ahora,
          personaConSesion: () => sesionDelServidor,
          cuentaDelEquipo: () => casa.persona.id,
          salida: SalidaSinPinConSesiones(
            bandeja: bandeja,
            abrir: servicio.abrirSesionAparte,
            enviadorDe: (aparte) => EnviadorDeSesion(servidor, () => aparte.personaId),
          ),
        );
        await pendiente(cola);
        await delegar(ServicioSesionFalso.credencialDe(dueno));
        expect((await bandeja.leer(dueno.persona.id))!.credencial, isNotNull);

        sesionDelServidor = null; // salir() de la cuenta del equipo
        ahora = ahora.add(const Duration(days: 8));
        await cola.procesar();

        final permiso = await bandeja.leer(dueno.persona.id);
        expect(
          permiso?.credencial,
          isNull,
          reason:
              'a los 8 días (7 de vigencia) la credencial en claro debería '
              'haberse borrado, pero como la caducidad solo corre dentro de '
              'procesar() con una sesión abierta (cola_sin_conexion.dart:431), '
              'sigue en el almacén seguro sin el PIN',
        );
      },
    );

    test(
      'salir() de la cuenta del equipo no deja credenciales en claro de otros',
      () async {
        final gotrue = GoTrueSimulado();
        await gotrue.abrir();
        addTearDown(gotrue.cerrar);
        final equipo = SupabaseClient(
          gotrue.url,
          'llave-publica-de-prueba',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(equipo.dispose);
        await equipo.auth.setInitialSession(jsonEncode(sesionJson(uidCasa, 'casa-0')));
        final servicio = ServicioSesionSupabase(
          cliente: equipo,
          almacen: almacen,
          url: gotrue.url,
          llavePublica: 'llave-publica-de-prueba',
          lectorPerfil: (cliente) async => cliente.auth.currentUser?.id == uidCasa ? casa : dueno,
        );
        addTearDown(servicio.cerrar);
        await servicio.iniciar();
        await delegar(jsonEncode(sesionJson(uidDueno, 'r0', vencida: true)));

        await servicio.salir();

        final permisos = await bandeja.todos();
        expect(
          permisos.where((p) => p.credencial != null),
          isEmpty,
          reason:
              'ServicioSesionSupabase.salir() solo borra la copia local de '
              'Hogar; el permiso de subida del dueño (con su sesión completa '
              'en claro) se queda en el equipo',
        );
      },
    );
  });

  // ---------------------------------------------------------------- B2
  group('B2: un error pasajero no es una credencial vencida', () {
    late GoTrueSimulado gotrue;
    late SupabaseClient equipo;
    late ServicioSesionSupabase servicio;

    setUp(() async {
      gotrue = GoTrueSimulado();
      await gotrue.abrir();
      equipo = SupabaseClient(
        gotrue.url,
        'llave-publica-de-prueba',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await equipo.auth.setInitialSession(jsonEncode(sesionJson(uidCasa, 'casa-0')));
      servicio = ServicioSesionSupabase(
        cliente: equipo,
        almacen: almacen,
        url: gotrue.url,
        llavePublica: 'llave-publica-de-prueba',
        lectorPerfil: (cliente) async => cliente.auth.currentUser?.id == uidCasa ? casa : dueno,
      );
      await servicio.iniciar();
    });

    tearDown(() async {
      await servicio.cerrar();
      await equipo.dispose();
      await gotrue.cerrar();
    });

    test(
      'el límite de peticiones (429) no destruye el permiso ni manda lo pendiente '
      'a "requiere atención"',
      () async {
        final servidor = ServidorFalso();
        final cola = ColaSinConexion(
          base: base,
          enviador: EnviadorDeSesion(servidor, () => servicio.personaEnServidor),
          reloj: () => ahora,
          personaConSesion: () => casa.persona.id,
          cuentaDelEquipo: () => casa.persona.id,
          salida: SalidaSinPinConSesiones(
            bandeja: bandeja,
            abrir: servicio.abrirSesionAparte,
            enviadorDe: (aparte) => EnviadorDeSesion(servidor, () => aparte.personaId),
          ),
        );
        await pendiente(cola);
        await delegar(jsonEncode(sesionJson(uidDueno, 'r0', vencida: true)));

        gotrue.estadoFijoAlRenovar = 429; // "Request rate limit reached"
        await cola.procesar();

        final permiso = await bandeja.leer(dueno.persona.id);
        final registro = (await cola.registros()).single;
        expect(
          (permiso?.estado, registro.estado),
          (EstadoPermiso.enEspera, EstadoPendiente.pendiente),
          reason:
              'con un 429 el servidor sigue ahí y la credencial sirve: debe '
              'reintentarse. Hoy abrirSesionAparte lo traduce a '
              'credencialVencida (servicio_sesion_supabase.dart:439-441), la '
              'cola borra el permiso y lo pendiente queda en "requiere '
              'atención" (${registro.ultimoError})',
        );

        // Cuando el límite se levanta, sube sola.
        gotrue.estadoFijoAlRenovar = null;
        ahora = ahora.add(const Duration(minutes: 5));
        await cola.procesar();
        expect(servidor.idsDe(dueno.persona.id), ['gasto-1']);
      },
    );

    test('control: un refresh token realmente revocado sí es credencial vencida',
        () async {
      gotrue.revocados.add('r0');
      await expectLater(
        servicio.abrirSesionAparte(
          dueno.persona.id,
          jsonEncode(sesionJson(uidDueno, 'r0', vencida: true)),
          alRenovar: (_) {},
        ),
        throwsA(ErrorSesion.credencialVencida),
      );
    });

    // ------------------------------------------------------------ B4
    test(
      'al caducar el permiso se revoca también la sesión en el servidor',
      () async {
        final servidor = ServidorFalso();
        final cola = ColaSinConexion(
          base: base,
          enviador: EnviadorDeSesion(servidor, () => servicio.personaEnServidor),
          reloj: () => ahora,
          personaConSesion: () => casa.persona.id,
          cuentaDelEquipo: () => casa.persona.id,
          salida: SalidaSinPinConSesiones(
            bandeja: bandeja,
            abrir: servicio.abrirSesionAparte,
            enviadorDe: (aparte) => EnviadorDeSesion(servidor, () => aparte.personaId),
          ),
        );
        await pendiente(cola);
        await delegar(jsonEncode(sesionJson(uidDueno, 'r0', vencida: true)));
        servidor.conSenal = false;
        ahora = ahora.add(const Duration(days: 7, minutes: 1));
        await cola.procesar();

        expect(await bandeja.leer(dueno.persona.id), isNull, reason: 'la copia local sí se borró');
        expect(
          gotrue.rutas,
          contains('POST /auth/v1/logout'),
          reason:
              'caducar borra la copia local, pero la sesión del dueño sigue '
              'viva en el servidor (los refresh tokens de Supabase no caducan '
              'por tiempo en el plan gratis): quien se hubiera llevado una copia '
              'en esos 7 días la conserva para siempre. Con señal, la app '
              'debería cerrar esa sesión al caducar o al descartar el permiso',
        );
      },
      tags: ['hallazgo'],
    );
  });

  // ---------------------------------------------------------------- B3
  test(
    'B3: una subida colgada no deja entrar a la persona con su PIN',
    () async {
      final servicio = ServicioSesionFalso(inicial: casa)..rotacionEstricta = true;
      final colgado = Completer<ResultadoEnvio>();
      final cola = ColaSinConexion(
        base: base,
        enviador: _Colgado(colgado),
        reloj: () => ahora,
        personaConSesion: () => casa.persona.id,
        cuentaDelEquipo: () => casa.persona.id,
        salida: SalidaSinPinConSesiones(
          bandeja: bandeja,
          abrir: servicio.abrirSesionAparte,
          enviadorDe: (aparte) => _Colgado(colgado),
        ),
      );
      await pendiente(cola);
      await delegar(ServicioSesionFalso.credencialDe(dueno));

      final subida = cola.procesar(); // el servidor no contesta nunca
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final entrada = bandeja.tomarParaEntrada(dueno.persona.id, pin);
      Object? resultado;
      try {
        await entrada.timeout(const Duration(seconds: 2));
      } on TimeoutException catch (e) {
        resultado = e;
      } finally {
        colgado.complete(ResultadoEnvio.enviado); // limpieza: suelta el candado
        await subida;
      }
      expect(
        resultado,
        isNull,
        reason:
            'la persona escribió su PIN y la tablet se quedó esperando a una '
            'subida que no termina (no hay tiempo máximo en ningún envío): el '
            'candado por persona de la bandeja nunca se suelta. Ni entrar, ni '
            'cambiar el PIN, ni quitarla de la tablet avanzan',
      );
    },
  );

  // ---------------------------------------------------------------- B5
  group('B5: volver a agregar a una persona con un permiso en espera', () {
    late AlmacenSeguroEnMemoria almacenTablet;
    late ServicioSesionFalso servicio;
    late ServidorFalso servidor;
    late ProviderContainer contenedor;
    late ControladorTablet tablet;
    late ColaSinConexion cola;
    late DateTime reloj;
    const pinViejo = '284651';
    const pinNuevo = '739150';

    setUp(() async {
      almacenTablet = AlmacenSeguroEnMemoria();
      servidor = ServidorFalso();
      reloj = DateTime.utc(2026, 10, 24, 10);
      servicio = ServicioSesionFalso(inicial: casa)..rotacionEstricta = true;
      contenedor = ProviderContainer(
        overrides: [
          almacenSeguroProvider.overrideWithValue(almacenTablet),
          servicioSesionProvider.overrideWithValue(servicio),
          biometriaProvider.overrideWithValue(BiometriaFalsa()),
          baseLocalProvider.overrideWithValue(base),
          relojSeguridadProvider.overrideWithValue(() => reloj),
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
              enviadorDe: (aparte) => EnviadorDeSesion(servidor, () => aparte.personaId),
            ),
          ),
        ],
      );
      addTearDown(contenedor.dispose);
      tablet = contenedor.read(controladorTabletProvider.notifier);
      await tablet.listo;
      cola = contenedor.read(colaSinConexionProvider);
      await tablet.agregarUsuario(
        dueno,
        pin: pinViejo,
        credencial: ServicioSesionFalso.credencialDe(dueno),
      );
    });

    test(
      'el permiso viejo no pisa la credencial nueva al entrar con el PIN nuevo',
      () async {
        expect(await tablet.entrarConPin(dueno.persona.id, pinViejo), ResultadoDesbloqueo.abierto);
        servicio.sinConexion = true;
        servidor.conSenal = false;
        await cola.encolar(tipo: 'finanzas.movimiento', carga: const {'monto_centavos': 100}, id: 'g1');
        await cola.procesar();
        tablet.volverAlReposo();
        await tablet.cambiosEnServidor;
        final permiso = await contenedor.read(bandejaDeSalidaProvider).leer(dueno.persona.id);
        expect(permiso?.estado, EstadoPermiso.enEspera, reason: 'salió con algo por subir');

        // La persona vuelve a registrarse en la tablet (correo y contraseña de
        // nuevo, PIN nuevo): hay una credencial nueva, de otra cadena.
        servicio.sinConexion = false;
        servidor.conSenal = true;
        await tablet.agregarUsuario(
          dueno,
          pin: pinNuevo,
          credencial: ServicioSesionFalso.credencialDe(dueno, vuelta: 9),
        );

        final resultado = await tablet.entrarConPin(dueno.persona.id, pinNuevo);
        expect(
          resultado,
          ResultadoDesbloqueo.abierto,
          reason:
              'agregarUsuario no toca el permiso de subida: al entrar, '
              'tomarParaEntrada devuelve la credencial VIEJA del permiso en '
              'espera (no necesita PIN) y se usa en lugar de la nueva '
              '(controlador_tablet.dart:318-329)',
        );
        final guardada = await RepositorioTablet(almacenTablet)
            .leerCredencial(dueno.persona.id, pinNuevo);
        expect(guardada?.$2, ServicioSesionFalso.credencialDe(dueno, vuelta: 10));
      },
    );
  });
}
