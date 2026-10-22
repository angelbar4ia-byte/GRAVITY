import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:test/test.dart';

import 'hogar_ejemplo.dart';

void main() {
  final hoy = Fecha(2026, 10, 21);
  Libro libro(String id) => librosEjemplo.firstWhere((l) => l.id == id);

  group('Libros (D19; 4.5)', () {
    test('los libros del ejemplo cumplen las reglas', () {
      for (final l in librosEjemplo) {
        expect(() => l.validar(hoy), returnsNormally, reason: l.nombre);
      }
    });

    test('un libro personal tiene un solo miembro: su titular', () {
      final mal = Libro(
        id: 'x',
        nombre: 'X',
        tipo: TipoLibro.personal,
        titularId: ana,
        miembros: const [
          MiembroLibro(personaId: ana, papel: PapelLibro.titular),
          MiembroLibro(personaId: alex, papel: PapelLibro.miembro),
        ],
      );
      expect(() => mal.validar(hoy), throwsA(isA<ErrorLibros>()));
    });

    test('el libro de papá lleva 1 albacea y como máximo 1 suplente', () {
      Libro con(List<MiembroLibro> m) => Libro(
        id: 'p',
        nombre: 'Papá',
        tipo: TipoLibro.representado,
        titularId: papa,
        miembros: m,
      );
      expect(
        () =>
            con(const [MiembroLibro(personaId: ana, papel: PapelLibro.albacea)])
                .validar(hoy),
        returnsNormally,
      );
      expect(
        () => con(const [
          MiembroLibro(personaId: ana, papel: PapelLibro.albacea),
          MiembroLibro(personaId: alex, papel: PapelLibro.albacea),
        ]).validar(hoy),
        throwsA(isA<ErrorLibros>()),
      );
      expect(
        () => con(const [
          MiembroLibro(personaId: ana, papel: PapelLibro.albacea),
          MiembroLibro(personaId: alex, papel: PapelLibro.albaceaSuplente),
          MiembroLibro(personaId: maestra, papel: PapelLibro.albaceaSuplente),
        ]).validar(hoy),
        throwsA(isA<ErrorLibros>()),
      );
      expect(
        () => con(const [
          MiembroLibro(personaId: alex, papel: PapelLibro.albaceaSuplente),
        ]).validar(hoy),
        throwsA(isA<ErrorLibros>()),
        reason: 'sin albacea principal',
      );
    });

    test('un compartido tiene 2 o más miembros', () {
      final solo = Libro(
        id: 'c',
        nombre: 'C',
        tipo: TipoLibro.compartido,
        miembros: const [
          MiembroLibro(personaId: ana, papel: PapelLibro.miembro),
        ],
      );
      expect(() => solo.validar(hoy), throwsA(isA<ErrorLibros>()));
    });
  });

  group('Permiso por libro (fin_puede)', () {
    test('el titular hace todo en su libro personal', () {
      final p = permisoEnLibro(libro(libroAna), ana, hoy: hoy);
      expect(
        (p.leer, p.escribir, p.administrar, p.enNombreDe),
        (true, true, true, false),
      );
    });

    test('la pareja no ve el libro personal del otro (P1)', () {
      final p = permisoEnLibro(libro(libroAna), alex, hoy: hoy);
      expect(p.leer, isFalse);
      expect(p.escribir, isFalse);
    });

    test('en el compartido cualquier miembro registra y administra', () {
      for (final persona in [ana, alex]) {
        final p = permisoEnLibro(libro(casa), persona, hoy: hoy);
        expect((p.leer, p.escribir, p.administrar), (true, true, true));
      }
      expect(permisoEnLibro(libro(casa), papa, hoy: hoy).leer, isFalse);
    });

    test('el albacea registra en nombre de papá; el suplente no escribe ni '
        'administra mientras haya albacea (D17)', () {
      final albacea = permisoEnLibro(libro(libroPapa), ana, hoy: hoy);
      expect(
        (albacea.escribir, albacea.administrar, albacea.enNombreDe),
        (true, true, true),
      );
      final suplente = permisoEnLibro(libro(libroPapa), alex, hoy: hoy);
      expect(
        (suplente.leer, suplente.escribir, suplente.administrar),
        (true, false, false),
        reason: 'lee el libro, pero solo actúa sin albacea vigente',
      );
    });

    test('sin albacea vigente, el suplente administra', () {
      final sinAlbacea = Libro(
        id: 'p2',
        nombre: 'Papá',
        tipo: TipoLibro.representado,
        titularId: papa,
        miembros: [
          MiembroLibro(
            personaId: ana,
            papel: PapelLibro.albacea,
            hasta: Fecha(2026, 10, 1),
          ),
          const MiembroLibro(
            personaId: alex,
            papel: PapelLibro.albaceaSuplente,
          ),
        ],
      );
      final suplente = permisoEnLibro(sinAlbacea, alex, hoy: hoy);
      expect(
        (suplente.escribir, suplente.administrar, suplente.enNombreDe),
        (true, true, true),
      );
      expect(
        permisoEnLibro(sinAlbacea, ana, hoy: hoy).leer,
        isFalse,
        reason: 'su papel ya venció',
      );
    });

    test('la cuenta maestra lee todo y no escribe en lo ajeno', () {
      for (final l in librosEjemplo) {
        final p = permisoEnLibro(l, maestra, hoy: hoy, esMaestra: true);
        expect(
          (p.leer, p.escribir, p.administrar, p.comoMaestra),
          (true, false, false, true),
          reason: l.nombre,
        );
      }
      final propio = permisoEnLibro(
        libro(libroAna),
        ana,
        hoy: hoy,
        esMaestra: true,
      );
      expect(propio.escribir, isTrue, reason: 'en su libro sí escribe');
      expect(propio.comoMaestra, isFalse);
    });

    test('un rol sin Finanzas no ve nada aunque figure como miembro', () {
      final p = permisoEnLibro(
        libro(casa),
        ana,
        hoy: hoy,
        rolConFinanzas: false,
      );
      expect(p.leer, isFalse);
    });

    test('orden del selector: mi libro, compartidos, representado, ajenos', () {
      expect(librosVisibles(librosEjemplo, ana, hoy: hoy).map((l) => l.id), [
        libroAna,
        casa,
        libroPapa,
      ]);
      expect(librosVisibles(librosEjemplo, alex, hoy: hoy).map((l) => l.id), [
        libroAlex,
        casa,
        libroPapa,
      ]);
      expect(
        librosVisibles(
          librosEjemplo,
          maestra,
          hoy: hoy,
          esMaestra: true,
        ).length,
        4,
      );
    });
  });

  group('Vista por libro y transferencias entre libros (regla 1 de 4.5)', () {
    final transferencia = Movimiento(
      id: 'aportacion',
      tipo: TipoMovimiento.transferencia,
      fecha: Fecha(2026, 10, 20),
      registradoEn: DateTime(2026, 10, 20, 9),
      cuentaOrigenId: 'banco-ana',
      cuentaDestinoId: 'banco-casa',
      monto: 200000,
      realizadoPor: ana,
    );
    final datos = hogarEjemplo(
      movimientos: [
        transferencia,
        gasto('super-casa', Fecha(2026, 10, 20), 150000, 'g-alimentacion'),
        gasto(
          'super-ana',
          Fecha(2026, 10, 20),
          30000,
          'g-alimentacion',
          origen: 'banco-ana',
        ),
      ],
    );

    test('la aportación se ve en los dos libros y cada uno cuadra', () {
      final deAna = datos.vista(libroAna);
      final deCasa = datos.vista(casa);
      expect(deAna.movimientos.map((m) => m.id), contains('aportacion'));
      expect(deCasa.movimientos.map((m) => m.id), contains('aportacion'));
      expect(deAna.disponible(), 1000000 - 200000 - 30000);
      expect(deCasa.disponible(), 500000 + 200000 - 150000);
      expect(deAna.balance().entreLibros, -200000);
      expect(deCasa.balance().entreLibros, 200000);
      expect(deAna.balance().aportacionesEntregadas, 200000);
      expect(deCasa.balance().aportacionesRecibidas, 200000);
      expect(deAna.balance().cuadra, isTrue);
      expect(deCasa.balance().cuadra, isTrue);
    });

    test('la cuenta del otro libro aparece con el nombre del libro', () {
      final m = datos
          .vista(libroAna)
          .movimientos
          .firstWhere((m) => m.id == 'aportacion');
      expect(m.cuentaDestinoId, idCuentaOtroLibro(casa));
      expect(
        datos.vista(libroAna).cuenta(m.cuentaDestinoId).nombre,
        'Gastos de la casa',
      );
    });

    test('cada libro ve solo su gasto en la cuenta de gasto del hogar', () {
      final periodo = Periodo.semana(Fecha(2026, 10, 20));
      expect(
        datos.vista(casa).gastoPorCuenta(periodo)['g-alimentacion'],
        150000,
      );
      expect(
        datos.vista(libroAna).gastoPorCuenta(periodo)['g-alimentacion'],
        30000,
      );
    });

    test(
      'una cuenta que no se ve (de un libro ajeno) queda como "otro libro"',
      () {
        final sinAna = datos.copiar(
          cuentas: [
            for (final c in cuentasEjemplo)
              if (c.libroId != libroAna) c,
          ],
        );
        final m = sinAna
            .vista(casa)
            .movimientos
            .firstWhere((m) => m.id == 'aportacion');
        expect(esCuentaDeOtroLibro(m.cuentaOrigenId), isTrue);
        expect(sinAna.vista(casa).balance().cuadra, isTrue);
        // El libro del hogar visible también la acepta.
        expect(sinAna.libroHogar.movimientos.length, sinAna.movimientos.length);
      },
    );
  });

  group('En nombre de papá (regla 3 de 4.5)', () {
    Movimiento pago({String? motivo}) => Movimiento(
      id: 'farmacia',
      tipo: TipoMovimiento.gasto,
      fecha: Fecha(2026, 10, 20),
      registradoEn: DateTime(2026, 10, 20, 10),
      cuentaOrigenId: 'banco-papa',
      cuentaDestinoId: 'g-salud',
      monto: 45000,
      realizadoPor: papa,
      registradoPor: ana,
      enNombreDe: papa,
      motivo: motivo,
    );

    test('exige motivo', () {
      final libro = hogarEjemplo().nuevoLibroHogar();
      expect(() => libro.agregar(pago()), throwsA(isA<ErrorLibro>()));
      expect(libro.agregar(pago(motivo: 'Medicinas del mes')).enNombreDe, papa);
    });

    test('el contraasiento también va en su nombre', () {
      final libro = hogarEjemplo().nuevoLibroHogar()
        ..agregar(pago(motivo: 'Medicinas del mes'));
      final c = libro.anular(
        'farmacia',
        nuevoId: 'anula-farmacia',
        motivo: 'Se capturó dos veces',
        registradoPor: ana,
        registradoEn: DateTime(2026, 10, 20, 11),
      );
      expect(c.enNombreDe, papa);
      expect(c.registradoPor, ana);
    });
  });
}
