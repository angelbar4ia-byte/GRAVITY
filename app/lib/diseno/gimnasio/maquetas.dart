/// Maquetas E1 a E10 de «Mi gimnasio» (7.1): cada pantalla armada **solo con
/// los componentes de diseño** y datos de ejemplo inventados. G5 las usa como
/// guía de composición y las pruebas las miden (estilos, claro y oscuro, letra
/// al doble, 48 dp). No hay lógica: los toques no hacen nada, salvo el
/// temporizador de la sesión en curso, que sí cuenta y se puede ajustar.
///
/// La sesión en curso y el registro rápido (E5 y E6) usan la personalidad
/// **Sport**; las demás, la calma de Hábitos (H-18).
library;

import 'package:flutter/material.dart';

import '../componentes/indicador_conexion.dart';
import '../componentes/tarjeta_modulo.dart';
import '../personalidad_modulo.dart';
import '../tema_modulo.dart';
import '../../nucleo/contratos/roles.dart';
import '../valores_diseno.dart';
import 'avisos_gimnasio.dart';
import 'historial.dart';
import 'linea_semana.dart';
import 'selectores.dart';
import 'serie_descanso.dart';
import 'sesion_hoy.dart';
import 'tarjeta_aparato.dart';
import 'temporizador_descanso.dart';
import 'tipos_gimnasio.dart';

/// Las diez pantallas de la sección 7.1.
enum PantallaMaqueta {
  e1Hoy('E1 · Hoy', false),
  e2Inventario('E2 · Inventario', false),
  e3Plan('E3 · Plan de la semana', false),
  e4SesionDeHoy('E4 · Sesión de hoy', false),
  e5SesionEnCurso('E5 · Sesión en curso', true),
  e6RegistroRapido('E6 · Registro rápido', true),
  e7Historial('E7 · Historial', false),
  e8Records('E8 · Récords', false),
  e9Molestias('E9 · Molestias', false),
  e10Ajustes('E10 · Ajustes', false);

  const PantallaMaqueta(this.titulo, this.sport);

  final String titulo;

  /// Usa la personalidad Sport (pantallas en movimiento).
  final bool sport;
}

/// Una pantalla de maqueta con su personalidad y datos de ejemplo.
class MaquetaGimnasio extends StatelessWidget {
  const MaquetaGimnasio({
    super.key,
    required this.pantalla,
    this.ahora,
    this.vibrar,
  });

  final PantallaMaqueta pantalla;

  /// Reloj inyectable (pruebas).
  final DateTime Function()? ahora;
  final Future<void> Function()? vibrar;

