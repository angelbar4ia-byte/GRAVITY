/// Ajustes › Voz: lo que el equipo puede decir hoy y con qué voz.
///
/// Es la voz **real** del dispositivo (fuente A del motor de voz, Fase 8,
/// P3.2a-1): se elige la voz y la velocidad, se prueba una frase y se ve, sin
/// adornos, qué hay en este equipo. La voz descargada y el audio pregrabado
/// aparecen como "próximamente", sin fecha.
///
/// Reglas: la pantalla solo ofrece voces que funcionan sin conexión (R8); las
/// frases de prueba son fijas (R1); la lectura en voz alta de las respuestas
/// de GRAVITY se enciende en el cuadro de conversación y se apaga al cerrar la
/// app, no aquí.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/sesion_efectiva.dart';
import '../../../nucleo/permisos/permisos.dart' show puedeUsarHabitos;
import '../../gravity/conversacion/panel_conversacion.dart'
    show rolesQueConversan;
import '../../gravity/voz/asignador.dart';
import '../../gravity/voz/preferencias.dart';
import '../../gravity/voz/proveedores.dart';
import '../../gravity/voz/tipos.dart';
import '../marco_seccion.dart';
import '../secciones_ajustes.dart';
import 'informe_voz.dart';
import 'prueba_voz.dart';

class PantallaVoz extends ConsumerWidget {
  const PantallaVoz({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final informe = ref.watch(informeVozProvider);
    final rol = ref.watch(rolEfectivoProvider);
    final maestra = ref.watch(esCuentaMaestraProvider);
    final conversa = rol != null && rolesQueConversan.contains(rol);
    final usaCurso = rol != null && puedeUsarHabitos(rol, esMaestra: maestra);
    final datos = informe.value;
    return MarcoSeccion(
      seccion: SeccionAjustes.voz,
      hijos: [
        _EstadoDeLaVoz(informe: informe),
        if (datos != null && !datos.plataformaSinVoz && !datos.sinMotor) ...[
          if (conversa && datos.vocesEnEspanol.isNotEmpty)
            _SeccionAsistente(informe: datos),
          if (usaCurso) _SeccionIngles(informe: datos),
          const _OtrasVoces(),
          _DetallesTecnicos(informe: datos),
        ],
        const NotaAjustes(
          'GRAVITY solo lee en voz alta lo que ya pasó el filtro de '
          'privacidad: nunca montos de dinero ni datos de salud.',
          icono: Icons.shield_outlined,
        ),
        const NotaAjustes(
          'Por las bocinas de la casa nunca se dicen montos de dinero ni datos '
          'clínicos; los recordatorios de cuidados son genéricos.',
          icono: Icons.speaker_outlined,
        ),
      ],
    );
  }
}

String _cuantas(int n, String singular, String plural) =>
    n == 1 ? '1 $singular' : '$n $plural';

/// Qué hay en este equipo, dicho con honestidad.
class _EstadoDeLaVoz extends ConsumerWidget {
  const _EstadoDeLaVoz({required this.informe});

