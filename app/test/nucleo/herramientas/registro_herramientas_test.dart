import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

/// Herramienta de prueba con contador de ejecuciones.
final class _Falsa extends Herramienta {
  _Falsa({
    this.nombre = 'habitos.resumen_hoy',
    this.modulo = Modulo.habitos,
    this.roles = const {Rol.dueno, Rol.coadministrador, Rol.familiar},
    this.escribe = false,
    this.soloLocal = false,
    this.paraIaQueIntenta = 'Resumen listo.',
    this.resultadoAjeno,
    this.error,
  });

  /// Una de Finanzas solo para el Dueño (D3: solo local).
  factory _Falsa.deFinanzas({
    String nombre = 'finanzas.resumen_semana',
    bool escribe = false,
    String paraIaQueIntenta = 'Resumen listo.',
    ResultadoHerramienta? resultadoAjeno,
    Object? error,
  }) => _Falsa(
    nombre: nombre,
    modulo: Modulo.finanzas,
    roles: const {Rol.dueno},
    escribe: escribe,
    soloLocal: true,
    paraIaQueIntenta: paraIaQueIntenta,
    resultadoAjeno: resultadoAjeno,
    error: error,
  );

  @override
  final String nombre;
  @override
  final Modulo modulo;
  @override
  final Set<Rol> roles;
  @override
  final bool escribe;
  @override
  final bool soloLocal;

  final String paraIaQueIntenta;

  /// Si no es `null`, la herramienta devuelve este resultado (como si
  /// intentara hacerse pasar por otra).
  final ResultadoHerramienta? resultadoAjeno;

  /// Si no es `null`, la herramienta lo lanza al ejecutarse.
  final Object? error;

  int ejecuciones = 0;

  @override
  String get descripcion => 'Herramienta de prueba.';

  @override
  Future<ResultadoHerramienta> ejecutar(
    Map<String, Object?> parametros,
    ContextoHerramienta ctx,
  ) async {
    ejecuciones++;
    if (error case final e?) throw e;
    return resultadoAjeno ??
        ResultadoHerramienta(
          this,
          contenido: 'Gastaste \$1,234.50 esta semana.',
          paraIa: paraIaQueIntenta,
        );
  }
}

