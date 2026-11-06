/// Diálogos de configuración de un libro: ingreso (con su calendario),
/// compromiso, sobre y deuda. Los usan sus pantallas y el asistente de
/// arranque. Montos y fechas los captura la persona: nada se inventa.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../casos_uso/sugerencias.dart';
import '../../datos/repositorio.dart';
import '../../estado/proveedores.dart';
import '../comunes.dart';

const _diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Lee "1, 11" o "15 y último" en días del mes (0 = último).
List<int>? diasDeTexto(String texto) {
  final partes = texto
      .toLowerCase()
      .replaceAll('último', '0')
      .replaceAll('ultimo', '0')
      .split(RegExp(r'[,y\s]+'))
      .where((p) => p.isNotEmpty);
  final dias = <int>[];
  for (final p in partes) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 31) return null;
    dias.add(n);
  }
  return dias.isEmpty ? null : dias;
}

/// Editor del calendario de un pago o ingreso.
class EditorCalendario extends StatefulWidget {
  const EditorCalendario({
    super.key,
    required this.inicial,
    required this.alCambiar,
    this.paraIngreso = true,
  });

  final CalendarioConfig inicial;
  final ValueChanged<CalendarioConfig?> alCambiar;

  /// Los ingresos pasan al siguiente día hábil; los pagos que salen se
  /// quedan en su fecha (regla 5 de 4.5).
  final bool paraIngreso;

  @override
  State<EditorCalendario> createState() => _EditorCalendarioState();
}

class _EditorCalendarioState extends State<EditorCalendario> {
  late FormaPago _forma = widget.inicial.forma;
  late int _diaSemana = widget.inicial.diaSemana ?? 5;
  late final _dias = TextEditingController(
    text: widget.inicial.diasMes
        .map((d) => d == 0 ? 'último' : '$d')
        .join(', '),
  );

  /// Fecha de un pago conocido: la escribe la persona (no se inventa); sin
  /// ella el calendario catorcenal o cada N meses no está completo.
  late Fecha? _ancla = widget.inicial.fechaAncla;
  late int _intervalo = widget.inicial.intervaloMeses ?? 2;
  late ReglaDiaInhabil _regla = widget.inicial.reglaPara(
    widget.paraIngreso
        ? CalendarioConfig.reglaDeIngreso
        : CalendarioConfig.reglaDeSalida,
  );

  @override
  void dispose() {
    _dias.dispose();
    super.dispose();
  }

  CalendarioConfig? _armar() {
    final dias = diasDeTexto(_dias.text);
    final ancla = _ancla;
    final c = switch (_forma) {
      FormaPago.semanal => CalendarioConfig.semanal(_diaSemana, regla: _regla),
      FormaPago.catorcenal =>
        ancla == null
            ? null
            : CalendarioConfig.catorcenal(ancla, regla: _regla),
      FormaPago.quincenal => CalendarioConfig.quincenal(
        diasMes: dias != null && dias.length == 2 ? dias : const [15, 0],
        regla: _regla,
      ),
      FormaPago.mensual =>
        dias == null ? null : CalendarioConfig.mensual(dias, regla: _regla),
      FormaPago.cadaMeses =>
        ancla == null
            ? null
            : CalendarioConfig.cadaMeses(ancla, _intervalo, regla: _regla),
    };
    if (c == null) return null;
    try {
      c.calendario;
      return c;
    } on ArgumentError {
      return null;
    }
  }

