/// Maquetas B1 a B11 de «Bicicleta» (6.1): cada pantalla armada **solo con los
/// componentes de diseño** y datos de ejemplo inventados. B5 las usa como guía
/// de composición y las pruebas las miden (estilos, claro y oscuro, letra al
/// doble, 48 dp). No hay lógica: los toques no hacen nada, salvo el
/// cronómetro de B4, que sí cuenta y se puede empezar y terminar.
///
/// **B10 y B11 (el visor en vivo y el resumen con mapa) son V2 y no están
/// aprobados:** solo existen como maqueta sin funcionar, con una marca clara
/// «V2, no aprobado», sin botones que se toquen y sin mapa ni GPS. No hay
/// ningún paquete detrás.
///
/// El cronómetro de B4 y el visor de B10 usan la personalidad **Sport** (alto
/// contraste, números grandes); la tarjeta de Hoy (B1) también. Las demás, la
/// calma de Hábitos (6, `DISENO_UX_UI.md:194`).
library;

import 'package:flutter/material.dart';

import '../../nucleo/contratos/roles.dart';
import '../componentes/tarjeta_modulo.dart';
import '../personalidad_modulo.dart';
import '../tema_modulo.dart';
import '../valores_diseno.dart';
import 'clima.dart';
import 'cronometro.dart';
import 'enlaces.dart';
import 'historial_bici.dart';
import 'mantenimiento.dart';
import 'meta_mensual.dart';
import 'piezas_bici.dart';
import 'plan_salida.dart';
import 'preparacion.dart';
import 'registro_salida.dart';
import 'rutas.dart';
import 'seguridad.dart';
import 'tarjeta_hoy.dart';
import 'textos_bici.dart';
import 'tipos_bici.dart';

/// Las once pantallas de la sección 6.1.
enum PantallaMaquetaBici {
  b1Hoy('B1 · Hoy: tarjeta Bicicleta', true, false),
  b2Planear('B2 · Planear la salida', false, false),
  b3Preparacion('B3 · Preparación', false, false),
  b4Registro('B4 · Cronómetro y registro de la salida', true, false),
  b5Historial('B5 · Historial', false, false),
  b6Rutas('B6 · Rutas guardadas', false, false),
  b7MiBici('B7 · Mi bici y mantenimiento', false, false),
  b8Seguridad('B8 · Seguridad y contacto', false, false),
  b9Ajustes('B9 · Ajustes de la bicicleta', false, false),
  b10EnVivo('B10 · En vivo (visor)', true, true),
  b11Resumen('B11 · Resumen con mapa', false, true);

  const PantallaMaquetaBici(this.titulo, this.sport, this.v2);

  final String titulo;

  /// Usa la personalidad Sport (pantallas en movimiento).
  final bool sport;

  /// Es la versión 2: solo maqueta, sin funcionar y **no aprobada**.
  final bool v2;
}

/// Una pantalla de maqueta con su personalidad y datos de ejemplo.
class MaquetaBici extends StatelessWidget {
  const MaquetaBici({super.key, required this.pantalla, this.ahora});

  final PantallaMaquetaBici pantalla;

  /// Reloj inyectable (pruebas).
  final DateTime Function()? ahora;

