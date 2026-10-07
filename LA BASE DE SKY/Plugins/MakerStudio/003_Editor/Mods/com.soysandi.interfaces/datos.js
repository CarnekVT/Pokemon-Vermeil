//=============================================================================
// Los datos del juego que se pueden meter en un texto.
//
// GENERADO DESDE Plugins/[LBDS] Interfaces/[007] Datos.rb (su lista CATALOGO).
// No editar a mano: se regenera con  node tools/generar-datos.js
//
// El "ejemplo" es lo que enseña el lienzo del editor en vez de las llaves, para
// poder cuadrar el hueco que el dato va a ocupar de verdad en el juego.
//=============================================================================

export const DATOS = [
  {
    "clave": "jugador",
    "que": "El nombre del jugador",
    "ejemplo": "ENTRENADOR"
  },
  {
    "clave": "dinero",
    "que": "El dinero que lleva",
    "ejemplo": "1500"
  },
  {
    "clave": "insignias",
    "que": "Cuantas medallas tiene",
    "ejemplo": "3"
  },
  {
    "clave": "id",
    "que": "Su numero de entrenador",
    "ejemplo": "04213"
  },
  {
    "clave": "horas",
    "que": "Horas jugadas",
    "ejemplo": "12"
  },
  {
    "clave": "minutos",
    "que": "Minutos (de la hora en curso)",
    "ejemplo": "34"
  },
  {
    "clave": "pokedex",
    "que": "Pokemon capturados",
    "ejemplo": "27"
  },
  {
    "clave": "vistos",
    "que": "Pokemon vistos",
    "ejemplo": "58"
  },
  {
    "clave": "mapa",
    "que": "Donde esta ahora",
    "ejemplo": "Pueblo Rumh"
  },
  {
    "clave": "seleccion",
    "que": "Que copia esta elegida ahora",
    "ejemplo": "1"
  },
  {
    "clave": "seleccion.id",
    "que": "El nombre del elemento elegido",
    "ejemplo": "boton_1"
  },
  {
    "clave": "seleccion.NOMBRE",
    "que": "1 si ese boton es el elegido",
    "ejemplo": "1"
  },
  {
    "clave": "equipo.total",
    "que": "Cuantos Pokemon lleva",
    "ejemplo": "4"
  },
  {
    "clave": "equipo.1.nombre",
    "que": "Nombre del Pokemon 1",
    "ejemplo": "PIKACHU"
  },
  {
    "clave": "equipo.1.especie",
    "que": "Su especie",
    "ejemplo": "Pikachu"
  },
  {
    "clave": "equipo.1.nivel",
    "que": "Su nivel",
    "ejemplo": "24"
  },
  {
    "clave": "equipo.1.hp",
    "que": "Su vida ahora",
    "ejemplo": "31"
  },
  {
    "clave": "equipo.1.hp_max",
    "que": "Su vida maxima",
    "ejemplo": "45"
  },
  {
    "clave": "equipo.1.hp_pct",
    "que": "Su vida en porcentaje",
    "ejemplo": "69"
  },
  {
    "clave": "equipo.1.exp",
    "que": "Su experiencia",
    "ejemplo": "8420"
  },
  {
    "clave": "equipo.1.exp_max",
    "que": "La que necesita para subir",
    "ejemplo": "9261"
  },
  {
    "clave": "equipo.1.estado",
    "que": "Envenenado, dormido...",
    "ejemplo": "PSN"
  },
  {
    "clave": "equipo.1.genero",
    "que": "M o F",
    "ejemplo": "M"
  },
  {
    "clave": "equipo.1.objeto",
    "que": "Lo que lleva puesto",
    "ejemplo": "Baya Aranja"
  },
  {
    "clave": "equipo.1.naturaleza",
    "que": "Su naturaleza",
    "ejemplo": "Alegre"
  },
  {
    "clave": "equipo.1.ataque",
    "que": "Su ataque",
    "ejemplo": "52"
  },
  {
    "clave": "equipo.1.defensa",
    "que": "Su defensa",
    "ejemplo": "40"
  },
  {
    "clave": "equipo.1.velocidad",
    "que": "Su velocidad",
    "ejemplo": "90"
  },
  {
    "clave": "variable.5",
    "que": "El valor de la variable 5",
    "ejemplo": "7"
  },
  {
    "clave": "interruptor.20",
    "que": "1 si el interruptor 20 esta on",
    "ejemplo": "1"
  },
  {
    "clave": "combate.turno",
    "que": "En que turno va el combate",
    "ejemplo": "3"
  },
  {
    "clave": "combate.mio.nombre",
    "que": "Mi Pokemon en combate",
    "ejemplo": "PIKACHU"
  },
  {
    "clave": "combate.mio.hp",
    "que": "Su vida",
    "ejemplo": "31"
  },
  {
    "clave": "combate.mio.hp_max",
    "que": "Su vida maxima",
    "ejemplo": "45"
  },
  {
    "clave": "combate.rival.nombre",
    "que": "El Pokemon rival",
    "ejemplo": "RATTATA"
  },
  {
    "clave": "combate.rival.hp_pct",
    "que": "Su vida en porcentaje",
    "ejemplo": "80"
  }
];

// Sustituye las {llaves} por sus valores de ejemplo. Espejo de Datos.rellenar en
// Ruby, pero con valores de muestra: el editor no tiene una partida cargada.
const PORCLAVE = Object.fromEntries(DATOS.map(d => [d.clave, d.ejemplo]));
export function rellenarEjemplo(texto) {
  const t = String(texto == null ? "" : texto);
  if (!t.includes("{")) return t;
  return t.replace(/\{([^{}]+)\}/g, (_, clave) => {
    if (PORCLAVE[clave] != null) return PORCLAVE[clave];
    // Un dato de otro Pokemon del equipo ({equipo.3.hp}) usa el ejemplo del 1.
    const generico = clave.replace(/^equipo\.\d+\./, "equipo.1.");
    if (PORCLAVE[generico] != null) return PORCLAVE[generico];
    // UN INTERRUPTOR O UNA VARIABLE CUALQUIERA VALE 0, NO HUECO.
    //
    // El motor NUNCA da hueco en estos dos: su proc es
    // "$game_switches[n] ? 1 : 0", o sea que uno sin tocar vale 0, y una
    // variable sin asignar vale 0. El editor devolvia "---" para cualquiera que
    // no estuviera en el catalogo (solo estan el 20 y la 5, de muestra), asi que
    // en cuanto alguien ponia una condicion sobre SU interruptor el editor
    // dejaba de coincidir con el juego. Es el mismo fallo de "el que mentia era
    // el editor" que ya costo caro con {seleccion.NOMBRE}.
    if (/^interruptor\.\d+$/.test(clave) || /^variable\.\d+$/.test(clave)) return "0";
    return "---";                      // igual que el hueco del motor
  });
}

export function tieneDatos(texto) {
  return String(texto == null ? "" : texto).includes("{");
}