  @override
  Widget build(BuildContext context) {
    final cuerpo = switch (pantalla) {
      PantallaMaqueta.e1Hoy => const _E1Hoy(),
      PantallaMaqueta.e2Inventario => const _E2Inventario(),
      PantallaMaqueta.e3Plan => const _E3Plan(),
      PantallaMaqueta.e4SesionDeHoy => const _E4Sesion(),
      PantallaMaqueta.e5SesionEnCurso => _E5EnCurso(ahora: ahora, vibrar: vibrar),
      PantallaMaqueta.e6RegistroRapido => const _E6Registro(),
      PantallaMaqueta.e7Historial => const _E7Historial(),
      PantallaMaqueta.e8Records => const _E8Records(),
      PantallaMaqueta.e9Molestias => const _E9Molestias(),
      PantallaMaqueta.e10Ajustes => const _E10Ajustes(),
    };
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: pantalla.sport ? Submodulo.entrenamiento : null,
      child: Builder(
        builder: (context) {
          final v = ValoresDiseno.de(context);
          return ColoredBox(
            color: v.fondo,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        pantalla.titulo,
                        style: v.titulo(tamano: 22),
                      ),
                    ),
                    SizedBox(height: v.espacio * 2),
                    cuerpo,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Datos de ejemplo (inventados) -------------------------------------------

const _semana3 = [
  DiaSemanaVista(
    nombre: 'lunes',
    letra: 'L',
    tipo: TipoDiaPlan.fuerzaA,
    estado: EstadoDiaPlan.hecho,
    detalleTexto: 'estándar · 19:15',
  ),
  DiaSemanaVista(nombre: 'martes', letra: 'M', tipo: TipoDiaPlan.descanso),
  DiaSemanaVista(
    nombre: 'miércoles',
    letra: 'X',
    tipo: TipoDiaPlan.fuerzaB,
    esHoy: true,
    detalleTexto: 'estándar · 19:15',
  ),
  DiaSemanaVista(nombre: 'jueves', letra: 'J', tipo: TipoDiaPlan.descanso),
  DiaSemanaVista(
    nombre: 'viernes',
    letra: 'V',
    tipo: TipoDiaPlan.fuerzaC,
    detalleTexto: 'corta · 19:15',
    conAviso: true,
  ),
  DiaSemanaVista(
    nombre: 'sábado',
    letra: 'S',
    tipo: TipoDiaPlan.bicicleta,
    detalleTexto: '8:00',
    conAviso: true,
  ),
  DiaSemanaVista(nombre: 'domingo', letra: 'D', tipo: TipoDiaPlan.descanso),
];

const _avisosSemana = [
  'Fuerza C y la bicicleta del sábado comparten piernas con solo 12 horas '
      'de descanso. Puedes mover C al jueves o hacerla corta.',
];

class _E1Hoy extends StatelessWidget {
  const _E1Hoy();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TarjetaEntrenamientoHoy(
        plantillaTexto: 'Fuerza B · Tirón',
        versionTexto: 'estándar',
        horaTexto: '19:15',
        duracionTexto: '≈ 36 min',
        contenidoEnRevision: true,
        alEmpezar: () {},
        alHecho: () {},
        alAbrir: () {},
      ),
      const SizedBox(height: 12),
      LineaSemana(dias: _semana3, alTocarDia: (_) {}),
    ],
  );
}

class _E2Inventario extends StatelessWidget {
  const _E2Inventario();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TarjetaAparato(
        nombre: 'Estación multifuncional Marcy MWM-7119',
        detalle: 'Pila, poleas alta y baja, brazos de press y cojín de curl.',
        puestos: [
          PuestoVista(nombre: 'Brazos de press', alCambiar: () {}),
          PuestoVista(nombre: 'Polea alta', alCambiar: () {}),
          PuestoVista(nombre: 'Polea baja', alCambiar: () {}),
          PuestoVista(
            nombre: 'Cojín de curl',
            disponibilidad: DisponibilidadAparato.noDisponible,
            alCambiar: () {},
          ),
        ],
        datos: const [
          DatoAparatoVista(
            etiqueta: 'Peso de la pila',
            valorTexto: '68 kg aprox.',
            confirmacion: EstadoConfirmacionDato.delDiseno,
          ),
          DatoAparatoVista(etiqueta: 'Placas de la pila'),
          DatoAparatoVista(etiqueta: 'Kilos por placa'),
        ],
        alConfirmar: () {},
        alCambiarDisponibilidad: () {},
      ),
      const SizedBox(height: 12),
      TarjetaAparato(
        nombre: 'Banco inclinado',
        icono: Icons.event_seat_outlined,
        alCambiarDisponibilidad: () {},
      ),
      const SizedBox(height: 12),
      TarjetaAparato(
        nombre: 'Bandas de resistencia',
        icono: Icons.linear_scale,
        detalle: '3 bandas activas, de la más ligera a la más fuerte.',
        alCambiarDisponibilidad: () {},
      ),
      const SizedBox(height: 12),
      const TarjetaAparato(
        nombre: 'Mancuernas',
        icono: Icons.fitness_center,
        disponibilidad: DisponibilidadAparato.futuro,
      ),
    ],
  );
}

class _E3Plan extends StatelessWidget {
  const _E3Plan();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LineaSemana(
        titulo: 'Plan de 3 días',
        dias: _semana3,
        avisos: _avisosSemana,
        alTocarDia: (_) {},
      ),
      const SizedBox(height: 12),
      const TarjetaContenidoEnRevision(),
    ],
  );
}

