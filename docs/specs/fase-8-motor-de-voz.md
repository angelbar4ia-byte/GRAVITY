# Especificación — Motor de voz de GRAVITY

> Versión 0.1 (16/nov/2026), **propuesta**. Paquete **P3.0** del plan de inglés (`docs/specs/fase-8-ingles-plan.md`, fase 3). Lo pidió el dueño el 16/nov/2026 (D29, D-ING-3: *las tres vías de audio* y *empezar también el motor de voz de GRAVITY*; `docs/DECISIONES.md`, línea 562).
> **No cambia ninguna decisión confirmada.** D6 está en estado *propuesta* (`docs/DECISIONES.md`, líneas 18 y 146): todo lo que dependa de ella está marcado **pendiente de D6** y no se decide aquí.
> Es solo especificación: no hay código ni cambios en `pubspec.yaml`. Las firmas en Dart de la sección 3 son una propuesta; se comprobaron con el analizador de Dart en una copia fuera del repositorio.
> **Estado (22/nov/2026): P3.2a-1 y P3.2a-2 hechos en lo técnico** (interfaz, fuentes simuladas, fuente A con `flutter_tts` 4.2.5 y fuente B con `sherpa_onnx` 2.0.1 y `audioplayers` 6.8.1; sección 14). La lectura de este documento sigue valiendo, con las pequeñas diferencias de las secciones 14.2 y 14.8. Falta probarlo en el Galaxy A52 y en la laptop (14.5 y 14.8).
> **Cómo se marca lo que se afirma.** Las citas `archivo:línea` se comprueban leyendo el archivo. **[consultado]** es lo que se leyó o midió el 16/nov/2026 en pub.dev, en paquetes descargados, en documentación pública o en tarjetas de modelos (detalle en 9.1). **[sin verificar]** no se pudo comprobar y tiene su procedimiento en 9.2. Lo demás es diseño de esta especificación.

## 1. Resultado buscado y quién usa la voz

**Resultado.** Un solo componente de voz de salida, el *motor de voz de GRAVITY*, que convierte texto ya filtrado en audio por tres vías intercambiables (voz del dispositivo, modelo de voz descargable y audio pregrabado), detrás de una misma interfaz, en el teléfono Android y en la laptop Windows. Cuando exista, el dueño abre Ajustes › Voz, escucha la misma frase con cada vía y elige de oído; el curso de inglés reproduce un diálogo de dos voces, dos veces, a 0.8 y a 1.0, sin conexión; y el asistente puede leer sus respuestas en voz alta.

### 1.1 Qué hay hoy

| Pieza | Estado | Dónde |
|---|---|---|
| Dictado (voz a texto) | Solo Android, con `speech_to_text` 7.5.0. En Windows el micrófono no se ofrece | `app/lib/modulos/gravity/conversacion/voz.dart:46-92`, `:152-156`; `app/pubspec.yaml:81` |
| Interfaz `VozSalida` | Dos métodos (`hablar`, `detener`) y sin implementación real: el valor por omisión no habla | `voz.dart:38-41`, `:108-117`, `:158-160` |
| Leer en voz alta | Interruptor apagado por omisión; si la persona lo enciende se queda encendido en las siguientes sesiones (por persona, 22/nov/2026); lee solo la respuesta del asistente, nunca mensajes locales | `voz.dart:162-173`; `panel_conversacion.dart:154-164`, `:276-294`; prueba `app/test/modulos/gravity/conversacion/voz_test.dart:52-81` |
| Paquetes de síntesis o de reproducción de audio | Ninguno: no hay `flutter_tts`, `sherpa_onnx` ni reproductor | `app/pubspec.yaml` |
| Bocinas | El puente manda texto al servicio `tts/speak` de Home Assistant | `app/lib/modulos/casa/puente/puente_casa.dart:85-107` |
| Ajustes › Voz | Pantalla con dos notas; no elige nada | `app/lib/modulos/ajustes/voz/pantalla_voz.dart:13-27` |

**Hallazgo para quien integre.** El interruptor "Leer las respuestas en voz alta" aparece cuando hay *micrófono* (`panel_conversacion.dart:38-40`, `:259`, `:276`), no cuando hay *salida de voz*: en Android hoy se ve y no hace nada. Además, `_escucharVoz` (`panel_conversacion.dart:115-134`) no detiene la salida antes de dictar. Con el motor, el interruptor se condiciona a `disponibilidad(UsoVoz.asistente)` y el dictado detiene al motor (criterio 38). La especificación del bloque 4 dejó la lectura en voz alta fuera de esa fase (`docs/specs/fase-8-reportes-imagen-voz.md:25`); D29 la incluye en el motor (pregunta 3).

### 1.2 Quién usa la voz

| Quién | Qué necesita del motor | Idioma | Estado |
|---|---|---|---|
| **Curso de inglés** (Hábitos) | Escuchar guiones (monólogos y diálogos de 60 a 500 palabras de habla según la etapa) con hasta cinco voces: F1, F2, M1, M2 y N (narrador); dos reproducciones por cada audio del traslado y las que pida el contrato en exámenes; 20 o más frases para repetir al día; tarjetas en audio; la escucha de la ubicación y de las puertas | Inglés (`en-US`, `en-GB`); español si las tarjetas dicen la traducción (pregunta 12) | **Confirmado** (D29, D-ING-3). Contenido: formato `docs/specs/fase-8-ingles-formato.md`, secciones 4.1 y 7; contrato `data/ingles/formatos/gravity-sesion-60.yaml` (P1.1b, commit `b0e3462` del 16/nov/2026, bloques `traslado-audio`, `traslado-repeticion` y `traslado-tarjetas`) |
| **Asistente** | Leer en voz alta sus respuestas, con una sola voz | Español de México | Interfaz existente sin implementación. D29 lo incluye en el motor. Falta confirmar que se enciende (pregunta 3) |
| **Bocinas** (D6) | Recordatorios genéricos, pasos de receta, lectura de la lista de compras | Español de México | **Pendiente de D6**. Hoy van por el TTS de Home Assistant (sección 7) |

Otros usos que el diseño ya menciona (la receta paso a paso con voz en la tablet: `docs/DISENO_UX_UI.md:113`, `:214`; `app/lib/app/tablet/pantalla_modo_casa.dart:31`) se sumarán como otro valor de `UsoVoz` cuando se especifiquen. No son parte de P3.0.

### 1.3 Qué NO es

- **No es reconocimiento de voz.** Escuchar lo que dice la persona ya existe (`VozEntrada`, `speech_to_text`) y esta especificación no lo toca.
- **No identifica ni autoriza.** Ni la voz que se oye ni la que se dicta dicen quién es la persona ni confirman una acción (D5, D8; sección 2).
- **No graba ni califica al estudiante.** La grabación del habla y su comparación son del reproductor del curso (P3.2b, sección 6.3).
- **No genera contenido.** No escribe guiones ni decide qué se dice: habla lo que recibe.
- **No es la conversación con la IA.** El proveedor de IA, el filtro de D3 y las herramientas siguen donde están.

## 2. Reglas que no se rompen

| # | Regla | De dónde sale | Cómo la cumple el motor | Criterios |
|---|---|---|---|---|
| R1 | **Al motor solo llega texto ya filtrado.** | D3 (`DECISIONES.md:77-87`), D6 (`:158-162`), `voz.dart:9-11` | Tres entradas y ninguna más: (a) el guion del curso, que sale del contenido compilado y revisado y no lleva datos de la persona; (b) la respuesta del asistente, que el modelo produce sin haber visto cifras ni datos clínicos porque el filtro de D3 corre en el servidor antes de enviarle nada (`docs/ROADMAP.md:279`); (c) el `MensajeBocina` ya validado (solo si D6 se confirma). El motor no filtra ni corrige: quien llama filtra. Los mensajes locales (resultados de herramientas, que pueden traer cifras) y los de error no se leen | 9, 12 |
| R2 | **La voz no identifica ni autoriza.** | D5 (`:131`, `:142`), D8, `voz.dart:4-8` | El motor solo produce sonido y no recibe identidad por voz. Las preferencias son de la persona que tiene la sesión, no de quien habla. Nada de lo que se oiga ni de lo que se dicte confirma una acción | 13, 36 |
| R3 | **Lo que se lee es información, nunca órdenes.** | D8 (`:211-218`) | El motor habla y calla: no interpreta el texto ni ejecuta nada, y no tiene ninguna ruta hacia el registro de herramientas | 11, 13 |
| R4 | **Bocinas: ni dinero ni datos clínicos.** | D3, D6 | Mientras D6 sea propuesta, el motor no tiene uso `bocinas`. `PuenteCasa.hablar` conserva su firma, que solo acepta `MensajeBocina` (`puente_casa.dart:17-18`) | 12 |
| R5 | **Puente de casa.** | D9 (`:222-239`), `puente_casa.dart:1-7` | El motor no conoce el token de Home Assistant ni abre puertos. Si algún día entrega audio al puente, el puente se autentica con su cuenta de rol Casa | 11, 12 |
| R6 | **El curso no lleva dinero ni datos clínicos, y lo que se estudia no sale del dispositivo.** | D3; `docs/specs/fase-8-habitos-ampliaciones.md` (reglas: el progreso de inglés no sale de Hábitos) | El curso solo entrega guiones compilados. El motor no registra qué texto dijo ni de qué unidad: solo códigos de error sin texto | 16 |
| R7 | **Sin secretos.** | `CLAUDE.md`; `docs/specs/fase-0-cimientos.md:72` | El catálogo y los manifiestos llevan direcciones públicas y huellas; ninguna clave, token ni dirección firmada. Las descargas no llevan credenciales | 14, 15 |
| R8 | **La reproducción no usa la red.** | Plan, líneas 15 y 111 (el curso funciona sin conexión y estudiar no usa la red) | La fuente A solo usa voces locales; B y C reproducen archivos del equipo; las fuentes y el reproductor no importan nada de red. Solo el gestor de descargas habla con la red, y solo cuando la persona lo pide | 10, 11, 35, 41 |
| R9 | **Descargar un modelo no envía datos de la persona.** | D3; `docs/specs/fase-8-habitos-ampliaciones.md` (el progreso de inglés no sale de Hábitos) | Petición HTTPS sin credenciales, cookies ni identificadores, a la dirección exacta del catálogo, con cabeceras de una lista cerrada. El sitio que aloja el archivo ve la dirección de internet del equipo; el aviso lo dice | 15 |
| R10 | **Solo se carga lo verificado.** | Seguridad: el modelo lo lee código nativo | Ningún archivo llega al cargador nativo sin coincidir con su sha256 del catálogo; lo que no coincide se borra | 22, 23, 27 |
| R11 | **Licencias.** | Plan, anexo F, fila *B. Modelo descargable* ("licencia de cada voz (no la verifiqué)") | Ningún modelo entra al catálogo sin su licencia leída y registrada; las que piden atribución se muestran en pantalla; el audio pregrabado solo se distribuye con voces cuya licencia lo permita | 27 |

## 3. La interfaz

### 3.1 Principios

1. **Lo actual no se rompe.** `VozSalida` (`voz.dart:38-41`) no cambia. El motor la implementa, así que el panel de conversación, `VozSalidaNoDisponible` y `VozSalidaFalsa` siguen valiendo tal cual.
2. **Se separa lo que dice el contenido de lo que ofrece una fuente.** El contenido habla de *voces de guion* (F1, F2, M1, M2, N: las de la comprobación V16 de `herramientas/ingles`). Cada fuente ofrece *voces del motor*. Una **asignación** une las dos; la propone el motor y la persona la cambia.
3. **Todo es interfaz y todo tiene su versión falsa**, como `VozSalidaFalsa` (`voz.dart:142-150`) y `PuenteCasaFalso` (`puente_casa.dart:22-32`): fuentes, reproductor de audio, descargador, tipo de red y almacén de preferencias. Así el curso y el motor se prueban sin audio, sin red y sin dispositivo.
4. **Una reproducción usa una sola fuente de principio a fin.** El motor no cambia de fuente a la mitad de un guion: cambiaría las voces en medio de un diálogo.

### 3.2 Firmas propuestas

```dart
// PROPUESTA de firmas. No es código del repositorio.
// Destino (P3.2a): app/lib/modulos/gravity/voz/ (carpeta nueva; ver sección 12).

// ───────────────────────────────────────────────────────────────────────
// 1. Lo que NO cambia (voz.dart:38-41)
// ───────────────────────────────────────────────────────────────────────
abstract class VozSalida {
  Future<void> hablar(String texto);
  Future<void> detener();
}

// ───────────────────────────────────────────────────────────────────────
// 2. Vocabulario
// ───────────────────────────────────────────────────────────────────────

/// Para qué se habla. Decide qué preferencia se aplica y qué texto se acepta.
/// `bocinas` no existe todavía: depende de D6 (propuesta); ver sección 7.
enum UsoVoz { curso, asistente }

/// Nombre de una voz DENTRO de un guion. Son las del formato (V16).
enum VozDeGuion {
  f1('F1'),
  f2('F2'),
  m1('M1'),
  m2('M2'),
  n('N'); // narrador

  const VozDeGuion(this.etiqueta);
  final String etiqueta;
}

/// Idioma y acento. `enUS` y `enGB` son la `variante` del contenido.
enum Variante { enUS, enGB, esMX }

/// Las tres vías. El orden es el de la cadena por omisión del curso.
enum Fuente { pregrabado, modelo, dispositivo } // C, B, A

enum Genero { mujer, hombre, sinDato }

/// Una voz concreta de una fuente: lo que lista Ajustes › Voz.
final class VozMotor {
  const VozMotor({
    required this.id, // estable entre ejecuciones
    required this.fuente,
    required this.nombre, // lo que ve la persona
    required this.variante,
    required this.genero,
    required this.local,
  });
  final String id;
  final Fuente fuente;
  final String nombre;
  final Variante variante;
  final Genero genero;

  /// `false` si para hablar necesita red. Una voz así NUNCA se usa (R8).
  final bool local;
}

// ───────────────────────────────────────────────────────────────────────
// 3. Lo que se reproduce
// ───────────────────────────────────────────────────────────────────────

final class Turno {
  const Turno({required this.voz, required this.texto, this.pausaDespues});
  final VozDeGuion voz;
  final String texto;
  final Duration? pausaDespues; // null: la pausa del guion
}

/// Una unidad de audio o una sesión del curso.
final class Guion {
  const Guion({
    required this.id, // id de la unidad (o de sesión y frase): nombra el audio pregrabado
    required this.variante,
    required this.turnos,
    this.huella, // la escribe `compilar`; sin huella no hay audio pregrabado
    this.pausaEntreTurnos = const Duration(milliseconds: 600), // propuesta: se decide de oído (P3.3)
  });
  final String id;
  final String? huella;
  final Variante variante;
  final List<Turno> turnos;
  final Duration pausaEntreTurnos;
  int get vocesDistintas => turnos.map((t) => t.voz).toSet().length;
}

/// Avance de una reproducción. NUNCA lleva el texto: el curso oculta el guion
/// hasta que la persona contesta (plan 3.5).
final class Avance {
  const Avance({
    required this.turno, // 0 .. totalTurnos - 1
    required this.totalTurnos,
    required this.voz,
    required this.posicion, // desde el inicio de la reproducción
    this.duracion, // la fuente pregrabada la conoce; el dispositivo, no
  });
  final int turno;
  final int totalTurnos;
  final VozDeGuion voz;
  final Duration posicion;
  final Duration? duracion;
}

enum Fin { completa, parada }

/// Lo que devuelve `reproducir` y `decir`. Es independiente de las pantallas.
abstract interface class Reproduccion {
  Fuente get fuente; // la que se usó (el curso la registra en las pruebas con valor)
  Stream<Avance> get avance;

  /// Completa al terminar o al parar. Si falla, completa con un `ErrorVoz`.
  Future<Fin> get terminada;
  Future<void> pausar();
  Future<void> reanudar();
  Future<void> parar();
}

// ───────────────────────────────────────────────────────────────────────
// 4. Disponibilidad y errores
// ───────────────────────────────────────────────────────────────────────

enum Motivo {
  plataformaNoSoportada,
  sinVozEnElIdioma,
  vocesInsuficientes,
  modeloNoInstalado,
  sinPaqueteDeAudio,
  audioCaducado,
  formatoNoSoportado,
  excluidaPorLaPersona,
}

final class Disponibilidad {
  const Disponibilidad({required this.cadena, required this.descartadas});
  final List<Fuente> cadena; // las que sirven, en orden de uso
  final Map<Fuente, Motivo> descartadas; // las que no, y por qué
  bool get disponible => cadena.isNotEmpty;
  Fuente? get usaria => cadena.isEmpty ? null : cadena.first;
}

/// Ningún error lleva el texto que se iba a decir (R6).
sealed class ErrorVoz implements Exception {
  const ErrorVoz();
}

final class SinFuenteDisponible extends ErrorVoz {
  const SinFuenteDisponible(this.motivos);
  final Map<Fuente, Motivo> motivos;
}

final class OcupadoPorOtroUso extends ErrorVoz {
  const OcupadoPorOtroUso();
}

final class FalloDeSintesis extends ErrorVoz {
  const FalloDeSintesis(this.fuente, this.codigo);
  final Fuente fuente;
  final String codigo;
}

// Del gestor de descargas:
final class SinWifi extends ErrorVoz {
  const SinWifi();
}

final class SinRed extends ErrorVoz {
  const SinRed();
}

final class SinEspacio extends ErrorVoz {
  const SinEspacio(this.bytesNecesarios);
  final int bytesNecesarios;
}

final class HuellaIncorrecta extends ErrorVoz {
  const HuellaIncorrecta(this.archivo);
  final String archivo;
}

final class DescargaInterrumpida extends ErrorVoz {
  const DescargaInterrumpida(this.bytes, this.total);
  final int bytes;
  final int total;
}

// ───────────────────────────────────────────────────────────────────────
// 5. El motor
// ───────────────────────────────────────────────────────────────────────

abstract interface class MotorVoz implements VozSalida {
  /// Cambia cuando cambian voces, modelos o paquetes (la pantalla se refresca).
  Stream<void> get cambios;

  /// ¿Puede hablar este uso con esta variante? Dice la cadena y por qué no
  /// sirve cada fuente descartada. Sin red y sin hablar.
  Future<Disponibilidad> disponibilidad(
    UsoVoz uso, {
    Variante? variante,
    int vocesNecesarias = 1,
  });

  /// Voces locales de una fuente.
  Future<List<VozMotor>> voces(Fuente fuente, {Variante? variante});

  /// Reproduce un guion por turnos, cada uno con la voz asignada a su
  /// `VozDeGuion`. `soloFuente` quita el respaldo (pruebas con valor, "Probar").
  Future<Reproduccion> reproducir(
    Guion guion, {
    UsoVoz uso = UsoVoz.curso,
    double velocidad = 1.0, // 1.0 = normal; el curso usa 0.8 y 1.0
    Fuente? soloFuente,
  });

  /// Una frase suelta: repetir, tarjetas, probar una voz.
  Future<Reproduccion> decir(
    String texto, {
    required UsoVoz uso,
    Variante variante = Variante.enUS,
    VozDeGuion voz = VozDeGuion.f1,
    double velocidad = 1.0,
    Fuente? soloFuente,
  });

  Future<void> pausarTodo();
  Future<void> reanudarTodo();

  // Heredados de VozSalida:
  //   hablar(texto) == decir(texto, uso: UsoVoz.asistente, variante: Variante.esMX)
  //   detener()     == para lo que suene y vacía la cola
}

// ───────────────────────────────────────────────────────────────────────
// 6. Asignación de voces
// ───────────────────────────────────────────────────────────────────────

final class Asignacion {
  const Asignacion(this.fuente, this.variante, this.idVozMotor);
  final Fuente fuente;
  final Variante variante;
  final Map<VozDeGuion, String> idVozMotor; // VozDeGuion -> VozMotor.id
}

abstract interface class Asignador {
  /// Propuesta automática: mujeres para F1 y F2, hombres para M1 y M2, y para
  /// N la primera voz que quede; sin repetir voces si hay suficientes.
  Asignacion proponer(Fuente fuente, Variante variante, List<VozMotor> voces);
}

// ───────────────────────────────────────────────────────────────────────
// 7. Modelos descargables (fuente B) y paquetes de audio (fuente C)
// ───────────────────────────────────────────────────────────────────────

enum EstadoModelo { noDescargado, descargando, instalado, corrupto }

final class ProgresoDescarga {
  const ProgresoDescarga(this.bytes, this.total, this.archivo);
  final int bytes;
  final int total;
  final String archivo;
}

abstract interface class GestorDeModelos {
  List<ModeloDelCatalogo> get catalogo; // sale de app/assets, no de la red
  Future<EstadoModelo> estado(String idModelo);
  Stream<ProgresoDescarga> descargar(
    String idModelo, {
    bool permitirDatosMoviles = false,
  });
  Future<void> cancelar(String idModelo); // conserva lo descargado para reanudar
  Future<void> borrar(String idModelo); // libera el espacio
  Future<int> bytesOcupados();
}

// ───────────────────────────────────────────────────────────────────────
// 8. Costuras para pruebas (cada una tiene su versión falsa)
// ───────────────────────────────────────────────────────────────────────

final class Capacidades {
  const Capacidades({
    required this.tono,
    required this.progresoPorPalabra,
    required this.pausa,
    required this.velocidadMin,
    required this.velocidadMax,
  });
  final bool tono;
  final bool progresoPorPalabra;
  final bool pausa;
  final double velocidadMin;
  final double velocidadMax;
}

abstract interface class FuenteDeVoz {
  Fuente get tipo;
  Capacidades get capacidades;
  Future<List<VozMotor>> voces(Variante variante);

  /// `null` si esta fuente puede con TODO el guion; si no, por qué no.
  Future<Motivo?> motivoNoDisponible(Guion guion, Asignacion asignacion);
  Future<Reproduccion> reproducir(
    Guion guion,
    Asignacion asignacion,
    double velocidad,
  );
}

/// Envuelve el paquete de reproducción (B y C lo usan; A habla por sí misma).
abstract interface class ReproductorDeAudio {
  Future<void> abrir(String rutaDeArchivo);
  Future<void> reproducir();
  Future<void> pausar();
  Future<void> parar();
  Future<void> fijarVelocidad(double factor);
  Stream<Duration> get posicion;
  Stream<void> get terminado;
}
```

