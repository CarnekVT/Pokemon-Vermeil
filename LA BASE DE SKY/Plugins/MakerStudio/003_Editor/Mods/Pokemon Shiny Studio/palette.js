// Conversión y manipulación de colores para sprites y texturas

export function rgbToHex(r, g, b) {
  return "#" + [r, g, b].map(x => {
    const hex = Math.max(0, Math.min(255, Math.round(x))).toString(16);
    return hex.length === 1 ? "0" + hex : hex;
  }).join("");
}

export function hexToRgb(hex) {
  let c = hex.replace("#", "").trim();
  if (c.length === 3) c = c.split("").map(x => x + x).join("");
  const num = parseInt(c, 16);
  return {
    r: (num >> 16) & 255,
    g: (num >> 8) & 255,
    b: num & 255
  };
}

export function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h, s, l = (max + min) / 2;

  if (max === min) {
    h = s = 0; // achromatic
  } else {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break;
      case g: h = (b - r) / d + 2; break;
      case b: h = (r - g) / d + 4; break;
    }
    h *= 60;
  }
  return [h, s, l];
}

export function hslToRgb(h, s, l) {
  h = ((h % 360) + 360) % 360;
  let r, g, b;

  if (s === 0) {
    r = g = b = l; // achromatic
  } else {
    const hue2rgb = (p, q, t) => {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    };

    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h / 360 + 1 / 3);
    g = hue2rgb(p, q, h / 360);
    b = hue2rgb(p, q, h / 360 - 1 / 3);
  }

  return [Math.round(r * 255), Math.round(g * 255), Math.round(b * 255)];
}

// Extrae todos los colores únicos no transparentes de un canvas
export function extractPalette(canvas) {
  if (!canvas || canvas.width === 0 || canvas.height === 0) return [];
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  const imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const data = imgData.data;
  const map = new Map();

  for (let i = 0; i < data.length; i += 4) {
    const a = data[i + 3];
    if (a < 16) continue; // Descartar píxeles transparentes
    const r = data[i], g = data[i + 1], b = data[i + 2];
    const key = `${r},${g},${b}`;
    map.set(key, (map.get(key) || 0) + 1);
  }

  const entries = Array.from(map.entries()).map(([k, count]) => {
    const [r, g, b] = k.split(",").map(Number);
    const hex = rgbToHex(r, g, b);
    const [h, s, l] = rgbToHsl(r, g, b);
    return { r, g, b, hex, count, l, h, s };
  });

  // Ordenar por luminosidad descendente para agrupar tonos lógicamente
  entries.sort((a, b) => b.l - a.l);
  return entries;
}

// Reemplaza colores específicos según un mapa { hexOriginal => hexNuevo }
export function applyColorSwap(srcCanvas, destCanvas, colorMap) {
  if (!srcCanvas || !destCanvas) return;
  destCanvas.width = srcCanvas.width;
  destCanvas.height = srcCanvas.height;
  const srcCtx = srcCanvas.getContext("2d", { willReadFrequently: true });
  const destCtx = destCanvas.getContext("2d");
  const imgData = srcCtx.getImageData(0, 0, srcCanvas.width, srcCanvas.height);
  const d = imgData.data;

  // Convertir mapa a clave numérica rápida
  const fastMap = new Map();
  for (const [oldHex, newHex] of colorMap.entries()) {
    if (oldHex === newHex) continue;
    const o = hexToRgb(oldHex);
    const n = hexToRgb(newHex);
    const key = (o.r << 16) | (o.g << 8) | o.b;
    fastMap.set(key, n);
  }

  if (fastMap.size === 0) {
    destCtx.putImageData(imgData, 0, 0);
    return;
  }

  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] < 16) continue;
    const key = (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
    const match = fastMap.get(key);
    if (match) {
      d[i]     = match.r;
      d[i + 1] = match.g;
      d[i + 2] = match.b;
    }
  }

  destCtx.putImageData(imgData, 0, 0);
}

// Desplazamiento HSL general (Hue, Saturación, Brillo)
export function applyHslAdjustment(srcCanvas, destCanvas, { hueShift = 0, satMult = 1, lightShift = 0 } = {}) {
  if (!srcCanvas || !destCanvas) return;
  destCanvas.width = srcCanvas.width;
  destCanvas.height = srcCanvas.height;
  const srcCtx = srcCanvas.getContext("2d", { willReadFrequently: true });
  const destCtx = destCanvas.getContext("2d");
  const imgData = srcCtx.getImageData(0, 0, srcCanvas.width, srcCanvas.height);
  const d = imgData.data;

  const noOp = (hueShift % 360 === 0) && satMult === 1 && lightShift === 0;
  if (noOp) {
    destCtx.putImageData(imgData, 0, 0);
    return;
  }

  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] < 16) continue;
    let [h, s, l] = rgbToHsl(d[i], d[i + 1], d[i + 2]);
    h = (h + hueShift) % 360;
    if (h < 0) h += 360;
    s = Math.max(0, Math.min(1, s * satMult));
    l = Math.max(0, Math.min(1, l + lightShift / 100));

    const [nr, ng, nb] = hslToRgb(h, s, l);
    d[i]     = nr;
    d[i + 1] = ng;
    d[i + 2] = nb;
  }

  destCtx.putImageData(imgData, 0, 0);
}

export function cloneCanvas(srcCanvas) {
  if (!srcCanvas) return null;
  const copy = document.createElement("canvas");
  copy.width = srcCanvas.width;
  copy.height = srcCanvas.height;
  const ctx = copy.getContext("2d");
  ctx.drawImage(srcCanvas, 0, 0);
  return copy;
}

export function canvasToBlob(canvas) {
  return new Promise(resolve => canvas.toBlob(resolve, "image/png"));
}

// Compara un canvas base con un canvas variante y extrae el mapa de colores { hexBase => hexVar }
export function extractColorMapBetween(baseCanvas, variantCanvas) {
  const map = new Map();
  if (!baseCanvas || !variantCanvas) return map;
  const w = Math.min(baseCanvas.width, variantCanvas.width);
  const h = Math.min(baseCanvas.height, variantCanvas.height);
  if (w <= 0 || h <= 0) return map;

  const bCtx = baseCanvas.getContext("2d", { willReadFrequently: true });
  const vCtx = variantCanvas.getContext("2d", { willReadFrequently: true });
  const bData = bCtx.getImageData(0, 0, w, h).data;
  const vData = vCtx.getImageData(0, 0, w, h).data;

  for (let i = 0; i < bData.length; i += 4) {
    const bA = bData[i + 3];
    const vA = vData[i + 3];
    if (bA >= 16 && vA >= 16) {
      const bHex = rgbToHex(bData[i], bData[i + 1], bData[i + 2]);
      const vHex = rgbToHex(vData[i], vData[i + 1], vData[i + 2]);
      if (bHex !== vHex && !map.has(bHex)) {
        map.set(bHex, vHex);
      }
    }
  }
  return map;
}
