import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('CA-B-14 enlaces (solo https, tel, sms y geo)', () {
    test('se aceptan los cuatro esquemas', () {
      expect(
        validarEnlace('https://open.spotify.com/playlist/abc').esquema,
        EsquemaEnlace.https,
      );
      expect(validarEnlace('tel:+520000000000').esquema, EsquemaEnlace.tel);
      expect(
        validarEnlace('sms:+520000000000?body=hola').esquema,
        EsquemaEnlace.sms,
      );
      expect(validarEnlace('geo:0,0?q=algo').esquema, EsquemaEnlace.geo);
      expect(
        validarEnlace('  https://ejemplo.mx/x  ').enlace,
        'https://ejemplo.mx/x',
      );
    });

    test('CASO MALO: se rechazan javascript, intent, file, content, http y '
        'cualquier otro', () {
      final malos = {
        'javascript:alert(1)': 'esquema',
        'JavaScript:alert(1)': 'esquema',
        'intent://scan/#Intent;scheme=zxing;end': 'esquema',
        'file:///sdcard/x.gpx': 'esquema',
        'content://com.app/x': 'esquema',
        'http://ejemplo.mx/lista': 'sin_cifrar',
        'ftp://ejemplo.mx/x': 'esquema',
        'market://details?id=x': 'esquema',
        'data:text/html,<b>x</b>': 'esquema',
        'ejemplo.mx/sin-esquema': 'forma',
        '': 'vacio',
        'https://': 'forma',
        'https:/ejemplo.mx': 'forma',
        'tel:': 'forma',
        'https://user:clave@ejemplo.mx/x': 'credenciales',
        'https://ejemplo.mx/ con espacio': 'caracteres',
      };
      for (final e in malos.entries) {
        final r = validarEnlace(e.key);
        expect(r.valido, isFalse, reason: e.key);
        expect(r.motivo, e.value, reason: e.key);
      }
    });

    test('se puede limitar a https (música y clima)', () {
      const soloHttps = {EsquemaEnlace.https};
      expect(
        validarEnlace('tel:+520000000000', permitidos: soloHttps).motivo,
        'no_permitido',
      );
      expect(
        validarEnlace('https://ejemplo.mx/x', permitidos: soloHttps).valido,
        isTrue,
      );
    });

    test('un enlace con coordenadas es una ruta: se detecta', () {
      expect(enlaceLlevaUbicacion('geo:19.432608,-99.133209'), isTrue);
      expect(
        enlaceLlevaUbicacion('https://mapa.ejemplo/?q=19.4326,-99.1332'),
        isTrue,
      );
      expect(
        enlaceLlevaUbicacion('https://mapa.ejemplo/@19.4326,-99.1332,15z'),
        isTrue,
      );
      expect(
        enlaceLlevaUbicacion('https://open.spotify.com/playlist/abc'),
        isFalse,
      );
    });

    test('listas de música: https de 10 a 300 caracteres, orden de 1 a 20', () {
      ListaMusica lista(String enlace, {int orden = 1}) => ListaMusica(
        id: 'l',
        nombre: 'Ruta del sábado',
        actividad: ActividadMusica.bicicleta,
        app: AppMusica.spotify,
        enlace: enlace,
        orden: orden,
      );
      expect(lista('https://open.spotify.com/playlist/abc').validar(), isEmpty);
      expect(lista('http://open.spotify.com/x').validar(), isNotEmpty);
      expect(lista('https://ab').validar(), isEmpty); // 10 justo
      expect(lista('https://a').validar(), isNotEmpty); // 9 < 10
      expect(lista('https://a.mx/${'x' * 300}').validar(), isNotEmpty);
      expect(lista('tel:+520000000000').validar(), isNotEmpty);
      expect(lista('javascript:alert(1)').validar(), isNotEmpty);
      expect(lista('https://ejemplo.mx/x', orden: 21).validar(), isNotEmpty);
      expect(
        lista('https://mapa.ejemplo/?q=19.4326,-99.1332').validar(),
        isNotEmpty,
      );
      expect(lista('https://open.spotify.com/playlist/abc').aJson().keys, [
        'id',
        'nombre',
        'actividad',
        'app',
        'enlace',
        'orden',
      ]);
    });
  });
}