  @override
  Widget build(BuildContext context) {
    final cuerpo = switch (pantalla) {
      PantallaMaquetaBici.b1Hoy => const _B1Hoy(),
      PantallaMaquetaBici.b2Planear => const _B2Planear(),
      PantallaMaquetaBici.b3Preparacion => const _B3Preparacion(),
      PantallaMaquetaBici.b4Registro => _B4Registro(ahora: ahora),
      PantallaMaquetaBici.b5Historial => const _B5Historial(),
      PantallaMaquetaBici.b6Rutas => const _B6Rutas(),
      PantallaMaquetaBici.b7MiBici => const _B7MiBici(),
      PantallaMaquetaBici.b8Seguridad => const _B8Seguridad(),
      PantallaMaquetaBici.b9Ajustes => const _B9Ajustes(),
      PantallaMaquetaBici.b10EnVivo => const _B10EnVivo(),
      PantallaMaquetaBici.b11Resumen => const _B11Resumen(),
    };
    return TemaModulo(
      modulo: Modulo.habitos,
      submodulo: pantalla.sport ? Submodulo.bici : null,
      child: Builder(
        builder: (context) {
          final v = ValoresDiseno.de(context);
          return ColoredBox(
            color: v.fondo,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: AlignmentDirectional.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
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
                        if (pantalla.v2) ...[
                          SizedBox(height: v.espacio * 1.5),
                          const _BannerV2(),
                        ],
                        SizedBox(height: v.espacio * 2),
                        cuerpo,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Piezas de composición de las maquetas -----------------------------------

/// Un subtítulo que separa los casos de una misma maqueta.
class _Caso extends StatelessWidget {
  const _Caso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Padding(
      padding: EdgeInsets.only(top: v.espacio * 1.5, bottom: v.espacio),
      child: Semantics(
        header: true,
        child: Text(texto, style: v.etiquetaPanel()),
      ),
    );
  }
}

/// La marca grande de lo que **no** existe todavía.
class _BannerV2 extends StatelessWidget {
  const _BannerV2();

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Semantics(
      container: true,
      label: '${TextosBici.v2NoAprobado}. ${TextosBici.v2Detalle}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(v.alerta.withValues(alpha: 0.12), v.panel),
          border: Border.all(color: v.alerta, width: v.grosorBorde + 1),
          borderRadius: BorderRadius.circular(v.radioMediano),
        ),
        child: Padding(
          padding: EdgeInsets.all(e * 1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.block, size: 24, color: v.alerta),
              SizedBox(width: e * 1.25),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TextosBici.v2NoAprobado,
                      key: const ValueKey('banner-v2'),
                      style: v.lectura(
                        tamano: 17,
                        peso: FontWeight.w700,
                        color: v.textoFuerte,
                      ),
                    ),
                    Text(
                      TextosBici.v2Detalle,
                      style: v.lectura(tamano: 14, color: v.texto),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un recuadro que hace de mapa en la maqueta V2: no dibuja ningún mapa.
class _MapaMaqueta extends StatelessWidget {
  const _MapaMaqueta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: v.panel,
        border: Border.all(color: v.acento, width: v.grosorBorde + 0.5),
        borderRadius: BorderRadius.circular(v.radioMediano),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 160),
        child: Padding(
          padding: EdgeInsets.all(v.espacio * 1.5),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 24, color: v.textoFuerte),
                SizedBox(width: v.espacio),
                Flexible(
                  child: Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: v.lectura(
                      tamano: 15,
                      peso: FontWeight.w600,
                      color: v.textoFuerte,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un botón dibujado (no tocable) de las maquetas V2: 64 dp de alto.
class _BotonMaqueta extends StatelessWidget {
  const _BotonMaqueta({required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: v.panel,
        border: Border.all(color: v.acento, width: v.grosorBorde + 0.5),
        borderRadius: BorderRadius.circular(v.radioMediano),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: altoAccionBici,
          minWidth: altoAccionBici,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: v.espacio * 2,
            vertical: v.espacio,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 24, color: v.textoFuerte),
              SizedBox(width: v.espacio),
              Flexible(
                child: Text(
                  texto,
                  style: v.lectura(
                    tamano: 16,
                    peso: FontWeight.w700,
                    color: v.textoFuerte,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un número enorme con su etiqueta, para el visor y el resumen (V2).
class _NumeroGrande extends StatelessWidget {
  const _NumeroGrande({
    required this.valor,
    required this.etiqueta,
    this.tamano = 96,
  });

  final String valor;
  final String etiqueta;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            valor,
            maxLines: 1,
            style: v.numero(
              tamano: tamano,
              peso: FontWeight.w700,
              color: v.textoFuerte,
            ),
          ),
        ),
        Text(etiqueta, style: v.etiquetaPanel()),
      ],
    );
  }
}

// --- Datos de ejemplo (inventados) -------------------------------------------

const _puntosVispera = [
  PuntoPreparacionVista(
    id: 'bici_revisada',
    texto: 'Bici revisada: frenos, llantas y cadena',
    marcado: true,
  ),
  PuntoPreparacionVista(
    id: 'luces_cargadas',
    texto: 'Luces cargadas',
    marcado: true,
  ),
  PuntoPreparacionVista(
    id: 'telefono_cargando',
    texto: 'Teléfono y luces a cargar',
    marcado: true,
  ),
  PuntoPreparacionVista(id: 'agua_lista', texto: 'Agua lista', marcado: true),
  PuntoPreparacionVista(
    id: 'comida_lista',
    texto: 'Algo fácil de comer',
    marcado: true,
  ),
  PuntoPreparacionVista(
    id: 'herramientas',
    texto: 'Bomba o inflador, parche y cámara de repuesto',
    marcado: true,
  ),
  PuntoPreparacionVista(
    id: 'ropa_lista',
    texto: 'Casco y ropa visible listos',
    marcado: true,
  ),
  PuntoPreparacionVista(
    id: 'clima_visto',
    texto: 'Revisé el clima',
    marcado: true,
  ),
  PuntoPreparacionVista(
    id: 'luces_siempre',
    texto: 'En calle, luces encendidas y ropa visible',
    ambito: AmbitoPunto.calle,
  ),
  PuntoPreparacionVista(
    id: 'llantas_frenos_terreno',
    texto: 'Llantas y frenos revisados para terreno',
    ambito: AmbitoPunto.terreno,
  ),
];

const _puntosAntesDeSalir = [
  PuntoPreparacionVista(id: 'casco_puesto', texto: 'Casco'),
  PuntoPreparacionVista(id: 'luces_puestas', texto: 'Luces puestas'),
  PuntoPreparacionVista(id: 'frenos_probados', texto: 'Probé los frenos'),
  PuntoPreparacionVista(id: 'presion_llantas', texto: 'Llantas en buen estado'),
  PuntoPreparacionVista(
    id: 'escucha_exterior',
    texto: 'Audífonos en escucha exterior o a volumen bajo',
  ),
  PuntoPreparacionVista(id: 'aviso_regreso', texto: 'Avisé mi hora de regreso'),
];

const _consejos = [
  ConsejoSeguridadVista(
    titulo: 'En calle',
    texto:
        'En calle, usa casco, luces y ropa visible, y respeta las señales. '
        'Con audífonos, deja pasar el sonido del entorno.',
    icono: Icons.traffic_outlined,
  ),
  ConsejoSeguridadVista(
    titulo: 'En terreno',
    texto:
        'En terreno, revisa llantas y frenos antes de salir y lleva '
        'herramientas básicas.',
    icono: Icons.terrain,
  ),
  ConsejoSeguridadVista(
    titulo: 'Agua y algo de comer',
    texto:
        'Lleva agua y algo fácil de comer, y bebe con regularidad desde el '
        'inicio.',
    icono: Icons.water_drop_outlined,
  ),
  ConsejoSeguridadVista(
    titulo: 'Si te sientes mal',
    texto: TextosBici.siTeSientesMal,
    icono: Icons.health_and_safety_outlined,
  ),
  ConsejoSeguridadVista(
    titulo: 'Hora de regreso',
    texto:
        'Avisa a alguien de confianza tu hora de regreso. Para una '
        'emergencia, llama a emergencias o a tu contacto.',
    icono: Icons.schedule,
  ),
];

const _enlacesEjemplo = [
  EnlaceVista(
    tipo: TipoEnlace.musica,
    texto: TextosBici.abrirMiLista,
    nombreTexto: 'Rodadas de sábado',
  ),
  EnlaceVista(tipo: TipoEnlace.clima, texto: TextosBici.verElClima),
  EnlaceVista(
    tipo: TipoEnlace.mapa,
    texto: TextosBici.abrirMiRuta,
    guardado: false,
  ),
];

List<EnlaceVista> _enlacesConToque() => [
  for (final x in _enlacesEjemplo)
    EnlaceVista(
      tipo: x.tipo,
      texto: x.texto,
      nombreTexto: x.nombreTexto,
      guardado: x.guardado,
      alAbrir: () {},
    ),
];

// --- B1 · Hoy ----------------------------------------------------------------

class _B1Hoy extends StatelessWidget {
  const _B1Hoy();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Caso('VIERNES EN LA NOCHE'),
      TarjetaBiciHoy(
        momento: MomentoSalida.vispera,
        salidaTexto: 'Mañana · 8:00',
        detalleTexto: 'Unas 4 h',
        preparacionTexto: '6 de 10',
        notaTexto: 'Prepara tu bici con calma. Lo que falte puede esperar.',
        alPreparar: () {},
        alAbrir: () {},
      ),
      const _Caso('SÁBADO, ANTES DE SALIR'),
      TarjetaBiciHoy(
        momento: MomentoSalida.diaDeSalida,
        salidaTexto: '8:00',
        detalleTexto: 'Sábado · unas 4 h · ruta mixta',
        regresoTexto: '12:00',
        revisionTexto: '14:30',
        encaje: EncajeRevision.cabe,
        encajeTexto: 'Sobran 60 min',
        preparacionTexto: '10 de 10',
        notaTexto: 'Hoy toca tu salida en bici. ¿Todo listo?',
        alSali: () {},
        alEmpezar: () {},
        alRegistrar: () {},
        alAbrir: () {},
      ),
      const _Caso('SÁBADO, CUANDO LA SALIDA NO CABE'),
      TarjetaBiciHoy(
        momento: MomentoSalida.diaDeSalida,
        salidaTexto: '8:00',
        detalleTexto: 'Sábado · unas 5 h 30 min',
        regresoTexto: '13:30',
        revisionTexto: '14:30',
        encaje: EncajeRevision.noCabe,
        encajeTexto: 'Faltan 30 min',
        avisoPiernasTexto:
            'Tu revisión semanal puede esperar un rato más si lo necesitas.',
        alSali: () {},
        alEmpezar: () {},
        alPosponerRevision: () {},
        alAbrir: () {},
      ),
      const _Caso('YA REGISTRADA'),
      TarjetaBiciHoy(
        momento: MomentoSalida.hecha,
        salidaTexto: '8:00',
        detalleTexto: 'Sábado · 4 h 05 min',
        notaTexto: 'Salida registrada. Gracias por avisar.',
        alRegistrar: () {},
        alDeshacer: () {},
      ),
      const _Caso('NO SALIÓ HOY'),
      TarjetaBiciHoy(
        momento: MomentoSalida.omitida,
        salidaTexto: '8:00',
        notaTexto: 'Hoy no salió la ruta. Cuando quieras, la retomamos.',
        alDeshacer: () {},
      ),
      const _Caso('CON EL MODO FOCO'),
      TarjetaBiciHoy(
        momento: MomentoSalida.diaDeSalida,
        salidaTexto: '8:00',
        detalleTexto: 'Sábado · unas 4 h',
        modoFoco: true,
        alSali: () {},
        alEmpezar: () {},
      ),
    ],
  );
}

// --- B2 · Planear la salida --------------------------------------------------

class _B2Planear extends StatelessWidget {
  const _B2Planear();

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaPlanSalida(
          diaHoraTexto: 'Sábado · 8:00',
          duracionTexto: '≈ 4 h',
          regresoTexto: '12:00',
          revisionTexto: '14:30',
          encaje: EncajeRevision.cabe,
          encajeTexto: 'Sobran 60 min',
          rutaTexto: 'Vuelta al cerro (ejemplo)',
          bicicletaTexto: 'Mi bici',
          odometroTexto: '470 km',
          alElegirRuta: () {},
          alElegirBicicleta: () {},
          alCambiarHora: () {},
        ),
        SizedBox(height: e * 1.5),
        AvisoBici(
          texto:
              'Si pasas la sesión C al jueves, queda a 36 h 45 min de la '
              'ruta. Puedes volver a C el martes, tratar la ruta como ligera '
              'o dejarlo así.',
          acciones: [
            AccionAvisoBici(texto: TextosBici.verOpciones, alTocar: () {}),
            AccionAvisoBici(texto: TextosBici.dejarloAsi, alTocar: () {}),
          ],
        ),
        SizedBox(height: e * 1.5),
        TarjetaModulo(
          titulo: 'Preparación',
          icono: Icons.checklist,
          child: Wrap(
            spacing: e,
            runSpacing: e,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Preparación (8 de 10)',
                style: v.lectura(
                  tamano: 16,
                  peso: FontWeight.w700,
                  color: v.textoFuerte,
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                child: const Text(TextosBici.abrir),
              ),
            ],
          ),
        ),
        SizedBox(height: e * 1.5),
        TarjetaModulo(
          titulo: 'Mantenimiento',
          icono: Icons.build_outlined,
          child: Text(
            'Toca: revisar frenos y llantas. Sin registro: limpiar la '
            'transmisión.',
            style: v.lectura(tamano: 15, color: v.texto),
          ),
        ),
        SizedBox(height: e * 1.5),
        CasillasClima(
          seleccionado: ClimaBici.despejado,
          respuestaTexto: 'Buen día para salir. Cuídate en las calles.',
          alElegir: (_) {},
          alVerClima: () {},
        ),
        SizedBox(height: e * 1.5),
        ListaEnlaces(enlaces: _enlacesConToque()),
        SizedBox(height: e * 1.5),
        Wrap(
          spacing: e,
          runSpacing: e,
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(zonaTactilBici, 56),
              ),
              icon: const Icon(Icons.sms_outlined, size: 20),
              label: const Text(TextosBici.avisarMiHoraDeRegreso),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(zonaTactilBici, 56),
              ),
              icon: const Icon(Icons.call, size: 20),
              label: const Text(TextosBici.llamarAMiContacto),
            ),
          ],
        ),
        SizedBox(height: e * 1.5),
        Text(
          TextosBici.guiaNoSustituyeCorta,
          style: v.lectura(tamano: 13.5, color: v.textoTenue),
        ),
        SizedBox(height: e * 1.5),
        const TarjetaContenidoEnRevisionBici(compacta: true),
      ],
    );
  }
}

