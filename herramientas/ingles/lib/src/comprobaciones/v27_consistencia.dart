import '../contexto.dart';
import '../hallazgo.dart';
import '../modelo/archivo.dart';
import '../modelo/contrato_sesion.dart';
import '../modelo/datos.dart';
import '../modelo/listas.dart';
import 'comun.dart';

/// Los identificadores de los contratos propios que V27 contrasta.
const String idContratoEscalon = 'gravity-escalon';
const String idContratoUbicacion = 'gravity-ubicacion';

/// Las preguntas de cada etapa de la ubicación (plan 3.3, primera viñeta): 6 de
/// gramática y vocabulario, 3 de lectura y 3 de escucha. Es la regla del plan;
/// V27 la contrasta con lo que el contrato dice.
const int ubicacionGramatica = 6;
const int ubicacionLectura = 3;
const int ubicacionEscucha = 3;

/// V27 · Consistencia de los contratos propios y de `niveles.yaml`. Es error.
/// Se aplica a `gravity-sesion-60`, `gravity-escalon`, `gravity-ubicacion` y
/// `niveles.yaml`; cada hallazgo se pone en el archivo que depende de lo que
/// contrasta (para no decir dos veces lo mismo).
///
/// - **gravity-sesion-60**: sumas de minutos (partes, secciones, total y
///   `tolerancias_de_minutos`), días y tarjetas de la semana, `sin_audio` y
///   `asistencia`, las semanas de la mini prueba y de la prueba por unidad y su
///   composición y minutos, y que los mínimos por bloque alcancen el 70 % del
///   bloque con la fórmula de minutos (si no, V21 aceptaría sesiones que V22
///   rechaza).
/// - **gravity-escalon**: 13 escalones y horas = 40 × escalones, las etapas y
///   sus horas acumuladas, las formas por puerta y las pruebas por unidad, y
///   que la asistencia, la mini prueba y las minutos por día sean los de
///   `gravity-sesion-60`.
/// - **gravity-ubicacion**: 6 + 3 + 3 = 12 preguntas por etapa y 48 en total, el
///   banco, el corte y que los rangos de longitud sean los de `gravity-sesion-60`.
/// - **niveles.yaml**: 13 escalones con sus horas, etapas y puertas iguales a las
///   de `gravity-escalon`; cada tema de gramática es nuevo en un solo escalón;
///   un escalón solo retoma temas de escalones anteriores; el temario por semana
///   reparte exactamente los temas nuevos; y todo lo que el inventario de un
///   manual nombra queda visto, a más tardar, al cerrar la etapa.
///
/// Un dato pendiente en el contrato no se da por error: el contraste que depende
/// de él es un aviso. Un dato que falta se dice como "no declara" (aviso en
/// borrador, error desde validado).
List<Hallazgo> v27(Archivo a, Contexto c) {
  if (a is ArchivoFormato) {
    switch (a.id) {
      case idContratoSesion:
        return _Chequeo(a, c).sesion();
      case idContratoEscalon:
        return _Chequeo(a, c).escalon();
      case idContratoUbicacion:
        return _Chequeo(a, c).ubicacion();
    }
  }
  if (a is ArchivoNiveles) return _Chequeo(a, c).niveles();
  return const [];
}

num _suma(Iterable<num?> xs) => xs.fold<num>(0, (s, x) => s + (x ?? 0));

String _n(num n) =>
    n == n.roundToDouble() ? '${n.round()}' : n.toStringAsFixed(1);

class _Chequeo {
  _Chequeo(this.a, this.c) : datos = _datos(a);

  final Archivo a;
  final Contexto c;
  final Mapa datos;
  final List<Hallazgo> h = [];

  static Mapa _datos(Archivo a) => switch (a) {
    ArchivoFormato() => a.contrato.datos,
    ArchivoNiveles() => a.niveles.datos,
    _ => const {},
  };

  void err(String m, {String? id}) => h.add(error(a, 'V27', m, id: id));

  /// El dato que falta.
  void falta(String ruta, String paraQue) =>
      h.add(faltante(a, 'V27', 'el contrato no declara $ruta: $paraQue'));

  /// Exige que existan estos datos; devuelve si están todos.
  bool requiere(Map<String, String> rutas) {
    var ok = true;
    for (final e in rutas.entries) {
      if (en(datos, e.key) == null) {
        falta(e.key, e.value);
        ok = false;
      }
    }
    return ok;
  }

  /// Contraste de dos valores del mismo contrato: error si faltan o difieren.
  void iguales(String que, num? x, num? y) {
    if (x == null || y == null) return;
    if (x != y) err('$que: ${_n(x)} y ${_n(y)} no coinciden');
  }

  // ======================================================= gravity-sesion-60