  final AsyncValue<InformeVoz> informe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = Theme.of(context).textTheme;
    final datos = informe.value;
    if (datos == null) {
      return NotaAjustes(
        informe.hasError
            ? 'No se pudieron consultar las voces de este equipo.'
            : 'Buscando las voces de este equipo…',
        icono: Icons.record_voice_over_outlined,
      );
    }
    if (datos.plataformaSinVoz) {
      return const NotaAjustes(
        'La voz todavía no está disponible en este equipo; mientras tanto '
        'puedes escribirle a GRAVITY. En el teléfono Android también puedes '
        'dictar el mensaje con el micrófono del cuadro de conversación.',
        icono: Icons.record_voice_over_outlined,
      );
    }
    if (datos.sinMotor) {
      return const NotaAjustes(
        'Este equipo no tiene un motor de texto a voz que responda. Actívalo '
        'o instálalo en los ajustes del sistema (en Android, "Salida de texto '
        'a voz"); mientras tanto puedes escribirle a GRAVITY.',
        icono: Icons.record_voice_over_outlined,
      );
    }
    final es = datos.vocesEnEspanol.length;
    final enUS = datos.vocesEnIngles[Variante.enUS]?.length ?? 0;
    final enGB = datos.vocesEnIngles[Variante.enGB]?.length ?? 0;
    return Card(
      key: const ValueKey('voz-estado'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voz del dispositivo', style: texto.titleMedium),
            const SizedBox(height: 8),
            Text(
              'GRAVITY usa las voces que ya trae este equipo y que funcionan '
              'sin conexión. No descarga nada para hablar.',
              style: texto.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              es == 0
                  ? 'En español: no hay ninguna voz que funcione sin conexión.'
                  : 'En español: ${_cuantas(es, 'voz', 'voces')}.',
              key: const ValueKey('voz-estado-espanol'),
            ),
            Text(
              datos.totalEnIngles == 0
                  ? 'En inglés: no hay ninguna voz que funcione sin conexión.'
                  : 'En inglés: ${_cuantas(datos.totalEnIngles, 'voz', 'voces')} '
                        '(americano $enUS, británico $enGB).',
              key: const ValueKey('voz-estado-ingles'),
            ),
            if (datos.vocesDeRed > 0)
              Text(
                'Se dejaron fuera ${_cuantas(datos.vocesDeRed, 'voz', 'voces')} '
                'que necesitan conexión.',
                key: const ValueKey('voz-estado-red'),
              ),
            if (datos.vocesSinInstalar > 0)
              Text(
                'Hay ${_cuantas(datos.vocesSinInstalar, 'voz', 'voces')} cuyos '
                'datos no están instalados.',
              ),
            if (es == 0 || datos.totalEnIngles == 0) ...[
              const SizedBox(height: 8),
              Text(
                'Para agregar una voz, instálala en los ajustes del sistema '
                '(Android: "Salida de texto a voz"; Windows: Hora e idioma › '
                'Voz). La ruta exacta cambia según el fabricante y la versión.',
                key: const ValueKey('voz-como-instalar'),
                style: texto.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('voz-actualizar'),
                onPressed: () async {
                  await ref.read(motorVozProvider).refrescar();
                  ref.invalidate(informeVozProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar la lista de voces'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una voz que se muestra para una voz de guion (o para la del asistente).
class _FilaDeVoz extends StatelessWidget {
  const _FilaDeVoz({
    required this.claveBase,
    required this.titulo,
    required this.voz,
    required this.onProbar,
    required this.onCambiar,
    required this.prueba,
    required this.onParar,
  });

  final String claveBase;
  final String titulo;
  final VozMotor? voz;
  final VoidCallback? onProbar;
  final VoidCallback? onCambiar;
  final EstadoPrueba prueba;
  final VoidCallback onParar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final mia = prueba.clave == claveBase;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: texto.titleSmall),
          Text(
            voz == null ? 'Sin otra voz distinta en este equipo' : '${voz!.nombre} · ${voz!.locale}',
            key: ValueKey('$claveBase-voz'),
            style: texto.bodyMedium,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                key: ValueKey('$claveBase-probar'),
                onPressed: voz == null ? null : onProbar,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Probar'),
              ),
              TextButton(
                key: ValueKey('$claveBase-cambiar'),
                onPressed: onCambiar,
                child: const Text('Cambiar'),
              ),
              if (mia && (prueba.sonando || prueba.hayOtraVoz))
                TextButton.icon(
                  key: ValueKey('$claveBase-parar'),
                  onPressed: onParar,
                  icon: const Icon(Icons.stop),
                  label: const Text('Parar'),
                ),
            ],
          ),
          if (mia && prueba.mensaje != null)
            Semantics(
              liveRegion: true,
              child: Text(
                prueba.mensaje!,
                key: ValueKey('$claveBase-mensaje'),
                style: texto.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Deja elegir una voz de la lista. Devuelve la elegida o `null`.
Future<VozMotor?> _elegirVoz(
  BuildContext context, {
  required String titulo,
  required List<VozMotor> voces,
  required String? actual,
  Map<String, String> usadasPor = const {},
}) => showDialog<VozMotor>(
  context: context,
  builder: (dialogo) => AlertDialog(
    key: const ValueKey('voz-elegir'),
    title: Text(titulo),
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final v in voces)
            ListTile(
              key: ValueKey('voz-opcion-${v.id}'),
              selected: v.id == actual,
              title: Text(v.nombre),
              subtitle: Text(
                [
                  v.locale,
                  if (usadasPor[v.id] != null && v.id != actual)
                    'la usa: ${usadasPor[v.id]}',
                ].join(' · '),
              ),
              trailing: v.id == actual ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(dialogo).pop(v),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialogo).pop(),
        child: const Text('Cancelar'),
      ),
    ],
  ),
);

/// La voz y la velocidad del asistente.
class _SeccionAsistente extends ConsumerWidget {
  const _SeccionAsistente({required this.informe});

  final InformeVoz informe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = Theme.of(context).textTheme;
    final prefs = ref.watch(preferenciasVozProvider);
    final prueba = ref.watch(pruebaVozProvider);
    final asignacion = resolverAsignacion(
      asignador: const AsignadorPorGenero(),
      fuente: Fuente.dispositivo,
      variante: Variante.esMX,
      voces: informe.vocesEnEspanol,
      roles: const {VozDeGuion.f1},
      guardadas: prefs.asignacionDe(Fuente.dispositivo, Variante.esMX),
    );
    final id = asignacion.idVozMotor[VozDeGuion.f1];
    final voz = informe.vocesEnEspanol.where((v) => v.id == id).firstOrNull;
    final velocidad = prefs.asistente.velocidad;
    return Card(
      key: const ValueKey('voz-asistente'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Respuestas de GRAVITY', style: texto.titleMedium),
            const SizedBox(height: 4),
            Text(
              'La voz con la que GRAVITY lee sus respuestas, en español. La '
              'lectura se enciende con el interruptor "Leer las respuestas en '
              'voz alta" del cuadro de conversación y se apaga al cerrar la '
              'app. Nunca lee lo que aparece solo en tu pantalla.',
              style: texto.bodyMedium,
            ),
            _FilaDeVoz(
              claveBase: 'voz-asistente-fila',
              titulo: 'Voz de GRAVITY',
              voz: voz,
              prueba: prueba,
              onProbar: () => ref
                  .read(pruebaVozProvider.notifier)
                  .probar(
                    clave: 'voz-asistente-fila',
                    guion: const Guion(
                      id: 'prueba',
                      variante: Variante.esMX,
                      turnos: [
                        Turno(
                          voz: VozDeGuion.f1,
                          texto: fraseDePruebaEnEspanol,
                        ),
                      ],
                    ),
                    uso: UsoVoz.asistente,
                    velocidad: velocidad,
                  ),
              onParar: () => ref.read(pruebaVozProvider.notifier).parar(),
              onCambiar: () async {
                final elegida = await _elegirVoz(
                  context,
                  titulo: 'Voz de GRAVITY',
                  voces: informe.vocesEnEspanol,
                  actual: id,
                );
                if (elegida == null) return;
                ref
                    .read(preferenciasVozProvider.notifier)
                    .fijarAsignacion(Fuente.dispositivo, Variante.esMX, {
                      VozDeGuion.f1: elegida.id,
                    });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Velocidad: ${velocidad.toStringAsFixed(1)} (1.0 es la normal)',
              key: const ValueKey('voz-velocidad-texto'),
              style: texto.titleSmall,
            ),
            Slider(
              key: const ValueKey('voz-velocidad'),
              value: velocidad,
              min: velocidadVozMinima,
              max: velocidadVozMaxima,
              divisions: 10,
              label: velocidad.toStringAsFixed(1),
              semanticFormatterCallback: (v) =>
                  'Velocidad ${v.toStringAsFixed(1)}, 1.0 es la normal',
              onChanged: (v) => ref
                  .read(preferenciasVozProvider.notifier)
                  .fijarVelocidad(UsoVoz.asistente, v),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las cinco voces del curso de inglés, por acento.
class _SeccionIngles extends ConsumerWidget {
  const _SeccionIngles({required this.informe});

  final InformeVoz informe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('voz-curso'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Curso de inglés', style: texto.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Con qué voces sonará el curso de inglés (mujeres, hombres y '
              'narrador). Todavía no hay audios del curso en la app: aquí solo '
              'se eligen y se prueban las voces.',
              style: texto.bodyMedium,
            ),
            if (informe.totalEnIngles == 0) ...[
              const SizedBox(height: 8),
              Text(
                'Este equipo no tiene una voz en inglés que funcione sin '
                'conexión. Puedes instalar una en los ajustes del sistema '
                '(Android: "Salida de texto a voz"; Windows: Hora e idioma › '
                'Voz).',
                key: const ValueKey('voz-curso-sin-ingles'),
              ),
            ],
            for (final variante in const [Variante.enUS, Variante.enGB])
              if ((informe.vocesEnIngles[variante] ?? const []).isNotEmpty)
                _AcentoIngles(
                  variante: variante,
                  voces: informe.vocesEnIngles[variante]!,
                ),
          ],
        ),
      ),
    );
  }
}

class _AcentoIngles extends ConsumerWidget {
  const _AcentoIngles({required this.variante, required this.voces});

  final Variante variante;
  final List<VozMotor> voces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = Theme.of(context).textTheme;
    final prefs = ref.watch(preferenciasVozProvider);
    final prueba = ref.watch(pruebaVozProvider);
    final asignacion = resolverAsignacion(
      asignador: const AsignadorPorGenero(),
      fuente: Fuente.dispositivo,
      variante: variante,
      voces: voces,
      roles: VozDeGuion.values.toSet(),
      guardadas: prefs.asignacionDe(Fuente.dispositivo, variante),
    );
    final porId = {for (final v in voces) v.id: v};
    final usadasPor = {
      for (final e in asignacion.idVozMotor.entries) e.value: e.key.nombre,
    };
    final claveDialogo = 'voz-dialogo-${variante.etiqueta}';
    final hayDialogo =
        asignacion.idVozMotor.containsKey(VozDeGuion.f1) &&
        asignacion.idVozMotor.containsKey(VozDeGuion.m1);
    final dialogoSuena = prueba.clave == claveDialogo;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        key: ValueKey('voz-acento-${variante.etiqueta}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${variante.nombre} (${_cuantas(voces.length, 'voz', 'voces')})',
            style: texto.titleSmall,
          ),
          for (final rol in VozDeGuion.values)
            _FilaDeVoz(
              claveBase: 'voz-${variante.etiqueta}-${rol.etiqueta}',
              titulo: rol.nombre,
              voz: porId[asignacion.idVozMotor[rol]],
              prueba: prueba,
              onProbar: () => ref
                  .read(pruebaVozProvider.notifier)
                  .probar(
                    clave: 'voz-${variante.etiqueta}-${rol.etiqueta}',
                    guion: Guion(
                      id: 'prueba',
                      variante: variante,
                      turnos: [Turno(voz: rol, texto: fraseDePruebaEnIngles)],
                    ),
                    uso: UsoVoz.curso,
                  ),
              onParar: () => ref.read(pruebaVozProvider.notifier).parar(),
              onCambiar: () async {
                final elegida = await _elegirVoz(
                  context,
                  titulo: rol.nombre,
                  voces: voces,
                  actual: asignacion.idVozMotor[rol],
                  usadasPor: usadasPor,
                );
                if (elegida == null) return;
                ref
                    .read(preferenciasVozProvider.notifier)
                    .fijarAsignacion(
                      Fuente.dispositivo,
                      variante,
                      _cambiar(asignacion.idVozMotor, rol, elegida.id),
                    );
              },
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: ValueKey(claveDialogo),
                onPressed: hayDialogo
                    ? () => ref
                          .read(pruebaVozProvider.notifier)
                          .probar(
                            clave: claveDialogo,
                            guion: Guion(
                              id: 'prueba-dialogo',
                              variante: variante,
                              turnos: dialogoDePrueba,
                            ),
                            uso: UsoVoz.curso,
                          )
                    : null,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Diálogo de prueba (2 voces)'),
              ),
              if (dialogoSuena && (prueba.sonando || prueba.hayOtraVoz))
                TextButton.icon(
                  key: ValueKey('$claveDialogo-parar'),
                  onPressed: () =>
                      ref.read(pruebaVozProvider.notifier).parar(),
                  icon: const Icon(Icons.stop),
                  label: const Text('Parar'),
                ),
            ],
          ),
          if (!hayDialogo)
            Text(
              'Para el diálogo hacen falta al menos dos voces distintas.',
              key: ValueKey('$claveDialogo-falta'),
              style: texto.bodySmall,
            ),
          if (dialogoSuena && prueba.mensaje != null)
            Semantics(
              liveRegion: true,
              child: Text(
                prueba.mensaje!,
                key: ValueKey('$claveDialogo-mensaje'),
                style: texto.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  /// Da [id] a [rol]. Si otro rol ya usaba esa voz, se intercambian (una voz
  /// nunca queda en dos papeles).
  static Map<VozDeGuion, String> _cambiar(
    Map<VozDeGuion, String> actual,
    VozDeGuion rol,
    String id,
  ) {
    final nuevo = Map<VozDeGuion, String>.of(actual);
    final anterior = nuevo[rol];
    for (final e in actual.entries) {
      if (e.key != rol && e.value == id) {
        if (anterior == null) {
          nuevo.remove(e.key);
        } else {
          nuevo[e.key] = anterior;
        }
      }
    }
    nuevo[rol] = id;
    return nuevo;
  }
}

/// Las fuentes que todavía no están, sin prometer fecha.
class _OtrasVoces extends StatelessWidget {
  const _OtrasVoces();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('voz-otras'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Otras voces', style: texto.titleMedium),
            const SizedBox(height: 8),
            Text('Voz descargada · próximamente', style: texto.titleSmall),
            const Text(
              'Voces más naturales que se descargan una vez y funcionan sin '
              'conexión.',
            ),
            const SizedBox(height: 8),
            Text(
              'Audio pregrabado del curso · próximamente',
              style: texto.titleSmall,
            ),
            const Text('Los audios del curso de inglés ya preparados.'),
          ],
        ),
      ),
    );
  }
}

/// Lo que dice el sistema, voz por voz (para saber qué trae cada aparato).
class _DetallesTecnicos extends StatelessWidget {
  const _DetallesTecnicos({required this.informe});

