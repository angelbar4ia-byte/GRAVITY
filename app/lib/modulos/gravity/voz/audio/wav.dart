/// Codifica muestras de audio (lo que devuelve `sherpa_onnx`) como un WAV de
/// 16 bits, mono, que cualquier reproductor entiende.
///
/// Es una elección de esta fase: `audioplayers` reproduce archivos, no
/// muestras sueltas, así que cada frase sintetizada se escribe como WAV en la
/// carpeta temporal y se borra al terminar de sonar.
library;

import 'dart:typed_data';

/// WAV PCM de 16 bits, un canal. Las muestras se acotan a [-1, 1].
Uint8List codificarWav(Float32List muestras, int frecuencia) {
  final datos = muestras.length * 2;
  final bytes = Uint8List(44 + datos);
  final v = ByteData.view(bytes.buffer);
  void texto(int pos, String t) {
    for (var i = 0; i < t.length; i++) {
      bytes[pos + i] = t.codeUnitAt(i);
    }
  }

  texto(0, 'RIFF');
  v.setUint32(4, 36 + datos, Endian.little);
  texto(8, 'WAVE');
  texto(12, 'fmt ');
  v.setUint32(16, 16, Endian.little); // tamaño del bloque fmt
  v.setUint16(20, 1, Endian.little); // PCM
  v.setUint16(22, 1, Endian.little); // mono
  v.setUint32(24, frecuencia, Endian.little);
  v.setUint32(28, frecuencia * 2, Endian.little); // bytes por segundo
  v.setUint16(32, 2, Endian.little); // bytes por muestra
  v.setUint16(34, 16, Endian.little); // bits por muestra
  texto(36, 'data');
  v.setUint32(40, datos, Endian.little);
  for (var i = 0; i < muestras.length; i++) {
    final m = muestras[i].clamp(-1.0, 1.0);
    v.setInt16(44 + i * 2, (m * 32767).round(), Endian.little);
  }
  return bytes;
}

/// Cuánto dura un audio de [muestras] muestras a [frecuencia] Hz.
Duration duracionDe(int muestras, int frecuencia) => frecuencia <= 0
    ? Duration.zero
    : Duration(microseconds: (muestras * 1000000 / frecuencia).round());