  void _avisar() => widget.alCambiar(_armar());

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<FormaPago>(
        key: const ValueKey('calendario-forma'),
        initialValue: _forma,
        decoration: const InputDecoration(labelText: 'Cada cuándo'),
        items: const [
          DropdownMenuItem(value: FormaPago.semanal, child: Text('Semanal')),
          DropdownMenuItem(
            value: FormaPago.catorcenal,
            child: Text('Catorcenal'),
          ),
          DropdownMenuItem(
            value: FormaPago.quincenal,
            child: Text('Quincenal'),
          ),
          DropdownMenuItem(
            value: FormaPago.mensual,
            child: Text('Mensual (1 o 2 días fijos)'),
          ),
          DropdownMenuItem(
            value: FormaPago.cadaMeses,
            child: Text('Cada N meses (bimestral…)'),
          ),
        ],
        onChanged: (f) {
          setState(() => _forma = f!);
          _avisar();
        },
      ),
      if (_forma == FormaPago.semanal)
        DropdownButtonFormField<int>(
          initialValue: _diaSemana,
          decoration: const InputDecoration(labelText: 'Día'),
          items: [
            for (var i = 1; i <= 7; i++)
              DropdownMenuItem(value: i, child: Text(_diasSemana[i - 1])),
          ],
          onChanged: (d) {
            setState(() => _diaSemana = d!);
            _avisar();
          },
        ),
      if (_forma == FormaPago.quincenal || _forma == FormaPago.mensual)
        TextFormField(
          key: const ValueKey('calendario-dias'),
          controller: _dias,
          decoration: InputDecoration(
            labelText: _forma == FormaPago.quincenal
                ? 'Días (por omisión 15 y último)'
                : 'Día o días del mes (p. ej. 1, 11 o "último")',
          ),
          onChanged: (_) => _avisar(),
          validator: (_) =>
              _forma == FormaPago.mensual &&
                  (diasDeTexto(_dias.text)?.length ?? 0) == 0
              ? 'Escribe uno o dos días'
              : ((diasDeTexto(_dias.text)?.length ?? 0) > 2
                    ? 'Uno o dos días'
                    : null),
        ),
      if (_forma == FormaPago.catorcenal || _forma == FormaPago.cadaMeses)
        FormField<Fecha>(
          key: const ValueKey('calendario-ancla'),
          validator: (_) => _ancla == null
              ? 'Elige la fecha de un pago que ya conozcas'
              : null,
          builder: (estado) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha de un pago conocido'),
            subtitle: Text(
              _ancla == null
                  ? (estado.errorText ?? 'Sin elegir: toca para escribirla')
                  : '${textoFecha(_ancla!)} ${_ancla!.anio}',
            ),
            trailing: const Icon(Icons.event_outlined),
            onTap: () async {
              final f = await elegirFecha(
                context,
                _ancla ?? Fecha.deDateTime(DateTime.now()),
              );
              if (f != null) {
                setState(() => _ancla = f);
                estado.didChange(f);
                _avisar();
              }
            },
          ),
        ),
      if (_forma == FormaPago.cadaMeses)
        DropdownButtonFormField<int>(
          initialValue: _intervalo,
          decoration: const InputDecoration(labelText: 'Cada cuántos meses'),
          items: const [
            DropdownMenuItem(value: 2, child: Text('2 (bimestral)')),
            DropdownMenuItem(value: 3, child: Text('3 (trimestral)')),
            DropdownMenuItem(value: 6, child: Text('6 (semestral)')),
            DropdownMenuItem(value: 12, child: Text('12 (anual)')),
          ],
          onChanged: (n) {
            setState(() => _intervalo = n!);
            _avisar();
          },
        ),
      DropdownButtonFormField<ReglaDiaInhabil>(
        key: const ValueKey('calendario-regla'),
        initialValue: _regla,
        decoration: InputDecoration(
          labelText: 'Si cae en fin de semana o festivo',
          helperText: widget.paraIngreso
              ? 'Los ingresos pasan al siguiente día hábil'
              : 'Los pagos se quedan en su fecha. Elige "Siguiente día hábil" '
                    'solo para la deuda cuyo pago pasa al día hábil siguiente '
                    '(se decide deuda por deuda)',
        ),
        items: const [
          DropdownMenuItem(
            value: ReglaDiaInhabil.siguienteDiaHabil,
            child: Text('Siguiente día hábil'),
          ),
          DropdownMenuItem(
            value: ReglaDiaInhabil.diaHabilAnterior,
            child: Text('Día hábil anterior'),
          ),
          DropdownMenuItem(
            value: ReglaDiaInhabil.sinCambio,
            child: Text('En su fecha'),
          ),
        ],
        onChanged: (r) {
          setState(() => _regla = r!);
          _avisar();
        },
      ),
    ],
  );
}

/// Base de los diálogos: título, formulario y "Guardar".
class _DialogoForma extends StatelessWidget {
  const _DialogoForma({
    required this.titulo,
    required this.forma,
    required this.campos,
    required this.alGuardar,
  });