(`ModeloDelCatalogo` es el registro del catálogo de 4.2.1: `id`, `nombre`, `bytes` totales, voces, archivos y licencia.)

### 3.3 Cómo cubre cada requisito

| Se pidió | Dónde está |
|---|---|
| Varias voces con nombre asignables a F1, F2, M1, M2 y N | `VozDeGuion`, `VozMotor`, `Asignacion`, `Asignador` |
| Velocidad | `velocidad` en `reproducir` y `decir`; `Capacidades.velocidadMin/Max` |
| Pausar y parar | `Reproduccion.pausar/reanudar/parar`; `MotorVoz.pausarTodo/reanudarTodo/detener` |
| Avance o progreso | `Reproduccion.avance` (`Avance`, por turno y sin texto) |
| Reproducir un guion por turnos, cada uno con su voz | `Guion`, `Turno`, `MotorVoz.reproducir` |
| Disponibilidad y lista de voces | `MotorVoz.disponibilidad`, `MotorVoz.voces`, `Disponibilidad` |
| Errores | `ErrorVoz` y sus subtipos; `Motivo` |
| Sin romper el uso actual | `MotorVoz implements VozSalida` (3.5) |

### 3.4 Comportamiento

1. **Una sola voz a la vez.** Si algo suena, `reproducir` y `decir` del uso `curso` detienen lo anterior (es una acción explícita de la persona). `decir` del uso `asistente` no interrumpe al curso: lanza `OcupadoPorOtroUso`, y `hablar` lo atrapa y no hace nada (la respuesta sigue en pantalla). Dos respuestas seguidas del asistente se encolan en orden. `detener()` para todo y vacía la cola.
2. **Elegir la fuente.** `reproducir` toma la primera fuente de la cadena (5.3) que pueda con *todo* el guion: voces suficientes de la variante, modelo instalado, pieza pregrabada vigente. Con `soloFuente` no hay respaldo. Si ninguna puede, lanza `SinFuenteDisponible` con el motivo de cada una.
3. **Fallas a mitad.** `terminada` completa con el error; el motor no cambia de fuente. La pantalla ofrece reintentar con otra fuente, desde el principio del audio.
4. **Avance por turno.** Todas las fuentes avisan el turno en curso. La posición dentro del turno y la duración solo las dan las fuentes que las conocen (C sí; A no).
5. **`hablar(texto)`** equivale a `decir(texto, uso: asistente, variante: esMX)` con la velocidad que la persona fijó. El panel no espera su resultado (`panel_conversacion.dart:161`); el `Future` completa al terminar o al detener.
6. **La reproducción no depende de la pantalla.** Vive en un proveedor (`motorVozProvider`): salir de una pantalla no la detiene a menos que la pantalla lo pida. Es condición para el modo traslado (6.4).
7. **Velocidad.** 1.0 es la normal. Cada fuente traduce el factor a su escala (4.1 a 4.3) y el motor lo ajusta al rango de sus `Capacidades`. El curso solo usa 0.8 y 1.0.

### 3.5 Compatibilidad con lo actual

1. `VozSalida`, `VozSalidaNoDisponible` y `VozSalidaFalsa` no se tocan; las pruebas de `voz_test.dart` (líneas 21-116) pasan sin cambios (criterio 1).
2. `vozSalidaProvider` (`voz.dart:158-160`) pasa a devolver el motor; si no hay fuente para el asistente, el motor no hace nada, igual que `VozSalidaNoDisponible`. Las pruebas que lo sustituyen con `overrideWithValue` siguen sirviendo.
3. Se agrega `motorVozProvider` (`Provider<MotorVoz>`) para el curso y para Ajustes.
4. `leerEnVozAltaProvider` está apagado por omisión y, **desde el 22/nov/2026 (respuesta del dueño a la pregunta 3)**, se recuerda entre sesiones por persona en las preferencias de voz (`PreferenciasVoz.leerRespuestas`).
5. El panel cambia en dos puntos (criterio 38): la visibilidad del interruptor depende de `disponibilidad(UsoVoz.asistente)` y `_escucharVoz` detiene al motor antes de escuchar. Esa carpeta (`app/lib/modulos/gravity/conversacion/`) no aparece en la tabla de 11.2 del roadmap; el arquitecto decide quién escribe ahí (sección 12).
6. `FuenteConectividad` (`app/lib/nucleo/conectividad/conectividad.dart:26-32`) solo dice si hay red. El gestor necesita saber si es Wi-Fi o datos móviles: se agrega una interfaz aparte (`FuenteTipoDeRed`) para no romper a sus tres implementaciones, con `connectivity_plus` (ya está en `pubspec.yaml:74`). La escribe plataforma (`app/lib/nucleo`).

## 4. Las tres fuentes

| | **A. Voz del dispositivo** | **B. Modelo descargable** | **C. Audio pregrabado** |
|---|---|---|---|
| Qué es | La voz del sistema (Android, Windows) | Voz neuronal que se ejecuta en el equipo | Archivos de audio generados antes, en la laptop |
| Texto nuevo | Sí | Sí | No: solo los guiones que se pregrabaron |
| Voces distintas | Las que tenga el equipo | Varias por modelo (hasta 904 en un candidato) | Las del modelo que los generó |
| Pesa | Casi nada | De unos 27 MB a unos 320 MB por modelo, más las bibliotecas nativas (4.2) | Por paquete; el plan estima 90 a 120 MB todo el curso (no medido) |
| Sin conexión | Sí, con voces locales | Sí, una vez descargado | Sí, una vez descargado |
| Falla cuando | No hay voz en inglés o hay pocas | No está descargado, es lento o está corrupto | Falta el paquete o el guion cambió |
| Paquete | `flutter_tts` | `sherpa_onnx` y un reproductor | El reproductor |

### 4.1 Fuente A: voz del dispositivo

| | |
|---|---|
| **Qué es** | El texto a voz del sistema: Android `TextToSpeech` (el motor que tenga instalado el teléfono) y Windows (voces del sistema). |
| **Cómo se obtiene la voz** | `flutter_tts` 4.2.5: `getVoices` lista nombre y `locale` (`lib/flutter_tts.dart:523`); en Android agrega `quality`, `latency`, `network_required` y `features` (`android/.../FlutterTtsPlugin.kt:619-624`). El motor filtra por idioma y variante, **descarta las voces con `network_required == "1"`** y ofrece el resto como `VozMotor` con `local: true`. `setVoice` elige la voz; `setSpeechRate` la velocidad (el rango de cada plataforma lo da `getSpeechRateValidRange`, línea 545, y el motor lo normaliza a un factor); `speak` con `awaitSpeakCompletion(true)` (línea 345) dice un turno y avisa cuando termina. Cada turno es una llamada a `speak`: el avance por turno es exacto. |
| **Qué necesita** | Paquete `flutter_tts` (MIT). Permisos: ninguno nuevo. En Android 11 o más, agregar `<intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>` al bloque `<queries>` que ya existe (`app/android/app/src/main/AndroidManifest.xml:80-88`), como pide el README del paquete. |
| **Qué pesa** | El paquete, casi nada (el archivo de pub.dev pesa 498 253 bytes con su ejemplo). Los datos de voz los instala el sistema, no la app. |
| **Sin conexión** | Funciona con voces locales. Las voces de red de Android se descartan por la regla R8. |
| **Cómo falla** | (1) No hay motor de voz o `getVoices` viene vacío. (2) No hay voz en el idioma: `sinVozEnElIdioma`. (3) Hay menos voces distintas que las que pide el guion: `vocesInsuficientes`. (4) Los datos de la voz no están instalados (en Android, la voz trae `features` con `notInstalled`). (5) El servicio de voz se desconecta (el CHANGELOG 4.2.3 corrige reconexiones). (6) `speak` avisa error por `setErrorHandler`. |
| **Qué ve la persona** | Si falta la voz en inglés: *"Este equipo no tiene una voz en inglés. Puedes descargar una voz de GRAVITY o instalar una en los ajustes del sistema"*, con los pasos del sistema y el botón de descargar (5.5). La Ubicación no se ofrece (plan, paquete P2.4). |
| **Límites conocidos** | En Windows, el README de `flutter_tts` no lista `isLanguageAvailable` ni `synthesizeToFile`, ni progreso por palabra (solo Android, iOS y Web), así que la fuente A **no sirve para pregrabar en la laptop** y el avance es solo por turno. La pausa en Android es un truco que repite desde la última palabra (README, "Pausing on Android"; API 26 o más). Con pocas voces, F1 y F2 podrían sonar igual: el motor no las repite sin avisar (criterio 4); un tono distinto sobre la misma voz (`setPitch`) solo sería un último recurso que la persona acepte a sabiendas (la calidad se oye en P3.3: 9.2, V2). |

**Windows.** `windows/flutter_tts_plugin.cpp` tiene dos implementaciones: una con `SpeechSynthesizer` de WinRT (línea 18) y otra con SAPI 5 (`ISpVoice`, línea 238). Cada una lista voces distintas y **no pude determinar cuál se compila** en una app de escritorio (9.2, V5).

### 4.2 Fuente B: modelo descargable que corre en el dispositivo

| | |
|---|---|
| **Qué es** | Voces neuronales (familias VITS/Piper, Kokoro, Matcha, Kitten…) que se ejecutan con ONNX Runtime dentro de la app, con la biblioteca **sherpa-onnx**. Una misma voz en teléfono y laptop y, según el modelo, varias voces en un solo archivo (`sid`). |
| **Cómo se obtiene la voz** | La persona descarga un modelo (4.2.2). `sherpa_onnx` 2.0.1: `OfflineTts(OfflineTtsConfig(model: …))` carga el modelo; `generate(text, sid, speed)` (`lib/src/tts.dart:376`) devuelve `GeneratedAudio(samples, sampleRate)` (`tts_config.dart:565`); `numSpeakers`, `sampleRate` y `lang` dicen lo que trae (`tts.dart:467-494`); `free()` libera (línea 363). El motor parte cada turno en frases, genera una por una (la siguiente mientras suena la anterior), escribe cada frase como WAV temporal y la reproduce con el reproductor de audio. La velocidad es el parámetro `speed`. |
| **Qué necesita** | Paquete `sherpa_onnx` (Apache-2.0), un reproductor de audio (sección 8) y, solo si los modelos se descargan como `.tar.bz2`, `archive` (camino 2 de 4.2.1). Permisos: ninguno nuevo; `INTERNET` ya está declarado (`AndroidManifest.xml:3`) y solo lo usa el gestor de descargas. |
| **Qué pesa** | **Bibliotecas nativas [consultado]:** Android arm64, 27 176 800 bytes sin comprimir (`libonnxruntime.so` 22 249 560, `libsherpa-onnx-c-api.so` 4 484 952, `libsherpa-onnx-cxx-api.so` 442 288; el paquete pesa 10 448 654 bytes comprimido); Windows x64, 22 093 824 bytes (`onnxruntime.dll` 17 799 168 y `sherpa-onnx-c-api.dll` 4 294 656). Lo que añaden al instalador se mide al compilar (9.2, V3). **Cada modelo [consultado]:** entre los candidatos de 9.1, de 26 855 312 bytes (Kitten) a 319 625 534 (Kokoro en inglés). |
| **Sin conexión** | Funciona una vez descargado. Es la razón de ser de la vía. |
| **Cómo falla** | (1) No descargado: `modeloNoInstalado`. (2) Archivo corrupto: no llega a cargarse (4.2.2). (3) `OfflineTts` lanza *"Failed to create offline tts"* (`tts.dart:356`): `FalloDeSintesis`. (4) El proceso muere al cargar (error nativo): marca de carga (4.2.3). (5) Es más lento que el audio (RTF mayor que 1): el catálogo no lo ofrece para tiempo real. (6) Sin espacio al descargar. |
| **Qué ve la persona** | Ajustes › Voz › Voces descargables: nombre, voces, tamaño, licencia y estado (*no descargada*, *descargando 43 %*, *instalada*, *dañada*), con Descargar, Cancelar, Borrar y Probar (5.1). |

#### 4.2.1 Catálogo de modelos (datos, no código)

Archivo `app/assets/voces/catalogo.json`, dentro de la app: **no se descarga**, así que las huellas viajan firmadas con la app. Forma (los valores entre `<>` los llena P3.0b; los números de ejemplo son los medidos el 16/nov/2026, 9.1):

```json
{
  "esquema": "gravity-voces-v1",
  "modelos": [
    {
      "id": "piper-en_US-libritts_r-medium",
      "nombre": "Inglés americano (904 voces)",
      "familia": "vits",
      "idioma": "en",
      "variantes": ["en-US"],
      "voces": [ { "sid": "<n>", "nombre": "<nombre>", "genero": "<mujer | hombre>", "variante": "en-US" } ],
      "asignacion_sugerida": { "F1": "<sid>", "F2": "<sid>", "M1": "<sid>", "M2": "<sid>", "N": "<sid>" },
      "archivos": [
        { "rol": "modelo",  "nombre": "en_US-libritts_r-medium.onnx", "bytes": 78529840,
          "sha256": "8cce84cee4060bc3c2194bf95d33253c48dc8ff15e197b3b7a00b334ee0017f4", "url": "<revisión fija>" },
        { "rol": "tokens",  "nombre": "tokens.txt", "bytes": 954,
          "sha256": "620e1aecf1a68fea3ba5850d137b0138fa2037c9b372dad13b95a2a215d0849a", "url": "<revisión fija>" },
        { "rol": "lexicon", "nombre": "lexicon-en-us.txt", "bytes": 6305773,
          "sha256": "8b67ae549a465eee78f92ecb74644ad90c3c58ce65f19c68baf85878a10ef73a", "url": "<revisión fija>" }
      ],
      "licencia": {
        "id": "CC-BY-4.0", "origen": "tarjeta del modelo (MODEL_CARD)", "atribucion": "<texto para la pantalla>",
        "permite_distribuir_audio": "<sí | no: lo decide quien lee la licencia>", "texto": "docs/licencias-voces/<archivo>"
      },
      "fuente": { "url": "<página del modelo>", "revision": "<etiqueta o commit>" },
      "consultado": "2026-11-16",
      "uso": { "tiempo_real_telefono": "<true | false: lo da la medición de P3.3>", "tiempo_real_laptop": "<…>", "pregrabar": "<…>" },
      "rtf": [ { "equipo": "<Galaxy A52>", "hilos": 2, "rtf": "<medido>", "fecha": "<…>" } ]
    }
  ],
  "paquetes_audio": [
    { "id": "<escalon>", "ambito": "escalon", "bytes": "<…>", "sha256_manifiesto": "<…>", "url_base": "<…>" }
  ]
}
```

Reglas del catálogo (criterios 14 y 27):

