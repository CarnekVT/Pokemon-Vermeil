//=============================================================================
// El lienzo: dibuja el diseño y deja arrastrar y redimensionar con el raton.
//
// FIDELIDAD CON EL JUEGO
//   Esto vuelve a pintar en un canvas lo que el motor pinta con sprites de RGSS.
//   Dos detalles que hay que respetar o el editor miente:
//
//   1. El zoom y el giro se aplican desde el CENTRO del elemento. RGSS por si
//      solo lo hace desde la esquina, pero el motor pone el origen en el centro
//      a proposito (ver Elemento#actualizar en [003] Elementos.rb): girar desde
//      una esquina manda el elemento describiendo un arco, y no es lo que espera
//      nadie que haya usado un editor de imagenes.
//   2. El angulo de RGSS va en grados y en sentido ANTIHORARIO; el rotate del
//      canvas es horario. Por eso se pasa negado.
//
//   El texto se dibuja con la fuente de verdad del juego (Power Green, cargada
//   del proyecto) al mismo tamaño en pixeles. No es exacto al pixel porque el
//   trazado de fuentes de RGSS y el del navegador no son el mismo, pero las
//   cajas y las posiciones cuadran, que es para lo que sirve.
//=============================================================================

import { h, colorCss } from "./dom.js";
import * as M from "../modelo.js";
import * as G from "../graficos.js";
import * as D from "../datos.js";

// ¿El usuario esta escribiendo en un campo? Entonces las teclas son del campo y
// no atajos del lienzo. Sin esto, escribir un espacio en el nombre de un elemento
// activaria el modo de arrastrar el lienzo.
export function escribiendo(destino) {
  if (!destino || !destino.tagName) return false;
  return ["INPUT", "TEXTAREA", "SELECT"].includes(destino.tagName) || destino.isContentEditable;
}

const TIRADOR = 7;                 // lado del tirador de redimension, en pixeles de pantalla
const MINIMO = 2;                  // no se puede hacer un elemento mas pequeño que esto
const GIRO_DIST = 22;              // cuanto se separa la bolita de girar del borde de arriba
const GIRO_RADIO = 5;
const GIRO_PASO = 15;              // con Shift, el giro va a saltos de estos grados

// Los ocho tiradores, con el factor que aplican a x, y, ancho y alto.
const TIRADORES = [
  { id: "no", cx: 0,   cy: 0,   dx: 1, dy: 1, dw: -1, dh: -1 },
  { id: "n",  cx: 0.5, cy: 0,   dx: 0, dy: 1, dw: 0,  dh: -1 },
  { id: "ne", cx: 1,   cy: 0,   dx: 0, dy: 1, dw: 1,  dh: -1 },
  { id: "e",  cx: 1,   cy: 0.5, dx: 0, dy: 0, dw: 1,  dh: 0 },
  { id: "se", cx: 1,   cy: 1,   dx: 0, dy: 0, dw: 1,  dh: 1 },
  { id: "s",  cx: 0.5, cy: 1,   dx: 0, dy: 0, dw: 0,  dh: 1 },
  { id: "so", cx: 0,   cy: 1,   dx: 1, dy: 0, dw: -1, dh: 1 },
  { id: "o",  cx: 0,   cy: 0.5, dx: 1, dy: 0, dw: -1, dh: 0 }
];

// Hacia donde apunta cada tirador, en grados. Sirve para elegir el cursor: en un
// elemento girado, el tirador de la derecha ya no estira a lo ancho de la
// pantalla, y un cursor que apunte mal despista mas que ayuda.
const ANGULO_TIRADOR = { e: 0, se: 45, s: 90, so: 135, o: 180, no: 225, n: 270, ne: 315 };
const CURSORES_POR_ANGULO = ["ew-resize", "nwse-resize", "ns-resize", "nesw-resize",
                             "ew-resize", "nwse-resize", "ns-resize", "nesw-resize"];

export class Lienzo {
  constructor(opciones) {
    this.op = opciones;                 // {alSeleccionar, alCambiar, alMoverRaton}
    this.diseno = null;
    this.seleccion = null;
    this.extra = new Set();          // los demas marcados con Ctrl
    this.goma = null;                // rectangulo de goma mientras se arrastra
    this.tiempo = 0;
    this.zoom = 1;
    this.rejilla = true;
    this.imantar = true;
    this.simulaElegido = null;       // que boton se da por elegido (null = el de salida)
    this.verEscondidos = true;       // los que una condicion esconde, en fantasma
    this.pendientes = new Set();        // imagenes que se estan cargando

    // Dos capas: abajo el diseño a tamaño real y estirado picado (lo que se ve
    // en el juego), y encima los adornos del editor (rejilla, contorno,
    // tiradores) a resolucion de pantalla, para que sigan siendo finos y no se
    // conviertan en una escalera de pixeles ellos tambien.
    this.canvas = h("canvas", { className: "ui-lienzo" });
    this.ctx2d = this.canvas.getContext("2d");
    this.capa = h("canvas", { className: "ui-lienzo-capa" });
    this.ctxCapa = this.capa.getContext("2d");
    this.marco = h("div", { className: "ui-lienzo-marco" }, this.canvas, this.capa);
    this.el = h("div", { className: "ui-lienzo-zona" }, this.marco);

    this.arrastre = null;
    this.hayAnimadas = false;
    this.conectar();
    this.arrancarLatido();
  }

  //---------------------------------------------------------------------------
  fijarDiseno(diseno) { this.diseno = diseno; this.repintar(); }

  // "seleccion" es el elemento PRINCIPAL: el que enseña el inspector y el que
  // lleva los tiradores. "extra" son los demas marcados con Ctrl, que se mueven
  // con el pero no se editan uno a uno.
  //
  // Se guardan aparte en vez de una lista sin mas porque el inspector tiene que
  // enseñar UNO, y en un grupo hace falta saber cual manda al alinear.
  fijarSeleccion(id, extra) {
    this.seleccion = id;
    this.extra = new Set(extra || []);
    this.repintar();
  }

  // Todos los marcados, con el principal primero.
  marcados() {
    const salida = [];
    if (this.seleccion) salida.push(this.seleccion);
    for (const id of (this.extra || [])) if (id !== this.seleccion) salida.push(id);
    return salida;
  }

  elementosMarcados() {
    const lista = this.diseno?.elementos || [];
    return this.marcados().map(id => lista.find(e => e.id === id)).filter(Boolean);
  }
  fijarTiempo(t) { this.tiempo = t; this.repintar(); }
  fijarZoom(z) { this.fijarZoomHacia(z, null, null); }

  // Mantiene quieto el punto que el usuario esta mirando al cambiar el zoom.
  // A diferencia de la 1.6.1, la v2 admite zoom por debajo de 100% para que
  // canvases grandes (960x540, 1280x720...) quepan en el workspace.
  fijarZoomHacia(z, clienteX, clienteY) {
    const nuevo = Math.max(0.1, Math.min(6, Number(z) || 1));
    if (Math.abs(nuevo - this.zoom) < 0.0001) return;
    const zona = this.el;

    const cajaZona = zona.getBoundingClientRect();
    const px = (clienteX == null) ? cajaZona.left + (cajaZona.width / 2) : clienteX;
    const py = (clienteY == null) ? cajaZona.top + (cajaZona.height / 2) : clienteY;

    const antes = this.canvas.getBoundingClientRect();
    const disenoX = (px - antes.left) / this.zoom;
    const disenoY = (py - antes.top) / this.zoom;

    this.zoom = nuevo;
    this.repintar();

    const despues = this.canvas.getBoundingClientRect();
    zona.scrollLeft += (despues.left + (disenoX * nuevo)) - px;
    zona.scrollTop += (despues.top + (disenoY * nuevo)) - py;
  }

  encajar() {
    const aw = Math.max(80, this.el.clientWidth - 40);
    const ah = Math.max(80, this.el.clientHeight - 40);
    const maximo = Math.min(aw / this.ancho, ah / this.alto, 6);
    const niveles = [0.1, 0.125, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 6];
    let z = niveles[0];
    for (const n of niveles) if (n <= maximo + 0.001) z = n;
    this.fijarZoom(z);
    this.op.alCambiarZoom?.(z);
    return z;
  }

  redondear(v) {
    return this.diseno?.lienzo?.pixel_perfect === false ? Math.round(v * 10) / 10 : Math.round(v);
  }
  fijarRejilla(v) { this.rejilla = !!v; this.repintar(); }
  fijarImantar(v) { this.imantar = !!v; }
  fijarSimulaElegido(id) { this.simulaElegido = id || null; this.repintar(); }
  fijarVerEscondidos(v) { this.verEscondidos = !!v; this.repintar(); }

  get ancho() { return M.num(this.diseno?.lienzo?.ancho, M.LIENZO_ANCHO); }
  get alto() { return M.num(this.diseno?.lienzo?.alto, M.LIENZO_ALTO); }

  elementoElegido() {
    if (!this.diseno || !this.seleccion) return null;
    return (this.diseno.elementos || []).find(e => e.id === this.seleccion) || null;
  }