// --- B3 · Preparación --------------------------------------------------------

class _B3Preparacion extends StatelessWidget {
  const _B3Preparacion();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListaPreparacion(
        momento: MomentoPreparacion.vispera,
        puntos: _puntosVispera,
        alCambiar: (_, _) {},
        alListo: () {},
        alEditar: () {},
      ),
      const SizedBox(height: 12),
      ListaPreparacion(
        momento: MomentoPreparacion.antesDeSalir,
        puntos: _puntosAntesDeSalir,
        alCambiar: (_, _) {},
        alListo: () {},
        mostrarGuia: false,
      ),
    ],
  );
}

// --- B4 · Cronómetro y registro ----------------------------------------------

class _B4Registro extends StatefulWidget {
  const _B4Registro({this.ahora});

  final DateTime Function()? ahora;

  @override
  State<_B4Registro> createState() => _B4RegistroState();
}

class _B4RegistroState extends State<_B4Registro> {
  late DateTime Function() _ahora;
  SalidaCronometrada? _salida;
  int? _esfuerzo = 3;
  SuperficieSalida? _superficie = SuperficieSalida.mixta;
  ClimaBici? _clima = ClimaBici.despejado;
  bool _acompanado = false;
  int _minutos = 245;

  @override
  void initState() {
    super.initState();
    _ahora = widget.ahora ?? DateTime.now;
    // Ya lleva 1 h 42 min 10 s: así se ve el estado «en curso» con su botón.
    _salida = SalidaCronometrada(
      inicio: _ahora().subtract(
        const Duration(hours: 1, minutes: 42, seconds: 10),
      ),
    );
  }

