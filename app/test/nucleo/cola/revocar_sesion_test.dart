// B4 de la revisión de la Fase 1b: al caducar o descartar un permiso de subida
// de la bandeja de salida, la sesión de esa persona se cierra TAMBIÉN en el
// servidor (con señal) y, sin señal, la orden de cerrarla queda anotada aparte
// del permiso que se borra, con lo mínimo para revocar, hasta que se cumpla.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/bandeja_salida.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/revocaciones_pendientes.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_supabase.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../revision_calidad/ayuda_gotrue.dart';
import 'ayuda_bandeja.dart';

void main() {
  final dueno = sesionDeEjemplo(Rol.dueno);
  final pareja = sesionDeEjemplo(Rol.coadministrador);
  final casa = sesionDeEjemplo(Rol.casa);
  const pin = '284651';
  const secreto = 'rt-secreto-9f3a';

  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;
  late BandejaDeSalida bandeja;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    ahora = DateTime.utc(2026, 10, 24, 10);
    bandeja = BandejaDeSalida(almacen, reloj: () => ahora);
  });

  Future<void> delegar(Sesion sesion, {String? credencial}) => bandeja.delegar(
    sesion.persona.id,
    credencial ?? ServicioSesionFalso.credencialDe(sesion),
    LlavePin.derivar(pin, iteraciones: 10),
  );

  // ----------------------------------------------- las órdenes (RevocacionesPendientes)
  group('RevocacionesPendientes', () {
    late RevocacionesPendientes ordenes;
    final completa = jsonEncode(sesionJson(uidDueno, secreto));

    setUp(() => ordenes = RevocacionesPendientes(almacen, reloj: () => ahora));

    test('guarda solo lo mínimo para revocar: el refresh token', () async {
      await ordenes.anotar('persona-1', completa);

      final texto = almacen.datos.entries
          .singleWhere((e) => e.key.startsWith(RevocacionesPendientes.prefijo))
          .value;
      expect(texto, contains(secreto));
      expect(
        texto,
        isNot(contains('access_token')),
        reason: 'el token de acceso no hace falta para revocar',
      );
      expect(
        texto,
        isNot(contains('ejemplo.test')),
        reason: 'tampoco los datos del usuario',
      );
      final orden = (await ordenes.todas()).single;
      expect(orden.personaId, 'persona-1');
      expect(jsonDecode(orden.credencial), {'refresh_token': secreto});
      expect(orden.toString(), isNot(contains(secreto)));
    });

    test('anotar dos veces la misma sesión deja una sola orden', () async {
      await ordenes.anotar('persona-1', completa);
      await ordenes.anotar('persona-1', completa);
      await ordenes.anotar('persona-1', jsonEncode({'refresh_token': secreto}));
      expect(await ordenes.todas(), hasLength(1));
    });

    test('dos sesiones de la misma persona son dos órdenes', () async {
      await ordenes.anotar('persona-1', jsonEncode(sesionJson(uidDueno, 'a')));
      await ordenes.anotar('persona-1', jsonEncode(sesionJson(uidDueno, 'b')));
      expect(await ordenes.todas(), hasLength(2));
    });

    test('si el servidor la cierra, la orden y la credencial se borran', () async {
      await ordenes.anotar('persona-1', completa);
      final recibidas = <String>[];
      final resumen = await ordenes.ejecutar((credencial, {required alRenovar}) async {
        recibidas.add(credencial);
        return ResultadoRevocacion.cerrada;
      });
      expect((resumen.cerradas, resumen.pendientes), (1, 0));
      expect(recibidas.single, contains(secreto));
      expect(await ordenes.todas(), isEmpty);
      expect(
        almacen.datos.keys.where(
          (k) => k.startsWith(RevocacionesPendientes.prefijo),
        ),
        isEmpty,
        reason: 'no queda ningún secreto en el almacén',
      );
    });

    test('si no se pudo, la orden espera y se reintenta', () async {
      await ordenes.anotar('persona-1', completa);
      var intentos = 0;
      Future<ResultadoRevocacion> sinSenal(
        String credencial, {
        required void Function(String) alRenovar,
      }) async {
        intentos++;
        return ResultadoRevocacion.reintentar;
      }

      var resumen = await ordenes.ejecutar(sinSenal);
      expect((resumen.cerradas, resumen.pendientes), (0, 1));
      resumen = await ordenes.ejecutar(sinSenal);
      expect((intentos, resumen.pendientes), (2, 1));
      expect(await ordenes.todas(), hasLength(1));

      resumen = await ordenes.ejecutar(
        (c, {required alRenovar}) async => ResultadoRevocacion.cerrada,
      );
      expect((resumen.cerradas, await ordenes.todas()), (1, isEmpty));
    });

    test('una red que no contesta no atora: tiempo máximo y las demás esperan', () async {
      await ordenes.anotar('persona-1', jsonEncode(sesionJson(uidDueno, 'a')));
      await ordenes.anotar('persona-2', jsonEncode(sesionJson(uidDueno, 'b')));
      var intentos = 0;
      final resumen = await ordenes.ejecutar((c, {required alRenovar}) {
        intentos++;
        return Completer<ResultadoRevocacion>().future; // nunca contesta
      }, tiempoMaximo: const Duration(milliseconds: 50));
      expect(intentos, 1, reason: 'tras un tiempo agotado no insiste en la ronda');
      expect((resumen.cerradas, resumen.pendientes), (0, 2));
      expect(await ordenes.todas(), hasLength(2));
    });

    test('el refresh token que el servidor rota se guarda en lugar del anterior', () async {
      await ordenes.anotar('persona-1', completa);
      await ordenes.ejecutar((c, {required alRenovar}) async {
        alRenovar(jsonEncode(sesionJson(uidDueno, 'rotado-2')));
        return ResultadoRevocacion.reintentar;
      });
      final orden = (await ordenes.todas()).single;
      expect(jsonDecode(orden.credencial), {'refresh_token': 'rotado-2'});
      expect(
        almacen.datos.values.join(),
        isNot(contains(secreto)),
        reason: 'el token viejo ya no se conserva',
      );
    });

    test('una renovación que llega tarde no resucita una orden cumplida', () async {
      await ordenes.anotar('persona-1', completa);
      await ordenes.ejecutar((c, {required alRenovar}) async {
        Future<void>.delayed(
          const Duration(milliseconds: 20),
          () => alRenovar(jsonEncode(sesionJson(uidDueno, 'tarde'))),
        );
        return ResultadoRevocacion.cerrada;
      });
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(await ordenes.todas(), isEmpty);
    });

    test('pasado el plazo se abandona y se borra: no se guarda un secreto para siempre', () async {
      await ordenes.anotar('persona-1', completa);
      ahora = ahora.add(plazoParaRevocar + const Duration(minutes: 1));
      var llamadas = 0;
      final resumen = await ordenes.ejecutar((c, {required alRenovar}) async {
        llamadas++;
        return ResultadoRevocacion.cerrada;
      });
      expect((resumen.abandonadas, llamadas), (1, 0));
      expect(await ordenes.todas(), isEmpty);
      expect(almacen.datos, isEmpty);
    });

    test('una orden dañada se borra sin usarla', () async {
      almacen.datos['${RevocacionesPendientes.prefijo}persona-1.x'] = 'no es json';
      expect(await ordenes.todas(), isEmpty);
      expect(almacen.datos, isEmpty);
    });

    test('dos vueltas a la vez son una sola', () async {
      await ordenes.anotar('persona-1', completa);
      var llamadas = 0;
      final gate = Completer<void>();
      Future<ResultadoRevocacion> lento(
        String c, {
        required void Function(String) alRenovar,
      }) async {
        llamadas++;
        await gate.future;
        return ResultadoRevocacion.cerrada;
      }

      final a = ordenes.ejecutar(lento);
      final b = ordenes.ejecutar(lento);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      await Future.wait([a, b]);
      expect(llamadas, 1);
    });
  });

  // -------------------------------------- cuándo se anota la orden (BandejaDeSalida)
  group('BandejaDeSalida anota la orden de revocar', () {
    test('al caducar el permiso', () async {
      await delegar(dueno);
      ahora = ahora.add(vigenciaDelPermisoDeSubida + const Duration(minutes: 1));
      expect(await bandeja.caducar(), [dueno.persona.id]);
      expect(await bandeja.leer(dueno.persona.id), isNull);
      final orden = (await bandeja.revocaciones.todas()).single;
      expect(orden.personaId, dueno.persona.id);
      expect(orden.credencial, ServicioSesionFalso.credencialDe(dueno));
    });

    test('un permiso vigente no se revoca', () async {
      await delegar(dueno);
      ahora = ahora.add(const Duration(days: 6));
      expect(await bandeja.caducar(), isEmpty);
      expect(await bandeja.revocaciones.todas(), isEmpty);
    });

    test('al descartarlo a mano (quitar a la persona o volver a agregarla)', () async {
      await delegar(dueno);
      await bandeja.descartarPermiso(dueno.persona.id);
      expect(await bandeja.leer(dueno.persona.id), isNull);
      expect(await bandeja.revocaciones.todas(), hasLength(1));
    });

    test('idempotente: descartar o caducar otra vez no duplica ni inventa órdenes', () async {
      await delegar(dueno);
      await bandeja.descartarPermiso(dueno.persona.id);
      await bandeja.descartarPermiso(dueno.persona.id);
      ahora = ahora.add(const Duration(days: 9));
      await bandeja.caducar();
      expect(await bandeja.revocaciones.todas(), hasLength(1));
    });

    test('un permiso sellado no se revoca: no hay credencial en claro', () async {
      await delegar(dueno);
      await bandeja.sellarTodos();
      await bandeja.descartarPermiso(dueno.persona.id);
      expect(await bandeja.revocaciones.todas(), isEmpty);
    });

    test('entrar con el PIN se lleva la credencial y NO la revoca', () async {
      await delegar(dueno);
      expect(
        await bandeja.tomarParaEntrada(dueno.persona.id, pin),
        ServicioSesionFalso.credencialDe(dueno),
      );
      expect(await bandeja.revocaciones.todas(), isEmpty);
    });

    test('la orden queda aunque el permiso ya se haya borrado', () async {
      await delegar(dueno);
      ahora = ahora.add(const Duration(days: 8));
      await bandeja.caducar();
      // Otra bandeja sobre el mismo almacén (la app se reinició).
      final otra = BandejaDeSalida(almacen, reloj: () => ahora);
      expect(await otra.leer(dueno.persona.id), isNull);
      expect(await otra.revocaciones.todas(), hasLength(1));
    });
  });

  // ---------------------------------- con la cola y un servicio falso (sin servidor)
  group('la cola cierra la sesión al caducar o descartar', () {
    late BaseLocal base;
    late ServicioSesionFalso servicio;
    late ServidorFalso servidor;
    late ColaSinConexion cola;
    String? persona;

    ColaSinConexion crearCola({SalidaSinPin? salida}) => ColaSinConexion(
      base: base,
      enviador: EnviadorDeSesion(servidor, () => servicio.personaEnServidor),
      reloj: () => ahora,
      personaConSesion: () => persona,
      cuentaDelEquipo: () => casa.persona.id,
      salida:
          salida ??
          SalidaSinPinConSesiones(
            bandeja: bandeja,
            abrir: servicio.abrirSesionAparte,
            revocar: servicio.revocarSesion,
            enviadorDe: (aparte) =>
                EnviadorDeSesion(servidor, () => aparte.personaId),
          ),
    );

    Future<void> pendiente(Sesion de, String id) => cola.encolar(
      tipo: 'finanzas.movimiento',
      carga: const {'monto_centavos': 100},
      id: id,
      personaId: de.persona.id,
    );

    setUp(() {
      base = BaseLocal.enMemoria();
      servidor = ServidorFalso();
      servicio = ServicioSesionFalso(inicial: casa);
      persona = casa.persona.id;
      cola = crearCola();
    });

    tearDown(() => base.close());

    test('sin señal caduca igual, no revoca y deja la orden; con señal la cumple una sola vez', () async {
      await pendiente(dueno, 'g1');
      await delegar(dueno);
      servicio.sinConexion = true;
      servidor.conSenal = false;
      ahora = ahora.add(const Duration(days: 7, minutes: 1));

      await cola.procesar();
      expect(
        await bandeja.leer(dueno.persona.id),
        isNull,
        reason: 'caducar no espera a la red',
      );
      expect(servicio.credencialesRevocadas, isEmpty);
      expect(
        servicio.vecesRevocar,
        1,
        reason: 'lo intentó y no pudo: la orden sigue',
      );
      expect(await bandeja.revocaciones.todas(), hasLength(1));
      expect(
        (await cola.registros()).single.estado,
        EstadoPendiente.rechazado,
        reason: 'lo pendiente pasa a "requiere atención" como siempre',
      );

      // Vuelve la señal: la siguiente ronda cierra la sesión.
      servicio.sinConexion = false;
      servidor.conSenal = true;
      await cola.procesar();
      expect(servicio.credencialesRevocadas, [
        ServicioSesionFalso.credencialDe(dueno),
      ]);
      expect(await bandeja.revocaciones.todas(), isEmpty);

      // Idempotente: otra ronda no vuelve a cerrarla.
      await cola.procesar();
      await cola.procesar();
      expect(servicio.credencialesRevocadas, hasLength(1));
    });

    test('con señal, al caducar cierra la sesión en la misma ronda', () async {
      await pendiente(dueno, 'g1');
      await delegar(dueno);
      ahora = ahora.add(const Duration(days: 8));
      await cola.procesar();
      expect(servicio.credencialesRevocadas, hasLength(1));
      expect(await bandeja.revocaciones.todas(), isEmpty);
    });

    test('también corre sin sesión abierta en la tablet (B1)', () async {
      await pendiente(dueno, 'g1');
      await delegar(dueno);
      persona = null; // la cuenta del equipo cerró sesión
      ahora = ahora.add(const Duration(days: 8));
      await cola.procesar();
      expect(servicio.credencialesRevocadas, hasLength(1));
    });

    test('descarte manual: quitar a la persona de la tablet cierra su sesión', () async {
      await pendiente(dueno, 'g1');
      await delegar(dueno);
      final tablet = BandejaDeLaTabletConCola(bandeja, () => cola);
      await tablet.alQuitarPersona(dueno.persona.id);
      expect(await bandeja.leer(dueno.persona.id), isNull);
      expect(servicio.credencialesRevocadas, isEmpty, reason: 'aún no hubo ronda');

      await cola.procesar();
      expect(servicio.credencialesRevocadas, [
        ServicioSesionFalso.credencialDe(dueno),
      ]);
    });

    test('descarte manual: volver a agregar a la persona cierra la sesión vieja', () async {
      await delegar(dueno);
      final tablet = BandejaDeLaTabletConCola(bandeja, () => cola);
      await tablet.alAgregarDeNuevo(dueno.persona.id);
      await cola.procesar();
      expect(servicio.credencialesRevocadas, hasLength(1));
    });

    test('no cierra la sesión de otra persona ni la de un permiso vigente', () async {
      await delegar(dueno);
      // Solo el del dueño caduca: el de la pareja se crea 5 días después.
      ahora = ahora.add(const Duration(days: 5));
      await delegar(pareja);
      ahora = ahora.add(const Duration(days: 3));
      await cola.procesar();

      expect(servicio.credencialesRevocadas, [
        ServicioSesionFalso.credencialDe(dueno),
      ]);
      final vigente = await bandeja.leer(pareja.persona.id);
      expect(vigente?.credencial, isNotNull, reason: 'la de la pareja sigue');
    });

    test('un permiso que se sube y se sella con normalidad no genera órdenes', () async {
      await pendiente(dueno, 'g1');
      await delegar(dueno);
      await cola.procesar();
      expect(servidor.idsDe(dueno.persona.id), ['g1']);
      expect(await bandeja.revocaciones.todas(), isEmpty);
      expect(servicio.vecesRevocar, 0);
    });

    test('si revocar falla con una excepción, la ronda no se rompe', () async {
      await pendiente(dueno, 'g1');
      await delegar(dueno);
      ahora = ahora.add(const Duration(days: 8));
      final cola2 = crearCola(
        salida: SalidaSinPinConSesiones(
          bandeja: bandeja,
          abrir: servicio.abrirSesionAparte,
          revocar: (c, {required alRenovar}) async =>
              throw StateError('se cayó'),
          enviadorDe: (aparte) =>
              EnviadorDeSesion(servidor, () => aparte.personaId),
        ),
      );
      final resumen = await cola2.procesar();
      expect(resumen.rechazados, 1);
      expect(await bandeja.revocaciones.todas(), hasLength(1));
    });
  });

  // -------------------- con Supabase de verdad (GoTrue simulado en este equipo)
  group('ServicioSesionSupabase.revocarSesion', () {
    late GoTrueSimulado gotrue;
    late SupabaseClient equipo;
    late ServicioSesionSupabase servicio;
    late List<String> impresos;
    late DebugPrintCallback impresoOriginal;

    setUp(() async {
      impresos = [];
      impresoOriginal = debugPrint;
      debugPrint = (String? mensaje, {int? wrapWidth}) =>
          impresos.add(mensaje ?? '');
      gotrue = GoTrueSimulado();
      await gotrue.abrir();
      equipo = SupabaseClient(
        gotrue.url,
        'llave-publica-de-prueba',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await equipo.auth.setInitialSession(
        jsonEncode(sesionJson(uidCasa, 'casa-0')),
      );
      servicio = ServicioSesionSupabase(
        cliente: equipo,
        almacen: almacen,
        url: gotrue.url,
        llavePublica: 'llave-publica-de-prueba',
        lectorPerfil: (cliente) async =>
            cliente.auth.currentUser?.id == uidCasa ? casa : dueno,
      );
      await servicio.iniciar();
    });

    tearDown(() async {
      debugPrint = impresoOriginal;
      await servicio.cerrar();
      await equipo.dispose();
      await gotrue.cerrar();
    });

    final credencialDelDueno = jsonEncode(
      sesionJson(uidDueno, secreto, vencida: true),
    );

    test('con señal cierra SOLO esa sesión: alcance local, con el token de esa persona', () async {
      final renovadas = <String>[];
      final resultado = await servicio.revocarSesion(
        credencialDelDueno,
        alRenovar: renovadas.add,
      );

      expect(resultado, ResultadoRevocacion.cerrada);
      expect(gotrue.renovados, [secreto]);
      expect(
        gotrue.cierres,
        [(scope: 'local', usuario: uidDueno)],
        reason:
            'alcance local: no cierra las otras sesiones del dueño (teléfono, '
            'laptop) ni la de la cuenta Casa',
      );
      expect(
        equipo.auth.currentSession?.user.id,
        uidCasa,
        reason: 'la sesión del equipo sigue abierta',
      );
      expect(servicio.personaEnServidor, casa.persona.id);
      expect(renovadas, hasLength(1));
      expect(jsonDecode(renovadas.single), {'refresh_token': 'renovado-1'});
    });

    test('sirve con la credencial mínima de la orden (solo el refresh token)', () async {
      final resultado = await servicio.revocarSesion(
        credencialMinima(credencialDelDueno),
        alRenovar: (_) {},
      );
      expect(resultado, ResultadoRevocacion.cerrada);
      expect(gotrue.cierres, hasLength(1));
    });

    test('sin señal no cierra nada y pide reintentar', () async {
      gotrue.sinRespuesta = true;
      final resultado = await servicio.revocarSesion(
        credencialDelDueno,
        alRenovar: (_) {},
      );
      expect(resultado, ResultadoRevocacion.reintentar);
      expect(gotrue.cierres, isEmpty);

      gotrue.sinRespuesta = false;
      expect(
        await servicio.revocarSesion(credencialDelDueno, alRenovar: (_) {}),
        ResultadoRevocacion.cerrada,
      );
      expect(gotrue.cierres, hasLength(1));
    });

    test('si el servidor ya no conoce el refresh token, no hay nada que revocar', () async {
      gotrue.revocados.add(secreto);
      final resultado = await servicio.revocarSesion(
        credencialDelDueno,
        alRenovar: (_) {},
      );
      expect(resultado, ResultadoRevocacion.cerrada);
      expect(gotrue.cierres, isEmpty);
    });

    test('el límite de peticiones (429) no cuenta como cerrada: se reintenta', () async {
      gotrue.estadoFijoAlRenovar = 429;
      expect(
        await servicio.revocarSesion(credencialDelDueno, alRenovar: (_) {}),
        ResultadoRevocacion.reintentar,
      );
      gotrue.estadoFijoAlRenovar = 503;
      expect(
        await servicio.revocarSesion(credencialDelDueno, alRenovar: (_) {}),
        ResultadoRevocacion.reintentar,
      );
      expect(gotrue.cierres, isEmpty);
    });

    test('si el cierre falla (500) se reintenta con el refresh token ya rotado', () async {
      gotrue.estadoFijoAlCerrar = 500;
      final renovadas = <String>[];
      expect(
        await servicio.revocarSesion(
          credencialDelDueno,
          alRenovar: renovadas.add,
        ),
        ResultadoRevocacion.reintentar,
      );
      expect(jsonDecode(renovadas.single), {'refresh_token': 'renovado-1'});

      gotrue.estadoFijoAlCerrar = null;
      expect(
        await servicio.revocarSesion(renovadas.single, alRenovar: (_) {}),
        ResultadoRevocacion.cerrada,
      );
      expect(gotrue.renovados, [secreto, 'renovado-1']);
    });

    test('un 401 al cerrar significa que la sesión ya no existe: cerrada', () async {
      gotrue.estadoFijoAlCerrar = 401;
      expect(
        await servicio.revocarSesion(credencialDelDueno, alRenovar: (_) {}),
        ResultadoRevocacion.cerrada,
      );
    });

    test('una credencial que no es una sesión no llega al servidor', () async {
      expect(
        await servicio.revocarSesion('basura', alRenovar: (_) {}),
        ResultadoRevocacion.cerrada,
      );
      expect(
        await servicio.revocarSesion('{"otra":1}', alRenovar: (_) {}),
        ResultadoRevocacion.cerrada,
      );
      expect(gotrue.rutas, isEmpty);
    });

    test('nunca imprime ni registra tokens', () async {
      gotrue.estadoFijoAlCerrar = 500;
      await servicio.revocarSesion(credencialDelDueno, alRenovar: (_) {});
      gotrue.estadoFijoAlCerrar = null;
      gotrue.estadoFijoAlRenovar = 429;
      await servicio.revocarSesion(credencialDelDueno, alRenovar: (_) {});
      gotrue.estadoFijoAlRenovar = null;
      gotrue.sinRespuesta = true;
      await servicio.revocarSesion(credencialDelDueno, alRenovar: (_) {});

      final todo = impresos.join('\n');
      expect(todo, isNot(contains(secreto)));
      expect(todo, isNot(contains('renovado-')));
      expect(todo, isNot(contains('eyJ')), reason: 'ningún JWT');
    });

    test('de punta a punta: sin señal caduca, queda la orden; con señal se cierra una vez', () async {
      final base = BaseLocal.enMemoria();
      addTearDown(base.close);
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
          revocar: servicio.revocarSesion,
          enviadorDe: (aparte) =>
              EnviadorDeSesion(servidor, () => aparte.personaId),
        ),
      );
      await cola.encolar(
        tipo: 'finanzas.movimiento',
        carga: const {'monto_centavos': 100},
        id: 'g1',
        personaId: dueno.persona.id,
      );
      await delegar(dueno, credencial: credencialDelDueno);

      gotrue.sinRespuesta = true;
      ahora = ahora.add(vigenciaDelPermisoDeSubida + const Duration(minutes: 1));
      await cola.procesar();
      expect(await bandeja.leer(dueno.persona.id), isNull);
      expect(gotrue.cierres, isEmpty);
      final orden = (await bandeja.revocaciones.todas()).single;
      expect(
        jsonDecode(orden.credencial),
        {'refresh_token': secreto},
        reason: 'solo lo mínimo para revocar',
      );

      gotrue.sinRespuesta = false;
      await cola.procesar();
      expect(gotrue.cierres, [(scope: 'local', usuario: uidDueno)]);
      expect(await bandeja.revocaciones.todas(), isEmpty);
      expect(
        almacen.datos.keys.where((k) => k.startsWith('bandeja.')),
        isEmpty,
        reason: 'no queda ni permiso ni orden ni credencial en el almacén',
      );

      await cola.procesar();
      expect(gotrue.cierres, hasLength(1), reason: 'idempotente');
      expect(equipo.auth.currentSession?.user.id, uidCasa);
    });
  });
}
