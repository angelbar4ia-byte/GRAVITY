// Arranque de Swagger UI para GRAVITY (D16).
// - Servida por http(s): lee ../openapi.yaml.
// - Abierta con doble clic (file://): el navegador no deja leer archivos vecinos, así que
//   usa especificacion.js, generado desde openapi.yaml con `npm run generar`.
(function () {
  'use strict';

  var desdeArchivo = window.location.protocol === 'file:';
  var origen = document.getElementById('gravity-origen');

  // Toda llamada que no sea de lectura pide confirmación antes de salir (D16, F10).
  function confirmarEscritura(peticion) {
    var metodo = String(peticion.method || 'GET').toUpperCase();
    if (peticion.loadSpec || metodo === 'GET' || metodo === 'HEAD' || metodo === 'OPTIONS') {
      return peticion;
    }
    var ok = window.confirm(
      'Esta llamada puede escribir datos:\n\n' + metodo + ' ' + peticion.url + '\n\n¿La envío?'
    );
    if (!ok) {
      throw new Error('Cancelada: no se envió nada.');
    }
    return peticion;
  }

  // Swagger UI muestra `false` y `0` como `null` en las extensiones; x-escribe: false
  // y x-fase: 0 deben verse tal cual.
  function extensionesFieles(sistema) {
    var React = sistema.React;
    return {
      components: {
        OperationExtRow: function (props) {
          var valor = props.xVal && props.xVal.toJS ? props.xVal.toJS() : props.xVal;
          return React.createElement(
            'tr',
            null,
            React.createElement('td', null, props.xKey),
            React.createElement('td', null, JSON.stringify(valor === undefined ? null : valor))
          );
        },
      },
    };
  }

  var configuracion = {
    dom_id: '#swagger-ui',
    layout: 'BaseLayout',
    presets: [SwaggerUIBundle.presets.apis],
    plugins: [extensionesFieles],
    deepLinking: true,
    docExpansion: 'list',
    defaultModelsExpandDepth: 0,
    displayOperationId: false,
    displayRequestDuration: true,
    showExtensions: true,
    showCommonExtensions: true,
    persistAuthorization: false,
    tryItOutEnabled: false,
    // Nunca se manda la especificación al validador público de swagger.io.
    validatorUrl: null,
    requestInterceptor: confirmarEscritura,
  };

  if (desdeArchivo) {
    if (!window.ESPECIFICACION_GRAVITY) {
      origen.textContent =
        'Falta especificacion.js: corre `npm run generar` en api/.';
      return;
    }
    configuracion.spec = window.ESPECIFICACION_GRAVITY;
    origen.textContent =
      'Copia generada de openapi.yaml (' + window.HUELLA_ESPECIFICACION_GRAVITY + ').';
  } else {
    configuracion.url = '../openapi.yaml';
    origen.textContent = 'Leída de ../openapi.yaml.';
  }

  window.ui = SwaggerUIBundle(configuracion);
})();
