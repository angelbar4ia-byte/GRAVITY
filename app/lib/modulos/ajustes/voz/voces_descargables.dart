/// Ajustes › Voz › Voces descargables (motor de voz, P3.2a-2, spec 4.2.2 y
/// 5.1 punto 3).
///
/// Por cada voz del catálogo: nombre, voces, **tamaño total**, licencia y
/// atribución, y su estado. Botones *Descargar (70 MB)*, *Cancelar*, *Borrar*,
/// *Comprobar* y *Probar*.
///
/// Reglas:
/// - **Ninguna conexión hasta que la persona toca Descargar** (criterio 17):
///   la pantalla solo lee el catálogo y el disco.
/// - **Solo Wi-Fi o Ethernet**; con datos móviles se pide confirmación **cada
///   vez** y no se recuerda; sin red solo se avisa (pregunta 8, criterio 18).
/// - **Estados honestos:** si el alojamiento todavía no tiene el archivo, dice
///   *no disponible aún* (no es un error de la red de la persona).
/// - El estado nunca se dice solo con color: siempre hay icono y palabras, y
///   el avance lleva etiqueta para el lector de pantalla.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/conectividad/tipo_de_red.dart';
import '../../gravity/voz/descarga/gestor_de_modelos.dart';
import '../../gravity/voz/fuentes/modelo/fuente_modelo.dart';
import '../../gravity/voz/modelos/catalogo.dart';
import '../../gravity/voz/modelos/estado_modelo.dart';
import '../../gravity/voz/proveedores.dart';
import '../../gravity/voz/tipos.dart';
import 'prueba_voz.dart';

/// Lo que la pantalla sabe de un modelo.
@immutable
class InfoDeModelo {
  const InfoDeModelo({
    this.estado = EstadoModelo.noDescargado,
    this.parcial = 0,
    this.ocupado = 0,
    this.progreso,
    this.error,
    this.aviso,
  });

  final EstadoModelo estado;

  /// Bytes de una descarga a medias.
  final int parcial;

  /// Lo que ocupa en el equipo.
  final int ocupado;
  final ProgresoDescarga? progreso;

  /// Cómo terminó la última descarga, si falló.
  final ErrorVoz? error;

  /// Un aviso suelto (sin red, "Liberaste 70 MB"…).
  final String? aviso;

  InfoDeModelo copiar({
    EstadoModelo? estado,
    int? parcial,
    int? ocupado,
    Object? progreso = _igual,
    Object? error = _igual,
    Object? aviso = _igual,
  }) => InfoDeModelo(
    estado: estado ?? this.estado,
    parcial: parcial ?? this.parcial,
    ocupado: ocupado ?? this.ocupado,
    progreso: identical(progreso, _igual)
        ? this.progreso
        : progreso as ProgresoDescarga?,
    error: identical(error, _igual) ? this.error : error as ErrorVoz?,
    aviso: identical(aviso, _igual) ? this.aviso : aviso as String?,
  );

  static const Object _igual = Object();
}

@immutable
class EstadoDeVoces {
  const EstadoDeVoces({this.modelos = const {}, this.bytesOcupados = 0});
  final Map<String, InfoDeModelo> modelos;
  final int bytesOcupados;

  InfoDeModelo de(String id) => modelos[id] ?? const InfoDeModelo();
}

final vocesDescargablesProvider =
    NotifierProvider.autoDispose<VocesDescargablesEstado, EstadoDeVoces>(
      VocesDescargablesEstado.new,
    );

class VocesDescargablesEstado extends Notifier<EstadoDeVoces> {
  final _suscripciones = <String, StreamSubscription<ProgresoDescarga>>{};
  StreamSubscription<void>? _cambios;

  GestorDeModelos get _gestor => ref.read(gestorDeModelosProvider)!;

