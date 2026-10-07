function makeCanvas(w, h) {
  const c = document.createElement("canvas");
  c.width = Math.max(1, Math.round(w));
  c.height = Math.max(1, Math.round(h));
  return c;
}

function ctx2d(canvas) {
  const c = canvas.getContext("2d", { willReadFrequently: true });
  c.imageSmoothingEnabled = false;
  return c;
}

function canvasBlob(canvas) {
  return new Promise((resolve, reject) => canvas.toBlob((b) => b ? resolve(b) : reject(new Error("No se pudo codificar el PNG.")), "image/png"));
}

async function decodeBlob(blob) {
  if (typeof createImageBitmap === "function") {
    try { return await createImageBitmap(blob); } catch (_) {}
  }
  const url = URL.createObjectURL(blob);
  try {
    const img = new Image();
    await new Promise((resolve, reject) => {
      img.onload = resolve;
      img.onerror = () => reject(new Error("El PNG no pudo decodificarse."));
      img.src = url;
    });
    return img;
  } finally {
    URL.revokeObjectURL(url);
  }
}

function detectLayout(w, h) {
  // inteligente: si ancho divisible por alto → tira horizontal de frames cuadrados, sin límite fijo
  if (h > 0 && w % h === 0 && w / h >= 2) {
    return { orientation: "horizontal", frameW: h, frameH: h, frameCount: Math.round(w / h) };
  }
  if (w > 0 && h % w === 0 && h / w >= 2) {
    return { orientation: "vertical", frameW: w, frameH: w, frameCount: Math.round(h / w) };
  }
  if (w >= h * 1.5 && w % 2 === 0) return { orientation: "horizontal", frameW: w / 2, frameH: h, frameCount: 2 };
  if (h >= w * 1.5 && h % 2 === 0) return { orientation: "vertical", frameW: w, frameH: h / 2, frameCount: 2 };
  return { orientation: "horizontal", frameW: w, frameH: h, frameCount: 1 };
}

function detectBattlerLayout(w, h) {
  // inteligente sin parámetros fijos: tira cuadrada si divisible, sino busca divisor
  if (h > 0 && w % h === 0 && w / h >= 2) {
    return { orientation: "horizontal", frameW: h, frameH: h, frameCount: Math.round(w / h) };
  }
  if (w > 0 && h % w === 0 && h / w >= 2) {
    return { orientation: "vertical", frameW: w, frameH: w, frameCount: Math.round(h / w) };
  }
  if (w >= h * 1.5 && w % 2 === 0) {
    const f = Math.round(w / 2);
    if (h > 0 && w % f === 0) return { orientation: "horizontal", frameW: f, frameH: h, frameCount: Math.round(w / f) };
    return { orientation: "horizontal", frameW: w / 2, frameH: h, frameCount: 2 };
  }
  if (h >= w * 1.5 && h % 2 === 0) {
    const f = Math.round(h / 2);
    if (w > 0 && h % f === 0) return { orientation: "vertical", frameW: w, frameH: f, frameCount: Math.round(h / f) };
    return { orientation: "vertical", frameW: w, frameH: h / 2, frameCount: 2 };
  }
  return { orientation: "horizontal", frameW: w, frameH: h, frameCount: 1 };
}

function cloneImageData(data) {
  return new ImageData(new Uint8ClampedArray(data.data), data.width, data.height);
}

export class IconDocument {
  constructor({ orientation, frameW, frameH, frames, sourcePath = "" }) {
    this.orientation = orientation || "horizontal";
    this.frameW = frameW;
    this.frameH = frameH;
    this.frames = frames || [];
    this.sourcePath = sourcePath;
    this.offsets = this.frames.map(() => ({ x: 0, y: 0 }));
    this.undoStack = [];
    this.redoStack = [];
    this.dirty = false;
    this.maxHistory = 40;
  }

  static async fromBytes(bytes, sourcePath = "") {
    return this.fromBlob(new Blob([bytes], { type: "image/png" }), sourcePath);
  }

