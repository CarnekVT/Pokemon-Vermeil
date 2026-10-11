//=============================================================================
// El armazon del editor: junta las piezas, guarda y carga, y lleva el deshacer.
//
// EL CICLO DE TRABAJO QUE HACE ESTO UTIL
//   1. Montas la pantalla aqui y le das a Guardar (escribe UI/<nombre>.json).
//   2. En el juego: menu de debug -> "Abrir una interfaz..." y la eliges.
//   3. Cambias algo aqui, guardas, y la vuelves a abrir en el juego.
//
//   En el paso 3 NO hay que cerrar el juego ni borrar PluginScripts.rxdata,
//   porque el diseño es un dato y no codigo compilado. Eso es justo lo que se
//   buscaba con esta arquitectura.
//=============================================================================

import { h, boton, casilla } from "./components/dom.js";
import { CSS } from "./estilo.js";
import * as M from "./modelo.js";
import * as G from "./graficos.js";
import * as P from "./proyecto.js";
import { Lienzo } from "./components/lienzo.js";
import { Capas } from "./components/capas.js";
import { Inspector } from "./components/inspector.js";
import { Tiempo } from "./components/tiempo.js";
import { Resolucion } from "./components/resolucion.js";

const CARPETA = "UI";
// El nombre TAL CUAL aparece en el campo Name del meta.txt del plugin. Si se
// cambia alli, hay que cambiarlo aqui y en el "requires" del manifest.
const PLUGIN_NECESARIO = "Interfaces";
const URL_PLUGIN = "https://github.com/yobrantoro/essentials-interfaces";
const TOPE_DESHACER = 60;
// Cambios mas seguidos que esto se agrupan en una sola foto de deshacer.
const VENTANA_DESHACER = 600;

export class EditorInterfaces {
  constructor(ctx, host) {
    this.ctx = ctx;
    this.host = host;
    this.diseno = null;
    this.nombre = null;
    this.sucio = false;
    this.seleccion = null;
    this.extra = new Set();       // los demas marcados del grupo
    this.disponibles = [];
    this.deshacerPila = [];
    this.rehacerPila = [];

    G.configurar(ctx);
    // Los nombres de los interruptores y variables del proyecto, para poder
    // elegirlos de una lista en vez de escribir numeros a ciegas.
    P.configurar(ctx);
    this.construir();
    this.conectarTeclado();
    this.arrancar();
  }

