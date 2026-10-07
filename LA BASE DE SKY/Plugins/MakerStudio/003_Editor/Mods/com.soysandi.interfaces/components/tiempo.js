//=============================================================================
// La linea de tiempo: claves de animacion del elemento elegido.
//
// COMO SE LEE
//   Cada fila es una propiedad (Posicion X, Transparencia...). Los rombos son
//   claves: momentos en los que la propiedad vale algo concreto. Entre dos claves
//   el motor interpola con el suavizado de la clave de LLEGADA, que es como
//   funcionan las herramientas de animacion de verdad.
//
//   El reproductor mueve el mismo reloj que usa el lienzo, asi que lo que se ve
//   al darle a play es exactamente lo que hara el juego: las curvas son las
//   mismas, portadas en modelo.js.
//=============================================================================

import { h, boton, desplegable, campoNumero, casilla } from "./dom.js";
import * as M from "../modelo.js";

export class Tiempo {
  constructor(opciones) {
    this.op = opciones;                 // {alCambiarTiempo, alCambiar}
    this.diseno = null;
    this.seleccion = null;
    this.tiempo = 0;
    this.duracion = 2;
    this.reproduciendo = false;
    this.claveElegida = null;           // {propiedad, indice}
    this._ultimo = 0;

    this.reloj = h("span", { className: "ui-tiempo-reloj", textContent: "0.00 / 2.00 s" });
    this.btnPlay = boton("Play", () => this.alternar());
    this.deslizador = h("input", { type: "range", min: 0, max: 1000, value: 0, style: { flex: "1", minWidth: "120px" } });
    this.deslizador.addEventListener("input", () => {
      this.parar();
      this.fijarTiempo((Number(this.deslizador.value) / 1000) * this.duracion);
      this.op.alCambiarTiempo?.(this.tiempo);
    });

    this.selPropiedad = desplegable("", [], () => {});
    this.btnAnadir = boton("Animar esta propiedad", () => this.anadirPista());

    this.barra = h("div", { className: "ui-tiempo-barra" },
      this.btnPlay,
      boton("Al principio", () => { this.parar(); this.fijarTiempo(0); this.op.alCambiarTiempo?.(0); }),
      this.reloj,
      this.deslizador,
      this.selPropiedad,
      this.btnAnadir
    );

    this.pistas = h("div", { className: "ui-pistas" });
    this.el = h("div", { className: "ui-tiempo" }, this.barra, this.pistas);
  }

  fijarDiseno(d) { this.diseno = d; this.recalcularDuracion(); this.refrescar(); }
  fijarSeleccion(id) { this.seleccion = id; this.claveElegida = null; this.refrescar(); }

  fijarTiempo(t) {
    this.duracion = Math.max(this.duracion, 0.5);
    this.tiempo = Math.max(0, Math.min(t, this.duracion));
    this.reloj.textContent = `${this.tiempo.toFixed(2)} / ${this.duracion.toFixed(2)} s`;
    this.deslizador.value = Math.round((this.tiempo / this.duracion) * 1000);
    this.pintarAgujas();
  }

  recalcularDuracion() {
    this.duracion = Math.max(M.duracionDiseno(this.diseno || {}), 0.5);
    this.fijarTiempo(this.tiempo);
  }

  elegido() {
    if (!this.diseno || !this.seleccion) return null;
    return (this.diseno.elementos || []).find(e => e.id === this.seleccion) || null;
  }

  //---------------------------------------------------------------------------
  // Reproduccion.
  //---------------------------------------------------------------------------
  alternar() { this.reproduciendo ? this.parar() : this.arrancar(); }

  arrancar() {
    if (this.reproduciendo) return;
    this.reproduciendo = true;
    this.btnPlay.textContent = "Pausa";
    this._ultimo = performance.now();
    const paso = (ahora) => {
      if (!this.reproduciendo) return;
      const dt = (ahora - this._ultimo) / 1000;
      this._ultimo = ahora;
      let t = this.tiempo + dt;
      if (t > this.duracion) t = 0;           // en bucle, para ver la entrada otra vez
      this.fijarTiempo(t);
      this.op.alCambiarTiempo?.(this.tiempo);
      requestAnimationFrame(paso);
    };
    requestAnimationFrame(paso);
  }