  List<Hallazgo> sesion() {
    final k = c.contratoSesion!;
    requiere({
      'totales.minutos': 'V21 y V22 comparan con los 60 minutos',
      'totales.minutos_principal': 'suma de los bloques principales',
      'totales.minutos_traslado': 'suma de los bloques de traslado',
      'totales.sesiones_por_semana': 'días de la semana',
      'tolerancias_de_minutos.por_bloque.minimo_porcentaje': 'V22',
      'tolerancias_de_minutos.por_bloque.maximo_porcentaje': 'V22',
      'tolerancias_de_minutos.total.min': 'V22',
      'tolerancias_de_minutos.total.max': 'V22',
      'estimacion_de_minutos.explicacion.palabras_por_minuto': 'V22',
      'estimacion_de_minutos.ejemplo.segundos': 'V22',
      'estimacion_de_minutos.frase_para_repetir.segundos': 'V22',
      'estimacion_de_minutos.elemento_de_pronunciacion.segundos': 'V22',
      'estimacion_de_minutos.tarjeta_nueva.segundos': 'V22',
      'tarjetas_nuevas.por_dia': 'V21',
      'tarjetas_nuevas.por_semana': 'suma de las tarjetas por día',
      'sin_audio.minutos_que_cuentan_al_dia': 'asistencia sin audio',
      'asistencia.minutos_planeados_por_dia': 'asistencia',
      'asistencia.faltante_maximo_por_dia_segundos': 'asistencia',
      'asistencia.dias_faltados_tolerados_por_escalon': 'asistencia',
      'viernes.mini_prueba.preguntas': 'V21 y V28',
      'viernes.mini_prueba.aprobar_con': 'V28',
      'viernes.prueba_por_unidad.viernes_de_las_semanas': 'V21 y V28',
      'viernes.prueba_por_unidad.preguntas': 'V28',
      'viernes.prueba_por_unidad.umbral_porcentaje': 'V28',
    });
    if (k.dias.isEmpty) {
      falta('dias.lista', 'V21 necesita los días de la semana');
    }

    // -------- Sumas de minutos
    final secciones = listaEn(datos, 'secciones') ?? const [];
    var sumaSecciones = 0.0;
    for (var i = 0; i < secciones.length; i++) {
      final s = secciones[i];
      if (s is! Map) continue;
      final sid = s['id'];
      final minutos = s['minutos'];
      final partes = listaEn(s, 'partes') ?? const [];
      final porPartes = _suma([
        for (final p in partes)
          if (p is Map) p['minutos_parte'] as num?,
      ]);
      if (minutos is num) {
        sumaSecciones += minutos;
        if (minutos != porPartes) {
          err(
            'la sección "$sid" declara ${_n(minutos)} minutos y sus partes suman ${_n(porPartes)}',
          );
        }
      }
      if (sid == 'principal') {
        iguales(
          'totales.minutos_principal y la sección principal',
          k.minutosPrincipal,
          minutos as num?,
        );
      }
      if (sid == 'traslado') {
        iguales(
          'totales.minutos_traslado y la sección traslado',
          k.minutosTraslado,
          minutos as num?,
        );
      }
    }
    iguales(
      'totales.minutos y la suma de las secciones',
      k.minutosTotales,
      sumaSecciones,
    );
    final p = k.minutosPrincipal;
    final t = k.minutosTraslado;
    if (p != null && t != null) {
      iguales(
        'totales.minutos y minutos_principal + minutos_traslado',
        k.minutosTotales,
        p + t,
      );
    }
    // El mínimo y el máximo del total contienen los 60.
    final tot = k.minutosTotales;
    if (tot != null && k.totalMinimo != null && k.totalMaximo != null) {
      if (tot < k.totalMinimo! || tot > k.totalMaximo!) {
        err(
          'el total de ${_n(tot)} minutos queda fuera de tolerancias_de_minutos.total (${k.totalMinimo} a ${k.totalMaximo})',
        );
      }
    }
    final mn = k.porcentajeMinimoPorBloque;
    final mx = k.porcentajeMaximoPorBloque;
    if (mn != null && mx != null && !(mn < 100 && mx > 100)) {
      err(
        'tolerancias_de_minutos.por_bloque ($mn % a $mx %) debe rodear el 100 %',
      );
    }

    // -------- Días y tarjetas de la semana
    final n = k.dias.length;
    iguales(
      'totales.sesiones_por_semana y los días de dias.lista',
      k.sesionesPorSemana,
      n,
    );
    iguales(
      'totales.sesiones_por_semana y semana.sesiones',
      k.sesionesPorSemana,
      numeroEn(datos, 'semana.sesiones'),
    );
    final dSemana = textosEn(datos, 'semana.dias');
    if (dSemana != null && dSemana.join(',') != k.dias.join(',')) {
      err(
        'semana.dias (${dSemana.join(', ')}) y dias.lista (${k.dias.join(', ')}) no coinciden',
      );
    }
    final porDia = mapaEn(datos, 'tarjetas_nuevas.por_dia');
    if (porDia != null) {
      final extra = porDia.keys.where((d) => !k.dias.contains(d));
      if (extra.isNotEmpty) {
        err(
          'tarjetas_nuevas.por_dia trae días que no existen: ${extra.join(', ')}',
        );
      }
      final suma = _suma(porDia.values.map((v) => v is num ? v : null));
      iguales(
        'tarjetas_nuevas.por_semana y la suma de las tarjetas por día',
        k.tarjetasNuevasPorSemana,
        suma,
      );
      iguales(
        'tarjetas_nuevas.por_semana y semana.tarjetas_nuevas',
        k.tarjetasNuevasPorSemana,
        numeroEn(datos, 'semana.tarjetas_nuevas'),
      );
    }
    final pron = mapaEn(_parte('pronunciacion'), 'por_dia');
    if (pron != null) {
      for (final d in k.dias) {
        if (!pron.containsKey(d)) {
          err('pronunciacion.por_dia no trae el día $d');
        }
      }
    }
    final lec = mapaEn(_parte('leccion'), 'por_dia');
    if (lec != null) {
      for (final d in k.dias) {
        if (!lec.containsKey(d)) err('leccion.por_dia no trae el día $d');
      }
    }

    // -------- Sin audio y asistencia
    final sa = k.bloquesQueCuentanSinAudio;
    if (sa != null && sa.join(',') != 'principal') {
      err('sin_audio.cuentan debe ser [principal], no [${sa.join(', ')}]');
    }
    iguales(
      'sin_audio.minutos_que_cuentan_al_dia y totales.minutos_principal',
      k.minutosSinAudio,
      k.minutosPrincipal,
    );
    iguales(
      'asistencia.minutos_planeados_por_dia.con_audio y totales.minutos',
      k.minutosPlaneadosConAudio,
      k.minutosTotales,
    );
    iguales(
      'asistencia.minutos_planeados_por_dia.sin_audio y totales.minutos_principal',
      k.minutosPlaneadosSinAudio,
      k.minutosPrincipal,
    );

    // -------- Viernes
    _viernes(k);

    // -------- Longitudes por etapa
    final porNivel = c
        .contrato(idContratoSesion)
        ?.parte('traslado-audio')
        ?.palabrasPorNivel;
    for (final e in etapas) {
      final audio = mapaEn(datos, 'longitudes_por_etapa.$e.audio_palabras');
      if (audio == null) {
        falta(
          'longitudes_por_etapa.$e.audio_palabras',
          'la tabla de longitudes por etapa',
        );
        continue;
      }
      final r = porNivel?[e];
      if (r == null) {
        if (porNivel != null) {
          falta(
            'traslado-audio.palabras_estimulo.por_nivel.$e',
            'el rango de audio de la etapa',
          );
        }
      } else if (r.min != audio['min'] || r.max != audio['max']) {
        err(
          'el audio de $e mide ${audio['min']} a ${audio['max']} en longitudes_por_etapa y ${r.min} a ${r.max} en traslado-audio.por_nivel',
        );
      }
    }

    // -------- Los mínimos alcanzan el 70 % del bloque con la fórmula
    _minimosAlcanzanLaBanda(k);
    return h;
  }

  Mapa? _parte(String id) => c.contrato(idContratoSesion)?.parte(id)?.datos;

