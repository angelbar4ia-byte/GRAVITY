/// El aviso del banco (spec 3.2, G6-M3): antes de la **primera vez** que una
/// sesión usa el banco (fondos, subidas, sentadilla al banco o puente apoyado),
/// se pide comprobar en el aparato su capacidad y su estabilidad, y la persona
/// lo confirma. **Una sola vez por persona.**
///
/// Solo se guarda **en este equipo**, en la copia local de la persona
/// (`habitos.copia.<persona>`, la que borra la limpieza al salir o dar de baja),
/// junto a lo del modo foco: una fecha y nada más. No se sube a ninguna parte.
library;

import 'dart:convert';

import 'package:habitos_dominio/habitos_dominio.dart';

import '../../../../nucleo/contratos/roles.dart';
import '../../../../nucleo/seguridad/almacen_seguro.dart';
import '../../../../nucleo/seguridad/limpieza_local.dart' show claveCopiaLocal;

/// El id del aparato del banco en el catálogo (`requiere` de las variantes).
const idBancoInclinado = 'banco_inclinado';

/// ¿La sesión usa el banco en algún ejercicio?
bool sesionUsaBanco(SesionPlanificada sesion, Catalogo catalogo) =>
    sesion.ejercicios.any(
      (e) =>
          catalogo
              .variante(e.varianteId)
              ?.requiere
              .contains(idBancoInclinado) ??
          false,
    );

class AvisoBancoLocal {
  AvisoBancoLocal(this._almacen, this.persona);

  final AlmacenSeguro _almacen;
  final String persona;

  static const _campo = 'gim_banco_revisado';

  String get _clave => claveCopiaLocal(Modulo.habitos, persona);

  Future<Map<String, Object?>> _leer() async {
    try {
      final t = await _almacen.leer(_clave);
      if (t == null) return {};
      return (jsonDecode(t) as Map).cast<String, Object?>();
    } catch (_) {
      return {};
    }
  }

  /// ¿La persona ya confirmó que revisó el banco?
  Future<bool> revisado() async => (await _leer())[_campo] != null;

  /// «Ya lo revisé»: se guarda la fecha y no vuelve a salir.
  Future<void> marcarRevisado(DateTime ahora) async {
    final m = await _leer();
    m[_campo] = ahora.toUtc().toIso8601String().substring(0, 10);
    await _almacen.escribir(_clave, jsonEncode(m));
  }
}
