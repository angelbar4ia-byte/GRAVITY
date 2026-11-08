/// Ajustes › Hábitos › Nube cifrada (P5 del dueño, E7 de la Fase 4; D13, D21).
///
/// Por omisión **todo se queda solo en el teléfono** (decisión del dueño): esta
/// pantalla existe para que la nube cifrada no quede a medias, y no cambia el
/// modo por sí sola. Qué se puede hacer:
///
/// - **Activar** la nube con la frase de 12 palabras: se muestra una vez (sin
///   capturas, sin copiar), se confirma con 3 palabras al azar y se pasan los
///   tipos elegidos a `nube_cifrada`.
/// - **Añadir este equipo** a una nube ya activada: se escribe la frase.
/// - **Volver a solo teléfono** un tipo (avisa que se borra de la nube).
/// - **Cambiar** y **verificar** la frase.
/// - **Reiniciar la nube** si se perdió la frase y ningún equipo tiene la llave.
///
/// Todo detrás de la puerta reservada (PIN). Solo donde el equipo puede tener
/// llaves (no en la tablet pública de la casa). La lógica está en
/// `nucleo/sensibles/nube_cifrada.dart`; aquí solo se pregunta y se muestra.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/avisos/con_avisos.dart' show tipoEquipoAvisosProvider;
import '../../../app/pantalla_segura.dart' show PantallaSegura;
import '../../../app/sensibles/puerta_reservada.dart';
import '../../../app/sensibles/sensibles.dart';
import '../../../app/sesion_efectiva.dart';
import '../../../nucleo/permisos/permisos.dart' show puedeUsarHabitos;
import '../../../nucleo/seguridad/montos.dart';
import '../../../nucleo/sensibles/llaves_habitos.dart';
import '../../../nucleo/sensibles/nube_cifrada.dart';
import '../marco_seccion.dart';
import '../secciones_ajustes.dart';

/// Palabra que se escribe para reiniciar la nube.
const palabraDeReinicio = 'REINICIAR';

String nombreDelTipo(TipoSensible tipo) => switch (tipo) {
  TipoSensible.habitosSensibles => 'Hábitos a eliminar y consumo',
  TipoSensible.diarioOracion => 'Diario y oración',
};

class PantallaHabitosAjustes extends ConsumerWidget {
  const PantallaHabitosAjustes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionEfectivaProvider);
    final tipo = ref.watch(tipoEquipoAvisosProvider);
    final puede =
        sesion != null &&
        puedeUsarHabitos(sesion.rol, esMaestra: sesion.esMaestra) &&
        equipoPuedeTenerLlaves(tipo);
    return MarcoSeccion(
      seccion: SeccionAjustes.habitos,
      hijos: [
        if (!puede)
          const NotaAjustes(
            'Esto no está disponible en este equipo ni con esta cuenta.',
            icono: Icons.lock_outline,
          )
        else
          const PuertaReservada(child: SeccionNubeCifrada()),
      ],
    );
  }
}

class SeccionNubeCifrada extends ConsumerStatefulWidget {
  const SeccionNubeCifrada({super.key});

  @override
  ConsumerState<SeccionNubeCifrada> createState() => _SeccionNubeCifradaState();
}

class _SeccionNubeCifradaState extends ConsumerState<SeccionNubeCifrada> {
  Future<EstadoNubeEnEquipo>? _estado;
  bool _trabajando = false;
  String? _avisoDeEpoca;

  String? get _persona => ref.read(sesionEfectivaProvider)?.persona.id;

  @override
  void initState() {
    super.initState();
    _estado = _cargar()..ignore();
  }

  Future<EstadoNubeEnEquipo> _cargar() async {
    final nube = ref.read(nubeCifradaHabitosProvider);
    final persona = _persona;
    if (nube == null || persona == null) {
      return const EstadoNubeEnEquipo(modos: {}, tieneLlave: false);
    }
    // Otro equipo pudo reiniciar la nube o volver a "solo teléfono".
    if (await nube.revisarEpoca(persona)) {
      _avisoDeEpoca =
          'Otro de tus equipos cambió la nube cifrada. Este equipo se '
          'actualizó y quitó la copia que ya no sirve.';
    }
    return nube.estado(persona);
  }

