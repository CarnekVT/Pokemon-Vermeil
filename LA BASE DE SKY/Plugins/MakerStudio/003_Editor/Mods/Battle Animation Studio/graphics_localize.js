var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try {
            step(generator.next(value));
        }
        catch (e) {
            reject(e);
        } }
        function rejected(value) { try {
            step(generator["throw"](value));
        }
        catch (e) {
            reject(e);
        } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function () { if (t[0] & 1)
            throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function () { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f)
            throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _)
            try {
                if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done)
                    return t;
                if (y = 0, t)
                    op = [op[0] & 2, t.value];
                switch (op[0]) {
                    case 0:
                    case 1:
                        t = op;
                        break;
                    case 4:
                        _.label++;
                        return { value: op[1], done: false };
                    case 5:
                        _.label++;
                        y = op[1];
                        op = [0];
                        continue;
                    case 7:
                        op = _.ops.pop();
                        _.trys.pop();
                        continue;
                    default:
                        if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) {
                            _ = 0;
                            continue;
                        }
                        if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) {
                            _.label = op[1];
                            break;
                        }
                        if (op[0] === 6 && _.label < t[1]) {
                            _.label = t[1];
                            t = op;
                            break;
                        }
                        if (t && _.label < t[2]) {
                            _.label = t[2];
                            _.ops.push(op);
                            break;
                        }
                        if (t[2])
                            _.ops.pop();
                        _.trys.pop();
                        continue;
                }
                op = body.call(thisArg, _);
            }
            catch (e) {
                op = [6, e];
                y = 0;
            }
            finally {
                f = t = 0;
            }
        if (op[0] & 5)
            throw op[1];
        return { value: op[0] ? op[1] : void 0, done: true };
    }
};
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
// Graphic localization helpers for imported animations.
// Collects every graphic referenced by an animation (particle bitmaps,
// mid-animation setBitmap switches and PBS mask graphics), checks which ones
// already exist in the current project, finds similar project assets by name
// and can copy the exact source files from the source game into the project.
import { getAllClips } from "./model.js";
import { absoluteProjectPath, resolveExternalGraphicPath } from "./assets.js";
var IMAGE_EXT_RE = /\.(png|bmp|jpg|jpeg|webp|gif)$/i;
var ASSET_ROOTS = [
    { id: "studio", projectPath: "Graphics/AnimationStudio" },
    { id: "legacy", projectPath: "Graphics/Animations" },
    { id: "new", projectPath: "Graphics/Battle animations" },
    { id: "ebdx_moves", projectPath: "Graphics/EBDX/Animations/Moves" },
    { id: "ebdx_common", projectPath: "Graphics/EBDX/Animations/Common" },
    { id: "battle", projectPath: "Graphics/Battle" },
    { id: "code", projectPath: "Graphics/BattleParticlesAnimations" }
];
export function basename(path) { return String(path || "").replace(/[\\/]+$/, "").split(/[\\/]/).pop() || ""; }
export function stemOf(path) { return basename(path).replace(/\.[^.]+$/, ""); }
function invoke(name, args) {
    return __awaiter(this, void 0, void 0, function () {
        var _a, _b, fn;
        return __generator(this, function (_c) {
            switch (_c.label) {
                case 0:
                    fn = (_b = (_a = window.__TAURI__) === null || _a === void 0 ? void 0 : _a.core) === null || _b === void 0 ? void 0 : _b.invoke;
                    if (!fn)
                        throw new Error("Tauri invoke is unavailable");
                    return [4 /*yield*/, fn(name, args)];
                case 1: return [2 /*return*/, _c.sent()];
            }
        });
    });
}
function projectFileExists(ctx, projectPath) {
    return __awaiter(this, void 0, void 0, function () {
        var _a_1;
        return __generator(this, function (_c) {
            switch (_c.label) {
                case 0:
                    if (!projectPath)
                        return [2 /*return*/, false];
                    _c.label = 1;
                case 1:
                    _c.trys.push([1, 3, , 4]);
                    return [4 /*yield*/, invoke("file_exists", { path: absoluteProjectPath(ctx, projectPath) })];
                case 2: return [2 /*return*/, !!(_c.sent())];
                case 3:
                    _a_1 = _c.sent();
                    return [2 /*return*/, false];
                case 4: return [2 /*return*/];
            }
        });
    });
}
// -----------------------------------------------------------------------------
// Collecting every graphic the animation references
// -----------------------------------------------------------------------------
export function collectAnimationGraphics(animation) {
    var e_1, _c;
    var items = [];
    var seen = new Set();
    var _loop_1 = function (clip) {
        var e_2, _f;
        var g = clip.graphic || {};
        var src = String(g.source || "");
        if (src.startsWith("battler-"))
            return "continue";
        var hasReference = !!(g.projectPath || g.relativeHint || g.name || (g.assetCandidates || []).length);
        if (hasReference) {
            items.push({
                key: "main:".concat(clip.id),
                kind: "main",
                label: clip.name || "Partícula",
                clip: clip,
                desc: g,
                apply: function (projectPath) {
                    g.projectPath = projectPath;
                    g.name = stemOf(projectPath);
                    delete g.externalGameRoot;
                    g.localized = true;
                }
            });
        }
        var _loop_2 = function (sw) {
            var raw = String(sw.value || "");
            if (!raw || !/(Graphics|\.(?:png|bmp|jpg|jpeg|webp|gif)$)/i.test(raw))
                return "continue";
            var key = "switch:".concat(clip.id, ":").concat(raw);
            if (seen.has(key))
                return "continue";
            seen.add(key);
            items.push({
                key: key,
                kind: "switch",
                label: "Switch bitmap \u00B7 ".concat(clip.name || "Partícula"),
                clip: clip,
                sw: sw,
                desc: {
                    source: "code",
                    projectPath: raw,
                    externalRelativePath: raw,
                    relativeHint: raw,
                    name: stemOf(raw),
                    folder: raw.includes("AnimationStudio") ? "AnimationStudio" : raw.includes("BattleParticlesAnimations") ? "BattleParticlesAnimations" : raw.includes("Battle animations") ? "Battle animations" : raw.includes("Animations") ? "Animations" : ""
                },
                apply: function (projectPath) {
                    sw.value = projectPath;
                    if (!clip.graphic)
                        clip.graphic = {};
                    clip.graphic.localized = true;
                }
            });
        };
        try {
            for (var _g = (e_2 = void 0, __values(clip.graphicSwitches || [])), _h = _g.next(); !_h.done; _h = _g.next()) {
                var sw = _h.value;
                _loop_2(sw);
            }
        }
        catch (e_2_1) {
            e_2 = { error: e_2_1 };
        }
        finally {
            try {
                if (_h && !_h.done && (_f = _g.return))
                    _f.call(_g);
            }
            finally {
                if (e_2)
                    throw e_2.error;
            }
        }
        if (clip.pbs && clip.pbs.maskGraphic) {
            var raw = String(clip.pbs.maskGraphic);
            var key = "mask:".concat(clip.id, ":").concat(raw);
            items.push({
                key: key,
                kind: "mask",
                label: "M\u00E1scara \u00B7 ".concat(clip.name || "Partícula"),
                clip: clip,
                desc: { source: "new", folder: "Battle animations", name: stemOf(raw), relativeHint: raw },
                apply: function (projectPath) {
                    clip.pbs.maskGraphic = basename(projectPath);
                    if (!clip.graphic)
                        clip.graphic = {};
                    clip.graphic.localized = true;
                }
            });
        }
    };
    try {
        for (var _d = __values(getAllClips(animation)), _e = _d.next(); !_e.done; _e = _d.next()) {
            var clip = _e.value;
            _loop_1(clip);
        }
    }
    catch (e_1_1) {
        e_1 = { error: e_1_1 };
    }
    finally {
        try {
            if (_e && !_e.done && (_c = _d.return))
                _c.call(_d);
        }
        finally {
            if (e_1)
                throw e_1.error;
        }
    }
    return items;
}
// -----------------------------------------------------------------------------
// Similar-graphic search inside the current project
// -----------------------------------------------------------------------------
function normKey(s) {
    return String(s || "").toLowerCase()
        .replace(IMAGE_EXT_RE, "")
        .replace(/\[\s*bottom\s*\]/g, "")
        .replace(/[^a-z0-9]+/g, " ")
        .trim();
}
function wordsOf(k) { return k.split(/\s+/).filter(Boolean); }
export function similarProjectAssets(assets, desc) {
    var e_3, _c, e_4, _d, e_5, _e;
    // Match on the file's leaf name only. The full path may contain generic
    // folder words ("graphics", "battle", "animations") that would match every
    // asset and drown out the actual name comparison.
    var raw = String(desc.relativeHint || desc.externalRelativePath || desc.projectPath || desc.name || "").replace(/\\/g, "/");
    var folder = String(desc.folder || "").toLowerCase();
    var leafRaw = raw.split("/").pop() || raw;
    var want = normKey(leafRaw), wantFull = normKey(raw);
    if (!want)
        return [];
    var wanted = wordsOf(want), wantStripped = want.replace(/\s*\d+$/, "");
    var wantNum = (leafRaw.match(/(\d+)\s*$/) || [])[1] || "";
    var scored = [];
    try {
        for (var _f = __values(assets || []), _g = _f.next(); !_g.done; _g = _f.next()) {
            var a = _g.value;
            var key = normKey(a.name), proj = normKey(a.projectPath);
            if (!key && !proj)
                continue;
            // Folder affinity: same animation root is much more likely to be the
            // intended graphic than a same-named asset living elsewhere.
            var pathL = String(a.projectPath || "").toLowerCase();
            var inFolder = !!folder && (pathL.includes("/".concat(folder, "/")) || pathL.endsWith("/".concat(folder)));
            var inOtherRoot = !!folder && !inFolder;
            if (proj === wantFull || key === want || proj.endsWith("/".concat(want))) {
                scored.push({ asset: a, score: 100 + (inFolder ? 5 : 0) });
                continue;
            }
            var ka = wordsOf(key);
            // Strongest signal: the wanted name appears as a whole word in the
            // asset name ("ember" -> "ember fire"). Assets are usually more
            // specific than the bare hint, e.g. numbered PBS particles.
            var prefixHit = key === wantStripped || key.startsWith(wantStripped + " ")
                || key.includes(" " + wantStripped + " ") || key.endsWith(" " + wantStripped);
            // Weakest acceptable signal: the asset is a truncation of the wanted
            // name ("ember fire" -> "ember"). Easily confused with unrelated
            // graphics, so it barely qualifies.
            var truncationHit = !prefixHit && wantStripped.length > 2 && wantStripped.startsWith(key);
            var common = 0;
            try {
                for (var wanted_1 = (e_4 = void 0, __values(wanted)), wanted_1_1 = wanted_1.next(); !wanted_1_1.done; wanted_1_1 = wanted_1.next()) {
                    var kw = wanted_1_1.value;
                    try {
                        for (var ka_1 = (e_5 = void 0, __values(ka)), ka_1_1 = ka_1.next(); !ka_1_1.done; ka_1_1 = ka_1.next()) {
                            var ak = ka_1_1.value;
                            if (kw === ak) {
                                common++;
                                break;
                            }
                        }
                    }
                    catch (e_5_1) {
                        e_5 = { error: e_5_1 };
                    }
                    finally {
                        try {
                            if (ka_1_1 && !ka_1_1.done && (_e = ka_1.return))
                                _e.call(ka_1);
                        }
                        finally {
                            if (e_5)
                                throw e_5.error;
                        }
                    }
                }
            }
            catch (e_4_1) {
                e_4 = { error: e_4_1 };
            }
            finally {
                try {
                    if (wanted_1_1 && !wanted_1_1.done && (_d = wanted_1.return))
                        _d.call(wanted_1);
                }
                finally {
                    if (e_4)
                        throw e_4.error;
                }
            }
            var score = 0;
            if (prefixHit) {
                score = 78 + Math.min(10, common * 3);
            }
            else if (truncationHit) {
                score = 46;
            }
            else if (common > 0) {
                // Missing wanted words hurt: "fire punch hit" must not match
                // "fire slash" as well as "fire punch".
                score = Math.round((common / wanted.length) * 70);
                if (ka.length === 1 && common === 1 && wanted.length > 1)
                    score = Math.min(score, 42);
            }
            if (score >= 45) {
                // Close numbered variants are a plus ("ember 2" vs "ember 3").
                var an = (a.name.match(/(\d+)\s*$/) || [])[1] || "";
                if (wantNum && an && Math.abs(Number(wantNum) - Number(an)) <= 1)
                    score += 5;
                score += inFolder ? 14 : (inOtherRoot ? -16 : 0);
                if (score >= 45)
                    scored.push({ asset: a, score: score });
            }
        }
    }
    catch (e_3_1) {
        e_3 = { error: e_3_1 };
    }
    finally {
        try {
            if (_g && !_g.done && (_c = _f.return))
                _c.call(_f);
        }
        finally {
            if (e_3)
                throw e_3.error;
        }
    }
    var sourcePriority = { legacy: 0, new: 1, code: 2 };
    scored.sort(function (x, y) { return y.score - x.score || ((sourcePriority[x.asset.source] !== undefined) ? sourcePriority[x.asset.source] : 9) - ((sourcePriority[y.asset.source] !== undefined) ? sourcePriority[y.asset.source] : 9) || x.asset.projectPath.localeCompare(y.asset.projectPath); });
    return scored.slice(0, 4).map(function (s) { return s.asset; });
}
// -----------------------------------------------------------------------------
// Planning: what exists / what can be imported / what is similar
// -----------------------------------------------------------------------------
export function planGraphicItems(ctx, items, externalRoot, assets) {
    return __awaiter(this, void 0, void 0, function () {
        var out, _loop_3, items_1, items_1_1, item, e_6_1;
        var e_6, _c;
        return __generator(this, function (_d) {
            switch (_d.label) {
                case 0:
                    out = [];
                    _loop_3 = function (item) {
                        var desc, existing, candidates, addExact, leaf, filename, folder, root, seenCandidates, candidates_1, candidates_1_1, c, key, e_7_1, sourcePath, similars;
                        var e_7, _e;
                        return __generator(this, function (_f) {
                            switch (_f.label) {
                                case 0:
                                    desc = item.desc;
                                    existing = null;
                                    candidates = [];
                                    addExact = function (value) {
                                        var v = String(value || "").trim().replace(/\\/g, "/").replace(/^\/+/, "");
                                        if (!v)
                                            return;
                                        if (/^Graphics\//i.test(v))
                                            candidates.push(v);
                                        else if (/^(?:AnimationStudio|Animations|Battle animations|BattleParticlesAnimations)\//i.test(v))
                                            candidates.push("Graphics/".concat(v));
                                    };
                                    addExact(desc.projectPath);
                                    addExact(desc.externalRelativePath);
                                    addExact(desc.relativeHint);
                                    leaf = basename(desc.projectPath || desc.externalRelativePath || desc.relativeHint || desc.name || "");
                                    filename = IMAGE_EXT_RE.test(leaf) ? leaf : (leaf ? "".concat(leaf, ".png") : "");
                                    folder = String(desc.folder || "").trim().replace(/^Graphics\//i, "").replace(/[\\/]+$/, "");
                                    if (filename)
                                        candidates.push("Graphics/AnimationStudio/".concat(filename));
                                    if (filename && folder)
                                        candidates.push("Graphics/".concat(folder, "/").concat(filename));
                                    if (filename && desc.source) {
                                        root = ASSET_ROOTS.find(function (r) { return r.id === String(desc.source); });
                                        if (root)
                                            candidates.push("".concat(root.projectPath, "/").concat(filename));
                                    }
                                    if (filename) {
                                        ASSET_ROOTS.forEach(function (r) {
                                            candidates.push("".concat(r.projectPath, "/").concat(filename));
                                        });
                                    }
                                    seenCandidates = new Set();
                                    _f.label = 1;
                                case 1:
                                    _f.trys.push([1, 6, 7, 8]);
                                    candidates_1 = (e_7 = void 0, __values(candidates)), candidates_1_1 = candidates_1.next();
                                    _f.label = 2;
                                case 2:
                                    if (!!candidates_1_1.done)
                                        return [3 /*break*/, 5];
                                    c = candidates_1_1.value;
                                    key = String(c || "").toLowerCase();
                                    if (!c || seenCandidates.has(key))
                                        return [3 /*break*/, 4];
                                    seenCandidates.add(key);
                                    return [4 /*yield*/, projectFileExists(ctx, c)];
                                case 3:
                                    if (_f.sent()) {
                                        existing = c;
                                        return [3 /*break*/, 5];
                                    }
                                    _f.label = 4;
                                case 4:
                                    candidates_1_1 = candidates_1.next();
                                    return [3 /*break*/, 2];
                                case 5: return [3 /*break*/, 8];
                                case 6:
                                    e_7_1 = _f.sent();
                                    e_7 = { error: e_7_1 };
                                    return [3 /*break*/, 8];
                                case 7:
                                    try {
                                        if (candidates_1_1 && !candidates_1_1.done && (_e = candidates_1.return))
                                            _e.call(candidates_1);
                                    }
                                    finally {
                                        if (e_7)
                                            throw e_7.error;
                                    }
                                    return [7 /*endfinally*/];
                                case 8:
                                    if (!existing && filename && Array.isArray(assets) && assets.length) {
                                        var fnLower_1 = filename.toLowerCase();
                                        var exactAsset = assets.find(function (a) {
                                            return (a.filename && a.filename.toLowerCase() === fnLower_1)
                                                || (a.name && normKey(a.name) === normKey(leaf));
                                        });
                                        if (exactAsset && exactAsset.projectPath) {
                                            existing = exactAsset.projectPath;
                                        }
                                    }
                                    sourcePath = "";
                                    if (!externalRoot)
                                        return [3 /*break*/, 10];
                                    return [4 /*yield*/, resolveExternalGraphicPath(externalRoot, desc)];
                                case 9:
                                    sourcePath = _f.sent();
                                    _f.label = 10;
                                case 10:
                                    similars = [];
                                    if (!existing)
                                        similars = similarProjectAssets(assets, desc).filter(function (a) { return a.projectPath !== existing; });
                                    out.push(Object.assign(Object.assign({}, item), { plan: { existing: existing, sourcePath: sourcePath, similars: similars } }));
                                    return [2 /*return*/];
                            }
                        });
                    };
                    _d.label = 1;
                case 1:
                    _d.trys.push([1, 6, 7, 8]);
                    items_1 = __values(items), items_1_1 = items_1.next();
                    _d.label = 2;
                case 2:
                    if (!!items_1_1.done)
                        return [3 /*break*/, 5];
                    item = items_1_1.value;
                    return [5 /*yield**/, _loop_3(item)];
                case 3:
                    _d.sent();
                    _d.label = 4;
                case 4:
                    items_1_1 = items_1.next();
                    return [3 /*break*/, 2];
                case 5: return [3 /*break*/, 8];
                case 6:
                    e_6_1 = _d.sent();
                    e_6 = { error: e_6_1 };
                    return [3 /*break*/, 8];
                case 7:
                    try {
                        if (items_1_1 && !items_1_1.done && (_c = items_1.return))
                            _c.call(items_1);
                    }
                    finally {
                        if (e_6)
                            throw e_6.error;
                    }
                    return [7 /*endfinally*/];
                case 8: return [2 /*return*/, out];
            }
        });
    });
}
// -----------------------------------------------------------------------------
// Importing the source file into the project
// -----------------------------------------------------------------------------
function rootFor(desc) {
    var folder = String(desc.folder || "").toLowerCase();
    var root = ASSET_ROOTS.find(function (r) { return r.projectPath.toLowerCase().endsWith("/".concat(folder)); });
    if (!root) {
        var p_1 = String(desc.projectPath || desc.externalRelativePath || "").replace(/\\/g, "/");
        root = ASSET_ROOTS.find(function (r) { return p_1.toLowerCase().startsWith(r.projectPath.toLowerCase()); })
            || ASSET_ROOTS.find(function (r) { return r.id === String(desc.source || ""); })
            || ASSET_ROOTS[0];
    }
    return root;
}
export function destinationForImport(desc, filename) { return "".concat(rootFor(desc).projectPath, "/").concat(filename); }
export function importGraphicIntoProject(ctx, desc, sourcePath) {
    return __awaiter(this, void 0, void 0, function () {
        var bytes, _a_2, preferred, root, _c, _d, r, e_8_1, filename, dot, dest, n, base, ext, e_9;
        var e_8, _e;
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    if (!sourcePath)
                        return [2 /*return*/, ""];
                    _f.label = 1;
                case 1:
                    _f.trys.push([1, 3, , 4]);
                    return [4 /*yield*/, invoke("read_binary_file", { path: sourcePath })];
                case 2:
                    bytes = _f.sent();
                    return [3 /*break*/, 4];
                case 3:
                    _a_2 = _f.sent();
                    return [2 /*return*/, ""];
                case 4:
                    if (!bytes || !bytes.length)
                        return [2 /*return*/, ""];
                    preferred = rootFor(desc);
                    root = preferred;
                    _f.label = 5;
                case 5:
                    _f.trys.push([5, 10, 11, 12]);
                    _c = __values(__spreadArray([preferred], __read(ASSET_ROOTS.filter(function (x) { return x !== preferred; })), false)), _d = _c.next();
                    _f.label = 6;
                case 6:
                    if (!!_d.done)
                        return [3 /*break*/, 9];
                    r = _d.value;
                    return [4 /*yield*/, projectFileExists(ctx, r.projectPath)];
                case 7:
                    if (_f.sent()) {
                        root = r;
                        return [3 /*break*/, 9];
                    }
                    _f.label = 8;
                case 8:
                    _d = _c.next();
                    return [3 /*break*/, 6];
                case 9: return [3 /*break*/, 12];
                case 10:
                    e_8_1 = _f.sent();
                    e_8 = { error: e_8_1 };
                    return [3 /*break*/, 12];
                case 11:
                    try {
                        if (_d && !_d.done && (_e = _c.return))
                            _e.call(_c);
                    }
                    finally {
                        if (e_8)
                            throw e_8.error;
                    }
                    return [7 /*endfinally*/];
                case 12:
                    filename = basename(sourcePath), dot = filename.lastIndexOf(".");
                    dest = "".concat(root.projectPath, "/").concat(filename), n = 1;
                    _f.label = 13;
                case 13: return [4 /*yield*/, projectFileExists(ctx, dest)];
                case 14:
                    if (!_f.sent())
                        return [3 /*break*/, 15];
                    base = dot > 0 ? filename.slice(0, dot) : filename, ext = dot > 0 ? filename.slice(dot) : "";
                    dest = "".concat(root.projectPath, "/").concat(base, "_").concat(++n).concat(ext);
                    return [3 /*break*/, 13];
                case 15:
                    _f.trys.push([15, 17, , 18]);
                    return [4 /*yield*/, invoke("write_binary_file", { path: absoluteProjectPath(ctx, dest), data: Array.from(bytes) })];
                case 16:
                    _f.sent();
                    return [3 /*break*/, 18];
                case 17:
                    e_9 = _f.sent();
                    console.error("Graphic import failed", e_9);
                    return [2 /*return*/, ""];
                case 18: return [2 /*return*/, dest];
            }
        });
    });
}
export function localizeGraphic(item, projectPath) {
    if (!item || !projectPath)
        return false;
    item.apply(projectPath);
    return true;
}