  String get _duracionTexto =>
      '${_minutos ~/ 60} h ${(_minutos % 60).toString().padLeft(2, '0')} min';

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaModulo(
          titulo: TextosBici.cronometro,
          icono: Icons.timer_outlined,
          child: CronometroSalida(
            salida: _salida,
            ahora: _ahora,
            alEmpezar: () =>
                setState(() => _salida = SalidaCronometrada.iniciar(_ahora())),
            alTerminar: () =>
                setState(() => _salida = _salida?.terminar(_ahora())),
            alRegistrar: () {},
          ),
        ),
        const _Caso('AL TERMINAR SE ABRE ESTA HOJA'),
        HojaRegistroSalida(
          fechaTexto: 'Sábado 28 nov',
          horaTexto: '8:00',
          duracionTexto: _duracionTexto,
          distanciaTexto: '62,4',
          bicicletaTexto: 'Mi bici',
          superficie: _superficie,
          esfuerzo: _esfuerzo,
          clima: _clima,
          respuestaClimaTexto: 'Buen día para salir. Cuídate en las calles.',
          acompanado: _acompanado,
          alMenosDuracion: _minutos > 15
              ? () => setState(() => _minutos -= 15)
              : null,
          alMasDuracion: () => setState(() => _minutos += 15),
          alCambiarFecha: () {},
          alCambiarDistancia: (_) {},
          alElegirSuperficie: (s) => setState(() => _superficie = s),
          alElegirEsfuerzo: (n) => setState(() => _esfuerzo = n),
          alElegirClima: (c) => setState(() => _clima = c),
          alCambiarAcompanado: (x) => setState(() => _acompanado = x),
          alTodoComoPlaneado: () {},
          alGuardar: () {},
          alCancelar: () {},
        ),
        SizedBox(height: e),
      ],
    );
  }
}

