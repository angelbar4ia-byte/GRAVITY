/// **Hoja de registro de la salida** (B4, 4.5, F-B3 y F-B4): hora, duración,
/// distancia que **escribe la persona**, tipo de ruta (calle, terreno o
/// mixta), esfuerzo percibido de 1 a 5, clima y «Salí acompañado».
///
/// Con todo como se planeó son **3 toques** (*Registrar lo que hice*, *Todo
/// como estaba planeado*, *Guardar*). Todos los campos son opcionales. La
/// distancia no se valida contra un mapa: la app dice de dónde sacarla. La
/// hoja solo muestra y avisa; quien la arma guarda. Se llena **parado**.
library;

import 'package:flutter/material.dart';

import '../componentes/tarjeta_modulo.dart';
import '../valores_diseno.dart';
import 'clima.dart';
import 'piezas_bici.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// La hoja de registro. Es un formulario **controlado**: lo que se elige vive
/// en quien la arma (la pantalla de B5), que responde a cada aviso con una
/// hoja nueva.
class HojaRegistroSalida extends StatefulWidget {
  const HojaRegistroSalida({
    super.key,
    required this.fechaTexto,
    required this.horaTexto,
    required this.duracionTexto,
    this.distanciaTexto = '',
    this.bicicletaTexto,
    this.superficie,
    this.esfuerzo,
    this.clima,
    this.respuestaClimaTexto,
    this.acompanado = false,
    this.alMenosDuracion,
    this.alMasDuracion,
    this.alCambiarHora,
    this.alCambiarFecha,
    this.alCambiarDistancia,
    this.alElegirSuperficie,
    this.alElegirEsfuerzo,
    this.alElegirClima,
    this.alCambiarAcompanado,
    this.alTodoComoPlaneado,
    this.alGuardar,
    this.alCancelar,
    this.estado = EstadoVistaBici.listo,
    this.mensajes = const MensajesEstadoBici(
      vacio: 'No hay una salida para registrar.',
      cargando: 'Guardando…',
      sinConexion: 'Sin conexión. Se guarda en este equipo y se sube después.',
      error: 'No se pudo guardar. Tus datos siguen aquí; intenta otra vez.',
    ),
    this.alReintentar,
  });

  /// «Sábado 28 nov».
  final String fechaTexto;

  /// «8:00».
  final String horaTexto;

  /// «4 h 00 min».
  final String duracionTexto;

  /// Lo que la persona escribió, en kilómetros («62,4»). Vacío no se guarda.
  final String distanciaTexto;

  /// «Mi bici».
  final String? bicicletaTexto;
  final SuperficieSalida? superficie;

  /// De 1 a 5; `null` si no lo dijo.
  final int? esfuerzo;
  final ClimaBici? clima;
  final String? respuestaClimaTexto;
  final bool acompanado;
  final VoidCallback? alMenosDuracion;
  final VoidCallback? alMasDuracion;
  final VoidCallback? alCambiarHora;

  /// Para registrar una salida de otro día (la del domingo por lluvia).
  final VoidCallback? alCambiarFecha;
  final ValueChanged<String>? alCambiarDistancia;
  final ValueChanged<SuperficieSalida?>? alElegirSuperficie;
  final ValueChanged<int?>? alElegirEsfuerzo;
  final ValueChanged<ClimaBici?>? alElegirClima;
  final ValueChanged<bool>? alCambiarAcompanado;

  /// *Todo como estaba planeado*: 1 toque.
  final VoidCallback? alTodoComoPlaneado;
  final VoidCallback? alGuardar;
  final VoidCallback? alCancelar;
  final EstadoVistaBici estado;
  final MensajesEstadoBici mensajes;
  final VoidCallback? alReintentar;

  @override
  State<HojaRegistroSalida> createState() => _EstadoHoja();
}

class _EstadoHoja extends State<HojaRegistroSalida> {
  late final TextEditingController _distancia;

  @override
  void initState() {
    super.initState();
    _distancia = TextEditingController(text: widget.distanciaTexto);
  }

  @override
  void didUpdateWidget(HojaRegistroSalida anterior) {
    super.didUpdateWidget(anterior);
    // Si quien arma la hoja cambia el texto (no el que se está escribiendo),
    // lo reflejamos sin mover el cursor de lo que la persona teclea.
    if (widget.distanciaTexto != anterior.distanciaTexto &&
        widget.distanciaTexto != _distancia.text) {
      _distancia.text = widget.distanciaTexto;
    }
  }

