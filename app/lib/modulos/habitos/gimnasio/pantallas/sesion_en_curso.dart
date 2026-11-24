/// E5 · Sesión en curso (pantalla completa, personalidad Sport): una pantalla,
/// una decisión (7.2).
///
/// - ✓ **Hecha** guarda la serie con lo que se ve (un toque); − y + ajustan
///   repeticiones y carga sin teclado; *Deshacer* queda a la vista 5 s.
/// - El descanso cuenta hacia un instante final y avisa por
///   `ServicioAvisoDescanso` (notificación local discreta).
/// - La sesión queda guardada `en_curso` desde el primer toque: si la tablet
///   vuelve a Casa se retoma con el PIN (PG-17). Mientras dura, retiene la
///   pantalla (`sesionGimnasioEnCursoProvider`, que enciende la pantalla).
/// - Todo funciona sin red: lo hecho se guarda en el equipo y sube después.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import '../../../../app/gimnasio/acceso_gimnasio.dart';
import '../../../../app/gimnasio/proveedores_gimnasio.dart';
import '../../../../diseno/gimnasio/gimnasio.dart';
import '../../../../diseno/proveedores.dart' show relojProvider;
import '../../../../diseno/valores_diseno.dart';
import '../../estado/proveedores.dart' show versionHabitosProvider;
import '../casos_uso/controlador_sesion.dart';
import '../casos_uso/servicio_gimnasio.dart';
import '../datos/modelos_gimnasio.dart';
import '../estado/proveedores_gimnasio.dart';
import 'comun.dart';

class PantallaSesionEnCurso extends ConsumerStatefulWidget {
  const PantallaSesionEnCurso({super.key});

  @override
  ConsumerState<PantallaSesionEnCurso> createState() => _EstadoSesionEnCurso();
}

class _EstadoSesionEnCurso extends ConsumerState<PantallaSesionEnCurso> {
  ControladorSesion? _c;
  ControladorRegenerativa? _r;
  EntrenamientoHoy? _h;
  DatosGimnasio? _datos;
  bool _cargando = true;
  bool _arrancado = false;
  late final ProviderContainer _contenedor;

  @override
  void initState() {
    super.initState();
    _contenedor = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    Map<String, String> parametros = const {};
    try {
      parametros = GoRouterState.of(context).uri.queryParameters;
    } catch (_) {
      // Sin router (pruebas de la pantalla sola): sin parámetros.
    }
    _iniciar(parametros);
  }