// --- B5 · Historial ----------------------------------------------------------

class _B5Historial extends StatelessWidget {
  const _B5Historial();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const MetaMensualBici(
        mesTexto: 'noviembre',
        hechas: 2,
        meta: 3,
        omitidasPorClima: 1,
        mensajeTexto: 'Llevas 2 de 3 salidas este mes.',
      ),
      const SizedBox(height: 12),
      const BarrasHistorialBici(
        subtitulo: 'Últimas 6 semanas',
        notaProgresionTexto:
            'Esta salida fue bastante más larga que tus últimas. Si te '
            'sientes bien, adelante; si no, acórtala.',
        barras: [
          BarraSalidaVista(
            etiqueta: 'Semana del 19 oct',
            valor: 48,
            valorTexto: '48,0 km',
            detalleTexto: '3 h 30 min · calle',
          ),
          BarraSalidaVista(
            etiqueta: 'Semana del 26 oct',
            valor: 55,
            valorTexto: '55,2 km',
            detalleTexto: '3 h 50 min · mixta',
          ),
          BarraSalidaVista(
            etiqueta: 'Semana del 2 nov',
            valor: 0,
            valorTexto: 'Sin salida',
            estado: EstadoSemanaBici.omitidaPorClima,
          ),
          BarraSalidaVista(
            etiqueta: 'Semana del 9 nov',
            valor: 0,
            valorTexto: 'Sin salida',
            estado: EstadoSemanaBici.sinSalida,
          ),
          BarraSalidaVista(
            etiqueta: 'Semana del 16 nov',
            valor: 58,
            valorTexto: '58,0 km',
            detalleTexto: '4 h 00 min · mixta',
          ),
          BarraSalidaVista(
            etiqueta: 'Semana del 23 nov',
            valor: 62.4,
            valorTexto: '62,4 km',
            detalleTexto: '4 h 05 min · mixta',
          ),
        ],
      ),
      const SizedBox(height: 12),
      ListaSalidasHistorial(
        salidas: const [
          SalidaHistorialVista(
            fechaTexto: 'sáb 21 nov',
            resumenTexto: '4 h 05 min · 62,4 km',
            superficie: SuperficieSalida.mixta,
            esfuerzoTexto: 'Esfuerzo 3 de 5',
            climaTexto: 'Despejado',
          ),
          SalidaHistorialVista(
            fechaTexto: 'sáb 14 nov',
            resumenTexto: '4 h 00 min · 58,0 km',
            superficie: SuperficieSalida.mixta,
            esfuerzoTexto: 'Esfuerzo 4 de 5',
            acompanado: true,
          ),
        ],
        alTocarSalida: (_) {},
      ),
    ],
  );
}