1. **Sin nulos ni pendientes.** Un modelo con un dato sin verificar no entra al catálogo de la app; vive como *candidato* en 9.1 hasta que se verifique.
2. Toda dirección es `https://`, sin parámetros de consulta y con **revisión fija** (etiqueta o commit), nunca `main` ni "la última".
3. Los nombres de archivo no llevan `/`, `\` ni `..`.
4. La licencia lleva su identificador, el texto literal de la tarjeta y la atribución que la pantalla debe mostrar. Si `permite_distribuir_audio` no es claramente verdadero, el modelo no se usa para pregrabar (C).
5. `uso` y `rtf` salen de la medición en el equipo, no de la documentación de terceros.
6. Modelo = **lista de archivos con huella**. El modelo no se descarga como carpeta: cada archivo se verifica por separado y solo se bajan los que el catálogo lista (por ejemplo, no el `espeak-ng-data` de 392 entradas que traen los paquetes originales y que `sherpa_onnx` 2.0.x ignora: 4.2.5).

**De dónde salen los archivos.** Los modelos ya preparados para sherpa-onnx se publican como `.tar.bz2` en los *releases* de GitHub [consultado]. Si existen copias con los archivos sueltos, estarán en Hugging Face, que esta sesión no alcanzó (9.0). Hay dos caminos y decide el dueño (preguntas 1 y 4):

- **Camino 1 (recomendado): archivos sueltos en un alojamiento propio.** Quien verifica el modelo (P3.0b) extrae solo los archivos útiles, los hashea y los sube a un lugar con dirección fija (por ejemplo, un bucket público de Supabase Storage, dentro del 1 GB de D7). Así no hace falta `archive`, no se descomprime bzip2 en el teléfono y cada archivo se baja y se verifica solo. Cuesta un paso manual por modelo y obliga a cumplir las licencias al redistribuir (atribución y copia del texto de la licencia junto a los archivos).
- **Camino 2: los `.tar.bz2` originales con `archive`.** La app verifica la huella del archivo comprimido, extrae solo los miembros que el catálogo declara (verificando de nuevo cada uno y rechazando rutas absolutas o con `..`) y borra el comprimido. Hay que comprobar que `archive` descomprime bzip2 en flujo y sin cargar todo en memoria: si no, un modelo de 320 MB no es viable en el teléfono (9.2, V3).

#### 4.2.2 Gestor de descarga

Estados de un modelo: `noDescargado` → `descargando` → `instalado`; `corrupto` aparte. Reglas:

1. **Aviso del tamaño.** Antes de pedir nada, la pantalla muestra nombre, voces, **tamaño total** (suma de `bytes`), licencia y "necesitas Wi-Fi". La persona toca *Descargar (63 MB)*; nada empieza antes (criterio 17). El aviso dice que el sitio que aloja el archivo verá la dirección de internet del equipo.
2. **Wi-Fi por omisión.** Solo con Wi-Fi o Ethernet. Con datos móviles pide confirmación explícita **cada vez** y no la recuerda; sin red avisa y no abre nada (criterio 18). Lo decide `FuenteTipoDeRed`; `connectivity_plus` informa el tipo de red pero no si es medida (un punto de acceso del teléfono contaría como Wi-Fi): el aviso lo dice.
3. **Carpeta privada.** `<datos de la app>/voces/modelos/<id>/`. Android: `getApplicationSupportDirectory()` (`filesDir`: el sistema no lo vacía; `path_provider_android` 2.3.1, `lib/src/path_provider_android_real.dart:28-34`, frente a `cacheDir`, líneas 49-55, que sí puede vaciar). Windows: `getApplicationCacheDirectory()` (AppData\Local), **no** `getApplicationSupportDirectory()`, que es AppData\Roaming (`path_provider_windows` 2.3.0, `lib/src/path_provider_windows_real.dart:119-128`). Los WAV temporales van a `getTemporaryDirectory()` y se vacían al arrancar. Ninguna carpeta pública, ningún permiso de almacenamiento, y Android no respalda estos archivos (`allowBackup="false"` y las reglas de extracción, `AndroidManifest.xml:31-32`).
4. **Descarga por archivo, en orden.** `GET` a la dirección del catálogo; si hay `<archivo>.parcial`, con `Range: bytes=N-` y `If-Range` con el `ETag` guardado en `estado.json`. Se sigue la redirección (GitHub redirige a direcciones firmadas que caducan: la dirección que se vio el 16/nov/2026 vencía a la hora), pero **la reanudación siempre empieza de nuevo por la dirección del catálogo**, nunca por la dirección firmada. Si el servidor ignora `Range` y responde 200 completo, se reinicia ese archivo y no se concatena (criterios 20 y 21). El **progreso** (`ProgresoDescarga`) cuenta los bytes de todo el modelo, no solo los del archivo actual, y la pantalla muestra porcentaje y MB (criterio 19).
5. **Verificación.** Al terminar cada archivo se comprueba el tamaño y el **sha256** contra el catálogo (`crypto` ya está en `pubspec.yaml:58`; el cálculo corre en un `Isolate`). Si no coincide: **se borra el archivo y toda la carpeta de descarga**, el estado vuelve a `noDescargado` y se lanza `HuellaIncorrecta`. No hay reintento automático (criterio 22).
6. **Instalación atómica.** Se descarga en `<id>.descarga/`; solo cuando todos los archivos verificaron, la carpeta se renombra a `<id>/` y se escribe `instalado.json`. Un corte en cualquier punto nunca deja un modelo `instalado` a medias (criterio 23).
7. **Sin espacio.** No se agrega un paquete para medir el espacio libre: se maneja el error de disco lleno del sistema (`FileSystemException` con código 28 en Android y 112 en Windows) como `SinEspacio`, sin dejar carpetas a medias (criterio 24).
8. **Cancelar** detiene y conserva lo descargado para reanudar, con un botón *Borrar lo descargado*. **Borrar un modelo** elimina `<id>/` y `<id>.descarga/`, para antes la voz si estaba sonando, actualiza la cadena y dice *"Liberaste 63 MB"* (criterio 25).
9. **Integridad después.** Al arrancar solo se comprueban los tamaños; el sha256 completo se recalcula con el botón *Comprobar* (en un `Isolate`) y tras actualizar la app.
10. **Una descarga a la vez por modelo.** Pedir la misma otra vez devuelve el mismo flujo.
11. **Cabeceras.** Solo `Range`, `If-Range`, `Accept-Encoding` y un `User-Agent` fijo y genérico; ni cookies, ni `Authorization`, ni parámetros con identificadores (criterio 15).

#### 4.2.3 Síntesis y reproducción

- **Hilo.** La generación bloquea al hilo que la llama (`generate` es síncrona, `tts.dart:376-466`): el motor la corre en un `Isolate` de larga vida y **cada isolate llama `initBindings()`** (`lib/sherpa_onnx.dart:22-41`; sin eso, `OfflineTts` lanza "Please initialize sherpa-onnx first").
- **Por frase.** Un turno largo (los guiones de ejemplo traen párrafos de unas 50 palabras) no se genera de golpe: el tiempo hasta el primer sonido dependería del turno entero. Se parte en frases por la puntuación y se genera una de adelanto. `onProgress` devuelve 1 para seguir y 0 para detener (ejemplo oficial `dart-api-examples/tts/bin/piper-lexicon.dart`): así `parar` interrumpe también la generación.
- **Hilos de cómputo.** `OfflineTtsModelConfig.numThreads` vale 1 por omisión (`tts_config.dart:458`). Se miden 1, 2 y 4, como hace la documentación de sherpa-onnx, y se fija el menor con RTF menor que 1 (criterio 42).
- **Marca de carga.** Antes de cargar un modelo se escribe un archivo `cargando-<id>`; al terminar de cargar se borra. Si al arrancar existe, el proceso murió al cargar (un error nativo no se atrapa): el modelo queda `corrupto` hasta que la persona lo reintente o lo borre (criterio 26). Una voz que tumba la app no puede tumbarla en cada arranque.
- **Solo lo del catálogo.** El cargador arma las rutas con los nombres del catálogo dentro de la carpeta del modelo; nunca recorre la carpeta ni acepta otros archivos.
- **Prueba de humo.** La primera vez que se carga un modelo se genera una frase fija y se comprueba que hay muestras y una frecuencia de muestreo mayor que cero (el paquete devuelve `GeneratedAudio` vacío cuando falla, `tts.dart:416` y `:455`).

#### 4.2.4 Qué modelo para qué uso

Los números de la documentación de sherpa-onnx están medidos en una Raspberry Pi 4B, no en el Galaxy A52 ni en la laptop (9.1). Sirven como señal, no como dato:

- Los modelos tipo **Piper** (de unos 61 a 75 MB de modelo) tuvieron RTF de 0.77 a 0.81 con un hilo y de 0.35 a 0.36 con cuatro: más rápidos que el audio incluso en ese equipo. Son los candidatos a **tiempo real en el teléfono**.
- **Kokoro** (de 311 a 330 MB de modelo) tuvo RTF de 6.6 a 7.6 con un hilo y de 2.8 a 3.2 con cuatro: más lento que el audio en ese equipo. Es candidato a **pregrabar en la laptop** (fuente C), donde la calidad pesa más que la velocidad. Si en el A52 o en la laptop el RTF mide menos de 1.0, también puede ser de tiempo real (criterio 42).
- El catálogo guarda en `uso` lo que la **medición propia** decide, no lo que dice la documentación.

#### 4.2.5 Cambio de versión que afecta al diseño

El CHANGELOG de `sherpa_onnx` 2.0.0 dice *"Remove espeak-ng and piper-phonemize from sherpa-onnx (#4055)"* (`CHANGELOG.md:50`), y en 2.0.x el campo `dataDir` de VITS y de Kokoro está *"Deprecated. Ignored since v2.0.0. Use a lexicon file or pass pre-phonemized input"* (`lib/src/tts_config.dart:101`, `:213`). Consecuencias:

- Los paquetes de modelo originales (con la carpeta `espeak-ng-data`) **ya no funcionan solos**: necesitan un archivo de **lexicón**. Para inglés americano el ejemplo oficial usa `lexicon-en-us.txt` con Piper (`dart-api-examples/tts/run-piper-lexicon.sh`) y con Kokoro (`run-kokoro-en-lexicon.sh`) [consultado].
- **Inglés británico y español con Piper:** no encontré un lexicón para ellos en la misma etiqueta de *releases* (9.1). Que existan es **[sin verificar]** (9.2, V8 y V9). Esto afecta al asistente en español y a los simulacros con acento británico.
- La alternativa sería quedarse en una versión anterior a 2.0.0 (la 1.13.8 es del 11/sep/2026), que todavía traía `espeak-ng` según el CHANGELOG; su licencia como parte del binario está **[sin verificar]** (9.2, V13).

### 4.3 Fuente C: audio pregrabado

| | |
|---|---|
| **Qué es** | Los audios del curso, generados antes en la laptop con la vía B, normalizados, comprimidos y entregados como archivos. La app solo los reproduce: no sintetiza nada. |
| **Cómo se obtiene la voz** | Un generador (4.3.4) recorre las unidades de audio en estado `revisado` o `aprobado`, las sintetiza con el modelo y las voces asignadas, y escribe un **paquete por escalón** con su manifiesto. El dueño oye una muestra antes de publicarlo (D-ING-4: aprobación por muestras). La app descarga el paquete del escalón que estudia y lo verifica. |
| **Qué necesita** | El reproductor de audio (sección 8). Para descargar, `INTERNET` (ya declarado) y el mismo gestor de 4.2.2. En la laptop, el generador necesita un codificador de audio externo (pregunta 5). |
| **Qué pesa** | El plan estimó 90 a 120 MB para todo el curso en Opus (cálculo del plan, unos 300 audios de 1.6 minutos, **no medido**; plan, anexo F, fila *C. Audio pregrabado*). Con AAC sería mayor. El tamaño real es la suma de los `bytes` de los manifiestos; las frases para repetir (20 o más por sesión) no están en esa estimación (se miden en P3.2b). |
| **Sin conexión** | Funciona una vez descargado el paquete. Sin el paquete y sin conexión, la cadena pasa a B o a A. |
| **Cómo falla** | (1) No hay paquete: `sinPaqueteDeAudio`. (2) La pieza no coincide con el guion actual: `audioCaducado`. (3) Una pieza no coincide con su huella: se borra y se pide de nuevo una vez. (4) El formato no se reproduce en la plataforma: `formatoNoSoportado`. |
| **Qué ve la persona** | En Ajustes › Voz › Audio del curso: un paquete por escalón con su tamaño y *Descargar* o *Borrar*. En la unidad, una etiqueta *"audio desactualizado"* cuando una pieza caducó. |

#### 4.3.1 Contenido de un paquete

```
<datos de la app>/voces/audio/<escalon>/
  manifiesto.json
  <id-de-pieza>.<ext>           una pieza por unidad de audio: el id de la unidad
  <id-de-sesion>-frase-NN.<ext>  una pieza por frase para repetir (propuesta; se confirma en P3.2b)
