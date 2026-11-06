/// Piezas comunes de las pantallas de Finanzas: adaptadores entre el dominio
/// y los componentes de diseno, estados (cargando, sin conexión, error,
/// vacío), selector de libro, montos ocultables y diálogos.
///
/// El dominio se importa ocultando los nombres que también exporta diseno
/// (`Semaforo`, `formatearCentavos`, `TipoLibro`, `VisibilidadLibro`,
/// `puntosBaseEnCien`); donde
/// hace falta el del dominio se usa el prefijo `dom`.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide
        Semaforo,
        formatearCentavos,
        TipoLibro,
        VisibilidadLibro,
        puntosBaseEnCien;
import 'package:finanzas_dominio/finanzas_dominio.dart' as dom
    show Semaforo, TipoLibro, VisibilidadLibro;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../datos/repositorio.dart';
import '../estado/proveedores.dart';

// ------------------------------------------------------------------ fechas

DateTime aDateTime(Fecha f) => DateTime(f.anio, f.mes, f.dia);

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// `mar 20 oct`
String textoFecha(Fecha f) => fechaCorta(aDateTime(f));

/// `20 oct`
String textoDiaMes(Fecha f) => '${f.dia} ${_meses[f.mes - 1]}';

/// `Semana 44 · 26 oct – 1 nov`
String textoSemana(Semana s) =>
    'Semana ${s.numeroIso} · ${textoDiaMes(s.inicio)} – ${textoDiaMes(s.fin)}';

// ----------------------------------------------------------------- nombres

String nombreTipoCuenta(TipoCuenta t) => switch (t) {
  TipoCuenta.efectivo => 'Efectivo',
  TipoCuenta.banco => 'Banco',
  TipoCuenta.ahorro => 'Ahorro',
  TipoCuenta.inversion => 'Inversión',
  TipoCuenta.porCobrar => 'Por cobrar',
  TipoCuenta.tarjeta => 'Tarjeta de crédito',
  TipoCuenta.prestamo => 'Préstamo',
  TipoCuenta.origenIngreso => 'Origen de ingreso',
  TipoCuenta.deGasto => 'Cuenta de gasto',
  TipoCuenta.gastoFinanciero => 'Gasto financiero',
  TipoCuenta.porClasificar => 'Por clasificar',
  TipoCuenta.ajustes => 'Ajustes',
  TipoCuenta.apertura => 'Apertura',
  TipoCuenta.otroLibro => 'Otro libro',
};

String nombreTipoMovimiento(TipoMovimiento t) => switch (t) {
  TipoMovimiento.apertura => 'Saldo inicial',
  TipoMovimiento.ingreso => 'Ingreso',
  TipoMovimiento.gasto => 'Gasto',
  TipoMovimiento.reembolso => 'Reembolso',
  TipoMovimiento.transferencia => 'Transferencia',
  TipoMovimiento.pagoDeuda => 'Pago de deuda',
  TipoMovimiento.reclasificacion => 'Reclasificación',
  TipoMovimiento.ajuste => 'Ajuste',
  TipoMovimiento.anulacion => 'Anulación',
};

String nombreFrecuencia(Frecuencia f) => switch (f) {
  Frecuencia.semanal => 'Semanal',
  Frecuencia.catorcenal => 'Catorcenal',
  Frecuencia.quincenal => 'Quincenal',
  Frecuencia.mensual => 'Mensual',
  Frecuencia.bimestral => 'Bimestral',
  Frecuencia.trimestral => 'Trimestral',
  Frecuencia.semestral => 'Semestral',
  Frecuencia.anual => 'Anual',
  Frecuencia.diaria => 'Diaria',
};

const _diasSemana = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

String _dia(int d) => d == 0 ? 'último' : '$d';