// --- B6 · Rutas guardadas ----------------------------------------------------

class _B6Rutas extends StatelessWidget {
  const _B6Rutas();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Caso('EN EL TELÉFONO DONDE SE ESCRIBIERON'),
      ListaRutas(
        rutas: const [
          RutaVista(
            id: 'r1',
            nombre: 'Vuelta al cerro (ejemplo)',
            distanciaTexto: '42,0 km',
            desnivelTexto: '+ 310 m',
            superficie: SuperficieSalida.mixta,
            tramosTexto: '24 km de calle, 18 km de terreno',
          ),
          RutaVista(
            id: 'r2',
            nombre: 'Ciclovía larga (ejemplo)',
            distanciaTexto: '35,5 km',
            desnivelTexto: '+ 60 m',
            superficie: SuperficieSalida.calle,
          ),
          RutaVista(
            id: 'r3',
            nombre: 'Brecha del arroyo (ejemplo)',
            distanciaTexto: '28,0 km',
            superficie: SuperficieSalida.terreno,
          ),
        ],
        alElegir: (_) {},
        alNueva: () {},
      ),
      const _Caso('EN LA LAPTOP'),
      const ListaRutas(rutas: [], enEsteEquipo: false),
    ],
  );
}

// --- B7 · Mi bici y mantenimiento --------------------------------------------

