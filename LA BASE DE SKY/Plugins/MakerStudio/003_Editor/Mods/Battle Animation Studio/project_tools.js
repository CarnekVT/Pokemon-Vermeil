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
import { scanProjectFiles } from "./assets.js";
import { fallbackBattleContext } from "./context.js";
function stripRubyComment(line) {
    var q = false, quote = "";
    for (var i = 0; i < String(line || "").length; i++) {
        var c = line[i];
        if ((c === '"' || c === "'") && line[i - 1] !== "\\" && (!q || quote === c)) {
            q = !q;
            quote = q ? c : "";
            continue;
        }
        if (c === "#" && !q)
            return line.slice(0, i);
    }
    return line;
}
function basename(p) { return String(p || "").replace(/\\/g, "/").split("/").pop() || ""; }
function lower(p) { return String(p || "").replace(/\\/g, "/").toLowerCase(); }
function scoreSettingsCandidate(path, kind, source) {
    var p = lower(path);
    var score = 0;
    // Plugin overrides are loaded after base Essentials scripts and therefore win.
    if (source === "plugin")
        score += 400;
    if (p.includes("carnek project settings"))
        score += 500;
    if (/\/settings\/settings\.rb$/.test(p))
        score += 220;
    if (/settings\.rb$/.test(p))
        score += 100;
    if (p.includes("resolution") || p.includes("screen"))
        score += 60;
    if (kind === "resize_screen")
        score += 35;
    if (source === "script" && p.includes("scripts/001_settings/002_settings.rb"))
        score -= 100;
    return score;
}
function evalDimExpr(expr, width, height) {
    var s = String(expr || "").trim();
    s = s.replace(/Settings::SCREEN_WIDTH/g, String(width)).replace(/Settings::SCREEN_HEIGHT/g, String(height));
    if (!/^[\d\s()+\-*/.]+$/.test(s))
        return null;
    try {
        var v = Function("\"use strict\"; return (".concat(s, ");"))();
        return Number.isFinite(Number(v)) ? Number(v) : null;
    }
    catch (_a) {
        return null;
    }
}
function scanBattleSceneGeometry(ctx, width, height) {
    return __awaiter(this, void 0, void 0, function () {
        var files, _a_1, likely, _loop_1, likely_1, likely_1_1, file, state_1, e_1_1;
        var e_1, _m;
        return __generator(this, function (_o) {
            switch (_o.label) {
                case 0:
                    files = [];
                    _o.label = 1;
                case 1:
                    _o.trys.push([1, 3, , 4]);
                    return [4 /*yield*/, Promise.all([
                            scanProjectFiles(ctx, "Scripts", ["rb"], 8).catch(function () { return []; }),
                            scanProjectFiles(ctx, "Data/Scripts", ["rb"], 8).catch(function () { return []; })
                        ])];
                case 2:
                    files = (_o.sent() || []).flat();
                    return [3 /*break*/, 4];
                case 3:
                    _a_1 = _o.sent();
                    return [2 /*return*/, null];
                case 4:
                    likely = files.filter(function (f) { return /battle_scene\.rb$/i.test(f.filename) || /scene[\\/]002_battle_scene\.rb/i.test(f.projectPath); });
                    _loop_1 = function (file) {
                        var text, _b_1, clean, c, _p, _q, name, m, _r, _s, name, m, vals, methodExpr;
                        var e_2, _t, e_3, _u;
                        return __generator(this, function (_v) {
                            switch (_v.label) {
                                case 0:
                                    text = "";
                                    _v.label = 1;
                                case 1:
                                    _v.trys.push([1, 3, , 4]);
                                    return [4 /*yield*/, ctx.fs.readProjectFile(file.projectPath)];
                                case 2:
                                    text = _v.sent();
                                    return [3 /*break*/, 4];
                                case 3:
                                    _b_1 = _v.sent();
                                    return [2 /*return*/, "continue"];
                                case 4:
                                    clean = text.split(/\r?\n/).map(stripRubyComment).join("\n");
                                    c = {};
                                    try {
                                        for (_p = (e_2 = void 0, __values(["PLAYER_BASE_X", "FOCUSUSER_X", "FOCUSUSER_Y", "FOCUSTARGET_X", "FOCUSTARGET_Y"])), _q = _p.next(); !_q.done; _q = _p.next()) {
                                            name = _q.value;
                                            m = clean.match(new RegExp("\\b".concat(name, "\\s*=\\s*([^\\n;]+)")));
                                            if (m)
                                                c[name] = evalDimExpr(m[1], width, height);
                                        }
                                    }
                                    catch (e_2_1) {
                                        e_2 = { error: e_2_1 };
                                    }
                                    finally {
                                        try {
                                            if (_q && !_q.done && (_t = _p.return))
                                                _t.call(_p);
                                        }
                                        finally {
                                            if (e_2)
                                                throw e_2.error;
                                        }
                                    }
                                    try {
                                        for (_r = (e_3 = void 0, __values(["BATTLER_OFFSET_2_X", "BATTLER_OFFSET_2_Y", "BATTLER_OFFSET_3_X", "BATTLER_OFFSET_3_Y"])), _s = _r.next(); !_s.done; _s = _r.next()) {
                                            name = _s.value;
                                            m = clean.match(new RegExp("\\b".concat(name, "\\s*=\\s*\\[([^\\]]+)\\]")));
                                            if (m) {
                                                vals = m[1].split(",").map(function (v) { return Number(String(v).trim()); }).filter(Number.isFinite);
                                                if (vals.length)
                                                    c[name] = vals;
                                            }
                                        }
                                    }
                                    catch (e_3_1) {
                                        e_3 = { error: e_3_1 };
                                    }
                                    finally {
                                        try {
                                            if (_s && !_s.done && (_u = _r.return))
                                                _u.call(_r);
                                        }
                                        finally {
                                            if (e_3)
                                                throw e_3.error;
                                        }
                                    }
                                    methodExpr = function (name) {
                                        var m = clean.match(new RegExp("def\\s+self\\.".concat(name, "\\s*;\\s*([^;]+);\\s*end")));
                                        if (m)
                                            return evalDimExpr(m[1], width, height);
                                        var m2 = clean.match(new RegExp("def\\s+self\\.".concat(name, "[^\\n]*\\n([\\s\\S]{0,200}?)\\n\\s*end")));
                                        if (m2) {
                                            var ret = m2[1].match(/(?:return\s+)?([^\n#]+)/);
                                            if (ret)
                                                return evalDimExpr(ret[1], width, height);
                                        }
                                        return null;
                                    };
                                    c.PLAYER_BASE_Y = methodExpr("PLAYER_BASE_Y");
                                    c.FOE_BASE_X = methodExpr("FOE_BASE_X");
                                    c.FOE_BASE_Y = methodExpr("FOE_BASE_Y");
                                    if (Number.isFinite(c.PLAYER_BASE_X) && Number.isFinite(c.PLAYER_BASE_Y) && Number.isFinite(c.FOE_BASE_X) && Number.isFinite(c.FOE_BASE_Y))
                                        return [2 /*return*/, { value: Object.assign(Object.assign({}, c), { path: file.projectPath }) }];
                                    return [2 /*return*/];
                            }
                        });
                    };
                    _o.label = 5;
                case 5:
                    _o.trys.push([5, 10, 11, 12]);
                    likely_1 = __values(likely), likely_1_1 = likely_1.next();
                    _o.label = 6;
                case 6:
                    if (!!likely_1_1.done)
                        return [3 /*break*/, 9];
                    file = likely_1_1.value;
                    return [5 /*yield**/, _loop_1(file)];
                case 7:
                    state_1 = _o.sent();
                    if (typeof state_1 === "object")
                        return [2 /*return*/, state_1.value];
                    _o.label = 8;
                case 8:
                    likely_1_1 = likely_1.next();
                    return [3 /*break*/, 6];
                case 9: return [3 /*break*/, 12];
                case 10:
                    e_1_1 = _o.sent();
                    e_1 = { error: e_1_1 };
                    return [3 /*break*/, 12];
                case 11:
                    try {
                        if (likely_1_1 && !likely_1_1.done && (_m = likely_1.return))
                            _m.call(likely_1);
                    }
                    finally {
                        if (e_1)
                            throw e_1.error;
                    }
                    return [7 /*endfinally*/];
                case 12: return [2 /*return*/, null];
            }
        });
    });
}
function scanEbdxMetrics(ctx, width, height) {
    return __awaiter(this, void 0, void 0, function () {
        function section(name) {
            var m = text.match(new RegExp("^\\s*\\[" + name.replace(/[.*+?^${}()|[\\]\\]/g, "\\$&") + "\\]\\s*([\\s\\S]*?)(?=^\\s*\\[|\\s*$)", "mi"));
            return m ? m[1] : "";
        }
        function xyz(sec) {
            var body = section(sec);
            var m = body.match(/SINGLE[\s\S]*?XYZ\s*=\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)/i) || body.match(/XYZ\s*=\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)/i);
            if (!m)
                return null;
            return { x: Number(m[1]), y: Number(m[2]), z: Number(m[3]) };
        }
        var paths, text, foundPath, paths_1, paths_1_1, path, _a_2, e_4_1, u, t;
        var e_4, _m;
        return __generator(this, function (_o) {
            switch (_o.label) {
                case 0:
                    paths = ["PBS/EBDX/metrics.txt", "PBS/metrics.txt"];
                    text = "", foundPath = "";
                    _o.label = 1;
                case 1:
                    _o.trys.push([1, 10, 11, 12]);
                    paths_1 = __values(paths), paths_1_1 = paths_1.next();
                    _o.label = 2;
                case 2:
                    if (!!paths_1_1.done)
                        return [3 /*break*/, 9];
                    path = paths_1_1.value;
                    _o.label = 3;
                case 3:
                    _o.trys.push([3, 7, , 8]);
                    return [4 /*yield*/, ctx.fs.projectExists(path)];
                case 4:
                    if (!_o.sent())
                        return [3 /*break*/, 6];
                    return [4 /*yield*/, ctx.fs.readProjectFile(path)];
                case 5:
                    text = _o.sent();
                    foundPath = path;
                    return [3 /*break*/, 9];
                case 6: return [3 /*break*/, 8];
                case 7:
                    _a_2 = _o.sent();
                    return [3 /*break*/, 8];
                case 8:
                    paths_1_1 = paths_1.next();
                    return [3 /*break*/, 2];
                case 9: return [3 /*break*/, 12];
                case 10:
                    e_4_1 = _o.sent();
                    e_4 = { error: e_4_1 };
                    return [3 /*break*/, 12];
                case 11:
                    try {
                        if (paths_1_1 && !paths_1_1.done && (_m = paths_1.return))
                            _m.call(paths_1);
                    }
                    finally {
                        if (e_4)
                            throw e_4.error;
                    }
                    return [7 /*endfinally*/];
                case 12:
                    if (!text)
                        return [2 /*return*/, null];
                    u = xyz("BATTLERPOS-0"), t = xyz("BATTLERPOS-1");
                    if (!u || !t)
                        return [2 /*return*/, null];
                    return [2 /*return*/, { path: foundPath, user: u, target: t }];
            }
        });
    });
}
export function detectProjectBattleContext(ctx) {
    return __awaiter(this, void 0, void 0, function () {
        var _a, _b, _c, _d, _e, _f, _g, _h, candidates, add, j, _m, _o, _j_1, roots, roots_1, roots_1_1, root, files, _k_1, files_1, files_1_1, file, text, _l_1, clean, wm, hm, _p, _q, m, e_5_1, e_6_1, best, c, geom, ebdx;
        var e_6, _r, e_5, _s, e_7, _t;
        return __generator(this, function (_u) {
            switch (_u.label) {
                case 0:
                    candidates = [];
                    add = function (width, height, path, kind, source) {
                        if (source === void 0) {
                            source = "other";
                        }
                        width = Number(width);
                        height = Number(height);
                        if (!Number.isFinite(width) || !Number.isFinite(height) || width < 160 || height < 120)
                            return;
                        candidates.push({ width: width, height: height, path: path, kind: kind, source: source, score: scoreSettingsCandidate(path, kind, source) });
                    };
                    _u.label = 1;
                case 1:
                    _u.trys.push([1, 5, , 6]);
                    return [4 /*yield*/, ctx.fs.projectExists("mkxp.json")];
                case 2:
                    if (!_u.sent())
                        return [3 /*break*/, 4];
                    _o = (_m = JSON).parse;
                    return [4 /*yield*/, ctx.fs.readProjectFile("mkxp.json")];
                case 3:
                    j = _o.apply(_m, [_u.sent()]);
                    add((_b = (_a = j.defScreenW) !== null && _a !== void 0 ? _a : j.screenWidth) !== null && _b !== void 0 ? _b : j.width, (_d = (_c = j.defScreenH) !== null && _c !== void 0 ? _c : j.screenHeight) !== null && _d !== void 0 ? _d : j.height, "mkxp.json", "mkxp.json", "config");
                    _u.label = 4;
                case 4: return [3 /*break*/, 6];
                case 5:
                    _j_1 = _u.sent();
                    return [3 /*break*/, 6];
                case 6:
                    roots = [{ path: "Data/Scripts", source: "script" }, { path: "Scripts", source: "script" }, { path: "Plugins", source: "plugin" }];
                    _u.label = 7;
                case 7:
                    _u.trys.push([7, 24, 25, 26]);
                    roots_1 = __values(roots), roots_1_1 = roots_1.next();
                    _u.label = 8;
                case 8:
                    if (!!roots_1_1.done)
                        return [3 /*break*/, 23];
                    root = roots_1_1.value;
                    files = [];
                    _u.label = 9;
                case 9:
                    _u.trys.push([9, 11, , 12]);
                    return [4 /*yield*/, scanProjectFiles(ctx, root.path, ["rb"], 18)];
                case 10:
                    files = _u.sent();
                    return [3 /*break*/, 12];
                case 11:
                    _k_1 = _u.sent();
                    return [3 /*break*/, 12];
                case 12:
                    _u.trys.push([12, 20, 21, 22]);
                    files_1 = (e_5 = void 0, __values(files)), files_1_1 = files_1.next();
                    _u.label = 13;
                case 13:
                    if (!!files_1_1.done)
                        return [3 /*break*/, 19];
                    file = files_1_1.value;
                    text = "";
                    _u.label = 14;
                case 14:
                    _u.trys.push([14, 16, , 17]);
                    return [4 /*yield*/, ctx.fs.readProjectFile(file.projectPath)];
                case 15:
                    text = _u.sent();
                    return [3 /*break*/, 17];
                case 16:
                    _l_1 = _u.sent();
                    return [3 /*break*/, 18];
                case 17:
                    clean = text.split(/\r?\n/).map(stripRubyComment).join("\n");
                    wm = __spreadArray([], __read(clean.matchAll(/(?:Settings::)?SCREEN_WIDTH\s*=\s*(\d+)/g)), false);
                    hm = __spreadArray([], __read(clean.matchAll(/(?:Settings::)?SCREEN_HEIGHT\s*=\s*(\d+)/g)), false);
                    if (wm.length && hm.length)
                        add(wm.at(-1)[1], hm.at(-1)[1], file.projectPath, "Settings", root.source);
                    try {
                        for (_p = (e_7 = void 0, __values(clean.matchAll(/Graphics\.resize_screen\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)/g))), _q = _p.next(); !_q.done; _q = _p.next()) {
                            m = _q.value;
                            add(m[1], m[2], file.projectPath, "resize_screen", root.source);
                        }
                    }
                    catch (e_7_1) {
                        e_7 = { error: e_7_1 };
                    }
                    finally {
                        try {
                            if (_q && !_q.done && (_t = _p.return))
                                _t.call(_p);
                        }
                        finally {
                            if (e_7)
                                throw e_7.error;
                        }
                    }
                    _u.label = 18;
                case 18:
                    files_1_1 = files_1.next();
                    return [3 /*break*/, 13];
                case 19: return [3 /*break*/, 22];
                case 20:
                    e_5_1 = _u.sent();
                    e_5 = { error: e_5_1 };
                    return [3 /*break*/, 22];
                case 21:
                    try {
                        if (files_1_1 && !files_1_1.done && (_s = files_1.return))
                            _s.call(files_1);
                    }
                    finally {
                        if (e_5)
                            throw e_5.error;
                    }
                    return [7 /*endfinally*/];
                case 22:
                    roots_1_1 = roots_1.next();
                    return [3 /*break*/, 8];
                case 23: return [3 /*break*/, 26];
                case 24:
                    e_6_1 = _u.sent();
                    e_6 = { error: e_6_1 };
                    return [3 /*break*/, 26];
                case 25:
                    try {
                        if (roots_1_1 && !roots_1_1.done && (_r = roots_1.return))
                            _r.call(roots_1);
                    }
                    finally {
                        if (e_6)
                            throw e_6.error;
                    }
                    return [7 /*endfinally*/];
                case 26:
                    if (!candidates.length)
                        return [2 /*return*/, null];
                    // Highest load priority first. Equal-priority candidates prefer the largest explicit canvas.
                    candidates.sort(function (a, b) { return b.score - a.score || (b.width * b.height) - (a.width * a.height); });
                    best = candidates[0];
                    c = fallbackBattleContext(best.width, best.height, "project");
                    c.captureKind = "".concat(best.kind, " \u00B7 ").concat(basename(best.path));
                    c.projectPath = best.path;
                    c.detectedCandidates = candidates.slice(0, 20);
                    return [4 /*yield*/, scanBattleSceneGeometry(ctx, best.width, best.height)];
                case 27:
                    geom = _u.sent();
                    if (geom) {
                        c.scriptGeometryPath = geom.path;
                        c.scriptUser = { x: geom.PLAYER_BASE_X, y: geom.PLAYER_BASE_Y };
                        c.scriptTarget = { x: geom.FOE_BASE_X, y: geom.FOE_BASE_Y };
                        c.user.x = c.scriptUser.x;
                        c.user.y = c.scriptUser.y;
                        c.user.focusX = c.scriptUser.x;
                        c.user.focusY = c.scriptUser.y - 40;
                        c.target.x = c.scriptTarget.x;
                        c.target.y = c.scriptTarget.y;
                        c.target.focusX = c.scriptTarget.x;
                        c.target.focusY = c.scriptTarget.y - 40;
                        // Legacy focus constants are kept for RXDATA conversion; actual sprite focus is refined once a battler image/runtime capture exists.
                        c.legacyFocus = {
                            userX: (_e = geom.FOCUSUSER_X) !== null && _e !== void 0 ? _e : 128, userY: (_f = geom.FOCUSUSER_Y) !== null && _f !== void 0 ? _f : 224,
                            targetX: (_g = geom.FOCUSTARGET_X) !== null && _g !== void 0 ? _g : 384, targetY: (_h = geom.FOCUSTARGET_Y) !== null && _h !== void 0 ? _h : 96
                        };
                        c.battlerOffsets = {
                            twoX: Array.isArray(geom.BATTLER_OFFSET_2_X) ? geom.BATTLER_OFFSET_2_X : [-48, 48, 32, -32],
                            twoY: Array.isArray(geom.BATTLER_OFFSET_2_Y) ? geom.BATTLER_OFFSET_2_Y : [0, 0, 16, -16],
                            threeX: Array.isArray(geom.BATTLER_OFFSET_3_X) ? geom.BATTLER_OFFSET_3_X : [-80, 80, 0, 0, 80, -80],
                            threeY: Array.isArray(geom.BATTLER_OFFSET_3_Y) ? geom.BATTLER_OFFSET_3_Y : [0, 0, 8, -8, 16, -16]
                        };
                    }
                    return [4 /*yield*/, scanEbdxMetrics(ctx, best.width, best.height)];
                case 28:
                    ebdx = _u.sent();
                    if (ebdx) {
                        // Keep EBDX positions available for EBDX-specific import diagnostics, but
                        // do not replace Battle::Scene.pbBattlerPosition in the normal preview.
                        // The actual Essentials battler sprite starts at pbBattlerPosition and then
                        // applies pokemon_metrics (BackSprite/FrontSprite/FrontSpriteAltitude).
                        c.ebdxMetricsPath = ebdx.path;
                        c.ebdxPositions = { user: ebdx.user, target: ebdx.target };
                    }
                    return [2 /*return*/, c];
            }
        });
    });
}
function parseMovesText(text, map, orderRef) {
    var e_8, _m;
    var id = null, name = null, target = null;
    var flush = function () {
        var _a;
        if (!id)
            return;
        var old = map.get(id);
        map.set(id, { id: id, name: name || (old === null || old === void 0 ? void 0 : old.name) || id, target: target || (old === null || old === void 0 ? void 0 : old.target) || null, order: (_a = old === null || old === void 0 ? void 0 : old.order) !== null && _a !== void 0 ? _a : orderRef.value++ });
    };
    try {
        for (var _o = __values(String(text || "").split(/\r?\n/)), _p = _o.next(); !_p.done; _p = _o.next()) {
            var raw = _p.value;
            var line = stripRubyComment(raw).trim();
            if (!line)
                continue;
            var sec = line.match(/^\[\s*([^\]]+)\s*\]$/);
            if (sec) {
                flush();
                id = sec[1].trim().toUpperCase();
                name = null;
                target = null;
                continue;
            }
            if (id) {
                var m = line.match(/^Name\s*=\s*(.+)$/i);
                if (m)
                    name = m[1].trim();
                var tm = line.match(/^Target\s*=\s*(.+)$/i);
                if (tm)
                    target = tm[1].trim();
            }
        }
    }
    catch (e_8_1) {
        e_8 = { error: e_8_1 };
    }
    finally {
        try {
            if (_p && !_p.done && (_m = _o.return))
                _m.call(_o);
        }
        finally {
            if (e_8)
                throw e_8.error;
        }
    }
    flush();
}
export function loadProjectMoveCatalog(ctx) {
    return __awaiter(this, void 0, void 0, function () {
        var _a, _b, _c, map, orderRef, paths, _d_1, files, files_2, files_2_1, f, _e_1, paths_2, paths_2_1, path, _m, _f_1, e_9_1, rows, rows_1, rows_1_1, r, id, old;
        var e_10, _o, e_9, _p, e_11, _q;
        return __generator(this, function (_r) {
            switch (_r.label) {
                case 0:
                    map = new Map(), orderRef = { value: 0 }, paths = [];
                    _r.label = 1;
                case 1:
                    _r.trys.push([1, 3, , 4]);
                    return [4 /*yield*/, ctx.fs.projectExists("PBS/moves.txt")];
                case 2:
                    if (_r.sent())
                        paths.push("PBS/moves.txt");
                    return [3 /*break*/, 4];
                case 3:
                    _d_1 = _r.sent();
                    return [3 /*break*/, 4];
                case 4:
                    _r.trys.push([4, 6, , 7]);
                    return [4 /*yield*/, scanProjectFiles(ctx, "Plugins", ["txt"], 16)];
                case 5:
                    files = _r.sent();
                    try {
                        for (files_2 = __values(files), files_2_1 = files_2.next(); !files_2_1.done; files_2_1 = files_2.next()) {
                            f = files_2_1.value;
                            if (/^moves\.txt$/i.test(f.filename))
                                paths.push(f.projectPath);
                        }
                    }
                    catch (e_10_1) {
                        e_10 = { error: e_10_1 };
                    }
                    finally {
                        try {
                            if (files_2_1 && !files_2_1.done && (_o = files_2.return))
                                _o.call(files_2);
                        }
                        finally {
                            if (e_10)
                                throw e_10.error;
                        }
                    }
                    return [3 /*break*/, 7];
                case 6:
                    _e_1 = _r.sent();
                    return [3 /*break*/, 7];
                case 7:
                    _r.trys.push([7, 14, 15, 16]);
                    paths_2 = __values(paths), paths_2_1 = paths_2.next();
                    _r.label = 8;
                case 8:
                    if (!!paths_2_1.done)
                        return [3 /*break*/, 13];
                    path = paths_2_1.value;
                    _r.label = 9;
                case 9:
                    _r.trys.push([9, 11, , 12]);
                    _m = parseMovesText;
                    return [4 /*yield*/, ctx.fs.readProjectFile(path)];
                case 10:
                    _m.apply(void 0, [_r.sent(), map, orderRef]);
                    return [3 /*break*/, 12];
                case 11:
                    _f_1 = _r.sent();
                    return [3 /*break*/, 12];
                case 12:
                    paths_2_1 = paths_2.next();
                    return [3 /*break*/, 8];
                case 13: return [3 /*break*/, 16];
                case 14:
                    e_9_1 = _r.sent();
                    e_9 = { error: e_9_1 };
                    return [3 /*break*/, 16];
                case 15:
                    try {
                        if (paths_2_1 && !paths_2_1.done && (_p = paths_2.return))
                            _p.call(paths_2);
                    }
                    finally {
                        if (e_9)
                            throw e_9.error;
                    }
                    return [7 /*endfinally*/];
                case 16:
                    try {
                        rows = ((_b = (_a = ctx.projectData).moves) === null || _b === void 0 ? void 0 : _b.call(_a)) || [];
                        try {
                            for (rows_1 = __values(rows), rows_1_1 = rows_1.next(); !rows_1_1.done; rows_1_1 = rows_1.next()) {
                                r = rows_1_1.value;
                                id = String((r === null || r === void 0 ? void 0 : r.id) || (r === null || r === void 0 ? void 0 : r.internal_name) || (r === null || r === void 0 ? void 0 : r.key) || "").toUpperCase();
                                if (!id)
                                    continue;
                                old = map.get(id);
                                map.set(id, { id: id, name: (r === null || r === void 0 ? void 0 : r.name) || (old === null || old === void 0 ? void 0 : old.name) || id, order: (_c = old === null || old === void 0 ? void 0 : old.order) !== null && _c !== void 0 ? _c : orderRef.value++ });
                            }
                        }
                        catch (e_11_1) {
                            e_11 = { error: e_11_1 };
                        }
                        finally {
                            try {
                                if (rows_1_1 && !rows_1_1.done && (_q = rows_1.return))
                                    _q.call(rows_1);
                            }
                            finally {
                                if (e_11)
                                    throw e_11.error;
                            }
                        }
                    }
                    catch (_g) { }
                    return [2 /*return*/, map];
            }
        });
    });
}
// -----------------------------------------------------------------------------
// Battler rendering compatibility (Essentials metrics + DBK animated battlers)
// -----------------------------------------------------------------------------
var _battlerCompatCache = null;
// Battle Animation Studio preview scale. The Studio reads the raw battler PNG,
// while DBK bakes its renderer scale into DeluxeBitmapWrapper. Mirror the same
// presentation used by the actual game renderer. DBK/DeluxeBitmapWrapper bakes
// the project scale into the battler bitmap (default Back x3 / Front x2); native/Gen 4 = x1/x1.
var BAS_DBK_EDITOR_BACK_SCALE = 3.0;
var BAS_DBK_EDITOR_FRONT_SCALE = 2.0;
var BAS_NATIVE_EDITOR_BACK_SCALE = 1.0;
var BAS_NATIVE_EDITOR_FRONT_SCALE = 1.0;
function parseMetricsFiles(text, out) {
    var e_12, _m;
    var id = null;
    var flushLine = function (line) {
        if (!id)
            return;
        var m = String(line || "").match(/^([^=]+?)\s*=\s*(.*)$/);
        if (!m)
            return;
        var key = m[1].trim().toLowerCase();
        var vals = m[2].split(",").map(function (x) { return x.trim(); }).filter(Boolean).map(Number);
        var rec = out.get(id) || { id: id, back: [0, 0, null], front: [0, 0, null], altitude: 0, speed: [2, 2] };
        if (key === "backsprite" && vals.length >= 2)
            rec.back = [vals[0] || 0, vals[1] || 0, Number.isFinite(vals[2]) ? vals[2] : null];
        else if (key === "frontsprite" && vals.length >= 2)
            rec.front = [vals[0] || 0, vals[1] || 0, Number.isFinite(vals[2]) ? vals[2] : null];
        else if (key === "frontspritealtitude" && vals.length)
            rec.altitude = vals[0] || 0;
        else if (key === "animationspeed" && vals.length)
            rec.speed = [vals[0] || 2, vals[1] || vals[0] || 2];
        out.set(id, rec);
    };
    try {
        for (var _o = __values(String(text || "").split(/\r?\n/)), _p = _o.next(); !_p.done; _p = _o.next()) {
            var raw = _p.value;
            var line = stripRubyComment(raw).trim();
            if (!line)
                continue;
            var sec = line.match(/^\[\s*([^\]]+)\s*\]$/);
            if (sec) {
                id = sec[1].trim().toUpperCase();
                continue;
            }
            flushLine(line);
        }
    }
    catch (e_12_1) {
        e_12 = { error: e_12_1 };
    }
    finally {
        try {
            if (_p && !_p.done && (_m = _o.return))
                _m.call(_o);
        }
        finally {
            if (e_12)
                throw e_12.error;
        }
    }
}
function loadBattlerCompatDatabase(ctx) {
    return __awaiter(this, void 0, void 0, function () {
        var metrics, dbk, backScale, frontScale, frameDelay, files, _m, _o, file, _p, _a_3, e_13_1, _b_2, files, files_3, files_3_1, file, pathLower, nameLower, pathLooksDbk, likelyScaleFile, text, _c_1, m, e_14_1, _d_2;
        var e_13, _q, e_14, _r;
        return __generator(this, function (_s) {
            switch (_s.label) {
                case 0:
                    if (_battlerCompatCache)
                        return [2 /*return*/, _battlerCompatCache];
                    metrics = new Map();
                    dbk = false, backScale = 1, frontScale = 1, frameDelay = 60;
                    _s.label = 1;
                case 1:
                    _s.trys.push([1, 13, , 14]);
                    return [4 /*yield*/, scanProjectFiles(ctx, "PBS", ["txt"], 5)];
                case 2:
                    files = _s.sent();
                    _s.label = 3;
                case 3:
                    _s.trys.push([3, 10, 11, 12]);
                    _m = __values(files.filter(function (f) { return /^pokemon_metrics.*\.txt$/i.test(f.filename); })), _o = _m.next();
                    _s.label = 4;
                case 4:
                    if (!!_o.done)
                        return [3 /*break*/, 9];
                    file = _o.value;
                    _s.label = 5;
                case 5:
                    _s.trys.push([5, 7, , 8]);
                    _p = parseMetricsFiles;
                    return [4 /*yield*/, ctx.fs.readProjectFile(file.projectPath)];
                case 6:
                    _p.apply(void 0, [_s.sent(), metrics]);
                    return [3 /*break*/, 8];
                case 7:
                    _a_3 = _s.sent();
                    return [3 /*break*/, 8];
                case 8:
                    _o = _m.next();
                    return [3 /*break*/, 4];
                case 9: return [3 /*break*/, 12];
                case 10:
                    e_13_1 = _s.sent();
                    e_13 = { error: e_13_1 };
                    return [3 /*break*/, 12];
                case 11:
                    try {
                        if (_o && !_o.done && (_q = _m.return))
                            _q.call(_m);
                    }
                    finally {
                        if (e_13)
                            throw e_13.error;
                    }
                    return [7 /*endfinally*/];
                case 12: return [3 /*break*/, 14];
                case 13:
                    _b_2 = _s.sent();
                    return [3 /*break*/, 14];
                case 14:
                    _s.trys.push([14, 27, , 28]);
                    return [4 /*yield*/, scanProjectFiles(ctx, "Plugins", ["rb"], 18)];
                case 15:
                    files = _s.sent();
                    _s.label = 16;
                case 16:
                    _s.trys.push([16, 24, 25, 26]);
                    files_3 = __values(files), files_3_1 = files_3.next();
                    _s.label = 17;
                case 17:
                    if (!!files_3_1.done)
                        return [3 /*break*/, 23];
                    file = files_3_1.value;
                    pathLower = lower(file.projectPath);
                    nameLower = lower(file.filename);
                    pathLooksDbk = pathLower.includes("sprites animados dbk") || pathLower.includes("animated pokemon") || pathLower.includes("deluxe bitmap") || pathLower.includes("deluxe battle kit") || /(^|\W)dbk(\W|$)/i.test(file.projectPath);
                    if (pathLooksDbk)
                        dbk = true;
                    likelyScaleFile = pathLooksDbk || /settings|game data|sprite|bitmap|battler|pokemon/i.test(nameLower);
                    if (!likelyScaleFile)
                        return [3 /*break*/, 22];
                    text = "";
                    _s.label = 18;
                case 18:
                    _s.trys.push([18, 20, , 21]);
                    return [4 /*yield*/, ctx.fs.readProjectFile(file.projectPath)];
                case 19:
                    text = _s.sent();
                    return [3 /*break*/, 21];
                case 20:
                    _c_1 = _s.sent();
                    return [3 /*break*/, 22];
                case 21:
                    m = text.match(/(?:BACK_BATTLER_SPRITE_SCALE|BACK_SPRITE_SCALE)\s*=\s*(\d+(?:\.\d+)?)/);
                    if (m) {
                        backScale = Number(m[1]);
                        dbk = true;
                    }
                    m = text.match(/(?:FRONT_BATTLER_SPRITE_SCALE|FRONT_SPRITE_SCALE)\s*=\s*(\d+(?:\.\d+)?)/);
                    if (m) {
                        frontScale = Number(m[1]);
                        dbk = true;
                    }
                    m = text.match(/ANIMATION_FRAME_DELAY\s*=\s*(\d+(?:\.\d+)?)/);
                    if (m)
                        frameDelay = Number(m[1]);
                    _s.label = 22;
                case 22:
                    files_3_1 = files_3.next();
                    return [3 /*break*/, 17];
                case 23: return [3 /*break*/, 26];
                case 24:
                    e_14_1 = _s.sent();
                    e_14 = { error: e_14_1 };
                    return [3 /*break*/, 26];
                case 25:
                    try {
                        if (files_3_1 && !files_3_1.done && (_r = files_3.return))
                            _r.call(files_3);
                    }
                    finally {
                        if (e_14)
                            throw e_14.error;
                    }
                    return [7 /*endfinally*/];
                case 26: return [3 /*break*/, 28];
                case 27:
                    _d_2 = _s.sent();
                    return [3 /*break*/, 28];
                case 28:
                    _battlerCompatCache = { metrics: metrics, dbk: dbk, backScale: backScale, frontScale: frontScale, frameDelay: frameDelay };
                    return [2 /*return*/, _battlerCompatCache];
            }
        });
    });
}
function candidateSpeciesIds(config) {
    if (config === void 0) {
        config = {};
    }
    var raw = String(config.name || config.projectPath || "").replace(/\\/g, "/").split("/").pop().replace(/\.[^.]+$/, "").toUpperCase();
    if (!raw)
        return [];
    var ret = [raw];
    // Match Essentials' pokemon_metrics section IDs, including forms and female
    // variants. Sprite filenames use SPECIES_1_female while PBS uses
    // [SPECIES,1,female] (or [SPECIES,,female]). Prefer those exact records
    // before falling back to the base species metrics.
    var stem = raw.replace(/_SHADOW$/i, "");
    var female = /_FEMALE$/i.test(stem);
    if (female)
        stem = stem.replace(/_FEMALE$/i, "");
    var fm = stem.match(/^(.*)_(\d+)$/);
    var species = (fm ? fm[1] : stem).replace(/[_-]+$/, "");
    var form = fm ? Number(fm[2]) : 0;
    if (species) {
        if (female)
            ret.push("".concat(species, ",").concat(form > 0 ? form : "", ",FEMALE"));
        if (form > 0)
            ret.push("".concat(species, ",").concat(form));
        if (female)
            ret.push("".concat(species, ",,FEMALE"));
        ret.push(species);
    }
    return __spreadArray([], __read(new Set(ret.filter(Boolean))), false);
}
export function loadBattlerRenderingInfo(ctx_1) {
    return __awaiter(this, arguments, void 0, function (ctx, config, side) {
        var _a, _b, _c, db, projectPath, lowerPath, isPokemonSprite, isAnimTestSprite, speciesCandidates, rec, speciesId, speciesCandidates_1, speciesCandidates_1_1, id, back, metric, metricScale, usesBattleScale, dbkEditorScale, nativeEditorScale, rendererDefaultScale, rendererMetricScale, scale, finalScale, speed;
        var e_15, _m;
        if (config === void 0) {
            config = {};
        }
        if (side === void 0) {
            side = "user";
        }
        return __generator(this, function (_o) {
            switch (_o.label) {
                case 0: return [4 /*yield*/, loadBattlerCompatDatabase(ctx)];
                case 1:
                    db = _o.sent();
                    projectPath = String((config && config.projectPath) || "").replace(/\\/g, "/");
                    lowerPath = lower(projectPath);
                    isPokemonSprite = /graphics\/(?:pokemon\/(back|front)|ebdx\/battlers\/(back|front))\//.test(lowerPath);
                    isAnimTestSprite = /graphics\/ui\/anim(?:back|front)test(?:\.[a-z0-9]+)?$/i.test(lowerPath);
                    speciesCandidates = candidateSpeciesIds(config);
                    rec = null, speciesId = speciesCandidates[0] || "";
                    try {
                        for (speciesCandidates_1 = __values(speciesCandidates), speciesCandidates_1_1 = speciesCandidates_1.next(); !speciesCandidates_1_1.done; speciesCandidates_1_1 = speciesCandidates_1.next()) {
                            id = speciesCandidates_1_1.value;
                            if (db.metrics.has(id)) {
                                rec = db.metrics.get(id);
                                speciesId = id;
                                break;
                            }
                        }
                    }
                    catch (e_15_1) {
                        e_15 = { error: e_15_1 };
                    }
                    finally {
                        try {
                            if (speciesCandidates_1_1 && !speciesCandidates_1_1.done && (_m = speciesCandidates_1.return))
                                _m.call(speciesCandidates_1);
                        }
                        finally {
                            if (e_15)
                                throw e_15.error;
                        }
                    }
                    back = side === "user";
                    metric = back ? ((rec && rec.back) || [0, 0, null]) : ((rec && rec.front) || [0, 0, null]);
                    metricScale = Number(metric && metric[2]);
                    usesBattleScale = isPokemonSprite || isAnimTestSprite;
                    dbkEditorScale = back ? BAS_DBK_EDITOR_BACK_SCALE : BAS_DBK_EDITOR_FRONT_SCALE;
                    nativeEditorScale = back ? BAS_NATIVE_EDITOR_BACK_SCALE : BAS_NATIVE_EDITOR_FRONT_SCALE;
                    rendererDefaultScale = Math.max(.01, Number(back ? db.backScale : db.frontScale) || (back ? 3 : 2));
                    rendererMetricScale = isPokemonSprite && Number.isFinite(metricScale) && metricScale > 0
                        ? metricScale
                        : rendererDefaultScale;
                    // Match the renderer selected by the project. DBK scales the source
                    // bitmap itself (default Back x3 / Front x2, or the third PBS metric).
                    // Gen 4/native remains x1 and is also available as an explicit UI preset.
                    scale = db.dbk && usesBattleScale
                        ? rendererMetricScale
                        : (isAnimTestSprite
                            ? nativeEditorScale
                            : (isPokemonSprite && Number.isFinite(metricScale) && metricScale > 0 ? metricScale : (isPokemonSprite ? nativeEditorScale : 1)));
                    finalScale = scale;
                    speed = Number((_c = (back ? (_a = rec && rec.speed) === null || _a === void 0 ? void 0 : _a[0] : (_b = rec && rec.speed) === null || _b === void 0 ? void 0 : _b[1])) !== null && _c !== void 0 ? _c : 2) || 2;
                    return [2 /*return*/, {
                            dbk: !!db.dbk && usesBattleScale,
                            dbkInstalled: !!db.dbk,
                            view: back ? "back" : "front",
                            // Editor-facing scales mirror the actual game renderer:
                            // DBK uses the detected project defaults; native/Gen 4 is x1/x1.
                            dbkBackScale: db.dbk ? Number(db.backScale || BAS_DBK_EDITOR_BACK_SCALE) : BAS_NATIVE_EDITOR_BACK_SCALE,
                            dbkFrontScale: db.dbk ? Number(db.frontScale || BAS_DBK_EDITOR_FRONT_SCALE) : BAS_NATIVE_EDITOR_FRONT_SCALE,
                            rendererBackScale: back && Number.isFinite(metricScale) && metricScale > 0 ? metricScale : Number(db.backScale || 1),
                            rendererFrontScale: !back && Number.isFinite(metricScale) && metricScale > 0 ? metricScale : Number(db.frontScale || 1),
                            rendererDefaultBackScale: Number(db.backScale || 1),
                            rendererDefaultFrontScale: Number(db.frontScale || 1),
                            editorViewScale: Math.max(0.05, finalScale || 1),
                            speciesId: speciesId,
                            projectPath: projectPath,
                            metricX: isPokemonSprite ? Number((metric && metric[0]) || 0) * 2 : 0,
                            metricY: isPokemonSprite ? (Number((metric && metric[1]) || 0) * 2 - (!back ? Number((rec && rec.altitude) || 0) * 2 : 0)) : 0,
                            scale: Math.max(0.05, finalScale || 1),
                            animationSpeed: speed,
                            frameDelayMs: Math.max(16, ((speed / 2) * Number(db.frameDelay || 60))),
                            source: rec ? "pokemon_metrics" : (isAnimTestSprite ? "anim-test" : (isPokemonSprite && db.dbk ? "dbk-default" : "editor-default"))
                        }];
            }
        });
    });
}
export function clearBattlerRenderingCache() { _battlerCompatCache = null; }