  //---------------------------------------------------------------------------
  // Pintado.
  //---------------------------------------------------------------------------
  // SE DIBUJA A TAMAÑO REAL (512x384) Y SE ESTIRA CON CSS, PICADO.
  //
  // Antes se dibujaba en un canvas ya escalado, o sea con la letra a doble o
  // triple resolucion, y salia mucho mas fina que en el juego. Eso convertia el
  // editor en un mentiroso bonito: enseñaba una calidad que el juego no puede
  // dar, porque el juego dibuja en 512x384 y luego estira la imagen entera.
  //
  // Dibujando 1:1 y dejando que el navegador lo estire con image-rendering
  // pixelated, se ve EXACTAMENTE la misma escalera de pixeles que en el juego.
  // Feo, pero verdad; y para cuadrar una pantalla la verdad es lo unico que vale.
  repintar() {
    if (!this.diseno) return;
    const z = this.zoom;
    const W = this.ancho, H = this.alto;
    if (this.canvas.width !== W || this.canvas.height !== H) {
      this.canvas.width = W;
      this.canvas.height = H;
    }
    // El tamaño en pantalla lo pone el CSS, no el canvas.
    this.canvas.style.width = (W * z) + "px";
    this.canvas.style.height = (H * z) + "px";

    // Se recalcula en cada pasada: si se quita el ultimo GIF, el latido para.
    this.hayAnimadas = false;

    const c = this.ctx2d;
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.clearRect(0, 0, W, H);

    // Fondo del lienzo: un gris neutro que representa "aqui se ve el mapa".
    c.fillStyle = "#20242b";
    c.fillRect(0, 0, W, H);

    c.imageSmoothingEnabled = false;

    // Pantalla completa: fondo opaco, el mapa no se ve. Si no, se oscurece lo
    // que diga el diseño y el gris de debajo hace de "aqui se vera el mapa".
    if (this.diseno.pantalla_completa) {
      c.fillStyle = colorCss(this.diseno.color_fondo || "#000000FF", "#000000FF");
      c.fillRect(0, 0, W, H);
    } else {
      const oscurecer = M.num(this.diseno.oscurecer_mapa, 0);
      if (oscurecer > 0) {
        c.fillStyle = `rgba(0,0,0,${Math.min(oscurecer, 255) / 255})`;
        c.fillRect(0, 0, W, H);
      }
    }

    // Se dibuja la lista EXPANDIDA: un grupo repetido se ve con sus seis copias,
    // igual que en el juego. Lo que se edita sigue siendo el elemento de origen.
    this.expandidos = M.expandirRepeticiones(this.diseno, (clave) => D.rellenarEjemplo(clave));
    // Y despues los huecos, en el MISMO orden que el motor (Repeticiones y luego
    // Huecos, ver [005] Escena.rb). Se pregunta si cada uno se veria AL ABRIR, sin
    // ningun boton elegido todavia, que es el momento exacto en que el juego los
    // reparte: mirando la seleccion de ahora, el editor colocaria los botones en
    // sitios en los que el juego no los pone nunca.
    M.colocarHuecos(this.diseno, this.expandidos, (el) => this.seVeAlAbrir(el));
    // Quien quedaria elegido al abrirse la pantalla. Se calcula UNA vez por
    // repintado y SIN mirar condiciones: si mirara condiciones, evaluar una
    // condicion sobre {seleccion} volveria a preguntar quien esta elegido y se
    // llamaria a si mismo sin parar.
    this._elegido = this.primerBoton();
    const ordenados = this.expandidos
      .map((el, i) => ({ el, i }))
      .sort((a, b) => (M.num(a.el.capa, 0) - M.num(b.el.capa, 0)) || (a.i - b.i));

    // UN ELEMENTO ESCONDIDO POR UNA CONDICION NO DESAPARECE: SE PINTA EN
    // FANTASMA.
    //
    // Antes se saltaba y ya. Eso dejaba a alguien sin poder trabajar: pones a un
    // texto "se ve cuando esta elegido el boton 3", se esfuma del lienzo, y ya no
    // puedes ni verlo ni colocarlo. Quien lo probo entendio que la condicion no
    // funcionaba, cuando en el juego iba bien.
    //
    // En fantasma se sigue viendo donde esta y se puede seguir moviendo, y a la
    // vez queda claro que ahora mismo no se veria. Y el que este marcado se pinta
    // SIEMPRE, aunque los fantasmas esten apagados: no se puede editar algo que
    // no se ve.
    this.fantasmas = [];
    const marcados = new Set(this.marcados());
    for (const { el } of ordenados) {
      if (el.visible === false) continue;
      if (!this.visiblePorCondicion(el)) {
        const suyo = marcados.has(el._origen || el.id);
        if (!this.verEscondidos && !suyo) continue;
        this.fantasmas.push(el);
        // El marcado se ve mas, porque es el que se esta editando.
        this.pintarElemento(c, el, suyo ? 0.55 : 0.22);
        continue;
      }
      this.pintarElemento(c, el);
    }

    this.repintarCapa();
  }

  // Los adornos del editor, encima y a resolucion de pantalla.
  repintarCapa() {
    const z = this.zoom;
    const W = this.ancho, H = this.alto;
    if (this.capa.width !== W * z || this.capa.height !== H * z) {
      this.capa.width = W * z;
      this.capa.height = H * z;
    }
    this.capa.style.width = (W * z) + "px";
    this.capa.style.height = (H * z) + "px";

    const c = this.ctxCapa;
    c.setTransform(1, 0, 0, 1, 0, 0);
    c.clearRect(0, 0, this.capa.width, this.capa.height);
    if (this.rejilla) this.pintarRejilla(c, W, H, z);
    if (this.diseno?.lienzo?.safe_area) this.pintarAreaSegura(c, W, H, z);
    this.pintarFantasmas(c);
    this.pintarSeleccion(c);
  }

  pintarAreaSegura(c, W, H, z) {
    // 5% on each side: a guide only, never modifies game coordinates.
    const mx = Math.round(W * 0.05) * z;
    const my = Math.round(H * 0.05) * z;
    c.save();
    c.strokeStyle = "rgba(255,210,90,0.72)";
    c.lineWidth = 1;
    c.setLineDash([6, 4]);
    c.strokeRect(mx + 0.5, my + 0.5, W * z - mx * 2 - 1, H * z - my * 2 - 1);
    c.restore();
  }

  //---------------------------------------------------------------------------
  // LOS QUE AHORA MISMO NO SE VERIAN, con un contorno de rayas naranja.
  //
  // Con la transparencia sola no basta: un elemento a medio pintar puede ser una
  // imagen que de verdad es tenue. El contorno dice "esto es que una condicion lo
  // esta escondiendo", que es una cosa distinta.
  //---------------------------------------------------------------------------
  pintarFantasmas(c) {
    for (const el of (this.fantasmas || [])) {
      const r = this.rectanguloPantalla(el);
      if (!r) continue;
      c.save();
      c.strokeStyle = "rgba(232,160,60,0.75)";
      c.lineWidth = 1;
      c.setLineDash([2, 3]);
      const v = [[0, 0], [1, 0], [1, 1], [0, 1]]
        .map(([u, w]) => this.girar(r, r.x + r.w * u, r.y + r.h * w));
      c.beginPath();
      c.moveTo(v[0].x + 0.5, v[0].y + 0.5);
      for (let i = 1; i < 4; i++) c.lineTo(v[i].x + 0.5, v[i].y + 0.5);
      c.closePath();
      c.stroke();
      c.restore();
    }
  }

  pintarRejilla(c, W, H, z) {
    const paso = M.REJILLA * z;
    c.save();
    c.strokeStyle = "rgba(255,255,255,0.07)";
    c.lineWidth = 1;
    c.beginPath();
    for (let x = paso; x < W * z; x += paso) { c.moveTo(x + 0.5, 0); c.lineTo(x + 0.5, H * z); }
    for (let y = paso; y < H * z; y += paso) { c.moveTo(0, y + 0.5); c.lineTo(W * z, y + 0.5); }
    c.stroke();
    // El centro, que es la guia que mas se usa para centrar cosas.
    c.strokeStyle = "rgba(120,180,255,0.18)";
    c.beginPath();
    c.moveTo((W * z) / 2, 0); c.lineTo((W * z) / 2, H * z);
    c.moveTo(0, (H * z) / 2); c.lineTo(W * z, (H * z) / 2);
    c.stroke();
    c.restore();
  }

  //---------------------------------------------------------------------------
  // EL EDITOR TIENE QUE ESCONDER LO MISMO QUE EL JUEGO.
  //
  // Antes el lienzo no miraba "mostrar_si" y dibujaba TODO. En una ficha con dos
  // insignias de sexo excluyentes salian las dos, una encima de otra, y parecia
  // que todos los Pokemon iban a ser del mismo sexo. El diseño estaba bien; el
  // que mentia era el editor.
  //
  // Se evalua con los valores de ejemplo del catalogo, los mismos que ya se usan
  // para los textos.
  //---------------------------------------------------------------------------
  visiblePorCondicion(el) {
    if (!el.mostrar_si) return true;
    return M.cumpleCondicion(el.mostrar_si, (clave) => this.valorEjemplo(clave));
  }

  // Lo mismo pero en el instante de abrir la pantalla, cuando todavia no hay nada
  // elegido. Es lo que decide quien ocupa hueco, porque es cuando el motor los
  // reparte. Cuenta tambien el ojo de la lista de capas: apagarlo escribe
  // "visible": false en el diseño de verdad, asi que es la manera de ver aqui como
  // queda el menu con una prenda bloqueada.
  seVeAlAbrir(el) {
    if (el.visible === false) return false;
    if (!el.mostrar_si) return true;
    return M.cumpleCondicion(el.mostrar_si, (clave) => {
      const sel = M.valorSeleccion(clave, null);
      return (sel !== null) ? sel : D.rellenarEjemplo("{" + clave + "}");
    });
  }