class _B7MiBici extends StatelessWidget {
  const _B7MiBici();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TarjetaMantenimiento(
        bicicletaTexto: 'MI BICI',
        odometroTexto: '470 km',
        tareas: const [
          TareaMantenimientoVista(
            id: 'lubricar_cadena',
            nombre: 'Lubricar la cadena',
            estado: EstadoTarea.alDia,
            intervaloTexto: 'Cada 150 km o 4 semanas',
            ultimaVezTexto: 'Hecha a los 350 km',
            faltaTexto: 'Faltan 30 km',
          ),
          TareaMantenimientoVista(
            id: 'revisar_frenos_llantas',
            nombre: 'Revisar frenos y llantas',
            estado: EstadoTarea.toca,
            intervaloTexto: 'Cada 300 km o 8 semanas',
            ultimaVezTexto: 'Hecha el 28 sep',
            faltaTexto: 'Ya pasaron 8 semanas',
          ),
          TareaMantenimientoVista(
            id: 'limpiar_transmision',
            nombre: 'Limpiar la transmisión',
            estado: EstadoTarea.sinRegistro,
            intervaloTexto: 'Cada 400 km o 12 semanas',
          ),
          TareaMantenimientoVista(
            id: 'revision_general',
            nombre: 'Revisión general en el taller',
            estado: EstadoTarea.sinRegistro,
            intervaloTexto: 'Cada 2 000 km o 26 semanas',
          ),
        ],
        alHecho: (_) {},
        alAnotarLectura: () {},
        alCambiarIntervalos: () {},
      ),
      const SizedBox(height: 12),
      const TarjetaContenidoEnRevisionBici(),
    ],
  );
}

// --- B8 · Seguridad y contacto -----------------------------------------------

class _B8Seguridad extends StatelessWidget {
  const _B8Seguridad();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Caso('EN EL TELÉFONO'),
      TarjetaSeguridad(
        consejos: _consejos,
        contactoTexto: 'Ana (ejemplo)',
        mensajeRegresoTexto:
            'Salgo a las 8:00 y regreso hacia las 12:00. No me vigila nadie: '
            'si no sé de ti, llámame.',
        alLlamar: () {},
        alAvisarRegreso: () {},
      ),
      const _Caso('EN LA LAPTOP'),
      const TarjetaSeguridad(consejos: _consejos, contactoEnEsteEquipo: false),
    ],
  );
}

// --- B9 · Ajustes ------------------------------------------------------------

