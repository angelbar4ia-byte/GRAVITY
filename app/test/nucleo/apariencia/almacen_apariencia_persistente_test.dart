// La apariencia por persona sobrevive al reinicio (P3, D22).
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/almacen_apariencia.dart';
import 'package:gravity/nucleo/apariencia/almacen_apariencia_persistente.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('guarda por persona y lo recupera al "reiniciar"', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await AlmacenAparienciaPersistente.abrir();
    a.guardar('ana', CampoApariencia.estilo, 'glass');
    a.guardar('hogar', CampoApariencia.estilo, 'glass');
    expect(a.leer('ana', CampoApariencia.estilo), 'glass');
    await Future<void>.delayed(Duration.zero);
    final b = AlmacenAparienciaPersistente(
      await SharedPreferences.getInstance(),
    );
    expect(b.leer('ana', CampoApariencia.estilo), 'glass');
    expect(b.leer('hogar', CampoApariencia.estilo), 'glass');
    expect(b.leer('luis', CampoApariencia.estilo), isNull);
  });

  test('null borra el campo', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await AlmacenAparienciaPersistente.abrir();
    a.guardar('ana', CampoApariencia.modo, 'oscuro');
    a.guardar('ana', CampoApariencia.modo, null);
    expect(a.leer('ana', CampoApariencia.modo), isNull);
  });
}