  @override
  EstadoDeVoces build() {
    final gestor = ref.watch(gestorDeModelosProvider);
    if (gestor == null) return const EstadoDeVoces();
    _cambios = gestor.cambios.listen((_) => unawaited(refrescar()));
    ref.onDispose(() {
      _cambios?.cancel();
      for (final s in _suscripciones.values) {
        // Las descargas siguen en el gestor: la pantalla solo deja de oír.
        s.cancel();
      }
      _suscripciones.clear();
    });
    // Lo que ya se esté descargando (la pantalla se abrió después de tocar
    // Descargar).
    for (final m in gestor.catalogo) {
      final flujo = gestor.seguir(m.id);
      if (flujo != null) _escuchar(m.id, flujo);
    }
    unawaited(Future.microtask(refrescar));
    return const EstadoDeVoces();
  }

  Future<void> refrescar() async {
    final gestor = ref.read(gestorDeModelosProvider);
    if (gestor == null || !ref.mounted) return;
    final nuevos = <String, InfoDeModelo>{};
    for (final m in gestor.catalogo) {
      final estado = await gestor.estado(m.id);
      final parcial = estado == EstadoModelo.noDescargado
          ? await gestor.bytesDescargados(m.id)
          : 0;
      final ocupado = await gestor.bytesOcupadosPor(m.id);
      if (!ref.mounted) return;
      final previo = state.de(m.id);
      nuevos[m.id] = previo.copiar(
        estado: estado,
        parcial: parcial,
        ocupado: ocupado,
        progreso: estado == EstadoModelo.descargando ? previo.progreso : null,
      );
    }
    final total = await gestor.bytesOcupados();
    if (!ref.mounted) return;
    state = EstadoDeVoces(modelos: nuevos, bytesOcupados: total);
  }

  void _poner(String id, InfoDeModelo Function(InfoDeModelo) cambiar) {
    if (!ref.mounted) return;
    state = EstadoDeVoces(
      modelos: {...state.modelos, id: cambiar(state.de(id))},
      bytesOcupados: state.bytesOcupados,
    );
  }

  void avisar(String id, String? aviso) =>
      _poner(id, (i) => i.copiar(aviso: aviso, error: null));

  void _escuchar(String id, Stream<ProgresoDescarga> flujo) {
    _suscripciones[id]?.cancel();
    _suscripciones[id] = flujo.listen(
      (p) => _poner(id, (i) => i.copiar(progreso: p)),
      onError: (Object e) {
        _poner(
          id,
          (i) => i.copiar(
            progreso: null,
            error: e is ErrorVoz
                ? e
                : const FalloDeSintesis(Fuente.modelo, 'desconocido'),
            aviso: null,
          ),
        );
        unawaited(refrescar());
      },
      onDone: () {
        _poner(id, (i) => i.copiar(progreso: null));
        unawaited(refrescar());
      },
    );
  }

  /// Empieza (o reanuda) la descarga. [datosMoviles] es el permiso de **esta**
  /// descarga: no se guarda.
  void descargar(String id, {bool datosMoviles = false}) {
    _poner(id, (i) => i.copiar(error: null, aviso: null));
    _escuchar(id, _gestor.descargar(id, permitirDatosMoviles: datosMoviles));
  }

  Future<void> cancelar(String id) async {
    await _gestor.cancelar(id);
    await refrescar();
  }

  Future<void> borrar(String id) async {
    final liberados = await _gestor.borrar(id);
    _poner(
      id,
      (i) => i.copiar(
        progreso: null,
        error: null,
        aviso: 'Liberaste ${formatearBytes(liberados)}.',
      ),
    );
    await refrescar();
  }

  Future<void> comprobar(String id) async {
    _poner(id, (i) => i.copiar(aviso: 'Comprobando…', error: null));
    final bien = await _gestor.comprobar(id);
    _poner(
      id,
      (i) => i.copiar(
        aviso: bien ? 'Todo en orden: los archivos son los esperados.' : 'Algún archivo no era el esperado. Borra la voz y vuelve a descargarla.',
      ),
    );
    await refrescar();
  }