class _B9Ajustes extends StatelessWidget {
  const _B9Ajustes();

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    final e = v.espacio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaModulo(
          titulo: 'Valores de la salida',
          icono: Icons.tune,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorPasosBici(
                etiqueta: 'DURACIÓN PREVISTA',
                valorTexto: '4 h',
                descripcionAccesible: 'Duración prevista: 4 horas',
                etiquetaMenos: 'Quitar 15 minutos',
                etiquetaMas: 'Agregar 15 minutos',
                alMenos: () {},
                alMas: () {},
              ),
              SizedBox(height: e * 2),
              SelectorPasosBici(
                etiqueta: 'MARGEN ANTES DE LA REVISIÓN',
                valorTexto: '90 min',
                descripcionAccesible: 'Margen antes de la revisión: 90 minutos',
                etiquetaMenos: 'Quitar 15 minutos de margen',
                etiquetaMas: 'Agregar 15 minutos de margen',
                alMenos: () {},
                alMas: () {},
              ),
              SizedBox(height: e * 2),
              SelectorPasosBici(
                etiqueta: 'AVISO DE SALIDA MUCHO MÁS LARGA',
                valorTexto: '20 %',
                descripcionAccesible:
                    'Aviso de salida más larga que tus últimas: 20 por ciento',
                etiquetaMenos: 'Bajar 5 por ciento',
                etiquetaMas: 'Subir 5 por ciento',
                alMenos: () {},
                alMas: () {},
              ),
              SizedBox(height: e * 2),
              Text(
                'LA RUTA CUENTA COMO CARGA DE PIERNAS',
                style: v.etiquetaPanel(),
              ),
              SizedBox(height: e),
              Wrap(
                spacing: e,
                runSpacing: e,
                children: [
                  for (final c in CargaPiernas.values)
                    OpcionBici(
                      texto: c.texto,
                      icono: c.icono,
                      seleccionada: c == CargaPiernas.normal,
                      etiquetaAccesible: 'Carga de piernas: ${c.texto}',
                      alTocar: () {},
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: e * 1.5),
        ListaEnlaces(enlaces: _enlacesConToque()),
        SizedBox(height: e * 1.5),
        TarjetaContenidoEnRevisionBici(alAbrir: () {}),
        SizedBox(height: e * 1.5),
        TarjetaModulo(
          titulo: 'Mis datos',
          icono: Icons.lock_outline,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mis datos de la bicicleta'),
            subtitle: const Text('Exportar o borrar lo de la bicicleta.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

// --- B10 · En vivo (V2, no aprobado) -------------------------------------------

class _B10EnVivo extends StatelessWidget {
  const _B10EnVivo();

  @override
  Widget build(BuildContext context) {
    final e = ValoresDiseno.de(context).espacio;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _NumeroGrande(valor: '1:42:10', etiqueta: 'TIEMPO'),
            SizedBox(height: e),
            Wrap(
              spacing: e * 3,
              runSpacing: e,
              children: const [
                SizedBox(
                  width: 180,
                  child: _NumeroGrande(
                    valor: '32,4',
                    etiqueta: 'KM',
                    tamano: 64,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _NumeroGrande(
                    valor: '410',
                    etiqueta: 'M DE SUBIDA',
                    tamano: 64,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _NumeroGrande(
                    valor: '19',
                    etiqueta: 'KM/H',
                    tamano: 64,
                  ),
                ),
              ],
            ),
            SizedBox(height: e * 2),
            const _MapaMaqueta(
              texto: 'Mapa de ejemplo (V2): planeada y recorrida',
            ),
            SizedBox(height: e * 2),
            Wrap(
              spacing: e,
              runSpacing: e,
              children: const [
                _BotonMaqueta(texto: 'Pausa', icono: Icons.pause),
                _BotonMaqueta(texto: 'Modo ahorro', icono: Icons.battery_saver),
                _BotonMaqueta(texto: 'SOS', icono: Icons.call),
              ],
            ),
            SizedBox(height: e * 1.5),
            const _BotonMaqueta(
              texto: 'Mantén 2 s para terminar',
              icono: Icons.stop_circle_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// --- B11 · Resumen con mapa (V2, no aprobado) ----------------------------------

class _B11Resumen extends StatelessWidget {
  const _B11Resumen();

  @override
  Widget build(BuildContext context) {
    final e = ValoresDiseno.de(context).espacio;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: e * 3,
              runSpacing: e,
              children: const [
                SizedBox(
                  width: 200,
                  child: _NumeroGrande(
                    valor: '62,4',
                    etiqueta: 'KM',
                    tamano: 56,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: _NumeroGrande(
                    valor: '4:05:12',
                    etiqueta: 'TIEMPO',
                    tamano: 56,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: _NumeroGrande(
                    valor: '540',
                    etiqueta: 'M DE SUBIDA',
                    tamano: 56,
                  ),
                ),
              ],
            ),
            SizedBox(height: e * 2),
            const _MapaMaqueta(
              texto:
                  'Resumen con mapa de ejemplo (V2): el trazo solo en el '
                  'equipo donde se grabó',
            ),
            SizedBox(height: e * 2),
            Wrap(
              spacing: e,
              runSpacing: e,
              children: const [
                _BotonMaqueta(
                  texto: 'Mapas sin conexión',
                  icono: Icons.download_outlined,
                ),
                _BotonMaqueta(
                  texto: 'Importar GPX',
                  icono: Icons.file_open_outlined,
                ),
                _BotonMaqueta(
                  texto: 'Exportar GPX (recorta 200 m)',
                  icono: Icons.ios_share,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
