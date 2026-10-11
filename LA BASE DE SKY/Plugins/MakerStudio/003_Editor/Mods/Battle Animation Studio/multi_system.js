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
import { animationFromCode, discoverCodeMetadata } from "./importers.js";
// Internal compatibility layer inspired by Animation Multi-System Compat.
// It keeps one Studio/Preview Bridge, but routes each source through a clearly
// identified subsystem and preserves EBDX definition metadata such as species.
export var MULTI_SYSTEM_ORDER = ["studio", "vanilla", "pbs", "vermeil_ruby", "ebdx", "ruby"];
export function detectCodeSystem(text, filename) {
    if (filename === void 0) {
        filename = "";
    }
    var src = String(text || "");
    var name = String(filename || "");
    if (/EliteBattle\.define(?:Move|Common)Animation\s*\(/.test(src) || /Elite\s*Battle\s*DX|EBDX/i.test(name))
        return "ebdx";
    if (/Vermeil|Battle::Scene::Animation::Vermeil|\[VERMEIL\]/i.test(src + " " + name))
        return "vermeil_ruby";
    return "ruby";
}
function sourceLineAt(text, index) {
    return String(text || "").slice(0, Math.max(0, Number(index || 0))).split(/\r?\n/).length;
}
// EBDX files can define the same move more than once for species overrides.
// Keep every definition instead of collapsing everything by Move ID.
export function extractEliteDefinitions(text, filename) {
    var e_1, _a, e_2, _b;
    if (filename === void 0) {
        filename = "";
    }
    var src = String(text || "");
    var re = /EliteBattle\.define(Move|Common)Animation\s*\(\s*(?::([A-Za-z0-9_]+)|["']([^"']+)["'])(?:\s*,\s*(?::([A-Za-z0-9_]+)|["']([^"']+)["']))?/g;
    var found = [];
    var m;
    while ((m = re.exec(src))) {
        found.push({
            type: m[1] === "Common" ? "common" : "move",
            id: String(m[2] || m[3] || "").trim(),
            species: String(m[4] || m[5] || "").trim(),
            start: m.index,
            sourceLine: sourceLineAt(src, m.index),
            filename: String(filename || ""),
            system: "ebdx"
        });
    }
    for (var i = 0; i < found.length; i++) {
        var end = i + 1 < found.length ? found[i + 1].start : src.length;
        found[i].selectedSource = src.slice(found[i].start, end);
        var alias = found[i].selectedSource.match(/EliteBattle\.playMoveAnimation\s*\(\s*:([A-Za-z0-9_]+)/);
        var executableLines = found[i].selectedSource.split(/\r?\n/).map(function (x) { return x.replace(/#.*$/, "").trim(); }).filter(Boolean);
        // Only treat tiny wrapper definitions as aliases. Full animations often
        // call another move near the end as one phase (TAKEDOWN -> HEADBUTT).
        found[i].aliasTarget = alias && executableLines.length <= 4 ? String(alias[1]).toUpperCase() : "";
    }
    // Resolve local EBDX aliases (BODYSLAM -> TAKEDOWN, etc.) so an alias imports
    // the visual implementation instead of producing an empty timeline.
    var byId = new Map();
    try {
        for (var found_1 = __values(found), found_1_1 = found_1.next(); !found_1_1.done; found_1_1 = found_1.next()) {
            var def = found_1_1.value;
            var key = "".concat(def.type, ":").concat(String(def.id).toUpperCase());
            if (!byId.has(key) || def.species)
                byId.set(key, def);
        }
    }
    catch (e_1_1) {
        e_1 = { error: e_1_1 };
    }
    finally {
        try {
            if (found_1_1 && !found_1_1.done && (_a = found_1.return))
                _a.call(found_1);
        }
        finally {
            if (e_1)
                throw e_1.error;
        }
    }
    var resolve = function (def, seen) {
        if (seen === void 0) {
            seen = new Set();
        }
        if (!def || !def.aliasTarget)
            return def ? def.selectedSource : "";
        var key = String(def.aliasTarget).toUpperCase();
        if (seen.has(key))
            return def.selectedSource;
        seen.add(key);
        var target = byId.get("move:".concat(key));
        return target ? resolve(target, seen) : def.selectedSource;
    };
    try {
        for (var found_2 = __values(found), found_2_1 = found_2.next(); !found_2_1.done; found_2_1 = found_2.next()) {
            var def = found_2_1.value;
            def.resolvedSource = resolve(def);
        }
    }
    catch (e_2_1) {
        e_2 = { error: e_2_1 };
    }
    finally {
        try {
            if (found_2_1 && !found_2_1.done && (_b = found_2.return))
                _b.call(found_2);
        }
        finally {
            if (e_2)
                throw e_2.error;
        }
    }
    return found;
}
export function extractCodeDefinitions(text, filename) {
    var e_3, _a, e_4, _b;
    if (filename === void 0) {
        filename = "";
    }
    var system = detectCodeSystem(text, filename);
    if (system === "ebdx") {
        var defs_1 = extractEliteDefinitions(text, filename);
        if (defs_1.length)
            return defs_1;
    }
    var metadata = discoverCodeMetadata(text, filename);
    var defs = [];
    try {
        for (var _c = __values(metadata.moves || []), _d = _c.next(); !_d.done; _d = _c.next()) {
            var id = _d.value;
            defs.push({ type: "move", id: id, species: "", system: system, selectedSource: null, sourceLine: 0, metadata: metadata });
        }
    }
    catch (e_3_1) {
        e_3 = { error: e_3_1 };
    }
    finally {
        try {
            if (_d && !_d.done && (_a = _c.return))
                _a.call(_c);
        }
        finally {
            if (e_3)
                throw e_3.error;
        }
    }
    try {
        for (var _e = __values(metadata.common || []), _f = _e.next(); !_f.done; _f = _e.next()) {
            var id = _f.value;
            defs.push({ type: "common", id: id, species: "", system: system, selectedSource: null, sourceLine: 0, metadata: metadata });
        }
    }
    catch (e_4_1) {
        e_4 = { error: e_4_1 };
    }
    finally {
        try {
            if (_f && !_f.done && (_b = _e.return))
                _b.call(_e);
        }
        finally {
            if (e_4)
                throw e_4.error;
        }
    }
    if (!defs.length) {
        var fallback = String(filename || "Code Animation").replace(/\.rb$/i, "").replace(/[^A-Za-z0-9_]+/g, "");
        if (fallback)
            defs.push({ type: "move", id: fallback.toUpperCase(), species: "", system: system, selectedSource: null, sourceLine: 0, metadata: metadata });
    }
    return defs;
}
export function buildCodeImportCatalog(text, filename, behavior, metadataOverride) {
    var e_5, _a, e_6, _b, e_7, _c, e_8, _d;
    if (filename === void 0) {
        filename = "";
    }
    if (behavior === void 0) {
        behavior = "cinematic";
    }
    if (metadataOverride === void 0) {
        metadataOverride = null;
    }
    var metadata = metadataOverride || discoverCodeMetadata(text, filename);
    var definitions = extractCodeDefinitions(text, filename);
    var moves = new Map(), common = new Map();
    var add = function (map, key, rec) {
        if (!map.has(key))
            map.set(key, []);
        map.get(key).push(rec);
    };
    try {
        for (var definitions_1 = __values(definitions), definitions_1_1 = definitions_1.next(); !definitions_1_1.done; definitions_1_1 = definitions_1.next()) {
            var def = definitions_1_1.value;
            var map = def.type === "common" ? common : moves;
            var key = def.id;
            try {
                for (var _e = (e_6 = void 0, __values(["player", "foe"])), _f = _e.next(); !_f.done; _f = _e.next()) {
                    var sideContext = _f.value;
                    var speciesText = def.species ? " \u00B7 ".concat(def.species) : "";
                    add(map, key, {
                        move: key,
                        common: def.type === "common" ? key : undefined,
                        catalogType: def.type,
                        label: "".concat(key).concat(speciesText, " \u00B7 ").concat(sideContext === "foe" ? "Foe" : "Player"),
                        version: 0,
                        opposing: sideContext === "foe",
                        sideContext: sideContext,
                        behavior: metadata.behavior || behavior,
                        system: def.system,
                        species: def.species || "",
                        sourceLine: def.sourceLine || 0,
                        selectedSource: def.resolvedSource || def.selectedSource || null,
                        aliasTarget: def.aliasTarget || "",
                        id: "".concat(key, ":").concat(def.species || "default", ":").concat(sideContext)
                    });
                }
            }
            catch (e_6_1) {
                e_6 = { error: e_6_1 };
            }
            finally {
                try {
                    if (_f && !_f.done && (_b = _e.return))
                        _b.call(_e);
                }
                finally {
                    if (e_6)
                        throw e_6.error;
                }
            }
        }
    }
    catch (e_5_1) {
        e_5 = { error: e_5_1 };
    }
    finally {
        try {
            if (definitions_1_1 && !definitions_1_1.done && (_a = definitions_1.return))
                _a.call(definitions_1);
        }
        finally {
            if (e_5)
                throw e_5.error;
        }
    }
    try {
        for (var _g = __values([moves, common]), _h = _g.next(); !_h.done; _h = _g.next()) {
            var map = _h.value;
            try {
                for (var _j = (e_8 = void 0, __values(map.values())), _k = _j.next(); !_k.done; _k = _j.next()) {
                    var arr = _k.value;
                    arr.sort(function (a, b) { return String(a.species || "").localeCompare(String(b.species || ""), undefined, { numeric: true, sensitivity: "base" }) || Number(a.opposing) - Number(b.opposing); });
                }
            }
            catch (e_8_1) {
                e_8 = { error: e_8_1 };
            }
            finally {
                try {
                    if (_k && !_k.done && (_d = _j.return))
                        _d.call(_j);
                }
                finally {
                    if (e_8)
                        throw e_8.error;
                }
            }
        }
    }
    catch (e_7_1) {
        e_7 = { error: e_7_1 };
    }
    finally {
        try {
            if (_h && !_h.done && (_c = _g.return))
                _c.call(_g);
        }
        finally {
            if (e_7)
                throw e_7.error;
        }
    }
    return { moves: moves, common: common, metadata: metadata, system: detectCodeSystem(text, filename), definitions: definitions };
}
export function importCodeVariant(text, filename, context, options) {
    if (options === void 0) {
        options = {};
    }
    var system = options.system || detectCodeSystem(text, filename);
    var metadata = options.metadata || discoverCodeMetadata(text, filename);
    var animation = animationFromCode(text, filename, context, Object.assign({}, options, {
        metadata: metadata,
        sourceSystem: system,
        selectedSource: options.selectedSource || null,
        sourceSpecies: options.species || "",
        sourceLine: Number(options.sourceLine || 0)
    }));
    animation.source || (animation.source = {});
    animation.source.system = system;
    if (options.species)
        animation.source.species = String(options.species);
    if (options.sourceLine)
        animation.source.sourceLine = Number(options.sourceLine);
    return animation;
}
export function buildMultiSystemRegistry(animations) {
    var e_9, _a, e_10, _b, e_11, _c;
    var moves = new Map(), common = new Map(), custom = new Map();
    try {
        for (var _d = __values(animations || []), _e = _d.next(); !_e.done; _e = _d.next()) {
            var a = _e.value;
            var src = a.source || {};
            var map = src.catalogType === "common" ? common : (src.catalogType === "custom" ? custom : moves);
            var key = String(src.move || a.name || "Animation");
            if (!map.has(key))
                map.set(key, []);
            map.get(key).push(a);
        }
    }
    catch (e_9_1) {
        e_9 = { error: e_9_1 };
    }
    finally {
        try {
            if (_e && !_e.done && (_a = _d.return))
                _a.call(_d);
        }
        finally {
            if (e_9)
                throw e_9.error;
        }
    }
    var systemRank = function (a) {
        var src = a.source || {};
        var sys = String(src.system || src.type || "studio");
        var i = MULTI_SYSTEM_ORDER.indexOf(sys);
        return i < 0 ? 99 : i;
    };
    var sorter = function (a, b) {
        var sa = a.source || {}, sb = b.source || {};
        return Number(sa.opposing) - Number(sb.opposing) ||
            Number(sa.version || 0) - Number(sb.version || 0) ||
            systemRank(a) - systemRank(b) ||
            String(sa.species || "").localeCompare(String(sb.species || ""), undefined, { numeric: true, sensitivity: "base" }) ||
            String(a.name || "").localeCompare(String(b.name || ""), undefined, { numeric: true, sensitivity: "base" });
    };
    try {
        for (var _f = __values([moves, common, custom]), _g = _f.next(); !_g.done; _g = _f.next()) {
            var map = _g.value;
            try {
                for (var _h = (e_11 = void 0, __values(map.values())), _j = _h.next(); !_j.done; _j = _h.next()) {
                    var arr = _j.value;
                    arr.sort(sorter);
                }
            }
            catch (e_11_1) {
                e_11 = { error: e_11_1 };
            }
            finally {
                try {
                    if (_j && !_j.done && (_c = _h.return))
                        _c.call(_h);
                }
                finally {
                    if (e_11)
                        throw e_11.error;
                }
            }
        }
    }
    catch (e_10_1) {
        e_10 = { error: e_10_1 };
    }
    finally {
        try {
            if (_g && !_g.done && (_b = _f.return))
                _b.call(_f);
        }
        finally {
            if (e_10)
                throw e_10.error;
        }
    }
    return { moves: moves, common: common, custom: custom };
}
export function compatibilityReport(animation) {
    var e_12, _a;
    if (!animation)
        return "No hay una animación seleccionada.";
    var src = animation.source || {};
    var lines = [];
    var system = String(src.system || src.type || "studio");
    lines.push("Sistema: ".concat(system));
    lines.push("Tipo: ".concat(src.catalogType === "common" ? "Common" : (src.catalogType === "custom" ? "Custom / Standalone" : "Move")));
    if (src.move)
        lines.push("ID: ".concat(src.move));
    if (src.species)
        lines.push("Especie EBDX: ".concat(src.species));
    if (src.path)
        lines.push("Fuente: ".concat(src.path).concat(src.sourceLine ? ":".concat(src.sourceLine) : ""));
    lines.push("Importaci\u00F3n: ".concat(src.approximate === false ? "runtime exacta" : src.type === "code" ? "estática" : "normalizada"));
    var unsupported = Array.isArray(src.unsupported) ? src.unsupported : [];
    if (!unsupported.length) {
        lines.push("Advertencias: ninguna detectada por el analizador.");
    }
    else {
        lines.push("Advertencias: ".concat(unsupported.length));
        try {
            for (var unsupported_1 = __values(unsupported), unsupported_1_1 = unsupported_1.next(); !unsupported_1_1.done; unsupported_1_1 = unsupported_1.next()) {
                var u = unsupported_1_1.value;
                lines.push("- ".concat(u.id || u.context || "unsupported", ": ").concat(u.detail || "no representable de forma estática"));
            }
        }
        catch (e_12_1) {
            e_12 = { error: e_12_1 };
        }
        finally {
            try {
                if (unsupported_1_1 && !unsupported_1_1.done && (_a = unsupported_1.return))
                    _a.call(unsupported_1);
            }
            finally {
                if (e_12)
                    throw e_12.error;
            }
        }
    }
    if (src.codeMetadata && src.codeMetadata.hasRandom)
        lines.push("- rand: la reproducción estática conserva una realización; el runtime puede variar.");
    if (src.codeMetadata && src.codeMetadata.hasCallbacks)
        lines.push("- callbacks: se interpretan los patrones conocidos; callbacks de estado real pueden requerir captura runtime.");
    return lines.join("\n");
}
