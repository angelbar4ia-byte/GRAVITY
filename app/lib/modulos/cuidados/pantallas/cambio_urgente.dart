/// Cambio urgente (dueño): suspender o agregar un medicamento con una nota.
/// El servidor avisa al instante a quien está de turno (D4); aquí se ve si lo
/// atendieron ("Enterada").
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

class PantallaCambioUrgente extends ConsumerStatefulWidget {
  const PantallaCambioUrgente({super.key});

  @override
  ConsumerState<PantallaCambioUrgente> createState() => _EstadoCambio();
}

class _EstadoCambio extends ConsumerState<PantallaCambioUrgente> {
  AccionCambio _accion = AccionCambio.suspender;
  String? _medId;
  final _nombre = TextEditingController();
  final _nota = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final ok = await ejecutarCuidados(
      context,
      ref,
      () => ref
          .read(servicioCuidadosProvider)
          .crearCambioUrgente(
            accion: _accion,
            nota: _nota.text,
            medicamentoId: _accion == AccionCambio.suspender ? _medId : null,
            medicamentoNombre: _accion == AccionCambio.agregar
                ? _nombre.text
                : ref
                      .read(medicamentosProvider)
                      .value
                      ?.where((m) => m.id == _medId)
                      .firstOrNull
                      ?.nombre,
          ),
      ok: 'Aviso enviado a quien está de turno',
    );
    if (ok) {
      _nota.clear();
      _nombre.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(permisosCuidadosProvider);
    final t = Theme.of(context).textTheme;
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Cambio urgente',
        cuerpo: !p.creaCambioUrgente
            ? const SinAccesoCuidados()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<AccionCambio>(
                    segments: [
                      for (final a in AccionCambio.values)
                        ButtonSegment(value: a, label: Text(a.etiqueta)),
                    ],
                    selected: {_accion},
                    onSelectionChanged: (s) =>
                        setState(() => _accion = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (_accion == AccionCambio.suspender)
                    cuando(
                      ref.watch(medicamentosProvider),
                      () => ref.invalidate(medicamentosProvider),
                      (meds) => DropdownButtonFormField<String>(
                        initialValue: _medId,
                        decoration: const InputDecoration(
                          labelText: 'Medicamento',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final m in meds)
                            DropdownMenuItem(
                              value: m.id,
                              child: Text(m.nombre),
                            ),
                        ],
                        onChanged: (v) => setState(() => _medId = v),
                      ),
                    )
                  else
                    TextField(
                      controller: _nombre,
                      decoration: const InputDecoration(
                        labelText: 'Medicamento a agregar',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nota,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Nota',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BotonGrande(
                    texto: 'Enviar aviso',
                    icono: Icons.send,
                    onPressed: _enviar,
                  ),
                  const SizedBox(height: 24),
                  Text('Enviados', style: t.titleLarge),
                  cuando(
                    ref.watch(cambiosUrgentesProvider),
                    () => ref.invalidate(cambiosUrgentesProvider),
                    (cambios) => cambios.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Todavía no hay cambios urgentes.'),
                          )
                        : Column(
                            children: [
                              for (final c in cambios)
                                ListTile(
                                  leading: Icon(
                                    c.atendido
                                        ? Icons.done_all
                                        : Icons.hourglass_empty,
                                  ),
                                  title: Text(c.texto),
                                  subtitle: Text(
                                    !c.atendido
                                        ? 'Sin atender todavía'
                                        : (c.atendidoNombre ?? '').isEmpty
                                        ? 'Atendido a las ${horaTexto(c.atendidoEn!)}'
                                        : 'Atendido por ${c.atendidoNombre} a las ${horaTexto(c.atendidoEn!)}',
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
