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
var IMAGE_EXTS = new Set(["png", "bmp", "jpg", "jpeg", "webp", "gif"]);
export var ANIMATION_ASSET_ROOTS = [
    { id: "studio", label: "Battle Animation Studio", projectPath: "Graphics/AnimationStudio" },
    { id: "legacy", label: "In-game Animation Editor / Vanilla", projectPath: "Graphics/Animations" },
    { id: "new", label: "New Animation Editor", projectPath: "Graphics/Battle animations" },
    { id: "ebdx_moves", label: "Elite Battle DX · Moves", projectPath: "Graphics/EBDX/Animations/Moves" },
    { id: "ebdx_common", label: "Elite Battle DX · Common", projectPath: "Graphics/EBDX/Animations/Common" },
    { id: "battle", label: "Battle graphics", projectPath: "Graphics/Battle" },
    { id: "code", label: "BattleAnimations / Code", projectPath: "Graphics/BattleParticlesAnimations" }
];
function norm(path) { return String(path || "").replace(/\\/g, "/").replace(/\/{2,}/g, "/").replace(/\/$/, ""); }
function join() {
    var parts = [];
    for (var _i = 0; _i < arguments.length; _i++) {
        parts[_i] = arguments[_i];
    }
    return norm(parts.filter(Boolean).join("/"));
}
function extOf(name) { var m = String(name == null ? "" : name).match(/\.([^.]+)$/); return (m && typeof m[1] === "string") ? String(m[1]).toLowerCase() : ""; }
function stemOf(name) { return String(name || "").replace(/\.[^.]+$/, ""); }
function mimeFor(path) {
    var ext = extOf(path);
    if (ext === "jpg" || ext === "jpeg")
        return "image/jpeg";
    if (ext === "bmp")
        return "image/bmp";
    if (ext === "webp")
        return "image/webp";
    if (ext === "gif")
        return "image/gif";
    return "image/png";
}
export function absoluteProjectPath(ctx, projectPath) {
    var editor = ctx && ctx.editor ? ctx.editor : null;
    var rel = norm(projectPath);
    if (!editor || typeof editor.gameRoot !== "function" || !rel)
        return "";
    var root = norm(editor.gameRoot() || "");
    if (!root)
        return "";
    return join(root, rel);
}
function invoke(name, args) {
    return __awaiter(this, void 0, void 0, function () {
        var _a, _b, fn;
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    fn = (_b = (_a = window.__TAURI__) === null || _a === void 0 ? void 0 : _a.core) === null || _b === void 0 ? void 0 : _b.invoke;
                    if (!fn)
                        throw new Error("Tauri invoke is unavailable");
                    return [4 /*yield*/, fn(name, args)];
                case 1: return [2 /*return*/, _f.sent()];
            }
        });
    });
}
export function ensureAbsoluteDirectory(path) {
    return __awaiter(this, void 0, void 0, function () {
        var attempts, i, item;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    if (!path) return [2 /*return*/, false];
                    attempts = [
                        ["create_dir_all", { path: path }],
                        ["create_directory", { path: path, recursive: true }],
                        ["create_dir", { path: path, recursive: true }],
                        ["mkdir", { path: path, recursive: true }]
                    ];
                    i = 0;
                    _a.label = 1;
                case 1:
                    if (!(i < attempts.length)) return [3 /*break*/, 6];
                    item = attempts[i];
                    _a.label = 2;
                case 2:
                    _a.trys.push([2, 4, , 5]);
                    return [4 /*yield*/, invoke(item[0], item[1])];
                case 3:
                    _a.sent();
                    return [2 /*return*/, true];
                case 4:
                    _a.sent();
                    return [3 /*break*/, 5];
                case 5:
                    i++;
                    return [3 /*break*/, 1];
                case 6:
                    return [2 /*return*/, false];
            }
        });
    });
}
export function readAbsoluteText(path) {
    return __awaiter(this, void 0, void 0, function () {
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    if (!path)
                        throw new Error("Missing external file path");
                    return [4 /*yield*/, invoke("read_text_file", { path: path })];
                case 1: return [2 /*return*/, _f.sent()];
            }
        });
    });
}
export function writeAbsoluteText(path, text) {
    return __awaiter(this, void 0, void 0, function () {
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    if (!path) throw new Error("Missing external file path");
                    return [4 /*yield*/, invoke("write_text_file", { path: path, content: String(text == null ? "" : text) })];
                case 1: _a.sent(); return [2 /*return*/, true];
            }
        });
    });
}
export function writeAbsoluteBinary(path, bytes) {
    return __awaiter(this, void 0, void 0, function () {
        var arr;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    if (!path) throw new Error("Missing external file path");
                    arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || []);
                    return [4 /*yield*/, invoke("write_binary_file", { path: path, data: Array.from(arr) })];
                case 1: _a.sent(); return [2 /*return*/, true];
            }
        });
    });
}
export function readAbsoluteBinary(path) {
    return __awaiter(this, void 0, void 0, function () {
        var bytes;
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    if (!path)
                        throw new Error("Missing external file path");
                    return [4 /*yield*/, invoke("read_binary_file", { path: path })];
                case 1:
                    bytes = _f.sent();
                    return [2 /*return*/, bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes || [])];
            }
        });
    });
}
export function loadAbsoluteImageUrl(path) {
    return __awaiter(this, void 0, void 0, function () {
        var bytes, _a_1, arr;
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    if (!path)
                        return [2 /*return*/, null];
                    _f.label = 1;
                case 1:
                    _f.trys.push([1, 3, , 4]);
                    return [4 /*yield*/, invoke("read_binary_file", { path: path })];
                case 2:
                    bytes = _f.sent();
                    return [3 /*break*/, 4];
                case 3:
                    _a_1 = _f.sent();
                    return [2 /*return*/, null];
                case 4:
                    if (!bytes || !bytes.length)
                        return [2 /*return*/, null];
                    arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
                    return [2 /*return*/, URL.createObjectURL(new Blob([arr], { type: mimeFor(path) }))];
            }
        });
    });
}
function dirname(path) {
    var p = norm(path);
    var i = p.lastIndexOf("/");
    return i >= 0 ? p.slice(0, i) : "";
}
export function detectExternalGameRoot(filePath) {
    return __awaiter(this, void 0, void 0, function () {
        var dir, depth, hasGraphics, hasProjectMarker, _f, _g, _h, _j, parent;
        return __generator(this, function (_k) {
            switch (_k.label) {
                case 0:
                    dir = dirname(filePath);
                    depth = 0;
                    _k.label = 1;
                case 1:
                    if (!(depth < 12 && dir))
                        return [3 /*break*/, 13];
                    return [4 /*yield*/, existsAbsolute(join(dir, "Graphics"))];
                case 2:
                    hasGraphics = _k.sent();
                    return [4 /*yield*/, existsAbsolute(join(dir, "Game.rxproj"))];
                case 3:
                    _j = (_k.sent());
                    if (_j)
                        return [3 /*break*/, 5];
                    return [4 /*yield*/, existsAbsolute(join(dir, "Game.exe"))];
                case 4:
                    _j = (_k.sent());
                    _k.label = 5;
                case 5:
                    _h = _j;
                    if (_h)
                        return [3 /*break*/, 7];
                    return [4 /*yield*/, existsAbsolute(join(dir, "Data"))];
                case 6:
                    _h = (_k.sent());
                    _k.label = 7;
                case 7:
                    _g = _h;
                    if (_g)
                        return [3 /*break*/, 9];
                    return [4 /*yield*/, existsAbsolute(join(dir, "PBS"))];
                case 8:
                    _g = (_k.sent());
                    _k.label = 9;
                case 9:
                    _f = _g;
                    if (_f)
                        return [3 /*break*/, 11];
                    return [4 /*yield*/, existsAbsolute(join(dir, "Plugins"))];
                case 10:
                    _f = (_k.sent());
                    _k.label = 11;
                case 11:
                    hasProjectMarker = _f;
                    if (hasGraphics && hasProjectMarker)
                        return [2 /*return*/, dir];
                    parent = dirname(dir);
                    if (!parent || parent === dir)
                        return [3 /*break*/, 13];
                    dir = parent;
                    _k.label = 12;
                case 12:
                    depth++;
                    return [3 /*break*/, 1];
                case 13: return [2 /*return*/, ""];
            }
        });
    });
}
export function resolveExternalGraphicPath(gameRoot_1) {
    return __awaiter(this, arguments, void 0, function (gameRoot, graphic) {
        var exts, candidates, add, _f, _g, c, hint, name, folder, seen, candidates_1, candidates_1_1, rel, alreadyExt, _h, _j, ext, abs, e_1_1, e_2_1;
        var e_3, _k, e_2, _l, e_1, _m;
        if (graphic === void 0) {
            graphic = {};
        }
        return __generator(this, function (_o) {
            switch (_o.label) {
                case 0:
                    if (!gameRoot)
                        return [2 /*return*/, ""];
                    exts = ["", ".png", ".bmp", ".jpg", ".jpeg", ".webp", ".gif"];
                    candidates = [];
                    add = function (value) {
                        var v = String(value || "").trim().replace(/^\/+/, "").replace(/\\/g, "/");
                        if (!v)
                            return;
                        candidates.push(v);
                        var stripped = v.replace(/\[\s*bottom\s*\]\s*$/i, "").trim();
                        if (stripped && stripped !== v)
                            candidates.push(stripped);
                    };
                    try {
                        for (_f = __values(graphic.assetCandidates || []), _g = _f.next(); !_g.done; _g = _f.next()) {
                            c = _g.value;
                            add(c);
                        }
                    }
                    catch (e_3_1) {
                        e_3 = { error: e_3_1 };
                    }
                    finally {
                        try {
                            if (_g && !_g.done && (_k = _f.return))
                                _k.call(_f);
                        }
                        finally {
                            if (e_3)
                                throw e_3.error;
                        }
                    }
                    add(graphic.projectPath || graphic.externalRelativePath || "");
                    hint = String(graphic.relativeHint || "").replace(/^\/+/, "").replace(/\\/g, "/").trim();
                    name = String(graphic.name || "").trim();
                    folder = String(graphic.folder || "");
                    if (hint) {
                        if (/^Graphics\//i.test(hint))
                            add(hint);
                        add(join("Graphics/AnimationStudio", hint));
                        add(join("Graphics/Animations", hint));
                        add(join("Graphics/Battle animations", hint));
                        add(join("Graphics/EBDX/Animations/Moves", hint));
                        add(join("Graphics/EBDX/Animations/Common", hint));
                        add(join("Graphics/Battle", hint));
                        add(join("Graphics/BattleParticlesAnimations", hint));
                    }
                    if (name) {
                        if (folder)
                            add(join("Graphics", folder, name));
                        add(join("Graphics/AnimationStudio", name));
                        add(join("Graphics/Animations", name));
                        add(join("Graphics/Battle animations", name));
                        add(join("Graphics/EBDX/Animations/Moves", name));
                        add(join("Graphics/EBDX/Animations/Common", name));
                        add(join("Graphics/Battle", name));
                        add(join("Graphics/BattleParticlesAnimations", name));
                    }
                    seen = new Set();
                    _o.label = 1;
                case 1:
                    _o.trys.push([1, 12, 13, 14]);
                    candidates_1 = __values(candidates), candidates_1_1 = candidates_1.next();
                    _o.label = 2;
                case 2:
                    if (!!candidates_1_1.done)
                        return [3 /*break*/, 11];
                    rel = candidates_1_1.value;
                    if (!rel || seen.has(String(rel || "").toLowerCase()))
                        return [3 /*break*/, 10];
                    seen.add(String(rel || "").toLowerCase());
                    alreadyExt = !!extOf(rel);
                    _o.label = 3;
                case 3:
                    _o.trys.push([3, 8, 9, 10]);
                    _h = (e_1 = void 0, __values(alreadyExt ? [""] : exts)), _j = _h.next();
                    _o.label = 4;
                case 4:
                    if (!!_j.done)
                        return [3 /*break*/, 7];
                    ext = _j.value;
                    abs = join(gameRoot, rel + ext);
                    return [4 /*yield*/, existsAbsolute(abs)];
                case 5:
                    if (_o.sent())
                        return [2 /*return*/, abs];
                    _o.label = 6;
                case 6:
                    _j = _h.next();
                    return [3 /*break*/, 4];
                case 7: return [3 /*break*/, 10];
                case 8:
                    e_1_1 = _o.sent();
                    e_1 = { error: e_1_1 };
                    return [3 /*break*/, 10];
                case 9:
                    try {
                        if (_j && !_j.done && (_m = _h.return))
                            _m.call(_h);
                    }
                    finally {
                        if (e_1)
                            throw e_1.error;
                    }
                    return [7 /*endfinally*/];
                case 10:
                    candidates_1_1 = candidates_1.next();
                    return [3 /*break*/, 2];
                case 11: return [3 /*break*/, 14];
                case 12:
                    e_2_1 = _o.sent();
                    e_2 = { error: e_2_1 };
                    return [3 /*break*/, 14];
                case 13:
                    try {
                        if (candidates_1_1 && !candidates_1_1.done && (_l = candidates_1.return))
                            _l.call(candidates_1);
                    }
                    finally {
                        if (e_2)
                            throw e_2.error;
                    }
                    return [7 /*endfinally*/];
                case 14: return [2 /*return*/, ""];
            }
        });
    });
}
function listAbsolute(path) {
    return __awaiter(this, void 0, void 0, function () {
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0: return [4 /*yield*/, invoke("list_directory", { path: path })];
                case 1: return [2 /*return*/, _f.sent()];
            }
        });
    });
}
function existsAbsolute(path) {
    return __awaiter(this, void 0, void 0, function () {
        var _a_2;
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    _f.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, invoke("file_exists", { path: path })];
                case 1: return [2 /*return*/, !!(_f.sent())];
                case 2:
                    _a_2 = _f.sent();
                    return [2 /*return*/, false];
                case 3: return [2 /*return*/];
            }
        });
    });
}
function entryFlags(entry) {
    var _a, _b, _c, _d, _e;
    var isDir = !!((_c = (_b = (_a = entry === null || entry === void 0 ? void 0 : entry.isDir) !== null && _a !== void 0 ? _a : entry === null || entry === void 0 ? void 0 : entry.is_dir) !== null && _b !== void 0 ? _b : entry === null || entry === void 0 ? void 0 : entry.isDirectory) !== null && _c !== void 0 ? _c : entry === null || entry === void 0 ? void 0 : entry.is_directory);
    var isFile = !!((_e = (_d = entry === null || entry === void 0 ? void 0 : entry.isFile) !== null && _d !== void 0 ? _d : entry === null || entry === void 0 ? void 0 : entry.is_file) !== null && _e !== void 0 ? _e : (!isDir && (entry === null || entry === void 0 ? void 0 : entry.name)));
    return { isDir: isDir, isFile: isFile };
}
export function scanImageRoot(ctx_1, rootProjectPath_1) {
    return __awaiter(this, arguments, void 0, function (ctx, rootProjectPath, source, label, maxDepth) {
        function walk(absDir, relDir, depth) {
            return __awaiter(this, void 0, void 0, function () {
                var entries, _a_3, _f, _g, entry, name, flags, abs, rel, e_4_1;
                var e_4, _h;
                return __generator(this, function (_j) {
                    switch (_j.label) {
                        case 0:
                            if (depth > maxDepth)
                                return [2 /*return*/];
                            entries = [];
                            _j.label = 1;
                        case 1:
                            _j.trys.push([1, 3, , 4]);
                            return [4 /*yield*/, listAbsolute(absDir)];
                        case 2:
                            entries = _j.sent();
                            return [3 /*break*/, 4];
                        case 3:
                            _a_3 = _j.sent();
                            return [2 /*return*/];
                        case 4:
                            _j.trys.push([4, 10, 11, 12]);
                            _f = __values(entries || []), _g = _f.next();
                            _j.label = 5;
                        case 5:
                            if (!!_g.done)
                                return [3 /*break*/, 9];
                            entry = _g.value;
                            name = (entry === null || entry === void 0 ? void 0 : entry.name) || norm(entry === null || entry === void 0 ? void 0 : entry.path).split("/").pop();
                            if (!name)
                                return [3 /*break*/, 8];
                            flags = entryFlags(entry);
                            abs = norm((entry === null || entry === void 0 ? void 0 : entry.path) || join(absDir, name));
                            rel = join(relDir, name);
                            if (!flags.isDir)
                                return [3 /*break*/, 7];
                            return [4 /*yield*/, walk(abs, rel, depth + 1)];
                        case 6:
                            _j.sent();
                            return [3 /*break*/, 8];
                        case 7:
                            if (flags.isFile && IMAGE_EXTS.has(extOf(name))) {
                                out.push({
                                    source: source,
                                    sourceLabel: label,
                                    projectPath: join(rootProjectPath, rel),
                                    rootProjectPath: rootProjectPath,
                                    relativePath: rel,
                                    name: stemOf(name),
                                    filename: name,
                                    extension: extOf(name)
                                });
                            }
                            _j.label = 8;
                        case 8:
                            _g = _f.next();
                            return [3 /*break*/, 5];
                        case 9: return [3 /*break*/, 12];
                        case 10:
                            e_4_1 = _j.sent();
                            e_4 = { error: e_4_1 };
                            return [3 /*break*/, 12];
                        case 11:
                            try {
                                if (_g && !_g.done && (_h = _f.return))
                                    _h.call(_f);
                            }
                            finally {
                                if (e_4)
                                    throw e_4.error;
                            }
                            return [7 /*endfinally*/];
                        case 12: return [2 /*return*/];
                    }
                });
            });
        }
        var rootAbs, _f, out;
        if (source === void 0) {
            source = "custom";
        }
        if (label === void 0) {
            label = "Graphics";
        }
        if (maxDepth === void 0) {
            maxDepth = 12;
        }
        return __generator(this, function (_g) {
            switch (_g.label) {
                case 0:
                    rootAbs = absoluteProjectPath(ctx, rootProjectPath);
                    _f = !rootAbs;
                    if (_f)
                        return [3 /*break*/, 2];
                    return [4 /*yield*/, existsAbsolute(rootAbs)];
                case 1:
                    _f = !(_g.sent());
                    _g.label = 2;
                case 2:
                    if (_f)
                        return [2 /*return*/, []];
                    out = [];
                    return [4 /*yield*/, walk(rootAbs, "", 0)];
                case 3:
                    _g.sent();
                    out.sort(function (a, b) { return String((a && a.relativePath) || "").localeCompare(String((b && b.relativePath) || ""), undefined, { numeric: true, sensitivity: "base" }); });
                    return [2 /*return*/, out];
            }
        });
    });
}
export function scanAnimationAssets(ctx) {
    return __awaiter(this, void 0, void 0, function () {
        var groups;
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0: return [4 /*yield*/, Promise.all(ANIMATION_ASSET_ROOTS.map(function (root) { return scanImageRoot(ctx, root.projectPath, root.id, root.label); }))];
                case 1:
                    groups = _f.sent();
                    return [2 /*return*/, groups.flat()];
            }
        });
    });
}
export function scanBattlerAssets(ctx, side) {
    return __awaiter(this, void 0, void 0, function () {
        var roots, groups, roots_1, roots_1_1, root, _f, _g, _h, _j, e_5_1, seen, out, groups_1, groups_1_1, item, key;
        var e_5, _k, e_6, _l;
        return __generator(this, function (_m) {
            switch (_m.label) {
                case 0:
                    roots = side === "user"
                        ? ["Graphics/Pokemon/Back", "Graphics/EBDX/Battlers/Back"]
                        : ["Graphics/Pokemon/Front", "Graphics/EBDX/Battlers/Front"];
                    groups = [];
                    _m.label = 1;
                case 1:
                    _m.trys.push([1, 6, 7, 8]);
                    roots_1 = __values(roots), roots_1_1 = roots_1.next();
                    _m.label = 2;
                case 2:
                    if (!!roots_1_1.done)
                        return [3 /*break*/, 5];
                    root = roots_1_1.value;
                    _g = (_f = groups.push).apply;
                    _h = [groups];
                    _j = [[]];
                    return [4 /*yield*/, scanImageRoot(ctx, root, side === "user" ? "battler-user" : "battler-target", side === "user" ? "User battlers" : "Target battlers")];
                case 3:
                    _g.apply(_f, _h.concat([__spreadArray.apply(void 0, _j.concat([__read.apply(void 0, [_m.sent()]), false]))]));
                    _m.label = 4;
                case 4:
                    roots_1_1 = roots_1.next();
                    return [3 /*break*/, 2];
                case 5: return [3 /*break*/, 8];
                case 6:
                    e_5_1 = _m.sent();
                    e_5 = { error: e_5_1 };
                    return [3 /*break*/, 8];
                case 7:
                    try {
                        if (roots_1_1 && !roots_1_1.done && (_k = roots_1.return))
                            _k.call(roots_1);
                    }
                    finally {
                        if (e_5)
                            throw e_5.error;
                    }
                    return [7 /*endfinally*/];
                case 8:
                    seen = new Set(), out = [];
                    try {
                        for (groups_1 = __values(groups), groups_1_1 = groups_1.next(); !groups_1_1.done; groups_1_1 = groups_1.next()) {
                            item = groups_1_1.value;
                            key = String(item.projectPath || item.relativePath || "").toLowerCase();
                            if (seen.has(key))
                                continue;
                            seen.add(key);
                            out.push(item);
                        }
                    }
                    catch (e_6_1) {
                        e_6 = { error: e_6_1 };
                    }
                    finally {
                        try {
                            if (groups_1_1 && !groups_1_1.done && (_l = groups_1.return))
                                _l.call(groups_1);
                        }
                        finally {
                            if (e_6)
                                throw e_6.error;
                        }
                    }
                    out.sort(function (a, b) {
                        var an = String((a && a.name) || (a && a.relativePath) || "");
                        var bn = String((b && b.name) || (b && b.relativePath) || "");
                        var byName = an.localeCompare(bn, undefined, { numeric: true, sensitivity: "base" });
                        return byName || String((a && a.relativePath) || "").localeCompare(String((b && b.relativePath) || ""), undefined, { numeric: true, sensitivity: "base" });
                    });
                    return [2 /*return*/, out];
            }
        });
    });
}
export function scanUiAssets(ctx) {
    return __awaiter(this, void 0, void 0, function () {
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0: return [4 /*yield*/, scanImageRoot(ctx, "Graphics/UI", "ui", "UI")];
                case 1: return [2 /*return*/, _f.sent()];
            }
        });
    });
}
export function loadProjectImageUrl(ctx, projectPath) {
    return __awaiter(this, void 0, void 0, function () {
        var abs, bytes, _a_4, arr;
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    abs = absoluteProjectPath(ctx, projectPath);
                    if (!abs)
                        return [2 /*return*/, null];
                    _f.label = 1;
                case 1:
                    _f.trys.push([1, 3, , 4]);
                    return [4 /*yield*/, invoke("read_binary_file", { path: abs })];
                case 2:
                    bytes = _f.sent();
                    return [3 /*break*/, 4];
                case 3:
                    _a_4 = _f.sent();
                    return [2 /*return*/, null];
                case 4:
                    if (!bytes || !bytes.length)
                        return [2 /*return*/, null];
                    arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
                    return [2 /*return*/, URL.createObjectURL(new Blob([arr], { type: mimeFor(projectPath) }))];
            }
        });
    });
}
export function resolveImageByStem(ctx, rootProjectPath, stem) {
    return __awaiter(this, void 0, void 0, function () {
        var files, wanted;
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    if (!stem)
                        return [2 /*return*/, null];
                    return [4 /*yield*/, scanImageRoot(ctx, rootProjectPath, "resolve", rootProjectPath)];
                case 1:
                    files = _f.sent();
                    wanted = String(stem).toLowerCase();
                    return [2 /*return*/, files.find(function (item) { return String((item && item.name) || "").toLowerCase() === wanted; }) || null];
            }
        });
    });
}
export function resolveLegacyGraphic(ctx_1, graphic_1) {
    return __awaiter(this, arguments, void 0, function (ctx, graphic, cachedAssets) {
        var sourceRoot, assets, _f, folder, name, hintRaw, hint, hintStripped, hinted, byName, priority, prioritizedByName, match;
        if (cachedAssets === void 0) {
            cachedAssets = null;
        }
        return __generator(this, function (_g) {
            switch (_g.label) {
                case 0:
                    if (!graphic)
                        return [2 /*return*/, null];
                    if (graphic.projectPath)
                        return [2 /*return*/, { projectPath: graphic.projectPath, name: graphic.name || stemOf(graphic.projectPath), source: graphic.source || "custom" }];
                    sourceRoot = ANIMATION_ASSET_ROOTS.find(function (root) { return root.id === graphic.source; })
                        || ANIMATION_ASSET_ROOTS.find(function (root) { return String((root && root.projectPath) || "").toLowerCase().endsWith("/".concat(String(graphic.folder || "").toLowerCase())); });
                    _f = cachedAssets;
                    if (_f)
                        return [3 /*break*/, 2];
                    return [4 /*yield*/, scanAnimationAssets(ctx)];
                case 1:
                    _f = (_g.sent());
                    _g.label = 2;
                case 2:
                    assets = _f;
                    folder = String(graphic.folder || "").toLowerCase();
                    name = String(graphic.name || "").toLowerCase();
                    hintRaw = String(graphic.relativeHint || "").replace(/\\/g, "/").replace(/\.[^.]+$/, "").trim().toLowerCase();
                    hint = hintRaw;
                    hintStripped = hintRaw.replace(/\[\s*bottom\s*\]\s*$/i, "").trim();
                    hinted = hint ? assets.find(function (item) { var rel = String((item && item.relativePath) || "").replace(/\.[^.]+$/, "").trim().toLowerCase(); var proj = String((item && item.projectPath) || "").replace(/^Graphics\/(?:AnimationStudio|Battle animations|Animations)\//i, "").replace(/\.[^.]+$/, "").trim().toLowerCase(); return rel === hint || proj === hint || rel === hintStripped || proj === hintStripped; }) : null;
                    byName = assets.filter(function (item) { return String((item && item.name) || "").toLowerCase() === name; });
                    priority = ["studio", "legacy", "new", "ebdx_moves", "ebdx_common", "battle", "code"];
                    prioritizedByName = priority.map(function (id) { return byName.find(function (item) { return item.source === id; }); }).find(Boolean) || byName[0] || null;
                    match = hinted
                        || (folder ? byName.find(function (item) { return String((item && item.rootProjectPath) || "").toLowerCase().endsWith("/".concat(folder)) || String((item && item.projectPath) || "").toLowerCase().includes("/".concat(folder, "/")); }) : null)
                        || prioritizedByName
                        || (sourceRoot ? byName.find(function (item) { return item.source === sourceRoot.id; }) : null)
                        || null;
                    return [2 /*return*/, match || null];
            }
        });
    });
}
export function compactProjectPath(path) {
    var p = norm(path);
    return p.startsWith("Graphics/") ? p.slice("Graphics/".length) : p;
}
// Generic recursive project scanner used by the animation importers.
export function scanProjectFiles(ctx_1, rootProjectPath_1) {
    return __awaiter(this, arguments, void 0, function (ctx, rootProjectPath, extensions, maxDepth) {
        function walk(absDir, relDir, depth) {
            return __awaiter(this, void 0, void 0, function () {
                var entries, _a_5, _f, _g, entry, name, flags, abs, rel, e_7_1;
                var e_7, _h;
                return __generator(this, function (_j) {
                    switch (_j.label) {
                        case 0:
                            if (depth > maxDepth)
                                return [2 /*return*/];
                            entries = [];
                            _j.label = 1;
                        case 1:
                            _j.trys.push([1, 3, , 4]);
                            return [4 /*yield*/, listAbsolute(absDir)];
                        case 2:
                            entries = _j.sent();
                            return [3 /*break*/, 4];
                        case 3:
                            _a_5 = _j.sent();
                            return [2 /*return*/];
                        case 4:
                            _j.trys.push([4, 10, 11, 12]);
                            _f = __values(entries || []), _g = _f.next();
                            _j.label = 5;
                        case 5:
                            if (!!_g.done)
                                return [3 /*break*/, 9];
                            entry = _g.value;
                            name = (entry === null || entry === void 0 ? void 0 : entry.name) || norm(entry === null || entry === void 0 ? void 0 : entry.path).split("/").pop();
                            if (!name)
                                return [3 /*break*/, 8];
                            flags = entryFlags(entry);
                            abs = norm((entry === null || entry === void 0 ? void 0 : entry.path) || join(absDir, name));
                            rel = join(relDir, name);
                            if (!flags.isDir)
                                return [3 /*break*/, 7];
                            return [4 /*yield*/, walk(abs, rel, depth + 1)];
                        case 6:
                            _j.sent();
                            return [3 /*break*/, 8];
                        case 7:
                            if (flags.isFile && wanted.has(extOf(name)))
                                out.push({ projectPath: join(rootProjectPath, rel), relativePath: rel, name: stemOf(name), filename: name, extension: extOf(name) });
                            _j.label = 8;
                        case 8:
                            _g = _f.next();
                            return [3 /*break*/, 5];
                        case 9: return [3 /*break*/, 12];
                        case 10:
                            e_7_1 = _j.sent();
                            e_7 = { error: e_7_1 };
                            return [3 /*break*/, 12];
                        case 11:
                            try {
                                if (_g && !_g.done && (_h = _f.return))
                                    _h.call(_f);
                            }
                            finally {
                                if (e_7)
                                    throw e_7.error;
                            }
                            return [7 /*endfinally*/];
                        case 12: return [2 /*return*/];
                    }
                });
            });
        }
        var wanted, rootAbs, _f, out;
        if (extensions === void 0) {
            extensions = ["txt"];
        }
        if (maxDepth === void 0) {
            maxDepth = 12;
        }
        return __generator(this, function (_g) {
            switch (_g.label) {
                case 0:
                    wanted = new Set((extensions || []).map(function (x) { return String(x).replace(/^\./, "").toLowerCase(); }));
                    rootAbs = absoluteProjectPath(ctx, rootProjectPath);
                    _f = !rootAbs;
                    if (_f)
                        return [3 /*break*/, 2];
                    return [4 /*yield*/, existsAbsolute(rootAbs)];
                case 1:
                    _f = !(_g.sent());
                    _g.label = 2;
                case 2:
                    if (_f)
                        return [2 /*return*/, []];
                    out = [];
                    return [4 /*yield*/, walk(rootAbs, "", 0)];
                case 3:
                    _g.sent();
                    return [2 /*return*/, out.filter(function (x) { return !!x && typeof x === "object"; }).sort(function (a, b) { return String((a && a.relativePath) || "").localeCompare(String((b && b.relativePath) || ""), undefined, { numeric: true, sensitivity: "base" }); })];
            }
        });
    });
}
// Recursive scanner for an arbitrary external folder selected by the user.
export function scanAbsoluteFiles(rootPath_1) {
    return __awaiter(this, arguments, void 0, function (rootPath, extensions, maxDepth) {
        function walk(absDir, relDir, depth) {
            return __awaiter(this, void 0, void 0, function () {
                var entries, _a_6, _f, _g, entry, name, flags, abs, rel, e_8_1;
                var e_8, _h;
                return __generator(this, function (_j) {
                    switch (_j.label) {
                        case 0:
                            if (depth > maxDepth)
                                return [2 /*return*/];
                            entries = [];
                            _j.label = 1;
                        case 1:
                            _j.trys.push([1, 3, , 4]);
                            return [4 /*yield*/, listAbsolute(absDir)];
                        case 2:
                            entries = _j.sent();
                            return [3 /*break*/, 4];
                        case 3:
                            _a_6 = _j.sent();
                            return [2 /*return*/];
                        case 4:
                            _j.trys.push([4, 10, 11, 12]);
                            _f = __values(entries || []), _g = _f.next();
                            _j.label = 5;
                        case 5:
                            if (!!_g.done)
                                return [3 /*break*/, 9];
                            entry = _g.value;
                            name = (entry === null || entry === void 0 ? void 0 : entry.name) || norm(entry === null || entry === void 0 ? void 0 : entry.path).split("/").pop();
                            if (!name)
                                return [3 /*break*/, 8];
                            flags = entryFlags(entry);
                            abs = norm((entry === null || entry === void 0 ? void 0 : entry.path) || join(absDir, name));
                            rel = join(relDir, name);
                            if (!flags.isDir)
                                return [3 /*break*/, 7];
                            return [4 /*yield*/, walk(abs, rel, depth + 1)];
                        case 6:
                            _j.sent();
                            return [3 /*break*/, 8];
                        case 7:
                            if (flags.isFile && wanted.has(extOf(name)))
                                out.push({ absolutePath: abs, relativePath: rel, name: stemOf(name), filename: name, extension: extOf(name) });
                            _j.label = 8;
                        case 8:
                            _g = _f.next();
                            return [3 /*break*/, 5];
                        case 9: return [3 /*break*/, 12];
                        case 10:
                            e_8_1 = _j.sent();
                            e_8 = { error: e_8_1 };
                            return [3 /*break*/, 12];
                        case 11:
                            try {
                                if (_g && !_g.done && (_h = _f.return))
                                    _h.call(_f);
                            }
                            finally {
                                if (e_8)
                                    throw e_8.error;
                            }
                            return [7 /*endfinally*/];
                        case 12: return [2 /*return*/];
                    }
                });
            });
        }
        var wanted, root, _f, out;
        if (extensions === void 0) {
            extensions = ["txt"];
        }
        if (maxDepth === void 0) {
            maxDepth = 14;
        }
        return __generator(this, function (_g) {
            switch (_g.label) {
                case 0:
                    wanted = new Set((extensions || []).map(function (x) { return String(x).replace(/^\./, "").toLowerCase(); }));
                    root = norm(rootPath || "");
                    _f = !root;
                    if (_f)
                        return [3 /*break*/, 2];
                    return [4 /*yield*/, existsAbsolute(root)];
                case 1:
                    _f = !(_g.sent());
                    _g.label = 2;
                case 2:
                    if (_f)
                        return [2 /*return*/, []];
                    out = [];
                    return [4 /*yield*/, walk(root, "", 0)];
                case 3:
                    _g.sent();
                    return [2 /*return*/, out.filter(function (x) { return !!x && typeof x === "object"; }).sort(function (a, b) { return String((a && a.relativePath) || "").localeCompare(String((b && b.relativePath) || ""), undefined, { numeric: true, sensitivity: "base" }); })];
            }
        });
    });
}
// Battle scene backdrop/base browser. Essentials convention:
// <stem>_bg, <stem>_base0 and <stem>_base1 in Graphics/Battlebacks.
export function scanBattlebackAssets(ctx) {
    return __awaiter(this, void 0, void 0, function () {
        var files, groups, files_1, files_1_1, file, stem, key, role, g;
        var e_9, _f;
        return __generator(this, function (_g) {
            switch (_g.label) {
                case 0: return [4 /*yield*/, scanImageRoot(ctx, "Graphics/Battlebacks", "battleback", "Battlebacks", 6)];
                case 1:
                    files = _g.sent();
                    groups = new Map();
                    try {
                        for (files_1 = __values(files), files_1_1 = files_1.next(); !files_1_1.done; files_1_1 = files_1.next()) {
                            file = files_1_1.value;
                            stem = file.name;
                            key = stem, role = "other";
                            if (/_bg$/i.test(stem)) {
                                key = stem.replace(/_bg$/i, "");
                                role = "background";
                            }
                            else if (/_base0$/i.test(stem)) {
                                key = stem.replace(/_base0$/i, "");
                                role = "playerBase";
                            }
                            else if (/_base1$/i.test(stem)) {
                                key = stem.replace(/_base1$/i, "");
                                role = "enemyBase";
                            }
                            if (!groups.has(key))
                                groups.set(key, { key: key, label: key, background: null, playerBase: null, enemyBase: null, files: [] });
                            g = groups.get(key);
                            g.files.push(file);
                            if (role !== "other")
                                g[role] = file;
                        }
                    }
                    catch (e_9_1) {
                        e_9 = { error: e_9_1 };
                    }
                    finally {
                        try {
                            if (files_1_1 && !files_1_1.done && (_f = files_1.return))
                                _f.call(files_1);
                        }
                        finally {
                            if (e_9)
                                throw e_9.error;
                        }
                    }
                    return [2 /*return*/, { files: files, groups: __spreadArray([], __read(groups.values()), false).sort(function (a, b) { return a.key.localeCompare(b.key, undefined, { numeric: true, sensitivity: "base" }); }) }];
            }
        });
    });
}
export function scanAbsoluteImages(rootPath_1) {
    return __awaiter(this, arguments, void 0, function (rootPath, maxDepth) {
        var files;
        if (maxDepth === void 0) {
            maxDepth = 10;
        }
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0: return [4 /*yield*/, scanAbsoluteFiles(rootPath, __spreadArray([], __read(IMAGE_EXTS), false), maxDepth)];
                case 1:
                    files = _f.sent();
                    return [2 /*return*/, files.filter(function (f) { return IMAGE_EXTS.has(f.extension); })];
            }
        });
    });
}
