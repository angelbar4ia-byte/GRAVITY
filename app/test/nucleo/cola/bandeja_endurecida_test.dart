// Endurecimiento de la bandeja de salida (revisión de la Fase 1b, B1, B2, B3 y
// B5, `docs/revisiones/fase-1b.md`): la caducidad corre sin sesión, al cerrar
// la cuenta del equipo no queda una credencial en claro, un error pasajero no
// destruye el permiso, una subida colgada no bloquea a la persona y volver a
// agregarla no deja el permiso viejo.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/bandeja_salida.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
import 'package:gravity/nucleo/seguridad/limpieza_local.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/errores_red.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ayuda_bandeja.dart';

const pin = '284651';

void main() {
  final dueno = sesionDeEjemplo(Rol.dueno);
  final pareja = sesionDeEjemplo(Rol.coadministrador);
  final casa = sesionDeEjemplo(Rol.casa);

  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;
  late BandejaDeSalida bandeja;
  late BaseLocal base;
  late ServidorFalso servidor;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    ahora = DateTime.utc(2026, 10, 30, 10);
    bandeja = BandejaDeSalida(almacen, reloj: () => ahora);
    base = BaseLocal.enMemoria();
    servidor = ServidorFalso();
  });

  tearDown(() => base.close());

  Future<void> delegar(Sesion sesion, {int vuelta = 0}) => bandeja.delegar(
    sesion.persona.id,
    ServicioSesionFalso.credencialDe(sesion, vuelta: vuelta),
    LlavePin.derivar(pin, iteraciones: 10),
  );

  group('B1: nada en claro con la cuenta del equipo cerrada', () {
    test('sellarTodos sella lo que está en claro y deja lo sellado como estaba', () async {
      await delegar(dueno, vuelta: 3);
      await delegar(pareja, vuelta: 1);
      await bandeja.sellarYDevolver(
        pareja.persona.id,
        ServicioSesionFalso.credencialDe(pareja, vuelta: 1),
      );
      final sobreDePareja = (await bandeja.leer(pareja.persona.id))!.sobre;

      await bandeja.sellarTodos();

      for (final permiso in await bandeja.todos()) {
        expect(permiso.estado, EstadoPermiso.devuelto);
        expect(permiso.credencial, isNull);
      }
      expect((await bandeja.leer(pareja.persona.id))!.sobre, sobreDePareja);
      expect(
        almacen.datos.values.join('\n'),
        isNot(contains('falsa:3')),
        reason: 'la credencial del dueño ya no está en claro',
      );
      // Solo el PIN la recupera, y es la más reciente.
      expect(await bandeja.tomarParaEntrada(dueno.persona.id, '000000'), isNull);
      expect(
        await bandeja.tomarParaEntrada(dueno.persona.id, pin),
        ServicioSesionFalso.credencialDe(dueno, vuelta: 3),
      );
    });

    test('sin permisos no hace nada', () async {
      await bandeja.sellarTodos();
      expect(await bandeja.todos(), isEmpty);
    });

    test('LimpiezaLocal.alCerrarElEquipo sella y no lanza aunque el almacén falle',
        () async {
      await delegar(dueno);
      final limpieza = LimpiezaLocal(almacen, bandeja: bandeja);
      await limpieza.alCerrarElEquipo();
      expect((await bandeja.leer(dueno.persona.id))!.estado, EstadoPermiso.devuelto);

      final rota = LimpiezaLocal(_AlmacenQueFalla());
      await rota.alCerrarElEquipo();
    });

    test('la limpieza y la subida comparten la misma bandeja (un solo candado)', () {
      final contenedor = ProviderContainer(
        overrides: [almacenSeguroProvider.overrideWithValue(almacen)],
      );
      addTearDown(contenedor.dispose);
      expect(
        identical(
          contenedor.read(limpiezaLocalProvider).bandeja,
          contenedor.read(bandejaDeSalidaProvider),
        ),
        isTrue,
      );
    });

    test('la caducidad corre aunque nadie tenga la sesión abierta; lo pendiente '
        'pasa a "requiere atención"', () async {
      final cola = ColaSinConexion(
        base: base,
        enviador: EnviadorDeSesion(servidor, () => null),
        reloj: () => ahora,
        personaConSesion: () => null,
        salida: SalidaSinPinConSesiones(
          bandeja: bandeja,
          abrir: ServicioSesionFalso(inicial: casa).abrirSesionAparte,
          enviadorDe: (_) => EnviadorDeSesion(servidor, () => null),
        ),
      );
      await cola.encolar(
        tipo: 'finanzas.movimiento',
        carga: const {'monto_centavos': 100},
        id: 'g1',
        personaId: dueno.persona.id,
      );
      await delegar(dueno);

      ahora = ahora.add(const Duration(days: 6));
      await cola.procesar();
      expect(await bandeja.leer(dueno.persona.id), isNotNull, reason: 'aún no vence');

      ahora = ahora.add(const Duration(days: 2));
      final resumen = await cola.procesar();
      expect(await bandeja.leer(dueno.persona.id), isNull);
      expect(resumen.rechazados, 1);
      final registro = (await cola.registros()).single;
      expect(registro.estado, EstadoPendiente.rechazado);
      expect(registro.ultimoError, motivoBandejaCaducada);
      expect(servidor.recibidos, isEmpty, reason: 'sin sesión no se sube nada');
    });
  });

  group('B2: solo un error claro destruye la credencial', () {
    AuthException api(int estado, [String? codigo]) =>
        AuthApiException('x', statusCode: '$estado', code: codigo);

    test('credencialYaNoSirve: 4xx del servidor sí; 408, 429, 5xx, red e inesperados no', () {
      for (final estado in [400, 401, 403, 404, 422]) {
        expect(credencialYaNoSirve(api(estado)), isTrue, reason: '$estado');
      }
      expect(credencialYaNoSirve(api(400, 'refresh_token_not_found')), isTrue);
      expect(credencialYaNoSirve(api(400, 'refresh_token_already_used')), isTrue);
      for (final estado in [408, 429]) {
        expect(credencialYaNoSirve(api(estado)), isFalse, reason: '$estado');
      }
      expect(credencialYaNoSirve(api(429, 'over_request_rate_limit')), isFalse);
      expect(credencialYaNoSirve(AuthRetryableFetchException(statusCode: '503')), isFalse);
      expect(credencialYaNoSirve(api(500)), isFalse);
      expect(credencialYaNoSirve(const AuthApiException('x')), isFalse);
      expect(credencialYaNoSirve(TimeoutException('x')), isFalse);
      expect(credencialYaNoSirve(StateError('inesperado')), isFalse);
      expect(credencialYaNoSirve(const FormatException('x')), isFalse);
    });

    Future<SesionDeSubida?> abrirConError(ErrorSesion error) async {
      await delegar(dueno);
      final salida = SalidaSinPinConSesiones(
        bandeja: bandeja,
        abrir: (_, _, {required alRenovar}) async => throw error,
        enviadorDe: (_) => EnviadorDeSesion(servidor, () => null),
      );
      return salida.abrir(dueno.persona.id);
    }

    test('sin señal, servidor ocupado o un error genérico: se reintenta y el '
        'permiso se queda', () async {
      for (final error in [
        ErrorSesion.sinConexion,
        ErrorSesion.servidorOcupado,
        const ErrorSesion('No se pudo entrar. Intenta de nuevo.'),
      ]) {
        expect(await abrirConError(error), isNull, reason: error.mensaje);
        final permiso = await bandeja.leer(dueno.persona.id);
        expect(permiso?.estado, EstadoPermiso.enEspera, reason: error.mensaje);
        // Y el candado quedó libre.
        await bandeja.conCandado(dueno.persona.id, () async {}).timeout(
          const Duration(seconds: 2),
        );
      }
    });

    test('credencial vencida o dada de baja: sí lanza (la cola descarta el permiso)',
        () async {
      for (final error in [ErrorSesion.credencialVencida, ErrorSesion.sinRol]) {
        await expectLater(abrirConError(error), throwsA(error));
      }
    });

    test('la cola no descarta el permiso con un error pasajero y reintenta después',
        () async {
      var falla = true;
      final servicio = ServicioSesionFalso(inicial: casa);
      final salida = SalidaSinPinConSesiones(
        bandeja: bandeja,
        abrir: (persona, credencial, {required alRenovar}) async {
          if (falla) throw ErrorSesion.servidorOcupado;
          return servicio.abrirSesionAparte(persona, credencial, alRenovar: alRenovar);
        },
        enviadorDe: (aparte) => EnviadorDeSesion(servidor, () => aparte.personaId),
      );
      final cola = ColaSinConexion(
        base: base,
        enviador: EnviadorDeSesion(servidor, () => casa.persona.id),
        reloj: () => ahora,
        personaConSesion: () => casa.persona.id,
        salida: salida,
      );
      await cola.encolar(
        tipo: 'finanzas.movimiento',
        carga: const {'monto_centavos': 100},
        id: 'g1',
        personaId: dueno.persona.id,
      );
      await delegar(dueno);

      await cola.procesar();
      expect((await bandeja.leer(dueno.persona.id))?.estado, EstadoPermiso.enEspera);
      expect((await cola.registros()).single.estado, EstadoPendiente.pendiente);

      falla = false;
      await cola.procesar();
      expect(servidor.idsDe(dueno.persona.id), ['g1']);
    });
  });

  group('B3: una subida colgada no bloquea', () {
    test('un envío que no contesta se toma como falta de respuesta y la ronda sigue',
        () async {
      final colgado = Completer<ResultadoEnvio>();
      final cola = ColaSinConexion(
        base: base,
        enviador: _Colgado(colgado),
        reloj: () => ahora,
        tiempoMaximoDeEnvio: const Duration(milliseconds: 50),
      );
      await cola.encolar(tipo: 'finanzas.movimiento', carga: const {}, id: 'g1');
      final resumen = await cola.procesar().timeout(const Duration(seconds: 5));
      expect(resumen.reintentos, 1);
      final registro = (await cola.registros()).single;
      expect(registro.estado, EstadoPendiente.pendiente);
      expect(registro.ultimoError, contains('TimeoutException'));
      colgado.complete(ResultadoEnvio.enviado);
    });

    test('entrar con el PIN interrumpe la subida; la siguiente ronda la reanuda sin '
        'duplicar', () async {
      final servicio = ServicioSesionFalso(inicial: casa)..rotacionEstricta = true;
      final espera = Completer<void>();
      final cola = ColaSinConexion(
        base: base,
        enviador: EnviadorDeSesion(servidor, () => casa.persona.id),
        reloj: () => ahora,
        personaConSesion: () => casa.persona.id,
        salida: SalidaSinPinConSesiones(
          bandeja: bandeja,
          abrir: servicio.abrirSesionAparte,
          enviadorDe: (aparte) =>
              _Lento(espera.future, servidor, aparte.personaId),
        ),
      );
      await cola.encolar(
        tipo: 'finanzas.movimiento',
        carga: const {'monto_centavos': 100},
        id: 'g1',
        personaId: dueno.persona.id,
      );
      await delegar(dueno);

      final ronda = cola.procesar();
      await pumpEventQueue();
      final credencial = await bandeja
          .tomarParaEntrada(dueno.persona.id, pin)
          .timeout(const Duration(seconds: 2));
      expect(credencial, isNotNull, reason: 'no esperó al servidor');
      await ronda;
      final registro = (await cola.registros()).single;
      expect(registro.estado, EstadoPendiente.pendiente);
      expect(registro.intentos, 0, reason: 'ceder el turno no es un fallo');

      // La persona entró y salió: la subida normal lo manda una sola vez.
      espera.complete();
      await pumpEventQueue();
      servidor.recibidos.clear();
      await bandeja.delegar(dueno.persona.id, credencial!, LlavePin.derivar(pin, iteraciones: 10));
      await cola.procesar();
      expect(servidor.idsDe(dueno.persona.id).where((id) => id == 'g1'), hasLength(1));
    });

    test('quitar o cambiar el PIN también piden el turno con urgencia', () async {
      await delegar(dueno);
      final soltar = await bandeja.adquirir(dueno.persona.id);
      var pedido = false;
      unawaited(bandeja.turnoPedido(dueno.persona.id).then((_) => pedido = true));
      final cambio = bandeja.cambiarPin(dueno.persona.id, pin, '739150');
      await pumpEventQueue();
      expect(pedido, isTrue);
      soltar();
      expect(await cambio, isTrue);

      final soltar2 = await bandeja.adquirir(dueno.persona.id);
      pedido = false;
      final borrar = bandeja.descartarPermiso(dueno.persona.id);
      await pumpEventQueue();
      expect(bandeja.turnoPedidoYa(dueno.persona.id), isTrue);
      soltar2();
      await borrar;
      expect(await bandeja.leer(dueno.persona.id), isNull);
    });

    test('un turno ya pedido: la subida no empieza otro envío', () async {
      final soltar = await bandeja.adquirir(dueno.persona.id);
      final urgente = bandeja.conCandado(dueno.persona.id, urgente: true, () async {});
      await pumpEventQueue();
      final envio = _EnviadorContador();
      final cede = EnviadorQueCede(envio, bandeja, dueno.persona.id);
      final r = await cede.enviar(
        PeticionEnvio(
          id: 'x',
          tipo: 't',
          carga: const {},
          creadoEn: ahora,
          intento: 1,
        ),
      );
      expect(r, ResultadoEnvio.sinSesion);
      expect(envio.llamadas, 0, reason: 'ni siquiera se mandó');
      soltar();
      await urgente;
    });
  });

  group('B5: volver a agregar a la persona', () {
    test('descartarPermiso borra el permiso en espera y el sellado', () async {
      await delegar(dueno);
      await delegar(pareja);
      await bandeja.sellarYDevolver(
        pareja.persona.id,
        ServicioSesionFalso.credencialDe(pareja),
      );
      await bandeja.descartarPermiso(dueno.persona.id);
      await bandeja.descartarPermiso(pareja.persona.id);
      expect(await bandeja.todos(), isEmpty);
      // Sin permiso, no pasa nada.
      await bandeja.descartarPermiso(dueno.persona.id);
    });

    test('alAgregarDeNuevo borra el permiso y deja lo pendiente en su sitio', () async {
      final cola = ColaSinConexion(
        base: base,
        enviador: EnviadorDeSesion(servidor, () => casa.persona.id),
        reloj: () => ahora,
      );
      final tablet = BandejaDeLaTabletConCola(bandeja, () => cola);
      await cola.encolar(
        tipo: 'finanzas.movimiento',
        carga: const {'monto_centavos': 100},
        id: 'g1',
        personaId: dueno.persona.id,
      );
      await delegar(dueno);
      await tablet.alAgregarDeNuevo(dueno.persona.id);
      expect(await bandeja.leer(dueno.persona.id), isNull);
      expect((await cola.registros()).single.estado, EstadoPendiente.pendiente);
      // Quitar, en cambio, sí manda lo pendiente a "requiere atención".
      await delegar(dueno);
      await tablet.alQuitarPersona(dueno.persona.id);
      expect((await cola.registros()).single.estado, EstadoPendiente.rechazado);
    });
  });
}

class _Colgado implements Enviador {
  _Colgado(this.espera);

  final Completer<ResultadoEnvio> espera;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) => espera.future;
}

class _Lento implements Enviador {
  _Lento(this.pausa, this.servidor, this.personaId);

  final Future<void> pausa;
  final ServidorFalso servidor;
  final String personaId;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    await pausa;
    servidor.recibidos.add((id: peticion.id, sesionDe: personaId));
    return ResultadoEnvio.enviado;
  }
}

class _EnviadorContador implements Enviador {
  int llamadas = 0;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    llamadas++;
    return ResultadoEnvio.enviado;
  }
}

class _AlmacenQueFalla implements AlmacenSeguro {
  @override
  Future<String?> leer(String clave) async => throw StateError('no se pudo');

  @override
  Future<void> escribir(String clave, String valor) async =>
      throw StateError('no se pudo');

  @override
  Future<void> borrar(String clave) async => throw StateError('no se pudo');

  @override
  Future<List<String>> claves() async => throw StateError('no se pudo');
}