  //---------------------------------------------------------------------------
  construir() {
    const estilo = document.createElement("style");
    estilo.textContent = CSS;
    this.host.appendChild(estilo);

    this.selDiseno = h("select", { className: "ui-sel", style: { width: "auto", minWidth: "150px" } });
    this.selDiseno.addEventListener("change", () => this.abrir(this.selDiseno.value));

    this.etiquetaSucio = h("span", { className: "ui-sucio", textContent: "" });
    this.btnGuardar = boton("Guardar", () => this.guardar(), "primario");
    this.avisosBtn = boton("", () => this.mostrarAvisos());
    this.avisosBtn.style.display = "none";

    this.barra = h("div", { className: "ui-barra" },
      h("span", { className: "ui-capa-tipo", textContent: "Diseño:" }),
      this.selDiseno,
      this.etiquetaSucio,
      boton("Nuevo...", () => this.nuevo()),
      boton("Duplicar...", () => this.duplicar()),
      boton("Borrar...", () => this.borrar(), "peligro"),
      h("span", { className: "ui-barra-hueco" }),
      boton("Mapa de aperturas", () => this.mostrarMapaAperturas()),
      this.avisosBtn,
      this.btnGuardar
    );

    this.barraAnadir = h("div", { className: "ui-barra" },
      h("span", { className: "ui-capa-tipo", textContent: "Añadir:" }),
      ...M.TIPOS.map(t => boton(M.NOMBRE_TIPO[t], () => this.anadir(t))),
      h("span", { className: "ui-barra-hueco" }),
      boton("Duplicar (Ctrl+D)", () => this.duplicarElemento()),
      boton("Borrar (Supr)", () => this.borrarElemento(), "peligro")
    );

    // BARRA DE ALINEAR. Solo aparece con varios marcados: enseñarla siempre
    // apagada seria ruido permanente en la pantalla.
    //
    // Se alinea contra el elemento PRINCIPAL, el que lleva los tiradores, y se
    // dice en la propia barra para que no haya que adivinar la referencia.
    this.etiquetaGrupo = h("span", { className: "ui-capa-tipo", textContent: "" });
    this.botonesRepartir = [
      boton("Repartir en fila", () => this.repartir("horizontal")),
      boton("Repartir en columna", () => this.repartir("vertical"))
    ];
    this.barraGrupo = h("div", { className: "ui-barra", style: { display: "none" } },
      this.etiquetaGrupo,
      h("span", { className: "ui-capa-tipo", textContent: "· alinear al de tiradores:" }),
      boton("Izq", () => this.alinear("izquierda")),
      boton("Centro", () => this.alinear("centro_h")),
      boton("Der", () => this.alinear("derecha")),
      boton("Arriba", () => this.alinear("arriba")),
      boton("Medio", () => this.alinear("centro_v")),
      boton("Abajo", () => this.alinear("abajo")),
      h("span", { className: "ui-barra-hueco" }),
      ...this.botonesRepartir,
      boton("Quitar seleccion", () => this.seleccionar(null))
    );

    // --- piezas ---
    // El motivo agrupa pulsaciones seguidas de la MISMA operacion. Sin el, editar
    // un campo y arrastrar otro elemento medio segundo despues se fundian en un
    // solo paso de deshacer.
    const antesDeCambiar = (motivo) => this.apuntarDeshacer(motivo);

    this.lienzo = new Lienzo({
      antesDeCambiar,
      alSeleccionar: (id) => this.seleccionar(id),
      alMarcar: (id, como) => this.marcar(id, como),
      alMarcarVarios: (ids, sumar) => this.marcarVarios(ids, sumar),
      alCambiar: (_el, arrastrando) => {
        // Mientras se arrastra solo se marca sucio y se repinta; el trabajo de
        // refrescar listas se deja para cuando se suelte, que si no va a tirones.
        this.sucio = true;
        this.pintarSucio();
        if (!arrastrando) this.pintarAvisos();
        this.inspector.refrescar();
      },
      alMoverRaton: (p) => {
        this.coords.textContent = p ? `${p.x}, ${p.y}` : "";
      },
      alCambiarZoom: (z) => { this.fijarSelectorZoom(z); }
    });

    this.capas = new Capas({
      antesDeCambiar,
      alSeleccionar: (id) => this.seleccionar(id),
      alMarcar: (id, como) => this.marcar(id, como),
      alCambiar: () => { this.marcarSucio(); this.refrescarTodo(); },
      pedirTexto: (titulo, valor) => this.pedirTexto(titulo, valor),
      avisar: (m) => this.toast(m, "warning")
    });

    this.inspector = new Inspector(this.ctx, {
      antesDeCambiar,
      alCambiar: () => { this.marcarSucio(); this.lienzo.repintar(); this.capas.refrescar(); this.tiempo.recalcularDuracion(); },
      listaInterfaces: () => this.disponibles.filter(n => n !== this.nombre),
      interruptoresConocidos: () => this.interruptoresConocidos(),
      catalogo: () => this.catalogo || [],
      fondoPantallaCompleta: () => this.anadirFondo(),
      marcos: () => this.marcos || [],
      pedirTexto: (titulo, valor) => this.pedirTexto(titulo, valor),
      avisar: (m) => this.toast(m, "warning")
    });

    this.tiempo = new Tiempo({
      antesDeCambiar,
      alCambiarTiempo: (t) => this.lienzo.fijarTiempo(t),
      alCambiar: () => { this.marcarSucio(); this.lienzo.repintar(); }
    });

    this.resolucion = new Resolucion({
      antesDeCambiar,
      alCambiar: () => { this.marcarSucio(); this.refrescarCanvas(); },
      alAplicar: (cfg) => this.aplicarResolucion(cfg),
      avisar: (m) => this.toast(m, "warning")
    });

    // --- pie del lienzo ---
    this.coords = h("span", { className: "ui-tiempo-reloj", textContent: "" });
    this.selZoom = h("select", { className: "ui-sel", style: { width: "auto" } });
    const nivelesZoom = [0.1, 0.125, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4];
    for (const z of nivelesZoom) this.selZoom.appendChild(h("option", { value: z, textContent: `${Math.round(z * 100)}%`, selected: z === 1 }));
    this.selZoom.addEventListener("change", () => this.lienzo.fijarZoom(Number(this.selZoom.value)));

    // QUE BOTON SE DA POR ELEGIDO AL DIBUJAR.
    //
    // Una pantalla suele llevar un elemento por cada opcion ("este texto se ve
    // cuando esta elegido el boton 3"). Con un solo elegido posible, los de los
    // demas botones no se podrian ver NUNCA aqui. Con esto se recorren los estados
    // uno a uno, igual que la linea de tiempo recorre una animacion.
    this.selElegido = h("select", { className: "ui-sel", style: { width: "auto", maxWidth: "160px" } });
    this.selElegido.addEventListener("change", () => {
      this.lienzo.fijarSimulaElegido(this.selElegido.value || null);
    });

    this.etiquetaLienzo = h("span", { textContent: `Canvas ${M.LIENZO_ANCHO}×${M.LIENZO_ALTO} · 4:3` });
    this.pie = h("div", { className: "ui-pie-lienzo" },
      this.etiquetaLienzo,
      h("span", { className: "ui-barra-hueco" }),
      this.coords,
      h("span", { textContent: "Elegido" }), this.selElegido,
      h("span", { textContent: "Zoom" }), this.selZoom,
      boton("Encajar", () => this.lienzo.encajar()),
      casilla(true, (v) => this.lienzo.fijarRejilla(v), "rejilla"),
      casilla(true, (v) => this.lienzo.fijarImantar(v), "imantar"),
      // Los que una condicion esconde, en fantasma. Encendido por defecto: perder
      // un elemento de vista sin saber donde esta es mucho peor que verlo a
      // medias, y asi se puede seguir colocando.
      casilla(true, (v) => this.lienzo.fijarVerEscondidos(v), "ver escondidos")
    );

    this.centro = h("div", { className: "ui-centro" }, this.lienzo.el, this.pie);
    this.cuerpo = h("div", { className: "ui-cuerpo" }, this.capas.el, this.centro, this.inspector.el);

    this.raiz = h("div", { className: "ui-raiz" }, this.barra, this.barraAnadir, this.resolucion.el, this.barraGrupo, this.cuerpo, this.tiempo.el);
    this.host.appendChild(this.raiz);
  }

