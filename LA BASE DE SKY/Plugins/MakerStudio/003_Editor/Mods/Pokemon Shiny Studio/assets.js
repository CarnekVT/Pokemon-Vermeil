const norm = (p) => String(p || "").replace(/\\/g, "/").replace(/\/{2,}/g, "/").replace(/^\.\//, "").replace(/\/$/, "");
const ext = (p) => (String(p || "").match(/\.([^.\/]+)$/) || [])[1]?.toLowerCase() || "";
const stem = (p) => String(p || "").split(/[\\/]/).pop().replace(/\.[^.]+$/, "");
const dirname = (p) => norm(String(p || "").replace(/[\\/][^\\/]*$/, ""));
const basename = (p) => String(p || "").split(/[\\/]/).pop();
const lower = (v) => String(v || "").toLowerCase();

function getRequire() {
  try {
    if (typeof globalThis.require === "function") return globalThis.require;
  } catch (_) {}
  try {
    if (globalThis.window && typeof globalThis.window.require === "function") return globalThis.window.require;
  } catch (_) {}
  return null;
}

function pngSignature(bytes) {
  if (!bytes || bytes.length < 8) return false;
  const sig = [137, 80, 78, 71, 13, 10, 26, 10];
  for (let i = 0; i < 8; i++) if (bytes[i] !== sig[i]) return false;
  return true;
}

async function asBytes(value) {
  if (value == null) return null;
  if (value instanceof Uint8Array) return value;
  if (Array.isArray(value)) return new Uint8Array(value);
  if (value instanceof ArrayBuffer) return new Uint8Array(value);
  if (ArrayBuffer.isView(value)) return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
  if (typeof Blob !== "undefined" && value instanceof Blob) return new Uint8Array(await value.arrayBuffer());
  if (value?.data && value.data !== value) {
    const nested = await asBytes(value.data);
    if (nested) return nested;
  }
  if (typeof value === "string") {
    const text = value;
    const dataUrl = text.match(/^data:[^;,]+;base64,(.+)$/s);
    if (dataUrl) {
      const raw = globalThis.atob ? globalThis.atob(dataUrl[1]) : null;
      if (raw != null) {
        const out = new Uint8Array(raw.length);
        for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i) & 255;
        return out;
      }
    }
    if (text.length >= 8 && text.charCodeAt(0) === 137 && text.slice(1, 4) === "PNG") {
      const out = new Uint8Array(text.length);
      for (let i = 0; i < text.length; i++) out[i] = text.charCodeAt(i) & 255;
      return out;
    }
  }
  return null;
}

export class ProjectFS {
  constructor(ctx) {
    this.ctx = ctx || {};
    this.urlCache = new Map();
    this.req = getRequire();
    this.node = null;
    this.root = "";
    if (this.req) {
      try {
        this.node = {
          fs: this.req("fs"),
          path: this.req("path"),
          url: this.req("url")
        };
      } catch (_) {
        this.node = null;
      }
    }
    try {
      this.root = norm(this.ctx?.editor?.gameRoot?.() || this.ctx?.gameRoot?.() || "");
    } catch (_) {}
  }

  getInvoke() {
    return globalThis.window?.__TAURI__?.core?.invoke ||
           globalThis.window?.__TAURI__?.tauri?.invoke ||
           globalThis.window?.__TAURI__?.invoke ||
           globalThis.__TAURI__?.core?.invoke ||
           globalThis.__TAURI__?.tauri?.invoke ||
           globalThis.__TAURI__?.invoke ||
           null;
  }

  async invoke(name, args) {
    const fn = this.getInvoke();
    if (typeof fn !== "function") throw new Error("Tauri invoke no disponible");
    return fn(name, args);
  }

  hasTauri() {
    return typeof this.getInvoke() === "function";
  }

  abs(projectPath) {
    const p = norm(projectPath);
    if (!this.root) return "";
    if (this.node) return this.node.path.resolve(this.root, ...p.split("/"));
    return norm(`${this.root}/${p}`);
  }

