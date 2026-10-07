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
export var FORMAT_ID = "battle-animation-studio";
export var FORMAT_VERSION = 41;
export var SAVE_DIR = "PBS/AnimationStudio";
export var SAVE_FILE = "".concat(SAVE_DIR, "/animations.json");
export var CONTEXT_FILE = "".concat(SAVE_DIR, "/battle_context.json");
export var LEGACY_CACHE_FILE = "".concat(SAVE_DIR, "/legacy_animations.json");
export var CODE_CAPTURE_FILE = "".concat(SAVE_DIR, "/code_capture.json");
export var COMPILED_FILE = "".concat(SAVE_DIR, "/compiled_animations.json");
export var GAME_RUNTIME_DIR = "Plugins/Battle Animation Studio Runtime";
export var GAME_RUNTIME_FILE = "".concat(GAME_RUNTIME_DIR, "/001_Runtime.rb");
var serial = 1;
export function uid(prefix) {
    if (prefix === void 0) {
        prefix = "id";
    }
    return "".concat(prefix, "_").concat(Date.now().toString(36), "_").concat((serial++).toString(36));
}
export function clampNumber(value, min, max, fallback) {
    var n = Number(value);
    return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : fallback;
}
export function point(anchor, x, y, offsetX, offsetY) {
    if (anchor === void 0) {
        anchor = "screen";
    }
    if (x === void 0) {
        x = 256;
    }
    if (y === void 0) {
        y = 192;
    }
    if (offsetX === void 0) {
        offsetX = 0;
    }
    if (offsetY === void 0) {
        offsetY = 0;
    }
    return { anchor: anchor, x: x, y: y, offsetX: offsetX, offsetY: offsetY };
}
function deepMerge(base, overrides) {
    var e_1, _c;
    if (!overrides || typeof overrides !== "object")
        return structuredCloneSafe(base);
    var out = Array.isArray(base) ? __spreadArray([], __read(base), false) : Object.assign({}, base);
    try {
        for (var _d = __values(Object.entries(overrides)), _e = _d.next(); !_e.done; _e = _d.next()) {
            var _f = __read(_e.value, 2), k = _f[0], v = _f[1];
            if (v && typeof v === "object" && !Array.isArray(v) && (base === null || base === void 0 ? void 0 : base[k]) && typeof base[k] === "object" && !Array.isArray(base[k]))
                out[k] = deepMerge(base[k], v);
            else
                out[k] = v;
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
    return out;
}
function structuredCloneSafe(v) { return typeof structuredClone === "function" ? structuredClone(v) : JSON.parse(JSON.stringify(v)); }
export function createProjectile(overrides) {
    if (overrides === void 0) {
        overrides = {};
    }
    var clip = {
        id: uid("clip"), type: "projectile", name: "Projectile", enabled: true, locked: false,
        startFrame: 0, endFrame: 18,
        graphic: {
            source: "legacy", projectPath: "", folder: "Animations", name: "", relativeHint: "", externalGameRoot: "",
            hue: 0, spritesheet: "auto", frame: 0, playSheet: false, sheetFps: 20,
            cellW: 192, cellH: 192, cols: 5, rows: 0, origin: "auto", assetCandidates: []
        },
        // Discrete bitmap changes. Each entry becomes active at its frame and
        // remains active until the next switch (useful for black->white BGs,
        // alternate impact art, etc.).
        graphicSwitches: [],
        visual: { size: 100, scaleX: 100, scaleY: 100, opacity: 100, rotation: 0, z: 0, blend: 0, flip: 0 },
        priority: 0, priorityReference: "auto", replicateTo: "none", coordinateSpace: "auto", coordinateSpaceManual: false,
        visibleKeys: [{ id: uid("vkey"), frame: 0, value: true }],
        positionKeys: [
            { id: uid("key"), frame: 0, easing: "ease_both", point: point("user", 0, 0, 0, -48) },
            { id: uid("key"), frame: 18, easing: "ease_both", point: point("target", 0, 0, 0, -42) }
        ],
        valueKeys: defaultValueKeys(),
        fxOps: [],
        pbs: null,
        logic: [],
        imported: null
    };
    return deepMerge(clip, overrides);
}
function defaultValueKeys() {
    return {
        size: [], scaleX: [], scaleY: [], viewScale: [], rotation: [], opacity: [], graphicFrame: [],
        srcX: [], srcY: [], srcW: [], srcH: [], z: [], blend: [], flip: [], flipY: [], facing: [],
        toneRed: [], toneGreen: [], toneBlue: [], toneGray: [],
        cameraX: [], cameraY: [], cameraZoom: [], cameraRotation: []
    };
}
export function createBattlerTrack(side) {
    var anchor = side === "user" ? "user_battler" : "target_battler";
    return {
        id: "battler_".concat(side), type: "battler",
        side: side,
        name: side === "user" ? "User" : "Target", enabled: true, locked: false, formRules: [],
        visual: { size: 100, scaleX: 100, scaleY: 100, opacity: 100, rotation: 0, z: 0, blend: 0, flip: 0 },
        visibleKeys: [{ id: uid("vkey"), frame: 0, value: true }],
        positionKeys: [{ id: uid("key"), frame: 0, easing: "ease_both", point: point(anchor, 0, 0, 0, 0) }],
        valueKeys: defaultValueKeys(), fxOps: [], logic: [], startFrame: 0, endFrame: 0
    };
}
export function createCameraTrack() {
    return {
        id: "camera_main", type: "camera", name: "Camera", enabled: true, locked: false,
        visual: { cameraX: 0, cameraY: 0, cameraZoom: 100, cameraRotation: 0 },
        valueKeys: defaultValueKeys(),
        visibleKeys: [{ id: uid("vkey"), frame: 0, value: true }],
        positionKeys: [{ id: uid("key"), frame: 0, easing: "linear", point: point("screen", 0, 0) }],
        startFrame: 0, endFrame: 0, logic: []
    };
}
export function createAnimation(name, options) {
    if (name === void 0) {
        name = "New Animation";
    }
    if (options === void 0) {
        options = {};
    }
    var targetMode = String(options.targetMode || "foe");
    var sideContext = targetMode === "player" ? "foe" : "player";
    return {
        id: uid("anim"),
        name: name,
        fps: 20, duration: 30,
        source: {
            type: "studio", move: options.move || null, version: 0,
            catalogType: ["move", "common", "custom"].includes(String(options.catalogType || "move")) ? String(options.catalogType || "move") : "move",
            opposing: targetMode === "player",
            sideContext: sideContext,
            targetMode: ["foe", "player", "both", "environment"].includes(targetMode) ? targetMode : "foe",
            targetScope: targetMode === "player" ? "single_user" : (targetMode === "both" ? "all_battlers" : (targetMode === "environment" ? "environment" : "single_foe")),
            allowedTargetScopes: [],
            contextAutoAdapt: true,
            previewAffectedTargets: true,
            autoReplicateAffected: true,
            autoReplicateTouched: false,
            askBackupOnContextEdit: false,
            commonSubjectRole: "auto",
            activeTimelineContext: null,
            authors: Array.isArray(options.authors) ? options.authors.slice() : (options.author ? [String(options.author)] : [])
        },
        contextTimelines: [],
        battlers: { user: createBattlerTrack("user"), target: createBattlerTrack("target") },
        camera: createCameraTrack(),
        tracks: [{ id: uid("track"), type: "effects", name: "Effects", clips: [] }],
        events: [], logic: [], notes: "",
        hidesDataBoxes: false,
        hidesAdjacents: false,
        scene: { inheritProject: true, source: "project", responsive: true, referenceWidth: 0, referenceHeight: 0, cameraBoundsMode: "auto" }
    };
}
export function defaultPreviewSettings() {
    return {
        language: "es",
        studioName: "Battle Animation Studio",
        // Preview battlers are optional. AnimTest remains an explicit preset, never a requirement.
        battlers: {
            user: { projectPath: "", folder: "", name: "", label: "" },
            target: { projectPath: "", folder: "", name: "", label: "" }
        },
        battlerSelectionExplicit: false,
        // Tracks whether Player/Foe preview size was intentionally overridden.
        // Auto must always be driven by the selected project battler/renderer, never by AnimTest.
        battlerSizeManual: { player: false, foe: false },
        battlerScalePreset: "auto",
        scene: { background: "Graphics/Battlebacks/indoor1_bg.png", playerBase: "Graphics/Battlebacks/indoor1_base0.png", enemyBase: "Graphics/Battlebacks/indoor1_base1.png", showBases: true, dim: 0 },
        contextMode: "auto",
        battleFormat: "1v1",
        activeUserSlot: 0,
        activeTargetSlot: 0,
        activeTargetIndex: -1,
        activeTargetSelectionExplicit: false,
        manualContext: {
            width: 512, height: 384,
            user: { x: 128, y: 304, focusX: 128, focusY: 256, zoomX: 1, zoomY: 1 },
            target: { x: 384, y: 176, focusX: 384, focusY: 128, zoomX: 1, zoomY: 1 }
        },
        autoKey: true, loop: true, showPath: true,
        autosaveEnabled: true, autosaveDelaySeconds: 3.5, defaultAnimationAuthor: "",
        initialPackPrompted: false, initialPackInstalled: false,
        focusMode: false,
        battlerScale: 1,
        testBattlerScale: 1,
        // 0 = Auto (use the scale detected from the project/renderer for that view).
        // Manual values are side-level preview overrides exposed in Battlers.
        playerBattlerSize: 0,
        foeBattlerSize: 0,
        quickIntensity: 100,
        sidePreview: "auto",
        layout: { leftWidth: 235, rightWidth: 520, timelineHeight: 390, framePixels: 24 }
    };
}
export function createProject() {
    return {
        format: FORMAT_ID, version: FORMAT_VERSION,
        preview: defaultPreviewSettings(),
        animations: [], reusableClips: [], packages: [], exportGameDataDir: SAVE_DIR, exportPackageDir: SAVE_DIR + "/Exports", editor: { lastAnimationId: null }
    };
}
export function getAllClips(animation) { var _a; return ((_a = animation === null || animation === void 0 ? void 0 : animation.tracks) === null || _a === void 0 ? void 0 : _a.flatMap(function (t) { return t.clips || []; })) || []; }
export function getClip(animation, id) { return getAllClips(animation).find(function (c) { return c.id === id; }) || null; }
export function getBattlerTrack(animation, side) { var _a; return ((_a = animation === null || animation === void 0 ? void 0 : animation.battlers) === null || _a === void 0 ? void 0 : _a[side]) || null; }
export function getCameraTrack(animation) { return (animation === null || animation === void 0 ? void 0 : animation.camera) || null; }
export function getAnimatable(animation, id) {
    if (!animation || !id)
        return null;
    if (id === "battler_user")
        return getBattlerTrack(animation, "user");
    if (id === "battler_target")
        return getBattlerTrack(animation, "target");
    if (id === "camera_main")
        return getCameraTrack(animation);
    return getClip(animation, id);
}
export function getAllAnimatables(animation) {
    return __spreadArray([getBattlerTrack(animation, "user"), getBattlerTrack(animation, "target"), getCameraTrack(animation)], __read(getAllClips(animation)), false).filter(Boolean);
}
export function getEffectsTrack(animation) {
    var _a;
    var t = (_a = animation === null || animation === void 0 ? void 0 : animation.tracks) === null || _a === void 0 ? void 0 : _a.find(function (x) { return x.type === "effects"; });
    if (!t) {
        t = { id: uid("track"), type: "effects", name: "Effects", clips: [] };
        animation.tracks || (animation.tracks = []);
        animation.tracks.push(t);
    }
    return t;
}
export function sortPositionKeys(o) { o.positionKeys || (o.positionKeys = []); o.positionKeys.sort(function (a, b) { return Number(a.frame) - Number(b.frame); }); return o.positionKeys; }
export function positionKeyAt(o, frame, tolerance) {
    if (tolerance === void 0) {
        tolerance = .001;
    }
    return sortPositionKeys(o).find(function (k) { return Math.abs(Number(k.frame) - Number(frame)) <= tolerance; }) || null;
}
export function getPositionKeyById(o, id) { return sortPositionKeys(o).find(function (k) { return k.id === id; }) || null; }
export function setPositionKey(o, frame, p, easing, anchor) {
    if (easing === void 0) {
        easing = "ease_both";
    }
    if (anchor === void 0) {
        anchor = "screen";
    }
    var f = Math.max(0, Math.round(Number(frame) || 0));
    var k = positionKeyAt(o, f);
    if (!k) {
        k = { id: uid("key"), frame: f, easing: easing, point: point(anchor, p.x || 0, p.y || 0, p.offsetX || 0, p.offsetY || 0) };
        o.positionKeys.push(k);
    }
    k.frame = f;
    k.easing = easing || k.easing || "ease_both";
    k.point = Object.assign(Object.assign({ anchor: p.anchor || anchor, x: Number(p.x) || 0, y: Number(p.y) || 0, offsetX: Number(p.offsetX) || 0, offsetY: Number(p.offsetY) || 0 }, (p.foeInvertX != null ? { foeInvertX: !!p.foeInvertX } : {})), (p.foeInvertY != null ? { foeInvertY: !!p.foeInvertY } : {}));
    recalcObjectBounds(o);
    return k;
}
export function movePositionKey(o, id, frame, duration) {
    var k = getPositionKeyById(o, id);
    if (!k)
        return null;
    // A dragged key must land on the exact frame requested by the user.
    // Older builds silently pushed it one frame aside when that frame was
    // occupied, which made timeline edits feel inaccurate and could leave a
    // second, hidden state behind. Collisions are resolved by the editor after
    // the drag, keeping the moved/selected key as the winner.
    var f = Math.round(clampNumber(frame, 0, duration, k.frame));
    k.frame = Math.max(0, Math.min(duration, f));
    recalcObjectBounds(o);
    return k;
}
export function removePositionKey(o, idOrFrame) {
    var ks = sortPositionKeys(o);
    if (ks.length <= 1)
        return false;
    var i = typeof idOrFrame === "string" ? ks.findIndex(function (k) { return k.id === idOrFrame; }) : ks.findIndex(function (k) { return k.frame === Math.round(Number(idOrFrame)); });
    if (i < 0)
        return false;
    ks.splice(i, 1);
    recalcObjectBounds(o);
    return true;
}
export function recalcObjectBounds(o) {
    var ks = sortPositionKeys(o);
    if (!ks.length)
        return;
    o.startFrame = ks[0].frame;
    o.endFrame = Math.max(Number(o.endFrame || 0), ks[ks.length - 1].frame);
}
export function sortValueKeys(o, prop) { var _a; o.valueKeys || (o.valueKeys = {}); (_a = o.valueKeys)[prop] || (_a[prop] = []); o.valueKeys[prop].sort(function (a, b) { return a.frame - b.frame; }); return o.valueKeys[prop]; }
export function setValueKey(o, prop, frame, value, easing) {
    if (easing === void 0) {
        easing = "ease_both";
    }
    var f = Math.max(0, Math.round(Number(frame) || 0));
    var arr = sortValueKeys(o, prop);
    var k = arr.find(function (x) { return x.frame === f; });
    if (!k) {
        k = { id: uid("pkey"), frame: f, value: Number(value), easing: easing };
        arr.push(k);
    }
    k.value = Number(value);
    k.easing = easing || k.easing || "ease_both";
    return k;
}
export function sampleValue(o, prop, frame, fallback) {
    var _a, _b;
    var ks = sortValueKeys(o, prop);
    var base = Number((_b = (_a = o.visual) === null || _a === void 0 ? void 0 : _a[prop]) !== null && _b !== void 0 ? _b : fallback);
    if (!ks.length)
        return base;
    if (frame <= ks[0].frame)
        return ks[0].value;
    if (frame >= ks[ks.length - 1].frame)
        return ks[ks.length - 1].value;
    for (var i = 0; i < ks.length - 1; i++) {
        var a = ks[i], b = ks[i + 1];
        if (frame < a.frame || frame > b.frame)
            continue;
        var t = ease01((frame - a.frame) / Math.max(.0001, b.frame - a.frame), a.easing);
        return a.value + (b.value - a.value) * t;
    }
    return base;
}
export function setVisibleKey(o, frame, value) {
    o.visibleKeys || (o.visibleKeys = []);
    var f = Math.max(0, Math.round(Number(frame) || 0));
    var k = o.visibleKeys.find(function (x) { return x.frame === f; });
    if (!k) {
        k = { id: uid("vkey"), frame: f, value: !!value };
        o.visibleKeys.push(k);
    }
    k.value = !!value;
    o.visibleKeys.sort(function (a, b) { return a.frame - b.frame; });
    return k;
}
export function sampleVisible(o, frame) {
    var e_2, _c;
    var ks = (o.visibleKeys || []).slice().sort(function (a, b) { return a.frame - b.frame; });
    var v = o.enabled !== false;
    try {
        for (var ks_1 = __values(ks), ks_1_1 = ks_1.next(); !ks_1_1.done; ks_1_1 = ks_1.next()) {
            var k = ks_1_1.value;
            if (k.frame > frame)
                break;
            v = !!k.value;
        }
    }
    catch (e_2_1) {
        e_2 = { error: e_2_1 };
    }
    finally {
        try {
            if (ks_1_1 && !ks_1_1.done && (_c = ks_1.return))
                _c.call(ks_1);
        }
        finally {
            if (e_2)
                throw e_2.error;
        }
    }
    return v && o.enabled !== false;
}
function ease01(x, mode) {
    var t = Math.max(0, Math.min(1, x));
    if (mode === "linear")
        return t;
    if (mode === "ease_in")
        return t * t;
    if (mode === "ease_out")
        return 1 - (1 - t) * (1 - t);
    return t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
}
export function normalizeProject(raw) {
    var e_3, _c;
    var _a;
    var _b;
    if (!raw || typeof raw !== "object")
        return createProject();
    if (raw.format && ![FORMAT_ID, "vermeil-battle-animation-studio"].includes(raw.format))
        return createProject();
    var sourceVersion = Number(raw.version || 1), d = defaultPreviewSettings();
    var p = {
        format: FORMAT_ID, version: FORMAT_VERSION,
        preview: deepMerge(d, raw.preview || {}),
        animations: Array.isArray(raw.animations) ? raw.animations : [],
        reusableClips: Array.isArray(raw.reusableClips) ? raw.reusableClips : [],
        packages: Array.isArray(raw.packages) ? raw.packages : [],
        exportGameDataDir: String(raw.exportGameDataDir || SAVE_DIR),
        exportPackageDir: String(raw.exportPackageDir || (SAVE_DIR + "/Exports")),
        editor: { lastAnimationId: ((_a = raw.editor) === null || _a === void 0 ? void 0 : _a.lastAnimationId) || null }
    };
    if (sourceVersion < 4) {
        p.preview.layout.leftWidth = Math.max(235, Number(p.preview.layout.leftWidth || 0));
        p.preview.layout.rightWidth = Math.max(520, Number(p.preview.layout.rightWidth || 0));
        p.preview.layout.timelineHeight = Math.max(390, Number(p.preview.layout.timelineHeight || 0));
    }
    if (sourceVersion < 5 && ["runtime", "script", "manual", "default"].includes(p.preview.contextMode))
        p.preview.contextMode = "auto";
    var oldBattleFormat = String(p.preview.battleFormat || "1v1");
    var battleFormatAliases = { auto: "1v1", single: "1v1", double: "2v2", triple: "3v3" };
    p.preview.battleFormat = battleFormatAliases[oldBattleFormat] || oldBattleFormat;
    if (!/^[123]v[123]$/.test(String(p.preview.battleFormat || "1v1")))
        p.preview.battleFormat = "1v1";
    p.preview.activeUserSlot = clampNumber(p.preview.activeUserSlot, 0, 2, 0);
    p.preview.activeTargetSlot = clampNumber(p.preview.activeTargetSlot, 0, 2, 0);
    p.preview.activeTargetIndex = Number.isFinite(Number(p.preview.activeTargetIndex)) ? Math.max(-1, Math.min(5, Number(p.preview.activeTargetIndex))) : -1;
    p.preview.activeTargetSelectionExplicit = p.preview.activeTargetSelectionExplicit === true;
    // v38 repairs preview-state pollution left by the public battler experiments.
    // Formation changes must start from the canonical first User and first opposing Target;
    // choosing another Target is an explicit per-session action, not a stale global carry-over.
    if (sourceVersion < 38) {
        p.preview.activeUserSlot = 0;
        p.preview.activeTargetSlot = 0;
        p.preview.activeTargetIndex = -1;
        p.preview.activeTargetSelectionExplicit = false;
    }
    // v39: Auto is now strictly project-driven. Keep an explicit Runtime choice,
    // but normalize any obsolete/default aliases back to deterministic Auto.
    if (sourceVersion < 39 && !["auto", "runtime", "script", "manual"].includes(String(p.preview.contextMode || "").toLowerCase()))
        p.preview.contextMode = "auto";
    // Public v1 accidentally persisted AnimBackTest/AnimFrontTest as an implicit default.
    // Through format v33, migrate that implicit pair away. AnimTest remains available only
    // when the user explicitly chooses the optional test preset.
    if (sourceVersion < 34 && !(raw.preview && raw.preview.battlerSelectionExplicit === true)) {
        var oldUser = p.preview.battlers && p.preview.battlers.user || {};
        var oldTarget = p.preview.battlers && p.preview.battlers.target || {};
        var oldPair = /AnimBackTest/i.test(String(oldUser.name || oldUser.projectPath || "")) && /AnimFrontTest/i.test(String(oldTarget.name || oldTarget.projectPath || ""));
        if (oldPair) {
            p.preview.battlers.user = { projectPath: "", folder: "", name: "", label: "" };
            p.preview.battlers.target = { projectPath: "", folder: "", name: "", label: "" };
        }
    }
    p.preview.battlerSelectionExplicit = p.preview.battlerSelectionExplicit === true;
    if (!p.preview.battlerSizeManual || typeof p.preview.battlerSizeManual !== "object")
        p.preview.battlerSizeManual = { player: false, foe: false };
    p.preview.battlerSizeManual.player = p.preview.battlerSizeManual.player === true;
    p.preview.battlerSizeManual.foe = p.preview.battlerSizeManual.foe === true;
    p.preview.autosaveEnabled = p.preview.autosaveEnabled !== false;
    p.preview.autosaveDelaySeconds = clampNumber(p.preview.autosaveDelaySeconds, 1, 60, 3.5);
    if (sourceVersion < 25) {
        var fm = String(p.preview.battleFormat || "1v1").match(/^([123])v([123])$/) || [null, "1", "1"];
        if (Number(fm[1]) > 1 && Number(p.preview.activeUserSlot || 0) === 0)
            p.preview.activeUserSlot = 1;
        if (Number(fm[2]) > 1 && Number(p.preview.activeTargetSlot || 0) === 0)
            p.preview.activeTargetSlot = 1;
    }
    if (sourceVersion < 10) {
        (_b = p.preview).scene || (_b.scene = {});
        if (!p.preview.scene.background)
            p.preview.scene.background = "Graphics/Battlebacks/indoor1_bg.png";
        if (!p.preview.scene.playerBase)
            p.preview.scene.playerBase = "Graphics/Battlebacks/indoor1_base0.png";
        if (!p.preview.scene.enemyBase)
            p.preview.scene.enemyBase = "Graphics/Battlebacks/indoor1_base1.png";
    }
    if (sourceVersion < 13) {
        var oldScale = raw.preview && raw.preview.battlerScale != null ? raw.preview.battlerScale : (raw.preview && raw.preview.testBattlerScale != null ? raw.preview.testBattlerScale : 1);
        p.preview.battlerScale = clampNumber(oldScale, 1, 8, 1);
    }
    // Remove the legacy global battler inspection multiplier. Gameplay has no
    // equivalent global zoom: battler presentation comes from the selected
    // renderer profile (DBK project scales or Native/Gen 4 x1/x1), Pokémon
    // Metrics and the animation's own Size/Scale/ViewScale channels.
    p.preview.battlerScale = 1;
    p.preview.testBattlerScale = 1;
    p.preview.playerBattlerSize = clampNumber(p.preview.playerBattlerSize, 0, 8, 0);
    p.preview.foeBattlerSize = clampNumber(p.preview.foeBattlerSize, 0, 8, 0);
    // Player/Foe values are explicit view-profile overrides only. Auto reads the
    // renderer from the project: this project uses DBK Back x3 / Front x2, while
    // Native/Gen 4 is x1/x1. The migration below only clears stale implicit public
    // defaults; a value explicitly authored by the user is preserved.
    // v33: the public v1 branch exposed x3/x2 (or x1/x1) as if they were generic
    // Player/Foe sizes. Those values were presentation defaults, not authored animation data.
    // If an older project did not explicitly mark a manual size, return it to Auto so the
    // selected game battler, PBS metrics and live renderer decide its presentation.
    if (sourceVersion < 33) {
        var rawManual = raw.preview && raw.preview.battlerSizeManual;
        if (!(rawManual && rawManual.player === true)) {
            p.preview.playerBattlerSize = 0;
            p.preview.battlerSizeManual.player = false;
        }
        if (!(rawManual && rawManual.foe === true)) {
            p.preview.foeBattlerSize = 0;
            p.preview.battlerSizeManual.foe = false;
        }
    }
    // v36: preserve any side scale the user actually set. Older public builds
    // sometimes lost the "manual" flag while keeping a non-zero Player/Foe value.
    // A non-zero saved value is authoritative and must survive changing battlers.
    if (sourceVersion < 36) {
        if (Number(p.preview.playerBattlerSize || 0) > 0)
            p.preview.battlerSizeManual.player = true;
        if (Number(p.preview.foeBattlerSize || 0) > 0)
            p.preview.battlerSizeManual.foe = true;
    }
    p.preview.battlerScalePreset = ["auto", "dbk", "gen4", "custom"].includes(String(p.preview.battlerScalePreset || "").toLowerCase())
        ? String(p.preview.battlerScalePreset).toLowerCase()
        : ((p.preview.battlerSizeManual.player || p.preview.battlerSizeManual.foe) ? "custom" : "auto");
    // Keep the old field only as a migration alias for projects saved by 1.8.0-1.8.4.
    p.preview.testBattlerScale = 1;
    p.preview.language = ["es", "en"].includes(String(p.preview.language || "es").toLowerCase()) ? String(p.preview.language || "es").toLowerCase() : "es";
    try {
        for (var _d = __values(p.animations), _e = _d.next(); !_e.done; _e = _d.next()) {
            var a = _e.value;
            normalizeAnimation(a);
        }
    }
    catch (e_3_1) {
        e_3 = { error: e_3_1 };
    }
    finally {
        try {
            if (_e && !_e.done && (_c = _d.return))
                _c.call(_d);
        }
        finally {
            if (e_3)
                throw e_3.error;
        }
    }
    return p;
}
function emitterRequiredEnd(c) {
    var e_4, _c, e_5, _d, e_6, _e;
    var pbs = c && c.pbs ? c.pbs : {};
    var type = String(pbs.emitter || pbs.emitterType || "none").toLowerCase().replace(/[^a-z]/g, "");
    if (!type || type === "none")
        return 0;
    var ec = pbs.emitterCommands || {};
    var emitting = Array.isArray(ec.emitting) ? ec.emitting.slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); }) : [];
    if (!emitting.length)
        return 0;
    var active = false, lastStop = 0, lastStart = 0;
    try {
        for (var emitting_1 = __values(emitting), emitting_1_1 = emitting_1.next(); !emitting_1_1.done; emitting_1_1 = emitting_1.next()) {
            var cmd = emitting_1_1.value;
            var f = Math.max(0, Number(cmd.frame || 0));
            if (!!cmd.value) {
                active = true;
                lastStart = f;
                lastStop = Math.max(lastStop, f);
            }
            else if (active) {
                active = false;
                lastStop = Math.max(lastStop, f);
            }
        }
    }
    catch (e_4_1) {
        e_4 = { error: e_4_1 };
    }
    finally {
        try {
            if (emitting_1_1 && !emitting_1_1.done && (_c = emitting_1.return))
                _c.call(emitting_1);
        }
        finally {
            if (e_4)
                throw e_4.error;
        }
    }
    if (active)
        lastStop = Math.max(lastStop, lastStart);
    var maxEmitterValue = function (name, fallback) {
        var list = Array.isArray(ec[name]) ? ec[name] : [];
        var values = list.map(function (x) { return Number(x.value || 0); }).filter(Number.isFinite);
        return values.length ? Math.max.apply(Math, __spreadArray([], __read(values), false)) : Number(fallback || 0);
    };
    var tail = 0;
    if (type === "energyin" || type === "energyout")
        tail = Math.max(1, maxEmitterValue("energyTravelFrames", pbs.energyTravelFrames || 16)) + 4;
    else if (type === "drain")
        tail = Math.max(1, maxEmitterValue("drainTravelFrames", pbs.drainTravelFrames || 14)) + 4;
    else {
        var commands = pbs.commands || {};
        var first = Infinity, last = -Infinity;
        try {
            for (var _f = __values(Object.values(commands)), _g = _f.next(); !_g.done; _g = _f.next()) {
                var list = _g.value;
                if (!Array.isArray(list))
                    continue;
                try {
                    for (var list_1 = (e_6 = void 0, __values(list)), list_1_1 = list_1.next(); !list_1_1.done; list_1_1 = list_1.next()) {
                        var cmd = list_1_1.value;
                        var f = Number(cmd.frame || 0), e = f + Number(cmd.duration || 0);
                        if (Number.isFinite(f))
                            first = Math.min(first, f);
                        if (Number.isFinite(e))
                            last = Math.max(last, e);
                    }
                }
                catch (e_6_1) {
                    e_6 = { error: e_6_1 };
                }
                finally {
                    try {
                        if (list_1_1 && !list_1_1.done && (_e = list_1.return))
                            _e.call(list_1);
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
                if (_g && !_g.done && (_d = _f.return))
                    _d.call(_f);
            }
            finally {
                if (e_5)
                    throw e_5.error;
            }
        }
        if (Number.isFinite(first) && Number.isFinite(last))
            tail = Math.max(0, last - first);
    }
    return Math.max(0, lastStop + tail);
}
function normalizeAnimation(a) {
    var e_7, _c, e_8, _d, e_9, _e;
    a.id || (a.id = uid("anim"));
    a.name || (a.name = "Animation");
    a.fps = clampNumber(a.fps, 1, 120, 20);
    a.duration = clampNumber(a.duration, 1, 9999, 30);
    a.source = Object.assign({ type: "studio", move: null, version: 0, catalogType: "move", opposing: false, sideContext: "player", targetMode: "foe", targetScope: "single_foe", allowedTargetScopes: [], variantScope: "auto", customSpace: "battlers", detectedTraits: [], detectedFunctionCode: "", detectedCategory: "", detectedTarget: "", contextAutoAdapt: true, previewAffectedTargets: true, autoReplicateAffected: true, activeTimelineContext: null, askBackupOnContextEdit: false, autoReplicateTouched: false, commonSubjectRole: "auto", authors: [] }, (a.source || {}));
    if (typeof a.source.authors === "string") a.source.authors = a.source.authors.split(/[,;]+/).map(function (x) { return x.trim(); }).filter(Boolean);
    if (!Array.isArray(a.source.authors)) a.source.authors = a.source.author ? [String(a.source.author)] : [];
    a.source.authors = a.source.authors.map(function (x) { return String(x || "").trim(); }).filter(Boolean);
    if (!["move", "common", "custom"].includes(String(a.source.catalogType || "move")))
        a.source.catalogType = "move";
    if (!a.source.targetMode)
        a.source.targetMode = a.source.opposing || a.source.sideContext === "foe" ? "player" : "foe";
    if (!["auto", "single_foe", "multiple_foes", "single_other", "adjacent_others", "single_user", "multiple_users", "all_battlers", "environment"].includes(String(a.source.targetScope || "single_foe")))
        a.source.targetScope = "single_foe";
    if (a.source.targetScope === "single_foe" && a.source.targetMode === "player")
        a.source.targetScope = "single_user";
    else if (a.source.targetScope === "single_foe" && a.source.targetMode === "both")
        a.source.targetScope = "all_battlers";
    else if (a.source.targetScope === "single_foe" && a.source.targetMode === "environment")
        a.source.targetScope = "environment";
    a.source.allowedTargetScopes = Array.isArray(a.source.allowedTargetScopes) ? a.source.allowedTargetScopes : [];
    if (!["auto", "physical", "special", "both", "status"].includes(String(a.source.variantScope || "auto")))
        a.source.variantScope = "auto";
    if (!["battlers", "screen", "field", "ui", "overlay"].includes(String(a.source.customSpace || "battlers")))
        a.source.customSpace = "battlers";
    a.source.detectedTraits = Array.isArray(a.source.detectedTraits) ? a.source.detectedTraits : [];
    a.source.contextAutoAdapt = a.source.contextAutoAdapt !== false;
    a.source.previewAffectedTargets = a.source.previewAffectedTargets === true;
    a.source.autoReplicateAffected = a.source.autoReplicateAffected === true;
    a.source.autoReplicateTouched = a.source.autoReplicateTouched === true;
    a.source.runtimeSelected = a.source.runtimeSelected === true;
    a.source.askBackupOnContextEdit = a.source.askBackupOnContextEdit === true;
    if (!["auto", "user", "target", "both", "none"].includes(String(a.source.commonSubjectRole || "auto")))
        a.source.commonSubjectRole = "auto";
    a.source.activeTimelineContext = a.source.activeTimelineContext && typeof a.source.activeTimelineContext === "object" ? a.source.activeTimelineContext : null;
    a.contextTimelines = Array.isArray(a.contextTimelines) ? a.contextTimelines.filter(function (v) { return v && typeof v === "object" && v.snapshot && typeof v.snapshot === "object"; }).map(function (v) {
        return ({
            id: String(v.id || uid("ctxver")),
            key: String(v.key || ""),
            label: String(v.label || v.key || "Context"),
            savedAt: v.savedAt || null,
            context: v.context && typeof v.context === "object" ? v.context : {},
            snapshot: v.snapshot
        });
    }) : [];
    a.battlers || (a.battlers = {});
    a.battlers.user = normalizeBattler(a.battlers.user, "user", a.duration);
    a.battlers.target = normalizeBattler(a.battlers.target, "target", a.duration);
    a.camera = normalizeCamera(a.camera, a.duration);
    if (!Array.isArray(a.tracks))
        a.tracks = [];
    var t = getEffectsTrack(a);
    if (!Array.isArray(t.clips))
        t.clips = [];
    try {
        for (var _f = __values(t.clips), _g = _f.next(); !_g.done; _g = _f.next()) {
            var c = _g.value;
            normalizeClip(c, a.duration);
        }
    }
    catch (e_7_1) {
        e_7 = { error: e_7_1 };
    }
    finally {
        try {
            if (_g && !_g.done && (_c = _f.return))
                _c.call(_f);
        }
        finally {
            if (e_7)
                throw e_7.error;
        }
    }
    // New Animation Editor keeps an emitter animation alive until the newest
    // particle can finish its local commands. Older BAS projects only stored
    // the emission stop frame, which could cut the last particles in gameplay.
    var emitterEnd = 0;
    try {
        for (var _h = __values(t.clips), _j = _h.next(); !_j.done; _j = _h.next()) {
            var c = _j.value;
            emitterEnd = Math.max(emitterEnd, emitterRequiredEnd(c));
        }
    }
    catch (e_8_1) {
        e_8 = { error: e_8_1 };
    }
    finally {
        try {
            if (_j && !_j.done && (_d = _h.return))
                _d.call(_h);
        }
        finally {
            if (e_8)
                throw e_8.error;
        }
    }
    if (emitterEnd > a.duration)
        a.duration = clampNumber(Math.ceil(emitterEnd), 1, 9999, a.duration);
    try {
        for (var _k = __values(t.clips), _l = _k.next(); !_l.done; _l = _k.next()) {
            var c = _l.value;
            var end = emitterRequiredEnd(c);
            if (end > 0)
                c.endFrame = Math.max(Number(c.endFrame || 0), Math.ceil(end));
        }
    }
    catch (e_9_1) {
        e_9 = { error: e_9_1 };
    }
    finally {
        try {
            if (_l && !_l.done && (_e = _k.return))
                _e.call(_k);
        }
        finally {
            if (e_9)
                throw e_9.error;
        }
    }
    a.events = Array.isArray(a.events) ? a.events : [];
    a.logic = Array.isArray(a.logic) ? a.logic : [];
    a.hidesDataBoxes = !!a.hidesDataBoxes;
    a.hidesAdjacents = !!a.hidesAdjacents;
    a.scene = Object.assign({ inheritProject: true, source: "project", responsive: true, referenceWidth: 0, referenceHeight: 0, cameraBoundsMode: "auto" }, (a.scene || {}));
    a.scene.cameraBoundsMode = ["auto", "screen", "extended"].includes(String(a.scene.cameraBoundsMode || "auto")) ? String(a.scene.cameraBoundsMode || "auto") : "auto";
    if (a.scene.source === "project")
        a.scene.inheritProject = true;
}
function normalizeBattler(b, side, d) { var base = createBattlerTrack(side), out = deepMerge(base, b || {}); out.formRules = Array.isArray(out.formRules) ? out.formRules.map(function (r) { return ({ frame: clampNumber(r && r.frame, 0, d, 0), species: String((r && r.species) || "").trim().toUpperCase(), form: Math.max(0, Math.round(Number((r && r.form) || 0))) }); }).filter(function (r) { return r.species; }) : []; normalizeAnimatable(out, d); return out; }
function normalizeCamera(c, d) { var out = deepMerge(createCameraTrack(), c || {}); normalizeAnimatable(out, d); return out; }
function normalizeClip(c, d) {
    var base = createProjectile(), original = c || {}, out = deepMerge(base, original);
    Object.keys(c || {}).forEach(function (k) { return delete c[k]; });
    Object.assign(c, out);
    normalizeAnimatable(c, d);
    c.type = original.type || c.type || "projectile";
    c.priority = clampNumber(c.priority, -9999, 9999, 0);
    c.priorityReference = ["auto", "user", "target", "foreground", "background", "absolute"].includes(String(c.priorityReference || "auto")) ? String(c.priorityReference || "auto") : "auto";
    c.replicateTo = ["none", "affected", "target_adjacents", "user_adjacents", "all_adjacents"].includes(String(c.replicateTo || "none")) ? String(c.replicateTo || "none") : "none";
    c.coordinateSpace = ["auto", "screen", "user", "target"].includes(String(c.coordinateSpace || "auto")) ? String(c.coordinateSpace || "auto") : "auto";
    c.coordinateSpaceManual = c.coordinateSpaceManual === true;
    c.graphicSwitches = Array.isArray(c.graphicSwitches) ? c.graphicSwitches.map(function (sw) { return (Object.assign(Object.assign({}, sw), { id: (sw && sw.id) || uid("gkey"), frame: clampNumber(sw && sw.frame, 0, d, 0), value: String((sw && (sw.value || sw.projectPath)) || ""), projectPath: String((sw && (sw.projectPath || sw.value)) || ""), source: String((sw && sw.source) || "legacy"), name: String((sw && sw.name) || "") })); }).filter(function (sw) { return sw.value; }).sort(function (a, b) { return a.frame - b.frame; }) : [];
    if (c.graphicSwitches.length) {
        c.startFrame = Math.min(Number(c.startFrame || 0), Number(c.graphicSwitches[0].frame || 0));
        c.endFrame = Math.max(Number(c.endFrame || 0), Number(c.graphicSwitches[c.graphicSwitches.length - 1].frame || 0));
    }
    c.fxOps = Array.isArray(c.fxOps) ? c.fxOps : [];
    c.logic = Array.isArray(c.logic) ? c.logic : [];
}
function normalizeAnimatable(o, d) {
    var e_10, _c;
    var _a;
    o.id || (o.id = uid("obj"));
    o.name || (o.name = "Object");
    o.enabled = o.enabled !== false;
    o.locked = o.locked === true;
    o.visual || (o.visual = {});
    o.visual.size = clampNumber(o.visual.size, 1, 1600, 100);
    o.visual.scaleX = clampNumber(o.visual.scaleX, -1600, 1600, 100);
    o.visual.scaleY = clampNumber(o.visual.scaleY, -1600, 1600, 100);
    o.visual.opacity = clampNumber(o.visual.opacity, 0, 100, 100);
    o.visual.rotation = Number(o.visual.rotation || 0);
    o.visual.z = Number(o.visual.z || 0);
    o.visual.blend = Number(o.visual.blend || 0);
    o.visual.flip = Number(o.visual.flip || 0);
    o.valueKeys = Object.assign(Object.assign({}, defaultValueKeys()), (o.valueKeys || {}));
    o.visibleKeys = Array.isArray(o.visibleKeys) && o.visibleKeys.length ? o.visibleKeys : [{ id: uid("vkey"), frame: 0, value: true }];
    if (!Array.isArray(o.positionKeys) || !o.positionKeys.length)
        o.positionKeys = [{ id: uid("key"), frame: 0, easing: "ease_both", point: point("screen", 256, 192) }];
    try {
        for (var _d = __values(o.positionKeys), _e = _d.next(); !_e.done; _e = _d.next()) {
            var k = _e.value;
            k.id || (k.id = uid("key"));
            k.frame = clampNumber(k.frame, 0, d, 0);
            k.easing || (k.easing = "ease_both");
            k.point || (k.point = point());
            (_a = k.point).anchor || (_a.anchor = "screen");
        }
    }
    catch (e_10_1) {
        e_10 = { error: e_10_1 };
    }
    finally {
        try {
            if (_e && !_e.done && (_c = _d.return))
                _c.call(_d);
        }
        finally {
            if (e_10)
                throw e_10.error;
        }
    }
    o.fxOps = Array.isArray(o.fxOps) ? o.fxOps : [];
    o.logic = Array.isArray(o.logic) ? o.logic : [];
    recalcObjectBounds(o);
}
export function cloneClipForLibrary(clip, name) {
    if (name === void 0) {
        name = (clip === null || clip === void 0 ? void 0 : clip.name) || "Clip";
    }
    var c = structuredCloneSafe(clip);
    c.id = uid("cliplib");
    c.name = name;
    return c;
}
export function instantiateReusableClip(saved) {
    var e_11, _c, e_12, _d, e_13, _e, e_14, _f, e_15, _g;
    var c = structuredCloneSafe(saved);
    c.id = uid("clip");
    try {
        for (var _h = __values(c.positionKeys || []), _j = _h.next(); !_j.done; _j = _h.next()) {
            var k = _j.value;
            k.id = uid("key");
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
    try {
        for (var _k = __values(Object.values(c.valueKeys || {})), _l = _k.next(); !_l.done; _l = _k.next()) {
            var arr = _l.value;
            try {
                for (var _m = (e_13 = void 0, __values(arr || [])), _o = _m.next(); !_o.done; _o = _m.next()) {
                    var k = _o.value;
                    k.id = uid("pkey");
                }
            }
            catch (e_13_1) {
                e_13 = { error: e_13_1 };
            }
            finally {
                try {
                    if (_o && !_o.done && (_e = _m.return))
                        _e.call(_m);
                }
                finally {
                    if (e_13)
                        throw e_13.error;
                }
            }
        }
    }
    catch (e_12_1) {
        e_12 = { error: e_12_1 };
    }
    finally {
        try {
            if (_l && !_l.done && (_d = _k.return))
                _d.call(_k);
        }
        finally {
            if (e_12)
                throw e_12.error;
        }
    }
    try {
        for (var _p = __values(c.visibleKeys || []), _q = _p.next(); !_q.done; _q = _p.next()) {
            var k = _q.value;
            k.id = uid("vkey");
        }
    }
    catch (e_14_1) {
        e_14 = { error: e_14_1 };
    }
    finally {
        try {
            if (_q && !_q.done && (_f = _p.return))
                _f.call(_p);
        }
        finally {
            if (e_14)
                throw e_14.error;
        }
    }
    try {
        for (var _r = __values(c.graphicSwitches || []), _s = _r.next(); !_s.done; _s = _r.next()) {
            var k = _s.value;
            k.id = uid("gkey");
        }
    }
    catch (e_15_1) {
        e_15 = { error: e_15_1 };
    }
    finally {
        try {
            if (_s && !_s.done && (_g = _r.return))
                _g.call(_r);
        }
        finally {
            if (e_15)
                throw e_15.error;
        }
    }
    return c;
}
