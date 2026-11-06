/// Menú de la semana: 7 días por 3 tiempos. Editable solo para quien puede.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../../../nucleo/contratos/rutas.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';

String _fechaCorta(DateTime d) => '${d.day}/${d.month}';

class PantallaMenuSemana extends ConsumerWidget {
  const PantallaMenuSemana({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semana = ref.watch(semanaAlimentacionProvider);
    final domingo = semana.add(const Duration(days: 6));
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: MarcoPantalla(
        titulo: 'Menú de la semana',
        acciones: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Lista de compras',
            onPressed: () => context.go('${Rutas.alimentacion}/compras'),
          ),
        ],
        cuerpo: Column(children: [
          _NavegadorSemana(
            texto: 'Semana del ${_fechaCorta(semana)} al ${_fechaCorta(domingo)}',
            alCambiar: (dias) => ref.read(semanaAlimentacionProvider.notifier).state =
                semana.add(Duration(days: dias)),
          ),
          Expanded(
            child: ref.watch(platillosProvider).when(
                  loading: () => const EstadoCargando(),
                  error: (_, _) => EstadoError(
                    mensaje: 'No pudimos cargar los platillos.',
                    alReintentar: () => ref.invalidate(platillosProvider),
                  ),
                  data: (platillos) => ref.watch(menuSemanaProvider).when(
                        loading: () => const EstadoCargando(),
                        error: (_, _) => EstadoError(
                          mensaje: 'No pudimos cargar el menú.',
                          alReintentar: () => ref.invalidate(menuSemanaProvider),
                        ),
                        data: (menu) => _ListaDias(menu: menu, platillos: platillos),
                      ),
                ),
          ),
        ]),
      ),
    );
  }
}

class _NavegadorSemana extends StatelessWidget {
  const _NavegadorSemana({required this.texto, required this.alCambiar});
  final String texto;
  final void Function(int dias) alCambiar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Semana anterior',
            onPressed: () => alCambiar(-7),
          ),
          Expanded(
            child: Text(texto,
                textAlign: TextAlign.center,
                style: ValoresDiseno.de(context).lectura(
                    tamano: 16, peso: FontWeight.w600, color: ValoresDiseno.de(context).textoFuerte)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Semana siguiente',
            onPressed: () => alCambiar(7),
          ),
        ]),
      );
}

class _ListaDias extends ConsumerWidget {
  const _ListaDias({required this.menu, required this.platillos});
  final List<EntradaMenu> menu;
  final List<Platillo> platillos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final editar = ref.watch(puedeEditarAlimentacionProvider);
    final porId = {for (final p in platillos) p.id: p};
    String? nombreDe(int dia, TiempoComida t) {
      for (final e in menu) {
        if (e.dia == dia && e.tiempo == t) return porId[e.platilloId]?.nombre;
      }
      return null;
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (!editar)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(Icons.visibility_outlined, size: 18, color: v.textoTenue),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Solo lectura',
                  style: v.lectura(tamano: 14, color: v.textoTenue)),
            ),
          ]),
        ),
      for (var d = 0; d < 7; d++)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(diasSemana[d],
                  style: v.titulo(tamano: 18, color: v.textoFuerte)),
              for (final t in TiempoComida.values)
                _CeldaComida(
                  dia: d,
                  tiempo: t,
                  nombre: nombreDe(d, t),
                  editable: editar,
                  platillos: platillos,
                ),
            ]),
          ),
        ),
    ]);
  }
}

class _CeldaComida extends ConsumerWidget {
  const _CeldaComida({
    required this.dia,
    required this.tiempo,
    required this.nombre,
    required this.editable,
    required this.platillos,
  });
  final int dia;
  final TiempoComida tiempo;
  final String? nombre;
  final bool editable;
  final List<Platillo> platillos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ValoresDiseno.de(context);
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(children: [
        SizedBox(
          width: 96,
          child: Text(tiempo.etiqueta, style: v.lectura(tamano: 14, color: v.etiqueta)),
        ),
        Expanded(
          child: Text(nombre ?? 'Sin platillo',
              style: v.lectura(
                  tamano: 16,
                  color: nombre == null ? v.textoTenue : v.texto)),
        ),
        if (editable) Icon(Icons.edit_outlined, size: 18, color: v.textoTenue),
      ]),
    );
    final etiqueta = '${diasSemana[dia]}, ${tiempo.etiqueta}: ${nombre ?? 'sin platillo'}';
    if (!editable) return Semantics(label: etiqueta, excludeSemantics: true, child: contenido);
    return Semantics(
      button: true,
      label: '$etiqueta. Toca para cambiar.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _elegir(context, ref),
        child: contenido,
      ),
    );
  }

  Future<void> _elegir(BuildContext context, WidgetRef ref) async {
    final elegido = await mostrarHojaInferior<String>(
      context,
      titulo: '${diasSemana[dia]} · ${tiempo.etiqueta}',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final p in platillos)
          ListTile(
            title: Text(p.nombre),
            onTap: () => Navigator.of(context).pop(p.id),
          ),
        ListTile(
          leading: const Icon(Icons.clear),
          title: const Text('Quitar platillo'),
          onTap: () => Navigator.of(context).pop(''),
        ),
      ]),
    );
    if (elegido == null || !context.mounted) return;
    final servicio = ref.read(servicioAlimentacionProvider);
    final semana = ref.read(semanaAlimentacionProvider);
    final antes = await servicio.asignar(semana, dia, tiempo, elegido.isEmpty ? null : elegido);
    ref.read(versionAlimentacionProvider.notifier).state++;
    if (!context.mounted) return;
    mostrarAvisoDeshacer(
      context,
      mensaje: elegido.isEmpty ? 'Platillo quitado' : 'Menú actualizado',
      alDeshacer: () async {
        await servicio.asignar(semana, dia, tiempo, antes);
        ref.read(versionAlimentacionProvider.notifier).state++;
      },
    );
  }
}
