import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

import 'ayuda_pruebas.dart';

/// La persona frente a la pantalla, que la prueba puede cambiar.
class _Persona extends Notifier<String?> {
  @override
  String? build() => 'ana';

  void cambiar(String? id) => state = id;
}

final _personaFalsa = NotifierProvider<_Persona, String?>(_Persona.new);

ProviderContainer _contenedor([AlmacenApariencia? almacen]) {
  final c = ProviderContainer(
    overrides: [
      personaEnPantallaProvider.overrideWith((ref) => ref.watch(_personaFalsa)),
      if (almacen != null) almacenAparienciaProvider.overrideWithValue(almacen),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('Apariencia por persona (P3)', () {
    test('cada persona tiene su estilo y no pisa el de otra', () {
      final c = _contenedor();
      c.read(estiloProvider.notifier).elegir(estiloBento);
      expect(c.read(estiloProvider), estiloBento);

      c.read(_personaFalsa.notifier).cambiar('beto');
      expect(c.read(estiloProvider), estiloFuturista);
      c.read(estiloProvider.notifier).elegir(estiloFuturista);

      c.read(_personaFalsa.notifier).cambiar('ana');
      expect(c.read(estiloProvider), estiloBento);
    });

    test('la tablet de la casa (sin persona) tiene el suyo', () {
      final c = _contenedor();
      c.read(estiloProvider.notifier).elegir(estiloBento);
      c.read(_personaFalsa.notifier).cambiar(null);
      expect(c.read(claveAparienciaProvider), claveHogar);
      expect(c.read(estiloProvider), estiloFuturista);
      c.read(estiloProvider.notifier).elegirPorId('bento');
      c.read(_personaFalsa.notifier).cambiar('ana');
      c.read(estiloProvider.notifier).elegir(estiloFuturista);
      c.read(_personaFalsa.notifier).cambiar(null);
      expect(c.read(estiloProvider), estiloBento);
    });

    test('claro/oscuro, lugar y alto contraste también son por persona', () {
      final c = _contenedor();
      c
          .read(preferenciaClaroOscuroProvider.notifier)
          .fijar(
            PreferenciaClaroOscuro(
              modo: ModoClaroOscuro.automaticoPorHora,
              horario: const HorarioClaro(
                inicio: TimeOfDay(hour: 6, minute: 15),
                fin: TimeOfDay(hour: 20, minute: 45),
              ),
              lugar: lugarSolarPorId('cancun'),
            ),
          );
      c.read(altoContrasteProvider.notifier).fijar(true);

      c.read(_personaFalsa.notifier).cambiar('beto');
      expect(
        c.read(preferenciaClaroOscuroProvider),
        const PreferenciaClaroOscuro(),
      );
      expect(c.read(altoContrasteProvider), isFalse);

      c.read(_personaFalsa.notifier).cambiar('ana');
      final p = c.read(preferenciaClaroOscuroProvider);
      expect(p.modo, ModoClaroOscuro.automaticoPorHora);
      expect(p.horario.inicio, const TimeOfDay(hour: 6, minute: 15));
      expect(p.horario.fin, const TimeOfDay(hour: 20, minute: 45));
      expect(p.lugar.id, 'cancun');
      expect(c.read(altoContrasteProvider), isTrue);
    });

    test(
      'lo guardado sobrevive a un contenedor nuevo con el mismo almacén',
      () {
        final almacen = AlmacenAparienciaMemoria();
        _contenedor(almacen).read(estiloProvider.notifier).elegir(estiloBento);
        final otro = _contenedor(almacen);
        expect(otro.read(estiloProvider), estiloBento);
      },
    );

    test('un valor guardado que no se entiende regresa a lo de omisión', () {
      final almacen = AlmacenAparienciaMemoria()
        ..guardar('ana', CampoApariencia.estilo, 'no-existe')
        ..guardar('ana', CampoApariencia.modo, 'raro')
        ..guardar('ana', CampoApariencia.horario, '99:99-xx')
        ..guardar('ana', CampoApariencia.lugar, 'luna');
      final c = _contenedor(almacen);
      expect(c.read(estiloProvider), estiloPorDefecto);
      final p = c.read(preferenciaClaroOscuroProvider);
      expect(p.modo, ModoClaroOscuro.automaticoSolar);
      expect(p.horario, HorarioClaro.porDefecto);
      expect(p.lugar, lugarSolarPorDefecto);
    });

    test('el almacén no guarda nada sensible: solo estas claves', () {
      final almacen = AlmacenAparienciaMemoria();
      final c = _contenedor(almacen);
      c.read(estiloProvider.notifier).elegir(estiloBento);
      c.read(altoContrasteProvider.notifier).fijar(true);
      c
          .read(preferenciaClaroOscuroProvider.notifier)
          .cambiarModo(ModoClaroOscuro.oscuro);
      expect(almacen.leer('ana', CampoApariencia.estilo), 'bento');
      expect(almacen.leer('ana', CampoApariencia.altoContraste), 'true');
      expect(almacen.leer('ana', CampoApariencia.modo), 'oscuro');
    });
  });

  testWidgets('Configuración: elegir Bento cambia el tema en vivo y el '
      'cambio queda para esa persona', (tester) async {
    fijarVentana(tester, const Size(1000, 1200));
    await montar(
      tester,
      const Scaffold(body: SingleChildScrollView(child: SeccionApariencia())),
    );
    ValoresDiseno valores() =>
        ValoresDiseno.de(tester.element(find.byType(SeccionApariencia)));
    expect(find.byKey(const ValueKey('apariencia-por-persona')), findsOne);
    expect(valores().fuenteTitulos, FuentesGravity.titulos);

    await tester.tap(find.byKey(const ValueKey('estilo-bento')));
    await tester.pump();
    await tester.pump(duracionCambioTema);
    expect(valores().radioMediano, 20);

    await tester.ensureVisible(find.byKey(const ValueKey('alto-contraste')));
    await tester.tap(find.byKey(const ValueKey('alto-contraste')));
    await tester.pump();
    await tester.pump(duracionCambioTema);
    expect(valores().altoContraste, isTrue);
    expect(
      contenedorDe(tester, find.byType(SeccionApariencia))
          .read(almacenAparienciaProvider)
          .leer(claveHogar, CampoApariencia.estilo),
      'bento',
    );
  });
}