```

Un paquete también puede ser de una forma de examen o de la ubicación (`ambito`), con el mismo mecanismo.

#### 4.3.2 Manifiesto

```json
{
  "esquema": "gravity-audio-v1",
  "ambito": "escalon", "escalon": "A2.1", "generado": "<fecha>",
  "motor": { "modelo": "<id del catálogo>", "version": "sherpa_onnx <x.y.z>" },
  "formato": { "contenedor": "<m4a | opus>", "codec": "<aac-lc | opus>", "kbps": "<n>", "hz": "<n>", "canales": 1 },
  "piezas": [
    {
      "id": "<id de la unidad>",
      "archivo": "<id>.<ext>", "bytes": "<n>", "sha256": "<archivo>",
      "huella_guion": "<sha256>", "huella_voz": "<sha256>",
      "variante": "en-US", "velocidad": 1.0, "duracion_ms": "<n>",
      "voces": { "M1": "<id de la voz del motor>" },
      "turnos": [ { "i": 0, "voz": "M1", "inicio_ms": 0, "fin_ms": "<n>" } ]
    }
  ]
}
```

#### 4.3.3 Cuándo caduca un audio

- **`huella_guion`** = sha256, en hexadecimal minúscula, de la cadena UTF-8 `gravity-guion-v1`, salto de línea, la `variante`, salto de línea y, por cada turno, `voz`, tabulador, `texto` y salto de línea. El `texto` va en NFC, sin espacios al inicio ni al final y con cada secuencia de espacios en blanco reducida a un espacio. La calcula **una sola función**, en `herramientas/ingles`: `compilar` la escribe en cada unidad compilada y el generador la escribe en el manifiesto. **La app no la recalcula: compara las dos cadenas.** Si el guion cambia una sola palabra, la huella cambia y la pieza caduca (criterio 28). Es la misma idea de la huella de las revisiones a ciegas (formato, sección 9, punto 4; plan, sección 5.6, regla 12).
- **`huella_voz`** = sha256 de modelo, huellas de sus archivos, versión del motor, velocidad, parámetros de síntesis y asignación de voces. Es informativa: dice con qué voz se hizo, no invalida nada.
- **Velocidad.** Las piezas se pregraban a 1.0. A 0.8 se le pide al reproductor que cambie el ritmo sin cambiar el tono; **que lo haga así en Android y en Windows está [sin verificar]** (9.2, V7). Si en la prueba de oído (P3.3) suena mal en alguna plataforma, se pregraba también a 0.8 (el tamaño casi se duplica).

#### 4.3.4 Generador de audio

Orden `audio` de `herramientas/ingles` (la escribe habitos, depende de `compilar`, P1.2c):

1. Lee las unidades `revisado` o `aprobado` y sus `huella_guion`.
2. Sintetiza cada turno por frase con el modelo y la `asignacion_sugerida` del catálogo, une los turnos con la pausa del guion y nivela el volumen (el criterio de nivelación se decide de oído en P3.3).
3. Codifica con una herramienta externa (propuesta: AAC-LC en M4A si Windows no reproduce Opus; ver 9.2, V7).
4. Calcula bytes, sha256, duración y límites de cada turno; escribe el manifiesto.
5. **Control automático (propuesta):** compara la duración medida con la que estima la regla V22 (palabras ÷ 150 por minuto, `gravity-sesion-60.yaml`: `palabras_por_minuto: 150`) y, con la misma tolerancia que V22 usa por bloque (70 % a 150 %), marca para oír la pieza que quede fuera.
6. La síntesis del generador es la misma que usa la app, así que corre dentro de la app de escritorio (modo Desarrollador) salvo que se compruebe que `sherpa_onnx` carga sus bibliotecas nativas desde un `dart run` sin Flutter (9.2, V3).

## 5. Cómo se elige

### 5.1 Ajustes › Voz

Hoy es una pantalla con dos notas (`pantalla_voz.dart:13-27`); la ven todos los roles que abren Ajustes (`secciones_ajustes.dart:46-51`, `:137`). El diseño ya decide que se elige la voz, la velocidad y el tono y que **cada persona elige la suya** (`docs/DISENO_UX_UI.md:305`). Se amplía con estas secciones (las escribe plataforma; el diseño visual, diseno):

1. **Curso de inglés** (solo quien usa Hábitos). Fuente preferida: *Automática* (recomendada), *Audio pregrabado*, *Voz descargada* o *Voz del dispositivo*, con el interruptor *Solo esta fuente*. Voces por acento (*Inglés americano* y *Inglés británico*): cinco filas (F1, F2, M1, M2, N) con el nombre de la voz asignada, *Probar* y *Cambiar*.
2. **Asistente** (quien conversa: dueño, coadministrador y familiar; `panel_conversacion.dart:31-36`). Fuente y voz en español, velocidad y, solo si la fuente lo admite (A), tono.
3. **Voces descargables.** La lista de 4.2.2, con *Espacio usado* y *Comprobar integridad*.
4. **Audio del curso.** Un paquete por escalón (4.3).
5. **Probar** (5.4).
6. **Licencias.** La atribución de cada voz instalada (R11).
7. **Detalles técnicos** (plegado). Voces del sistema (nombre, `locale`, calidad, `network_required`, `features`), RTF, tiempo hasta el primer sonido, tiempo de carga y memoria de cada modelo. Es lo que mide P3.3 (9.2, V3 y V4) y también sirve para ver qué voces trae cada aparato.

### 5.2 Preferencias

Por persona y por uso: fuente preferida, *solo esta fuente*, velocidad, tono y asignaciones por fuente y variante. Se guardan en `shared_preferences` con una clave por persona, como hace `almacen_apariencia_persistente.dart:1-35` (no es dato sensible). En la tablet cambian con el usuario activo (`DISENO_UX_UI.md:305`); la cuenta Casa tiene las suyas. Los **modelos y paquetes de audio son del equipo, no de la persona**: se descargan una vez y los ve quien abra Ajustes › Voz en ese equipo.

### 5.3 La cadena de respaldo

- **Curso:** C, luego B, luego A. **Asistente:** A, luego B (C no aplica: el texto es nuevo). Son propuestas: el dueño las cambia de oído después de P3.3.
- La persona elige una **fuente preferida**; las demás quedan detrás en el mismo orden. *Solo esta fuente* quita el respaldo.
- La cadena que usa cada reproducción sale de `disponibilidad`: solo cuentan las fuentes que pueden con **todo** el guion (voces suficientes de la variante, modelo instalado, pieza vigente).
- Cuando se usa una fuente de respaldo, el reproductor lo dice en pequeño (*"Voz: dispositivo"*), para que el dueño sepa qué oye.
- **Si no hay ninguna**, el mensaje dice por qué no sirve cada fuente y qué hacer (5.5). Si el audio es obligatorio (ubicación, puertas), no se ofrece la prueba hasta que haya una fuente (plan, sección 3.3 y paquete P2.4).

### 5.4 Probar con la misma frase

El dueño elige de oído (D-ING-3; plan, P3.3). La pantalla *Probar* reproduce **el mismo guion de prueba** con cada fuente disponible, una a la vez, con `soloFuente`, y muestra qué fuente y qué voz sonó y, en *Detalles técnicos*, el RTF y el tiempo hasta el primer sonido.

- **Guion de prueba.** Contenido propio, incluido en la app, copiado de los ejemplos patrón: los seis primeros turnos de `data/ingles/ejemplos/audio-b1-1-s01-b-ejemplo.yaml` (diálogo F1 y M1) y las cinco primeras frases de `data/ingles/ejemplos/sesion-b1-1-s01-lun-ejemplo.yaml` (líneas 198-202). Si el ejemplo cambia, la prueba no.
- Para la vía C se incluye en la app una pieza pregrabada de ese mismo guion (pocos segundos), de modo que se compare sin descargar un escalón.
- **Hoja de escucha** (P3.3), por fuente y voz, de 1 a 5: se entiende cada palabra; suena natural; el ritmo a 1.0 y a 0.8; se distingue F1 de M1; el acento; se puede escuchar 10 minutos sin cansarse; números y horas bien dichos. Al final, *elijo esta*.

### 5.5 Mensajes

Tono de GRAVITY: tranquila, breve y sin culpa (`DISENO_UX_UI.md:307`).

| Situación | Mensaje | Acciones |
|---|---|---|
| Sin voz en inglés (A) y sin modelo | "Este equipo no tiene una voz en inglés. Puedes descargar una voz de GRAVITY o instalar una en los ajustes del sistema." | Descargar una voz · Cómo instalar una voz |
| Pocas voces | "Este audio tiene {n} voces y la voz elegida solo tiene {m}. Prueba con otra fuente." | Cambiar fuente |
| Modelo no descargado | "La voz «{nombre}» no está descargada. Pesa {tamaño}." | Descargar |
| Datos móviles | "No estás en Wi-Fi. La descarga usará {tamaño} de tus datos." | Descargar con datos · Esperar al Wi-Fi |
| Sin red | "No hay conexión. Cuando vuelva, puedes continuar la descarga." | — |
| Sin espacio | "No hay espacio para esta voz. Necesitas liberar {tamaño}." | Ver qué ocupa espacio |
| Huella incorrecta | "El archivo no era el esperado y se borró. Vuelve a intentarlo; si sigue igual, revisa tu conexión." | Reintentar |
| Descarga interrumpida | "La descarga se detuvo en {x} %." | Reanudar |
| Audio caducado | "El audio de esta unidad ya no coincide con el texto; uso otra voz." | — |
| Ninguna fuente | "No hay una voz disponible para este audio." y, debajo, el motivo de cada fuente | Descargar · Instalar · Ajustes de voz |
| Otra voz sonando | "Hay otra voz sonando." | Parar |
| Falla a mitad | "La voz se detuvo." | Reintentar con otra fuente |

**Cómo instalar una voz en inglés.** Android: en los ajustes del sistema, *Salida de texto a voz* e instalar los datos de voz del inglés. Windows: en Configuración, *Hora e idioma › Voz*, agregar voces en inglés. **La ruta exacta cambia entre fabricantes y versiones y no se verificó en el A52 ni en la laptop** (9.2, V4); se ajusta en P3.3.

## 6. Integración con el curso

### 6.1 Lo que el reproductor del curso pide al motor

| El curso necesita | El motor ofrece | Origen del requisito |
|---|---|---|
| Reproducir un audio **una o dos veces** | El reproductor llama a `reproducir` el número de veces que diga el contrato (`reproducciones`: 2 en `traslado-audio` y en Cambridge; 1 en TOEIC y TOEFL) y deja una pausa entre repeticiones (valor de P3.1). El motor no cuenta repeticiones | `gravity-sesion-60.yaml` (`traslado-audio`: `reproducciones: 2`); `data/ingles/formatos/cambridge-b1-preliminary.yaml` (listening) |
| **Velocidades 0.8 y 1.0** | `velocidad` en cada reproducción (4.1 a 4.3) | Plan, paquete P3.1. **Ningún contrato de `data/ingles/formatos/` declara velocidades hoy** (comprobado con búsqueda): si P3.1 las quiere por contrato, habitos debe agregar el campo |
| **Guion oculto hasta contestar** | `Avance` lleva turno y voz, nunca el texto; el `Guion` vive solo en el reproductor | Plan, sección 3.5; formato, sección 4.1 |
| **Pausa entre turnos** | `Guion.pausaEntreTurnos` y `Turno.pausaDespues` (propuesta de 600 ms, se decide de oído en P3.3) | — |
| **Varias voces** (F1, F2, M1, M2, N) | `VozDeGuion`, `Asignacion` y `disponibilidad(vocesNecesarias: …)` | Formato 4.1; V16 |
| **Acento** | `Guion.variante` (`en-GB` en los contratos de Cambridge y `en-US` en los de TOEFL, TOEIC y la sesión del curso: campo `variante` de cada archivo de `data/ingles/formatos/`) | Contratos |
| **Frases para repetir** (20 o más al día) | `decir(frase, uso: curso, variante, voz, velocidad)`, una a una; el reproductor espera `terminada` y recién entonces empieza a grabar (P3.2b) | `traslado-repeticion` |
| **Tarjetas en audio** | `decir` de la palabra, del ejemplo y, si P3.1 lo decide, de la traducción en `Variante.esMX` | `traslado-tarjetas` |
| **Saber si hay audio** | `disponibilidad(UsoVoz.curso, variante, vocesNecesarias)` antes de ofrecer la Ubicación, las puertas o el traslado | Plan, sección 3.3 y paquete P2.4; `gravity-sesion-60.yaml` (`sin_audio`) |
| **Parar y pausar** | `Reproduccion.pausar/reanudar/parar` | — |

### 6.2 Pruebas con valor: la fuente se congela y se registra

La ubicación, las puertas y los simulacros deciden el nivel de una persona. Si un intento se oyó con una voz clara y otro con una voz de baja calidad, la dificultad cambió sin que nadie lo dijera. Por eso:

1. Dentro de una prueba, **todas** las reproducciones usan la misma fuente (`soloFuente`), elegida al empezar con la cadena de 5.3.
2. El reproductor **registra** con el intento la fuente y el acento usados (`Reproduccion.fuente`, `Guion.variante`). Pedirlo a habitos para las tablas `ing_*` (la decisión es de ellos).
3. Si no hay fuente, la prueba no se ofrece. Si falta el acento de la prueba (por ejemplo, voces británicas en un simulacro de Cambridge), se avisa y se registra.

### 6.3 Lo que NO es del motor

- **Grabar el habla del estudiante** (micrófono y permiso `RECORD_AUDIO`, ya declarado para el dictado en `AndroidManifest.xml:19`), guardarla en el dispositivo y compararla: P3.2b.
- **Calificar o reconocer** lo que dijo: autoevaluación con lista de cotejo y modelo, y revisión en pareja (plan 3.5 y fase 6). El reconocimiento de voz (`speech_to_text`) no se usa para calificar.
- **Cuántas veces se oye, cuándo, y el modo examen** (sin pausa y sin 0.8, como el examen oficial): política del reproductor (P3.1).
- **Decidir qué contenido se oye**: es el curso.

### 6.4 Modo traslado

El diseño de Hábitos define el traslado como **solo audio y manos libres**, con la pantalla bloqueada y control por voz (`docs/modulos/habitos/diseno-app-habitos.md:495-499`), y el plan lo incluye en P3.2b. El motor se diseña para eso (la reproducción no depende de la pantalla: 3.4, punto 6), pero **reproducir con la pantalla bloqueada o la app en segundo plano normalmente necesita un servicio en primer plano de Android y su permiso**, y no se resuelve aquí: se especifica y se prueba en P3.2b (9.2, V12). Hasta entonces, el traslado funciona con la app abierta.

## 7. Integración con las bocinas

**Pendiente de D6.** D6 está en estado propuesta (`DECISIONES.md:18`, `:146`); la especificación de la Fase 6 y `frases.dart:45` registran las frases fijas como aprobadas el 8/nov/2026, pero no cambian el estado de D6. Esta sección **no decide nada**: describe lo que hay y una alternativa para que el dueño elija dentro de D6.

### 7.1 Hoy

`PuenteHomeAssistant.hablar` hace `POST /api/services/tts/speak` con `entity_id` (por omisión `tts.home_assistant_cloud`, `puente_casa.dart:54`), `media_player_entity_id`, `message` y `language: 'es-MX'` (`:85-107`). Solo acepta un `MensajeBocina`, ya validado por `FiltroBocina` (máximo 280 caracteres; sin cifras, dinero, datos clínicos ni nombres; `mensaje_bocina.dart:14-19`, `:55`, `:73-96`). El puente corre en la red de la casa, sin puertos abiertos, y su token no está en la app (`puente_casa.dart:1-7`).

La documentación de Home Assistant presenta el texto a voz de *Home Assistant Cloud* como un servicio en la nube (`integrations/cloud.markdown`) **[consultado]**: con la entidad por omisión, el texto de cada mensaje sale de la casa hacia ese servicio. El filtro de D6 evita dinero y datos clínicos, pero no vuelve local el texto. D6 dice además que lo que se dice a la bocina pasa por Google (`DECISIONES.md:160`). Conviene confirmarlo con el agente casa.

### 7.2 Alternativa: generar el audio en el motor local y mandarlo por el puente

**DECISIÓN DEL DUEÑO dentro de D6 (propuesta). No se decide aquí.**

1. Quien manda el mensaje (el puente en la laptop) pide al motor que sintetice el `MensajeBocina` ya validado con la voz local (vía B) y obtiene un archivo de audio.
2. El archivo llega a la bocina por el puente: Home Assistant reproduce medios con `media_player.play_media` si están disponibles por HTTP(S) (`integrations/cast.markdown`, línea 51 **[consultado]**). Cómo se aloja ese archivo (la carpeta de medios de Home Assistant o un servidor local temporal) lo define el agente casa con la documentación de Home Assistant, que esta sesión leyó solo en parte.
3. Las bocinas Cast **no resuelven nombres locales**: la dirección debe ser una IP o resolverse por el DNS público de Google (`cast.markdown`, líneas 37-41 **[consultado]**).
4. Los modelos Piper generan a 22 050 Hz y Home Assistant documenta que algunas bocinas Cast **omiten el inicio del audio a 22 050 Hz** y piden 44 100 Hz (`tts.markdown`, sección *Partial, corrupted or no audio* **[consultado]**): habría que remuestrear (y, para MP3, usar tasa de bits constante).

| | **Hoy: texto al TTS de Home Assistant** | **Alternativa: audio del motor local** |
|---|---|---|
| El texto sale de la casa | Con la entidad por omisión (nube de Home Assistant), sí | No |
| Misma voz que en la app | No | Sí |
| Depende de la nube de Home Assistant para hablar | Sí | No |
| Depende de la laptop encendida | Mientras la laptop sea el puente (D9, fase 1) | Siempre que el modelo corra en la laptop. Con el equipo dedicado (D9, fase 2), un equipo sin la capacidad para correr el modelo **[sin verificar]** no puede generarlo |
| Latencia | La del servicio | La de sintetizar y servir el archivo |
| Piezas nuevas | Ninguna | Entrega del archivo, remuestreo, y un uso `bocinas` en el motor |

### 7.3 Lo que no cambia, se decida lo que se decida

Las frases fijas (`frases.dart:45-78`), el filtro de salida (D6, D3), el rol Casa (D5), la regla de no abrir puertos y de no guardar el token en la app (D9). La entrada sigue siendo del servicio de Google Home.

### 7.4 Si el dueño elige la alternativa

Se agregaría `UsoVoz.bocinas` y un método del motor que **solo acepte un `MensajeBocina`** (no un texto libre), y la entrega la implementa el agente casa en `app/lib/modulos/casa/puente/`. Los criterios de esa parte se escribirían entonces. Mientras no haya decisión, el motor no tiene uso `bocinas` (criterio 12).

## 8. Paquetes que el dueño tiene que aprobar

Ningún paquete se agrega con esta especificación. La aprobación se registra como en la Fase 8 bloque 4 (`docs/ROADMAP.md:283`) y los agrega plataforma. Versiones: exactas, con más de dos semanas de publicadas (como en `app/pubspec.yaml:52-53`, `:75-77`, `:79-80`), compatibles con Flutter 3.47.7 y Dart 3.13.5. Todo **[consultado]** en la API de pub.dev el 16/nov/2026.

| Paquete | Para qué | Licencia | Versión propuesta | Plataformas | Qué pesa y qué trae |
|---|---|---|---|---|---|
| **`flutter_tts`** | Fuente A: voz del dispositivo | MIT | 4.2.5 (5/ene/2026) | Android, iOS, Windows, macOS, web | Casi nada: archivo de 498 253 bytes con su ejemplo. Pide `<queries>` en Android (4.1) |
| **`sherpa_onnx`** | Fuente B: voces neuronales en el equipo; además la usa el generador de la fuente C | Apache-2.0 | 2.0.1 (26/oct/2026, 21 días) | Android, iOS, Windows, Linux, macOS, web | Depende de 9 paquetes de plataforma (`sherpa_onnx_android_arm64`, `_armeabi`, `_x86`, `_x86_64`, `_ios`, `_linux`, `_macos`, `_web`, `_windows`). Bibliotecas nativas: arm64 27 176 800 bytes, Windows x64 22 093 824 (4.2). Archivos de pub.dev: 10 448 654 (arm64), 9 433 203 (armeabi), 11 714 261 (x86), 11 428 967 (x86_64) y 16 787 852 (Windows) |
| **`audioplayers`** | Reproducir los archivos de B y C (WAV temporales y piezas pregrabadas) | MIT | 6.8.1 (27/jun/2026) | Android, iOS, Windows, Linux, macOS, web | Seis paquetes hijos (`audioplayers_android`, `_darwin`, `_linux`, `_web`, `_windows` y `_platform_interface`), más `file` y `synchronized`; usa `path_provider`, `http` y `uuid`, que ya están. En Windows (`audioplayers_windows` 4.4.1) usa Media Foundation: `MediaEngineWrapper.cpp` implementa `SetPlaybackRate` y `audio_player.cpp`, fuente por dirección y por bytes. Requiere Flutter 3.44 o más |
| `archive` | **Solo si** los modelos se quedan en `.tar.bz2` (camino 2 de 4.2.1) | MIT | 4.6.0 (31/oct/2026, 16 días) | Todas | Dart puro. Hay que comprobar que descomprime bzip2 en flujo (9.2, V3) |

**Alternativa al reproductor.** `just_audio` 0.10.6 (29/jun/2026, Apache-2.0 y MIT) **no declara Windows** entre sus plataformas: necesitaría además `just_audio_windows` 0.2.3 (4/abr/2026, MIT, WinRT). Es el reproductor más usado en Android (el modo traslado seguramente querrá un servicio de audio en segundo plano) pero son dos paquetes. Se propone `audioplayers` por ser uno solo para las dos plataformas; el reproductor va detrás de `ReproductorDeAudio`, así que cambiarlo después cuesta una clase.

**Lo que ya está y no se agrega** (`app/pubspec.yaml`): `path_provider` ^2.1.6 (carpetas), `crypto` ^3.0.7 (sha256), `http` ^1.6.0 (descarga), `connectivity_plus` ^7.3.2 (tipo de red), `shared_preferences` ^2.5.6 (preferencias), `flutter_riverpod` (proveedores).

**Se evalúan en P3.2b, no se piden ahora** (grabación y traslado): `record` 7.1.2 (9/oct/2026, BSD-3-Clause; Android y Windows), `audio_service` 0.18.19 (29/jun/2026, MIT; no declara Windows) y `audio_session` 0.2.4 (MIT).

**No es un paquete, pero se necesita:** un codificador de audio externo en la laptop del dueño, solo para generar la fuente C (pregunta 5); no entra al repositorio ni a la app.

## 9. Lo que no se pudo verificar y cómo verificarlo

### 9.0 Qué alcanzó esta sesión

El entorno de la sesión **sí alcanzó**: pub.dev, `raw.githubusercontent.com`, los *releases* de GitHub (descarga de archivos) y `developer.android.com`. **No alcanzó**: Hugging Face (`huggingface.co`), `k2-fsa.github.io`, `creativecommons.org`, `cstr.ed.ac.uk`, `learn.microsoft.com`, `docs.flutter.dev` ni `www.home-assistant.io`. La API de GitHub para el repositorio de sherpa-onnx quedó bloqueada por la sesión. Tampoco hay un teléfono ni una laptop Windows: **nada se ejecutó en un dispositivo**. Se intentó instalar y correr la biblioteca de Python de sherpa-onnx para probar la síntesis, y **el sistema de permisos lo denegó**; no se hizo ninguna prueba de síntesis. El anexo F del plan decía que el entorno solo llegaba a ets.org y cambridgeenglish.org: ya no es exacto para GitHub *releases*, `raw.githubusercontent.com` y pub.dev.

### 9.1 Lo que sí se verificó (y de dónde sale)

**Paquetes** (API de pub.dev, y los archivos de `flutter_tts` 4.2.5, `sherpa_onnx` 2.0.1, `sherpa_onnx_android_arm64` 2.0.1, `sherpa_onnx_windows` 2.0.1 y `audioplayers` 6.8.1, **cuya huella sha256 coincide con la que publica pub.dev**; los leí sin ejecutar nada):

- `flutter_tts` 4.2.5 (sha256 `ce5eb209b40e95f2f4a1397116c87ab2fcdff32257d04ed7a764e75894c03775`): MIT; README: velocidad, volumen, tono, voces y `setVoice` en Android, iOS, Web, Windows y macOS; `isLanguageAvailable` sin Windows; `synthesizeToFile` solo Android e iOS; progreso por palabra solo Android, iOS y Web; pausa en Android, iOS, Web y Windows; Android 11 pide `<queries>`. En Android, cada voz trae `network_required` (`FlutterTtsPlugin.kt:623`).
- `sherpa_onnx` 2.0.1 (sha256 `fce38e628bacdd0ff9dd3e11011657b96611158685ef08985a3203cef6e0d171`): Apache-2.0 (texto de `LICENSE` leído); API de síntesis de 4.2; `numThreads` por omisión 1; sin `espeak-ng` desde 2.0.0.
- Tamaños de bibliotecas nativas: 4.2.

**Modelos** (archivos de los *releases* `tts-models` de sherpa-onnx medidos con `Content-Length` el 16/nov/2026; tarjetas y licencias leídas dentro de los paquetes; voces, RTF y tamaños de archivo de la documentación de sherpa-onnx leída en `raw.githubusercontent.com/k2-fsa/sherpa`). **RTF en una Raspberry Pi 4B con 1, 2, 3 y 4 hilos, medido por los autores de sherpa-onnx, no en el A52 ni en la laptop.**

Son **candidatas, no voces verificadas para el catálogo**: a todas les falta al menos la huella de cada archivo, la licencia del conjunto de datos o la medición propia (columna *Pendiente*).

| Candidata | Voces | Archivo (bytes) | Licencia que declara el paquete | RTF 1 → 4 hilos (Pi 4B) | Uso previsto | Pendiente |
|---|---|---|---|---|---|---|
| `vits-piper-en_US-libritts_r-medium` y `lexicon-en-us.txt` | 904 (en-US) | 82 038 311 y 6 305 773 | Tarjeta: conjunto de datos LibriTTS-R, **CC BY 4.0**; "ajustado desde lessac medium" | 0.790 → 0.357 | Tiempo real en teléfono y laptop; las cinco voces del curso en inglés americano | Licencia del modelo base (lessac); los `sid` de cada papel; que el lexicón funcione con él en 2.0.x (el ejemplo oficial lo hace) |
| `vits-piper-en_GB-vctk-medium` | 109 (en-GB) | 80 488 085 | Tarjeta: VCTK, **CC BY 4.0**; ajustado desde lessac | sin dato | Acento británico | Que haya lexicón británico para 2.0.x (no lo encontré) |
| `vits-piper-en_US-kristin-medium`, `-john-medium`, `-norman-medium` | 1 cada una (mujer, hombre, hombre) | 67 259 230; 67 249 181; 67 203 672 | Tarjeta: **dominio público** (LibriVox); kristin y norman entrenadas desde cero; john, ajustada desde kristin | sin dato | La opción de licencia más limpia en inglés americano, pero son 3 voces (faltan 2 de las 5) | Se descargarían 3 modelos (unos 200 MB) |
| `vits-piper-en_GB-cori-medium` | 1 (mujer, en-GB) | 67 257 412 | Tarjeta: dominio público; desde cero | sin dato | Una voz británica limpia | Falta una voz masculina británica limpia |
| `kokoro-en-v0_19` | 11: `af`, `af_bella`, `af_nicole`, `af_sarah`, `af_sky`, `am_adam`, `am_michael`, `bf_emma`, `bf_isabella`, `bm_george`, `bm_lewis` | 319 625 534 | `LICENSE` del paquete: texto de la Apache-2.0; el README remite a `hexgrad/Kokoro-82M` (no se pudo leer) | 6.629 → 2.774 | **Pregrabar en la laptop** (fuente C), con acento americano y británico | Licencia de los datos de entrenamiento; RTF en la laptop |
| `kokoro-int8-multi-lang-v1_1` | 103 (inglés y chino) | 147 052 523 | `LICENSE` del paquete: Apache-2.0 | no está en la tabla | Quizá tiempo real en teléfono (es la versión cuantizada). El paquete v1_0 trae `lexicon-us-en.txt` y `lexicon-gb-en.txt` (5.6 y 6.0 MB según la documentación); el listado del v1_1 no se leyó | RTF y calidad del inglés; qué lexicones trae |
| `kitten-nano-en-v0_1-fp16` | 8 (4 y 4) | 26 855 312 | `LICENSE` del paquete: Apache-2.0 | no está en la tabla | La más pequeña, con las voces suficientes | Calidad; que funcione con la API de Dart (el ejemplo que cita la documentación no existe: 404) |
| `vits-piper-es_MX-claude-high` y `-ald-medium` | 1 cada una | 67 207 890 y 67 196 497 | Tarjeta: `apache-2.0` y `unlicense` | sin dato | El asistente en español | Que haya un lexicón de español para 2.0.x (no lo encontré) |

Se descartan por ahora (por su licencia declarada): `hfc_female`, `hfc_male` y `ryan` (CC BY-NC-SA 4.0, uso no comercial y compartir igual); `northern_english_male` (CC-BY-SA 4.0); y `amy`, `alan` y `jenny_dioco` (la tarjeta dice "See URL"). `libritts_r`, `vctk`, `alba`, `alan`, `jenny_dioco`, `northern_english_male`, `hfc_*`, `ryan`, `amy`, `joe` y `sam` están ajustadas desde la voz *lessac*, cuyo conjunto de datos (Blizzard 2013) tiene una licencia propia que **no pude leer** (9.2, V11).

**Huellas medidas** (para el catálogo de ejemplo de 4.2.1): `vits-piper-en_US-libritts_r-medium.tar.bz2`, sha256 `10dc268f3e371696d721486123e2705a9fc1faa113491979fde4d88dba1f1b1c`; el modelo `.onnx` (78 529 840 bytes), `8cce84cee4060bc3c2194bf95d33253c48dc8ff15e197b3b7a00b334ee0017f4`; `tokens.txt`, `620e1aecf1a68fea3ba5850d137b0138fa2037c9b372dad13b95a2a215d0849a`; `lexicon-en-us.txt` (6 305 773 bytes, 168 662 líneas, encabezado "CMUDict + en_list + compounds"), `8b67ae549a465eee78f92ecb74644ad90c3c58ce65f19c68baf85878a10ef73a`. Los *releases* de GitHub pueden reemplazarse: por eso el catálogo fija revisión y huella.

**Formatos de audio en Android** (`developer.android.com/media/platform/supported-formats`): AAC-LC en M4A y MP3 se decodifican; Opus se decodifica desde Android 5.0 en contenedor Ogg, MP4 y Matroska.

**Home Assistant** (documentación fuente en `raw.githubusercontent.com/home-assistant/home-assistant.io`, archivos `tts.markdown`, `cast.markdown` y `cloud.markdown`): lo que se cita en 7.1 y 7.2.

### 9.2 Lo que no se verificó, y cómo verificarlo

| # | Qué falta | Cómo verificarlo (quien tenga el equipo o la red) |
|---|---|---|
| **V1** | **Licencia, tamaño y huella de cada voz que entre al catálogo**, voz por voz y archivo por archivo (9.1 solo cubre los candidatos de la tabla y no todos los archivos) | (1) Tamaño sin descargar: `curl -sIL <url> \| grep -i content-length`. (2) Huella: `curl -L -o <archivo> <url>` y `sha256sum <archivo>` (en PowerShell: `curl.exe` y `Get-FileHash <archivo> -Algorithm SHA256`). (3) Contenido: `tar -tjvf <archivo> \| grep -v espeak-ng-data/`. (4) Licencia: `tar -xjO -f <archivo> <carpeta>/MODEL_CARD` (Piper) o `<carpeta>/LICENSE` (Kokoro y Kitten). (5) Abrir las direcciones de licencia que cita la tarjeta y copiar el texto literal a `docs/licencias-voces/`. (6) Hashear **cada archivo que se vaya a bajar** (no solo el comprimido), con revisión fija. (7) Llenar el catálogo (4.2.1) sin ningún campo pendiente |
| **V2** | **Calidad en inglés** de cada fuente y voz | P3.3: reproducir el guion de prueba (5.4) con cada fuente y llenar la hoja de escucha. Debe hacerlo una persona que oiga; no se puede automatizar |
| **V3** | **Velocidad y peso en el Galaxy A52 y en la laptop**: RTF, tiempo hasta el primer sonido, tiempo de carga, memoria, tamaño del instalador; si `archive` descomprime en flujo; si `sherpa_onnx` carga sus bibliotecas desde `dart run` | Con el guion de prueba y *Detalles técnicos* (5.1): RTF = tiempo de síntesis ÷ duración del audio, con 1, 2 y 4 hilos, por modelo. Memoria en el A52: `adb shell dumpsys meminfo <paquete>` durante la síntesis. Instalador: `flutter build apk --split-per-abi` antes y después de agregar `sherpa_onnx` y comparar los `.apk` de `build/app/outputs/flutter-apk/`. Para `archive`: descomprimir el `.tar.bz2` de 320 MB en el A52 y mirar la memoria. Para `dart run`: ejecutar el ejemplo `dart-api-examples/tts/run-piper-lexicon.sh` del repositorio de sherpa-onnx |
| **V4** | **Qué voces en inglés trae cada aparato**, y la ruta para instalarlas | A52: *Detalles técnicos › Voces del sistema* (lista `getVoices` con `locale`, `quality`, `network_required` y `features`). Laptop: lo mismo, y en PowerShell `Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).GetInstalledVoices() \| % { $_.VoiceInfo \| Select-Object Name, Culture, Gender }` (voces SAPI 5) y `Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens' \| % PSChildName` (voces de Windows 10/11). Anotar los pasos reales para instalar una voz inglesa en cada sistema |
| **V5** | **Qué implementación de `flutter_tts` se compila en Windows** (WinRT o SAPI 5, `flutter_tts_plugin.cpp:18` y `:238`) | Compilar con `flutter build windows` y llamar `getVoices`: si las voces traen `identifier` y `gender` es la de WinRT (`flutter_tts_plugin.cpp:168`); comparar con la lista del sistema de V4 |
| **V6** | Si `network_required` de Android es fiable en Samsung y en el motor de Google | Con el A52 en modo avión, hablar con cada voz inglesa que `getVoices` marque `network_required == "0"`: debe sonar. Y con una marcada `"1"`: no debe aparecer en `voces()` |
| **V7** | **Formato del audio pregrabado**: si Windows reproduce Opus; y si `audioplayers` conserva el tono a 0.8 en Android y Windows | Generar un mismo audio de prueba con `ffmpeg -i entrada.wav -c:a libopus -b:a 24k salida.opus` y `ffmpeg -i entrada.wav -c:a aac -b:a 48k salida.m4a`; reproducir los dos en el A52 y en la laptop, a 1.0 y a 0.8, y oír si el tono cambia. Se elige el formato que reproducen las dos plataformas. Android sí decodifica Opus (9.1); Windows **[sin verificar]** |
| **V8** | **Lexicón británico** (acento de Cambridge) para los modelos de sherpa-onnx 2.0.x, y si el ejemplo oficial con `libritts_r` y `lexicon-en-us.txt` suena bien | Ejecutar `run-piper-lexicon.sh` y `run-kokoro-en-lexicon.sh` (dart-api-examples/tts); probar una voz británica con `lexicon-en-us.txt` y oír si se americaniza; revisar si el paquete `kokoro-multi-lang-v1_0` (que trae `lexicon-gb-en.txt`) sirve para las voces `bf_` y `bm_` |
| **V9** | **Español para el asistente por la vía B** | Buscar en `https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models` un lexicón de español (probé seis nombres como `lexicon-es.txt` y ninguno existe); si no hay, la vía B no sirve para el asistente y queda la fuente A |
| **V10** | Cuál de los modelos medianos **suena mejor en 0.8** | P3.3: misma hoja de escucha a 0.8 |
| **V11** | **Texto de la licencia del conjunto de datos de lessac (Blizzard 2013)** y si sus condiciones pasan a los modelos ajustados desde él; licencia del lexicón `lexicon-en-us.txt` (derivado de CMUDict y de `en_list`); licencia de los datos de entrenamiento de Kokoro | Leer `https://www.cstr.ed.ac.uk/projects/blizzard/2013/lessac_blizzard2013/license.html` y la tarjeta `hexgrad/Kokoro-82M`. **Lo decide una persona, no un agente** (el dueño o su asesor). Mientras tanto no se publica audio pregrabado hecho con esas voces |
| **V12** | **Reproducir con la pantalla bloqueada** en el A52 (modo traslado) | P3.2b: reproducir 10 minutos con la pantalla apagada y la app en segundo plano; anotar si se corta |
| **V13** | Licencia de `espeak-ng` como parte del binario de `sherpa_onnx` 1.13.x (por si se quisiera esa versión) | Leer los avisos de licencia del paquete 1.13.8 y el texto de la licencia de espeak-ng. **Lo decide una persona.** Con 2.0.x el punto no existe |
| **V14** | Si el catálogo de **modelos que acepta la API de Dart de 2.0.1** incluye Kitten con lexicón (el ejemplo citado no existe) | Probar `OfflineTtsKittenModelConfig` (existe en `tts_config.dart`) con el modelo de 27 MB |
| **V15** | Compilación de Android con `flutter_tts` y `sherpa_onnx` (Gradle, Kotlin, NDK) | `flutter build apk` en la laptop tras agregar los paquetes |
| **V16** | Si Home Assistant en el equipo dedicado puede correr un modelo (7.2) | Medir en el equipo que se compre; no hace falta mientras D6 no se decida |

