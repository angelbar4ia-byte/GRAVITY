# finanzas_dominio

Lógica pura del módulo **Finanzas** de GRAVITY (Dart sin Flutter). La usan la app (laptop y teléfono) y las pruebas; no depende de la base de datos ni de la interfaz.

Base: diseño de FINANZAS v23 (`docs/modulos/finanzas/ESTRUCTURA_APP_PRESUPUESTO_SEMANAL.md`) y la especificación `docs/specs/fase-1-finanzas.md`.

| Archivo | Qué resuelve | Diseño |
|---|---|---|
| `dinero.dart` | Centavos y reglas de redondeo R1 (al centavo, medios lejos de cero) y R2 (suma exacta y reparto por mayor resto) | Convenciones |
| `fecha.dart`, `semana.dart` | Fecha sin hora, semana de lunes a domingo, número ISO, periodos (catorcena, quincena, mes) | 5.6 bis, punto 2 |
| `frecuencia.dart` | Equivalentes semanales exactos por frecuencia | 4 |
| `calendario.dart` | Días hábiles, festivos oficiales (LFT art. 74) inyectables y fechas de pago | 5.1; decisiones 44 y 55 |
| `flujo.dart` | Saldo día a día con peor caso y flujo por semana | 4; 5.1 bis, punto 9 |
| `libro.dart` | Libro solo-agregar con partida doble simplificada, anulación por contraasiento, confirmaciones, saldos, balance, estado de resultados y conciliación | 5.0 bis; 5.0 bis 2; 5.0 ter |
| `presupuesto.dart`, `indicadores.dart` | Plan semanal, cascada, sobregasto, arrastre, recortes y semáforos | 5.6 bis; decisiones 45, 46 y 49 |
| `proyeccion_deuda.dart` | Proyección ilustrativa de salida de deuda | 5.6 bis, punto 5 |
| `libros.dart` | Libros personal, compartido y representado; permisos por libro (espejo de `fin_puede`, el suplente escribe solo sin albacea) y vista de un libro con las aportaciones entre libros | D19; 4.5 |
| `libro.dart` (cuadre) | `Balance` con aportaciones recibidas y entregadas: `patrimonio = inicial + resultado + ajustes + recibidas − entregadas` | D19; reglas 47 y 48 |
| `configuracion.dart` | Ingresos con vigencias, compromisos, sobres y deudas (grupo prioritario); calendarios con la regla de día inhábil por origen | 5.1; reglas 52 a 54 |
| `categorias.dart`, `plan_guardado.dart`, `seguimiento.dart`, `datos_finanzas.dart` | Árbol e importador de la hoja Categorías; foto del plan y del cierre (versión = reaperturas + 1); vista de la semana; todo lo visible del hogar | 5.2, 5.6 bis, 5.9 bis |

## Pruebas

```bash
cd paquetes/finanzas_dominio
dart pub get
dart analyze
dart test
```

Las pruebas reproducen los ejemplos numéricos del diseño (hogar de Ana y Alex, ejemplo contable de 5.0 bis 2, calendario de flujo de 5.1 bis). Los datos son ilustrativos, nunca reales.
