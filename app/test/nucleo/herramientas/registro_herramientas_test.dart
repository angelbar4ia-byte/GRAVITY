import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';
import 'package:gravity/nucleo/permisos/permisos.dart';

/// Herramienta de prueba con contador de ejecuciones.
final class _Falsa extends Herramienta {
  _Falsa({
    this.nombre = 'finanzas.resumen_semana',
    this.modulo = Modulo.finanzas,
    this.roles = const {Rol.dueno, Rol.coadministrador},
    this.escribe = false,
    this.soloLocal = false,
    this.paraIaQueIntenta = 'Resumen listo.',
    this.resultadoAjeno,
  });

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

  int ejecuciones = 0;

  @override
  String get descripcion => 'Herramienta de prueba.';

  @override
  Future<ResultadoHerramienta> ejecutar(
    Map<String, Object?> parametros,
    ContextoHerramienta ctx,
  ) async {
    ejecuciones++;
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
      final h = _Falsa(soloLocal: true, paraIaQueIntenta: r'Gastaste $1,234.50');
      final r = await RegistroHerramientas([h]).ejecutar(
        h.nombre,
        const {},
        const ContextoHerramienta(rol: Rol.dueno),
      );
      expect(h.ejecuciones, 1);
      expect(r.contenido, contains(r'$1,234.50'));
      expect(r.paraIa, isNull);
    });

    test('ni si intenta devolver el resultado de otra herramienta', () async {
      final ajena = _Falsa(nombre: 'habitos.resumen', modulo: Modulo.habitos);
      final tramposa = _Falsa(
        soloLocal: true,
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
      final r = await RegistroHerramientas([h]).ejecutar(
        h.nombre,
        const {},
        const ContextoHerramienta(rol: Rol.dueno),
      );
      expect(r.paraIa, 'Resumen listo.');
    });
  });

  group('Confirmación', () {
    test('las que escriben piden confirmación y no se ejecutan', () async {
      final h = _Falsa(nombre: 'finanzas.registrar_gasto', escribe: true);
      final r = await RegistroHerramientas([h]).ejecutar(
        h.nombre,
        const {'monto_centavos': 12350},
        const ContextoHerramienta(rol: Rol.dueno),
      );
      expect(r.requiereConfirmacion, isTrue);
      expect(r.paraIa, isNull);
      expect(r.contenido, isNotEmpty);
      expect(h.ejecuciones, 0);
    });

    test('ya confirmadas, se ejecutan una vez', () async {
      final h = _Falsa(nombre: 'finanzas.registrar_gasto', escribe: true);
      const ctx = ContextoHerramienta(rol: Rol.dueno);
      final r = await RegistroHerramientas([h]).ejecutar(
        h.nombre,
        const {'monto_centavos': 12350},
        ctx.confirmar(),
      );
      expect(r.requiereConfirmacion, isFalse);
      expect(h.ejecuciones, 1);
    });

    test('las que solo leen no piden confirmación', () async {
      final h = _Falsa();
      final r = await RegistroHerramientas([h]).ejecutar(
        h.nombre,
        const {},
        const ContextoHerramienta(rol: Rol.dueno),
      );
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
          _Falsa(nombre: 'habitos.resumen', modulo: Modulo.finanzas),
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
  });
}
