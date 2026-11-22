/// Módulo **Casa** de GRAVITY (agente casa; pantalla de la plataforma, F8-7.1).
///
/// - [PantallaCasa]: estado del puente y frases fijas de las bocinas (solo
///   lectura).
/// - [fuentePuenteProvider]: de dónde sale el estado del puente. Por omisión
///   "no configurado"; la implementación real depende de un canal de reporte
///   del puente que aún no está definido.
/// - `puente/`: frases, filtro de la bocina y la interfaz del puente (sin
///   pantalla; pruebas en `test/modulos/casa/`).
library;

import 'package:flutter/widgets.dart';

import 'pantallas/pantalla_casa.dart';

export 'estado/estado_puente.dart'
    show
        EstadoDelPuente,
        FuentePuente,
        FuentePuenteEnMemoria,
        InformePuente,
        estadoPuenteProvider,
        fuentePuenteProvider;

/// Pantalla del módulo Casa.
Widget pantallaCasa() => const PantallaCasa();
