/// PIN no trivial al elegirlo ([motivoPinDebil]). Nunca se guarda el PIN: solo
/// su hash con sal (PBKDF2 con HMAC-SHA256), dentro del almacenamiento seguro.
///
/// Largo (decisión del dueño, 23/oct/2026, D18): **6 dígitos para quien ve
/// dinero** (dueño y coadministradores, incluida la cuenta maestra:
/// [rolVeDinero]); familiar y cuidador conservan de 4 a 6. Un PIN anterior más
/// corto sigue abriendo la cuenta una última vez, pero su dueño debe cambiarlo
/// en ese momento ([pinEsCortoParaSuRol]); cada lugar donde se escribe un PIN
/// lo maneja con un resultado `debeCambiarPin`.
///
/// ## Pendiente (siguiente ronda): costo del PIN en el teléfono
///
/// El PIN se estira con 100 000 vueltas de PBKDF2 ([HashPin.iteracionesActuales],
/// M9' de la revisión de la Fase 1b): ~0.3 s en una computadora. Entrar con el
/// PIN en la tablet hace 2 o 3 derivaciones (verificar el hash, abrir el sobre y,
/// la primera vez tras la actualización, rehacerlo), y todas corren hoy en el
/// hilo de la interfaz. Decisión del dueño (31/oct): se dejan 100 000, sin subir
/// ni bajar. Queda para la siguiente ronda (1) mover la derivación a un hilo
/// aparte (`Isolate`), lo que vuelve asíncrono `desbloquearConPin`/`verificar`,
/// y (2) **medirla en el Galaxy A52**. Calidad pide ≥ 600 000 vueltas o Argon2:
/// la decisión depende de esa medición.
library;

import 'dart:convert';
import 'dart:math';
import '../contratos/roles.dart';
import '../permisos/permisos.dart';
import 'pbkdf2.dart';

final _formatoPin = RegExp(r'^\d{4,6}$');

/// Largo del PIN de quien ve dinero.
const largoPinConDinero = 6;

/// `true` si [pin] tiene de 4 a 6 dígitos (el formato general; el largo que
/// pide cada rol es [pinValidoPara]).
bool pinValido(String pin) => _formatoPin.hasMatch(pin);

/// `true` si [rol] ve dinero: abre Finanzas según la matriz de permisos
/// (dueño y coadministrador; la cuenta maestra es coadministradora).
bool rolVeDinero(Rol rol) => puedeAbrir(rol, Modulo.finanzas);

/// `true` si [pin] tiene el largo que pide [rol]: 6 dígitos si ve dinero, de 4
/// a 6 si no. Con [rol] `null` (aún no se sabe) vale el formato general.
bool pinValidoPara(Rol? rol, String pin) =>
    pinValido(pin) &&
    (rol == null || !rolVeDinero(rol) || pin.length == largoPinConDinero);

/// `true` si [rol] ve dinero y [pin] (que ya es el correcto) es de menos de 6
/// dígitos: hay que cambiarlo antes de entrar.
bool pinEsCortoParaSuRol(Rol? rol, String pin) =>
    rol != null && rolVeDinero(rol) && pin.length < largoPinConDinero;

/// Cuántos dígitos pide [rol], para etiquetas y ayudas.
String textoDelLargoDelPin(Rol? rol) =>
    rol != null && rolVeDinero(rol) ? '6 dígitos' : '4 a 6 dígitos';

/// Aviso que se le da a quien ve dinero y tiene un PIN más corto.
const avisoPinCortoConDinero =
    'Ahora el PIN de quien ve dinero es de 6 dígitos. Elige uno nuevo para '
    'seguir; tu cuenta y lo que tengas por subir se conservan.';

/// Por qué [pin] (de 4 a 6 dígitos) es **trivial** y no se acepta como PIN
/// nuevo (M9, revisión de la Fase 1), o `null` si no lo es. Cuenta como
/// trivial:
///
/// - el mismo dígito repetido (`0000`, `1111`, `999999`);
/// - una secuencia seguida, de subida o de bajada, que da la vuelta del 9 al 0
///   (`1234`, `4321`, `0123`, `7890`, `123456`, `654321`);
/// - un bloque que se repite (`1212`, `4545`, `123123`, `686868`).
///
/// No cambia el largo del PIN (4 a 6): eso lo decide el dueño. Un PIN que no
/// pasa [pinValido] no se juzga aquí.
String? motivoPinDebil(String pin) {
  if (!pinValido(pin)) return null;
  final digitos = [for (final c in pin.split('')) int.parse(c)];
  if (digitos.every((d) => d == digitos.first)) {
    return 'Ese PIN repite el mismo número. Elige uno menos fácil de adivinar.';
  }
  bool conPaso(int paso) {
    for (var i = 1; i < digitos.length; i++) {
      if ((digitos[i] - digitos[i - 1]) % 10 != paso % 10) return false;
    }
    return true;
  }

  if (conPaso(1) || conPaso(-1)) {
    return 'Ese PIN es una secuencia (como 1234). Elige uno menos fácil de '
        'adivinar.';
  }
  for (var periodo = 2; periodo <= digitos.length ~/ 2; periodo++) {
    if (digitos.length % periodo != 0) continue;
    var seRepite = true;
    for (var i = periodo; i < digitos.length; i++) {
      if (digitos[i] != digitos[i - periodo]) {
        seRepite = false;
        break;
      }
    }
    if (seRepite) {
      return 'Ese PIN repite un mismo bloque (como 1212). Elige uno menos '
          'fácil de adivinar.';
    }
  }
  return null;
}

