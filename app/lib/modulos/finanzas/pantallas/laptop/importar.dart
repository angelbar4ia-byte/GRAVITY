/// Importar datos (laptop; especificación 6.1): elegir archivo → vista
/// previa → confirmar → resumen (creadas, omitidas y por qué). Importa la
/// hoja **Categorías** de `data/DATOS_SEMILLA_PRESUPUESTO.xlsx` o su CSV;
/// reimportar no duplica.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../estado/proveedores.dart';
import '../../importacion/lector_xlsx.dart';
import '../comunes.dart';
import 'marco_laptop.dart';

/// Lee la plantilla de una ruta. Se reemplaza en las pruebas.
typedef LectorPlantilla = Future<LecturaPlantilla> Function(String ruta, String hoja);

final lectorPlantillaProvider = Provider<LectorPlantilla>(
  (ref) => (ruta, hoja) => leerPlantillaDeRuta(ruta, hoja: hoja),
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

  Future<void> _previsualizar() async {
    setState(() {
      _trabajando = true;
      _error = null;
      _resultado = null;
    });
    try {
      final lectura = await ref.read(lectorPlantillaProvider)(_ruta.text, _hoja.text);
      final vista = ref.read(servicioFinanzasProvider).previsualizarImportacion(lectura);
      setState(() {
        _lectura = lectura;
        _vista = vista;
      });
    } on ErrorArchivo catch (e) {
      setState(() => _error = e.mensaje);
    } catch (e) {
      setState(() => _error = 'No pude leer el archivo: $e');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _importar() async {
    final lectura = _lectura;
    if (lectura == null) return;
    setState(() => _trabajando = true);
    final nombre = _ruta.text.trim().split(RegExp(r'[\\/]')).last;
    try {
      final r = await ref.read(servicioFinanzasProvider).importarCategorias(
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
        for (final e in porMotivo.entries) Text('${e.value} omitidas: ${e.key}'),
        for (final o in omitidas.where((o) => o.motivo != 'Ya existe').take(20))
          Text('Fila ${o.numero} (${o.texto}): ${o.motivo}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vista = _vista;
    final resultado = _resultado;
    final arbol = vista == null ? null : ArbolCategorias([...widget.contexto.datos.categorias, ...vista.nuevas]);
    return ContenidoLaptop(
      children: [
        TarjetaModulo(
          titulo: '1. Elegir archivo',
          icono: Icons.upload_file_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('importar-ruta'),
                controller: _ruta,
                decoration: const InputDecoration(
                  labelText: 'Ruta del archivo (.xlsx o .csv)',
                  hintText: r'p. ej. C:\Users\...\DATOS_SEMILLA_PRESUPUESTO.xlsx',
                ),
              ),
              TextField(
                controller: _hoja,
                decoration: const InputDecoration(labelText: 'Hoja (solo .xlsx)'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: const ValueKey('importar-vista-previa'),
                  onPressed: _trabajando || _ruta.text.trim().isEmpty && false
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
                    child: Text(vista.sinCambios ? 'Registrar (sin cambios)' : 'Importar'),
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
