var __values = (this && this.__values) || function (o) {
    var s = typeof Symbol === "function" && Symbol.iterator, m = s && o[s], i = 0;
    if (m)
        return m.call(o);
    if (o && typeof o.length === "number")
        return {
            next: function () {
                if (o && i >= o.length)
                    o = void 0;
                return { value: o && o[i++], done: !o };
            }
        };
    throw new TypeError(s ? "Object is not iterable." : "Symbol.iterator is not defined.");
};
var __read = (this && this.__read) || function (o, n) {
    var m = typeof Symbol === "function" && o[Symbol.iterator];
    if (!m)
        return o;
    var i = m.call(o), r, ar = [], e;
    try {
        while ((n === void 0 || n-- > 0) && !(r = i.next()).done)
            ar.push(r.value);
    }
    catch (error) {
        e = { error: error };
    }
    finally {
        try {
            if (r && !r.done && (m = i["return"]))
                m.call(i);
        }
        finally {
            if (e)
                throw e.error;
        }
    }
    return ar;
};
var __spreadArray = (this && this.__spreadArray) || function (to, from, pack) {
    if (pack || arguments.length === 2)
        for (var i = 0, l = from.length, ar; i < l; i++) {
            if (ar || !(i in from)) {
                if (!ar)
                    ar = Array.prototype.slice.call(from, 0, i);
                ar[i] = from[i];
            }
        }
    return to.concat(ar || Array.prototype.slice.call(from));
};
// Ruby Marshal 4.8 reader specialised for RPG Maker XP / Pokémon Essentials
// animation data. It intentionally has no dependency on Ruby or the game runtime.
var td = new TextDecoder("utf-8", { fatal: false });
var MarshalReader = /** @class */ (function () {
    function MarshalReader(bytes) {
        this.b = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
        this.p = 0;
        this.symbols = [];
        this.objects = [];
    }
    MarshalReader.prototype.byte = function () {
        if (this.p >= this.b.length)
            throw new Error("Unexpected end of Ruby Marshal data");
        return this.b[this.p++];
    };
    MarshalReader.prototype.signedByte = function () { var n = this.byte(); return n >= 128 ? n - 256 : n; };
    MarshalReader.prototype.bytes = function (n) {
        var end = this.p + n;
        if (end > this.b.length)
            throw new Error("Unexpected end of Ruby Marshal data");
        var out = this.b.slice(this.p, end);
        this.p = end;
        return out;
    };
    MarshalReader.prototype.fixnum = function () {
        var c = this.signedByte();
        if (c === 0)
            return 0;
        if (c > 4)
            return c - 5;
        if (c < -4)
            return c + 5;
        var n = Math.abs(c);
        var v = 0n;
        for (var i = 0; i < n; i++)
            v |= BigInt(this.byte()) << BigInt(8 * i);
        if (c < 0)
            v -= 1n << BigInt(8 * n);
        var num = Number(v);
        return Number.isSafeInteger(num) ? num : num;
    };
    MarshalReader.prototype.rawString = function () {
        var n = this.fixnum();
        if (n < 0)
            throw new Error("Invalid Ruby Marshal string length");
        return td.decode(this.bytes(n));
    };
    MarshalReader.prototype.register = function (v) { this.objects.push(v); return v; };
    MarshalReader.prototype.attachIvars = function (v, ivars) {
        if (v && (typeof v === "object" || typeof v === "function")) {
            var dst = v.__ivars || (v.__ivars = {});
            Object.assign(dst, ivars);
        }
        return v;
    };
    MarshalReader.prototype.value = function () {
        var tag = String.fromCharCode(this.byte());
        switch (tag) {
            case "0": return null;
            case "T": return true;
            case "F": return false;
            case "i": return this.fixnum();
            case "f": {
                var s = this.rawString();
                var n = Number(s);
                var v = Number.isNaN(n) ? (s === "nan" ? NaN : s === "inf" ? Infinity : s === "-inf" ? -Infinity : 0) : n;
                this.register(v);
                return v;
            }
            case ":": {
                var s = this.rawString();
                this.symbols.push(s);
                return s;
            }
            case ";": {
                var i = this.fixnum();
                if (i < 0 || i >= this.symbols.length)
                    throw new Error("Bad symbol link ".concat(i));
                return this.symbols[i];
            }
            case "@": {
                var i = this.fixnum();
                if (i < 0 || i >= this.objects.length)
                    throw new Error("Bad object link ".concat(i));
                return this.objects[i];
            }
            case "\"": {
                var s = this.rawString();
                this.register(s);
                return s;
            }
            case "[": {
                var a = this.register([]), n = this.fixnum();
                for (var i = 0; i < n; i++)
                    a.push(this.value());
                return a;
            }
            case "{": {
                var m = this.register(new Map()), n = this.fixnum();
                for (var i = 0; i < n; i++)
                    m.set(this.value(), this.value());
                return m;
            }
            case "}": {
                var m = this.register(new Map()), n = this.fixnum();
                for (var i = 0; i < n; i++)
                    m.set(this.value(), this.value());
                m.__default = this.value();
                return m;
            }
            case "o": {
                var klass = this.value();
                var o = this.register({ __rubyClass: String(klass || "Object"), __ivars: {} });
                var n = this.fixnum();
                for (var i = 0; i < n; i++)
                    o.__ivars[String(this.value())] = this.value();
                return o;
            }
            case "I": {
                var v = this.value(), n = this.fixnum(), ivars = {};
                for (var i = 0; i < n; i++)
                    ivars[String(this.value())] = this.value();
                return this.attachIvars(v, ivars);
            }
            case "C": {
                var klass = String(this.value() || "");
                var v = this.value();
                if (v && typeof v === "object")
                    v.__rubyClass = klass;
                return v;
            }
            case "e": {
                var mod = String(this.value() || "");
                var v = this.value();
                if (v && typeof v === "object")
                    (v.__rubyExtensions || (v.__rubyExtensions = [])).push(mod);
                return v;
            }
            case "u": {
                var klass = String(this.value() || ""), n = this.fixnum();
                return this.register({ __rubyClass: klass, __raw: this.bytes(n) });
            }
            case "U": {
                var klass = String(this.value() || ""), data = this.value();
                return this.register({ __rubyClass: klass, __marshalData: data });
            }
            case "l": {
                var sign = String.fromCharCode(this.byte()), words = this.fixnum();
                var v = 0n;
                for (var i = 0; i < words * 2; i++)
                    v |= BigInt(this.byte()) << BigInt(8 * i);
                if (sign === "-")
                    v = -v;
                return Number(v);
            }
            case "/": {
                var source = this.rawString(), options = this.byte();
                return this.register({ __rubyClass: "Regexp", source: source, options: options });
            }
            default: throw new Error("Unsupported Ruby Marshal tag ".concat(JSON.stringify(tag), " at 0x").concat((this.p - 1).toString(16)));
        }
    };
    MarshalReader.prototype.read = function () {
        var major = this.byte(), minor = this.byte();
        if (major !== 4 || minor !== 8)
            throw new Error("Unsupported Ruby Marshal version ".concat(major, ".").concat(minor));
        return this.value();
    };
    return MarshalReader;
}());
function iv(o, name, fallback) {
    if (fallback === void 0) {
        fallback = null;
    }
    var _a, _b, _c;
    if (!o || typeof o !== "object")
        return fallback;
    var v = (_b = (_a = o.__ivars) === null || _a === void 0 ? void 0 : _a[name]) !== null && _b !== void 0 ? _b : (_c = o.__ivars) === null || _c === void 0 ? void 0 : _c["@".concat(String(name).replace(/^@/, ""))];
    return v === undefined ? fallback : v;
}
function num(v, fallback) {
    if (fallback === void 0) {
        fallback = 0;
    }
    var n = Number(v);
    return Number.isFinite(n) ? n : fallback;
}
function cleanName(v) { return String(v !== null && v !== void 0 ? v : "").replace(/\0/g, "").trim(); }
function rawArray(o) { return Array.isArray(iv(o, "@array")) ? iv(o, "@array") : (Array.isArray(o) ? o : []); }
function plainIvars(o) {
    var e_1, _d;
    var out = {};
    try {
        for (var _e = __values(Object.entries((o === null || o === void 0 ? void 0 : o.__ivars) || {})), _f = _e.next(); !_f.done; _f = _e.next()) {
            var _g = __read(_f.value, 2), k = _g[0], v = _g[1];
            out[String(k).replace(/^@/, "")] = v;
        }
    }
    catch (e_1_1) {
        e_1 = { error: e_1_1 };
    }
    finally {
        try {
            if (_f && !_f.done && (_d = _e.return))
                _d.call(_e);
        }
        finally {
            if (e_1)
                throw e_1.error;
        }
    }
    return out;
}
function decodeFourDoubles(raw) {
    var b = raw === null || raw === void 0 ? void 0 : raw.__raw;
    if (!(b instanceof Uint8Array) || b.byteLength < 32)
        return null;
    var dv = new DataView(b.buffer, b.byteOffset, b.byteLength);
    return [0, 8, 16, 24].map(function (off) { return dv.getFloat64(off, true); });
}
function normalizeTiming(t) {
    var h = plainIvars(t), color = decodeFourDoubles(h.flashColor);
    return {
        type: num(h.timingType, 0), frame: num(h.frame, 0), name: cleanName(h.name), volume: num(h.volume, 100), pitch: num(h.pitch, 100),
        flashScope: num(h.flashScope, 0), flashDuration: num(h.flashDuration, 0), flashColor: color,
        duration: num(h.duration, 0), opacity: num(h.opacity, 0), x: num(h.bgX, 0), y: num(h.bgY, 0),
        color: [num(h.colorRed, 0), num(h.colorGreen, 0), num(h.colorBlue, 0), num(h.colorAlpha, 0)]
    };
}
export var LEGACY_ANIMFRAME = Object.freeze({
    x: 0, y: 1, zoomx: 2, angle: 3, mirror: 4, blendtype: 5,
    pattern: 7, opacity: 8, zoomy: 11,
    colorred: 12, colorgreen: 13, colorblue: 14, coloralpha: 15,
    tonered: 16, tonegreen: 17, toneblue: 18, tonegray: 19,
    visible: 6, locked: 20, flashred: 21, flashgreen: 22, flashblue: 23, flashalpha: 24, priority: 25, focus: 26
});
export function parseRubyMarshal(bytes) { return new MarshalReader(bytes).read(); }
export function parseLegacyAnimationsRxdata(bytes, sourcePath) {
    if (sourcePath === void 0) {
        sourcePath = "PkmnAnimations.rxdata";
    }
    var top = parseRubyMarshal(bytes), source = rawArray(top), animations = [];
    for (var id = 0; id < source.length; id++) {
        var x = source[id];
        if (!x || typeof x !== "object")
            continue;
        var frames = rawArray(x);
        var name = cleanName(iv(x, "@name", ""));
        animations.push({
            id: id,
            name: name,
            animation_name: cleanName(iv(x, "@graphic", "")), graphic: cleanName(iv(x, "@graphic", "")),
            position: num(iv(x, "@position", 3), 3), hue: num(iv(x, "@hue", 0), 0), scope: num(iv(x, "@scope", 0), 0),
            frames: frames,
            frame_max: frames.length, timing: (iv(x, "@timing", []) || []).map(normalizeTiming), _animframe: Object.assign({}, LEGACY_ANIMFRAME),
            sourcePath: sourcePath
        });
    }
    return animations;
}
export function parseMove2AnimDat(bytes) {
    var root = parseRubyMarshal(bytes);
    var normal = (root === null || root === void 0 ? void 0 : root[0]) instanceof Map ? root[0] : new Map();
    var opposing = (root === null || root === void 0 ? void 0 : root[1]) instanceof Map ? root[1] : new Map();
    return { normal: normal, opposing: opposing };
}
function meaningfulLegacy(rec) {
    if (!(rec === null || rec === void 0 ? void 0 : rec.name) || !Array.isArray(rec.frames) || rec.frames.length <= 1)
        return false;
    return !/^~.*~$/.test(rec.name.trim());
}
function prefixedName(name) {
    var m = String(name || "").match(/^(Common|Move|OppMove)\s*:\s*(.+)$/i);
    if (!m)
        return null;
    return { prefix: m[1].toLowerCase(), value: m[2].trim() };
}
// Reproduces the legacy-to-new grouping used by New Animation Editor:
// Move/OppMove/Common prefixes begin a family; following bare names are versions.
export function buildLegacyCatalog(animations, move2anim) {
    var e_2, _d, e_3, _e, e_4, _f, e_5, _g, e_6, _h;
    if (move2anim === void 0) {
        move2anim = null;
    }
    var normalByIndex = new Map(), oppByIndex = new Map();
    try {
        for (var _j = __values((move2anim === null || move2anim === void 0 ? void 0 : move2anim.normal) || []), _k = _j.next(); !_k.done; _k = _j.next()) {
            var _l = __read(_k.value, 2), move = _l[0], idx = _l[1];
            normalByIndex.set(Number(idx), String(move));
        }
    }
    catch (e_2_1) {
        e_2 = { error: e_2_1 };
    }
    finally {
        try {
            if (_k && !_k.done && (_d = _j.return))
                _d.call(_j);
        }
        finally {
            if (e_2)
                throw e_2.error;
        }
    }
    try {
        for (var _m = __values((move2anim === null || move2anim === void 0 ? void 0 : move2anim.opposing) || []), _o = _m.next(); !_o.done; _o = _m.next()) {
            var _p = __read(_o.value, 2), move = _p[0], idx = _p[1];
            oppByIndex.set(Number(idx), String(move));
        }
    }
    catch (e_3_1) {
        e_3 = { error: e_3_1 };
    }
    finally {
        try {
            if (_o && !_o.done && (_e = _m.return))
                _e.call(_m);
        }
        finally {
            if (e_3)
                throw e_3.error;
        }
    }
    var moves = new Map(), common = new Map(), records = [];
    var last = null;
    try {
        for (var _q = __values(animations || []), _r = _q.next(); !_r.done; _r = _q.next()) {
            var rec = _r.value;
            if (!meaningfulLegacy(rec))
                continue;
            var p = prefixedName(rec.name);
            var type = void 0, move = void 0, version = 0, label = void 0;
            if (p) {
                type = p.prefix === "common" ? "common" : p.prefix === "oppmove" ? "opp_move" : "move";
                move = p.value;
                version = 0;
                last = { type: type, move: move, version: 0 };
                label = p.value;
            }
            else if (last) {
                type = last.type;
                move = last.move;
                version = ++last.version;
                label = rec.name;
            }
            else {
                // move2anim.dat can still identify old entries whose name has no prefix.
                var mappedOpp = oppByIndex.get(Number(rec.id)), mapped = normalByIndex.get(Number(rec.id));
                if (!mapped && !mappedOpp)
                    continue;
                type = mappedOpp ? "opp_move" : "move";
                move = mappedOpp || mapped;
                version = 0;
                label = rec.name || move;
                last = { type: type, move: move, version: version };
            }
            var mappedMove = type === "opp_move" ? oppByIndex.get(Number(rec.id)) : normalByIndex.get(Number(rec.id));
            if (mappedMove && version === 0)
                move = mappedMove;
            var item = Object.assign(Object.assign({}, rec), { catalogType: type, move: move, version: version, label: label || move, opposing: type === "opp_move" });
            records.push(item);
            var target = type === "common" ? common : moves;
            var key = type === "common" ? move : move;
            if (!target.has(key))
                target.set(key, []);
            target.get(key).push(item);
        }
    }
    catch (e_4_1) {
        e_4 = { error: e_4_1 };
    }
    finally {
        try {
            if (_r && !_r.done && (_f = _q.return))
                _f.call(_q);
        }
        finally {
            if (e_4)
                throw e_4.error;
        }
    }
    var sortVersions = function (arr) { return arr.sort(function (a, b) { return Number(a.opposing) - Number(b.opposing) || a.version - b.version || a.id - b.id; }); };
    try {
        for (var _s = __values(moves.values()), _t = _s.next(); !_t.done; _t = _s.next()) {
            var arr = _t.value;
            sortVersions(arr);
        }
    }
    catch (e_5_1) {
        e_5 = { error: e_5_1 };
    }
    finally {
        try {
            if (_t && !_t.done && (_g = _s.return))
                _g.call(_s);
        }
        finally {
            if (e_5)
                throw e_5.error;
        }
    }
    try {
        for (var _u = __values(common.values()), _v = _u.next(); !_v.done; _v = _u.next()) {
            var arr = _v.value;
            sortVersions(arr);
        }
    }
    catch (e_6_1) {
        e_6 = { error: e_6_1 };
    }
    finally {
        try {
            if (_v && !_v.done && (_h = _u.return))
                _h.call(_u);
        }
        finally {
            if (e_6)
                throw e_6.error;
        }
    }
    return { moves: moves, common: common, records: records };
}
export function catalogToSerializable(catalog) {
    var conv = function (map) {
        return __spreadArray([], __read(map.entries()), false).map(function (_d) {
            var _e = __read(_d, 2), name = _e[0], versions = _e[1];
            return ({ name: name, versions: versions.map(function (v) { return ({ id: v.id, name: v.name, label: v.label, version: v.version, opposing: v.opposing, move: v.move }); }) });
        });
    };
    return { moves: conv(catalog.moves), common: conv(catalog.common) };
}
