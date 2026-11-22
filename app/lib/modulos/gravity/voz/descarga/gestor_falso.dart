/// Gestor de modelos simulado para las pruebas de la fuente B y de Ajustes:
/// vive en memoria, no toca el disco ni la red, y la prueba maneja a mano lo
/// que pasa con cada descarga.
library;

import 'dart:async';

import '../modelos/catalogo.dart';
import '../modelos/estado_modelo.dart';
import '../tipos.dart';
import 'gestor_de_modelos.dart';

class GestorDeModelosFalso implements GestorDeModelos {
  GestorDeModelosFalso(
    this._modelos, {
    Map<String, EstadoModelo> estados = const {},
  }) : estados = {for (final m in _modelos) m.id: EstadoModelo.noDescargado} {
    this.estados.addAll(estados);
  }

  final List<ModeloDelCatalogo> _modelos;

  /// Estado de cada modelo (la prueba lo cambia).
  final Map<String, EstadoModelo> estados;

  /// Bytes de descarga a medias por modelo.
  final Map<String, int> parciales = {};

  final _cambios = StreamController<void>.broadcast();
  final _flujos = <String, StreamController<ProgresoDescarga>>{};
  final _antes = <Future<void> Function(String)>[];

  /// Cada vez que se pidió descargar: modelo y permiso de datos móviles.
  final descargasPedidas = <({String id, bool datosMoviles})>[];
  final cancelados = <String>[];
  final borrados = <String>[];
  final cargasIniciadas = <String>[];
  final cargasTerminadas = <String>[];
  final marcadosCorruptos = <String>[];
  final reintentados = <String>[];
  final comprobados = <String>[];

  /// Cuánto pesa lo ocupado por cada modelo instalado.
  int ocupadoPorInstalado(ModeloDelCatalogo m) => m.bytes;

  /// Si es `false`, `comprobar` dice que las huellas no coinciden.
  bool huellasBien = true;

  @override
  List<ModeloDelCatalogo> get catalogo => _modelos;

  @override
  Stream<void> get cambios => _cambios.stream;

  void _avisar() => _cambios.add(null);

  /// Cambia el estado de un modelo y avisa.
  void poner(String id, EstadoModelo estado) {
    estados[id] = estado;
    _avisar();
  }

  /// Avanza la descarga en curso del modelo.
  void avanzar(String id, int bytes, {String archivo = 'modelo.onnx'}) {
    final m = _modelos.firstWhere((m) => m.id == id);
    _flujos[id]?.add(ProgresoDescarga(bytes, m.bytes, archivo));
  }

  /// La descarga termina bien: el modelo queda instalado.
  Future<void> terminarDescarga(String id) async {
    estados[id] = EstadoModelo.instalado;
    final m = _modelos.firstWhere((m) => m.id == id);
    _flujos[id]?.add(ProgresoDescarga(m.bytes, m.bytes, 'modelo.onnx'));
    await _flujos.remove(id)?.close();
    _avisar();
  }

  /// La descarga falla con [error].
  Future<void> fallarDescarga(String id, ErrorVoz error) async {
    estados[id] = EstadoModelo.noDescargado;
    _flujos[id]?.addError(error);
    await _flujos.remove(id)?.close();
    _avisar();
  }

  @override
  Future<EstadoModelo> estado(String idModelo) async =>
      estados[idModelo] ?? EstadoModelo.noDescargado;

  @override
  Future<int> bytesDescargados(String idModelo) async =>
      parciales[idModelo] ?? 0;

  @override
  Stream<ProgresoDescarga> descargar(
    String idModelo, {
    bool permitirDatosMoviles = false,
  }) {
    descargasPedidas.add((id: idModelo, datosMoviles: permitirDatosMoviles));
    final existente = _flujos[idModelo];
    if (existente != null) return existente.stream;
    final c = StreamController<ProgresoDescarga>.broadcast();
    _flujos[idModelo] = c;
    estados[idModelo] = EstadoModelo.descargando;
    _avisar();
    return c.stream;
  }

  @override
  Stream<ProgresoDescarga>? seguir(String idModelo) =>
      _flujos[idModelo]?.stream;

  @override
  Future<void> cancelar(String idModelo) async {
    cancelados.add(idModelo);
    estados[idModelo] = EstadoModelo.noDescargado;
    await _flujos.remove(idModelo)?.close();
    _avisar();
  }

  @override
  Future<int> borrar(String idModelo) async {
    for (final hacer in List.of(_antes)) {
      await hacer(idModelo);
    }
    final m = _modelos.firstWhere((m) => m.id == idModelo);
    final liberados = estados[idModelo] == EstadoModelo.noDescargado
        ? (parciales[idModelo] ?? 0)
        : ocupadoPorInstalado(m);
    borrados.add(idModelo);
    estados[idModelo] = EstadoModelo.noDescargado;
    parciales.remove(idModelo);
    await _flujos.remove(idModelo)?.close();
    _avisar();
    return liberados;
  }

  @override
  Future<int> bytesOcupados() async => [
    for (final m in _modelos)
      if (estados[m.id] == EstadoModelo.instalado ||
          estados[m.id] == EstadoModelo.corrupto)
        ocupadoPorInstalado(m),
  ].fold<int>(0, (a, b) => a + b);

  @override
  Future<int> bytesOcupadosPor(String idModelo) async {
    final m = _modelos.firstWhere((m) => m.id == idModelo);
    final e = estados[idModelo];
    return e == EstadoModelo.instalado || e == EstadoModelo.corrupto
        ? ocupadoPorInstalado(m)
        : (parciales[idModelo] ?? 0);
  }

  @override
  Future<bool> comprobar(String idModelo) async {
    comprobados.add(idModelo);
    if (!huellasBien) {
      await marcarCorrupto(idModelo);
      return false;
    }
    return true;
  }

  @override
  Future<EstadoModelo> reintentar(String idModelo) async {
    reintentados.add(idModelo);
    if (estados[idModelo] == EstadoModelo.corrupto) {
      estados[idModelo] = EstadoModelo.instalado;
    }
    _avisar();
    return estados[idModelo] ?? EstadoModelo.noDescargado;
  }

  @override
  Future<RutasDelModelo?> rutasParaCargar(String idModelo) async {
    if (estados[idModelo] != EstadoModelo.instalado) return null;
    final m = _modelos.firstWhere((m) => m.id == idModelo);
    final carpeta = '/falso/$idModelo';
    return RutasDelModelo(
      carpeta: carpeta,
      modelo: '$carpeta/${m.archivoDe(RolDeArchivo.modelo).nombre}',
      tokens: '$carpeta/${m.archivoDe(RolDeArchivo.tokens).nombre}',
      lexicon: m.archivoOpcional(RolDeArchivo.lexicon) == null
          ? null
          : '$carpeta/${m.archivoDe(RolDeArchivo.lexicon).nombre}',
    );
  }

  @override
  Future<void> iniciarCarga(String idModelo) async =>
      cargasIniciadas.add(idModelo);

  @override
  Future<void> terminarCarga(String idModelo) async =>
      cargasTerminadas.add(idModelo);

  @override
  Future<void> marcarCorrupto(String idModelo) async {
    marcadosCorruptos.add(idModelo);
    estados[idModelo] = EstadoModelo.corrupto;
    _avisar();
  }

  @override
  void Function() antesDeBorrar(Future<void> Function(String idModelo) hacer) {
    _antes.add(hacer);
    return () => _antes.remove(hacer);
  }

  Future<void> cerrar() async {
    for (final c in _flujos.values) {
      await c.close();
    }
    await _cambios.close();
  }
}