  void _viernes(ContratoSesion k) {
    final pu = k.semanasDePruebaPorUnidad;
    final rep = k.semanasDeRepeticion;
    final mini = k.semanasDeMiniPrueba;
    final escalon = c.contrato(idContratoEscalon);
    final semanas = enteroEn(escalon?.datos, 'escalera.semanas_por_escalon');
    if (pu != null) {
      iguales(
        'viernes.prueba_por_unidad.por_escalon y las semanas de viernes_de_las_semanas',
        k.pruebasPorEscalon,
        pu.length,
      );
      if (semanas != null && pu.any((s) => s < 1 || s > semanas)) {
        err('viernes_de_las_semanas trae semanas fuera de 1 a $semanas');
      }
      if (pu.toSet().length != pu.length) {
        err('viernes_de_las_semanas repite semanas');
      }
      if (rep != null) {
        final esperado = [for (final s in pu) s + 1];
        if (rep.join(',') != esperado.join(',')) {
          err(
            'la repetición va el lunes siguiente: con las pruebas en las semanas ${pu.join(', ')} debería ir en las ${esperado.join(', ')}, y trae ${rep.join(', ')}',
          );
        }
      }
      if (mini != null && pu.any((s) => !mini.contains(s) && s != 8)) {
        // La mini prueba y la prueba por unidad comparten el viernes de las semanas 2, 4, 6 y 7.
        err(
          'la mini prueba (semanas ${mini.join(', ')}) no cubre algún viernes de prueba por unidad',
        );
      }
    }
    if (mini != null &&
        semanas != null &&
        mini.any((s) => s < 1 || s > semanas)) {
      err('viernes.mini_prueba.semanas trae semanas fuera de 1 a $semanas');
    }
    final pregMini = k.preguntasDeMiniPrueba;
    final aprobar = k.aprobarMiniPruebaCon;
    if (pregMini != null &&
        aprobar != null &&
        (aprobar < 1 || aprobar > pregMini)) {
      err(
        'viernes.mini_prueba.aprobar_con ($aprobar) debe estar entre 1 y las preguntas ($pregMini)',
      );
    }
    final comp = k.composicionDePrueba;
    final con = k.preguntasDePruebaConAudio;
    final sin = k.preguntasDePruebaSinAudio;
    if (comp.isNotEmpty && con != null) {
      iguales(
        'viernes.prueba_por_unidad.preguntas.con_audio y la suma de composicion_con_audio',
        con,
        _suma(comp.values),
      );
    }
    if (con != null && sin != null) {
      final escucha = comp['escucha'];
      if (escucha != null) {
        iguales(
          'preguntas.sin_audio y con_audio menos las de escucha',
          sin,
          con - escucha,
        );
      }
    }
    final umbral = k.umbralDePruebaPorcentaje;
    if (umbral != null && (umbral < 1 || umbral > 100)) {
      err('umbral_porcentaje ($umbral) debe estar entre 1 y 100');
    }
    // Minutos estimados que el contrato anota, contra su fórmula.
    final seg = k.segundosDePregunta('opcion_multiple');
    void minutosAnotados(String ruta, num? preguntas) {
      final anotado = numeroEn(datos, ruta);
      if (anotado == null || preguntas == null || seg == null) return;
      final calculado = preguntas * seg / 60;
      if ((anotado - calculado).abs() > 0.06) {
        err(
          '$ruta anota ${_n(anotado)} minutos y $preguntas preguntas de $seg segundos dan ${calculado.toStringAsFixed(1)}',
        );
      }
    }

    minutosAnotados('viernes.mini_prueba.minutos_estimados', pregMini);
    minutosAnotados(
      'viernes.prueba_por_unidad.minutos_estimados.con_audio',
      con,
    );
    minutosAnotados(
      'viernes.prueba_por_unidad.minutos_estimados.sin_audio',
      sin,
    );
  }

