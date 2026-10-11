//=============================================================================
// El inspector: las propiedades del elemento elegido.
//
// SIN JERGA, A PROPOSITO. En pantalla no pone "z-index", "opacity" ni "easing":
// pone Capa, Transparencia y Suavizado. Y las curvas se llaman "rebote" y
// "golpe", que si dicen lo que va a pasar. Quien monta una pantalla no tiene por
// que aprender el vocabulario de nadie.
//=============================================================================

import { h, fila, campoNumero, campoTexto, desplegable, casilla, campoColor,
         boton, titulillo, separador } from "./dom.js";
import * as M from "../modelo.js";
import * as G from "../graficos.js";
import * as D from "../datos.js";
import * as P from "../proyecto.js";

// ¿La condicion esta negada? Se usa al cambiar de boton para no perder el
// "cuando NO esta elegido" que ya estuviera puesto.
const negado = (cond) => "no_es" in cond;

export class Inspector {
  constructor(ctx, opciones) {
    this.ctx = ctx;
    this.op = opciones;              // {alCambiar, avisar, listaInterfaces}
    this.diseno = null;
    this.seleccion = null;

    this.cuerpo = h("div", { className: "ui-inspector" });
    this.el = h("div", { className: "ui-panel-der" },
      h("div", { className: "ui-cabecera-panel" }, h("span", { textContent: "Propiedades" })),
      this.cuerpo
    );
  }

  fijarDiseno(d) { this.diseno = d; this.refrescar(); }
  fijarSeleccion(id) { this.seleccion = id; this.refrescar(); }

  elegido() {
    if (!this.diseno || !this.seleccion) return null;
    return (this.diseno.elementos || []).find(e => e.id === this.seleccion) || null;
  }

  // Cambia una propiedad y avisa. Un valor vacio borra la clave, para que el
  // fichero no se llene de nulos.
  fijar(el, clave, valor) {
    // Escribir seguido en el MISMO campo del MISMO elemento es un solo paso de
    // deshacer; cambiar de campo o de elemento empieza uno nuevo.
    this.op.antesDeCambiar?.("campo:" + el.id + ":" + clave);
    if (valor === null || valor === "" || valor === undefined) delete el[clave];
    else el[clave] = valor;
    this.op.alCambiar?.();
  }

  // Para los cambios que no pasan por fijar (acciones, efecto de entrada): deja
  // la foto de deshacer y avisa.
  tocado() {
    this.op.antesDeCambiar?.();
    this.op.alCambiar?.();
  }

  refrescar() {
    this.cuerpo.innerHTML = "";
    const el = this.elegido();
    if (!el) { this.pintarSinSeleccion(); return; }

    this.pintarGenerales(el);
    this.pintarPosicion(el);
    this.pintarPorTipo(el);
    this.pintarRepeticion(el);
    this.pintarHueco(el);
    this.pintarCondicion(el);
    this.pintarAspecto(el);
    this.pintarEntrada(el);
  }