  async ensureDir(projectPath) {
    const p = norm(projectPath);
    const abs = this.abs(p);
    const dir = abs.replace(/[\\/][^\\/]+$/, "");
    const invoke = this.getInvoke();
    if (invoke) {
      for (const [name, args] of [
        ["create_dir_all", { path: dir }],
        ["create_directory", { path: dir, recursive: true }],
        ["create_dir", { path: dir, recursive: true }],
        ["mkdir", { path: dir, recursive: true }]
      ]) {
        try { await invoke(name, args); break; } catch (_) {}
      }
    }
    if (this.node && this.root) {
      try { await this.node.fs.promises.mkdir(dir, { recursive: true }); } catch (_) {}
    }
    const fs = this.ctx?.fs;
    if (typeof fs?.projectMkdir === "function") {
      try { await fs.projectMkdir(dirname(p)); } catch (_) {}
    }
  }

  async readText(projectPath) {
    const p = norm(projectPath);
    if (typeof this.ctx?.fs?.readProjectFile === "function") {
      try {
        const out = await this.ctx.fs.readProjectFile(p);
        if (typeof out === "string") return out;
        if (out != null) {
          const bytes = await asBytes(out);
          if (bytes) return new TextDecoder("utf-8").decode(bytes);
        }
      } catch (_) {}
    }
    if (this.node && this.root) return this.node.fs.promises.readFile(this.abs(p), "utf8");
    throw new Error(`No se pudo leer texto en ${p}.`);
  }

  async writeText(projectPath, text) {
    const bytes = new TextEncoder().encode(text);
    return this.writeBytes(projectPath, bytes);
  }

  async listDir(projectPath) {
    const p = norm(projectPath);
    if (typeof this.ctx?.fs?.listProjectDir === "function") {
      try {
        const entries = await this.ctx.fs.listProjectDir(p);
        return (entries || []).map((entry) => {
          if (typeof entry === "string") {
            let q = norm(entry);
            if (!lower(q).startsWith(lower(p) + "/") && lower(q) !== lower(p)) q = norm(`${p}/${q}`);
            return { path: q, name: basename(q), isDirectory: null };
          }
          const raw = entry?.path || entry?.name || "";
          let q = norm(raw);
          if (!lower(q).startsWith(lower(p) + "/") && lower(q) !== lower(p)) q = norm(`${p}/${q}`);
          const dirFlag = entry?.isDirectory ?? entry?.is_directory ?? entry?.isDir ?? entry?.is_dir;
          const isDirectory = dirFlag === true || entry?.kind === "directory";
          return { path: q, name: basename(q), isDirectory };
        });
      } catch (_) {}
    }
    if (this.node && this.root) {
      const items = await this.node.fs.promises.readdir(this.abs(p), { withFileTypes: true });
      return items.map((e) => ({ path: norm(`${p}/${e.name}`), name: e.name, isDirectory: e.isDirectory() }));
    }
    return [];
  }

  async exists(projectPath) {
    const p = norm(projectPath);
    if (typeof this.ctx?.fs?.projectExists === "function") {
      try { return !!(await this.ctx.fs.projectExists(p)); } catch (_) {}
    }
    if (this.hasTauri() && this.root) {
      try { return !!(await this.invoke("file_exists", { path: this.abs(p) })); } catch (_) {}
    }
    if (this.node && this.root) {
      try { await this.node.fs.promises.access(this.abs(p)); return true; } catch (_) { return false; }
    }
    try { await this.readBytes(p); return true; } catch (_) { return false; }
  }

