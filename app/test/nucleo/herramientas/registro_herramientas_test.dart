import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/navegacion.dart' show RutasApp, calcularRedireccion;
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
    this.pertenencia = Pertenencia.propia,
    this.ambito = AmbitoHerramienta.general,
    Accion? accion,
  }) : _accion = accion;

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
  @override
  final Pertenencia pertenencia;
  @override
  final AmbitoHerramienta ambito;

  final Accion? _accion;

  @override
  Accion get accion => _accion ?? super.accion;

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

/// `null` si [crear] arma el registro; si no, el [ArgumentError].
ArgumentError? _errorAlRegistrar(List<Herramienta> Function() crear) {
  try {
    RegistroHerramientas(crear());
    return null;
  } on ArgumentError catch (e) {
    return e;
  }
}

Matcher _noDisponiblePor(MotivoNoDisponible motivo) => throwsA(
  isA<HerramientaNoDisponible>().having((e) => e.motivo, 'motivo', motivo),
);

void main() {
  group('Filtro por rol', () {
    final registro = registroDeGravity();

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
        _noDisponiblePor(MotivoNoDisponible.rolSinPermiso),
      );
    });

    test('dueño y coadministrador ven Finanzas, cada quien su libro (D19)', () {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        for (final nombre in [
          'finanzas.abrir',
          'finanzas.registrar_gasto',
          'finanzas.abrir_semana',
        ]) {
          expect(
            registro.buscar(nombre, rol: rol),
            isNotNull,
            reason: '$nombre / ${rol.name}',
          );
        }
      }
    });

    test('familiar, cuidador y casa: ninguna herramienta de Finanzas', () {
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        expect(
          registro.disponibles(rol: rol).where(
            (h) => h.modulo == Modulo.finanzas,
          ),
          isEmpty,
          reason: rol.name,
        );
      }
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
        _noDisponiblePor(MotivoNoDisponible.noExiste),
      );
    });
  });

  group('Módulos activos', () {
    final registro = registroDeGravity();

    test('un módulo inactivo no ofrece herramientas', () {
      final nombres = registro
          .disponibles(rol: Rol.dueno, modulosActivos: {Modulo.habitos})
          .map((h) => h.nombre);
      expect(nombres, contains('habitos.abrir'));
      expect(nombres, isNot(contains('finanzas.abrir')));
      expect(nombres, isNot(contains('finanzas.registrar_gasto')));
    });

    test('GRAVITY y Ajustes siempre están activos', () {
      Set<String> nombres(Rol rol) => registro
          .disponibles(rol: rol, modulosActivos: const {})
          .map((h) => h.nombre)
          .toSet();
      expect(nombres(Rol.dueno), {
        'gravity.abrir',
        'ajustes.abrir',
        'ajustes.abrir_desarrollador',
      });
      // La bandeja de la cuidadora es de GRAVITY: siempre está.
      expect(nombres(Rol.cuidador), {'gravity.abrir_solicitudes'});
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
        _noDisponiblePor(MotivoNoDisponible.moduloInactivo),
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

    test('las de navegación tampoco son excepción: abrir Finanzas o Cuidados '
        'es solo local', () {
      for (final h in herramientasNavegacion) {
        expect(
          h.soloLocal,
          modulosSoloLocal.contains(h.modulo),
          reason: h.nombre,
        );
      }
    });

    test('criterio 30: ninguna herramienta de Finanzas deja de ser solo local '
        'ni entrega nada a la IA', () async {
      final registro = registroDeGravity();
      final deFinanzas = registro.todas
          .where((h) => h.modulo == Modulo.finanzas)
          .toList();
      expect(deFinanzas.map((h) => h.nombre), [
        'finanzas.abrir',
        'finanzas.registrar_gasto',
        'finanzas.abrir_semana',
      ]);
      for (final h in deFinanzas) {
        expect(h.soloLocal, isTrue, reason: h.nombre);
        for (final ctx in [
          ContextoHerramienta(rol: Rol.dueno, navegar: (_) {}),
          ContextoHerramienta(
            rol: Rol.coadministrador,
            navegar: (_) {},
            abrirHoja: (_) {},
          ),
          const ContextoHerramienta(rol: Rol.dueno),
        ]) {
          final r = await registro.ejecutar(h.nombre, const {}, ctx);
          expect(r.paraIa, isNull, reason: h.nombre);
          expect(r.soloLocal, isTrue, reason: h.nombre);
        }
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

    test('lectura: acepta el rol si y solo si la matriz le deja leer '
        '(y no es solo de bandeja, D18)', () {
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          final error = _errorAlRegistrar(
            () => [
              _Falsa(
                nombre: '${modulo.name}.leer_prueba',
                modulo: modulo,
                roles: {rol},
                soloLocal: true,
              ),
            ],
          );
          expect(
            error == null,
            puede(rol, modulo, Accion.leer) && !soloBandejaEnGravity(rol),
            reason: '${rol.name} × ${modulo.name}',
          );
        }
      }
    });

    test('escritura: acepta el rol si y solo si la matriz le deja escribir '
        '(y no es solo de bandeja, D18)', () {
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          final error = _errorAlRegistrar(
            () => [
              _Falsa(
                nombre: '${modulo.name}.escribir_prueba',
                modulo: modulo,
                roles: {rol},
                escribe: true,
                soloLocal: true,
              ),
            ],
          );
          expect(
            error == null,
            puede(rol, modulo, Accion.escribir) && !soloBandejaEnGravity(rol),
            reason: '${rol.name} × ${modulo.name}',
          );
        }
      }
    });

    // D19 (21/oct/2026): el dueño y la pareja llevan cada quien su libro de
    // Finanzas (alcance propio): los dos leen y escriben. Familiar, cuidador y
    // casa no reciben ninguna herramienta de Finanzas; la cuidadora registrará
    // sus gastos de cuidado desde Cuidados (Fase 5), no desde GRAVITY.
    test('D19: dueño y pareja leen y escriben su Finanzas; nadie más', () {
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
        for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
          expect(
            () => RegistroHerramientas([deFinanzas({rol}, escribe: escribe)]),
            throwsArgumentError,
            reason: '${rol.name} ${escribe ? 'escribe' : 'lee'} Finanzas',
          );
        }
      }
    });

    test('navegación: solo para quien abre el módulo desde la navegación '
        '(y no es solo de bandeja, D18)', () {
      for (final modulo in Modulo.values) {
        for (final rol in Rol.values) {
          final error = _errorAlRegistrar(
            () => [
              HerramientaNavegacion(
                nombre: '${modulo.name}.abrir_prueba',
                modulo: modulo,
                roles: {rol},
                ruta: '/prueba',
                etiqueta: 'Prueba',
                palabrasClave: const ['prueba'],
              ),
            ],
          );
          expect(
            error == null,
            puedeAbrir(rol, modulo) && !soloBandejaEnGravity(rol),
            reason: '${rol.name} × ${modulo.name}',
          );
        }
      }
    });

    test('abrir la hoja de un registro exige poder escribir en el módulo', () {
      for (final rol in Rol.values) {
        final error = _errorAlRegistrar(
          () => [
            HerramientaNavegacion(
              nombre: 'finanzas.registrar_prueba',
              modulo: Modulo.finanzas,
              roles: {rol},
              ruta: Rutas.finanzas,
              etiqueta: 'Registrar prueba',
              palabrasClave: const ['prueba'],
              accion: Accion.escribir,
              hoja: HojaDeRegistro.gasto,
            ),
          ],
        );
        expect(
          error == null,
          puedeAbrir(rol, Modulo.finanzas) &&
              puede(rol, Modulo.finanzas, Accion.escribir),
          reason: rol.name,
        );
      }
    });
  });

  group('D18: la cuidadora solo tiene su bandeja de solicitudes', () {
    final registro = registroDeGravity();

    test('el cuidador es el rol de la bandeja', () {
      expect(rolesConBandeja(), {Rol.cuidador});
      expect(soloBandejaEnGravity(Rol.cuidador), isTrue);
      for (final rol in Rol.values.where((r) => r != Rol.cuidador)) {
        expect(soloBandejaEnGravity(rol), isFalse, reason: rol.name);
      }
    });

    test('su única herramienta es abrir Solicitudes, en todo dispositivo', () {
      final disponibles = registro.disponibles(rol: Rol.cuidador);
      expect(disponibles.map((h) => h.nombre), ['gravity.abrir_solicitudes']);
      final h = disponibles.single as HerramientaNavegacion;
      expect(h.ambito, AmbitoHerramienta.solicitudes);
      expect(h.escribe, isFalse);
      expect(h.dispositivos, isNull);
      expect(h.roles, {Rol.cuidador});
    });

    test('nada de dinero, de la familia ni de conversación libre', () {
      final modulos = registro
          .disponibles(rol: Rol.cuidador)
          .map((h) => h.modulo)
          .toSet();
      expect(modulos, {Modulo.gravity});
      for (final nombre in [
        'finanzas.abrir',
        'finanzas.registrar_gasto',
        'finanzas.abrir_semana',
        'habitos.abrir',
        'alimentacion.abrir',
        'casa.abrir',
        'gravity.abrir',
        'cuidados.abrir',
        'ajustes.abrir',
      ]) {
        expect(
          registro.buscar(nombre, rol: Rol.cuidador),
          isNull,
          reason: nombre,
        );
      }
      // Una de conversación libre (Fase 6) no se puede declarar para ella.
      expect(
        () => RegistroHerramientas([
          _Falsa(
            nombre: 'gravity.conversar',
            modulo: Modulo.gravity,
            roles: const {Rol.dueno, Rol.cuidador},
          ),
        ]),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'roles')),
      );
    });

    test('sí puede tener herramientas de la bandeja que confirmen, con '
        'tarjeta de confirmación', () async {
      final confirmar = _Falsa(
        nombre: 'gravity.confirmar_solicitud',
        modulo: Modulo.gravity,
        roles: const {Rol.cuidador},
        escribe: true,
        ambito: AmbitoHerramienta.solicitudes,
      );
      final r = await RegistroHerramientas([confirmar]).ejecutar(
        confirmar.nombre,
        const {'estado': 'hecha'},
        const ContextoHerramienta(rol: Rol.cuidador),
      );
      expect(r.requiereConfirmacion, isTrue);
      expect(confirmar.ejecuciones, 0);
    });

    test('ni marcada como de la bandeja recibe una de Finanzas o de otro '
        'módulo que no le toca', () {
      for (final (modulo, escribe) in [
        (Modulo.finanzas, true),
        (Modulo.finanzas, false),
        (Modulo.habitos, false),
      ]) {
        expect(
          () => RegistroHerramientas([
            _Falsa(
              nombre: '${modulo.name}.de_bandeja',
              modulo: modulo,
              roles: const {Rol.cuidador},
              escribe: escribe,
              soloLocal: true,
              ambito: AmbitoHerramienta.solicitudes,
            ),
          ]),
          throwsArgumentError,
          reason: '${modulo.name} (escribe: $escribe)',
        );
      }
    });

    test('abrir Solicitudes lleva a la ruta de la bandeja y el router la deja '
        'pasar', () async {
      expect(RutasDeHerramientas.solicitudes, RutasApp.solicitudes);
      final rutas = <String>[];
      final r = await registro.ejecutar(
        'gravity.abrir_solicitudes',
        const {},
        ContextoHerramienta(rol: Rol.cuidador, navegar: rutas.add),
      );
      expect(rutas, [RutasApp.solicitudes]);
      expect(r.requiereConfirmacion, isFalse);
      for (final dispositivo in TipoDispositivo.values) {
        expect(
          calcularRedireccion(
            ubicacion: RutasApp.solicitudes,
            rol: Rol.cuidador,
            dispositivo: dispositivo,
          ),
          isNull,
          reason: dispositivo.name,
        );
      }
    });

    test('los demás roles no tienen la bandeja en GRAVITY', () {
      for (final rol in Rol.values.where((r) => r != Rol.cuidador)) {
        expect(
          registro.buscar('gravity.abrir_solicitudes', rol: rol),
          isNull,
          reason: rol.name,
        );
      }
    });
  });

  group('D19: cuenta maestra', () {
    final registro = registroDeGravity();

    test('solo un rol con Finanzas puede ser la cuenta maestra', () {
      expect(
        {for (final rol in Rol.values) if (puedeSerCuentaMaestra(rol)) rol},
        {Rol.dueno, Rol.coadministrador},
      );
    });

    test('no recibe Desarrollador (administra el hogar: es lo ajeno)', () async {
      expect(
        registro.buscar('ajustes.abrir_desarrollador', rol: Rol.dueno),
        isNotNull,
      );
      expect(
        registro.buscar(
          'ajustes.abrir_desarrollador',
          rol: Rol.dueno,
          esMaestra: true,
        ),
        isNull,
      );
      await expectLater(
        registro.ejecutar(
          'ajustes.abrir_desarrollador',
          const {},
          ContextoHerramienta(rol: Rol.dueno, esMaestra: true, navegar: (_) {}),
        ),
        _noDisponiblePor(MotivoNoDisponible.cuentaMaestra),
      );
    });

    test('lo propio sigue igual: abre Finanzas, su semana y la hoja de su '
        'gasto (la hoja solo ofrece sus libros)', () {
      for (final rol in [Rol.dueno, Rol.coadministrador]) {
        final normal = registro
            .disponibles(rol: rol)
            .map((h) => h.nombre)
            .toSet();
        final maestra = registro
            .disponibles(rol: rol, esMaestra: true)
            .map((h) => h.nombre)
            .toSet();
        expect(normal.difference(maestra), {
          if (rol == Rol.dueno) 'ajustes.abrir_desarrollador',
        }, reason: rol.name);
        expect(maestra.difference(normal), isEmpty, reason: rol.name);
      }
    });

    test('ninguna herramienta que escribe o administra lo ajeno aparece para '
        'la cuenta maestra', () {
      final escribeAjeno = _Falsa(
        nombre: 'cuidados.suspender_medicamento',
        modulo: Modulo.cuidados,
        roles: const {Rol.dueno},
        escribe: true,
        soloLocal: true,
        pertenencia: Pertenencia.ajena,
      );
      final conLaDelCatalogo = RegistroHerramientas([
        ...herramientasDeGravity(),
        escribeAjeno,
      ]);
      // El dueño (alcance total en Cuidados) sí la tiene.
      expect(
        conLaDelCatalogo.buscar(escribeAjeno.nombre, rol: Rol.dueno),
        isNotNull,
      );
      for (final rol in Rol.values) {
        for (final h in conLaDelCatalogo.disponibles(
          rol: rol,
          esMaestra: true,
        )) {
          expect(
            h.pertenencia == Pertenencia.ajena && h.accion != Accion.leer,
            isFalse,
            reason: '${h.nombre} / ${rol.name}',
          );
        }
      }
    });

    test('ejecutar una que escribe lo ajeno como cuenta maestra no la '
        'ejecuta ni pide confirmación', () async {
      final h = _Falsa(
        nombre: 'cuidados.suspender_medicamento',
        modulo: Modulo.cuidados,
        roles: const {Rol.dueno},
        escribe: true,
        soloLocal: true,
        pertenencia: Pertenencia.ajena,
      );
      final r = RegistroHerramientas([h]);
      await expectLater(
        r.ejecutar(
          h.nombre,
          const {},
          const ContextoHerramienta(
            rol: Rol.dueno,
            esMaestra: true,
            confirmado: true,
          ),
        ),
        _noDisponiblePor(MotivoNoDisponible.cuentaMaestra),
      );
      expect(h.ejecuciones, 0);
      // Sin la marca, el dueño sí (con su tarjeta de confirmación).
      final pendiente = await r.ejecutar(
        h.nombre,
        const {},
        const ContextoHerramienta(rol: Rol.dueno),
      );
      expect(pendiente.requiereConfirmacion, isTrue);
    });

    test('nadie escribe en el libro de otra persona: ni se puede declarar', () {
      for (final rol in Rol.values) {
        expect(
          () => RegistroHerramientas([
            _Falsa(
              nombre: 'finanzas.anular_ajeno',
              modulo: Modulo.finanzas,
              roles: {rol},
              escribe: true,
              soloLocal: true,
              pertenencia: Pertenencia.ajena,
            ),
          ]),
          throwsArgumentError,
          reason: rol.name,
        );
      }
    });

    test('una de lectura de lo ajeno es solo para la cuenta maestra y solo '
        'local', () async {
      final h = _Falsa(
        nombre: 'finanzas.resumen_de_otro_libro',
        modulo: Modulo.finanzas,
        roles: const {Rol.dueno, Rol.coadministrador},
        soloLocal: true,
        pertenencia: Pertenencia.ajena,
        paraIaQueIntenta: r'Ana gastó $1,234.50',
      );
      final r = RegistroHerramientas([h]);
      expect(r.buscar(h.nombre, rol: Rol.dueno), isNull);
      expect(r.buscar(h.nombre, rol: Rol.dueno, esMaestra: true), isNotNull);
      await expectLater(
        r.ejecutar(h.nombre, const {}, const ContextoHerramienta(rol: Rol.dueno)),
        _noDisponiblePor(MotivoNoDisponible.rolSinPermiso),
      );
      final resultado = await r.ejecutar(
        h.nombre,
        const {},
        const ContextoHerramienta(rol: Rol.coadministrador, esMaestra: true),
      );
      expect(resultado.paraIa, isNull);
    });

    test('la marca no amplía nada a un rol sin Finanzas', () {
      for (final rol in [Rol.familiar, Rol.cuidador, Rol.casa]) {
        expect(
          () => RegistroHerramientas([
            _Falsa(
              nombre: 'finanzas.resumen_de_otro_libro',
              modulo: Modulo.finanzas,
              roles: {rol},
              soloLocal: true,
              pertenencia: Pertenencia.ajena,
            ),
          ]),
          throwsArgumentError,
          reason: rol.name,
        );
        expect(
          registro
              .disponibles(rol: rol, esMaestra: true)
              .map((h) => h.nombre)
              .toSet(),
          registro.disponibles(rol: rol).map((h) => h.nombre).toSet(),
          reason: rol.name,
        );
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

    test('confirmar conserva la marca de cuenta maestra y las pantallas', () {
      void navegar(String _) {}
      void abrirHoja(HojaDeRegistro _) {}
      final ctx = ContextoHerramienta(
        rol: Rol.coadministrador,
        esMaestra: true,
        modulosActivos: const {Modulo.finanzas},
        navegar: navegar,
        abrirHoja: abrirHoja,
      ).confirmar();
      expect(ctx.confirmado, isTrue);
      expect(ctx.esMaestra, isTrue);
      expect(ctx.modulosActivos, {Modulo.finanzas});
      expect(ctx.navegar, same(navegar));
      expect(ctx.abrirHoja, same(abrirHoja));
    });

    test('las que solo leen no piden confirmación', () async {
      final h = _Falsa();
      final r = await RegistroHerramientas(
        [h],
      ).ejecutar(h.nombre, const {}, const ContextoHerramienta(rol: Rol.dueno));
      expect(r.requiereConfirmacion, isFalse);
      expect(h.ejecuciones, 1);
    });

    test('una que escribe debe exigir poder escribir o administrar', () {
      expect(
        () => RegistroHerramientas([
          _Falsa(escribe: true, accion: Accion.leer),
        ]),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'accion')),
      );
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

    test('el catálogo vigente es el de la Fase 0 más el de la Fase 1', () {
      expect(
        herramientasDeGravity().map((h) => h.nombre).toSet(),
        {
          ...herramientasFase0().map((h) => h.nombre),
          ...herramientasFase1().map((h) => h.nombre),
        },
      );
      expect(registroFase0().todas, hasLength(8));
      expect(registroDeGravity().todas, hasLength(11));
    });
  });

  group('Navegación', () {
    test('cada herramienta abre su ruta, no escribe y solo las de Finanzas '
        'y Cuidados callan ante la IA', () async {
      final rutas = <String>[];
      final registro = registroDeGravity();
      for (final h in herramientasNavegacion) {
        expect(h.escribe, isFalse, reason: h.nombre);
        final r = await registro.ejecutar(
          h.nombre,
          const {},
          ContextoHerramienta(rol: h.roles.first, navegar: rutas.add),
        );
        expect(r.requiereConfirmacion, isFalse);
        expect(r.paraIa == null, h.soloLocal, reason: h.nombre);
      }
      expect(rutas, [
        Rutas.inicio,
        Rutas.finanzas,
        // Registrar gasto sin dónde mostrar la hoja: abre Finanzas.
        Rutas.finanzas,
        RutasDeHerramientas.semanaFinanzas,
        Rutas.habitos,
        Rutas.cuidados,
        Rutas.alimentacion,
        Rutas.casa,
        RutasApp.solicitudes,
        Rutas.ajustes,
        Rutas.desarrollador,
      ]);
    });

    test('sin pantalla, avisa y no falla', () async {
      final r = await registroDeGravity().ejecutar(
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
          final esperado = h.ambito == AmbitoHerramienta.solicitudes
              ? soloBandejaEnGravity(rol)
              : puedeAbrir(rol, h.modulo) &&
                    puede(rol, h.modulo, h.accion) &&
                    !soloBandejaEnGravity(rol);
          expect(
            h.roles.contains(rol),
            esperado,
            reason: '${h.nombre} / ${rol.name}',
          );
        }
      }
    });

    test(
      'Desarrollador: rol y dispositivo según puedeVerDesarrollador (D16)',
      () {
        final h = herramientaAbrirDesarrollador;
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
        expect(h.accion, Accion.administrar);
        expect(h.pertenencia, Pertenencia.ajena);
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

  group('Finanzas (Fase 1)', () {
    final registro = registroDeGravity();

    test('"registrar gasto" abre la hoja y no escribe nada', () async {
      final h = herramientaRegistrarGasto;
      expect(h.escribe, isFalse);
      expect(h.accion, Accion.escribir);
      expect(h.hoja, HojaDeRegistro.gasto);
      expect(h.soloLocal, isTrue);
      expect(h.roles, {Rol.dueno, Rol.coadministrador});
      expect(h.titulo, 'Registrar gasto');

      final hojas = <HojaDeRegistro>[];
      final rutas = <String>[];
      final r = await registro.ejecutar(
        h.nombre,
        const {'monto_centavos': 12350},
        ContextoHerramienta(
          rol: Rol.dueno,
          navegar: rutas.add,
          abrirHoja: hojas.add,
        ),
      );
      expect(hojas, [HojaDeRegistro.gasto]);
      expect(rutas, isEmpty);
      expect(r.requiereConfirmacion, isFalse);
      expect(r.paraIa, isNull);
      expect(r.contenido, isNot(contains(r'$')));
      expect(r.contenido, isNot(contains('123')));
    });

    test('ninguna herramienta del catálogo escribe dinero (la hoja es la '
        'confirmación)', () {
      for (final h in registro.todas) {
        expect(h.escribe, isFalse, reason: h.nombre);
      }
    });

    test('"mi semana" abre la semana de Finanzas', () async {
      final h = herramientaAbrirSemanaFinanzas;
      expect(h.ruta, '${Rutas.finanzas}/semana');
      expect(h.roles, {Rol.dueno, Rol.coadministrador});
      expect(h.soloLocal, isTrue);
      final rutas = <String>[];
      await registro.ejecutar(
        h.nombre,
        const {},
        ContextoHerramienta(rol: Rol.coadministrador, navegar: rutas.add),
      );
      expect(rutas, [RutasDeHerramientas.semanaFinanzas]);
    });

    test('el router deja la semana y Finanzas solo a dueño y pareja', () {
      for (final rol in Rol.values) {
        for (final ruta in [
          Rutas.finanzas,
          RutasDeHerramientas.semanaFinanzas,
        ]) {
          final destino = calcularRedireccion(
            ubicacion: ruta,
            rol: rol,
            dispositivo: TipoDispositivo.laptop,
          );
          expect(
            destino == null,
            rol == Rol.dueno || rol == Rol.coadministrador,
            reason: '$ruta / ${rol.name}',
          );
        }
      }
    });
  });
}
