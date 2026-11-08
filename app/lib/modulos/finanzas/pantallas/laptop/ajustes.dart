/// Ajustes de Finanzas (laptop; especificación 6.1): parámetros del libro
/// (meta, ahorro mínimo con deuda, tope de arrastre, cierre automático),
/// umbrales de semáforo, días inhábiles por año, libros y albaceas (D19) y la
/// cuenta maestra (privacidad).
///
/// Los parámetros son **por libro**; los días inhábiles son del **hogar**.
/// Nada se inventa: la precarga de festivos nace inactiva y la revisa el
/// dueño; los libros se crean con los nombres que escribe la persona.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart'
    as dom
    show TipoLibro, VisibilidadLibro;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../diseno/diseno.dart';
import '../../../../nucleo/contratos/roles.dart';
import '../../datos/repositorio.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';
import 'dialogos_libros.dart';
import '../transferencias/aportacion_casa.dart';
import 'marco_laptop.dart';

class PantallaAjustesFinanzas extends StatelessWidget {
  const PantallaAjustesFinanzas({super.key});

  @override
  Widget build(BuildContext context) => MarcoFinanzasLaptop(
    seccion: SeccionFinanzas.ajustes,
    builder: (context, c) => _Ajustes(contexto: c),
  );
}

class _Ajustes extends ConsumerStatefulWidget {
  const _Ajustes({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_Ajustes> createState() => _AjustesState();
}

class _AjustesState extends ConsumerState<_Ajustes> {
  @override
  void initState() {
    super.initState();
    // Al abrir Ajustes se vuelve a pedir lo del servidor: tras una baja del
    // hogar o un cambio de rol pudo cambiar el administrador, la visibilidad
    // de los compartidos o el cargo de albacea.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        refrescarFinanzas(ProviderScope.containerOf(context, listen: false));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    return ContenidoLaptop(
      children: [
        _Parametros(
          key: ValueKey('ajustes-parametros-${c.libroId}'),
          contexto: c,
        ),
        if (c.administraHogar && !c.permiso.comoMaestra)
          _DiasInhabiles(contexto: c),
        if (c.rol == Rol.dueno && !c.permiso.comoMaestra)
          const SelectorPeriodoAportacion(),
        _Libros(contexto: c),
        _Privacidad(contexto: c),
      ],
    );
  }
}

// ------------------------------------------------------------- parámetros

/// Un parámetro en porcentaje (puntos base) del formulario.
class _CampoPb {
  _CampoPb(this.etiqueta, int valor)
    : control = TextEditingController(text: CampoPorcentaje.texto(valor));

  final String etiqueta;
  final TextEditingController control;

