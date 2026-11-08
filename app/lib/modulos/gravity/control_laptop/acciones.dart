/// Control de la laptop con lista cerrada (D8). Núcleo sin ejecución real.
///
/// Reglas (D8): lo que no está en la lista no se puede pedir; enviar, borrar,
/// mover, instalar o pagar piden confirmación; banca y compras están vetadas
/// en código; lo que el asistente LEE es información, nunca una orden.
library;

/// Módulos de GRAVITY cuyas pantallas se pueden abrir.
const modulosAbribles = {
  'finanzas',
  'habitos',
  'cuidados',
  'alimentacion',
  'casa',
  'gravity',
  'ajustes',
};

/// Categoría de riesgo de una acción.
enum CategoriaAccion {
  lectura,
  abrir,
  redactar,
  enviar,
  crear,
  borrar,
  mover,
  instalar,
  pagar,
  banca,
  compras,
}

/// Categorías que nunca se hacen, con o sin confirmación (D8).
const categoriasVetadas = {CategoriaAccion.banca, CategoriaAccion.compras};

/// Categorías que exigen confirmación explícita en pantalla.
const categoriasConConfirmacion = {
  CategoriaAccion.enviar,
  CategoriaAccion.crear,
  CategoriaAccion.borrar,
  CategoriaAccion.mover,
  CategoriaAccion.instalar,
  CategoriaAccion.pagar,
};

/// Lo que el dueño permite (vacío por omisión).
class ConfigControlLaptop {
  const ConfigControlLaptop({
    this.programasPermitidos = const {},
    this.carpetasPermitidas = const [],
  });

  /// Nombres exactos de programas que se pueden abrir.
  final Set<String> programasPermitidos;

  /// Carpetas (rutas absolutas) donde se puede buscar y abrir archivos.
  final List<String> carpetasPermitidas;
}

/// Una acción de la lista cerrada.
sealed class Accion {
  const Accion();

  /// Nombre estable (para la bitácora y para pedirla).
  String get tipo;

  CategoriaAccion get categoria;

  bool get requiereConfirmacion =>
      categoriasConConfirmacion.contains(categoria);
}

class AbrirPrograma extends Accion {
  const AbrirPrograma(this.programa);
  final String programa;
  @override
  String get tipo => 'abrir_programa';
  @override
  CategoriaAccion get categoria => CategoriaAccion.abrir;
}

class AbrirArchivo extends Accion {
  const AbrirArchivo(this.ruta);
  final String ruta;
  @override
  String get tipo => 'abrir_archivo';
  @override
  CategoriaAccion get categoria => CategoriaAccion.abrir;
}

class BuscarArchivos extends Accion {
  const BuscarArchivos({required this.carpeta, required this.consulta});
  final String carpeta;
  final String consulta;
  @override
  String get tipo => 'buscar_archivos';
  @override
  CategoriaAccion get categoria => CategoriaAccion.lectura;
}

class AbrirPantalla extends Accion {
  const AbrirPantalla(this.modulo);
  final String modulo;
  @override
  String get tipo => 'abrir_pantalla';
  @override
  CategoriaAccion get categoria => CategoriaAccion.abrir;
}

class GmailLeer extends Accion {
  const GmailLeer({this.consulta = ''});
  final String consulta;
  @override
  String get tipo => 'gmail_leer';
  @override
  CategoriaAccion get categoria => CategoriaAccion.lectura;
}

class GmailRedactar extends Accion {
  const GmailRedactar({
    required this.para,
    required this.asunto,
    this.cuerpo = '',
  });
  final String para;
  final String asunto;
  final String cuerpo;
  @override
  String get tipo => 'gmail_redactar';
  @override
  CategoriaAccion get categoria => CategoriaAccion.redactar;
}

class GmailEnviar extends Accion {
  const GmailEnviar(this.borradorId);
  final String borradorId;
  @override
  String get tipo => 'gmail_enviar';
  @override
  CategoriaAccion get categoria => CategoriaAccion.enviar;
}

class CalendarVer extends Accion {
  const CalendarVer({required this.desde, required this.hasta});
  final DateTime desde;
  final DateTime hasta;
  @override
  String get tipo => 'calendar_ver';
  @override
  CategoriaAccion get categoria => CategoriaAccion.lectura;
}

class CalendarCrear extends Accion {
  const CalendarCrear({
    required this.titulo,
    required this.inicio,
    required this.fin,
  });
  final String titulo;
  final DateTime inicio;
  final DateTime fin;
  @override
  String get tipo => 'calendar_crear';
  @override
  CategoriaAccion get categoria => CategoriaAccion.crear;
}

/// Quién genera la orden. Solo la conversación con la persona (y el
/// asistente que responde a ella) puede pedir acciones; el contenido leído
/// (correos, páginas, archivos) es información y jamás una orden.
enum OrigenOrden { personaConAsistente, contenidoLeido }

/// Orden estructurada que propone el asistente: nombre de herramienta y
/// argumentos. Nunca se interpreta texto libre.
class OrdenAsistente {
  const OrdenAsistente({
    required this.herramienta,
    this.argumentos = const {},
    this.origen = OrigenOrden.personaConAsistente,
  });

  final String herramienta;
  final Map<String, Object?> argumentos;
  final OrigenOrden origen;
}

/// Resultado de traducir una orden.
sealed class Traduccion {
  const Traduccion();
}

class Permitida extends Traduccion {
  const Permitida(this.accion);
  final Accion accion;
}