/// "Quincenal (15 y último)", "Mensual (1 y 11)", "Cada 2 meses desde el
/// 1 sep 2026", con la regla de día inhábil. Con [salida] (compromisos y
/// deudas), sin regla elegida se queda en su fecha (regla 5 de 4.5).
String descripcionCalendario(CalendarioConfig c, {bool salida = false}) {
  final base = switch (c.forma) {
    FormaPago.semanal => 'Cada ${_diasSemana[(c.diaSemana ?? 1) - 1]}',
    FormaPago.catorcenal =>
      'Cada 14 días desde el ${c.fechaAncla == null ? '?' : textoDiaMes(c.fechaAncla!)}',
    FormaPago.quincenal =>
      'Quincenal (${(c.diasMes.isEmpty ? const [15, 0] : c.diasMes).map(_dia).join(' y ')})',
    FormaPago.mensual => c.diasMes.length > 1
        ? 'Días ${c.diasMes.map(_dia).join(' y ')} de cada mes'
        : 'Mensual (día ${c.diasMes.isEmpty ? '?' : _dia(c.diasMes.first)})',
    FormaPago.cadaMeses =>
      'Cada ${c.intervaloMeses ?? '?'} meses desde el '
          '${c.fechaAncla == null ? '?' : '${textoDiaMes(c.fechaAncla!)} ${c.fechaAncla!.anio}'}',
  };
  final regla = switch (c.reglaPara(
    salida ? CalendarioConfig.reglaDeSalida : CalendarioConfig.reglaDeIngreso,
  )) {
    ReglaDiaInhabil.siguienteDiaHabil => 'si es inhábil, el siguiente día hábil',
    ReglaDiaInhabil.diaHabilAnterior => 'si es inhábil, el día hábil anterior',
    ReglaDiaInhabil.sinCambio => 'en su fecha',
  };
  return '$base · $regla';
}

String nombreEstadoSemana(EstadoSemana e) => switch (e) {
  EstadoSemana.borrador => 'Sin activar',
  EstadoSemana.activa => 'Activa',
  EstadoSemana.pendienteIngreso => 'Pendiente de ingreso',
  EstadoSemana.porCerrar => 'Por cerrar',
  EstadoSemana.cerrada => 'Cerrada',
};

String nombrePrioridad(Prioridad p) => switch (p) {
  Prioridad.necesario => 'Necesario',
  Prioridad.deseable => 'Deseable',
  Prioridad.discrecional => 'Discrecional',
};

String nombreCerteza(Certeza c) => switch (c) {
  Certeza.segura => 'Segura',
  Certeza.probable => 'Probable',
  Certeza.incierta => 'Incierta (no cuenta)',
};

String nombreTipoDeuda(TipoDeuda t) => switch (t) {
  TipoDeuda.conCosto => 'Con costo',
  TipoDeuda.familiar => 'Préstamo familiar',
  TipoDeuda.msi => 'Meses sin intereses',
};

String nombreTipoLibro(dom.TipoLibro t) => switch (t) {
  dom.TipoLibro.personal => 'Personal',
  dom.TipoLibro.compartido => 'Compartido',
  dom.TipoLibro.representado => 'Representado',
};

// ----------------------------------------------------------- adaptadores

EstadoSemaforo estadoDe(dom.Semaforo s) => switch (s) {
  dom.Semaforo.verde => EstadoSemaforo.verde,
  dom.Semaforo.ambar => EstadoSemaforo.ambar,
  dom.Semaforo.rojo => EstadoSemaforo.rojo,
};

TonoEscalon tonoDe(dom.Semaforo s) => switch (s) {
  dom.Semaforo.verde => TonoEscalon.exito,
  dom.Semaforo.ambar => TonoEscalon.alerta,
  dom.Semaforo.rojo => TonoEscalon.peligro,
};

/// Opción del selector de libros (diseno) para [libro].
OpcionLibro opcionDe(Libro libro, PermisoLibro permiso, String personaId) {
  final tipo = switch (libro.tipo) {
    dom.TipoLibro.personal => TipoLibro.personal,
    dom.TipoLibro.compartido => TipoLibro.compartido,
    dom.TipoLibro.representado => TipoLibro.representado,
  };
  // Cómo lo ve la persona: la maestra y quien lee un público solo leen; un
  // archivado conserva su acceso (la marca "Archivado" ya dice que nadie
  // registra); si no puede escribir por otra razón (el suplente en espera),
  // solo lee.
  final acceso = permiso.comoMaestra
      ? AccesoLibro.soloLectura
      : permiso.comoLector
      ? AccesoLibro.lector
      : (!permiso.escribir && !libro.archivado)
      ? AccesoLibro.soloLectura
      : switch (libro.tipo) {
          dom.TipoLibro.personal => AccesoLibro.titular,
          dom.TipoLibro.compartido => AccesoLibro.miembro,
          dom.TipoLibro.representado => AccesoLibro.albacea,
        };
  return OpcionLibro(
    id: libro.id,
    nombre: libro.nombre,
    tipo: tipo,
    acceso: acceso,
    visibilidad: libro.visibilidad == dom.VisibilidadLibro.publica
        ? VisibilidadLibro.publica
        : VisibilidadLibro.privada,
    archivado: libro.archivado,
  );
}