  // Un boton apagado se dibuja como en el juego: sin color y medio transparente.
  // Sin esto el editor enseñaria un boton normal y corriente y la unica manera de
  // ver que esta bloqueado seria abrir el juego.
  //
  // Se mira con los valores de ejemplo, igual que "mostrar_si": no es una promesa
  // de que en la partida vaya a estar apagado, es enseñar como queda cuando lo
  // este.
  botonApagado(el) {
    if (el.tipo !== "boton" || !el.activo_si) return false;
    return !M.cumpleCondicion(el.activo_si, (clave) => this.valorEjemplo(clave));
  }

  valorEjemplo(clave) {
    // {seleccion...} no sale del catalogo: depende de ESTA pantalla, asi que hay
    // que simularlo. La cuenta esta en modelo.js, con las tres formas y probada
    // contra la de Ruby.
    //
    // Aqui antes solo se contestaban dos ({seleccion} y {seleccion.id}) y la que
    // faltaba era justo la que escribe el desplegable "cuando este elegido tal
    // boton". Devolvia el hueco, la condicion no se cumplia y el elemento
    // desaparecia del lienzo aunque en el juego se viera perfectamente.
    const sel = M.valorSeleccion(clave, this._elegido);
    if (sel !== null) return sel;
    return D.rellenarEjemplo("{" + clave + "}");
  }

  // QUE BOTON SE DA POR ELEGIDO AL DIBUJAR.
  //
  // Normalmente el que quedaria elegido al abrirse la pantalla, con el mismo
  // criterio que el motor (primero el orden_teclado que se haya puesto, y si no,
  // de arriba abajo y de izquierda a derecha).
  //
  // Pero se puede fijar otro a mano, y hace falta: una pantalla suele tener un
  // elemento por cada opcion ("se ve cuando esta elegido el boton 3"), y con un
  // solo elegido posible los de los demas botones no se podrian ver NUNCA en el
  // editor. Con esto se recorren los estados uno por uno, como con la linea de
  // tiempo de las animaciones.
  //
  // Se mira la lista EXPANDIDA, no la de origen: en una lista repetida el que
  // queda elegido es la primera COPIA, y de ella sale el numero que compara
  // {seleccion}.
  botonesDibujados() {
    return (this.expandidos || this.diseno?.elementos || [])
      .filter(e => e.tipo === "boton" && e.visible !== false);
  }

  primerBoton() {
    const botones = this.botonesDibujados();
    if (!botones.length) return null;
    // Si se ha pedido simular uno concreto, manda ese. Vale tanto el nombre de la
    // copia como el del elemento del diseño, igual que en el juego.
    if (this.simulaElegido) {
      const n = String(this.simulaElegido).toLowerCase();
      const suyo = botones.find(b => String(b.id).toLowerCase() === n ||
                                     String(b._origen || "").toLowerCase() === n);
      if (suyo) return suyo;
    }
    return botones.slice().sort((a, b) => {
      const oa = a.orden_teclado == null ? 1 : 0, ob = b.orden_teclado == null ? 1 : 0;
      if (oa !== ob) return oa - ob;
      if (M.num(a.orden_teclado, 0) !== M.num(b.orden_teclado, 0)) return M.num(a.orden_teclado, 0) - M.num(b.orden_teclado, 0);
      if (M.num(a.y, 0) !== M.num(b.y, 0)) return M.num(a.y, 0) - M.num(b.y, 0);
      return M.num(a.x, 0) - M.num(b.x, 0);
    })[0];
  }

  // Coloca el canvas en el estado que pide el elemento (posicion, giro, zoom,
  // transparencia) y llama al dibujo concreto.
  //
  // "factorAlfa" multiplica la transparencia del propio elemento, y es lo que
  // pinta los fantasmas. Va como parametro y no tocando globalAlpha por fuera
  // porque aqui abajo se ASIGNA (no se multiplica), asi que cualquier cosa puesta
  // antes se perderia sin dejar rastro.
  pintarElemento(c, el, factorAlfa = 1) {
    let x = M.valorDe(el, "x", this.tiempo);
    let y = M.valorDe(el, "y", this.tiempo);

    // El cursor no se dibuja donde dice su x,y: se pega al boton elegido, igual
    // que hara en el juego. Si no, el editor enseñaria la flecha en una esquina
    // y en el juego apareceria en otro sitio.
    if (el.sigue_seleccion) {
      const destino = this._elegido || this.primerBoton();
      if (destino) {
        const mc = this.medidaElemento(el);
        const mb = this.medidaElemento(destino);
        x = M.num(destino.x, 0) + M.num(el.cursor_x, 0);
        y = M.num(destino.y, 0) + Math.floor((mb.h - mc.h) / 2) + M.num(el.cursor_y, 0);
      }
    }
    const op = M.valorDe(el, "opacidad", this.tiempo);
    const zoom = M.valorDe(el, "zoom", this.tiempo);
    const ang = M.valorDe(el, "angulo", this.tiempo);
    // La caja que ocupa: la que pida el diseño, o la de su imagen si no pide
    // ninguna. Todo lo de dentro se dibuja de 0,0 a m.w,m.h.
    const m = this.medidaElemento(el);

    // UN BOTON APAGADO SE VE APAGADO, con los mismos numeros que el motor
    // (Interfaces::APAGADO_OPACIDAD y APAGADO_GRIS). Salvo que tenga arte propio
    // de apagado: entonces manda el dibujo y no se le echa gris encima, igual que
    // en Boton#apagado_a_mano?.
    const apagado = this.botonApagado(el);
    const conArte = apagado && (el.imagen ? !!el.imagen_apagado : !!el.color_apagado);

    c.save();
    c.globalAlpha = (Math.max(0, Math.min(255, op)) / 255) * factorAlfa *
                    ((apagado && !conArte) ? M.APAGADO_OPACIDAD : 1);
    if (apagado && !conArte) c.filter = "grayscale(1)";
    // El eje va al CENTRO, se gira y se escala, y luego se vuelve a la esquina
    // para dibujar. Es lo mismo que hace el motor poniendo ox y oy en el centro.
    c.translate(x + m.w / 2, y + m.h / 2);
    if (ang) c.rotate(-ang * Math.PI / 180);      // RGSS gira al contrario
    if (zoom !== 1) c.scale(zoom, zoom);
    c.translate(-m.w / 2, -m.h / 2);

    switch (el.tipo) {
      case "panel":   this.pintarPanel(c, el, m); break;
      case "texto":   this.pintarTexto(c, el, m); break;
      case "boton":   this.pintarBoton(c, el, m); break;
      case "imagen":  this.pintarImagen(c, el, el.imagen, m); break;
      case "animado": this.pintarAnimado(c, el, m); break;
      case "ventana": this.pintarVentana(c, el, m); break;
      case "barra":   this.pintarBarra(c, el, m); break;
      case "pokemon": this.pintarPokemon(c, el, m); break;
    }
    c.restore();
  }

  pintarPanel(c, el, m) {
    this.recuadro(c, 0, 0, m.w, m.h, colorCss(el.color, "#000000FF"),
      el.borde ? colorCss(el.borde, "#FFFFFFFF") : null,
      el.borde_grosor == null ? 1 : M.num(el.borde_grosor, 1));
  }

  pintarTexto(c, el, m) {
    // Se enseña el VALOR DE EJEMPLO, no las llaves: asi se ve el hueco que va a
    // ocupar de verdad en el juego y se puede cuadrar.
    const txt = D.rellenarEjemplo(el.texto);
    const tam = M.num(el.tamano, M.TEXTO_TAMANO);
    const w = m.w, hh = m.h;
    this.escribir(c, txt, 0, 0, w, hh, tam, {
      alineacion: el.alineacion,
      vertical: el.alineacion_vertical,
      desplazar: M.num(el.desplazar_y, 0),
      contorno: el.contorno,
      color: colorCss(el.color, M.TEXTO_COLOR),
      sombra: colorCss(el.sombra, M.TEXTO_SOMBRA)
    });
  }

  // El ancho del texto, y de paso la caja de linea.
  medirTexto(c, txt, tam) {
    c.font = G.fuenteSegunTamano(tam);
    const m = c.measureText(txt);
    const asc = m.fontBoundingBoxAscent != null ? m.fontBoundingBoxAscent : tam * 0.8;
    const desc = m.fontBoundingBoxDescent != null ? m.fontBoundingBoxDescent : tam * 0.2;
    return { ancho: m.width, alto: asc + desc, subida: asc };
  }

  // DONDE ESTA LA TINTA de una muestra fija, medida desde la linea base.
  //
  // Espejo de Interfaces.metricas en Ruby, que lo saca escaneando pixeles. Aqui
  // el canvas lo da hecho con actualBoundingBox, que son los limites REALES de lo
  // que se pinta (no la caja de linea de la fuente, que lleva hueco de sobra
  // repartido de forma desigual).
  //
  // Se mide una muestra FIJA, no el texto de cada elemento, para que todos los
  // textos compartan la misma linea base y no bailen segun lleven o no una "g".
  metricasTinta(c, tam) {
    this._tinta = this._tinta || {};
    if (this._tinta[tam]) return this._tinta[tam];
    c.font = G.fuenteSegunTamano(tam);
    const m = c.measureText(M.MUESTRA_METRICA);
    const subida = m.actualBoundingBoxAscent != null ? m.actualBoundingBoxAscent : tam * 0.72;
    const bajada = m.actualBoundingBoxDescent != null ? m.actualBoundingBoxDescent : tam * 0.22;
    this._tinta[tam] = { subida, bajada, alto: subida + bajada };
    return this._tinta[tam];
  }

