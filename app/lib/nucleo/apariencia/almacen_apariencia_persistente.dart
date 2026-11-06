/// Almacén persistente de la apariencia por persona (P3 del dueño, D22):
/// conecta la puerta `AlmacenApariencia` del sistema de diseño con
/// `shared_preferences`. Lee de una copia ya cargada (la lectura del diseño es
/// síncrona) y escribe sin esperar. No guarda nada sensible: estilo, claro u
/// oscuro, lugar del sol y alto contraste.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../diseno/almacen_apariencia.dart';

class AlmacenAparienciaPersistente implements AlmacenApariencia {
  AlmacenAparienciaPersistente(this._preferencias);

  /// Abre las preferencias del equipo (se llama una vez en el arranque).
  static Future<AlmacenAparienciaPersistente> abrir() async =>
      AlmacenAparienciaPersistente(await SharedPreferences.getInstance());

  static const prefijo = 'apariencia/';

  final SharedPreferences _preferencias;

  @override
  String? leer(String clave, String campo) {
    try {
      return _preferencias.getString('$prefijo$clave/$campo');
    } catch (error) {
      debugPrint('Apariencia: $error');
      return null;
    }
  }

  @override
  void guardar(String clave, String campo, String? valor) {
    final llave = '$prefijo$clave/$campo';
    final futuro = valor == null
        ? _preferencias.remove(llave)
        : _preferencias.setString(llave, valor);
    futuro.catchError((Object error) {
      debugPrint('Apariencia: $error');
      return false;
    });
  }
}
