//=============================================================================
// La lista de capas.
//
// Se muestra de arriba a abajo como en cualquier editor de imagenes: lo primero
// de la lista es lo que se dibuja ENCIMA.
//
// AL ARRASTRAR SE RENUMERAN TODAS LAS CAPAS de 10 en 10. Se eligio asi porque la
// alternativa (respetar los numeros que hubiera y colarse entre ellos) obliga a
// entender que la capa es un numero y que puede haber huecos. Aqui la lista ES el
// orden, y el numero es un detalle que casi nunca hay que mirar.
//=============================================================================

import { h, iconoBoton } from "./dom.js";
import * as M from "../modelo.js";

const OJO = "&#128065;";
const CANDADO = "&#128274;";

export class Capas {
  constructor(opciones) {
    this.op = opciones;              // {alSeleccionar, alCambiar}
    this.diseno = null;
    this.seleccion = null;

    this.lista = h("div", { className: "ui-capas" });
    this.el = h("div", { className: "ui-panel-izq" },
      h("div", { className: "ui-cabecera-panel" },
        h("span", { textContent: "Capas" }),
        h("span", { className: "ui-barra-hueco" }),
        h("span", { className: "ui-capa-tipo", textContent: "arriba = delante" })
      ),
      this.lista
    );
  }

  fijarDiseno(diseno) { this.diseno = diseno; this.refrescar(); }

  fijarSeleccion(id, extra) {
    this.seleccion = id;
    this.extra = new Set(extra || []);
    this.refrescar();
  }

  // De delante a atras, que es como se lee una lista de capas.
  ordenados() {
    return (this.diseno?.elementos || [])
      .map((el, i) => ({ el, i }))
      .sort((a, b) => (M.num(b.el.capa, 0) - M.num(a.el.capa, 0)) || (b.i - a.i))
      .map(x => x.el);
  }

  refrescar() {
    this.lista.innerHTML = "";
    const els = this.ordenados();
    if (!els.length) {
      this.lista.appendChild(h("div", { className: "ui-ayuda", style: { padding: "10px" },
        textContent: "Todavia no hay nada. Añade algo con los botones de arriba." }));
      return;
    }
    els.forEach((el) => this.lista.appendChild(this.filaCapa(el)));
  }

  filaCapa(el) {
    const elegida = el.id === this.seleccion;
    // Los del grupo se marcan tambien aqui, mas suave. Es donde se ve de un
    // vistazo cuantos hay cogidos, incluso los que quedan fuera de pantalla.
    const enGrupo = !elegida && this.extra && this.extra.has(el.id);
    const fila = h("div", {
      className: "ui-capa" + (elegida ? " elegida" : (enGrupo ? " en-grupo" : "")),
      draggable: "true",
      dataset: { id: el.id },
      // Ctrl o Shift añaden al grupo desde la lista, igual que en el lienzo: con
      // veinte botones apilados es mas comodo marcarlos aqui que en el dibujo.
      onClick: (e) => {
        if (e.ctrlKey || e.shiftKey) this.op.alMarcar?.(el.id, "alternar");
        else this.op.alSeleccionar?.(el.id);
      },
      onDblclick: () => this.renombrar(el)
    });

    const ojo = iconoBoton(OJO, el.visible === false ? "No se ve en el juego" : "Se ve en el juego",
      (e) => {
        e.stopPropagation();
        el.visible = (el.visible === false) ? true : false;
        this.op.alCambiar?.();
      });
    ojo.className = "ui-ojo" + (el.visible === false ? " apagado" : "");

    const candado = iconoBoton(CANDADO, el.bloqueado ? "Bloqueado: no se puede tocar en el lienzo" : "Bloquear para no moverlo sin querer",
      (e) => {
        e.stopPropagation();
        el.bloqueado = !el.bloqueado;
        this.op.alCambiar?.();
      });
    candado.className = "ui-ojo" + (el.bloqueado ? "" : " apagado");

    fila.appendChild(ojo);
    fila.appendChild(h("span", { className: "ui-capa-id", textContent: el.id, title: el.id }));
    // Marcas de un vistazo: lo que se repite y lo que tiene condicion. Sin esto
    // habria que ir elemento por elemento para saber por que algo no sale.
    let marca = "";
    if (el.repetir) marca += "x" + el.repetir + " ";
    if (el.hueco) marca += "▦ ";          // va en un hueco que se rellena
    if (el.mostrar_si) marca += "?";
    if (el.activo_si) marca += "⊘";       // se puede apagar
    if (marca) {
      fila.appendChild(h("span", { className: "ui-capa-tipo", style: { color: "var(--accent)" },
        textContent: marca.trim(),
        title: (el.repetir ? "Se repite en el grupo " + el.repetir + ". " : "") +
               (el.hueco ? "Se coloca en los huecos de " + el.hueco + ". " : "") +
               (el.mostrar_si ? "Se ve " + M.resumenCondicion(el.mostrar_si) + ". " : "") +
               (el.activo_si ? "Se puede pulsar " + M.resumenCondicion(el.activo_si) : "") }));
    }
    fila.appendChild(h("span", { className: "ui-capa-tipo", textContent: M.NOMBRE_TIPO[el.tipo] || el.tipo }));
    fila.appendChild(candado);

    this.conectarArrastre(fila, el);
    return fila;
  }