  /// V21 acepta sesiones con los mínimos del contrato; V22 las rechaza si esos
  /// mínimos no llegan al 70 % del bloque. Este contraste lo hace sobre el
  /// contrato, antes de que haya una sola sesión (así se calibraron en P1.1b los
  /// mínimos de martes, miércoles y jueves).
  void _minimosAlcanzanLaBanda(ContratoSesion k) {
    final mn = k.porcentajeMinimoPorBloque;
    final ppm = k.palabrasPorMinuto;
    final segEj = k.segundosPorEjemplo;
    final segFrase = k.segundosPorFrase;
    final segEl = k.segundosPorElemento;
    final segTar = k.segundosPorTarjetaNueva;
    final segOm = k.segundosDePregunta('opcion_multiple');
    if (mn == null ||
        ppm == null ||
        segEj == null ||
        segFrase == null ||
        segEl == null ||
        segTar == null ||
        segOm == null) {
      return;
    }

    void contraste(
      String bloque,
      num? declarados,
      double estimado, {
      DatoPendiente? pendiente,
    }) {
      if (declarados == null || declarados <= 0) return;
      final pct = estimado / declarados * 100;
      if (pct >= mn - 1e-9) return;
      final m =
          'los mínimos del contrato para $bloque estiman ${estimado.toStringAsFixed(1)} minutos, el ${pct.round()} % de los ${_n(declarados)} declarados, y V22 pide el $mn %: V21 aceptaría sesiones que V22 rechaza';
      h.add(
        pendiente == null
            ? error(a, 'V27', m)
            : aviso(
                a,
                'V27',
                '$m (dato pendiente en el contrato: ${pendiente.ruta})',
              ),
      );
    }

    for (final dia in k.dias) {
      final sustituida = k.leccionSustituidaPor(dia);
      if (sustituida != null) continue; // el viernes se contrasta aparte
      final pend = k.pendienteDeLeccion(dia);
      final ej = k.ejemplosMinimos(dia) ?? 0;
      final preg = k.preguntasMinimasDeLeccion(dia) ?? 0;
      final el = k.elementosDeLeccion(dia) ?? 0;
      // El texto de la lección de lectura, con la etapa más corta: palabras ÷ 150.
      var lectura = 0.0;
      if (k.estimuloDeLeccion(dia) == 'texto') {
        final menores = [
          for (final e in etapas)
            if (numeroEn(datos, 'longitudes_por_etapa.$e.lectura_palabras.min')
                case final num m)
              m,
        ];
        if (menores.isNotEmpty) {
          lectura = menores.reduce((x, y) => x < y ? x : y) / ppm;
        }
      }
      contraste(
        'la lección del $dia',
        k.minutosDeParte('leccion'),
        ej * segEj / 60 + preg * segOm / 60 + el * segEl / 60 + lectura,
        pendiente: pend,
      );
      final elp = k.elementosDePronunciacion(dia);
      if (elp != null) {
        contraste(
          'la pronunciación del $dia',
          k.minutosDeParte('pronunciacion'),
          elp * segEl / 60,
        );
      }
    }
    final frases = k.frasesMinimas;
    if (frases != null) {
      final audios = k.audiosDeTraslado ?? 0;
      final menores = [
        for (final e in etapas)
          if (mapaEn(datos, 'longitudes_por_etapa.$e.audio_palabras')?['min']
              is num)
            (mapaEn(datos, 'longitudes_por_etapa.$e.audio_palabras')!['min']!
                as num),
      ];
      if (menores.isNotEmpty) {
        final repro = k.reproduccionesDeTraslado ?? 1;
        final audio =
            audios * menores.reduce((x, y) => x < y ? x : y) / ppm * repro;
        final tarjetasMin = [
          for (final d in k.dias) k.tarjetasNuevasDelDia(d) ?? 0,
        ].reduce((x, y) => x < y ? x : y);
        contraste(
          'el traslado (con el audio más corto, A1, y el día sin tarjetas nuevas)',
          k.minutosTraslado,
          audio +
              frases * segFrase / 60 +
              tarjetasMin * segTar / 60 +
              (k.minutosDeParte('traslado-tarjetas') ?? 0),
          pendiente: k.pendienteDeTarjetasNuevas,
        );
      }
    }
    // Viernes: la conversación guiada con el menor número de turnos que V21 acepta.
    final turnos = k.turnosMinimosDeConversacion;
    if (turnos != null) {
      final persona = k.turnosMinimosDeLaPersona;
      final sistema = turnos > persona ? turnos - persona : 0;
      final estimado =
          (persona * k.segundosPorTurnoDePersona +
              sistema * k.segundosPorTurnoDeSistema) /
          60;
      final pend = pendientesEn(
        mapaEn(datos, 'viernes.estructura_de_la_conversacion_guiada'),
        'viernes.estructura_de_la_conversacion_guiada',
      );
      contraste(
        'la conversación guiada ($turnos turnos, $persona de la persona)',
        k.minutosDeParte('leccion'),
        estimado,
        pendiente: pend.isEmpty ? null : pend.first,
      );
    }
    final pregMini = k.preguntasDeMiniPrueba;
    if (pregMini != null) {
      contraste(
        'la mini prueba',
        k.minutosDeParte('repaso'),
        pregMini * segOm / 60,
      );
    }
    final sinAudio = k.preguntasDePruebaSinAudio;
    if (sinAudio != null) {
      contraste(
        'la prueba por unidad sin audio',
        k.minutosDeParte('leccion'),
        sinAudio * segOm / 60,
      );
    }
  }

  // ========================================================= gravity-escalon