  parar() {
    this.reproduciendo = false;
    this.btnPlay.textContent = "Play";
  }

  //---------------------------------------------------------------------------
  refrescar() {
    this.pistas.innerHTML = "";
    const el = this.elegido();

    // El desplegable solo ofrece las propiedades que aun no tienen pista.
    const usadas = new Set((el?.animaciones || []).map(p => p.propiedad));
    const libres = M.PROPIEDADES.filter(p => !usadas.has(p));
    this.selPropiedad.innerHTML = "";
    for (const p of libres) {
      this.selPropiedad.appendChild(h("option", { value: p, textContent: M.NOMBRE_PROPIEDAD[p] || p }));
    }
    this.selPropiedad.disabled = !el || !libres.length;
    this.btnAnadir.disabled = !el || !libres.length;

    if (!el) {
      this.pistas.appendChild(h("div", { className: "ui-ayuda", style: { padding: "10px" },
        textContent: "Elige un elemento para animarlo." }));
      return;
    }
    const lista = el.animaciones || [];
    if (!lista.length) {
      this.pistas.appendChild(h("div", { className: "ui-ayuda", style: { padding: "10px" },
        textContent: "Este elemento no tiene animacion de claves. Para que solo aparezca al abrirse basta con \"Como aparece\" en las propiedades; las claves son para movimientos mas largos o en bucle." }));
      return;
    }
    for (const pista of lista) this.pistas.appendChild(this.filaPista(el, pista));
    if (this.claveElegida) this.pistas.appendChild(this.editorClave(el));
    this.pintarAgujas();
  }

  filaPista(el, pista) {
    const carril = h("div", { className: "ui-pista-carril" });
    carril.appendChild(h("div", { className: "ui-aguja", style: { left: "0px" } }));

    // Doble clic en un hueco: clave nueva ahi, con el valor que tenga en ese
    // instante, para que añadir una clave nunca de un salto.
    carril.addEventListener("dblclick", (e) => {
      const caja = carril.getBoundingClientRect();
      const t = ((e.clientX - caja.left) / caja.width) * this.duracion;
      this.anadirClave(el, pista, Math.max(0, t));
    });

    (pista.claves || []).forEach((clave, i) => {
      const rombo = h("div", {
        className: "ui-clave" + (this.claveElegida && this.claveElegida.propiedad === pista.propiedad && this.claveElegida.indice === i ? " elegida" : ""),
        title: `${M.num(clave.t, 0).toFixed(2)} s = ${clave.valor}`,
        style: { left: `${(M.num(clave.t, 0) / this.duracion) * 100}%` }
      });
      rombo.addEventListener("mousedown", (e) => {
        e.stopPropagation();
        this.claveElegida = { propiedad: pista.propiedad, indice: i };
        this.arrastrarClave(e, carril, pista, clave);
        this.refrescar();
      });
      rombo.addEventListener("dblclick", (e) => {
        e.stopPropagation();
        this.borrarClave(el, pista, i);
      });
      carril.appendChild(rombo);
    });

    const quitar = boton("Quitar", () => {
      this.op.antesDeCambiar?.();          // se lleva la pista entera con sus claves
      el.animaciones = (el.animaciones || []).filter(p => p !== pista);
      if (!el.animaciones.length) delete el.animaciones;
      this.claveElegida = null;
      this.op.alCambiar?.();
      this.recalcularDuracion();
      this.refrescar();
    }, "peligro");
    quitar.style.padding = "2px 6px";

    return h("div", { className: "ui-pista" },
      h("span", { className: "ui-pista-nombre", textContent: M.NOMBRE_PROPIEDAD[pista.propiedad] || pista.propiedad }),
      carril,
      casilla(!!pista.bucle, (v) => { pista.bucle = v || undefined; this.op.alCambiar?.(); }, "bucle"),
      quitar
    );
  }