## 10. Criterios de aceptación

| # | Criterio | Cómo se comprueba |
|---|---|---|
| **Interfaz y compatibilidad** | | |
| 1 | `VozSalida` (`voz.dart:38-41`) no cambia; `VozSalidaNoDisponible` y `VozSalidaFalsa` compilan sin tocarse; las pruebas de `voz_test.dart` (líneas 21-116) pasan sin modificarse | `flutter analyze` y `flutter test` sobre ese archivo |
| 2 | `MotorVoz` es una `VozSalida`: `hablar(t)` equivale a `decir(t, uso: asistente, variante: esMX)` y `detener()` para lo que suene y vacía la cola | Prueba con fuente simulada |
| 3 | **Dado un guion de dos voces** (turnos F1, M1, F1, M1), el reproductor cambia de voz en cada turno: la fuente simulada recibe cuatro peticiones en orden con las voces del motor asignadas a F1, M1, F1 y M1, distintas entre F1 y M1 | Prueba con `FuenteDeVozFalsa` |
| 4 | Con un guion de cinco voces (F1, F2, M1, M2, N) y una fuente con tres voces, `disponibilidad` la descarta con `vocesInsuficientes`, la cadena sigue con la siguiente y no se asigna una misma voz del motor a dos voces de guion | Prueba con fuentes simuladas |
| 5 | En un guion de 8 turnos, `avance` emite los turnos 0 a 7 en orden con su voz y **ningún evento contiene el texto del turno** (el `toString()` de cada evento no incluye ninguna palabra del guion) | Prueba con fuente simulada |
| 6 | `reproducir(…, velocidad: 0.8)` y `1.0` llegan a la fuente tal cual; la fuente B pasa `speed` 0.8 a cada síntesis; la fuente C a 0.8 pide al reproductor el cambio de ritmo (o usa la pieza a 0.8 si existe) | Fuentes y reproductor simulados |
| 7 | `pausar` detiene el avance sin cambiar de turno; `reanudar` sigue en el mismo turno; `parar` completa `terminada` con `parada` y libera la fuente; después se puede reproducir otro guion | Prueba con reloj simulado |
| 8 | Entre el fin de un turno y el inicio del siguiente pasa al menos `pausaEntreTurnos` (o el `pausaDespues` del turno) | Reloj simulado |
| **Reglas (D3, D5, D6, D8, D9)** | | |
| 9 | Al leer en voz alta solo llega al motor el texto de los mensajes del asistente; los mensajes locales (resultados de herramientas) y los de error **no** llegan | Ampliación de `voz_test.dart:52-81` con el motor simulado |
| 10 | **Sin conexión funciona con un modelo ya descargado, y durante la reproducción no sale ningún texto del dispositivo:** con `HttpOverrides` que falla cualquier conexión y un descargador que hace fallar la prueba si se le llama, reproducir con cada fuente simulada termina sin error | Prueba automática |
| 11 | Guardia de importaciones: ningún archivo de `app/lib/modulos/gravity/voz/`, fuera de su subcarpeta `descarga/`, importa `package:http` ni usa `HttpClient`, `Socket` o `WebSocket`; ninguno importa `nucleo/herramientas` ni `modulos/casa` | Prueba de código fuente, como `app/test/diseno/guardia_sin_colores_fijos_test.dart:20` |
| 12 | Mientras D6 sea propuesta: `UsoVoz` no tiene valor para bocinas, el motor no importa `puente_casa.dart` y `PuenteCasa.hablar` sigue recibiendo solo `MensajeBocina` (`puente_casa.dart:17-18`) | Prueba de código fuente y `app/test/modulos/casa/puente_casa_test.dart` |
| 13 | **La voz no confirma nada:** la prueba `voz_test.dart:83-105` pasa y el motor no tiene ninguna ruta hacia el registro de herramientas (criterio 11) | Prueba existente y guardia |
| 14 | El catálogo no tiene secretos: toda dirección empieza con `https://`, sin parámetros de consulta; ningún campo se llama `token`, `clave`, `key`, `secret` ni `password`; ningún valor parece una credencial | Prueba que carga `catalogo.json` |
| 15 | La descarga no envía datos de la persona: con un cliente HTTP simulado, cada petición lleva solo `Range`, `If-Range`, `Accept-Encoding` y un `User-Agent` fijo, y la dirección exacta del catálogo; sin `Authorization`, `Cookie` ni identificadores | Prueba con cliente simulado |
| 16 | Ningún `ErrorVoz`, `toString()` ni mensaje de registro contiene el texto hablado (se fuerza un fallo con un texto reconocible y se busca en lo registrado) | Prueba automática |
| **Descarga y modelos** | | |
| 17 | La pantalla muestra nombre, voces, tamaño total y licencia, y no abre ninguna conexión hasta que la persona toca *Descargar* | Prueba de widgets con descargador simulado |
| 18 | Con datos móviles y sin permiso, `descargar` lanza `SinWifi` sin abrir conexión; con `permitirDatosMoviles: true` descarga; sin red, `SinRed` | `FuenteTipoDeRedFalsa` |
| 19 | El progreso es creciente y termina en el total del catálogo | Descargador simulado |
| 20 | **Reanudar:** si el servidor simulado corta a la mitad y se vuelve a llamar a `descargar`, la petición lleva `Range: bytes=N-` con N igual a los bytes guardados y el archivo final tiene la huella correcta; lo ya guardado no se pide otra vez | Servidor simulado con `Range` |
| 21 | Un servidor que ignora `Range` y responde 200 completo hace que se reinicie el archivo, sin concatenar (huella correcta) | Servidor simulado |
| 22 | **Un modelo con huella incorrecta se rechaza y se borra:** un servidor simulado que entrega bytes distintos produce `HuellaIncorrecta`; el archivo y la carpeta de descarga ya no existen, el estado es `noDescargado` y no hay nada que cargar | Servidor simulado |
| 23 | Si se interrumpe después de bajar algunos archivos y antes de verificar todos, el estado nunca es `instalado` y el modelo no se carga | Sistema de archivos con corte inyectado |
| 24 | Con un sistema de archivos que falla con disco lleno, se obtiene `SinEspacio`, sin carpeta a medias y con el estado anterior | Sistema de archivos con fallo inyectado |
| 25 | **Borrar un modelo libera el espacio y la fuente cae a la siguiente:** tras `borrar`, `bytesOcupados` baja en el tamaño del modelo, `disponibilidad` ya no incluye B y la siguiente reproducción usa la fuente que sigue; si el modelo sonaba, se para antes de borrar | Prueba con fuentes y gestor simulados |
| 26 | Si al arrancar existe la marca de carga de un modelo, queda `corrupto` hasta que se reintente o se borre | Archivo marcador en carpeta temporal |
| 27 | El catálogo es válido: cada entrada tiene sha256 de 64 hexadecimales, `bytes` mayor que cero, licencia con atribución, fuente, revisión fija y fecha; ningún nombre de archivo lleva `/`, `\` ni `..`; no hay valores pendientes | Prueba que carga `catalogo.json` |
| **Audio pregrabado** | | |
| 28 | **El audio pregrabado caduca si cambia el guion:** con una pieza cuyo `huella_guion` difiere de la `huella` del guion compilado, `disponibilidad` descarta C con `audioCaducado` y `reproducir` usa la siguiente fuente; la unidad muestra *audio desactualizado* | Manifiesto simulado |
| 29 | Cada pieza se verifica contra el sha256 del manifiesto al instalarse; una pieza alterada se borra y se pide una sola vez más | Servidor simulado |
| 30 | En una pieza pregrabada, `Avance.turno` cambia exactamente en los límites `inicio_ms` y `fin_ms` del manifiesto | `ReproductorDeAudioFalso` con reloj |
| 31 | Descargar, verificar y borrar el paquete de un escalón no toca los de otro; sin el paquete, la cadena pasa a B o A | Gestor simulado |
| **Elección y concurrencia** | | |
| 32 | La cadena por omisión del curso es C, B, A y la del asistente, A, B; una fuente preferida pasa al frente y las demás siguen en el mismo orden; *Solo esta fuente* quita el respaldo | Prueba de la cadena |
| 33 | Sin ninguna fuente, `reproducir` lanza `SinFuenteDisponible` con el motivo de cada una; la pantalla muestra el mensaje de 5.5 con sus acciones; la Ubicación no se ofrece | Prueba de widgets |
| 34 | Con `soloFuente: modelo` y B no disponible, `reproducir` lanza `SinFuenteDisponible` y no usa otra; `Reproduccion.fuente` dice la usada | Fuentes simuladas |
| 35 | Una voz con `local == false` (Android: `network_required == "1"`) no aparece en `voces()` ni se asigna nunca | Fuente A simulada con voces de red |
| 36 | Dos personas en el mismo equipo tienen preferencias distintas y la cuenta Casa, las suyas; cambiar de persona cambia la voz sin reiniciar | Prueba de preferencias |
| 37 | *Probar* reproduce la misma frase con cada fuente disponible, una a la vez, y muestra qué fuente y qué voz sonó | Prueba de widgets |
| 38 | Una sola voz a la vez: iniciar el curso mientras habla el asistente detiene al asistente; una respuesta del asistente mientras suena el curso no la interrumpe; al empezar el dictado el motor se detiene; el interruptor de leer en voz alta solo aparece si `disponibilidad(UsoVoz.asistente)` lo permite | Prueba con fuentes simuladas y de widgets |
| **En el dispositivo (las hace el dueño, P3.3)** | | |
| 39 | **Sin conexión (modo avión) y con un modelo ya descargado**, el guion de prueba (6 turnos, 2 voces) se reproduce completo en el Galaxy A52, con voces distintas para F1 y M1, a 1.0 y a 0.8 | Manual |
| 40 | Lo mismo en la laptop con Windows | Manual |
| 41 | Con Wi-Fi activo, el contador de bytes de la app no cambia durante una reproducción con cada fuente (A52: `adb shell dumpsys netstats`, antes y después) | Manual |
| 42 | Para cada modelo se anotan el RTF y el tiempo hasta el primer sonido en el A52 y en la laptop; solo se ofrece para tiempo real donde el RTF medido es menor que 1.0 con el mismo número de hilos; si no, solo sirve para pregrabar | Manual, con *Detalles técnicos* |
| 43 | En un equipo sin voz en inglés la pantalla dice cómo instalarla (Android y Windows) y la Ubicación no se ofrece | Manual |
| 44 | El formato de audio pregrabado elegido se reproduce en el A52 y en la laptop; a 0.8 no se oye un cambio de tono, o existe la pieza a 0.8 | Manual |
| 45 | El dueño oye la misma frase con las tres vías, llena la hoja de escucha y la cadena por omisión queda como él la decidió | Manual (P3.3) |

## 11. Pruebas

### 11.1 Automatizables con fuentes simuladas

Siguen el patrón del repositorio (`VozSalidaFalsa`, `PuenteCasaFalso`, `FuenteConectividadFalsa`): las versiones falsas viven junto al código y se inyectan con Riverpod.

| Doble de prueba | Qué hace | Criterios |
|---|---|---|
| `FuenteDeVozFalsa` | Guarda las peticiones (voz, texto, velocidad); duración de cada turno configurable; puede fallar a mitad; puede declarar pocas voces o voces de red | 2 a 10, 16, 25, 32 a 38 |
| `ReproductorDeAudioFalso` | Reproduce "en el reloj simulado" una duración dada; guarda la velocidad | 6, 7, 30 |
| `DescargadorFalso` | Servidor simulado con `Range`, `ETag`, cortes a la mitad, bytes alterados y respuesta 200 completa; registra las cabeceras | 15, 17 a 22, 29 |
| `SistemaDeArchivosFalso` o carpeta temporal con fallos inyectados | Disco lleno y corte entre archivos | 23, 24, 26 |
| `FuenteTipoDeRedFalsa` | Wi-Fi, datos móviles, sin red | 18 |
| `HttpOverrides` que falla | Garantiza que reproducir no abre conexiones | 10 |
| Reloj simulado (`fake_async` de `testWidgets`) | Pausas y turnos | 7, 8, 30 |
| Guardia de código fuente | Lee los archivos de `voz/` | 11, 12, 13 |
| `catalogo.json` y manifiestos de prueba | Validan el catálogo y la caducidad | 14, 27, 28, 31 |

Comandos (de `CLAUDE.md`): `cd app && flutter analyze && flutter test`. Flutter y Dart están en `/home/user/tools/flutter/bin`. Cada criterio de 1 a 38 debe tener al menos una prueba, y cada una de las comprobaciones de descarga, un caso malo.

### 11.2 En dispositivo (las hace el dueño)

Criterios 39 a 45, con el Galaxy A52 y la laptop Windows, **en cuanto exista P3.2a-1 y P3.2a-2 y antes de producir muchos guiones** (plan, paquete P3.3). Se registran en `docs/revisiones/` (lo escribe calidad con lo que el dueño anote en la hoja de escucha).

### 11.3 Lo que ninguna prueba cubre

La calidad de la voz (solo se oye), la licencia de cada voz (la decide una persona) y el comportamiento con la pantalla bloqueada (P3.2b).

## 12. Paquetes de trabajo que siguen

| Paquete | Qué | Agente y carpetas | Depende de |
|---|---|---|---|
| **P3.0b** *(propuesta nueva)* Verificar candidatas y escribir el catálogo | Ejecutar V1 en 9.2 para las voces que se elijan y escribir `catalogo.json` sin pendientes y los textos de licencias | **asistente**, en una sesión con acceso a los *releases* de GitHub y a las páginas de licencia (esta no alcanzó estas últimas): `app/assets/voces/catalogo.json`, `docs/licencias-voces/` | Preguntas 4 y 6 |
| **P3.1** Especificación del reproductor del curso | Reproducciones y velocidades, guion oculto, pausa entre turnos, modo examen, frases para repetir, tarjetas en audio, fuente congelada y registrada (6) | **habitos** (redacta) y **plataforma** (revisa): `docs/specs/fase-8-habitos-reproductor-curso.md` (el nombre sigue el patrón `docs/specs/fase-8-habitos-*` de 11.2) | Esta especificación |
| **P3.2a-1** Interfaz, fuentes simuladas y fuente A | `MotorVoz`, tipos, `Asignador`, `FuenteDeVozFalsa`, fuente A con `flutter_tts`, cadena y preferencias; Ajustes › Voz sin B ni C; `FuenteTipoDeRed`; interruptor del panel; reproductor del curso con fuente simulada | **asistente**: `app/lib/modulos/gravity/voz/` *(carpeta nueva)* y `app/test/modulos/gravity/voz/`; **plataforma**: `app/pubspec.yaml`, `AndroidManifest.xml` (`<queries>`), `app/lib/nucleo/conectividad/`, `app/lib/modulos/ajustes/voz/`; **habitos**: `app/lib/modulos/habitos/` (bloque de escucha); **el arquitecto** decide quién escribe en `app/lib/modulos/gravity/conversacion/` (3.5, punto 5) | Aprobación de `flutter_tts` y del reproductor (pregunta 1) |
| **P3.2a-2** Gestor de modelos y fuente B | Catálogo, `GestorDeModelos`, descarga con huella y reanudación, `sherpa_onnx` en un `Isolate`, marca de carga, Ajustes › Voz › Voces descargables | **asistente**: `voz/modelos/`, `voz/descarga/`, `voz/fuentes/modelo/`; **plataforma**: `app/pubspec.yaml`, Ajustes | P3.0b y aprobación de `sherpa_onnx` (y `archive` si aplica) |
| **P3.2a-3** Fuente C y generador | Fuente pregrabada, paquetes por escalón (el primero que hace falta es el de **A2.1**, D-ING-7), caducidad por huella; orden `audio` y `huella_guion` en `compilar` | **asistente**: `voz/fuentes/pregrabado/`; **habitos**: `herramientas/ingles/` y la ampliación de `docs/specs/fase-8-ingles-formato.md` (su sección 13 deja fuera el audio grabado) | P3.2a-2, P1.2c (`compilar`) y preguntas 4 y 5 |
| **P3.2b** Repetición, traslado y grabación | Repetir frases, traslado con pantalla bloqueada, grabación local; evaluar `record`, `audio_service` y `audio_session` | **habitos** y **plataforma** | P3.1 y P3.2a-1 |
| **P3.3** Prueba en el teléfono | El dueño compara las tres vías con el guion de prueba y elige de oído (5.4, criterios 39 a 45) | **dueño**; **calidad** registra el resultado en `docs/revisiones/` | P3.2a-1 y P3.2a-2 |
| **Cierre** | Revisión de privacidad (R1 a R10) y de la guardia de red | **calidad**: `docs/revisiones/` | Todo lo anterior |

**Lo que se pide a otras áreas** (porque aquí no se resuelve):

- **arquitecto:** agregar a la fila del agente asistente en 11.2 las carpetas `app/lib/modulos/gravity/voz/` y `app/assets/voces/` y decidir quién escribe en `conversacion/`; registrar las aprobaciones de paquetes (sección 8) en el control de cambios del roadmap; decidir si P3.0b entra al plan.
- **habitos:** (1) si P3.1 quiere velocidades por contrato, un campo en los contratos; (2) `compilar` escribe `huella_guion` (4.3.3); (3) ampliar el formato, que hoy deja fuera el audio grabado (sección 13) y la comprobación V26; (4) decidir si las tarjetas en audio dicen la traducción (pregunta 12).
- **plataforma:** paquetes y permisos de la sección 8, `<queries>`, `FuenteTipoDeRed`, carpeta de datos por plataforma (4.2.2, punto 3), registro del recurso `app/assets/voces/`.
- **casa:** solo si el dueño elige la alternativa de 7.2.

## 13. Riesgos y preguntas para el dueño

### 13.1 Riesgos

| Riesgo | Efecto | Cómo se controla |
|---|---|---|
| **`sherpa_onnx` 2.0 retiró `espeak-ng`** (4.2.5) | Los paquetes de modelo originales no funcionan solos; el inglés británico y el español con Piper pueden no tener camino | Verificar V8 y V9; el español del asistente queda en la fuente A; el inglés americano tiene el ejemplo oficial con lexicón |
| **Los modelos grandes son lentos** (Kokoro: RTF mayor que 2.7 en la Pi 4B incluso con 4 hilos) y pesan de 147 a 320 MB | No sirven para tiempo real en el teléfono | Piper o Kitten para tiempo real; Kokoro para pregrabar en la laptop; el RTF propio decide (criterio 42) |
| **Licencias de las voces**: CC BY pide atribución; CC BY-NC-SA es no comercial; la mayoría de las voces Piper vienen ajustadas desde *lessac*, cuya licencia no se leyó; el lexicón y los datos de Kokoro, tampoco | Un audio o una voz que no se puede publicar | Catálogo con licencia por voz, pantalla de licencias, V11 lo decide una persona, audio pregrabado solo con licencia clara |
| **Un archivo nativo malicioso o dañado** (ONNX leído por código nativo) | Falla del proceso o algo peor | Huella obligatoria, carpeta privada, solo archivos del catálogo, marca de carga (4.2.2, 4.2.3) |
| **Alojamiento de terceros**: los *releases* pueden reemplazarse, limitarse o retirarse; las direcciones firmadas caducan | Descarga rota o con huella distinta | Revisión fija y huella en el catálogo; reanudar por la dirección del catálogo; copia propia (pregunta 4) |
| **Pocas voces en el dispositivo** (A) | F1 y F2 suenan igual | No se repiten voces sin avisar; B y C como respaldo; diagnóstico en *Detalles técnicos* |
| **Con la pantalla bloqueada** el sonido puede cortarse (traslado) | El traslado no sirve manos libres | P3.2b: servicio en primer plano; V12 |
| **El instalador crece**: 27 MB sin comprimir en arm64 y 22 MB en Windows solo por las bibliotecas | APK más pesado | Medir (V3); `--split-per-abi` |
| **Calidad percibida**: ninguna fuente alcanza al oído del dueño | El curso suena mal | La decisión es de oído (P3.3); si ninguna alcanza, se vuelve a pedir una decisión al dueño (por ejemplo, audio grabado por una persona), que esta especificación no cubre |
| **Evaluaciones desiguales**: una prueba con voz mala y otra con voz buena | Resultados no comparables | Fuente congelada y registrada (6.2) |
| **Acento británico** en simulacros de Cambridge | Se oye americano | V8; aviso y registro (6.2) |
| **Espacio**: B y C pueden sumar cientos de MB | El teléfono se llena | Tamaño a la vista, borrar y recuperar (4.2.2); pregunta 10 |
| **Eco del dictado** si el motor sigue hablando | La app "se oye a sí misma" | Criterio 38: el dictado detiene al motor |
| **El formato Opus puede no reproducirse en Windows** | Piezas mudas | V7; AAC como alternativa |
| **Dos implementaciones de `flutter_tts` en Windows** (V5) | Lista de voces distinta de la esperada | Verificar en la laptop |
| **Compilación** (Gradle, Kotlin, NDK) al agregar paquetes nativos | P3.2a-1 se atasca | V15 |

### 13.2 Preguntas para el dueño

| # | Pregunta | Recomendación |
|---|---|---|
| 1 | ¿Apruebas los paquetes de la sección 8? `flutter_tts` 4.2.5, `sherpa_onnx` 2.0.1 y `audioplayers` 6.8.1; y `archive` 4.6.0 solo si los modelos se quedan en `.tar.bz2` | Sí a los tres primeros. `archive` no hace falta con el camino 1 de 4.2.1 |
| 2 | **D6, bocinas:** ¿dejas el texto a voz de Home Assistant, pasas al audio del motor local (7.2) o lo mezclas según quién sea el puente? Esta decisión es tuya dentro de D6 y no se toma aquí | Sin recomendación mientras D6 siga en propuesta |
| 3 | ¿Quieres que el asistente lea sus respuestas en voz alta cuando exista el motor? El bloque 4 dijo que no en esa fase (`fase-8-reportes-imagen-voz.md:25`). ¿Y que el interruptor se recuerde entre sesiones, o sigue apagado en cada sesión? | Sí, y que siga apagado por sesión como hoy |
| 4 | ¿Dónde se alojan los modelos y los paquetes de audio: el sitio original (releases de GitHub), una copia propia (por ejemplo Supabase Storage, dentro del 1 GB de D7 compartido con las fotos) u otro? | Copia propia con revisión fija y huella |
| 5 | ¿Aceptas instalar en la laptop una herramienta de codificación de audio (ffmpeg u otra) para generar el audio pregrabado? No entra al repositorio ni a la app | Sí |
| 6 | **Licencias:** ¿aceptas voces con atribución obligatoria (CC BY), mostrando la atribución en Ajustes? ¿Excluimos las de uso no comercial (CC BY-NC-SA) y las ajustadas desde *lessac* hasta que alguien lea su licencia? ¿Cambia algo que el uso sea familiar y sin fines de lucro? | Sí a CC BY; excluir las otras mientras no se lea la licencia |
| 7 | Si la vía B no tiene voz en español (V9), ¿basta la voz del dispositivo para el asistente? | Sí |
| 8 | ¿Las descargas con datos móviles: nunca, o con confirmación cada vez? | Con confirmación cada vez |
| 9 | ¿Los simulacros y las puertas de Cambridge exigen voces británicas (aunque haya que pregrabar con un modelo grande)? ¿Y americanas en TOEFL y TOEIC? | Sí; si falta el acento, avisar y registrarlo |
| 10 | ¿Hay un tope de espacio para voces y audio en el teléfono? | Sin tope; tamaño siempre a la vista |
| 11 | ¿Cuándo haces la prueba de oído en el A52 y en la laptop (P3.3)? Necesita P3.2a-1 y P3.2a-2 | En cuanto existan |
| 12 | ¿Las tarjetas en audio dicen también la traducción al español? (pide una voz en español en el curso) | Que lo decida habitos en P3.1 |

## 14. Estado de la ejecución

### 14.1 P3.2a-1 (22/nov/2026): hecho en lo técnico, sin probar en un aparato

Aprobación del dueño: `flutter_tts` 4.2.5, `sherpa_onnx` 2.0.1 y `audioplayers` 6.8.1, con versión exacta (`docs/ROADMAP.md`, control de cambios 3.0). **En este paquete solo entró `flutter_tts` 4.2.5**; `sherpa_onnx` y `audioplayers` entran en P3.2a-2. `pub get` con Flutter 3.47.9 y Dart 3.13.7 resolvió sin cambiar ninguna otra dependencia (el `pubspec.lock` solo ganó `flutter_tts`; `windows/flutter/generated_plugin_registrant.cc` y `generated_plugins.cmake` registran el plugin).

| Pieza | Dónde |
|---|---|
| Tipos, errores e interfaz `MotorVoz implements VozSalida` (`VozSalida` no cambió) | `app/lib/modulos/gravity/voz/tipos.dart`, `motor.dart` |
| `Asignador` por género y `resolverAsignacion` (lo elegido por la persona + la propuesta, sin repetir voces) | `voz/asignador.dart` |
| Reproducción turno por turno (pausa entre turnos, pausar, reanudar, parar) | `voz/reproduccion_por_turnos.dart` |
| `FuenteDeVozFalsa` y `PuertoTtsFalso` (pruebas sin plugin) | `voz/fuente_falsa.dart`, `voz/fuentes/dispositivo/puerto_tts.dart` |
| **Fuente A:** voz del dispositivo con `flutter_tts` | `voz/fuentes/dispositivo/fuente_dispositivo.dart` y `puerto_tts.dart` (la única puerta al plugin) |
| Cadena de fuentes (5.3) y motor | `voz/motor.dart` (`cadenaPorOmision`, `cadenaDe`, `MotorDeVoz`) |
| Preferencias por persona (5.2) en `shared_preferences` | `voz/preferencias.dart`; se abren en `app/lib/app/arranque.dart` |
| Proveedores (`motorVozProvider`, `fuentesDeVozProvider`) | `voz/proveedores.dart` |
| `FuenteTipoDeRed` (con `connectivity_plus`; sin quien la use hasta P3.2a-2) | `app/lib/nucleo/conectividad/tipo_de_red.dart` y `tipo_de_red_plus.dart` |
| Panel de conversación: interruptor «Leer las respuestas en voz alta» según la **salida** de voz y dictado que calla al motor (criterio 38) | `app/lib/modulos/gravity/conversacion/panel_conversacion.dart` |
| Ajustes › Voz real (estado, voz y velocidad del asistente, voces del curso por acento, probar, detalles técnicos; B y C como «próximamente») | `app/lib/modulos/ajustes/voz/` |
| Android 11 o más: `<queries>` con `TTS_SERVICE` | `app/android/app/src/main/AndroidManifest.xml` |

**Lectura en voz alta del asistente (pregunta 3, aún sin respuesta del dueño).** Se implementó la recomendación: el asistente lee sus respuestas **solo si la persona enciende el interruptor**, y el interruptor está **apagado en cada sesión** (no se recuerda). Lo lee con la voz del dispositivo, en español, a la velocidad que la persona fijó en Ajustes. Nunca lee lo dicho por la persona, los resultados locales («En tu pantalla») ni los errores (criterio 9). **Es una lectura de esta especificación, no una decisión confirmada:** si el dueño responde otra cosa, el cambio es el valor por omisión de `leerEnVozAltaProvider` y un campo en las preferencias.

**Cómo llega el motor al panel.** `vozSalidaProvider` conserva su valor por omisión (`VozSalidaNoDisponible`), así las pruebas y los equipos sin voz no cambian. El arranque lo sustituye por el motor (`arranque.dart`). Una variante equivalente a 3.5, punto 2, sin dependencia circular entre `voz.dart` y la carpeta `voz/`.

### 14.2 Diferencias con las firmas de la sección 3 (todas son agregados)

- `Motivo.sinMotorDeVoz`: el equipo no tiene motor de texto a voz o no responde (4.1, falla 1). Distinto de `sinVozEnElIdioma`.
- `VozMotor` lleva además `locale` y `calidad` (para ordenar y para Detalles técnicos).
- `Variante` y `VozDeGuion` llevan `etiqueta`, `nombre` (y `idioma` en `Variante`); `Fuente` lleva `nombre`.
- `Asignador.proponer` acepta `roles` (solo asigna los papeles que usa el guion). Una voz con género conocido nunca ocupa el lugar del otro género.
- `MotorVoz` agrega `asignacion`, `diagnostico` y `refrescar`; `FuenteConDiagnostico` es la interfaz que lo hace posible. `VozDelSistema` es la voz tal como la reporta el sistema.
- `Guion.vocesUsadas` y `Capacidades.ajustarVelocidad`.
- Los errores del gestor de descargas (`SinWifi`, `SinRed`, `SinEspacio`, `HuellaIncorrecta`, `DescargaInterrumpida`) **no están**: llegan con P3.2a-2. Lo mismo `EstadoModelo`, `ProgresoDescarga`, `GestorDeModelos` y `ReproductorDeAudio`.
- `Avance.posicion` en la fuente A es el tiempo transcurrido, no la posición en el audio; `duracion` es `null`.
- **Pausa (4.1, límites conocidos):** en lugar del truco de Android que repite desde la última palabra, **pausar corta el turno que suena y reanudar lo repite desde el principio**. Es lo único que se puede garantizar igual en Android y en Windows sin un aparato a la mano. La pantalla todavía no tiene botón de pausa (solo Parar).
- **Tono:** la fuente A declara que el plugin lo admite (`Capacidades.tono`), pero esta versión no lo usa ni lo ofrece en Ajustes.
- **Fuente preferida y «Solo esta fuente»:** el motor y las preferencias ya lo manejan (criterio 32), pero Ajustes no lo ofrece mientras haya una sola fuente real.
- **Probar:** usa `soloFuente: dispositivo` para que suene lo que la pantalla muestra, no un respaldo. La Hoja de escucha y el guion de prueba de 5.4 son de P3.3; aquí hay un diálogo de prueba de dos voces y seis turnos con líneas propias (no es contenido del curso).

### 14.3 Lo que se leyó en `flutter_tts` 4.2.5 y condiciona el diseño

Resuelve en parte V5 (sin ejecutar nada; es lectura del código):

- **Windows compila la rama de WinRT** (`SpeechSynthesizer`): `flutter_tts_plugin.cpp:18` la elige con `WINAPI_FAMILY == WINAPI_FAMILY_DESKTOP_APP`, que es el valor de una aplicación de escritorio. Esa rama da `gender` e `identifier` en cada voz y emite los avisos de inicio, fin, pausa, continuar y cancelado. **Sin verificar compilando en la laptop** (V5 sigue abierto, pero ahora hay una hipótesis).
- **Windows exige `nuget.exe` en el PATH para compilar.** `windows/CMakeLists.txt` hace `find_program(NUGET_EXE)` y un `FATAL_ERROR` si no lo halla, y descarga `Microsoft.Windows.CppWinRT` 2.0.210503.1 de nuget.org al compilar. Es un requisito nuevo para la laptop del dueño (no entra al repositorio ni a la app).
- **Windows: `stop()` sin nada sonando puede cerrar la app.** Con `awaitSpeakCompletion(true)`, `stop()` responde 1 al `speak` pendiente sin comprobar que exista. Por eso `PuertoTtsFlutter` solo llama a `stop` si hay un turno en curso, y marca como interrumpido lo que cortó, sin fiarse de que el plugin conteste 1 al cortar (en Windows, un `speak` cortado responde 1, igual que uno terminado).
- **Windows: `getSpeechRateValidRange` no existe** (`NotImplemented`): la puerta usa valores por omisión (mínimo 0, normal 0.5, máximo 1.5). En las dos plataformas 0.5 del plugin es la velocidad normal; el motor traduce el factor (1.0 normal) multiplicando por 0.5 y lo acota a 0.5 a 1.5.
- **Android: si hay un error, `speak` no completa.** Solo avisa por `setErrorHandler`. La puerta toma como resultado la primera señal que llegue (fin, cancelado, error o el `Future` de `speak`).
- **Android: `speak` responde 0** cuando lo cortan y cuando ya había algo sonando. Tras un corte propio, la puerta espera (hasta 250 ms) el aviso de cancelado antes de hablar de nuevo, para que ese aviso no corte el turno siguiente.
- Android devuelve `getVoices` nulo si el servicio de voz no está listo: la puerta lo trata como «sin motor de voz». El género casi nunca viene; las voces de Google lo traen en el nombre (`en-us-x-sfg#female_1-local`) y se usa solo como pista para el `Asignador`.
- `minSdk` del plugin: 24, igual que el de Flutter 3.47.