  pintarSinSeleccion() {
    this.pintarPantalla();
    this.pintarRepeticiones();
    this.pintarHuecos();
    this.pintarAperturas();
    this.cuerpo.appendChild(separador());
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda" },
      h("p", { textContent: "Pulsa un elemento en el lienzo o en la lista de capas para ver sus propiedades." }),
      // Las tres de abajo se hacen desde el elemento, no desde aqui, y por eso se
      // dice DONDE estan: son justo las que no se encontraban.
      h("p", { textContent: "Pincha un boton y abajo del todo tienes: \"Mostrar solo si\" (y ahi, \"Añadir otra condicion\" para pedir varias a la vez), \"Se puede pulsar si\" para que salga apagado y no se pueda usar, y \"Se coloca en\" para que los desbloqueados se pongan en orden sin dejar huecos." }),
      h("p", { textContent: "Atajos: flechas para mover 1 pixel, Shift+flechas para saltar de rejilla, Alt mientras arrastras para no imantar, Supr para borrar, Ctrl+D para duplicar. Ctrl+rueda amplia hacia donde apuntas, y con el boton central o con espacio se arrastra el lienzo." })
    ));
  }

  // Propiedades de la pantalla entera, cuando no hay nada elegido.
  pintarPantalla() {
    if (!this.diseno) return;
    this.cuerpo.appendChild(titulillo("La pantalla"));
    this.cuerpo.appendChild(fila("Titulo",
      campoTexto(this.diseno.titulo, (v) => {
        this.diseno.titulo = v;
        this.op.antesDeCambiar?.();
        this.op.alCambiar?.();
      }, this.diseno.nombre || "")
    ));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "El nombre bonito, el que vera el jugador en el menu de pausa. El fichero se sigue llamando igual." }));

    // Ventana sobre el mapa, o pantalla propia que lo tapa entero.
    const completa = !!this.diseno.pantalla_completa;
    this.cuerpo.appendChild(fila("Ocupa todo",
      casilla(completa, (v) => {
        this.op.antesDeCambiar?.();
        if (v) this.diseno.pantalla_completa = true;
        else { delete this.diseno.pantalla_completa; delete this.diseno.color_fondo; }
        this.op.alCambiar?.();
        this.refrescar();
      }, "tapar el mapa del todo")));

    if (completa) {
      this.cuerpo.appendChild(fila("Color de fondo",
        campoColor(this.diseno.color_fondo || "#000000FF", (v) => {
          this.op.antesDeCambiar?.();
          this.diseno.color_fondo = v;
          this.op.alCambiar?.();
        })));
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: `El mapa deja de verse: la pantalla es tuya entera. Si el fondo cubre ${this.diseno.lienzo?.ancho || M.LIENZO_ANCHO}×${this.diseno.lienzo?.alto || M.LIENZO_ALTO}, este color no se llega a ver.` }));
      this.cuerpo.appendChild(boton("Añadir imagen de fondo a pantalla completa",
        () => this.op.fondoPantallaCompleta?.()));
    } else {
      this.cuerpo.appendChild(fila("Oscurecer mapa",
        campoNumero(M.num(this.diseno.oscurecer_mapa, 0), (v) => {
          this.op.antesDeCambiar?.();
          this.diseno.oscurecer_mapa = Math.max(0, Math.min(255, Math.round(v || 0)));
          this.op.alCambiar?.();
        }, { min: 0, max: 255 })
      ));
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "0 = se ve el mapa tal cual. 255 = negro. Con 140 queda como una ventana sobre el mapa." }));
    }
    this.cuerpo.appendChild(fila("Teclado",
      casilla(this.diseno.teclado !== false, (v) => {
        this.op.antesDeCambiar?.();
        if (v) delete this.diseno.teclado; else this.diseno.teclado = false;
        this.op.alCambiar?.();
        this.refrescar();
      }, "flechas y Z, ademas del raton")));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Con esto puesto, las flechas mueven la seleccion y Z pulsa. El raton sigue funcionando a la vez y al pasar por encima de un boton lo elige. Quitalo solo si quieres una pantalla que sea unicamente de raton." }));
  }

  //---------------------------------------------------------------------------
  // GRUPOS QUE SE REPITEN.
  //
  // Se declaran en la pantalla y no en cada elemento a proposito: los cinco
  // elementos de una ficha comparten la separacion, y asi se cambia en un sitio.
  //---------------------------------------------------------------------------
  pintarRepeticiones() {
    if (!this.diseno) return;
    this.cuerpo.appendChild(titulillo("Grupos que se repiten"));
    const reps = this.diseno.repeticiones || {};
    const nombres = Object.keys(reps);

    if (!nombres.length) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Para una lista (los 6 del equipo, una lista de misiones) declara un grupo aqui, y luego marca los elementos que se repiten con el. Pones la ficha UNA vez y salen todas." }));
    }

    for (const nombre of nombres) {
      const r = reps[nombre];
      const tocar = () => { this.op.antesDeCambiar?.("rep:" + nombre); this.op.alCambiar?.(); };
      this.cuerpo.appendChild(fila(nombre,
        boton("Quitar", () => {
          this.op.antesDeCambiar?.();
          delete this.diseno.repeticiones[nombre];
          // Los elementos que lo usaban se quedarian huerfanos.
          for (const el of this.diseno.elementos || []) if (el.repetir === nombre) delete el.repetir;
          if (!Object.keys(this.diseno.repeticiones).length) delete this.diseno.repeticiones;
          this.op.alCambiar?.();
          this.refrescar();
        }, "peligro")));
      this.cuerpo.appendChild(fila("Cuantas",
        campoTexto(String(r.cuantos == null ? "" : r.cuantos),
          (v) => { const n = parseInt(v, 10); r.cuantos = (String(v).includes("{") ? v : (isNaN(n) ? v : n)); tocar(); }, "6")));
      this.cuerpo.appendChild(fila("Por fila",
        campoNumero(M.num(r.por_fila, 0), (v) => { r.por_fila = Math.max(0, Math.round(v || 0)) || undefined; tocar(); this.refrescar(); }, { min: 0 }),
        h("span", { className: "ui-capa-tipo", textContent: "0 = en linea" })
      ));
      this.cuerpo.appendChild(fila("Separacion",
        campoNumero(M.num(r.salto_x, 0), (v) => { r.salto_x = Math.round(v || 0) || undefined; tocar(); }),
        campoNumero(M.num(r.salto_y, 0), (v) => { r.salto_y = Math.round(v || 0) || undefined; tocar(); })
      ));
      if (M.num(r.por_fila, 0) > 0) {
        this.cuerpo.appendChild(fila("Salto de fila",
          campoNumero(M.num(r.salto_fila_x, 0), (v) => { r.salto_fila_x = Math.round(v || 0) || undefined; tocar(); }),
          campoNumero(M.num(r.salto_fila_y, 0), (v) => { r.salto_fila_y = Math.round(v || 0) || undefined; tocar(); })
        ));
      }
      this.cuerpo.appendChild(fila("Cascada",
        campoNumero(M.num(r.retraso, 0), (v) => { r.retraso = (v || 0) || undefined; tocar(); }, { paso: 0.02, min: 0 }),
        h("span", { className: "ui-capa-tipo", textContent: "s entre copias" })
      ));
      this.cuerpo.appendChild(separador());
    }

    this.cuerpo.appendChild(boton("Añadir un grupo...", async () => {
      const n = await this.op.pedirTexto?.("Nombre del grupo (equipo, misiones...)", "equipo");
      if (!n) return;
      const limpio = String(n).toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
      if (!limpio) return;
      this.op.antesDeCambiar?.();
      this.diseno.repeticiones = this.diseno.repeticiones || {};
      this.diseno.repeticiones[limpio] = { cuantos: 6, salto_y: 40 };
      this.op.alCambiar?.();
      this.refrescar();
    }));
  }

  //---------------------------------------------------------------------------
  // HUECOS QUE SE RELLENAN.
  //
  // AQUI NO SE ESCRIBE NI UNA COORDENADA, y esa es toda la gracia: los huecos son
  // las posiciones que los elementos del grupo ya tienen puestas en el lienzo. Una
  // lista de coordenadas aparte se desincronizaria con lo que se ve el primer dia.
  //---------------------------------------------------------------------------
  pintarHuecos() {
    if (!this.diseno) return;
    this.cuerpo.appendChild(titulillo("Huecos que se rellenan"));
    const huecos = this.diseno.huecos || {};
    const nombres = Object.keys(huecos);

    if (!nombres.length) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Para un menu donde algunos botones estan bloqueados: declara un grupo, marca los botones con el, y los que se vean se colocaran en los primeros sitios sin dejar agujeros. Coloca los botones donde quieras: sus posiciones SON los huecos." }));
    }

    for (const nombre of nombres) {
      const r = huecos[nombre];
      const cuantos = (this.diseno.elementos || []).filter(e => e.hueco === nombre).length;
      this.cuerpo.appendChild(fila(`${nombre} (${cuantos})`,
        boton("Quitar", () => {
          this.op.antesDeCambiar?.();
          delete this.diseno.huecos[nombre];
          for (const el of this.diseno.elementos || []) if (el.hueco === nombre) delete el.hueco;
          if (!Object.keys(this.diseno.huecos).length) delete this.diseno.huecos;
          this.op.alCambiar?.();
          this.refrescar();
        }, "peligro")));
      this.cuerpo.appendChild(fila("Se llenan",
        desplegable(r.orden === "fila" ? "fila" : "columna", [
          { valor: "columna", texto: "de arriba abajo" },
          { valor: "fila", texto: "de izquierda a derecha" }
        ], (v) => {
          this.op.antesDeCambiar?.();
          if (v === "fila") r.orden = "fila"; else delete r.orden;
          this.op.alCambiar?.();
          this.refrescar();
        })));
      this.cuerpo.appendChild(fila("Cascada",
        campoNumero(M.num(r.retraso, 0), (v) => {
          this.op.antesDeCambiar?.("hueco:" + nombre);
          r.retraso = (v || 0) || undefined;
          this.op.alCambiar?.();
        }, { paso: 0.02, min: 0 }),
        h("span", { className: "ui-capa-tipo", textContent: "s entre uno y otro" })
      ));
      this.cuerpo.appendChild(separador());
    }

    this.cuerpo.appendChild(boton("Añadir un grupo de huecos...", async () => {
      const n = await this.op.pedirTexto?.("Nombre del grupo (menu, prendas...)", "menu");
      if (!n) return;
      const limpio = String(n).toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
      if (!limpio) return;
      this.op.antesDeCambiar?.();
      this.diseno.huecos = this.diseno.huecos || {};
      this.diseno.huecos[limpio] = {};
      this.op.alCambiar?.();
      this.refrescar();
    }));
  }

  //---------------------------------------------------------------------------
  // APERTURAS: como se abre esta pantalla dentro del juego.
  //
  // Esto antes se configuraba editando Settings.rb, o sea escribiendo Ruby. Era
  // un fallo de diseño en una herramienta pensada para no programar.
  //---------------------------------------------------------------------------
  pintarAperturas() {
    if (!this.diseno) return;
    const ap = M.aperturas(this.diseno);
    const tocar = () => { this.op.antesDeCambiar?.(); this.op.alCambiar?.(); };

    this.cuerpo.appendChild(titulillo("Como se abre en el juego"));

    // 1. Menu de pausa
    this.cuerpo.appendChild(fila("Menu de pausa",
      casilla(!!ap.menu_pausa, (v) => {
        if (v) { ap.menu_pausa = true; if (ap.orden == null) ap.orden = M.ORDEN_DEFECTO; }
        else { delete ap.menu_pausa; delete ap.orden; }
        tocar();
        this.refrescar();
      }, "que salga al pulsar X")));
    if (ap.menu_pausa) {
      const orden = M.num(ap.orden, M.ORDEN_DEFECTO);
      this.cuerpo.appendChild(fila("En que puesto",
        campoNumero(orden, (v) => { ap.orden = Math.round(v || M.ORDEN_DEFECTO); tocar(); this.refrescar(); }, { min: 1, max: 99 }),
        h("span", { className: "ui-capa-tipo",
          textContent: M.ORDENES_OCUPADOS[orden] ? `ocupado por ${M.ORDENES_OCUPADOS[orden]}` : "libre" })
      ));
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Numero mas bajo = mas arriba en el menu. El juego usa 10 Pokedex, 20 Pokemon, 30 Mochila, 40 Mapa, 50 Ficha, 60 Guardar. Pon 35 para que salga entre la Mochila y el Mapa." }));
    }

    // 2. Tecla
    this.cuerpo.appendChild(fila("Con una tecla",
      desplegable(String(ap.tecla || ""), M.TECLAS.map(t => ({ valor: t, texto: t === "" ? "(ninguna)" : t })),
        (v) => { if (v) ap.tecla = v; else delete ap.tecla; tocar(); this.refrescar(); })));
    if (ap.tecla) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: `Estando en el mapa, la tecla ${ap.tecla} abre esta pantalla. No salen en la lista las que ya usa el juego (Z, X, C, flechas...).` }));
    }

    // 3. Interruptor de interfaz
    const entradaInt = campoTexto(ap.interruptor, (v) => {
      const limpio = String(v || "").toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
      if (limpio) ap.interruptor = limpio; else delete ap.interruptor;
      tocar();
      this.refrescar();
    }, "misiones");
    this.cuerpo.appendChild(fila("Interruptor", entradaInt));

    // Reemplazar una pantalla del juego: se elige de una lista, porque el nombre
    // tiene que coincidir EXACTO y de memoria se falla.
    this.cuerpo.appendChild(fila("O reemplaza",
      desplegable(M.INTEGRADAS[ap.interruptor] ? ap.interruptor : "",
        [{ valor: "", texto: "(una pantalla del juego...)" },
         ...Object.keys(M.INTEGRADAS).map(k => ({ valor: k, texto: M.INTEGRADAS[k].titulo }))],
        (v) => {
          if (v) ap.interruptor = v; else delete ap.interruptor;
          entradaInt.value = v;
          tocar();
          this.refrescar();
        })));

    const integrada = M.INTEGRADAS[ap.interruptor];
    if (integrada) {
      // Este es el aviso que mas tiempo puede ahorrar: rehacer la Mochila da un
      // marco bonito y vacio, porque la lista de objetos es codigo y no datos.
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        style: { borderLeft: "3px solid var(--accent)", paddingLeft: "8px" } },
        h("p", { innerHTML: `<strong>Esta pantalla reemplaza a ${integrada.titulo} del juego.</strong>` }),
        h("p", { textContent: `Al entrar en el juego, el menu de pausa y cualquier boton que use "${ap.interruptor}" abriran ESTA en vez de la original.` }),
        h("p", { textContent: `OJO: ${integrada.contenido} NO se puede dibujar aqui, porque eso lo genera el codigo del juego y no es un dato. Si la reemplazas del todo, tendras el marco pero no ${integrada.contenido}. Para menus de botones va perfecto; para pantallas con contenido, mejor deja un boton que abra la original.` })
      ));
    } else {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Un nombre tuyo. Cualquier boton que active este interruptor abrira esta pantalla, cerrandose la de antes. NO son los interruptores de los eventos de Essentials: estos son aparte y van por nombre." }));
    }

    this.cuerpo.appendChild(h("div", { className: "ui-ayuda", style: { marginTop: "8px" } },
      h("strong", { textContent: "Se abre asi: " }),
      h("span", { textContent: M.resumenAperturas(this.diseno) })
    ));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda", style: { opacity: ".8" },
      textContent: "El menu de pausa y las teclas se leen al arrancar el juego. Si cambias esto, reinicia el juego una vez (los cambios de diseño no lo piden)." }));
  }

  //---------------------------------------------------------------------------
  pintarGenerales(el) {
    this.cuerpo.appendChild(titulillo(M.NOMBRE_TIPO[el.tipo] || el.tipo));
    this.cuerpo.appendChild(fila("Nombre",
      h("span", { textContent: el.id, title: "Doble clic en la lista de capas para cambiarlo" })));
    this.cuerpo.appendChild(fila("Capa",
      campoNumero(M.num(el.capa, 0), (v) => this.fijar(el, "capa", Math.round(v || 0)))));
  }

  pintarPosicion(el) {
    this.cuerpo.appendChild(titulillo("Posicion y tamaño"));
    this.cuerpo.appendChild(fila("Posicion",
      campoNumero(M.num(el.x, 0), (v) => this.fijar(el, "x", Math.round(v || 0))),
      campoNumero(M.num(el.y, 0), (v) => this.fijar(el, "y", Math.round(v || 0)))
    ));
    this.cuerpo.appendChild(fila("Tamaño",
      campoNumero(el.ancho == null ? null : M.num(el.ancho, 0), (v) => this.fijar(el, "ancho", v == null ? null : Math.round(v)), { hueco: "auto" }),
      campoNumero(el.alto == null ? null : M.num(el.alto, 0), (v) => this.fijar(el, "alto", v == null ? null : Math.round(v)), { hueco: "auto" })
    ));
    this.cuerpo.appendChild(fila("Anchor",
      desplegable(el.ancla || "arriba_izq", M.ANCLAS, (v) => this.fijar(el, "ancla", v || "arriba_izq"))
    ));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "El anchor decide como se recoloca este elemento al cambiar la resolucion del canvas. Arriba izquierda conserva el comportamiento de los diseños v1." }));
    // TIPOS QUE MIDEN LO QUE MIDE SU IMAGEN. Se les puede dar un tamaño igual: el
    // motor lo traduce a zoom_x y zoom_y por separado, o sea que se puede
    // deformar. Dejarlo vacio vuelve al tamaño de la imagen.
    const porImagen = el.tipo === "imagen" || el.tipo === "animado" ||
                      el.tipo === "pokemon" || (el.tipo === "boton" && el.imagen);
    if (porImagen) {
      this.cuerpo.appendChild(fila("",
        boton("Tamaño original", () => {
          this.op.antesDeCambiar?.();
          delete el.ancho;
          delete el.alto;
          this.op.alCambiar?.();
          this.refrescar();
        })));
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Vacio = el tamaño de la imagen. Arrastra una esquina en el lienzo para estirarla; con Shift no se deforma." }));
    } else if (el.tipo === "texto") {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Dejalo vacio y la caja se ajusta sola al texto." }));
    }
  }

  // A que grupo repetido pertenece este elemento.
  pintarRepeticion(el) {
    const declaradas = Object.keys((this.diseno && this.diseno.repeticiones) || {});
    if (!declaradas.length && !el.repetir) return;
    this.cuerpo.appendChild(titulillo("Se repite"));
    this.cuerpo.appendChild(fila("En el grupo",
      desplegable(el.repetir || "",
        [{ valor: "", texto: "(no se repite)" }, ...declaradas.map(d => ({ valor: d, texto: d }))],
        (v) => this.fijar(el, "repetir", v || null))));
    if (el.repetir) {
      const r = (this.diseno.repeticiones || {})[el.repetir] || {};
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: `Se dibujara ${r.cuantos || "?"} veces. Usa {n} en los textos para el numero de copia: {equipo.{n}.nombre} da el nombre del Pokemon 1, 2, 3...` }));
    }
  }

  //---------------------------------------------------------------------------
  // A que grupo de huecos pertenece, y en que puesto de la fila va hoy.
  //
  // ESTA SECCION SE ENSEÑA AUNQUE NO HAYA NINGUN GRUPO TODAVIA, y no es un
  // capricho: antes los grupos solo se podian crear con NADA seleccionado, o sea
  // que quien pinchaba un boton buscando "botones dinamicos" no encontraba nada y
  // daba por hecho que no existia. Paso de verdad. Se crea desde aqui, que es
  // donde a uno se le ocurre buscarlo.
  //---------------------------------------------------------------------------
  pintarHueco(el) {
    const declarados = Object.keys((this.diseno && this.diseno.huecos) || {});
    if (!declarados.length && !el.hueco) {
      if (el.tipo !== "boton") return;      // en un texto suelto seria ruido
      const botones = this.botonesDelDiseno();
      this.cuerpo.appendChild(titulillo("Se coloca en"));
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Ahora mismo este boton se queda siempre donde lo pongas. Si quieres una lista donde los que esten bloqueados no dejen un agujero (un vestidor, un menu que se va desbloqueando), haz un grupo de huecos: los que se vean ocuparan los primeros sitios, en orden." }));
      this.cuerpo.appendChild(boton(
        botones.length > 1
          ? `Que los ${botones.length} botones se coloquen en orden`
          : "Crear un grupo de huecos",
        () => {
          this.op.antesDeCambiar?.();
          this.diseno.huecos = this.diseno.huecos || {};
          this.diseno.huecos["menu"] = {};
          // Se meten TODOS los botones y no solo este: un grupo de uno no
          // compacta nada (no hay a donde subir) y es el aviso que da el propio
          // revisor. Sacar al que sobre es un desplegable.
          for (const b of botones) b.hueco = "menu";
          this.op.alCambiar?.();
          this.refrescar();
        }, "primario"));
      if (botones.length > 1) {
        this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
          textContent: "Entran todos, y al que no quieras (el de Salir, por ejemplo) le pones \"(donde esta puesto)\" aqui mismo. Sus posiciones de ahora SON los huecos: con todos visibles no se mueve nada." }));
      }
      return;
    }
    this.cuerpo.appendChild(titulillo("Se coloca en"));
    this.cuerpo.appendChild(fila("Huecos de",
      desplegable(el.hueco || "",
        [{ valor: "", texto: "(donde esta puesto)" }, ...declarados.map(d => ({ valor: d, texto: d }))],
        (v) => { this.fijar(el, "hueco", v || null); this.refrescar(); })));
    if (!el.hueco) return;

    // Se dice cuantos son y en que puesto va este: sin eso, "va en el grupo menu"
    // no le dice a nadie que va a pasar cuando falte alguno.
    const grupo = (this.diseno.elementos || []).filter(e => e.hueco === el.hueco);
    const regla = (this.diseno.huecos || {})[el.hueco] || {};
    const ordenados = grupo.slice().sort((a, b) => (regla.orden === "fila")
      ? (M.num(a.x, 0) - M.num(b.x, 0)) || (M.num(a.y, 0) - M.num(b.y, 0))
      : (M.num(a.y, 0) - M.num(b.y, 0)) || (M.num(a.x, 0) - M.num(b.x, 0)));
    const puesto = ordenados.findIndex(e => e.id === el.id) + 1;
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: `Hoy va el ${puesto} de ${grupo.length}. Si alguno de los de antes no se ve, este sube a su sitio. ` +
                   `Los huecos son las posiciones que ya tienen los del grupo: muevelos en el lienzo y listo.` }));
  }

  //---------------------------------------------------------------------------
  // MOSTRAR SOLO SI...
  //
  // Es lo que convierte una lista repetida en algo util: pones seis fichas de
  // equipo y las de los huecos vacios se esconden solas.
  //---------------------------------------------------------------------------
  //---------------------------------------------------------------------------
  // MOSTRAR SOLO SI.
  //
  // POR QUE NO ES UN CAMPO DE TEXTO
  //   Antes habia que escribir el dato a mano ("{interruptor.45}"). Alguien
  //   probando el editor quiso que un texto siguiera a un boton, escribio
  //   "seleccion.boton_1" dando por hecho que eso preguntaba por ese boton, y no
  //   funciono. Su intuicion era razonable; el que estaba mal era el diseño.
  //
  //   Ahora se elige PRIMERO de que va la condicion y despues se rellena con
  //   desplegables. Los cuatro casos que la gente pide de verdad:
  //
  //     boton        cuando este elegido tal boton   -> lista de los que hay
  //     interruptor  un interruptor del juego        -> lista con sus NOMBRES
  //     variable     una variable del juego          -> lista con sus NOMBRES
  //     dato         cualquier otra cosa             -> lo de antes, a mano
  //
  //   Los interruptores y variables se enseñan como "0045: Derrotado Gim 4",
  //   igual que la pestaña de condiciones de RPG Maker: es donde la gente ya
  //   sabe leerlo.
  //---------------------------------------------------------------------------
  //---------------------------------------------------------------------------
  // VARIAS CONDICIONES A LA VEZ.
  //
  // Lo pidio quien monta las pantallas: "hay veces que se necesita que se cumpla
  // mas de una condicion a la vez, y el programa lo limita a una". Antes habia que
  // inventarse una variable puente en el editor de eventos para juntar dos cosas.
  //
  // El editor trabaja SIEMPRE con una lista, aunque tenga un solo elemento, y al
  // guardar la de uno se escribe pelada (ver M.empaquetarCondiciones). Asi las
  // pantallas de antes se leen y se reescriben exactamente igual que siempre.
  //
  // El mismo cajon vale para "mostrar_si" (si se ve) y para "activo_si" (si se
  // puede pulsar), que es lo que hace que los botones apagados no hayan costado
  // una interfaz nueva.
  //---------------------------------------------------------------------------
  pintarCondicion(el) {
    this.pintarCondiciones(el, "mostrar_si", "Mostrar solo si", "se ve siempre",
      "Un elemento escondido tampoco se puede pulsar ni elegir con las flechas.");
    if (el.tipo === "boton") {
      this.pintarCondiciones(el, "activo_si", "Se puede pulsar si", "siempre se puede pulsar",
        "Apagado SE VE igual, pero no se puede pulsar ni alcanzar con las flechas, " +
        "y al intentarlo suena un zumbido. Es lo que hace falta para una lista donde " +
        "quieres que se vea lo que aun no tienes.");
      if (el.activo_si) this.pintarAspectoApagado(el);
    }
  }

  pintarCondiciones(el, clave, titulo, siNoHay, ayuda) {
    this.cuerpo.appendChild(titulillo(titulo));
    const tiene = !!el[clave];
    this.cuerpo.appendChild(fila("Con condicion",
      casilla(tiene, (v) => {
        this.op.antesDeCambiar?.();
        if (v) el[clave] = { dato: "{interruptor.1}", es: 1 };
        else delete el[clave];
        this.op.alCambiar?.();
        this.refrescar();
      }, tiene ? "" : siNoHay)));
    if (!tiene) return;

    const { modo, lista } = M.listaCondiciones(el[clave]);
    // Cualquier cambio de ESTRUCTURA (añadir, quitar, cambiar Y por O) reescribe
    // la clave entera. Los cambios DENTRO de una condicion la tocan en su sitio,
    // que es lo que permite reutilizar los tres editores de siempre sin tocarlos.
    const rehacer = (nuevoModo, nuevaLista) => {
      this.op.antesDeCambiar?.();
      const empaquetada = M.empaquetarCondiciones(nuevoModo, nuevaLista);
      if (empaquetada) el[clave] = empaquetada; else delete el[clave];
      this.op.alCambiar?.();
      this.refrescar();
    };

    if (lista.length > 1) {
      this.cuerpo.appendChild(fila("Se cumplen",
        desplegable(modo, [
          { valor: "todas", texto: "TODAS (y)" },
          { valor: "alguna", texto: "AL MENOS UNA (o)" }
        ], (v) => rehacer(v, lista))));
    }

    const tocar = () => { this.op.antesDeCambiar?.("cond:" + el.id + ":" + clave); this.op.alCambiar?.(); };
    lista.forEach((cond, i) => {
      if (lista.length > 1) {
        this.cuerpo.appendChild(fila(`Condicion ${i + 1}`,
          boton("Quitar", () => rehacer(modo, lista.filter((_, j) => j !== i)), "peligro")));
      }
      const clase = M.claseCondicion(cond);
      this.cuerpo.appendChild(fila("De que va",
        desplegable(clase, M.CLASES_CONDICION, (v) => {
          if (v === clase) return;
          // Se reescribe la condicion entera: mezclar restos de la anterior es lo
          // que produce condiciones a medias que no se cumplen nunca.
          const nueva = lista.slice();
          nueva[i] = M.condicionNueva(v, this.primerBotonDe(el));
          rehacer(modo, nueva);
        })));

      if (clase === "boton") this.condicionBoton(el, cond, tocar);
      else if (clase === "interruptor" || clase === "variable") this.condicionInterruptor(el, cond, tocar, clase);
      else this.condicionDato(el, cond, tocar);
      if (i < lista.length - 1) this.cuerpo.appendChild(separador());
    });

    this.cuerpo.appendChild(boton("Añadir otra condicion",
      () => rehacer(modo, [...lista, { dato: "{interruptor.1}", es: 1 }])));

    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "En el juego: " + M.resumenCondicion(el[clave]) + ". " + ayuda +
                   " Si la condicion esta mal escrita el elemento SE VE, para que no desaparezca en silencio." }));
  }

  //---------------------------------------------------------------------------
  // Como se ve un boton apagado. Sin poner nada se apaga con gris y transparencia
  // (Interfaces::APAGADO_* en Settings.rb); quien tenga arte lo pisa aqui, y
  // entonces manda el dibujo y no se le echa gris encima.
  //---------------------------------------------------------------------------
  pintarAspectoApagado(el) {
    this.cuerpo.appendChild(titulillo("Y apagado se ve..."));
    if (el.imagen) {
      this.cuerpo.appendChild(fila("Imagen",
        campoTexto(el.imagen_apagado || "", (v) => this.fijar(el, "imagen_apagado", v),
                   "(gris y translucido)")));
    } else {
      this.cuerpo.appendChild(fila("Color",
        campoColor(el.color_apagado || el.color || M.BOTON_COLOR,
          (v) => this.fijar(el, "color_apagado", v))));
      if (el.color_apagado) {
        this.cuerpo.appendChild(boton("Quitar el color de apagado",
          () => { this.fijar(el, "color_apagado", null); this.refrescar(); }));
      }
    }
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Dejalo vacio y el boton se apaga solo: se le quita el color y se pone medio transparente. " +
                   "Si pones algo aqui manda lo tuyo y no se le echa nada encima." }));
  }

  // Los botones de esta pantalla, para poder elegirlos por nombre.
  botonesDelDiseno() {
    return (this.diseno?.elementos || []).filter(e => e.tipo === "boton");
  }

  primerBotonDe(el) {
    const otros = this.botonesDelDiseno().filter(b => b.id !== el.id);
    return (otros[0] || this.botonesDelDiseno()[0] || {}).id || "";
  }

  //---------------------------------------------------------------------------
  // "Cuando este elegido tal boton".
  //
  // Se escribe como {seleccion.<id>} comparado con 1, que el motor entiende como
  // "¿es ese el elegido?". En una lista repetida se ofrece ademas la opcion
  // "el mio", que usa {n} y hace que cada copia pregunte por si misma: es lo que
  // permite que la ficha elegida de un equipo se vea distinta.
  //---------------------------------------------------------------------------
  condicionBoton(el, cond, tocar) {
    // "{seleccion}" a secas tambien es el modo copia: es lo que se guarda al
    // elegir "el de esta misma copia", y antes de expandir la lista todavia no
    // lleva {n} dentro.
    const esElMio = String(cond.dato || "").includes("{n}") ||
                    /^\{?seleccion\}?$/.test(String(cond.dato || ""));
    const opciones = [];
    if (el.repetir) opciones.push({ valor: "@mio", texto: "el de esta misma copia" });
    // Se enseña el TEXTO del boton junto a su nombre: en una pantalla con
    // boton_1..boton_6 los ids no dicen nada, y el texto si ("Mochila", "Cerrar").
    for (const b of this.botonesDelDiseno()) {
      const rotulo = String(b.texto || "").trim();
      opciones.push({ valor: b.id, texto: rotulo ? `${b.id} — ${rotulo}` : b.id });
    }

    if (!opciones.length) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Esta pantalla todavia no tiene ningun boton. Añade uno y podras elegirlo aqui." }));
      return;
    }

    const actual = esElMio ? "@mio" : String(cond.dato || "").replace(/^\{seleccion\.?|\}$/g, "");
    this.cuerpo.appendChild(fila("El boton",
      desplegable(opciones.some(o => o.valor === actual) ? actual : opciones[0].valor, opciones, (v) => {
        this.op.antesDeCambiar?.();
        // Se mira si estaba negada ANTES de borrar los comparadores. Al reves
        // (mirarlo despues) siempre daria false, y cambiar de boton le daba la
        // vuelta a un "cuando NO esta elegido" que ya estuviera puesto.
        const neg = negado(cond);
        delete cond.es;
        delete cond.no_es;
        cond.dato = (v === "@mio") ? "{seleccion}" : ("{seleccion." + v + "}");
        cond[neg ? "no_es" : "es"] = (v === "@mio") ? "{n}" : 1;
        this.op.alCambiar?.();
        this.refrescar();
      })));

    // Cuando NO esta elegido es igual de util: es como se hace la version
    // "apagada" de una ficha, la que se ve mientras el cursor esta en otra.
    const neg = "no_es" in cond;
    this.cuerpo.appendChild(fila("Se ve cuando",
      desplegable(neg ? "no" : "si",
        [{ valor: "si", texto: "SI esta elegido" }, { valor: "no", texto: "NO esta elegido" }],
        (v) => {
          this.op.antesDeCambiar?.();
          const valor = esElMio ? "{n}" : 1;
          delete cond.es; delete cond.no_es;
          cond[(v === "no") ? "no_es" : "es"] = valor;
          this.op.alCambiar?.();
          this.refrescar();
        })));

    if (el.repetir && !esElMio) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Este elemento se repite. Si querias que cada copia mire SU boton, elige \"el de esta misma copia\"." }));
    }

    // POR QUE EN EL LIENZO SE VE A MEDIAS.
    //
    // Aqui solo puede haber UN boton elegido a la vez, asi que en cuanto la
    // condicion pregunta por otro, el elemento se dibuja en fantasma. Sin
    // explicarlo eso se lee como "la condicion no funciona", que es exactamente
    // lo que reporto la primera persona que la uso.
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "En el lienzo solo puede estar elegido un boton a la vez. Si esto se ve " +
                   "a medias y con el borde de rayas naranja es que ahora mismo no le toca, " +
                   "no que este mal: cambia \"Elegido\" en la barra de debajo del lienzo para " +
                   "ver como queda en cada opcion. En el juego se ve entero." }));
  }

  //---------------------------------------------------------------------------
  // Un interruptor o una variable del juego, elegidos por nombre.
  //---------------------------------------------------------------------------
  condicionInterruptor(el, cond, tocar, clase) {
    const raiz = (clase === "variable") ? "variable" : "interruptor";
    const num = String(cond.dato || "").replace(/[^0-9]/g, "") || "1";

    this.cuerpo.appendChild(fila(clase === "variable" ? "La variable" : "El interruptor",
      desplegable(num, P.opciones(clase, num), (v) => {
        cond.dato = "{" + raiz + "." + v + "}";
        tocar();
        this.refrescar();
      })));

    if (clase === "interruptor") {
      // Un interruptor solo puede estar de dos maneras, asi que preguntar por
      // comparadores y valores seria ruido: el motor devuelve 1 o 0.
      const enc = !(("es" in cond) && M.num(cond.es, 1) === 0);
      this.cuerpo.appendChild(fila("Se ve cuando",
        desplegable(enc ? "on" : "off",
          [{ valor: "on", texto: "esta ACTIVADO" }, { valor: "off", texto: "esta apagado" }],
          (v) => {
            this.op.antesDeCambiar?.();
            for (const c of M.COMPARADORES) delete cond[c.valor];
            cond.es = (v === "on") ? 1 : 0;
            this.op.alCambiar?.();
            this.refrescar();
          })));
      if (!P.hayNombres()) {
        this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
          textContent: "Tu version del editor no me da los nombres de los interruptores, asi que solo salen los numeros." }));
      }
      return;
    }

    const comp = M.comparadorDe(cond) || "es";
    this.cuerpo.appendChild(fila("Que", desplegable(comp, M.COMPARADORES.filter(c => c.valor !== "existe"), (v) => {
      this.op.antesDeCambiar?.();
      for (const c of M.COMPARADORES) delete cond[c.valor];
      cond[v] = 0;
      this.op.alCambiar?.();
      this.refrescar();
    })));
    this.cuerpo.appendChild(fila("A",
      campoNumero(M.num(cond[comp], 0), (v) => { cond[comp] = Math.round(v || 0); tocar(); })));
  }

  //---------------------------------------------------------------------------
  // Cualquier otro dato, a mano. Es la valvula de escape para lo que no cabe en
  // los tres casos de arriba.
  //---------------------------------------------------------------------------
  condicionDato(el, cond, tocar) {
    const entrada = campoTexto(cond.dato, (v) => { cond.dato = v; tocar(); }, "{equipo.1.nombre}");
    const btn = boton("Datos...", async () => {
      const d = await this.elegirDato();
      if (!d) return;
      cond.dato = "{" + d + "}";
      entrada.value = cond.dato;
      tocar();
      this.refrescar();
    });
    this.cuerpo.appendChild(fila("El dato", entrada, btn));

    const comp = M.comparadorDe(cond) || "es";
    this.cuerpo.appendChild(fila("Que", desplegable(comp, M.COMPARADORES, (v) => {
      this.op.antesDeCambiar?.();
      for (const c of M.COMPARADORES) delete cond[c.valor];
      cond[v] = (v === "existe") ? true : "";
      this.op.alCambiar?.();
      this.refrescar();
    })));

    if (comp === "existe") {
      this.cuerpo.appendChild(fila("Tiene que",
        desplegable(cond.existe === false ? "no" : "si",
          [{ valor: "si", texto: "existir" }, { valor: "no", texto: "NO existir" }],
          (v) => { cond.existe = (v === "si"); tocar(); })));
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Con una lista repetida esto es lo mas util: pon {equipo.{n}.nombre} y las fichas de los huecos vacios desaparecen solas." }));
    } else {
      this.cuerpo.appendChild(fila("A", campoTexto(String(cond[comp] == null ? "" : cond[comp]),
        (v) => { const n = parseFloat(v); cond[comp] = (v !== "" && !isNaN(n) && String(n) === v.trim()) ? n : v; tocar(); }, "1")));
    }
  }

  pintarAspecto(el) {
    this.cuerpo.appendChild(titulillo("Aspecto"));
    this.cuerpo.appendChild(fila("Transparencia",
      campoNumero(M.num(el.opacidad, 255), (v) => this.fijar(el, "opacidad", v == null ? null : Math.round(v)), { min: 0, max: 255 }),
      h("span", { className: "ui-capa-tipo", textContent: "0-255" })
    ));
    this.cuerpo.appendChild(fila("Tamaño x",
      campoNumero(M.num(el.zoom, 1), (v) => this.fijar(el, "zoom", v == null ? null : v), { paso: 0.1 }),
      h("span", { className: "ui-capa-tipo", textContent: "1 = normal" })
    ));
    this.cuerpo.appendChild(fila("Giro",
      campoNumero(M.num(el.angulo, 0), (v) => this.fijar(el, "angulo", (v == null || v === 0) ? null : v), { paso: 5, min: -180, max: 180 }),
      boton("Enderezar", () => this.fijar(el, "angulo", null))
    ));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Tambien se gira con la bolita de encima del elemento; con Shift va de 15 en 15 grados. El giro y el tamaño trabajan sobre el CENTRO." }));
    this.cuerpo.appendChild(fila("Se ve",
      casilla(el.visible !== false, (v) => this.fijar(el, "visible", v ? null : false), "en el juego")
    ));
    this.pintarCursor(el);
  }

  //---------------------------------------------------------------------------
  // Convertir un elemento en el CURSOR que señala al boton elegido.
  //
  // Es lo que hace que una flecha puesta en el diseño signifique algo: en vez de
  // quedarse quieta de adorno, se coloca sola al lado del boton que esta elegido
  // y se mueve con las flechas del teclado.
  //---------------------------------------------------------------------------
  pintarCursor(el) {
    if (el.tipo === "boton") return;              // un boton no puede señalarse a si mismo
    const es = !!el.sigue_seleccion;
    this.cuerpo.appendChild(fila("Es el cursor",
      casilla(es, (v) => {
        this.op.antesDeCambiar?.();
        if (v) el.sigue_seleccion = true;
        else { delete el.sigue_seleccion; delete el.cursor_x; delete el.cursor_y; }
        this.op.alCambiar?.();
        this.refrescar();
      }, "que señale al boton elegido")));
    if (!es) return;

    this.cuerpo.appendChild(fila("Separacion",
      campoNumero(M.num(el.cursor_x, 0), (v) => this.fijar(el, "cursor_x", v == null ? null : Math.round(v))),
      campoNumero(M.num(el.cursor_y, 0), (v) => this.fijar(el, "cursor_y", v == null ? null : Math.round(v)))
    ));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Se pega al borde izquierdo del boton elegido y se centra a su altura. Estos dos numeros lo corren desde ahi: pon un valor negativo en el primero para dejarlo por fuera del boton. Su x e y del diseño dejan de contar." }));
  }

  //---------------------------------------------------------------------------
  pintarPorTipo(el) {
    switch (el.tipo) {
      case "imagen":  this.pintarImagen(el); break;
      case "texto":   this.pintarTexto(el); break;
      case "panel":   this.pintarPanel(el); break;
      case "animado": this.pintarAnimado(el); break;
      case "boton":   this.pintarBoton(el); break;
      case "ventana": this.pintarVentana(el); break;
      case "barra":   this.pintarBarra(el); break;
      case "pokemon": this.pintarPokemon(el); break;
    }
  }

  //---------------------------------------------------------------------------
  // Un campo de texto con un boton que abre la lista de datos del juego.
  //
  // Es la pieza que hace usable todo esto: nadie se va a aprender de memoria que
  // existe {equipo.1.hp_max}. Se elige de una lista con su explicacion.
  //---------------------------------------------------------------------------
  campoConDatos(valor, alCambiar, hueco, soloUno = false) {
    const entrada = campoTexto(valor, alCambiar, hueco);
    const btn = boton("Datos...", async () => {
      const elegido = await this.elegirDato();
      if (!elegido) return;
      // En un campo que SOLO admite un dato (el valor de una barra) se sustituye;
      // en un texto se añade donde estaba, que es lo natural al escribir frases.
      entrada.value = soloUno ? `{${elegido}}` : (entrada.value || "") + `{${elegido}}`;
      alCambiar(entrada.value);
      this.refrescar();
    });
    return { entrada, btn };
  }

  async elegirDato() {
    const lista = D.DATOS.map(d => `${d.clave}  —  ${d.que}  (ej: ${d.ejemplo})`).join("\n");
    try {
      const r = await this.ctx.ui.showInputDialog({
        title: "Datos del juego",
        message: "Escribe el dato que quieres meter (sin llaves).\n\n" + lista,
        defaultValue: "jugador"
      });
      return r ? String(r).trim().replace(/^\{|\}$/g, "") : null;
    } catch { return null; }
  }

  //---------------------------------------------------------------------------
  pintarVentana(el) {
    this.cuerpo.appendChild(titulillo("Ventana"));
    const marcos = this.op.marcos?.() || [];
    const deMenu = marcos.filter(m => m.formato === "3x3");
    const clasicos = marcos.filter(m => m.formato === "clasico");
    const opciones = [{ valor: "", texto: "El que elija el jugador" },
                      ...deMenu.map(m => ({ valor: m.nombre, texto: m.nombre })),
                      ...clasicos.map(m => ({ valor: m.nombre, texto: m.nombre + "  (clasico)" }))];
    // Si el diseño trae un marco que ya no esta en la lista (se borro, o es de los
    // que no valen), se añade para no perderlo en silencio al abrir el inspector.
    if (el.marco && !marcos.some(m => m.nombre === el.marco)) {
      opciones.push({ valor: el.marco, texto: el.marco + "  (no es un marco de ventana)" });
    }
    this.cuerpo.appendChild(fila("Marco",
      desplegable(el.marco || "", opciones, (v) => this.fijar(el, "marco", v || null))));

    if (!el.marco) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Sin marco elegido usa el del sistema, que es el que el jugador tenga puesto en Opciones. Es lo recomendable: asi tu pantalla cambia de marco con las del juego y no desentona. Aqui se dibuja el primero de la lista solo para hacerte una idea." }));
    } else {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Marco fijo: esta pantalla lo llevara siempre, aunque el jugador elija otro en Opciones." }));
    }
    const elegido = marcos.find(m => m.nombre === el.marco);
    if (el.marco && !elegido) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        style: { color: "#ffb4a8" },
        textContent: "Ese fichero NO es un marco de ventana: en la carpeta Windowskins hay tambien bocadillos de dialogo y carteles de señal, que tienen otra distribucion por dentro y se veran deformes. Elige uno de la lista." }));
    }
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: `En la lista solo salen los que son marcos de verdad: ${deMenu.length} de menu (los "choice", los mismos que puede elegir el jugador) y ${clasicos.length} del formato clasico de RPG Maker.` }));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "El marco va DETRAS de lo que lleve dentro: dejale la capa mas baja que los textos y botones que pongas encima. Y no se puede girar (una ventana de RPG Maker no gira)." }));
  }

  //---------------------------------------------------------------------------
  pintarBarra(el) {
    this.cuerpo.appendChild(titulillo("Barra"));
    const v = this.campoConDatos(el.valor, (x) => this.fijar(el, "valor", x), "{equipo.1.hp}", true);
    this.cuerpo.appendChild(fila("Valor", v.entrada, v.btn));
    const m = this.campoConDatos(el.maximo, (x) => this.fijar(el, "maximo", x), "{equipo.1.hp_max}", true);
    this.cuerpo.appendChild(fila("De un maximo de", m.entrada, m.btn));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Si dejas el maximo vacio, el valor se toma como porcentaje (0 a 100). Para una barra de vida: valor {equipo.1.hp} y maximo {equipo.1.hp_max}." }));

    // CON GRAFICO O CON COLORES. Con grafico se usa el arte del juego y los
    // colores dejan de pintar nada, asi que se esconden en vez de dejarlos ahi
    // engañando.
    this.cuerpo.appendChild(titulillo("Con grafico (opcional)"));
    this.cuerpo.appendChild(this.filaGrafico("Barra", el, "imagen"));
    this.cuerpo.appendChild(this.filaGrafico("Canal vacio", el, "imagen_fondo"));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "La barra es una TIRA con un estado por fila, de arriba a abajo: llena, media y baja. Vale tal cual Graphics/UI/Party/overlay_hp, que es la del juego." }));
    if (el.imagen) {
      this.cuerpo.appendChild(fila("Filas de la tira",
        campoNumero(M.num(el.tramos_imagen, 3), (v2) => this.fijar(el, "tramos_imagen", (v2 == null || v2 === 3) ? null : Math.max(1, Math.round(v2))), { min: 1, max: 8 })));
      this.cuerpo.appendChild(fila("",
        boton("Quitar el grafico", () => {
          this.op.antesDeCambiar?.();
          delete el.imagen;
          delete el.imagen_fondo;
          delete el.tramos_imagen;
          this.op.alCambiar?.();
          this.refrescar();
        })));
      this.pintarBorde(el);
      return;
    }

    this.cuerpo.appendChild(fila("Colores por vida",
      casilla(el.por_tramos !== false, (v2) => this.fijar(el, "por_tramos", v2 ? null : false), "verde, amarillo y rojo")));
    this.cuerpo.appendChild(fila("Color", campoColor(el.color || "#68D076FF", (x) => this.fijar(el, "color", x))));
    if (el.por_tramos !== false) {
      this.cuerpo.appendChild(fila("A media vida", campoColor(el.color_medio || "#E8A830FF", (x) => this.fijar(el, "color_medio", x))));
      this.cuerpo.appendChild(fila("Con poca", campoColor(el.color_bajo || "#E24234FF", (x) => this.fijar(el, "color_bajo", x))));
    }
    this.cuerpo.appendChild(fila("Fondo", campoColor(el.color_fondo || "#20242BFF", (x) => this.fijar(el, "color_fondo", x))));
    this.cuerpo.appendChild(fila("Se llena hacia",
      desplegable(el.hacia || "derecha", ["derecha", "izquierda"], (x) => this.fijar(el, "hacia", x === "derecha" ? null : x))));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Hacia la izquierda es como se ven las barras del rival en muchos juegos." }));
    this.pintarBorde(el);
  }

  pintarPokemon(el) {
    this.cuerpo.appendChild(titulillo("Pokemon del equipo"));
    this.cuerpo.appendChild(fila("Cual",
      campoNumero(M.num(el.cual, 1), (v) => this.fijar(el, "cual", Math.max(1, Math.min(6, Math.round(v || 1)))), { min: 1, max: 6 }),
      h("span", { className: "ui-capa-tipo", textContent: "1 a 6" })
    ));
    this.cuerpo.appendChild(fila("Como se ve",
      desplegable(el.modo || "icono", M.MODOS_POKEMON, (v) => this.fijar(el, "modo", v))));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "icono es el pequeñito de las listas; frente y espalda son los grandes de combate. Si el jugador no lleva tantos Pokemon, ese hueco simplemente no se dibuja: puedes poner los seis sin miedo." }));
  }

  pintarImagen(el) {
    this.cuerpo.appendChild(titulillo("Imagen"));
    this.cuerpo.appendChild(this.filaGrafico("Fichero", el, "imagen"));
    const aviso = this.avisoTamano(el);
    if (aviso) this.cuerpo.appendChild(aviso);
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Vale PNG y GIF. Los GIF animados se mueven solos en el juego: los reproduce el motor por su cuenta, asi que no cuestan rendimiento (pero uno enorme si ocupa memoria)." }));

    // Una imagen puede pasar a ser un boton sin rehacerla. El tipo cambia, la
    // imagen y la posicion se quedan.
    this.cuerpo.appendChild(boton("Convertir en boton", () => {
      this.op.antesDeCambiar?.();
      el.tipo = "boton";
      el.accion = el.accion || { tipo: "cerrar" };
      this.op.alCambiar?.();
      this.refrescar();
    }));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Se queda con la misma imagen y en el mismo sitio, pero ya se puede pulsar. Luego puedes darle otra imagen para cuando pasas por encima y otra para cuando la pulsas." }));
  }

  pintarTexto(el) {
    this.cuerpo.appendChild(titulillo("Texto"));
    const t = this.campoConDatos(el.texto, (v) => this.fijar(el, "texto", v), "Vida: {equipo.1.hp}");
    this.cuerpo.appendChild(fila("Texto", t.entrada, t.btn));
    if (D.tieneDatos(el.texto)) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda" },
        h("p", { textContent: "En el juego se vera: " + D.rellenarEjemplo(el.texto) + "  (con datos de ejemplo)" }),
        !M.num(el.ancho, 0) ? h("p", { textContent: "Ponle un ANCHO a mano: el hueco se esta midiendo con el valor de ahora y si mañana el numero es mas largo, se apretara." }) : null
      ));
    }
    this.cuerpo.appendChild(fila("Tamaño letra",
      campoNumero(M.num(el.tamano, M.TEXTO_TAMANO), (v) => this.fijar(el, "tamano", v == null ? null : Math.round(v)), { min: 6, max: 72 })));
    this.cuerpo.appendChild(fila("Color", campoColor(el.color || M.TEXTO_COLOR, (v) => this.fijar(el, "color", v))));
    this.cuerpo.appendChild(fila("Sombra", campoColor(el.sombra || M.TEXTO_SOMBRA, (v) => this.fijar(el, "sombra", v))));
    this.cuerpo.appendChild(fila("Alineacion",
      desplegable(el.alineacion || "izquierda", M.ALINEACIONES, (v) => this.fijar(el, "alineacion", v))));
    this.pintarVertical(el);
  }

  // Borde del rectangulo. Un menu de Pokemon casi nunca es un color plano, y
  // ponerle marco es lo que mas cambia como se ve una pantalla por lo poco que
  // cuesta.
  pintarBorde(el) {
    const tiene = !!el.borde;
    this.cuerpo.appendChild(fila("Borde",
      casilla(tiene, (v) => {
        this.op.antesDeCambiar?.();
        if (v) { el.borde = "#FFFFFFFF"; el.borde_grosor = 1; }
        else { delete el.borde; delete el.borde_grosor; delete el.borde_encima; delete el.borde_pulsado; }
        this.op.alCambiar?.();
        this.refrescar();
      }, "marco alrededor")));
    if (!tiene) return;
    this.cuerpo.appendChild(fila("Color borde", campoColor(el.borde, (v) => this.fijar(el, "borde", v))));
    this.cuerpo.appendChild(fila("Grosor",
      campoNumero(M.num(el.borde_grosor, 1), (v) => this.fijar(el, "borde_grosor", Math.max(1, Math.round(v || 1))), { min: 1, max: 8 }),
      h("span", { className: "ui-capa-tipo", textContent: "px" })
    ));
    if (el.tipo === "boton") {
      this.cuerpo.appendChild(fila("Al pasar", campoColor(el.borde_encima || el.borde, (v) => this.fijar(el, "borde_encima", v))));
      this.cuerpo.appendChild(fila("Al pulsar", campoColor(el.borde_pulsado || el.borde, (v) => this.fijar(el, "borde_pulsado", v))));
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: "Que el borde cambie de color al pasar por encima da sensacion de que el boton responde, sin necesidad de tener arte." }));
    }
  }

  // Colocacion vertical dentro de la caja, con ajuste fino.
  //
  // Existe porque la fuente del juego no reparte igual el hueco de arriba y el
  // de abajo, asi que "centrado" no siempre se ve centrado. En vez de esconderlo,
  // se deja a mano: el editor enseña el resultado al momento.
  pintarVertical(el) {
    this.cuerpo.appendChild(fila("Vertical",
      desplegable(el.alineacion_vertical || "centro", M.VERTICALES,
        (v) => this.fijar(el, "alineacion_vertical", v === "centro" ? null : v))));
    this.cuerpo.appendChild(fila("Subir/bajar",
      campoNumero(M.num(el.desplazar_y, 0), (v) => this.fijar(el, "desplazar_y", (v == null || v === 0) ? null : Math.round(v))),
      h("span", { className: "ui-capa-tipo", textContent: "px (- sube)" })
    ));
    this.cuerpo.appendChild(fila("Contorno",
      casilla(!!el.contorno, (v) => this.fijar(el, "contorno", v ? true : null), "rodear la letra")));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Rodea la letra por los ocho lados con el color de sombra, en vez de dejar solo una sombrita. Es lo que hace que un texto claro se lea sobre cualquier fondo." }));
  }

  pintarPanel(el) {
    this.cuerpo.appendChild(titulillo("Rectangulo"));
    this.cuerpo.appendChild(fila("Color", campoColor(el.color || "#000000FF", (v) => this.fijar(el, "color", v))));
    this.pintarBorde(el);
  }

  pintarAnimado(el) {
    this.cuerpo.appendChild(titulillo("Animacion por hoja"));
    this.cuerpo.appendChild(this.filaGrafico("Hoja", el, "imagen"));
    this.cuerpo.appendChild(fila("Fotogramas",
      campoNumero(M.num(el.fotogramas, 1), (v) => this.fijar(el, "fotogramas", Math.max(1, Math.round(v || 1))), { min: 1 })));
    this.cuerpo.appendChild(fila("Cada uno mide",
      campoNumero(el.ancho_fotograma == null ? null : M.num(el.ancho_fotograma, 0), (v) => this.fijar(el, "ancho_fotograma", v == null ? null : Math.round(v)), { hueco: "auto" }),
      campoNumero(el.alto_fotograma == null ? null : M.num(el.alto_fotograma, 0), (v) => this.fijar(el, "alto_fotograma", v == null ? null : Math.round(v)), { hueco: "auto" })
    ));
    this.cuerpo.appendChild(fila("Velocidad",
      campoNumero(M.num(el.velocidad, 2), (v) => this.fijar(el, "velocidad", Math.max(1, Math.round(v || 2))), { min: 1 }),
      h("span", { className: "ui-capa-tipo", textContent: "menor = mas rapido" })
    ));
    this.cuerpo.appendChild(fila("En bucle", casilla(el.bucle !== false, (v) => this.fijar(el, "bucle", v), "repetir sin parar")));
    const dato = G.imagenEnCache(el.imagen);
    if (dato && dato.ancho) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: `La hoja mide ${dato.ancho}x${dato.alto}. Dejando el tamaño en auto se reparte entre los fotogramas.` }));
    }
  }

  pintarBoton(el) {
    this.cuerpo.appendChild(titulillo("Boton"));

    const porImagen = !!el.imagen;
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: porImagen
        ? "Con imagen puesta manda la imagen. Vacia la casilla de la imagen normal para volver al modo color."
        : "Sin imagen se dibuja como un rectangulo de color. Sirve para montar la pantalla antes de tener el arte." }));

    this.cuerpo.appendChild(this.filaGrafico("Imagen", el, "imagen"));
    if (porImagen) {
      this.cuerpo.appendChild(this.filaGrafico("Al pasar", el, "imagen_encima"));
      this.cuerpo.appendChild(this.filaGrafico("Al pulsar", el, "imagen_pulsado"));
    } else {
      this.cuerpo.appendChild(fila("Color", campoColor(el.color || M.BOTON_COLOR, (v) => this.fijar(el, "color", v))));
      this.cuerpo.appendChild(fila("Al pasar", campoColor(el.color_encima || M.BOTON_COLOR_ENCIMA, (v) => this.fijar(el, "color_encima", v))));
      this.cuerpo.appendChild(fila("Al pulsar", campoColor(el.color_pulsado || M.BOTON_COLOR_PULSADO, (v) => this.fijar(el, "color_pulsado", v))));
      this.pintarBorde(el);
      this.cuerpo.appendChild(separador());
      this.cuerpo.appendChild(fila("Texto", campoTexto(el.texto, (v) => this.fijar(el, "texto", v))));
      this.cuerpo.appendChild(fila("Tamaño letra",
        campoNumero(M.num(el.tamano, M.TEXTO_TAMANO), (v) => this.fijar(el, "tamano", v == null ? null : Math.round(v)), { min: 6, max: 72 })));
      this.cuerpo.appendChild(fila("Color texto", campoColor(el.color_texto || M.TEXTO_COLOR, (v) => this.fijar(el, "color_texto", v))));
      this.pintarVertical(el);
    }

    // Crecer al pasar por encima. Es el efecto que mas "vivo" hace un menu por lo
    // poco que cuesta, y funciona igual con imagen o con color.
    this.cuerpo.appendChild(separador());
    this.cuerpo.appendChild(fila("Crece al pasar",
      campoNumero(M.num(el.escala_encima, 1), (v) => this.fijar(el, "escala_encima", (v == null || v === 1) ? null : v), { paso: 0.05, min: 0.5, max: 3 }),
      h("span", { className: "ui-capa-tipo", textContent: "1 = igual" })
    ));
    this.cuerpo.appendChild(fila("Y al pulsar",
      campoNumero(M.num(el.escala_pulsado, M.num(el.escala_encima, 1)), (v) => this.fijar(el, "escala_pulsado", v == null ? null : v), { paso: 0.05, min: 0.5, max: 3 })
    ));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "1.08 se nota y no molesta. Crece desde su centro y de forma suave, no de golpe, y la zona de pulsado no se mueve (si se moviera, en el borde parpadearia). Para que ENCOJA al pulsar, pon algo menor que 1 en el segundo: queda como si se hundiera." }));

    this.cuerpo.appendChild(fila("Sonido", campoTexto(el.sonido, (v) => this.fijar(el, "sonido", v), "GUI sel decision")));
    this.cuerpo.appendChild(fila("Orden teclado",
      campoNumero(el.orden_teclado, (v) => this.fijar(el, "orden_teclado", v == null ? null : Math.round(v)), { hueco: "auto", min: 1 }),
      h("span", { className: "ui-capa-tipo", textContent: "1, 2, 3..." })
    ));
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Dejalo en auto y las flechas van al boton mas cercano en esa direccion, que suele ser lo que uno espera. Ponle numero solo si quieres mandar tu sobre el recorrido." }));

    // TECLA DE ACCESO RAPIDO. Es lo que hace la gente en los menus de pausa: la D
    // abre el mapa desde cualquier sitio, sin recorrer la lista con las flechas.
    this.cuerpo.appendChild(fila("Tecla rapida",
      desplegable(el.tecla || "",
        [{ valor: "", texto: "(ninguna)" }, ...M.TECLAS.filter(t => t).map(t => ({ valor: t, texto: t }))],
        (v) => this.fijar(el, "tecla", v || null))));
    const otros = (this.diseno?.elementos || [])
      .filter(e => e !== el && e.tipo === "boton" && e.tecla && el.tecla && e.tecla === el.tecla)
      .map(e => e.id);
    if (otros.length) {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda", style: { color: "var(--danger, #e05c48)" },
        textContent: `La tecla ${el.tecla} tambien la tiene "${otros.join('", "')}". Solo respondera uno.` }));
    } else {
      this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
        textContent: el.tecla
          ? `Pulsar ${el.tecla} dentro de esta pantalla dispara este boton desde donde sea. Si una condicion lo esconde, la tecla tampoco funciona.`
          : "Con una tecla puesta, este boton se puede pulsar sin ir hasta el con las flechas. Util para accesos rapidos en un menu de pausa." }));
    }
    this.pintarAccion(el);
  }

  //---------------------------------------------------------------------------
  // Que hace el boton.
  //---------------------------------------------------------------------------
  pintarAccion(el) {
    this.cuerpo.appendChild(titulillo("Al pulsarlo"));
    const accion = el.accion || (el.accion = { tipo: "nada" });

    this.cuerpo.appendChild(fila("Hace", desplegable(accion.tipo || "nada", M.ACCIONES, (v) => {
      // Se cambia el tipo y se limpian los datos del anterior, que ya no valen.
      // Esto TIRA informacion, asi que la foto de deshacer no es opcional.
      this.op.antesDeCambiar?.();
      el.accion = { tipo: v };
      this.op.alCambiar?.();
      this.refrescar();
    })));

    switch (accion.tipo) {
      case "ir_a_interfaz": {
        this.cuerpo.appendChild(this.filaPantalla("A cual", accion));
        this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
          textContent: "Se cierra esta y se abre la otra. Es lo normal para moverse por un menu: puedes ir y volver todas las veces que quieras." }));
        break;
      }
      case "interruptor_interfaz": {
        const catalogo = this.op.catalogo?.() || [];
        const conocidos = this.op.interruptoresConocidos?.() || [];
        const entrada = campoTexto(accion.nombre, (v) => {
          accion.nombre = String(v || "").toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
          this.op.alCambiar?.();
          this.refrescar();
        }, "misiones");
        this.cuerpo.appendChild(fila("Interruptor", entrada));

        // Todos los que existen: los tuyos y los de las pantallas del juego.
        const opciones = [{ valor: "", texto: "(elige uno...)" }];
        for (const k of Object.keys(M.INTEGRADAS)) {
          const reemplazada = catalogo.find(e => (e.aperturas || {}).interruptor === k);
          opciones.push({ valor: k, texto: `${M.INTEGRADAS[k].titulo}${reemplazada ? " (la tuya)" : " (del juego)"}` });
        }
        for (const c of conocidos) {
          if (M.INTEGRADAS[c.interruptor]) continue;      // ya salio arriba
          opciones.push({ valor: c.interruptor, texto: `${c.interruptor} -> ${c.nombre}` });
        }
        this.cuerpo.appendChild(fila("O elige uno",
          desplegable(accion.nombre || "", opciones,
            (v) => { if (!v) return; accion.nombre = v; entrada.value = v; this.op.alCambiar?.(); this.refrescar(); })));

        const destino = M.destinoDeInterruptor(accion.nombre, catalogo);
        let ayuda;
        if (destino.tipo === "interfaz") ayuda = `Ahora mismo lleva a tu pantalla "${destino.nombre}".`;
        else if (destino.tipo === "integrada") ayuda = `Ahora mismo abre ${destino.titulo} del juego. Si algun dia haces tu propia version con este mismo interruptor, este boton pasara a abrir la tuya sin tocarlo.`;
        else if (accion.nombre) ayuda = `Todavia nada responde a "${accion.nombre}". Abre la pantalla que quieras que salga y ponle ese interruptor en "Como se abre en el juego".`;
        else ayuda = "Elige uno de la lista, o escribe un nombre nuevo y luego ponselo a la pantalla que quieras que se abra.";
        this.cuerpo.appendChild(h("div", { className: "ui-ayuda", textContent: ayuda }));
        break;
      }
      case "abrir_interfaz": {
        this.cuerpo.appendChild(this.filaPantalla("Cual", accion));
        this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
          textContent: "Esta se queda DEBAJO y vuelves a ella al cerrar la otra. Para un aviso o un \"¿seguro?\". Para navegar por un menu usa \"Ir a otra pantalla\"." }));
        break;
      }
      case "interruptor":
        // Por nombre, igual que en las condiciones: "0045: Derrotado Gim 4".
        this.cuerpo.appendChild(fila("Interruptor",
          desplegable(String(accion.numero || 1), P.opciones("interruptor", accion.numero),
            (v) => { accion.numero = parseInt(v, 10); this.op.alCambiar?.(); this.refrescar(); })));
        this.cuerpo.appendChild(fila("Ponerlo a",
          desplegable(String(accion.valor == null ? "true" : accion.valor),
            [{ valor: "true", texto: "Activado" }, { valor: "false", texto: "Desactivado" }, { valor: "cambiar", texto: "Al contrario de como este" }],
            (v) => { accion.valor = (v === "cambiar") ? "cambiar" : (v === "true"); this.op.alCambiar?.(); })));
        break;
      case "variable":
        this.cuerpo.appendChild(fila("Variable",
          desplegable(String(accion.numero || 1), P.opciones("variable", accion.numero),
            (v) => { accion.numero = parseInt(v, 10); this.op.alCambiar?.(); this.refrescar(); })));
        this.cuerpo.appendChild(fila("Operacion",
          desplegable(accion.operacion || "poner",
            [{ valor: "poner", texto: "Poner este valor" }, { valor: "sumar", texto: "Sumarle este valor" }],
            (v) => { accion.operacion = v; this.op.alCambiar?.(); })));
        this.cuerpo.appendChild(fila("Valor",
          campoNumero(accion.valor, (v) => { accion.valor = v; this.op.alCambiar?.(); })));
        break;
      case "sonido":
        this.cuerpo.appendChild(fila("Nombre", campoTexto(accion.nombre, (v) => { accion.nombre = v; this.op.alCambiar?.(); }, "GUI sel decision")));
        this.cuerpo.appendChild(h("div", { className: "ui-ayuda", textContent: "El nombre del fichero de Audio/SE, sin extension." }));
        break;
      case "script": {
        const area = h("textarea", { className: "ui-txt", rows: 4, style: { fontFamily: "ui-monospace, monospace", fontSize: "11px" } });
        area.value = accion.codigo || "";
        area.addEventListener("input", () => { accion.codigo = area.value; this.op.alCambiar?.(); });
        this.cuerpo.appendChild(area);
        this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
          textContent: "Ruby. Tienes disponible `escena`, asi que escena.resultado = :algo hace que pbInterfaz devuelva eso. Un fallo aqui se avisa en pantalla, no tira el juego." }));
        break;
      }
    }
  }

  //---------------------------------------------------------------------------
  // Efecto de entrada.
  //---------------------------------------------------------------------------
  pintarEntrada(el) {
    this.cuerpo.appendChild(titulillo("Como aparece"));
    const tiene = !!el.entrada;
    this.cuerpo.appendChild(fila("Animar entrada",
      casilla(tiene, (v) => {
        this.op.antesDeCambiar?.();          // quitarlo borra los ajustes del efecto
        if (v) el.entrada = { efecto: "aparece", duracion: M.ENTRADA_DURACION, suavizado: M.SUAVIZADO_DEFECTO, retraso: 0 };
        else delete el.entrada;
        this.op.alCambiar?.();
        this.refrescar();
      }, tiene ? "" : "aparece de golpe")));
    if (!tiene) return;

    const ent = el.entrada;
    this.cuerpo.appendChild(fila("Efecto",
      desplegable(ent.efecto || "aparece", M.EFECTOS, (v) => { ent.efecto = v; this.op.alCambiar?.(); this.refrescar(); })));
    // Velocidad de bolsillo. La casilla de segundos sigue estando para afinar,
    // pero elegir "muy lento" de una lista es mucho mas rapido que adivinar que
    // 1,2 segundos es lo que uno queria decir.
    const dur = M.num(ent.duracion, M.ENTRADA_DURACION);
    this.cuerpo.appendChild(fila("Velocidad",
      desplegable(M.velocidadDe(dur), M.VELOCIDADES,
        (v) => {
          const s = M.SEGUNDOS_VELOCIDAD[v];
          if (s == null) return;                    // "a medida": no toca nada
          ent.duracion = s;
          tocar();
          this.refrescar();
        })));
    this.cuerpo.appendChild(fila("Duracion",
      campoNumero(dur, (v) => { ent.duracion = v; this.op.alCambiar?.(); this.refrescar(); }, { paso: 0.05, min: 0, max: 10 }),
      h("span", { className: "ui-capa-tipo", textContent: "segundos" })));
    this.cuerpo.appendChild(fila("Suavizado",
      desplegable(ent.suavizado || M.SUAVIZADO_DEFECTO, M.SUAVIZADOS, (v) => { ent.suavizado = v; this.op.alCambiar?.(); })));
    this.cuerpo.appendChild(fila("Esperar",
      campoNumero(M.num(ent.retraso, 0), (v) => { ent.retraso = v || 0; this.op.alCambiar?.(); }, { paso: 0.05, min: 0 }),
      h("span", { className: "ui-capa-tipo", textContent: "segundos" })));
    if (String(ent.efecto || "").startsWith("desde_")) {
      this.cuerpo.appendChild(fila("Distancia",
        campoNumero(M.num(ent.distancia, M.DESLIZA_DISTANCIA), (v) => { ent.distancia = v == null ? null : Math.round(v); this.op.alCambiar?.(); })));
    }
    this.cuerpo.appendChild(h("div", { className: "ui-ayuda",
      textContent: "Escalonar los retrasos (0, 0.08, 0.16...) hace que los elementos entren en cascada, que queda mucho mejor que todos a la vez." }));
  }

  // Elegir una pantalla de destino. Desplegable con las que hay, para no tener
  // que escribir el nombre del fichero de memoria y equivocarse en una letra.
  filaPantalla(etiqueta, accion) {
    const lista = this.op.listaInterfaces?.() || [];
    if (!lista.length) {
      return fila(etiqueta, campoTexto(accion.interfaz, (v) => { accion.interfaz = v; this.op.alCambiar?.(); }, "nombre del fichero"));
    }
    return fila(etiqueta, desplegable(accion.interfaz || "",
      [{ valor: "", texto: "(elige una)" }, ...lista.map(n => ({ valor: n, texto: n }))],
      (v) => { accion.interfaz = v; this.op.alCambiar?.(); this.refrescar(); }));
  }

  //---------------------------------------------------------------------------
  // Elegir un grafico.
  //---------------------------------------------------------------------------
  filaGrafico(etiqueta, el, clave) {
    const entrada = campoTexto(el[clave], async (v) => {
      this.fijar(el, clave, v);
      await this.comprobarImagen(el, clave);
    }, "Graphics/UI/...");
    const btn = boton("Elegir...", async () => {
      const elegido = await this.elegirGrafico();
      if (!elegido) return;
      entrada.value = elegido;
      this.fijar(el, clave, elegido);
      await this.comprobarImagen(el, clave);
      this.refrescar();
    });
    return fila(etiqueta, entrada, btn);
  }

  //---------------------------------------------------------------------------
  // Comprueba que el juego va a poder abrir esa imagen, y si no, la arregla.
  //
  // Las webs de recursos dan WebP con nombre .png. El juego se cae al abrirlos
  // ("Unsupported image format") y ademas lo hace DELANTE DEL JUGADOR, no aqui.
  // Como el editor corre dentro de un navegador y el navegador si lee WebP, se
  // convierte a PNG de verdad al vuelo y se apunta la ruta nueva. Asi no hay que
  // pedirle a nadie que se busque un conversor.
  //---------------------------------------------------------------------------
  async comprobarImagen(el, clave) {
    const ruta = el[clave];
    if (!ruta) return;
    let dato;
    try { dato = await G.bytesDeImagen(ruta); } catch { return; }
    if (!dato) {
      this.op.avisar?.(`No encuentro ${ruta}`);
      return;
    }
    const formato = G.formatoReal(dato.bytes);
    if (G.FORMATOS_BUENOS.includes(formato)) return;

    this.op.avisar?.(`"${ruta}" dice ser una imagen pero por dentro es ${formato.toUpperCase()}. Convirtiendo a PNG...`);
    const nueva = await G.convertirAPng(dato.ruta, dato.bytes);
    if (!nueva) {
      this.op.avisar?.(`No he podido convertirla. El juego NO va a poder abrirla: guardala como PNG de verdad.`);
      return;
    }
    const sinExt = nueva.replace(/\.png$/i, "");
    this.fijar(el, clave, sinExt);
    this.op.avisar?.(`Convertida y guardada como ${nueva}. Ya la puede abrir el juego.`);
    this.refrescar();
  }

  // Aviso de tamaño. Una imagen de 700x700 en una pantalla de 512x384 no cabe, y
  // el juego no la encoge sola: se ve un trozo. Mejor decirlo aqui que dejar que
  // se descubra probando.
  avisoTamano(el) {
    const dato = G.imagenEnCache(el.imagen);
    if (!dato || !dato.ancho) return null;
    const grande = dato.ancho > M.LIENZO_ANCHO || dato.alto > M.LIENZO_ALTO;
    const texto = `La imagen mide ${dato.ancho}x${dato.alto}.` +
      (grande
        ? ` La pantalla es ${M.LIENZO_ANCHO}x${M.LIENZO_ALTO}, asi que NO CABE: solo se vera un trozo. Encogela con "Tamaño x" en Aspecto, o recortala antes.`
        : "");
    return h("div", { className: "ui-ayuda", textContent: texto });
  }

  async elegirGrafico() {
    // El selector nativo del editor si esta: trae miniaturas y conoce las
    // carpetas del proyecto, asi que siempre es mejor que uno propio.
    if (this.ctx?.selectors?.pickGraphic) {
      try {
        const r = await this.ctx.selectors.pickGraphic("UI");
        if (r) return this.normalizarRuta(typeof r === "string" ? r : (r.path || r.name || ""), "UI");
      } catch { /* si falla se cae al camino de abajo */ }
    }
    // Reserva: escribir la ruta a mano, listando lo que hay para ayudar.
    let pista = "";
    try {
      const carpetas = await G.carpetasGraficos(this.ctx);
      if (carpetas.length) pista = "\n\nCarpetas de Graphics/ con contenido: " + carpetas.join(", ");
    } catch { /* da igual */ }
    try {
      const r = await this.ctx.ui.showInputDialog({
        title: "Ruta del grafico",
        message: "Escribe la ruta desde la raiz del proyecto, sin extension. Por ejemplo: Graphics/UI/mi_menu/fondo" + pista,
        defaultValue: ""
      });
      return r ? this.normalizarRuta(String(r), "") : null;
    } catch { return null; }
  }

  // El diseño guarda la ruta como la espera Essentials: desde la raiz y SIN
  // extension, porque pbResolveBitmap le añade .png o .gif.
  normalizarRuta(bruto, subcarpeta) {
    let r = String(bruto || "").trim().replace(/\\/g, "/");
    if (!r) return "";
    r = r.replace(/\.(png|gif)$/i, "");
    if (!/^Graphics\//i.test(r)) {
      r = "Graphics/" + (subcarpeta ? subcarpeta + "/" : "") + r.replace(/^\/+/, "");
    }
    return r;
  }
}