  arrastrarClave(evento, carril, pista, clave) {
    const caja = carril.getBoundingClientRect();
    const mover = (e) => {
      const t = ((e.clientX - caja.left) / caja.width) * this.duracion;
      clave.t = Math.max(0, Math.round(t * 100) / 100);
      pista.claves.sort((a, b) => M.num(a.t, 0) - M.num(b.t, 0));
      this.op.alCambiar?.();
      this.refrescar();
    };
    const soltar = () => {
      window.removeEventListener("mousemove", mover);
      window.removeEventListener("mouseup", soltar);
      this.recalcularDuracion();
      this.refrescar();
    };
    window.addEventListener("mousemove", mover);
    window.addEventListener("mouseup", soltar);
    evento.preventDefault();
  }

  // Los datos de la clave elegida, para poder afinarla a mano.
  editorClave(el) {
    const pista = (el.animaciones || []).find(p => p.propiedad === this.claveElegida.propiedad);
    if (!pista) return h("div");
    const clave = (pista.claves || [])[this.claveElegida.indice];
    if (!clave) return h("div");

    return h("div", { className: "ui-pista", style: { height: "auto", padding: "6px 8px", flexWrap: "wrap" } },
      h("span", { className: "ui-pista-nombre", textContent: "Clave elegida" }),
      h("span", { textContent: "en" }),
      campoNumero(M.num(clave.t, 0), (v) => {
        clave.t = Math.max(0, v || 0);
        pista.claves.sort((a, b) => M.num(a.t, 0) - M.num(b.t, 0));
        this.op.alCambiar?.(); this.recalcularDuracion(); this.refrescar();
      }, { paso: 0.05, min: 0 }),
      h("span", { textContent: "s vale" }),
      campoNumero(M.num(clave.valor, 0), (v) => { clave.valor = v; this.op.alCambiar?.(); this.refrescar(); }, { paso: 1 }),
      h("span", { textContent: "llegando con" }),
      desplegable(clave.suavizado || M.SUAVIZADO_DEFECTO, M.SUAVIZADOS, (v) => { clave.suavizado = v; this.op.alCambiar?.(); }),
      boton("Borrar clave", () => this.borrarClave(el, pista, this.claveElegida.indice), "peligro")
    );
  }

  //---------------------------------------------------------------------------
  anadirPista() {
    const el = this.elegido();
    if (!el) return;
    const propiedad = this.selPropiedad.value;
    if (!propiedad) return;
    this.op.antesDeCambiar?.();
    // Dos claves de salida: del valor actual al mismo valor. Asi la pista nace
    // sin cambiar nada y se retoca desde ahi, en vez de dar un salto raro.
    const actual = M.valorDe(el, propiedad, 0);
    el.animaciones = el.animaciones || [];
    el.animaciones.push({
      propiedad,
      claves: [
        { t: 0, valor: Math.round(actual * 100) / 100 },
        { t: 1, valor: Math.round(actual * 100) / 100, suavizado: M.SUAVIZADO_DEFECTO }
      ]
    });
    this.op.alCambiar?.();
    this.recalcularDuracion();
    this.refrescar();
  }

  anadirClave(el, pista, t) {
    this.op.antesDeCambiar?.();
    const valor = M.valorDe(el, pista.propiedad, t);
    pista.claves.push({ t: Math.round(t * 100) / 100, valor: Math.round(valor * 100) / 100, suavizado: M.SUAVIZADO_DEFECTO });
    pista.claves.sort((a, b) => M.num(a.t, 0) - M.num(b.t, 0));
    this.op.alCambiar?.();
    this.recalcularDuracion();
    this.refrescar();
  }

  borrarClave(el, pista, indice) {
    this.op.antesDeCambiar?.();
    if (pista.claves.length <= 2) {
      // Con menos de dos claves una pista no interpola nada: mejor quitarla
      // entera que dejarla a medias sin que se entienda por que no hace nada.
      el.animaciones = (el.animaciones || []).filter(p => p !== pista);
      if (!el.animaciones.length) delete el.animaciones;
    } else {
      pista.claves.splice(indice, 1);
    }
    this.claveElegida = null;
    this.op.alCambiar?.();
    this.recalcularDuracion();
    this.refrescar();
  }

  pintarAgujas() {
    const pct = this.duracion > 0 ? (this.tiempo / this.duracion) * 100 : 0;
    this.pistas.querySelectorAll(".ui-aguja").forEach(a => { a.style.left = pct + "%"; });
  }
}