  Future<void> reintentar(String id) async {
    final estado = await _gestor.reintentar(id);
    _poner(
      id,
      (i) => i.copiar(
        aviso: estado == EstadoModelo.instalado
            ? 'La voz está lista otra vez.'
            : 'La voz sigue dañada. Bórrala y vuelve a descargarla.',
        error: null,
      ),
    );
    await refrescar();
  }
}

/// Mensajes del tono de GRAVITY: tranquilos, breves y sin culpa (spec 5.5).
String mensajeDeErrorDeDescarga(ErrorVoz error, InfoDeModelo info, int total) {
  return switch (error) {
    SinWifi() =>
      'Solo se descarga con Wi-Fi, o con tu permiso si usas datos móviles. '
          'Vuelve a tocar Descargar.',
    SinRed() => 'No hay conexión. Cuando vuelva, puedes continuar la descarga.',
    SinEspacio(:final bytesNecesarios) =>
      'No hay espacio para esta voz. Necesitas liberar '
          '${formatearBytes(bytesNecesarios)}.',
    HuellaIncorrecta() =>
      'El archivo no era el esperado y se borró. Vuelve a intentarlo; si sigue '
          'igual, revisa tu conexión.',
    DescargaInterrumpida(:final bytes, :final total) =>
      'La descarga se detuvo en ${total <= 0 ? 0 : (bytes * 100 ~/ total)} %.',
    NoDisponibleAun() =>
      'Esta voz todavía no está disponible para descargar. Cuando esté lista, '
          'aparecerá aquí.',
    _ => 'No se pudo descargar la voz. Puedes intentarlo otra vez.',
  };
}

/// "inglés americano, mujer" para una voz del catálogo.
String _describirVoz(VozDeModelo v) {
  final genero = switch (v.genero) {
    Genero.mujer => 'mujer',
    Genero.hombre => 'hombre',
    Genero.sinDato => '',
  };
  final acento = v.acentoAproximado ? ' · acento aproximado' : '';
  return '${v.nombre} · ${v.variante.nombre.toLowerCase()}'
      '${genero.isEmpty ? '' : ' · $genero'}$acento';
}

