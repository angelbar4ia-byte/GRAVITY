## Sin publicar (Fase 1)

- Libros de D19: `Libro`, `permisoEnLibro` (el suplente escribe solo sin albacea
  vigente, D17), `vistaDelLibro` y `DatosFinanzas`.
- **Cuadre por libro con aportaciones:** `Balance.aportacionesRecibidas` y
  `aportacionesEntregadas` (`LibroMovimientos.aportaciones`);
  `patrimonio = inicial + resultado + ajustes + recibidas - entregadas`. Una
  aportación entre libros no pasa por el resultado; su anulación se descuenta de
  su mismo lado.
- Solo `transferencia` y `pago_deuda` (y su anulación) cruzan de un libro a otro.
- `CalendarioConfig`: la regla de día inhábil es opcional y su valor por
  omisión depende del origen (ingreso: siguiente día hábil; compromiso y deuda:
  en su fecha). `Compromiso.reglaInhabil` y `Deuda.reglaInhabil`.
- Formas `cada_meses` (intervalo 2, bimestral) y varios días fijos al mes
  ({1, 11}) con siguiente día hábil.
- Grupo de deudas prioritarias (`DeudaPlan.grupoPrioritario`, `ordenGrupo`).
- `SemanaGuardada.reaperturas` y `versionDelSiguienteCierre` (`reaperturas + 1`);
  `fotoDelPlan` acepta `idPara` para ids estables.

## 0.1.0

- Primera versión (adelanto de la Fase 1): fecha y semana en lunes, equivalentes
  semanales, calendario de días hábiles, flujo con peor caso, libro de
  movimientos solo-agregar y motor del presupuesto semanal en cascada.