  Future<void> _iniciar(Map<String, String> parametros) async {
    final s = ref.read(servicioGimnasioProvider);
    if (s == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    try {
      final datos = await s.cargar();
      final hoy = ref.read(fechaDeHoyGimnasioProvider);
      var version = VersionSesion.deId(parametros['version'] ?? '');
      var h = await s.entrenamientoDe(
        hoy,
        datos: datos,
        tipo: parametros['tipo'],
        version: version,
      );
      // Si ya hay una sesión en curso, se retoma con su misma versión.
      final enCurso = h.filaSesion;
      if (version == null && enCurso != null && enCurso.estado == 'en_curso') {
        final v = VersionSesion.deId(enCurso.version);
        if (v != null && h.esFuerza && v != h.version) {
          h = await s.entrenamientoDe(
            hoy,
            datos: datos,
            tipo: parametros['tipo'],
            version: v,
          );
        }
      }
      final terminado =
          h.estado == EstadoEntrenamientoDia.hecho ||
          h.estado == EstadoEntrenamientoDia.parcial;
      if (!h.esSesion || terminado) {
        if (mounted) {
          setState(() {
            _h = h;
            _datos = datos;
            _cargando = false;
          });
        }
        return;
      }
      final fila = await s.iniciarSesion(h);
      ControladorSesion? c;
      ControladorRegenerativa? r;
      if (h.esFuerza) {
        c = ControladorSesion(
          servicio: s,
          hoy: h,
          fila: fila,
          datos: datos,
          ahora: ref.read(relojProvider).ahora,
          avisos: ref.read(servicioAvisoDescansoProvider),
        );
        await c.inicializar();
      } else {
        r = ControladorRegenerativa(servicio: s, hoy: h, fila: fila);
      }
      // La tablet retiene la pantalla y la pantalla se mantiene encendida.
      ref.read(sesionGimnasioEnCursoProvider.notifier).iniciar(s.persona);
      if (!mounted) {
        c?.dispose();
        r?.dispose();
        return;
      }
      setState(() {
        _c = c;
        _r = r;
        _h = h;
        _datos = datos;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    _r?.dispose();
    // Salir de la pantalla suelta la retención y la pantalla encendida. Se hace
    // fuera del árbol: no se modifica un proveedor mientras se desmonta.
    final contenedor = _contenedor;
    Future<void>.microtask(() {
      try {
        contenedor.read(sesionGimnasioEnCursoProvider.notifier).terminar();
      } catch (_) {
        // El contenedor ya no existe (la app se cerró).
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ref.watch(servicioGimnasioProvider);
    return MarcoGimnasio(
      destino: DestinoGimnasio.sesionEnCurso,
      sport: true,
      cuerpo: servicio == null
          ? const SinPersonaGimnasio()
          : _cargando
          ? const Center(
              child: CuerpoEstadoGimnasio(
                estado: EstadoVistaGimnasio.cargando,
                mensajes: MensajesEstadoGimnasio(
                  cargando: 'Preparando tu sesión…',
                ),
              ),
            )
          : _c != null
          ? _VistaFuerza(
              c: _c!,
              datos: _datos!,
              servicio: servicio,
              alTerminar: _terminar,
            )
          : _r != null
          ? _VistaRegenerativa(
              r: _r!,
              servicio: servicio,
              alTerminar: _terminarRegenerativa,
            )
          : _SinSesion(h: _h),
    );
  }

  void _recargar() {
    ref.read(versionGimnasioProvider.notifier).state++;
    ref.read(versionHabitosProvider.notifier).state++;
  }

  Future<void> _despues(ResultadoSesion r) async {
    ref.read(sesionGimnasioEnCursoProvider.notifier).terminar();
    _recargar();
    if (!mounted) return;
    final s = ref.read(servicioGimnasioProvider)!;
    final mensajes = [
      TextosHabitosGimnasio.sesionTerminada,
      for (final x in r.records.take(2))
        _textoRecord(x, s.catalogo, _datos?.inventario),
    ];
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(mensajes.join(' '))));
    context.go(RutasGimnasio.hoy);
  }

  Future<void> _terminar() async {
    final r = await _preguntarFinal(context, conEsfuerzo: true);
    if (r == null || _c == null) return;
    final res = await _c!.terminar(
      completa: r.completa,
      esfuerzo: r.esfuerzo,
      energia: r.energia,
    );
    await _despues(res);
  }

  Future<void> _terminarRegenerativa() async {
    final r = await _preguntarFinal(context, conEsfuerzo: false);
    if (r == null || _r == null) return;
    final res = await _r!.terminar(completa: r.completa, energia: r.energia);
    await _despues(res);
  }
}

/// «Nuevo récord personal en press de pecho: placa 6.»
String _textoRecord(RecordNuevo r, Catalogo c, Inventario? inv) {
  final ej = nombreDeEjercicio(
    c,
    c.ejercicioDeVariante(r.varianteId)?.id ?? r.varianteId,
  );
  final valor = switch (r.tipo) {
    'carga' => inv == null
        ? 'placa ${r.valor}'
        : mostrarCargaPasos(r.valor, inv).texto,
    'tiempo' => '${r.valor} s',
    'banda' => 'una banda más fuerte',
    _ => '${r.valor} repeticiones',
  };
  return MensajesGimnasio.recordPersonal(ej, valor);
}

class _Final {
  const _Final(this.completa, this.esfuerzo, this.energia);
  final bool completa;
  final int? esfuerzo;
  final int? energia;
}

/// «Terminé la sesión» o «Terminé una parte» (PG-13), con el esfuerzo y la
/// energía opcionales. Dos toques para terminar.
Future<_Final?> _preguntarFinal(
  BuildContext context, {
  required bool conEsfuerzo,
}) => showModalBottomSheet<_Final>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _HojaFinal(conEsfuerzo: conEsfuerzo),
);

class _HojaFinal extends StatefulWidget {
  const _HojaFinal({required this.conEsfuerzo});
  final bool conEsfuerzo;

  @override
  State<_HojaFinal> createState() => _EstadoHojaFinal();
}

class _EstadoHojaFinal extends State<_HojaFinal> {
  int? _esfuerzo;
  int? _energia;

  Widget _fila(String titulo, int? valor, ValueChanged<int?> alCambiar) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 1; i <= 5; i++)
                ChoiceChip(
                  label: Text('$i'),
                  selected: valor == i,
                  onSelected: (s) => alCambiar(s ? i : null),
                ),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.conEsfuerzo) ...[
              _fila(
                'Esfuerzo de la sesión (opcional)',
                _esfuerzo,
                (v) => setState(() => _esfuerzo = v),
              ),
              const SizedBox(height: 8),
            ],
            _fila(
              'Energía (opcional)',
              _energia,
              (v) => setState(() => _energia = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('termine-sesion'),
              onPressed: () => Navigator.pop(
                context,
                _Final(true, _esfuerzo, _energia),
              ),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              child: const Text(TextosHabitosGimnasio.terminoSesion),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const ValueKey('termine-parte'),
              onPressed: () => Navigator.pop(
                context,
                _Final(false, _esfuerzo, _energia),
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              child: const Text(TextosHabitosGimnasio.terminoParte),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SinSesion extends StatelessWidget {
  const _SinSesion({required this.h});
  final EntrenamientoHoy? h;

  @override
  Widget build(BuildContext context) {
    final terminado =
        h != null &&
        (h!.estado == EstadoEntrenamientoDia.hecho ||
            h!.estado == EstadoEntrenamientoDia.parcial);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              terminado
                  ? TextosHabitosGimnasio.sesionTerminada
                  : TextosHabitosGimnasio.hoyNoHayPlan,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(
                terminado ? RutasGimnasio.hoy : DestinoGimnasio.plan.ruta,
              ),
              child: Text(terminado ? 'Volver' : 'Ver mi plan'),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- regenerativa

class _VistaRegenerativa extends StatelessWidget {
  const _VistaRegenerativa({
    required this.r,
    required this.servicio,
    required this.alTerminar,
  });

  final ControladorRegenerativa r;
  final ServicioGimnasio servicio;
  final VoidCallback alTerminar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final c = servicio.catalogo;
    return ListenableBuilder(
      listenable: r,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            nombreDePlantilla(c, r.hoy.tipo),
            style: v.titulo(tamano: 24),
          ),
          Text(
            'Recuperar, no rendir. ${r.minutosHechos} de '
            '${r.hoy.regenerativa!.minutos} min',
            style: v.lectura(tamano: 15, color: v.textoTenue),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < r.bloques.length; i++)
            CheckboxListTile(
              key: ValueKey('bloque-$i'),
              contentPadding: EdgeInsets.zero,
              value: r.hechos.contains(i),
              onChanged: (_) => r.alternar(i),
              title: Text(
                c.bloque(r.bloques[i].bloqueId)?.nombre ?? r.bloques[i].bloqueId,
              ),
              subtitle: Text(c.bloque(r.bloques[i].bloqueId)?.instruccion ?? ''),
              secondary: Text('${r.bloques[i].minutos} min'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('terminar'),
            onPressed: alTerminar,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 64)),
            child: const Text(TextosHabitosGimnasio.terminar),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------- fuerza

class _VistaFuerza extends ConsumerWidget {
  const _VistaFuerza({
    required this.c,
    required this.datos,
    required this.servicio,
    required this.alTerminar,
  });

  final ControladorSesion c;
  final DatosGimnasio datos;
  final ServicioGimnasio servicio;
  final VoidCallback alTerminar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final cat = servicio.catalogo;
    final reloj = ref.watch(relojProvider).ahora;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final ancho = MediaQuery.sizeOf(context).width;
        final amplio = ancho >= 720;
        final nombre = nombreDePlantilla(cat, c.hoy.tipo);
        final cabecera = <Widget>[
          Text(
            '$nombre · ${textoVersion(c.hoy.version ?? VersionSesion.estandar)}',
            style: v.lectura(tamano: 15, color: v.textoTenue),
          ),
          if (c.hoy.duracionSeg != null)
            Text(
              '${textoDuracion(c.hoy.duracionSeg!)} · ejercicio '
              '${c.fase == FaseSesion.calentamiento ? 0 : c.idx + 1} de '
              '${c.ejercicios.length}',
              style: v.numero(tamano: 14, color: v.textoTenue),
            ),
          SizedBox(height: v.espacio * 2),
        ];
        final pie = Text(
          TextosHabitosGimnasio.guardadoEnElEquipo,
          style: v.lectura(tamano: 13, color: v.textoTenue),
        );
        if (c.fase == FaseSesion.calentamiento) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...cabecera,
                    _Calentamiento(c: c, catalogo: cat),
                    SizedBox(height: v.espacio * 2),
                    pie,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  key: const ValueKey('calentamiento-listo'),
                  onPressed: c.listo,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 64),
                  ),
                  child: const Text(TextosHabitosGimnasio.listo),
                ),
              ),
            ],
          );
        }
        return _SerieEnCurso(
          c: c,
          catalogo: cat,
          reloj: reloj,
          amplio: amplio,
          alTerminar: alTerminar,
          cabecera: cabecera,
          pie: pie,
        );
      },
    );
  }
}