  //---------------------------------------------------------------------------
  // ¿ESTA EL PLUGIN QUE HACE FALTA PARA QUE ESTO SIRVA DE ALGO?
  //
  // Este editor escribe UI/<nombre>.json. Quien los lee y los pinta es el plugin
  // de Ruby "Interfaces", que va dentro del proyecto del juego. Sin el, se puede
  // diseñar igual pero en el juego no aparece nada, y sin un aviso eso se
  // descubre despues de montar una pantalla entera.
  //
  // CUIDADO CON EL FALSO POSITIVO: available() devuelve false en proyectos sin
  // carpeta Plugins/ (v16, BES v5), y ahi isInstalled() dice "no instalado" para
  // TODO. Si se avisara sin mirar eso, se estaria acusando en falso en proyectos
  // donde ni siquiera se puede comprobar. Por eso hay tres casos y no dos.
  comprobarPlugin() {
    const P = this.ctx.plugins;
    if (!P || typeof P.available !== "function") return;   // editor mas viejo
    let disponible = false, instalado = false, info = null;
    try {
      disponible = P.available();
      if (disponible) {
        instalado = P.isInstalled(PLUGIN_NECESARIO);
        info = P.get(PLUGIN_NECESARIO);
      }
    } catch { return; }

    if (disponible && instalado) {
      // Esta puesto. Se dice la version, que ayuda si algun dia hay incompatibles.
      this.quitarAviso();
      if (info && info.version) this.toast(`Plugin Interfaces ${info.version} detectado en el proyecto.`, "success");
      return;
    }
    if (!disponible) {
      // No se puede saber. Se dice lo que hay, sin acusar.
      this.mostrarAviso(
        "No puedo comprobar los plugins de este proyecto (no tiene carpeta Plugins/). " +
        "Asegurate de que el plugin Interfaces esta instalado, o los diseños no se veran en el juego.",
        "aviso");
      return;
    }
    this.mostrarAviso(
      "Falta el plugin Interfaces en este proyecto. El editor funciona y guarda los diseños, " +
      "pero el juego no los va a pintar hasta que lo instales.",
      "falta");
  }

  mostrarAviso(texto, clase) {
    this.quitarAviso();
    const enlace = h("a", {
      href: URL_PLUGIN, target: "_blank", rel: "noreferrer",
      className: "ui-aviso-enlace", textContent: "Descargar el plugin"
    });
    this.avisoPlugin = h("div", { className: "ui-aviso-plugin " + clase },
      h("span", { textContent: texto }),
      h("span", { className: "ui-barra-hueco" }),
      enlace,
      h("button", { className: "ui-aviso-cerrar", textContent: "×", title: "Ocultar",
                    onClick: () => this.quitarAviso() })
    );
    this.raiz.insertBefore(this.avisoPlugin, this.raiz.firstChild);
  }

  quitarAviso() {
    if (this.avisoPlugin && this.avisoPlugin.parentNode) this.avisoPlugin.remove();
    this.avisoPlugin = null;
  }

  //---------------------------------------------------------------------------
  async arrancar() {
    this.comprobarPlugin();
    await G.cargarFuente();
    if (!G.hayTauri()) {
      this.toast("No puedo leer las imagenes del proyecto: el editor se vera sin graficos.", "warning");
    }
    // LOS MARCOS, CLASIFICADOS POR SU FORMATO DE VERDAD.
    //
    // La carpeta Windowskins mezcla marcos de menu con bocadillos de dialogo y
    // carteles de señal, y estos ultimos NO son marcos: dibujarlos como tal sale
    // deforme. Se miden todos (solo la cabecera, es barato) y se ofrecen unicamente
    // los que el editor sabe dibujar. Ofrecer los 108 fue un error que se vio en
    // cuanto alguien eligio uno.
    this.marcos = [];
    try {
      const ls = await G.listarGraficos(this.ctx, "Windowskins");
      const nombres = (ls || []).map(n => String(n).replace(/.(png|gif)$/i, "")).sort();
      const medidos = await Promise.all(nombres.map(async (n) => {
        const m = await G.medirGrafico("Graphics/Windowskins/" + n);
        return { nombre: n, formato: m ? M.formatoMarco(m.ancho, m.alto) : "ninguno" };
      }));
      this.marcos = medidos.filter(m => m.formato !== "ninguno");
      const fuera = medidos.length - this.marcos.length;
      if (fuera > 0) {
        this.toast(`${this.marcos.length} marcos de ventana disponibles. Los otros ${fuera} de esa carpeta son bocadillos y carteles, no marcos.`, "info");
      }
    } catch { this.marcos = []; }

    await this.recargarLista();
    if (this.disponibles.length) await this.abrir(this.disponibles[0]);
    else this.cargarDiseno(M.disenoNuevo("sin_nombre"), null);
  }

  async recargarLista() {
    this.disponibles = [];
    try {
      const ficheros = await this.ctx.fs.listProjectDir(CARPETA);
      this.disponibles = (ficheros || [])
        .filter(n => /\.json$/i.test(n))
        .map(n => n.replace(/\.json$/i, ""))
        .sort();
    } catch { this.disponibles = []; }

    await this.recargarAperturas();

    this.selDiseno.innerHTML = "";
    for (const n of this.disponibles) {
      this.selDiseno.appendChild(h("option", { value: n, textContent: n, selected: n === this.nombre }));
    }
    if (!this.disponibles.length) {
      this.selDiseno.appendChild(h("option", { value: "", textContent: "(no hay ninguno)" }));
    }
  }