### 14.4 Pruebas

Las nuevas están en `app/test/modulos/gravity/voz/` (asignador, motor, fuente A con puerta simulada, puerta real contra un canal simulado, preferencias, guardia de código fuente, panel), `app/test/modulos/ajustes/voz/pantalla_voz_test.dart` y `app/test/nucleo/conectividad/tipo_de_red_test.dart`. Cubren los criterios 1 a 10, 12, 13 y 16, 32 a 36 y 38 (11 con la guardia de código); los criterios 14, 15 y 17 a 31 son de la descarga y del audio pregrabado (P3.2a-2 y P3.2a-3); 37 se cubre con «Probar» de Ajustes de la fuente A (la prueba con las tres fuentes es de P3.2a-3). Los criterios 39 a 45 son del dueño (14.5).

### 14.5 Para probar en dispositivo

**Galaxy A52 (Android).**
1. En la laptop: `cd app && flutter build apk` (V15: nunca se compiló Android con `flutter_tts`). Instalar el APK.
2. Ajustes › Voz. Anotar lo que dice «Voz del dispositivo»: cuántas voces en español y en inglés y cuántas «se dejaron fuera por necesitar conexión». Abrir «Detalles técnicos» y fotografiarlo (V4 y V6). Comparar con Ajustes del sistema › «Salida de texto a voz».
3. Modo avión y Wi-Fi apagado. «Probar» la voz de GRAVITY: debe sonar (V6). Si una voz que la pantalla ofrece **no** suena sin conexión, anotar su nombre exacto (el dato `network_required` no sería fiable en ese motor).
4. Velocidad: probar 0.5, 1.0 y 1.5. Debe oírse más lenta y más rápida, sin cortes.
5. «Parar» a media frase: debe callar en menos de un segundo; pulsar «Probar» enseguida: debe sonar de nuevo (prueba el corte y el aviso de cancelado de la puerta).
6. Curso de inglés (solo con una sesión que use Hábitos): «Probar» F1, M1, N en inglés americano y británico, y el «Diálogo de prueba»: ¿F1 y M1 suenan distintas? Anotar las filas que dicen «Sin otra voz distinta».
7. Conversación: encender «Leer las respuestas en voz alta»; hacer una pregunta; debe leerse solo la respuesta de GRAVITY (no lo que aparece como «En tu pantalla»). Tocar el micrófono mientras habla: debe callar **antes** de escuchar y el dictado no debe captar la voz de la app (criterio 38).
8. Cerrar la app y volver a abrirla: el interruptor debe estar apagado. La voz y la velocidad elegidas deben seguir.
9. Con el interruptor apagado no debe hablarse nada (ni siquiera con voz).
10. Criterio 41 (red): con Wi-Fi, `adb shell dumpsys netstats` antes y después de varias respuestas leídas: los bytes de la app no deben cambiar por la voz.
11. Criterio 43: desactivar o desinstalar las voces en inglés del sistema, abrir Ajustes › Voz: debe decir cómo instalar una. Anotar los pasos reales de ese teléfono.