class VocesDescargablesCard extends ConsumerWidget {
  const VocesDescargablesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestor = ref.watch(gestorDeModelosProvider);
    if (gestor == null) return const SizedBox.shrink();
    final texto = Theme.of(context).textTheme;
    final estado = ref.watch(vocesDescargablesProvider);
    return Card(
      key: const ValueKey('voces-descargables'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voces descargables', style: texto.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Voces más naturales que se descargan una sola vez y después '
              'funcionan sin conexión. Se descargan solo con Wi-Fi, y solo '
              'cuando tú tocas Descargar. El sitio que aloja el archivo verá '
              'la dirección de internet de este equipo; no se envía nada '
              'tuyo.',
              style: texto.bodyMedium,
            ),
            for (final modelo in gestor.catalogo) ...[
              const Divider(height: 24),
              _TarjetaDeModelo(modelo: modelo, info: estado.de(modelo.id)),
            ],
            const Divider(height: 24),
            _DialogoDeVoces(gestor: gestor, estado: estado),
            const SizedBox(height: 12),
            Text(
              'Espacio usado por las voces: ${formatearBytes(estado.bytesOcupados)}',
              key: const ValueKey('voces-espacio'),
              style: texto.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// El diálogo de prueba de dos voces con las voces descargadas: F1 es la
/// mujer y M1 el hombre (el motor las reparte por género). Sirve para oír
/// que las dos voces suenan distintas (criterios 39 y 40).
class _DialogoDeVoces extends ConsumerWidget {
  const _DialogoDeVoces({required this.gestor, required this.estado});

  final GestorDeModelos gestor;
  final EstadoDeVoces estado;

  static const _clave = 'voces-dialogo';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = Theme.of(context).textTheme;
    final prueba = ref.watch(pruebaVozProvider);
    var mujer = false;
    var hombre = false;
    for (final m in gestor.catalogo) {
      if (!m.cargable || estado.de(m.id).estado != EstadoModelo.instalado) {
        continue;
      }
      for (final v in m.voces.where((v) => v.variante == Variante.enUS)) {
        mujer = mujer || v.genero == Genero.mujer;
        hombre = hombre || v.genero == Genero.hombre;
      }
    }
    final hay = mujer && hombre;
    final suena = prueba.clave == _clave;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('$_clave-en-US'),
              onPressed: hay
                  ? () => unawaited(
                      ref
                          .read(pruebaVozProvider.notifier)
                          .probar(
                            clave: _clave,
                            guion: const Guion(
                              id: 'prueba-dialogo',
                              variante: Variante.enUS,
                              turnos: dialogoDePrueba,
                            ),
                            uso: UsoVoz.curso,
                            fuente: Fuente.modelo,
                          ),
                    )
                  : null,
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Diálogo de prueba (2 voces)'),
            ),
            if (suena && (prueba.sonando || prueba.hayOtraVoz))
              TextButton.icon(
                key: const ValueKey('$_clave-parar'),
                onPressed: () =>
                    unawaited(ref.read(pruebaVozProvider.notifier).parar()),
                icon: const Icon(Icons.stop),
                label: const Text('Parar'),
              ),
          ],
        ),
        if (!hay)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Para el diálogo hacen falta una voz de mujer y una de hombre '
              'descargadas, en inglés americano.',
              key: const ValueKey('$_clave-falta'),
              style: texto.bodySmall,
            ),
          ),
        if (suena && prueba.mensaje != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                prueba.mensaje!,
                key: const ValueKey('$_clave-mensaje'),
                style: texto.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _TarjetaDeModelo extends ConsumerWidget {
  const _TarjetaDeModelo({required this.modelo, required this.info});

  final ModeloDelCatalogo modelo;
  final InfoDeModelo info;

  String get _clave => 'modelo-${modelo.id}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = Theme.of(context).textTheme;
    final prueba = ref.watch(pruebaVozProvider);
    final miPrueba = prueba.clave == '$_clave-probar';
    return Column(
      key: ValueKey(_clave),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(modelo.nombre, style: texto.titleSmall),
        const SizedBox(height: 4),
        for (final v in modelo.voces)
          Text('Voz: ${_describirVoz(v)}', style: texto.bodyMedium),
        Text(
          'Pesa ${formatearBytes(modelo.bytes)} · necesitas Wi-Fi',
          key: ValueKey('$_clave-tamano'),
          style: texto.bodyMedium,
        ),
        Text(
          'Licencia: ${_licenciaCorta(modelo.licencia)}',
          key: ValueKey('$_clave-licencia'),
          style: texto.bodySmall,
        ),
        ExpansionTile(
          key: ValueKey('$_clave-atribucion'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text('Licencia y atribución', style: texto.bodyMedium),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              modelo.licencia.atribucion,
              key: ValueKey('$_clave-atribucion-texto'),
              style: texto.bodySmall,
            ),
          ],
        ),
        _Estado(modelo: modelo, info: info, clave: _clave),
        const SizedBox(height: 8),
        _Botones(
          modelo: modelo,
          info: info,
          clave: _clave,
          sonando: miPrueba && prueba.sonando,
        ),
        if (info.aviso != null ||
            info.error != null ||
            (miPrueba && prueba.mensaje != null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                info.error != null
                    ? mensajeDeErrorDeDescarga(info.error!, info, modelo.bytes)
                    : info.aviso ?? prueba.mensaje!,
                key: ValueKey('$_clave-mensaje'),
                style: texto.bodySmall,
              ),
            ),
          ),
      ],
    );
  }

  static String _licenciaCorta(LicenciaDeModelo l) => switch (l.id) {
    'public-domain' => 'dominio público (según su autor)',
    final otro => otro,
  };
}