  // Lee de cada diseño solo como se abre. Sirve para el mapa de aperturas, para
  // el desplegable de interruptores y para avisar de choques (dos pantallas con
  // la misma tecla). Un fichero roto se salta sin ruido: ya se quejara al abrirlo.
  async recargarAperturas() {
    this.catalogo = [];
    for (const n of this.disponibles) {
      if (n === this.nombre && this.diseno) {
        // El que se esta editando: se usa lo que hay en memoria, no lo guardado,
        // para que los avisos reaccionen a lo que acabas de escribir.
        this.catalogo.push({ nombre: n, titulo: this.diseno.titulo, aperturas: this.diseno.aperturas || {} });
        continue;
      }
      try {
        const texto = await this.ctx.fs.readProjectFile(`${CARPETA}/${n}.json`);
        const d = JSON.parse(texto);
        this.catalogo.push({ nombre: n, titulo: d.titulo, aperturas: d.aperturas || {} });
      } catch { /* roto: se salta */ }
    }
  }

  // Los interruptores de interfaz que ya existen, con la pantalla a la que van.
  interruptoresConocidos() {
    return (this.catalogo || [])
      .filter(e => e.aperturas && e.aperturas.interruptor)
      .map(e => ({ interruptor: e.aperturas.interruptor, nombre: e.nombre }));
  }

  //---------------------------------------------------------------------------
  async abrir(nombre) {
    if (!nombre) return;
    if (this.sucio && !(await this.confirmar("Hay cambios sin guardar. ¿Los descarto?"))) {
      this.selDiseno.value = this.nombre || "";
      return;
    }
    try {
      const texto = await this.ctx.fs.readProjectFile(`${CARPETA}/${nombre}.json`);
      const datos = JSON.parse(texto);
      this.cargarDiseno(datos, nombre);
    } catch (e) {
      this.toast(`No puedo abrir "${nombre}": ${e.message}`, "error");
    }
  }

  cargarDiseno(datos, nombre) {
    M.normalizarDiseno(datos);
    this.diseno = datos;
    this.nombre = nombre;
    this.sucio = false;
    this.seleccion = null;
    this.deshacerPila = [];
    this.rehacerPila = [];
    if (nombre) this.selDiseno.value = nombre;
    this.refrescarTodo();
    this.tiempo.fijarTiempo(0);
  }

  refrescarTodo() {
    // Se limpia el grupo de ids que ya no existen (borrados, renombrados, o
    // cargando otro diseño). Si no, alinear intentaria mover fantasmas.
    const vivos = new Set((this.diseno?.elementos || []).map(e => e.id));
    this.extra = new Set([...(this.extra || [])].filter(id => vivos.has(id)));
    if (this.seleccion && !vivos.has(this.seleccion)) this.seleccion = null;
    if (this.seleccion) this.extra.add(this.seleccion);

    this.lienzo.fijarDiseno(this.diseno);
    this.lienzo.fijarSeleccion(this.seleccion, this.extra);
    this.resolucion?.fijarDiseno(this.diseno);
    this.refrescarEtiquetaLienzo();
    this.capas.fijarDiseno(this.diseno);
    this.capas.fijarSeleccion(this.seleccion, this.extra);
    this.inspector.fijarDiseno(this.diseno);
    this.inspector.fijarSeleccion(this.seleccion);
    this.tiempo.fijarDiseno(this.diseno);
    this.tiempo.fijarSeleccion(this.seleccion);
    this.pintarSucio();
    this.pintarAvisos();
    this.pintarGrupo();
    this.pintarElegidos();
  }

  //---------------------------------------------------------------------------
  // La lista de "que boton se da por elegido".
  //
  // Se rehace con el diseño porque los botones se añaden, se borran y se
  // renombran: una lista que se quedara con nombres viejos simularia un boton que
  // ya no existe y el lienzo dejaria de cuadrar con el juego sin decir nada.
  //---------------------------------------------------------------------------
  pintarElegidos() {
    if (!this.selElegido) return;
    const botones = (this.diseno?.elementos || []).filter(e => e.tipo === "boton");
    const antes = this.selElegido.value;
    this.selElegido.textContent = "";
    this.selElegido.appendChild(h("option", { value: "", textContent: "el de salida" }));
    for (const b of botones) {
      const rotulo = String(b.texto || "").trim();
      this.selElegido.appendChild(h("option", {
        value: b.id, textContent: rotulo ? `${b.id} — ${rotulo}` : b.id
      }));
    }
    // Si el que estaba simulado ya no existe, se vuelve al de salida en vez de
    // dejar el desplegable señalando a la nada.
    const sigue = antes && botones.some(b => b.id === antes);
    this.selElegido.value = sigue ? antes : "";
    this.selElegido.disabled = botones.length === 0;
    if (!sigue && antes) this.lienzo.fijarSimulaElegido(null);
  }

