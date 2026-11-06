/// (+) Gasto en el teléfono (flujo F1, `DISENO_UX_UI.md` sección 14): el
/// teclado numérico ya abierto → categoría (la última preseleccionada y 5
/// sugeridas) → cuenta (la última usada) → Guardar → aviso *"Guardado ·
/// Deshacer"*. Sin señal: *"Guardado en el teléfono; se sube al volver la
/// señal"*. Meta: menos de 10 s.
///
/// En el libro de papá el gasto va en su nombre y pide motivo (D19).
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom show TipoLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../casos_uso/servicio_finanzas.dart';
import '../../casos_uso/sugerencias.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'marco_hoja.dart';
import 'nueva_cuenta_en_hoja.dart';

/// Libros donde la persona puede registrar, empezando por el activo.
List<Libro> librosParaRegistrar(ContextoFinanzas c) => [
  if (c.libro != null && c.puedeEscribir) c.libro!,
  for (final l in c.libros)
    if (l.id != c.libro?.id && c.permisoEn(l).escribir) l,
];

/// Mensaje del aviso después de guardar.
String mensajeGuardado(ResultadoRegistro r) => r.enCola
    ? 'Guardado en el teléfono; se sube al volver la señal'
    : 'Guardado';

/// Muestra *"Guardado · Deshacer"* con el aviso de diseno
/// ([mostrarAvisoDeshacer]); sigue vivo aunque la hoja se cierre. Deshacer no
/// borra: registra la anulación con motivo "Deshecho al capturar" (su id sale
/// del original, así repetirlo no duplica).
void avisarGuardado(
  BuildContext context,
  ResultadoRegistro r,
  ServicioFinanzas servicio,
) {
  final mensajero = ScaffoldMessenger.of(context);
  mostrarAvisoDeshacer(
    context,
    mensaje: mensajeGuardado(r),
    alDeshacer: () async {
      try {
        await servicio.deshacer(r);
        mensajero.showSnackBar(
          const SnackBar(content: Text('Se deshizo (queda anulado).')),
        );
      } catch (e) {
        mensajero.showSnackBar(SnackBar(content: Text('$e')));
      }
    },
  );
}

class HojaRegistrarGasto extends ConsumerStatefulWidget {
  const HojaRegistrarGasto({super.key});

  @override
  ConsumerState<HojaRegistrarGasto> createState() => _HojaRegistrarGastoState();
}