/// Una línea con icono y palabras: el estado nunca se dice solo con color.
class _Estado extends StatelessWidget {
  const _Estado({
    required this.modelo,
    required this.info,
    required this.clave,
  });

  final ModeloDelCatalogo modelo;
  final InfoDeModelo info;
  final String clave;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final p = info.progreso;
    final noDisponible = info.error is NoDisponibleAun;
    final (IconData icono, String etiqueta) = switch (info.estado) {
      EstadoModelo.descargando => (
        Icons.downloading_outlined,
        p == null
            ? 'Descargando…'
            : 'Descargando ${(p.fraccion * 100).floor()} % '
                  '(${formatearBytes(p.bytes)} de ${formatearBytes(p.total)})',
      ),
      EstadoModelo.instalado => (Icons.check_circle_outline, 'Instalada'),
      EstadoModelo.corrupto => (
        Icons.warning_amber_outlined,
        'Dañada: no se usa hasta que la reintentes o la borres',
      ),
      EstadoModelo.noDescargado when noDisponible => (
        Icons.cloud_off_outlined,
        'No disponible aún',
      ),
      EstadoModelo.noDescargado when info.parcial > 0 => (
        Icons.pause_circle_outline,
        'Descarga a medias: ${formatearBytes(info.parcial)} de ${formatearBytes(modelo.bytes)}',
      ),
      EstadoModelo.noDescargado => (
        Icons.cloud_download_outlined,
        'No descargada',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: 'Estado: $etiqueta',
            excludeSemantics: true,
            child: Row(
              children: [
                Icon(icono, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    etiqueta,
                    key: ValueKey('$clave-estado'),
                    style: texto.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          if (info.estado == EstadoModelo.descargando && p != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                key: ValueKey('$clave-progreso'),
                value: p.fraccion,
                minHeight: 6,
                semanticsLabel: 'Avance de la descarga',
                semanticsValue: '${(p.fraccion * 100).floor()} %',
              ),
            ),
        ],
      ),
    );
  }
}

class _Botones extends ConsumerWidget {
  const _Botones({
    required this.modelo,
    required this.info,
    required this.clave,
    required this.sonando,
  });