  async readBytes(projectPath) {
    const p = norm(projectPath);
    if (this.hasTauri() && this.root) {
      try {
        const value = await this.invoke("read_binary_file", { path: this.abs(p) });
        const bytes = await asBytes(value);
        if (bytes) return bytes;
      } catch (_) {}
    }
    if (this.node && this.root) {
      try {
        const buf = await this.node.fs.promises.readFile(this.abs(p));
        return new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
      } catch (_) {}
    }
    const fs = this.ctx?.fs;
    const names = ["readProjectBinary", "readProjectBytes", "readProjectBuffer", "readProjectFileBinary", "readBinaryProjectFile"];
    for (const name of names) {
      if (typeof fs?.[name] !== "function") continue;
      try {
        const value = await fs[name](p);
        const bytes = await asBytes(value);
        if (bytes) return bytes;
      } catch (_) {}
    }
    if (typeof fs?.readProjectFile === "function") {
      try {
        const value = await fs.readProjectFile(p, { binary: true });
        const bytes = await asBytes(value);
        if (bytes) return bytes;
      } catch (_) {}
    }
    throw new Error(`No se pudo leer el archivo binario: ${p}`);
  }

  async writeBytes(projectPath, bytes) {
    const p = norm(projectPath);
    const data = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    await this.ensureDir(p);

    const abs = this.abs(p);
    const invoke = this.getInvoke();
    let lastError = null;

    if (invoke && this.root) {
      try {
        await invoke("write_binary_file", { path: abs, data: Array.from(data) });
        this.revokeUrl(p);
        return p;
      } catch (err) {
        lastError = err;
      }
    }

    if (this.node && this.root) {
      try {
        await this.node.fs.promises.writeFile(abs, data);
        this.revokeUrl(p);
        return p;
      } catch (err) {
        lastError = err;
      }
    }

    const fs = this.ctx?.fs;
    const names = ["writeProjectBinary", "writeProjectBytes", "writeProjectBuffer", "writeProjectFileBinary", "writeBinaryProjectFile"];
    for (const name of names) {
      if (typeof fs?.[name] !== "function") continue;
      try {
        await fs[name](p, data);
        this.revokeUrl(p);
        return p;
      } catch (err) {
        lastError = err;
      }
    }

    if (typeof fs?.writeProjectFile === "function") {
      const attempts = [
        [p, data, { binary: true }],
        [p, data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength), { binary: true }],
        [p, data]
      ];
      for (const args of attempts) {
        try {
          await fs.writeProjectFile(...args);
          this.revokeUrl(p);
          return p;
        } catch (err) {
          lastError = err;
        }
      }
    }

    const detail = lastError ? (lastError.message || (typeof lastError === "string" ? lastError : JSON.stringify(lastError))) : "Maker Studio no expone backend de escritura binaria";
    throw new Error(`No se pudo guardar ${p}: ${detail}`);
  }

  async assetUrl(projectPath) {
    const p = norm(projectPath);
    if (this.urlCache.has(lower(p))) return this.urlCache.get(lower(p));
    if (this.node && this.root) {
      try {
        const url = this.node.url.pathToFileURL(this.abs(p)).href;
        this.urlCache.set(lower(p), url);
        return url;
      } catch (_) {}
    }
    const bytes = await this.readBytes(p);
    const url = URL.createObjectURL(new Blob([bytes], { type: "image/png" }));
    this.urlCache.set(lower(p), url);
    return url;
  }

  revokeUrl(projectPath) {
    const key = lower(norm(projectPath));
    const url = this.urlCache.get(key);
    if (url && String(url).startsWith("blob:")) {
      try { URL.revokeObjectURL(url); } catch (_) {}
    }
    this.urlCache.delete(key);
  }

  dispose() {
    for (const url of this.urlCache.values()) {
      if (String(url).startsWith("blob:")) try { URL.revokeObjectURL(url); } catch (_) {}
    }
    this.urlCache.clear();
  }
}

