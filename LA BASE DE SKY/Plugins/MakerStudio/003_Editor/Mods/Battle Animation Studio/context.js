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
import { CONTEXT_FILE, clampNumber } from "./model.js";
export function fallbackBattleContext(width, height, source) {
    if (width === void 0) {
        width = 512;
    }
    if (height === void 0) {
        height = 384;
    }
    if (source === void 0) {
        source = "default";
    }
    var w = clampNumber(width, 160, 4096, 512), h = clampNumber(height, 120, 4096, 384);
    // Match Essentials 21.1 Battle::Scene.pbBattlerPosition exactly.
    // These are not percentages: PLAYER_BASE_X is fixed at 128, while the
    // opposite side and both Y coordinates are derived from the active screen.
    var ux = 128, uy = h - 80, tx = w - 128, ty = (h * 3 / 4) - 112;
    return { version: 4, source: source, captureKind: "fallback", capturedAt: null, sceneClass: "Battle::Scene", width: w, height: h, graphicsWidth: w, graphicsHeight: h, settingsWidth: w, settingsHeight: h, userIndex: 0, targetIndex: 1, sideSizes: { user: 1, target: 1 },
        user: { x: ux, y: uy, focusX: ux, focusY: uy - 40, zoomX: 1, zoomY: 1, z: 1100, ox: 0, oy: 0, bitmapWidth: 0, bitmapHeight: 0, tone: null, color: null },
        target: { x: tx, y: ty, focusX: tx, focusY: ty - 40, zoomX: 1, zoomY: 1, z: 900, ox: 0, oy: 0, bitmapWidth: 0, bitmapHeight: 0, tone: null, color: null },
        scriptUser: { x: ux, y: uy }, scriptTarget: { x: tx, y: ty },
        bases: { user: { x: ux, y: uy, width: w * .34, height: h * .12, zoomX: 1, zoomY: 1 }, target: { x: tx, y: ty, width: w * .27, height: h * .10, zoomX: 1, zoomY: 1 } }, raw: null };
}
function num(v, f) { var n = Number(v); return Number.isFinite(n) ? n : f; }
function normalizeSprite(s, f) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l;
    if (!s || typeof s !== "object")
        return Object.assign({}, f);
    var bw = num((_f = s.bitmap_width) !== null && _f !== void 0 ? _f : s.bitmapWidth, 0), bh = num((_g = s.bitmap_height) !== null && _g !== void 0 ? _g : s.bitmapHeight, 0);
    return { x: num(s.x, f.x), y: num(s.y, f.y), focusX: num((_a = s.focus_x) !== null && _a !== void 0 ? _a : s.focusX, f.focusX), focusY: num((_b = s.focus_y) !== null && _b !== void 0 ? _b : s.focusY, f.focusY), zoomX: num((_c = s.zoom_x) !== null && _c !== void 0 ? _c : s.zoomX, 1), zoomY: num((_d = s.zoom_y) !== null && _d !== void 0 ? _d : s.zoomY, 1), z: num(s.z, (_e = f.z) !== null && _e !== void 0 ? _e : 100), ox: num(s.ox, 0), oy: num(s.oy, 0), bitmapWidth: bw, bitmapHeight: bh, bitmapReal: s.bitmap_real === false || s.bitmapReal === false ? false : (bw > 0 && bh > 0), visible: s.visible !== false, mirror: !!s.mirror, angle: num(s.angle, 0), tone: (_j = (_h = s.tone) !== null && _h !== void 0 ? _h : f.tone) !== null && _j !== void 0 ? _j : null, color: (_l = (_k = s.color) !== null && _k !== void 0 ? _k : f.color) !== null && _l !== void 0 ? _l : null, species: String(s.species || s.species_id || s.speciesId || f.species || "") };
}
function normalizeBase(s, f) {
    var _a, _b, _c, _d;
    if (!s || typeof s !== "object")
        return Object.assign({}, f);
    return { x: num(s.x, f.x), y: num(s.y, f.y), width: num((_a = s.bitmap_width) !== null && _a !== void 0 ? _a : s.bitmapWidth, f.width), height: num((_b = s.bitmap_height) !== null && _b !== void 0 ? _b : s.bitmapHeight, f.height), zoomX: num((_c = s.zoom_x) !== null && _c !== void 0 ? _c : s.zoomX, 1), zoomY: num((_d = s.zoom_y) !== null && _d !== void 0 ? _d : s.zoomY, 1), ox: num(s.ox, 0), oy: num(s.oy, 0), visible: s.visible !== false };
}
function parseBattleFormat(format) {
    var m = String(format || "1v1").match(/^([123])v([123])$/i);
    return m ? { user: Number(m[1]), target: Number(m[2]) } : { user: 1, target: 1 };
}
function battlerPositionForIndex(index, sideSize, width, height, offsets) {
    if (offsets === void 0) {
        offsets = null;
    }
    var w = Number(width || 512), h = Number(height || 384), foe = (Number(index) & 1) === 1;
    var x = foe ? (w - 128) : 128;
    var y = foe ? ((h * 3 / 4) - 112) : (h - 80);
    var off2x = Array.isArray(offsets && offsets.twoX) ? offsets.twoX : [-48, 48, 32, -32], off2y = Array.isArray(offsets && offsets.twoY) ? offsets.twoY : [0, 0, 16, -16];
    var off3x = Array.isArray(offsets && offsets.threeX) ? offsets.threeX : [-80, 80, 0, 0, 80, -80], off3y = Array.isArray(offsets && offsets.threeY) ? offsets.threeY : [0, 0, 8, -8, 16, -16];
    if (sideSize === 2) {
        x += Number(off2x[index] || 0);
        y += Number(off2y[index] || 0);
    }
    else if (sideSize === 3) {
        x += Number(off3x[index] || 0);
        y += Number(off3y[index] || 0);
    }
    return { x: x, y: y };
}
function syntheticSideSlots(side, count, width, height, offsets) {
    if (offsets === void 0) {
        offsets = null;
    }
    var foe = side === "target", out = [];
    for (var i = 0; i < count; i++) {
        var index = i * 2 + (foe ? 1 : 0), p = battlerPositionForIndex(index, count, width, height, offsets);
        out.push({ index: index, x: p.x, y: p.y });
    }
    return out;
}
function applyBattleFormatOverride(context, format, preview) {
    if (preview === void 0) {
        preview = null;
    }
    if (!context)
        return context;
    var counts = parseBattleFormat(format), clone = (typeof structuredClone === "function") ? structuredClone(context) : JSON.parse(JSON.stringify(context));
    var userSlot = Math.max(0, Math.min(counts.user - 1, Number((preview && preview.activeUserSlot) || 0))), targetSlot = Math.max(0, Math.min(counts.target - 1, Number((preview && preview.activeTargetSlot) || 0)));
    var requestedTargetIndex = Number(preview && preview.activeTargetIndex);
    if (!Number.isFinite(requestedTargetIndex) || requestedTargetIndex < 0)
        requestedTargetIndex = targetSlot * 2 + 1;
    var liveBattlers = clone.raw && Array.isArray(clone.raw.battlers) ? clone.raw.battlers.filter(Boolean) : [];
    var liveUserCount = Number((context.sideSizes && context.sideSizes.user) || 1), liveTargetCount = Number((context.sideSizes && context.sideSizes.target) || 1);
    // If the requested format is the format that was actually captured, keep the
    // real rendered positions/origins from Battle::Scene. This preserves DBK and
    // any project plugin that shifts battlers after pbBattlerPosition.
    var captureKind = String(clone.captureKind || "").toLowerCase();
    var exactLiveFormation = /^(battle_settled|battle_scene|battle_live)/.test(captureKind);
    if (String(clone.source || "").toLowerCase() !== "script" && exactLiveFormation && liveBattlers.length && liveUserCount === counts.user && liveTargetCount === counts.target) {
        var users = liveBattlers.filter(function (b) { return Number(b.index) % 2 === 0; }).sort(function (a, b) { return Number(a.index) - Number(b.index); }).slice(0, counts.user);
        var targets = liveBattlers.filter(function (b) { return Number(b.index) % 2 === 1; }).sort(function (a, b) { return Number(a.index) - Number(b.index); }).slice(0, counts.target);
        if (users.length === counts.user && targets.length === counts.target) {
            var ur = users[userSlot] || users[0], allLive = users.concat(targets), tr = allLive.find(function (b) { return Number(b.index) === requestedTargetIndex; }) || targets[targetSlot] || targets[0];
            var ui = Number(ur.index), ti = Number(tr.index);
            clone.sideSizes = { user: counts.user, target: counts.target };
            clone.userIndex = ui;
            clone.targetIndex = ti;
            clone.user = normalizeSprite(ur, clone.user || fallbackBattleContext(clone.width, clone.height).user);
            clone.user.index = ui;
            clone.target = normalizeSprite(tr, clone.target || fallbackBattleContext(clone.width, clone.height).target);
            clone.target.index = ti;
            var targetSideSize = (ti % 2 === 0) ? counts.user : counts.target;
            var up = battlerPositionForIndex(ui, counts.user, clone.width, clone.height, clone.battlerOffsets), tp = battlerPositionForIndex(ti, targetSideSize, clone.width, clone.height, clone.battlerOffsets);
            clone.scriptUser = { x: up.x, y: up.y };
            clone.scriptTarget = { x: tp.x, y: tp.y };
            clone.raw.user_index = ui;
            clone.raw.target_index = ti;
            clone.raw.user_side_size = counts.user;
            clone.raw.target_side_size = targetSideSize;
            clone.raw.user_battler_position = [up.x, up.y];
            clone.raw.target_battler_position = [tp.x, tp.y];
            // The Studio formation is a positional reference, not a snapshot of temporary
            // show/hide state. A battle capture taken while a battler sprite was hidden must
            // not make allies/opponents disappear from 2v2/3v3 preview. Keep the real scene
            // coordinates/species/origins, but restore visibility for every occupied slot.
            clone.raw.battlers = users.concat(targets).map(function (b) {
                var idx = Number(b.index);
                return Object.assign({}, b, { visible: true, side_size: idx % 2 === 0 ? counts.user : counts.target });
            });
            clone.captureKind = "".concat(clone.captureKind || clone.source || "preview", " \u00B7 ").concat(counts.user, "v").concat(counts.target);
            return clone;
        }
    }
    // No exact live formation is available (for example, previewing 2v1 while
    // the last battle was 1v1). Reproduce Essentials' pbBattlerPosition offsets.
    // SpeciesMetrics are applied later by preview.js exactly like NAE does.
    var userSlots = syntheticSideSlots("user", counts.user, clone.width, clone.height, clone.battlerOffsets), targetSlots = syntheticSideSlots("target", counts.target, clone.width, clone.height, clone.battlerOffsets);
    var allSlots = userSlots.concat(targetSlots);
    var userPrimary = userSlots[userSlot] || userSlots[0], targetPrimary = allSlots.find(function (slot) { return Number(slot.index) === requestedTargetIndex; }) || targetSlots[targetSlot] || targetSlots[0];
    clone.sideSizes = { user: counts.user, target: counts.target };
    clone.userIndex = Number(userPrimary.index);
    clone.targetIndex = Number(targetPrimary.index);
    clone.scriptUser = { x: Number(userPrimary.x), y: Number(userPrimary.y) };
    clone.scriptTarget = { x: Number(targetPrimary.x), y: Number(targetPrimary.y) };
    var userFocusOffset = Math.max(40, Number((clone.user && clone.user.bitmapHeight) || 80) / 2), targetFocusOffset = Math.max(40, Number((clone.target && clone.target.bitmapHeight) || 80) / 2);
    clone.user = Object.assign(Object.assign({}, clone.user || {}), { index: clone.userIndex, x: Number(userPrimary.x), y: Number(userPrimary.y), focusX: Number(userPrimary.x), focusY: Number(userPrimary.y - userFocusOffset), bitmapReal: false });
    clone.target = Object.assign(Object.assign({}, clone.target || {}), { index: clone.targetIndex, x: Number(targetPrimary.x), y: Number(targetPrimary.y), focusX: Number(targetPrimary.x), focusY: Number(targetPrimary.y - targetFocusOffset), bitmapReal: false });
    var synth = [];
    userSlots.forEach(function (slot) { return synth.push({ index: slot.index, x: slot.x, y: slot.y, focus_x: slot.x, focus_y: slot.y - userFocusOffset, side_size: counts.user, visible: true, bitmap_real: false }); });
    targetSlots.forEach(function (slot) { return synth.push({ index: slot.index, x: slot.x, y: slot.y, focus_x: slot.x, focus_y: slot.y - targetFocusOffset, side_size: counts.target, visible: true, bitmap_real: false }); });
    clone.raw = Object.assign(Object.assign({}, clone.raw || {}), { battlers: synth, user_side_size: counts.user, target_side_size: (clone.targetIndex % 2 === 0 ? counts.user : counts.target), user_index: clone.userIndex, target_index: clone.targetIndex, user_battler_position: [userPrimary.x, userPrimary.y], target_battler_position: [targetPrimary.x, targetPrimary.y] });
    clone.captureKind = "".concat(clone.captureKind || clone.source || "preview", " \u00B7 ").concat(counts.user, "v").concat(counts.target);
    return clone;
}
export function normalizeRuntimeContext(raw) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v;
    if (!raw || typeof raw !== "object")
        return null;
    var width = clampNumber((_c = (_b = (_a = raw.width) !== null && _a !== void 0 ? _a : raw.detected_width) !== null && _b !== void 0 ? _b : raw.graphics_width) !== null && _c !== void 0 ? _c : raw.settings_width, 160, 4096, 512), height = clampNumber((_f = (_e = (_d = raw.height) !== null && _d !== void 0 ? _d : raw.detected_height) !== null && _e !== void 0 ? _e : raw.graphics_height) !== null && _f !== void 0 ? _f : raw.settings_height, 120, 4096, 384), fb = fallbackBattleContext(width, height, "runtime");
    var bs = Array.isArray(raw.battlers) ? raw.battlers : [], ui = Number.isInteger(Number(raw.user_index)) ? Number(raw.user_index) : 0, ti = Number.isInteger(Number(raw.target_index)) ? Number(raw.target_index) : 1;
    var ur = bs.find(function (b) { return Number(b.index) === ui; }) || raw.user, tr = bs.find(function (b) { return Number(b.index) === ti; }) || raw.target;
    var usp = raw.user_battler_position || ((_g = raw.script_positions) === null || _g === void 0 ? void 0 : _g.user) || [fb.user.x, fb.user.y], tsp = raw.target_battler_position || ((_h = raw.script_positions) === null || _h === void 0 ? void 0 : _h.target) || [fb.target.x, fb.target.y];
    var user = normalizeSprite(ur, fb.user), target = normalizeSprite(tr, fb.target);
    user.index = ui;
    target.index = ti;
    var captureKind = String(raw.capture_kind || raw.captureKind || "runtime").toLowerCase();
    var staticSnapshot = /^(plugin_load|game_load|static)$/.test(captureKind);
    if (staticSnapshot) {
        // Static snapshots have screen geometry but no rendered battler. Ignore
        // synthetic 96x96 data written by older bridges and let the selected PNG
        // plus pokemon_metrics determine width, height and origin.
        user.x = num(usp[0], fb.user.x);
        user.y = num(usp[1], fb.user.y);
        user.focusX = user.x;
        user.focusY = user.y;
        user.ox = 0;
        user.oy = 0;
        user.bitmapWidth = 0;
        user.bitmapHeight = 0;
        user.bitmapReal = false;
        target.x = num(tsp[0], fb.target.x);
        target.y = num(tsp[1], fb.target.y);
        target.focusX = target.x;
        target.focusY = target.y;
        target.ox = 0;
        target.oy = 0;
        target.bitmapWidth = 0;
        target.bitmapHeight = 0;
        target.bitmapReal = false;
    }
    // Match New Animation Editor's focal point: battler X and Y minus half bitmap height.
    // Runtime captures may provide a more exact focus (e.g. animated sprite plugins); keep it when present.
    if (!(ur && (ur.focus_y != null || ur.focusY != null)) && user.bitmapHeight > 0)
        user.focusY = user.y - user.bitmapHeight / 2;
    if (!(tr && (tr.focus_y != null || tr.focusY != null)) && target.bitmapHeight > 0)
        target.focusY = target.y - target.bitmapHeight / 2;
    return { version: Number(raw.version || 3), source: "runtime", captureKind: raw.capture_kind || raw.captureKind || "runtime", capturedAt: (_k = (_j = raw.captured_at) !== null && _j !== void 0 ? _j : raw.capturedAt) !== null && _k !== void 0 ? _k : null, sceneClass: raw.scene_class || raw.sceneClass || "Battle::Scene", width: width, height: height, graphicsWidth: num(raw.graphics_width, width), graphicsHeight: num(raw.graphics_height, height), settingsWidth: num(raw.settings_width, width), settingsHeight: num(raw.settings_height, height),
        userIndex: ui, targetIndex: ti, sideSizes: { user: Number((_o = (_l = raw.user_side_size) !== null && _l !== void 0 ? _l : (_m = raw.side_sizes) === null || _m === void 0 ? void 0 : _m.user) !== null && _o !== void 0 ? _o : 1), target: Number((_r = (_p = raw.target_side_size) !== null && _p !== void 0 ? _p : (_q = raw.side_sizes) === null || _q === void 0 ? void 0 : _q.target) !== null && _r !== void 0 ? _r : 1) }, user: user, target: target, scriptUser: { x: num(usp[0], fb.user.x), y: num(usp[1], fb.user.y) }, scriptTarget: { x: num(tsp[0], fb.target.x), y: num(tsp[1], fb.target.y) },
        bases: { user: normalizeBase((_t = (_s = raw.bases) === null || _s === void 0 ? void 0 : _s.user) !== null && _t !== void 0 ? _t : raw.base_0, fb.bases.user), target: normalizeBase((_v = (_u = raw.bases) === null || _u === void 0 ? void 0 : _u.target) !== null && _v !== void 0 ? _v : raw.base_1, fb.bases.target) }, raw: raw };
}
export function readRuntimeContext(ctx) {
    return __awaiter(this, void 0, void 0, function () {
        var _a, _b, _w, _x, _y, e_1;
        return __generator(this, function (_z) {
            switch (_z.label) {
                case 0:
                    _z.trys.push([0, 3, , 4]);
                    return [4 /*yield*/, ctx.fs.projectExists(CONTEXT_FILE)];
                case 1:
                    if (!(_z.sent()))
                        return [2 /*return*/, null];
                    _w = normalizeRuntimeContext;
                    _y = (_x = JSON).parse;
                    return [4 /*yield*/, ctx.fs.readProjectFile(CONTEXT_FILE)];
                case 2: return [2 /*return*/, _w.apply(void 0, [_y.apply(_x, [_z.sent()])])];
                case 3:
                    e_1 = _z.sent();
                    (_b = (_a = ctx.log) === null || _a === void 0 ? void 0 : _a.warn) === null || _b === void 0 ? void 0 : _b.call(_a, "Battle Animation Studio: invalid battle context snapshot", e_1);
                    return [2 /*return*/, null];
                case 4: return [2 /*return*/];
            }
        });
    });
}
export function effectiveBattleContext(preview, runtime, projectDetected) {
    if (projectDetected === void 0) {
        projectDetected = null;
    }
    var mode = (preview === null || preview === void 0 ? void 0 : preview.contextMode) || "auto";
    var format = (preview === null || preview === void 0 ? void 0 : preview.battleFormat) || "1v1";
    var cloneOf = function (value) { return value ? ((typeof structuredClone === "function") ? structuredClone(value) : JSON.parse(JSON.stringify(value))) : null; };
    // The editor must be deterministic. Auto/Script are built from the project
    // configuration and pbBattlerPosition geometry, never from whichever battle
    // happened to run last. A live battle is consulted only when the user
    // explicitly selects Runtime / live scene.
    if (mode === "auto") {
        var autoBase = cloneOf(projectDetected);
        if (!autoBase) {
            var w = Number((runtime && runtime.width) || 512), h = Number((runtime && runtime.height) || 384);
            autoBase = fallbackBattleContext(w, h, "auto");
            if (runtime && runtime.battlerOffsets)
                autoBase.battlerOffsets = cloneOf(runtime.battlerOffsets);
        }
        autoBase.source = "auto";
        autoBase.captureKind = projectDetected ? (projectDetected.captureKind || "project scripts") : "project fallback";
        return applyBattleFormatOverride(autoBase, format, preview);
    }
    if (mode === "script") {
        var scriptBase = cloneOf(projectDetected);
        if (!scriptBase) {
            var w = Number((runtime && runtime.width) || 512), h = Number((runtime && runtime.height) || 384);
            scriptBase = fallbackBattleContext(w, h, "script");
            if (runtime && runtime.battlerOffsets)
                scriptBase.battlerOffsets = cloneOf(runtime.battlerOffsets);
        }
        scriptBase.source = "script";
        scriptBase.captureKind = projectDetected ? (projectDetected.captureKind || "pbBattlerPosition") : "pbBattlerPosition fallback";
        return applyBattleFormatOverride(scriptBase, format, preview);
    }
    if (mode === "runtime" && runtime) {
        var live = cloneOf(runtime);
        live.source = "runtime";
        if (!live.battlerOffsets && projectDetected && projectDetected.battlerOffsets)
            live.battlerOffsets = cloneOf(projectDetected.battlerOffsets);
        return applyBattleFormatOverride(live, format, preview);
    }
    if (mode === "manual") {
        var m = (preview === null || preview === void 0 ? void 0 : preview.manualContext) || {}, b = fallbackBattleContext(m.width || 512, m.height || 384, "manual");
        b.user = Object.assign(Object.assign({}, b.user), (m.user || {}));
        b.target = Object.assign(Object.assign({}, b.target), (m.target || {}));
        return applyBattleFormatOverride(b, format, preview);
    }
    if (projectDetected) {
        var projectBase = cloneOf(projectDetected);
        projectBase.source = "project";
        return applyBattleFormatOverride(projectBase, format, preview);
    }
    if (runtime) {
        // Runtime is only a last-resort source of canvas dimensions here; strip
        // all live battler sprite/species state unless Runtime mode was selected.
        var fallback = fallbackBattleContext(Number(runtime.width || 512), Number(runtime.height || 384), "default");
        if (runtime.battlerOffsets)
            fallback.battlerOffsets = cloneOf(runtime.battlerOffsets);
        return applyBattleFormatOverride(fallback, format, preview);
    }
    return applyBattleFormatOverride(fallbackBattleContext(512, 384, "default"), format, preview);
}