  // ESPEJO DE Interfaces.escribir EN RUBY. Misma cuenta: se coloca por la TINTA,
  // o sea por lo que se ve, no por una caja invisible de la fuente. Si una de las
  // dos cambia, hay que cambiar la otra o el editor vuelve a mentir.
  escribir(c, txt, x, y, ancho, alto, tam, op) {
    if (!txt) return;
    const t = this.metricasTinta(c, tam);
    c.font = G.fuenteSegunTamano(tam);
    const al = op.alineacion || "izquierda";
    c.textAlign = al === "centro" ? "center" : (al === "derecha" ? "right" : "left");
    const tx = x + (al === "centro" ? ancho / 2 : (al === "derecha" ? ancho : 0));

    // Donde tiene que caer el borde de arriba de la tinta.
    let tintaArriba;
    if (op.vertical === "arriba") tintaArriba = 0;
    else if (op.vertical === "abajo") tintaArriba = alto - t.alto;
    else tintaArriba = Math.round((alto - t.alto) / 2);
    tintaArriba += M.num(op.desplazar, 0);

    c.textBaseline = "alphabetic";
    const base = y + tintaArriba + t.subida;
    if (op.sombra) {
      c.fillStyle = op.sombra;
      if (op.contorno) {
        // Ocho pasadas alrededor, las mismas que hace el motor.
        for (const [dx, dy] of [[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]]) {
          c.fillText(txt, tx + dx, base + dy);
        }
      } else {
        c.fillText(txt, tx + 1, base + 1);
      }
    }
    c.fillStyle = op.color;
    c.fillText(txt, tx, base);
  }

  // Rectangulo con borde. Espejo de Interfaces.recuadro en Ruby.
  recuadro(c, x, y, ancho, alto, relleno, borde, grosor) {
    if (relleno) { c.fillStyle = relleno; c.fillRect(x, y, ancho, alto); }
    if (!borde || grosor <= 0) return;
    let g = Math.min(grosor, Math.floor(Math.min(ancho, alto) / 2));
    if (g < 1) g = 1;
    c.fillStyle = borde;
    c.fillRect(x, y, ancho, g);
    c.fillRect(x, y + alto - g, ancho, g);
    c.fillRect(x, y, g, alto);
    c.fillRect(x + ancho - g, y, g, alto);
  }

  pintarBoton(c, el, m) {
    // Con arte de apagado manda ese, como en Boton#pintar_estado del motor.
    const apagado = this.botonApagado(el);
    const conImagen = !!el.imagen;
    if (conImagen) {
      this.pintarImagen(c, el, (apagado && el.imagen_apagado) || el.imagen, m);
      return;
    }

    const w = m.w, hh = m.h;
    const relleno = (apagado && el.color_apagado) ? el.color_apagado : el.color;
    const cerco = (apagado && el.borde_apagado) ? el.borde_apagado : el.borde;
    this.recuadro(c, 0, 0, w, hh, colorCss(relleno, M.BOTON_COLOR),
      el.borde ? colorCss(cerco, "#FFFFFFFF") : null,
      el.borde_grosor == null ? 1 : M.num(el.borde_grosor, 1));

    const txt = D.rellenarEjemplo(el.texto);
    if (!txt) return;
    const tam = M.num(el.tamano, M.TEXTO_TAMANO);
    this.escribir(c, txt, 0, 0, w, hh, tam, {
      alineacion: el.alineacion || "centro",
      vertical: el.alineacion_vertical,
      desplazar: M.num(el.desplazar_y, 0),
      contorno: el.contorno,
      color: colorCss(el.color_texto, M.TEXTO_COLOR),
      sombra: colorCss(el.sombra, M.TEXTO_SOMBRA)
    });
  }

  // Se dibuja al tamaño de la CAJA, no al de la imagen: si el diseño pide un
  // ancho y un alto, la imagen se estira hasta ahi. En el juego eso lo hacen
  // zoom_x y zoom_y por separado (ver Elemento#estirado), que es lo mismo.
  pintarImagen(c, el, ruta, m) {
    const dato = this.pedirImagen(ruta);
    if (!dato) { this.pintarHueco(c, el, ruta ? "?" : "", m); return; }
    c.drawImage(dato.img, 0, 0, m.w, m.h);
  }

  pintarAnimado(c, el, m) {
    const dato = this.pedirImagen(el.imagen);
    if (!dato) { this.pintarHueco(c, el, "?", m); return; }
    const n = Math.max(M.num(el.fotogramas, 1), 1);
    const fw = M.num(el.ancho_fotograma, 0) > 0 ? M.num(el.ancho_fotograma, 0) : Math.floor(dato.ancho / n);
    const fh = M.num(el.alto_fotograma, 0) > 0 ? M.num(el.alto_fotograma, 0) : dato.alto;
    const porFila = Math.max(Math.floor(dato.ancho / Math.max(fw, 1)), 1);

    // Que fotograma toca ahora. El motor cambia cada velocidad/20 segundos.
    const vel = Math.max(M.num(el.velocidad, 2), 1);
    const porSeg = 20 / vel;
    const cual = Math.floor(this.tiempo * porSeg) % n;
    const sx = (cual % porFila) * fw;
    const sy = Math.floor(cual / porFila) * fh;
    c.drawImage(dato.img, sx, sy, fw, fh, 0, 0, m.w, m.h);
  }

  // EL MARCO DE NUEVE TROZOS.
  //
  // Un windowskin de menu es de 48x48: nueve piezas de 16x16. Las esquinas van a
  // tamaño fijo, los bordes se estiran a lo largo y el centro rellena. Es lo mismo
  // que hace RGSS por dentro, y hay que hacerlo aqui tambien o el editor
  // enseñaria un rectangulo donde el juego pinta un marco.
  pintarVentana(c, el, m) {
    const w = m.w, hh = m.h;
    const nombre = el.marco || M.MARCO_DEFECTO;
    const dato = this.pedirImagen("Graphics/Windowskins/" + nombre);

    const formato = dato ? M.formatoMarco(dato.ancho, dato.alto) : "ninguno";
    if (dato && dato.img && formato === "clasico") { this.marcoClasico(c, dato, w, hh); return; }
    if (!dato || !dato.img || formato !== "3x3") {
      // Sin el marco cargado (o con un formato que no es 3x3), se dibuja un hueco
      // para poder colocarlo igual, en vez de no pintar nada.
      c.save();
      c.fillStyle = "rgba(20,28,42,0.85)";
      c.fillRect(0, 0, w, hh);
      c.strokeStyle = "rgba(140,190,255,0.85)";
      c.setLineDash([4, 3]);
      c.strokeRect(0.5, 0.5, w - 1, hh - 1);
      c.restore();
      return;
    }

    const p = dato.ancho / 3;                    // lado de cada pieza
    const q = Math.min(p, Math.floor(w / 2), Math.floor(hh / 2));
    const img = dato.img;
    const trozo = (sx, sy, sw, sh, dx, dy, dw, dh) => {
      if (dw <= 0 || dh <= 0) return;
      c.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
    };
    const centroW = w - q * 2, centroH = hh - q * 2;

    trozo(p, p, p, p, q, q, centroW, centroH);               // fondo
    trozo(p, 0, p, p, q, 0, centroW, q);                     // arriba
    trozo(p, p * 2, p, p, q, hh - q, centroW, q);            // abajo
    trozo(0, p, p, p, 0, q, q, centroH);                     // izquierda
    trozo(p * 2, p, p, p, w - q, q, q, centroH);             // derecha
    trozo(0, 0, p, p, 0, 0, q, q);                           // esquinas
    trozo(p * 2, 0, p, p, w - q, 0, q, q);
    trozo(0, p * 2, p, p, 0, hh - q, q, q);
    trozo(p * 2, p * 2, p, p, w - q, hh - q, q, q);
  }

  // EL WINDOWSKIN CLASICO DE RPG MAKER (192x128 o 128x128).
  //
  // No es un 3x3: el fondo y el borde estan en sitios distintos de la imagen.
  //   (0,0,128,128)    el fondo, que se estira para rellenar
  //   (128,0,64,64)    el borde, en nueve piezas de 16 y 32
  // Dibujarlo con la cuenta del 3x3 daba una mancha deforme, que es justo lo que
  // se veia.
  marcoClasico(c, dato, w, hh) {
    const img = dato.img;
    const t = (sx, sy, sw, sh, dx, dy, dw, dh) => {
      if (dw <= 0 || dh <= 0) return;
      c.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
    };
    const q = Math.min(16, Math.floor(w / 2), Math.floor(hh / 2));
    // Fondo estirado, dejando el borde fuera.
    t(0, 0, 128, 128, q / 2, q / 2, Math.max(w - q, 0), Math.max(hh - q, 0));
    const cw = w - q * 2, ch = hh - q * 2;
    t(144, 0, 32, 16, q, 0, cw, q);              // arriba
    t(144, 48, 32, 16, q, hh - q, cw, q);        // abajo
    t(128, 16, 16, 32, 0, q, q, ch);             // izquierda
    t(176, 16, 16, 32, w - q, q, q, ch);         // derecha
    t(128, 0, 16, 16, 0, 0, q, q);               // esquinas
    t(176, 0, 16, 16, w - q, 0, q, q);
    t(128, 48, 16, 16, 0, hh - q, q, q);
    t(176, 48, 16, 16, w - q, hh - q, q, q);
  }