  void _recargar() {
    final estado = _cargar()..ignore();
    setState(() {
      _estado = estado;
    });
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// En la laptop y la tablet personal las llaves van cifradas con el PIN: se
  /// pide para poder guardarlas. En el teléfono no hace falta. Devuelve
  /// `(sigue, pin)`.
  Future<(bool, String?)> _pin() async {
    final tipo = ref.read(tipoEquipoAvisosProvider);
    if (!llavesVanConPin(tipo)) return (true, null);
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoTexto(
        titulo: 'Tu PIN',
        mensaje:
            'En este equipo las llaves de Hábitos se guardan cifradas con tu '
            'PIN. Escríbelo para continuar.',
        etiqueta: 'PIN',
        boton: 'Continuar',
        oculto: true,
        soloNumeros: true,
      ),
    );
    if (pin == null || pin.isEmpty || !mounted) return (false, null);
    final r = await ref.read(controladorMontosProvider.notifier).verificar(pin);
    if (r == ResultadoRevelar.revelado) return (true, pin);
    _aviso(
      r == ResultadoRevelar.bloqueado
          ? 'Demasiados intentos. Espera un momento.'
          : 'Ese PIN no es el correcto.',
    );
    return (false, null);
  }

  Future<void> _hacer(Future<void> Function() accion, String listo) async {
    setState(() => _trabajando = true);
    try {
      await accion();
      _aviso(listo);
    } on ErrorNubeCifrada catch (error) {
      _aviso(error.mensaje);
    } on LlaveBloqueada {
      _aviso('Escribe tu PIN para abrir las llaves de este equipo.');
    } catch (_) {
      _aviso('No se pudo. No se cambió nada; vuelve a intentar.');
    } finally {
      if (mounted) {
        setState(() => _trabajando = false);
        _recargar();
      }
    }
  }

  // ----------------------------------------------------------------- acciones