  int? get valor => CampoPorcentaje.puntosBase(control.text);
}

class _Parametros extends ConsumerStatefulWidget {
  const _Parametros({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_Parametros> createState() => _ParametrosState();
}

class _ParametrosState extends ConsumerState<_Parametros> {
  final _forma = GlobalKey<FormState>();
  late final ParametrosFinanzas _p = widget.contexto.datos.parametrosDe(
    widget.contexto.libroId,
  );
  late final _meta = _CampoPb('Meta de remanente', _p.metaRemanentePuntosBase);
  late final _ahorro = _CampoPb(
    'Ahorro mínimo con deuda (del remanente)',
    _p.ahorroMinimoConDeudaPuntosBase,
  );
  late final _arrastre = TextEditingController(
    text: '${_p.topeArrastreSemanas}',
  );
  late final _cierre = TextEditingController(
    text: '${_p.cierreAutomaticoDias}',
  );
  late final _umbrales = <String, _CampoPb>{
    'partida-ambar': _CampoPb(
      'Partida: ámbar desde',
      _p.umbrales.partidaAmbarDesde,
    ),
    'partida-rojo': _CampoPb(
      'Partida: rojo arriba de',
      _p.umbrales.partidaRojoArribaDe,
    ),
    'remanente-verde': _CampoPb(
      'Remanente: verde desde',
      _p.umbrales.remanenteVerdeDesde,
    ),
    'remanente-ambar': _CampoPb(
      'Remanente: ámbar desde',
      _p.umbrales.remanenteAmbarDesde,
    ),
    'carga-ambar': _CampoPb(
      'Carga de deuda: ámbar desde',
      _p.umbrales.cargaDeudaAmbarDesde,
    ),
    'carga-rojo': _CampoPb(
      'Carga de deuda: rojo arriba de',
      _p.umbrales.cargaDeudaRojoArribaDe,
    ),
    'cumplimiento-verde': _CampoPb(
      'Cumplimiento: verde desde',
      _p.umbrales.cumplimientoVerdeDesde,
    ),
    'cumplimiento-ambar': _CampoPb(
      'Cumplimiento: ámbar desde',
      _p.umbrales.cumplimientoAmbarDesde,
    ),
  };
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [
      _meta.control,
      _ahorro.control,
      _arrastre,
      _cierre,
      for (final u in _umbrales.values) u.control,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_forma.currentState?.validate() ?? false)) return;
    int pb(String clave) => _umbrales[clave]!.valor!;
    final nuevo = _p.copiar(
      metaRemanentePuntosBase: _meta.valor,
      ahorroMinimoConDeudaPuntosBase: _ahorro.valor,
      topeArrastreSemanas: int.parse(_arrastre.text.trim()),
      cierreAutomaticoDias: int.parse(_cierre.text.trim()),
      umbrales: Umbrales(
        partidaAmbarDesde: pb('partida-ambar'),
        partidaRojoArribaDe: pb('partida-rojo'),
        remanenteVerdeDesde: pb('remanente-verde'),
        remanenteAmbarDesde: pb('remanente-ambar'),
        cargaDeudaAmbarDesde: pb('carga-ambar'),
        cargaDeudaRojoArribaDe: pb('carga-rojo'),
        cumplimientoVerdeDesde: pb('cumplimiento-verde'),
        cumplimientoAmbarDesde: pb('cumplimiento-ambar'),
      ),
    );
    setState(() => _guardando = true);
    final ok = await intentar(
      context,
      () => ref.read(servicioFinanzasProvider).guardarParametros(nuevo),
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) avisar(context, 'Ajustes guardados.');
  }

  Widget _numero(
    String clave,
    TextEditingController control,
    String etiqueta,
    int min,
    int max, {
    bool editable = true,
  }) => SizedBox(
    width: 260,
    child: TextFormField(
      key: ValueKey('ajustes-$clave'),
      controller: control,
      enabled: editable,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: etiqueta),
      validator: (v) {
        final n = int.tryParse((v ?? '').trim());
        return n == null || n < min || n > max ? 'De $min a $max' : null;
      },
    ),
  );