/// La cascada planeado contra real (5.6 bis; 5.9 bis punto 2.1).
List<EscalonCascada> escalonesDe(VistaSemana v) {
  final p = v.planSemanal;
  final r = v.real;
  final presupuestoTono = r.sobregasto > 0
      ? TonoEscalon.alerta
      : TonoEscalon.neutro;
  return [
    EscalonCascada(
      etiqueta: 'Ingreso',
      planeadoCentavos: p.ingreso,
      realCentavos: r.ingresoReal,
      tono: r.ingresoReal < p.ingreso ? TonoEscalon.alerta : TonoEscalon.neutro,
    ),
    EscalonCascada(
      etiqueta: '− Presupuesto',
      planeadoCentavos: p.presupuesto,
      realCentavos: r.gastoReal,
      tono: presupuestoTono,
    ),
    EscalonCascada(
      etiqueta: '− Deuda',
      planeadoCentavos: p.deudaPlaneada,
      realCentavos: r.abonoReal,
      tono: r.abonosBajoMinimo.isNotEmpty
          ? TonoEscalon.peligro
          : (r.abonoDiferido > 0 ? TonoEscalon.alerta : TonoEscalon.neutro),
    ),
    EscalonCascada(
      etiqueta: '= Remanente',
      planeadoCentavos: p.remanente,
      realCentavos: r.deficit > 0 ? -r.deficit : r.remanenteReal,
      tono: tonoDe(v.indicadores.remanente),
    ),
  ];
}

/// Efecto de un movimiento en el patrimonio del libro de [vista]: positivo
/// si entra, negativo si sale, cero si solo se mueve dentro del libro.
int efectoEnLibro(Movimiento m, LibroMovimientos vista) {
  int signo(String cuentaId) {
    final c = vista.cuenta(cuentaId);
    return switch (c.clase) {
      ClaseCuenta.activo => 1,
      ClaseCuenta.pasivo => -1,
      _ => 0,
    };
  }

  return m.monto * (signo(m.cuentaDestinoId) - signo(m.cuentaOrigenId));
}

/// Texto de un movimiento para listas: categoría, nota o tipo.
String conceptoDe(Movimiento m, DatosFinanzas d, LibroMovimientos vista) {
  if (m.tipo == TipoMovimiento.anulacion) {
    return 'Anulación · ${m.motivo ?? ''}';
  }
  final categoria = m.categoriaId == null ? null : d.arbol.ruta(m.categoriaId!);
  final destino = vista.cuenta(m.cuentaDestinoId);
  final origen = vista.cuenta(m.cuentaOrigenId);
  final base = switch (m.tipo) {
    TipoMovimiento.gasto =>
      (categoria?.isNotEmpty ?? false) ? categoria! : destino.nombre,
    TipoMovimiento.ingreso => origen.nombre,
    TipoMovimiento.transferencia =>
      esCuentaDeOtroLibro(destino.id)
          ? 'Aportación a ${destino.nombre}'
          : esCuentaDeOtroLibro(origen.id)
          ? 'Aportación de ${origen.nombre}'
          : '${origen.nombre} → ${destino.nombre}',
    TipoMovimiento.pagoDeuda => 'Pago a ${destino.nombre}',
    _ => nombreTipoMovimiento(m.tipo),
  };
  return m.nota == null ? base : '$base · ${m.nota}';
}

// ------------------------------------------------------------------ montos

/// Monto en pesos que respeta el modo privado y "Mostrar/Ocultar".
class Monto extends ConsumerWidget {
  const Monto(this.centavos, {super.key, this.estilo, this.signo = false});

  final int centavos;
  final TextStyle? estilo;
  final bool signo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MontoOcultable(
    centavos: centavos,
    oculto: ref.watch(montosOcultosProvider),
    estilo: estilo,
    mostrarSigno: signo,
  );
}

/// "Etiqueta: $monto" que pasa a otra línea si no cabe (con letra grande o en
/// una ventana angosta un `Row` rígido se desbordaba: M7 de la revisión de la
/// Fase 1).
class DatoConMonto extends StatelessWidget {
  const DatoConMonto(this.etiqueta, this.centavos, {super.key, this.signo = false});

