/// Importar recetas desde un archivo JSON, con vista previa antes de guardar
/// (Fase 7, decisión 1). La app solo importa: no redacta recetas.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/importar_recetas.dart';
import '../estado/proveedores.dart';

/// Lo que devuelve el selector de archivos.
class ArchivoRecetas {
  const ArchivoRecetas(this.nombre, this.bytes);
  final String nombre;
  final Uint8List bytes;
}

typedef SelectorArchivoRecetas = Future<ArchivoRecetas?> Function();

Future<ArchivoRecetas?> elegirArchivoDeRecetas() async {
  final archivo = await FilePicker.pickFile(
    dialogTitle: 'Elegir el archivo de recetas',
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (archivo == null) return null;
  // El archivo no es confiable: se mira el tamaño antes de leerlo.
  final tamano = archivo.lengthSync() ?? await archivo.length();
  if (tamano != null && tamano > maxBytesArchivoRecetas) {
    return ArchivoRecetas(archivo.name, Uint8List(maxBytesArchivoRecetas + 1));
  }
  final bytes = BytesBuilder();
  await for (final pedazo in archivo.readAsByteStream()) {
    bytes.add(pedazo);
    if (bytes.length > maxBytesArchivoRecetas) break;
  }
  return ArchivoRecetas(archivo.name, bytes.takeBytes());
}

/// El selector del sistema; las pruebas lo reemplazan.
final selectorRecetasProvider = Provider<SelectorArchivoRecetas>(
  (ref) => elegirArchivoDeRecetas,
);

class PantallaImportarRecetas extends ConsumerStatefulWidget {
  const PantallaImportarRecetas({super.key});

  @override
  ConsumerState<PantallaImportarRecetas> createState() => _Estado();
}

class _Estado extends ConsumerState<PantallaImportarRecetas> {
  ResultadoImportacion? _resultado;
  String? _nombre;
  Set<String> _existentes = {};
  String? _mensaje;
  bool _guardando = false;

  Future<void> _elegir() async {
    final archivo = await ref.read(selectorRecetasProvider)();
    if (archivo == null) return;
    final r = importarRecetasDeBytes(archivo.bytes);
    Set<String> existentes = {};
    try {
      existentes = {
        for (final p in await ref.read(servicioAlimentacionProvider).platillos())
          p.id,
      };
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _resultado = r;
      _nombre = archivo.nombre;
      _existentes = existentes;
      _mensaje = null;
    });
  }

  Future<void> _guardar() async {
    final r = _resultado;
    if (r == null || !r.valido) return;
    setState(() => _guardando = true);
    try {
      final n = await ref.read(servicioAlimentacionProvider).importarRecetas(r);
      ref.invalidate(platillosProvider);
      ref.read(versionAlimentacionProvider.notifier).state++;
      if (!mounted) return;
      setState(() {
        _resultado = null;
        _mensaje = n == 1 ? 'Se guardó 1 receta' : 'Se guardaron $n recetas';
      });
    } on UnsupportedError {
      if (!mounted) return;
      setState(
        () => _mensaje =
            'Alimentación aún no está activa en tu hogar: no se guardó nada.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensaje = 'No pudimos guardar las recetas. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final puede = ref.watch(puedeEditarAlimentacionProvider);
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: MarcoPantalla(
        titulo: 'Importar recetas',
        rutaAnterior: Rutas.alimentacion,
        cuerpo: !puede
            ? const EstadoVacio(
                mensaje: 'Solo el dueño y la pareja importan recetas',
                icono: Icons.lock_outline,
              )
            : _cuerpo(context),
      ),
    );
  }

  Widget _cuerpo(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final r = _resultado;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Elige un archivo .json con tus recetas. Puedes pedirle a una IA que '
          'lo redacte fuera de la app; aquí solo se revisa y se guarda. '
          'Cada receta lleva título, porciones, pasos en orden (hasta '
          '$maxPasosPorReceta, de $maxCaracteresPaso letras) e ingredientes con '
          'cantidad y unidad.',
          style: v.lectura(tamano: 15, color: v.texto),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _guardando ? null : _elegir,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Elegir archivo'),
          ),
        ),
        if (_mensaje != null) ...[
          const SizedBox(height: 12),
          Text(
            _mensaje!,
            style: v.lectura(
              tamano: 16,
              peso: FontWeight.w600,
              color: v.textoFuerte,
            ),
          ),
        ],
        if (r != null) ...[
          const SizedBox(height: 16),
          if (_nombre != null)
            Text(_nombre!, style: v.lectura(tamano: 14, color: v.textoTenue)),
          if (!r.valido) _Errores(errores: r.errores) else ..._vistaPrevia(r, v),
        ],
      ],
    );
  }

  List<Widget> _vistaPrevia(ResultadoImportacion r, ValoresDiseno v) => [
    Text(
      'Vista previa: ${r.recetas.length} ${r.recetas.length == 1 ? 'receta' : 'recetas'}',
      style: v.titulo(tamano: 18, color: v.textoFuerte),
    ),
    const SizedBox(height: 8),
    for (final x in r.recetas)
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                x.platillo.nombre,
                style: v.titulo(tamano: 17, color: v.textoFuerte),
              ),
              Text(
                '${x.platillo.porciones} ${x.platillo.porciones == 1 ? 'porción' : 'porciones'}'
                ' · ${x.platillo.ingredientes.length} ingredientes'
                ' · ${x.platillo.pasos.length} pasos',
                style: v.lectura(tamano: 14, color: v.textoTenue),
              ),
              if (_existentes.contains(x.platillo.id))
                Text(
                  'Ya existe: se reemplaza',
                  style: v.lectura(tamano: 14, color: v.etiqueta),
                ),
              const SizedBox(height: 8),
              for (final i in x.platillo.ingredientes)
                Text(
                  '• ${i.nombre} · ${cantidadTextoReceta(i.cantidad)} ${i.unidad} (${i.seccion.etiqueta})',
                  style: v.lectura(tamano: 15, color: v.texto),
                ),
              const SizedBox(height: 8),
              for (var n = 0; n < x.platillo.pasos.length; n++)
                Text(
                  '${n + 1}. ${x.platillo.pasos[n]}',
                  style: v.lectura(tamano: 15, color: v.texto),
                ),
              for (final a in x.advertencias)
                Text(a, style: v.lectura(tamano: 14, color: v.etiqueta)),
            ],
          ),
        ),
      ),
    FilledButton(
      onPressed: _guardando ? null : _guardar,
      child: Text(r.recetas.length == 1 ? 'Guardar receta' : 'Guardar recetas'),
    ),
    TextButton(
      onPressed: _guardando ? null : () => setState(() => _resultado = null),
      child: const Text('Descartar'),
    ),
  ];
}

String cantidadTextoReceta(double c) =>
    c == c.roundToDouble() ? c.round().toString() : c.toString();

class _Errores extends StatelessWidget {
  const _Errores({required this.errores});
  final List<ErrorReceta> errores;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'El archivo no se puede importar',
          style: v.titulo(tamano: 18, color: v.textoFuerte),
        ),
        const SizedBox(height: 4),
        Text(
          'No se guardó nada. Corrige esto y vuelve a elegirlo:',
          style: v.lectura(tamano: 15, color: v.texto),
        ),
        const SizedBox(height: 8),
        for (final e in errores.take(30))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• ${e.donde}: ${e.mensaje}',
              style: v.lectura(tamano: 15, color: v.texto),
            ),
          ),
        if (errores.length > 30)
          Text('… y ${errores.length - 30} más.'),
      ],
    );
  }
}
