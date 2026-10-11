//=============================================================================
// Los interruptores y las variables DEL JUEGO, con su nombre.
//
// POR QUE ESTO IMPORTA
//   Escribir "interruptor 45" a mano obliga a tener el editor de eventos abierto
//   al lado para saber cual era el 45. En RPG Maker la pestaña de condiciones de
//   un evento enseña "0045: Derrotado Gim 4" y se elige de una lista; aqui igual,
//   o esto es un paso atras respecto a la herramienta que la gente ya conoce.
//
// DE DONDE SALEN
//   ctx.data.switchNames() y ctx.data.variableNames(), que MakerStudio expone ya
//   leidos de System.rxdata.
//
//   PERO NO SE DA POR HECHO QUE ESTEN. No aparecen en el registro de cambios de
//   la API, asi que puede haber versiones del editor que no los traigan. Si
//   faltan, se cae a una lista de numeros pelados: pierdes los nombres, no la
//   funcion. Un desplegable que se queda vacio porque falta un metodo seria peor
//   que el campo de texto que habia antes.
//=============================================================================

let _interruptores = [];
let _variables = [];
let _conNombres = false;

const TOPE = 500;          // hasta donde se numeran si no hay nombres

export function configurar(ctx) {
  _interruptores = leer(ctx, "switchNames");
  _variables = leer(ctx, "variableNames");
  _conNombres = _interruptores.length > 0 || _variables.length > 0;
  return { conNombres: _conNombres, interruptores: _interruptores.length, variables: _variables.length };
}

function leer(ctx, metodo) {
  try {
    const lista = ctx?.data?.[metodo]?.();
    if (!Array.isArray(lista)) return [];
    // El indice 0 no se usa en RPG Maker, y los sin nombre se dejan fuera de la
    // parte "con nombre": se ofrecen aparte para no perderlos.
    const salida = [];
    for (let i = 1; i < lista.length; i++) {
      const nombre = String(lista[i] == null ? "" : lista[i]).trim();
      if (nombre) salida.push({ id: i, nombre });
    }
    return salida;
  } catch {
    return [];
  }
}

export function hayNombres() { return _conNombres; }

//-----------------------------------------------------------------------------
// Las opciones para un desplegable. Formato "0045: Derrotado Gim 4", igual que
// RPG Maker, que es donde la gente ya sabe leerlo.
//
// "actual" se pasa para que un numero que no tiene nombre (o que ya no existe)
// siga saliendo elegido en vez de desaparecer del desplegable en silencio.
//-----------------------------------------------------------------------------
export function opciones(cuales, actual) {
  const lista = (cuales === "variable") ? _variables : _interruptores;
  const salida = [];
  if (!lista.length) {
    // Sin nombres: numeros pelados. Se ofrece un rango razonable.
    for (let i = 1; i <= TOPE; i++) salida.push({ valor: String(i), texto: String(i).padStart(4, "0") });
  } else {
    for (const s of lista) {
      salida.push({ valor: String(s.id), texto: String(s.id).padStart(4, "0") + ": " + s.nombre });
    }
  }
  const n = parseInt(actual, 10);
  if (Number.isFinite(n) && n > 0 && !salida.some(o => o.valor === String(n))) {
    salida.unshift({ valor: String(n), texto: String(n).padStart(4, "0") + ": (sin nombre)" });
  }
  return salida;
}

export function nombreDe(cuales, id) {
  const lista = (cuales === "variable") ? _variables : _interruptores;
  const s = lista.find(x => x.id === parseInt(id, 10));
  return s ? s.nombre : "";
}