  final InformeVoz informe;

  static const _maximo = 80;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final voces = informe.sistema;
    String red(bool? r) => switch (r) {
      true => 'necesita red',
      false => 'sin red',
      null => 'red: sin dato',
    };
    // Solo se dice cuando el sistema (o el nombre de la voz) lo dan.
    String genero(Genero g) => switch (g) {
      Genero.mujer => ' · mujer',
      Genero.hombre => ' · hombre',
      Genero.sinDato => '',
    };
    return Card(
      child: ExpansionTile(
        key: const ValueKey('voz-detalles'),
        title: const Text('Detalles técnicos'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            voces.isEmpty
                ? 'El sistema no dio ninguna voz.'
                : 'Voces que reporta el sistema: ${voces.length}.',
            style: texto.bodyMedium,
          ),
          for (final v in voces.take(_maximo))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${v.nombre} · ${v.locale} · calidad ${v.calidad ?? 'sin dato'} '
                '· ${red(v.requiereRed)}${genero(v.genero)}'
                '${v.instalada ? '' : ' · sin instalar'}',
                style: texto.bodySmall,
              ),
            ),
          if (voces.length > _maximo)
            Text('… y ${voces.length - _maximo} más.', style: texto.bodySmall),
        ],
      ),
    );
  }
}