void main() {
  group('Filtro por rol', () {
    final registro = registroFase0();

    test('familiar no ve herramientas de finanzas', () {
      final disponibles = registro.disponibles(rol: Rol.familiar);
      expect(disponibles, isNotEmpty);
      expect(disponibles.where((h) => h.modulo == Modulo.finanzas), isEmpty);
      expect(registro.buscar('finanzas.abrir', rol: Rol.familiar), isNull);
    });

    test('familiar no puede ejecutar una herramienta de finanzas', () async {
      await expectLater(
        registro.ejecutar(
          'finanzas.abrir',
          const {},
          ContextoHerramienta(rol: Rol.familiar, navegar: (_) {}),
        ),
        throwsA(
          isA<HerramientaNoDisponible>().having(
            (e) => e.motivo,
            'motivo',
            MotivoNoDisponible.rolSinPermiso,
          ),
        ),
      );
    });

    test('dueño ve finanzas; coadministrador también (solo lectura)', () {
      expect(registro.buscar('finanzas.abrir', rol: Rol.dueno), isNotNull);
      expect(
        registro.buscar('finanzas.abrir', rol: Rol.coadministrador),
        isNotNull,
      );
    });

    test('cuidador solo navega a Cuidados y a sus ajustes', () {
      final nombres = registro
          .disponibles(rol: Rol.cuidador)
          .map((h) => h.nombre)
          .toSet();
      expect(nombres, {'cuidados.abrir', 'ajustes.abrir'});
    });

    test('casa no ve dinero', () {
      final modulos = registro.disponibles(rol: Rol.casa).map((h) => h.modulo);
      expect(modulos, isNot(contains(Modulo.finanzas)));
    });

    test('Desarrollador solo para el dueño', () {
      for (final rol in Rol.values) {
        expect(
          registro.buscar('ajustes.abrir_desarrollador', rol: rol) != null,
          rol == Rol.dueno,
          reason: rol.name,
        );
      }
    });

    test('una herramienta inexistente no existe para nadie', () async {
      await expectLater(
        registro.ejecutar(
          'finanzas.borrar_todo',
          const {},
          const ContextoHerramienta(rol: Rol.dueno),
        ),
        throwsA(
          isA<HerramientaNoDisponible>().having(
            (e) => e.motivo,
            'motivo',
            MotivoNoDisponible.noExiste,
          ),
        ),
      );
    });
  });

  group('Módulos activos', () {
    final registro = registroFase0();

    test('un módulo inactivo no ofrece herramientas', () {
      final nombres = registro
          .disponibles(rol: Rol.dueno, modulosActivos: {Modulo.habitos})
          .map((h) => h.nombre);
      expect(nombres, contains('habitos.abrir'));
      expect(nombres, isNot(contains('finanzas.abrir')));
    });

    test('GRAVITY y Ajustes siempre están activos', () {
      final nombres = registro
          .disponibles(rol: Rol.dueno, modulosActivos: const {})
          .map((h) => h.nombre)
          .toSet();
      expect(nombres, {
        'gravity.abrir',
        'ajustes.abrir',
        'ajustes.abrir_desarrollador',
      });
    });

    test('ejecutar respeta los módulos del contexto', () async {
      await expectLater(
        registro.ejecutar(
          'finanzas.abrir',
          const {},
          ContextoHerramienta(
            rol: Rol.dueno,
            modulosActivos: const {Modulo.habitos},
            navegar: (_) {},
          ),
        ),
        throwsA(
          isA<HerramientaNoDisponible>().having(
            (e) => e.motivo,
            'motivo',
            MotivoNoDisponible.moduloInactivo,
          ),
        ),
      );
    });
  });

  group('Solo local (D3)', () {
    test('el resultado de una herramienta solo local nunca lleva paraIa', () {
      final h = _Falsa(soloLocal: true);
      final r = ResultadoHerramienta(h, contenido: 'x', paraIa: 'cifras');
      expect(r.paraIa, isNull);
      expect(r.soloLocal, isTrue);
    });

    test('tampoco al ejecutarla por el registro', () async {
      final h = _Falsa.deFinanzas(paraIaQueIntenta: r'Gastaste $1,234.50');
      final r = await RegistroHerramientas(
        [h],
      ).ejecutar(h.nombre, const {}, const ContextoHerramienta(rol: Rol.dueno));
      expect(h.ejecuciones, 1);
      expect(r.contenido, contains(r'$1,234.50'));
      expect(r.paraIa, isNull);
    });

    test('ni si intenta devolver el resultado de otra herramienta', () async {
      final ajena = _Falsa(nombre: 'habitos.resumen');
      final tramposa = _Falsa.deFinanzas(
        resultadoAjeno: ResultadoHerramienta(
          ajena,
          contenido: 'Saldo: \$5,000.00',
          paraIa: 'Saldo: \$5,000.00',
        ),
      );
      final r = await RegistroHerramientas([tramposa]).ejecutar(
        tramposa.nombre,
        const {},
        const ContextoHerramienta(rol: Rol.dueno),
      );
      expect(r.paraIa, isNull);
      expect(r.soloLocal, isTrue);
      expect(r.nombreHerramienta, tramposa.nombre);
    });

    test('una herramienta que no es solo local sí entrega paraIa', () async {
      final h = _Falsa();
      final r = await RegistroHerramientas(
        [h],
      ).ejecutar(h.nombre, const {}, const ContextoHerramienta(rol: Rol.dueno));
      expect(r.paraIa, 'Resumen listo.');
    });

    test('si falla, el error no lleva el mensaje original (M14)', () async {
      final original = StateError(r'Saldo insuficiente: $5,000.00');
      final h = _Falsa.deFinanzas(error: original);
      await expectLater(
        RegistroHerramientas([h]).ejecutar(
          h.nombre,
          const {},
          const ContextoHerramienta(rol: Rol.dueno),
        ),
        throwsA(
          isA<FalloHerramienta>()
              .having((e) => e.nombre, 'nombre', h.nombre)
              .having((e) => '$e', 'toString', isNot(contains('5,000')))
              .having((e) => e.mensaje, 'mensaje', isNot(contains('5,000')))
              .having((e) => e.causaLocal, 'causaLocal', same(original)),
        ),
      );
    });

    test('el error de una que no es solo local sale tal cual', () async {
      final original = StateError('Sin conexión');
      final h = _Falsa(error: original);
      await expectLater(
        RegistroHerramientas([h]).ejecutar(
          h.nombre,
          const {},
          const ContextoHerramienta(rol: Rol.dueno),
        ),
        throwsA(same(original)),
      );
    });
  });

  group('D3: Finanzas y Cuidados son solo locales', () {
    for (final modulo in modulosSoloLocal) {
      final nombre = '${modulo.name}.resumen';

      test('rechaza una de ${modulo.name} que lee sin soloLocal', () {
        expect(
          () => RegistroHerramientas([
            _Falsa(nombre: nombre, modulo: modulo, roles: const {Rol.dueno}),
          ]),
          throwsA(
            isA<ArgumentError>().having((e) => e.name, 'name', 'soloLocal'),
          ),
        );
      });

      test('rechaza una de ${modulo.name} que escribe sin soloLocal', () {
        expect(
          () => RegistroHerramientas([
            _Falsa(
              nombre: '${modulo.name}.registrar',
              modulo: modulo,
              roles: const {Rol.dueno},
              escribe: true,
            ),
          ]),
          throwsArgumentError,
        );
      });

      test('acepta una de ${modulo.name} solo local', () {
        final registro = RegistroHerramientas([
          _Falsa(
            nombre: nombre,
            modulo: modulo,
            roles: const {Rol.dueno},
            soloLocal: true,
          ),
        ]);
        expect(registro.todas.single.soloLocal, isTrue);
      });
    }

    test('solo las de navegación son la excepción', () {
      for (final h in herramientasNavegacion) {
        if (!modulosSoloLocal.contains(h.modulo)) continue;
        expect(h.soloLocal, isFalse, reason: h.nombre);
        expect(RegistroHerramientas([h]).todas, [h]);
      }
    });

    test('otros módulos pueden enviar su resultado a la IA', () {
      expect(RegistroHerramientas([_Falsa()]).todas.single.soloLocal, isFalse);
    });
  });

  group('D5: los roles respetan la matriz de permisos', () {
    test('rechaza una de Finanzas para el Familiar o la cuenta Casa', () {
      for (final rol in [Rol.familiar, Rol.casa]) {
        expect(
          () => RegistroHerramientas([
            _Falsa(
              nombre: 'finanzas.resumen_semana',
              modulo: Modulo.finanzas,
              roles: {Rol.dueno, rol},
              soloLocal: true,
            ),
          ]),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'roles')),
          reason: rol.name,
        );
      }
    });

    test('lectura: acepta el rol si y solo si la matriz le deja leer', () {
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          Object? error;
          try {
            RegistroHerramientas([
              _Falsa(
                nombre: '${modulo.name}.leer_prueba',
                modulo: modulo,
                roles: {rol},
                soloLocal: true,
              ),
            ]);
          } on ArgumentError catch (e) {
            error = e;
          }
          expect(
            error == null,
            puede(rol, modulo, Accion.leer),
            reason: '${rol.name} × ${modulo.name}',
          );
        }
      }
    });

    test(
      'escritura: acepta el rol si y solo si la matriz le deja escribir',
      () {
        for (final modulo in Modulo.values) {
          for (final rol in Rol.values) {
            Object? error;
            try {
              RegistroHerramientas([
                _Falsa(
                  nombre: '${modulo.name}.escribir_prueba',
                  modulo: modulo,
                  roles: {rol},
                  escribe: true,
                  soloLocal: true,
                ),
              ]);
            } on ArgumentError catch (e) {
              error = e;
            }
            expect(
              error == null,
              puede(rol, modulo, Accion.escribir),
              reason: '${rol.name} × ${modulo.name}',
            );
          }
        }
      },
    );

    // D19 (21/oct/2026): el dueño y la pareja llevan cada quien su libro de
    // Finanzas (alcance propio): los dos leen y escriben. Familiar, cuidador y
    // casa siguen sin leer Finanzas; la cuidadora solo registrará gastos de
    // cuidado (Fase 5), así que nunca recibe una herramienta que lea Finanzas.
    test('D19: dueño y pareja leen y escriben su Finanzas; nadie más la lee', () {
      _Falsa deFinanzas(Set<Rol> roles, {required bool escribe}) => _Falsa(
        nombre: 'finanzas.prueba',
        modulo: Modulo.finanzas,
        roles: roles,
        escribe: escribe,
        soloLocal: true,
      );
      const pareja = {Rol.dueno, Rol.coadministrador};
      for (final escribe in [false, true]) {
        expect(
          RegistroHerramientas([deFinanzas(pareja, escribe: escribe)]).todas,
          hasLength(1),
          reason: escribe ? 'escribe' : 'lee',
        );
      }
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        expect(
          () => RegistroHerramientas([deFinanzas({rol}, escribe: false)]),
          throwsArgumentError,
          reason: '${rol.name} no lee Finanzas',
        );
      }
      for (final rol in [Rol.familiar, Rol.casa]) {
        expect(
          () => RegistroHerramientas([deFinanzas({rol}, escribe: true)]),
          throwsArgumentError,
          reason: '${rol.name} no escribe en Finanzas',
        );
      }
    });

    test('navegación: solo para quien abre el módulo desde la navegación', () {
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          Object? error;
          try {
            RegistroHerramientas([
              HerramientaNavegacion(
                nombre: '${modulo.name}.abrir_prueba',
                modulo: modulo,
                roles: {rol},
                ruta: '/prueba',
                etiqueta: 'Prueba',
                palabrasClave: const ['prueba'],
              ),
            ]);
          } on ArgumentError catch (e) {
            error = e;
          }
          expect(
            error == null,
            puedeAbrir(rol, modulo),
            reason: '${rol.name} × ${modulo.name}',
          );
        }
      }
    });
  });

  group('Confirmación', () {
    test('las que escriben piden confirmación y no se ejecutan', () async {
      final h = _Falsa.deFinanzas(
        nombre: 'finanzas.registrar_gasto',
        escribe: true,
      );
      final r = await RegistroHerramientas([h]).ejecutar(h.nombre, const {
        'monto_centavos': 12350,
      }, const ContextoHerramienta(rol: Rol.dueno));
      expect(r.requiereConfirmacion, isTrue);
      expect(r.paraIa, isNull);
      expect(r.contenido, isNotEmpty);
      expect(h.ejecuciones, 0);
    });

    test('ya confirmadas, se ejecutan una vez', () async {
      final h = _Falsa.deFinanzas(
        nombre: 'finanzas.registrar_gasto',
        escribe: true,
      );
      const ctx = ContextoHerramienta(rol: Rol.dueno);
      final r = await RegistroHerramientas([h])
          .ejecutar(h.nombre, const {'monto_centavos': 12350}, ctx.confirmar());
      expect(r.requiereConfirmacion, isFalse);
      expect(h.ejecuciones, 1);
    });

    test('las que solo leen no piden confirmación', () async {
      final h = _Falsa();
      final r = await RegistroHerramientas(
        [h],
      ).ejecutar(h.nombre, const {}, const ContextoHerramienta(rol: Rol.dueno));
      expect(r.requiereConfirmacion, isFalse);
      expect(h.ejecuciones, 1);
    });
  });

  group('Validación del registro', () {
    test('rechaza nombres sin el formato <modulo>.<accion>', () {
      expect(
        () => RegistroHerramientas([_Falsa(nombre: 'Finanzas.Resumen')]),
        throwsArgumentError,
      );
      expect(
        () => RegistroHerramientas([_Falsa(nombre: 'resumen')]),
        throwsArgumentError,
      );
    });

    test('el prefijo del nombre es el módulo', () {
      expect(
        () => RegistroHerramientas([
          _Falsa(nombre: 'finanzas.resumen', modulo: Modulo.habitos),
        ]),
        throwsArgumentError,
      );
    });

    test('rechaza nombres repetidos y herramientas sin roles', () {
      expect(
        () => RegistroHerramientas([_Falsa(), _Falsa()]),
        throwsArgumentError,
      );
      expect(
        () => RegistroHerramientas([_Falsa(roles: const {})]),
        throwsArgumentError,
      );
    });
  });

  group('Navegación de la Fase 0', () {
    test('cada herramienta abre su ruta y no escribe', () async {
      final rutas = <String>[];
      for (final h in herramientasNavegacion) {
        expect(h.escribe, isFalse, reason: h.nombre);
        expect(h.soloLocal, isFalse, reason: h.nombre);
        final r = await registroFase0().ejecutar(
          h.nombre,
          const {},
          ContextoHerramienta(rol: Rol.dueno, navegar: rutas.add),
        );
        expect(r.requiereConfirmacion, isFalse);
        expect(r.paraIa, isNotNull);
      }
      expect(rutas, [
        Rutas.inicio,
        Rutas.finanzas,
        Rutas.habitos,
        Rutas.cuidados,
        Rutas.alimentacion,
        Rutas.casa,
        Rutas.ajustes,
        Rutas.desarrollador,
      ]);
    });

    test('sin pantalla, avisa y no falla', () async {
      final r = await registroFase0().ejecutar(
        'habitos.abrir',
        const {},
        const ContextoHerramienta(rol: Rol.familiar),
      );
      expect(r.contenido, contains('No hay una pantalla'));
    });

    test('los roles salen del espejo de permisos de la plataforma', () {
      for (final h in herramientasNavegacion) {
        if (h.nombre == 'ajustes.abrir_desarrollador') continue;
        for (final rol in Rol.values) {
          expect(
            h.roles.contains(rol),
            puedeAbrir(rol, h.modulo),
            reason: '${h.nombre} / ${rol.name}',
          );
        }
      }
    });

    test(
      'Desarrollador: rol y dispositivo según puedeVerDesarrollador (D16)',
      () {
        final h = herramientasNavegacion.singleWhere(
          (h) => h.nombre == 'ajustes.abrir_desarrollador',
        );
        for (final rol in Rol.values) {
          for (final dispositivo in TipoDispositivo.values) {
            expect(
              h.roles.contains(rol) && h.disponibleEn(dispositivo),
              puedeVerDesarrollador(rol, dispositivo),
              reason: '${rol.name} en ${dispositivo.name}',
            );
          }
        }
        expect(h.disponibleEn(null), isFalse);
      },
    );

    test('las demás van en todos los dispositivos', () {
      for (final h in herramientasNavegacion) {
        if (h.nombre == 'ajustes.abrir_desarrollador') continue;
        expect(h.dispositivos, isNull, reason: h.nombre);
        expect(h.disponibleEn(null), isTrue, reason: h.nombre);
      }
    });
  });
}
