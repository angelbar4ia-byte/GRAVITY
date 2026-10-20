/// Ajustes › Apariencia (DISENO_UX_UI, sección 13 y flujo F9): estilo,
/// claro/oscuro con horario editable y personalidad por módulo, con vista
/// previa en vivo. Todo cambia al instante, sin reiniciar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nucleo/contratos/roles.dart';
import '../componentes/etiqueta_panel.dart';
import '../componentes/monto_ocultable.dart';
import '../componentes/semaforo.dart';
import '../componentes/tarjeta_modulo.dart';
import '../modo_claro_oscuro.dart';
import '../personalidad_modulo.dart';
import '../proveedores.dart';
import '../valores_diseno.dart';

class SeccionApariencia extends ConsumerWidget {
  const SeccionApariencia({super.key});

  static const _modos = {
    ModoClaroOscuro.automaticoPorHora: 'Automático por hora',
    ModoClaroOscuro.sistema: 'Del sistema',
    ModoClaroOscuro.claro: 'Siempre claro',
    ModoClaroOscuro.oscuro: 'Siempre oscuro',
  };

  static const _modulos = {
    Modulo.finanzas: 'Finanzas',
    Modulo.habitos: 'Hábitos',
    Modulo.cuidados: 'Cuidados',
    Modulo.alimentacion: 'Alimentación',
    Modulo.casa: 'Casa',
    Modulo.ajustes: 'Ajustes',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final estilos = ref.watch(estilosDisponiblesProvider);
    final estilo = ref.watch(estiloProvider);
    final preferencia = ref.watch(preferenciaClaroOscuroProvider);
    final opciones = ref.watch(opcionesPersonalidadProvider);
    final titulo = SizedBox(height: e * 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EtiquetaPanel('Estilo'),
        SizedBox(height: e),
        Wrap(
          spacing: e,
          runSpacing: e,
          children: [
            for (final opcion in estilos)
              ChoiceChip(
                key: ValueKey('estilo-${opcion.id}'),
                label: Text(opcion.nombre),
                selected: opcion.id == estilo.id,
                onSelected: (_) =>
                    ref.read(estiloProvider.notifier).elegir(opcion),
              ),
          ],
        ),
        if (estilo.descripcion.isNotEmpty) ...[
          SizedBox(height: e),
          Text(
            estilo.descripcion,
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
        ],
        titulo,
        const EtiquetaPanel('Claro / oscuro'),
        SizedBox(height: e),
        Wrap(
          spacing: e,
          runSpacing: e,
          children: [
            for (final MapEntry(key: modo, value: nombre) in _modos.entries)
              ChoiceChip(
                key: ValueKey('modo-${modo.name}'),
                label: Text(nombre),
                selected: preferencia.modo == modo,
                onSelected: (_) => ref
                    .read(preferenciaClaroOscuroProvider.notifier)
                    .cambiarModo(modo),
              ),
          ],
        ),
        if (preferencia.modo == ModoClaroOscuro.automaticoPorHora) ...[
          SizedBox(height: e * 1.5),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: e,
            runSpacing: e,
            children: [
              Text('Claro de', style: v.lectura()),
              _BotonHora(
                key: const ValueKey('horario-inicio'),
                hora: preferencia.horario.inicio,
                alElegir: (t) => ref
                    .read(preferenciaClaroOscuroProvider.notifier)
                    .cambiarHorario(preferencia.horario.copyWith(inicio: t)),
              ),
              Text('a', style: v.lectura()),
              _BotonHora(
                key: const ValueKey('horario-fin'),
                hora: preferencia.horario.fin,
                alElegir: (t) => ref
                    .read(preferenciaClaroOscuroProvider.notifier)
                    .cambiarHorario(preferencia.horario.copyWith(fin: t)),
              ),
            ],
          ),
        ],
        titulo,
        const EtiquetaPanel('Personalidad por módulo'),
        SizedBox(height: e),
        for (final MapEntry(key: modulo, value: nombre) in _modulos.entries)
          _FilaPersonalidad(
            modulo: modulo,
            nombre: nombre,
            opcion: opciones[modulo] ?? OpcionPersonalidad.automatica,
          ),
        titulo,
        const EtiquetaPanel('Vista previa'),
        SizedBox(height: e),
        const _VistaPrevia(),
      ],
    );
  }
}

class _BotonHora extends StatelessWidget {
  const _BotonHora({super.key, required this.hora, required this.alElegir});

  final TimeOfDay hora;
  final ValueChanged<TimeOfDay> alElegir;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final texto =
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
    return OutlinedButton(
      onPressed: () async {
        final elegida = await showTimePicker(
          context: context,
          initialTime: hora,
          builder: (context, hijo) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: hijo!,
          ),
        );
        if (elegida != null) alElegir(elegida);
      },
      child: Text(texto, style: v.numero(tamano: 15)),
    );
  }
}

class _FilaPersonalidad extends ConsumerWidget {
  const _FilaPersonalidad({
    required this.modulo,
    required this.nombre,
    required this.opcion,
  });

  final Modulo modulo;
  final String nombre;
  final OpcionPersonalidad opcion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final automatica = PersonalidadModulo.automatica(modulo);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: v.espacio * 0.5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: v.lectura(color: v.textoFuerte)),
                Text(
                  automatica.tieneExcepciones
                      ? '${automatica.nombre} · siempre en alto contraste'
                      : automatica.nombre,
                  style: v.lectura(tamano: 13, color: v.textoTenue),
                ),
              ],
            ),
          ),
          DropdownButton<OpcionPersonalidad>(
            key: ValueKey('personalidad-${modulo.name}'),
            value: opcion,
            underline: const SizedBox(),
            onChanged: (nueva) {
              if (nueva == null) return;
              ref
                  .read(opcionesPersonalidadProvider.notifier)
                  .fijar(modulo, nueva);
            },
            items: const [
              DropdownMenuItem(
                value: OpcionPersonalidad.automatica,
                child: Text('Automática'),
              ),
              DropdownMenuItem(
                value: OpcionPersonalidad.igualAlEstilo,
                child: Text('Igual al estilo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia();

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return TarjetaModulo(
      key: const ValueKey('vista-previa'),
      titulo: 'Finanzas · semana',
      accion: const Semaforo(estado: EstadoSemaforo.verde),
      child: Row(
        children: [
          Text('Quedan', style: v.lectura(tamano: 14, color: v.textoTenue)),
          SizedBox(width: v.espacio),
          Expanded(
            child: MontoOcultable(
              centavos: 123450,
              estilo: v.numero(
                tamano: 20,
                peso: FontWeight.w600,
                color: v.acento,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