class _E4Sesion extends StatelessWidget {
  const _E4Sesion();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const TarjetaContenidoEnRevision(compacta: true),
      const SizedBox(height: 12),
      FilaEjercicioPlan(
        numero: 1,
        total: 4,
        datos: const EjercicioPlanVista(
          ejercicio: 'Jalón al pecho',
          varianteTexto: 'Polea alta',
          seriesTexto: '3 × 10–12',
          cargaTexto: 'Placa 4',
        ),
        alCambiar: () {},
      ),
      const SizedBox(height: 8),
      FilaEjercicioPlan(
        numero: 2,
        total: 4,
        datos: const EjercicioPlanVista(
          ejercicio: 'Remo sentado',
          varianteTexto: 'Con banda pisada',
          seriesTexto: '3 × 10–12',
          cargaTexto: 'Banda verde',
          cambioTexto: 'Sin aparato',
        ),
        alCambiar: () {},
      ),
      const SizedBox(height: 8),
      FilaEjercicioPlan(
        numero: 3,
        total: 4,
        datos: const EjercicioPlanVista(
          ejercicio: 'Face pull',
          varianteTexto: 'Polea alta',
          seriesTexto: '3 × 12–15',
          conPrecaucion: true,
        ),
        alCambiar: () {},
      ),
      const SizedBox(height: 8),
      FilaEjercicioPlan(
        numero: 4,
        total: 4,
        datos: const EjercicioPlanVista(
          ejercicio: 'Curl de bíceps',
          varianteTexto: 'Cojín de curl',
          seriesTexto: '3 × 10–12',
          cargaTexto: 'Placa 2',
        ),
        alCambiar: () {},
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () {},
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Empezar'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () {}, child: const Text('Versión corta')),
    ],
  );
}

class _E5EnCurso extends StatefulWidget {
  const _E5EnCurso({this.ahora, this.vibrar});

  final DateTime Function()? ahora;
  final Future<void> Function()? vibrar;

  @override
  State<_E5EnCurso> createState() => _E5EnCursoState();
}

class _E5EnCursoState extends State<_E5EnCurso> {
  late DateTime Function() _ahora;
  late DescansoPlanificado _descanso;
  int _reps = 12;
  int _placa = 3;

  @override
  void initState() {
    super.initState();
    _ahora = widget.ahora ?? DateTime.now;
    _descanso = DescansoPlanificado.iniciar(_ahora(), const Duration(seconds: 48));
  }

  void _ajustar(Duration d) =>
      setState(() => _descanso = _descanso.ajustar(d, _ahora()));

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fuerza A · Empuje · estándar',
          style: v.lectura(tamano: 15, color: v.textoTenue),
        ),
        Text(
          '≈ 36 min · ejercicio 2 de 4',
          style: v.numero(tamano: 14, color: v.textoTenue),
        ),
        SizedBox(height: e * 2),
        Semantics(
          header: true,
          child: Text('Elevaciones laterales', style: v.titulo(tamano: 28)),
        ),
        Text('Polea baja', style: v.lectura(tamano: 16, color: v.textoTenue)),
        SizedBox(height: e * 2),
        PanelRegistroSerie(
          serieActual: 2,
          seriesTotales: 3,
          repeticionesTexto: '$_reps',
          alMenosReps: _reps > 1 ? () => setState(() => _reps--) : null,
          alMasReps: () => setState(() => _reps++),
          carga: SelectorCarga(
            valorTexto: 'Placa $_placa',
            confirmacion: EstadoConfirmacionDato.confirmar,
            alMenos: _placa > 1 ? () => setState(() => _placa--) : null,
            alMas: () => setState(() => _placa++),
            alConfirmar: () {},
          ),
          alHecha: () {},
        ),
        SizedBox(height: e * 3),
        TemporizadorDescanso(
          descanso: _descanso,
          ahora: _ahora,
          vibrar: widget.vibrar ?? vibracionFinDescanso,
          alMasQuince: () => _ajustar(const Duration(seconds: 15)),
          alMenosQuince: () => _ajustar(const Duration(seconds: -15)),
          alSaltar: () => setState(() => _descanso = _descanso.saltar(_ahora())),
        ),
        SizedBox(height: e * 2),
        Text(
          'Sigue: tríceps en polea alta',
          style: v.lectura(tamano: 15, color: v.textoTenue),
        ),
        SizedBox(height: e * 2),
        Wrap(
          spacing: e,
          runSpacing: e,
          children: [
            OutlinedButton(onPressed: () {}, child: const Text('Cambiar ejercicio')),
            OutlinedButton(onPressed: () {}, child: const Text('Versión corta')),
            OutlinedButton(onPressed: () {}, child: const Text('Terminar')),
          ],
        ),
        SizedBox(height: e * 2),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: IndicadorConexion(estado: EstadoConexion.sinConexion, pendientes: 2),
        ),
        SizedBox(height: e),
        Text(
          'Guardado en el teléfono; se sube al volver la señal.',
          style: v.lectura(tamano: 13, color: v.textoTenue),
        ),
      ],
    );
  }
}

