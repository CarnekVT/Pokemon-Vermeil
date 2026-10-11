//=============================================================================
// Resolution / canvas controls for Editor de Interfaces 2.x.
// Keeps logical game resolution independent from editor zoom.
//=============================================================================

import { h, boton, casilla } from "./dom.js";
import * as M from "../modelo.js";

const PRESETS = [
  { id: "512x384", w: 512, h: 384, label: "512 x 384 · 4:3 Essentials" },
  { id: "640x480", w: 640, h: 480, label: "640 x 480 · 4:3" },
  { id: "768x576", w: 768, h: 576, label: "768 x 576 · 4:3" },
  { id: "960x540", w: 960, h: 540, label: "960 x 540 · 16:9" },
  { id: "1280x720", w: 1280, h: 720, label: "1280 x 720 · 16:9" },
  { id: "custom", w: 0, h: 0, label: "Personalizada..." }
];

const ESTRATEGIAS = [
  { id: "anchors", label: "Adaptar con anchors" },
  { id: "scale", label: "Escalar todo" },
  { id: "positions", label: "Escalar posiciones" },
  { id: "keep", label: "Mantener coordenadas" }
];

const MODOS = [
  { id: "pixel_perfect", label: "Pixel Perfect" },
  { id: "fixed", label: "Fija" },
  { id: "fit", label: "Fit" },
  { id: "responsive", label: "Responsive" }
];

function option(value, text) { return h("option", { value, textContent: text }); }

export class Resolucion {
  constructor(opciones) {
    this.op = opciones || {};
    this.diseno = null;

    this.preset = h("select", { className: "ui-sel ui-res-preset" });
    for (const p of PRESETS) this.preset.appendChild(option(p.id, p.label));
    this.preset.addEventListener("change", () => this.aplicarPresetVisual());

    this.ancho = h("input", { type: "number", className: "ui-num ui-res-num", min: 160, max: 4096, step: 1, value: 512 });
    this.alto = h("input", { type: "number", className: "ui-num ui-res-num", min: 120, max: 4096, step: 1, value: 384 });
    this._ratio = 512 / 384;
    this._bloqueando = false;
    this.ancho.addEventListener("input", () => this.cambiarMedida("ancho"));
    this.alto.addEventListener("input", () => this.cambiarMedida("alto"));

    this.estrategia = h("select", { className: "ui-sel ui-res-estrategia" });
    for (const e of ESTRATEGIAS) this.estrategia.appendChild(option(e.id, e.label));

    this.modo = h("select", { className: "ui-sel ui-res-modo" });
    for (const m of MODOS) this.modo.appendChild(option(m.id, m.label));
    this.modo.addEventListener("change", () => this.cambiarOpcion("scale_mode", this.modo.value));

    this.info = h("span", { className: "ui-res-info", textContent: "4:3" });
    this.btnAplicar = boton("Aplicar", () => this.aplicar(), "primario");

    this.pixel = casilla(true, (v) => this.cambiarOpcion("pixel_perfect", v), "pixel perfect");
    this.entera = casilla(true, (v) => this.cambiarOpcion("integer_scaling", v), "escala entera");
    this.segura = casilla(false, (v) => this.cambiarOpcion("safe_area", v), "area segura");
    this.bloqueo = casilla(false, (v) => {
      this._ratio = Math.max(1, Number(this.ancho.value) || 512) / Math.max(1, Number(this.alto.value) || 384);
      this.cambiarOpcion("lock_aspect", v);
    }, "bloquear proporcion");

    this.el = h("div", { className: "ui-resolucion" },
      h("span", { className: "ui-capa-tipo", textContent: "Canvas" }),
      this.preset,
      this.ancho,
      h("span", { textContent: "×", className: "ui-res-x" }),
      this.alto,
      this.info,
      h("span", { className: "ui-res-sep" }),
      h("span", { className: "ui-capa-tipo", textContent: "Al cambiar" }),
      this.estrategia,
      this.btnAplicar,
      h("span", { className: "ui-barra-hueco" }),
      this.modo,
      this.pixel,
      this.entera,
      this.segura,
      this.bloqueo
    );
  }

  fijarDiseno(diseno) {
    this.diseno = diseno;
    if (!diseno) return;
    M.normalizarDiseno(diseno);
    const l = diseno.lienzo;
    this.ancho.value = String(M.num(l.ancho, M.LIENZO_ANCHO));
    this.alto.value = String(M.num(l.alto, M.LIENZO_ALTO));
    this.modo.value = l.scale_mode || "pixel_perfect";
    this._fijarCheck(this.pixel, l.pixel_perfect !== false);
    this._fijarCheck(this.entera, l.integer_scaling !== false);
    this._fijarCheck(this.segura, !!l.safe_area);
    this._fijarCheck(this.bloqueo, !!l.lock_aspect);
    this._ratio = Math.max(1, Number(this.ancho.value) || 512) / Math.max(1, Number(this.alto.value) || 384);
    const exacto = PRESETS.find(p => p.w === Number(this.ancho.value) && p.h === Number(this.alto.value));
    this.preset.value = exacto ? exacto.id : "custom";
    this.actualizarInfo();
  }

  _fijarCheck(label, valor) {
    const input = label && label.querySelector ? label.querySelector('input[type="checkbox"]') : null;
    if (input) input.checked = !!valor;
  }

  aplicarPresetVisual() {
    const p = PRESETS.find(x => x.id === this.preset.value);
    if (!p || p.id === "custom") return;
    this.ancho.value = String(p.w);
    this.alto.value = String(p.h);
    this._ratio = p.w / p.h;
    this.actualizarInfo();
  }

  cambiarMedida(cual) {
    if (this._bloqueando) return;
    const lock = this.bloqueo?.querySelector('input[type="checkbox"]')?.checked;
    if (lock && Number.isFinite(this._ratio) && this._ratio > 0) {
      this._bloqueando = true;
      if (cual === "ancho") {
        const w = Math.max(1, Number(this.ancho.value) || 1);
        this.alto.value = String(Math.max(120, Math.round(w / this._ratio)));
      } else {
        const h = Math.max(1, Number(this.alto.value) || 1);
        this.ancho.value = String(Math.max(160, Math.round(h * this._ratio)));
      }
      this._bloqueando = false;
    }
    this.actualizarInfo();
  }

  actualizarInfo() {
    const w = Math.max(1, Number(this.ancho.value) || 1);
    const h = Math.max(1, Number(this.alto.value) || 1);
    this.info.textContent = M.nombreAspecto(w, h);
    const exacto = PRESETS.find(p => p.w === w && p.h === h);
    if (exacto) this.preset.value = exacto.id;
    else if (this.preset.value !== "custom") this.preset.value = "custom";
  }

  cambiarOpcion(clave, valor) {
    if (!this.diseno) return;
    this.op.antesDeCambiar?.("canvas:" + clave);
    M.normalizarDiseno(this.diseno);
    this.diseno.lienzo[clave] = valor;
    this.op.alCambiar?.(clave);
  }

  aplicar() {
    if (!this.diseno) return;
    const w = Math.round(Number(this.ancho.value));
    const h = Math.round(Number(this.alto.value));
    if (!Number.isFinite(w) || !Number.isFinite(h) || w < 160 || h < 120 || w > 4096 || h > 4096) {
      this.op.avisar?.("La resolucion debe estar entre 160x120 y 4096x4096.");
      return;
    }
    this.op.alAplicar?.({ ancho: w, alto: h, estrategia: this.estrategia.value });
  }
}