  //---------------------------------------------------------------------------
  // Canvas / resolution system 2.x.
  fijarSelectorZoom(z) {
    if (!this.selZoom) return;
    const valor = String(z);
    let opt = [...this.selZoom.options].find(o => o.value === valor);
    if (!opt) {
      opt = h("option", { value: valor, textContent: `${Math.round(Number(z) * 100)}%` });
      this.selZoom.appendChild(opt);
    }
    this.selZoom.value = valor;
  }

  refrescarEtiquetaLienzo() {
    if (!this.etiquetaLienzo || !this.diseno) return;
    const l = this.diseno.lienzo || {};
    this.etiquetaLienzo.textContent = `Canvas ${l.ancho}×${l.alto} · ${M.nombreAspecto(l.ancho, l.alto)}`;
  }

  refrescarCanvas() {
    this.lienzo.repintar();
    this.inspector.refrescar();
    this.refrescarEtiquetaLienzo();
    this.resolucion?.fijarDiseno(this.diseno);
  }

  aplicarResolucion({ ancho, alto, estrategia }) {
    if (!this.diseno) return;
    const viejo = { ...this.diseno.lienzo };
    if (Number(ancho) === Number(viejo.ancho) && Number(alto) === Number(viejo.alto)) return;
    this.apuntarDeshacer("resolucion");
    const cambio = M.cambiarResolucion(this.diseno, ancho, alto, estrategia);
    if (!cambio) return;
    this.marcarSucio();
    this.refrescarTodo();
    this.lienzo.encajar();
    this.toast(`Canvas ${viejo.ancho}×${viejo.alto} → ${ancho}×${alto} (${M.nombreAspecto(ancho, alto)}).`, "success");
  }

  //---------------------------------------------------------------------------
  // SELECCION, SIMPLE Y DE GRUPO.
  //
  // "seleccion" es el elemento principal (el que edita el inspector) y "extra"
  // son los demas del grupo. El inspector siempre enseña UNO: enseñar campos de
  // seis elementos a la vez pide decidir que pasa cuando no coinciden, y eso es
  // mas complicado de usar que util.
  //---------------------------------------------------------------------------
  seleccionar(id) {
    this.seleccion = id;
    this.extra = new Set(id ? [id] : []);
    this.refrescarSeleccion();
  }

  // como: "alternar" (Ctrl-clic) o "principal" (pasa a ser el que se edita).
  marcar(id, como) {
    if (!id) return;
    this.extra = this.extra || new Set();
    if (como === "principal") {
      this.extra.add(id);
      this.seleccion = id;
    } else if (this.extra.has(id) && this.extra.size > 1) {
      this.extra.delete(id);
      if (this.seleccion === id) this.seleccion = [...this.extra][0] || null;
    } else {
      this.extra.add(id);
      if (!this.seleccion) this.seleccion = id;
    }
    this.refrescarSeleccion();
  }

  marcarVarios(ids, sumar) {
    this.extra = new Set(sumar ? [...(this.extra || [])] : []);
    for (const id of ids) this.extra.add(id);
    // El principal se conserva si sigue en el grupo, y si no manda el primero
    // que se haya cogido: asi alinear tiene una referencia estable.
    if (!this.seleccion || !this.extra.has(this.seleccion)) this.seleccion = [...this.extra][0] || null;
    this.refrescarSeleccion();
  }

  refrescarSeleccion() {
    const id = this.seleccion;
    this.lienzo.fijarSeleccion(id, this.extra);
    this.capas.fijarSeleccion(id, this.extra);
    this.inspector.fijarSeleccion(id);
    this.tiempo.fijarSeleccion(id);
    this.pintarGrupo();
  }

  alinear(como) {
    if (!this.lienzo.alinear(como)) { this.toast("Marca al menos dos elementos", "warning"); return; }
    this.marcarSucio();
    this.inspector.refrescar();
  }

  repartir(eje) {
    if (!this.lienzo.repartir(eje)) { this.toast("Para repartir hacen falta tres o mas", "warning"); return; }
    this.marcarSucio();
    this.inspector.refrescar();
  }

  // Cuantos hay marcados y los botones de alinear, que solo tienen sentido con
  // varios: enseñarlos siempre apagados seria ruido permanente.
  pintarGrupo() {
    if (!this.barraGrupo) return;
    const n = (this.extra || new Set()).size;
    this.barraGrupo.style.display = (n > 1) ? "" : "none";
    if (this.etiquetaGrupo) this.etiquetaGrupo.textContent = `${n} elegidos`;
    for (const b of (this.botonesRepartir || [])) b.disabled = (n < 3);
  }

  //---------------------------------------------------------------------------
  // Guardar y ficheros.
  //---------------------------------------------------------------------------
  async guardar() {
    if (!this.diseno) return false;
    if (!this.nombre) {
      const n = await this.pedirNombre("Nombre del diseño");
      if (!n) return false;
      this.nombre = n;
      this.diseno.nombre = n;
    }
    try {
      await this.asegurarCarpeta();
      await this.ctx.fs.writeProjectFile(`${CARPETA}/${this.nombre}.json`, M.escribirJSON(this.diseno));
      this.sucio = false;
      this.pintarSucio();
      await this.recargarLista();
      this.selDiseno.value = this.nombre;
      this.toast(`Guardado en ${CARPETA}/${this.nombre}.json. En el juego: menu de debug, "Abrir una interfaz...".`, "success");
      return true;
    } catch (e) {
      this.toast(`No he podido guardar: ${e.message}`, "error");
      return false;
    }
  }