  final String etiqueta;
  final int centavos;
  final bool signo;

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [Text('$etiqueta: '), Monto(centavos, signo: signo)],
  );
}

/// Botón "Mostrar / Ocultar montos" (los montos se abren ocultos).
class BotonMontos extends ConsumerWidget {
  const BotonMontos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocultos = ref.watch(montosOcultosProvider);
    final privado = ref.watch(modoPrivadoProvider);
    return IconButton(
      key: const ValueKey('finanzas-mostrar-montos'),
      tooltip: privado
          ? 'Modo privado: montos ocultos'
          : (ocultos ? 'Mostrar montos' : 'Ocultar montos'),
      // Mostrar pide el PIN o la huella (plataforma); Ocultar es inmediato.
      onPressed: privado
          ? null
          : ocultos
          ? () => ref.read(revelarMontosProvider)(context)
          : () => ref.read(montosVisiblesProvider.notifier).alternar(),
      icon: Icon(ocultos ? Icons.visibility_outlined : Icons.visibility_off_outlined),
    );
  }
}

/// Texto con `{monto}` ya formateado (u oculto).
String textoConMonto(AccionSugerida a, bool oculto) =>
    a.texto((c) => oculto ? montoOculto : formatearCentavos(c));

// ----------------------------------------------------------------- estados

/// Pantalla de Finanzas con sus estados: cargando, sin conexión, error, sin
/// libros, la **portada** de la cuenta maestra (sus libros, sin consulta
/// registrada) y, para ella en un libro ajeno, el registro de la consulta en la
/// bitácora **antes** de pedir y mostrar sus datos (D19, I2).
class ConDatosFinanzas extends ConsumerWidget {
  const ConDatosFinanzas({super.key, required this.builder});

  final Widget Function(BuildContext context, ContextoFinanzas contexto)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asincrono = ref.watch(contextoFinanzasProvider);
    return asincrono.when(
      // Una recarga (renovar la consulta, escribir) no tapa la pantalla.
      skipLoadingOnReload: true,
      loading: () => const _Cargando(),
      error: (error, _) => _Error(error: error),
      data: (c) {
        final libro = c.libro;
        if (libro == null) {
          if (c.enPortada) return PortadaMaestra(contexto: c);
          return const EstadoVacio(
            icono: Icons.account_balance_wallet_outlined,
            mensaje: 'Aún no tienes un libro de Finanzas.',
            detalle:
                'Cada adulto con Finanzas tiene su libro; pide al Dueño que '
                'te agregue a los compartidos.',
          );
        }
        if (c.puedeEscribir &&
            !ref.read(cierresRevisadosProvider).contains(libro.id)) {
          // Fuera de la construcción: puede guardar cierres.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(cierresRevisadosProvider.notifier).revisar(libro.id);
            }
          });
        }
        Widget contenido = c.requiereConsulta
            ? _ConConsultaMaestra(contexto: c, builder: builder)
            : builder(context, c);
        if (!c.carga.desdeCopia) return contenido;
        return Column(
          children: [
            MaterialBanner(
              key: const ValueKey('finanzas-sin-conexion'),
              leading: const Icon(Icons.cloud_off_outlined),
              content: const Text(
                'Sin conexión: ves lo último que se cargó. Lo que registres '
                'se sube al volver la señal.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(cargaFinanzasProvider.notifier).recargar(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
            Expanded(child: contenido),
          ],
        );
      },
    );
  }
}

/// Muestra el libro ajeno a la cuenta maestra solo cuando su consulta está
/// registrada y los datos ya se pidieron con ella ([consultaMaestraProvider]).
/// Si el servidor devuelve vacío un libro ya consultado, la consulta venció
/// (filtra sin dar error): se renueva y se recarga sola.
class _ConConsultaMaestra extends ConsumerWidget {
  const _ConConsultaMaestra({required this.contexto, required this.builder});

