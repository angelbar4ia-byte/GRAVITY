// Copia a api/swagger/swagger-ui/ los archivos de swagger-ui-dist que usa la página
// local (versión fija en package.json), con su licencia y su aviso (Apache-2.0).
//
// Uso (desde api/): npm install && npm run swagger

import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = dirname(fileURLToPath(import.meta.url));
const origen = join(raiz, 'node_modules', 'swagger-ui-dist');
const destino = join(raiz, 'swagger', 'swagger-ui');

const ARCHIVOS = [
  'swagger-ui-bundle.js',
  'swagger-ui-bundle.js.LICENSE.txt',
  'swagger-ui.css',
  'favicon-32x32.png',
  'LICENSE',
  'NOTICE',
];

const paquete = JSON.parse(readFileSync(join(origen, 'package.json'), 'utf8'));
mkdirSync(destino, { recursive: true });
for (const archivo of ARCHIVOS) copyFileSync(join(origen, archivo), join(destino, archivo));
writeFileSync(
  join(destino, 'VERSION'),
  `swagger-ui-dist ${paquete.version} (${paquete.license})\n` +
    'Copiado de npm con `npm run swagger` en api/. No se edita a mano.\n',
);
console.log(`swagger-ui-dist ${paquete.version} copiado a swagger/swagger-ui/.`);