  Future<void> _activar() async {
    final persona = _persona;
    final nube = ref.read(nubeCifradaHabitosProvider);
    if (persona == null || nube == null) return;
    final tipos = await showDialog<Set<TipoSensible>>(
      context: context,
      builder: (_) => const _DialogoElegirTipos(),
    );
    if (tipos == null || tipos.isEmpty || !mounted) return;
    final frase = FraseDeRecuperacion.generar();
    final confirmada = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoFrase(frase: frase),
    );
    if (confirmada != true || !mounted) return;
    final (sigue, pin) = await _pin();
    if (!sigue) return;
    await _hacer(
      () => nube.activar(persona, frase, tipos: tipos, pin: pin),
      'Listo: la nube cifrada quedó activada. Lo guardarás con tu frase.',
    );
  }

  Future<void> _anadirEquipo() async {
    final persona = _persona;
    final nube = ref.read(nubeCifradaHabitosProvider);
    if (persona == null || nube == null) return;
    final frase = await _pedirFrase(
      'Añadir este equipo',
      'Escribe tus 12 palabras para que este equipo pueda abrir lo de la nube.',
    );
    if (frase == null || !mounted) return;
    final (sigue, pin) = await _pin();
    if (!sigue) return;
    await _hacer(
      () => nube.anadirEquipo(persona, frase, pin: pin),
      'Listo: este equipo ya tiene la llave de la nube.',
    );
  }

  Future<void> _cambiarFrase() async {
    final persona = _persona;
    final nube = ref.read(nubeCifradaHabitosProvider);
    if (persona == null || nube == null) return;
    final frase = FraseDeRecuperacion.generar();
    final confirmada = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoFrase(frase: frase, esCambio: true),
    );
    if (confirmada != true || !mounted) return;
    final (sigue, pin) = await _pin();
    if (!sigue) return;
    await _hacer(
      () => nube.cambiarFrase(persona, frase, pin: pin),
      'Listo: tu frase nueva ya funciona. La anterior dejó de servir.',
    );
  }

  Future<void> _verificarFrase() async {
    final nube = ref.read(nubeCifradaHabitosProvider);
    if (nube == null) return;
    final frase = await _pedirFrase(
      'Verificar mi frase',
      'Escribe tus 12 palabras. No se guardan; solo se comprueba que abren la '
          'llave.',
    );
    if (frase == null || !mounted) return;
    await _hacer(() async {
      final ok = await nube.verificarFrase(frase);
      if (!ok) throw ErrorNubeCifrada.fraseIncorrecta;
    }, 'Tu frase es correcta.');
  }

  Future<void> _volverASoloTelefono(TipoSensible tipo) async {
    final persona = _persona;
    final nube = ref.read(nubeCifradaHabitosProvider);
    if (persona == null || nube == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Volver a solo teléfono: ${nombreDelTipo(tipo)}'),
        content: const Text(
          'Se borrará de la nube y la laptop dejará de verlo. Antes, este '
          'equipo trae todo lo que le falte para no perder nada. ¿Seguimos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirmar-solo-telefono'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Volver a solo teléfono'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final (sigue, pin) = await _pin();
    if (!sigue) return;
    await _hacer(
      () => nube.volverASoloTelefono(persona, tipo, pin: pin),
      '${nombreDelTipo(tipo)}: otra vez solo en este equipo.',
    );
  }

  Future<void> _reiniciar() async {
    final persona = _persona;
    final nube = ref.read(nubeCifradaHabitosProvider);
    if (persona == null || nube == null) return;
    final palabra = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoTexto(
        titulo: 'Reiniciar la nube',
        mensaje:
            'Úsalo solo si perdiste la frase y ningún equipo tiene la llave. '
            'Se borra TODO lo de la nube y la llave; lo que este equipo pueda '
            'abrir se conserva aquí. Escribe $palabraDeReinicio para '
            'confirmar.',
        etiqueta: palabraDeReinicio,
        boton: 'Reiniciar',
      ),
    );
    if (palabra == null || !mounted) return;
    if (palabra.trim() != palabraDeReinicio) {
      _aviso('No escribiste $palabraDeReinicio; no se cambió nada.');
      return;
    }
    final (sigue, pin) = await _pin();
    if (!sigue) return;
    await _hacer(
      () => nube.reiniciar(persona, pin: pin),
      'Listo: la nube se reinició. Todo está solo en este equipo.',
    );
  }

  Future<List<String>?> _pedirFrase(String titulo, String mensaje) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoTexto(
        titulo: titulo,
        mensaje: mensaje,
        etiqueta: '12 palabras',
        boton: 'Continuar',
        oculto: true,
      ),
    );
    if (texto == null || !mounted) return null;
    final frase = FraseDeRecuperacion.normalizar(texto);
    if (!FraseDeRecuperacion.esValida(frase)) {
      _aviso('Esa frase no es válida. Revisa las 12 palabras.');
      return null;
    }
    return frase;
  }

  // -------------------------------------------------------------------- vista

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nube = ref.watch(nubeCifradaHabitosProvider);
    return Card(
      key: const ValueKey('ajustes-nube-cifrada'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nube cifrada', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Por ahora todo está solo en tu equipo. Si activas la nube, lo '
              'sensible se cifra aquí antes de subirse: el servidor no puede '
              'leerlo y solo tu frase de 12 palabras lo recupera en otro '
              'equipo. Nadie más la tiene.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (nube == null)
              const Text(
                'La nube cifrada estará disponible cuando haya servidor.',
                key: ValueKey('nube-sin-servidor'),
              )
            else
              FutureBuilder<EstadoNubeEnEquipo>(
                future: _estado,
                builder: (context, instantanea) {
                  if (instantanea.hasError) {
                    return const Text('No se pudo leer el estado de la nube.');
                  }
                  final estado = instantanea.data;
                  if (estado == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  return _Contenido(
                    estado: estado,
                    aviso: _avisoDeEpoca,
                    trabajando: _trabajando,
                    alActivar: _activar,
                    alAnadirEquipo: _anadirEquipo,
                    alCambiarFrase: _cambiarFrase,
                    alVerificarFrase: _verificarFrase,
                    alVolver: _volverASoloTelefono,
                    alReiniciar: _reiniciar,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.estado,
    required this.aviso,
    required this.trabajando,
    required this.alActivar,
    required this.alAnadirEquipo,
    required this.alCambiarFrase,
    required this.alVerificarFrase,
    required this.alVolver,
    required this.alReiniciar,
  });

  final EstadoNubeEnEquipo estado;
  final String? aviso;
  final bool trabajando;
  final VoidCallback alActivar;
  final VoidCallback alAnadirEquipo;
  final VoidCallback alCambiarFrase;
  final VoidCallback alVerificarFrase;
  final ValueChanged<TipoSensible> alVolver;
  final VoidCallback alReiniciar;

  @override
  Widget build(BuildContext context) {
    final sinSenal = estado.servidor == null;
    final hayNube = estado.hayNubeEnServidor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aviso != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(aviso!, key: const ValueKey('nube-aviso-epoca')),
          ),
        for (final tipo in TipoSensible.values)
          ListTile(
            key: ValueKey('nube-tipo-${tipo.valor}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              estado.modoDe(tipo) == ModoSensible.nubeCifrada
                  ? Icons.cloud_done_outlined
                  : Icons.phone_android_outlined,
            ),
            title: Text(nombreDelTipo(tipo)),
            subtitle: Text(
              estado.modoDe(tipo) == ModoSensible.nubeCifrada
                  ? 'En la nube cifrada'
                  : 'Solo en este equipo',
            ),
            trailing: estado.modoDe(tipo) == ModoSensible.nubeCifrada
                ? TextButton(
                    key: ValueKey('volver-${tipo.valor}'),
                    onPressed: trabajando ? null : () => alVolver(tipo),
                    child: const Text('Volver a solo teléfono'),
                  )
                : null,
          ),
        if (sinSenal)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin conexión: puedes ver el estado, pero para cambiar algo '
              'hace falta señal.',
              key: ValueKey('nube-sin-senal'),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Activar: la nube aún no existe, o existe y este equipo ya
            // tiene la llave (para pasar otro tipo).
            if ((!hayNube || estado.tieneLlave) &&
                TipoSensible.values.any(
                  (t) => estado.modoDe(t) != ModoSensible.nubeCifrada,
                ))
              FilledButton.icon(
                key: const ValueKey('nube-activar'),
                onPressed: trabajando || sinSenal ? null : alActivar,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Activar la nube cifrada'),
              ),
            if (hayNube && !estado.tieneLlave)
              FilledButton.icon(
                key: const ValueKey('nube-anadir-equipo'),
                onPressed: trabajando || sinSenal ? null : alAnadirEquipo,
                icon: const Icon(Icons.add_to_home_screen_outlined),
                label: const Text('Añadir este equipo'),
              ),
            if (hayNube) ...[
              if (estado.tieneLlave)
                OutlinedButton(
                  key: const ValueKey('nube-cambiar-frase'),
                  onPressed: trabajando || sinSenal ? null : alCambiarFrase,
                  child: const Text('Cambiar la frase'),
                ),
              OutlinedButton(
                key: const ValueKey('nube-verificar-frase'),
                onPressed: trabajando || sinSenal ? null : alVerificarFrase,
                child: const Text('Verificar mi frase'),
              ),
              TextButton(
                key: const ValueKey('nube-reiniciar'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: trabajando || sinSenal ? null : alReiniciar,
                child: const Text('Reiniciar la nube'),
              ),
            ],
          ],
        ),
        if (trabajando)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _DialogoElegirTipos extends StatefulWidget {
  const _DialogoElegirTipos();

  @override
  State<_DialogoElegirTipos> createState() => _DialogoElegirTiposState();
}

class _DialogoElegirTiposState extends State<_DialogoElegirTipos> {
  final Set<TipoSensible> _tipos = {...TipoSensible.values};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Activar la nube cifrada'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Elige qué se guarda en la nube. Se cifra en tu equipo con una '
            'llave que solo tu frase de 12 palabras puede recuperar. Si la '
            'pierdes y ningún equipo tiene la llave, la nube no se puede '
            'recuperar.',
          ),
          const SizedBox(height: 8),
          for (final tipo in TipoSensible.values)
            CheckboxListTile(
              key: ValueKey('nube-elegir-${tipo.valor}'),
              contentPadding: EdgeInsets.zero,
              value: _tipos.contains(tipo),
              title: Text(nombreDelTipo(tipo)),
              onChanged: (v) => setState(
                () => v == true ? _tipos.add(tipo) : _tipos.remove(tipo),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('nube-elegir-continuar'),
        onPressed: _tipos.isEmpty ? null : () => Navigator.pop(context, _tipos),
        child: const Text('Continuar'),
      ),
    ],
  );
}

/// Muestra la frase **una vez** (sin capturas ni copiar) y la confirma con 3
/// palabras al azar. Devuelve `true` si se confirmó.
class _DialogoFrase extends StatefulWidget {
  const _DialogoFrase({required this.frase, this.esCambio = false});

  final List<String> frase;
  final bool esCambio;

  @override
  State<_DialogoFrase> createState() => _DialogoFraseState();
}

class _DialogoFraseState extends State<_DialogoFrase> {
  late final List<int> _posiciones =
      FraseDeRecuperacion.posicionesDeConfirmacion();
  late final List<TextEditingController> _respuestas = [
    for (final _ in _posiciones) TextEditingController(),
  ];
  bool _confirmando = false;
  String? _error;

  @override
  void dispose() {
    for (final r in _respuestas) {
      r.dispose();
    }
    super.dispose();
  }

  void _confirmar() {
    final ok = FraseDeRecuperacion.confirma(widget.frase, _posiciones, [
      for (final r in _respuestas) r.text,
    ]);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Alguna palabra no coincide. Revisa tu papel.');
    }
  }

  @override
  Widget build(BuildContext context) => PantallaSegura(
    activa: true,
    child: AlertDialog(
      title: Text(
        widget.esCambio ? 'Tu frase nueva' : 'Tu frase de recuperación',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_confirmando) ...[
              const Text(
                'Anótala en papel, en este orden. No hay copia en ningún '
                'otro lado y no se puede copiar de aquí.',
              ),
              const SizedBox(height: 12),
              Wrap(
                key: const ValueKey('nube-frase'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < widget.frase.length; i++)
                    Chip(label: Text('${i + 1}. ${widget.frase[i]}')),
                ],
              ),
            ] else ...[
              const Text('Para estar seguros, escribe estas palabras:'),
              const SizedBox(height: 8),
              for (var i = 0; i < _posiciones.length; i++)
                TextField(
                  key: ValueKey('nube-confirma-$i'),
                  controller: _respuestas[i],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Palabra ${_posiciones[i] + 1}',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    key: const ValueKey('nube-confirma-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        if (!_confirmando)
          FilledButton(
            key: const ValueKey('nube-ya-anote'),
            onPressed: () => setState(() => _confirmando = true),
            child: const Text('Ya la anoté'),
          )
        else
          FilledButton(
            key: const ValueKey('nube-confirmar'),
            onPressed: _confirmar,
            child: const Text('Confirmar'),
          ),
      ],
    ),
  );
}

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.mensaje,
    required this.etiqueta,
    required this.boton,
    this.oculto = false,
    this.soloNumeros = false,
  });

  final String titulo;
  final String mensaje;
  final String etiqueta;
  final String boton;
  final bool oculto;
  final bool soloNumeros;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.mensaje),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('dialogo-texto'),
          controller: _texto,
          obscureText: widget.oculto,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: widget.soloNumeros ? TextInputType.number : null,
          maxLength: widget.soloNumeros ? 6 : null,
          inputFormatters: widget.soloNumeros
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(labelText: widget.etiqueta),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _texto.text),
        child: Text(widget.boton),
      ),
    ],
  );
}