  static async fromBlob(blob, sourcePath = "") {
    const image = await decodeBlob(blob);
    const layout = detectLayout(image.width, image.height);
    const frames = [];
    for (let i = 0; i < layout.frameCount; i++) {
      const c = makeCanvas(layout.frameW, layout.frameH);
      const x = layout.orientation === "horizontal" ? i * layout.frameW : 0;
      const y = layout.orientation === "vertical" ? i * layout.frameH : 0;
      ctx2d(c).drawImage(image, x, y, layout.frameW, layout.frameH, 0, 0, layout.frameW, layout.frameH);
      frames.push(c);
    }
    if (typeof image.close === "function") try { image.close(); } catch (_) {}
    return new IconDocument({ ...layout, frames, sourcePath });
  }

  static blank(frameW = 64, frameH = 64, frameCount = 2, sourcePath = "") {
    const frames = Array.from({ length: Math.max(2, frameCount) }, () => makeCanvas(frameW, frameH));
    const doc = new IconDocument({ orientation: "horizontal", frameW, frameH, frames, sourcePath });
    doc.dirty = true;
    return doc;
  }

  get frameCount() { return this.frames.length; }
  get sheetW() { return this.orientation === "horizontal" ? this.frameW * this.frameCount : this.frameW; }
  get sheetH() { return this.orientation === "vertical" ? this.frameH * this.frameCount : this.frameH; }

  ensureTwoFrames(recordHistory = true) {
    if (this.frames.length >= 2) return;
    if (recordHistory) this.checkpoint();
    const c = makeCanvas(this.frameW, this.frameH);
    ctx2d(c).drawImage(this.frames[0], 0, 0);
    this.frames.push(c);
    this.offsets.push({ x: 0, y: 0 });
    this.dirty = true;
  }

  snapshot() {
    return {
      orientation: this.orientation,
      frameW: this.frameW,
      frameH: this.frameH,
      offsets: this.offsets.map((o) => ({ ...o })),
      frames: this.frames.map((c) => cloneImageData(ctx2d(c).getImageData(0, 0, c.width, c.height)))
    };
  }

  restore(snap) {
    this.orientation = snap.orientation;
    this.frameW = snap.frameW;
    this.frameH = snap.frameH;
    this.frames = snap.frames.map((data) => {
      const c = makeCanvas(data.width, data.height);
      ctx2d(c).putImageData(cloneImageData(data), 0, 0);
      return c;
    });
    this.offsets = snap.offsets.map((o) => ({ ...o }));
    this.dirty = true;
  }

  checkpoint() {
    this.undoStack.push(this.snapshot());
    if (this.undoStack.length > this.maxHistory) this.undoStack.shift();
    this.redoStack.length = 0;
  }

  undo() {
    if (!this.undoStack.length) return false;
    this.redoStack.push(this.snapshot());
    this.restore(this.undoStack.pop());
    return true;
  }

  redo() {
    if (!this.redoStack.length) return false;
    this.undoStack.push(this.snapshot());
    this.restore(this.redoStack.pop());
    return true;
  }

  setOffset(index, x, y) {
    if (!this.offsets[index]) return;
    this.offsets[index].x = Math.round(Number(x) || 0);
    this.offsets[index].y = Math.round(Number(y) || 0);
    this.dirty = true;
  }

  nudge(index, dx, dy, both = false) {
    const indices = both ? [0, 1].filter((i) => this.offsets[i]) : [index];
    for (const i of indices) this.setOffset(i, this.offsets[i].x + dx, this.offsets[i].y + dy);
  }

  copyOffset(from, to) {
    if (!this.offsets[from] || !this.offsets[to]) return;
    this.offsets[to] = { ...this.offsets[from] };
    this.dirty = true;
  }

  copyFrameGraphic(from, to) {
    if (!this.frames[from] || !this.frames[to]) return;
    const c = makeCanvas(this.frameW, this.frameH);
    ctx2d(c).drawImage(this.frames[from], 0, 0);
    this.frames[to] = c;
    this.offsets[to] = { ...this.offsets[from] };
    this.dirty = true;
  }


  drawFrame(targetCtx, index, { alpha = 1, includeOffset = true } = {}) {
    if (!this.frames[index]) return;
    const o = includeOffset ? this.offsets[index] : { x: 0, y: 0 };
    targetCtx.save();
    targetCtx.globalAlpha = alpha;
    targetCtx.imageSmoothingEnabled = false;
    targetCtx.drawImage(this.frames[index], o.x, o.y);
    targetCtx.restore();
  }

