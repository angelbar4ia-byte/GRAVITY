/// Importar datos (laptop; especificación 6.1): elegir archivo con el
/// **selector de archivos** del sistema → vista previa → confirmar → resumen
/// (creadas, omitidas y por qué). Importa la hoja **Categorías** de
/// `data/DATOS_SEMILLA_PRESUPUESTO.xlsx` o su CSV; reimportar no duplica.
///
/// Ya no se escribe una ruta (respuestas del dueño del 23/oct/2026). Para las
/// pruebas queda una ruta **oculta** ([rutaManualProvider]).
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../../importacion/lector_xlsx.dart';
import '../comunes.dart';
import 'marco_laptop.dart';

/// Lee la plantilla de una ruta. Solo para las pruebas (ruta oculta).
typedef LectorPlantilla = Future<LecturaPlantilla> Function(
  String ruta,
  String hoja,
);

final lectorPlantillaProvider = Provider<LectorPlantilla>(
  (ref) =>
      (ruta, hoja) => leerPlantillaDeRuta(ruta, hoja: hoja),
);

/// Muestra el campo de ruta escrita (oculto por omisión; solo las pruebas lo
/// encienden).
final rutaManualProvider = Provider<bool>((ref) => false);

/// Lo que devuelve el selector de archivos: el nombre y los bytes (en Android
/// el sistema da un `content://`, no una ruta que se pueda abrir).
class ArchivoElegido {
  const ArchivoElegido(this.nombre, this.bytes);

  final String nombre;
  final Uint8List bytes;
}

/// Abre el selector de archivos del sistema (`.xlsx` o `.csv`). `null` si la
/// persona cancela.
typedef SelectorArchivo = Future<ArchivoElegido?> Function();

Future<ArchivoElegido?> elegirArchivoDelSistema() async {
  final archivo = await FilePicker.pickFile(
    dialogTitle: 'Elegir el archivo de datos',
    type: FileType.custom,
    allowedExtensions: const ['xlsx', 'csv'],
  );
  if (archivo == null) return null;
  // El archivo es NO confiable (viene de un correo o una descarga): se mira su
  // tamaño ANTES de leerlo, para no cargar en memoria uno de varios GB.
  final tamano = archivo.lengthSync() ?? await archivo.length();
  if (tamano != null && tamano > maximoBytesDeImportacion) {
    throw const ErrorArchivo(
      'El archivo pesa más de 10 MB: no es la plantilla.',
    );
  }
  // Y se lee por pedazos con el mismo tope, por si el tamaño no se supo o
  // mintió.
  final bytes = BytesBuilder();
  await for (final pedazo in archivo.readAsByteStream()) {
    bytes.add(pedazo);
    if (bytes.length > maximoBytesDeImportacion) {
      throw const ErrorArchivo(
        'El archivo pesa más de 10 MB: no es la plantilla.',
      );
    }
  }
  return ArchivoElegido(archivo.name, bytes.takeBytes());
}

/// El selector de archivos de la app; las pruebas lo reemplazan.
final selectorArchivoProvider = Provider<SelectorArchivo>(
  (ref) => elegirArchivoDelSistema,
);