class _Calentamiento extends StatelessWidget {
  const _Calentamiento({required this.c, required this.catalogo});

  final ControladorSesion c;
  final Catalogo catalogo;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final s = c.hoy.sesion!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            '${TextosHabitosGimnasio.calentamiento} · ${s.calentamientoMin} min',
            style: v.titulo(tamano: 26),
          ),
        ),
        const SizedBox(height: 8),
        for (final id in s.calentamiento)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.self_improvement),
            title: Text(catalogo.bloque(id)?.nombre ?? id),
            subtitle: Text(catalogo.bloque(id)?.instruccion ?? ''),
          ),
        const SizedBox(height: 8),
        Text(TextosHabitosGimnasio.calentamientoAyuda),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => context.go(DestinoGimnasio.sesion.ruta),
            child: const Text('Ver la sesión completa'),
          ),
        ),
      ],
    );
  }
}

class _SerieEnCurso extends ConsumerWidget {
  const _SerieEnCurso({
    required this.c,
    required this.catalogo,
    required this.reloj,
    required this.amplio,
    required this.alTerminar,
    required this.cabecera,
    required this.pie,
  });

  final ControladorSesion c;
  final Catalogo catalogo;
  final DateTime Function() reloj;
  final bool amplio;
  final VoidCallback alTerminar;
  final List<Widget> cabecera;
  final Widget pie;

