/// Platillos desde la despensa (Fase 8, sección 2): qué se puede cocinar con
/// lo que hay en la despensa de la cuenta que lo pide, y "Sugerir con IA".
///
/// A la IA solo salen nombres de ingredientes, cantidades aproximadas y las
/// preferencias que la persona escribe aquí (nunca el perfil clínico de Papá).
/// Una receta sugerida no se guarda hasta tocar "Guardar receta".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../casos_uso/sugerir_platillos.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';

class PantallaDespensaPlatillos extends ConsumerStatefulWidget {
  const PantallaDespensaPlatillos({super.key});

  @override
  ConsumerState<PantallaDespensaPlatillos> createState() => _Estado();
}

class _Estado extends ConsumerState<PantallaDespensaPlatillos> {
  final _preferencias = TextEditingController();
  List<Platillo> _sugeridas = const [];
  final _guardadas = <String>{};
  bool _pidiendo = false;
  String? _error;

  @override
  void dispose() {
    _preferencias.dispose();
    super.dispose();
  }

  Future<void> _sugerir() async {
    setState(() {
      _pidiendo = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(servicioAlimentacionProvider)
          .sugerirConIA(_preferencias.text);
      if (!mounted) return;
      setState(() {
        _sugeridas = r;
        _guardadas.clear();
      });
    } on ErrorSugerencia catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = 'No se pudo sugerir: $e');
    } finally {
      if (mounted) setState(() => _pidiendo = false);
    }
  }

  Future<void> _guardar(Platillo p) async {
    try {
      await ref.read(servicioAlimentacionProvider).guardarSugerida(p);
      ref.invalidate(platillosProvider);
      ref.read(versionAlimentacionProvider.notifier).state++;
      if (mounted) setState(() => _guardadas.add(p.id));
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se guardó la receta: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final editar = ref.watch(puedeEditarAlimentacionProvider);
    return TemaModulo(
      modulo: Modulo.alimentacion,
      child: Scaffold(
        appBar: AppBar(title: const Text('Cocinar con la despensa')),
        body: ref
            .watch(platillosConDespensaProvider)
            .when(
              loading: () => const EstadoCargando(),
              error: (_, _) => EstadoError(
                mensaje: 'No pudimos leer la despensa.',
                alReintentar: () => ref.invalidate(platillosConDespensaProvider),
              ),
              data: (lista) {
                final cocinables = [for (final x in lista) if (x.cocinable) x];
                final casi = [
                  for (final x in lista)
                    if (!x.cocinable && x.faltantes.length <= 2) x,
                ];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Con lo que hay en tu despensa',
                      style: v.titulo(tamano: 18, color: v.etiqueta),
                    ),
                    if (cocinables.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          key: const Key('sin_cocinables'),
                          'Con tu despensa de hoy no alcanza para un platillo completo.',
                          style: v.lectura(tamano: 15, color: v.textoTenue),
                        ),
                      ),
                    for (final x in cocinables)
                      ListTile(
                        key: Key('cocinable_${x.platillo.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(x.platillo.nombre),
                      ),
                    if (casi.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 4),
                        child: Text(
                          'Te falta poco',
                          style: v.titulo(tamano: 18, color: v.etiqueta),
                        ),
                      ),
                      for (final x in casi)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(x.platillo.nombre),
                          subtitle: Text('Falta: ${x.faltantes.join(', ')}'),
                        ),
                    ],
                    const Divider(height: 32),
                    Text(
                      'Ideas con IA',
                      style: v.titulo(tamano: 18, color: v.etiqueta),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      key: const Key('aviso_ia'),
                      'A la IA solo se envían los nombres de tus ingredientes, '
                      'cantidades aproximadas y lo que escribas aquí. Nada de '
                      'salud, dinero ni cuentas.',
                      style: v.lectura(tamano: 14, color: v.textoTenue),
                    ),
                    TextField(
                      key: const Key('preferencias_ia'),
                      controller: _preferencias,
                      maxLength: maxCaracteresPreferencias,
                      decoration: const InputDecoration(
                        labelText: 'Preferencias (opcional)',
                        hintText: 'Algo rápido, sin horno...',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        key: const Key('sugerir_ia'),
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(_pidiendo ? 'Pensando...' : 'Sugerir con IA'),
                        onPressed: _pidiendo ? null : _sugerir,
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(key: const Key('error_ia'), _error!),
                      ),
                    for (var i = 0; i < _sugeridas.length; i++)
                      _TarjetaSugerida(
                        indice: i,
                        receta: _sugeridas[i],
                        guardada: _guardadas.contains(_sugeridas[i].id),
                        alGuardar: editar ? () => _guardar(_sugeridas[i]) : null,
                      ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

class _TarjetaSugerida extends StatelessWidget {
  const _TarjetaSugerida({
    required this.indice,
    required this.receta,
    required this.guardada,
    required this.alGuardar,
  });
  final int indice;
  final Platillo receta;
  final bool guardada;
  final VoidCallback? alGuardar;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('sugerida_$indice'),
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receta.nombre,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Sugerida por la IA, sin guardar · ${receta.porciones} porciones',
          ),
          const SizedBox(height: 4),
          for (final ing in receta.ingredientes)
            Text('· ${ing.nombre}: ${cantidadTexto(ing.cantidad)} ${ing.unidad}'),
          if (receta.pasos.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (var n = 0; n < receta.pasos.length; n++)
              Text('${n + 1}. ${receta.pasos[n]}'),
          ],
          const SizedBox(height: 8),
          if (guardada)
            const Text('Receta guardada')
          else if (alGuardar != null)
            FilledButton(
              key: Key('guardar_sugerida_$indice'),
              onPressed: alGuardar,
              child: const Text('Guardar receta'),
            ),
        ],
      ),
    ),
  );
}