  final ContextoFinanzas contexto;
  final Widget Function(BuildContext context, ContextoFinanzas contexto)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = contexto;
    final libroId = c.libroId;
    final consulta = ref.watch(consultaMaestraProvider(libroId));
    final listaYVacia =
        consulta.hasValue &&
        !consulta.isLoading &&
        !consulta.hasError &&
        c.carga.libroSinContenido(libroId);
    if (listaYVacia) {
      // Vacío después de una consulta buena: venció. Se registra otra vez.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ref.invalidate(consultaMaestraProvider(libroId));
      });
    }
    return consulta.when(
      // La renovación (cada 25 min) no tapa la pantalla con "Cargando".
      skipLoadingOnReload: true,
      data: (_) => listaYVacia ? _CargandoConsulta(contexto: c) : builder(context, c),
      loading: () => _CargandoConsulta(contexto: c),
      error: (e, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SelectorLibroFinanzas(contexto: c),
          ),
          Expanded(
            child: EstadoVacio(
              key: const ValueKey('finanzas-consulta-error'),
              icono: Icons.lock_outline,
              mensaje: 'No se pudo registrar la consulta de este libro.',
              detalle:
                  'La cuenta maestra abre un libro ajeno solo si la consulta '
                  'queda registrada en la bitácora. $e',
              textoAccion: 'Reintentar',
              alAccionar: () => ref.invalidate(consultaMaestraProvider(libroId)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CargandoConsulta extends StatelessWidget {
  const _CargandoConsulta({required this.contexto});

  final ContextoFinanzas contexto;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('finanzas-consultando'),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SelectorLibroFinanzas(contexto: contexto),
      ),
      const Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Registrando la consulta…'),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Portada de la cuenta maestra: los libros del hogar y quién los lleva, sin
/// leer su contenido. Abrir uno **registra la consulta** en la bitácora (la
/// ven quienes lo llevan).
class PortadaMaestra extends ConsumerWidget {
  const PortadaMaestra({super.key, required this.contexto});

  final ContextoFinanzas contexto;

  String _quienes(Libro l) {
    final c = contexto.carga;
    final vigentes = l.vigentes(contexto.hoy);
    final nombres = [
      for (final m in vigentes)
        if (m.papel != PapelLibro.albaceaSuplente) c.nombreDe(m.personaId),
    ];
    return switch (l.tipo) {
      dom.TipoLibro.personal => 'De ${c.nombreDe(l.titularId)}',
      dom.TipoLibro.representado =>
        'En nombre de ${c.nombreDe(l.titularId)}'
            '${nombres.isEmpty ? '' : ' · lo lleva ${nombres.join(', ')}'}',
      dom.TipoLibro.compartido => 'Miembros: ${nombres.join(', ')}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    return ListView(
      key: const ValueKey('finanzas-portada'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Libros del hogar', style: tema.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Cuenta maestra: solo lectura. Al abrir un libro, la consulta queda '
          'registrada en la bitácora y la ven quienes lo llevan.',
          style: tema.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final l in contexto.libros)
          Card(
            key: ValueKey('finanzas-portada-libro-${l.id}'),
            child: ListTile(
              minVerticalPadding: 12,
              leading: Icon(switch (l.tipo) {
                dom.TipoLibro.personal => Icons.person_outline,
                dom.TipoLibro.compartido => Icons.group_outlined,
                dom.TipoLibro.representado => Icons.volunteer_activism_outlined,
              }),
              title: Text(l.nombre),
              subtitle: Text(
                [
                  _quienes(l),
                  if (l.tipo == dom.TipoLibro.compartido)
                    l.visibilidad == dom.VisibilidadLibro.publica
                        ? 'Pública'
                        : 'Privada',
                  if (l.archivado) 'Archivado',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ref.read(libroElegidoProvider.notifier).elegir(l.id),
            ),
          ),
      ],
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('Cargando Finanzas…'),
      ],
    ),
  );
}

class _Error extends ConsumerWidget {
  const _Error({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinConexion = error is ErrorFinanzas && (error as ErrorFinanzas).sinConexion;
    return EstadoVacio(
      key: ValueKey(sinConexion ? 'finanzas-sin-conexion' : 'finanzas-error'),
      icono: sinConexion ? Icons.cloud_off_outlined : Icons.error_outline,
      mensaje: sinConexion
          ? 'Sin conexión y sin datos guardados en este equipo.'
          : 'No se pudo cargar Finanzas.',
      detalle: sinConexion
          ? 'Conéctate una vez para traer tus cuentas y categorías.'
          : '$error',
      textoAccion: 'Reintentar',
      alAccionar: () => ref.read(cargaFinanzasProvider.notifier).recargar(),
    );
  }
}

/// Selector del libro activo ("Mi libro", compartidos, el de papá).
class SelectorLibroFinanzas extends ConsumerWidget {
  const SelectorLibroFinanzas({super.key, required this.contexto, this.comoMenu});

  final ContextoFinanzas contexto;
  final bool? comoMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La cuenta maestra que no tiene libro propio entra por la portada y
    // puede volver a ella.
    final conPortada = contexto.esMaestra && !contexto.tienePropioLibro;
    if (contexto.libros.length < 2 && !conPortada) {
      return const SizedBox.shrink();
    }
    final selector = contexto.libros.length < 2
        ? const SizedBox.shrink()
        : SelectorLibro(
            key: const ValueKey('finanzas-selector-libro'),
            libros: [
              for (final l in contexto.libros)
                opcionDe(l, contexto.permisoEn(l), contexto.personaId),
            ],
            libroActualId: contexto.libroId,
            alCambiar: (id) => ref.read(libroElegidoProvider.notifier).elegir(id),
            comoMenu: comoMenu,
          );
    if (!conPortada) return selector;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        selector,
        TextButton.icon(
          key: const ValueKey('finanzas-todos-los-libros'),
          onPressed: () => ref.read(libroElegidoProvider.notifier).alaPortada(),
          icon: const Icon(Icons.library_books_outlined),
          label: const Text('Todos los libros'),
        ),
      ],
    );
  }
}

/// Marca del libro activo ("Solo lectura", "En nombre de…").
Widget marcaDe(ContextoFinanzas c) => MarcaLibro(
  libro: opcionDe(c.libro!, c.permiso, c.personaId),
);

// ----------------------------------------------------------------- diálogos

void avisar(BuildContext context, String mensaje) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(mensaje)),
    );