  List<SerieVista> _series() {
    final e = c.actual;
    final inv = c.inventario;
    return [
      for (var n = 1; n <= e.series; n++)
        () {
          final hecha = c.hechas
              .where((s) => s.ejercicio == c.idx && s.n == n)
              .firstOrNull;
          if (hecha != null) {
            return SerieVista(
              numero: n,
              estado: EstadoSerie.hecha,
              repeticiones: e.porTiempo ? null : hecha.reps,
              cargaTexto: hecha.cargaPasos == null
                  ? null
                  : mostrarCargaPasos(hecha.cargaPasos!, inv).texto,
            );
          }
          final actual = n == c.serie && c.fase == FaseSesion.serie;
          return SerieVista(
            numero: n,
            estado: actual
                ? (c.descanso != null &&
                          !c.descanso!.haTerminado(reloj())
                      ? EstadoSerie.enDescanso
                      : EstadoSerie.actual)
                : (e.conPrecaucion
                      ? EstadoSerie.conPrecaucion
                      : EstadoSerie.pendiente),
            repeticiones: e.porTiempo ? null : e.objetivo,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final e = c.actual;
    final inv = c.inventario;
    final terminado = c.fase == FaseSesion.fin;
    final sigue = _sigue();
    final carga = c.llevaCarga && !terminado
        ? SelectorCarga(
            unidad: c.esDeBanda ? UnidadCarga.banda : UnidadCarga.placa,
            valorTexto: c.cargaTexto == null
                ? null
                : c.cargaTexto![0].toUpperCase() + c.cargaTexto!.substring(1),
            equivalenciaTexto: !c.esDeBanda &&
                    c.cargaPasos != null &&
                    inv.kgPorPasoX10 != null
                ? '≈ ${(c.cargaPasos! * inv.kgPorPasoX10!) ~/ 10} kg'
                : null,
            confirmacion: c.esDeBanda
                ? EstadoConfirmacionDato.confirmado
                : (inv.pasosMax != null
                      ? EstadoConfirmacionDato.confirmado
                      : EstadoConfirmacionDato.confirmar),
            enTope: c.enTope,
            alMenos: c.menosCarga,
            alMas: c.enTope ? null : c.masCarga,
            alConfirmar: c.esDeBanda
                ? null
                : () => context.push(DestinoGimnasio.inventario.ruta),
          )
        : null;
    final panel = terminado
        ? _Terminado(alTerminar: alTerminar)
        : PanelRegistroSerie(
            serieActual: c.serie,
            seriesTotales: e.series,
            repeticionesTexto: c.porTiempo ? '${c.reps} s' : '${c.reps}',
            porTiempo: c.porTiempo,
            alMenosReps: c.reps > 0 ? c.menosReps : null,
            alMasReps: c.masReps,
            carga: carga,
            alHecha: c.hecha,
            guardada: c.deshacerVisible,
            alDeshacer: c.deshacer,
          );
    // En el teléfono el ✓ y el temporizador quedan fijos abajo; lo demás se
    // desplaza (10): nunca salen de la pantalla con la letra grande.
    final ajustes = <Widget>[
      Semantics(
        label: 'Serie ${c.serie} de ${e.series}',
        excludeSemantics: true,
        child: Text(
          'SERIE  ${c.serie} / ${e.series}',
          style: v.titulo(tamano: 26, peso: FontWeight.w700),
        ),
      ),
      SizedBox(height: v.espacio * 1.5),
      SelectorPasos(
        etiqueta: c.porTiempo ? 'SEGUNDOS' : 'REPS',
        valorTexto: c.porTiempo ? '${c.reps} s' : '${c.reps}',
        descripcionAccesible:
            '${c.reps} ${c.porTiempo ? 'segundos' : 'repeticiones'}',
        etiquetaMenos: c.porTiempo ? 'Quitar segundos' : 'Quitar una repetición',
        etiquetaMas: c.porTiempo
            ? 'Agregar segundos'
            : 'Agregar una repetición',
        alMenos: c.reps > 0 ? c.menosReps : null,
        alMas: c.masReps,
      ),
      if (carga != null) ...[SizedBox(height: v.espacio * 1.5), carga],
    ];
    final hecha = BotonSerieHecha(
      alHecha: c.hecha,
      guardada: c.deshacerVisible,
      alDeshacer: c.deshacer,
      etiquetaAccesible:
          'Marcar la serie ${c.serie} de ${e.series} como hecha',
    );
    final temporizador = TemporizadorDescanso(
      descanso: c.descanso,
      escala: EscalaTemporizador.sesion,
      ahora: reloj,
      alMasQuince: c.masQuince,
      alMenosQuince: c.menosQuince,
      alSaltar: c.saltarDescanso,
    );
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            nombreDeEjercicio(catalogo, e.ejercicioId),
            style: v.titulo(tamano: 28),
          ),
        ),
        Text(
          nombreDeVariante(catalogo, e.varianteId),
          style: v.lectura(tamano: 16, color: v.textoTenue),
        ),
        if (e.conPrecaucion)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: MarcaGimnasio(
              texto: 'Con precaución',
              icono: Icons.warning_amber_outlined,
            ),
          ),
        if (e.topeDePila)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(MensajesGimnasio.topeDePila),
          ),
      ],
    );
    final acciones = Wrap(
      spacing: v.espacio,
      runSpacing: v.espacio,
      children: [
        if (!terminado)
          OutlinedButton(
            key: const ValueKey('cambiar-ejercicio'),
            onPressed: () => _cambiar(context),
            child: const Text(TextosHabitosGimnasio.cambiarEjercicio),
          ),
        if (!terminado && !c.versionCorta)
          OutlinedButton(
            key: const ValueKey('version-corta'),
            onPressed: c.acortar,
            child: const Text(TextosHabitosGimnasio.versionCorta),
          ),
        OutlinedButton(
          key: const ValueKey('terminar'),
          onPressed: alTerminar,
          child: const Text(TextosHabitosGimnasio.terminar),
        ),
      ],
    );
    final esfuerzo = c.esfuerzoPendiente == null
        ? const SizedBox.shrink()
        : _EsfuerzoEjercicio(
            nombre: nombreDeEjercicio(
              catalogo,
              c.ejercicios[c.esfuerzoPendiente!].ejercicioId,
            ),
            alElegir: c.esfuerzoDelEjercicio,
          );

    if (amplio && !terminado) {
      final fila = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titulo,
                esfuerzo,
                SizedBox(height: v.espacio * 2),
                panel,
                SizedBox(height: v.espacio * 2),
                acciones,
              ],
            ),
          ),
          SizedBox(width: v.espacio * 3),
          Expanded(
            child: GadgetSerieDescanso(
              ejercicio: nombreDeEjercicio(catalogo, e.ejercicioId),
              puestoTexto: nombreDeVariante(catalogo, e.varianteId),
              serieActual: c.serie,
              seriesTotales: e.series,
              repeticionesTexto: c.porTiempo
                  ? '${c.reps} s'
                  : '${c.reps} repeticiones',
              cargaTexto: c.cargaTexto,
              series: _series(),
              descanso: c.descanso,
              siguiente: sigue,
              escala: EscalaTemporizador.tablet,
              ahora: reloj,
              alMasQuince: c.masQuince,
              alMenosQuince: c.menosQuince,
              alSaltar: c.saltarDescanso,
            ),
          ),
        ],
      );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [...cabecera, fila, SizedBox(height: v.espacio * 2), pie],
      );
    }
    if (terminado) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...cabecera,
          titulo,
          esfuerzo,
          SizedBox(height: v.espacio * 2),
          panel,
          SizedBox(height: v.espacio * 2),
          acciones,
          SizedBox(height: v.espacio * 2),
          pie,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              ...cabecera,
              titulo,
              esfuerzo,
              SizedBox(height: v.espacio * 1.5),
              ...ajustes,
              SizedBox(height: v.espacio * 2),
              Wrap(
                spacing: v.espacio,
                runSpacing: v.espacio,
                children: [
                  for (final s in _series()) ChipSerie(serie: s, total: e.series),
                ],
              ),
              if (sigue != null) ...[
                SizedBox(height: v.espacio * 2),
                Text(
                  '${TextosGimnasio.siguiente}: $sigue',
                  style: v.lectura(tamano: 15, color: v.textoTenue),
                ),
              ],
              SizedBox(height: v.espacio * 2),
              pie,
            ],
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hecha,
                SizedBox(height: v.espacio),
                temporizador,
                SizedBox(height: v.espacio),
                acciones,
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _sigue() {
    final e = c.actual;
    if (c.fase == FaseSesion.fin) return null;
    if (c.serie < e.series) {
      return '${nombreDeEjercicio(catalogo, e.ejercicioId)}, serie ${c.serie + 1}';
    }
    final s = c.siguiente;
    return s == null ? null : nombreDeEjercicio(catalogo, s.ejercicioId);
  }

  Future<void> _cambiar(BuildContext context) async {
    final e = c.actual;
    if (e.alternativas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este ejercicio no tiene otra opción con tu equipo.'),
        ),
      );
      return;
    }
    final alt = await showModalBottomSheet<AlternativaSlot>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in e.alternativas)
              ListTile(
                key: ValueKey('alt-${a.varianteId}'),
                title: Text(nombreDeVariante(catalogo, a.varianteId)),
                subtitle: Text(_motivo(a.motivo)),
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
    );
    if (alt != null) await c.cambiarEjercicio(alt);
  }

  String _motivo(MotivoAlternativa m) => switch (m) {
    MotivoAlternativa.masFacil => 'Más fácil',
    MotivoAlternativa.masDificil => 'Más difícil',
    MotivoAlternativa.sinAparato => 'Sin aparato',
    MotivoAlternativa.conPrecaucion => 'Con precaución',
  };
}

class _Terminado extends StatelessWidget {
  const _Terminado({required this.alTerminar});
  final VoidCallback alTerminar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Hiciste todas las series de hoy.'),
      const SizedBox(height: 12),
      FilledButton(
        key: const ValueKey('terminar-final'),
        onPressed: alTerminar,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 64)),
        child: const Text(TextosHabitosGimnasio.terminar),
      ),
    ],
  );
}

class _EsfuerzoEjercicio extends StatelessWidget {
  const _EsfuerzoEjercicio({required this.nombre, required this.alElegir});

  final String nombre;
  final Future<void> Function(int?) alElegir;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('esfuerzo-ejercicio'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${TextosHabitosGimnasio.esfuerzoDelEjercicio}: $nombre'),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 1; i <= 5; i++)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => alElegir(i),
                  child: Text('$i'),
                ),
              TextButton(
                onPressed: () => alElegir(null),
                child: const Text(TextosHabitosGimnasio.omitir),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