class _E6Registro extends StatelessWidget {
  const _E6Registro();

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fuerza A · Empuje · estándar · ayer',
          style: v.lectura(tamano: 15, color: v.textoTenue),
        ),
        SizedBox(height: e * 2),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
          icon: const Icon(Icons.done_all, size: 26),
          label: const Text('Todo como estaba planeado'),
        ),
        SizedBox(height: e * 2),
        const _FilasRegistro(),
        SizedBox(height: e * 2),
        TarjetaModulo(
          titulo: 'Esfuerzo de la sesión',
          icono: Icons.speed,
          child: SelectorPasos(
            etiqueta: 'ESFUERZO',
            valorTexto: '3 de 5',
            descripcionAccesible: 'Esfuerzo de la sesión: 3 de 5, moderado',
            etiquetaMenos: 'Bajar el esfuerzo',
            etiquetaMas: 'Subir el esfuerzo',
            alMenos: () {},
            alMas: () {},
          ),
        ),
        SizedBox(height: e * 2),
        FilledButton(onPressed: () {}, child: const Text('Guardar')),
      ],
    );
  }
}

/// Dos filas de ejercicio ya hechas para el registro de E6.
class _FilasRegistro extends StatelessWidget {
  const _FilasRegistro();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilaEjercicioPlan(
        numero: 1,
        total: 2,
        datos: const EjercicioPlanVista(
          ejercicio: 'Press de pecho',
          varianteTexto: 'En la estación',
          seriesTexto: '3 × 10–12',
          cargaTexto: 'Placa 5',
        ),
        alCambiar: () {},
      ),
      const SizedBox(height: 8),
      FilaEjercicioPlan(
        numero: 2,
        total: 2,
        datos: const EjercicioPlanVista(
          ejercicio: 'Fondos en banco',
          seriesTexto: '3 × 8–12',
          cargaTexto: 'Peso corporal',
        ),
        alCambiar: () {},
      ),
    ],
  );
}

class _E7Historial extends StatelessWidget {
  const _E7Historial();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const BarrasHistorial(
        titulo: 'Press de pecho',
        subtitulo: 'Carga por semana',
        barras: [
          BarraHistorialVista(
            etiqueta: 'Semana del 9 nov',
            valor: 3,
            valorTexto: 'Placa 3',
          ),
          BarraHistorialVista(
            etiqueta: 'Semana del 16 nov',
            valor: 4,
            valorTexto: 'Placa 4',
          ),
          BarraHistorialVista(
            etiqueta: 'Semana del 23 nov',
            valor: 5,
            valorTexto: 'Placa 5',
            esRecord: true,
          ),
          BarraHistorialVista(
            etiqueta: 'Semana del 30 nov',
            valor: 4,
            valorTexto: 'Placa 4',
            tipoSemana: TipoSemanaVista.descarga,
          ),
        ],
      ),
      const SizedBox(height: 12),
      ListaSesionesHistorial(
        sesiones: const [
          SesionHistorialVista(
            fechaTexto: 'lun 23 nov',
            plantillaTexto: 'Fuerza A · estándar',
            resumenTexto: '12 de 12 series · 38 min',
            esfuerzoTexto: 'Esfuerzo 3 de 5',
          ),
          SesionHistorialVista(
            fechaTexto: 'lun 30 nov',
            plantillaTexto: 'Fuerza A · corta',
            resumenTexto: '8 de 8 series · 27 min',
            tipoSemana: TipoSemanaVista.descarga,
          ),
        ],
        alTocarSesion: (_) {},
      ),
    ],
  );
}

class _E8Records extends StatelessWidget {
  const _E8Records();