  Widget _porcentaje(String clave, _CampoPb campo, {bool editable = true}) =>
      SizedBox(
        width: 260,
        child: editable
            ? CampoPorcentaje(
                key: ValueKey('ajustes-$clave'),
                controlador: campo.control,
                etiqueta: campo.etiqueta,
              )
            : TextFormField(
                key: ValueKey('ajustes-$clave'),
                controller: campo.control,
                enabled: false,
                decoration: InputDecoration(
                  labelText: campo.etiqueta,
                  suffixText: '%',
                ),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final editable = c.puedeAdministrar;
    return TarjetaModulo(
      key: const ValueKey('ajustes-tarjeta-parametros'),
      titulo: 'Presupuesto de ${c.libro!.nombre}',
      icono: Icons.tune,
      child: Form(
        key: _forma,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!editable)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Solo lectura: los cambia quien lleva este libro.'),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _porcentaje('meta', _meta, editable: editable),
                _porcentaje('ahorro', _ahorro, editable: editable),
                _numero(
                  'arrastre',
                  _arrastre,
                  'Tope de arrastre (semanas de su monto)',
                  0,
                  52,
                  editable: editable,
                ),
                _numero(
                  'cierre',
                  _cierre,
                  'Cierre automático (días después del domingo)',
                  1,
                  6,
                  editable: editable,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const EtiquetaPanel('Semáforos'),
            const SizedBox(height: 4),
            const Text(
              'Nunca dependen solo del color: cada semáforo lleva su texto.',
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final e in _umbrales.entries)
                  _porcentaje(e.key, e.value, editable: editable),
              ],
            ),
            if (editable) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: const ValueKey('ajustes-guardar'),
                  onPressed: _guardando ? null : _guardar,
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- días inhábiles

class _DiasInhabiles extends ConsumerStatefulWidget {
  const _DiasInhabiles({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<_DiasInhabiles> createState() => _DiasInhabilesState();
}

class _DiasInhabilesState extends ConsumerState<_DiasInhabiles> {
  late int _anio = widget.contexto.hoy.anio;

  Future<void> _agregarPropio() async {
    final c = widget.contexto;
    final fecha = await elegirFecha(context, c.hoy);
    if (fecha == null || !mounted) return;
    final nombre = await pedirTexto(
      context,
      titulo: 'Día inhábil propio',
      etiqueta: 'Nombre (p. ej. Día de la empresa)',
      textoAccion: 'Agregar',
    );
    if (nombre == null || !mounted) return;
    await intentar(
      context,
      () => ref.read(servicioFinanzasProvider).agregarDiaPropio(fecha, nombre),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final servicio = ref.read(servicioFinanzasProvider);
    final dias = [
      for (final d in c.datos.diasInhabiles)
        if (d.fecha.anio == _anio) d,
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));
    return TarjetaModulo(
      key: const ValueKey('ajustes-dias-inhabiles'),
      titulo: 'Días inhábiles',
      icono: Icons.event_busy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Un pago que cae en sábado, domingo o día inhábil se mueve según '
            'su regla (los ingresos, al siguiente día hábil). Solo cuentan '
            'los festivos oficiales (LFT art. 74) que tú revisas y activas, '
            'más tus días propios.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                key: const ValueKey('ajustes-anio'),
                segments: [
                  for (final a in [c.hoy.anio, c.hoy.anio + 1])
                    ButtonSegment(value: a, label: Text('$a')),
                ],
                selected: {_anio},
                onSelectionChanged: (s) => setState(() => _anio = s.first),
              ),
              OutlinedButton.icon(
                key: const ValueKey('ajustes-precargar'),
                onPressed: () async {
                  final n = await servicio.precargarFestivos(_anio);
                  if (context.mounted) {
                    avisar(
                      context,
                      n == 0
                          ? 'Los festivos de $_anio ya estaban.'
                          : 'Se agregaron $n festivos de $_anio, inactivos: '
                                'revísalos y actívalos.',
                    );
                  }
                },
                icon: const Icon(Icons.download_outlined),
                label: Text('Precargar festivos de $_anio'),
              ),
              TextButton.icon(
                key: const ValueKey('ajustes-dia-propio'),
                onPressed: _agregarPropio,
                icon: const Icon(Icons.add),
                label: const Text('Día propio'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (dias.isEmpty)
            Text('Sin días inhábiles en $_anio.')
          else
            for (final d in dias)
              SwitchListTile(
                key: ValueKey('ajustes-dia-${d.fecha}'),
                contentPadding: EdgeInsets.zero,
                value: d.activo,
                title: Text('${textoFecha(d.fecha)} · ${d.nombre}'),
                subtitle: Text(
                  [
                    d.tipo == TipoDiaInhabil.festivoOficial
                        ? 'Festivo oficial'
                        : 'Propio',
                    if (d.fuente.isNotEmpty) d.fuente,
                    if (!d.activo) 'Sin activar',
                  ].join(' · '),
                ),
                onChanged: (activo) => intentar(
                  context,
                  () => servicio.activarDiaInhabil(d, activo: activo),
                ),
              ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ libros

String nombrePapel(PapelLibro p) => switch (p) {
  PapelLibro.titular => 'Titular',
  PapelLibro.miembro => 'Miembro',
  PapelLibro.albacea => 'Albacea',
  PapelLibro.albaceaSuplente => 'Suplente',
};

class _Libros extends ConsumerWidget {
  const _Libros({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final adultos = c.carga.adultosConFinanzas;
    final otros = [
      for (final p in adultos)
        if (p != c.personaId) p,
    ];
    final tieneRepresentado = c.datos.libros.any(
      (l) => l.tipo == dom.TipoLibro.representado,
    );
    // Crear libros: adultos con Finanzas en lo suyo (la maestra no escribe en
    // lo ajeno). El de papá, solo el dueño (fin_crear_libro_representado).
    final creaLibros = c.administraHogar && !c.permiso.comoMaestra;
    final creaRepresentado =
        creaLibros && c.rol == Rol.dueno && !tieneRepresentado;
    return TarjetaModulo(
      key: const ValueKey('ajustes-libros'),
      titulo: 'Libros y albaceas',
      icono: Icons.menu_book_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cada adulto lleva su libro personal (lo crea el servidor al darle '
            'su rol). Un libro compartido se crea con 2 o más miembros: quien lo '
            'crea es su administrador (agrega y saca miembros, lo hace pública '
            'o privada y lo archiva) y cualquiera puede salirse, menos el '
            'último; si quedan menos de 2, el presupuesto pasa a privado para '
            'quien se queda. El libro de papá lo llevan 1 albacea y, si '
            'quieres, 1 suplente, que escribe solo si no hay albacea vigente.',
          ),
          const SizedBox(height: 8),
          for (final l in c.libros) _FilaLibro(contexto: c, libro: l),
          if (creaLibros) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('ajustes-nuevo-compartido'),
                  onPressed: otros.isEmpty
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => DialogoLibroCompartido(contexto: c),
                        ),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Nuevo libro compartido'),
                ),
                if (creaRepresentado)
                  OutlinedButton.icon(
                    key: const ValueKey('ajustes-nuevo-representado'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => DialogoLibroRepresentado(contexto: c),
                    ),
                    icon: const Icon(Icons.elderly_outlined),
                    label: const Text('Libro de papá (albaceas)'),
                  ),
              ],
            ),
            if (otros.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Para un libro compartido hace falta otro adulto con '
                  'Finanzas; pídele al dueño que lo cree.',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Un libro en la lista de Ajustes: sus miembros, su visibilidad y lo que
/// puede hacer la persona (administrarlo si lo creó; salirse si es miembro).
class _FilaLibro extends ConsumerWidget {
  const _FilaLibro({required this.contexto, required this.libro});

  final ContextoFinanzas contexto;
  final Libro libro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final l = libro;
    final compartido = l.tipo == dom.TipoLibro.compartido;
    final permiso = c.permisoEn(l);
    final marcas = [
      if (compartido) nombreVisibilidad(l.visibilidad),
      if (l.archivado) 'Archivado · solo lectura',
      if (permiso.comoMaestra || permiso.comoLector) 'Solo lectura',
    ];
    return ListTile(
      key: ValueKey('ajustes-libro-${l.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (l.tipo) {
        dom.TipoLibro.personal => Icons.person_outline,
        dom.TipoLibro.compartido => Icons.groups_outlined,
        dom.TipoLibro.representado => Icons.elderly_outlined,
      }),
      title: Text(
        ['${l.nombre} · ${nombreTipoLibro(l.tipo)}', ...marcas].join(' · '),
      ),
      subtitle: Text(
        [
              for (final m in l.vigentes(c.hoy))
                '${c.carga.nombreDe(m.personaId)} (${nombrePapel(m.papel)}'
                    '${l.esAdministrador(m.personaId) ? ', administrador' : ''})',
            ].join(', ') +
            (compartido &&
                    l.papelDe(c.personaId, c.hoy) != null &&
                    l.vigentes(c.hoy).length == 1
                ? '\nEres el último miembro: no puedes salirte; para dejar de '
                      'usarlo, archívalo.'
                : ''),
      ),
      trailing:
          l.tipo == dom.TipoLibro.representado &&
              (c.puedeNombrarAlbaceaEn(l, PapelLibro.albacea) ||
                  c.puedeNombrarAlbaceaEn(l, PapelLibro.albaceaSuplente))
          ? Wrap(
              spacing: 4,
              children: [
                for (final (papel, etiqueta) in [
                  (PapelLibro.albacea, 'Nombrar albacea'),
                  (PapelLibro.albaceaSuplente, 'Nombrar suplente'),
                ])
                  if (c.puedeNombrarAlbaceaEn(l, papel))
                    TextButton(
                      key: ValueKey(
                        'libro-nombrar-${papel == PapelLibro.albacea ? 'albacea' : 'suplente'}-${l.id}',
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            DialogoNombrarAlbacea(libroId: l.id, papel: papel),
                      ),
                      child: Text(etiqueta),
                    ),
              ],
            )
          : compartido && (c.administraMiembrosDe(l) || c.puedeSalirDe(l))
          ? Wrap(
              spacing: 4,
              children: [
                if (c.administraMiembrosDe(l))
                  TextButton(
                    key: ValueKey('libro-miembros-${l.id}'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => DialogoMiembrosLibro(libroId: l.id),
                    ),
                    child: const Text('Administrar'),
                  ),
                if (c.puedeSalirDe(l))
                  TextButton(
                    key: ValueKey('libro-salir-${l.id}'),
                    onPressed: () => salirDelLibro(context, ref, c, l),
                    child: const Text('Salir del libro'),
                  ),
              ],
            )
          : null,
    );
  }
}

/// Nuevo libro compartido: nombre, visibilidad (privada por omisión) y otros
/// miembros adultos con Finanzas. Quien lo crea es su administrador.
class DialogoLibroCompartido extends ConsumerStatefulWidget {
  const DialogoLibroCompartido({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoLibroCompartido> createState() =>
      _DialogoLibroCompartidoState();
}

class _DialogoLibroCompartidoState
    extends ConsumerState<DialogoLibroCompartido> {
  final _nombre = TextEditingController();
  final _elegidos = <String>{};
  dom.VisibilidadLibro _visibilidad = dom.VisibilidadLibro.privada;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final otros = [
      for (final p in c.carga.adultosConFinanzas)
        if (p != c.personaId) p,
    ];
    final valido = _nombre.text.trim().isNotEmpty && _elegidos.isNotEmpty;
    return AlertDialog(
      title: const Text('Nuevo libro compartido'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('compartido-nombre'),
                controller: _nombre,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Nombre (p. ej. Gastos de la casa)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              const Text('Quién lo ve'),
              const SizedBox(height: 4),
              SelectorVisibilidad(
                valor: _visibilidad,
                alCambiar: (v) => setState(() => _visibilidad = v),
              ),
              const SizedBox(height: 12),
              const Text(
                'Miembros (además de ti, que serás el administrador):',
              ),
              for (final p in otros)
                CheckboxListTile(
                  key: ValueKey('compartido-miembro-$p'),
                  contentPadding: EdgeInsets.zero,
                  value: _elegidos.contains(p),
                  title: Text(c.carga.nombreDe(p)),
                  onChanged: (x) => setState(() {
                    if (x ?? false) {
                      _elegidos.add(p);
                    } else {
                      _elegidos.remove(p);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('compartido-crear'),
          onPressed: !valido || _guardando
              ? null
              : () async {
                  setState(() => _guardando = true);
                  final navegador = Navigator.of(context);
                  String? id;
                  final ok = await intentar(context, () async {
                    id = await ref
                        .read(servicioFinanzasProvider)
                        .crearLibroCompartido(_nombre.text, [
                          ..._elegidos,
                        ], visibilidad: _visibilidad);
                  });
                  if (!mounted) return;
                  if (ok) {
                    if (id != null) {
                      ref.read(libroElegidoProvider.notifier).elegir(id!);
                    }
                    navegador.pop();
                  } else {
                    setState(() => _guardando = false);
                  }
                },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

/// Libro de papá (persona representada, sin cuenta): quien lo crea queda
/// como albacea; el suplente es opcional (D19; P4).
class DialogoLibroRepresentado extends ConsumerStatefulWidget {
  const DialogoLibroRepresentado({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoLibroRepresentado> createState() =>
      _DialogoLibroRepresentadoState();
}

class _DialogoLibroRepresentadoState
    extends ConsumerState<DialogoLibroRepresentado> {
  final _titular = TextEditingController();
  final _libro = TextEditingController();
  String? _suplente;
  bool _guardando = false;

  @override
  void dispose() {
    _titular.dispose();
    _libro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final otros = [
      for (final p in c.carga.adultosConFinanzas)
        if (p != c.personaId) p,
    ];
    return AlertDialog(
      title: const Text('Libro de una persona representada'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Para la persona que no usa la app (papá). Tú quedas como '
              'albacea: registras en su nombre, siempre con motivo, y queda en '
              'la bitácora.',
            ),
            TextField(
              key: const ValueKey('representado-titular'),
              controller: _titular,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nombre de la persona (p. ej. Papá)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              key: const ValueKey('representado-libro'),
              controller: _libro,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Nombre del libro (opcional)',
              ),
            ),
            DropdownButtonFormField<String?>(
              key: const ValueKey('representado-suplente'),
              initialValue: _suplente,
              decoration: const InputDecoration(
                labelText: 'Suplente (opcional)',
                helperText: 'Escribe solo si no hay albacea vigente.',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin suplente'),
                ),
                for (final p in otros)
                  DropdownMenuItem(value: p, child: Text(c.carga.nombreDe(p))),
              ],
              onChanged: (x) => setState(() => _suplente = x),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('representado-crear'),
          onPressed: _titular.text.trim().isEmpty || _guardando
              ? null
              : () async {
                  setState(() => _guardando = true);
                  final navegador = Navigator.of(context);
                  String? id;
                  final ok = await intentar(context, () async {
                    id = await ref
                        .read(servicioFinanzasProvider)
                        .crearLibroRepresentado(
                          _titular.text,
                          nombreLibro: _libro.text,
                          suplenteId: _suplente,
                        );
                  });
                  if (!mounted) return;
                  if (ok) {
                    if (id != null) {
                      ref.read(libroElegidoProvider.notifier).elegir(id!);
                    }
                    navegador.pop();
                  } else {
                    setState(() => _guardando = false);
                  }
                },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- privacidad

class _Privacidad extends StatelessWidget {
  const _Privacidad({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context) {
    final CargaFinanzas carga = contexto.carga;
    final maestra = carga.cuentaMaestra;
    return TarjetaModulo(
      key: const ValueKey('ajustes-privacidad'),
      titulo: 'Privacidad',
      icono: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            carga.esMaestra
                ? 'Esta es la cuenta maestra del hogar: lee todos los libros y '
                      'no escribe en lo ajeno. Cada vez que abres un libro de '
                      'otra persona queda en la bitácora, y esa persona lo ve.'
                : maestra == null
                ? 'El hogar no tiene cuenta maestra: solo tú y quienes llevan '
                      'cada libro lo ven.'
                : 'El hogar tiene una cuenta maestra ($maestra) que lee todos '
                      'los libros, también el tuyo, y nunca escribe en ellos. '
                      'Cada consulta a tu libro queda en la bitácora.',
            key: const ValueKey('ajustes-texto-maestra'),
          ),
          const SizedBox(height: 8),
          const Text(
            'El dinero nunca va a la IA en la nube ni a las bocinas (D3).',
          ),
        ],
      ),
    );
  }
}