  async asegurarCarpeta() {
    try {
      if (this.ctx.fs.projectExists && !(await this.ctx.fs.projectExists(CARPETA))) {
        if (this.ctx.fs.projectMkdir) await this.ctx.fs.projectMkdir(CARPETA);
      }
    } catch { /* si no se puede comprobar, se intenta escribir igual */ }
  }

  async nuevo() {
    if (this.sucio && !(await this.confirmar("Hay cambios sin guardar. ¿Los descarto?"))) return;
    const n = await this.pedirNombre("Nombre del diseño nuevo");
    if (!n) return;
    this.cargarDiseno(M.disenoNuevo(n), n);
    this.sucio = true;
    this.pintarSucio();
  }

  async duplicar() {
    if (!this.diseno) return;
    const n = await this.pedirNombre("Nombre de la copia", this.nombre ? this.nombre + "_copia" : "");
    if (!n) return;
    const copia = JSON.parse(M.escribirJSON(this.diseno));
    copia.nombre = n;
    this.cargarDiseno(copia, n);
    await this.guardar();
  }

  async borrar() {
    if (!this.nombre) return;
    if (!(await this.confirmar(`¿Borro el diseño "${this.nombre}"? No se puede deshacer.`))) return;
    // La API de mods no expone borrar ficheros, asi que se vacia y se avisa: es
    // mejor decirlo que dejar creer que desaparecio.
    try {
      await this.ctx.fs.writeProjectFile(`${CARPETA}/${this.nombre}.json`, M.escribirJSON(M.disenoNuevo(this.nombre)));
      this.toast(`"${this.nombre}" se ha vaciado. Borra el fichero UI/${this.nombre}.json a mano para quitarlo de la lista.`, "warning");
      await this.abrirSinPreguntar(this.nombre);
    } catch (e) {
      this.toast(`No he podido vaciarlo: ${e.message}`, "error");
    }
  }

  async abrirSinPreguntar(nombre) {
    this.sucio = false;
    await this.abrir(nombre);
  }

  //---------------------------------------------------------------------------
  // Elementos.
  //---------------------------------------------------------------------------
  anadir(tipo) {
    if (!this.diseno) return;
    this.apuntarDeshacer();
    const id = M.idLibre(this.diseno, tipo);
    // En el centro, desplazado un poco por cada uno que ya haya, para que dos
    // elementos nuevos no queden uno tapando al otro.
    const n = this.diseno.elementos.length;
    const x = Math.round(M.LIENZO_ANCHO / 2) - 60 + (n % 6) * 8;
    const y = Math.round(M.LIENZO_ALTO / 2) - 20 + (n % 6) * 8;
    const el = M.elementoNuevo(tipo, id, x, y);
    const maxCapa = this.diseno.elementos.reduce((m, e) => Math.max(m, M.num(e.capa, 0)), 0);
    el.capa = maxCapa + 10;
    this.diseno.elementos.push(el);
    this.marcarSucio();
    this.seleccion = id;
    this.refrescarTodo();
  }

  // Una imagen que cubre el lienzo entero, colocada DEBAJO de todo. Es el primer
  // paso de casi cualquier pantalla completa, y a mano significa crear la imagen,
  // ponerla en 0,0 y acordarse de bajarla del todo en las capas.
  anadirFondo() {
    if (!this.diseno) return;
    this.apuntarDeshacer();
    const id = M.idLibre(this.diseno, "fondo");
    const el = M.elementoNuevo("imagen", id, 0, 0);
    // Por debajo de lo que ya hubiera, para que no tape nada.
    const minCapa = this.diseno.elementos.reduce((m, e) => Math.min(m, M.num(e.capa, 0)), 0);
    el.capa = minCapa - 10;
    this.diseno.elementos.push(el);
    this.marcarSucio();
    this.seleccion = id;
    this.refrescarTodo();
    this.toast(`Elige la imagen en "Fichero". Tiene que medir ${M.LIENZO_ANCHO}x${M.LIENZO_ALTO} para cubrir la pantalla entera.`, "info");
  }

  // Duplica todo el grupo, y las copias quedan marcadas: asi se puede duplicar
  // una fila de botones y arrastrarla entera al sitio, que es para lo que se
  // duplica un grupo.
  duplicarElemento() {
    const origen = (this.extra && this.extra.size)
      ? this.diseno.elementos.filter(e => this.extra.has(e.id))
      : [this.elementoElegido()].filter(Boolean);
    if (!origen.length) return;
    this.apuntarDeshacer();
    // Por encima de TODO lo que haya, no +1 sobre el original: si el elemento de
    // al lado ya estaba en esa capa, la copia aparecia por detras de el, que es lo
    // contrario de lo que uno espera al duplicar.
    let capa = this.diseno.elementos.reduce((m, e) => Math.max(m, M.num(e.capa, 0)), 0) + 10;
    const nuevos = [];
    for (const el of origen) {
      const copia = JSON.parse(JSON.stringify(el));
      copia.id = M.idLibre(this.diseno, el.id.replace(/_\d+$/, ""));
      copia.x = M.num(copia.x, 0) + 8;
      copia.y = M.num(copia.y, 0) + 8;
      copia.capa = capa;
      capa += 10;
      this.diseno.elementos.push(copia);
      nuevos.push(copia.id);
    }
    this.marcarSucio();
    this.seleccion = nuevos[0];
    this.extra = new Set(nuevos);
    this.refrescarTodo();
  }