**Laptop con Windows.**
1. Requisito: `nuget.exe` en el PATH y conexión durante la primera compilación (14.3). `flutter run -d windows`. Si la compilación falla en `flutter_tts`, anotar el mensaje: puede faltar nuget o el SDK de Windows.
2. Ajustes › Voz › «Detalles técnicos»: ¿trae las voces del sistema con sus idiomas? Para V5: la rama de WinRT da el género de cada voz; si los detalles muestran las voces pero el asistente o el curso dicen que no hay voces en inglés, anotar la lista (Windows: Configuración › Hora e idioma › Voz para agregar voces; luego «Actualizar la lista de voces» sin reiniciar la app, y si no aparecen, reiniciarla).
3. «Probar» y «Parar» a media frase **varias veces seguidas**: la app **no debe cerrarse** (riesgo conocido del plugin al cortar). Anotar cualquier cierre.
4. Velocidad 0.5, 1.0 y 1.5.
5. Conversación: lo mismo que en el teléfono, sin el micrófono (el dictado solo existe en Android).

### 14.6 Pendiente y no hecho

- **P3.2a-1:** el bloque de escucha de `app/lib/modulos/habitos/` (reproductor del curso con la fuente simulada) **no se hizo**: es de habitos y depende de P3.1 (`docs/specs/fase-8-habitos-reproductor-curso.md`), que no existe. Los guiones del curso ya se pueden reproducir con `MotorVoz.reproducir`.
- Voz de las bocinas (D6): no se tocó.
- Tono, botón de pausa, fuente preferida y «Solo esta fuente» en la pantalla: no hay nada que elegir mientras la fuente A sea la única.
- Descarga de voces, `sherpa_onnx`, `audioplayers`, audio pregrabado (P3.2a-2 y P3.2a-3) y todo el catálogo (P3.0b).
- Lo que ningún equipo de pruebas del repositorio verifica: que las voces del A52 y de la laptop suenen y se enumeren como se espera; la latencia; que TalkBack lea el interruptor y el control de velocidad (la prueba de widgets solo comprueba la etiqueta y el texto de valor); Windows completo.

### 14.7 Preguntas abiertas para el dueño

1. **Pregunta 3 (lectura en voz alta):** se implementó la recomendación (solo si la persona enciende el interruptor, apagado en cada sesión). ¿Se queda así?
2. En Windows, ¿aceptas instalar `nuget.exe` en la laptop para compilar (14.3)?
3. La pausa repite el turno desde el principio (14.2). Para el curso (turnos de hasta 50 palabras) ¿basta, o quieres probar primero en el A52 el truco de Android que retoma desde la última palabra?



### 14.6 Respuestas del dueño a las preguntas de 14.5 (22/nov/2026)

1. **Lectura en voz alta:** si la persona decide encenderla, **queda encendida en todas las sesiones** (por persona; en la tablet cambia con la persona en pantalla). Apagada por omisión. Hecho: `PreferenciasVoz.leerRespuestas`, guardada con el resto de las preferencias de voz. Sigue leyendo solo la respuesta de GRAVITY (D3, D6).
2. **`nuget.exe` en la laptop:** aceptado. Pendiente del dueño: instalarlo y ponerlo en el PATH antes de compilar para Windows.
3. **Pausa:** el dueño pide **probar** retomar desde la palabra que sonaba. Hecho: la puerta a `flutter_tts` pasa el inicio de la palabra que avisa el plugin (`setProgressHandler`) y la fuente A reanuda desde ahí; si la plataforma no avisa (Windows, según la lectura del plugin) el turno se repite desde el principio. **Falta probar en el A52** (paso 5 de «Para probar en dispositivo»: pausar a media frase y reanudar; ¿retoma desde la palabra, repite o salta?). Si en el aparato se comporta mal, se vuelve a repetir el turno completo cambiando una sola función en `fuente_dispositivo.dart`. La pantalla todavía no tiene botón de pausa.

### 14.7 P3.0b: verificación de licencias y huellas (22/nov/2026)

Hecho: tamaño y sha256 de las 11 candidatas (`.tar.bz2` completos y cada archivo útil, sin `espeak-ng-data`) y de `lexicon-en-us.txt`; tarjetas y licencias leídas y copiadas literales. Resultados y veredictos en `docs/licencias-voces/README.md`; huellas en `docs/licencias-voces/verificadas.json`. Cierra la parte de licencias de V1 y V11 **en lo que se pudo leer**; no se escribió `catalogo.json` (faltan alojamiento, `sid`, `uso` y `rtf`, regla 1 de 4.2.1).

Hallazgos que cambian el plan:
- **Lessac (Blizzard 2013) es licencia de investigación**: excluye el uso comercial en productos de síntesis de voz y prohíbe distribuir los materiales. `libritts_r` y `vctk` salen de ahí. Si pasa a los pesos es una pregunta jurídica que decide una persona.
- **Solo las voces de dominio público (kristin, john, norman, cori) tienen licencia limpia**: tres en inglés americano y una británica; sin F2 ni acento británico real (cori necesita un lexicón que no existe, V8).
- **Kokoro** es Apache-2.0 pero se entrenó en parte con datos CC BY (atribución) y con audio sintético de modelos cerrados; **Kitten** es Apache-2.0 sin datos de entrenamiento documentados.
- Los modelos de Piper usan fonemas `espeak`; con `sherpa_onnx` 2.0.x necesitan lexicón y el único es el americano (`lexicon-en-us.txt`, cuyo origen `en_list` no pude leer).
- No pude leer librivox.org, la página del autor, `davefx`, `en_list` ni `espeak-ng`.

Decisiones que necesita el dueño: preguntas 4 (alojamiento) y 6 (licencias), ahora con estas lecturas.

Respuestas del dueño (22/nov/2026): **pregunta 6** (aceptar atribución, Kokoro v1_1 con atribución, dominio público de respaldo, lessac excluido) y **pregunta 4** (copia propia con revisión fija y huella). Prueba con `sherpa_onnx` 2.0.1 (detalle en `docs/licencias-voces/README.md`): las voces Piper con `lexicon-en-us.txt` funcionan sin espeak y rápido; `kokoro-int8-multi-lang-v1_1` funciona pero **salta en silencio las palabras que no están en su lexicón** (`lived`, `wanted`, `opened`…) y es más lento que el habla en un x86 de 4 núcleos (solo sirve para pregrabar); `kokoro-en-v0_19` no funciona sin espeak y se descarta. `supabase/scripts/verificar-voces.sh` comprueba las huellas ya alojadas.

### 14.8 P3.2a-2 (22/nov/2026): gestor de modelos y fuente B, hecho en lo técnico, sin probar en un aparato

Paquetes (aprobados, ROADMAP control de cambios 3.0, versión exacta): `sherpa_onnx` 2.0.1 y `audioplayers` 6.8.1. **`archive` no se agregó** (camino 1 de 4.2.1: archivos sueltos, nada se descomprime). `audioplayers` sí hizo falta aquí, no solo en la fuente C: la fuente B sintetiza muestras y la única forma aprobada de oírlas es escribir cada frase como WAV temporal y reproducirlo (sin él, B no sonaría). Va detrás de `ReproductorDeAudio` y solo `voz/audio/reproductor_audioplayers.dart` lo importa. `pub get` (Flutter 3.47.9, Dart 3.13.7) solo agregó paquetes: `sherpa_onnx` y sus 9 de plataforma, `audioplayers` y sus 6; `windows/flutter/generated_plugin_registrant.cc` y `generated_plugins.cmake` registran los dos plugins.

| Pieza | Dónde |
|---|---|
| Catálogo real (cuatro voces Piper de dominio público: `kristin` mujer, `john` y `norman` hombres en-US, `cori` mujer en-GB «acento aproximado») | `app/assets/voces/catalogo.json` (registrado en `pubspec.yaml`); huellas copiadas de `docs/licencias-voces/verificadas.json` |
| `ModeloDelCatalogo` y tipos, lector y **validador** (criterios 14 y 27), `EstadoModelo`, `ProgresoDescarga`, `formatearBytes` | `voz/modelos/` |
| Gestor: interfaz, implementación en disco, falso; puerta HTTP (real con `dart:io`, falsa con `Range`/`ETag`/cortes); disco con fallos inyectables; sha256 en un `Isolate` | `voz/descarga/` |
| Errores tipados `SinWifi`, `SinRed`, `SinEspacio`, `HuellaIncorrecta`, `DescargaInterrumpida`, `NoDisponibleAun` (sin texto ni direcciones) | `voz/tipos.dart` (la jerarquía `ErrorVoz` es `sealed`) |
| Fuente B (`FuenteModelo`), puerta de síntesis (interfaz, falsa y real en un `Isolate`), partir en frases | `voz/fuentes/modelo/` |
| Reproductor de audio (interfaz, falso, `audioplayers`) y WAV | `voz/audio/` |
| Cadena del motor (B entra: curso C, B, A; asistente A, B), «solo esta fuente» y `vocesElegidas` para «Probar» una voz concreta | `voz/motor.dart`, `voz/fuente_de_voz.dart`, `voz/proveedores.dart` |
| Ajustes › Voz › Voces descargables (con «Probar» cada voz y un «Diálogo de prueba (2 voces)» con las voces descargadas) | `app/lib/modulos/ajustes/voz/voces_descargables.dart` (+ `pantalla_voz.dart`, `prueba_voz.dart`) |
| El arranque lee y valida el catálogo y usa `FuenteTipoDeRedPlus` | `app/lib/app/arranque.dart` |

**Desviaciones y decisiones de esta fase**