class PantallaImportar extends StatelessWidget {
  const PantallaImportar({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.importar,
    builder: (context, c) => c.administraHogar && !c.permiso.comoMaestra
        ? _Importar(contexto: c)
        : const EstadoVacio(
            icono: Icons.lock_outline,
            mensaje: 'Solo quien administra Finanzas importa datos.',
          ),
  );
}

class _Importar extends ConsumerStatefulWidget {
  const _Importar({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_Importar> createState() => _ImportarState();
}

class _ImportarState extends ConsumerState<_Importar> {
  final _ruta = TextEditingController();
  final _hoja = TextEditingController(text: 'Categorías');
  ArchivoElegido? _archivo;
  LecturaPlantilla? _lectura;
  PlanImportacion? _vista;
  PlanImportacion? _resultado;
  String? _error;
  bool _trabajando = false;

  @override
  void dispose() {
    _ruta.dispose();
    _hoja.dispose();
    super.dispose();
  }

  /// Nombre del archivo con el que se trabaja: el elegido o, en las pruebas, la
  /// ruta oculta.
  String get _nombreArchivo =>
      _archivo?.nombre ?? _ruta.text.trim().split(RegExp(r'[\\/]')).last;

  bool get _hayArchivo =>
      _archivo != null ||
      (ref.read(rutaManualProvider) && _ruta.text.trim().isNotEmpty);

  Future<void> _elegir() async {
    setState(() {
      _trabajando = true;
      _error = null;
    });
    ArchivoElegido? elegido;
    try {
      elegido = await ref.read(selectorArchivoProvider)();
    } on ErrorArchivo catch (e) {
      // Un archivo demasiado grande se explica tal cual.
      if (mounted) {
        setState(() {
          _trabajando = false;
          _error = e.mensaje;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _trabajando = false;
          _error = 'No pude abrir el selector de archivos.';
        });
      }
      return;
    }
    if (!mounted) return;
    if (elegido == null) {
      setState(() => _trabajando = false); // la persona canceló
      return;
    }
    setState(() {
      _archivo = elegido;
      _lectura = null;
      _vista = null;
      _resultado = null;
    });
    await _previsualizar();
  }

  Future<void> _previsualizar() async {
    setState(() {
      _trabajando = true;
      _error = null;
      _resultado = null;
    });
    try {
      final archivo = _archivo;
      final lectura = archivo != null
          ? leerPlantillaDeBytes(
              archivo.bytes,
              nombre: archivo.nombre,
              hoja: _hoja.text,
            )
          : await ref.read(lectorPlantillaProvider)(_ruta.text, _hoja.text);
      final vista = ref
          .read(servicioFinanzasProvider)
          .previsualizarImportacion(lectura);
      setState(() {
        _lectura = lectura;
        _vista = vista;
      });
    } on ErrorArchivo catch (e) {
      setState(() => _error = e.mensaje);
    } catch (e) {
      setState(
        () => _error =
            'No pude leer el archivo: está dañado o no es la plantilla.',
      );
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _importar() async {
    final lectura = _lectura;
    if (lectura == null) return;
    setState(() => _trabajando = true);
    final nombre = _nombreArchivo;
    try {
      final r = await ref
          .read(servicioFinanzasProvider)
          .importarCategorias(
            lectura,
            archivo: nombre,
            hoja: _hoja.text.trim(),
          );
      setState(() {
        _resultado = r;
        _vista = null;
      });
    } catch (e) {
      if (mounted) avisarError(context, e);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Widget _omitidas(List<FilaOmitida> omitidas) {
    final porMotivo = <String, int>{};
    for (final o in omitidas) {
      porMotivo[o.motivo] = (porMotivo[o.motivo] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in porMotivo.entries)
          Text('${e.value} omitidas: ${e.key}'),
        for (final o in omitidas.where((o) => o.motivo != 'Ya existe').take(20))
          Text(
            'Fila ${o.numero} (${o.texto}): ${o.motivo}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vista = _vista;
    final resultado = _resultado;
    final arbol = vista == null
        ? null
        : ArbolCategorias([
            ...widget.contexto.datos.categorias,
            ...vista.nuevas,
          ]);
    return ContenidoLaptop(
      children: [
        TarjetaModulo(
          titulo: '1. Elegir archivo',
          icono: Icons.upload_file_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: const ValueKey('importar-elegir'),
                  onPressed: _trabajando ? null : _elegir,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Elegir archivo…'),
                ),
              ),
              if (_archivo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Archivo: ${_archivo!.nombre}',
                    key: const ValueKey('importar-archivo'),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Elige el archivo .xlsx o .csv de tu equipo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (ref.watch(rutaManualProvider))
                TextField(
                  key: const ValueKey('importar-ruta'),
                  controller: _ruta,
                  decoration: const InputDecoration(
                    labelText: 'Ruta del archivo',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_archivo == null ||
                  _nombreArchivo.toLowerCase().endsWith('.xlsx'))
                TextField(
                  key: const ValueKey('importar-hoja'),
                  controller: _hoja,
                  decoration: const InputDecoration(
                    labelText: 'Hoja (solo .xlsx)',
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: const ValueKey('importar-vista-previa'),
                  onPressed: _trabajando || !_hayArchivo
                      ? null
                      : _previsualizar,
                  child: const Text('Vista previa'),
                ),
              ),
              if (_error != null)
                Text(_error!, key: const ValueKey('importar-error')),
            ],
          ),
        ),
        if (vista != null)
          TarjetaModulo(
            key: const ValueKey('importar-previa'),
            titulo: '2. Vista previa',
            icono: Icons.preview_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vista.filasLeidas} filas leídas · ${vista.nuevas.length} '
                  'categorías nuevas · ${vista.cuentasNuevas.length} cuentas de '
                  'gasto nuevas · ${vista.omitidas.length} omitidas',
                ),
                const SizedBox(height: 8),
                for (final x in vista.nuevas.take(30))
                  Text(
                    '${arbol!.ruta(x.id)} · ${x.naturaleza} · ${nombrePrioridad(x.prioridad)}'
                    '${x.protegida ? ' · protegida' : ''}',
                  ),
                if (vista.nuevas.length > 30)
                  Text('… y ${vista.nuevas.length - 30} más'),
                _omitidas(vista.omitidas),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton(
                    key: const ValueKey('importar-confirmar'),
                    onPressed: _trabajando ? null : _importar,
                    child: Text(
                      vista.sinCambios ? 'Registrar (sin cambios)' : 'Importar',
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (resultado != null)
          TarjetaModulo(
            key: const ValueKey('importar-resumen'),
            titulo: '3. Resumen',
            icono: Icons.task_alt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creadas: ${resultado.nuevas.length} categorías y '
                  '${resultado.cuentasNuevas.length} cuentas de gasto. '
                  'Omitidas: ${resultado.omitidas.length}.',
                ),
                _omitidas(resultado.omitidas),
              ],
            ),
          ),
        const Text(
          'Solo se importa la hoja Categorías (MVP 1). Reimportar no duplica: '
          'lo que ya existe se omite. Los precios, comercios y recetas del '
          'libro no se importan aquí.',
        ),
      ],
    );
  }
}