class NoPermitida extends Traduccion {
  const NoPermitida(this.motivo);
  final String motivo;
}

class Vetada extends Traduccion {
  const Vetada(this.categoria);
  final CategoriaAccion categoria;
}

const _palabrasBanca = [
  'banc',
  'banco',
  'bank',
  'transfer',
  'spei',
  'tarjeta',
  'nip',
  'cuenta_',
];
const _palabrasCompras = [
  'compra',
  'comprar',
  'buy',
  'purchase',
  'checkout',
  'carrito',
  'pedido',
  'amazon',
  'mercadolibre',
];
const _palabrasPago = ['pagar', 'pago', 'pay'];

String _norm(String s) => s.toLowerCase().trim();

/// Detecta las categorías vetadas en un nombre de herramienta o destino.
CategoriaAccion? _vetoPorNombre(String texto) {
  final t = _norm(texto);
  if (_palabrasBanca.any(t.contains)) return CategoriaAccion.banca;
  if (_palabrasCompras.any(t.contains)) return CategoriaAccion.compras;
  if (_palabrasPago.any(t.contains)) return CategoriaAccion.pagar;
  return null;
}

bool _rutaSegura(String ruta, List<String> carpetas) {
  final r = ruta.replaceAll('\\', '/');
  if (r.isEmpty || r.split('/').contains('..')) return false;
  return carpetas.any((c) {
    final base = c.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return false;
    return r == base || r.startsWith('$base/');
  });
}

String? _txt(Map<String, Object?> a, String k) {
  final v = a[k];
  return v is String && v.trim().isNotEmpty ? v : null;
}

DateTime? _fecha(Map<String, Object?> a, String k) {
  final v = a[k];
  return v is String ? DateTime.tryParse(v) : null;
}

/// Traduce una orden del asistente a una acción de la lista cerrada.
/// Todo lo que no está en la lista devuelve [NoPermitida]; banca y compras
/// devuelven [Vetada].
Traduccion traducirOrden(
  OrdenAsistente orden, {
  ConfigControlLaptop config = const ConfigControlLaptop(),
}) {
  if (orden.origen == OrigenOrden.contenidoLeido) {
    return const NoPermitida('lo leído es información, no una orden');
  }
  final veto = _vetoPorNombre(orden.herramienta);
  if (veto != null && !_conocidas.contains(_norm(orden.herramienta))) {
    return categoriasVetadas.contains(veto)
        ? Vetada(veto)
        : const NoPermitida('fuera de la lista');
  }
  final a = orden.argumentos;
  switch (_norm(orden.herramienta)) {
    case 'abrir_programa':
      final p = _txt(a, 'programa');
      if (p == null) return const NoPermitida('falta el programa');
      final v = _vetoPorNombre(p);
      if (v != null && categoriasVetadas.contains(v)) return Vetada(v);
      if (!config.programasPermitidos.contains(p)) {
        return const NoPermitida('programa no permitido por el dueño');
      }
      return Permitida(AbrirPrograma(p));
    case 'abrir_archivo':
      final r = _txt(a, 'ruta');
      if (r == null || !_rutaSegura(r, config.carpetasPermitidas)) {
        return const NoPermitida('archivo fuera de las carpetas permitidas');
      }
      return Permitida(AbrirArchivo(r));
    case 'buscar_archivos':
      final c = _txt(a, 'carpeta');
      final q = _txt(a, 'consulta');
      if (c == null ||
          q == null ||
          !_rutaSegura(c, config.carpetasPermitidas)) {
        return const NoPermitida('carpeta fuera de las permitidas');
      }
      return Permitida(BuscarArchivos(carpeta: c, consulta: q));
    case 'abrir_pantalla':
      final m = _txt(a, 'modulo');
      if (m == null || !modulosAbribles.contains(_norm(m))) {
        return const NoPermitida('módulo desconocido');
      }
      return Permitida(AbrirPantalla(_norm(m)));
    case 'gmail_leer':
      return Permitida(GmailLeer(consulta: _txt(a, 'consulta') ?? ''));
    case 'gmail_redactar':
      final para = _txt(a, 'para');
      final asunto = _txt(a, 'asunto');
      if (para == null || asunto == null) {
        return const NoPermitida('faltan destinatario o asunto');
      }
      return Permitida(
        GmailRedactar(
          para: para,
          asunto: asunto,
          cuerpo: _txt(a, 'cuerpo') ?? '',
        ),
      );
    case 'gmail_enviar':
      final id = _txt(a, 'borrador_id');
      if (id == null) return const NoPermitida('falta el borrador');
      return Permitida(GmailEnviar(id));
    case 'calendar_ver':
      final d = _fecha(a, 'desde');
      final h = _fecha(a, 'hasta');
      if (d == null || h == null) return const NoPermitida('faltan fechas');
      return Permitida(CalendarVer(desde: d, hasta: h));
    case 'calendar_crear':
      final t = _txt(a, 'titulo');
      final i = _fecha(a, 'inicio');
      final f = _fecha(a, 'fin');
      if (t == null || i == null || f == null) {
        return const NoPermitida('faltan datos del evento');
      }
      return Permitida(CalendarCrear(titulo: t, inicio: i, fin: f));
    default:
      return const NoPermitida('fuera de la lista');
  }
}

const _conocidas = {
  'abrir_programa',
  'abrir_archivo',
  'buscar_archivos',
  'abrir_pantalla',
  'gmail_leer',
  'gmail_redactar',
  'gmail_enviar',
  'calendar_ver',
  'calendar_crear',
};
