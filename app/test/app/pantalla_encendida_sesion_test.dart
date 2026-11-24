// H-14: la sesión de gimnasio en curso mantiene la pantalla encendida y la
// suelta al terminar, al cambiar de persona y al apagar el proveedor.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/gimnasio/proveedores_gimnasio.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show sesionDeEjemplo;
import 'package:gravity/nucleo/sesion/sesion.dart';
import 'package:gravity/nucleo/tablet/retencion_sesion_gimnasio.dart'
    show SesionGimnasioEnCurso;

/// Cuenta los pedidos y las sueltas.
class _Espia implements PantallaEncendida {
  int pedidos = 0;
  int vigentes = 0;

  @override
  bool get disponible => true;

  @override
  Future<bool> mantener(bool encendida) async => true;

  @override
  void Function() pedir() {
    pedidos++;
    vigentes++;
    var soltado = false;
    return () {
      if (soltado) return;
      soltado = true;
      vigentes--;
    };
  }
}

class _Persona extends Notifier<Sesion?> {
  _Persona(this._inicial);
  final Sesion? _inicial;
  @override
  Sesion? build() => _inicial;
  void cambiar(Sesion? s) => state = s;
}

void main() {
  final dueno = sesionDeEjemplo(Rol.dueno);
  final otra = sesionDeEjemplo(Rol.casa);
  final personaProvider = NotifierProvider<_Persona, Sesion?>(
    () => _Persona(dueno),
  );

  late _Espia espia;
  late ProviderContainer c;

  setUp(() {
    espia = _Espia();
    c = ProviderContainer(
      overrides: [
        pantallaEncendidaProvider.overrideWithValue(espia),
        sesionEfectivaProvider.overrideWith(
          (ref) => ref.watch(personaProvider),
        ),
      ],
    );
    addTearDown(c.dispose);
    // Como AppGravity: alguien lo mantiene vivo.
    c.listen(pantallaEncendidaDeLaSesionProvider, (_, _) {});
  });

  SesionGimnasioEnCurso sesion() =>
      c.read(sesionGimnasioEnCursoProvider.notifier);

  test('sin sesión en curso, no pide nada', () async {
    expect(c.read(pantallaEncendidaDeLaSesionProvider), isFalse);
    expect(espia.pedidos, 0);
  });

  test('al iniciar o retomar pide la pantalla; al terminar la suelta', () async {
    sesion().iniciar(dueno.persona.id);
    await c.pump();
    expect(c.read(pantallaEncendidaDeLaSesionProvider), isTrue);
    expect(espia.vigentes, 1);
    sesion().terminar();
    await c.pump();
    expect(c.read(pantallaEncendidaDeLaSesionProvider), isFalse);
    expect(espia.vigentes, 0);
  });

  test('iniciar de nuevo (retomar) no suma pedidos', () async {
    sesion().iniciar(dueno.persona.id);
    await c.pump();
    sesion().iniciar(dueno.persona.id);
    await c.pump();
    expect(espia.pedidos, 1);
    expect(espia.vigentes, 1);
  });

  test('si cambia la persona en pantalla, se suelta', () async {
    sesion().iniciar(dueno.persona.id);
    await c.pump();
    expect(espia.vigentes, 1);
    c.read(personaProvider.notifier).cambiar(otra);
    await c.pump();
    expect(c.read(pantallaEncendidaDeLaSesionProvider), isFalse);
    expect(espia.vigentes, 0);
  });

  test('la sesión de otra persona no enciende la pantalla de esta', () async {
    sesion().iniciar('otra-persona');
    await c.pump();
    expect(espia.pedidos, 0);
  });

  test('renovar la sesión de la misma persona no suelta ni vuelve a pedir', () async {
    sesion().iniciar(dueno.persona.id);
    await c.pump();
    c.read(personaProvider.notifier).cambiar(
      Sesion(persona: dueno.persona, rol: dueno.rol, hogarId: 'otro-hogar'),
    );
    await c.pump();
    expect(espia.pedidos, 1);
    expect(espia.vigentes, 1);
  });

  test('al apagar el contenedor se suelta', () async {
    sesion().iniciar(dueno.persona.id);
    await c.pump();
    c.dispose();
    expect(espia.vigentes, 0);
  });

  test('sin Android el proveedor no rompe nada: la nula', () async {
    final solo = ProviderContainer(
      overrides: [
        sesionEfectivaProvider.overrideWith((ref) => dueno),
      ],
    );
    addTearDown(solo.dispose);
    solo.listen(pantallaEncendidaDeLaSesionProvider, (_, _) {});
    solo.read(sesionGimnasioEnCursoProvider.notifier).iniciar(dueno.persona.id);
    await solo.pump();
    expect(solo.read(pantallaEncendidaDeLaSesionProvider), isTrue);
    expect(solo.read(pantallaEncendidaProvider).disponible, isFalse);
  });
}