  final String titulo;
  final GlobalKey<FormState> forma;
  final List<Widget> campos;
  final Future<void> Function() alGuardar;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(titulo),
    content: SizedBox(
      width: 480,
      child: Form(
        key: forma,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: campos),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('dialogo-guardar'),
        onPressed: () async {
          if (!(forma.currentState?.validate() ?? false)) return;
          final navegador = Navigator.of(context);
          if (await intentar(context, alGuardar)) navegador.pop();
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}

// ------------------------------------------------------------------ ingreso

/// Forma de un ingreso conocido, **sin montos ni fechas**: esos los captura
/// el dueño (D19: "Montos y fechas los captura el dueño; no se inventan").
class PlantillaIngreso {
  const PlantillaIngreso({
    required this.nombre,
    required this.tipo,
    required this.certeza,
    required this.calendario,
    required this.ayuda,
  });

  final String nombre;
  final TipoIngreso tipo;
  final Certeza certeza;
  final CalendarioConfig calendario;
  final String ayuda;

  /// Pensión de papá: días 1 y 11 de cada mes; si cae en fin de semana o
  /// festivo, el siguiente día hábil (P15; regla 6 de 4.5).
  static const pension = PlantillaIngreso(
    nombre: 'Pensión',
    tipo: TipoIngreso.pension,
    certeza: Certeza.segura,
    calendario: CalendarioConfig.mensual([
      1,
      11,
    ], regla: ReglaDiaInhabil.siguienteDiaHabil),
    ayuda:
        'Días 1 y 11 de cada mes; si cae en fin de semana o festivo, el '
        'siguiente día hábil. Escribe el neto que llega en cada pago.',
  );

  /// Apoyo 60+ cada bimestre, probable (P15; regla 6 de 4.5). La fecha de un
  /// pago la elige el dueño.
  static const apoyo60 = PlantillaIngreso(
    nombre: 'Apoyo 60+',
    tipo: TipoIngreso.otro,
    certeza: Certeza.probable,
    calendario: CalendarioConfig(
      forma: FormaPago.cadaMeses,
      intervaloMeses: 2,
      regla: ReglaDiaInhabil.siguienteDiaHabil,
    ),
    ayuda:
        'Cada 2 meses, desde la fecha de un pago que ya conozcas. Cuenta como '
        'probable. Escribe el monto de cada pago.',
  );

  /// Las del libro de una persona representada.
  static const deRepresentado = [pension, apoyo60];
}

class DialogoIngreso extends ConsumerStatefulWidget {
  const DialogoIngreso({super.key, required this.contexto, this.plantilla});

  final ContextoFinanzas contexto;

  /// Forma ya llenada (p. ej. la pensión de papá); el monto y las fechas los
  /// escribe la persona.
  final PlantillaIngreso? plantilla;

  @override
  ConsumerState<DialogoIngreso> createState() => _DialogoIngresoState();
}

class _DialogoIngresoState extends ConsumerState<DialogoIngreso> {
  final _forma = GlobalKey<FormState>();
  late final _nombre = TextEditingController(
    text: widget.plantilla?.nombre ?? '',
  );
  final _monto = TextEditingController();
  late final CalendarioConfig _inicial =
      widget.plantilla?.calendario ?? const CalendarioConfig.quincenal();
  late CalendarioConfig? _calendario = widget.plantilla == null
      ? _inicial
      : (_completo(_inicial) ? _inicial : null);
  late Certeza _certeza = widget.plantilla?.certeza ?? Certeza.segura;
  late TipoIngreso _tipo = widget.plantilla?.tipo ?? TipoIngreso.salario;
  String? _destino;

  static bool _completo(CalendarioConfig c) {
    try {
      c.calendario;
      return true;
    } on ArgumentError {
      return false;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final destinos = cuentasParaRecibir(c.datos, c.libroId);
    _destino ??= destinos.firstOrNull?.id;
    final plantilla = widget.plantilla;
    return _DialogoForma(
      titulo: plantilla == null
          ? 'Nuevo ingreso'
          : 'Nuevo ingreso: ${plantilla.nombre}',
      forma: _forma,
      campos: [
        if (plantilla != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              plantilla.ayuda,
              key: const ValueKey('ingreso-ayuda-plantilla'),
            ),
          ),
        TextFormField(
          key: const ValueKey('ingreso-nombre'),
          controller: _nombre,
          decoration: const InputDecoration(
            labelText: 'Nombre (p. ej. Sueldo)',
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
        ),
        CampoMonto(
          key: const ValueKey('ingreso-monto'),
          controlador: _monto,
          etiqueta: 'Neto por pago',
          ayuda: 'Lo que llega a la cuenta, después de descuentos.',
        ),
        EditorCalendario(
          inicial: _inicial,
          alCambiar: (cal) => _calendario = cal,
        ),
        DropdownButtonFormField<TipoIngreso>(
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: const [
            DropdownMenuItem(
              value: TipoIngreso.salario,
              child: Text('Salario'),
            ),
            DropdownMenuItem(
              value: TipoIngreso.independiente,
              child: Text('Independiente'),
            ),
            DropdownMenuItem(
              value: TipoIngreso.prestaciones,
              child: Text('Prestaciones'),
            ),
            DropdownMenuItem(
              value: TipoIngreso.pension,
              child: Text('Pensión'),
            ),
            DropdownMenuItem(
              value: TipoIngreso.otro,
              child: Text('Otro (apoyo, renta…)'),
            ),
          ],
          onChanged: (t) => setState(() => _tipo = t!),
        ),
        DropdownButtonFormField<Certeza>(
          initialValue: _certeza,
          decoration: const InputDecoration(labelText: 'Certeza'),
          items: [
            for (final x in Certeza.values)
              DropdownMenuItem(value: x, child: Text(nombreCerteza(x))),
          ],
          onChanged: (x) => setState(() => _certeza = x!),
        ),
        DropdownButtonFormField<String>(
          initialValue: _destino,
          decoration: const InputDecoration(labelText: 'Llega a'),
          items: [
            for (final x in destinos)
              DropdownMenuItem(value: x.id, child: Text(x.nombre)),
          ],
          onChanged: (x) => setState(() => _destino = x),
          validator: (v) =>
              v == null ? 'Crea primero una cuenta de banco o efectivo' : null,
        ),
      ],
      alGuardar: () async {
        final cal = _calendario;
        if (cal == null) throw const ErrorFinanzas('Revisa el calendario');
        await ref
            .read(servicioFinanzasProvider)
            .crearIngreso(
              libroId: c.libroId,
              nombre: _nombre.text,
              montoNeto: centavosDeTexto(_monto.text)!,
              calendario: cal,
              cuentaDestinoId: _destino!,
              tipo: _tipo,
              certeza: _certeza,
            );
      },
    );
  }
}

/// Cambiar el neto desde una fecha (vigencia nueva).
class DialogoCambiarNeto extends ConsumerStatefulWidget {
  const DialogoCambiarNeto({
    super.key,
    required this.ingreso,
    required this.hoy,
  });

  final Ingreso ingreso;
  final Fecha hoy;

  @override
  ConsumerState<DialogoCambiarNeto> createState() => _DialogoCambiarNetoState();
}

class _DialogoCambiarNetoState extends ConsumerState<DialogoCambiarNeto> {
  final _forma = GlobalKey<FormState>();
  late final _monto = TextEditingController(
    text: widget.ingreso.vigenciaActual == null
        ? ''
        : textoDeCentavos(widget.ingreso.vigenciaActual!.montoNeto),
  );
  late CalendarioConfig? _calendario =
      widget.ingreso.vigenciaActual?.calendario ??
      const CalendarioConfig.quincenal();
  late Fecha _desde = widget.hoy;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DialogoForma(
    titulo: 'Cambiar ${widget.ingreso.nombre}',
    forma: _forma,
    campos: [
      CampoMonto(controlador: _monto, etiqueta: 'Neto nuevo por pago'),
      EditorCalendario(
        inicial: _calendario ?? const CalendarioConfig.quincenal(),
        alCambiar: (cal) => _calendario = cal,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Desde'),
        subtitle: Text(textoFecha(_desde)),
        trailing: const Icon(Icons.event_outlined),
        onTap: () async {
          final f = await elegirFecha(context, _desde);
          if (f != null) setState(() => _desde = f);
        },
      ),
      const Text('El historial no cambia: se crea una vigencia nueva.'),
    ],
    alGuardar: () => ref
        .read(servicioFinanzasProvider)
        .cambiarNeto(
          widget.ingreso.id,
          montoNeto: centavosDeTexto(_monto.text)!,
          calendario: _calendario!,
          desde: _desde,
        ),
  );
}

// -------------------------------------------------------------- compromiso

/// Elige una categoría (y con ella la cuenta de gasto).
Widget campoCategoria(
  DatosFinanzas d,
  String? valor,
  ValueChanged<String?> alCambiar, {
  bool soloNivel1 = false,
}) {
  final todas = [
    for (final x in d.arbol.todas)
      if (x.visible && (!soloNivel1 || x.nivel == 1)) x,
  ]..sort((a, b) => d.arbol.ruta(a.id).compareTo(d.arbol.ruta(b.id)));
  return DropdownButtonFormField<String>(
    key: const ValueKey('campo-categoria'),
    initialValue: todas.any((x) => x.id == valor) ? valor : null,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Categoría'),
    items: [
      for (final x in todas)
        DropdownMenuItem(value: x.id, child: Text(d.arbol.ruta(x.id))),
    ],
    onChanged: alCambiar,
    validator: (v) => v == null
        ? (todas.isEmpty
              ? 'Importa o crea primero las categorías'
              : 'Elige una categoría')
        : null,
  );
}

class DialogoCompromiso extends ConsumerStatefulWidget {
  const DialogoCompromiso({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoCompromiso> createState() => _DialogoCompromisoState();
}

class _DialogoCompromisoState extends ConsumerState<DialogoCompromiso> {
  final _forma = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _monto = TextEditingController();
  TipoCompromiso _tipo = TipoCompromiso.fija;
  String? _categoria;
  CalendarioConfig? _calendario = const CalendarioConfig.mensual([
    1,
  ], regla: ReglaDiaInhabil.sinCambio);
  bool _protegida = false;

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    return _DialogoForma(
      titulo: 'Nuevo compromiso',
      forma: _forma,
      campos: [
        TextFormField(
          key: const ValueKey('compromiso-nombre'),
          controller: _nombre,
          decoration: const InputDecoration(
            labelText: 'Nombre (renta, luz, predial…)',
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
        ),
        SegmentedButton<TipoCompromiso>(
          segments: const [
            ButtonSegment(
              value: TipoCompromiso.fija,
              label: Text('Gasto fijo'),
            ),
            ButtonSegment(
              value: TipoCompromiso.reserva,
              label: Text('Reserva'),
            ),
          ],
          selected: {_tipo},
          onSelectionChanged: (s) => setState(() => _tipo = s.first),
        ),
        CampoMonto(
          key: const ValueKey('compromiso-monto'),
          controlador: _monto,
          etiqueta: 'Monto de cada pago',
        ),
        EditorCalendario(
          inicial: _calendario!,
          paraIngreso: false,
          alCambiar: (cal) => _calendario = cal,
        ),
        campoCategoria(c.datos, _categoria, (v) {
          setState(() {
            _categoria = v;
            _protegida =
                v != null && (c.datos.arbol.porId(v)?.protegida ?? false);
          });
        }),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _protegida,
          onChanged: (x) => setState(() => _protegida = x),
          title: const Text('Protegido (nunca se propone recortarlo)'),
        ),
      ],
      alGuardar: () async {
        final cal = _calendario;
        if (cal == null) throw const ErrorFinanzas('Revisa el calendario');
        final cuenta = c.datos.arbol.cuentaGastoDe(_categoria!);
        if (cuenta == null) {
          throw const ErrorFinanzas('La categoría no tiene cuenta de gasto');
        }
        final categoria = c.datos.arbol.porId(_categoria)!;
        await ref
            .read(servicioFinanzasProvider)
            .guardarCompromiso(
              Compromiso(
                id: const Uuid().v4(),
                libroId: c.libroId,
                nombre: _nombre.text.trim(),
                tipo: _tipo,
                cuentaGastoId: cuenta,
                categoriaId: _categoria,
                monto: centavosDeTexto(_monto.text)!,
                frecuencia: cal.frecuencia,
                calendario: cal,
                protegida: _protegida,
                prioridad: categoria.prioridad,
                desde: Semana.de(c.hoy).inicio,
              ),
            );
      },
    );
  }
}

// ------------------------------------------------------------------- sobre

class DialogoSobre extends ConsumerStatefulWidget {
  const DialogoSobre({super.key, required this.contexto, this.sobre});

  final ContextoFinanzas contexto;
  final Sobre? sobre;

  @override
  ConsumerState<DialogoSobre> createState() => _DialogoSobreState();
}

class _DialogoSobreState extends ConsumerState<DialogoSobre> {
  final _forma = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.sobre?.nombre ?? '');
  late final _monto = TextEditingController(
    text: widget.sobre == null
        ? ''
        : textoDeCentavos(widget.sobre!.montoSemanal),
  );
  late final _piso = TextEditingController(
    text: widget.sobre == null || widget.sobre!.pisoMinimo == 0
        ? ''
        : textoDeCentavos(widget.sobre!.pisoMinimo),
  );
  late String? _categoria = widget.sobre == null
      ? null
      : widget.contexto.datos.arbol
            .deCuentaGasto(widget.sobre!.cuentaGastoId)
            ?.id;
  late Prioridad _prioridad = widget.sobre?.prioridad ?? Prioridad.deseable;
  late ModoArrastre _arrastre =
      widget.sobre?.modoArrastre ?? ModoArrastre.arrastrar;
  late bool _protegida = widget.sobre?.protegida ?? false;

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    _piso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    return _DialogoForma(
      titulo: widget.sobre == null ? 'Nuevo sobre semanal' : 'Cambiar sobre',
      forma: _forma,
      campos: [
        campoCategoria(c.datos, _categoria, (v) {
          setState(() {
            _categoria = v;
            final cat = c.datos.arbol.porId(v);
            if (cat != null) {
              if (_nombre.text.trim().isEmpty) _nombre.text = cat.nombre;
              _prioridad = cat.prioridad;
              _protegida = cat.protegida;
            }
          });
        }, soloNivel1: true),
        TextFormField(
          key: const ValueKey('sobre-nombre'),
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre del sobre'),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
        ),
        CampoMonto(
          key: const ValueKey('sobre-monto'),
          controlador: _monto,
          etiqueta: 'Monto por semana',
        ),
        DropdownButtonFormField<Prioridad>(
          initialValue: _prioridad,
          decoration: const InputDecoration(
            labelText: 'Prioridad (orden de recortes)',
          ),
          items: [
            for (final p in Prioridad.values)
              DropdownMenuItem(value: p, child: Text(nombrePrioridad(p))),
          ],
          onChanged: (p) => setState(() => _prioridad = p!),
        ),
        CampoMonto(
          controlador: _piso,
          etiqueta: 'Piso mínimo (opcional)',
          obligatorio: false,
          ayuda: 'Lo que nunca se propone recortar.',
        ),
        DropdownButtonFormField<ModoArrastre>(
          initialValue: _arrastre,
          decoration: const InputDecoration(labelText: 'Lo que sobra'),
          items: const [
            DropdownMenuItem(
              value: ModoArrastre.arrastrar,
              child: Text('Pasa a la semana siguiente (hasta 2 semanas)'),
            ),
            DropdownMenuItem(
              value: ModoArrastre.alRemanente,
              child: Text('Va al remanente'),
            ),
          ],
          onChanged: (m) => setState(() => _arrastre = m!),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _protegida,
          onChanged: (x) => setState(() => _protegida = x),
          title: const Text('Protegido'),
        ),
      ],
      alGuardar: () async {
        final cuenta = c.datos.arbol.cuentaGastoDe(_categoria!);
        if (cuenta == null) {
          throw const ErrorFinanzas('La categoría no tiene cuenta de gasto');
        }
        await ref
            .read(servicioFinanzasProvider)
            .guardarSobre(
              Sobre(
                id: widget.sobre?.id ?? const Uuid().v4(),
                libroId: c.libroId,
                cuentaGastoId: cuenta,
                nombre: _nombre.text.trim(),
                montoSemanal: centavosDeTexto(_monto.text)!,
                protegida: _protegida,
                prioridad: _prioridad,
                pisoMinimo: centavosDeTexto(_piso.text) ?? 0,
                modoArrastre: _arrastre,
                activo: widget.sobre?.activo ?? true,
              ),
            );
      },
    );
  }
}

// ------------------------------------------------------------------- deuda

class DialogoDeuda extends ConsumerStatefulWidget {
  const DialogoDeuda({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  @override
  ConsumerState<DialogoDeuda> createState() => _DialogoDeudaState();
}

class _DialogoDeudaState extends ConsumerState<DialogoDeuda> {
  final _forma = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _abono = TextEditingController();
  final _minimo = TextEditingController();
  final _tasa = TextEditingController();
  TipoDeuda _tipo = TipoDeuda.conCosto;
  String? _cuenta;
  CalendarioConfig? _calendario = const CalendarioConfig.mensual([
    1,
  ], regla: ReglaDiaInhabil.sinCambio);

  @override
  void dispose() {
    _nombre.dispose();
    _abono.dispose();
    _minimo.dispose();
    _tasa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contexto;
    final pasivos = [
      for (final x in c.datos.cuentasDe(c.libroId))
        if (x.clase == ClaseCuenta.pasivo && x.estado == EstadoCuenta.activa) x,
    ];
    return _DialogoForma(
      titulo: 'Nueva deuda',
      forma: _forma,
      campos: [
        TextFormField(
          key: const ValueKey('deuda-nombre'),
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre'),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
        ),
        DropdownButtonFormField<TipoDeuda>(
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [
            for (final t in TipoDeuda.values)
              DropdownMenuItem(value: t, child: Text(nombreTipoDeuda(t))),
          ],
          onChanged: (t) => setState(() => _tipo = t!),
        ),
        DropdownButtonFormField<String>(
          initialValue: _cuenta,
          decoration: const InputDecoration(
            labelText: 'Cuenta (tarjeta o préstamo)',
            helperText: 'El saldo sale de esta cuenta.',
          ),
          items: [
            for (final x in pasivos)
              DropdownMenuItem(value: x.id, child: Text(x.nombre)),
          ],
          onChanged: (x) => setState(() => _cuenta = x),
          // fin_deudas.cuenta_pasivo_id es obligatoria: el saldo sale de ella.
          validator: (v) => v == null
              ? (pasivos.isEmpty
                    ? 'Crea primero la tarjeta o el préstamo en Cuentas'
                    : 'Elige la cuenta de la deuda')
              : null,
        ),
        CampoMonto(
          key: const ValueKey('deuda-abono'),
          controlador: _abono,
          etiqueta: 'Abono planeado por pago',
        ),
        if (_tipo == TipoDeuda.conCosto) ...[
          CampoMonto(
            controlador: _minimo,
            etiqueta: 'Pago mínimo',
            obligatorio: false,
          ),
          CampoPorcentaje(
            controlador: _tasa,
            etiqueta: 'Tasa anual (del estado de cuenta)',
          ),
        ],
        EditorCalendario(
          inicial: _calendario!,
          paraIngreso: false,
          alCambiar: (cal) => _calendario = cal,
        ),
      ],
      alGuardar: () async {
        final cal = _calendario;
        if (cal == null) throw const ErrorFinanzas('Revisa el calendario');
        await ref
            .read(servicioFinanzasProvider)
            .guardarDeuda(
              Deuda(
                id: const Uuid().v4(),
                libroId: c.libroId,
                nombre: _nombre.text.trim(),
                tipo: _tipo,
                cuentaPasivoId: _cuenta,
                abono: centavosDeTexto(_abono.text)!,
                frecuencia: cal.frecuencia,
                calendario: cal,
                minimo: _tipo == TipoDeuda.conCosto
                    ? (centavosDeTexto(_minimo.text) ?? 0)
                    : 0,
                tasaAnualPuntosBase: _tipo == TipoDeuda.conCosto
                    ? (CampoPorcentaje.puntosBase(_tasa.text) ?? 0)
                    : 0,
              ),
            );
      },
    );
  }
}