  // Borra TODO el grupo, no solo el principal: si has marcado seis y le das a
  // Supr, esperas que se vayan los seis. Va en un solo paso de deshacer.
  borrarElemento() {
    const ids = new Set(this.extra && this.extra.size ? [...this.extra] : (this.seleccion ? [this.seleccion] : []));
    if (!ids.size) return;
    this.apuntarDeshacer();
    this.diseno.elementos = this.diseno.elementos.filter(e => !ids.has(e.id));
    this.seleccion = null;
    this.extra = new Set();
    this.marcarSucio();
    this.refrescarTodo();
  }

  elementoElegido() {
    if (!this.diseno || !this.seleccion) return null;
    return this.diseno.elementos.find(e => e.id === this.seleccion) || null;
  }

  //---------------------------------------------------------------------------
  // Deshacer. Se guardan fotos del diseño entero en texto: un diseño son unos
  // pocos kilobytes, asi que sale mas barato y mas fiable que ir apuntando
  // cambios sueltos.
  //---------------------------------------------------------------------------
  // Se llama ANTES de cada cambio, desde todas las piezas. Para que escribir en
  // un campo de texto no llene la pila de una foto por tecla, varios cambios
  // seguidos dentro de la misma ventana de tiempo cuentan como uno.
  // "motivo" agrupa: escribir en el mismo campo seguido cuenta como un paso, pero
  // escribir y luego arrastrar son DOS pasos.
  //
  // Antes solo se miraba el tiempo, asi que editar la capa de un elemento y 400 ms
  // despues arrastrar otro se fundian en una sola foto: un Ctrl+Z deshacia las dos
  // cosas y se perdia un cambio que nadie queria deshacer.
  apuntarDeshacer(motivo = null) {
    if (!this.diseno) return;
    const ahora = performance.now();
    const mismo = motivo != null && motivo === this._ultimoMotivo;
    if (mismo && this._ultimaFoto && (ahora - this._ultimaFoto) < VENTANA_DESHACER) return;
    this._ultimoMotivo = motivo;
    this._ultimaFoto = ahora;
    this.deshacerPila.push(M.escribirJSON(this.diseno));
    if (this.deshacerPila.length > TOPE_DESHACER) this.deshacerPila.shift();
    this.rehacerPila = [];
  }

  deshacer() {
    if (!this.deshacerPila.length) return;
    this.rehacerPila.push(M.escribirJSON(this.diseno));
    const foto = this.deshacerPila.pop();
    this.diseno = JSON.parse(foto);
    this.seleccion = null;
    this.sucio = true;
    this.refrescarTodo();
  }

  rehacer() {
    if (!this.rehacerPila.length) return;
    this.deshacerPila.push(M.escribirJSON(this.diseno));
    const foto = this.rehacerPila.pop();
    this.diseno = JSON.parse(foto);
    this.seleccion = null;
    this.sucio = true;
    this.refrescarTodo();
  }

  marcarSucio() {
    this.sucio = true;
    this.pintarSucio();
    this.pintarAvisos();
  }

  pintarSucio() {
    this.etiquetaSucio.textContent = this.sucio ? "· sin guardar" : "";
  }

  pintarAvisos() {
    if (!this.diseno) return;
    const avisos = M.revisar(this.diseno, this.catalogo || []);
    this.ultimosAvisos = avisos;
    if (!avisos.length) { this.avisosBtn.style.display = "none"; return; }
    this.avisosBtn.style.display = "";
    this.avisosBtn.textContent = `${avisos.length} aviso${avisos.length === 1 ? "" : "s"}`;
  }

  async mostrarAvisos() {
    const avisos = this.ultimosAvisos || [];
    if (!avisos.length) return;
    await this.confirmar("Cosas que revisar:\n\n- " + avisos.join("\n- "));
  }

