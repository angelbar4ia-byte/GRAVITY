// M8 (docs/revisiones/fase-0.md): el modo privado y los montos mostrados no
// pasan de una persona a la siguiente (tablet compartida).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';

/// Persona frente a la pantalla, que la prueba cambia (como la tablet al
/// entrar con PIN o volver al modo Casa).
class _Persona extends Notifier<String?> {
  @override
  String? build() => 'dueno';

  void cambiar(String? persona) => state = persona;
}

final _personaProvider = NotifierProvider<_Persona, String?>(_Persona.new);

void main() {
  ProviderContainer contenedor() {
    final c = ProviderContainer(
      overrides: [
        personaEnPantallaProvider.overrideWith(
          (ref) => ref.watch(_personaProvider),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('sin conectar a la sesión, empieza oculto y sin modo privado', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(personaEnPantallaProvider), isNull);
    expect(c.read(montosOcultosProvider), isTrue);
    expect(c.read(modoPrivadoProvider), isFalse);
  });

  test('los montos que mostró una persona se ocultan para la siguiente', () {
    final c = contenedor();
    c.read(montosVisiblesProvider.notifier).fijar(true);
    expect(c.read(montosOcultosProvider), isFalse);

    c.read(_personaProvider.notifier).cambiar('familiar');
    expect(c.read(montosVisiblesProvider), isFalse);
    expect(c.read(montosOcultosProvider), isTrue);
  });

  test('el modo privado de una persona no pasa a la siguiente', () {
    final c = contenedor();
    c.read(modoPrivadoProvider.notifier).fijar(true);
    expect(c.read(modoPrivadoProvider), isTrue);

    c.read(_personaProvider.notifier).cambiar(null); // regresa al modo Casa
    expect(c.read(modoPrivadoProvider), isFalse);
  });

  test('con la misma persona, lo elegido se conserva', () {
    final c = contenedor();
    c.read(montosVisiblesProvider.notifier).fijar(true);
    c.read(_personaProvider.notifier).cambiar('dueno');
    expect(c.read(montosVisiblesProvider), isTrue);
  });
}
