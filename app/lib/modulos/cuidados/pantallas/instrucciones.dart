/// Instrucciones para la cuidadora principal (spec §8f, v1.4).
///
/// - Dueño, hermana y pareja: formulario corto (1 a 500 letras) que llama a
///   `cui_dejar_instruccion`. El texto viaja solo al servidor: no se guarda
///   en ningún registro local y el aviso de éxito no lo repite (D3).
/// - Cuidadora principal: lista, solo lectura, de las instrucciones que le
///   llegan y de sus propias notas.
/// - Cuidadora y cuenta maestra no dejan instrucciones.
///
/// La app solo oculta; el servidor decide. Textos sobrios, sin nombres de
/// medicamentos: pueden verse en un bloqueo de pantalla.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/pantallas/marco_pantalla.dart';
import '../../../diseno/diseno.dart';
import '../../../nucleo/contratos/roles.dart';
import '../datos/modelos.dart';
import '../estado/proveedores.dart';
import 'comunes.dart';

/// Tope del servidor (`cui_dejar_instruccion`).
const topeInstruccion = 500;

class PantallaInstrucciones extends ConsumerWidget {
  const PantallaInstrucciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(permisosCuidadosProvider);
    return TemaModulo(
      modulo: Modulo.cuidados,
      child: MarcoPantalla(
        titulo: 'Instrucciones',
        cuerpo: p.dejaInstruccion
            ? const FormularioInstruccion()
            : p.veInstruccionesRecibidas
            ? const _ListaInstrucciones()
            : const SinAccesoCuidados(),
      ),
    );
  }
}

/// Formulario corto. Tras enviar, el campo se vacía y el texto no queda en
/// pantalla ni en el aviso.
class FormularioInstruccion extends ConsumerStatefulWidget {
  const FormularioInstruccion({super.key});

  @override
  ConsumerState<FormularioInstruccion> createState() =>
      _FormularioInstruccionState();
}

class _FormularioInstruccionState extends ConsumerState<FormularioInstruccion> {
  final _texto = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    final ok = await ejecutarCuidados(
      context,
      ref,
      () => ref.read(servicioCuidadosProvider).dejarInstruccion(t),
      ok: 'Instrucción enviada',
    );
    if (!mounted) return;
    if (ok) _texto.clear();
    setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Instrucción para la cuidadora', style: t.titleLarge),
        const SizedBox(height: 8),
        Text('La verá en su teléfono en su próximo turno.', style: t.bodyLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _texto,
          minLines: 4,
          maxLines: 8,
          maxLength: topeInstruccion,
          style: const TextStyle(fontSize: 20),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Instrucción',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        BotonGrande(
          texto: 'Enviar instrucción',
          icono: Icons.send_outlined,
          onPressed: _texto.text.trim().isEmpty || _enviando ? null : _enviar,
        ),
      ],
    );
  }
}

class _ListaInstrucciones extends ConsumerWidget {
  const _ListaInstrucciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return cuando(
      ref.watch(instruccionesRecibidasProvider),
      () => ref.invalidate(instruccionesRecibidasProvider),
      (entradas) => entradas.isEmpty
          ? const EstadoVacio(
              mensaje: 'Sin instrucciones por ahora',
              icono: Icons.assignment_outlined,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final e in entradas)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        e.tipo == TipoBitacora.instruccion
                            ? Icons.assignment_outlined
                            : Icons.edit_note_outlined,
                      ),
                      title: Text(e.texto, style: t.titleMedium),
                      subtitle: Text(
                        '${e.tipo == TipoBitacora.instruccion ? 'Instrucción' : 'Nota propia'}'
                        ' · ${e.autorNombre} · ${diaLargo(e.creadaEn)} ${horaTexto(e.creadaEn)}',
                        style: t.bodyMedium,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