  //---------------------------------------------------------------------------
  // MAPA DE APERTURAS: como se abre cada pantalla y quien lleva a quien.
  //
  // Existe para que la lista la lleve el programa y no tu. Sin esto habria que
  // acordarse de memoria de que interruptor lleva a que pantalla en cuanto haya
  // mas de tres.
  //---------------------------------------------------------------------------
  async mostrarMapaAperturas() {
    await this.recargarAperturas();
    const lineas = [];

    if (!this.catalogo.length) {
      await this.confirmar("Todavia no hay ninguna pantalla guardada.");
      return;
    }

    lineas.push("TUS PANTALLAS");
    lineas.push("");
    for (const e of this.catalogo) {
      const titulo = e.titulo ? ` (${e.titulo})` : "";
      lineas.push(`${e.nombre}${titulo}`);
      lineas.push(`    ${M.resumenAperturas(e)}`);
    }

    // Las del juego: cual sigue siendo la original y cual has reemplazado. Esta
    // es la lista que antes habria que llevar de memoria.
    lineas.push("");
    lineas.push("PANTALLAS DEL JUEGO");
    lineas.push("");
    for (const k of Object.keys(M.INTEGRADAS)) {
      const mia = this.catalogo.find(e => (e.aperturas || {}).interruptor === k);
      lineas.push(`${M.INTEGRADAS[k].titulo}  ("${k}")`);
      lineas.push(mia ? `    -> LA TUYA: ${mia.nombre}` : "    -> la del juego, sin tocar");
    }

    // Quien lleva a quien: se saca de los botones del diseño abierto, que es el
    // unico cuyos elementos tenemos cargados.
    const saltos = [];
    for (const el of (this.diseno?.elementos || [])) {
      const a = el.accion;
      if (!a) continue;
      if (a.tipo === "ir_a_interfaz" && a.interfaz) saltos.push(`    "${el.id}" -> ${a.interfaz}`);
      if (a.tipo === "abrir_interfaz" && a.interfaz) saltos.push(`    "${el.id}" -> ${a.interfaz} (encima)`);
      if (a.tipo === "interruptor_interfaz" && a.nombre) {
        const destino = this.interruptoresConocidos().find(c => c.interruptor === a.nombre);
        saltos.push(`    "${el.id}" -> interruptor "${a.nombre}" -> ${destino ? destino.nombre : "NADIE LO RECOGE"}`);
      }
    }
    if (saltos.length) {
      lineas.push("");
      lineas.push(`BOTONES DE "${this.nombre || "esta pantalla"}" QUE LLEVAN A OTRA`);
      lineas.push("");
      lineas.push(...saltos);
    }

    // Interruptores que nadie recoge, mirando todas las pantallas de golpe.
    const declarados = new Set(this.interruptoresConocidos().map(c => c.interruptor));
    const usados = new Set();
    for (const el of (this.diseno?.elementos || [])) {
      if (el.accion?.tipo === "interruptor_interfaz" && el.accion.nombre) usados.add(el.accion.nombre);
    }
    const huerfanos = [...usados].filter(u => !declarados.has(u));
    if (huerfanos.length) {
      lineas.push("");
      lineas.push("INTERRUPTORES QUE NO LLEVAN A NINGUNA PARTE");
      lineas.push(...huerfanos.map(u => `    "${u}"`));
    }

    lineas.push("");
    lineas.push("El menu de pausa y las teclas se leen al arrancar el juego.");
    lineas.push("Si cambias como se abre una pantalla, reinicia el juego una vez.");

    await this.confirmar(lineas.join("\n"));
  }

  //---------------------------------------------------------------------------
  // Teclado.
  //---------------------------------------------------------------------------
  conectarTeclado() {
    this._teclas = (e) => {
      if (!this.raiz.isConnected) return;
      const t = e.target;
      // Si se esta escribiendo en un campo, el teclado es del campo.
      if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.tagName === "SELECT")) return;

      const ctrl = e.ctrlKey || e.metaKey;
      if (ctrl && e.key.toLowerCase() === "s") { e.preventDefault(); this.guardar(); return; }
      if (ctrl && e.key.toLowerCase() === "d") { e.preventDefault(); this.duplicarElemento(); return; }
      if (ctrl && e.key.toLowerCase() === "z") { e.preventDefault(); e.shiftKey ? this.rehacer() : this.deshacer(); return; }
      if (ctrl && e.key.toLowerCase() === "y") { e.preventDefault(); this.rehacer(); return; }
      if (e.key === "Delete" || e.key === "Backspace") { e.preventDefault(); this.borrarElemento(); return; }

      const flechas = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
      if (flechas[e.key]) {
        const [dx, dy] = flechas[e.key];
        const paso = e.shiftKey ? M.REJILLA : 1;
        if (this.lienzo.empujar(dx, dy, paso)) {
          e.preventDefault();
          this.marcarSucio();
          this.inspector.refrescar();
        }
      }
    };
    document.addEventListener("keydown", this._teclas, true);
  }

  destruir() {
    document.removeEventListener("keydown", this._teclas, true);
    this.tiempo.parar();
    this.lienzo.desconectar();
    G.soltarImagenes();
  }

  //---------------------------------------------------------------------------
  // Dialogos, con reserva por si el editor no expone alguno.
  //---------------------------------------------------------------------------
  toast(mensaje, nivel = "info") {
    try { this.ctx.ui.showToast({ message: mensaje, level: nivel }); }
    catch { console.log("[Editor de Interfaces]", mensaje); }
  }

  async confirmar(mensaje) {
    try {
      const r = await this.ctx.ui.showConfirmDialog({ title: "Editor de Interfaces", message: mensaje });
      return r === true || r === "ok" || r === "yes" || r === "confirm";
    } catch { return true; }
  }

  async pedirTexto(titulo, valor = "") {
    try {
      const r = await this.ctx.ui.showInputDialog({ title: titulo, message: titulo, defaultValue: valor });
      return r ? String(r) : null;
    } catch { return null; }
  }

  // Un nombre de fichero seguro: sin espacios ni acentos, que es lo que espera
  // Ruby al construir la ruta y lo que evita sorpresas entre Windows y git.
  async pedirNombre(titulo, valor = "") {
    const bruto = await this.pedirTexto(titulo, valor);
    if (!bruto) return null;
    // NFD separa la tilde de la letra y luego se quitan los diacriticos, asi
    // "Misión" queda "mision" en vez de "misi_n".
    const limpio = String(bruto).trim().toLowerCase()
      .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9_-]+/g, "_").replace(/^_+|_+$/g, "");
    if (!limpio) { this.toast("Ese nombre no vale. Usa letras, numeros y guiones bajos.", "warning"); return null; }
    if (limpio !== String(bruto).trim()) this.toast(`Lo he guardado como "${limpio}".`, "info");
    return limpio;
  }
}