  //---------------------------------------------------------------------------
  // Reordenar arrastrando.
  //---------------------------------------------------------------------------
  conectarArrastre(fila, el) {
    fila.addEventListener("dragstart", (e) => {
      e.dataTransfer.setData("text/plain", el.id);
      e.dataTransfer.effectAllowed = "move";
      fila.classList.add("arrastrando");
    });
    fila.addEventListener("dragend", () => {
      fila.classList.remove("arrastrando");
      this.lista.querySelectorAll(".ui-capa").forEach(f => f.classList.remove("destino"));
    });
    fila.addEventListener("dragover", (e) => {
      e.preventDefault();
      fila.classList.add("destino");
    });
    fila.addEventListener("dragleave", () => fila.classList.remove("destino"));
    fila.addEventListener("drop", (e) => {
      e.preventDefault();
      fila.classList.remove("destino");
      const movido = e.dataTransfer.getData("text/plain");
      if (movido && movido !== el.id) this.mover(movido, el.id);
    });
  }

  mover(idMovido, idDestino) {
    this.op.antesDeCambiar?.();            // renumera TODAS las capas: hay que poder deshacerlo
    const orden = this.ordenados().map(e => e.id);
    const desde = orden.indexOf(idMovido);
    const hasta = orden.indexOf(idDestino);
    if (desde < 0 || hasta < 0) return;
    orden.splice(desde, 1);
    orden.splice(hasta, 0, idMovido);
    this.renumerar(orden);
    this.op.alCambiar?.();
  }

  // orden viene de delante a atras, asi que el primero se lleva la capa mas alta.
  renumerar(ordenVisual) {
    const total = ordenVisual.length;
    ordenVisual.forEach((id, i) => {
      const el = (this.diseno.elementos || []).find(e => e.id === id);
      if (el) el.capa = (total - i) * 10;
    });
  }

  async renombrar(el) {
    const nuevo = await this.op.pedirTexto?.("Nombre del elemento", el.id);
    if (!nuevo || nuevo === el.id) return;
    const limpio = String(nuevo).trim().replace(/\s+/g, "_");
    if (!limpio) return;
    if ((this.diseno.elementos || []).some(e => e !== el && e.id === limpio)) {
      this.op.avisar?.(`Ya hay un elemento llamado "${limpio}"`);
      return;
    }
    this.op.antesDeCambiar?.();
    const antiguo = el.id;
    el.id = limpio;

    // SE ARRASTRAN LAS CONDICIONES QUE APUNTABAN A ESTE BOTON.
    //
    // Desde que existen las condiciones "cuando este elegido tal boton", los ids
    // SI se referencian entre elementos. Renombrar sin actualizarlas dejaria
    // condiciones apuntando a un boton que ya no existe, y eso no falla con un
    // error: el elemento simplemente deja de aparecer, que es peor.
    // Se baja hasta el fondo de los grupos ("todas" / "alguna"): una referencia
    // enterrada dentro de un grupo se rompe igual de silenciosamente que una
    // suelta, y ahi todavia es mas dificil de encontrar.
    let arrastradas = 0;
    const renombrarEn = (cond, hondura = 0) => {
      if (!cond || typeof cond !== "object" || hondura > M.ANIDAMIENTO_MAXIMO) return;
      if (Array.isArray(cond)) { for (const c of cond) renombrarEn(c, hondura + 1); return; }
      const junta = M.JUNTAS.find(j => j in cond);
      if (junta) {
        if (Array.isArray(cond[junta])) for (const c of cond[junta]) renombrarEn(c, hondura + 1);
        return;
      }
      if (String(cond.dato || "") !== `{seleccion.${antiguo}}`) return;
      cond.dato = `{seleccion.${limpio}}`;
      arrastradas++;
    };
    for (const otro of (this.diseno.elementos || [])) {
      renombrarEn(otro.mostrar_si);
      renombrarEn(otro.activo_si);
    }
    if (arrastradas > 0) {
      this.op.avisar?.(`Renombrado, y ${arrastradas} condicion(es) que lo miraban se han actualizado`);
    }
    this.op.alRenombrar?.(antiguo, limpio);
    this.op.alCambiar?.();
  }
}