  final ModeloDelCatalogo modelo;
  final InfoDeModelo info;
  final String clave;
  final bool sonando;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.read(vocesDescargablesProvider.notifier);
    final botones = <Widget>[];
    switch (info.estado) {
      case EstadoModelo.noDescargado:
        final falta = modelo.bytes - info.parcial;
        botones.add(
          FilledButton.icon(
            key: ValueKey('$clave-descargar'),
            onPressed: () => _pedirDescarga(context, ref),
            icon: const Icon(Icons.download),
            label: Text(
              info.parcial > 0
                  ? 'Reanudar (${formatearBytes(falta)})'
                  : 'Descargar (${formatearBytes(modelo.bytes)})',
            ),
          ),
        );
        if (info.parcial > 0) {
          botones.add(
            TextButton(
              key: ValueKey('$clave-borrar'),
              onPressed: () => _confirmarBorrado(context, ref),
              child: const Text('Borrar lo descargado'),
            ),
          );
        }
      case EstadoModelo.descargando:
        botones.add(
          OutlinedButton.icon(
            key: ValueKey('$clave-cancelar'),
            onPressed: () => unawaited(estado.cancelar(modelo.id)),
            icon: const Icon(Icons.close),
            label: const Text('Cancelar'),
          ),
        );
      case EstadoModelo.instalado:
        botones.add(
          sonando
              ? OutlinedButton.icon(
                  key: ValueKey('$clave-parar'),
                  onPressed: () =>
                      unawaited(ref.read(pruebaVozProvider.notifier).parar()),
                  icon: const Icon(Icons.stop),
                  label: const Text('Parar'),
                )
              : OutlinedButton.icon(
                  key: ValueKey('$clave-probar'),
                  onPressed: () => _probar(ref),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Probar'),
                ),
        );
        botones.addAll([
          TextButton(
            key: ValueKey('$clave-comprobar'),
            onPressed: () => unawaited(estado.comprobar(modelo.id)),
            child: const Text('Comprobar'),
          ),
          TextButton(
            key: ValueKey('$clave-borrar'),
            onPressed: () => _confirmarBorrado(context, ref),
            child: const Text('Borrar'),
          ),
        ]);
      case EstadoModelo.corrupto:
        botones.addAll([
          FilledButton(
            key: ValueKey('$clave-reintentar'),
            onPressed: () => unawaited(estado.reintentar(modelo.id)),
            child: const Text('Reintentar'),
          ),
          TextButton(
            key: ValueKey('$clave-borrar'),
            onPressed: () => _confirmarBorrado(context, ref),
            child: const Text('Borrar'),
          ),
        ]);
    }
    return Wrap(spacing: 8, runSpacing: 4, children: botones);
  }

  Future<void> _pedirDescarga(BuildContext context, WidgetRef ref) async {
    final estado = ref.read(vocesDescargablesProvider.notifier);
    final tipo = await ref.read(fuenteTipoDeRedProvider).tipo();
    if (!context.mounted) return;
    if (tipo == TipoDeRed.sinRed) {
      estado.avisar(
        modelo.id,
        'No hay conexión. Cuando vuelva, puedes continuar la descarga.',
      );
      return;
    }
    var datosMoviles = false;
    if (!tipo.esSinCostoDeDatos) {
      final falta = formatearBytes(modelo.bytes - info.parcial);
      final seguir = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          key: const ValueKey('voces-datos-moviles'),
          title: const Text('No estás en Wi-Fi'),
          content: Text('La descarga usará $falta de tus datos.'),
          actions: [
            TextButton(
              key: const ValueKey('voces-datos-moviles-esperar'),
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Esperar al Wi-Fi'),
            ),
            FilledButton(
              key: const ValueKey('voces-datos-moviles-descargar'),
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Descargar con datos'),
            ),
          ],
        ),
      );
      if (seguir != true) return;
      datosMoviles = true;
    }
    estado.descargar(modelo.id, datosMoviles: datosMoviles);
  }

  Future<void> _confirmarBorrado(BuildContext context, WidgetRef ref) async {
    final estado = ref.read(vocesDescargablesProvider.notifier);
    final seguir = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        key: const ValueKey('voces-borrar'),
        title: Text('¿Borrar «${modelo.voces.first.nombre}»?'),
        content: Text(
          'Liberarás ${formatearBytes(info.ocupado > 0 ? info.ocupado : info.parcial)}. '
          'Puedes descargarla otra vez cuando quieras.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('voces-borrar-cancelar'),
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Conservar'),
          ),
          FilledButton(
            key: const ValueKey('voces-borrar-confirmar'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (seguir != true) return;
    await estado.borrar(modelo.id);
  }

  void _probar(WidgetRef ref) {
    final voz = modelo.voces.first;
    final rol = voz.genero == Genero.hombre ? VozDeGuion.m1 : VozDeGuion.f1;
    unawaited(
      ref
          .read(pruebaVozProvider.notifier)
          .probar(
            clave: '$clave-probar',
            guion: Guion(
              id: 'prueba',
              variante: voz.variante,
              turnos: [Turno(voz: rol, texto: fraseDePruebaEnIngles)],
            ),
            uso: UsoVoz.curso,
            fuente: Fuente.modelo,
            vocesElegidas: {rol: FuenteModelo.idDeVoz(modelo.id, voz.sid)},
          ),
    );
  }
}