// Rutas canónicas para cualquier variante
export function canonicalSpritePath({ type = "Front", variant = "normal", speciesId, form = 0, gender = 0 }) {
  const formSuffix = Number(form) > 0 ? `_${Number(form)}` : "";
  const genderSuffix = Number(gender) === 1 ? "_female" : "";
  const file = `${speciesId}${formSuffix}${genderSuffix}.png`;

  let folder = "";
  if (type === "Icons") {
    folder = variant === "normal" ? "Graphics/Pokemon/Icons" : `Graphics/Pokemon/Icons ${variant}`;
  } else {
    // Front o Back
    folder = variant === "normal" ? `Graphics/Pokemon/${type}` : `Graphics/Pokemon/${type} ${variant}`;
  }
  return `${folder}/${file}`;
}

// Carga y guarda Data/shiny_variants.json
export const DEFAULT_VARIANTS = [
  { id: "shiny", name: "Variocolor (Shiny)", folder: "shiny", color: "#facc15", rate: 65536 },
  { id: "supershiny", name: "Super Variocolor", folder: "supershiny", color: "#c084fc", rate: 655360 }
];

export async function loadVariantsConfig(fs) {
  const path = "Data/shiny_variants.json";
  try {
    if (await fs.exists(path)) {
      const text = await fs.readText(path);
      const data = JSON.parse(text);
      if (Array.isArray(data?.variants) && data.variants.length > 0) {
        return data.variants;
      }
    }
  } catch (err) {
    console.warn("No se pudo cargar shiny_variants.json:", err);
  }
  return DEFAULT_VARIANTS;
}

export async function saveVariantsConfig(fs, variants) {
  const path = "Data/shiny_variants.json";
  const json = JSON.stringify({ variants }, null, 2);
  await fs.writeText(path, json);
}

// Parser de PBS para catálogo de Pokémon
export function parsePokemonPBS(text, sourcePath = "") {
  const result = [];
  const raw = String(text || "");
  const re = /^\s*\[([^\]\r\n]+)\]\s*$/gm;
  const hits = [];
  let m;
  while ((m = re.exec(raw))) hits.push({ header: m[1].trim(), start: m.index, bodyStart: re.lastIndex });
  for (let i = 0; i < hits.length; i++) {
    const hit = hits[i];
    const end = i + 1 < hits.length ? hits[i + 1].start : raw.length;
    const body = raw.slice(hit.bodyStart, end);
    const parts = hit.header.split(",").map((v) => v.trim()).filter(Boolean);
    const id = parts[0];
    if (!id || /\s/.test(id)) continue;
    let form = 0;
    if (parts.length > 1 && /^\d+$/.test(parts[1])) form = Number(parts[1]);
    const field = (key) => {
      const fm = body.match(new RegExp(`^\\s*${key}\\s*=\\s*(.*?)\\s*$`, "mi"));
      return fm ? fm[1].trim() : "";
    };
    result.push({
      id,
      form,
      name: field("Name") || id,
      formName: field("FormName") || "",
      sourcePath,
      order: result.length
    });
  }
  return result;
}

export async function loadPokemonCatalog(fs) {
  const speciesList = [];
  const seenKeys = new Set();
  const candidateFiles = ["PBS/pokemon.txt"];

  try {
    const pbsEntries = await fs.listDir("PBS");
    for (const e of pbsEntries) {
      if (lower(e.name).startsWith("pokemon_") && lower(e.name).endsWith(".txt")) {
        candidateFiles.push(e.path);
      }
    }
  } catch (_) {}

  for (const file of candidateFiles) {
    try {
      if (!(await fs.exists(file))) continue;
      const text = await fs.readText(file);
      const parsed = parsePokemonPBS(text, file);
      for (const item of parsed) {
        const key = `${item.id}_${item.form}`;
        if (!seenKeys.has(key)) {
          seenKeys.add(key);
          speciesList.push(item);
        }
      }
    } catch (_) {}
  }

  return speciesList;
}

// Carga imagen a un HTMLImageElement
export function loadImageElement(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = (e) => reject(new Error("Error al cargar imagen " + url));
    img.src = url;
  });
}