1. **Catálogo (regla 1 de 4.2.1).** `uso` y `rtf` son **opcionales** hasta P3.3 (salen de medir en el aparato); si están, se validan. `licencia.permite_distribuir_audio` también es opcional: **ausente = nadie lo decidió = el modelo no se usa para pregrabar** (regla 4); lo decide una persona (pregunta 3 de 14.8.5). Todas las voces son de un solo `sid` (0). `asignacion_sugerida` guarda `sid`. `fuente.original` guarda la dirección y la huella del `.tar.bz2` de origen (trazabilidad). Cada modelo lista **tres archivos**: el `.onnx`, `tokens.txt` y `lexicon-en-us.txt`; sin `espeak-ng-data`, sin `MODEL_CARD` ni `.onnx.json`. **Kokoro v1_1 no está en el catálogo de la app** (solo servirá para pregrabar, P3.2a-3; su limitación, que salta en silencio palabras fuera de su lexicón como `lived` o `wanted`, queda documentada en `docs/licencias-voces/README.md` y no se resuelve aquí).
2. **Peso real.** Cada voz pesa 69.5 a 69.8 MB (63.5 MB el modelo más 6.3 MB el lexicón), **70 MB en pantalla**, no 63 MB. El lexicón se baja **una vez por modelo** (carpeta propia): descargar las tres voces americanas baja el mismo lexicón tres veces (19 MB repetidos). Se dejó así por simplicidad y por seguir `<id_modelo>/<archivo>`; la alternativa (un lexicón compartido) cambia el catálogo y el gestor.
3. **Cori.** `kristin`, `john` y `norman` son en-US; `cori` es en-GB pero con `sherpa_onnx` 2.0.x solo existe el lexicón americano (V8): suena más americana de lo que debería. Va **marcada «acento aproximado»** en su nombre (`Cori (acento aproximado)`), en la pantalla y al final de la lista de voces; **la fuente B la ofrece para `Variante.enGB`**, así que un simulacro de Cambridge puede usarla (pregunta 4 de 14.8.5).
4. **Aviso y permiso de red.** El aviso (tamaño, «necesitas Wi-Fi», licencia, «el sitio verá la dirección de internet de este equipo») está siempre en la tarjeta; el botón dice *Descargar (70 MB)*. Un toque basta con Wi-Fi o Ethernet. Con datos móviles aparece un diálogo **cada vez** («No estás en Wi-Fi. La descarga usará X de tus datos.») y el permiso vale solo para esa descarga; una red de la que no se sabe si cuesta datos (VPN, Bluetooth) se trata como datos móviles. El gestor lo vuelve a exigir por dentro (`SinWifi`), así que ningún otro camino descarga sin permiso. Sin red solo se avisa.
5. **Espacio libre antes de empezar.** Con los paquetes aprobados no hay forma portátil de medirlo: `SistemaDeArchivos.bytesLibres` existe, la implementación real devuelve `null` y el gestor se apoya en el error de disco lleno del sistema (28, 122, 39 y 112), que borra la descarga a medias y deja el estado anterior. Si el sistema de archivos supiera medirlo, el gestor avisa antes de abrir ninguna conexión (probado con un disco falso). `SinEspacio.bytesNecesarios` es lo que falta liberar si se sabe y, si no, lo que faltaba bajar.
6. **404 y parecidas.** `NoDisponibleAun` (el alojamiento todavía no tiene el archivo) se lanza con 404 **y también con 400, 403 y 410**, porque Supabase Storage suele contestar 400 (con `"statusCode":"404"` en el cuerpo) cuando el objeto o el bucket no existen en una dirección pública. **Es una suposición no verificada** (no se hizo ninguna petición a Supabase); si en la prueba real el comportamiento es otro, se cambia la lista `_codigosDeNoDisponible` de `gestor_en_disco.dart`. Un 5xx es `DescargaInterrumpida`. La pantalla muestra «No disponible aún», sin culpa y sin prometer fecha.
7. **Reanudar.** Se usa `If-Range` con el `ETag` guardado en `estado.json`; **sin `ETag` se empieza de nuevo** (no hay forma de saber si el archivo cambió). Un archivo ya verificado en una descarga anterior no se vuelve a pedir ni a calcular al reanudar (se confía en la marca y el tamaño); el botón *Comprobar* sí recalcula todas las huellas. Si el servidor dice que el archivo pesa otra cosa que el catálogo, se rechaza **antes** de bajarlo (`HuellaIncorrecta`). Cancelar no es un error: el flujo termina y lo bajado se conserva.
8. **`GestorDeModelos` tiene más que la sección 3.2:** `seguir` (una pantalla que se abre después ve la descarga en curso), `bytesDescargados`, `bytesOcupadosPor`, `comprobar`, `reintentar`, `rutasParaCargar`, `iniciarCarga`/`terminarCarga`/`marcarCorrupto` y `antesDeBorrar`. `borrar` devuelve los bytes liberados («Liberaste 70 MB»).
9. **Síntesis.** Por frase (`partirEnFrases`: no corta en `Mr.`, `a.m.`, iniciales ni `3.5`); la siguiente se genera mientras suena la anterior. **No se interrumpe una frase a media síntesis** (no se usa `onProgress`): parar o pausar corta el audio al instante, y la que se estaba generando termina en el `Isolate` y se descarta (o se reutiliza si se reanuda). Hilos de cómputo: 2 (se mide en P3.3). El `Isolate` mantiene a lo sumo dos modelos cargados (un diálogo de dos voces de dos modelos no recarga en cada turno) y suelta el más viejo.
10. **Pausa.** Pausar corta la frase que suena; reanudar **repite esa frase desde el principio** (lo ya sintetizado no se vuelve a pedir; las anteriores no se repiten). Es la misma limitación honesta que la fuente A en Windows.
11. **Marca de carga y prueba de humo.** La primera carga de cada modelo en la sesión escribe `cargando-<id>`, carga, sintetiza `Hello.` (el paquete devuelve audio vacío cuando falla), y borra la marca. Si la carga o la prueba fallan de forma atrapable, el modelo queda `corrupto`. **Si falla el entorno** (`biblioteca_no_disponible`, `isolate_no_arranco`, `isolate_perdido`, `tiempo_agotado`) **el modelo NO se marca dañado**: no es culpa suya. Recargar un modelo que el `Isolate` soltó no vuelve a poner la marca.
12. **Motor.** `MotorVoz.reproducir` tiene un parámetro nuevo opcional, `vocesElegidas` (qué voz suena como cada voz de guion, sin guardarlo): es lo que usa «Probar» una voz concreta. `FuenteConMotivoSinVoces` hace que una fuente B sin modelo diga `modeloNoInstalado` («no está descargada») y no `sinVozEnElIdioma`; para el español (sin modelo en el catálogo) sigue diciendo que no hay voz en ese idioma.
13. **Borrar** para antes la voz que sonaba (si usa ese modelo), suelta el modelo del `Isolate` y borra la carpeta y la descarga a medias; pide confirmación y dice cuánto libera. La fuente B deja de ofrecer sus voces y la cadena cae a la siguiente (criterio 25).
14. **Carpetas.** Android `getApplicationSupportDirectory()/voces/modelos/<id>`; Windows `getApplicationCacheDirectory()/voces/modelos/<id>` (4.2.2, punto 3). Los WAV temporales van a `getTemporaryDirectory()/gravity-voz` y se vacían al arrancar.
15. **Lo que Ajustes todavía no hace con B:** la sección «Curso de inglés» sigue listando solo las voces de la voz del dispositivo; **no se elige a mano qué voz de B suena como F1, M1, etc.** (el motor las asigna por género cuando la cadena usa B). Con las voces de dominio público hay mujer (F1), dos hombres (M1, M2) y, en británico, una mujer: **un guion con F2 o con N no se puede decir con B** (`vocesInsuficientes`) y cae a la fuente A.

**Pruebas nuevas** (`flutter test` en `app/`, sin tocar internet):

| Archivo | Qué cubre |
|---|---|
| `test/modulos/gravity/voz/modelos/catalogo_test.dart` | Criterios 14 y 27 (cada regla con su caso malo); el catálogo REAL pasa el validador, coincide archivo por archivo (nombre, bytes, sha256) con `verificadas.json`, no trae lessac, espeak ni Kokoro, cita textos de licencia que existen |
| `test/modulos/gravity/voz/descarga/gestor_en_disco_test.dart` | Criterios 15 y 17 a 26 (más 16): Wi-Fi, datos móviles, sin red, progreso, reanudar, servidor que ignora `Range`, huella mala, interrupción entre archivos, 404, disco lleno (códigos 28, 112, 39, 122), cancelar, borrar, marca de carga, modelo dañado, catálogo que cambia |
| `test/modulos/gravity/voz/descarga/puerta_http_test.dart` | La puerta HTTP real contra un servidor en 127.0.0.1: cabeceras en el cable, redirecciones, tiempo sin datos |
| `test/modulos/gravity/voz/fuentes/fuente_modelo_test.dart` | Criterios 3 a 7, 10, 16, 25, 26, 32 y 34 con la fuente B y el motor, con puerta de síntesis, reproductor, gestor y disco simulados |
| `test/modulos/gravity/voz/fuentes/frases_wav_test.dart` | Partir en frases y WAV |
| `test/modulos/gravity/voz/fuentes/puerta_sherpa_real_test.dart` | **Con la biblioteca nativa real** (solo corre si se le da un modelo; ver su encabezado): carga, sintetiza a 22 050 Hz, 0.8 dura más, libera y los fallos dicen códigos |
| `test/modulos/ajustes/voz/voces_descargables_test.dart` | Criterios 17 y 18 en pantalla, mensajes de 5.5, «No disponible aún», «Probar» con B, accesibilidad y letra al doble |
| `test/modulos/gravity/voz/guardia_voz_test.dart` | Nuevas guardias: solo `puerta_de_descarga.dart` abre conexiones; `sherpa_onnx` y `audioplayers` solo en su archivo; la fuente B y el catálogo no usan `dart:io` ni recorren carpetas (R10) |

Comandos y resultado: `cd app && flutter analyze` (solo quedan los 7 hallazgos antiguos de Alimentación, Finanzas y `f4_alimentacion_test`) y `flutter test test/app test/modulos test/nucleo test/diseno test/revision_calidad`: **3 703 pasan y 16 se omiten** (las 14 de antes más las 2 de la prueba con la biblioteca nativa real, que solo corren si se les da un modelo). La prueba con la biblioteca real se corrió además a mano en Linux x64: `LD_LIBRARY_PATH=~/.pub-cache/hosted/pub.dev/sherpa_onnx_linux-2.0.1/linux/x64 GRAVITY_VOZ_MODELO_DIR=<kristin> GRAVITY_VOZ_LEXICON=<lexicon-en-us.txt> flutter test test/modulos/gravity/voz/fuentes/puerta_sherpa_real_test.dart` (2 pasan).

Criterios de la sección 10 cubiertos por pruebas automáticas en este paquete: 14, 15, 17 a 26 y 27 (más 3 a 7, 10, 16, 25, 32 y 34 con la fuente B). **Siguen para P3.2a-3:** 28 a 31 (audio pregrabado) y la prueba de «Probar» con las tres fuentes (37). **Siguen para el dueño en el aparato:** 39 a 45.

**Hallazgos**

- **`sherpa_onnx` 2.0.1 corre de verdad con Piper + lexicón en la laptop de desarrollo** (Linux x64, no es el A52 ni Windows): el `Isolate` arranca, `initBindings()` carga la biblioteca, el modelo `kristin` con `lexicon-en-us.txt` carga sin `espeak-ng`, sintetiza a 22 050 Hz, a 0.8 el audio dura más y `free()` lo suelta (`puerta_sherpa_real_test.dart`). Dos cosas: (1) `flutter test` no encuentra la biblioteca nativa por sí solo (hay que darle `LD_LIBRARY_PATH` a `sherpa_onnx_linux/linux/x64`; dentro de la app la empaqueta el plugin); (2) cuando un modelo no carga, **la biblioteca nativa escribe en `stderr` la ruta del modelo** (no el texto): no pasa por nuestros errores ni registros.
- **Errores propios que las pruebas atraparon (ya corregidos):** `whenComplete(() => mapa.remove(...))` devuelve el propio futuro y se espera a sí mismo (llevaba la primera carga a un bloqueo); `await subscription.cancel()` no completa con el reloj simulado de las pruebas de widgets (se hace sin `await`); `DateTime.tryParse('2026-13-45')` **acepta** el mes 13 (el validador del catálogo comprueba la fecha por su cuenta); un `return` dentro del `try` de la descarga se saltaba el aviso de final cuando el modelo ya estaba instalado.
- **Peso de las bibliotecas nativas (Android arm64):** `jniLibs/arm64-v8a` de `sherpa_onnx_android_arm64` 2.0.1 pesa 26 MB en disco (el spec decía 27 176 800 bytes); el efecto en el APK se mide al compilar (V3).
- **Compilación de Android (V15), sin verificar:** `sherpa_onnx_android_*` 2.0.1 declara en su propio `build.gradle` el plugin de Android 7.3.0 y `compileSdk 34`, y `audioplayers_android` 5.3.0 pide `compileSdk 36`; la app usa el plugin de Android 9.1.1 y Kotlin 2.4.0. No hay SDK de Android aquí: **no se compiló el APK**. Si falla, el mensaje de Gradle dice cuál.
- **Windows (V15), sin verificar:** no se compiló. `sherpa_onnx_windows` empaqueta `sherpa-onnx-c-api.dll` y `onnxruntime.dll`; `audioplayers_windows` 4.4.1 usa Media Foundation (reproduce WAV PCM). Sigue valiendo el requisito de `nuget.exe` del 14.3.

**Para probar en dispositivo (P3.3 y antes)**

*Antes de nada (el dueño):* crear el bucket público `voces` en Supabase Storage y subir, en `2026-11-22/<id_modelo>/`, los tres archivos de cada voz (`<modelo>.onnx`, `tokens.txt` y `lexicon-en-us.txt`) de `kristin`, `john`, `norman` y `cori` (ids `vits-piper-en_US-kristin-medium`, `vits-piper-en_US-john-medium`, `vits-piper-en_US-norman-medium`, `vits-piper-en_GB-cori-medium`). `supabase/scripts/verificar-voces.sh <url_base> <ids…>` comprueba las huellas, **pero no el lexicón** (lee solo `archivos`): hay que comprobar `lexicon-en-us.txt` a mano (`sha256sum`, debe dar `8b67ae54…ef73a`, 6 305 773 bytes). Mientras no estén subidos, la pantalla debe decir «No disponible aún» al tocar Descargar (probar eso también).

**Galaxy A52.**
1. `cd app && flutter build apk` (V15: nunca se compiló Android con `sherpa_onnx` ni `audioplayers`). Anotar el tamaño del APK con `--split-per-abi` frente al de antes (V3). Instalar.
2. Ajustes › Voz › Voces descargables: cuatro tarjetas con 70 MB, licencia y atribución (abrir «Licencia y atribución»). Con Wi-Fi tocar *Descargar* en **Kristin**: porcentaje y MB crecen; *Cancelar* a la mitad y *Reanudar*: debe continuar desde donde iba (probar también cortar el Wi-Fi a media descarga: «No hay conexión…» y reanudar).
3. Con datos móviles (Wi-Fi apagado): aparece el diálogo con el tamaño; «Esperar al Wi-Fi» no descarga nada. Sin ninguna red: «No hay conexión».
4. Al terminar: *Instalada*. *Probar*: debe sonar la frase en inglés. Anotar el tiempo hasta el primer sonido, si hay cortes entre frases (cada frase es un archivo; un silencio notable entre ellas es el riesgo conocido), y si la voz se entiende. Probar a velocidad 0.8 y 1.0 desde el curso (cuando exista el reproductor, P3.1) o con «Probar» de las voces del dispositivo.
5. Modo avión con el modelo ya descargado: *Probar* debe sonar (criterio 39).
6. *Borrar* mientras suena una prueba: debe callar, decir «Liberaste 70 MB» y *No descargada*. *Comprobar* en una voz instalada: «Todo en orden».
7. Matar la app **mientras carga** una voz por primera vez (justo después de tocar *Probar*): al volver a abrirla, esa voz debe decir *Dañada* con *Reintentar* (criterio 26); *Reintentar* la deja lista.
8. Descargar **Kristin y John** (o Norman) y, al pie de la tarjeta Voces descargables, tocar **«Diálogo de prueba (2 voces)»** (seis turnos, F1 y M1; criterio 39): debe decir «Suena con: Voz descargada · F1: Kristin · M1: John», con las dos voces distintas y sin cortes raros entre frases. A 0.8 y 1.0 se prueba cuando exista el reproductor del curso (P3.1); hoy el diálogo suena a velocidad normal. (La tarjeta «Curso de inglés» sigue probando solo la voz del dispositivo.)
9. Memoria y velocidad: `adb shell dumpsys meminfo <paquete>` durante la síntesis con una y con dos voces cargadas; RTF = tiempo de síntesis ÷ duración del audio con 1, 2 y 4 hilos (hoy fijo en 2): V3 y criterio 42.

**Laptop con Windows.** Lo mismo con *Probar*. Además: que el instalador de Windows incluya `sherpa-onnx-c-api.dll` y `onnxruntime.dll` junto al ejecutable; que `audioplayers` reproduzca el WAV; y que la carpeta de los modelos esté en `%LOCALAPPDATA%` (no en `Roaming`).

**Pendiente y no hecho en este paquete**
- Elegir a mano qué voz de B suena como cada papel, y mostrar en el curso cuál fuente sonó (la pantalla del curso es de Hábitos, P3.1).
- Audio pregrabado (fuente C), generador y `paquetes_audio` (P3.2a-3). Kokoro v1_1 en el catálogo para pregrabar.
- Mediciones de `uso` y `rtf` (P3.3), y la decisión de hilos.
- Interrumpir una síntesis a media frase (`onProgress`) y retomar una pausa a media frase.
- Un lexicón compartido entre modelos; lexicón británico (V8) y español (V9).
- Probar en un aparato: nada de lo de este paquete se oyó ni se compiló para Android o Windows.

#### 14.8.5 Preguntas abiertas para el dueño

1. **Subir los archivos al alojamiento** (ver «Antes de nada»): 4 carpetas, 12 archivos. Hasta entonces la app dice «No disponible aún».
2. **`en_list` (lexicón).** El origen y la licencia de la parte `en_list` de `lexicon-en-us.txt` siguen **sin verificar** y quedan **pendientes de la decisión de una persona** (V11). La atribución en pantalla de cada voz lo dice. ¿Quién lo decide y cuándo?
3. **Audio pregrabado con estas voces.** `permite_distribuir_audio` está ausente en las cuatro: ¿una persona confirma que el dominio público declarado por el autor basta para publicar audio hecho con ellas (necesario para la fuente C)?
4. **Cori, acento aproximado.** Hoy se ofrece para el acento británico con la etiqueta «acento aproximado». ¿Se oculta para los simulacros de Cambridge (que exigen acento británico, pregunta 9) hasta tener un lexicón británico, o se deja con el aviso?
5. **Papeles que faltan.** Con kristin, john y norman un diálogo con F2 o N no se puede decir con B. ¿Se completan con Kokoro v1_1 (más voces, pero 180 MB y solo para pregrabar) o se acepta que esos guiones usen la voz del dispositivo?
6. **Lexicón repetido.** ¿Vale pagar 6.3 MB extra por cada voz americana para que cada modelo sea autónomo, o se pasa a un lexicón compartido (menos espacio, más cambio)?
7. **Supabase.** ¿Confirmas que un archivo inexistente en el bucket público contesta 400 o 404? (La app trata 400, 403, 404 y 410 como «no disponible aún».)


**Decisión del dueño (22/nov/2026): licencia de `en_list`.** Opción 1: se acepta el riesgo y se registra. `lexicon-en-us.txt` (CMUDict + `en_list` + compounds) se sigue usando y alojando; la atribución en pantalla conserva el aviso de CMUDict y dice que el origen de `en_list` no se verificó. Motivo: uso familiar y sin fines de lucro. Se revisa si el uso deja de ser familiar. **Grabar la voz de quien estudia (P3.2b):** el dueño no sabe si hace falta; recomendación del arquitecto en el informe de esa fecha: no hacerlo ahora (las tareas de habla del curso se evalúan con lista de cotejo y modelo, sin calificar el audio; 6.3), y reabrirlo solo si el dueño quiere oírse y comparar.
