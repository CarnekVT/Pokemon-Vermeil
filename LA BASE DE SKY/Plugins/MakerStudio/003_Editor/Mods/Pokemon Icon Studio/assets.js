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
    if (/^[A-Za-z0-9+/=\r\n]+$/.test(text) && text.length > 64) {
      try {
        const raw = globalThis.atob ? globalThis.atob(text.replace(/\s+/g, "")) : null;
        if (raw != null) {
          const out = new Uint8Array(raw.length);
          for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i) & 255;
          if (pngSignature(out)) return out;
        }
      } catch (_) {}
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

  async invoke(name, args) {
    const fn = globalThis.window?.__TAURI__?.core?.invoke || globalThis.__TAURI__?.core?.invoke;
    if (typeof fn !== "function") throw new Error("Tauri invoke is unavailable");
    return fn(name, args);
  }

  hasTauri() {
    return typeof (globalThis.window?.__TAURI__?.core?.invoke || globalThis.__TAURI__?.core?.invoke) === "function";
  }

  abs(projectPath) {
    const p = norm(projectPath);
    if (!this.root) return "";
    if (this.node) return this.node.path.resolve(this.root, ...p.split("/"));
    return norm(`${this.root}/${p}`);
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
    throw new Error(`No se pudo leer ${p}. Maker Studio no expone lectura de proyecto.`);
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
          const fileFlag = entry?.isFile ?? entry?.is_file;
          const isDirectory = dirFlag === true || entry?.kind === "directory" || entry?.type === "directory"
            ? true
            : dirFlag === false || fileFlag === true || entry?.kind === "file" || entry?.type === "file"
              ? false
              : null;
          return { path: q, name: basename(q), isDirectory };
        });
      } catch (_) {}
    }
    if (this.node && this.root) {
      const items = await this.node.fs.promises.readdir(this.abs(p), { withFileTypes: true });
      return items.map((e) => ({ path: norm(`${p}/${e.name}`), name: e.name, isDirectory: e.isDirectory() }));
    }
    throw new Error(`No se pudo listar ${p}.`);
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
    try {
      if (typeof this.ctx?.fs?.statProjectFile === "function") {
        await this.ctx.fs.statProjectFile(p);
        return true;
      }
    } catch (_) {}
    try {
      if (typeof this.ctx?.fs?.readProjectFile === "function") { await this.ctx.fs.readProjectFile(p); return true; }
    } catch (_) {}
    try { await this.readBytes(p); return true; } catch (_) { return false; }
  }

  async listRecursive(projectPath, { extensions = null, max = 12000 } = {}) {
    const start = norm(projectPath);
    const out = [];
    const seen = new Set();
    const walk = async (dir) => {
      if (out.length >= max || seen.has(lower(dir))) return;
      seen.add(lower(dir));
      let entries = [];
      try { entries = await this.listDir(dir); } catch (_) { return; }
      for (const entry of entries) {
        if (out.length >= max) break;
        const p = norm(entry.path);
        if (entry.isDirectory === true) { await walk(p); continue; }
        if (entry.isDirectory === false) {
          if (!extensions || extensions.includes(ext(p))) out.push(p);
          continue;
        }
        if (extensions && extensions.includes(ext(p))) { out.push(p); continue; }
        try {
          await this.listDir(p);
          await walk(p);
        } catch (_) {
          if (!extensions || extensions.includes(ext(p))) out.push(p);
        }
      }
    };
    await walk(start);
    return out.sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" }));
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
      const attempts = [[p, { binary: true }], [p, "binary"], [p, { encoding: null }], [p]];
      for (const args of attempts) {
        try {
          const value = await fs.readProjectFile(...args);
          const bytes = await asBytes(value);
          if (bytes && (pngSignature(bytes) || args.length > 1)) return bytes;
        } catch (_) {}
      }
    }
    throw new Error(`Maker Studio no pudo leer el archivo binario: ${p}`);
  }

  async writeBytes(projectPath, bytes) {
    const p = norm(projectPath);
    const data = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    if (this.hasTauri() && this.root) {
      const abs = this.abs(p);
      const dir = abs.replace(/[\\/][^\\/]+$/, "");
      for (const [name, args] of [["create_dir_all", { path: dir }], ["create_directory", { path: dir, recursive: true }]]) {
        try { await this.invoke(name, args); break; } catch (_) {}
      }
      try {
        await this.invoke("write_binary_file", { path: abs, data: Array.from(data) });
        this.revokeUrl(p);
        return p;
      } catch (_) {}
    }
    if (this.node && this.root) {
      const abs = this.abs(p);
      await this.node.fs.promises.mkdir(this.node.path.dirname(abs), { recursive: true });
      await this.node.fs.promises.writeFile(abs, data);
      this.revokeUrl(p);
      return p;
    }
    const fs = this.ctx?.fs;
    if (typeof fs?.projectMkdir === "function") {
      try { await fs.projectMkdir(dirname(p)); } catch (_) {}
    }
    const names = ["writeProjectBinary", "writeProjectBytes", "writeProjectBuffer", "writeProjectFileBinary", "writeBinaryProjectFile"];
    for (const name of names) {
      if (typeof fs?.[name] !== "function") continue;
      try {
        await fs[name](p, data);
        this.revokeUrl(p);
        return p;
      } catch (_) {}
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
        } catch (_) {}
      }
    }
    throw new Error("Maker Studio no expone escritura binaria y no hay acceso Node/NW.js al proyecto. No se modificó ningún PNG.");
  }

  async assetUrl(projectPath) {
    const p = norm(projectPath);
    if (this.urlCache.has(lower(p))) return this.urlCache.get(lower(p));
    const providers = [
      [this.ctx?.fs, "projectFileUrl"], [this.ctx?.fs, "assetUrl"],
      [this.ctx?.editor, "projectFileUrl"], [this.ctx?.editor, "assetUrl"],
      [this.ctx, "projectFileUrl"]
    ];
    for (const [owner, name] of providers) {
      if (typeof owner?.[name] !== "function") continue;
      try {
        const value = await owner[name](p);
        if (value) { this.urlCache.set(lower(p), String(value)); return String(value); }
      } catch (_) {}
    }
    if (this.node && this.root) {
      try {
        const url = this.node.url.pathToFileURL(this.abs(p)).href;
        this.urlCache.set(lower(p), url);
        return url;
      } catch (_) {}
    }
    const bytes = await this.readBytes(p);
    const url = URL.createObjectURL(new Blob([bytes], { type: ext(p) === "png" ? "image/png" : "application/octet-stream" }));
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

function uniquePaths(paths) {
  const out = [], seen = new Set();
  for (const path of paths || []) {
    const p = norm(path);
    const key = lower(p);
    if (!p || seen.has(key)) continue;
    seen.add(key);
    out.push(p);
  }
  return out;
}

function pbsPokemonSort(a, b) {
  const an = lower(basename(a)), bn = lower(basename(b));
  const ap = an === "pokemon.txt" ? 0 : 1;
  const bp = bn === "pokemon.txt" ? 0 : 1;
  return ap - bp || an.localeCompare(bn, undefined, { numeric: true, sensitivity: "base" }) || lower(a).localeCompare(lower(b));
}

function iconBelongsToId(assetStem, id) {
  const a = lower(assetStem), b = lower(id);
  return a === b || a.startsWith(`${b}_`) || a.startsWith(`${b}-`);
}

export function parseIconVariant(assetStem, id, shiny = false) {
  let rest = String(assetStem || "").slice(String(id || "").length).replace(/^[_-]+/, "");
  let gender = 0;
  let shadow = false;
  if (/(?:^|[_-])shadow$/i.test(rest)) {
    shadow = true;
    rest = rest.replace(/(?:^|[_-])shadow$/i, "");
  }
  if (/(?:^|[_-])female$/i.test(rest)) {
    gender = 1;
    rest = rest.replace(/(?:^|[_-])female$/i, "");
  }
  rest = rest.replace(/^[_-]+|[_-]+$/g, "");
  const fm = rest.match(/^(\d+)(?:[_-]|$)/);
  const form = fm ? Number(fm[1]) : 0;
  return { form, gender, shiny: !!shiny, shadow };
}

export function canonicalIconPath(speciesId, form = 0, gender = 0, shiny = false) {
  const folder = shiny ? "Graphics/Pokemon/Icons shiny" : "Graphics/Pokemon/Icons";
  const formSuffix = Number(form) > 0 ? `_${Number(form)}` : "";
  const genderSuffix = Number(gender) === 1 ? "_female" : "";
  return `${folder}/${speciesId}${formSuffix}${genderSuffix}.png`;
}

export function canonicalBattlerPath(speciesId, form = 0, gender = 0, shiny = false, back = false) {
  const base = back ? "Back" : "Front";
  const folder = shiny ? `Graphics/Pokemon/${base} shiny` : `Graphics/Pokemon/${base}`;
  const formSuffix = Number(form) > 0 ? `_${Number(form)}` : "";
  const genderSuffix = Number(gender) === 1 ? "_female" : "";
  return `${folder}/${speciesId}${formSuffix}${genderSuffix}.png`;
}

function parseBattlerVariant(assetStem, id, shiny = false) {
  // reutiliza lógica de icons: asigna form/gender a partir del stem
  return parseIconVariant(assetStem, id, shiny);
}

function assetMatches(asset, form, gender, shiny, shadow = false) {
  return Number(asset.form || 0) === Number(form || 0) && Number(asset.gender || 0) === Number(gender || 0) && !!asset.shiny === !!shiny && !!asset.shadow === !!shadow;
}

function battlerAssetMatches(asset, form, gender, shiny) {
  return Number(asset.form || 0) === Number(form || 0) && Number(asset.gender || 0) === Number(gender || 0) && !!asset.shiny === !!shiny;
}

function exactAsset(sp, form = 0, gender = 0, shiny = false) {
  return (sp?.iconAssets || []).find((a) => assetMatches(a, form, gender, shiny, false)) || null;
}

function exactBattlerAsset(sp, form = 0, gender = 0, shiny = false) {
  return (sp?.battlerAssets || []).find((a) => battlerAssetMatches(a, form, gender, shiny)) || null;
}

function fallbackAsset(sp, form = 0, gender = 0, shiny = false) {
  const tries = [];
  const push = (f, g, s) => {
    const key = `${Number(f)}:${Number(g)}:${s ? 1 : 0}`;
    if (!tries.some((x) => x.key === key)) tries.push({ key, form: Number(f), gender: Number(g), shiny: !!s });
  };
  // Mirrors the practical Essentials fallbacks that matter for editing icons:
  // requested variant -> normal colour -> male/default -> form 0.
  push(form, gender, shiny);
  if (shiny) push(form, gender, false);
  if (Number(gender) === 1) {
    push(form, 0, shiny);
    if (shiny) push(form, 0, false);
  }
  if (Number(form) > 0) {
    push(0, gender, shiny);
    if (shiny) push(0, gender, false);
    if (Number(gender) === 1) {
      push(0, 0, shiny);
      if (shiny) push(0, 0, false);
    }
  }
  for (const t of tries) {
    const asset = exactAsset(sp, t.form, t.gender, t.shiny);
    if (asset) return asset;
  }
  return null;
}

function fallbackBattlerAsset(sp, form = 0, gender = 0, shiny = false) {
  const tries = [];
  const push = (f, g, s) => {
    const key = `${Number(f)}:${Number(g)}:${s ? 1 : 0}`;
    if (!tries.some((x) => x.key === key)) tries.push({ key, form: Number(f), gender: Number(g), shiny: !!s });
  };
  push(form, gender, shiny);
  if (shiny) push(form, gender, false);
  if (Number(gender) === 1) { push(form, 0, shiny); if (shiny) push(form, 0, false); }
  if (Number(form) > 0) {
    push(0, gender, shiny);
    if (shiny) push(0, gender, false);
    if (Number(gender) === 1) { push(0, 0, shiny); if (shiny) push(0, 0, false); }
  }
  for (const t of tries) {
    const asset = exactBattlerAsset(sp, t.form, t.gender, t.shiny);
    if (asset) return asset;
  }
  return null;
}

export async function loadPokemonIconCatalog(fs) {
  let pbsCandidates = [];
  try {
    const pbsFiles = await fs.listRecursive("PBS", { extensions: ["txt"], max: 3000 });
    pbsCandidates = pbsFiles.filter((p) => /^pokemon(?:_.*)?\.txt$/i.test(basename(p)));
  } catch (_) {}
  try {
    if (await fs.exists("PBS/pokemon.txt")) pbsCandidates.push("PBS/pokemon.txt");
  } catch (_) {}
  pbsCandidates = uniquePaths(pbsCandidates).sort(pbsPokemonSort);

  const parsed = [];
  for (let fileOrder = 0; fileOrder < pbsCandidates.length; fileOrder++) {
    const p = pbsCandidates[fileOrder];
    try {
      const text = await fs.readText(p);
      if (!/^\s*(?:Name|FormName)\s*=/mi.test(text)) continue;
      for (const rec of parsePokemonPBS(text, p)) parsed.push({ ...rec, fileOrder });
    } catch (_) {}
  }

  const byId = new Map();
  let speciesOrder = 0;
  for (const rec of parsed) {
    const key = lower(rec.id);
    if (!byId.has(key)) {
      byId.set(key, {
        id: rec.id,
        name: rec.name || rec.id,
        dex: ++speciesOrder,
        sourceOrder: speciesOrder,
        primarySourcePath: rec.sourcePath,
        forms: new Map(),
        iconPaths: [],
        iconAssets: [],
        sourcePaths: new Set()
      });
    }
    const sp = byId.get(key);
    if (rec.form === 0) sp.name = rec.name || sp.name;
    const current = sp.forms.get(rec.form);
    sp.forms.set(rec.form, {
      form: rec.form,
      name: rec.formName || current?.name || (rec.form === 0 ? "Normal" : `Forma ${rec.form}`)
    });
    sp.sourcePaths.add(rec.sourcePath);
  }
  // Form 0 must always be the default editable/preview form, even if a project
  // only declared extra forms in a supplemental PBS file.
  for (const sp of byId.values()) if (!sp.forms.has(0)) sp.forms.set(0, { form: 0, name: "Normal" });

  let normalPaths = [], shinyPaths = [];
  try { normalPaths = await fs.listRecursive("Graphics/Pokemon/Icons", { extensions: ["png"], max: 20000 }); } catch (_) {}
  try { shinyPaths = await fs.listRecursive("Graphics/Pokemon/Icons shiny", { extensions: ["png"], max: 20000 }); } catch (_) {}
  normalPaths = uniquePaths(normalPaths);
  shinyPaths = uniquePaths(shinyPaths);
  const iconPaths = [...normalPaths, ...shinyPaths];
  // Battlers para referencia de paleta shiny
  let frontPaths = [], frontShinyPaths = [];
  try { frontPaths = await fs.listRecursive("Graphics/Pokemon/Front", { extensions: ["png"], max: 20000 }); } catch (_) {}
  try { frontShinyPaths = await fs.listRecursive("Graphics/Pokemon/Front shiny", { extensions: ["png"], max: 20000 }); } catch (_) {}
  frontPaths = uniquePaths(frontPaths);
  frontShinyPaths = uniquePaths(frontShinyPaths);
  const idsByLength = [...byId.values()].sort((a, b) => b.id.length - a.id.length);
  const unmatched = [];
  const battlerUnmatched = [];

  for (const [paths, shiny] of [[normalPaths, false], [shinyPaths, true]]) {
    for (const path of paths) {
      const s = stem(path);
      const sp = idsByLength.find((x) => iconBelongsToId(s, x.id));
      if (!sp) { unmatched.push({ path, shiny }); continue; }
      const variant = parseIconVariant(s, sp.id, shiny);
      sp.iconPaths.push(path);
      sp.iconAssets.push({ path, ...variant });
      if (!sp.forms.has(variant.form)) sp.forms.set(variant.form, { form: variant.form, name: variant.form === 0 ? "Normal" : `Forma ${variant.form}` });
    }
  }
  // Asigna battlers a cada especie (para paleta shiny)
  for (const sp of byId.values()) { sp.battlerPaths = []; sp.battlerAssets = []; }
  for (const [paths, shiny] of [[frontPaths, false], [frontShinyPaths, true]]) {
    for (const path of paths) {
      const s = stem(path);
      const sp = idsByLength.find((x) => iconBelongsToId(s, x.id));
      if (!sp) { battlerUnmatched.push({ path, shiny }); continue; }
      const variant = parseBattlerVariant(s, sp.id, shiny);
      sp.battlerPaths.push(path);
      sp.battlerAssets.push({ path, ...variant });
    }
  }

  // Keep truly unmatched graphics accessible, but after every PBS-defined species.
  // Known suffixes are stripped so ID_female.png doesn't become a fake species.
  let pseudoDex = speciesOrder;
  for (const { path, shiny } of unmatched) {
    const rawStem = stem(path);
    const cleaned = rawStem.replace(/(?:[_-]female)?(?:[_-]shadow)?$/i, "");
    const key = lower(cleaned);
    let sp = byId.get(key);
    if (!sp) {
      sp = {
        id: cleaned,
        name: cleaned,
        dex: ++pseudoDex,
        sourceOrder: pseudoDex,
        primarySourcePath: "",
        forms: new Map([[0, { form: 0, name: "Asset" }]]),
        iconPaths: [],
        iconAssets: [],
        battlerPaths: [],
        battlerAssets: [],
        sourcePaths: new Set(),
        assetOnly: true
      };
      byId.set(key, sp);
    }
    const variant = parseIconVariant(rawStem, sp.id, shiny);
    sp.iconPaths.push(path);
    sp.iconAssets.push({ path, ...variant });
  }
  // Battlers huérfanos: asigna a pseudo-especies si el stem no casa con PBS
  for (const { path, shiny } of battlerUnmatched) {
    const rawStem = stem(path);
    const cleaned = rawStem.replace(/(?:[_-]female)?(?:[_-]shadow)?$/i, "");
    const key = lower(cleaned);
    let sp = byId.get(key);
    if (!sp) {
      sp = {
        id: cleaned,
        name: cleaned,
        dex: ++pseudoDex,
        sourceOrder: pseudoDex,
        primarySourcePath: "",
        forms: new Map([[0, { form: 0, name: "Asset" }]]),
        iconPaths: [],
        iconAssets: [],
        battlerPaths: [],
        battlerAssets: [],
        sourcePaths: new Set(),
        assetOnly: true
      };
      byId.set(key, sp);
    }
    const variant = parseBattlerVariant(rawStem, sp.id, shiny);
    if (!sp.battlerPaths) { sp.battlerPaths = []; sp.battlerAssets = []; }
    sp.battlerPaths.push(path);
    sp.battlerAssets.push({ path, ...variant });
  }

  const species = [...byId.values()];
  for (const sp of species) {
    sp.iconPaths = uniquePaths(sp.iconPaths).sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" }));
    sp.iconAssets.sort((a, b) => Number(a.shiny) - Number(b.shiny) || a.form - b.form || a.gender - b.gender || a.path.localeCompare(b.path, undefined, { numeric: true, sensitivity: "base" }));
    sp.battlerPaths = uniquePaths(sp.battlerPaths || []).sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" }));
    sp.battlerAssets = (sp.battlerAssets || []).sort((a, b) => Number(a.shiny) - Number(b.shiny) || a.form - b.form || a.gender - b.gender || a.path.localeCompare(b.path, undefined, { numeric: true, sensitivity: "base" }));
    sp.forms = [...sp.forms.values()].sort((a, b) => a.form - b.form);
    if (!sp.forms.length || sp.forms[0].form !== 0) sp.forms.unshift({ form: 0, name: "Normal" });
    sp.sourcePaths = [...sp.sourcePaths];
  }
  species.sort((a, b) => (a.sourceOrder || 999999) - (b.sourceOrder || 999999) || a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));

  const assetSet = new Set(iconPaths.map(lower));
  const battlerPaths = [...frontPaths, ...frontShinyPaths];
  const battlerAssetSet = new Set(battlerPaths.map(lower));
  return {
    species,
    iconPaths,
    normalIconPaths: normalPaths,
    shinyIconPaths: shinyPaths,
    frontPaths,
    frontShinyPaths,
    battlerPaths,
    assetSet,
    battlerAssetSet,
    pbsPaths: pbsCandidates,
    canonicalIconPath,
    canonicalBattlerPath,
    existsInCatalog: (path) => assetSet.has(lower(path)),
    findExactVariant(sp, form = 0, gender = 0, shiny = false) {
      return exactAsset(sp, form, gender, shiny)?.path || "";
    },
    findFallbackVariant(sp, form = 0, gender = 0, shiny = false) {
      return fallbackAsset(sp, form, gender, shiny)?.path || "";
    },
    findBattlerExact(sp, form = 0, gender = 0, shiny = false) {
      return exactBattlerAsset(sp, form, gender, shiny)?.path || "";
    },
    findBattlerFallback(sp, form = 0, gender = 0, shiny = false) {
      return fallbackBattlerAsset(sp, form, gender, shiny)?.path || "";
    },
    findExistingForForm(sp, form = 0) {
      return exactAsset(sp, form, 0, false)?.path || "";
    },
    defaultPreviewPath(sp) {
      return exactAsset(sp, 0, 0, false)?.path || "";
    },
    hasAnyIcon(sp) { return !!sp?.iconAssets?.length; }
  };
}

export { norm, ext, stem, dirname, basename, lower, pngSignature, asBytes };