class _HojaRegistrarGastoState extends ConsumerState<HojaRegistrarGasto> {
  int _monto = 0;
  String? _libroId;
  String? _categoriaId;
  bool _categoriaElegida = false;
  String? _cuentaId;
  Fecha? _fecha;
  bool _conNota = false;
  bool _creandoCuenta = false;
  final _nota = TextEditingController();
  final _motivo = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nota.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _guardar(ContextoFinanzas c, Libro libro) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    final navegador = Navigator.of(context);
    final servicio = ref.read(servicioFinanzasProvider);
    try {
      final r = await servicio.registrarGasto(
        libroId: libro.id,
        cuentaOrigenId: _cuentaId!,
        lineas: [LineaGasto(monto: _monto, categoriaId: _categoriaId)],
        fecha: _fecha,
        nota: _conNota ? _nota.text : null,
        motivo: libro.tipo == dom.TipoLibro.representado ? _motivo.text : null,
      );
      if (mounted) avisarGuardado(context, r, servicio);
      if (navegador.canPop()) navegador.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        avisarError(context, e);
      }
    }
  }

  Future<void> _masCategorias(DatosFinanzas d) async {
    final elegida = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ListaCategorias(datos: d),
    );
    if (elegida != null) {
      setState(() {
        _categoriaId = elegida == '' ? null : elegida;
        _categoriaElegida = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asincrono = ref.watch(contextoFinanzasProvider);
    final c = asincrono.value;
    if (c == null) {
      return MarcoHojaRegistro(
        titulo: 'Gasto',
        cuerpo: asincrono.hasError
            ? Text('No se pudo abrir Finanzas: ${asincrono.error}')
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final libros = librosParaRegistrar(c);
    if (libros.isEmpty) {
      return const MarcoHojaRegistro(
        titulo: 'Gasto',
        cuerpo: Text(
          'Solo lectura: no tienes un libro donde registrar gastos.',
        ),
      );
    }
    final libro = libros.firstWhere(
      (l) => l.id == _libroId,
      orElse: () => libros.first,
    );
    final sugerencias = sugerenciasDeGasto(
      c.datos,
      libroId: libro.id,
      personaId: c.personaId,
      hoy: c.hoy,
    );
    // La categoría es **opcional**: sin ella el gasto queda en "Por
    // clasificar". Solo se preselecciona la última que usó la persona.
    if (!_categoriaElegida && _categoriaId == null) {
      _categoriaId = sugerencias.ultimaCategoriaId;
    }
    _cuentaId ??= sugerencias.ultimaCuentaId;
    if (_cuentaId != null &&
        !sugerencias.cuentas.any((x) => x.id == _cuentaId)) {
      _cuentaId = sugerencias.ultimaCuentaId;
    }
    final representado = libro.tipo == dom.TipoLibro.representado;
    final categorias = [
      ...sugerencias.categorias,
      if (_categoriaId != null &&
          !sugerencias.categorias.any((x) => x.id == _categoriaId))
        ?c.datos.arbol.porId(_categoriaId),
    ];
    final puedeGuardar =
        _monto > 0 &&
        _cuentaId != null &&
        !_guardando &&
        (!representado || motivoValido(_motivo.text));
    final v = ValoresDiseno.de(context);
    final fecha = _fecha ?? c.hoy;
    return MarcoHojaRegistro(
      titulo: 'Gasto',
      // El monto comparte línea con el título; se encoge en vez de partirse.
      tituloDerecha: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          formatearCentavos(_monto),
          key: const ValueKey('gasto-monto'),
          textAlign: TextAlign.center,
          style: v.numero(
            tamano: 32,
            peso: FontWeight.w600,
            color: v.textoFuerte,
          ),
        ),
      ),
      barra: BarraAccionesRegistro(
        llaveGuardar: const ValueKey('gasto-guardar'),
        alGuardar: puedeGuardar ? () => _guardar(c, libro) : null,
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (libros.length > 1)
            // Una sola línea que se desliza: cada fila de más empuja la
            // categoría y la cuenta fuera de la pantalla (I8).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final l in libros) ...[
                    ChoiceChip(
                      key: ValueKey('gasto-libro-${l.id}'),
                      label: Text(
                        opcionDe(l, c.permisoEn(l), c.personaId).etiqueta,
                      ),
                      selected: l.id == libro.id,
                      onSelected: (_) => setState(() {
                        _libroId = l.id;
                        _cuentaId = null;
                        _creandoCuenta = false;
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          if (representado) ...[
            const SizedBox(height: 4),
            marcaDe(
              ContextoFinanzas.armar(
                carga: c.carga,
                personaId: c.personaId,
                rol: c.rol,
                hoy: c.hoy,
                esMaestra: c.esMaestra,
                elegido: libro.id,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TecladoMonto(
            alCambiar: (centavos) => setState(() => _monto = centavos),
            autofocus: true,
            // Teclas de 48 dp: categoría y cuenta quedan a la vista (I8).
            compacto: true,
          ),
          const SizedBox(height: 12),
          const EtiquetaPanel('Categoría (opcional)'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final cat in categorias)
                ChoiceChip(
                  key: ValueKey('gasto-categoria-${cat.id}'),
                  label: Text(cat.nombre),
                  selected: _categoriaId == cat.id,
                  // Tocar la elegida otra vez la quita: queda "Por clasificar".
                  onSelected: (sel) => setState(() {
                    _categoriaId = sel ? cat.id : null;
                    _categoriaElegida = true;
                  }),
                ),
              ActionChip(
                key: const ValueKey('gasto-mas-categorias'),
                avatar: const Icon(Icons.more_horiz, size: 18),
                label: Text(
                  _categoriaId == null && _categoriaElegida
                      ? 'Por clasificar'
                      : 'Más…',
                ),
                onPressed: () => _masCategorias(c.datos),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const EtiquetaPanel('Cuenta'),
          const SizedBox(height: 4),
          if (sugerencias.cuentas.isEmpty || _creandoCuenta) ...[
            if (sugerencias.cuentas.isEmpty)
              Text(
                'Este libro aún no tiene cuentas de donde pagar. Crea la '
                'primera (efectivo, banco o tarjeta) y sigue con el gasto.',
                key: const ValueKey('gasto-sin-cuentas'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (c.permisoEn(libro).administrar)
              NuevaCuentaEnHoja(
                key: ValueKey('gasto-cuenta-nueva-${libro.id}'),
                libroId: libro.id,
                alCrear: (id) => setState(() {
                  _cuentaId = id;
                  _creandoCuenta = false;
                }),
              )
            else
              const Text(
                'Pide a quien administra este libro que cree una cuenta.',
              ),
          ] else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cuenta in sugerencias.cuentas)
                  ChoiceChip(
                    key: ValueKey('gasto-cuenta-${cuenta.id}'),
                    label: Text(cuenta.nombre),
                    selected: _cuentaId == cuenta.id,
                    onSelected: (_) => setState(() => _cuentaId = cuenta.id),
                  ),
                if (c.permisoEn(libro).administrar)
                  ActionChip(
                    key: const ValueKey('gasto-cuenta-nueva'),
                    // Al final de la lista (Fase 4, E6/P13): corto y de 48 dp.
                    tooltip: 'Agregar una cuenta a este libro',
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: const Text('+ Cuenta'),
                    onPressed: () => setState(() => _creandoCuenta = true),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                key: const ValueKey('gasto-fecha'),
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text(fecha == c.hoy ? 'Hoy' : textoFecha(fecha)),
                onPressed: () async {
                  final f = await elegirFecha(context, fecha);
                  if (f != null) setState(() => _fecha = f);
                },
              ),
              FilterChip(
                key: const ValueKey('gasto-con-nota'),
                label: const Text('Nota'),
                selected: _conNota,
                onSelected: (s) => setState(() => _conNota = s),
              ),
            ],
          ),
          if (_conNota)
            TextField(
              key: const ValueKey('gasto-nota'),
              controller: _nota,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Nota'),
            ),
          if (representado)
            TextField(
              key: const ValueKey('gasto-motivo'),
              controller: _motivo,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Motivo (obligatorio)',
                helperText:
                    '$ayudaDelMotivo Se registra en nombre de ${libro.nombre}.',
                helperMaxLines: 3,
                errorText: errorDeMotivo(_motivo.text),
                errorMaxLines: 3,
              ),
            ),
        ],
      ),
    );
  }
}

/// Todas las categorías visibles, con búsqueda. Devuelve el id ('' = Por
/// clasificar).
class _ListaCategorias extends StatefulWidget {
  const _ListaCategorias({required this.datos});

  final DatosFinanzas datos;

  @override
  State<_ListaCategorias> createState() => _ListaCategoriasState();
}

class _ListaCategoriasState extends State<_ListaCategorias> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final arbol = widget.datos.arbol;
    final filtro = normalizarNombre(_filtro);
    final todas = [
      for (final c in arbol.todas)
        if (c.visible &&
            (filtro.isEmpty ||
                normalizarNombre(arbol.ruta(c.id)).contains(filtro)))
          c,
    ]..sort((a, b) => arbol.ruta(a.id).compareTo(arbol.ruta(b.id)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const ValueKey('gasto-buscar-categoria'),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Buscar categoría',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (t) => setState(() => _filtro = t),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Por clasificar'),
                subtitle: const Text('Lo clasificas después'),
                onTap: () => Navigator.pop(context, ''),
              ),
              for (final c in todas)
                ListTile(
                  title: Text(c.nombre),
                  subtitle: c.nivel > 1 ? Text(arbol.ruta(c.id)) : null,
                  onTap: () => Navigator.pop(context, c.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