  List<Hallazgo> escalon() {
    requiere({
      'totales.escalones': 'los 13 escalones',
      'totales.horas_por_escalon': 'horas = 40 × escalones',
      'totales.horas_totales': 'horas = 40 × escalones',
      'escalera.escalones_total': 'los 13 escalones',
      'escalera.semanas_por_escalon': 'semanas del escalón',
      'escalera.dias_por_semana': 'días del escalón',
      'escalera.minutos_por_dia': 'minutos del día',
      'escalera.horas_por_escalon': 'horas por escalón',
      'escalera.horas_totales': 'horas totales',
    });
    final esc = numeroEn(datos, 'totales.escalones');
    iguales(
      'totales.escalones y escalera.escalones_total',
      esc,
      numeroEn(datos, 'escalera.escalones_total'),
    );
    final horas = numeroEn(datos, 'totales.horas_por_escalon');
    iguales(
      'totales.horas_por_escalon y escalera.horas_por_escalon',
      horas,
      numeroEn(datos, 'escalera.horas_por_escalon'),
    );
    if (horas != null && esc != null) {
      iguales(
        'totales.horas_totales y horas_por_escalon × escalones',
        numeroEn(datos, 'totales.horas_totales'),
        horas * esc,
      );
      iguales(
        'escalera.horas_totales y horas_por_escalon × escalones',
        numeroEn(datos, 'escalera.horas_totales'),
        horas * esc,
      );
    }
    final sem = numeroEn(datos, 'escalera.semanas_por_escalon');
    final dias = numeroEn(datos, 'escalera.dias_por_semana');
    final min = numeroEn(datos, 'escalera.minutos_por_dia');
    if (horas != null && sem != null && dias != null && min != null) {
      iguales(
        'las horas por escalón y semanas × días × minutos ÷ 60',
        horas,
        sem * dias * min / 60,
      );
    }
    // Etapas.
    final etapasLista = [
      for (final e in listaEn(datos, 'etapas') ?? const <Object?>[])
        if (e is Map<String, Object?>) e,
    ];
    iguales(
      'totales.etapas y las etapas listadas',
      numeroEn(datos, 'totales.etapas'),
      etapasLista.length,
    );
    var acumulados = 0;
    var cuantos = 0;
    for (final e in etapasLista) {
      final lista = textosEn(e, 'escalones') ?? const [];
      cuantos += lista.length;
      acumulados += lista.length;
      if (horas != null) {
        final ac = e['horas_acumuladas'];
        if (ac is num && ac != horas * acumulados) {
          err(
            'la etapa ${e['id']} acumula ${_n(ac)} horas y ${lista.length} escalones más los anteriores dan ${_n(horas * acumulados)}',
          );
        }
      }
      if (lista.isNotEmpty && e['escalon_de_cierre'] != lista.last) {
        err(
          'la etapa ${e['id']} cierra en ${e['escalon_de_cierre']} y su último escalón es ${lista.last}',
        );
      }
    }
    iguales(
      'escalera.escalones_total y los escalones de las etapas',
      esc,
      cuantos,
    );
    if (horas != null && etapasLista.isNotEmpty && esc != null) {
      final ult = etapasLista.last['horas_acumuladas'];
      if (ult is num && ult != horas * esc) {
        err(
          'la última etapa acumula $ult horas y las horas totales son ${_n(horas * esc)}',
        );
      }
    }
    // Habilidades.
    final habs = textosEn(datos, 'habilidades.lista');
    iguales(
      'totales.habilidades y habilidades.lista',
      numeroEn(datos, 'totales.habilidades'),
      habs?.length,
    );
    final peso = numeroEn(datos, 'habilidades.peso_en_el_resultado');
    if (habs != null && peso != null && peso * habs.length != 100) {
      err('las ${habs.length} habilidades de ${_n(peso)} % no suman 100 %');
    }
    // Formas y pruebas por unidad.
    final porPuerta = numeroEn(datos, 'totales.formas_por_puerta');
    iguales(
      'totales.formas_por_puerta y formas.por_puerta',
      porPuerta,
      numeroEn(datos, 'formas.por_puerta'),
    );
    final opo = numeroEn(datos, 'formas.oportunidades');
    final res = numeroEn(datos, 'formas.reserva');
    if (porPuerta != null && opo != null && res != null) {
      iguales(
        'formas por puerta y oportunidades + reserva',
        porPuerta,
        opo + res,
      );
    }
    iguales(
      'oportunidades.por_puerta y formas.oportunidades',
      numeroEn(datos, 'oportunidades.por_puerta'),
      opo,
    );
    iguales(
      'formas.total.puertas y los escalones',
      numeroEn(datos, 'formas.total.puertas'),
      esc,
    );
    if (esc != null && porPuerta != null) {
      iguales(
        'formas.total.formas_de_puerta y puertas × formas por puerta',
        numeroEn(datos, 'formas.total.formas_de_puerta'),
        esc * porPuerta,
      );
    }
    final k = c.contratoSesion;
    final porEscalon = numeroEn(
      datos,
      'formas.pruebas_por_unidad.formas_por_escalon',
    );
    final pregPorEscalon = numeroEn(
      datos,
      'formas.pruebas_por_unidad.preguntas_por_escalon',
    );
    final con = numeroEn(
      datos,
      'formas.pruebas_por_unidad.preguntas_por_forma.con_audio',
    );
    if (k != null && k.pruebasPorEscalon != null) {
      iguales(
        'formas.pruebas_por_unidad.formas_por_escalon y 4 unidades × formas a y b',
        porEscalon,
        k.pruebasPorEscalon! * 2,
      );
    }
    if (porEscalon != null && con != null) {
      iguales(
        'formas.pruebas_por_unidad.preguntas_por_escalon y formas × preguntas con audio',
        pregPorEscalon,
        porEscalon * con,
      );
    }
    if (k != null) {
      iguales(
        'formas.pruebas_por_unidad.preguntas_por_forma.con_audio y gravity-sesion-60',
        con,
        k.preguntasDePruebaConAudio,
      );
      iguales(
        'formas.pruebas_por_unidad.preguntas_por_forma.sin_audio y gravity-sesion-60',
        numeroEn(
          datos,
          'formas.pruebas_por_unidad.preguntas_por_forma.sin_audio',
        ),
        k.preguntasDePruebaSinAudio,
      );
    }
    if (pregPorEscalon != null && esc != null) {
      iguales(
        'formas.pruebas_por_unidad.preguntas_en_13_escalones y preguntas por escalón × escalones',
        numeroEn(datos, 'formas.pruebas_por_unidad.preguntas_en_13_escalones'),
        pregPorEscalon * esc,
      );
    }
    // Contra gravity-sesion-60: asistencia, minutos y mini prueba.
    if (k == null) {
      h.add(
        faltante(
          a,
          'V27',
          'falta el contrato gravity-sesion-60: no se pueden contrastar asistencia, minutos y mini prueba',
        ),
      );
    } else {
      iguales(
        'escalera.minutos_por_dia y totales.minutos de gravity-sesion-60',
        min,
        k.minutosTotales,
      );
      iguales(
        'escalera.dias_por_semana y totales.sesiones_por_semana de gravity-sesion-60',
        dias,
        k.sesionesPorSemana,
      );
      iguales(
        'el faltante máximo por día (segundos) de gravity-escalon y de gravity-sesion-60',
        numeroEn(
          datos,
          'requisitos_para_subir.minutos.faltante_maximo_por_dia_segundos',
        ),
        k.faltanteMaximoPorDia,
      );
      iguales(
        'los días faltados por escalón de gravity-escalon y de gravity-sesion-60',
        numeroEn(
          datos,
          'requisitos_para_subir.constancia.dias_faltados_maximos_por_escalon',
        ),
        k.diasFaltadosPorEscalon,
      );
      iguales(
        'minutos planeados por día con audio de gravity-escalon y de gravity-sesion-60',
        numeroEn(
          datos,
          'requisitos_para_subir.minutos.minutos_planeados_por_dia.con_audio',
        ),
        k.minutosPlaneadosConAudio,
      );
      iguales(
        'minutos planeados por día sin audio de gravity-escalon y de gravity-sesion-60',
        numeroEn(
          datos,
          'requisitos_para_subir.minutos.minutos_planeados_por_dia.sin_audio',
        ),
        k.minutosPlaneadosSinAudio,
      );
      iguales(
        'mini_prueba.preguntas de gravity-escalon y de gravity-sesion-60',
        numeroEn(datos, 'mini_prueba.preguntas'),
        k.preguntasDeMiniPrueba,
      );
      iguales(
        'mini_prueba.aprobar_con de gravity-escalon y de gravity-sesion-60',
        numeroEn(datos, 'mini_prueba.aprobar_con'),
        k.aprobarMiniPruebaCon,
      );
      final ms = enterosEn(datos, 'mini_prueba.semanas');
      if (ms != null &&
          k.semanasDeMiniPrueba != null &&
          ms.join(',') != k.semanasDeMiniPrueba!.join(',')) {
        err(
          'mini_prueba.semanas de gravity-escalon (${ms.join(', ')}) y de gravity-sesion-60 (${k.semanasDeMiniPrueba!.join(', ')}) no coinciden',
        );
      }
      iguales(
        'las pruebas por unidad que hay que aprobar y las del viernes de gravity-sesion-60',
        numeroEn(datos, 'requisitos_para_subir.pruebas_aprobadas.unidades'),
        k.pruebasPorEscalon,
      );
      iguales(
        'el umbral de la prueba por unidad y el mínimo por habilidad de la puerta',
        k.umbralDePruebaPorcentaje,
        numeroEn(datos, 'aprobar.por_habilidad.porcentaje_minimo'),
      );
    }
    iguales(
      'evaluacion_de_cierre.porcentaje_minimo_por_habilidad y aprobar.por_habilidad.porcentaje_minimo',
      numeroEn(
        datos,
        'requisitos_para_subir.evaluacion_de_cierre.porcentaje_minimo_por_habilidad',
      ),
      numeroEn(datos, 'aprobar.por_habilidad.porcentaje_minimo'),
    );
    final anticipada = numeroEn(
      datos,
      'puerta_anticipada.porcentaje_minimo_por_habilidad',
    );
    final minimo = numeroEn(datos, 'aprobar.por_habilidad.porcentaje_minimo');
    if (anticipada != null && minimo != null && anticipada <= minimo) {
      err(
        'la puerta anticipada (${_n(anticipada)} %) debe ser más exigente que la puerta (${_n(minimo)} %)',
      );
    }
    // Las puertas de examen tienen su contrato.
    for (final e in etapasLista) {
      final f = mapaEn(e, 'puerta')?['formato'];
      if (f is String && f != idContratoEscalon && c.contrato(f) == null) {
        h.add(
          faltante(
            a,
            'V27',
            'la puerta de la etapa ${e['id']} usa el contrato "$f", que no existe',
          ),
        );
      }
    }
    return h;
  }