  @override
  Widget build(BuildContext context) => ListaRecords(
    records: const [
      RecordVista(
        ejercicio: 'Press de pecho',
        varianteTexto: 'En la estación',
        tipo: TipoRecordVista.mejorCarga,
        valorTexto: 'Placa 5',
        fechaTexto: '23 nov',
        reciente: true,
      ),
      RecordVista(
        ejercicio: 'Plancha',
        tipo: TipoRecordVista.mejorTiempo,
        valorTexto: '45 s',
        fechaTexto: '16 nov',
      ),
      RecordVista(
        ejercicio: 'Remo sentado',
        varianteTexto: 'Con banda pisada',
        tipo: TipoRecordVista.mejorBanda,
        valorTexto: 'Banda verde',
        fechaTexto: '9 nov',
      ),
    ],
    alTocarRecord: (_) {},
  );
}

class _E9Molestias extends StatelessWidget {
  const _E9Molestias();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AvisoMolestia(
        zonaTexto: 'Hombro',
        nivel: NivelMolestia.fuerte,
        alProponerRegenerativa: () {},
        alSigue: () {},
        alYaNo: () {},
      ),
      const SizedBox(height: 12),
      const AvisoMolestia(zonaTexto: 'Rodilla', nivel: NivelMolestia.leve),
      const SizedBox(height: 12),
      FilaMolestia(
        zonaTexto: 'Hombro',
        nivel: NivelMolestia.fuerte,
        desdeTexto: 'desde el 20 nov',
        alTocar: () {},
      ),
      const SizedBox(height: 8),
      FilaMolestia(
        zonaTexto: 'Codo',
        nivel: NivelMolestia.leve,
        desdeTexto: 'desde el 2 nov',
        activa: false,
        alTocar: () {},
      ),
    ],
  );
}

class _E10Ajustes extends StatelessWidget {
  const _E10Ajustes();

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaModulo(
          titulo: 'Valores del plan',
          icono: Icons.tune,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorPasos(
                etiqueta: 'DESCANSO ENTRE SERIES',
                valorTexto: '60 s',
                descripcionAccesible: 'Descanso entre series: 60 segundos',
                etiquetaMenos: 'Quitar 15 segundos de descanso',
                etiquetaMas: 'Agregar 15 segundos de descanso',
                alMenos: () {},
                alMas: () {},
              ),
              SizedBox(height: v.espacio * 2),
              SelectorPasos(
                etiqueta: 'DÍAS DE FUERZA',
                valorTexto: '3',
                descripcionAccesible: 'Días del plan: 3',
                etiquetaMenos: 'Un día menos',
                etiquetaMas: 'Un día más',
                alMenos: null,
                alMas: () {},
              ),
            ],
          ),
        ),
        SizedBox(height: v.espacio * 2),
        TarjetaContenidoEnRevision(alAbrir: () {}),
        SizedBox(height: v.espacio * 2),
        TarjetaModulo(
          titulo: 'Mis datos',
          icono: Icons.lock_outline,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mis datos de Hábitos'),
            subtitle: const Text('Exportar o borrar lo del gimnasio.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

/// Un gadget de ejemplo para la tablet y Hoy (sin pantalla completa): el
/// gadget **Serie y descanso** con datos de ejemplo.
Widget gadgetSerieDescansoEjemplo({
  DateTime Function()? ahora,
  EscalaTemporizador escala = EscalaTemporizador.compacta,
}) {
  final reloj = ahora ?? DateTime.now;
  return GadgetSerieDescanso(
    ejercicio: 'Elevaciones laterales',
    puestoTexto: 'Polea baja',
    serieActual: 2,
    seriesTotales: 3,
    repeticionesTexto: '12 repeticiones',
    cargaTexto: 'Placa 3',
    series: const [
      SerieVista(
        numero: 1,
        estado: EstadoSerie.hecha,
        repeticiones: 12,
        cargaTexto: 'placa 3',
      ),
      SerieVista(
        numero: 2,
        estado: EstadoSerie.enDescanso,
        repeticiones: 12,
        cargaTexto: 'placa 3',
      ),
      SerieVista(
        numero: 3,
        estado: EstadoSerie.pendiente,
        repeticiones: 12,
        cargaTexto: 'placa 3',
      ),
    ],
    descanso: DescansoPlanificado.iniciar(reloj(), const Duration(seconds: 48)),
    siguiente: 'Tríceps en polea alta',
    escala: escala,
    ahora: reloj,
  );
}