void avisarError(BuildContext context, Object error) => avisar(
  context,
  error is ErrorFinanzas ? error.mensaje : 'No se pudo: $error',
);

/// Ejecuta [accion] y avisa del error (sin lanzar).
Future<bool> intentar(BuildContext context, Future<void> Function() accion) async {
  try {
    await accion();
    return true;
  } catch (e) {
    if (context.mounted) avisarError(context, e);
    return false;
  }
}

/// Pide un texto (motivo, nombre). Devuelve `null` si se cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String? ayuda,
  String textoAccion = 'Aceptar',
  String inicial = '',
  bool obligatorio = true,
  int minimoVisibles = 0,
}) => showDialog<String>(
  context: context,
  builder: (_) => _DialogoTexto(
    titulo: titulo,
    etiqueta: etiqueta,
    ayuda: ayuda,
    textoAccion: textoAccion,
    inicial: inicial,
    obligatorio: obligatorio,
    minimoVisibles: minimoVisibles,
  ),
);

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.etiqueta,
    required this.ayuda,
    required this.textoAccion,
    required this.inicial,
    required this.obligatorio,
    required this.minimoVisibles,
  });

  final String titulo;
  final String etiqueta;
  final String? ayuda;
  final String textoAccion;
  final String inicial;
  final bool obligatorio;

  /// Caracteres visibles que debe tener lo escrito (0: basta con no estar en
  /// blanco). Los motivos piden 3 (`motivoValido`).
  final int minimoVisibles;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  late final _control = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  bool get _valido {
    if (!widget.obligatorio) return true;
    final minimo = widget.minimoVisibles > 0 ? widget.minimoVisibles : 1;
    return caracteresVisibles(_control.text) >= minimo;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    content: TextField(
      key: const ValueKey('finanzas-dialogo-texto'),
      controller: _control,
      autofocus: true,
      maxLength: 200,
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        helperText: widget.ayuda,
        helperMaxLines: 3,
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) {
        if (_valido) Navigator.pop(context, _control.text.trim());
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _valido ? () => Navigator.pop(context, _control.text.trim()) : null,
        child: Text(widget.textoAccion),
      ),
    ],
  );
}

/// Pide confirmación. `true` si se acepta.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoAccion = 'Confirmar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: Text(textoAccion),
          ),
        ],
      ),
    ) ??
    false;

// ------------------------------------------------------- campos de captura

