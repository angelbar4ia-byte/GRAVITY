/// Asistente de configuración de 8 pasos (regla 68). Cada paso propone un
/// valor y siempre hay *Decidir después*.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../casos_uso/servicio_agenda.dart';
import '../estado/proveedores.dart';

const pasosAsistente = [
  'Perfil y áreas',
  'Trabajo y traslado',
  'Tu día',
  'Espiritual',
  'Hábitos a eliminar',
  'Revisión semanal',
  'Privacidad',
  'Resumen',
];

class PantallaAsistente extends ConsumerStatefulWidget {
  const PantallaAsistente({super.key});
  @override
  ConsumerState<PantallaAsistente> createState() => _AsistenteEstado();
}

class _AsistenteEstado extends ConsumerState<PantallaAsistente> {
  int paso = 0;
  final hechos = <int>{};
  int entrada = 480, salida = 1080, ida = 0, vuelta = 0, despertar = 360, dormir = 1320;
  int revisionDia = 6, revisionHora = 870;
  List<CargaDelDia>? semana;

  Future<void> _terminar() async {
    final s = ref.read(servicioAgendaProvider);
    await s.aplicarAsistente(
      despertarMin: despertar,
      dormirMin: dormir,
      trabajoEntradaMin: hechos.contains(1) ? entrada : null,
      trabajoSalidaMin: hechos.contains(1) ? salida : null,
      trasladoIdaMin: ida,
      trasladoVueltaMin: vuelta,
      revisionDia: revisionDia,
      revisionHoraMin: revisionHora,
      pasosHechos: hechos,
    );
    final sem = await s.semanaTipo();
    ref.read(versionHabitosProvider.notifier).state++;
    setState(() => semana = sem);
  }

  Widget _contenido() => switch (paso) {
        0 => const Text('Empezamos con tus seis áreas; después puedes quitar o sumar. Es solo para ti.'),
        1 => Column(children: [
            _Hora('Entrada', entrada, (v) => setState(() => entrada = v)),
            _Hora('Salida', salida, (v) => setState(() => salida = v)),
            _Minutos('Traslado de ida (min)', ida, (v) => setState(() => ida = v)),
            _Minutos('Traslado de regreso (min)', vuelta, (v) => setState(() => vuelta = v)),
          ]),
        2 => Column(children: [
            _Hora('Despertar', despertar, (v) => setState(() => despertar = v)),
            _Hora('Dormir', dormir, (v) => setState(() => dormir = v)),
          ]),
        3 => const Text('Biblia: Reina-Valera 1909 y KJV. Ruta de inicio: Juan, 21 días.'),
        4 => const Text('Configura cigarrillo o azúcar cuando quieras desde "Reservado". Nada de esto sale de tu control.'),
        5 => Column(children: [
            _Hora('Hora de la revisión (sábado)', revisionHora, (v) => setState(() => revisionHora = v)),
            const Text('Aviso 15 minutos antes.'),
          ]),
        6 => const Text('Lo sensible empieza solo en tu teléfono. En Ajustes › Privacidad puedes activar la nube cifrada con tu frase.'),
        _ => semana == null
            ? FilledButton(onPressed: _terminar, child: const Text('Ver mi semana tipo'))
            : Column(children: [
                for (var i = 0; i < 7; i++)
                  ListTile(
                    title: Text(const ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][i]),
                    subtitle: Text('${semana![i].programados} de ${semana![i].libres} min libres'),
                    trailing: Text(const {'ligero': 'Ligero', 'equilibrado': 'Equilibrado', 'saturado': 'Saturado'}[semana![i].nivel.name]!),
                  ),
              ]),
      };

  @override
  Widget build(BuildContext context) => TemaModulo(
        modulo: Modulo.habitos,
        child: MarcoPantalla(
          titulo: 'Configuración',
          rutaAnterior: Rutas.habitos,
          cuerpo: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Paso ${paso + 1} de ${pasosAsistente.length}: ${pasosAsistente[paso]}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _contenido(),
            const SizedBox(height: 16),
            Row(children: [
              if (paso > 0) TextButton(onPressed: () => setState(() => paso--), child: const Text('Atrás')),
              const Spacer(),
              if (paso < pasosAsistente.length - 1) ...[
                TextButton(onPressed: () => setState(() => paso++), child: const Text('Decidir después')),
                FilledButton(
                    onPressed: () => setState(() {
                          hechos.add(paso);
                          paso++;
                        }),
                    child: const Text('Siguiente')),
              ] else
                FilledButton(
                    onPressed: () => context.go(Rutas.habitos), child: const Text('Terminar')),
            ]),
          ]),
        ),
      );
}

class _Hora extends StatelessWidget {
  const _Hora(this.etiqueta, this.min, this.alCambiar);
  final String etiqueta;
  final int min;
  final ValueChanged<int> alCambiar;
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(etiqueta),
        subtitle: Text(
            '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}'),
        onTap: () async {
          final h = await showTimePicker(
              context: context, initialTime: TimeOfDay(hour: min ~/ 60, minute: min % 60));
          if (h != null) alCambiar(h.hour * 60 + h.minute);
        },
      );
}

class _Minutos extends StatelessWidget {
  const _Minutos(this.etiqueta, this.valor, this.alCambiar);
  final String etiqueta;
  final int valor;
  final ValueChanged<int> alCambiar;
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(etiqueta),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: 'Menos',
              icon: const Icon(Icons.remove),
              onPressed: valor >= 5 ? () => alCambiar(valor - 5) : null),
          Text('$valor'),
          IconButton(tooltip: 'Más', icon: const Icon(Icons.add), onPressed: () => alCambiar(valor + 5)),
        ]),
      );
}