  // Barra: se enseña a la mitad, que es lo util para cuadrar (llena o vacia no
  // deja ver donde queda el borde de relleno).
  pintarBarra(c, el, m) {
    const w = m.w, hh = m.h;
    const f = 0.6;                       // muestra: algo mas de la mitad

    // CON GRAFICO. La imagen es una tira con un estado por fila (llena, media,
    // baja), igual que overlay_hp.png de Essentials. Si el editor pintara aqui un
    // rectangulo de color, enseñaria una barra que el juego no va a dibujar.
    if (el.imagen) {
      const fondo = this.pedirImagen(el.imagen_fondo);
      if (fondo) c.drawImage(fondo.img, 0, 0, w, hh);
      const tira = this.pedirImagen(el.imagen);
      if (tira) {
        const filas = Math.max(M.num(el.tramos_imagen, 3), 1);
        const altoFila = Math.max(Math.floor(tira.alto / filas), 1);
        // A 0.6 toca la fila de arriba, que es la de "llena".
        c.drawImage(tira.img, 0, 0, Math.round(tira.ancho * f), altoFila,
                    0, 0, Math.round(w * f), hh);
      } else if (!fondo) {
        this.pintarHueco(c, el, "?", m);
      }
      return;
    }

    const g = el.borde_grosor == null ? 1 : M.num(el.borde_grosor, 1);
    this.recuadro(c, 0, 0, w, hh, colorCss(el.color_fondo, "#20242BFF"),
      el.borde ? colorCss(el.borde, "#FFFFFFFF") : null, g);
    const dentro = el.borde ? g : 0;
    const utilW = w - dentro * 2, utilH = hh - dentro * 2;
    if (utilW <= 0 || utilH <= 0) return;
    const largo = Math.max(Math.round(utilW * f), 1);
    c.fillStyle = colorCss(el.color, "#68D076FF");
    if (String(el.hacia) === "izquierda") c.fillRect(dentro + utilW - largo, dentro, largo, utilH);
    else c.fillRect(dentro, dentro, largo, utilH);
  }

  // Pokemon: en el editor no hay partida, asi que se dibuja un hueco con su
  // medida real de icono para poder colocarlo.
  pintarPokemon(c, el, m) {
    c.save();
    c.strokeStyle = "rgba(120,200,255,0.9)";
    c.setLineDash([3, 2]);
    c.strokeRect(0.5, 0.5, m.w - 1, m.h - 1);
    c.setLineDash([]);
    c.fillStyle = "rgba(120,200,255,0.9)";
    c.font = "9px sans-serif";
    c.textAlign = "center";
    c.textBaseline = "middle";
    c.fillText("POKE " + M.num(el.cual, 1), m.w / 2, m.h / 2);
    c.restore();
  }

  // Un elemento sin imagen: un recuadro a rayas para que se vea que esta ahi y
  // se pueda seleccionar y mover. Si no, seria invisible e imposible de tocar.
  pintarHueco(c, el, marca, m) {
    const w = m.w, hh = m.h;
    c.save();
    c.strokeStyle = "rgba(255,140,120,0.9)";
    c.setLineDash([3, 2]);
    c.lineWidth = 1;
    c.strokeRect(0.5, 0.5, w - 1, hh - 1);
    if (marca) {
      c.setLineDash([]);
      c.fillStyle = "rgba(255,140,120,0.9)";
      c.font = "10px sans-serif";
      c.textAlign = "center";
      c.textBaseline = "middle";
      c.fillText(marca, w / 2, hh / 2);
    }
    c.restore();
  }

  // Pide una imagen. Si no esta en cache lanza la carga y repinta al llegar. Se
  // recuerda lo pendiente para no lanzar la misma carga en cada repintado.
  pedirImagen(ruta) {
    if (!ruta) return null;
    const enCache = G.imagenEnCache(ruta);
    if (enCache !== undefined) {
      if (enCache && enCache.img) {
        // Un GIF animado sigue corriendo dentro del <img>, y drawImage pinta el
        // fotograma de ese instante. Para verlo moverse aqui igual que en el
        // juego hay que repintar seguido: se enciende el latido.
        if (enCache.animada) this.hayAnimadas = true;
        return enCache;
      }
      return null;
    }
    if (this.pendientes.has(ruta)) return null;
    this.pendientes.add(ruta);
    G.imagenDibujable(ruta).then(() => {
      this.pendientes.delete(ruta);
      this.repintar();
    });
    return null;
  }

  // Repinta 15 veces por segundo MIENTRAS HAYA algun GIF a la vista. No se deja
  // corriendo siempre a proposito: sin GIFs el lienzo solo se repinta cuando algo
  // cambia, y asi el editor no calienta el portatil por enseñar algo quieto.
  arrancarLatido() {
    if (this._latiendo) return;
    this._latiendo = true;
    const paso = () => {
      if (!this.el.isConnected) { this._latiendo = false; return; }
      if (this.hayAnimadas) this.repintar();
      setTimeout(paso, 66);
    };
    setTimeout(paso, 66);
  }

  //---------------------------------------------------------------------------
  // Contorno y tiradores del elemento elegido.
  //---------------------------------------------------------------------------
  pintarSeleccion(c) {
    // Los acompañantes, con un contorno mas tenue: se ve que se van a mover
    // juntos, pero no compiten con el principal ni llevan tiradores.
    for (const otro of this.elementosMarcados()) {
      if (otro.id === this.seleccion) continue;
      const ro = this.rectanguloPantalla(otro);
      if (!ro) continue;
      c.save();
      c.strokeStyle = "rgba(75,159,234,0.55)";
      c.lineWidth = 1;
      c.setLineDash([3, 3]);
      const v = [[0, 0], [1, 0], [1, 1], [0, 1]].map(([u, w]) => this.girar(ro, ro.x + ro.w * u, ro.y + ro.h * w));
      c.beginPath();
      c.moveTo(v[0].x + 0.5, v[0].y + 0.5);
      for (let i = 1; i < 4; i++) c.lineTo(v[i].x + 0.5, v[i].y + 0.5);
      c.closePath();
      c.stroke();
      c.restore();
    }

    // El rectangulo de goma, mientras se arrastra por un hueco vacio.
    if (this.goma) {
      const g = this.goma;
      c.save();
      c.strokeStyle = "#4b9fea";
      c.fillStyle = "rgba(75,159,234,0.12)";
      c.lineWidth = 1;
      const x = Math.min(g.x0, g.x1), y = Math.min(g.y0, g.y1);
      const w = Math.abs(g.x1 - g.x0), hh = Math.abs(g.y1 - g.y0);
      c.fillRect(x, y, w, hh);
      c.strokeRect(x + 0.5, y + 0.5, w, hh);
      c.restore();
    }

    const el = this.elementoElegido();
    if (!el) return;
    const r = this.rectanguloPantalla(el);
    if (!r) return;
    // Los cuatro vertices YA GIRADOS. Con un rectangulo recto no valdria: un
    // elemento de lado se enseñaria con un contorno derecho y los tiradores
    // caerian donde no esta.
    const v = [[0, 0], [1, 0], [1, 1], [0, 1]].map(([u, w]) =>
      this.girar(r, r.x + r.w * u, r.y + r.h * w));

    c.save();
    c.strokeStyle = "#4b9fea";
    c.lineWidth = 1;
    c.setLineDash([4, 3]);
    c.beginPath();
    c.moveTo(v[0].x + 0.5, v[0].y + 0.5);
    for (let i = 1; i < 4; i++) c.lineTo(v[i].x + 0.5, v[i].y + 0.5);
    c.closePath();
    c.stroke();
    c.setLineDash([]);

    if (this.transformable(el)) {
      // El palito y la bolita de girar, que salen del borde de arriba.
      const g = this.puntoGiro(r);
      const arriba = this.girar(r, r.x + r.w / 2, r.y);
      c.beginPath();
      c.moveTo(arriba.x, arriba.y);
      c.lineTo(g.x, g.y);
      c.stroke();
      c.fillStyle = "#fff";
      c.beginPath();
      c.arc(g.x, g.y, GIRO_RADIO, 0, Math.PI * 2);
      c.fill();
      c.stroke();

      for (const t of TIRADORES) {
        const p = this.puntoTirador(r, t);
        c.fillRect(p.x - TIRADOR / 2, p.y - TIRADOR / 2, TIRADOR, TIRADOR);
        c.strokeRect(p.x - TIRADOR / 2 + 0.5, p.y - TIRADOR / 2 + 0.5, TIRADOR - 1, TIRADOR - 1);
      }
    }
    c.restore();
  }

  // Todo se puede estirar y girar, incluidas las imagenes: si el diseño pide un
  // ancho y un alto, el motor los traduce a zoom_x y zoom_y por separado. Lo
  // unico que se respeta es el candado.
  transformable(el) {
    return !!el && el.bloqueado !== true;
  }

  puntoTirador(r, t) {
    return this.girar(r, r.x + r.w * t.cx, r.y + r.h * t.cy);
  }

  // La bolita de girar, colgada por encima del borde de arriba. Va girada con el
  // elemento, para que siga saliendo "de su cabeza" aunque este de lado.
  puntoGiro(r) {
    return this.girar(r, r.x + r.w / 2, r.y - GIRO_DIST);
  }

  //---------------------------------------------------------------------------
  // GIRO. Las cuentas viven en modelo.js, junto a las demas que tienen que
  // coincidir con Ruby, porque este fichero necesita el DOM y no se puede probar
  // sin navegador. Aqui solo se les pasa el rectangulo.
  //
  //   girar     de un punto de la caja sin girar a donde se ve. Para el contorno
  //             y los tiradores.
  //   desgirar  de donde esta el raton a la caja sin girar. Para los clics.
  //---------------------------------------------------------------------------
  girar(r, px, py) { return M.girarPunto(r, r.ang, px, py); }
  desgirar(r, px, py) { return M.desgirarPunto(r, r.ang, px, py); }

