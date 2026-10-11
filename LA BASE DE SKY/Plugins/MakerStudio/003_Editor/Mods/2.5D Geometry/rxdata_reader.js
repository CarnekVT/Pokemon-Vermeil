// Ruby Marshal 4.8 reader for the RGSS data this mod needs: RPG::Map,
// RPG::Tileset and Table. Pure ESM, no Ruby/runtime dependency.

const td = new TextDecoder("utf-8", { fatal: false });

class MarshalReader {
  constructor(bytes) {
    this.b = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
    this.p = 0;
    this.symbols = [];
    this.objects = [];
  }
  byte() { if (this.p >= this.b.length) throw new Error("Unexpected end of Ruby Marshal data"); return this.b[this.p++]; }
  signedByte() { const n = this.byte(); return n >= 128 ? n - 256 : n; }
  bytes(n) { const end = this.p + n; if (end > this.b.length) throw new Error("Unexpected end of Ruby Marshal data"); const out = this.b.slice(this.p, end); this.p = end; return out; }
  fixnum() {
    const c = this.signedByte();
    if (c === 0) return 0;
    if (c > 4) return c - 5;
    if (c < -4) return c + 5;
    const n = Math.abs(c);
    let v = 0n;
    for (let i = 0; i < n; i++) v |= BigInt(this.byte()) << BigInt(8 * i);
    if (c < 0) v -= 1n << BigInt(8 * n);
    return Number(v);
  }
  rawString() { const n = this.fixnum(); if (n < 0) throw new Error("Invalid Ruby Marshal string length"); return td.decode(this.bytes(n)); }
  register(v) { this.objects.push(v); return v; }
  attachIvars(v, ivars) {
    if (v && typeof v === "object") Object.assign(v.__ivars ||= {}, ivars);
    return v;
  }
  value() {
    const tag = String.fromCharCode(this.byte());
    switch (tag) {
      case "0": return null;
      case "T": return true;
      case "F": return false;
      case "i": return this.fixnum();
      case "f": { const s = this.rawString(); const n = Number(s); return this.register(Number.isNaN(n) ? 0 : n); }
      case ":": { const s = this.rawString(); this.symbols.push(s); return s; }
      case ";": return this.symbols[this.fixnum()];
      case "@": return this.objects[this.fixnum()];
      case "\"": return this.register(this.rawString());
      case "[": { const a = this.register([]), n = this.fixnum(); for (let i = 0; i < n; i++) a.push(this.value()); return a; }
      case "{": { const m = this.register(new Map()), n = this.fixnum(); for (let i = 0; i < n; i++) m.set(this.value(), this.value()); return m; }
      case "}": { const m = this.register(new Map()), n = this.fixnum(); for (let i = 0; i < n; i++) m.set(this.value(), this.value()); m.__default = this.value(); return m; }
      case "o": {
        const klass = this.value();
        const o = this.register({ __rubyClass: String(klass || "Object"), __ivars: {} });
        const n = this.fixnum();
        for (let i = 0; i < n; i++) o.__ivars[String(this.value())] = this.value();
        return o;
      }
      case "I": {
        const v = this.value(), n = this.fixnum(), ivars = {};
        for (let i = 0; i < n; i++) ivars[String(this.value())] = this.value();
        return this.attachIvars(v, ivars);
      }
      case "u": { const klass = String(this.value() || ""), n = this.fixnum(); return this.register({ __rubyClass: klass, __raw: this.bytes(n) }); }
      case "U": { const klass = String(this.value() || ""), data = this.value(); return this.register({ __rubyClass: klass, __marshalData: data }); }
      default: throw new Error(`Unsupported Ruby Marshal tag ${JSON.stringify(tag)} at 0x${(this.p - 1).toString(16)}`);
    }
  }
  read() {
    const major = this.byte(), minor = this.byte();
    if (major !== 4 || minor !== 8) throw new Error(`Unsupported Ruby Marshal version ${major}.${minor}`);
    return this.value();
  }
}

function iv(o, name, fallback = null) {
  const key = String(name).replace(/^@/, "");
  const v = o?.__ivars?.[`@${key}`] ?? o?.__ivars?.[key];
  return v === undefined ? fallback : v;
}

function clean(v) { return String(v ?? "").replace(/\0/g, "").trim(); }

function decodeTable(table) {
  const raw = table?.__raw;
  if (!(raw instanceof Uint8Array) || raw.byteLength < 20) return null;
  const dv = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
  const dim = dv.getInt32(0, true);
  const xsize = dv.getInt32(4, true);
  const ysize = dv.getInt32(8, true);
  const zsize = dv.getInt32(12, true);
  const count = dv.getInt32(16, true);
  const start = 20;
  return {
    dim, xsize, ysize, zsize, count,
    get(x, y, z = 0) {
      const idx = x + y * xsize + z * xsize * ysize;
      if (idx < 0 || idx >= count) return 0;
      return dv.getInt16(start + idx * 2, true);
    }
  };
}

export function parseRubyMarshal(bytes) { return new MarshalReader(bytes).read(); }

export function parseMapRxdata(bytes) {
  const map = parseRubyMarshal(bytes);
  const data = decodeTable(iv(map, "data"));
  const extended = iv(map, "extended_layers", "");
  return {
    width: Number(iv(map, "width", data?.xsize || 0)) || 0,
    height: Number(iv(map, "height", data?.ysize || 0)) || 0,
    tilesetId: Number(iv(map, "tileset_id", 0)) || 0,
    data,
    extendedLayers: typeof extended === "string" ? extended : ""
  };
}

export function parseTilesetsRxdata(bytes) {
  const arr = parseRubyMarshal(bytes) || [];
  return arr.map((ts, id) => {
    if (!ts || typeof ts !== "object") return null;
    return {
      id,
      name: clean(iv(ts, "name", "")),
      tilesetName: clean(iv(ts, "tileset_name", "")),
      autotileNames: (iv(ts, "autotile_names", []) || []).map(clean),
      passages: decodeTable(iv(ts, "passages")),
      priorities: decodeTable(iv(ts, "priorities")),
      terrainTags: decodeTable(iv(ts, "terrain_tags"))
    };
  });
}