  renderedFrameCanvas(index) {
    const c = makeCanvas(this.frameW, this.frameH);
    this.drawFrame(ctx2d(c), index);
    return c;
  }

  renderSheetCanvas() {
    const c = makeCanvas(this.sheetW, this.sheetH);
    const cctx = ctx2d(c);
    for (let i = 0; i < this.frameCount; i++) {
      const frame = this.renderedFrameCanvas(i);
      const x = this.orientation === "horizontal" ? i * this.frameW : 0;
      const y = this.orientation === "vertical" ? i * this.frameH : 0;
      cctx.drawImage(frame, x, y);
    }
    return c;
  }

  async renderSheetBlob() { return canvasBlob(this.renderSheetCanvas()); }
  async renderFrameBlob(index) { return canvasBlob(this.renderedFrameCanvas(index)); }

  bakeOffsets() {
    let changed = false;
    for (let i = 0; i < this.frameCount; i++) {
      const o = this.offsets[i];
      if (!o || (!o.x && !o.y)) continue;
      this.frames[i] = this.renderedFrameCanvas(i);
      this.offsets[i] = { x: 0, y: 0 };
      changed = true;
    }
    return changed;
  }

  bbox(index) {
    const frame = this.frames[index];
    if (!frame) return null;
    const data = ctx2d(frame).getImageData(0, 0, frame.width, frame.height).data;
    let minX = frame.width, minY = frame.height, maxX = -1, maxY = -1;
    for (let y = 0; y < frame.height; y++) {
      for (let x = 0; x < frame.width; x++) {
        if (data[(y * frame.width + x) * 4 + 3] === 0) continue;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < minX) return null;
    return { minX, minY, maxX, maxY, width: maxX - minX + 1, height: maxY - minY + 1 };
  }

  centerFrame(index) {
    const b = this.bbox(index);
    if (!b) return;
    const centerX = (b.minX + b.maxX + 1) / 2;
    const centerY = (b.minY + b.maxY + 1) / 2;
    this.setOffset(index, Math.round(this.frameW / 2 - centerX), Math.round(this.frameH / 2 - centerY));
  }

  diagnostics(index) {
    const b = this.bbox(index);
    if (!b) return { empty: true, clipped: false, bbox: null, shiftedCenterX: 0, shiftedCenterY: 0 };
    const o = this.offsets[index] || { x: 0, y: 0 };
    const moved = { minX: b.minX + o.x, maxX: b.maxX + o.x, minY: b.minY + o.y, maxY: b.maxY + o.y };
    return {
      empty: false,
      clipped: moved.minX < 0 || moved.minY < 0 || moved.maxX >= this.frameW || moved.maxY >= this.frameH,
      bbox: b,
      moved,
      shiftedCenterX: ((moved.minX + moved.maxX + 1) / 2) - this.frameW / 2,
      shiftedCenterY: ((moved.minY + moved.maxY + 1) / 2) - this.frameH / 2
    };
  }

  resizeCanvas(newW, newH, { anchor = "center" } = {}) {
    newW = Math.max(1, Math.round(Number(newW) || this.frameW));
    newH = Math.max(1, Math.round(Number(newH) || this.frameH));
    if (newW === this.frameW && newH === this.frameH) return false;
    const oldW = this.frameW, oldH = this.frameH;
    let dx = 0, dy = 0;
    if (anchor === "center") {
      dx = Math.round((newW - oldW) / 2);
      dy = Math.round((newH - oldH) / 2);
    }
    this.frames = this.frames.map((frame) => {
      const c = makeCanvas(newW, newH);
      ctx2d(c).drawImage(frame, dx, dy);
      return c;
    });
    this.frameW = newW;
    this.frameH = newH;
    this.dirty = true;
    return true;
  }

  async replaceFrameFromBlob(blob, index, { expandToFit = false } = {}) {
    const image = await decodeBlob(blob);
    if (expandToFit && (image.width > this.frameW || image.height > this.frameH)) {
      this.resizeCanvas(Math.max(this.frameW, image.width), Math.max(this.frameH, image.height));
    }
    const c = makeCanvas(this.frameW, this.frameH);
    const cctx = ctx2d(c);
    const x = Math.round((this.frameW - image.width) / 2);
    const y = Math.round((this.frameH - image.height) / 2);
    cctx.drawImage(image, x, y);
    if (typeof image.close === "function") try { image.close(); } catch (_) {}
    this.frames[index] = c;
    this.offsets[index] = { x: 0, y: 0 };
    this.dirty = true;
  }

  async replaceSheetFromBlob(blob) {
    const newer = await IconDocument.fromBlob(blob, this.sourcePath);
    this.orientation = newer.orientation;
    this.frameW = newer.frameW;
    this.frameH = newer.frameH;
    this.frames = newer.frames;
    this.offsets = newer.offsets;
    this.ensureTwoFrames(false);
    this.dirty = true;
  }

  async cloneAs(sourcePath = this.sourcePath) {
    const blob = await this.renderSheetBlob();
    const clone = await IconDocument.fromBlob(blob, sourcePath);
    clone.dirty = true;
    return clone;
  }

  // --- Pintura -----------------------------------------------------------
  pickColor(index, x, y) {
    const c = this.frames[index];
    if (!c) return null;
    x = Math.floor(Number(x)); y = Math.floor(Number(y));
    if (x < 0 || y < 0 || x >= c.width || y >= c.height) return null;
    const d = ctx2d(c).getImageData(x, y, 1, 1).data;
    if (d[3] === 0) return null;
    return `#${[d[0], d[1], d[2]].map((v) => v.toString(16).padStart(2, "0")).join("")}`;
  }

  // flood fill scanline - ponytail: iterative stack, O(n) pixels
  floodFill(index, sx, sy, fillHex, tolerance = 0) {
    const c = this.frames[index];
    if (!c) return false;
    sx = Math.floor(Number(sx)); sy = Math.floor(Number(sy));
    if (sx < 0 || sy < 0 || sx >= c.width || sy >= c.height) return false;
    const cc = ctx2d(c);
    const img = cc.getImageData(0, 0, c.width, c.height);
    const data = img.data;
    const w = c.width, h = c.height;
    const pos = (sy * w + sx) * 4;
    const sr = data[pos], sg = data[pos + 1], sb = data[pos + 2], sa = data[pos + 3];
    // rgba from hex
    const fr = parseInt(fillHex.slice(1, 3), 16), fg = parseInt(fillHex.slice(3, 5), 16), fb = parseInt(fillHex.slice(5, 7), 16);
    const fa = fillHex.length > 7 ? parseInt(fillHex.slice(7, 9), 16) : 255;
    if (sr === fr && sg === fg && sb === fb && sa === fa) return false;
    tolerance = Math.max(0, Math.min(255, Number(tolerance) || 0));
    const match = (idx) => {
      if (tolerance === 0) return data[idx] === sr && data[idx + 1] === sg && data[idx + 2] === sb && data[idx + 3] === sa;
      return Math.abs(data[idx] - sr) <= tolerance && Math.abs(data[idx + 1] - sg) <= tolerance && Math.abs(data[idx + 2] - sb) <= tolerance && Math.abs(data[idx + 3] - sa) <= tolerance;
    };
    // quick exit if start pixel transparent and tolerance 0? let fill anyway if picking transparent? for icons we skip transparent start
    if (sa === 0 && tolerance === 0) {
      // fill transparent contiguous - allow
    }
    const stack = [[sx, sy]];
    const visited = new Uint8Array(w * h);
    const mark = (x, y) => visited[y * w + x] = 1;
    const isVisited = (x, y) => visited[y * w + x] === 1;
    let filled = 0;
    while (stack.length) {
      const [x, y] = stack.pop();
      if (x < 0 || y < 0 || x >= w || y >= h) continue;
      if (isVisited(x, y)) continue;
      const idx = (y * w + x) * 4;
      if (!match(idx)) continue;
      // scanline left/right
      let xl = x, xr = x;
      while (xl >= 0 && !isVisited(xl, y) && match((y * w + xl) * 4)) xl--;
      xl++;
      while (xr < w && !isVisited(xr, y) && match((y * w + xr) * 4)) xr++;
      xr--;
      for (let xi = xl; xi <= xr; xi++) {
        const i2 = (y * w + xi) * 4;
        data[i2] = fr; data[i2 + 1] = fg; data[i2 + 2] = fb; data[i2 + 3] = fa;
        mark(xi, y);
        filled++;
        if (y > 0 && !isVisited(xi, y - 1) && match(( (y - 1) * w + xi) * 4)) stack.push([xi, y - 1]);
        if (y < h - 1 && !isVisited(xi, y + 1) && match(( (y + 1) * w + xi) * 4)) stack.push([xi, y + 1]);
      }
    }
    if (!filled) return false;
    cc.putImageData(img, 0, 0);
    this.dirty = true;
    return true;
  }

  replaceColor(index, targetHex, replacementHex, tolerance = 0) {
    const c = this.frames[index];
    if (!c) return 0;
    const cc = ctx2d(c);
    const img = cc.getImageData(0, 0, c.width, c.height);
    const d = img.data;
    const tr = parseInt(targetHex.slice(1, 3), 16), tg = parseInt(targetHex.slice(3, 5), 16), tb = parseInt(targetHex.slice(5, 7), 16);
    const ta = targetHex.length > 7 ? parseInt(targetHex.slice(7, 9), 16) : 255;
    const rr = parseInt(replacementHex.slice(1, 3), 16), rg = parseInt(replacementHex.slice(3, 5), 16), rb = parseInt(replacementHex.slice(5, 7), 16);
    const ra = replacementHex.length > 7 ? parseInt(replacementHex.slice(7, 9), 16) : 255;
    if (tr === rr && tg === rg && tb === rb && ta === ra) return 0;
    tolerance = Math.max(0, Math.min(255, Number(tolerance) || 0));
    let count = 0;
    for (let i = 0; i < d.length; i += 4) {
      const match = tolerance === 0 ? d[i] === tr && d[i + 1] === tg && d[i + 2] === tb && d[i + 3] === ta
        : Math.abs(d[i] - tr) <= tolerance && Math.abs(d[i + 1] - tg) <= tolerance && Math.abs(d[i + 2] - tb) <= tolerance && Math.abs(d[i + 3] - ta) <= tolerance;
      if (match) { d[i] = rr; d[i + 1] = rg; d[i + 2] = rb; d[i + 3] = ra; count++; }
    }
    if (count) { cc.putImageData(img, 0, 0); this.dirty = true; }
    return count;
  }

  // --- Escalado ----------------------------------------------------------
  // ponytail: nearest-neighbor via canvas scale, mantiene pixel art nítido
  scaleContent(factor) {
    factor = Number(factor);
    if (!factor || factor === 1) return false;
    if (factor <= 0 || factor > 8) return false;
    const newW = Math.max(1, Math.round(this.frameW * factor));
    const newH = Math.max(1, Math.round(this.frameH * factor));
    if (newW === this.frameW && newH === this.frameH) return false;
    if (newW > 4096 || newH > 4096) return false;
    this.frames = this.frames.map((frame) => {
      const c = makeCanvas(newW, newH);
      const cc = c.getContext("2d");
      cc.imageSmoothingEnabled = false;
      cc.drawImage(frame, 0, 0, frame.width, frame.height, 0, 0, newW, newH);
      return c;
    });
    this.offsets = this.offsets.map((o) => ({ x: Math.round(o.x * factor), y: Math.round(o.y * factor) }));
    this.frameW = newW;
    this.frameH = newH;
    this.dirty = true;
    return true;
  }

  scaleTo(w, h) {
    w = Math.max(1, Math.round(Number(w) || this.frameW));
    h = Math.max(1, Math.round(Number(h) || this.frameH));
    if (w === this.frameW && h === this.frameH) return false;
    if (w > 4096 || h > 4096) return false;
    const fx = w / this.frameW, fy = h / this.frameH;
    this.frames = this.frames.map((frame) => {
      const c = makeCanvas(w, h);
      const cc = c.getContext("2d");
      cc.imageSmoothingEnabled = false;
      cc.drawImage(frame, 0, 0, frame.width, frame.height, 0, 0, w, h);
      return c;
    });
    this.offsets = this.offsets.map((o) => ({ x: Math.round(o.x * fx), y: Math.round(o.y * fy) }));
    this.frameW = w;
    this.frameH = h;
    this.dirty = true;
    return true;
  }
}

export { detectLayout, detectBattlerLayout, decodeBlob, canvasBlob, makeCanvas };