  // Rectangulo del elemento EN PIXELES DE PANTALLA, ya con el zoom aplicado.
  rectanguloPantalla(el) {
    const l = this.rectanguloLogico(el);
    if (!l) return null;
    const z = this.zoom;
    return { x: l.x * z, y: l.y * z, w: Math.max(l.w * z, 4), h: Math.max(l.h * z, 4), ang: l.ang };
  }

  // Rectangulo en coordenadas del lienzo (512x384), en el instante actual.
  rectanguloLogico(el) {
    const x = M.valorDe(el, "x", this.tiempo);
    const y = M.valorDe(el, "y", this.tiempo);
    const zoom = M.valorDe(el, "zoom", this.tiempo);
    const m = this.medidaElemento(el);
    // El zoom crece desde el CENTRO, igual que en el juego.
    const caja = M.cajaConZoom(x, y, m.w, m.h, zoom);
    caja.ang = M.valorDe(el, "angulo", this.tiempo);
    return caja;
  }

  // Cuanto ocupa un elemento en pantalla: lo que pida el diseño, y si no pide
  // nada, su tamaño natural.
  medidaElemento(el) {
    const nat = this.medidaNatural(el);
    let w = M.num(el.ancho, 0) > 0 ? M.num(el.ancho, 0) : nat.w;
    let hh = M.num(el.alto, 0) > 0 ? M.num(el.alto, 0) : nat.h;
    // Por debajo de 32 el marco de una ventana no cabe y se ve roto. Mismo
    // limite que Ventana::MINIMO en Ruby.
    if (el.tipo === "ventana") { w = Math.max(w, 32); hh = Math.max(hh, 32); }
    return { w: Math.max(w, 1), h: Math.max(hh, 1) };
  }

  // Cuanto mide SIN estirar: lo que trae su imagen, lo que ocupa su texto, o el
  // tamaño de partida de los que se dibujan por color.
  medidaNatural(el) {
    if (el.tipo === "pokemon") {
      const lado = (el.modo === "frente" || el.modo === "espalda") ? 128 : 64;
      return { w: lado, h: lado };
    }
    if (el.tipo === "texto") {
      const tam = M.num(el.tamano, M.TEXTO_TAMANO);
      // La misma medida que usa Texto#medir en Ruby, para que la caja que se
      // dibuja y la que se puede arrastrar sean la misma que la del juego.
      const medida = this.medirTexto(this.ctx2d, D.rellenarEjemplo(el.texto), tam);
      return { w: Math.ceil(medida.ancho) + 4, h: Math.max(medida.alto, tam + 4) };
    }
    if (el.tipo === "animado") {
      const dato = G.imagenEnCache(el.imagen);
      if (!dato || !dato.ancho) return { w: 32, h: 32 };
      const n = Math.max(M.num(el.fotogramas, 1), 1);
      const fw = M.num(el.ancho_fotograma, 0) > 0 ? M.num(el.ancho_fotograma, 0) : Math.floor(dato.ancho / n);
      const fh = M.num(el.alto_fotograma, 0) > 0 ? M.num(el.alto_fotograma, 0) : dato.alto;
      return { w: Math.max(fw, 1), h: Math.max(fh, 1) };
    }
    if (el.tipo === "imagen" || (el.tipo === "boton" && el.imagen)) {
      const dato = G.imagenEnCache(el.imagen);
      return (dato && dato.ancho) ? { w: dato.ancho, h: dato.alto } : { w: 32, h: 32 };
    }
    // panel, barra, ventana y boton de color: se dibujan del tamaño que se pida.
    return { w: 32, h: 32 };
  }

  //---------------------------------------------------------------------------
  // Raton.
  //---------------------------------------------------------------------------
  conectar() {
    // Se guardan las funciones para poder QUITARLAS al cerrar. Sin esto, cada vez
    // que se abria el editor quedaban dos listeners mas en window apuntando a un
    // lienzo ya muerto: cada movimiento del raton en toda la ventana disparaba el
    // codigo de todos los lienzos zombis a la vez.
    this._alMoverVentana = (e) => this.alMover(e);
    this._alSoltarVentana = () => this.alSoltar();
    // Si la ventana pierde el foco a mitad de un arrastre (Alt+Tab, o un dialogo
    // que se abre encima), el mouseup se lo lleva otra ventana y nunca llega. Sin
    // esto el arrastre se quedaba pegado y al volver el elemento pegaba un salto.
    this._alPerderFoco = () => this.cancelarArrastre();
    this.canvas.addEventListener("mousedown", (e) => this.alPulsar(e));
    window.addEventListener("mousemove", this._alMoverVentana);
    window.addEventListener("mouseup", this._alSoltarVentana);
    window.addEventListener("blur", this._alPerderFoco);
    this.canvas.addEventListener("mousemove", (e) => this.alMoverEncima(e));
    this.canvas.addEventListener("mouseleave", () => this.op.alMoverRaton?.(null));
    // Rueda con Ctrl para el zoom, que es lo que espera cualquiera. Va en LA
    // ZONA y no en el canvas: ampliando mucho, el canvas se sale de la vista y
    // el raton puede estar sobre el fondo a cuadros, donde antes la rueda no
    // hacia nada.
    this._alRodar = (e) => {
      if (!e.ctrlKey) return;
      e.preventDefault();
      const niveles = [0.1, 0.125, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 6];
      let i = niveles.findIndex(v => v >= this.zoom - 0.001);
      if (i < 0) i = niveles.length - 1;
      i += e.deltaY < 0 ? 1 : -1;
      i = Math.max(0, Math.min(niveles.length - 1, i));
      this.fijarZoomHacia(niveles[i], e.clientX, e.clientY);
      this.op.alCambiarZoom?.(this.zoom);
    };
    this.el.addEventListener("wheel", this._alRodar, { passive: false });

    // ARRASTRAR PARA MOVER EL LIENZO.
    //
    // Con el zoom alto, llegar a una esquina con las barras es un suplicio. Se
    // puede arrastrar con el BOTON CENTRAL o manteniendo ESPACIO, que es lo que
    // hace cualquier programa de dibujo; el boton izquierdo se deja libre porque
    // ahi ya se selecciona y se mueven elementos.
    this._paneo = null;
    this._espacio = false;

    this._alPulsarZona = (e) => {
      const conEspacio = this._espacio && e.button === 0;
      if (e.button !== 1 && !conEspacio) return;
      e.preventDefault();
      this._paneo = {
        x: e.clientX, y: e.clientY,
        sx: this.el.scrollLeft, sy: this.el.scrollTop
      };
      this.el.classList.add("ui-paneando");
    };
    this._alMoverPaneo = (e) => {
      if (!this._paneo) return;
      this.el.scrollLeft = this._paneo.sx - (e.clientX - this._paneo.x);
      this.el.scrollTop = this._paneo.sy - (e.clientY - this._paneo.y);
    };
    this._alSoltarPaneo = () => {
      if (!this._paneo) return;
      this._paneo = null;
      this.el.classList.remove("ui-paneando");
    };

    // El espacio se vigila en la ventana, pero NO cuando se esta escribiendo en
    // una caja de texto del inspector: ahi el espacio es un espacio.
    this._alBajarTecla = (e) => {
      if (e.code !== "Space" || escribiendo(e.target)) return;
      this._espacio = true;
    };
    this._alSubirTecla = (e) => {
      if (e.code === "Space") this._espacio = false;
    };

    this.el.addEventListener("mousedown", this._alPulsarZona);
    window.addEventListener("mousemove", this._alMoverPaneo);
    window.addEventListener("mouseup", this._alSoltarPaneo);
    window.addEventListener("keydown", this._alBajarTecla);
    window.addEventListener("keyup", this._alSubirTecla);
    // Si se pierde el foco a mitad, el espacio se quedaria "pulsado" para
    // siempre y el clic izquierdo dejaria de seleccionar. Mismo motivo que el
    // cancelarArrastre de arriba.
    this._alPerderFocoPaneo = () => { this._espacio = false; this._alSoltarPaneo(); };
    window.addEventListener("blur", this._alPerderFocoPaneo);
  }

  posicionEnCanvas(e) {
    const caja = this.canvas.getBoundingClientRect();
    return { px: e.clientX - caja.left, py: e.clientY - caja.top };
  }

  aLogico(px, py) {
    return { x: px / this.zoom, y: py / this.zoom };
  }

