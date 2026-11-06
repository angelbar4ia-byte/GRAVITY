// Bandeja de salida sin PIN (D14, decisión del dueño del 23/oct/2026): lo
// registrado con nombre y PIN y sin señal se sube solo al haber señal, con el
// token de esa persona (nunca el de la cuenta Hogar/Casa), sin volver a pedir
// el PIN. La credencial sale del sobre del PIN solo mientras hay algo por
// subir, se sella al terminar y caduca a los 7 días.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/bandeja_salida.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/cifrado.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import 'ayuda_bandeja.dart';

void main() {
  final dueno = sesionDeEjemplo(Rol.dueno);
  final pareja = sesionDeEjemplo(Rol.coadministrador);
  final casa = sesionDeEjemplo(Rol.casa);
  const pin = '2846';

  late AlmacenSeguroEnMemoria almacen;
  late DateTime ahora;
  late BandejaDeSalida bandeja;

  setUp(() {
    almacen = AlmacenSeguroEnMemoria();
    ahora = DateTime.utc(2026, 10, 24, 10);
    bandeja = BandejaDeSalida(almacen, reloj: () => ahora);
  });

  Future<void> delegar(
    Sesion sesion, {
    String elPin = pin,
    int vuelta = 0,
  }) async {
    final llave = LlavePin.derivar(elPin, iteraciones: 10);
    await bandeja.delegar(
      sesion.persona.id,
      ServicioSesionFalso.credencialDe(sesion, vuelta: vuelta),
      llave,
    );
  }

  group('BandejaDeSalida (permisos de subida)', () {
    test('delegar guarda la credencial, una llave pública y la privada cifrada '
        'con el PIN', () async {
      await delegar(dueno);
      final permiso = (await bandeja.leer(dueno.persona.id))!;
      expect(permiso.estado, EstadoPermiso.enEspera);
      expect(permiso.credencial, ServicioSesionFalso.credencialDe(dueno));
      expect(permiso.sobre, isNull);
      expect(base64Decode(permiso.clavePublica), hasLength(65));
      // La privada solo la abre el PIN.
      expect(CifradoPin.descifrar('0000', permiso.clavePrivadaCifrada), isNull);
      expect(CifradoPin.descifrar(pin, permiso.clavePrivadaCifrada), isNotNull);
      // El PIN nunca se guarda.
      expect(jsonEncode(almacen.datos), isNot(contains(pin)));
    });

    test('vence a los 7 días', () async {
      await delegar(dueno);
      final permiso = (await bandeja.leer(dueno.persona.id))!;
      expect(permiso.vence, ahora.add(const Duration(days: 7)));
      expect(vigenciaDelPermisoDeSubida, const Duration(days: 7));
    });

    test(
      'delegar otra vez conserva el vencimiento mientras no caduque',
      () async {
        await delegar(dueno);
        final primero = (await bandeja.leer(dueno.persona.id))!;
        ahora = ahora.add(const Duration(days: 3));
        await delegar(dueno, vuelta: 5);
        final segundo = (await bandeja.leer(dueno.persona.id))!;
        expect(
          segundo.vence,
          primero.vence,
          reason: 'los 7 días son desde lo más viejo',
        );
        expect(segundo.creadoEn, primero.creadoEn);
        expect(
          segundo.credencial,
          ServicioSesionFalso.credencialDe(dueno, vuelta: 5),
        );
        // Pasado el vencimiento, empieza otra ventana.
        ahora = primero.vence.add(const Duration(hours: 1));
        await delegar(dueno);
        expect(
          (await bandeja.leer(dueno.persona.id))!.vence,
          ahora.add(const Duration(days: 7)),
        );
      },
    );

    test(
      'tomarParaEntrada devuelve la credencial y borra el permiso',
      () async {
        await delegar(dueno, vuelta: 2);
        final credencial = await bandeja.tomarParaEntrada(
          dueno.persona.id,
          pin,
        );
        expect(credencial, ServicioSesionFalso.credencialDe(dueno, vuelta: 2));
        expect(await bandeja.leer(dueno.persona.id), isNull);
        expect(await bandeja.tomarParaEntrada(dueno.persona.id, pin), isNull);
      },
    );

    test('sin permiso no hay nada que tomar', () async {
      expect(await bandeja.tomarParaEntrada(dueno.persona.id, pin), isNull);
    });

    test('sellar quita la credencial en claro; solo el PIN la abre', () async {
      await delegar(dueno);
      final reciente = ServicioSesionFalso.credencialDe(dueno, vuelta: 3);
      await bandeja.sellarYDevolver(dueno.persona.id, reciente);

      final permiso = (await bandeja.leer(dueno.persona.id))!;
      expect(permiso.estado, EstadoPermiso.devuelto);
      expect(permiso.credencial, isNull);
      expect(permiso.sobre, isNotNull);
      // En el almacén no queda la credencial (ni nada de ella) en claro.
      final guardado = almacen.datos[BandejaDeSalida.clave(dueno.persona.id)]!;
      expect(guardado, isNot(contains(reciente)));
      expect(guardado, isNot(contains('falsa:3')));

      // Un PIN equivocado no la abre ni borra el permiso.
      expect(await bandeja.tomarParaEntrada(dueno.persona.id, '0001'), isNull);
      expect(await bandeja.leer(dueno.persona.id), isNotNull);
      // El bueno sí, y entrega la más reciente.
      expect(await bandeja.tomarParaEntrada(dueno.persona.id, pin), reciente);
      expect(await bandeja.leer(dueno.persona.id), isNull);
    });

    test('cambiar el PIN con un permiso sellado: abre con el nuevo, no con el viejo', () async {
      await delegar(dueno);
      await bandeja.sellarYDevolver(
        dueno.persona.id,
        ServicioSesionFalso.credencialDe(dueno, vuelta: 1),
      );
      expect(
        await bandeja.cambiarPin(dueno.persona.id, '0001', '7391'),
        isFalse,
      );
      expect(await bandeja.cambiarPin(dueno.persona.id, pin, '7391'), isTrue);
      expect(await bandeja.tomarParaEntrada(dueno.persona.id, pin), isNull);
      expect(
        await bandeja.tomarParaEntrada(dueno.persona.id, '7391'),
        ServicioSesionFalso.credencialDe(dueno, vuelta: 1),
      );
    });

    test('cambiar el PIN sin permiso no hace nada', () async {
      expect(await bandeja.cambiarPin(dueno.persona.id, pin, '7391'), isTrue);
    });

    test(
      'caducar borra los permisos en espera vencidos; los sellados no caducan',
      () async {
        await delegar(dueno);
        await delegar(pareja);
        await bandeja.sellarYDevolver(
          pareja.persona.id,
          ServicioSesionFalso.credencialDe(pareja),
        );
        ahora = ahora.add(const Duration(days: 6, hours: 23));
        expect(await bandeja.caducar(), isEmpty);
        ahora = ahora.add(const Duration(hours: 2));
        expect(await bandeja.caducar(), [dueno.persona.id]);
        expect(await bandeja.leer(dueno.persona.id), isNull);
        expect(await bandeja.leer(pareja.persona.id), isNotNull);
        // Con el PIN todavía puede entrar y recuperar la suya.
        expect(
          await bandeja.tomarParaEntrada(pareja.persona.id, pin),
          ServicioSesionFalso.credencialDe(pareja),
        );
      },
    );

    test('un permiso dañado se ignora', () async {
      await almacen.escribir(BandejaDeSalida.clave('x'), 'no es json');
      await almacen.escribir(
        BandejaDeSalida.clave('y'),
        '{"estado":"enEspera"}',
      );
      expect(await bandeja.todos(), isEmpty);
    });

    test('el candado es por persona y serializa', () async {
      final orden = <String>[];
      final soltarA = await bandeja.adquirir('a');
      final esperaA = bandeja.adquirir('a').then((soltar) {
        orden.add('a2');
        soltar();
      });
      // Otra persona no espera.
      final soltarB = await bandeja.adquirir('b');
      orden.add('b');
      soltarB();
      await pumpEventQueue();
      expect(orden, ['b'], reason: 'a2 espera a que a1 suelte');
      orden.add('a1');
      soltarA();
      await esperaA;
      expect(orden, ['b', 'a1', 'a2']);
      // Soltar dos veces no estorba.
      soltarA();
      final otra = await bandeja.adquirir('a');
      otra();
    });
  });

  group('la cola sube la bandeja de quien ya salió', () {
    late BaseLocal base;
    late ServidorFalso servidor;
    late ServicioSesionFalso servicio;
    late ColaSinConexion cola;
    String? persona; // con cuya sesión corre la ronda principal
    var siguiente = 0;

    Future<void> registrar(Sesion sesion, {String? id}) => cola.encolar(
      tipo: 'finanzas.movimiento',
      carga: {'monto_centavos': 100},
      id: id ?? 'm${siguiente++}',
      personaId: sesion.persona.id,
    );

    ColaSinConexion crearCola({ServidorFalso? con}) {
      final srv = con ?? servidor;
      return ColaSinConexion(
        base: base,
        enviador: EnviadorDeSesion(srv, () => servicio.personaEnServidor),
        reloj: () => ahora,
        personaConSesion: () => persona,
        cuentaDelEquipo: () => casa.persona.id,
        salida: SalidaSinPinConSesiones(
          bandeja: bandeja,
          abrir: servicio.abrirSesionAparte,
          enviadorDe: (aparte) => EnviadorDeSesion(srv, () => aparte.personaId),
        ),
      );
    }

    setUp(() {
      base = BaseLocal.enMemoria();
      servidor = ServidorFalso();
      servicio = ServicioSesionFalso(inicial: casa)..rotacionEstricta = true;
      persona = casa.persona.id;
      siguiente = 0;
      cola = crearCola();
    });

    tearDown(() => base.close());

    test(
      'con señal sube con el token de ESA persona, nunca con el de Hogar',
      () async {
        await registrar(dueno, id: 'gasto-1');
        await delegar(dueno);
        final resumen = await cola.procesar();

        expect(resumen.enviados, 1);
        expect(servidor.idsDe(dueno.persona.id), ['gasto-1']);
        expect(
          servidor.idsDe(casa.persona.id),
          isEmpty,
          reason: 'la cuenta Hogar no subió nada de la persona',
        );
        expect(servidor.idsDe(null), isEmpty);
        expect((await cola.registros()).single.estado, EstadoPendiente.enviado);
      },
    );

    test(
      'sin señal no hace nada: el registro espera y el permiso sigue igual',
      () async {
        await registrar(dueno);
        await delegar(dueno);
        final antes = (await bandeja.leer(dueno.persona.id))!;
        servicio.sinConexion = true;
        servidor.conSenal = false;
        final resumen = await cola.procesar();
        expect((resumen.enviados, resumen.rechazados), (0, 0));
        expect(
          (await cola.registros()).single.estado,
          EstadoPendiente.pendiente,
        );
        expect(
          (await cola.registros()).single.intentos,
          0,
          reason: 'sin señal no cuenta como intento',
        );
        final despues = (await bandeja.leer(dueno.persona.id))!;
        expect(despues.credencial, antes.credencial);
        expect(despues.estado, EstadoPermiso.enEspera);

        // Vuelve la señal: sube solo.
        servicio.sinConexion = false;
        servidor.conSenal = true;
        expect((await cola.procesar()).enviados, 1);
      },
    );

    test(
      'al subir la última entrada la credencial queda sellada, no en claro',
      () async {
        await registrar(dueno);
        await delegar(dueno);
        await cola.procesar();

        final permiso = (await bandeja.leer(dueno.persona.id))!;
        expect(permiso.estado, EstadoPermiso.devuelto);
        expect(permiso.credencial, isNull);
        expect(
          almacen.datos[BandejaDeSalida.clave(dueno.persona.id)],
          isNot(contains('falsa:')),
        );
        expect(
          servicio.sesionesAparteAbiertas,
          isEmpty,
          reason: 'la sesión aparte se cerró',
        );
      },
    );

    test(
      'el refresh token rota al abrir: se guarda y nunca se usa uno viejo',
      () async {
        await registrar(dueno);
        await delegar(dueno, vuelta: 0);
        await cola.procesar();
        // Abrir rotó 0 -> 1: lo que quedó sellado es la 1, no la 0.
        expect(servicio.vecesAbrirAparte, 1);
        final recuperada = await bandeja.tomarParaEntrada(
          dueno.persona.id,
          pin,
        );
        expect(recuperada, ServicioSesionFalso.credencialDe(dueno, vuelta: 1));
        // Y con ella la persona puede entrar (la cadena sigue viva).
        await servicio.abrirSesionDePersona(dueno.persona.id, recuperada!);
        expect(servicio.usosDeCredencialVieja, 0);
      },
    );

    test(
      'usar la copia vieja habría fallado (el simulador lo vigila)',
      () async {
        await registrar(dueno);
        await delegar(dueno, vuelta: 0);
        await cola.procesar(); // rota 0 -> 1
        await expectLater(
          servicio.abrirSesionDePersona(
            dueno.persona.id,
            ServicioSesionFalso.credencialDe(dueno, vuelta: 0),
          ),
          throwsA(ErrorSesion.credencialVencida),
        );
        expect(servicio.usosDeCredencialVieja, 1);
      },
    );

    test(
      'si la renovación llega a mitad de la subida, se guarda al instante',
      () async {
        await registrar(dueno);
        await delegar(dueno, vuelta: 0);
        // Un enviador que, al enviar, hace que el servidor rote la credencial y
        // luego se cae la señal: lo renovado ya debe estar guardado.
        String? duranteLaSubida;
        final cortado = ColaSinConexion(
          base: base,
          enviador: EnviadorDeSesion(
            servidor,
            () => servicio.personaEnServidor,
          ),
          reloj: () => ahora,
          personaConSesion: () => persona,
          salida: SalidaSinPinConSesiones(
            bandeja: bandeja,
            abrir: servicio.abrirSesionAparte,
            enviadorDe: (aparte) => _EnviadorQueRota(
              aparte as SesionAparteFalsa,
              // Justo después de rotar, MIENTRAS sigue la subida: ya está guardada.
              despues: () async {
                await pumpEventQueue();
                duranteLaSubida = (await bandeja.leer(dueno.persona.id))
                    ?.credencial;
              },
            ),
          ),
        );
        await cortado.procesar();
        expect(
          duranteLaSubida,
          ServicioSesionFalso.credencialDe(dueno, vuelta: 2),
          reason: 'si la app muriera aquí, lo guardado ya sería la credencial que sirve',
        );
        final permiso = (await bandeja.leer(dueno.persona.id))!;
        // Abrir rotó a la 1 y a mitad de la subida rotó a la 2: la guardada es
        // la última (sigue en espera: el envío falló).
        expect(permiso.estado, EstadoPermiso.enEspera);
        expect(
          permiso.credencial,
          ServicioSesionFalso.credencialDe(dueno, vuelta: 2),
        );
      },
    );

    test(
      'si queda algo sin subir, el permiso sigue en espera con la credencial '
      'renovada',
      () async {
        await registrar(dueno, id: 'a');
        await registrar(dueno, id: 'b');
        await delegar(dueno);
        final parcial = ServidorFalso();
        // Se cae la señal tras el primero.
        final conCorte = ColaSinConexion(
          base: base,
          enviador: EnviadorDeSesion(parcial, () => servicio.personaEnServidor),
          reloj: () => ahora,
          personaConSesion: () => persona,
          salida: SalidaSinPinConSesiones(
            bandeja: bandeja,
            abrir: servicio.abrirSesionAparte,
            enviadorDe: (aparte) =>
                _EnviadorQueSeCaeTras(parcial, aparte.personaId, 1),
          ),
        );
        final resumen = await conCorte.procesar();
        expect(resumen.enviados, 1);
        expect(resumen.reintentos, 1);
        final permiso = (await bandeja.leer(dueno.persona.id))!;
        expect(permiso.estado, EstadoPermiso.enEspera);
        expect(
          permiso.credencial,
          ServicioSesionFalso.credencialDe(dueno, vuelta: 1),
        );
        expect((await cola.contarPendientesDe(dueno.persona.id)), 1);
      },
    );

    test(
      'quien está dentro sube con su propia sesión, no con el permiso',
      () async {
        await registrar(dueno);
        await delegar(dueno);
        persona = dueno.persona.id; // la persona entró de nuevo
        await cola.procesar();
        expect(
          servicio.vecesAbrirAparte,
          0,
          reason: 'no se abre una segunda sesión de la misma persona',
        );
      },
    );

    test(
      'lo de otra persona sin permiso espera a que entre con su PIN',
      () async {
        await registrar(pareja);
        await registrar(dueno);
        await delegar(dueno);
        await cola.procesar();
        expect(servidor.idsDe(dueno.persona.id), hasLength(1));
        final pendientes = (await cola.registros()).where(
          (r) => r.estado == EstadoPendiente.pendiente,
        );
        expect(pendientes.single.personaId, pareja.persona.id);
      },
    );

    test('lo registrado en la tablet con solo el nombre no sube con el token de nadie', () async {
      await cola.encolar(
        tipo: 'casa.lista',
        carga: const {},
        personaId: dueno.persona.id,
        origen: OrigenRegistro.tabletCasa,
      );
      await delegar(dueno);
      await cola.procesar();
      // Sube con la cuenta Hogar (es de la casa), jamás con el token del dueño.
      expect(servidor.idsDe(dueno.persona.id), isEmpty);
    });

    test('a los 7 días caduca: pasa a "requiere atención" con aviso y se borra '
        'la credencial', () async {
      await registrar(dueno, id: 'viejo');
      await delegar(dueno);
      servicio.sinConexion = true;
      servidor.conSenal = false;
      ahora = ahora.add(const Duration(days: 7, minutes: 1));
      final resumen = await cola.procesar();

      expect(resumen.rechazados, 1);
      final registro = (await cola.registros()).single;
      expect(registro.estado, EstadoPendiente.rechazado);
      expect(registro.ultimoError, motivoBandejaCaducada);
      expect(await bandeja.leer(dueno.persona.id), isNull);
      expect(
        almacen.datos.keys.where((k) => k.startsWith('bandeja.')),
        isEmpty,
      );
      // La persona lo ve en "Por revisar"; los demás, no (D5).
      expect(
        await cola.requierenAtencion(personaId: dueno.persona.id),
        hasLength(1),
      );
      expect(
        await cola.requierenAtencion(personaId: pareja.persona.id),
        isEmpty,
      );
      // Para el aviso de la tablet: solo el número.
      expect(await cola.contarCaducadosDeLaBandeja(), 1);
      // Y no sube nunca solo, aunque vuelva la señal.
      servicio.sinConexion = false;
      servidor.conSenal = true;
      await cola.procesar();
      expect(servidor.recibidos, isEmpty);
    });

    test(
      'una persona dada de baja no sube: 42501 sería inútil; pasa a atención',
      () async {
        await registrar(dueno);
        await delegar(dueno);
        servicio.bajas.add(dueno.persona.id);
        final resumen = await cola.procesar();
        expect(resumen.rechazados, 1);
        expect(
          (await cola.registros()).single.ultimoError,
          motivoSesionInservible,
        );
        expect(await bandeja.leer(dueno.persona.id), isNull);
        expect(servidor.recibidos, isEmpty);
      },
    );

    test(
      'una credencial vencida (o ya rotada por otra copia) tampoco',
      () async {
        await registrar(dueno);
        await delegar(dueno, vuelta: 0);
        // Alguien más usó la cadena: la vuelta 0 ya no sirve.
        await servicio.abrirSesionDePersona(
          dueno.persona.id,
          ServicioSesionFalso.credencialDe(dueno, vuelta: 0),
        );
        await servicio.cerrarSesionDePersona();
        final resumen = await cola.procesar();
        expect(resumen.rechazados, 1);
        expect(
          (await cola.registros()).single.ultimoError,
          motivoSesionInservible,
        );
      },
    );

    test(
      'un permiso en espera sin nada por subir se sella sin abrir sesión',
      () async {
        await delegar(dueno);
        await cola.procesar();
        expect(servicio.vecesAbrirAparte, 0);
        expect(
          (await bandeja.leer(dueno.persona.id))!.estado,
          EstadoPermiso.devuelto,
        );
      },
    );

    test('entrar con el PIN no espera a una subida lenta: la interrumpe, toma la '
        'credencial más reciente y lo pendiente sigue pendiente', () async {
      await registrar(dueno);
      await delegar(dueno);
      final pausa = Completer<void>();
      final lenta = ColaSinConexion(
        base: base,
        enviador: EnviadorDeSesion(servidor, () => servicio.personaEnServidor),
        reloj: () => ahora,
        personaConSesion: () => persona,
        salida: SalidaSinPinConSesiones(
          bandeja: bandeja,
          abrir: servicio.abrirSesionAparte,
          enviadorDe: (aparte) =>
              _EnviadorLento(pausa.future, servidor, aparte.personaId),
        ),
      );
      final ronda = lenta.procesar();
      await pumpEventQueue();
      String? entrada;
      final entrando = bandeja
          .tomarParaEntrada(dueno.persona.id, pin)
          .then((c) => entrada = c);
      await pumpEventQueue();
      // B3 (revisión de la Fase 1b): el servidor no ha contestado y la persona
      // ya entró. Tomó la más reciente (la rotada al abrir la sesión aparte).
      expect(entrada, ServicioSesionFalso.credencialDe(dueno, vuelta: 1));
      await ronda;
      await entrando;
      expect(await bandeja.leer(dueno.persona.id), isNull);
      // El registro no se perdió ni gastó un intento: se vuelve a subir.
      final registro = (await lenta.registros()).single;
      expect(registro.estado, EstadoPendiente.pendiente);
      expect(registro.intentos, 0);
      pausa.complete(); // el servidor por fin contesta; nadie lo espera
    });

    test('quien no pide el turno con urgencia sí espera su vez', () async {
      final soltar = await bandeja.adquirir(dueno.persona.id);
      var tomado = false;
      final espera = bandeja.conCandado(
        dueno.persona.id,
        () async => tomado = true,
      );
      await pumpEventQueue();
      expect(tomado, isFalse);
      expect(bandeja.turnoPedidoYa(dueno.persona.id), isFalse);
      soltar();
      await espera;
      expect(tomado, isTrue);
    });

    test(
      'el turno urgente avisa a quien tiene el candado y se reparte en orden',
      () async {
        final soltar = await bandeja.adquirir(dueno.persona.id);
        final avisos = <String>[];
        unawaited(
          bandeja
              .turnoPedido(dueno.persona.id)
              .then((_) => avisos.add('avisado')),
        );
        final urgente = bandeja.conCandado(
          dueno.persona.id,
          urgente: true,
          () async => avisos.add('urgente'),
        );
        final normal = bandeja.conCandado(
          dueno.persona.id,
          () async => avisos.add('normal'),
        );
        await pumpEventQueue();
        expect(avisos, [
          'avisado',
        ], reason: 'quien lo tiene se entera, pero no se lo quitan');
        expect(bandeja.turnoPedidoYa(dueno.persona.id), isTrue);
        soltar();
        await Future.wait([urgente, normal]);
        expect(avisos, ['avisado', 'urgente', 'normal']);
        expect(bandeja.turnoPedidoYa(dueno.persona.id), isFalse);
      },
    );
  });
}

class _EnviadorQueRota implements Enviador {
  _EnviadorQueRota(this.aparte, {this.despues});

  final SesionAparteFalsa aparte;
  final Future<void> Function()? despues;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    aparte.rotar();
    await despues?.call();
    return ResultadoEnvio.reintentar; // se cae la señal
  }
}

class _EnviadorQueSeCaeTras implements Enviador {
  _EnviadorQueSeCaeTras(this.servidor, this.sesionDe, this.antes);

  final ServidorFalso servidor;
  final String sesionDe;
  final int antes;
  int hechos = 0;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    if (hechos >= antes) return ResultadoEnvio.reintentar;
    hechos++;
    servidor.recibidos.add((id: peticion.id, sesionDe: sesionDe));
    return ResultadoEnvio.enviado;
  }
}

class _EnviadorLento implements Enviador {
  _EnviadorLento(this.espera, this.servidor, this.sesionDe);

  final Future<void> espera;
  final ServidorFalso servidor;
  final String sesionDe;

  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async {
    await espera;
    servidor.recibidos.add((id: peticion.id, sesionDe: sesionDe));
    return ResultadoEnvio.enviado;
  }
}