  // ======================================================= gravity-ubicacion

  List<Hallazgo> ubicacion() {
    requiere({
      'totales.etapas': 'etapas de la prueba',
      'totales.preguntas_por_etapa': '12 por etapa',
      'totales.preguntas': '48 preguntas',
      'corte.aciertos_minimos': 'el corte',
      'banco.preguntas_por_etapa': 'el banco',
      'banco.preguntas_total': 'el banco',
    });
    final secciones = [
      for (final s in listaEn(datos, 'secciones') ?? const <Object?>[])
        if (s is Map<String, Object?>) s,
    ];
    final etapasN = numeroEn(datos, 'totales.etapas');
    final porEtapa = numeroEn(datos, 'totales.preguntas_por_etapa');
    iguales('totales.etapas y las secciones', etapasN, secciones.length);
    iguales(
      'totales.preguntas y etapas × preguntas por etapa',
      numeroEn(datos, 'totales.preguntas'),
      etapasN == null || porEtapa == null ? null : etapasN * porEtapa,
    );
    if (porEtapa != null) {
      iguales(
        'totales.preguntas_por_etapa y 6 + 3 + 3',
        porEtapa,
        ubicacionGramatica + ubicacionLectura + ubicacionEscucha,
      );
    }
    iguales(
      'banco.forma.preguntas_total y totales.preguntas',
      numeroEn(datos, 'banco.forma.preguntas_total'),
      numeroEn(datos, 'totales.preguntas'),
    );
    iguales(
      'banco.forma.preguntas_por_etapa y totales.preguntas_por_etapa',
      numeroEn(datos, 'banco.forma.preguntas_por_etapa'),
      porEtapa,
    );
    final bancoPorEtapa = numeroEn(datos, 'banco.preguntas_por_etapa');
    if (bancoPorEtapa != null && etapasN != null) {
      iguales(
        'banco.preguntas_total y etapas × banco.preguntas_por_etapa',
        numeroEn(datos, 'banco.preguntas_total'),
        bancoPorEtapa * etapasN,
      );
    }
    if (bancoPorEtapa != null && porEtapa != null && bancoPorEtapa < porEtapa) {
      err(
        'el banco de ${_n(bancoPorEtapa)} preguntas por etapa no alcanza para una forma de ${_n(porEtapa)}',
      );
    }
    final de = numeroEn(datos, 'corte.de');
    if (de != null && porEtapa != null && de != porEtapa) {
      err(
        'corte.de (${_n(de)}) debe ser las preguntas por etapa (${_n(porEtapa)})',
      );
    }
    final corte = numeroEn(datos, 'corte.aciertos_minimos');
    if (corte != null && porEtapa != null && corte > porEtapa) {
      err('el corte (${_n(corte)} aciertos) pasa de las preguntas por etapa');
    }

    final orden = textosEn(datos, 'orden_de_etapas.etapas');
    if (orden != null && orden.join(',') != etapas.join(',')) {
      err(
        'orden_de_etapas (${orden.join(', ')}) debe ser ${etapas.join(', ')}',
      );
    }
    final k = c.contratoSesion;
    for (var i = 0; i < secciones.length; i++) {
      final s = secciones[i];
      final etapa = s['etapa'];
      if (i < etapas.length && etapa != etapas[i]) {
        err('la sección ${i + 1} es de $etapa y debería ser de ${etapas[i]}');
      }
      iguales(
        'el orden de la sección $etapa y su posición',
        s['orden'] as num?,
        i + 1,
      );
      final partes = [
        for (final p in listaEn(s, 'partes') ?? const <Object?>[])
          if (p is Map<String, Object?>) p,
      ];
      var suma = 0;
      final porEstimulo = <String, int>{};
      for (final p in partes) {
        final u = p['unidades'];
        final pu = p['preguntas_por_unidad'];
        final total = p['preguntas_total'];
        if (u is num && pu is num && total is num && u * pu != total) {
          err(
            'la parte ${p['id']} tiene $u unidades de $pu preguntas y declara $total',
          );
        }
        if (total is num) {
          suma += total.toInt();
          final tipo = '${p['tipo_estimulo']}';
          porEstimulo[tipo] = (porEstimulo[tipo] ?? 0) + total.toInt();
        }
      }
      iguales(
        'preguntas_total de la sección $etapa y la suma de sus partes',
        s['preguntas_total'] as num?,
        suma,
      );
      if (porEtapa != null) {
        iguales(
          'la suma de las partes de la sección $etapa y las preguntas por etapa',
          suma,
          porEtapa,
        );
      }
      final esperado = {
        'ninguno': ubicacionGramatica,
        'texto': ubicacionLectura,
        'audio': ubicacionEscucha,
      };
      for (final e in esperado.entries) {
        if ((porEstimulo[e.key] ?? 0) != e.value) {
          err(
            'la sección $etapa trae ${porEstimulo[e.key] ?? 0} preguntas con estímulo ${e.key} y el plan pide ${e.value} (6 + 3 + 3)',
          );
        }
      }
      // Longitudes: las mismas que la tabla de gravity-sesion-60.
      if (k != null && etapa is String) {
        for (final p in partes) {
          final tipo = p['tipo_estimulo'];
          if (tipo != 'texto' && tipo != 'audio') continue;
          final clave = tipo == 'texto' ? 'lectura_palabras' : 'audio_palabras';
          final r = mapaEn(k.datos, 'longitudes_por_etapa.$etapa.$clave');
          final propio = mapaEn(p, 'palabras_estimulo');
          if (r == null || propio == null) {
            falta(
              'palabras_estimulo de ${p['id']}',
              'el rango de longitud de la ubicación',
            );
          } else if (r['min'] != propio['min'] || r['max'] != propio['max']) {
            err(
              '${p['id']} mide ${propio['min']} a ${propio['max']} palabras y la tabla de gravity-sesion-60 da ${r['min']} a ${r['max']} para $etapa ($clave)',
            );
          }
        }
      }
    }
    if (k == null) {
      h.add(
        faltante(
          a,
          'V27',
          'falta el contrato gravity-sesion-60: no se pueden contrastar los rangos de longitud',
        ),
      );
    }
    return h;
  }