/// `true` si [pin] es trivial (ver [motivoPinDebil]).
bool pinEsDebil(String pin) => motivoPinDebil(pin) != null;

/// Mensaje para un PIN nuevo que no se puede aceptar (largo o trivial), o
/// `null` si sirve. Es lo que muestran los formularios. Con [rol] pide el
/// largo de ese rol (6 dígitos si ve dinero); sin él, de 4 a 6.
String? errorDePinNuevo(String pin, {Rol? rol}) {
  if (!pinValido(pin)) {
    return rol != null && rolVeDinero(rol)
        ? 'El PIN es de 6 dígitos.'
        : 'De 4 a 6 dígitos.';
  }
  if (!pinValidoPara(rol, pin)) return 'El PIN es de 6 dígitos.';
  return motivoPinDebil(pin);
}

/// Como [errorDePinNuevo], y además que [confirmacion] sea igual.
String? errorDePinNuevoConfirmado(
  String pin,
  String confirmacion, {
  Rol? rol,
}) => errorDePinNuevo(pin, rol: rol) ??
    (pin == confirmacion ? null : 'Los PIN no coinciden.');

abstract final class HashPin {
  static const version = 'pbkdf2-sha256';

  /// Vueltas de PBKDF2 con las que se hacen los hashes y los sobres **nuevos**
  /// (M9' de la revisión de la Fase 1b: eran 10 000; con un PIN de 6 dígitos
  /// ese costo no frena a quien extraiga el almacenamiento). 100 000 con la
  /// implementación de `pbkdf2.dart` tardan unos 0.3 s en una computadora y se
  /// estima ~1 s en un teléfono medio.
  static const iteracionesActuales = 100000;

  /// Las de los hashes y sobres anteriores: siguen verificándose (la cuenta de
  /// vueltas viaja en cada hash y en cada sobre) y se rehacen con
  /// [iteracionesPorDefecto] la próxima vez que su dueño escribe el PIN.
  static const iteracionesAnteriores = 10000;

  /// Con las que se hace lo nuevo. Es [iteracionesActuales]; las pruebas lo
  /// bajan (`test/flutter_test_config.dart`) para no esperar 0.3 s por PIN.
  static int iteracionesPorDefecto = iteracionesActuales;
  static const _bytesSal = 16;

  /// Hash con sal aleatoria: `pbkdf2-sha256$iteraciones$sal$hash` (base64).
  static String crear(
    String pin, {
    int? iteraciones,
    List<int>? sal,
  }) {
    if (!pinValido(pin)) {
      throw ArgumentError.value(pin, 'pin', 'Debe tener de 4 a 6 dígitos');
    }
    final vueltas = iteraciones ?? iteracionesPorDefecto;
    final salUsada = sal ?? _salAleatoria();
    final hash = pbkdf2HmacSha256(utf8.encode(pin), salUsada, vueltas);
    return [
      version,
      '$vueltas',
      base64Encode(salUsada),
      base64Encode(hash),
    ].join(r'$');
  }

  /// Cuántas vueltas tiene un hash guardado, o `null` si no se entiende.
  static int? iteracionesDe(String guardado) {
    final partes = guardado.split(r'$');
    if (partes.length != 4 || partes[0] != version) return null;
    return int.tryParse(partes[1]);
  }

  /// `true` si [guardado] se hizo con menos vueltas que las de hoy: hay que
  /// rehacerlo cuando su dueño escriba el PIN (es el único momento en que se
  /// tiene).
  static bool necesitaActualizarse(String guardado) {
    final vueltas = iteracionesDe(guardado);
    return vueltas != null && vueltas < iteracionesPorDefecto;
  }

  /// Compara [pin] con un hash guardado, en tiempo constante.
  static bool verificar(String pin, String guardado) {
    final partes = guardado.split(r'$');
    if (partes.length != 4 || partes[0] != version) return false;
    final iteraciones = int.tryParse(partes[1]);
    if (iteraciones == null || iteraciones < 1) return false;
    final List<int> sal;
    final List<int> esperado;
    try {
      sal = base64Decode(partes[2]);
      esperado = base64Decode(partes[3]);
    } on FormatException {
      return false;
    }
    final calculado = pbkdf2HmacSha256(utf8.encode(pin), sal, iteraciones);
    if (calculado.length != esperado.length) return false;
    var diferencia = 0;
    for (var i = 0; i < calculado.length; i++) {
      diferencia |= calculado[i] ^ esperado[i];
    }
    return diferencia == 0;
  }

  /// Llave de 32 bytes derivada del PIN (PBKDF2-HMAC-SHA256), p. ej. para
  /// cifrar la credencial de una persona en la tablet (`cifrado.dart`). Usa
  /// una sal distinta de la del hash.
  static List<int> derivarLlave(
    String pin,
    List<int> sal, {
    int? iteraciones,
  }) => pbkdf2HmacSha256(
    utf8.encode(pin),
    sal,
    iteraciones ?? iteracionesPorDefecto,
  );

  /// Sal aleatoria de 16 bytes.
  static List<int> salAleatoria() => _salAleatoria();

  static List<int> _salAleatoria() {
    final azar = Random.secure();
    return List<int>.generate(_bytesSal, (_) => azar.nextInt(256));
  }
}
