//=============================================================================
// Ayudantes de DOM. Mismo patron que usa el mod pbs-editor de este mismo editor,
// para que los dos se lean igual.
//=============================================================================

export function h(tag, attrs, ...hijos) {
  const el = document.createElement(tag);
  if (attrs) {
    for (const [k, v] of Object.entries(attrs)) {
      if (v == null) continue;
      if (k === "style" && typeof v === "object") Object.assign(el.style, v);
      else if (k.startsWith("on")) el.addEventListener(k.slice(2).toLowerCase(), v);
      else if (k === "className") el.className = v;
      else if (k === "textContent") el.textContent = v;
      else if (k === "innerHTML") el.innerHTML = v;
      else if (k === "dataset") Object.assign(el.dataset, v);
      else if (k === "disabled" || k === "checked" || k === "selected" || k === "readOnly") { if (v) el[k] = true; }
      else el.setAttribute(k, v);
    }
  }
  for (const c of hijos) {
    if (c == null || c === false) continue;
    if (typeof c === "string" || typeof c === "number") el.appendChild(document.createTextNode(String(c)));
    else if (c instanceof Node) el.appendChild(c);
  }
  return el;
}

export function boton(texto, alPulsar, variante = "") {
  return h("button", { className: "ui-btn " + variante, textContent: texto, onClick: alPulsar });
}

export function iconoBoton(svg, titulo, alPulsar, variante = "") {
  return h("button", { className: "ui-btn ui-btn-icono " + variante, innerHTML: svg, title: titulo, onClick: alPulsar });
}

// Una fila de "etiqueta + control" del inspector.
export function fila(etiqueta, ...controles) {
  return h("div", { className: "ui-fila" },
    h("label", { className: "ui-etiqueta", textContent: etiqueta }),
    h("div", { className: "ui-controles" }, ...controles)
  );
}

export function campoNumero(valor, alCambiar, opciones = {}) {
  const inp = h("input", {
    type: "number",
    className: "ui-num",
    value: valor == null ? "" : String(valor),
    step: opciones.paso == null ? 1 : opciones.paso,
    min: opciones.min,
    max: opciones.max,
    placeholder: opciones.hueco || ""
  });
  inp.addEventListener("input", () => {
    if (inp.value === "") { alCambiar(null); return; }
    const n = parseFloat(inp.value);
    if (!Number.isNaN(n)) alCambiar(n);
  });
  return inp;
}

export function campoTexto(valor, alCambiar, hueco = "") {
  const inp = h("input", { type: "text", className: "ui-txt", value: valor == null ? "" : String(valor), placeholder: hueco });
  inp.addEventListener("input", () => alCambiar(inp.value));
  return inp;
}

export function desplegable(valor, opciones, alCambiar) {
  const sel = h("select", { className: "ui-sel" });
  for (const o of opciones) {
    const v = typeof o === "string" ? o : o.valor;
    const t = typeof o === "string" ? o : o.texto;
    sel.appendChild(h("option", { value: v, textContent: t, selected: v === valor }));
  }
  sel.addEventListener("change", () => alCambiar(sel.value));
  return sel;
}

export function casilla(valor, alCambiar, etiqueta) {
  const inp = h("input", { type: "checkbox", checked: !!valor });
  inp.addEventListener("change", () => alCambiar(inp.checked));
  return h("label", { className: "ui-casilla" }, inp, h("span", { textContent: etiqueta || "" }));
}

// Campo de color con muestra. Guarda "#RRGGBB" o "#RRGGBBAA", que es lo que
// entiende el motor en Ruby.
export function campoColor(valor, alCambiar) {
  const v = normalizarColor(valor) || "#000000FF";
  const muestra = h("input", { type: "color", className: "ui-color", value: v.slice(0, 7) });
  const alfa = h("input", { type: "range", className: "ui-alfa", min: 0, max: 255, value: parseInt(v.slice(7, 9) || "ff", 16) });
  const texto = h("input", { type: "text", className: "ui-txt ui-color-txt", value: v });

  const emitir = (nuevo) => { texto.value = nuevo; alCambiar(nuevo); };
  const componer = () => {
    const a = Number(alfa.value).toString(16).padStart(2, "0").toUpperCase();
    emitir(muestra.value.toUpperCase() + a);
  };
  muestra.addEventListener("input", componer);
  alfa.addEventListener("input", componer);
  texto.addEventListener("input", () => {
    const n = normalizarColor(texto.value);
    if (!n) return;
    muestra.value = n.slice(0, 7);
    alfa.value = parseInt(n.slice(7, 9) || "ff", 16);
    alCambiar(n);
  });
  return h("div", { className: "ui-color-fila" }, muestra, alfa, texto);
}

export function normalizarColor(v) {
  if (!v) return null;
  let t = String(v).trim();
  if (t.startsWith("#")) t = t.slice(1);
  if (!/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(t)) return null;
  if (t.length === 6) t += "FF";
  return "#" + t.toUpperCase();
}

// "#RRGGBBAA" -> "rgba(r,g,b,a)" para pintar en el canvas.
export function colorCss(v, porDefecto = "#000000FF") {
  const n = normalizarColor(v) || normalizarColor(porDefecto);
  const r = parseInt(n.slice(1, 3), 16);
  const g = parseInt(n.slice(3, 5), 16);
  const b = parseInt(n.slice(5, 7), 16);
  const a = parseInt(n.slice(7, 9), 16) / 255;
  return `rgba(${r},${g},${b},${a})`;
}

export function separador() {
  return h("div", { className: "ui-sep" });
}

export function titulillo(texto) {
  return h("div", { className: "ui-titulillo", textContent: texto });
}
