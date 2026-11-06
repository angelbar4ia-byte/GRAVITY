import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

void main() {
  const prefs = PreferenciasAviso();

  test('criticas del catalogo (regla 33)', () {
    final criticas = TipoAlerta.values.where((t) => t.esCritica).map((t) => t.clave);
    expect(
      criticas.toSet(),
      {'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo',
       'flujo_negativo', 'abono_bajo_minimo', 'base_90'},
    );
    expect(TipoAlerta.partida80.nivel, NivelAlerta.informativa);
    expect(TipoAlerta.resumenLunes.fija, isTrue);
  });

  test('vencimiento: avisos 3 y 1 dias antes a las 9:00', () {
    final m = momentosDeVencimiento(DateTime(2026, 11, 10), prefs);
    expect(m, [DateTime(2026, 11, 7, 9), DateTime(2026, 11, 9, 9)]);
    final pasado = momentosDeVencimiento(
      DateTime(2026, 11, 10), prefs, ahora: DateTime(2026, 11, 8),
    );
    expect(pasado, [DateTime(2026, 11, 9, 9)]);
  });

  test('pago vencido: dia siguiente y a los 3 dias', () {
    expect(momentosDePagoVencido(DateTime(2026, 11, 10), prefs),
        [DateTime(2026, 11, 11, 9), DateTime(2026, 11, 13, 9)]);
  });

  test('criterio 37: critica a las 23:00 sale a las 07:00', () {
    final t = DateTime(2026, 11, 9, 23);
    expect(salidaDeAviso(t, NivelAlerta.critica, prefs), DateTime(2026, 11, 10, 7));
    expect(
      salidaDeAviso(t, NivelAlerta.critica, const PreferenciasAviso(criticasEnSilencio: true)),
      t,
    );
    expect(
      salidaDeAviso(t, NivelAlerta.informativa, const PreferenciasAviso(criticasEnSilencio: true)),
      DateTime(2026, 11, 10, 7),
    );
    expect(salidaDeAviso(DateTime(2026, 11, 9, 5), NivelAlerta.importante, prefs),
        DateTime(2026, 11, 9, 7));
    expect(salidaDeAviso(DateTime(2026, 11, 9, 12), NivelAlerta.critica, prefs),
        DateTime(2026, 11, 9, 12));
  });

  test('tope diario de 3 no criticos; criticas sin tope; agrupado', () {
    AvisoPlan a(String k, TipoAlerta t, int h) =>
        AvisoPlan(k, t, DateTime(2026, 11, 9, h));
    final plan = planearDia([
      a('1', TipoAlerta.partida80, 8),
      a('2', TipoAlerta.usoLimite, 9),
      a('3', TipoAlerta.partida100, 10),
      a('4', TipoAlerta.fondoBajo, 11),
      a('5', TipoAlerta.pagoProximo, 12),
      a('6', TipoAlerta.pagoVencido, 13),
    ], prefs);
    expect(plan.individuales.map((x) => x.clave), ['1', '2', '3', '5', '6']);
    expect(plan.agrupados.map((x) => x.clave), ['4']);
  });

  test('tipo silenciado va solo a bandeja, tambien la critica', () {
    final plan = planearDia([
      AvisoPlan('1', TipoAlerta.pagoProximo, DateTime(2026, 11, 9, 9)),
    ], const PreferenciasAviso(tiposSilenciados: {'pago_proximo'}));
    expect(plan.individuales, isEmpty);
    expect(plan.soloBandeja, hasLength(1));
  });

  test('posponer 1 hora o hasta manana', () {
    final n = DateTime(2026, 11, 9, 15, 30);
    expect(posponer(n, hastaManana: false), DateTime(2026, 11, 9, 16, 30));
    expect(posponer(n, hastaManana: true), DateTime(2026, 11, 10, 9));
  });

  test('criterio 47: rangos invalidos se rechazan', () {
    expect(prefs.validar(), isNull);
    expect(const PreferenciasAviso(topeDiario: 11).validar(), isNotNull);
    expect(const PreferenciasAviso(diasAntes: [1, 2, 3, 4]).validar(), isNotNull);
    expect(const PreferenciasAviso(diasAntes: [15]).validar(), isNotNull);
    expect(const PreferenciasAviso(silencioDesde: 7, silencioHasta: 7).validar(), isNotNull);
  });

  test('criterio 41: destinatarios por libro, nunca la maestra', () {
    bool r(LibroDestino l, RolDestino x, {bool alb = true}) =>
        recibeAvisoDeLibro(libro: l, rol: x, hayAlbaceaVigente: alb);
    expect(r(LibroDestino.personal, RolDestino.titular), isTrue);
    expect(r(LibroDestino.personal, RolDestino.miembro), isFalse);
    expect(r(LibroDestino.compartido, RolDestino.miembro), isTrue);
    expect(r(LibroDestino.compartido, RolDestino.titular), isTrue);
    expect(r(LibroDestino.representado, RolDestino.albacea), isTrue);
    expect(r(LibroDestino.representado, RolDestino.suplente), isFalse);
    expect(r(LibroDestino.representado, RolDestino.suplente, alb: false), isTrue);
    for (final l in LibroDestino.values) {
      expect(r(l, RolDestino.cuentaMaestra), isFalse);
      expect(r(l, RolDestino.otro), isFalse);
    }
  });
}