  // ============================================================== niveles.yaml

  List<Hallazgo> niveles() {
    final escalones = (a as ArchivoNiveles).niveles.escalonesEnOrden;
    final escalon = c.contrato(idContratoEscalon);
    final ed = escalon?.datos;
    final nEsc = numeroEn(ed, 'totales.escalones');
    iguales(
      'los escalones de niveles.yaml y totales.escalones de gravity-escalon',
      escalones.length,
      nEsc,
    );
    if (escalones.isEmpty) {
      h.add(faltante(a, 'V27', 'niveles.yaml no trae escalones'));
      return h;
    }
    iguales(
      'totales.escalones de niveles.yaml y los escalones listados',
      numeroEn(datos, 'totales.escalones'),
      escalones.length,
    );
    final horas = numeroEn(ed, 'totales.horas_por_escalon');
    iguales(
      'totales.horas_por_escalon de niveles.yaml y de gravity-escalon',
      numeroEn(datos, 'totales.horas_por_escalon'),
      horas,
    );
    iguales(
      'totales.horas_totales de niveles.yaml y de gravity-escalon',
      numeroEn(datos, 'totales.horas_totales'),
      numeroEn(ed, 'totales.horas_totales'),
    );
    iguales(
      'totales.semanas_por_escalon de niveles.yaml y escalera.semanas_por_escalon de gravity-escalon',
      numeroEn(datos, 'totales.semanas_por_escalon'),
      numeroEn(ed, 'escalera.semanas_por_escalon'),
    );
    iguales(
      'totales.etapas de niveles.yaml y de gravity-escalon',
      numeroEn(datos, 'totales.etapas'),
      numeroEn(ed, 'totales.etapas'),
    );
    if (escalon == null) {
      h.add(
        faltante(
          a,
          'V27',
          'falta el contrato gravity-escalon: no se pueden contrastar horas, etapas y puertas',
        ),
      );
    }

    final etapasEscalon = {
      for (final e in listaEn(ed, 'etapas') ?? const <Object?>[])
        if (e is Map<String, Object?> && e['id'] is String)
          e['id']! as String: e,
    };
    final ids = <String>[];
    final orden = <String, int>{};
    final nuevoEn = <String, String>{};
    for (var i = 0; i < escalones.length; i++) {
      final e = escalones[i];
      final id = e['id'] as String?;
      if (id == null) {
        err('el escalón ${i + 1} no trae id');
        continue;
      }
      if (ids.contains(id)) err('el escalón $id está repetido');
      ids.add(id);
      orden[id] = i + 1;
      iguales(
        'el orden de $id y su posición en la escalera',
        e['orden'] as num?,
        i + 1,
      );
      if (horas != null) {
        iguales(
          'las horas de $id y las de gravity-escalon',
          e['horas'] as num?,
          horas,
        );
        iguales(
          'horas_acumuladas_al_cerrar de $id y 40 × su orden',
          e['horas_acumuladas_al_cerrar'] as num?,
          horas * (i + 1),
        );
      }
      iguales(
        'las semanas de $id y escalera.semanas_por_escalon',
        e['semanas'] as num?,
        numeroEn(ed, 'escalera.semanas_por_escalon'),
      );
      for (final hab in const ['lectura', 'escucha', 'escritura', 'habla']) {
        final d = en(e, 'puedo.$hab');
        if (d is! String || d.trim().isEmpty) {
          err('el escalón $id no trae el descriptor "puedo" de $hab');
        }
      }
      final etapa = e['etapa'];
      final de = etapasEscalon[etapa];
      if (escalon != null) {
        if (de == null) {
          err('la etapa "$etapa" de $id no existe en gravity-escalon');
        } else {
          final lista = textosEn(de, 'escalones') ?? const [];
          if (!lista.contains(id)) {
            err('gravity-escalon no pone a $id en la etapa $etapa');
          }
          final cierra = de['escalon_de_cierre'] == id;
          iguales(
            'horas_acumuladas_al_pasar_la_puerta_de_etapa de $id y las horas acumuladas de la etapa $etapa',
            e['horas_acumuladas_al_pasar_la_puerta_de_etapa'] as num?,
            de['horas_acumuladas'] as num?,
          );
          final puerta = e['puerta'];
          if (puerta is Map) {
            final puertaEtapa = mapaEn(de, 'puerta');
            final Object? esperadoTipo = cierra
                ? (puertaEtapa == null ? null : puertaEtapa['tipo'])
                : 'escalon';
            final Object? esperadoFormato = cierra
                ? (puertaEtapa == null ? null : puertaEtapa['formato'])
                : idContratoEscalon;
            if (esperadoTipo != null && puerta['tipo'] != esperadoTipo) {
              err(
                'la puerta de $id es de tipo ${puerta['tipo']} y gravity-escalon dice $esperadoTipo',
              );
            }
            if (esperadoFormato != null &&
                puerta['formato'] != esperadoFormato) {
              err(
                'la puerta de $id usa ${puerta['formato']} y gravity-escalon dice $esperadoFormato',
              );
            }
          }
        }
      }
      for (final t in textosEn(e, 'gramatica_nueva') ?? const <String>[]) {
        if (nuevoEn.containsKey(t)) {
          err(
            'el tema $t es nuevo en ${nuevoEn[t]} y en $id: un tema es nuevo en un solo escalón',
            id: id,
          );
        } else {
          nuevoEn[t] = id;
        }
      }
    }

    // Las etapas de niveles.yaml contra las de gravity-escalon.
    for (final n in [
      for (final e in listaEn(datos, 'niveles') ?? const <Object?>[])
        if (e is Map<String, Object?>) e,
    ]) {
      final id = n['id'];
      final de = etapasEscalon[id];
      if (escalon != null && de == null) {
        err('la etapa $id de niveles.yaml no existe en gravity-escalon');
        continue;
      }
      if (de == null) continue;
      final a1 = (textosEn(n, 'escalones') ?? const []).join(',');
      final a2 = (textosEn(de, 'escalones') ?? const []).join(',');
      if (a1 != a2) {
        err(
          'los escalones de la etapa $id son $a1 en niveles.yaml y $a2 en gravity-escalon',
        );
      }
      if (n['escalon_de_cierre'] != de['escalon_de_cierre']) {
        err(
          'la etapa $id cierra en ${n['escalon_de_cierre']} en niveles.yaml y en ${de['escalon_de_cierre']} en gravity-escalon',
        );
      }
      iguales(
        'horas_acumuladas de la etapa $id en niveles.yaml y en gravity-escalon',
        n['horas_acumuladas'] as num?,
        de['horas_acumuladas'] as num?,
      );
      final pn = mapaEn(n, 'puerta');
      final pe = mapaEn(de, 'puerta');
      if (pn != null &&
          pe != null &&
          (pn['tipo'] != pe['tipo'] || pn['formato'] != pe['formato'])) {
        err(
          'la puerta de la etapa $id es ${pn['tipo']}/${pn['formato']} en niveles.yaml y ${pe['tipo']}/${pe['formato']} en gravity-escalon',
        );
      }
    }

    // Temas: cada uno es nuevo en un solo escalón y solo se retoma después.
    final temas = (a as ArchivoNiveles).niveles.temas;
    for (final t in temas) {
      if (!nuevoEn.containsKey(t)) {
        err(
          'el tema $t está en la lista de temas y no es nuevo en ningún escalón',
        );
      }
    }
    for (final t in nuevoEn.keys) {
      if (temas.isNotEmpty && !temas.contains(t)) {
        err(
          'el tema $t es nuevo en ${nuevoEn[t]} y no está en la lista de temas',
        );
      }
    }
    for (final e in escalones) {
      final id = e['id'] as String?;
      if (id == null) continue;
      for (final t
          in textosEn(e, 'gramatica_que_se_retoma') ?? const <String>[]) {
        final donde = nuevoEn[t];
        if (donde == null) {
          err('$id retoma $t, que no es nuevo en ningún escalón', id: id);
        } else if ((orden[donde] ?? 0) >= (orden[id] ?? 0)) {
          err(
            '$id retoma $t, que es nuevo en $donde: un escalón solo retoma temas de escalones anteriores',
            id: id,
          );
        }
      }
    }

    // Temario por semana: reparte exactamente los temas nuevos del escalón.
    final porSemana = mapaEn(datos, 'temario_por_semana');
    if (porSemana != null) {
      for (final entrada in porSemana.entries) {
        final id = entrada.key;
        final semanas = entrada.value;
        final e = escalones.where((x) => x['id'] == id).firstOrNull;
        if (e == null) {
          err('temario_por_semana trae el escalón $id, que no existe');
          continue;
        }
        if (semanas is! List) continue;
        final nSem = numeroEn(datos, 'totales.semanas_por_escalon');
        if (nSem != null && semanas.length != nSem) {
          err(
            'el temario de $id trae ${semanas.length} semanas y el escalón dura ${_n(nSem)}',
          );
        }
        final vistos = <String>[];
        final nuevos = <String>{};
        for (var i = 0; i < semanas.length; i++) {
          final s = semanas[i];
          if (s is! Map) continue;
          iguales(
            'el número de la semana ${i + 1} del temario de $id',
            s['semana'] as num?,
            i + 1,
          );
          for (final t in textosEn(s, 'gramatica_nueva') ?? const <String>[]) {
            if (!nuevos.add(t)) {
              err('el tema $t es nuevo en dos semanas de $id');
            }
            if (nuevoEn[t] != id) {
              err(
                'la semana ${i + 1} de $id da como nuevo $t, que no es nuevo en $id (lo es en ${nuevoEn[t]})',
              );
            }
          }
          for (final t in textosEn(s, 'retoma') ?? const <String>[]) {
            final donde = nuevoEn[t];
            final enAnterior =
                donde != null && (orden[donde] ?? 0) < (orden[id] ?? 0);
            if (!enAnterior && !vistos.contains(t)) {
              err(
                'la semana ${i + 1} de $id retoma $t antes de verlo (es nuevo en ${donde ?? 'ningún escalón'})',
              );
            }
          }
          vistos.addAll(textosEn(s, 'gramatica_nueva') ?? const <String>[]);
        }
        final propios = (textosEn(e, 'gramatica_nueva') ?? const <String>[])
            .toSet();
        if (nuevos.length != propios.length || !nuevos.containsAll(propios)) {
          err(
            'el temario por semana de $id reparte ${nuevos.length} temas nuevos y el escalón tiene ${propios.length}',
          );
        }
      }
    }

    // Los inventarios de los manuales quedan vistos al cerrar la etapa.
    final cobertura = mapaEn(datos, 'cobertura_de_manuales');
    if (cobertura != null) {
      for (final entrada in cobertura.entries) {
        final m = entrada.value;
        if (m is! Map || m['cierra_en'] is! String) continue;
        final cierre = orden[m['cierra_en']];
        if (cierre == null) {
          err('${entrada.key}: cierra_en ${m['cierra_en']} no es un escalón');
          continue;
        }
        for (final it in listaEn(m, 'items') ?? const <Object?>[]) {
          if (it is! Map) continue;
          for (final t in textosEn(it, 'temas') ?? const <String>[]) {
            final donde = nuevoEn[t];
            if (donde == null) {
              err(
                '${entrada.key}: «${it['elemento']}» apunta a $t, que no es nuevo en ningún escalón',
              );
            } else if (orden[donde]! > cierre) {
              err(
                '${entrada.key}: «${it['elemento']}» apunta a $t, que es nuevo en $donde, después de cerrar la etapa en ${m['cierra_en']}',
              );
            }
          }
        }
        for (final v
            in listaEn(cobertura, 'temas_de_vocabulario.${entrada.key}') ??
                const <Object?>[]) {
          if (v is! Map) continue;
          final donde = orden[v['escalon']];
          if (donde == null) {
            err(
              '${entrada.key}: el tema de vocabulario «${v['tema']}» está en el escalón ${v['escalon']}, que no existe',
            );
          } else if (donde > cierre) {
            err(
              '${entrada.key}: el tema de vocabulario «${v['tema']}» se ve en ${v['escalon']}, después de cerrar la etapa en ${m['cierra_en']}',
            );
          }
        }
      }
    }
    return h;
  }
}