  alPulsar(e) {
    if (e.button !== 0) return;
    const { px, py } = this.posicionEnCanvas(e);

    // Primero los tiradores del elegido: tienen prioridad sobre seleccionar otro.
    const elegido = this.elementoElegido();
    if (elegido && this.transformable(elegido)) {
      const r = this.rectanguloPantalla(elegido);
      const g = this.puntoGiro(r);
      if (Math.hypot(px - g.x, py - g.y) <= GIRO_RADIO + 4) {
        this.op.antesDeCambiar?.("girar:" + elegido.id);
        const cx = r.x + r.w / 2, cy = r.y + r.h / 2;
        this.arrastre = {
          modo: "girar", id: elegido.id, cx, cy,
          a0: M.num(elegido.angulo, 0),
          // Desde donde se empezo a tirar: se gira lo que se MUEVA el raton, no
          // se salta de golpe al angulo donde se pincho.
          apunta: Math.atan2(py - cy, px - cx)
        };
        return;
      }
      for (const t of TIRADORES) {
        const p = this.puntoTirador(r, t);
        if (Math.abs(px - p.x) <= TIRADOR && Math.abs(py - p.y) <= TIRADOR) {
          const m = this.medidaElemento(elegido);
          this.op.antesDeCambiar?.("medida:" + elegido.id);   // foto antes de tocar nada
          this.arrastre = {
            modo: "medida", tirador: t, id: elegido.id,
            ox: px, oy: py,
            ang: M.num(elegido.angulo, 0),
            x0: M.num(elegido.x, 0), y0: M.num(elegido.y, 0),
            w0: m.w, h0: m.h
          };
          return;
        }
      }
    }

    const tocado = this.elementoEn(px, py);

    // NADA DEBAJO: empieza el rectangulo de goma. Antes esto solo deseleccionaba,
    // que es medio gesto: si arrastras por un hueco vacio lo natural es que
    // estes intentando rodear varias cosas.
    if (!tocado) {
      if (!e.ctrlKey && !e.shiftKey) this.op.alSeleccionar?.(null);
      this.goma = { x0: px, y0: py, x1: px, y1: py, sumar: e.ctrlKey || e.shiftKey };
      return;
    }

    // CTRL O SHIFT: añadir o quitar del grupo, sin empezar a mover. Quitar
    // importa tanto como añadir: rodeas seis y descartas el que no querias.
    if (e.ctrlKey || e.shiftKey) {
      this.op.alMarcar?.(tocado.id, "alternar");
      return;
    }

    // Pulsar sobre algo que YA esta en el grupo mueve el grupo entero; pulsar
    // fuera de el lo deshace y empieza de cero, que es como se comporta cualquier
    // editor.
    const enGrupo = this.marcados().includes(tocado.id);
    if (!enGrupo) this.op.alSeleccionar?.(tocado.id);
    else if (tocado.id !== this.seleccion) this.op.alMarcar?.(tocado.id, "principal");

    const grupo = enGrupo ? this.elementosMarcados() : [tocado];
    this.op.antesDeCambiar?.("mover:" + tocado.id);
    this.arrastre = {
      modo: "mover", id: tocado.id,
      ox: px, oy: py,
      x0: M.num(tocado.x, 0), y0: M.num(tocado.y, 0),
      // Se apunta de donde salia CADA UNO: mover el grupo es sumarle a todos el
      // mismo desplazamiento, no arrastrarlos uno detras de otro.
      grupo: grupo.map(g => ({ el: g, x0: M.num(g.x, 0), y0: M.num(g.y, 0) }))
    };
  }

  // El de capa mas alta que este bajo el punto, igual que hace el motor con los
  // botones: si dos se solapan gana el que se ve.
  elementoEn(px, py) {
    const { x, y } = this.aLogico(px, py);
    // Se acierta sobre las copias dibujadas, pero se devuelve el elemento de
    // ORIGEN: pulsar la tercera ficha de una lista repetida selecciona el grupo,
    // no una copia que no existe en el fichero.
    const lista = (this.expandidos || this.diseno?.elementos || [])
      .map((el, i) => ({ el, i }))
      .filter(({ el }) => el.visible !== false && el.bloqueado !== true)
      .sort((a, b) => (M.num(b.el.capa, 0) - M.num(a.el.capa, 0)) || (b.i - a.i));
    for (const { el } of lista) {
      const r = this.rectanguloLogico(el);
      // El punto se lleva al sistema del elemento, que puede estar girado. Misma
      // cuenta que hace el motor para decidir si un boton se ha pulsado.
      const p = this.desgirar(r, x, y);
      if (p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h) {
        const origen = el._origen || el.id;
        return (this.diseno.elementos || []).find(e => e.id === origen) || el;
      }
    }
    return null;
  }

  alMover(e) {
    // El rectangulo de goma se dibuja mientras se arrastra; lo que quede dentro
    // se marca al soltar.
    if (this.goma) {
      const p = this.posicionEnCanvas(e);
      this.goma.x1 = p.px;
      this.goma.y1 = p.py;
      this.repintarCapa();
      return;
    }
    if (!this.arrastre) return;
    const a = this.arrastre;
    const { px, py } = this.posicionEnCanvas(e);
    const el = (this.diseno.elementos || []).find(x => x.id === a.id);
    if (!el) return;

    if (a.modo === "girar") this.girarArrastrando(el, px, py, e);
    else if (a.modo === "mover") {
      // El desplazamiento se calcula UNA vez con el elemento que se agarro y se
      // aplica igual a todos. Si cada uno se imantara por su cuenta, un grupo
      // desalineado se cuadraria solo y se perderia la disposicion que tenia.
      const nx = this.ajustar(a.x0 + (px - a.ox) / this.zoom, e.altKey);
      const ny = this.ajustar(a.y0 + (py - a.oy) / this.zoom, e.altKey);
      const dx = nx - a.x0, dy = ny - a.y0;
      for (const g of (a.grupo || [{ el, x0: a.x0, y0: a.y0 }])) {
        g.el.x = g.x0 + dx;
        g.el.y = g.y0 + dy;
      }
    } else {
      this.estirarArrastrando(el, px, py, e);
    }
    this.repintar();
    this.op.alCambiar?.(el, true);        // true = sigue arrastrando
  }

  //---------------------------------------------------------------------------
  // GIRAR. Se suma lo que el raton ha barrido alrededor del centro desde que se
  // agarro la bolita, no el angulo absoluto: asi no pega un salto al pinchar.
  //---------------------------------------------------------------------------
  girarArrastrando(el, px, py, e) {
    const a = this.arrastre;
    const barrido = Math.atan2(py - a.cy, px - a.cx) - a.apunta;
    // En pantalla la y crece hacia abajo y en RGSS el angulo crece al reves, de
    // ahi el signo.
    let ang = a.a0 - (barrido * 180 / Math.PI);
    if (e.shiftKey) ang = Math.round(ang / GIRO_PASO) * GIRO_PASO;
    else ang = Math.round(ang * 10) / 10;
    // Se deja siempre entre -180 y 180, que es como se lee mejor en el
    // inspector: "-90" en vez de "270".
    ang = ((ang % 360) + 360) % 360;
    if (ang > 180) ang -= 360;
    if (ang === 0) delete el.angulo; else el.angulo = ang;
  }

  //---------------------------------------------------------------------------
  // ESTIRAR POR LAS ESQUINAS.
  //
  //   sin Shift  cada lado va por su cuenta y la cosa se DEFORMA, que es lo que
  //              se quiere para estirar un fondo o achatar un marco
  //   con Shift  se mantiene la proporcion, como en cualquier editor de imagenes
  //   con Alt    no se imanta a la rejilla
  //---------------------------------------------------------------------------
  estirarArrastrando(el, px, py, e) {
    const a = this.arrastre;
    const t = a.tirador;
    let dx = (px - a.ox) / this.zoom;
    let dy = (py - a.oy) / this.zoom;

    // El tiron se mide EN EL SISTEMA DEL ELEMENTO. Si esta girado 30 grados,
    // tirar de su lado derecho tiene que ensancharlo por SU derecha, no por la
    // derecha de la pantalla.
    if (a.ang) {
      const r = a.ang * Math.PI / 180;
      const gx = dx * Math.cos(r) - dy * Math.sin(r);
      const gy = dx * Math.sin(r) + dy * Math.cos(r);
      dx = gx; dy = gy;
    }

    const dw = t.dw ? t.dw * dx : 0;
    const dh = t.dh ? t.dh * dy : 0;
    let nw = a.w0 + dw;
    let nh = a.h0 + dh;

    if (e.shiftKey && a.w0 > 0 && a.h0 > 0) {
      const razon = a.w0 / a.h0;
      if (!t.dh) nh = nw / razon;                                   // tirador de lado
      else if (!t.dw) nw = nh * razon;                              // tirador de arriba o abajo
      else if (Math.abs(dw) >= Math.abs(dh * razon)) nh = nw / razon;  // esquina: manda el que mas se movio
      else nw = nh * razon;
    } else {
      // Se imanta el BORDE que se esta moviendo, que es lo util para cuadrar.
      // Con Shift no se imanta: redondear rompe la proporcion que se acaba de
      // pedir, y entonces Shift no serviria de nada.
      if (t.dx) nw = a.x0 + a.w0 - this.ajustar(a.x0 + a.w0 - nw, e.altKey);
      else if (t.dw) nw = this.ajustar(a.x0 + nw, e.altKey) - a.x0;
      if (t.dy) nh = a.y0 + a.h0 - this.ajustar(a.y0 + a.h0 - nh, e.altKey);
      else if (t.dh) nh = this.ajustar(a.y0 + nh, e.altKey) - a.y0;
    }
    nw = Math.max(this.redondear(nw), MINIMO);
    nh = Math.max(this.redondear(nh), MINIMO);

    // DONDE QUEDA LA ESQUINA QUE NO SE TOCA.
    //
    // Sin giro es evidente: si tiras del lado izquierdo, el derecho se queda
    // donde estaba. Con giro no, porque el elemento gira alrededor de su centro
    // y el centro se mueve al cambiar de tamaño. Se calcula donde tiene que
    // quedar el centro nuevo para que el anclaje no se mueva en pantalla; sin
    // giro esta misma cuenta da el resultado de siempre.
    const fx = t.dx ? 1 : 0, fy = t.dy ? 1 : 0;
    const ox = (fx - 0.5) * (a.w0 - nw);
    const oy = (fy - 0.5) * (a.h0 - nh);
    let mx = ox, my = oy;
    if (a.ang) {
      const r = a.ang * Math.PI / 180;
      mx = ox * Math.cos(r) + oy * Math.sin(r);
      my = -ox * Math.sin(r) + oy * Math.cos(r);
    }
    const cx = a.x0 + a.w0 / 2 + mx;
    const cy = a.y0 + a.h0 / 2 + my;

    const cambiaW = !!t.dw || (e.shiftKey && !!t.dh);
    const cambiaH = !!t.dh || (e.shiftKey && !!t.dw);
    if (cambiaW) el.ancho = nw;
    if (cambiaH) el.alto = nh;
    el.x = this.redondear(cx - nw / 2);
    el.y = this.redondear(cy - nh / 2);
  }

