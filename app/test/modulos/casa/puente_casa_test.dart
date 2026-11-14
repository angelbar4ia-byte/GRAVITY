import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/casa/puente/frases.dart';
import 'package:gravity/modulos/casa/puente/mensaje_bocina.dart';
import 'package:gravity/modulos/casa/puente/puente_casa.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Falso implements EjecutorHerramienta {
  final llamadas = <String>[];
  @override
  Future<void> ejecutar(String h, {required Rol rol, String? bocina}) async =>
      llamadas.add('$h|${rol.name}|$bocina');
}

class _Auth implements AutorizacionHomeAssistant {
  @override
  Future<Map<String, String>> cabeceras() async => {
    'Authorization': 'Bearer x',
  };
}

void main() {
  group('frases', () {
    test('frase valida con rol permitido ejecuta la herramienta', () async {
      final e = _Falso();
      final r = await TraductorFrases(e).procesar(
        const EventoFrase(
          frase: 'Siguiente paso',
          rol: Rol.casa,
          bocina: 'cocina',
        ),
      );
      expect(r, ResultadoFrase.ejecutada);
      expect(e.llamadas, ['alimentacion.receta_siguiente_paso|casa|cocina']);
    });

    test('las cinco frases aprobadas estan en la tabla', () {
      for (final t in [
        'siguiente paso',
        'paso anterior',
        'repite el paso',
        'qué cocino hoy',
        'lee la lista de compras',
      ]) {
        expect(buscarFrase(t), isNotNull, reason: t);
      }
    });

    test('rol no permitido no ejecuta (cuidador)', () async {
      final e = _Falso();
      final r = await TraductorFrases(
        e,
      ).procesar(const EventoFrase(frase: 'paso anterior', rol: Rol.cuidador));
      expect(r, ResultadoFrase.rolNoPermitido);
      expect(e.llamadas, isEmpty);
    });

    test('frase desconocida no ejecuta', () async {
      final e = _Falso();
      for (final f in ['agrega leche a la lista', 'qué toca hoy', '']) {
        expect(
          await TraductorFrases(e)
              .procesar(EventoFrase(frase: f, rol: Rol.casa)),
          ResultadoFrase.fraseDesconocida,
        );
      }
      expect(e.llamadas, isEmpty);
    });

    test('ninguna frase la usa la cuidadora', () {
      expect(frasesFijas.every((f) => !f.roles.contains(Rol.cuidador)), isTrue);
    });
  });

  group('filtro de salida', () {
    final filtro = FiltroBocina(
      nombresPropios: ['Carlos'],
      medicamentos: ['losartan'],
    );
    ResultadoFiltro v(String t) =>
        filtro.validar(TipoMensajeBocina.recordatorioGenerico, t);

    test('acepta recordatorio generico y paso de receta', () {
      expect(v('Es hora de un recordatorio de la casa').aceptado, isTrue);
      expect(
        filtro
            .validar(
              TipoMensajeBocina.pasoReceta,
              'Mezcla la harina con los huevos y sigue batiendo.',
            )
            .aceptado,
        isTrue,
      );
    });
    test('rechaza medicamento conocido o terminologia clinica', () {
      expect(v('Toca el Losartán').motivo, MotivoRechazo.contieneDatoClinico);
      expect(
        v('Toca la pastilla de la tarde').motivo,
        MotivoRechazo.contieneDatoClinico,
      );
    });
    test('rechaza montos y cifras', () {
      expect(v('Pagar 500 pesos').motivo, MotivoRechazo.contieneDinero);
      expect(v('Tienes \$20 de saldo').motivo, MotivoRechazo.contieneDinero);
      expect(v('Hornea 20 minutos').motivo, MotivoRechazo.contieneCifras);
    });
    test('rechaza nombres de personas, enlaces, vacio y largo', () {
      expect(v('Carlos ya comió').motivo, MotivoRechazo.contieneNombre);
      expect(v('Mira https://x.com').motivo, MotivoRechazo.contieneEnlace);
      expect(v('  ').motivo, MotivoRechazo.vacio);
      expect(v('a' * 300).motivo, MotivoRechazo.demasiadoLargo);
    });
  });

  group('puente', () {
    test('el falso recibe solo el texto filtrado', () async {
      final puente = PuenteCasaFalso();
      final filtro = FiltroBocina(nombresPropios: ['Carlos']);
      for (final t in [
        'Carlos toma su medicina',
        'Cuesta 30 pesos',
        'Bate la mezcla',
      ]) {
        final r = filtro.validar(TipoMensajeBocina.pasoReceta, t);
        if (r.aceptado) {
          await puente.hablar(
            bocina: 'media_player.cocina',
            mensaje: r.mensaje!,
          );
        }
      }
      expect(puente.enviados.map((e) => e.texto), ['Bate la mezcla']);
    });

    test(
      'adaptador de Home Assistant llama a tts.speak en la red local',
      () async {
        late http.Request visto;
        final c = MockClient((req) async {
          visto = req;
          return http.Response('[]', 200);
        });
        final p = PuenteHomeAssistant(
          urlBase: Uri.parse('http://homeassistant.local:8123'),
          autorizacion: _Auth(),
          cliente: c,
        );
        final m = FiltroBocina()
            .validar(TipoMensajeBocina.pasoReceta, 'Bate la mezcla')
            .mensaje!;
        await p.hablar(bocina: 'media_player.cocina', mensaje: m);
        expect(visto.url.path, '/api/services/tts/speak');
        expect(visto.body, contains('Bate la mezcla'));
        expect(visto.headers['Authorization'], 'Bearer x');
      },
    );

    test('el adaptador rechaza hosts publicos y bocinas invalidas', () {
      expect(
        () => PuenteHomeAssistant(
          urlBase: Uri.parse('https://ejemplo.com'),
          autorizacion: _Auth(),
        ),
        throwsArgumentError,
      );
      final p = PuenteHomeAssistant(
        urlBase: Uri.parse('http://192.168.1.20:8123'),
        autorizacion: _Auth(),
        cliente: MockClient((_) async => http.Response('', 200)),
      );
      final m = FiltroBocina()
          .validar(TipoMensajeBocina.pasoReceta, 'Bate')
          .mensaje!;
      expect(p.hablar(bocina: 'light.sala', mensaje: m), throwsArgumentError);
    });
  });
}