  @override
  void dispose() {
    _distancia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    final w = widget;
    if (w.estado != EstadoVistaBici.listo) {
      return TarjetaModulo(
        titulo: 'Registrar la salida',
        icono: Icons.edit_note,
        child: CuerpoEstadoBici(
          estado: w.estado,
          mensajes: w.mensajes,
          alReintentar: w.alReintentar,
        ),
      );
    }
    final esfuerzo = w.esfuerzo;
    return TarjetaModulo(
      titulo: 'Registrar la salida',
      icono: Icons.edit_note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label:
                '${w.fechaTexto}, ${w.horaTexto}'
                '${w.bicicletaTexto == null ? '' : ', ${w.bicicletaTexto}'}',
            excludeSemantics: true,
            child: Wrap(
              spacing: e * 2,
              runSpacing: e * 0.5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(w.fechaTexto, style: v.titulo(tamano: 20)),
                Text(
                  w.horaTexto,
                  style: v.numero(
                    tamano: 20,
                    peso: FontWeight.w700,
                    color: v.textoFuerte,
                  ),
                ),
                if (w.bicicletaTexto != null)
                  Text(
                    w.bicicletaTexto!,
                    style: v.lectura(tamano: 14.5, color: v.textoTenue),
                  ),
              ],
            ),
          ),
          if (w.alCambiarFecha != null || w.alCambiarHora != null)
            Wrap(
              spacing: e,
              children: [
                if (w.alCambiarFecha != null)
                  TextButton.icon(
                    onPressed: w.alCambiarFecha,
                    icon: const Icon(Icons.event, size: 18),
                    label: const Text('Otro día'),
                  ),
                if (w.alCambiarHora != null)
                  TextButton.icon(
                    onPressed: w.alCambiarHora,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('Cambiar la hora'),
                  ),
              ],
            ),
          SizedBox(height: e * 1.5),
          if (w.alTodoComoPlaneado != null) ...[
            FilledButton.icon(
              key: const ValueKey('registro-todo-planeado'),
              onPressed: w.alTodoComoPlaneado,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(altoAccionBici),
              ),
              icon: const Icon(Icons.done_all, size: 24),
              label: const Text(TextosBici.todoComoEstabaPlaneado),
            ),
            SizedBox(height: e * 2),
          ],
          SelectorPasosBici(
            etiqueta: 'DURACIÓN',
            valorTexto: w.duracionTexto,
            descripcionAccesible: 'Duración: ${w.duracionTexto}',
            etiquetaMenos: 'Quitar 15 minutos',
            etiquetaMas: 'Agregar 15 minutos',
            alMenos: w.alMenosDuracion,
            alMas: w.alMasDuracion,
          ),
          SizedBox(height: e * 2),
          TextField(
            key: const ValueKey('registro-distancia'),
            controller: _distancia,
            enabled: w.alCambiarDistancia != null,
            onChanged: w.alCambiarDistancia,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Distancia en km (opcional)',
              helperText:
                  'Escribe lo que marque tu ciclocomputador o tu app. GRAVITY '
                  'no la revisa contra un mapa.',
              helperMaxLines: 3,
            ),
          ),
          SizedBox(height: e * 2),
          Text('TIPO DE RUTA', style: v.etiquetaPanel()),
          SizedBox(height: e),
          Wrap(
            spacing: e,
            runSpacing: e,
            children: [
              for (final s in SuperficieSalida.values)
                OpcionBici(
                  texto: s.texto,
                  icono: s.icono,
                  seleccionada: w.superficie == s,
                  etiquetaAccesible: 'Tipo de ruta: ${s.texto}',
                  alTocar: w.alElegirSuperficie == null
                      ? null
                      : () => w.alElegirSuperficie!(
                          w.superficie == s ? null : s,
                        ),
                ),
            ],
          ),
          SizedBox(height: e * 2),
          Text('ESFUERZO PERCIBIDO (OPCIONAL)', style: v.etiquetaPanel()),
          SizedBox(height: e),
          Wrap(
            spacing: e,
            runSpacing: e,
            children: [
              for (var n = 1; n <= 5; n++)
                OpcionBici(
                  texto: '$n',
                  seleccionada: esfuerzo == n,
                  etiquetaAccesible:
                      'Esfuerzo $n de 5, ${TextosBici.esfuerzos[n - 1].toLowerCase()}',
                  alTocar: w.alElegirEsfuerzo == null
                      ? null
                      : () => w.alElegirEsfuerzo!(esfuerzo == n ? null : n),
                ),
            ],
          ),
          SizedBox(height: e * 0.75),
          Text(
            esfuerzo == null
                ? '1 muy ligero · 5 al límite'
                : '$esfuerzo de 5: ${TextosBici.esfuerzos[esfuerzo - 1].toLowerCase()}',
            key: const ValueKey('registro-esfuerzo-texto'),
            style: v.lectura(tamano: 14, color: v.textoTenue),
          ),
          SizedBox(height: e * 2),
          Text('CLIMA (OPCIONAL)', style: v.etiquetaPanel()),
          SizedBox(height: e),
          CasillasClima(
            conTarjeta: false,
            seleccionado: w.clima,
            respuestaTexto: w.respuestaClimaTexto,
            alElegir: w.alElegirClima,
          ),
          SizedBox(height: e * 1.5),
          _FilaAcompanado(
            valor: w.acompanado,
            alCambiar: w.alCambiarAcompanado,
          ),
          SizedBox(height: e * 2),
          Wrap(
            spacing: e,
            runSpacing: e,
            children: [
              FilledButton(
                key: const ValueKey('registro-guardar'),
                onPressed: w.alGuardar,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(zonaTactilBici, 56),
                ),
                child: const Text(TextosBici.guardar),
              ),
              if (w.alCancelar != null)
                TextButton(
                  onPressed: w.alCancelar,
                  child: const Text('Cancelar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «Salí acompañado»: una casilla de 48 dp **sin identificar a nadie** (5.2).
class _FilaAcompanado extends StatelessWidget {
  const _FilaAcompanado({required this.valor, required this.alCambiar});

  final bool valor;
  final ValueChanged<bool>? alCambiar;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    const texto = 'Salí acompañado';
    final contenido = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zonaTactilBici),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              valor ? Icons.check_box : Icons.check_box_outline_blank,
              size: 26,
              color: valor ? v.acento : v.textoTenue,
            ),
          ),
          SizedBox(width: e * 1.25),
          Expanded(
            child: Text(
              '$texto${valor ? ': sí' : ': no'}',
              style: v.lectura(
                tamano: 15,
                peso: FontWeight.w600,
                color: v.textoFuerte,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      checked: valor,
      label: texto,
      onTap: alCambiar == null ? null : () => alCambiar!(!valor),
      excludeSemantics: true,
      child: alCambiar == null
          ? contenido
          : InkWell(onTap: () => alCambiar!(!valor), child: contenido),
    );
  }
}
