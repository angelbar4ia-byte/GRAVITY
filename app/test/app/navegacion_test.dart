import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';

List<String> etiquetas(Rol rol) => [for (final d in destinosDe(rol)) d.etiqueta];

void main() {
  group('pestañas del teléfono (sección 9)', () {
    test('Dueño y Pareja: Hoy · Finanzas · (+) · Hábitos · Más', () {
      const esperadas = ['Hoy', 'Finanzas', 'Registrar', 'Hábitos', 'Más'];
      expect(etiquetas(Rol.dueno), esperadas);
      expect(etiquetas(Rol.coadministrador), esperadas);
    });

    test('Cuidador: Mi turno · Solicitudes · Medicamentos · Comidas · Bitácora', () {
      expect(etiquetas(Rol.cuidador), [
        'Mi turno',
        'Solicitudes',
        'Medicamentos',
        'Comidas',
        'Bitácora',
      ]);
      // Solo Cuidados y su bandeja de solicitudes de GRAVITY (D18).
      expect(
        destinosDe(Rol.cuidador).every(
          (d) =>
              d.ruta!.startsWith(Rutas.cuidados) ||
              d.ruta == RutasApp.solicitudes,
        ),
        isTrue,
      );
    });

    test('Familiar: Hoy · Hábitos · Más (sin dinero)', () {
      expect(etiquetas(Rol.familiar), ['Hoy', 'Hábitos', 'Más']);
    });

    test('Casa: Hoy · Alimentación · Más', () {
      expect(etiquetas(Rol.casa), ['Hoy', 'Alimentación', 'Más']);
    });
  });

  test('(+) solo ofrece lo que el rol puede registrar', () {
    final dueno = [for (final o in opcionesRegistrar(Rol.dueno)) o.etiqueta];
    expect(dueno, contains('Gasto'));
    expect(dueno, contains('Hábito'));
    // D19: la pareja registra en su libro y en los compartidos.
    final pareja = [
      for (final o in opcionesRegistrar(Rol.coadministrador)) o.etiqueta,
    ];
    expect(pareja, containsAll(['Gasto', 'Ingreso extra', 'Hábito']));
    expect(
      [for (final o in opcionesRegistrar(Rol.familiar)) o.etiqueta],
      isNot(contains('Gasto')),
    );
    expect(opcionesRegistrar(Rol.cuidador), isEmpty);
    expect(opcionesRegistrar(Rol.casa), isEmpty);
  });

  test('Más: módulos sin pestaña propia', () {
    expect(modulosEnMas(Rol.dueno), [
      Modulo.cuidados,
      Modulo.alimentacion,
      Modulo.casa,
    ]);
    expect(modulosEnMas(Rol.familiar), [Modulo.alimentacion, Modulo.casa]);
    expect(modulosEnMas(Rol.cuidador), isEmpty);
  });

  test('indiceDestino elige la ruta más larga y cae en Más', () {
    final cuidador = destinosDe(Rol.cuidador);
    expect(indiceDestino(Rutas.cuidados, cuidador), 0);
    expect(indiceDestino(RutasApp.cuidadosComidas, cuidador), 3);
    expect(indiceDestino(RutasApp.solicitudes, cuidador), 1);
    final dueno = destinosDe(Rol.dueno);
    expect(indiceDestino(Rutas.inicio, dueno), 0);
    expect(indiceDestino(Rutas.finanzas, dueno), 1);
    expect(indiceDestino('${Rutas.ajustes}/voz', dueno), 4);
    expect(indiceDestino(Rutas.ajustes, cuidador), isNull);
  });

  test('moduloDeRuta e inicioDe', () {
    expect(moduloDeRuta(Rutas.inicio), Modulo.gravity);
    expect(moduloDeRuta('/finanzas/semana'), Modulo.finanzas);
    expect(moduloDeRuta(Rutas.desarrollador), Modulo.ajustes);
    expect(moduloDeRuta('/finanzasx'), isNull);
    expect(moduloDeRuta(RutasApp.mas), isNull);
    expect(inicioDe(Rol.dueno), Rutas.inicio);
    expect(inicioDe(Rol.casa), Rutas.inicio);
    expect(inicioDe(Rol.cuidador), Rutas.cuidados);
  });

  group('calcularRedireccion', () {
    String? redirigir(
      String ubicacion,
      Rol? rol, [
      TipoDispositivo dispositivo = TipoDispositivo.telefono,
    ]) => calcularRedireccion(
      ubicacion: ubicacion,
      rol: rol,
      dispositivo: dispositivo,
    );

    test('sin sesión todo lleva a Entrar', () {
      expect(redirigir(Rutas.inicio, null), Rutas.entrar);
      expect(redirigir(Rutas.finanzas, null), Rutas.entrar);
      expect(redirigir(Rutas.entrar, null), isNull);
    });

    test('con sesión, Entrar lleva al inicio del rol', () {
      expect(redirigir(Rutas.entrar, Rol.dueno), Rutas.inicio);
      expect(redirigir(Rutas.entrar, Rol.cuidador), Rutas.cuidados);
      expect(redirigir(Rutas.inicio, Rol.cuidador), Rutas.cuidados);
    });

    test('un módulo que el rol no ve regresa al inicio', () {
      expect(redirigir(Rutas.finanzas, Rol.familiar), Rutas.inicio);
      expect(redirigir('/finanzas/semana', Rol.casa), Rutas.inicio);
      expect(redirigir(Rutas.habitos, Rol.cuidador), Rutas.cuidados);
      expect(redirigir(Rutas.ajustes, Rol.casa), Rutas.inicio);
      expect(redirigir(Rutas.finanzas, Rol.dueno), isNull);
      expect(redirigir(RutasApp.cuidadosBitacora, Rol.cuidador), isNull);
    });

    test('Desarrollador solo para el Dueño en la laptop', () {
      expect(
        redirigir(Rutas.desarrollador, Rol.dueno, TipoDispositivo.laptop),
        isNull,
      );
      expect(
        redirigir(Rutas.desarrollador, Rol.dueno, TipoDispositivo.telefono),
        Rutas.ajustes,
      );
      expect(
        redirigir(
          Rutas.desarrollador,
          Rol.coadministrador,
          TipoDispositivo.laptop,
        ),
        Rutas.ajustes,
      );
    });

    test('Personas y roles solo para quien administra', () {
      expect(redirigir('/ajustes/personas', Rol.familiar), Rutas.ajustes);
      expect(redirigir('/ajustes/personas', Rol.dueno), isNull);
      expect(redirigir('/ajustes/voz', Rol.familiar), isNull);
    });

    test('Más no existe en la laptop', () {
      expect(
        redirigir(RutasApp.mas, Rol.dueno, TipoDispositivo.laptop),
        Rutas.inicio,
      );
      expect(redirigir(RutasApp.mas, Rol.dueno), isNull);
    });
  });
}
