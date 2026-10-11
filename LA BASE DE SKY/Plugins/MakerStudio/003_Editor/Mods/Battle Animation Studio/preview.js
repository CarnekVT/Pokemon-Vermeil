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
import { getAllClips, getAnimatable, getBattlerTrack, getCameraTrack, sortPositionKeys, sampleValue, sampleVisible } from "./model.js";
import { fallbackBattleContext } from "./context.js";
var EMITTER_KEY_ALIASES = {
    emitAngle: ["emitDirection", "direction", "moveEmitAngle", "moveEmitDirection"],
    emitDirection: ["emitAngle", "direction", "moveEmitAngle", "moveEmitDirection"],
    direction: ["emitDirection", "emitAngle"],
    emitAngleRange: ["emitDirectionRange", "directionRange", "moveEmitAngleRange", "moveEmitDirectionRange"],
    emitDirectionRange: ["emitAngleRange", "directionRange", "moveEmitAngleRange", "moveEmitDirectionRange"],
    directionRange: ["emitDirectionRange", "emitAngleRange"],
    emitSpeed: ["speed", "moveEmitSpeed"],
    speed: ["emitSpeed", "moveEmitSpeed"],
    emitSpeedRange: ["speedRange", "moveEmitSpeedRange"],
    speedRange: ["emitSpeedRange", "moveEmitSpeedRange"],
    emitGravity: ["gravity", "moveEmitGravity"],
    gravity: ["emitGravity", "moveEmitGravity"],
    emitGravityRange: ["gravityRange", "moveEmitGravityRange"],
    gravityRange: ["emitGravityRange", "moveEmitGravityRange"],
    emitDeceleration: ["deceleration", "moveEmitDeceleration"],
    deceleration: ["emitDeceleration", "moveEmitDeceleration"],
    emitDecelerationRange: ["decelerationRange", "moveEmitDecelerationRange"],
    decelerationRange: ["emitDecelerationRange", "moveEmitDecelerationRange"],
    emitX: ["spawnX", "moveSpawnX", "moveEmitX"],
    spawnX: ["emitX", "moveSpawnX", "moveEmitX"],
    emitXRange: ["spawnXRange", "moveSpawnXRange", "moveEmitXRange"],
    spawnXRange: ["emitXRange", "moveSpawnXRange", "moveEmitXRange"],
    emitY: ["spawnY", "moveSpawnY", "moveEmitY"],
    spawnY: ["emitY", "moveSpawnY", "moveEmitY"],
    emitYRange: ["spawnYRange", "moveSpawnYRange", "moveEmitYRange"],
    spawnYRange: ["emitYRange", "moveSpawnYRange", "moveEmitYRange"],
    emitR: ["spawnR", "moveSpawnR", "moveEmitR"],
    spawnR: ["emitR", "moveSpawnR", "moveEmitR"],
    emitRRange: ["spawnRRange", "moveSpawnRRange", "moveEmitRRange"],
    spawnRRange: ["emitRRange", "moveSpawnRRange", "moveEmitRRange"],
    emitTheta: ["spawnTheta", "moveSpawnTheta", "moveEmitTheta"],
    spawnTheta: ["emitTheta", "moveSpawnTheta", "moveEmitTheta"],
    emitThetaRange: ["spawnThetaRange", "moveSpawnThetaRange", "moveEmitThetaRange"],
    spawnThetaRange: ["emitThetaRange", "moveSpawnThetaRange", "moveEmitThetaRange"],
    particleSize: ["emitZoomMultiplier", "zoomMultiplier", "moveEmitZoomMultiplier"],
    emitZoomMultiplier: ["particleSize", "zoomMultiplier", "moveEmitZoomMultiplier"],
    zoomMultiplier: ["particleSize", "emitZoomMultiplier"],
    particleSizeRange: ["emitZoomRange", "zoomRange", "moveEmitZoomRange"],
    emitZoomRange: ["particleSizeRange", "zoomRange", "moveEmitZoomRange"],
    zoomRange: ["particleSizeRange", "emitZoomRange"],
    emitZoomXRange: ["zoomXRange", "moveEmitZoomXRange"],
    zoomXRange: ["emitZoomXRange", "moveEmitZoomXRange"],
    emitZoomYRange: ["zoomYRange", "moveEmitZoomYRange"],
    zoomYRange: ["emitZoomYRange", "moveEmitZoomYRange"],
    emitPeriodX: ["periodX", "movePeriodX", "moveEmitPeriodX"],
    periodX: ["emitPeriodX", "movePeriodX", "moveEmitPeriodX"],
    emitPeriodXRange: ["periodXRange", "movePeriodXRange", "moveEmitPeriodXRange"],
    periodXRange: ["emitPeriodXRange", "movePeriodXRange", "moveEmitPeriodXRange"],
    emitPeriodY: ["periodY", "movePeriodY", "moveEmitPeriodY"],
    periodY: ["emitPeriodY", "movePeriodY", "moveEmitPeriodY"],
    emitPeriodYRange: ["periodYRange", "movePeriodYRange", "moveEmitPeriodYRange"],
    periodYRange: ["emitPeriodYRange", "movePeriodYRange", "moveEmitPeriodYRange"],
    emitPeriodZ: ["periodZ", "movePeriodZ", "moveEmitPeriodZ"],
    periodZ: ["emitPeriodZ", "movePeriodZ", "moveEmitPeriodZ"],
    emitPeriodZRange: ["periodZRange", "movePeriodZRange", "moveEmitPeriodZRange"],
    periodZRange: ["emitPeriodZRange", "movePeriodZRange", "moveEmitPeriodZRange"],
    emitRadiusXRange: ["radiusXRange", "moveRadiusXRange", "moveEmitRadiusXRange"],
    radiusXRange: ["emitRadiusXRange", "moveRadiusXRange", "moveEmitRadiusXRange"],
    emitRadiusYRange: ["radiusYRange", "moveRadiusYRange", "moveEmitRadiusYRange"],
    radiusYRange: ["emitRadiusYRange", "moveRadiusYRange", "moveEmitRadiusYRange"],
    emitRadiusZRange: ["radiusZRange", "moveRadiusZRange", "moveEmitRadiusZRange"],
    radiusZRange: ["emitRadiusZRange", "moveRadiusZRange", "moveEmitRadiusZRange"],
    emitClockwise: ["clockwise", "moveEmitClockwise", "moveClockwise"],
    clockwise: ["emitClockwise", "moveEmitClockwise", "moveClockwise"],
    emitXMultiplier: ["xMultiplier"],
    xMultiplier: ["emitXMultiplier"],
    emitYMultiplier: ["yMultiplier"],
    yMultiplier: ["emitYMultiplier"],
    emitOpacityMultiplier: ["opacityMultiplier"],
    opacityMultiplier: ["emitOpacityMultiplier"]
};
var clamp = function (v, min, max) { return Math.max(min, Math.min(max, v)); };
var lerp = function (a, b, t) { return a + (b - a) * t; };
var ease = function (t, m) {
    var x = clamp(t, 0, 1);
    if (m === "linear")
        return x;
    if (m === "ease_in")
        return x * x;
    if (m === "ease_out")
        return 1 - (1 - x) * (1 - x);
    return x < .5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
};
var css = function (n, f) { return getComputedStyle(document.documentElement).getPropertyValue(n).trim() || f; };
var hash32 = function (s) {
    var e_1, _q;
    var h = 2166136261 >>> 0;
    try {
        for (var _r = __values(String(s)), _s = _r.next(); !_s.done; _s = _r.next()) {
            var c = _s.value;
            h ^= c.charCodeAt(0);
            h = Math.imul(h, 16777619);
        }
    }
    catch (e_1_1) {
        e_1 = { error: e_1_1 };
    }
    finally {
        try {
            if (_s && !_s.done && (_q = _r.return))
                _q.call(_r);
        }
        finally {
            if (e_1)
                throw e_1.error;
        }
    }
    return h >>> 0;
};
var seeded = function (seed) { var x = seed >>> 0; return function () { x ^= x << 13; x ^= x >>> 17; x ^= x << 5; return ((x >>> 0) % 1000000) / 1000000; }; };
function parseHexColor(raw, tone) {
    if (tone === void 0) {
        tone = false;
    }
    var s = String(raw || "").trim();
    if (tone) {
        var m = s.match(/^([+-]\d+)([+-]\d+)([+-]\d+)([+-]\d+)$/);
        if (m)
            return { r: Number(m[1]), g: Number(m[2]), b: Number(m[3]), a: Number(m[4]) };
    }
    var h = s.replace(/^#/, '');
    if (/^[0-9a-f]{8}$/i.test(h))
        return { r: parseInt(h.slice(0, 2), 16), g: parseInt(h.slice(2, 4), 16), b: parseInt(h.slice(4, 6), 16), a: parseInt(h.slice(6, 8), 16) };
    return { r: 0, g: 0, b: 0, a: 0 };
}
var BattlePreview = /** @class */ (function () {
    function BattlePreview(canvas, callbacks) {
        if (callbacks === void 0) {
            callbacks = {};
        }
        var _this = this;
        this.canvas = canvas;
        this.ctx = canvas.getContext("2d");
        this.callbacks = callbacks;
        this.animation = null;
        this.selectedObjectId = null;
        this.frame = 0;
        this.playing = false;
        this.onionMode = "off";
        this.emitterEditMode = "particle";
        this.emitterSoloPreview = false;
        this.previewSideOverride = "auto";
        this.previewSideAnimationId = null;
        this.battlerScale = 1;
        this.testBattlerScale = 1;
        this.playerBattlerSize = 0;
        this.foeBattlerSize = 0;
        this.context = fallbackBattleContext();
        this.replicaUserOverride = null;
        this.replicaTargetOverride = null;
        this.images = { user: null, target: null, userFront: null, userBack: null, targetFront: null, targetBack: null };
        this.urls = {};
        this.battlerMeta = { user: {}, target: {}, userFront: {}, userBack: {}, targetFront: {}, targetBack: {} };
        this.contextBattlerImages = new Map();
        this.contextBattlerUrls = new Map();
        this.contextBattlerMeta = new Map();
        this.clipImages = new Map();
        this.maskImages = new Map();
        this.sceneImages = { background: null, playerBase: null, enemyBase: null };
        this.sceneUrls = {};
        this.fxCache = new Map();
        this.dpr = Math.max(1, window.devicePixelRatio || 1);
        this.lastTransform = null;
        this.hitShapes = [];
        this.dragging = null;
        this.dragStart = null;
        this.editFrame = 0;
        this._pd = function (e) { return _this.pointerDown(e); };
        this._pm = function (e) { return _this.pointerMove(e); };
        this._pu = function (e) { return _this.pointerUp(e); };
        this._cm = function (e) { return e.preventDefault(); };
        this._wh = function (e) { return _this.wheel(e); };
        canvas.addEventListener("pointerdown", this._pd);
        window.addEventListener("pointermove", this._pm);
        window.addEventListener("pointerup", this._pu);
        canvas.addEventListener("contextmenu", this._cm);
        canvas.addEventListener("wheel", this._wh, { passive: false });
        this.resizeObserver = new ResizeObserver(function () { return _this.draw(); });
        this.resizeObserver.observe(canvas);
    }
    BattlePreview.prototype.setEmitterEditMode = function (mode) {
        this.emitterEditMode = String(mode || "particle") === "emission" ? "emission" : "particle";
        this.draw();
    };
    BattlePreview.prototype.setEmitterSoloPreview = function (enabled) {
        this.emitterSoloPreview = !!enabled;
        this.draw();
    };
    BattlePreview.prototype.destroy = function () {
        var e_2, _q, e_3, _r, e_4, _s;
        this.canvas.removeEventListener("pointerdown", this._pd);
        window.removeEventListener("pointermove", this._pm);
        window.removeEventListener("pointerup", this._pu);
        this.canvas.removeEventListener("contextmenu", this._cm);
        this.canvas.removeEventListener("wheel", this._wh);
        this.resizeObserver.disconnect();
        try {
            for (var _t = __values(Object.values(this.urls)), _u = _t.next(); !_u.done; _u = _t.next()) {
                var u = _u.value;
                if (u)
                    URL.revokeObjectURL(u);
            }
        }
        catch (e_2_1) {
            e_2 = { error: e_2_1 };
        }
        finally {
            try {
                if (_u && !_u.done && (_q = _t.return))
                    _q.call(_t);
            }
            finally {
                if (e_2)
                    throw e_2.error;
            }
        }
        try {
            for (var _v = __values(Object.values(this.sceneUrls)), _w = _v.next(); !_w.done; _w = _v.next()) {
                var u = _w.value;
                if (u)
                    URL.revokeObjectURL(u);
            }
        }
        catch (e_3_1) {
            e_3 = { error: e_3_1 };
        }
        finally {
            try {
                if (_w && !_w.done && (_r = _v.return))
                    _r.call(_v);
            }
            finally {
                if (e_3)
                    throw e_3.error;
            }
        }
        try {
            for (var _x = __values(__spreadArray(__spreadArray([], __read(this.clipImages.values()), false), __read(this.maskImages.values()), false)), _y = _x.next(); !_y.done; _y = _x.next()) {
                var r = _y.value;
                if (r === null || r === void 0 ? void 0 : r.url)
                    URL.revokeObjectURL(r.url);
            }
            this.contextBattlerUrls.forEach(function (u) { if (u) URL.revokeObjectURL(u); });
            this.contextBattlerImages.clear();
            this.contextBattlerUrls.clear();
            this.contextBattlerMeta.clear();
        }
        catch (e_4_1) {
            e_4 = { error: e_4_1 };
        }
        finally {
            try {
                if (_y && !_y.done && (_s = _x.return))
                    _s.call(_x);
            }
            finally {
                if (e_4)
                    throw e_4.error;
            }
        }
    };
    BattlePreview.prototype.setState = function (animation, selectedObjectId, frame, _q) {
        var _r = _q === void 0 ? {} : _q, _s = _r.playing, playing = _s === void 0 ? this.playing : _s;
        var nextAnimationId = animation && animation.id != null ? String(animation.id) : null;
        if (this.previewSideAnimationId !== nextAnimationId) {
            this.previewSideAnimationId = nextAnimationId;
            this.previewSideOverride = "auto";
        }
        this.animation = animation;
        this.selectedObjectId = selectedObjectId;
        this.frame = Number(frame) || 0;
        this.playing = !!playing;
        this.draw();
    };
    BattlePreview.prototype.setPreviewSide = function (side) {
        if (side === void 0) {
            side = "auto";
        }
        this.previewSideOverride = ["auto", "player", "foe"].includes(String(side)) ? String(side) : "auto";
        this.draw();
    };
    BattlePreview.prototype.setBattlerScale = function (value) {
        if (value === void 0) {
            value = 1;
        }
        var n = Number(value);
        this.battlerScale = Number.isFinite(n) ? Math.max(0.25, Math.min(8, n)) : 1;
        this.testBattlerScale = this.battlerScale;
        this.draw();
    };
    BattlePreview.prototype.setTestBattlerScale = function (value) {
        if (value === void 0) {
            value = 1;
        }
        this.setBattlerScale(value);
    };
    BattlePreview.prototype.setBattlerSizes = function (player, foe) {
        if (player === void 0) {
            player = 0;
        }
        if (foe === void 0) {
            foe = 0;
        }
        var clean = function (v) { var n = Number(v); return Number.isFinite(n) && n > 0 ? Math.max(.25, Math.min(8, n)) : 0; };
        this.playerBattlerSize = clean(player);
        this.foeBattlerSize = clean(foe);
        this.draw();
    };
    BattlePreview.prototype.resolveBattlerScale = function (detectedScale, isBackView) {
        if (detectedScale === void 0) {
            detectedScale = 1;
        }
        if (isBackView === void 0) {
            isBackView = true;
        }
        // Player/Foe size controls are presentation profiles for the sprite VIEW,
        // not for the physical battle side. This matters when an animation forces
        // User Back -> Front (or Target Front -> Back): the selected bitmap must
        // immediately use the Front/Back profile instead of keeping the old side's
        // scale. Back profile = Player, Front profile = Foe.
        var override = isBackView ? Number(this.playerBattlerSize || 0) : Number(this.foeBattlerSize || 0);
        var base = override > 0 ? override : Math.max(.01, Number(detectedScale || 1));
        return base * Math.max(.01, Number(this.battlerScale || 1));
    };
    BattlePreview.prototype.setOnionMode = function (mode) {
        if (mode === void 0) {
            mode = "off";
        }
        this.onionMode = ["prev", "next", "both"].includes(String(mode)) ? String(mode) : "off";
        this.draw();
    };
    BattlePreview.prototype.setContext = function (c) { this.context = c || fallbackBattleContext(); this.draw(); };
    BattlePreview.prototype.setBattlers = function (user, target, variants, metadata) {
        if (variants === void 0) {
            variants = {};
        }
        if (metadata === void 0) {
            metadata = {};
        }
        this.battlerMeta = Object.assign(Object.assign({}, this.battlerMeta), metadata);
        this._setNamed("user", user);
        this._setNamed("target", target);
        this._setNamed("userFront", variants.userFront || null);
        this._setNamed("userBack", variants.userBack || user);
        this._setNamed("targetFront", variants.targetFront || target);
        this._setNamed("targetBack", variants.targetBack || null);
    };
    BattlePreview.prototype.setContextBattler = function (index, url, meta) {
        var _this = this;
        var key = Number(index);
        var old = this.contextBattlerUrls.get(key) || null;
        if (old && old !== url)
            URL.revokeObjectURL(old);
        this.contextBattlerUrls.set(key, url || null);
        this.contextBattlerMeta.set(key, meta || {});
        this.contextBattlerImages.delete(key);
        if (!url) {
            this.draw();
            return;
        }
        var im = new Image();
        im.onload = function () { _this.contextBattlerImages.set(key, im); _this.draw(); };
        im.onerror = function () { _this.contextBattlerImages.delete(key); _this.draw(); };
        im.src = url;
    };
    BattlePreview.prototype.clearContextBattlers = function (valid) {
        var keep = new Set((valid || []).map(function (x) { return Number(x); }));
        var _this = this;
        this.contextBattlerUrls.forEach(function (url, key) {
            if (keep.has(Number(key))) return;
            if (url) URL.revokeObjectURL(url);
            _this.contextBattlerUrls.delete(key);
            _this.contextBattlerImages.delete(key);
            _this.contextBattlerMeta.delete(key);
        });
        this.draw();
    };
    BattlePreview.prototype.contextBattlerBundle = function (index, fallback) {
        var key = Number(index);
        var image = this.contextBattlerImages.get(key) || null;
        var meta = this.contextBattlerMeta.get(key) || null;
        return image ? { image: image, meta: meta || {} } : fallback;
    };
    BattlePreview.prototype.setSceneImages = function (background, playerBase, enemyBase) { this._setScene("background", background); this._setScene("playerBase", playerBase); this._setScene("enemyBase", enemyBase); };
    BattlePreview.prototype.setClipImage = function (id, url) { this._setMapImage(this.clipImages, id, url); };
    BattlePreview.prototype.setClipSwitchImage = function (id, path, url) { this._setMapImage(this.clipImages, "".concat(id, "@@").concat(String(path || "")), url); };
    BattlePreview.prototype.setMaskImage = function (id, url) { this._setMapImage(this.maskImages, id, url); };
    BattlePreview.prototype.clearClipImages = function (valid) {
        var e_5, _q, e_6, _r;
        if (valid === void 0) {
            valid = [];
        }
        var keep = new Set(valid);
        try {
            for (var _s = __values([this.clipImages, this.maskImages]), _t = _s.next(); !_t.done; _t = _s.next()) {
                var map = _t.value;
                try {
                    for (var map_1 = (e_6 = void 0, __values(map)), map_1_1 = map_1.next(); !map_1_1.done; map_1_1 = map_1.next()) {
                        var _u = __read(map_1_1.value, 2), id = _u[0], r = _u[1];
                        var base = String(id).split("@@")[0];
                        if (keep.has(base))
                            continue;
                        if (r === null || r === void 0 ? void 0 : r.url)
                            URL.revokeObjectURL(r.url);
                        map.delete(id);
                    }
                }
                catch (e_6_1) {
                    e_6 = { error: e_6_1 };
                }
                finally {
                    try {
                        if (map_1_1 && !map_1_1.done && (_r = map_1.return))
                            _r.call(map_1);
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
                if (_t && !_t.done && (_q = _s.return))
                    _q.call(_s);
            }
            finally {
                if (e_5)
                    throw e_5.error;
            }
        }
    };
    BattlePreview.prototype._setMapImage = function (map, id, url) {
        var _this = this;
        var old = map.get(id);
        if ((old === null || old === void 0 ? void 0 : old.url) === url)
            return;
        if (old === null || old === void 0 ? void 0 : old.url)
            URL.revokeObjectURL(old.url);
        if (!url) {
            map.delete(id);
            this.draw();
            return;
        }
        var im = new Image(), r = { url: url, image: null };
        map.set(id, r);
        im.onload = function () { r.image = im; _this.draw(); };
        im.onerror = function () { r.image = null; _this.draw(); };
        im.src = url;
    };
    BattlePreview.prototype._setNamed = function (key, url) {
        var _this = this;
        if (this.urls[key] && this.urls[key] !== url)
            URL.revokeObjectURL(this.urls[key]);
        this.urls[key] = url || null;
        this.images[key] = null;
        if (!url) {
            this.draw();
            return;
        }
        var im = new Image();
        im.onload = function () { _this.images[key] = im; _this.draw(); };
        im.onerror = function () { _this.images[key] = null; _this.draw(); };
        im.src = url;
    };
    BattlePreview.prototype._setScene = function (key, url) {
        var _this = this;
        if (this.sceneUrls[key] && this.sceneUrls[key] !== url)
            URL.revokeObjectURL(this.sceneUrls[key]);
        this.sceneUrls[key] = url || null;
        this.sceneImages[key] = null;
        if (!url) {
            this.draw();
            return;
        }
        var im = new Image();
        im.onload = function () { _this.sceneImages[key] = im; _this.draw(); };
        im.onerror = function () { _this.sceneImages[key] = null; _this.draw(); };
        im.src = url;
    };
    BattlePreview.prototype.logicalSize = function () { var _a, _b; return { width: Number(((_a = this.context) === null || _a === void 0 ? void 0 : _a.width) || 512), height: Number(((_b = this.context) === null || _b === void 0 ? void 0 : _b.height) || 384) }; };
    BattlePreview.prototype.semanticOpposing = function () {
        if (this.previewSideOverride === "foe")
            return true;
        if (this.previewSideOverride === "player")
            return false;
        var source = (this.animation && this.animation.source) || {};
        var side = String(source.sideContext || "").toLowerCase();
        // Native PBS/RXDATA Foe flag and explicit BAS Foe metadata are both valid.
        // A synthetic/default sideContext="player" must never hide opposing=true.
        return source.opposing === true || side === "foe";
    };
    BattlePreview.prototype.semanticInfo = function (side) {
        var _a, _b, _c, _d;
        if (side === "user" && this.replicaUserOverride)
            return this.replicaUserOverride;
        if (side === "target" && this.replicaTargetOverride)
            return this.replicaTargetOverride;
        var opp = this.semanticOpposing();
        if (side === "user")
            return opp ? (((_a = this.context) === null || _a === void 0 ? void 0 : _a.target) || {}) : (((_b = this.context) === null || _b === void 0 ? void 0 : _b.user) || {});
        return opp ? (((_c = this.context) === null || _c === void 0 ? void 0 : _c.user) || {}) : (((_d = this.context) === null || _d === void 0 ? void 0 : _d.target) || {});
    };
    BattlePreview.prototype.semanticIndex = function (side) {
        if (side === "user" && this.replicaUserOverride)
            return Number(this.replicaUserOverride.index || 0);
        if (side === "target" && this.replicaTargetOverride)
            return Number(this.replicaTargetOverride.index || 1);
        var c = this.context || {}, opp = this.semanticOpposing();
        if (side === "user")
            return Number(opp ? (c.targetIndex != null ? c.targetIndex : 1) : (c.userIndex != null ? c.userIndex : 0));
        return Number(opp ? (c.userIndex != null ? c.userIndex : 0) : (c.targetIndex != null ? c.targetIndex : 1));
    };
    BattlePreview.prototype.semanticContextBattlers = function (side) {
        if (side === void 0) {
            side = null;
        }
        var _a, _b, _c;
        var rawBattlers = Array.isArray((_c = (_b = (_a = this.context) === null || _a === void 0 ? void 0 : _a.raw) === null || _b === void 0 ? void 0 : _b.battlers) !== null && _c !== void 0 ? _c : null) ? this.context.raw.battlers : [];
        var opp = this.semanticOpposing();
        var converted = rawBattlers.map(function (b) {
            var index = Number((b === null || b === void 0 ? void 0 : b.index) || 0), physicalSide = index % 2 === 0 ? "user" : "target", semanticSide = opp ? (physicalSide === "user" ? "target" : "user") : physicalSide;
            return {
                index: index,
                side: semanticSide,
                physicalSide: physicalSide,
                x: Number((b === null || b === void 0 ? void 0 : b.x) || 0),
                y: Number((b === null || b === void 0 ? void 0 : b.y) || 0),
                focusX: Number((b === null || b === void 0 ? void 0 : b.focus_x) != null ? b.focus_x : ((b === null || b === void 0 ? void 0 : b.focusX) != null ? b.focusX : ((b === null || b === void 0 ? void 0 : b.x) || 0))),
                focusY: Number((b === null || b === void 0 ? void 0 : b.focus_y) != null ? b.focus_y : ((b === null || b === void 0 ? void 0 : b.focusY) != null ? b.focusY : ((b === null || b === void 0 ? void 0 : b.y) || 0))),
                sideSize: Number((b === null || b === void 0 ? void 0 : b.side_size) || 1),
                bitmapWidth: Number((b === null || b === void 0 ? void 0 : b.bitmap_width) != null ? b.bitmap_width : ((b === null || b === void 0 ? void 0 : b.bitmapWidth) || 0)),
                bitmapHeight: Number((b === null || b === void 0 ? void 0 : b.bitmap_height) != null ? b.bitmap_height : ((b === null || b === void 0 ? void 0 : b.bitmapHeight) || 0)),
                bitmapReal: (b === null || b === void 0 ? void 0 : b.bitmap_real) === false || (b === null || b === void 0 ? void 0 : b.bitmapReal) === false ? false : true,
                zoomX: Number((b === null || b === void 0 ? void 0 : b.zoom_x) != null ? b.zoom_x : ((b === null || b === void 0 ? void 0 : b.zoomX) || 1)),
                zoomY: Number((b === null || b === void 0 ? void 0 : b.zoom_y) != null ? b.zoom_y : ((b === null || b === void 0 ? void 0 : b.zoomY) || 1)),
                ox: Number((b === null || b === void 0 ? void 0 : b.ox) || 0), oy: Number((b === null || b === void 0 ? void 0 : b.oy) || 0),
                species: String((b === null || b === void 0 ? void 0 : b.species) || (b === null || b === void 0 ? void 0 : b.species_id) || ""),
                form: Number((b === null || b === void 0 ? void 0 : b.form) || 0),
                visible: b == null || b.visible !== false
            };
        }).filter(function (b) { return b.visible !== false; });
        var list = converted.length ? converted : [
            { index: this.semanticIndex("user"), side: "user", physicalSide: opp ? "target" : "user", x: Number((this.semanticInfo("user") || {}).x || 0), y: Number((this.semanticInfo("user") || {}).y || 0), focusX: Number((this.semanticInfo("user") || {}).focusX || (this.semanticInfo("user") || {}).x || 0), focusY: Number((this.semanticInfo("user") || {}).focusY || (this.semanticInfo("user") || {}).y || 0), sideSize: Number((((this.context || {}).sideSizes || {}).user) || 1), visible: true },
            { index: this.semanticIndex("target"), side: "target", physicalSide: opp ? "user" : "target", x: Number((this.semanticInfo("target") || {}).x || 0), y: Number((this.semanticInfo("target") || {}).y || 0), focusX: Number((this.semanticInfo("target") || {}).focusX || (this.semanticInfo("target") || {}).x || 0), focusY: Number((this.semanticInfo("target") || {}).focusY || (this.semanticInfo("target") || {}).y || 0), sideSize: Number((((this.context || {}).sideSizes || {}).target) || 1), visible: true }
        ];
        // User/Target are semantic actors, not hard-coded parties. If Target is
        // an ally, Target-side anchors/effects must use that ally's physical side.
        var filtered = list;
        if (side === "user" || side === "target") {
            var roleParity = Math.abs(Number(this.semanticIndex(side) || 0)) % 2;
            filtered = list.filter(function (b) { return Math.abs(Number(b.index || 0)) % 2 === roleParity; });
        }
        return filtered.sort(function (a, b) { return a.y - b.y || a.x - b.x || a.index - b.index; });
    };
    BattlePreview.prototype.battlersAreNear = function (indexA, indexB) {
        var a = Number(indexA), b = Number(indexB);
        if (!Number.isFinite(a) || !Number.isFinite(b) || a === b)
            return false;
        var sizes = (this.context && this.context.sideSizes) || { user: 1, target: 1 };
        var side0 = Number(sizes.user || 1), side1 = Number(sizes.target || 1);
        if (side0 <= 2 && side1 <= 2)
            return true;
        var pairs = [[0, 4], [1, 5]];
        if (side0 === 3 && side1 === 3)
            pairs.push([0, 1], [4, 5]);
        else if (side0 === 3 && side1 === 2)
            pairs.push([0, 1], [3, 4]);
        else if (side0 === 2 && side1 === 3)
            pairs.push([0, 1], [2, 5]);
        return !pairs.some(function (pair) { return pair.includes(a) && pair.includes(b); });
    };
    BattlePreview.prototype.replicaAnchorRoleForClip = function (clip, mode) {
        var e_7, _q;
        if (mode === void 0) {
            mode = "affected";
        }
        if (mode === "user_adjacents")
            return "user";
        if (mode === "target_adjacents")
            return "target";
        var focus = String((clip && clip.pbs && clip.pbs.focus) || "").toLowerCase();
        if (focus.includes("user") && !focus.includes("target"))
            return "user";
        if (focus.includes("target"))
            return "target";
        var keys = Array.isArray(clip && clip.positionKeys) ? clip.positionKeys : [];
        try {
            for (var keys_1 = __values(keys), keys_1_1 = keys_1.next(); !keys_1_1.done; keys_1_1 = keys_1.next()) {
                var k = keys_1_1.value;
                var a = String((k && k.point && k.point.anchor) || "").toLowerCase();
                if (a.includes("target"))
                    return "target";
                if (a.includes("user"))
                    return "user";
            }
        }
        catch (e_7_1) {
            e_7 = { error: e_7_1 };
        }
        finally {
            try {
                if (keys_1_1 && !keys_1_1.done && (_q = keys_1.return))
                    _q.call(keys_1);
            }
            finally {
                if (e_7)
                    throw e_7.error;
            }
        }
        return "target";
    };
    BattlePreview.prototype.clipSemanticRole = function (clip) {
        var manual, explicit, keys, i, k, a, original, originalAnchor, focus, pref;
        if (!clip)
            return "";
        manual = clip.coordinateSpaceManual === true;
        explicit = String(clip.coordinateSpace || "auto").toLowerCase();
        if (manual) {
            if (explicit === "user" || explicit === "target")
                return explicit;
            if (explicit === "screen")
                return "";
        }
        keys = Array.isArray(clip.positionKeys) ? clip.positionKeys : [];
        for (i = 0; i < keys.length; i++) {
            k = keys[i] || {};
            a = String((k.point && k.point.anchor) || "").toLowerCase();
            if (!a || a.indexOf("screen") >= 0 || a.indexOf("_and_") >= 0 || a === "user_target")
                continue;
            if (a.indexOf("target") >= 0 && a.indexOf("user") < 0)
                return "target";
            if (a.indexOf("user") >= 0 && a.indexOf("target") < 0)
                return "user";
        }
        original = clip.editorOriginalPosition || {};
        originalAnchor = String(original.anchor || "").toLowerCase();
        if (originalAnchor.indexOf("target") >= 0 && originalAnchor.indexOf("user") < 0)
            return "target";
        if (originalAnchor.indexOf("user") >= 0 && originalAnchor.indexOf("target") < 0)
            return "user";
        // Focus controls emitter/particle behavior, not coordinate ownership.
        // A pure screen-authored clip must stay where it was authored unless the
        // user explicitly selects Follow User/Follow Target or a semantic anchor exists.
        return "";
    };
    BattlePreview.prototype.clipIsTargetLocal = function (clip) {
        if (this.clipSemanticRole(clip) === "target")
            return true;
        var pbs = (clip && clip.pbs) || {};
        var emitterKind = String(pbs.emitter || pbs.emitterType || "none").toLowerCase();
        var focus = String(pbs.focus || "").toLowerCase();
        return emitterKind !== "none" && focus.indexOf("target") >= 0 && focus.indexOf("user") < 0;
    };
    BattlePreview.prototype.replicaBattlersForClip = function (clip) {
        var _this = this;
        var source = (this.animation && this.animation.source) || {};
        var mode = String((clip && clip.replicateTo) || "none").toLowerCase();
        var scope = String(source.targetScope || "single_foe").toLowerCase();
        var autoPreview = source.previewAffectedTargets === true && source.autoReplicateAffected === true;
        var targetLocal = this.clipIsTargetLocal(clip);
        if (mode === "none" && autoPreview && targetLocal && ["multiple_foes", "multiple_users", "adjacent_others", "all_battlers"].includes(scope))
            mode = "affected";
        if (mode === "none")
            return [];
        var all = this.semanticContextBattlers(), ui = this.semanticIndex("user"), ti = this.semanticIndex("target");
        if (mode === "affected") {
            if (!targetLocal)
                return [];
            return this.affectedBattlersForMove().filter(function (b) { return Number(b.index) !== Number(ti); }).map(function (b) { return Object.assign({}, b, { anchorRole: "target" }); });
        }
        var anchorRole = this.replicaAnchorRoleForClip(clip, mode);
        var list = [];
        if (mode === "target_near")
            list = this.affectedBattlersForMove().filter(function (b) { return Number(b.index) !== Number(ti) && _this.battlersAreNear(ui, Number(b.index)); });
        else if (mode === "target_adjacents")
            list = this.affectedBattlersForMove().filter(function (b) { return Number(b.index) !== Number(ti); });
        else if (mode === "user_adjacents")
            list = all.filter(function (b) { return Number(b.index) % 2 === Number(ui) % 2 && Number(b.index) !== Number(ui); });
        else if (mode === "near_others")
            list = all.filter(function (b) { return Number(b.index) !== Number(ui) && Number(b.index) !== Number(ti) && _this.battlersAreNear(ui, Number(b.index)); });
        else if (mode === "all_targets")
            list = all.filter(function (b) { return Number(b.index) !== Number(ti); });
        else if (mode === "all_adjacents")
            list = all.filter(function (b) { return Number(b.index) !== Number(ui) && Number(b.index) !== Number(ti); });
        return list.map(function (b) { return Object.assign({}, b, { anchorRole: anchorRole }); });
    };
    BattlePreview.prototype.affectedBattlersForMove = function () {
        var source = (this.animation && this.animation.source) || {};
        var scope = String(source.targetScope || "single_foe").toLowerCase();
        var detectedTarget = String(source.detectedTarget || "").toLowerCase();
        var all = this.semanticContextBattlers();
        var ui = this.semanticIndex("user"), ti = this.semanticIndex("target");
        var userSide = ui % 2, targetSide = ti % 2;
        if (scope === "environment")
            return [];
        if (scope === "single_user") {
            if (detectedTarget === "nearally" || detectedTarget === "userornearally")
                return all.filter(function (b) { return Number(b.index) === Number(ti); });
            return all.filter(function (b) { return Number(b.index) === Number(ui); });
        }
        if (scope === "multiple_users") {
            if (detectedTarget === "allallies")
                return all.filter(function (b) { return Number(b.index) % 2 === userSide && Number(b.index) !== Number(ui); });
            return all.filter(function (b) { return Number(b.index) % 2 === userSide; });
        }
        if (scope === "single_foe" || scope === "single_other")
            return all.filter(function (b) { return Number(b.index) === Number(ti); });
        if (scope === "multiple_foes") {
            return all.filter(function (b) {
                var idx = Number(b.index);
                if (idx % 2 !== targetSide)
                    return false;
                return detectedTarget === "allnearfoes" ? this.battlersAreNear(ui, idx) : true;
            }, this);
        }
        if (scope === "adjacent_others")
            return all.filter(function (b) { var idx = Number(b.index); return idx !== Number(ui) && this.battlersAreNear(ui, idx); }, this);
        if (scope === "all_battlers")
            return all.slice();
        return all.filter(function (b) { return Number(b.index) === Number(ti); });
    };
    BattlePreview.prototype.affectedBattlerIndexSet = function () {
        var set = new Set();
        this.affectedBattlersForMove().forEach(function (b) { set.add(Number(b.index)); });
        return set;
    };
    BattlePreview.prototype.withReplicaBattler = function (replica, fn) {
        var oldU = this.replicaUserOverride, oldT = this.replicaTargetOverride;
        var role = String((replica && replica.anchorRole) || (replica && replica.side) || "target");
        if (replica && role === "user")
            this.replicaUserOverride = replica;
        else if (replica)
            this.replicaTargetOverride = replica;
        try {
            return fn();
        }
        finally {
            this.replicaUserOverride = oldU;
            this.replicaTargetOverride = oldT;
        }
    };
    BattlePreview.prototype.prefersSpreadSideAnchors = function () {
        var _a, _b, _c;
        var source = ((_a = this.animation) === null || _a === void 0 ? void 0 : _a.source) || {};
        var targetMode = String(source.targetMode || "").toLowerCase();
        var targetScope = String(source.targetScope || "").toLowerCase();
        var catalogType = String(source.catalogType || "move").toLowerCase();
        var behavior = String(source.behavior || "").toLowerCase();
        if (catalogType === "common")
            return true;
        if (["multiple_foes", "multiple_users", "adjacent_others", "all_battlers", "environment"].includes(targetScope))
            return true;
        if (targetMode === "both" || targetMode === "environment")
            return true;
        if (behavior === "hazard")
            return true;
        var name = String((_c = (_b = this.animation) === null || _b === void 0 ? void 0 : _b.name) !== null && _c !== void 0 ? _c : "");
        if (/screen|field|weather|terrain/i.test(name))
            return true;
        return false;
    };
    BattlePreview.prototype.semanticSideAnchor = function (side, mode) {
        if (mode === void 0) {
            mode = "center";
        }
        var direct = this.semanticInfo(side) || {};
        var directAnchor = { x: Number(direct.x || 0), y: Number(direct.y || 0), focusX: Number(direct.focusX || direct.x || 0), focusY: Number(direct.focusY || direct.y || 0) };
        var list = this.semanticContextBattlers(side);
        if (!list.length) {
            return directAnchor;
        }
        if (mode !== "center" && !this.prefersSpreadSideAnchors()) {
            return directAnchor;
        }
        if (mode === "foreground") {
            return list.slice().sort(function (a, b) { return b.y - a.y || a.x - b.x || a.index - b.index; })[0];
        }
        if (mode === "background") {
            return list[0];
        }
        var sum = list.reduce(function (acc, b) {
            acc.x += Number(b.x || 0);
            acc.y += Number(b.y || 0);
            acc.focusX += Number(b.focusX || b.x || 0);
            acc.focusY += Number(b.focusY || b.y || 0);
            return acc;
        }, { x: 0, y: 0, focusX: 0, focusY: 0 });
        var n = list.length || 1;
        return { x: sum.x / n, y: sum.y / n, focusX: sum.focusX / n, focusY: sum.focusY / n };
    };
    BattlePreview.prototype.semanticBase = function (side) { return this.semanticOpposing() ? (side === "user" ? "target" : "user") : side; };
    BattlePreview.prototype.clipCoordinateSpace = function (o) {
        if (!o || o.type === "battler" || o.type === "camera")
            return "world";
        var manual = o.coordinateSpaceManual === true;
        var explicit = String(o.coordinateSpace || "auto").toLowerCase();
        // Backward compatibility: clips created before coordinate-space support
        // keep the exact old world/camera behavior until the user explicitly
        // chooses a coordinate space in the inspector.
        if (!manual)
            return "world";
        if (explicit === "screen")
            return "screen";
        if (explicit === "user" || explicit === "target")
            return explicit;
        return "world";
    };
    BattlePreview.prototype.contextRoleForObject = function (o) {
        if (!o || o.type === "battler" || o.type === "camera")
            return "";
        return this.clipSemanticRole(o);
    };
    BattlePreview.prototype.authoredSideOpposing = function () {
        var source = (this.animation && this.animation.source) || {};
        var side = String(source.sideContext || "").toLowerCase();
        return source.opposing === true || side === "foe";
    };
    BattlePreview.prototype.contextViewKey = function () {
        return this.semanticOpposing() ? "foe" : "player";
    };
    BattlePreview.prototype.contextOverrideForObject = function (o) {
        var all = o && o.contextOverrides;
        if (!all || typeof all !== "object") return null;
        var ov = all[this.contextViewKey()];
        return ov && typeof ov === "object" ? ov : null;
    };
    BattlePreview.prototype.contextOverrideNeutral = function (prop) {
        return ["scaleX", "scaleY", "opacity", "cameraZoom"].includes(String(prop || "")) ? 100 : 0;
    };
    BattlePreview.prototype.contextOverrideLocalValue = function (o, prop, frame, neutral) {
        if (neutral === void 0) neutral = this.contextOverrideNeutral(prop);
        var ov = this.contextOverrideForObject(o);
        if (!ov || !ov.contextKeys || !Array.isArray(ov.contextKeys[prop]) || !ov.contextKeys[prop].length)
            return neutral;
        var keys = ov.contextKeys[prop].slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
        // Context curves are corrections layered over BAS' automatic adaptation.
        // If the first correction starts after frame 0, frame 0 remains neutral
        // instead of inheriting that first value (the old global-override bug).
        if (Number(keys[0].frame || 0) > 0)
            keys.unshift({ frame: 0, value: neutral, easing: "ease_both" });
        var fake = { visual: {}, valueKeys: {} };
        fake.visual[prop] = neutral;
        fake.valueKeys[prop] = keys;
        return Number(sampleValue(fake, prop, frame, neutral));
    };
    BattlePreview.prototype.contextOverrideValue = function (o, prop, frame, neutral) {
        if (frame === void 0) frame = this.frame;
        if (neutral === void 0) neutral = this.contextOverrideNeutral(prop);
        var ov = this.contextOverrideForObject(o);
        if (!ov) return neutral;
        var global = Number.isFinite(Number(ov[prop])) ? Number(ov[prop]) : neutral;
        var local = this.contextOverrideLocalValue(o, prop, frame, neutral);
        if (["scaleX", "scaleY", "opacity", "cameraZoom"].includes(String(prop || "")))
            return global * local / 100;
        return global + local;
    };
    BattlePreview.prototype.contextAbsoluteLocalValue = function (o, prop, frame, fallback) {
        var ov = this.contextOverrideForObject(o);
        var raw = ov && ov.contextKeys && Array.isArray(ov.contextKeys[prop]) ? ov.contextKeys[prop] : [];
        var keys = raw.filter(function (k) { return k && !k.implicit; }).slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
        if (!keys.length) return fallback;
        var f = Number(frame || 0);
        if (f < Number(keys[0].frame || 0)) return fallback;
        if (f >= Number(keys[keys.length - 1].frame || 0)) return Number(keys[keys.length - 1].value);
        for (var i = 0; i < keys.length - 1; i++) {
            var a = keys[i], b = keys[i + 1], af = Number(a.frame || 0), bf = Number(b.frame || 0);
            if (f < af || f > bf) continue;
            var t = ease((f - af) / Math.max(.0001, bf - af), a.easing || "ease_both");
            return Number(a.value || 0) + (Number(b.value || 0) - Number(a.value || 0)) * t;
        }
        return fallback;
    };
    BattlePreview.prototype.contextEmitterDiscreteProp = function (prop) {
        return ["emitClockwise", "randomInvertFlip", "randomInvertAngle", "waveEnabled", "simpleStopAtDestination", "simpleFaceTravel"].includes(String(prop || ""));
    };
    BattlePreview.prototype.contextParameterValue = function (o, kind, prop, frame, fallback) {
        var ov = this.contextOverrideForObject(o), name = String(kind || "emitter") + ":" + String(prop || "");
        var raw = ov && ov.contextKeys && Array.isArray(ov.contextKeys[name]) ? ov.contextKeys[name] : [];
        var keys = raw.filter(function (k) { return k && !k.implicit; }).slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
        if (!keys.length) return fallback;
        var f = Number(frame || 0);
        if (f < Number(keys[0].frame || 0)) return fallback;
        if (this.contextEmitterDiscreteProp(prop)) {
            var value = fallback;
            keys.forEach(function (k) { if (Number(k.frame || 0) <= f) value = Number(k.value || 0) >= .5; });
            return value;
        }
        if (f >= Number(keys[keys.length - 1].frame || 0)) return Number(keys[keys.length - 1].value);
        for (var i = 0; i < keys.length - 1; i++) {
            var a = keys[i], b = keys[i + 1], af = Number(a.frame || 0), bf = Number(b.frame || 0);
            if (f < af || f > bf) continue;
            var t = ease((f - af) / Math.max(.0001, bf - af), a.easing || "ease_both");
            return Number(a.value || 0) + (Number(b.value || 0) - Number(a.value || 0)) * t;
        }
        return fallback;
    };
    BattlePreview.prototype.contextOpacityValue = function (o, frame, baseOpacity) {
        var ov = this.contextOverrideForObject(o);
        if (!ov) return clamp(Number(baseOpacity || 0), 0, 100);
        var global = Number.isFinite(Number(ov.opacity)) ? Number(ov.opacity) : 100;
        var inherited = clamp(Number(baseOpacity || 0) * global / 100, 0, 100);
        if (ov.contextOpacityAbsolute === true)
            return clamp(this.contextAbsoluteLocalValue(o, "opacity", frame, inherited), 0, 100);
        var correction = this.contextOverrideValue(o, "opacity", frame, 100);
        return clamp(Number(baseOpacity || 0) * Math.max(0, correction) / 100, 0, 100);
    };
    BattlePreview.prototype.contextualScreenRolePoint = function (o, p, q, role) {
        if (!o || !p || !q || !role) return { point: q, applied: false };
        if (o.coordinateSpaceManual !== true) return { point: q, applied: false };
        var space = String(o.coordinateSpace || "auto").toLowerCase();
        if (space !== role || (space !== "user" && space !== "target")) return { point: q, applied: false };
        if (String(p.anchor || "").toLowerCase() !== "screen") return { point: q, applied: false };
        if (this.authoredSideOpposing() === this.semanticOpposing()) return { point: q, applied: false };
        var a = this.anchors();
        var currentUser = a.user, currentTarget = a.target;
        if (!currentUser || !currentTarget) return { point: q, applied: false };
        // Player→Foe and Foe→Player are the same authored route viewed from the
        // opposite semantic side. The old transform rotated every screen point
        // 180° around its role anchor; that also inverted Y, so arcs, jumps and
        // multi-key routes visibly slid to the wrong height. Remap horizontal
        // progress from the authored User→Target baseline to the live baseline,
        // while preserving the point's vertical deviation from that baseline.
        // This swaps both endpoints exactly and keeps "above" routes above.
        var sourceUser = currentTarget, sourceTarget = currentUser;
        var destUser = currentUser, destTarget = currentTarget;
        var sourceDx = Number(sourceTarget.x || 0) - Number(sourceUser.x || 0);
        if (Math.abs(sourceDx) > .0001) {
            var alpha = (Number(q.x || 0) - Number(sourceUser.x || 0)) / sourceDx;
            var sourceLineY = Number(sourceUser.y || 0) + alpha * (Number(sourceTarget.y || 0) - Number(sourceUser.y || 0));
            var verticalDeviation = Number(q.y || 0) - sourceLineY;
            var mappedX = Number(destUser.x || 0) + alpha * (Number(destTarget.x || 0) - Number(destUser.x || 0));
            var mappedLineY = Number(destUser.y || 0) + alpha * (Number(destTarget.y || 0) - Number(destUser.y || 0));
            return { point: { x: mappedX, y: mappedLineY + verticalDeviation }, applied: true };
        }
        // Degenerate/vertical formation fallback: mirror only the local X and
        // preserve local Y, matching the anchor-based side-remap used elsewhere.
        var sourceAnchor = role === "user" ? sourceUser : sourceTarget;
        var destAnchor = role === "user" ? destUser : destTarget;
        return { point: {
            x: Number(destAnchor.x || 0) - (Number(q.x || 0) - Number(sourceAnchor.x || 0)),
            y: Number(destAnchor.y || 0) + (Number(q.y || 0) - Number(sourceAnchor.y || 0))
        }, applied: true };
    };
    BattlePreview.prototype.contextualScreenRotationDelta = function (o) {
        if (!o || o.coordinateSpaceManual !== true) return 0;
        var space = String(o.coordinateSpace || "auto").toLowerCase();
        if (space !== "user" && space !== "target") return 0;
        var keys = Array.isArray(o.positionKeys) ? o.positionKeys : [];
        if (!keys.some(function (k) { return k && k.point && String(k.point.anchor || "").toLowerCase() === "screen"; })) return 0;
        return this.authoredSideOpposing() === this.semanticOpposing() ? 0 : 180;
    };
    BattlePreview.prototype.primarySemanticInfo = function (side) {
        var opp = this.semanticOpposing(), c = this.context || {};
        if (side === "user")
            return opp ? (c.target || {}) : (c.user || {});
        return opp ? (c.user || {}) : (c.target || {});
    };
    BattlePreview.prototype.replicaRoleShift = function (role) {
        var replica = role === "user" ? this.replicaUserOverride : this.replicaTargetOverride;
        if (!replica)
            return { x: 0, y: 0 };
        var primary = this.primarySemanticInfo(role) || {};
        var rx = Number(replica.focusX != null ? replica.focusX : (replica.x || 0));
        var ry = Number(replica.focusY != null ? replica.focusY : (replica.y || 0));
        var px = Number(primary.focusX != null ? primary.focusX : (primary.x || 0));
        var py = Number(primary.focusY != null ? primary.focusY : (primary.y || 0));
        return { x: rx - px, y: ry - py };
    };
    BattlePreview.prototype.formationOffsetForRole = function (role) {
        var c = this.context || {}, size = this.logicalSize(), opp = this.semanticOpposing();
        var physical = opp ? (role === "user" ? "target" : "user") : role;
        var script = role === "user" ? (opp ? (c.scriptTarget || c.target || {}) : (c.scriptUser || c.user || {})) : (opp ? (c.scriptUser || c.user || {}) : (c.scriptTarget || c.target || {}));
        var bx = physical === "user" ? 128 : size.width - 128;
        var by = physical === "user" ? size.height - 80 : (size.height * 3 / 4) - 112;
        return { x: Number(script.x != null ? script.x : bx) - bx, y: Number(script.y != null ? script.y : by) - by };
    };
    BattlePreview.prototype.resizeCanvas = function () {
        var r = this.canvas.getBoundingClientRect(), w = Math.max(1, Math.round(r.width)), h = Math.max(1, Math.round(r.height)), pw = Math.max(1, Math.round(w * this.dpr)), ph = Math.max(1, Math.round(h * this.dpr));
        if (this.canvas.width !== pw || this.canvas.height !== ph) {
            this.canvas.width = pw;
            this.canvas.height = ph;
        }
        this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
        var l = this.logicalSize(), s = Math.min(w / l.width, h / l.height), ox = (w - l.width * s) / 2, oy = (h - l.height * s) / 2;
        return this.lastTransform = { width: w, height: h, scale: s, offsetX: ox, offsetY: oy, logicalWidth: l.width, logicalHeight: l.height };
    };
    BattlePreview.prototype.battlerImageAndMeta = function (side, track) {
        if (track === void 0) {
            track = null;
        }
        var idx = this.semanticIndex(side), physical = (Number(idx) % 2 === 0 ? "user" : "target");
        var facing = Math.round(track ? sampleValue(track, "facing", this.frame, 0) : 0);
        var view = facing === 1 ? "Back" : facing === 2 ? "Front" : (idx % 2 === 0 ? "Back" : "Front");
        var key = "".concat(physical).concat(view), fallback = physical;
        return { image: this.images[key] || this.images[fallback] || null, meta: this.battlerMeta[key] || this.battlerMeta[fallback] || {} };
    };
    BattlePreview.prototype.contextSpeciesMatchesBattler = function (info, meta) {
        if (info === void 0) {
            info = {};
        }
        if (meta === void 0) {
            meta = {};
        }
        var ctxSpecies = String((info && (info.species || info.species_id || info.speciesId)) || "").toUpperCase();
        var metaSpecies = String((meta && (meta.speciesId || meta.species || meta.id)) || "").toUpperCase();
        if (ctxSpecies && !metaSpecies)
            return false;
        if (!ctxSpecies || !metaSpecies)
            return true;
        var a = ctxSpecies.split(/[_-]/)[0], b = metaSpecies.split(/[_-]/)[0];
        return ctxSpecies === metaSpecies || a === b;
    };
    BattlePreview.prototype.naturalBattlerMeta = function (side) {
        var idx = this.semanticIndex(side);
        var physical = Number(idx) % 2 === 0 ? "user" : "target";
        return this.battlerMeta[physical] || {};
    };
    BattlePreview.prototype.viewAdjustedCapturedBaseline = function (side, info, bundle) {
        if (info === void 0) {
            info = {};
        }
        if (bundle === void 0) {
            bundle = {};
        }
        var desired = (bundle && bundle.meta) || {};
        if (!this.contextSpeciesMatchesBattler(info, desired))
            return null;
        if ((info && info.bitmapReal) === false || !(Number((info && info.bitmapHeight) || 0) > 0))
            return null;
        var idx = Number((info && info.index) != null ? info.index : NaN);
        if (!Number.isFinite(idx))
            return null;
        var naturalView = idx % 2 === 0 ? "back" : "front";
        var wantedView = String(desired.view || naturalView).toLowerCase();
        var natural = this.naturalBattlerMeta(side);
        if (wantedView === naturalView)
            return { x: Number(info.x || 0), y: Number(info.y || 0), changed: false };
        var dx = Number(desired.metricX || 0) - Number(natural.metricX || 0);
        var dy = Number(desired.metricY || 0) - Number(natural.metricY || 0);
        return { x: Number(info.x || 0) + dx, y: Number(info.y || 0) + dy, changed: true };
    };
    BattlePreview.prototype.contextMatchesBattler = function (info, meta) {
        if (info === void 0) {
            info = {};
        }
        if (meta === void 0) {
            meta = {};
        }
        var ctxSpecies = String((info && (info.species || info.species_id || info.speciesId)) || "").toUpperCase();
        var metaSpecies = String((meta && (meta.speciesId || meta.species || meta.id)) || "").toUpperCase();
        // A live capture describes the battler's natural battle view. Never reuse
        // the captured Back bitmap origin/size when the editor is explicitly
        // previewing Front (or vice versa), otherwise the Back/Front presentation scales get mixed.
        var idx = Number((info && info.index) != null ? info.index : NaN);
        var capturedView = Number.isFinite(idx) ? (idx % 2 === 0 ? "back" : "front") : "";
        var requestedView = String((meta && meta.view) || "").toLowerCase();
        if (capturedView && requestedView && capturedView !== requestedView)
            return false;
        // Do not apply a live-captured bitmap/origin/zoom from Charizard/Dragonite
        // to AnimBackTest or to a manually chosen battler whose species is unknown.
        // This was the main cause of huge/misplaced duplicate-looking battlers.
        if (ctxSpecies && !metaSpecies)
            return false;
        if (!ctxSpecies || !metaSpecies)
            return true;
        var a = ctxSpecies.split(/[_-]/)[0], b = metaSpecies.split(/[_-]/)[0];
        return ctxSpecies === metaSpecies || a === b;
    };
    // Return the amount of authored timeline time during which the battler's
    // own idle/spritesheet animation was allowed to advance. idlePause is a
    // stepped timeline channel: 1 freezes the battler image, 0 resumes it.
    // Paused intervals are removed from the idle clock so Resume continues from
    // the exact cel where Pause stopped instead of jumping ahead.
    BattlePreview.prototype.battlerIdleElapsedFrames = function (track, targetFrame) {
        var keys = ((((track || {}).valueKeys || {}).idlePause) || []).slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
        var f = Math.max(0, Number(targetFrame || 0));
        var paused = Number((((track || {}).visual || {}).idlePause) || 0) >= 0.5;
        var cursor = 0, elapsed = 0;
        for (var i = 0; i < keys.length; i++) {
            var kf = Math.max(0, Number(keys[i].frame || 0));
            if (kf > f) break;
            if (kf > cursor && !paused) elapsed += kf - cursor;
            cursor = kf;
            paused = Number(keys[i].value || 0) >= 0.5;
        }
        if (f > cursor && !paused) elapsed += f - cursor;
        return elapsed;
    };
    BattlePreview.prototype.battlerFrameInfo = function (image, meta, ctxInfo, track) {
        if (meta === void 0) {
            meta = {};
        }
        if (ctxInfo === void 0) {
            ctxInfo = {};
        }
        var _a;
        if (!image)
            return { sx: 0, sy: 0, sw: 0, sh: 0, count: 1, index: 0, scale: 1 };
        var strip = image.width > image.height * 2, sw = strip ? image.height : image.width, sh = image.height, count = strip ? Math.max(1, Math.floor(image.width / sw)) : 1;
        var delay = Math.max(16, Number(meta.frameDelayMs || 120));
        var idleFrame = track ? this.battlerIdleElapsedFrames(track, this.frame) : Number(this.frame || 0);
        var timeMs = (idleFrame / Math.max(1, Number(((_a = this.animation) === null || _a === void 0 ? void 0 : _a.fps) || 20))) * 1000;
        var index = (this.playing && count > 1) ? Math.floor(timeMs / delay) % count : 0;
        // Preview battler scale belongs to the editor selection/profile only.
        // A running battle must never overwrite it with bitmapWidth/bitmapHeight,
        // ox/oy or zoom captured from the current in-game battler. Runtime context
        // may describe formation geometry when explicitly selected, but never the
        // visual presentation of the battler chosen in the Studio.
        var scale = Number(meta.scale || 1);
        // Do not infer the renderer from PNG shape. The same source PNG can
        // be rendered at x1 (Gen 4/native) or be scaled by DBK in gameplay.
        // Auto/project detection and the explicit DBK/Gen 4 presets decide that scale.
        // Do not invent a minimum battler height here. v1.8.5 still enlarged
        // 96/128px battlers heuristically, which made their bodies extend much
        // farther above the bases and defeated the PBS metrics. At x1 the Studio
        // now uses the real source/runtime/PBS scale; x2-x8 is only the explicit
        // preview multiplier chosen by the user.
        return { sx: index * sw, sy: 0, sw: sw, sh: sh, count: count, index: index, scale: Math.max(.01, scale || 1) };
    };
    BattlePreview.prototype.anchors = function () {
        var _this = this;
        var c = this.context || fallbackBattleContext(), u = this.semanticInfo("user"), t = this.semanticInfo("target"), ui = this.semanticIndex("user"), ti = this.semanticIndex("target"), ub = this.battlerImageAndMeta("user", getBattlerTrack(this.animation, "user")), tb = this.battlerImageAndMeta("target", getBattlerTrack(this.animation, "target"));
        var opp = this.semanticOpposing();
        var normalScriptU = opp ? (c.scriptTarget || {}) : (c.scriptUser || {}), normalScriptT = opp ? (c.scriptUser || {}) : (c.scriptTarget || {});
        var scriptU = this.replicaUserOverride ? { x: Number(this.replicaUserOverride.x || 0), y: Number(this.replicaUserOverride.y || 0) } : normalScriptU;
        var scriptT = this.replicaTargetOverride ? { x: Number(this.replicaTargetOverride.x || 0), y: Number(this.replicaTargetOverride.y || 0) } : normalScriptT;
        var focus = function (side, info, bundle, scriptPos, dx, dy) {
            var m = bundle.meta || {}, fi = _this.battlerFrameInfo(bundle.image, m, info, getBattlerTrack(_this.animation, side));
            // Battler geometry is always reconstructed from the Studio context +
            // the selected battler's own Pokemon Metrics. Never borrow focus/origin
            // from the battler currently visible in a running game.
            var sx = scriptPos && scriptPos.x != null ? scriptPos.x : dx, sy = scriptPos && scriptPos.y != null ? scriptPos.y : dy;
            var baseX = Number(sx) + Number(m.metricX || 0), baseY = Number(sy) + Number(m.metricY || 0);
            var requestedBack = String(m.view || "").toLowerCase() === "back";
            var renderScale = _this.resolveBattlerScale(fi.scale, requestedBack);
            var renderedH = Number(fi.sh || 0) * renderScale;
            return { x: baseX, y: baseY - (renderedH > 0 ? renderedH / 2 : 40) };
        };
        var baseline = function (side, info, bundle, scriptPos, dx, dy) {
            var m = bundle.meta || {};
            // Same rule as focus(): baseline comes from formation + selected
            // battler metrics, not from a live sprite snapshot.
            var sx = scriptPos && scriptPos.x != null ? scriptPos.x : dx, sy = scriptPos && scriptPos.y != null ? scriptPos.y : dy;
            return { x: Number(sx) + Number(m.metricX || 0), y: Number(sy) + Number(m.metricY || 0) };
        };
        var uf = focus("user", u, ub, scriptU, 128, c.height - 80), tf = focus("target", t, tb, scriptT, c.width - 128, (c.height * 3 / 4) - 112), up = baseline("user", u, ub, scriptU, 128, c.height - 80), tp = baseline("target", t, tb, scriptT, c.width - 128, (c.height * 3 / 4) - 112);
        return { user: uf, target: tf, user_battler: up, target_battler: tp };
    };
    BattlePreview.prototype.responsiveScale = function () {
        var scene = (this.animation && this.animation.scene) || {};
        if (scene.responsive === false)
            return { x: 1, y: 1 };
        var size = this.logicalSize();
        var rw = Number(scene.referenceWidth || 0), rh = Number(scene.referenceHeight || 0);
        if (!(rw > 0) || !(rh > 0))
            return { x: 1, y: 1 };
        return { x: Number(size.width || rw) / rw, y: Number(size.height || rh) / rh };
    };
    BattlePreview.prototype.resolvePoint = function (p) {
        var _a, _b, _c, _d, _e, _f, _g, _h;
        var _q = this.logicalSize(), width = _q.width, height = _q.height, a = this.anchors(), ctx = this.context || {};
        if (!p)
            return { x: width / 2, y: height / 2 };
        if (String(p.anchor || "").startsWith("pbs:")) {
            var f = String(p.anchor).slice(4), su = { x: a.user.x, y: a.user.y }, st = { x: a.target.x, y: a.target.y }, opp = this.semanticOpposing(), baseScriptU = opp ? (ctx.scriptTarget || ctx.target) : (ctx.scriptUser || ctx.user), baseScriptT = opp ? (ctx.scriptUser || ctx.user) : (ctx.scriptTarget || ctx.target), scriptU = this.replicaUserOverride ? this.replicaUserOverride : baseScriptU, scriptT = this.replicaTargetOverride ? this.replicaTargetOverride : baseScriptT, pu = { x: a.user.x, y: Number((_a = scriptU === null || scriptU === void 0 ? void 0 : scriptU.y) !== null && _a !== void 0 ? _a : a.user.y) }, pt = { x: a.target.x, y: Number((_b = scriptT === null || scriptT === void 0 ? void 0 : scriptT.y) !== null && _b !== void 0 ? _b : a.target.y) };
            var x = Number(p.x || 0), y = Number(p.y || 0), one = null, pair = null;
            if (f === "user")
                one = su;
            else if (f === "user_position")
                one = pu;
            else if (f === "target")
                one = st;
            else if (f === "target_position")
                one = pt;
            else if (f === "user_and_target")
                pair = [su, st];
            else if (f === "user_position_and_target")
                pair = [pu, st];
            else if (f === "user_and_target_position")
                pair = [su, pt];
            else if (f === "user_position_and_target_position")
                pair = [pu, pt];
            else if (f === "user_side_foreground" || f === "user_side_background") {
                var anchor = this.semanticSideAnchor("user", f.endsWith("foreground") ? "foreground" : "background");
                one = { x: Number((_c = anchor === null || anchor === void 0 ? void 0 : anchor.x) !== null && _c !== void 0 ? _c : (((_d = scriptU === null || scriptU === void 0 ? void 0 : scriptU.x) !== null && _d !== void 0 ? _d : su.x))), y: Number((_e = anchor === null || anchor === void 0 ? void 0 : anchor.y) !== null && _e !== void 0 ? _e : (((_f = scriptU === null || scriptU === void 0 ? void 0 : scriptU.y) !== null && _f !== void 0 ? _f : su.y))) };
            }
            else if (f === "target_side_foreground" || f === "target_side_background") {
                var anchor = this.semanticSideAnchor("target", f.endsWith("foreground") ? "foreground" : "background");
                one = { x: Number((anchor === null || anchor === void 0 ? void 0 : anchor.x) != null ? anchor.x : (((scriptT === null || scriptT === void 0 ? void 0 : scriptT.x) != null ? scriptT.x : st.x))), y: Number((anchor === null || anchor === void 0 ? void 0 : anchor.y) != null ? anchor.y : (((scriptT === null || scriptT === void 0 ? void 0 : scriptT.y) != null ? scriptT.y : st.y))) };
            }
            var relativeIndex = !f.includes("and") ? (f.startsWith("user") ? this.semanticIndex("user") : f.startsWith("target") ? this.semanticIndex("target") : -1) : -1;
            if (relativeIndex >= 0 && relativeIndex % 2 === 1) {
                if (p.foeInvertX)
                    x *= -1;
                if (p.foeInvertY)
                    y *= -1;
            }
            if (pair) {
                // The New Animation Editor truncates the relative User/Target offset
                // to an integer before adding the focus point (Ruby `to_i`). Tiny
                // fractional differences accumulate into visibly different paths.
                var rx = Math.trunc((x / 200) * (pair[1].x - pair[0].x)), ry = Math.trunc((y / -200) * (pair[1].y - pair[0].y));
                return { x: pair[0].x + rx + Number(p.offsetX || 0), y: pair[0].y + ry + Number(p.offsetY || 0) };
            }
            if (one)
                return { x: one.x + x + Number(p.offsetX || 0), y: one.y + y + Number(p.offsetY || 0) };
            var rs_1 = this.responsiveScale();
            return { x: (x + Number(p.offsetX || 0)) * rs_1.x, y: (y + Number(p.offsetY || 0)) * rs_1.y };
        }
        if (p.anchor === "user_target") {
            return { x: a.user.x + Math.trunc((Number(p.x || 0) / 200) * (a.target.x - a.user.x)) + Number(p.offsetX || 0), y: a.user.y + Math.trunc((Number(p.y || 0) / -200) * (a.target.y - a.user.y)) + Number(p.offsetY || 0) };
        }
        if (a[p.anchor]) {
            var localOx = Number(p.offsetX || 0), localOy = Number(p.offsetY || 0);
            if (["user", "target", "user_battler", "target_battler"].includes(String(p.anchor || "").toLowerCase()) && this.authoredSideOpposing() !== this.semanticOpposing()) {
                // Side changes mirror horizontal choreography only. Vertical authored
                // motion (jump/lift/recoil such as Night Slash) must keep its sign;
                // flipping Y made an upward Target motion become a downward User motion.
                localOx *= -1;
            }
            return { x: a[p.anchor].x + localOx, y: a[p.anchor].y + localOy };
        }
        var rs = this.responsiveScale();
        var px = Number((_g = p.x) !== null && _g !== void 0 ? _g : (Number((this.animation && this.animation.scene && this.animation.scene.referenceWidth) || width) / 2));
        var py = Number((_h = p.y) !== null && _h !== void 0 ? _h : (Number((this.animation && this.animation.scene && this.animation.scene.referenceHeight) || height) / 2));
        return { x: (px + Number(p.offsetX || 0)) * rs.x, y: (py + Number(p.offsetY || 0)) * rs.y };
    };
    BattlePreview.prototype.baseBattlerPosition = function (side) { return Object.assign({}, this.anchors()[side === "user" ? "user_battler" : "target_battler"]); };
    BattlePreview.prototype.pbsBattlerBaselineOffset = function (o) {
        var _a, _b;
        if (!o || o.type !== "battler" || ((_a = o.imported) === null || _a === void 0 ? void 0 : _a.format) !== "pbs" || !((_b = o.imported) === null || _b === void 0 ? void 0 : _b.pbsBattlerParticle))
            return 0;
        var side = o.side === "target" ? "target" : "user", info = this.semanticInfo(side), capturedH = Number((info === null || info === void 0 ? void 0 : info.bitmapHeight) || 0);
        if (capturedH > 0)
            return capturedH / 2;
        var bundle = this.battlerImageAndMeta(side, getBattlerTrack(this.animation, side)), fi = this.battlerFrameInfo(bundle.image, bundle.meta || {}, info, getBattlerTrack(this.animation, side));
        return Number(fi.sh || 0) / 2;
    };
    BattlePreview.prototype.authoredRoleFollowDelta = function (role, frame) {
        if (frame === void 0) {
            frame = this.frame;
        }
        try {
            var side = role === "target" ? "target" : "user";
            var track = getBattlerTrack(this.animation, side);
            if (!track)
                return { x: 0, y: 0 };
            var base = this.baseBattlerPosition(side), pos = this.samplePosition(track, frame);
            return { x: Number(pos.x || 0) - Number(base.x || 0), y: Number(pos.y || 0) - Number(base.y || 0) };
        }
        catch (_authoredDeltaErr) {
            return { x: 0, y: 0 };
        }
    };
    BattlePreview.prototype.legacySingleTargetScreenPoint = function (o, p, q) {
        if (!o || !p || !q || o.type === "battler" || o.type === "camera") return q;
        var src = (this.animation && this.animation.source) || {}, scope = String(src.targetScope || "single_foe").toLowerCase();
        if (scope !== "single_foe" && scope !== "single_other") return q;
        if (o.coordinateSpaceManual === true) return q;
        if (String(p.anchor || "").toLowerCase() !== "screen") return q;
        var pref = String(o.priorityReference || "auto").toLowerCase();
        if (pref !== "target" && pref !== "user") return q;
        var size = this.logicalSize(), ux = 128, uy = size.height - 80, tx = size.width - 128, ty = (size.height * 3 / 4) - 112;
        var vx = tx - ux, vy = ty - uy, denom = vx * vx + vy * vy;
        var alpha = denom > 0 ? (((Number(q.x || 0) - ux) * vx + (Number(q.y || 0) - uy) * vy) / denom) : (pref === "target" ? 1 : 0);
        alpha = Math.max(0, Math.min(1, alpha));
        var du = this.formationOffsetForRole("user"), dt = this.formationOffsetForRole("target");
        return { x: Number(q.x || 0) + Number(du.x || 0) * (1 - alpha) + Number(dt.x || 0) * alpha, y: Number(q.y || 0) + Number(du.y || 0) * (1 - alpha) + Number(dt.y || 0) * alpha };
    };
    BattlePreview.prototype.authoredStageBattlerPoint = function (o, p, q) {
        if (!o || o.type !== "battler" || !p || !q)
            return q;
        var anchor = String(p.anchor || "").toLowerCase();
        var role = o.side === "target" ? "target" : "user";
        var src = (this.animation && this.animation.source) || {}, scope = String(src.targetScope || "single_foe").toLowerCase();
        if (role === "target" && (scope === "single_foe" || scope === "single_other")) return q;
        var belongs = role === "user" ? (anchor === "user_battler" || anchor === "user" || anchor === "pbs:user" || anchor === "pbs:user_position") : (anchor === "target_battler" || anchor === "target" || anchor === "pbs:target" || anchor === "pbs:target_position");
        if (!belongs)
            return q;
        var delta = this.formationOffsetForRole(role);
        if (Math.abs(Number(delta.x || 0)) < 0.001 && Math.abs(Number(delta.y || 0)) < 0.001)
            return q;
        var motion = Math.abs(Number(p.offsetX || 0)) + Math.abs(Number(p.offsetY || 0)) + Math.abs(Number(p.x || 0)) + Math.abs(Number(p.y || 0));
        if (motion < 24)
            return q;
        var size = this.logicalSize();
        var candidateX = Number(q.x || 0) - Number(delta.x || 0), candidateY = Number(q.y || 0) - Number(delta.y || 0);
        var cx = Number(size.width || 0) / 2.0;
        var currentDistance = Math.abs(Number(q.x || 0) - cx);
        var candidateDistance = Math.abs(candidateX - cx);
        // Authored attack choreography often moves a battler to the visual stage
        // centre. Battle-format offsets must not shift that authored destination.
        // Only compensate when removing the formation offset clearly restores a
        // more central authored point; idle/shake keys remain slot-relative.
        if (candidateDistance + 12 < currentDistance)
            return { x: candidateX, y: candidateY };
        return q;
    };
    BattlePreview.prototype.resolveObjectPoint = function (o, p) {
        var _a;
        var q = this.resolvePoint(p);
        var anchor = String((p && p.anchor) || "").toLowerCase();
        var source = (this.animation && this.animation.source) || {};
        var manualSpace = !!(o && o.coordinateSpaceManual === true);
        var explicitSpace = String((o && o.coordinateSpace) || "auto").toLowerCase();
        var role = (manualSpace && explicitSpace === "screen") ? "" : this.contextRoleForObject(o);
        if (source.contextAutoAdapt !== false) q = this.legacySingleTargetScreenPoint(o, p, q);
        if ((anchor === "screen" || anchor === "") && source.contextAutoAdapt !== false) {
            var screenRoleTransform = role ? this.contextualScreenRolePoint(o, p, q, role) : { point: q, applied: false };
            q = screenRoleTransform.point;
            if (role && !screenRoleTransform.applied) {
                var delta = this.formationOffsetForRole(role);
                q = { x: Number(q.x || 0) + Number(delta.x || 0), y: Number(q.y || 0) + Number(delta.y || 0) };
            }
            var replicaRole = this.replicaTargetOverride ? "target" : (this.replicaUserOverride ? "user" : "");
            if (replicaRole) {
                var replicaShift = this.replicaRoleShift(replicaRole);
                q = { x: Number(q.x || 0) + Number(replicaShift.x || 0), y: Number(q.y || 0) + Number(replicaShift.y || 0) };
            }
        }
        if (source.contextAutoAdapt !== false)
            q = this.authoredStageBattlerPoint(o, p, q);
        // Battler choreography (Impact, Dash, authored Position keys, etc.) must
        // not drag unrelated effects. Only an explicitly selected Follow User /
        // Follow Target coordinate space inherits the battler's authored motion.
        // Auto/legacy anchors remain attached to the battler's formation anchor,
        // but do not become child transforms of the moving battler sprite.
        var followSpace = this.clipCoordinateSpace(o);
        if (source.contextAutoAdapt !== false && role && followSpace === role && !(o && o.type === "battler")) {
            var follow = this.authoredRoleFollowDelta(role, this.frame);
            q = { x: Number(q.x || 0) + Number(follow.x || 0), y: Number(q.y || 0) + Number(follow.y || 0) };
            // Split-coordinate elements bound to a role (emitters whose points
            // are anchored to another battler as absolute placeholders) only get
            // the role's authored track motion, ~0 for a static battler. Translate
            // them by the live slot so they follow the actual User/Target instead
            // of freezing at the authored coordinates when the target moves.
            var pointAnchor = String((p && p.anchor) || "").toLowerCase();
            var targetNative = pointAnchor.indexOf("target") >= 0;
            var userNative = pointAnchor.indexOf("user") >= 0 && pointAnchor.indexOf("target") < 0 && role === "user";
            if (!targetNative && !userNative && pointAnchor !== "" && pointAnchor !== "screen") {
                var slot = this.formationOffsetForRole(role);
                q = { x: Number(q.x || 0) + Number(slot.x || 0), y: Number(q.y || 0) + Number(slot.y || 0) };
            }
        }
        // In PBS, the User/Target particle is positioned at the battler focus
        // (visual centre) and then `get_xy_offset` moves its bitmap down by half
        // its height. Our battler renderer uses a bottom-origin, so convert the
        // imported PBS focus coordinate back to that baseline here.
        if ((o === null || o === void 0 ? void 0 : o.type) === "battler" && ((_a = o.imported) === null || _a === void 0 ? void 0 : _a.pbsBattlerParticle) && String((p === null || p === void 0 ? void 0 : p.anchor) || "").startsWith("pbs:"))
            q.y += this.pbsBattlerBaselineOffset(o);
        return q;
    };
    BattlePreview.prototype.samplePosition = function (o, frame) {
        var _this = this;
        if (frame === void 0) {
            frame = this.frame;
        }
        if (!o)
            return { x: this.logicalSize().width / 2, y: this.logicalSize().height / 2 };
        var ks = sortPositionKeys(o);
        if (!ks.length)
            return { x: this.logicalSize().width / 2, y: this.logicalSize().height / 2 };
        var sampleAxis = function (axis) {
            var enabled = ks.filter(function (k) { return axis === "x" ? k.axisX !== false : k.axisY !== false; });
            if (!enabled.length)
                return axis === "x" ? _this.logicalSize().width / 2 : _this.logicalSize().height / 2;
            var component = function (k) {
                var p = _this.resolveObjectPoint(o, k.point);
                return axis === "x" ? p.x : p.y;
            };
            if (frame <= enabled[0].frame)
                return component(enabled[0]);
            if (frame >= enabled.at(-1).frame)
                return component(enabled.at(-1));
            for (var i = 0; i < enabled.length - 1; i++) {
                var a = enabled[i], b = enabled[i + 1];
                if (frame < a.frame || frame > b.frame)
                    continue;
                var t = ease((frame - a.frame) / Math.max(.0001, b.frame - a.frame), a.easing || "ease_both");
                return lerp(component(a), component(b), t);
            }
            return component(enabled[0]);
        };
        return { x: sampleAxis("x"), y: sampleAxis("y") };
    };
    BattlePreview.prototype.displayPosition = function (o, frame) {
        if (frame === void 0) frame = this.frame;
        var q = this.samplePosition(o, frame);
        var ox = this.contextOverrideValue(o, "offsetX", frame, 0);
        var oy = this.contextOverrideValue(o, "offsetY", frame, 0);
        q = { x: Number(q.x || 0) + Number(ox || 0), y: Number(q.y || 0) + Number(oy || 0) };
        return q;
    };
    BattlePreview.prototype.displayResolvedPoint = function (o, point) {
        var q = this.resolveObjectPoint(o, point);
        var ox = this.contextOverrideValue(o, "offsetX", this.frame, 0);
        var oy = this.contextOverrideValue(o, "offsetY", this.frame, 0);
        q = { x: Number(q.x || 0) + Number(ox || 0), y: Number(q.y || 0) + Number(oy || 0) };
        return q;
    };
    BattlePreview.prototype.active = function (o, frame) {
        if (frame === void 0) {
            frame = this.frame;
        }
        var _a, _b, _c, _d, _e, _f, _g, _h;
        if (!o)
            return false;
        if (o.enabled === false)
            return false;
        if (o.type === "battler" || o.type === "camera")
            return sampleVisible(o, frame);
        var emitter = String(((_a = o.pbs) === null || _a === void 0 ? void 0 : _a.emitter) || ((_b = o.pbs) === null || _b === void 0 ? void 0 : _b.emitterType) || "none").toLowerCase();
        if (emitter && emitter !== "none")
            return frame >= 0 && frame <= Number((_e = (_d = (_c = this.animation) === null || _c === void 0 ? void 0 : _c.duration) !== null && _d !== void 0 ? _d : o.endFrame) !== null && _e !== void 0 ? _e : 0);
        if (!sampleVisible(o, frame))
            return false;
        return frame >= Number(o.startFrame || 0) && frame <= Number((_h = (_f = o.endFrame) !== null && _f !== void 0 ? _f : (_g = this.animation) === null || _g === void 0 ? void 0 : _g.duration) !== null && _h !== void 0 ? _h : 0);
    };
    BattlePreview.prototype.draw = function () {
        if (!this.ctx)
            return;
        var tr = this.resizeCanvas(), c = this.ctx;
        c.clearRect(0, 0, tr.width, tr.height);
        c.fillStyle = css("--canvas-bg", "#0e1017");
        c.fillRect(0, 0, tr.width, tr.height);
        c.save();
        c.translate(tr.offsetX, tr.offsetY);
        c.scale(tr.scale, tr.scale);
        this.drawBattleScene();
        c.restore();
    };
    BattlePreview.prototype.cameraFollowPoint = function (side) {
        var role = side === "target" ? "target" : "user";
        var anchors = this.anchors();
        // Camera focus follows the semantic battler SLOT, never the sprite after
        // BAS position/size choreography has been applied. Following the animated
        // sprite made Impact, Dash and recoil visually cancel themselves.
        var stable = anchors[role] || anchors[role + "_battler"] || { x: this.logicalSize().width / 2, y: this.logicalSize().height / 2 };
        return { x: Number(stable.x || 0), y: Number(stable.y || 0) };
    };
    BattlePreview.prototype.cameraFocusEntries = function (cam) {
        return (cam && Array.isArray(cam.logic) ? cam.logic : []).filter(function (entry) {
            return !!entry && ["focus", "follow", "focus_clear"].includes(String(entry.type || "").toLowerCase());
        }).slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
    };
    BattlePreview.prototype.cameraFocusDirective = function (cam) {
        var list = this.cameraFocusEntries(cam), chosen = null;
        for (var i = 0; i < list.length; i++) {
            if (Number(list[i].frame || 0) > Number(this.frame || 0))
                break;
            chosen = list[i];
        }
        if (!chosen)
            return null;
        var chosenType = String(chosen.type || "").toLowerCase();
        var start = Number(chosen.frame || 0), duration = Math.max(0, Number(chosen.duration || 0));
        var t = duration <= 0 ? 1 : clamp(ease((Number(this.frame || 0) - start) / Math.max(.0001, duration), chosen.easing || "ease_out"), 0, 1);
        if (chosenType === "focus_clear") {
            if (t >= 1)
                return null;
            var previous = null, chosenIndex = list.indexOf(chosen);
            for (var j = chosenIndex - 1; j >= 0; j--) {
                var pt = String(list[j].type || "").toLowerCase();
                if (pt === "focus_clear")
                    break;
                previous = list[j];
                break;
            }
            if (!previous)
                return null;
            return { side: String(previous.side || "user").toLowerCase() === "target" ? "target" : "user", t: 1 - t, entry: chosen, releasing: true };
        }
        var side = String(chosen.side || "user").toLowerCase() === "target" ? "target" : "user";
        return { side: side, t: t, entry: chosen };
    };
    BattlePreview.prototype.cameraFocusOffset = function (cam) {
        var list = this.cameraFocusEntries(cam), chosenIndex = -1;
        for (var i = 0; i < list.length; i++) {
            if (Number(list[i].frame || 0) > Number(this.frame || 0))
                break;
            chosenIndex = i;
        }
        if (chosenIndex < 0)
            return { x: 0, y: 0, activeSide: null };
        var chosen = list[chosenIndex], type = String(chosen.type || "").toLowerCase();
        var start = Number(chosen.frame || 0), duration = Math.max(0, Number(chosen.duration || 0));
        var t = duration <= 0 ? 1 : clamp(ease((Number(this.frame || 0) - start) / Math.max(.0001, duration), chosen.easing || "ease_out"), 0, 1);
        var size = this.logicalSize(), center = { x: Number(size.width || 0) / 2, y: Number(size.height || 0) / 2 };
        var offsetForSide = function (side) {
            if (!side)
                return { x: 0, y: 0 };
            var fp = this.cameraFollowPoint(side);
            return { x: Number(fp.x || 0) - center.x, y: Number(fp.y || 0) - center.y };
        }.bind(this);
        var previousSide = null;
        if (chosenIndex > 0) {
            var previous = list[chosenIndex - 1], previousType = String(previous.type || "").toLowerCase();
            if (previousType !== "focus_clear")
                previousSide = String(previous.side || "user").toLowerCase() === "target" ? "target" : "user";
        }
        var currentSide = type === "focus_clear" ? null : (String(chosen.side || "user").toLowerCase() === "target" ? "target" : "user");
        var from = offsetForSide(previousSide), to = offsetForSide(currentSide);
        return {
            x: from.x + (to.x - from.x) * t,
            y: from.y + (to.y - from.y) * t,
            activeSide: currentSide,
            releasing: type === "focus_clear" && t < 1
        };
    };
    BattlePreview.prototype.cameraBoundsMode = function () {
        var scene = (this.animation && this.animation.scene) || {};
        var mode = String(scene.cameraBoundsMode || "auto").toLowerCase();
        if (mode === "screen" || mode === "extended")
            return mode;
        // Auto is adaptive: preserve authored zoom (including zoom-out) when
        // moving animations between screen formats. Strict edge-clamping is
        // available only when the author explicitly chooses Screen.
        return "adaptive";
    };
    BattlePreview.prototype.constrainCameraState = function (x, y, zoom, rot) {
        var boundsMode = this.cameraBoundsMode();
        if (boundsMode === "extended")
            return { x: x, y: y, zoom: zoom, rot: rot };
        if (boundsMode === "adaptive")
            return { x: x, y: y, zoom: Math.max(.05, Number(zoom || 1)), rot: rot };
        var size = this.logicalSize(), width = Math.max(1, Number(size.width || 1)), height = Math.max(1, Number(size.height || 1));
        var ac = Math.abs(Math.cos(rot || 0)), as = Math.abs(Math.sin(rot || 0));
        // A normal Essentials battleback is screen-sized. Keep the inverse camera
        // viewport inside that rectangle. Rotation may require a little extra zoom
        // even while centered; otherwise black/empty corners are unavoidable.
        var minZoomX = (width * ac + height * as) / width;
        var minZoomY = (width * as + height * ac) / height;
        zoom = Math.max(1, Number(zoom || 1), minZoomX, minZoomY);
        var reqHalfX = (width * ac + height * as) / (2 * zoom);
        var reqHalfY = (width * as + height * ac) / (2 * zoom);
        var maxX = Math.max(0, width / 2 - reqHalfX);
        var maxY = Math.max(0, height / 2 - reqHalfY);
        return { x: clamp(Number(x || 0), -maxX, maxX), y: clamp(Number(y || 0), -maxY, maxY), zoom: zoom, rot: rot };
    };
    BattlePreview.prototype.cameraState = function () {
        var e_9, _q;
        var cam = getCameraTrack(this.animation);
        // The timeline eye is a real preview mute. Camera used to bypass the
        // normal `active()` path, so disabling its row hid only the row while
        // pan/zoom/rotation/shake continued to affect the canvas.
        var cameraMuted = !!cam && (cam.enabled === false || !sampleVisible(cam, this.frame));
        if (cameraMuted)
            return { x: 0, y: 0, zoom: 1, rot: 0 };
        var x = cam ? sampleValue(cam, "cameraX", this.frame, 0) : 0;
        var y = cam ? sampleValue(cam, "cameraY", this.frame, 0) : 0;
        if (cam) {
            x += Number(this.contextOverrideValue(cam, "cameraX", this.frame, 0) || 0);
            y += Number(this.contextOverrideValue(cam, "cameraY", this.frame, 0) || 0);
        }
        var rs = this.responsiveScale();
        x *= rs.x;
        y *= rs.y;
        var zoom = cam ? Math.max(.05, sampleValue(cam, "cameraZoom", this.frame, 100) / 100) : 1;
        if (cam) zoom *= Math.max(.01, Number(this.contextOverrideValue(cam, "cameraZoom", this.frame, 100) || 100) / 100);
        var rotDeg = cam ? sampleValue(cam, "cameraRotation", this.frame, 0) : 0;
        if (cam) rotDeg += Number(this.contextOverrideValue(cam, "cameraRotation", this.frame, 0) || 0);
        var rot = rotDeg * Math.PI / 180;
        var focusOffset = this.cameraFocusOffset(cam);
        // Focus is a semantic tracking offset layered on top of authored Pan X/Y.
        // Interpolate from the previous focus target instead of dropping to the
        // neutral camera for one frame when switching User <-> Target.
        x += Number(focusOffset.x || 0);
        y += Number(focusOffset.y || 0);
        // Clamp the authored/focus camera first. Shake is then layered on top so
        // a focus sitting on a camera bound cannot clip every other shake frame.
        var constrained = this.constrainCameraState(x, y, zoom, rot);
        x = constrained.x;
        y = constrained.y;
        zoom = constrained.zoom;
        try {
            // Deterministic alternating offsets keep every active shake frame visible
            // while still making scrubbing and playback match exactly.
            for (var _r = __values(((this.animation && this.animation.events) || [])), _s = _r.next(); !_s.done; _s = _r.next()) {
                var ev = _s.value;
                if (String(ev.type || "") !== "screen_shake")
                    continue;
                var start = Number(ev.frame || 0), dur = Math.max(1, Number(ev.duration || 1));
                if (this.frame < start || this.frame >= start + dur)
                    continue;
                var local = this.frame - start, falloff = clamp(1 - local / dur, 0, 1), strength = Number(ev.strength || 0) * falloff, axis = Number(ev.axis || 0);
                var step = Math.max(0, Math.floor(local)) % 8;
                var xPattern = [1, -0.82, 0.68, -0.58, 0.48, -0.38, 0.28, -0.18];
                var yPattern = [-0.46, 0.41, -0.36, 0.31, -0.26, 0.21, -0.16, 0.11];
                var dx = xPattern[step] * strength;
                var dy = yPattern[step] * strength;
                if (axis !== 2)
                    x += dx;
                if (axis !== 1)
                    y += dy;
            }
        }
        catch (e_9_1) {
            e_9 = { error: e_9_1 };
        }
        finally {
            try {
                if (_s && !_s.done && (_q = _r.return))
                    _q.call(_r);
            }
            finally {
                if (e_9)
                    throw e_9.error;
            }
        }
        return { x: x, y: y, zoom: zoom, rot: rot };
    };
    BattlePreview.prototype.drawBattleScene = function () {
        var e_10, _q;
        var _this = this;
        var _a, _b;
        var c = this.ctx, _r = this.logicalSize(), width = _r.width, height = _r.height, accent = css("--accent", "#7b82ff"), text = css("--text-secondary", "#b7bac8");
        this.hitShapes = [];
        c.fillStyle = "#0b0d13";
        c.fillRect(0, 0, width, height);
        var cam = this.cameraState();
        this.sceneBaseTransform = c.getTransform ? c.getTransform() : null;
        c.save();
        c.translate(width / 2, height / 2);
        c.scale(cam.zoom, cam.zoom);
        c.rotate(cam.rot);
        c.translate(-width / 2 - cam.x, -height / 2 - cam.y);
        this.drawBackground(width, height);
        this.drawBase("target", this.sceneImages.enemyBase);
        this.drawBase("user", this.sceneImages.playerBase);
        var mainFrame = this.frame;
        if (!this.playing && this.onionMode !== "off") {
            var ghostFrames = [];
            if ((this.onionMode === "prev" || this.onionMode === "both") && mainFrame > 0)
                ghostFrames.push(mainFrame - 1);
            if ((this.onionMode === "next" || this.onionMode === "both") && this.animation && mainFrame < Number(this.animation.duration || 0))
                ghostFrames.push(mainFrame + 1);
            try {
                for (var ghostFrames_1 = __values(ghostFrames), ghostFrames_1_1 = ghostFrames_1.next(); !ghostFrames_1_1.done; ghostFrames_1_1 = ghostFrames_1.next()) {
                    var gf = ghostFrames_1_1.value;
                    this.drawOnionFrame(gf, 0.24, accent);
                }
            }
            catch (e_10_1) {
                e_10 = { error: e_10_1 };
            }
            finally {
                try {
                    if (ghostFrames_1_1 && !ghostFrames_1_1.done && (_q = ghostFrames_1.return))
                        _q.call(ghostFrames_1);
                }
                finally {
                    if (e_10)
                        throw e_10.error;
                }
            }
            this.frame = mainFrame;
        }
        var drawables = [], ub = getBattlerTrack(this.animation, "user"), tb = getBattlerTrack(this.animation, "target"), ui = this.semanticIndex("user"), ti = this.semanticIndex("target"), uinfo = this.semanticInfo("user"), tinfo = this.semanticInfo("target"), ubundle = this.battlerImageAndMeta("user", ub), tbundle = this.battlerImageAndMeta("target", tb);
        if (ub && this.active(ub))
            drawables.push({ z: this.battlerLayerZ("user"), order: 1000, draw: function () { return _this.drawBattler(ubundle.image, uinfo, ub, "USER", text, ui % 2 === 0, (ub === null || ub === void 0 ? void 0 : ub.id) === _this.selectedObjectId, accent, ubundle.meta); } });
        if (tb && this.active(tb))
            drawables.push({ z: this.battlerLayerZ("target"), order: 1001, draw: function () { return _this.drawBattler(tbundle.image, tinfo, tb, "TARGET", text, ti % 2 === 0, (tb === null || tb === void 0 ? void 0 : tb.id) === _this.selectedObjectId, accent, tbundle.meta); } });
        // Show the rest of the active side-size in doubles/triples/asymmetric
        // previews. They are positional references, not editable animation
        // battlers, so User/Target still represent the exact actors.
        var affectedSet = this.affectedBattlerIndexSet();
        var hideUnaffectedAdjacents = !!(this.animation && this.animation.hidesAdjacents);
        var replicateTargetReaction = !!(this.animation && this.animation.source && this.animation.source.autoReplicateAffected === true);
        var targetAnimPos = tb ? this.samplePosition(tb) : null;
        var targetDeltaX = targetAnimPos && tinfo ? Number(targetAnimPos.x || 0) - Number(tinfo.x || 0) : 0;
        var targetDeltaY = targetAnimPos && tinfo ? Number(targetAnimPos.y || 0) - Number(tinfo.y || 0) : 0;
        var adjacent = this.semanticContextBattlers().filter(function (b) { return Number(b.index) !== Number(ui) && Number(b.index) !== Number(ti); });
        adjacent.forEach(function (b, i) {
            var idx = Number(b.index);
            var isAffected = affectedSet.has(idx);
            // Always keep non-primary battlers visible as formation references in the editor.
            // hidesAdjacents is an animation/gameplay behavior; using it to remove the 2v2/3v3
            // reference formation made allies/opponents appear to be missing and hid bad targeting.
            var onUserParty = Number(idx) % 2 === Number(ui) % 2;
            var sourceTrack = onUserParty ? ub : tb;
            var fallbackBundle = onUserParty ? ubundle : tbundle;
            var bundle = _this.contextBattlerBundle(idx, fallbackBundle);
            if (!sourceTrack || !bundle)
                return;
            var metricX = b.bitmapReal === false ? Number((bundle.meta && bundle.meta.metricX) || 0) : 0, metricY = b.bitmapReal === false ? Number((bundle.meta && bundle.meta.metricY) || 0) : 0;
            var info = { index: idx, x: Number(b.x || 0) + metricX, y: Number(b.y || 0) + metricY, focusX: Number(b.focusX || b.x || 0) + metricX, focusY: Number(b.focusY || b.y || 0) + metricY, z: (idx % 2 === 0 ? 1050 : 850), bitmapWidth: Number(b.bitmapWidth || 0), bitmapHeight: Number(b.bitmapHeight || 0), bitmapReal: b.bitmapReal !== false, zoomX: Number(b.zoomX || 1), zoomY: Number(b.zoomY || 1), ox: Number(b.ox || 0), oy: Number(b.oy || 0), species: String(b.species || ""), visible: true };
            var reaction = replicateTargetReaction && isAffected && tb ? tb : null;
            var temp = { id: "adjacent_".concat(b.index), type: "battler", side: onUserParty ? "user" : "target", enabled: true, locked: true, visual: reaction ? Object.assign({}, reaction.visual || {}) : { size: 100, scaleX: 100, scaleY: 100, opacity: 100, rotation: 0, z: 0, blend: 0, flip: 0 }, visibleKeys: reaction ? JSON.parse(JSON.stringify(reaction.visibleKeys || [{ frame: 0, value: true }])) : [{ frame: 0, value: true }], positionKeys: [{ frame: 0, easing: "linear", point: { anchor: "screen", x: info.x + (reaction ? targetDeltaX : 0), y: info.y + (reaction ? targetDeltaY : 0), offsetX: 0, offsetY: 0 } }], valueKeys: reaction ? JSON.parse(JSON.stringify(reaction.valueKeys || {})) : {}, fxOps: reaction ? JSON.parse(JSON.stringify(reaction.fxOps || [])) : [], startFrame: 0, endFrame: Number((_this.animation && _this.animation.duration) || 9999) };
            if (reaction && !_this.active(temp))
                return;
            drawables.push({ z: Number(info.z), order: 900 + i, draw: function () { return _this.drawBattler(bundle.image, info, temp, "", text, idx % 2 === 0, false, accent, bundle.meta, isAffected ? 1.0 : 0.82); } });
        });
        if (this.animation) {
            var selectedAnimObject_1 = getAnimatable(this.animation, this.selectedObjectId);
            var soloEmitter_1 = !!(this.emitterSoloPreview && selectedAnimObject_1 && selectedAnimObject_1.type === "clip" && selectedAnimObject_1.pbs && String(selectedAnimObject_1.pbs.emitter || selectedAnimObject_1.pbs.emitterType || "none").toLowerCase() !== "none");
            getAllClips(this.animation).forEach(function (clip, i) {
                if (!_this.active(clip))
                    return;
                if (soloEmitter_1 && clip.id !== _this.selectedObjectId)
                    return;
                drawables.push({ z: _this.clipZ(clip), order: 2000 + (i * 20), draw: function () { return _this.drawClipOrEmitter(clip, clip.id === _this.selectedObjectId, accent); } });
                var replicas = _this.replicaBattlersForClip(clip);
                replicas.forEach(function (replica, ri) { return drawables.push({ z: _this.clipZ(clip) + ((ri + 1) * 0.001), order: 2001 + (i * 20) + ri, draw: function () { return _this.withReplicaBattler(replica, function () { return _this.drawClipOrEmitter(clip, false, accent); }); } }); });
            });
        }
        drawables.sort(function (a, b) { return a.z - b.z || a.order - b.order; }).forEach(function (x) { return x.draw(); });
        c.restore();
        this.drawScreenEvents(width, height);
        c.fillStyle = "rgba(0,0,0,.48)";
        c.fillRect(8, 8, Math.min(width - 16, 390), 24);
        c.fillStyle = text;
        c.font = "10px sans-serif";
        c.fillText("".concat(((_a = this.context) === null || _a === void 0 ? void 0 : _a.source) || "default", " \u00B7 ").concat(width, "\u00D7").concat(height).concat(((_b = this.context) === null || _b === void 0 ? void 0 : _b.captureKind) ? " \u00B7 ".concat(this.context.captureKind) : ""), 14, 24);
    };
    BattlePreview.prototype.drawOnionFrame = function (frame, alpha, accent) {
        var e_11, _q;
        if (alpha === void 0) {
            alpha = 0.24;
        }
        if (accent === void 0) {
            accent = "#7b82ff";
        }
        if (!this.animation)
            return;
        var old = this.frame, c = this.ctx;
        this.frame = frame;
        c.save();
        c.globalAlpha = alpha;
        c.filter = "opacity(45%)";
        var ub = getBattlerTrack(this.animation, "user"), tb = getBattlerTrack(this.animation, "target"), uinfo = this.semanticInfo("user"), tinfo = this.semanticInfo("target"), ui = this.semanticIndex("user"), ti = this.semanticIndex("target"), ubundle = this.battlerImageAndMeta("user", ub), tbundle = this.battlerImageAndMeta("target", tb);
        if (ub && this.active(ub, frame))
            this.drawBattler(ubundle.image, uinfo, ub, "", accent, ui % 2 === 0, false, accent, ubundle.meta, alpha);
        if (tb && this.active(tb, frame))
            this.drawBattler(tbundle.image, tinfo, tb, "", accent, ti % 2 === 0, false, accent, tbundle.meta, alpha);
        try {
            for (var _r = __values(getAllClips(this.animation)), _s = _r.next(); !_s.done; _s = _r.next()) {
                var clip = _s.value;
                if (this.active(clip, frame))
                    this.drawClipOrEmitter(clip, false, accent, alpha);
            }
        }
        catch (e_11_1) {
            e_11 = { error: e_11_1 };
        }
        finally {
            try {
                if (_s && !_s.done && (_q = _r.return))
                    _q.call(_r);
            }
            finally {
                if (e_11)
                    throw e_11.error;
            }
        }
        c.restore();
        this.frame = old;
    };
    BattlePreview.prototype.drawBackground = function (width, height) {
        var c = this.ctx, im = this.sceneImages.background;
        if (im) {
            c.imageSmoothingEnabled = false;
            c.drawImage(im, 0, 0, width, height);
            return;
        }
        var g = c.createLinearGradient(0, 0, 0, height);
        g.addColorStop(0, "#090a10");
        g.addColorStop(.58, "#11131b");
        g.addColorStop(1, "#1b1e29");
        c.fillStyle = g;
        c.fillRect(0, 0, width, height);
    };
    BattlePreview.prototype.drawBase = function (side, im) {
        var _a, _b, _c, _d, _e, _f;
        if (!im)
            return;
        var c = this.ctx, pos = ((_b = (_a = this.context) === null || _a === void 0 ? void 0 : _a.bases) === null || _b === void 0 ? void 0 : _b[side]) || this.baseBattlerPosition(side), x = Number((_c = pos.x) !== null && _c !== void 0 ? _c : 0), y = Number((_d = pos.y) !== null && _d !== void 0 ? _d : 0), zx = Number((_e = pos.zoomX) !== null && _e !== void 0 ? _e : 1), zy = Number((_f = pos.zoomY) !== null && _f !== void 0 ? _f : 1), w = im.width * zx, h = im.height * zy;
        c.save();
        c.globalAlpha = pos.visible === false ? 0 : 1;
        c.imageSmoothingEnabled = false;
        var oy = side === "user" ? h : h / 2;
        c.drawImage(im, x - w / 2, y - oy, w, h);
        c.restore();
    };
    BattlePreview.prototype.drawBattler = function (im, ctxInfo, obj, label, text, isPlayerSide, selected, accent, meta, alphaMult) {
        if (meta === void 0) {
            meta = {};
        }
        if (alphaMult === void 0) {
            alphaMult = 1;
        }
        var _a, _b;
        var runtimeMatch = this.contextMatchesBattler(ctxInfo, meta);
        var runtimePoseMatch = runtimeMatch || (this.contextSpeciesMatchesBattler(ctxInfo, meta) && (ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.bitmapReal) !== false && Number((ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.bitmapHeight) || 0) > 0);
        var c = this.ctx, pos = this.samplePosition(obj), contextOverride = this.contextOverrideForObject(obj), fi = this.battlerFrameInfo(im, meta, ctxInfo, obj), requestedView = String((meta && meta.view) || (isPlayerSide ? "back" : "front")).toLowerCase(), baseScale = this.resolveBattlerScale(fi.scale, requestedView === "back"), ctxZoomX = runtimePoseMatch ? Number((_a = ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.zoomX) !== null && _a !== void 0 ? _a : 1) : 1, ctxZoomY = runtimePoseMatch ? Number((_b = ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.zoomY) !== null && _b !== void 0 ? _b : 1) : 1, viewScale = Math.max(.01, sampleValue(obj, "viewScale", this.frame, 100) / 100), sx = Math.abs(sampleValue(obj, "scaleX", this.frame, 100) / 100) * sampleValue(obj, "size", this.frame, 100) / 100 * viewScale * ctxZoomX * baseScale * Math.max(.01, Number(this.contextOverrideValue(obj, "scaleX", this.frame, 100) || 100) / 100), sy = Math.abs(sampleValue(obj, "scaleY", this.frame, 100) / 100) * sampleValue(obj, "size", this.frame, 100) / 100 * viewScale * ctxZoomY * baseScale * Math.max(.01, Number(this.contextOverrideValue(obj, "scaleY", this.frame, 100) || 100) / 100), opa = clamp(this.contextOpacityValue(obj, this.frame, sampleValue(obj, "opacity", this.frame, 100)) / 100, 0, 1), ang = (sampleValue(obj, "rotation", this.frame, 0) + Number(this.contextOverrideValue(obj, "rotation", this.frame, 0) || 0) + (runtimePoseMatch ? Number((ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.angle) || 0) : 0)) * Math.PI / 180, flip = sampleValue(obj, "flip", this.frame, 0) >= .5 || (runtimePoseMatch && !!(ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.mirror)), flipY = sampleValue(obj, "flipY", this.frame, 0) >= .5;
        if (contextOverride && contextOverride.flip) flip = !flip;
        if (contextOverride && contextOverride.flipY) flipY = !flipY;
        pos = { x: Number(pos.x || 0) + Number(this.contextOverrideValue(obj, "offsetX", this.frame, 0) || 0), y: Number(pos.y || 0) + Number(this.contextOverrideValue(obj, "offsetY", this.frame, 0) || 0) };
        var w = 80 * sx, h = 80 * sy, drawLeft = pos.x - w / 2, drawTop = pos.y - h;
        c.save();
        c.translate(pos.x, pos.y);
        c.rotate(-ang);
        if (flip || flipY)
            c.scale(flip ? -1 : 1, flipY ? -1 : 1);
        c.globalAlpha = opa * alphaMult;
        if (im) {
            w = fi.sw * sx;
            h = fi.sh * sy;
            c.imageSmoothingEnabled = false;
            var captured = runtimeMatch && (ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.bitmapReal) !== false && Number((ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.bitmapHeight) || 0) > 0;
            // Runtime ox/oy are already expressed in the renderer's scaled
            // bitmap coordinates (e.g. DBK Back 48x46 -> 144x138, ox=72, oy=138).
            // Convert them back to raw PNG units before applying the Studio's
            // current Studio presentation/viewScale; otherwise renderer scale is applied twice.
            var runtimeScaleX = captured && fi.sw > 0 ? Math.max(.0001, Number((ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.bitmapWidth) || fi.sw) / fi.sw) : 1;
            var runtimeScaleY = captured && fi.sh > 0 ? Math.max(.0001, Number((ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.bitmapHeight) || fi.sh) / fi.sh) : 1;
            var baseOx = captured ? Number((ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.ox) || (fi.sw * runtimeScaleX / 2)) / runtimeScaleX : fi.sw / 2, baseOy = captured ? Number((ctxInfo === null || ctxInfo === void 0 ? void 0 : ctxInfo.oy) || (fi.sh * runtimeScaleY)) / runtimeScaleY : fi.sh;
            var absOx = sampleValue(obj, "originX", this.frame, NaN), absOy = sampleValue(obj, "originY", this.frame, NaN), offOx = sampleValue(obj, "originOffsetX", this.frame, 0), offOy = sampleValue(obj, "originOffsetY", this.frame, 0);
            var ox = (Number.isFinite(absOx) ? absOx : baseOx + offOx) * sx, oy = (Number.isFinite(absOy) ? absOy : baseOy + offOy) * sy;
            // Keep the RGSS origin exactly on pos.x/pos.y at every preview scale.
            // Only the bitmap grows; the
            // battler's registered battle position stays fixed.
            drawLeft = pos.x - ox;
            drawTop = pos.y - oy;
            var fx = this.fxImage(im, { sx: fi.sx, sy: fi.sy, sw: fi.sw, sh: fi.sh }, this.applyContextFxCorrection(obj, "tone", this.fxAt(obj, "tone", this.frame)), this.fxAt(obj, "color", this.frame));
            c.drawImage(fx.image, fx.src.sx, fx.src.sy, fx.src.sw, fx.src.sh, -ox, -oy, w, h);
        }
        else {
            c.fillStyle = "rgba(120,135,210,.28)";
            c.beginPath();
            c.ellipse(0, -30, 34, 52, 0, 0, Math.PI * 2);
            c.fill();
        }
        c.restore();
        this.hitShapes.push({ objectId: obj.id, x: drawLeft + w / 2, y: drawTop + h / 2, w: Math.max(28, w), h: Math.max(40, h), kind: "battler" });
        if (selected && !this.playing) {
            c.strokeStyle = accent;
            c.setLineDash([5, 3]);
            c.strokeRect(drawLeft - 5, drawTop - 5, w + 10, h + 10);
            c.setLineDash([]);
        }
        c.fillStyle = text;
        c.font = "9px sans-serif";
        c.textAlign = "center";
        c.fillText(label, pos.x, pos.y + 14);
        c.textAlign = "left";
    };
    BattlePreview.prototype.priorityReference = function (clip) {
        var e_12, _q;
        var contextOverride = this.contextOverrideForObject(clip);
        var explicit = String((contextOverride && contextOverride.priorityReference != null ? contextOverride.priorityReference : (clip && clip.priorityReference)) || "auto").toLowerCase();
        if (explicit !== "auto")
            return explicit;
        var focus = String((clip && clip.pbs && clip.pbs.focus) || "").toLowerCase();
        if (focus.includes("target"))
            return "target";
        if (focus.includes("user"))
            return "user";
        // A clip explicitly following a battler must layer relative to that same battler,
        // even when its authored anchor is screen/absolute. This fixes User-directed effects.
        var space = String((clip && clip.coordinateSpace) || "auto").toLowerCase();
        if (space === "target")
            return "target";
        if (space === "user")
            return "user";
        var keys = Array.isArray(clip && clip.positionKeys) ? __spreadArray([], __read(clip.positionKeys), false).sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); }) : [];
        var anchor = "";
        try {
            for (var keys_3 = __values(keys), keys_3_1 = keys_3.next(); !keys_3_1.done; keys_3_1 = keys_3.next()) {
                var key = keys_3_1.value;
                if (Number(key.frame || 0) <= this.frame)
                    anchor = String((key.point && key.point.anchor) || "").toLowerCase();
                else
                    break;
            }
        }
        catch (e_12_1) {
            e_12 = { error: e_12_1 };
        }
        finally {
            try {
                if (keys_3_1 && !keys_3_1.done && (_q = keys_3.return))
                    _q.call(keys_3);
            }
            finally {
                if (e_12)
                    throw e_12.error;
            }
        }
        if (!anchor && keys.length)
            anchor = String((keys[0].point && keys[0].point.anchor) || "").toLowerCase();
        if (anchor.includes("target"))
            return "target";
        if (anchor.includes("user"))
            return "user";
        return "absolute";
    };
    BattlePreview.prototype.battlerLayerZ = function (side) {
        var info = this.semanticInfo(side) || {};
        var track = getBattlerTrack(this.animation, side);
        var idx = this.semanticIndex(side), fallback = 1000 + ((100 * (Math.floor(Number(idx || 0) / 2) + 1)) * (Number(idx || 0) % 2 === 0 ? 1 : -1));
        var raw = Number(info.z);
        var base = Number.isFinite(raw) ? raw : fallback;
        var contextOverride = this.contextOverrideForObject(track);
        return base + sampleValue(track, "z", this.frame, 0) + Number(this.contextOverrideValue(track, "zOffset", this.frame, 0) || 0);
    };
    BattlePreview.prototype.applyLayerPriority = function (clip, baseZ) {
        var contextOverride = this.contextOverrideForObject(clip);
        var priority = sampleValue(clip, "priority", this.frame, Number((clip && clip.priority) || 0)) + Number(this.contextOverrideValue(clip, "priorityOffset", this.frame, 0) || 0);
        var contextOverride = this.contextOverrideForObject(clip);
        var explicit = String((contextOverride && contextOverride.priorityReference != null ? contextOverride.priorityReference : (clip && clip.priorityReference)) || "auto").toLowerCase();
        // "Z absoluto" is genuinely absolute. Auto that cannot infer a battler
        // remains a relative offset over the clip's existing Z.
        if (explicit === "absolute")
            return priority;
        var ref = this.priorityReference(clip);
        // Explicit battler references must never tie the battler's exact Z. RGSS
        // can resolve equal-Z sprites by creation order, so User/Target + 0 means
        // the normal effect layer immediately above that battler. Negative values
        // still go behind it, while positive values add more foreground steps.
        if (explicit === "auto" && !priority)
            return baseZ;
        var battlerOffset = priority >= 0 ? priority + 1 : priority;
        if (ref === "target")
            return this.battlerLayerZ("target") + battlerOffset;
        if (ref === "user")
            return this.battlerLayerZ("user") + battlerOffset;
        if (ref === "foreground")
            return 2000 + priority;
        if (ref === "background")
            return 100 + priority;
        return Number(baseZ || 0) + priority;
    };
    BattlePreview.prototype.clipZ = function (clip) {
        var _this = this;
        var _a, _b, _c;
        var focus = String(((_a = clip.pbs) === null || _a === void 0 ? void 0 : _a.focus) || ""), contextOverride = this.contextOverrideForObject(clip), z = sampleValue(clip, "z", this.frame, Number(((_b = clip.visual) === null || _b === void 0 ? void 0 : _b.z) || 0)) + Number(this.contextOverrideValue(clip, "zOffset", this.frame, 0) || 0);
        var rgssBattlerZ = function (idx) { return 1000 + ((100 * (Math.floor(Number(idx || 0) / 2) + 1)) * (Number(idx || 0) % 2 === 0 ? 1 : -1)); };
        var apply = function (value, base) { return Array.isArray(base) ? _this.applyPbsZFocus(value, base) : Number(value || 0) + Number(base || 0); };
        var baseZ = z;
        if (((_c = clip.imported) === null || _c === void 0 ? void 0 : _c.format) === "pbs" || clip.type === "pbs-particle") {
            var ui = this.semanticIndex("user"), ti = this.semanticIndex("target"), uz = rgssBattlerZ(ui), tz = rgssBattlerZ(ti);
            if (focus === "foreground")
                baseZ = 2000 + z;
            else if (focus === "midground")
                baseZ = 1000 + z;
            else if (focus === "background")
                baseZ = 100 + z;
            else if (focus === "user" || focus === "user_position")
                baseZ = apply(z, uz);
            else if (focus === "target" || focus === "target_position")
                baseZ = apply(z, tz);
            else if (focus.includes("user") && focus.includes("target"))
                baseZ = apply(z, [uz, tz]);
            else if (focus === "user_side_foreground")
                baseZ = 1000 + (ui % 2 === 0 ? 1000 : 0) + z;
            else if (focus === "target_side_foreground")
                baseZ = 1000 + (ti % 2 === 0 ? 1000 : 0) + z;
            else if (focus === "user_side_background")
                baseZ = (ui % 2 === 0 ? 1000 : 0) + z;
            else if (focus === "target_side_background")
                baseZ = (ti % 2 === 0 ? 1000 : 0) + z;
        }
        return this.applyLayerPriority(clip, baseZ);
    };
    BattlePreview.prototype.applyPbsZFocus = function (z, focus) {
        z = Number(z || 0);
        var distance = -100, u = Number((focus === null || focus === void 0 ? void 0 : focus[0]) || 0), t = Number((focus === null || focus === void 0 ? void 0 : focus[1]) || 0);
        if (z >= 0)
            return u > t ? u + z : u - z;
        if (z <= distance)
            return u > t ? t + z + distance : t - z + distance;
        return u + ((z / distance) * (t - u));
    };
    BattlePreview.prototype.drawClipOrEmitter = function (clip, selected, accent, alphaMult) {
        if (alphaMult === void 0) {
            alphaMult = 1;
        }
        var _a, _b;
        var emitter = String(((_a = clip.pbs) === null || _a === void 0 ? void 0 : _a.emitter) || ((_b = clip.pbs) === null || _b === void 0 ? void 0 : _b.emitterType) || "none").toLowerCase();
        if (emitter && emitter !== "none")
            this.drawEmitter(clip, selected, accent, alphaMult);
        else
            this.drawClip(clip, selected, accent, this.frame, null, alphaMult);
    };
    BattlePreview.prototype.emitterValue = function (clip, name, frame, def) {
        var e_13, _q;
        if (def === void 0) {
            def = 0;
        }
        var _a, _b;
        var pbs = (clip && clip.pbs) || {};
        var emitterCommands = pbs.emitterCommands || {};
        var list = name ? emitterCommands[name] : null;
        var resolvedName = name;
        if (!list || !list.length) {
            var aliases = (typeof EMITTER_KEY_ALIASES !== "undefined" && EMITTER_KEY_ALIASES && name && EMITTER_KEY_ALIASES[name]) || null;
            if (aliases && aliases.length) {
                for (var ai = 0; ai < aliases.length; ai++) {
                    var alt = aliases[ai];
                    if (emitterCommands[alt] && emitterCommands[alt].length) {
                        list = emitterCommands[alt];
                        resolvedName = alt;
                        break;
                    }
                }
            }
        }
        if (!list || !list.length) {
            var ctxVal = this.contextParameterValue(clip, "emitter", name, frame, undefined);
            if (ctxVal === undefined) {
                var aliases = (typeof EMITTER_KEY_ALIASES !== "undefined" && EMITTER_KEY_ALIASES && name && EMITTER_KEY_ALIASES[name]) || null;
                if (aliases && aliases.length) {
                    for (var ai = 0; ai < aliases.length; ai++) {
                        ctxVal = this.contextParameterValue(clip, "emitter", aliases[ai], frame, undefined);
                        if (ctxVal !== undefined) break;
                    }
                }
            }
            if (ctxVal !== undefined) return ctxVal;
            if (pbs[name] !== undefined) return pbs[name];
            var aliases2 = (typeof EMITTER_KEY_ALIASES !== "undefined" && EMITTER_KEY_ALIASES && name && EMITTER_KEY_ALIASES[name]) || null;
            if (aliases2 && aliases2.length) {
                for (var ai = 0; ai < aliases2.length; ai++) {
                    if (pbs[aliases2[ai]] !== undefined) return pbs[aliases2[ai]];
                }
            }
            return def;
        }
        var value = def;
        try {
            for (var list_1 = __values(list), list_1_1 = list_1.next(); !list_1_1.done; list_1_1 = list_1.next()) {
                var c = list_1_1.value;
                if (frame < c.frame)
                    break;
                if (c.duration > 0 && frame < c.frame + c.duration) {
                    var t = ease((frame - c.frame) / c.duration, c.easing || "linear");
                    var interpolated = typeof c.value === "number" ? lerp(value, c.value, t) : c.value;
                    return this.contextParameterValue(clip, "emitter", resolvedName, frame, interpolated);
                }
                value = c.value;
            }
        }
        catch (e_13_1) {
            e_13 = { error: e_13_1 };
        }
        finally {
            try {
                if (list_1_1 && !list_1_1.done && (_q = list_1.return))
                    _q.call(list_1);
            }
            finally {
                if (e_13)
                    throw e_13.error;
            }
        }
        return this.contextParameterValue(clip, "emitter", resolvedName, frame, value);
    };
    BattlePreview.prototype.emitterSemanticAngle = function (clip, frame, fallback) {
        var pbs = clip && clip.pbs ? clip.pbs : {};
        var destination = String(pbs.emitterDestination || "manual").toLowerCase();
        if (destination !== "target" && destination !== "user") return Number(fallback || 0);
        var origin = this.samplePosition(clip, frame);
        var anchors = this.anchors();
        var dest = destination === "target" ? anchors.target_battler : anchors.user_battler;
        if (!origin || !dest) return Number(fallback || 0);
        var dx = Number(dest.x || 0) - Number(origin.x || 0), dy = Number(dest.y || 0) - Number(origin.y || 0);
        if (Math.abs(dx) < .0001 && Math.abs(dy) < .0001) return Number(fallback || 0);
        return Math.atan2(-dy, dx) * 180 / Math.PI + Number(this.contextParameterValue(clip, "emitter", "simpleDirectionOffset", frame, Number(pbs.simpleDirectionOffset || 0)));
    };
    BattlePreview.prototype.emitterDistancePx = function (clip, frame, speedFallback) {
        var pbs = clip && clip.pbs ? clip.pbs : {};
        var stored = Number(pbs.simpleDistancePx);
        stored = Number(this.contextParameterValue(clip, "emitter", "simpleDistancePx", frame, stored));
        if (stored > 0) return stored;
        var destination = String(pbs.emitterDestination || "manual").toLowerCase();
        if (destination === "target" || destination === "user") {
            try {
                var origin = this.samplePosition(clip, frame), anchors = this.anchors();
                var dest = destination === "target" ? anchors.target_battler : anchors.user_battler;
                if (origin && dest) {
                    var dx = Number(dest.x || 0) - Number(origin.x || 0), dy = Number(dest.y || 0) - Number(origin.y || 0);
                    var geometric = Math.sqrt(dx * dx + dy * dy);
                    if (geometric > 0) return geometric;
                }
            } catch (_distanceError) {}
        }
        var fps = Math.max(1, Number((this.animation && this.animation.fps) || 20));
        var frames = Math.max(1, Number(pbs.simpleTravelFrames || 8));
        var speed = Math.abs(Number(speedFallback || 0));
        return speed > 0 ? speed * frames / fps : 160;
    };
    BattlePreview.prototype.emitterTravelFrames = function (clip, frame, speed) {
        var pbs = clip && clip.pbs ? clip.pbs : {};
        var fps = Math.max(1, Number((this.animation && this.animation.fps) || 20));
        var distance = this.emitterDistancePx(clip, frame, speed);
        var absSpeed = Math.abs(Number(speed || 0));
        return absSpeed > .0001 ? Math.max(1, distance / absSpeed * fps) : Math.max(1, Number(pbs.simpleTravelFrames || 8));
    };
    BattlePreview.prototype.emitterGuideGeometry = function (clip, frame) {
        if (!clip) return null;
        var center = this.samplePosition(clip, frame);
        var authored = Number(this.emitterValue(clip, "emitAngle", frame, 0) || 0);
        var angle = this.emitterSemanticAngle(clip, frame, authored);
        var speed = Number(this.emitterValue(clip, "emitSpeed", frame, 0) || 0);
        var distance = this.emitterDistancePx(clip, frame, speed);
        var rad = angle * Math.PI / 180;
        return { center: center, angle: angle, distance: distance, x: Number(center.x || 0) + Math.cos(rad) * distance, y: Number(center.y || 0) - Math.sin(rad) * distance };
    };
    BattlePreview.prototype.emitterEmissionFrames = function (clip, now, fps, rate, limit) {
        var e_14, _q;
        var _this = this;
        if (limit === void 0) {
            limit = 500;
        }
        var _a, _b;
        // Each SetEmitting=true starts/restarts the cadence. EmitterRate can be
        // keyed by the Studio, so sample it at each emission instead of assuming
        // one immutable interval for the whole attack.
        var list = (((_b = (_a = clip.pbs) === null || _a === void 0 ? void 0 : _a.emitterCommands) === null || _b === void 0 ? void 0 : _b.emitting) || []).slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
        if (!list.length)
            return [];
        var out = [];
        var state = false, start = null;
        var flush = function (end) {
            if (!state || start === null)
                return;
            var stop = Math.min(now, Number.isFinite(end) ? end : now);
            var f = start, guard = 0;
            while (f <= stop + 1e-6 && out.length < limit && guard++ < limit * 4) {
                out.push(f);
                var currentRate = Math.max(.01, Number(_this.emitterValue(clip, "emitterRate", f, rate) || rate));
                f += fps / currentRate;
            }
        };
        try {
            for (var list_2 = __values(list), list_2_1 = list_2.next(); !list_2_1.done; list_2_1 = list_2.next()) {
                var cmd = list_2_1.value;
                var f = Number(cmd.frame || 0);
                if (f > now + 1e-6)
                    break;
                flush(f - 1e-7);
                state = !!cmd.value;
                start = state ? f : null;
            }
        }
        catch (e_14_1) {
            e_14 = { error: e_14_1 };
        }
        finally {
            try {
                if (list_2_1 && !list_2_1.done && (_q = list_2.return))
                    _q.call(list_2);
            }
            finally {
                if (e_14)
                    throw e_14.error;
            }
        }
        flush(now);
        return out;
    };
    BattlePreview.prototype.emitterRandomized = function (clip, key, rangeKey, frame, rnd, def) {
        if (def === void 0) {
            def = 0;
        }
        var base = Number(this.emitterValue(clip, key, frame, def) || 0), range = Math.max(0, Number(this.emitterValue(clip, rangeKey, frame, 0) || 0));
        return range > 0 ? base + (rnd() * 2 - 1) * range : base;
    };
    BattlePreview.prototype.emitterParticleCommandFrame = function (clip, emissionFrame, age) {
        var e_15, _q, e_16, _r;
        var pbs = clip && clip.pbs ? clip.pbs : {};
        var mode = String(pbs.particleCommandSpace || "").toLowerCase();
        if (mode === "animation")
            return Number(emissionFrame || 0) + Number(age || 0);
        if (mode === "particle")
            return Number(age || 0);
        // Compatibility with BAS 1.9.4-1.9.6: Studio-created radial keys were
        // stored at the emitter's global start frame, while native PBS particle
        // commands are local to each particle's lifetime.
        var emitting = (((pbs.emitterCommands || {}).emitting) || []).slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
        var start = emitting.find(function (x) { return !!x.value; });
        var startFrame = start ? Number(start.frame || 0) : 0;
        var minRadiusFrame = Infinity;
        try {
            for (var _s = __values(["radiusX", "radiusY", "radiusZ"]), _t = _s.next(); !_t.done; _t = _s.next()) {
                var prop = _t.value;
                var list = ((pbs.commands || {})[prop]) || [];
                try {
                    for (var list_3 = (e_16 = void 0, __values(list)), list_3_1 = list_3.next(); !list_3_1.done; list_3_1 = list_3.next()) {
                        var cmd = list_3_1.value;
                        minRadiusFrame = Math.min(minRadiusFrame, Number(cmd.frame || 0));
                    }
                }
                catch (e_16_1) {
                    e_16 = { error: e_16_1 };
                }
                finally {
                    try {
                        if (list_3_1 && !list_3_1.done && (_r = list_3.return))
                            _r.call(list_3);
                    }
                    finally {
                        if (e_16)
                            throw e_16.error;
                    }
                }
            }
        }
        catch (e_15_1) {
            e_15 = { error: e_15_1 };
        }
        finally {
            try {
                if (_t && !_t.done && (_q = _s.return))
                    _q.call(_s);
            }
            finally {
                if (e_15)
                    throw e_15.error;
            }
        }
        if (startFrame > 0 && Number.isFinite(minRadiusFrame) && minRadiusFrame >= startFrame)
            return Number(emissionFrame || 0) + Number(age || 0);
        return Number(age || 0);
    };
    BattlePreview.prototype.drawEmitter = function (clip, selected, accent, alphaMult) {
        var e_17, _q, e_18, _r;
        if (alphaMult === void 0) {
            alphaMult = 1;
        }
        var _a, _b, _c, _d;
        var fps = Math.max(1, ((_a = this.animation) === null || _a === void 0 ? void 0 : _a.fps) || 20), baseRate = Math.max(.01, Number(((_b = clip.pbs) === null || _b === void 0 ? void 0 : _b.emitterRate) || 1)), baseIntensity = Math.max(1, Math.round(Number(((_c = clip.pbs) === null || _c === void 0 ? void 0 : _c.emitterIntensity) || 1))), now = this.frame, type = String(((_d = clip.pbs) === null || _d === void 0 ? void 0 : _d.emitter) || "none").toLowerCase();
        var particleLimit = this.playing ? 240 : 500;
        var emitterOpacity = clamp(this.sampleAt(clip, "emitterOpacity", now, 100) / 100, 0, 1);
        var emitterContextOverride = this.contextOverrideForObject(clip);
        if (emitterContextOverride) emitterOpacity = clamp(this.contextOpacityValue(clip, now, emitterOpacity * 100) / 100, 0, 1);
        var emissionFrames = this.emitterEmissionFrames(clip, now, fps, baseRate, particleLimit), particles = [];
        var emissionOrdinal = 0, particleOrdinal = 0;
        try {
            for (var emissionFrames_1 = __values(emissionFrames), emissionFrames_1_1 = emissionFrames_1.next(); !emissionFrames_1_1.done; emissionFrames_1_1 = emissionFrames_1.next()) {
                var ef = emissionFrames_1_1.value;
                var intensity = Math.max(1, Math.round(Number(this.emitterValue(clip, "emitterIntensity", ef, baseIntensity) || baseIntensity)));
                for (var j = 0; j < intensity && particles.length < particleLimit; j++) {
                    var stableSequenceIndex = particleOrdinal++;
                    var age = now - ef;
                    if (age < 0)
                        continue;
                    var seed = hash32("".concat(clip.id, ":").concat(Math.round(ef * 1000), ":").concat(j)), rnd = seeded(seed);
                    var ox = this.emitterRandomized(clip, "emitX", "emitXRange", ef, rnd, 0), oy = this.emitterRandomized(clip, "emitY", "emitYRange", ef, rnd, 0);
                    var spawnR = this.emitterRandomized(clip, "emitR", "emitRRange", ef, rnd, 0);
                    var spawnTheta = this.emitterRandomized(clip, "emitTheta", "emitThetaRange", ef, rnd, 0);
                    if (spawnR !== 0 || spawnTheta !== 0) {
                        var thetaRad = spawnTheta * Math.PI / 180;
                        ox += Math.round(spawnR * Math.cos(thetaRad));
                        oy += Math.round(-spawnR * Math.sin(thetaRad));
                    }
                    var speed = this.emitterRandomized(clip, "emitSpeed", "emitSpeedRange", ef, rnd, 0), angleDeg = this.emitterRandomized(clip, "emitAngle", "emitAngleRange", ef, rnd, 0);
                    var authoredBaseAngle = Number(this.emitterValue(clip, "emitAngle", ef, 0) || 0);
                    var semanticBaseAngle = this.emitterSemanticAngle(clip, ef, authoredBaseAngle);
                    var semanticDestination = String((clip.pbs && clip.pbs.emitterDestination) || "manual").toLowerCase();
                    var gravity = this.emitterRandomized(clip, "emitGravity", "emitGravityRange", ef, rnd, 0);
                    // Distance is the canonical route datum. Speed only determines how
                    // long it takes to traverse that distance; changing direction,
                    // gravity, wave/zigzag, etc. must never alter the endpoint radius.
                    var simpleTravelFrames = this.emitterTravelFrames(clip, ef, speed);
                    if (clip.pbs && this.contextParameterValue(clip, "emitter", "simpleStopAtDestination", ef, !!clip.pbs.simpleStopAtDestination) && age > simpleTravelFrames)
                        continue;
                    if (type === "straight" || type === "projectile" || type === "dampened") {
                        var angleJitter = angleDeg - authoredBaseAngle;
                        var routeBaseAngle = (semanticDestination === "target" || semanticDestination === "user") ? semanticBaseAngle : authoredBaseAngle;
                        var routeAngle = routeBaseAngle + angleJitter;
                        var routeDistance = this.emitterDistancePx(clip, ef, speed);
                        var travelSeconds = simpleTravelFrames / fps;
                        if (type === "projectile" && travelSeconds > 0 && routeDistance > 0) {
                            var routeRad = routeAngle * Math.PI / 180;
                            var travelDx = Math.cos(routeRad) * routeDistance;
                            var travelDy = -Math.sin(routeRad) * routeDistance;
                            var vx = travelDx / travelSeconds;
                            var vy = (travelDy - gravity * travelSeconds * travelSeconds / 2) / travelSeconds;
                            speed = Math.sqrt(vx * vx + vy * vy);
                            angleDeg = Math.atan2(-vy, vx) * 180 / Math.PI;
                        }
                        else {
                            angleDeg = routeAngle;
                        }
                    }
                    var periodX = Math.max(.0001, this.emitterRandomized(clip, "emitPeriodX", "emitPeriodXRange", ef, rnd, 100) / 100);
                    var periodY = Math.max(.0001, this.emitterRandomized(clip, "emitPeriodY", "emitPeriodYRange", ef, rnd, 100) / 100);
                    var periodZ = Math.max(.0001, this.emitterRandomized(clip, "emitPeriodZ", "emitPeriodZRange", ef, rnd, 100) / 100);
                    var radiusXMult = (100 + (rnd() * 2 - 1) * Math.max(0, Number(this.emitterValue(clip, "emitRadiusXRange", ef, 0) || 0))) / 100;
                    var radiusYMult = (100 + (rnd() * 2 - 1) * Math.max(0, Number(this.emitterValue(clip, "emitRadiusYRange", ef, 0) || 0))) / 100;
                    var radiusZMult = (100 + (rnd() * 2 - 1) * Math.max(0, Number(this.emitterValue(clip, "emitRadiusZRange", ef, 0) || 0))) / 100;
                    var particleSize = Math.max(1, Number(this.emitterValue(clip, "particleSize", ef, (clip.pbs && clip.pbs.particleSize) || 100) || 100));
                    var particleSizeRange = Math.max(0, Number(this.emitterValue(clip, "particleSizeRange", ef, (clip.pbs && clip.pbs.particleSizeRange) || 0) || 0));
                    var particleSizeMult = Math.max(0.01, (particleSize + (particleSizeRange > 0 ? (rnd() * 2 - 1) * particleSizeRange : 0)) / 100);
                    var zoomMult = (100 + (rnd() * 2 - 1) * Math.max(0, Number(this.emitterValue(clip, "emitZoomRange", ef, 0) || 0))) / 100;
                    var zoomXMult = (100 + (rnd() * 2 - 1) * Math.max(0, Number(this.emitterValue(clip, "emitZoomXRange", ef, 0) || 0))) / 100;
                    var zoomYMult = (100 + (rnd() * 2 - 1) * Math.max(0, Number(this.emitterValue(clip, "emitZoomYRange", ef, 0) || 0))) / 100;
                    var clockwise = !!this.emitterValue(clip, "emitClockwise", ef, false), sec = age / fps, dir = clockwise ? -1 : 1, phase = angleDeg * Math.PI / 180;
                    var particleCommandFrame = this.emitterParticleCommandFrame(clip, ef, age);
                    var radiusX = Number(this.samplePbsScalar(clip, "radiusX", particleCommandFrame, 0) || 0), radiusY = Number(this.samplePbsScalar(clip, "radiusY", particleCommandFrame, 0) || 0), radiusZ = Number(this.samplePbsScalar(clip, "radiusZ", particleCommandFrame, 0) || 0);
                    var dx = ox, dy = oy, zOffset = 0;
                    if (type === "straight" || type === "projectile") {
                        var ar = phase;
                        dx += Math.cos(ar) * speed * sec;
                        dy -= Math.sin(ar) * speed * sec;
                        if (type === "projectile")
                            dy += gravity * sec * sec / 2;
                        var simpleWave = clip.pbs && clip.pbs.simpleWave && typeof clip.pbs.simpleWave === "object" ? clip.pbs.simpleWave : null;
                        var waveEnabled = !!this.contextParameterValue(clip, "emitter", "waveEnabled", ef, !!(simpleWave && simpleWave.enabled));
                        if (simpleWave && waveEnabled) {
                            var waveAmp = Math.max(0, Number(this.contextParameterValue(clip, "emitter", "waveAmplitude", ef, simpleWave.amplitude || 0)));
                            var waveCycles = Math.max(.1, Number(this.contextParameterValue(clip, "emitter", "waveCycles", ef, simpleWave.cycles || 2)));
                            var waveMode = String(simpleWave.mode || "wave").toLowerCase();
                            var waveProgress = Math.max(0, Math.min(1, age / simpleTravelFrames));
                            var waveTheta = waveProgress * Math.PI * 2 * waveCycles;
                            // Envelope is always zero at ORIGIN and FIN, so adding a
                            // wave/zigzag changes only the path shape, never its endpoint.
                            var waveEnvelope = Math.sin(Math.PI * waveProgress);
                            var waveBase = Math.sin(waveTheta);
                            if (waveMode === "zigzag") waveBase = (2 / Math.PI) * Math.asin(Math.sin(waveTheta));
                            var waveOffset = waveBase * waveAmp * waveEnvelope;
                            dx += -Math.sin(ar) * waveOffset;
                            dy += -Math.cos(ar) * waveOffset;
                        }
                    }
                    else if (type === "risescatter" || type === "rise_scatter") {
                        var riseFrames = Math.max(1, Number(this.emitterValue(clip, "riseFrames", ef, 6) || 6));
                        var riseHeight = Math.max(1, Number(this.emitterValue(clip, "riseHeight", ef, 64) || 64));
                        var scatterFrames = Math.max(0, Number(this.emitterValue(clip, "scatterFrames", ef, 6) || 0));
                        var scatterSpeed = Math.max(0, Number(this.emitterValue(clip, "scatterSpeed", ef, Math.max(20, speed * 0.75)) || Math.max(20, speed * 0.75)));
                        var riseT = Math.max(0, Math.min(1, age / riseFrames));
                        var riseEase = 1 - Math.pow(1 - riseT, 2);
                        dy -= riseHeight * riseEase;
                        if (age > riseFrames) {
                            if (age > riseFrames + scatterFrames)
                                continue;
                            var scatterSec = (age - riseFrames) / fps;
                            dx += Math.cos(phase) * scatterSpeed * scatterSec;
                            dy -= Math.abs(Math.sin(phase)) * scatterSpeed * scatterSec * 0.12;
                        }
                    }
                    else if (type === "helix") {
                        if (periodX > 0)
                            dx += radiusX * radiusXMult * Math.sin(phase + (Math.PI * 2 * sec / periodX) * dir);
                        if (speed !== 0)
                            dy += speed * sec;
                        if (periodZ > 0)
                            zOffset += radiusZ * radiusZMult * Math.cos(phase + (Math.PI * 2 * sec / periodZ) * dir);
                    }
                    else if (type === "polar") {
                        if (periodX > 0)
                            dx += radiusX * radiusXMult * Math.sin(phase + (Math.PI * 2 * sec / periodX) * dir);
                        // The original player intentionally does not apply clockwise to Y.
                        if (periodY > 0)
                            dy += radiusY * radiusYMult * Math.cos(phase + (Math.PI * 2 * sec / periodY));
                    }
                    else if (type === "energyin" || type === "energyout") {
                        var travel = Math.max(1, Number(this.emitterValue(clip, "energyTravelFrames", ef, (clip.pbs && clip.pbs.energyTravelFrames) || 16) || 16));
                        if (age > travel + 4)
                            continue;
                        var t = Math.max(0, Math.min(1, age / travel));
                        var turns = Number(this.emitterValue(clip, "energyTurns", ef, (clip.pbs && clip.pbs.energyTurns) || 0) || 0);
                        var theta = phase + (Math.PI * 2 * turns * t * dir);
                        var radial = type === "energyin" ? (1 - t) : t;
                        dx += Math.cos(theta) * radiusX * radiusXMult * radial;
                        dy += Math.sin(theta) * radiusY * radiusYMult * radial;
                    }
                    else if (type === "orbit") {
                        var orbitPeriod = Math.max(.0001, periodX);
                        var theta = phase + (Math.PI * 2 * sec / orbitPeriod) * dir;
                        dx += Math.cos(theta) * radiusX * radiusXMult;
                        dy += Math.sin(theta) * radiusY * radiusYMult;
                    }
                    else if (type === "drain") {
                        var anchors = this.anchors(), from = anchors.target_battler, to = anchors.user_battler;
                        var travel = Math.max(1, Number(this.emitterValue(clip, "drainTravelFrames", ef, (clip.pbs && clip.pbs.drainTravelFrames) || 14) || 14));
                        if (age > travel + 4)
                            continue;
                        var t = Math.max(0, Math.min(1, age / travel)), eased = 1 - Math.pow(1 - t, 2);
                        dx += (to.x - from.x) * eased;
                        dy += (to.y - from.y) * eased;
                        var wobble = Math.sin((t * Math.PI * 2) + phase) * 10 * (1 - t);
                        dx += wobble;
                        dy += Math.cos((t * Math.PI * 2) + phase) * 5 * (1 - t);
                    }
                    else if (type === "dampened") {
                        var decel = Math.max(0, Number(this.emitterRandomized(clip, "emitDeceleration", "emitDecelerationRange", ef, rnd, 0) || 0));
                        var speedX = Math.cos(phase) * speed;
                        var speedY = -Math.sin(phase) * speed;
                        var decelX = decel * Math.abs(Math.cos(phase));
                        var decelY = decel * Math.abs(Math.sin(phase));
                        if (speedX > 0) decelX = -decelX;
                        if (speedY > 0) decelY = -decelY;
                        var useTime = sec;
                        if (decel > 0) {
                            var balanceTime = Math.abs(speed / decel);
                            if (useTime > balanceTime) useTime = balanceTime;
                        }
                        dx += speedX * useTime + 0.5 * decelX * useTime * useTime;
                        dy += speedY * useTime + 0.5 * decelY * useTime * useTime;
                    }
                    var randomFrameMax = Math.max(0, Math.round(Number(this.emitterValue(clip, "randomFrameMax", ef, (clip.pbs && clip.pbs.randomFrameMax) || 0) || 0)));
                    var randomAngleRange = Math.max(0, Number(this.emitterValue(clip, "randomAngleRange", ef, (clip.pbs && clip.pbs.randomAngleRange) || 0) || 0));
                    var randomInvertFlip = !!this.emitterValue(clip, "randomInvertFlip", ef, !!(clip.pbs && clip.pbs.randomInvertFlip));
                    var randomInvertAngle = !!this.emitterValue(clip, "randomInvertAngle", ef, !!(clip.pbs && clip.pbs.randomInvertAngle));
                    var emitXMult = Number(this.emitterValue(clip, "emitXMultiplier", ef, 100) || 100) / 100;
                    var emitYMult = Number(this.emitterValue(clip, "emitYMultiplier", ef, 100) || 100) / 100;
                    if (emitXMult !== 1) dx = ox + (dx - ox) * emitXMult;
                    if (emitYMult !== 1) dy = oy + (dy - oy) * emitYMult;
                    var emitOpacityMult = Number(this.emitterValue(clip, "emitOpacityMultiplier", ef, 100) || 100) / 100;
                    particles.push({ ef: ef, j: j, emissionIndex: emissionOrdinal, sequenceIndex: stableSequenceIndex, age: age, seed: seed, dx: dx, dy: dy, zOffset: zOffset, travelAngle: angleDeg, travelFrames: simpleTravelFrames, scaleXMult: particleSizeMult * zoomMult * zoomXMult, scaleYMult: particleSizeMult * zoomMult * zoomYMult, randomFrameMax: randomFrameMax, randomAngleRange: randomAngleRange, randomInvertFlip: randomInvertFlip, randomInvertAngle: randomInvertAngle, opacityMult: emitOpacityMult });
                }
                emissionOrdinal++;
            }
        }
        catch (e_17_1) {
            e_17 = { error: e_17_1 };
        }
        finally {
            try {
                if (emissionFrames_1_1 && !emissionFrames_1_1.done && (_q = emissionFrames_1.return))
                    _q.call(emissionFrames_1);
            }
            finally {
                if (e_17)
                    throw e_17.error;
            }
        }
        particles.sort(function (a, b) { return a.zOffset - b.zOffset; });
        try {
            for (var particles_1 = __values(particles), particles_1_1 = particles_1.next(); !particles_1_1.done; particles_1_1 = particles_1.next()) {
                var p = particles_1_1.value;
                var endFrame = Number((clip && clip.endFrame) != null ? clip.endFrame : ((this.animation && this.animation.duration) || now));
                var simpleLifeBase = clip.pbs && clip.pbs.simpleParticleLife && typeof clip.pbs.simpleParticleLife === "object" ? clip.pbs.simpleParticleLife : null;
                var simpleLife = simpleLifeBase ? {
                    duration: this.contextParameterValue(clip, "emitter", "life.duration", p.ef, simpleLifeBase.duration != null ? simpleLifeBase.duration : 12),
                    birthScale: this.contextParameterValue(clip, "emitter", "life.birthScale", p.ef, simpleLifeBase.birthScale != null ? simpleLifeBase.birthScale : 100),
                    midScale: this.contextParameterValue(clip, "emitter", "life.midScale", p.ef, simpleLifeBase.midScale != null ? simpleLifeBase.midScale : 100),
                    deathScale: this.contextParameterValue(clip, "emitter", "life.deathScale", p.ef, simpleLifeBase.deathScale != null ? simpleLifeBase.deathScale : 100),
                    birthOpacity: this.contextParameterValue(clip, "emitter", "life.birthOpacity", p.ef, simpleLifeBase.birthOpacity != null ? simpleLifeBase.birthOpacity : 0),
                    midOpacity: this.contextParameterValue(clip, "emitter", "life.midOpacity", p.ef, simpleLifeBase.midOpacity != null ? simpleLifeBase.midOpacity : 100),
                    deathOpacity: this.contextParameterValue(clip, "emitter", "life.deathOpacity", p.ef, simpleLifeBase.deathOpacity != null ? simpleLifeBase.deathOpacity : 0),
                    birthRotation: this.contextParameterValue(clip, "emitter", "life.birthRotation", p.ef, simpleLifeBase.birthRotation || 0),
                    midRotation: this.contextParameterValue(clip, "emitter", "life.midRotation", p.ef, simpleLifeBase.midRotation || 0),
                    deathRotation: this.contextParameterValue(clip, "emitter", "life.deathRotation", p.ef, simpleLifeBase.deathRotation || 0),
                    spinSpeed: this.contextParameterValue(clip, "emitter", "life.spinSpeed", p.ef, simpleLifeBase.spinSpeed || 0)
                } : null;
                var particleLife = simpleLife ? Math.max(1, Number(simpleLife.duration || 12)) : Math.max(1, endFrame - Number(p.ef || 0));
                if (!simpleLife && (type === "risescatter" || type === "rise_scatter"))
                    particleLife = Math.max(1, Number(this.emitterValue(clip, "riseFrames", p.ef, 6) || 6) + Number(this.emitterValue(clip, "scatterFrames", p.ef, 6) || 0));
                if ((type === "straight" || type === "projectile") && Number(p.travelFrames || 0) > particleLife)
                    particleLife = Math.max(particleLife, Number(p.travelFrames || 0));
                if (Number(p.age || 0) > particleLife)
                    continue;
                var opacityT = clamp(Number(p.age || 0) / particleLife, 0, 1);
                var particleOpacity = 1, simpleScale = 1, simpleRotation = 0;
                if (simpleLife) {
                    var halfT = opacityT <= .5 ? opacityT * 2 : (opacityT - .5) * 2;
                    var aScale = opacityT <= .5 ? Number(simpleLife.birthScale != null ? simpleLife.birthScale : 60) : Number(simpleLife.midScale != null ? simpleLife.midScale : 100);
                    var bScale = opacityT <= .5 ? Number(simpleLife.midScale != null ? simpleLife.midScale : 100) : Number(simpleLife.deathScale != null ? simpleLife.deathScale : 120);
                    simpleScale = Math.max(.01, lerp(aScale, bScale, halfT) / 100);
                    var aOpacity = opacityT <= .5 ? Number(simpleLife.birthOpacity != null ? simpleLife.birthOpacity : 0) : Number(simpleLife.midOpacity != null ? simpleLife.midOpacity : 100);
                    var bOpacity = opacityT <= .5 ? Number(simpleLife.midOpacity != null ? simpleLife.midOpacity : 100) : Number(simpleLife.deathOpacity != null ? simpleLife.deathOpacity : 0);
                    particleOpacity = clamp(lerp(aOpacity, bOpacity, halfT) / 100, 0, 1);
                    var aRot = opacityT <= .5 ? Number(simpleLife.birthRotation || 0) : Number(simpleLife.midRotation || 0);
                    var bRot = opacityT <= .5 ? Number(simpleLife.midRotation || 0) : Number(simpleLife.deathRotation || 0);
                    simpleRotation = lerp(aRot, bRot, halfT) + Number(simpleLife.spinSpeed || 0) * (Number(p.age || 0) / fps);
                }
                else {
                    var opacityStart = clamp(Number(this.emitterValue(clip, "particleOpacityStart", p.ef, 5) || 0), 0, 100) / 100;
                    var opacityNormal = clamp(Number(this.emitterValue(clip, "particleOpacity", p.ef, 100) || 0), 0, 100) / 100;
                    var opacityEnd = clamp(Number(this.emitterValue(clip, "particleOpacityEnd", p.ef, 0) || 0), 0, 100) / 100;
                    var fadeInEnd = 0.22;
                    particleOpacity = opacityT <= fadeInEnd ? lerp(opacityStart, opacityNormal, opacityT / fadeInEnd) : lerp(opacityNormal, opacityEnd, (opacityT - fadeInEnd) / (1 - fadeInEnd));
                }
                if (p.opacityMult != null) particleOpacity = clamp(particleOpacity * p.opacityMult, 0, 1);
                var orientationRaw = String((clip.pbs && clip.pbs.emitterGraphicOrientation) || "").toLowerCase();
                var angleOverrideRaw = String((clip.pbs && clip.pbs.angleOverride) || "none").toLowerCase();
                var orientationMode = ["manual", "travel", "legacy"].includes(orientationRaw) ? orientationRaw : ((clip.pbs && clip.pbs.simpleFaceTravel) ? "travel" : (angleOverrideRaw && angleOverrideRaw !== "none" ? "legacy" : "manual"));
                var faceTravelOffset = clip.pbs ? Number(this.contextParameterValue(clip, "emitter", "simpleFaceTravelOffset", p.ef, Number(clip.pbs.simpleFaceTravelOffset || 0))) : 0;
                var faceTravelRotation = orientationMode === "travel" ? (-Number(p.travelAngle || 0) + faceTravelOffset) : 0;
                var sequence = clip.pbs && Array.isArray(clip.pbs.emitterGraphicSequence) ? clip.pbs.emitterGraphicSequence.map(function (entry) {
                    if (typeof entry === "string") {
                        var path = String(entry || "").trim();
                        return path ? { projectPath: path, frame: 0 } : null;
                    }
                    if (entry && typeof entry === "object") {
                        var path = String(entry.projectPath || entry.value || "").trim();
                        return path ? { projectPath: path, frame: Math.max(0, Math.round(Number(entry.frame || 0) || 0)) } : null;
                    }
                    return null;
                }).filter(Boolean) : [];
                var sequenceEnabled = !!(clip.pbs && clip.pbs.emitterGraphicSequenceEnabled && sequence.length);
                var sequenceMode = String((clip.pbs && clip.pbs.emitterGraphicSequenceMode) || "animate").toLowerCase() === "assign" ? "assign" : "animate";
                var sequenceBasis = String((clip.pbs && clip.pbs.emitterGraphicSequenceBasis) || "particle").toLowerCase();
                var sequenceStepFrames = Math.max(1, Math.round(Number((clip.pbs && clip.pbs.emitterGraphicSequenceStepFrames) || 2) || 2));
                var sequenceOrdinal = sequenceMode === "animate" ? Math.floor(Math.max(0, Number(p.age || 0)) / sequenceStepFrames) : (sequenceBasis === "emission" ? Number(p.emissionIndex || 0) : Number(p.sequenceIndex || 0));
                var patternEntry = sequenceEnabled ? sequence[((sequenceOrdinal % sequence.length) + sequence.length) % sequence.length] : null;
                var patternGraphicPath = patternEntry ? String(patternEntry.projectPath || "") : null;
                var patternGraphicFrame = patternEntry ? Math.max(0, Math.round(Number(patternEntry.frame || 0) || 0)) : null;
                var extra = { offsetX: p.dx, offsetY: p.dy, zOffset: p.zOffset, scaleXMult: p.scaleXMult * simpleScale, scaleYMult: p.scaleYMult * simpleScale, rotationOffset: simpleRotation + faceTravelRotation, randomSeed: p.seed, emissionFrame: p.ef, randomFrameMax: p.randomFrameMax, randomAngleRange: p.randomAngleRange, randomInvertFlip: p.randomInvertFlip, randomInvertAngle: p.randomInvertAngle, suppressAngleOverride: orientationMode !== "legacy", patternGraphicPath: patternGraphicPath, patternGraphicFrame: patternGraphicFrame };
                // Particles live in emission-local time. A particle spawned after frame 0
                // therefore never satisfies drawClip(localFrame === globalFrame), which
                // used to make the entire emitter impossible to grab in the canvas.
                // Selection/movement belongs to the emitter center, not one particle.
                this.drawClip(clip, false, accent, p.age, extra, alphaMult * emitterOpacity * particleOpacity);
            }
        }
        catch (e_18_1) {
            e_18 = { error: e_18_1 };
        }
        finally {
            try {
                if (particles_1_1 && !particles_1_1.done && (_r = particles_1.return))
                    _r.call(particles_1);
            }
            finally {
                if (e_18)
                    throw e_18.error;
            }
        }
        var center = this.samplePosition(clip, now);
        this.hitShapes.push({ objectId: clip.id, x: center.x, y: center.y, w: 42, h: 42, kind: "emitter-anchor" });
        if (selected && !this.playing) {
            var c = this.ctx;
            c.save();
            c.translate(center.x, center.y);
            c.strokeStyle = accent;
            c.fillStyle = "rgba(15,18,30,.78)";
            c.lineWidth = 1.5;
            c.setLineDash([]);
            c.beginPath();
            c.arc(0, 0, 10, 0, Math.PI * 2);
            c.fill();
            c.stroke();
            c.beginPath();
            c.moveTo(-15, 0);
            c.lineTo(15, 0);
            c.moveTo(0, -15);
            c.lineTo(0, 15);
            c.stroke();
            c.fillStyle = "#fff";
            c.font = "bold 11px sans-serif";
            c.textAlign = "center";
            c.textBaseline = "middle";
            c.fillText("+", 0, 0);
            if (this.emitterEditMode === "emission") {
                var guideAngle = this.emitterSemanticAngle(clip, now, Number(this.emitterValue(clip, "emitAngle", now, 0) || 0));
                var guideRange = Math.max(0, Math.min(180, Number(this.emitterValue(clip, "emitAngleRange", now, 0) || 0)));
                var guideSpeed = Number(this.emitterValue(clip, "emitSpeed", now, 0) || 0);
                var guideXRange = Math.max(0, Number(this.emitterValue(clip, "emitXRange", now, 0) || 0));
                var guideYRange = Math.max(0, Number(this.emitterValue(clip, "emitYRange", now, 0) || 0));
                var guideTravelFrames = this.emitterTravelFrames(clip, now, guideSpeed);
                var guideLen = this.emitterDistancePx(clip, now, guideSpeed);
                var guideRad = guideAngle * Math.PI / 180;
                var gx = Math.cos(guideRad) * guideLen, gy = -Math.sin(guideRad) * guideLen;
                c.save();
                c.strokeStyle = "rgba(255,255,255,.92)";
                c.fillStyle = "rgba(255,255,255,.92)";
                c.lineWidth = 2;
                c.setLineDash([]);
                if (guideXRange > 0 || guideYRange > 0) {
                    c.strokeStyle = "rgba(255,255,255,.42)";
                    c.setLineDash([4, 4]);
                    c.strokeRect(-guideXRange, -guideYRange, guideXRange * 2, guideYRange * 2);
                    c.setLineDash([]);
                    c.strokeStyle = "rgba(255,255,255,.92)";
                }
                if (guideRange > 0) {
                    var aMin = (guideAngle - guideRange) * Math.PI / 180, aMax = (guideAngle + guideRange) * Math.PI / 180;
                    c.fillStyle = "rgba(255,255,255,.08)";
                    c.beginPath();
                    c.moveTo(0, 0);
                    c.lineTo(Math.cos(aMin) * guideLen, -Math.sin(aMin) * guideLen);
                    c.arc(0, 0, guideLen, -aMin, -aMax, true);
                    c.closePath();
                    c.fill();
                    c.strokeStyle = "rgba(255,255,255,.38)";
                    c.beginPath();
                    c.moveTo(0, 0);
                    c.lineTo(Math.cos(aMin) * guideLen, -Math.sin(aMin) * guideLen);
                    c.moveTo(0, 0);
                    c.lineTo(Math.cos(aMax) * guideLen, -Math.sin(aMax) * guideLen);
                    c.stroke();
                }
                c.strokeStyle = "rgba(255,255,255,.95)";
                c.beginPath();
                c.moveTo(0, 0);
                c.lineTo(gx, gy);
                c.stroke();
                var arrowAngle = Math.atan2(gy, gx);
                c.beginPath();
                c.moveTo(gx, gy);
                c.lineTo(gx - Math.cos(arrowAngle - .45) * 12, gy - Math.sin(arrowAngle - .45) * 12);
                c.lineTo(gx - Math.cos(arrowAngle + .45) * 12, gy - Math.sin(arrowAngle + .45) * 12);
                c.closePath();
                c.fill();
                c.font = "bold 10px sans-serif";
                c.textAlign = "left";
                c.textBaseline = "bottom";
                c.fillText("FIN · " + Math.round(guideLen) + " px · " + Math.round(guideTravelFrames) + "f", gx + 9, gy - 5);
                // FIN is always visible and draggable. It represents only the route
                // distance; dragging it does not modify angle or any other parameter.
                c.beginPath();
                c.arc(gx, gy, 7, 0, Math.PI * 2);
                c.fill();
                c.stroke();
                c.restore();
            }
            if (type === "risescatter" || type === "rise_scatter") {
                var guideHeight = Math.max(1, Number(this.emitterValue(clip, "riseHeight", now, 64) || 64));
                var guideScatterFrames = Math.max(0, Number(this.emitterValue(clip, "scatterFrames", now, 6) || 0));
                var guideScatterSpeed = Math.max(0, Number(this.emitterValue(clip, "scatterSpeed", now, 48) || 48));
                var guideSpread = guideScatterFrames * guideScatterSpeed / Math.max(1, fps);
                c.strokeStyle = "rgba(255,255,255,.72)";
                c.setLineDash([5, 4]);
                c.beginPath();
                c.moveTo(0, 0);
                c.lineTo(0, -guideHeight);
                c.moveTo(0, -guideHeight);
                c.lineTo(-guideSpread, -guideHeight - Math.min(12, guideSpread * .15));
                c.moveTo(0, -guideHeight);
                c.lineTo(guideSpread, -guideHeight - Math.min(12, guideSpread * .15));
                c.stroke();
                c.setLineDash([]);
                c.beginPath();
                c.arc(0, -guideHeight, 4, 0, Math.PI * 2);
                c.stroke();
            }
            c.restore();
            if (sortPositionKeys(clip).length && this.callbacks.showPath && this.callbacks.showPath() !== false)
                this.drawPath(clip, accent);
        }
    };
    BattlePreview.prototype.rgssAngleBetween = function (x1, y1, x2, y2) {
        // Exact convention used by AnimationPlayer::Helper.angle_between:
        // 0° points up and positive angles turn anticlockwise in RGSS space.
        var dx = Number(x1) - Number(x2), dy = Number(y1) - Number(y2);
        if (Math.abs(dy) < 1e-9)
            return dx >= 0 ? 90 : -90;
        var ret = Math.atan(dx / dy) * 180 / Math.PI;
        if (dy < 0)
            ret += 180;
        return ret;
    };
    BattlePreview.prototype.pbsInitialCommandValue = function (clip, prop) {
        var _a, _b;
        var list = ((_b = (_a = clip === null || clip === void 0 ? void 0 : clip.pbs) === null || _a === void 0 ? void 0 : _a.commands) === null || _b === void 0 ? void 0 : _b[prop]) || [], first = list[0];
        // The official helper only considers the first X/Y command, and only if
        // it is an instantaneous Set command. If that first command moves, the
        // starting value remains 0.
        if (!first || Number(first.duration || 0) > 0)
            return 0;
        return Number(first.value || 0);
    };
    BattlePreview.prototype.pbsInitialAngleOrigin = function (clip) {
        var _a;
        var focus = String(((_a = clip === null || clip === void 0 ? void 0 : clip.pbs) === null || _a === void 0 ? void 0 : _a.focus) || "foreground"), p = { anchor: "pbs:".concat(focus), x: this.pbsInitialCommandValue(clip, "x"), y: this.pbsInitialCommandValue(clip, "y"), offsetX: 0, offsetY: 0, foeInvertX: false, foeInvertY: false };
        return this.resolvePoint(p);
    };
    BattlePreview.prototype.pbsAngleTarget = function (clip) {
        var _a, _b, _c, _d;
        var f = String(((_a = clip === null || clip === void 0 ? void 0 : clip.pbs) === null || _a === void 0 ? void 0 : _a.focus) || "").toLowerCase(), a = this.anchors(), ctx = this.context || {}, opp = this.semanticOpposing(), baseScriptU = opp ? (ctx.scriptTarget || ctx.target) : (ctx.scriptUser || ctx.user), baseScriptT = opp ? (ctx.scriptUser || ctx.user) : (ctx.scriptTarget || ctx.target), scriptU = this.replicaUserOverride || baseScriptU, scriptT = this.replicaTargetOverride || baseScriptT;
        return f.includes("and_target_position") ? { x: a.target.x, y: Number((_b = scriptT === null || scriptT === void 0 ? void 0 : scriptT.y) !== null && _b !== void 0 ? _b : a.target.y) } : f.includes("and_target") ? Object.assign({}, a.target) : f.startsWith("target_position") ? { x: a.target.x, y: Number((_c = scriptT === null || scriptT === void 0 ? void 0 : scriptT.y) !== null && _c !== void 0 ? _c : a.target.y) } : f.startsWith("target") ? Object.assign({}, a.target) : f.startsWith("user_position") ? { x: a.user.x, y: Number((_d = scriptU === null || scriptU === void 0 ? void 0 : scriptU.y) !== null && _d !== void 0 ? _d : a.user.y) } : Object.assign({}, a.user);
    };
    BattlePreview.prototype.samplePbsScalar = function (clip, prop, frame, def) {
        var e_19, _q;
        var _a, _b;
        var cmds = ((_b = (_a = clip.pbs) === null || _a === void 0 ? void 0 : _a.commands) === null || _b === void 0 ? void 0 : _b[prop]) || [];
        if (!cmds.length)
            return this.contextParameterValue(clip, "particle", prop, frame, def);
        var state = def;
        try {
            for (var cmds_1 = __values(cmds), cmds_1_1 = cmds_1.next(); !cmds_1_1.done; cmds_1_1 = cmds_1.next()) {
                var x = cmds_1_1.value;
                if (frame < x.frame)
                    break;
                if (x.duration > 0 && frame < x.frame + x.duration) {
                    var t = ease((frame - x.frame) / Math.max(.001, x.duration), x.easing || "linear");
                    var interpolated = typeof x.value === "number" ? lerp(state, x.value, t) : x.value;
                    return this.contextParameterValue(clip, "particle", prop, frame, interpolated);
                }
                state = x.value;
            }
        }
        catch (e_19_1) {
            e_19 = { error: e_19_1 };
        }
        finally {
            try {
                if (cmds_1_1 && !cmds_1_1.done && (_q = cmds_1.return))
                    _q.call(cmds_1);
            }
            finally {
                if (e_19)
                    throw e_19.error;
            }
        }
        return this.contextParameterValue(clip, "particle", prop, frame, state);
    };
    BattlePreview.prototype.clipAfterimageConfig = function (clip) {
        var pbs = clip && clip.pbs ? clip.pbs : {}, raw = pbs.afterimage && typeof pbs.afterimage === "object" ? pbs.afterimage : {};
        var mode = String(raw.mode || "trail").toLowerCase() === "burst" ? "burst" : "trail";
        var legacyEnabled = !!raw.enabled;
        var trailEnabled = raw.trailEnabled == null ? (legacyEnabled && mode !== "burst") : !!raw.trailEnabled;
        var burstEnabled = raw.burstEnabled == null ? (legacyEnabled && mode === "burst") : !!raw.burstEnabled;
        var defaultStart = Math.max(0, Math.round(Number((clip && clip.startFrame) || 0) || 0));
        var defaultEnd = Math.max(defaultStart, Math.round(Number((clip && clip.endFrame) || (this.animation && this.animation.duration) || defaultStart) || defaultStart));
        return { enabled: legacyEnabled || trailEnabled || burstEnabled, mode: mode, trailEnabled: trailEnabled,
            copies: Math.max(1,Math.min(8,Math.round(Number(raw.copies||3)))), gap:Math.max(1,Math.min(12,Math.round(Number(raw.gap||1)))), opacity:clamp(Number(raw.opacity==null?40:raw.opacity)/100,0,1), scaleDecay:clamp(Number(raw.scaleDecay||8)/100,0,.9),
            trailStartFrame:Math.max(0,Math.round(Number(raw.trailStartFrame!=null?raw.trailStartFrame:defaultStart)||0)), trailEndFrame:Math.max(defaultStart,Math.round(Number(raw.trailEndFrame!=null?raw.trailEndFrame:defaultEnd)||defaultEnd)),
            burstEnabled:burstEnabled, burstFrame:Math.max(0,Math.round(Number(raw.burstFrame!=null?raw.burstFrame:defaultStart)||0)), burstCopies:Math.max(1,Math.min(12,Math.round(Number(raw.burstCopies||4)))), burstLifetime:Math.max(1,Math.min(120,Math.round(Number(raw.burstLifetime||10)))), burstInterval:Math.max(0,Math.min(30,Math.round(Number(raw.burstInterval||0)))),
            burstStartScale:Math.max(.01,Number(raw.burstStartScale==null?100:raw.burstStartScale)/100), burstEndScale:Math.max(.01,Number(raw.burstEndScale==null?150:raw.burstEndScale)/100), burstStartOpacity:clamp(Number(raw.burstStartOpacity==null?60:raw.burstStartOpacity)/100,0,1), burstEndOpacity:clamp(Number(raw.burstEndOpacity==null?0:raw.burstEndOpacity)/100,0,1), burstStartRadius:Math.max(0,Number(raw.burstStartRadius||0)), burstEndRadius:Math.max(0,Number(raw.burstEndRadius==null?24:raw.burstEndRadius)) };
    };
    BattlePreview.prototype.drawClipAfterimages = function (clip, selected, accent, localFrame, extra, alphaMult) {
        if (extra === void 0) extra = null; if (alphaMult === void 0) alphaMult = 1;
        if (extra && extra.skipAfterimage) return;
        var cfg=this.clipAfterimageConfig(clip); if(!cfg.enabled) return;
        var isEmitterParticle=!!(extra&&extra.emissionFrame!==undefined), start=Number((clip&&clip.startFrame)||0), end=Number((clip&&clip.endFrame)||((this.animation&&this.animation.duration)||localFrame||0));
        if (isEmitterParticle) {
            if (!cfg.trailEnabled && cfg.mode !== 'trail') return;
            var gf=Number(this.frame!=null?this.frame:localFrame); if(gf<cfg.trailStartFrame||gf>cfg.trailEndFrame) return;
            for(var pi=cfg.copies;pi>=1;pi--){var pf=cfg.opacity*((cfg.copies-pi+1)/cfg.copies); if(pf<=0)continue; var ps=Math.max(.01,1-cfg.scaleDecay*pi), ca=Math.max(0,Number(localFrame||0)), ga=ca-cfg.gap*pi; if(ga<0)continue; var pt=ca>0?ga/ca:0; var ge=Object.assign({},extra||{},{skipAfterimage:true,offsetX:Number((extra&&extra.offsetX)||0)*pt,offsetY:Number((extra&&extra.offsetY)||0)*pt,zOffset:Number((extra&&extra.zOffset)||0)*pt,scaleXMult:Number((extra&&extra.scaleXMult)!=null?extra.scaleXMult:1)*ps,scaleYMult:Number((extra&&extra.scaleYMult)!=null?extra.scaleYMult:1)*ps}); this.drawClip(clip,false,accent,ga,ge,alphaMult*pf);} return;
        }
        if (cfg.trailEnabled) {
            var globalFrame=Number(this.frame!=null?this.frame:localFrame);
            if(globalFrame>=cfg.trailStartFrame&&globalFrame<=cfg.trailEndFrame){
                for(var i=cfg.copies;i>=1;i--){var fade=cfg.opacity*((cfg.copies-i+1)/cfg.copies); if(fade<=0)continue; var scale=Math.max(.01,1-cfg.scaleDecay*i), ghostFrame=Number(localFrame||0)-cfg.gap*i; if(ghostFrame<start||ghostFrame>end||!sampleVisible(clip,ghostFrame))continue; var ghostExtra=Object.assign({},extra||{},{skipAfterimage:true,scaleXMult:Number((extra&&extra.scaleXMult)!=null?extra.scaleXMult:1)*scale,scaleYMult:Number((extra&&extra.scaleYMult)!=null?extra.scaleYMult:1)*scale}); this.drawClip(clip,false,accent,ghostFrame,ghostExtra,alphaMult*fade);}
            }
        }
        if (cfg.burstEnabled) {
            var currentFrame=Number(this.frame!=null?this.frame:localFrame);
            for(var j=0;j<cfg.burstCopies;j++){var born=cfg.burstFrame+cfg.burstInterval*j, age=currentFrame-born; if(age<0||age>cfg.burstLifetime)continue; var t=cfg.burstLifetime>0?age/cfg.burstLifetime:1, radius=cfg.burstStartRadius+(cfg.burstEndRadius-cfg.burstStartRadius)*t, theta=cfg.burstCopies<=1?0:(Math.PI*2*j/cfg.burstCopies)-Math.PI/2, dx=Math.cos(theta)*radius, dy=Math.sin(theta)*radius, bs=cfg.burstStartScale+(cfg.burstEndScale-cfg.burstStartScale)*t, bo=cfg.burstStartOpacity+(cfg.burstEndOpacity-cfg.burstStartOpacity)*t; if(bo<=0)continue; var be=Object.assign({},extra||{},{skipAfterimage:true,offsetX:Number((extra&&extra.offsetX)||0)+dx,offsetY:Number((extra&&extra.offsetY)||0)+dy,scaleXMult:Number((extra&&extra.scaleXMult)!=null?extra.scaleXMult:1)*bs,scaleYMult:Number((extra&&extra.scaleYMult)!=null?extra.scaleYMult:1)*bs}); this.drawClip(clip,false,accent,cfg.burstFrame,be,alphaMult*bo);}
        }
    };
    BattlePreview.prototype.drawClip = function (clip, selected, accent, localFrame, extra, alphaMult) {
        var e_20, _q, e_21, _r;
        if (localFrame === void 0) {
            localFrame = this.frame;
        }
        if (extra === void 0) {
            extra = null;
        }
        if (alphaMult === void 0) {
            alphaMult = 1;
        }
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p;
        if ((extra === null || extra === void 0 ? void 0 : extra.emissionFrame) !== undefined && !sampleVisible(clip, localFrame))
            return;
        var c = this.ctx, oldFrame = this.frame;
        // Emitter particles are born at the emitter position of their emission
        // frame. Follow User/Target must move the emitter for NEW particles, not
        // drag particles that already exist as the battler keeps moving.
        var positionFrame = (extra && extra.emissionFrame !== undefined) ? Number(extra.emissionFrame) : localFrame;
        this.frame = positionFrame;
        var basePos = this.samplePosition(clip, positionFrame);
        this.frame = oldFrame;
        basePos = { x: basePos.x + Number((extra === null || extra === void 0 ? void 0 : extra.offsetX) || 0), y: basePos.y + Number((extra === null || extra === void 0 ? void 0 : extra.offsetY) || 0) };
        var contextOverride = this.contextOverrideForObject(clip);
        basePos = { x: basePos.x + Number(this.contextOverrideValue(clip, "offsetX", positionFrame, 0) || 0), y: basePos.y + Number(this.contextOverrideValue(clip, "offsetY", positionFrame, 0) || 0) };
        var r = this.clipImages.get(clip.id);
        var switches = (clip.graphicSwitches || []).slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
        var activeSwitch = null;
        try {
            for (var switches_1 = __values(switches), switches_1_1 = switches_1.next(); !switches_1_1.done; switches_1_1 = switches_1.next()) {
                var sw = switches_1_1.value;
                if (Number(sw.frame || 0) > localFrame)
                    break;
                activeSwitch = sw;
            }
        }
        catch (e_20_1) {
            e_20 = { error: e_20_1 };
        }
        finally {
            try {
                if (switches_1_1 && !switches_1_1.done && (_q = switches_1.return))
                    _q.call(switches_1);
            }
            finally {
                if (e_20)
                    throw e_20.error;
            }
        }
        if (activeSwitch) {
            var sr = this.clipImages.get("".concat(clip.id, "@@").concat(String(activeSwitch.value || "")));
            if (sr === null || sr === void 0 ? void 0 : sr.image)
                r = sr;
        }
        if (extra && extra.patternGraphicPath) {
            var pr = this.clipImages.get("".concat(clip.id, "@@").concat(String(extra.patternGraphicPath || "")));
            if (pr === null || pr === void 0 ? void 0 : pr.image) r = pr;
        }
        var specialBundle = this.specialBattlerBundle((_a = clip.graphic) === null || _a === void 0 ? void 0 : _a.source), special = (specialBundle === null || specialBundle === void 0 ? void 0 : specialBundle.image) || null, im = special || ((r === null || r === void 0 ? void 0 : r.image) || null), procedural = !im && clip.graphic && clip.graphic.procedural;
        if (!im && !procedural && !selected)
            return;
        var size = Math.max(.01, this.sampleAt(clip, "size", localFrame, 100) / 100), sxScale = this.sampleAt(clip, "scaleX", localFrame, 100) / 100 * size * Number((_b = extra === null || extra === void 0 ? void 0 : extra.scaleXMult) !== null && _b !== void 0 ? _b : 1) * Math.max(.01, Number(this.contextOverrideValue(clip, "scaleX", this.frame, 100) || 100) / 100), syScale = this.sampleAt(clip, "scaleY", localFrame, 100) / 100 * size * Number((_c = extra === null || extra === void 0 ? void 0 : extra.scaleYMult) !== null && _c !== void 0 ? _c : 1) * Math.max(.01, Number(this.contextOverrideValue(clip, "scaleY", this.frame, 100) || 100) / 100), opacity = clamp(this.sampleAt(clip, "opacity", localFrame, 100) / 100, 0, 1), rotation = this.sampleAt(clip, "rotation", localFrame, 0) + Number((extra === null || extra === void 0 ? void 0 : extra.rotationOffset) || 0) + Number(this.contextOverrideValue(clip, "rotation", this.frame, 0) || 0) + this.contextualScreenRotationDelta(clip), blend = Math.round(contextOverride && contextOverride.blend !== null && contextOverride.blend !== undefined ? Number(contextOverride.blend) : this.sampleAt(clip, "blend", localFrame, 0)), invert = this.sampleAt(clip, "invert", localFrame, 0) >= .5;
        var isEmitterVisual = !!(clip && clip.pbs && String(clip.pbs.emitter || "none").toLowerCase() !== "none");
        if (contextOverride && !isEmitterVisual)
            opacity = clamp(this.contextOpacityValue(clip, this.frame, opacity * 100) / 100, 0, 1);
        if (specialBundle === null || specialBundle === void 0 ? void 0 : specialBundle.meta) {
            var view = String((specialBundle.meta && specialBundle.meta.view) || specialBundle.view || (specialBundle.playerSide ? "back" : "front")).toLowerCase();
            var bs = this.resolveBattlerScale(Math.max(.01, Number(specialBundle.meta.scale || 1)), view === "back");
            sxScale *= bs;
            syScale *= bs;
        }
        var rnd = seeded(Number((extra === null || extra === void 0 ? void 0 : extra.randomSeed) || hash32(clip.id)));
        var src = this.sourceFrame(clip, im, localFrame, extra === null || extra === void 0 ? void 0 : extra.randomSeed, extra && extra.randomFrameMax !== undefined ? extra.randomFrameMax : null, extra && extra.patternGraphicFrame !== undefined ? extra.patternGraphicFrame : null), focus = String(((_d = clip.pbs) === null || _d === void 0 ? void 0 : _d.focus) || ""), relativeIndex = focus.includes("and") ? -1 : focus.startsWith("user") ? this.semanticIndex("user") : focus.startsWith("target") ? this.semanticIndex("target") : -1, flip = this.sampleAt(clip, "flip", localFrame, 0) >= .5 || (((_e = clip.pbs) === null || _e === void 0 ? void 0 : _e.foeFlip) && relativeIndex >= 0 && relativeIndex % 2 === 1), flipY = this.sampleAt(clip, "flipY", localFrame, 0) >= .5;
        if (contextOverride && contextOverride.flip) flip = !flip;
        if (contextOverride && contextOverride.flipY) flipY = !flipY;
        var randomInvertFlip = extra && extra.randomInvertFlip !== undefined ? !!extra.randomInvertFlip : !!((_f = clip.pbs) === null || _f === void 0 ? void 0 : _f.randomInvertFlip);
        if (randomInvertFlip && rnd() < .5)
            flip = !flip;
        // New Animation Editor angle order is significant:
        //   command value + (InitialAngleToFocus OR random angle offset)
        //   OR AlwaysPointAtFocus + offset + command value
        //   THEN RandomInvertAngle. RandomAngleRange REPLACES the base angle offset.
        // Applying inversion/randomness before AngleOverride produced mirrored arcs.
        var angleOffset = 0;
        var range = Math.max(0, Number(extra && extra.randomAngleRange !== undefined ? extra.randomAngleRange : (((_g = clip.pbs) === null || _g === void 0 ? void 0 : _g.randomAngleRange) || 0)));
        var mode = (extra && extra.suppressAngleOverride) ? "none" : String(((_h = clip.pbs) === null || _h === void 0 ? void 0 : _h.angleOverride) || "none").toLowerCase();
        var xyOffset = (special && src) ? Number(src.sh || 0) / 2 : 0;
        if (range > 0) {
            // Ruby rand(-range, range) is integer for integer PBS values. Keep a
            // deterministic import preview while preserving the same bounds.
            angleOffset = Math.floor(rnd() * (range * 2 + 1)) - range;
        }
        else if (mode.includes("initial") && mode.includes("focus")) {
            var origin = this.pbsInitialAngleOrigin(clip), target = this.pbsAngleTarget(clip);
            // initial_angle_between adds get_xy_offset only to the source point.
            origin.y += xyOffset;
            angleOffset = this.rgssAngleBetween(origin.x, origin.y, target.x, target.y);
        }
        if (mode.includes("always") && mode.includes("focus")) {
            var origin = Object.assign({}, basePos), target = Object.assign({}, this.pbsAngleTarget(clip));
            // During playback the sprite position already contains offset_xy and the
            // target calculation adds the same offset, exactly as ParticleSprite.
            origin.y += xyOffset;
            target.y += xyOffset;
            rotation += this.rgssAngleBetween(origin.x, origin.y, target.x, target.y) + angleOffset;
        }
        else {
            rotation += angleOffset;
        }
        var randomAngleInverted = false;
        var randomInvertAngle = extra && extra.randomInvertAngle !== undefined ? !!extra.randomInvertAngle : !!((_j = clip.pbs) === null || _j === void 0 ? void 0 : _j.randomInvertAngle);
        if (randomInvertAngle) {
            randomAngleInverted = rnd() < .5;
            if (randomAngleInverted)
                rotation *= -1;
        }
        var w = 32 * Math.abs(sxScale), h = 32 * Math.abs(syScale), pos = Object.assign({}, basePos);
        this.drawClipAfterimages(clip, selected, accent, localFrame, extra, alphaMult);
        var visualLocalX = 0, visualLocalY = 0;
        if (special && src)
            pos.y += src.sh / 2;
        // Capture the scene/camera transform before applying the particle's own
        // position/rotation/flip. New Animation Editor's second layer x2/y2 are
        // screen/world-space offsets from sprite1, not local offsets rotated by
        // sprite1. Keeping this matrix lets drawSecondLayer reproduce that.
        c.save();
        if (this.clipCoordinateSpace(clip) === "screen" && this.sceneBaseTransform && c.setTransform)
            c.setTransform(this.sceneBaseTransform);
        var outerTransform = c.getTransform ? c.getTransform() : null;
        c.translate(pos.x, pos.y);
        c.rotate(-rotation * Math.PI / 180);
        if (flip || flipY)
            c.scale(flip ? -1 : 1, flipY ? -1 : 1);
        c.globalAlpha = opacity * alphaMult;
        if (invert)
            c.filter = "invert(1)";
        if (blend === 1)
            c.globalCompositeOperation = "lighter";
        else if (blend === 2)
            c.globalCompositeOperation = "multiply";
        if (procedural) {
            var g = clip.graphic || {}, rawW = Math.max(1, Number(g.proceduralW || 16)), rawH = Math.max(1, Number(g.proceduralH || 16)), ax = Math.abs(sxScale), ay = Math.abs(syScale), pw = rawW * ax, ph = rawH * ay;
            w = pw;
            h = ph;
            var ox = Number.isFinite(Number(g.proceduralOx)) ? Number(g.proceduralOx) : rawW / 2;
            var oy = Number.isFinite(Number(g.proceduralOy)) ? Number(g.proceduralOy) : rawH / 2;
            if (g.origin === "top_left") {
                ox = 0;
                oy = 0;
            }
            else if (g.origin === "bottom") {
                ox = rawW / 2;
                oy = rawH;
            }
            visualLocalX = (rawW / 2 - ox) * ax;
            visualLocalY = (rawH / 2 - oy) * ay;
            var cssColor = function (value, fallback) {
                if (fallback === void 0) {
                    fallback = "rgba(255,255,255,0.9)";
                }
                if (typeof value === "string")
                    return value;
                if (value && typeof value === "object")
                    return "rgba(".concat(Number(value.r || 0), ",").concat(Number(value.g || 0), ",").concat(Number(value.b || 0), ",").concat(clamp(Number(value.a == null ? 255 : value.a) / 255, 0, 1), ")");
                return fallback;
            };
            if (g.procedural === "composite") {
                try {
                    for (var _s = __values((g.proceduralLayers || [])), _t = _s.next(); !_t.done; _t = _s.next()) {
                        var layer = _t.value;
                        c.fillStyle = cssColor(layer.color);
                        c.fillRect((Number(layer.x || 0) - ox) * ax, (Number(layer.y || 0) - oy) * ay, Number(layer.w || 0) * ax, Number(layer.h || 0) * ay);
                    }
                }
                catch (e_21_1) {
                    e_21 = { error: e_21_1 };
                }
                finally {
                    try {
                        if (_t && !_t.done && (_r = _s.return))
                            _r.call(_s);
                    }
                    finally {
                        if (e_21)
                            throw e_21.error;
                    }
                }
            }
            else if (g.procedural === "spotlight") {
                var grad = c.createLinearGradient(0, -oy * ay, 0, (rawH - oy) * ay);
                grad.addColorStop(0, "rgba(255,255,255,0.66)");
                grad.addColorStop(1, "rgba(255,255,255,0)");
                c.fillStyle = grad;
                c.beginPath();
                c.moveTo((rawW * .43 - ox) * ax, -oy * ay);
                c.lineTo((rawW * .57 - ox) * ax, -oy * ay);
                c.lineTo((rawW - ox) * ax, (rawH - oy) * ay);
                c.lineTo(-ox * ax, (rawH - oy) * ay);
                c.closePath();
                c.fill();
            }
            else if (g.procedural === "circle") {
                c.strokeStyle = c.fillStyle = cssColor(g.proceduralColor);
                c.beginPath();
                c.ellipse((rawW / 2 - ox) * ax, (rawH / 2 - oy) * ay, pw / 2, ph / 2, 0, 0, Math.PI * 2);
                if (g.proceduralHollow) {
                    c.lineWidth = Math.max(1, Number(g.proceduralLineWidth || Math.max(1, Number(g.proceduralRadius || rawW / 2) * .12)) * Math.min(ax, ay));
                    c.stroke();
                }
                else
                    c.fill();
            }
            else {
                c.fillStyle = cssColor(g.proceduralColor);
                c.fillRect(-ox * ax, -oy * ay, pw, ph);
            }
        }
        else if (im && src) {
            var toneFx = this.applyContextFxCorrection(clip, "tone", this.fxAt(clip, "tone", localFrame));
            var colorFx = this.fxAt(clip, "color", localFrame);
            if (extra && extra.randomSeed !== undefined && clip.pbs && Array.isArray(clip.pbs.particleTonePalette) && clip.pbs.particleTonePalette.length) {
                var palette = clip.pbs.particleTonePalette.filter(function (x) { return /^#[0-9a-f]{6}$/i.test(String(x || "")); });
                var strength = Math.max(0, Math.min(100, Number(clip.pbs.particleToneStrength || 0)));
                if (palette.length && strength > 0) {
                    var idx = Math.abs(Math.floor(Number(extra.randomSeed) || 0)) % palette.length;
                    var hex = String(palette[idx] || "#ffffff").replace("#", "");
                    colorFx = { r: parseInt(hex.slice(0, 2), 16), g: parseInt(hex.slice(2, 4), 16), b: parseInt(hex.slice(4, 6), 16), a: 255 * strength / 100 };
                }
            }
            var fx = this.fxImage(im, src, toneFx, colorFx), drawIm = fx.image, drawSrc = fx.src;
            w = drawSrc.sw * Math.abs(sxScale);
            h = drawSrc.sh * Math.abs(syScale);
            c.imageSmoothingEnabled = false;
            var dx = -w / 2, dy = -h / 2;
            var oxOverride = this.sampleAt(clip, "originX", localFrame, NaN), oyOverride = this.sampleAt(clip, "originY", localFrame, NaN), oxOffset = this.sampleAt(clip, "originOffsetX", localFrame, 0), oyOffset = this.sampleAt(clip, "originOffsetY", localFrame, 0);
            if (Number.isFinite(oxOverride))
                dx = -oxOverride * Math.abs(sxScale);
            if (Number.isFinite(oyOverride))
                dy = -oyOverride * Math.abs(syScale);
            var origin = ((_k = clip.graphic) === null || _k === void 0 ? void 0 : _k.origin) || "auto", screenFocus = ["foreground", "midground", "background"].includes(focus);
            if (origin === "bottom" || special)
                dy = -h;
            else if (origin === "top_left" || (origin === "auto" && screenFocus && drawSrc.sw >= this.logicalSize().width * .8)) {
                dx = 0;
                dy = 0;
            }
            visualLocalX = dx + w / 2;
            visualLocalY = dy + h / 2;
            var hasSecond = !!((_m = clip.pbs) === null || _m === void 0 ? void 0 : _m.secondLayer), secondZ = hasSecond ? Number(this.samplePbsScalar(clip, "z2", localFrame, 0) || 0) : 0;
            if (hasSecond && secondZ < 0)
                this.drawSecondLayer(c, clip, drawIm, drawSrc, dx, dy, w, h, localFrame, pos, rotation, flip, flipY, randomAngleInverted, outerTransform, alphaMult);
            if ((_l = clip.pbs) === null || _l === void 0 ? void 0 : _l.tiled)
                this.drawTiledImage(c, clip, drawIm, drawSrc, dx, dy, w, h, localFrame, pos);
            else
                this.drawImageMasked(c, clip, drawIm, drawSrc, dx, dy, w, h, localFrame);
            if (hasSecond && secondZ >= 0)
                this.drawSecondLayer(c, clip, drawIm, drawSrc, dx, dy, w, h, localFrame, pos, rotation, flip, flipY, randomAngleInverted, outerTransform, alphaMult);
        }
        else {
            var rr = 15 * Math.max(Math.abs(sxScale), Math.abs(syScale)), gl = c.createRadialGradient(0, 0, 2, 0, 0, rr * 1.8);
            gl.addColorStop(0, "rgba(255,255,255,.98)");
            gl.addColorStop(.32, accent);
            gl.addColorStop(1, "rgba(90,120,255,0)");
            c.fillStyle = gl;
            c.beginPath();
            c.arc(0, 0, rr * 1.8, 0, Math.PI * 2);
            c.fill();
        }
        c.restore();
        if (localFrame === this.frame) {
            var localVX = visualLocalX * (flip ? -1 : 1), localVY = visualLocalY * (flipY ? -1 : 1);
            var hitRad = -rotation * Math.PI / 180, hitCos = Math.cos(hitRad), hitSin = Math.sin(hitRad);
            var visualCenterX = pos.x + localVX * hitCos - localVY * hitSin;
            var visualCenterY = pos.y + localVX * hitSin + localVY * hitCos;
            this.hitShapes.push({ objectId: clip.id, x: visualCenterX, y: visualCenterY, w: Math.max(20, w), h: Math.max(20, h), kind: "clip" });
            if (selected && !this.playing) {
                if (sortPositionKeys(clip).length && ((_p = (_o = this.callbacks).showPath) === null || _p === void 0 ? void 0 : _p.call(_o)) !== false)
                    this.drawPath(clip, accent);
                c.save();
                c.translate(pos.x, pos.y);
                c.rotate(-rotation * Math.PI / 180);
                c.strokeStyle = accent;
                c.lineWidth = 1.2;
                c.setLineDash([4, 3]);
                c.strokeRect(-w / 2 - 5, -h / 2 - 5, w + 10, h + 10);
                c.restore();
            }
        }
    };
    BattlePreview.prototype.sampleAt = function (o, prop, frame, def) { var old = this.frame; this.frame = frame; var v = sampleValue(o, prop, frame, def); this.frame = old; return v; };
    BattlePreview.prototype.sampleDiscreteAt = function (o, prop, frame, def) {
        var e_22, _q;
        var _a, _b;
        var keys = (((o === null || o === void 0 ? void 0 : o.valueKeys) || {})[prop] || []).slice().sort(function (a, b) { return Number(a.frame || 0) - Number(b.frame || 0); });
        var base = Number((_b = (_a = o === null || o === void 0 ? void 0 : o.visual) === null || _a === void 0 ? void 0 : _a[prop]) !== null && _b !== void 0 ? _b : def);
        if (!keys.length)
            return base;
        var f = Math.floor(Number(frame || 0) + 0.000001);
        if (f < Number(keys[0].frame || 0))
            return base;
        if (f === Number(keys[0].frame || 0))
            return Number(keys[0].value);
        var value = Number(keys[0].value);
        try {
            for (var keys_4 = __values(keys), keys_4_1 = keys_4.next(); !keys_4_1.done; keys_4_1 = keys_4.next()) {
                var key = keys_4_1.value;
                if (Number(key.frame || 0) > f)
                    break;
                value = Number(key.value);
            }
        }
        catch (e_22_1) {
            e_22 = { error: e_22_1 };
        }
        finally {
            try {
                if (keys_4_1 && !keys_4_1.done && (_q = keys_4.return))
                    _q.call(keys_4);
            }
            finally {
                if (e_22)
                    throw e_22.error;
            }
        }
        return value;
    };
    BattlePreview.prototype.drawTiledImage = function (c, clip, image, src, dx, dy, w, h, frame, pos) {
        if (!image || !src || !w || !h)
            return;
        var logical = this.logicalSize(), tw = Math.max(1, Math.abs(w)), th = Math.max(1, Math.abs(h)), pad = 2;
        var minX = -Number((pos === null || pos === void 0 ? void 0 : pos.x) || 0) - tw * pad, maxX = logical.width - Number((pos === null || pos === void 0 ? void 0 : pos.x) || 0) + tw * pad, minY = -Number((pos === null || pos === void 0 ? void 0 : pos.y) || 0) - th * pad, maxY = logical.height - Number((pos === null || pos === void 0 ? void 0 : pos.y) || 0) + th * pad;
        for (var yy = Math.floor(minY / th) * th; yy <= maxY; yy += th)
            for (var xx = Math.floor(minX / tw) * tw; xx <= maxX; xx += tw)
                c.drawImage(image, src.sx, src.sy, src.sw, src.sh, xx, yy, w, h);
    };
    BattlePreview.prototype.drawImageMasked = function (c, clip, image, src, dx, dy, w, h, frame) {
        var _a;
        var mask = (_a = this.maskImages.get(clip.id)) === null || _a === void 0 ? void 0 : _a.image;
        if (!mask) {
            c.drawImage(image, src.sx, src.sy, src.sw, src.sh, dx, dy, w, h);
            return;
        }
        var cv = document.createElement("canvas");
        cv.width = Math.max(1, Math.round(Math.abs(w)));
        cv.height = Math.max(1, Math.round(Math.abs(h)));
        var x = cv.getContext("2d");
        x.imageSmoothingEnabled = false;
        x.drawImage(image, src.sx, src.sy, src.sw, src.sh, 0, 0, cv.width, cv.height);
        x.globalCompositeOperation = "destination-in";
        var mx = this.samplePbsScalar(clip, "maskX", frame, 0), my = this.samplePbsScalar(clip, "maskY", frame, 0), mzX = this.samplePbsScalar(clip, "maskZoomX", frame, 100) / 100, mzY = this.samplePbsScalar(clip, "maskZoomY", frame, 100) / 100, mop = this.samplePbsScalar(clip, "maskOpacity", frame, 255) / 255;
        x.globalAlpha = mop;
        x.drawImage(mask, mx, my, mask.width * mzX, mask.height * mzY);
        c.drawImage(cv, dx, dy, w, h);
    };
    BattlePreview.prototype.drawSecondLayer = function (c, clip, image, src, dx, dy, w, h, frame, pos, mainRotation, mainFlip, mainFlipY, randomAngleInverted, outerTransform, alphaMult) {
        if (alphaMult === void 0) {
            alphaMult = 1;
        }
        var x2 = this.samplePbsScalar(clip, "x2", frame, 0), y2 = this.samplePbsScalar(clip, "y2", frame, 0), zx = this.samplePbsScalar(clip, "zoomX2", frame, 100) / 100, zy = this.samplePbsScalar(clip, "zoomY2", frame, 100) / 100, opaOffset = this.samplePbsScalar(clip, "opacity2", frame, 0), rawAng2 = this.samplePbsScalar(clip, "angle2", frame, 0), flip2 = !!this.samplePbsScalar(clip, "flip2", frame, 0), blend = Math.round(this.samplePbsScalar(clip, "blending2", frame, 0)), baseOpacity = this.sampleAt(clip, "opacity", frame, 100) * 255 / 100, alpha = clamp((baseOpacity + Number(opaOffset || 0)) / 255, 0, 1) * alphaMult;
        if (alpha <= 0)
            return;
        var src2 = Object.assign({}, src);
        // New Animation Editor defaults Frame2 to 0. It does not inherit the
        // current frame of layer 1 unless a Frame2 command explicitly says so.
        var fr2 = Math.max(0, Math.round(this.samplePbsScalar(clip, "frame2", frame, 0)));
        if ((src.frames || 1) > 1) {
            var cw = src.sw, ch = src.sh, cols = Math.max(1, Math.floor(image.width / cw)), count = Math.max(1, Math.floor(image.width / cw) * Math.floor(image.height / ch)), f = fr2 % count;
            src2 = Object.assign(Object.assign({}, src), { sx: (f % cols) * cw, sy: Math.floor(f / cols) * ch, frame: f });
        }
        var toneRaw = this.samplePbsScalar(clip, "tone2", frame, "+000+000+000+000"), colorRaw = this.samplePbsScalar(clip, "color2", frame, "#00000000"), fx = this.fxImage(image, src2, typeof toneRaw === "string" ? parseHexColor(toneRaw, true) : { r: 0, g: 0, b: 0, a: 0 }, typeof colorRaw === "string" ? parseHexColor(colorRaw, false) : { r: 0, g: 0, b: 0, a: 0 }), invBase = this.sampleAt(clip, "invert", frame, 0) >= .5, inv2 = !!this.samplePbsScalar(clip, "invertColor2", frame, false);
        var angle2 = Number(rawAng2 || 0) * (randomAngleInverted ? -1 : 1), finalRotation = Number(mainRotation || 0) + angle2, finalFlip = !!mainFlip !== flip2, finalFlipY = !!mainFlipY;
        c.save();
        // drawClip is currently inside sprite1's transform. Reset to the matrix
        // that contains only the battle scene/camera, then place sprite2 at
        // sprite1.x + x2 / sprite1.y + y2 exactly like ParticleSprite.rb.
        if (outerTransform && c.setTransform)
            c.setTransform(outerTransform.a, outerTransform.b, outerTransform.c, outerTransform.d, outerTransform.e, outerTransform.f);
        else {
            // Fallback for a very old Canvas implementation. This branch keeps
            // legacy behavior rather than failing the whole preview.
            c.translate(x2, y2);
        }
        if (outerTransform && c.setTransform)
            c.translate(Number((pos && pos.x) || 0) + Number(x2 || 0), Number((pos && pos.y) || 0) + Number(y2 || 0));
        c.rotate(-finalRotation * Math.PI / 180);
        if (finalFlip || finalFlipY)
            c.scale(finalFlip ? -1 : 1, finalFlipY ? -1 : 1);
        c.globalAlpha = alpha;
        if (invBase !== inv2)
            c.filter = "invert(1)";
        if (blend === 1)
            c.globalCompositeOperation = "lighter";
        else if (blend === 2)
            c.globalCompositeOperation = "multiply";
        // Zoom2 multiplies layer 1's zoom around the same origin. Multiplying
        // dx/dy as well as width/height preserves centre/bottom/top-left anchors.
        c.drawImage(fx.image, fx.src.sx, fx.src.sy, fx.src.sw, fx.src.sh, dx * zx, dy * zy, w * zx, h * zy);
        c.restore();
    };
    BattlePreview.prototype.dynamicCodeGrid = function (image) {
        var width = Number((image === null || image === void 0 ? void 0 : image.width) || 0), height = Number((image === null || image === void 0 ? void 0 : image.height) || 0);
        if (width <= 0 || height <= 0)
            return { cols: 1, rows: 1, fw: Math.max(1, width), fh: Math.max(1, height), count: 1 };
        if (width === height)
            return { cols: 1, rows: 1, fw: width, fh: height, count: 1 };
        if (width >= height * 2 && width % height === 0 && width / height <= 16) {
            var cols = width / height;
            return { cols: cols, rows: 1, fw: height, fh: height, count: cols };
        }
        if (height >= width * 2 && height % width === 0 && height / width <= 16) {
            var rows = height / width;
            return { cols: 1, rows: rows, fw: width, fh: width, count: rows };
        }
        var best = { cols: 1, rows: 1, fw: width, fh: height, count: 1 }, score = Infinity;
        for (var cols = 1; cols <= 8; cols++) {
            if (width % cols)
                continue;
            for (var rows = 1; rows <= 8; rows++) {
                if (height % rows || (cols === 1 && rows === 1))
                    continue;
                var fw = width / cols, fh = height / rows;
                if (fw < 12 || fh < 12)
                    continue;
                var ratio = fw / fh, pen = Math.abs(Math.log(Math.max(.0001, Math.abs(ratio)))) + Math.max(0, cols * rows - 16) + (fw * fh < 22 * 22 ? 10 : 0);
                if (pen < score) {
                    score = pen;
                    best = { cols: cols, rows: rows, fw: fw, fh: fh, count: cols * rows };
                }
            }
        }
        return best;
    };
    BattlePreview.prototype.sourceFrame = function (clip, image, frame, seed, randomFrameMaxOverride, forcedFrameOverride) {
        if (frame === void 0) {
            frame = this.frame;
        }
        if (seed === void 0) {
            seed = 0;
        }
        if (randomFrameMaxOverride === void 0) {
            randomFrameMaxOverride = null;
        }
        if (forcedFrameOverride === void 0) {
            forcedFrameOverride = null;
        }
        var _a;
        if (!(image === null || image === void 0 ? void 0 : image.width) || !(image === null || image === void 0 ? void 0 : image.height))
            return null;
        var g = clip.graphic || {}, customW = this.sampleDiscreteAt(clip, "srcW", frame, 0), customH = this.sampleDiscreteAt(clip, "srcH", frame, 0);
        if (customW > 0 && customH > 0) {
            var sx = this.sampleDiscreteAt(clip, "srcX", frame, 0), sy = this.sampleDiscreteAt(clip, "srcY", frame, 0);
            return { sx: Math.max(0, sx), sy: Math.max(0, sy), sw: Math.max(1, Math.min(customW, image.width - Math.max(0, sx))), sh: Math.max(1, Math.min(customH, image.height - Math.max(0, sy))), frames: 1, frame: 0 };
        }
        var fr = forcedFrameOverride !== null && forcedFrameOverride !== undefined ? Math.max(0, Math.round(Number(forcedFrameOverride) || 0)) : Math.max(0, Math.round(this.sampleDiscreteAt(clip, "graphicFrame", frame, Number(g.frame || 0))));
        var randomFrameMax = randomFrameMaxOverride !== null && randomFrameMaxOverride !== undefined ? Number(randomFrameMaxOverride) : Number(((_a = clip.pbs) === null || _a === void 0 ? void 0 : _a.randomFrameMax) || 0);
        if ((forcedFrameOverride === null || forcedFrameOverride === undefined) && randomFrameMax > 0) {
            var r = seeded(Number(seed || hash32("".concat(clip.id, ":").concat(Math.floor(frame)))))();
            fr = Math.floor(r * (randomFrameMax + 1));
        }
        if (g.spritesheet === "rmxp") {
            var cw = Math.max(1, Number(g.cellW || 192)), ch = Math.max(1, Number(g.cellH || 192));
            var actualCols = Math.max(1, Math.floor(image.width / cw)), actualRows = Math.max(1, Math.floor(image.height / ch));
            var declaredCols = Math.max(0, Math.floor(Number(g.cols || 0)));
            var cols = declaredCols > 0 && declaredCols <= actualCols ? declaredCols : actualCols;
            var rows = actualRows, count_1 = Math.max(1, cols * rows);
            fr = ((fr % count_1) + count_1) % count_1;
            var sx = (fr % cols) * cw, sy = Math.floor(fr / cols) * ch;
            return { sx: sx, sy: sy, sw: Math.max(1, Math.min(cw, image.width - sx)), sh: Math.max(1, Math.min(ch, image.height - sy)), frames: count_1, frame: fr };
        }
        if (g.spritesheet === "code-dynamic-grid") {
            var grid = this.dynamicCodeGrid(image);
            var idx = 0, style = String(g.sheetStyle || "default").toLowerCase();
            if (style === "charge")
                idx = Math.min(Math.floor(grid.count / 3), grid.count - 1);
            else if (style === "burst")
                idx = Math.min(grid.count - 1, Math.floor(grid.rows / 2) * grid.cols + Math.floor(grid.cols / 2));
            if (g.playSheet) {
                var start = Number(g.playStart || 0), count_2 = Math.max(1, Math.min(grid.count, Number(g.playFrameCount || grid.count))), ticks = Math.max(1, Number(g.ticksPerFrame || 1)), base = style === "burst" ? Math.max(0, Math.floor(grid.count / 3)) : 0;
                idx = base + Math.max(0, Math.floor((frame - start) / ticks)) % count_2;
            }
            idx = ((idx % grid.count) + grid.count) % grid.count;
            var sw = grid.fw, sh = grid.fh, sx = (idx % grid.cols) * sw, sy = Math.floor(idx / grid.cols) * sh;
            sw = Math.max(1, Math.min(sw, image.width - Math.max(0, sx)));
            sh = Math.max(1, Math.min(sh, image.height - Math.max(0, sy)));
            return { sx: sx, sy: sy, sw: sw, sh: sh, frames: grid.count, frame: idx };
        }
        if (g.spritesheet === "code-auto-grid" || g.spritesheet === "code-grid") {
            var fallback = g.cellMode === "square-height" ? image.height : Math.min(image.width, image.height), cw = Math.max(1, Number(g.cellW) || fallback), ch = Math.max(1, Number(g.cellH) || cw), cols = Math.max(1, Number(g.gridCols || g.cols) || Math.floor(image.width / cw)), rows = Math.max(1, Math.floor(image.height / ch)), count_3 = Math.max(1, cols * rows);
            if (g.playSheet) {
                var ticks = Math.max(1, Number(g.ticksPerFrame || 1)), start = Number(g.playStart || clip.startFrame || 0), first = Math.max(0, Number(g.playFirstFrame || 0)), limited = Math.max(0, Number(g.playFrameCount || 0)), span = limited > 0 ? Math.min(count_3, limited) : count_3;
                fr = first + Math.max(0, Math.floor((frame - start) / ticks)) % Math.max(1, span);
            }
            fr = ((fr % count_3) + count_3) % count_3;
            return { sx: (fr % cols) * cw, sy: Math.floor(fr / cols) * ch, sw: Math.min(cw, image.width), sh: Math.min(ch, image.height), frames: count_3, frame: fr };
        }
        var sheet = g.spritesheet === "sheet";
        if (g.spritesheet === "auto") {
            var codeLike = g.source === "code" || String(clip.type || "").includes("code");
            if (codeLike && (image.width > image.height * 1.35 || image.height > image.width * 1.35)) {
                var grid = this.dynamicCodeGrid(image);
                if (grid.count > 1) {
                    fr = ((fr % grid.count) + grid.count) % grid.count;
                    return { sx: (fr % grid.cols) * grid.fw, sy: Math.floor(fr / grid.cols) * grid.fh, sw: Math.min(grid.fw, image.width), sh: Math.min(grid.fh, image.height), frames: grid.count, frame: fr };
                }
            }
            sheet = codeLike ? (image.width > image.height && image.width % image.height === 0) : image.width > image.height * 2;
        }
        if (!sheet)
            return { sx: 0, sy: 0, sw: image.width, sh: image.height, frames: 1, frame: 0 };
        var side = image.height, count = Math.max(1, Math.floor(image.width / side));
        if (g.playSheet && this.animation) {
            var sec = Math.max(0, frame - (clip.startFrame || 0)) / Math.max(1, this.animation.fps || 20);
            fr = Math.floor(sec * Math.max(1, Number(g.sheetFps || 20)));
        }
        fr = ((fr % count) + count) % count;
        return { sx: fr * side, sy: 0, sw: side, sh: side, frames: count, frame: fr };
    };
    BattlePreview.prototype.applyContextFxCorrection = function (clip, kind, raw) {
        if (kind !== "tone") return raw;
        var ov = this.contextOverrideForObject(clip);
        if (!ov) return raw;
        // Context override keys live in the animation timeline, so use the
        // preview's current global frame here. The previous build referenced an
        // undefined local `frame`, causing `Unexpected error: frame is not defined`
        // as soon as a contextual Tone correction was evaluated.
        var contextFrame = Number(this.frame || 0);
        var value = raw && typeof raw === "object" ? Object.assign({}, raw) : { r: 0, g: 0, b: 0, a: 0 };
        var r = Number(value.red != null ? value.red : value.r || 0) + Number(this.contextOverrideValue(clip, "toneRed", contextFrame, 0) || 0);
        var g = Number(value.green != null ? value.green : value.g || 0) + Number(this.contextOverrideValue(clip, "toneGreen", contextFrame, 0) || 0);
        var b = Number(value.blue != null ? value.blue : value.b || 0) + Number(this.contextOverrideValue(clip, "toneBlue", contextFrame, 0) || 0);
        var gray = Number(value.gray != null ? value.gray : value.a || 0) + Number(this.contextOverrideValue(clip, "toneGray", contextFrame, 0) || 0);
        return { r: clamp(r, -255, 255), g: clamp(g, -255, 255), b: clamp(b, -255, 255), a: clamp(gray, 0, 255) };
    };
    BattlePreview.prototype.fxAt = function (clip, kind, frame) {
        var e_23, _q;
        if (frame === void 0) {
            frame = this.frame;
        }
        var _a, _b, _c, _d, _e, _f, _g, _h;
        var zero = { r: 0, g: 0, b: 0, a: 0 }, toFx = function (raw) {
            var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
            if (typeof raw === "string")
                return parseHexColor(raw, kind === "tone");
            if (raw && typeof raw === "object")
                return { r: Number((_b = (_a = raw.red) !== null && _a !== void 0 ? _a : raw.r) !== null && _b !== void 0 ? _b : 0), g: Number((_d = (_c = raw.green) !== null && _c !== void 0 ? _c : raw.g) !== null && _d !== void 0 ? _d : 0), b: Number((_f = (_e = raw.blue) !== null && _e !== void 0 ? _e : raw.b) !== null && _f !== void 0 ? _f : 0), a: Number(kind === "tone" ? ((_h = (_g = raw.gray) !== null && _g !== void 0 ? _g : raw.a) !== null && _h !== void 0 ? _h : 0) : ((_k = (_j = raw.alpha) !== null && _j !== void 0 ? _j : raw.a) !== null && _k !== void 0 ? _k : 0)) };
            return Object.assign({}, zero);
        };
        var mix = function (a, b, t) { return ({ r: lerp(a.r, b.r, t), g: lerp(a.g, b.g, t), b: lerp(a.b, b.b, t), a: lerp(a.a, b.a, t) }); };
        var value = Object.assign({}, zero);
        var ops = (clip.fxOps || []).slice().sort(function (a, b) { var _a, _b, _c, _d, _e, _f; return Number((_c = (_a = a.frame) !== null && _a !== void 0 ? _a : (_b = a.args) === null || _b === void 0 ? void 0 : _b[0]) !== null && _c !== void 0 ? _c : 0) - Number((_f = (_d = b.frame) !== null && _d !== void 0 ? _d : (_e = b.args) === null || _e === void 0 ? void 0 : _e[0]) !== null && _f !== void 0 ? _f : 0); });
        try {
            for (var ops_1 = __values(ops), ops_1_1 = ops_1.next(); !ops_1_1.done; ops_1_1 = ops_1.next()) {
                var op = ops_1_1.value;
                var name = String(op.name || ""), f = Number((_c = (_a = op.frame) !== null && _a !== void 0 ? _a : (_b = op.args) === null || _b === void 0 ? void 0 : _b[0]) !== null && _c !== void 0 ? _c : 0);
                if (f > frame)
                    break;
                if (name === "legacyFx") {
                    var v = op[kind];
                    if (v)
                        value = toFx(v);
                    continue;
                }
                if (kind === "tone" && !/Tone/i.test(name))
                    continue;
                if (kind === "color" && !/Color/i.test(name))
                    continue;
                var args = op.args || [], moving = /^move/i.test(name) || /^Move/.test(name), raw = (_d = op.value) !== null && _d !== void 0 ? _d : (moving ? ((_e = args[2]) !== null && _e !== void 0 ? _e : args.at(-1)) : ((_f = args[1]) !== null && _f !== void 0 ? _f : args.at(-1))), target = toFx(raw), dur = moving ? Math.max(0, Number((_h = (_g = op.duration) !== null && _g !== void 0 ? _g : args[1]) !== null && _h !== void 0 ? _h : 0)) : 0;
                if (moving && dur > 0 && frame < f + dur) {
                    var t = ease((frame - f) / dur, op.easing || args[3] || "linear");
                    return mix(value, target, t);
                }
                value = target;
            }
        }
        catch (e_23_1) {
            e_23 = { error: e_23_1 };
        }
        finally {
            try {
                if (ops_1_1 && !ops_1_1.done && (_q = ops_1.return))
                    _q.call(ops_1);
            }
            finally {
                if (e_23)
                    throw e_23.error;
            }
        }
        if (kind === "tone")
            value = { r: this.sampleAt(clip, "toneRed", frame, value.r), g: this.sampleAt(clip, "toneGreen", frame, value.g), b: this.sampleAt(clip, "toneBlue", frame, value.b), a: this.sampleAt(clip, "toneGray", frame, value.a) };
        else
            value = { r: this.sampleAt(clip, "colorRed", frame, value.r), g: this.sampleAt(clip, "colorGreen", frame, value.g), b: this.sampleAt(clip, "colorBlue", frame, value.b), a: this.sampleAt(clip, "colorAlpha", frame, value.a) };
        return value;
    };
    BattlePreview.prototype.fxImage = function (image, src, tone, color) {
        if (!image || !src)
            return { image: image, src: src };
        var key = [image.src, src.sx, src.sy, src.sw, src.sh, Math.round(tone.r), Math.round(tone.g), Math.round(tone.b), Math.round(tone.a), Math.round(color.r), Math.round(color.g), Math.round(color.b), Math.round(color.a)].join("|");
        if (this.fxCache.has(key))
            return this.fxCache.get(key);
        var cv = document.createElement("canvas");
        cv.width = Math.max(1, Math.round(src.sw));
        cv.height = Math.max(1, Math.round(src.sh));
        var cx = cv.getContext("2d", { willReadFrequently: true });
        cx.imageSmoothingEnabled = false;
        cx.drawImage(image, src.sx, src.sy, src.sw, src.sh, 0, 0, cv.width, cv.height);
        try {
            var d = cx.getImageData(0, 0, cv.width, cv.height), p = d.data, gray = clamp(tone.a / 255, 0, 1), ca = clamp(color.a / 255, 0, 1);
            for (var i = 0; i < p.length; i += 4) {
                var r = clamp(p[i] + tone.r, 0, 255), g = clamp(p[i + 1] + tone.g, 0, 255), b = clamp(p[i + 2] + tone.b, 0, 255);
                if (gray > 0) {
                    var y = .299 * r + .587 * g + .114 * b;
                    r = lerp(r, y, gray);
                    g = lerp(g, y, gray);
                    b = lerp(b, y, gray);
                }
                if (ca > 0) {
                    r = lerp(r, color.r, ca);
                    g = lerp(g, color.g, ca);
                    b = lerp(b, color.b, ca);
                }
                p[i] = r;
                p[i + 1] = g;
                p[i + 2] = b;
            }
            cx.putImageData(d, 0, 0);
        }
        catch (_a) { }
        var ret = { image: cv, src: { sx: 0, sy: 0, sw: cv.width, sh: cv.height, frames: 1, frame: 0 } };
        this.fxCache.set(key, ret);
        if (this.fxCache.size > 256)
            this.fxCache.delete(this.fxCache.keys().next().value);
        return ret;
    };
    BattlePreview.prototype.specialBattlerBundle = function (source) {
        var _this = this;
        var opp = this.semanticOpposing(), ui = this.semanticIndex("user"), ti = this.semanticIndex("target");
        var pick = function (imageKey, metaKey, fallbackImage, fallbackMeta) {
            var meta = _this.battlerMeta[metaKey] || _this.battlerMeta[fallbackMeta] || {};
            var view = String(meta.view || (String(imageKey || "").toLowerCase().endsWith("back") ? "back" : String(imageKey || "").toLowerCase().endsWith("front") ? "front" : ""));
            return { image: _this.images[imageKey] || _this.images[fallbackImage] || null, meta: meta, view: view, playerSide: String(imageKey || fallbackImage || "").startsWith("user") };
        };
        var actual = function (role, variant) {
            var semanticUser = role === "user";
            if (opp) {
                if (semanticUser) {
                    if (variant === "front")
                        return pick("targetFront", "targetFront", "target", "target");
                    if (variant === "back")
                        return pick("targetBack", "targetBack", "target", "target");
                    return ui % 2 === 0 ? pick("targetBack", "targetBack", "target", "target") : pick("targetFront", "targetFront", "target", "target");
                }
                if (variant === "front")
                    return pick("userFront", "userFront", "user", "user");
                if (variant === "back")
                    return pick("userBack", "userBack", "user", "user");
                return ti % 2 === 0 ? pick("userBack", "userBack", "user", "user") : pick("userFront", "userFront", "user", "user");
            }
            if (semanticUser) {
                if (variant === "front")
                    return pick("userFront", "userFront", "user", "user");
                if (variant === "back")
                    return pick("userBack", "userBack", "user", "user");
                return ui % 2 === 0 ? pick("userBack", "userBack", "user", "user") : pick("userFront", "userFront", "user", "user");
            }
            if (variant === "front")
                return pick("targetFront", "targetFront", "target", "target");
            if (variant === "back")
                return pick("targetBack", "targetBack", "target", "target");
            return ti % 2 === 0 ? pick("targetBack", "targetBack", "target", "target") : pick("targetFront", "targetFront", "target", "target");
        };
        switch (source) {
            case "battler-user-front": return actual("user", "front");
            case "battler-user-back": return actual("user", "back");
            case "battler-user-opp": return actual("user", ui % 2 === 0 ? "front" : "back");
            case "battler-user": return actual("user", "");
            case "battler-target-front": return actual("target", "front");
            case "battler-target-back": return actual("target", "back");
            case "battler-target-opp": return actual("target", ti % 2 === 0 ? "front" : "back");
            case "battler-target": return actual("target", "");
            default: return null;
        }
    };
    BattlePreview.prototype.specialBattlerImage = function (source) { var _a; return ((_a = this.specialBattlerBundle(source)) === null || _a === void 0 ? void 0 : _a.image) || null; };
    BattlePreview.prototype.drawScreenEvents = function (width, height) {
        var e_24, _q;
        var _a, _b;
        var c = this.ctx;
        try {
            for (var _r = __values(((_a = this.animation) === null || _a === void 0 ? void 0 : _a.events) || []), _s = _r.next(); !_s.done; _s = _r.next()) {
                var ev = _s.value;
                var type = String(ev.type || "");
                var start = Number(ev.frame || 0), dur = Math.max(1, Number(ev.duration || 1));
                if (this.frame < start || this.frame > start + dur)
                    continue;
                if (type === "screen_black_envelope" || type === "screen_white_envelope") {
                    var local = this.frame - start, fi = Math.max(1, Number(ev.fadeIn || 1)), hold = Math.max(0, Number(ev.hold || 0)), fo = Math.max(1, Number(ev.fadeOut || Math.max(1, dur - fi - hold)));
                    var alpha_1 = 1;
                    if (local < fi)
                        alpha_1 = clamp(local / fi, 0, 1);
                    else if (local > fi + hold)
                        alpha_1 = clamp(1 - (local - fi - hold) / fo, 0, 1);
                    c.save();
                    c.globalAlpha = alpha_1;
                    c.fillStyle = type === "screen_black_envelope" ? "#000" : "#fff";
                    c.fillRect(0, 0, width, height);
                    c.restore();
                    continue;
                }
                if (!["screen_flash", "flash", "darken"].includes(type))
                    continue;
                var t = 1 - (this.frame - start) / dur;
                var col = ev.color || [255, 255, 255, 255];
                if (typeof col === "string") {
                    var pc = parseHexColor(col, false);
                    col = [pc.r, pc.g, pc.b, pc.a];
                }
                else if (col && !Array.isArray(col) && typeof col === "object")
                    col = [col.r || 0, col.g || 0, col.b || 0, col.a == null ? 255 : col.a];
                var alpha = (Number((_b = col[3]) !== null && _b !== void 0 ? _b : 255) / 255) * clamp(t, 0, 1);
                c.save();
                c.globalAlpha = alpha;
                c.fillStyle = "rgb(".concat(Number(col[0] || 0), ",").concat(Number(col[1] || 0), ",").concat(Number(col[2] || 0), ")");
                c.fillRect(0, 0, width, height);
                c.restore();
            }
        }
        catch (e_24_1) {
            e_24 = { error: e_24_1 };
        }
        finally {
            try {
                if (_s && !_s.done && (_q = _r.return))
                    _q.call(_r);
            }
            finally {
                if (e_24)
                    throw e_24.error;
            }
        }
    };
    BattlePreview.prototype.drawPath = function (o, accent) {
        var e_25, _q;
        var _this = this;
        if (!o)
            return;
        var c = this.ctx, ks = sortPositionKeys(o);
        if (!ks.length)
            return;
        c.save();
        c.strokeStyle = "rgba(126,153,255,.62)";
        c.lineWidth = 1.3;
        c.setLineDash([5, 4]);
        c.beginPath();
        ks.forEach(function (k, i) { var p = _this.displayResolvedPoint(o, k.point); i ? c.lineTo(p.x, p.y) : c.moveTo(p.x, p.y); });
        c.stroke();
        c.restore();
        try {
            for (var ks_1 = __values(ks), ks_1_1 = ks_1.next(); !ks_1_1.done; ks_1_1 = ks_1.next()) {
                var k = ks_1_1.value;
                var p = this.displayResolvedPoint(o, k.point), act = Math.round(this.frame) === k.frame, s = act ? 7 : 5;
                c.save();
                c.translate(p.x, p.y);
                c.rotate(Math.PI / 4);
                c.fillStyle = act ? "#fff" : accent;
                c.strokeStyle = "rgba(0,0,0,.75)";
                c.fillRect(-s / 2, -s / 2, s, s);
                c.strokeRect(-s / 2, -s / 2, s, s);
                c.restore();
            }
        }
        catch (e_25_1) {
            e_25 = { error: e_25_1 };
        }
        finally {
            try {
                if (ks_1_1 && !ks_1_1.done && (_q = ks_1.return))
                    _q.call(ks_1);
            }
            finally {
                if (e_25)
                    throw e_25.error;
            }
        }
    };
    BattlePreview.prototype.eventLogical = function (e) {
        if (!this.lastTransform)
            this.resizeCanvas();
        var r = this.canvas.getBoundingClientRect(), _q = this.lastTransform, scale = _q.scale, offsetX = _q.offsetX, offsetY = _q.offsetY;
        return { x: (e.clientX - r.left - offsetX) / scale, y: (e.clientY - r.top - offsetY) / scale };
    };
    // Convert the visible preview point back into battle/world coordinates. The
    // scene is drawn through the BAS camera, while target/user-relative keys are
    // stored before that camera transform. Without this inverse transform, dragging
    // an effect while the camera is focused/zoomed writes huge false offsets (e.g.
    // +400 px from pbs:target) and makes it look impossible to place over a Foe.
    BattlePreview.prototype.scenePointFromLogical = function (p) {
        var cam = this.cameraState(), size = this.logicalSize();
        var cx = Number(size.width || 0) / 2, cy = Number(size.height || 0) / 2;
        var zoom = Math.max(.0001, Number(cam.zoom || 1));
        var dx = (Number(p.x || 0) - cx) / zoom, dy = (Number(p.y || 0) - cy) / zoom;
        var rot = Number(cam.rot || 0), co = Math.cos(rot), si = Math.sin(rot);
        var rx = (dx * co) + (dy * si);
        var ry = (-dx * si) + (dy * co);
        return { x: rx + cx + Number(cam.x || 0), y: ry + cy + Number(cam.y || 0) };
    };
    BattlePreview.prototype.pointerPointForObject = function (obj, p) {
        if (!obj || obj.type === "camera")
            return p;
        // Fixed-screen effects intentionally ignore the battle camera. Every other
        // battler/effect lives in scene space and therefore needs inverse-camera
        // pointer coordinates when selected or dragged.
        if (obj.type !== "battler" && this.clipCoordinateSpace(obj) === "screen")
            return p;
        return this.scenePointFromLogical(p);
    };
    BattlePreview.prototype.hitObject = function (p) {
        for (var i = this.hitShapes.length - 1; i >= 0; i--) {
            var h = this.hitShapes[i];
            if (!h.objectId)
                continue;
            var obj = getAnimatable(this.animation, h.objectId);
            if (obj && obj.locked)
                continue;
            var hp = this.pointerPointForObject(obj, p);
            // Slightly forgiving hit area: visual effects often contain large transparent
            // margins and should still be easy to grab with the mouse.
            if (Math.abs(hp.x - h.x) <= h.w / 2 + 18 && Math.abs(hp.y - h.y) <= h.h / 2 + 18)
                return h;
        }
        // If the selected object is tiny/transparent, keep a grab handle around its
        // logical anchor so manual dragging does not randomly become impossible.
        var selected = getAnimatable(this.animation, this.selectedObjectId);
        if (selected && !selected.locked && selected.type !== "camera") {
            var q = this.displayPosition(selected), sp = this.pointerPointForObject(selected, p);
            if (Math.hypot(sp.x - q.x, sp.y - q.y) <= 32)
                return { objectId: selected.id, x: q.x, y: q.y, w: 64, h: 64, kind: "anchor" };
        }
        return null;
    };
    BattlePreview.prototype.nearestSelectedKey = function (p) {
        var e_26, _q;
        var o = getAnimatable(this.animation, this.selectedObjectId);
        if (!o || o.type === "camera" || o.locked)
            return null;
        var n = null, d = Infinity;
        try {
            for (var _r = __values(sortPositionKeys(o)), _s = _r.next(); !_s.done; _s = _r.next()) {
                var k = _s.value;
                var q = this.displayResolvedPoint(o, k.point), dd = Math.hypot(p.x - q.x, p.y - q.y);
                if (dd < 11 && dd < d) {
                    n = k;
                    d = dd;
                }
            }
        }
        catch (e_26_1) {
            e_26 = { error: e_26_1 };
        }
        finally {
            try {
                if (_s && !_s.done && (_q = _r.return))
                    _q.call(_r);
            }
            finally {
                if (e_26)
                    throw e_26.error;
            }
        }
        return n;
    };
    BattlePreview.prototype.pointerDown = function (e) {
        var _a, _b, _c, _d, _e, _f;
        if (!this.animation || this.playing)
            return;
        var p = this.eventLogical(e), selectedForPointer = getAnimatable(this.animation, this.selectedObjectId), keyPoint = this.pointerPointForObject(selectedForPointer, p), key = this.nearestSelectedKey(keyPoint);
        if (e.button === 0 && selectedForPointer && !selectedForPointer.locked && this.emitterEditMode === "emission" && selectedForPointer.pbs && String(selectedForPointer.pbs.emitter || selectedForPointer.pbs.emitterType || "none").toLowerCase() !== "none") {
            var finGeometry = this.emitterGuideGeometry(selectedForPointer, this.frame);
            if (finGeometry && keyPoint && Math.hypot(keyPoint.x - finGeometry.x, keyPoint.y - finGeometry.y) <= 18) {
                this.editFrame = Math.round(this.frame);
                this.dragging = "emitter-distance";
                this.dragStart = { objectId: selectedForPointer.id, center: finGeometry.center, angle: finGeometry.angle };
                e.preventDefault();
                (_b = (_a = this.canvas).setPointerCapture) === null || _b === void 0 ? void 0 : _b.call(_a, e.pointerId);
                return;
            }
        }
        if (e.button === 0 && key && Number(key.frame || 0) !== Math.round(this.frame)) {
            // Clicking another path key still selects it, but clicking the key at the
            // current frame must be allowed to start a drag instead of swallowing it.
            (_b = (_a = this.callbacks).onSelectKey) === null || _b === void 0 ? void 0 : _b.call(_a, this.selectedObjectId, key.id, key.frame);
            return;
        }
        var hit = this.hitObject(p);
        if (!hit)
            return;
        if (hit.objectId !== this.selectedObjectId)
            (_d = (_c = this.callbacks).onSelectObject) === null || _d === void 0 ? void 0 : _d.call(_c, hit.objectId);
        var o = getAnimatable(this.animation, hit.objectId);
        if (!o || o.locked)
            return;
        var objectPoint = this.pointerPointForObject(o, p);
        if (e.button === 2) {
            this.editFrame = Math.round(this.frame);
            var isEmitter = !!(o.pbs && String(o.pbs.emitter || o.pbs.emitterType || "none").toLowerCase() !== "none");
            if (isEmitter && this.emitterEditMode === "emission") {
                this.dragging = "emitter-angle";
                this.dragStart = { p: objectPoint, center: this.displayPosition(o), objectId: o.id };
            }
            else {
                this.dragging = "rotate";
                var rotateOv = this.contextOverrideForObject(o);
                this.dragStart = { p: objectPoint, rotation: sampleValue(o, "rotation", this.frame, 0) + Number(this.contextOverrideValue(o, "rotation", this.frame, 0) || 0), center: this.displayPosition(o), objectId: o.id };
            }
        }
        else if (e.button === 0) {
            this.dragging = "move";
            this.editFrame = Math.round(this.frame);
            var current = this.displayPosition(o);
            // Preserve the point where the object was grabbed. Pointer coordinates
            // are in the same world/screen space as the object, even under camera
            // pan/zoom/rotation.
            this.dragStart = { objectId: o.id, offsetX: current.x - objectPoint.x, offsetY: current.y - objectPoint.y };
        }
        else
            return;
        e.preventDefault();
        (_f = (_e = this.canvas).setPointerCapture) === null || _f === void 0 ? void 0 : _f.call(_e, e.pointerId);
    };
    BattlePreview.prototype.pointerMove = function (e) {
        var _a, _b, _c, _d;
        if (!this.dragging || !this.animation || !this.dragStart)
            return;
        var o = getAnimatable(this.animation, this.dragStart.objectId);
        if (!o || o.locked)
            return;
        var p = this.eventLogical(e), objectPoint = this.pointerPointForObject(o, p), _q = this.logicalSize(), width = _q.width, height = _q.height;
        if (this.dragging === "move")
            (_b = (_a = this.callbacks).onMove) === null || _b === void 0 ? void 0 : _b.call(_a, { objectId: o.id, frame: this.editFrame, x: clamp(objectPoint.x + Number(this.dragStart.offsetX || 0), 0, width), y: clamp(objectPoint.y + Number(this.dragStart.offsetY || 0), 0, height) });
        else if (this.dragging === "emitter-distance") {
            var dc = this.dragStart.center;
            var distanceAngle = Number(this.dragStart.angle || 0) * Math.PI / 180;
            var dux = Math.cos(distanceAngle), duy = -Math.sin(distanceAngle);
            // Project onto the existing route axis: FIN changes only scalar distance.
            var distance = Math.max(1, (objectPoint.x - dc.x) * dux + (objectPoint.y - dc.y) * duy);
            (_d = (_c = this.callbacks).onEmitterDistance) === null || _d === void 0 ? void 0 : _d.call(_c, o.id, distance);
        }
        else if (this.dragging === "emitter-angle") {
            var ec = this.dragStart.center;
            var angle = Math.atan2(-(objectPoint.y - ec.y), objectPoint.x - ec.x) * 180 / Math.PI;
            while (angle > 180) angle -= 360;
            while (angle <= -180) angle += 360;
            (_d = (_c = this.callbacks).onEmitterAngle) === null || _d === void 0 ? void 0 : _d.call(_c, o.id, angle);
        }
        else {
            var cc = this.dragStart.center, a0 = Math.atan2(this.dragStart.p.y - cc.y, this.dragStart.p.x - cc.x), a1 = Math.atan2(objectPoint.y - cc.y, objectPoint.x - cc.x);
            (_d = (_c = this.callbacks).onRotate) === null || _d === void 0 ? void 0 : _d.call(_c, o.id, this.dragStart.rotation - (a1 - a0) * 180 / Math.PI);
        }
    };
    BattlePreview.prototype.pointerUp = function () {
        var _a, _b;
        if (!this.dragging)
            return;
        this.dragging = null;
        this.dragStart = null;
        (_b = (_a = this.callbacks).onEditEnd) === null || _b === void 0 ? void 0 : _b.call(_a);
    };
    BattlePreview.prototype.wheel = function (e) {
        var _a, _b, _c, _d;
        if (!this.animation || this.playing)
            return;
        var p = this.eventLogical(e), hit = this.hitObject(p);
        if (!hit)
            return;
        var o = getAnimatable(this.animation, hit.objectId);
        if (!o || o.locked)
            return;
        e.preventDefault();
        if (hit.objectId !== this.selectedObjectId)
            (_b = (_a = this.callbacks).onSelectObject) === null || _b === void 0 ? void 0 : _b.call(_a, hit.objectId);
        var isEmitter = !!(o.pbs && String(o.pbs.emitter || o.pbs.emitterType || "none").toLowerCase() !== "none");
        if (isEmitter && this.emitterEditMode === "emission") {
            if (e.shiftKey)
                (_d = (_c = this.callbacks).onEmitterRange) === null || _d === void 0 ? void 0 : _d.call(_c, hit.objectId, e.deltaY < 0 ? 5 : -5);
            else
                (_d = (_c = this.callbacks).onEmitterSpeed) === null || _d === void 0 ? void 0 : _d.call(_c, hit.objectId, e.deltaY < 0 ? 5 : -5);
        }
        else
            (_d = (_c = this.callbacks).onScale) === null || _d === void 0 ? void 0 : _d.call(_c, hit.objectId, e.deltaY < 0 ? 5 : -5);
    };
    return BattlePreview;
}());
export { BattlePreview };