  // Imantar a la rejilla, salvo que se tenga Alt pulsado (la escapatoria de
  // siempre para colocar algo a mano).
  ajustar(v, sinImantar) {
    if (!this.imantar || sinImantar) return this.redondear(v);
    return Math.round(v / M.REJILLA) * M.REJILLA;
  }

  // Suelta el elemento donde este, sin aplicar mas movimiento. Se usa al perder
  // el foco: mejor dejarlo donde estaba que darle un salto al volver.
  cancelarArrastre() {
    // La goma tambien se cancela: si la ventana pierde el foco a medias, dejarla
    // pintada haria creer que sigue viva.
    if (this.goma) { this.goma = null; this.repintarCapa(); }
    if (!this.arrastre) return;
    this.arrastre = null;
    this.op.alCambiar?.(null, false);
  }

  desconectar() {
    window.removeEventListener("mousemove", this._alMoverVentana);
    window.removeEventListener("mouseup", this._alSoltarVentana);
    window.removeEventListener("blur", this._alPerderFoco);
    // Los del arrastre del lienzo, por el mismo motivo que los de arriba: si se
    // quedan, cada movimiento del raton en toda la ventana despierta a un lienzo
    // que ya no existe.
    window.removeEventListener("mousemove", this._alMoverPaneo);
    window.removeEventListener("mouseup", this._alSoltarPaneo);
    window.removeEventListener("keydown", this._alBajarTecla);
    window.removeEventListener("keyup", this._alSubirTecla);
    window.removeEventListener("blur", this._alPerderFocoPaneo);
    this._latiendo = false;
    this.arrastre = null;
    this._paneo = null;
    this._espacio = false;
  }

  alSoltar() {
    if (this.goma) {
      const g = this.goma;
      this.goma = null;
      // Un arrastre de menos de cuatro pixeles es un clic con pulso, no una
      // seleccion: si no, cualquier clic en el fondo marcaria cosas sin querer.
      if (Math.abs(g.x1 - g.x0) >= 4 || Math.abs(g.y1 - g.y0) >= 4) {
        this.op.alMarcarVarios?.(this.dentroDeGoma(g), g.sumar);
      }
      this.repintarCapa();
      return;
    }
    if (!this.arrastre) return;
    const el = (this.diseno.elementos || []).find(x => x.id === this.arrastre.id);
    this.arrastre = null;
    if (el) this.op.alCambiar?.(el, false);
  }

  // Que elementos toca el rectangulo de goma. Basta con que se SOLAPEN, no hace
  // falta rodearlos del todo: rodear entero obliga a barridos enormes y es la
  // queja clasica de las herramientas que lo hacen asi.
  dentroDeGoma(g) {
    const z = this.zoom;
    const x0 = Math.min(g.x0, g.x1) / z, x1 = Math.max(g.x0, g.x1) / z;
    const y0 = Math.min(g.y0, g.y1) / z, y1 = Math.max(g.y0, g.y1) / z;
    const salida = new Set();
    for (const el of (this.expandidos || this.diseno?.elementos || [])) {
      if (el.visible === false || el.bloqueado === true) continue;
      const r = this.rectanguloLogico(el);
      if (r.x > x1 || r.x + r.w < x0 || r.y > y1 || r.y + r.h < y0) continue;
      salida.add(el._origen || el.id);
    }
    return [...salida];
  }

  // Cursor y coordenadas del pie.
  alMoverEncima(e) {
    const { px, py } = this.posicionEnCanvas(e);
    const { x, y } = this.aLogico(px, py);
    this.op.alMoverRaton?.({ x: Math.floor(x), y: Math.floor(y) });

    if (this.arrastre) return;
    const el = this.elementoElegido();
    if (el && this.transformable(el)) {
      const r = this.rectanguloPantalla(el);
      const g = this.puntoGiro(r);
      if (Math.hypot(px - g.x, py - g.y) <= GIRO_RADIO + 4) {
        this.canvas.style.cursor = "grab";
        return;
      }
      for (const t of TIRADORES) {
        const p = this.puntoTirador(r, t);
        if (Math.abs(px - p.x) <= TIRADOR && Math.abs(py - p.y) <= TIRADOR) {
          this.canvas.style.cursor = this.cursorTirador(t, r.ang || 0);
          return;
        }
      }
    }
    this.canvas.style.cursor = this.elementoEn(px, py) ? "move" : "default";
  }

  // El cursor de estirar tiene que girar con el elemento: en algo puesto de lado,
  // el tirador de la derecha estira hacia arriba y abajo, y una flecha que apunte
  // al lado contrario despista mas de lo que ayuda.
  cursorTirador(t, ang) {
    const g = (((ANGULO_TIRADOR[t.id] - ang) % 360) + 360) % 360;
    return CURSORES_POR_ANGULO[Math.round(g / 45) % 8];
  }

  // Mover con las flechas: 1 pixel, o un paso de rejilla con Shift. Mueve TODO
  // el grupo, que es lo util cuando ya has marcado seis botones.
  empujar(dx, dy, paso) {
    const grupo = this.elementosMarcados();
    if (!grupo.length) return false;
    this.op.antesDeCambiar?.("empujar:" + this.seleccion);
    for (const el of grupo) {
      el.x = M.num(el.x, 0) + dx * paso;
      el.y = M.num(el.y, 0) + dy * paso;
    }
    this.repintar();
    this.op.alCambiar?.(grupo[0], false);
    return true;
  }

  //---------------------------------------------------------------------------
  // ALINEAR Y REPARTIR.
  //
  // Se alinea contra el elemento PRINCIPAL (el que tiene los tiradores), no
  // contra el borde del grupo. Es lo que hace que el resultado sea previsible:
  // eliges el que ya esta bien puesto y los demas van a el.
  //
  // Se usa la caja EN PANTALLA (rectanguloLogico), no la x,y del diseño: asi un
  // texto de ancho automatico o algo girado se centran por lo que se ve, que es
  // lo que uno esta mirando cuando pulsa el boton.
  //---------------------------------------------------------------------------
  alinear(como) {
    const grupo = this.elementosMarcados();
    if (grupo.length < 2) return false;
    const principal = grupo[0];
    const ref = this.rectanguloLogico(principal);
    this.op.antesDeCambiar?.("alinear:" + como);

    for (const el of grupo) {
      if (el === principal) continue;
      const r = this.rectanguloLogico(el);
      // El desfase entre la x del diseño y la caja pintada (el zoom o el margen
      // del texto lo mueven), para devolver la correccion al sitio correcto.
      const offX = M.num(el.x, 0) - r.x;
      const offY = M.num(el.y, 0) - r.y;
      switch (como) {
        case "izquierda": el.x = Math.round(ref.x + offX); break;
        case "derecha":   el.x = Math.round(ref.x + ref.w - r.w + offX); break;
        case "centro_h":  el.x = Math.round(ref.x + (ref.w - r.w) / 2 + offX); break;
        case "arriba":    el.y = Math.round(ref.y + offY); break;
        case "abajo":     el.y = Math.round(ref.y + ref.h - r.h + offY); break;
        case "centro_v":  el.y = Math.round(ref.y + (ref.h - r.h) / 2 + offY); break;
      }
    }
    this.repintar();
    this.op.alCambiar?.(principal, false);
    return true;
  }

  // Repartir con el MISMO HUECO entre unos y otros. No es repartir los centros a
  // distancias iguales: con elementos de tamaños distintos eso deja huecos
  // desiguales, que es justo lo que se ve mal.
  repartir(eje) {
    const grupo = this.elementosMarcados();
    if (grupo.length < 3) return false;
    const conCaja = grupo.map(el => ({ el, r: this.rectanguloLogico(el) }));
    const vertical = (eje === "vertical");
    conCaja.sort((a, b) => (vertical ? a.r.y - b.r.y : a.r.x - b.r.x));

    const primero = conCaja[0], ultimo = conCaja[conCaja.length - 1];
    const desde = vertical ? primero.r.y : primero.r.x;
    const hasta = vertical ? (ultimo.r.y + ultimo.r.h) : (ultimo.r.x + ultimo.r.w);
    const ocupado = conCaja.reduce((s, c) => s + (vertical ? c.r.h : c.r.w), 0);
    const hueco = (hasta - desde - ocupado) / (conCaja.length - 1);

    this.op.antesDeCambiar?.("repartir:" + eje);
    let cursor = desde;
    for (const c of conCaja) {
      if (vertical) {
        const off = M.num(c.el.y, 0) - c.r.y;
        c.el.y = Math.round(cursor + off);
        cursor += c.r.h + hueco;
      } else {
        const off = M.num(c.el.x, 0) - c.r.x;
        c.el.x = Math.round(cursor + off);
        cursor += c.r.w + hueco;
      }
    }
    this.repintar();
    this.op.alCambiar?.(grupo[0], false);
    return true;
  }
}