/// Lee pesos escritos por la persona en centavos. `null` si no es un monto.
///
/// Acepta ("1,234.50", "$85", "85.5", "12,5", "1.234,50"):
/// - El **punto** es el separador decimal en "85.5"; con coma y punto juntos,
///   el último de los dos es el decimal y el otro separa miles ("1,234.50" y
///   "1.234,50").
/// - La **coma sola** es decimal si la siguen 1 o 2 dígitos ("12,5" = $12.50,
///   "85,50" = $85.50) y separa miles si la siguen grupos de 3 ("1,234" =
///   $1,234.00). Cualquier otra cosa ("1,2345") no es un monto: mejor
///   preguntar que errar por diez veces sin avisar (M2 de la revisión de la
///   Fase 1).
int? centavosDeTexto(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s$]'), '');
  if (limpio.isEmpty) return null;
  final coma = limpio.lastIndexOf(',');
  final punto = limpio.lastIndexOf('.');

  String enteros;
  String decimales = '';
  String? miles;
  if (coma >= 0 && punto >= 0) {
    // Los dos: el último es el decimal, el otro separa miles.
    final decimal = coma > punto ? ',' : '.';
    miles = decimal == ',' ? '.' : ',';
    final i = limpio.lastIndexOf(decimal);
    enteros = limpio.substring(0, i);
    decimales = limpio.substring(i + 1);
    if (enteros.contains(decimal) || decimales.contains(miles)) return null;
  } else if (coma >= 0) {
    final despues = limpio.substring(coma + 1);
    final comas = ','.allMatches(limpio).length;
    if (comas == 1 && despues.length <= 2) {
      enteros = limpio.substring(0, coma);
      decimales = despues;
    } else {
      // Solo miles: "1,234" o "12,345,678".
      miles = ',';
      enteros = limpio;
    }
  } else if (punto >= 0) {
    if ('.'.allMatches(limpio).length != 1) return null;
    enteros = limpio.substring(0, punto);
    decimales = limpio.substring(punto + 1);
  } else {
    enteros = limpio;
  }

  if (miles != null && enteros.contains(miles)) {
    final separador = RegExp.escape(miles);
    if (!RegExp('^\\d{1,3}($separador\\d{3})+\$').hasMatch(enteros)) {
      return null;
    }
    enteros = enteros.replaceAll(miles, '');
  }
  // ".5" es $0.50: sin enteros, pero con decimales.
  if (enteros.isEmpty && decimales.isNotEmpty) enteros = '0';
  if (!RegExp(r'^\d{1,9}$').hasMatch(enteros) ||
      !RegExp(r'^\d{0,2}$').hasMatch(decimales)) {
    return null;
  }
  return int.parse(enteros) * 100 + int.parse(decimales.padRight(2, '0'));
}

/// Pesos en texto para editar: 123450 → "1234.50".
String textoDeCentavos(int centavos) =>
    '${centavos ~/ 100}.${(centavos % 100).toString().padLeft(2, '0')}';

/// Campo de monto en pesos (laptop).
class CampoMonto extends StatelessWidget {
  const CampoMonto({
    super.key,
    required this.controlador,
    required this.etiqueta,
    this.obligatorio = true,
    this.ayuda,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final bool obligatorio;
  final String? ayuda;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controlador,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,$ ]'))],
    decoration: InputDecoration(
      labelText: etiqueta,
      prefixText: r'$ ',
      helperText: ayuda,
    ),
    validator: (v) {
      if ((v ?? '').trim().isEmpty) return obligatorio ? 'Escribe el monto' : null;
      return centavosDeTexto(v!) == null ? 'Monto no válido' : null;
    },
  );
}

/// Campo de porcentaje que guarda puntos base ("20" → 2000).
class CampoPorcentaje extends StatelessWidget {
  const CampoPorcentaje({
    super.key,
    required this.controlador,
    required this.etiqueta,
  });

  final TextEditingController controlador;
  final String etiqueta;

  static int? puntosBase(String texto) {
    final c = centavosDeTexto(texto.replaceAll('%', ''));
    return c;
  }

  static String texto(int puntosBase) =>
      puntosBase % 100 == 0 ? '${puntosBase ~/ 100}' : textoDeCentavos(puntosBase);

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controlador,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: etiqueta, suffixText: '%'),
    validator: (v) {
      final pb = puntosBase(v ?? '');
      if (pb == null || pb > 10000) return 'De 0 a 100';
      return null;
    },
  );
}

/// Elige una fecha (por omisión, hoy).
Future<Fecha?> elegirFecha(BuildContext context, Fecha inicial) async {
  final r = await showDatePicker(
    context: context,
    initialDate: aDateTime(inicial),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  return r == null ? null : Fecha.deDateTime(r);
}
