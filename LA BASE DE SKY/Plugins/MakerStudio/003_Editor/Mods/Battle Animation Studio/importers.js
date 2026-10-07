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
import { createAnimation, createProjectile, getEffectsTrack, getBattlerTrack, setPositionKey, setValueKey, setVisibleKey, sortPositionKeys, sampleValue, uid } from "./model.js";
function splitCsv(line) {
    var out = [];
    var cur = "", q = false, quote = "";
    for (var i = 0; i < String(line || "").length; i++) {
        var c = line[i];
        if ((c === '"' || c === "'") && (!q || quote === c)) {
            q = !q;
            quote = q ? c : "";
            continue;
        }
        if (c === ',' && !q) {
            out.push(cur.trim());
            cur = "";
        }
        else
            cur += c;
    }
    out.push(cur.trim());
    return out;
}
function stripComment(line) {
    var q = false, quote = "";
    for (var i = 0; i < line.length; i++) {
        var c = line[i];
        if ((c === '"' || c === "'") && (!q || quote === c)) {
            q = !q;
            quote = q ? c : "";
        }
        if (c === "#" && !q)
            return line.slice(0, i);
    }
    return line;
}
function bool(v) { return /^(true|1|yes)$/i.test(String(v).trim()); }
function num(v, f) {
    if (f === void 0) {
        f = 0;
    }
    var n = Number(v);
    return Number.isFinite(n) ? n : f;
}
function ease(v) {
    var s = String(v || "").toLowerCase().replace(/[^a-z]/g, "");
    if (s === "none")
        return "linear";
    if (s.includes("linear"))
        return "linear";
    if (s.includes("easein"))
        return "ease_in";
    if (s.includes("easeout"))
        return "ease_out";
    return "ease_both";
}
function ease01(t, m) {
    var x = Math.max(0, Math.min(1, t));
    if (m === "linear")
        return x;
    if (m === "ease_in")
        return x * x;
    if (m === "ease_out")
        return 1 - (1 - x) * (1 - x);
    return x < .5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
}
// -----------------------------------------------------------------------------
// New Animation Editor / PBS
// -----------------------------------------------------------------------------
export function parsePbsFile(text, path) {
    var e_1, _x;
    if (path === void 0) {
        path = "Imported PBS";
    }
    var sections = [];
    var sec = null, particle = null, order = 0;
    try {
        for (var _y = __values(String(text || "").replace(/^\uFEFF/, "").split(/\r?\n/)), _z = _y.next(); !_z.done; _z = _y.next()) {
            var raw = _z.value;
            var line = stripComment(raw).trim();
            if (!line)
                continue;
            var sm = line.match(/^\[\s*(.+?)\s*\]$/);
            if (sm) {
                var bits = splitCsv(sm[1]);
                sec = { type: bits[0] || "Move", move: bits[1] || "UNKNOWN", version: num(bits[2], 0), name: bits[1] || path, props: {}, particles: [], path: path };
                sections.push(sec);
                particle = null;
                continue;
            }
            if (!sec)
                continue;
            var pm = line.match(/^<\s*(.+?)\s*>$/);
            if (pm) {
                particle = { name: pm[1].trim(), props: {}, commands: [] };
                sec.particles.push(particle);
                continue;
            }
            var kv = line.match(/^(\w+)\s*=\s*(.*)$/);
            if (!kv)
                continue;
            var key = kv[1], vals = splitCsv(kv[2]);
            if (particle) {
                if (/^(Set|Move|Play)/.test(key))
                    particle.commands.push({ key: key, vals: vals, order: order++ });
                else
                    particle.props[key] = vals.length === 1 ? vals[0] : vals;
            }
            else
                sec.props[key] = vals.length === 1 ? vals[0] : vals;
        }
    }
    catch (e_1_1) {
        e_1 = { error: e_1_1 };
    }
    finally {
        try {
            if (_z && !_z.done && (_x = _y.return))
                _x.call(_y);
        }
        finally {
            if (e_1)
                throw e_1.error;
        }
    }
    return sections;
}
var PBS_FOCUS = {
    foreground: "foreground", midground: "midground", background: "background",
    user: "user", userposition: "user_position", target: "target", targetposition: "target_position",
    userandtarget: "user_and_target", userpositionandtarget: "user_position_and_target",
    userandtargetposition: "user_and_target_position", userpositionandtargetposition: "user_position_and_target_position",
    usersideforeground: "user_side_foreground", usersidebackground: "user_side_background",
    targetsideforeground: "target_side_foreground", targetsidebackground: "target_side_background"
};
function pbsFocus(v) { return PBS_FOCUS[String(v || "Foreground").replace(/[^A-Za-z]/g, "").toLowerCase()] || "foreground"; }
function cleanPbsGraphic(raw) { var s = String(raw || "").trim(); var bottom = /\[\s*bottom\s*\]\s*$/i.test(s), stripped = s.replace(/\[\s*bottom\s*\]\s*$/i, "").trim(); return { raw: s, path: s, stripped: stripped, bottom: bottom }; }
function commandsFor(p, prop, kind) {
    var e_2, _x;
    if (kind === void 0) {
        kind = "number";
    }
    var out = [];
    try {
        for (var _y = __values(p.commands || []), _z = _y.next(); !_z.done; _z = _y.next()) {
            var c = _z.value;
            if (c.key === "Set".concat(prop)) {
                var value = c.vals[1];
                if (kind === "number")
                    value = num(value);
                else if (kind === "bool")
                    value = bool(value);
                out.push({ frame: num(c.vals[0]), duration: 0, value: value, easing: "linear", order: c.order || 0 });
            }
            else if (c.key === "Move".concat(prop)) {
                var value = c.vals[2];
                if (kind === "number")
                    value = num(value);
                else if (kind === "bool")
                    value = bool(value);
                out.push({ frame: num(c.vals[0]), duration: Math.max(0, num(c.vals[1])), value: value, easing: ease(c.vals[3]), order: c.order || 0 });
            }
        }
    }
    catch (e_2_1) {
        e_2 = { error: e_2_1 };
    }
    finally {
        try {
            if (_z && !_z.done && (_x = _y.return))
                _x.call(_y);
        }
        finally {
            if (e_2)
                throw e_2.error;
        }
    }
    return out.sort(function (a, b) { return a.frame - b.frame || a.order - b.order; });
}
function commandFrames(cmds) {
    var e_3, _x;
    var s = new Set();
    try {
        for (var cmds_1 = __values(cmds), cmds_1_1 = cmds_1.next(); !cmds_1_1.done; cmds_1_1 = cmds_1.next()) {
            var c = cmds_1_1.value;
            s.add(c.frame);
            s.add(c.frame + c.duration);
        }
    }
    catch (e_3_1) {
        e_3 = { error: e_3_1 };
    }
    finally {
        try {
            if (cmds_1_1 && !cmds_1_1.done && (_x = cmds_1.return))
                _x.call(cmds_1);
        }
        finally {
            if (e_3)
                throw e_3.error;
        }
    }
    return __spreadArray([], __read(s), false).sort(function (a, b) { return a - b; });
}
function sampleCommands(cmds, frame, def) {
    var e_4, _x;
    if (def === void 0) {
        def = 0;
    }
    var state = def;
    try {
        for (var cmds_2 = __values(cmds), cmds_2_1 = cmds_2.next(); !cmds_2_1.done; cmds_2_1 = cmds_2.next()) {
            var c = cmds_2_1.value;
            if (frame < c.frame)
                break;
            if (c.duration <= 0) {
                state = c.value;
                continue;
            }
            var end = c.frame + c.duration;
            if (frame < end) {
                var t = ease01((frame - c.frame) / Math.max(.0001, c.duration), c.easing);
                return typeof c.value === "number" ? state + (c.value - state) * t : c.value;
            }
            state = c.value;
        }
    }
    catch (e_4_1) {
        e_4 = { error: e_4_1 };
    }
    finally {
        try {
            if (cmds_2_1 && !cmds_2_1.done && (_x = cmds_2.return))
                _x.call(cmds_2);
        }
        finally {
            if (e_4)
                throw e_4.error;
        }
    }
    return state;
}
function easingStartingAt(cmds, frame) { var c = cmds.find(function (x) { return x.frame === frame && x.duration > 0; }); return (c === null || c === void 0 ? void 0 : c.easing) || "linear"; }
function setValueTimeline(obj, prop, cmds, def, transform) {
    var e_5, _x;
    if (def === void 0) {
        def = 0;
    }
    if (transform === void 0) {
        transform = function (x) { return x; };
    }
    try {
        for (var _y = __values(commandFrames(cmds)), _z = _y.next(); !_z.done; _z = _y.next()) {
            var f = _z.value;
            setValueKey(obj, prop, f, transform(sampleCommands(cmds, f, def)), easingStartingAt(cmds, f));
        }
    }
    catch (e_5_1) {
        e_5 = { error: e_5_1 };
    }
    finally {
        try {
            if (_z && !_z.done && (_x = _y.return))
                _x.call(_y);
        }
        finally {
            if (e_5)
                throw e_5.error;
        }
    }
}
function pointForPbsFocus(focus, x, y, p) { return { anchor: "pbs:".concat(focus), x: x, y: y, offsetX: 0, offsetY: 0, foeInvertX: bool(p.props.FoeInvertX), foeInvertY: bool(p.props.FoeInvertY) }; }
function battlerGraphicSource(g) { var v = String(g || "").toUpperCase(); var map = { USER: "battler-user", USER_OPP: "battler-user-opp", USER_FRONT: "battler-user-front", USER_BACK: "battler-user-back", TARGET: "battler-target", TARGET_OPP: "battler-target-opp", TARGET_FRONT: "battler-target-front", TARGET_BACK: "battler-target-back" }; return map[v] || ""; }
function maxCommandFrame(p) {
    var e_6, _x;
    var _a, _b;
    var m = 0;
    try {
        for (var _y = __values(p.commands || []), _z = _y.next(); !_z.done; _z = _y.next()) {
            var c = _z.value;
            var f = num((_a = c.vals) === null || _a === void 0 ? void 0 : _a[0]), d = /^Move/.test(c.key) ? num((_b = c.vals) === null || _b === void 0 ? void 0 : _b[1]) : 0;
            m = Math.max(m, f + d);
        }
    }
    catch (e_6_1) {
        e_6 = { error: e_6_1 };
    }
    finally {
        try {
            if (_z && !_z.done && (_x = _y.return))
                _x.call(_y);
        }
        finally {
            if (e_6)
                throw e_6.error;
        }
    }
    return m;
}
export function animationFromPbsSection(section, sourcePath) {
    var e_7, _x, e_8, _y, e_9, _z;
    if (sourcePath === void 0) {
        sourcePath = "";
    }
    var _a;
    var _b, _c;
    var a = createAnimation(section.props.Name || section.move || "PBS Animation");
    a.tracks[0].clips = [];
    var importedOpposing = /opp|foe/i.test(String(section.type || ""));
    a.source = { type: "pbs", system: "pbs", path: sourcePath, move: section.move, version: section.version, native: true, catalogType: /common/i.test(String(section.type || "")) ? "common" : "move", opposing: importedOpposing, sideContext: importedOpposing ? "foe" : "player" };
    a.fps = num(section.props.FPS, 20) || 20;
    a.events = [];
    a.noUser = bool(section.props.NoUser);
    a.noTarget = bool(section.props.NoTarget);
    a.hidesDataBoxes = bool(section.props.HidesDataBoxes);
    a.credit = String(section.props.Credit || "");
    var maxFrame = 1;
    var _loop_1 = function (p) {
        var e_10, _6, e_11, _7, e_12, _8, e_13, _9, e_14, _10, e_15, _11, e_16, _12;
        maxFrame = Math.max(maxFrame, maxCommandFrame(p));
        if (p.name === "SE") {
            try {
                for (var _13 = (e_10 = void 0, __values(p.commands || [])), _14 = _13.next(); !_14.done; _14 = _13.next()) {
                    var c = _14.value;
                    if (c.key === "Play") {
                        a.events.push({ type: "se", frame: num(c.vals[0]), name: String(c.vals[1] || ""), volume: num(c.vals[2], 100), pitch: num(c.vals[3], 100) });
                    }
                    else if (c.key === "PlayUserCry")
                        a.events.push({ type: "user_cry", frame: num(c.vals[0]) });
                    else if (c.key === "PlayTargetCry")
                        a.events.push({ type: "target_cry", frame: num(c.vals[0]) });
                }
            }
            catch (e_10_1) {
                e_10 = { error: e_10_1 };
            }
            finally {
                try {
                    if (_14 && !_14.done && (_6 = _13.return))
                        _6.call(_13);
                }
                finally {
                    if (e_10)
                        throw e_10.error;
                }
            }
            return "continue";
        }
        if (p.props.Flash) {
            var vals = Array.isArray(p.props.Flash) ? p.props.Flash : splitCsv(String(p.props.Flash));
            var raw_1 = String(vals[2] || "FFFFFFFF").replace(/^#/, "").padEnd(8, "F").slice(0, 8);
            var color = [0, 2, 4, 6].map(function (i) { return parseInt(raw_1.slice(i, i + 2), 16); });
            a.events.push({ type: "screen_flash", frame: num(vals[0]), duration: Math.max(1, num(vals[1], 1)), color: color.map(function (v) { return Number.isFinite(v) ? v : 255; }) });
        }
        try {
            for (var _15 = (e_11 = void 0, __values(p.commands || [])), _16 = _15.next(); !_16.done; _16 = _15.next()) {
                var c = _16.value;
                if (c.key === "MoveScreenShake")
                    a.events.push({ type: "screen_shake", frame: num(c.vals[0]), duration: Math.max(1, num(c.vals[1], 1)), strength: num(c.vals[2], 8), axis: num(c.vals[3], 0) });
            }
        }
        catch (e_11_1) {
            e_11 = { error: e_11_1 };
        }
        finally {
            try {
                if (_16 && !_16.done && (_7 = _15.return))
                    _7.call(_15);
            }
            finally {
                if (e_11)
                    throw e_11.error;
            }
        }
        var graphicInfo = cleanPbsGraphic(p.props.Graphic || (p.name === "User" ? "USER" : p.name === "Target" ? "TARGET" : ""));
        var isUser = p.name === "User", isTarget = p.name === "Target";
        var obj = isUser ? getBattlerTrack(a, "user") : isTarget ? getBattlerTrack(a, "target") : createProjectile({ id: uid("clip"), name: p.name, type: "pbs-particle" });
        obj.positionKeys = [];
        obj.visibleKeys = [];
        obj.imported = { format: "pbs", focus: pbsFocus(p.props.Focus || (isUser ? "User" : isTarget ? "Target" : "Foreground")), rawProps: Object.assign({}, p.props), pbsBattlerParticle: (isUser || isTarget), graphic: graphicInfo.path };
        obj.pbs = { focus: obj.imported.focus, foeInvertX: bool(p.props.FoeInvertX), foeInvertY: bool(p.props.FoeInvertY), foeFlip: bool(p.props.FoeFlip), tiled: bool(p.props.TiledGraphic), angleOverride: String(p.props.AngleOverride || "None"), secondLayer: bool(p.props.SecondLayer), maskGraphic: String(p.props.MaskGraphic || ""), emitter: String(p.props.Emitter || "None"), emitterRate: num(p.props.EmitterRate, 1), emitterIntensity: num(p.props.EmitterIntensity, 1), randomFrameMax: num(p.props.RandomFrameMax, 0), randomAngleRange: num(p.props.RandomAngleRange, 0), randomInvertAngle: bool(p.props.RandomInvertAngle), randomInvertFlip: bool(p.props.RandomInvertFlip), commands: {}, emitterCommands: {} };
        // Preserve every advanced PBS command. The preview understands mask, second-layer
        // and emitter command families, while unknown commands remain round-trippable.
        var camel = function (x) { return String(x || "").replace(/^./, function (m) { return m.toLowerCase(); }); };
        try {
            for (var _17 = (e_12 = void 0, __values(p.commands || [])), _18 = _17.next(); !_18.done; _18 = _17.next()) {
                var c = _18.value;
                var mm = c.key.match(/^(Set|Move)(.+)$/);
                if (!mm)
                    continue;
                var moving = mm[1] === "Move", prop = camel(mm[2]), frame = num(c.vals[0]), duration = moving ? Math.max(0, num(c.vals[1])) : 0, vi = moving ? 2 : 1;
                var value = c.vals[vi];
                if (/Visible|Flip|Invert|Emitting|Clockwise/i.test(mm[2]))
                    value = bool(value);
                else if (!/Color|Tone/i.test(mm[2]))
                    value = num(value);
                var cmd = { id: uid("pcmd"), frame: frame, duration: duration, value: value, easing: moving ? ease(c.vals[vi + 1]) : "linear" };
                // PBS has two timing domains for emitter particles: emitter controls
                // (global animation time) and spawned-particle controls (relative to each
                // emission). Keep that distinction instead of treating similarly named
                // Radius/Zoom commands as the same thing.
                var emitterSuffixMap = {
                    Emitting: "emitting",
                    EmitX: "emitX", EmitXRange: "emitXRange",
                    SpawnX: "emitX", SpawnXRange: "emitXRange",
                    EmitY: "emitY", EmitYRange: "emitYRange",
                    SpawnY: "emitY", SpawnYRange: "emitYRange",
                    EmitR: "emitR", EmitRRange: "emitRRange",
                    SpawnR: "emitR", SpawnRRange: "emitRRange",
                    EmitTheta: "emitTheta", EmitThetaRange: "emitThetaRange",
                    SpawnTheta: "emitTheta", SpawnThetaRange: "emitThetaRange",
                    EmitSpeed: "emitSpeed", EmitSpeedRange: "emitSpeedRange",
                    EmitAngle: "emitAngle", EmitAngleRange: "emitAngleRange",
                    EmitDirection: "emitAngle", EmitDirectionRange: "emitAngleRange",
                    EmitGravity: "emitGravity", EmitGravityRange: "emitGravityRange",
                    EmitDeceleration: "emitDeceleration", EmitDecelerationRange: "emitDecelerationRange",
                    PeriodX: "emitPeriodX", PeriodXRange: "emitPeriodXRange",
                    EmitPeriodX: "emitPeriodX", EmitPeriodXRange: "emitPeriodXRange",
                    PeriodY: "emitPeriodY", PeriodYRange: "emitPeriodYRange",
                    EmitPeriodY: "emitPeriodY", EmitPeriodYRange: "emitPeriodYRange",
                    PeriodZ: "emitPeriodZ", PeriodZRange: "emitPeriodZRange",
                    EmitPeriodZ: "emitPeriodZ", EmitPeriodZRange: "emitPeriodZRange",
                    RadiusXRange: "emitRadiusXRange", RadiusYRange: "emitRadiusYRange", RadiusZRange: "emitRadiusZRange",
                    EmitRadiusXRange: "emitRadiusXRange", EmitRadiusYRange: "emitRadiusYRange", EmitRadiusZRange: "emitRadiusZRange",
                    Clockwise: "emitClockwise",
                    EmitClockwise: "emitClockwise",
                    ZoomRange: "particleSizeRange", ZoomXRange: "emitZoomXRange", ZoomYRange: "emitZoomYRange",
                    EmitZoomRange: "particleSizeRange", EmitZoomXRange: "emitZoomXRange", EmitZoomYRange: "emitZoomYRange",
                    EmitZoomMultiplier: "particleSize",
                    EmitXMultiplier: "emitXMultiplier", EmitYMultiplier: "emitYMultiplier",
                    EmitOpacityMultiplier: "emitOpacityMultiplier",
                    ParticleSize: "particleSize", ParticleSizeRange: "particleSizeRange"
                };
                var emitterKey = emitterSuffixMap[mm[2]];
                if (emitterKey) {
                    cmd.id = uid("ecmd");
                    (_b = obj.pbs.emitterCommands)[emitterKey] || (_b[emitterKey] = []);
                    obj.pbs.emitterCommands[emitterKey].push(cmd);
                }
                else {
                    (_c = obj.pbs.commands)[prop] || (_c[prop] = []);
                    obj.pbs.commands[prop].push(cmd);
                }
            }
        }
        catch (e_12_1) {
            e_12 = { error: e_12_1 };
        }
        finally {
            try {
                if (_18 && !_18.done && (_8 = _17.return))
                    _8.call(_17);
            }
            finally {
                if (e_12)
                    throw e_12.error;
            }
        }
        try {
            for (var _19 = (e_13 = void 0, __values([obj.pbs.commands, obj.pbs.emitterCommands])), _20 = _19.next(); !_20.done; _20 = _19.next()) {
                var map = _20.value;
                try {
                    for (var _21 = (e_14 = void 0, __values(Object.values(map))), _22 = _21.next(); !_22.done; _22 = _21.next()) {
                        var arr = _22.value;
                        arr.sort(function (a, b) { return a.frame - b.frame; });
                    }
                }
                catch (e_14_1) {
                    e_14 = { error: e_14_1 };
                }
                finally {
                    try {
                        if (_22 && !_22.done && (_10 = _21.return))
                            _10.call(_21);
                    }
                    finally {
                        if (e_14)
                            throw e_14.error;
                    }
                }
            }
        }
        catch (e_13_1) {
            e_13 = { error: e_13_1 };
        }
        finally {
            try {
                if (_20 && !_20.done && (_9 = _19.return))
                    _9.call(_19);
            }
            finally {
                if (e_13)
                    throw e_13.error;
            }
        }
        if (!isUser && !isTarget) {
            var special = battlerGraphicSource(graphicInfo.path);
            obj.graphic.source = special || "new";
            obj.graphic.relativeHint = graphicInfo.path;
            obj.graphic.rawName = graphicInfo.raw;
            obj.graphic.assetCandidates = [graphicInfo.path, graphicInfo.stripped].filter(Boolean);
            obj.graphic.name = (graphicInfo.path.split("/").pop() || graphicInfo.path);
            obj.graphic.folder = "Battle animations";
            obj.graphic.projectPath = "";
            obj.graphic.spritesheet = "auto";
            obj.graphic.origin = graphicInfo.bottom ? "bottom" : "auto";
            obj.graphic.specialBattler = graphicInfo.path;
            obj.graphic.maskGraphic = obj.pbs.maskGraphic;
            getEffectsTrack(a).clips.push(obj);
        }
        var xcmd = commandsFor(p, "X"), ycmd = commandsFor(p, "Y");
        var frames = __spreadArray([], __read(new Set(__spreadArray(__spreadArray([], __read(commandFrames(xcmd)), false), __read(commandFrames(ycmd)), false))), false).sort(function (x, y) { return x - y; });
        if (!frames.length)
            frames = [0];
        var focus = obj.imported.focus;
        try {
            for (var frames_1 = (e_15 = void 0, __values(frames)), frames_1_1 = frames_1.next(); !frames_1_1.done; frames_1_1 = frames_1.next()) {
                var f = frames_1_1.value;
                var x = sampleCommands(xcmd, f, 0), y = sampleCommands(ycmd, f, 0);
                var pt = void 0;
                if (isUser)
                    pt = { anchor: "user_battler", x: 0, y: 0, offsetX: x, offsetY: y };
                else if (isTarget)
                    pt = { anchor: "target_battler", x: 0, y: 0, offsetX: x, offsetY: y };
                else
                    pt = pointForPbsFocus(focus, x, y, p);
                setPositionKey(obj, f, pt, easingStartingAt(xcmd, f) !== "linear" ? easingStartingAt(xcmd, f) : easingStartingAt(ycmd, f), pt.anchor);
            }
        }
        catch (e_15_1) {
            e_15 = { error: e_15_1 };
        }
        finally {
            try {
                if (frames_1_1 && !frames_1_1.done && (_11 = frames_1.return))
                    _11.call(frames_1);
            }
            finally {
                if (e_15)
                    throw e_15.error;
            }
        }
        obj.fxOps = (p.commands || []).filter(function (c) { return /^(Set|Move)(Tone|Color)$/.test(c.key); }).map(function (c) { return ({ name: c.key, args: c.vals }); });
        var zx = commandsFor(p, "ZoomX"), zy = commandsFor(p, "ZoomY"), ang = commandsFor(p, "Angle"), opa = commandsFor(p, "Opacity"), z = commandsFor(p, "Z"), blend = commandsFor(p, "Blending"), flip = commandsFor(p, "Flip", "bool"), inv = commandsFor(p, "InvertColor", "bool"), gf = commandsFor(p, "Frame");
        setValueTimeline(obj, "scaleX", zx, 100);
        setValueTimeline(obj, "scaleY", zy, 100);
        setValueTimeline(obj, "rotation", ang, 0);
        setValueTimeline(obj, "opacity", opa, 255, function (x) { return x * 100 / 255; });
        setValueTimeline(obj, "z", z, 0);
        setValueTimeline(obj, "blend", blend, 0);
        setValueTimeline(obj, "flip", flip, false, function (x) { return x ? 1 : 0; });
        setValueTimeline(obj, "invert", inv, false, function (x) { return x ? 1 : 0; });
        setValueTimeline(obj, "graphicFrame", gf, 0);
        var commandTimes = (p.commands || []).map(function (c) { var _a; return num((_a = c.vals) === null || _a === void 0 ? void 0 : _a[0], 0); });
        var firstCommand = commandTimes.length ? Math.min.apply(Math, __spreadArray([], __read(commandTimes), false)) : 0;
        var isEmitter = String(((_a = obj.pbs) === null || _a === void 0 ? void 0 : _a.emitter) || "None").toLowerCase() !== "none";
        var emitterCommandSuffixes = new Set(["Emitting", "EmitX", "EmitXRange", "EmitY", "EmitYRange", "EmitSpeed", "EmitSpeedRange", "EmitAngle", "EmitAngleRange", "EmitGravity", "EmitGravityRange", "PeriodX", "PeriodXRange", "PeriodY", "PeriodYRange", "PeriodZ", "PeriodZRange", "RadiusXRange", "RadiusYRange", "RadiusZRange", "Clockwise", "ZoomRange", "ZoomXRange", "ZoomYRange"]);
        var hasParticleProcess = (p.commands || []).some(function (c) { var m = String(c.key || "").match(/^(?:Set|Move)(.+)$/); return m && !emitterCommandSuffixes.has(m[1]); });
        if (isUser || isTarget)
            setVisibleKey(obj, 0, true);
        else if (isEmitter) {
            setVisibleKey(obj, 0, hasParticleProcess);
        }
        else {
            setVisibleKey(obj, 0, false);
            setVisibleKey(obj, firstCommand, true);
        }
        try {
            for (var _23 = (e_16 = void 0, __values(p.commands || [])), _24 = _23.next(); !_24.done; _24 = _23.next()) {
                var c = _24.value;
                if (c.key === "SetVisible")
                    setVisibleKey(obj, num(c.vals[0]), bool(c.vals[1]));
            }
        }
        catch (e_16_1) {
            e_16 = { error: e_16_1 };
        }
        finally {
            try {
                if (_24 && !_24.done && (_12 = _23.return))
                    _12.call(_23);
            }
            finally {
                if (e_16)
                    throw e_16.error;
            }
        }
        obj.startFrame = 0;
        obj.endFrame = Math.max(maxCommandFrame(p), firstCommand, 0);
    };
    try {
        for (var _0 = __values(section.particles), _1 = _0.next(); !_1.done; _1 = _0.next()) {
            var p = _1.value;
            _loop_1(p);
        }
    }
    catch (e_7_1) {
        e_7 = { error: e_7_1 };
    }
    finally {
        try {
            if (_1 && !_1.done && (_x = _0.return))
                _x.call(_0);
        }
        finally {
            if (e_7)
                throw e_7.error;
        }
    }
    try {
        // Emitter particles can remain alive after the last emitter command. Account
        // for their relative particle-process lifetime so the tail isn't truncated.
        for (var _2 = __values(getEffectsTrack(a).clips || []), _3 = _2.next(); !_3.done; _3 = _2.next()) {
            var obj = _3.value;
            var ec = (obj.pbs && obj.pbs.emitterCommands) || {}, pc = (obj.pbs && obj.pbs.commands) || {};
            var ends = function (map) { return Math.max.apply(Math, __spreadArray([0], __read(Object.values(map).flat().map(function (c) { return Number(c.frame || 0) + Number(c.duration || 0); })), false)); };
            var emitEnd = ends(ec), particleLife = ends(pc);
            if (emitEnd > 0 && particleLife > 0)
                maxFrame = Math.max(maxFrame, emitEnd + particleLife);
        }
    }
    catch (e_8_1) {
        e_8 = { error: e_8_1 };
    }
    finally {
        try {
            if (_3 && !_3.done && (_y = _2.return))
                _y.call(_2);
        }
        finally {
            if (e_8)
                throw e_8.error;
        }
    }
    a.duration = Math.max(1, Math.ceil(maxFrame));
    try {
        for (var _4 = __values(getEffectsTrack(a).clips || []), _5 = _4.next(); !_5.done; _5 = _4.next()) {
            var obj = _5.value;
            obj.endFrame = Math.max(Number(obj.endFrame || 0), a.duration);
        }
    }
    catch (e_9_1) {
        e_9 = { error: e_9_1 };
    }
    finally {
        try {
            if (_5 && !_5.done && (_z = _4.return))
                _z.call(_4);
        }
        finally {
            if (e_9)
                throw e_9.error;
        }
    }
    return a;
}
// -----------------------------------------------------------------------------
// Multi-system source diagnostics
// Keeps Ruby VERMEIL and EBDX distinguishable in the normalized library and
// records constructs that a static timeline cannot safely reproduce. This is
// intentionally editor-side only; no second Preview Bridge is installed.
// -----------------------------------------------------------------------------
function codeSourceSystem(text, filename) {
    if (filename === void 0) {
        filename = "";
    }
    var src = String(text || "");
    if (/EliteBattle\.define(?:Move|Common)Animation\s*\(/.test(src) || /Elite Battle DX|EBDX/i.test(String(filename || "")))
        return "ebdx";
    if (/Vermeil|Battle::Scene::Animation::Vermeil|\[VERMEIL\]/i.test(src + " " + String(filename || "")))
        return "vermeil_ruby";
    return "ruby";
}
function codeUnsupportedDiagnostics(text) {
    var src = String(text || ""), out = [];
    var add = function (id, detail) {
        if (!out.some(function (x) { return x.id === id; }))
            out.push({ id: id, detail: detail });
    };
    if (/\byield\b/.test(src))
        add("yield", "depende del flujo real de batalla");
    if (/System\.uptime|Graphics\.frame_count/.test(src))
        add("runtime_clock", "depende del reloj/runtime del juego");
    if (/\b(?:eval|instance_eval|class_eval)\s*\(/.test(src))
        add("dynamic_eval", "ejecución Ruby dinámica");
    if (/\b(?:send|public_send)\s*\(/.test(src))
        add("dynamic_send", "llamada de método dinámica");
    if (/message(?:Box|Window)|pbWaitMessage|pbDisplay/.test(src))
        add("battle_ui", "interactúa con la UI/mensajes reales de batalla");
    if (/\bhitNum\b|@hitNum|hit_num/.test(src))
        add("hit_state", "depende del número/estado real del golpe");
    return out;
}
// -----------------------------------------------------------------------------
// Ruby / BattleAnimations static importer
// -----------------------------------------------------------------------------
export function discoverCodeMetadata(text, filename) {
    var e_17, _x, e_18, _y, e_19, _z, e_20, _0, e_21, _1, e_22, _2, e_23, _3, e_24, _4, e_25, _5, e_26, _6, e_27, _7;
    if (filename === void 0) {
        filename = "";
    }
    var src = String(text || ""), moves = [], common = [], seenMoves = new Set(), seenCommon = new Set();
    var clean = function (id) { return String(id || "").trim().replace(/^:/, ""); };
    var addMove = function (id) {
        id = clean(id).toUpperCase();
        if (id && /^[A-Z][A-Z0-9_]*$/.test(id) && !seenMoves.has(id)) {
            seenMoves.add(id);
            moves.push(id);
        }
    };
    var addCommon = function (id) {
        id = clean(id);
        if (id && /^[A-Za-z][A-Za-z0-9_]*$/.test(id) && !seenCommon.has(id)) {
            seenCommon.add(id);
            common.push(id);
        }
    };
    try {
        for (var _8 = __values(src.matchAll(/EliteBattle\.defineMoveAnimation\s*\(\s*:([A-Z][A-Z0-9_]*)/g)), _9 = _8.next(); !_9.done; _9 = _8.next()) {
            var m = _9.value;
            addMove(m[1]);
        }
    }
    catch (e_17_1) {
        e_17 = { error: e_17_1 };
    }
    finally {
        try {
            if (_9 && !_9.done && (_x = _8.return))
                _x.call(_8);
        }
        finally {
            if (e_17)
                throw e_17.error;
        }
    }
    try {
        for (var _10 = __values(src.matchAll(/EliteBattle\.defineCommonAnimation\s*\(\s*(?::([A-Z][A-Z0-9_]*)|["']([^"']+)["'])/g)), _11 = _10.next(); !_11.done; _11 = _10.next()) {
            var m = _11.value;
            addCommon(m[1] || m[2]);
        }
    }
    catch (e_18_1) {
        e_18 = { error: e_18_1 };
    }
    finally {
        try {
            if (_11 && !_11.done && (_y = _10.return))
                _y.call(_10);
        }
        finally {
            if (e_18)
                throw e_18.error;
        }
    }
    try {
        for (var _12 = __values(src.matchAll(/HANDLED_MOVES\s*=\s*\[([\s\S]*?)\]/g)), _13 = _12.next(); !_13.done; _13 = _12.next()) {
            var m = _13.value;
            try {
                for (var _14 = (e_20 = void 0, __values(m[1].matchAll(/:([A-Z][A-Z0-9_]*)/g))), _15 = _14.next(); !_15.done; _15 = _14.next()) {
                    var x = _15.value;
                    addMove(x[1]);
                }
            }
            catch (e_20_1) {
                e_20 = { error: e_20_1 };
            }
            finally {
                try {
                    if (_15 && !_15.done && (_0 = _14.return))
                        _0.call(_14);
                }
                finally {
                    if (e_20)
                        throw e_20.error;
                }
            }
        }
    }
    catch (e_19_1) {
        e_19 = { error: e_19_1 };
    }
    finally {
        try {
            if (_13 && !_13.done && (_z = _12.return))
                _z.call(_12);
        }
        finally {
            if (e_19)
                throw e_19.error;
        }
    }
    try {
        for (var _16 = __values(src.matchAll(/\b(?:mid|move_id|@move_id)\s*==\s*:([A-Z][A-Z0-9_]*)\b/g)), _17 = _16.next(); !_17.done; _17 = _16.next()) {
            var m = _17.value;
            addMove(m[1]);
        }
    }
    catch (e_21_1) {
        e_21 = { error: e_21_1 };
    }
    finally {
        try {
            if (_17 && !_17.done && (_1 = _16.return))
                _1.call(_16);
        }
        finally {
            if (e_21)
                throw e_21.error;
        }
    }
    var commonFile = /pbCommonAnimation\s*\(|CommonAnimations?/i.test(src) || /common/i.test(String(filename || ""));
    if (commonFile) {
        try {
            for (var _18 = __values(src.matchAll(/\b(?:animName|@anim_name|anim_name)\s*==\s*["']([^"']+)["']/g)), _19 = _18.next(); !_19.done; _19 = _18.next()) {
                var m = _19.value;
                addCommon(m[1]);
            }
        }
        catch (e_22_1) {
            e_22 = { error: e_22_1 };
        }
        finally {
            try {
                if (_19 && !_19.done && (_2 = _18.return))
                    _2.call(_18);
            }
            finally {
                if (e_22)
                    throw e_22.error;
            }
        }
        try {
            for (var _20 = __values(src.matchAll(/(?:custom_anims|common_anims|animations)\s*=\s*\[([\s\S]*?)\]/gi)), _21 = _20.next(); !_21.done; _21 = _20.next()) {
                var block = _21.value;
                try {
                    for (var _22 = (e_24 = void 0, __values(block[1].matchAll(/["']([^"']+)["']/g))), _23 = _22.next(); !_23.done; _23 = _22.next()) {
                        var q = _23.value;
                        addCommon(q[1]);
                    }
                }
                catch (e_24_1) {
                    e_24 = { error: e_24_1 };
                }
                finally {
                    try {
                        if (_23 && !_23.done && (_4 = _22.return))
                            _4.call(_22);
                    }
                    finally {
                        if (e_24)
                            throw e_24.error;
                    }
                }
            }
        }
        catch (e_23_1) {
            e_23 = { error: e_23_1 };
        }
        finally {
            try {
                if (_21 && !_21.done && (_3 = _20.return))
                    _3.call(_20);
            }
            finally {
                if (e_23)
                    throw e_23.error;
            }
        }
        var lines_3 = src.split(/\r?\n/);
        var inAnimCase = false, caseIndent_1 = -1;
        try {
            for (var lines_1 = __values(lines_3), lines_1_1 = lines_1.next(); !lines_1_1.done; lines_1_1 = lines_1.next()) {
                var line = lines_1_1.value;
                var indent = (line.match(/^\s*/) || [""])[0].length, t = line.trim();
                if (!inAnimCase && /^case\s+(?:@anim_name|anim_name|animName)\b/.test(t)) {
                    inAnimCase = true;
                    caseIndent_1 = indent;
                    continue;
                }
                if (inAnimCase && indent === caseIndent_1 && t === "end") {
                    inAnimCase = false;
                    continue;
                }
                if (inAnimCase) {
                    var m = t.match(/^when\s+["']([^"']+)["']/);
                    if (m)
                        addCommon(m[1]);
                }
            }
        }
        catch (e_25_1) {
            e_25 = { error: e_25_1 };
        }
        finally {
            try {
                if (lines_1_1 && !lines_1_1.done && (_5 = lines_1.return))
                    _5.call(lines_1);
            }
            finally {
                if (e_25)
                    throw e_25.error;
            }
        }
    }
    var lines = src.split(/\r?\n/);
    var inMoveCase = false, caseIndent = -1;
    try {
        for (var lines_2 = __values(lines), lines_2_1 = lines_2.next(); !lines_2_1.done; lines_2_1 = lines_2.next()) {
            var line = lines_2_1.value;
            var indent = (line.match(/^\s*/) || [""])[0].length, t = line.trim();
            if (!inMoveCase && /^case\s+(?:@move_id|move_id|mid)\b/.test(t)) {
                inMoveCase = true;
                caseIndent = indent;
                continue;
            }
            if (inMoveCase && indent === caseIndent && t === "end") {
                inMoveCase = false;
                continue;
            }
            if (inMoveCase) {
                var m = t.match(/^when\s+:([A-Z][A-Z0-9_]*)\b/);
                if (m)
                    addMove(m[1]);
            }
        }
    }
    catch (e_26_1) {
        e_26 = { error: e_26_1 };
    }
    finally {
        try {
            if (lines_2_1 && !lines_2_1.done && (_6 = lines_2.return))
                _6.call(lines_2);
        }
        finally {
            if (e_26)
                throw e_26.error;
        }
    }
    var behavior = (src.match(/\bBEHAVIOR\s*=\s*:([a-zA-Z0-9_]+)/) || [])[1] || "cinematic";
    var classes = __spreadArray([], __read(src.matchAll(/^\s*class\s+(?:Battle::Scene::Animation::)?([A-Za-z0-9_:]+)/gm)), false).map(function (m) { return m[1].split("::").pop(); }).filter(Boolean);
    var signatures = __spreadArray([], __read(src.matchAll(/def\s+initialize\s*\(([^\n)]*)\)/g)), false).map(function (m) { return m[1].split(",").map(function (x) { return x.trim(); }).filter(Boolean); });
    var classText = classes.join(" ");
    if (behavior === "cinematic" && /MultiHit/i.test(classText))
        behavior = "multihit";
    if (behavior === "cinematic" && /(ToxicSpikesCast|SpikesCast|StealthRockCast|StickyWebCast)/i.test(classText))
        behavior = "hazard";
    if (behavior === "cinematic" && /(SelfTarget|Shield)/i.test(classText))
        behavior = "self_targeting";
    if (!moves.length && !common.length) {
        var candidates = __spreadArray(__spreadArray([], __read(classes), false), [String(filename || "").replace(/\.rb$/i, "")], false);
        try {
            for (var candidates_1 = __values(candidates), candidates_1_1 = candidates_1.next(); !candidates_1_1.done; candidates_1_1 = candidates_1.next()) {
                var raw = candidates_1_1.value;
                var x = String(raw).replace(/^Vermeil(?:Cinematic)?/i, "").replace(/Animation$/i, "").replace(/[^A-Za-z0-9]+/g, "");
                if (x && x.length > 2 && !/^(Common|MultiHit|Priority|Heavy|Ethereal|Elemental|Grass|Battle)$/i.test(x))
                    addMove(x.toUpperCase());
            }
        }
        catch (e_27_1) {
            e_27 = { error: e_27_1 };
        }
        finally {
            try {
                if (candidates_1_1 && !candidates_1_1.done && (_7 = candidates_1.return))
                    _7.call(candidates_1);
            }
            finally {
                if (e_27)
                    throw e_27.error;
            }
        }
    }
    return { moves: moves, common: common, behavior: String(behavior).toLowerCase(), classes: classes, signatures: signatures, hasHandledMoves: /HANDLED_MOVES\s*=/.test(src), hasCallbacks: /setCallback\s*\(/.test(src), hasRandom: /\brand\s*\(/.test(src) };
}
export function discoverCodeVariants(text, filename) {
    if (filename === void 0) {
        filename = "";
    }
    return discoverCodeMetadata(text, filename).moves;
}
// Parses the optional Cinematic Engine Controller dictionary so older animation
// classes can still be associated with every move they handle.
export function discoverCinematicControllerMappings(text) {
    var e_28, _x, e_29, _y;
    var src = String(text || ""), byClass = new Map(), behaviorByClass = new Map();
    try {
        for (var _z = __values(src.matchAll(/:([A-Z][A-Z0-9_]*)\s*=>\s*["']([A-Za-z0-9_:]+)["']/g)), _0 = _z.next(); !_0.done; _0 = _z.next()) {
            var m = _0.value;
            var move = m[1], cls = m[2].split("::").pop();
            if (!byClass.has(cls))
                byClass.set(cls, []);
            if (!byClass.get(cls).includes(move))
                byClass.get(cls).push(move);
        }
    }
    catch (e_28_1) {
        e_28 = { error: e_28_1 };
    }
    finally {
        try {
            if (_0 && !_0.done && (_x = _z.return))
                _x.call(_z);
        }
        finally {
            if (e_28)
                throw e_28.error;
        }
    }
    var behBlock = (src.match(/def\s+self\.get_behavior[\s\S]*?map\s*=\s*\{([\s\S]*?)\}\s*\n/) || [])[1] || "";
    try {
        for (var _1 = __values(behBlock.matchAll(/["']([A-Za-z0-9_:]+)["']\s*=>\s*:([a-zA-Z0-9_]+)/g)), _2 = _1.next(); !_2.done; _2 = _1.next()) {
            var m = _2.value;
            behaviorByClass.set(m[1].split("::").pop(), m[2].toLowerCase());
        }
    }
    catch (e_29_1) {
        e_29 = { error: e_29_1 };
    }
    finally {
        try {
            if (_2 && !_2.done && (_y = _1.return))
                _y.call(_1);
        }
        finally {
            if (e_29)
                throw e_29.error;
        }
    }
    return { byClass: byClass, behaviorByClass: behaviorByClass };
}
function selectedCodeBranch(text, moveId) {
    var e_30, _x, e_31, _y;
    if (!moveId)
        return String(text || "");
    var src = String(text || ""), wanted = String(moveId);
    var marker = new RegExp("EliteBattle\\.define(?:Move|Common)Animation\\s*\\(\\s*(?::|[\"'])" + String(moveId).replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b", "i");
    var m0 = src.match(marker);
    if (m0) {
        var start = m0.index || 0;
        var chunk = src.slice(start);
        var lines0 = chunk.split(/\r?\n/);
        var out0 = [];
        var depth = 0, began = false;
        try {
            for (var lines0_1 = __values(lines0), lines0_1_1 = lines0_1.next(); !lines0_1_1.done; lines0_1_1 = lines0_1.next()) {
                var line = lines0_1_1.value;
                out0.push(line);
                var t = line.trim();
                if (/\bdo\b|\{\s*$/.test(t)) {
                    depth++;
                    began = true;
                }
                if (/^(?:for|if|unless|case|while|until|begin)\b/.test(t))
                    depth++;
                if (t === "end") {
                    depth--;
                    if (began && depth <= 0)
                        break;
                }
            }
        }
        catch (e_30_1) {
            e_30 = { error: e_30_1 };
        }
        finally {
            try {
                if (lines0_1_1 && !lines0_1_1.done && (_x = lines0_1.return))
                    _x.call(lines0_1);
            }
            finally {
                if (e_30)
                    throw e_30.error;
            }
        }
        return out0.join("\n");
    }
    var lines = src.split(/\r?\n/), out = [];
    var inCase = false, caseIndent = -1, branchIndent = -1, keep = true, kind = "move";
    var matchesCase = function (trim) {
        if (kind === "move") {
            var m_1 = trim.match(/^when\s+:([A-Z][A-Z0-9_]*)\b/);
            return !!m_1 && m_1[1] === wanted.toUpperCase();
        }
        var m = trim.match(/^when\s+["']([^"']+)["']/);
        return !!m && m[1] === wanted;
    };
    try {
        for (var lines_4 = __values(lines), lines_4_1 = lines_4.next(); !lines_4_1.done; lines_4_1 = lines_4.next()) {
            var line = lines_4_1.value;
            var indent = (line.match(/^\s*/) || [""])[0].length, trim = line.trim();
            if (!inCase && /^case\s+(?:@move_id|move_id|mid)\b/.test(trim)) {
                inCase = true;
                caseIndent = indent;
                branchIndent = indent;
                keep = true;
                kind = "move";
                out.push(line);
                continue;
            }
            if (!inCase && /^case\s+(?:@anim_name|anim_name|animName)\b/.test(trim)) {
                inCase = true;
                caseIndent = indent;
                branchIndent = indent;
                keep = true;
                kind = "common";
                out.push(line);
                continue;
            }
            if (inCase && indent === branchIndent && /^when\b/.test(trim)) {
                keep = matchesCase(trim);
                if (keep)
                    out.push(line);
                continue;
            }
            if (inCase && indent === caseIndent && trim === "end") {
                inCase = false;
                keep = true;
                kind = "move";
                out.push(line);
                continue;
            }
            if (!inCase || keep)
                out.push(line);
        }
    }
    catch (e_31_1) {
        e_31 = { error: e_31_1 };
    }
    finally {
        try {
            if (lines_4_1 && !lines_4_1.done && (_y = lines_4.return))
                _y.call(lines_4);
        }
        finally {
            if (e_31)
                throw e_31.error;
        }
    }
    return out.join("\n");
}
function expandForLoops(text) {
    var e_32, _x, e_33, _y;
    var lines = String(text || "").split(/\r?\n/), passes = 0;
    var scalar = {};
    try {
        for (var lines_5 = __values(lines), lines_5_1 = lines_5.next(); !lines_5_1.done; lines_5_1 = lines_5.next()) {
            var line = lines_5_1.value;
            var m = line.match(/^\s*([a-z_]\w*)\s*=\s*(-?\d+(?:\.\d+)?)\s*$/i);
            if (m) {
                scalar[m[1]] = Number(m[2]);
                continue;
            }
            m = line.match(/^\s*([a-z_]\w*)\s*=\s*.+?\?\s*(-?\d+(?:\.\d+)?)\s*:\s*(-?\d+(?:\.\d+)?)\s*$/i);
            if (m)
                scalar[m[1]] = Math.max(Number(m[2]), Number(m[3]));
        }
    }
    catch (e_32_1) {
        e_32 = { error: e_32_1 };
    }
    finally {
        try {
            if (lines_5_1 && !lines_5_1.done && (_x = lines_5.return))
                _x.call(lines_5);
        }
        finally {
            if (e_32)
                throw e_32.error;
        }
    }
    var bound = function (raw) { return /^-?\d+(?:\.\d+)?$/.test(String(raw)) ? Number(raw) : scalar[String(raw)]; };
    while (passes++ < 8) {
        var changed = false, out = [];
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^(\s*)for\s+([a-z_]\w*)\s+in\s+(-?\d+(?:\.\d+)?|[a-z_]\w*)\s*(\.\.\.|\.\.)\s*(-?\d+(?:\.\d+)?|[a-z_]\w*)\s*$/i);
            if (!m) {
                out.push(lines[i]);
                continue;
            }
            var indent = m[1].length, v = m[2], from = bound(m[3]), excl = m[4] === "...", toRaw = bound(m[5]);
            if (!Number.isFinite(from) || !Number.isFinite(toRaw)) {
                out.push(lines[i]);
                continue;
            }
            var to = excl ? toRaw - 1 : toRaw;
            var j = i + 1, end = -1, depth = 0;
            for (; j < lines.length; j++) {
                var t = lines[j].trim(), ind = (lines[j].match(/^\s*/) || [""])[0].length;
                if (ind === indent && t === "end" && depth === 0) {
                    end = j;
                    break;
                }
                if ((/^(?:for|case|if|unless|while|until|begin)\b/.test(t) || /\bdo\s*(?:\||$)/.test(t)) && ind >= indent)
                    depth++;
                if (t === "end" && depth > 0)
                    depth--;
            }
            if (end < 0) {
                out.push(lines[i]);
                continue;
            }
            var body = lines.slice(i + 1, end), step = from <= to ? 1 : -1;
            var n = from, guard = 0;
            while ((step > 0 ? n <= to : n >= to) && guard++ < 220) {
                try {
                    for (var body_1 = (e_33 = void 0, __values(body)), body_1_1 = body_1.next(); !body_1_1.done; body_1_1 = body_1.next()) {
                        var bl = body_1_1.value;
                        var expanded = bl.replace(new RegExp("\\b".concat(v, "\\b"), 'g'), String(n));
                        expanded = expanded.replace(/#\{\s*(-?\d+(?:\.\d+)?)\s*\}/g, "$1");
                        out.push(expanded);
                    }
                }
                catch (e_33_1) {
                    e_33 = { error: e_33_1 };
                }
                finally {
                    try {
                        if (body_1_1 && !body_1_1.done && (_y = body_1.return))
                            _y.call(body_1);
                    }
                    finally {
                        if (e_33)
                            throw e_33.error;
                    }
                }
                n += step;
            }
            i = end;
            changed = true;
        }
        lines = out;
        if (!changed)
            break;
    }
    return lines.join("\n");
}
function expandSimpleTimes(text) {
    var e_34, _x;
    text = String(text || "").replace(/^(\s*)(\d+)\.times\s*\{\s*\|\s*([a-z_]\w*)\s*\|\s*(.*?)\s*\}\s*$/gmi, function (_, ind, count, v, body) { return Array.from({ length: Math.min(80, Number(count)) }, function (__, i) { return ind + body.replace(new RegExp("\\b".concat(v, "\\b"), 'g'), String(i)); }).join("\n"); });
    var lines = String(text || "").split(/\r?\n/), passes = 0;
    while (passes++ < 5) {
        var changed = false, out = [];
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^(\s*)(\d+)\.times\s+do\s*\|\s*([a-z_]\w*)\s*\|\s*$/i);
            if (!m) {
                out.push(lines[i]);
                continue;
            }
            var indent = m[1].length, count = Math.min(80, Number(m[2])), v = m[3];
            var j = i + 1, depth = 0, end = -1;
            for (; j < lines.length; j++) {
                var t = lines[j].trim(), ind = (lines[j].match(/^\s*/) || [""])[0].length;
                if (ind === indent && t === "end" && depth === 0) {
                    end = j;
                    break;
                }
                if ((/^(?:case|if|unless|begin)\b/.test(t) || /\bdo\s*(?:\||$)/.test(t)) && ind >= indent)
                    depth++;
                if (t === "end" && depth > 0)
                    depth--;
            }
            if (end < 0) {
                out.push(lines[i]);
                continue;
            }
            var body = lines.slice(i + 1, end);
            for (var n = 0; n < count; n++)
                try {
                    for (var body_2 = (e_34 = void 0, __values(body)), body_2_1 = body_2.next(); !body_2_1.done; body_2_1 = body_2.next()) {
                        var bl = body_2_1.value;
                        out.push(bl.replace(new RegExp("\\b".concat(v, "\\b"), 'g'), String(n)));
                    }
                }
                catch (e_34_1) {
                    e_34 = { error: e_34_1 };
                }
                finally {
                    try {
                        if (body_2_1 && !body_2_1.done && (_x = body_2.return))
                            _x.call(body_2);
                    }
                    finally {
                        if (e_34)
                            throw e_34.error;
                    }
                }
            i = end;
            changed = true;
        }
        lines = out;
        if (!changed)
            break;
    }
    return lines.join("\n");
}
function parseLiteralArrays(text) {
    var arrays = {};
    var src = String(text || "");
    var re = /^\s*([a-z_]\w*)\s*=\s*\[/gmi;
    var m;
    while ((m = re.exec(src))) {
        var i = m.index + m[0].length - 1, depth = 0, q = false, quote = "", end = -1;
        for (; i < src.length; i++) {
            var c = src[i], prev = src[i - 1];
            if ((c === '"' || c === "'") && prev !== "\\" && (!q || quote === c)) {
                q = !q;
                quote = q ? c : "";
            }
            if (q)
                continue;
            if (c === '[')
                depth++;
            else if (c === ']') {
                depth--;
                if (depth === 0) {
                    end = i;
                    break;
                }
            }
        }
        if (end < 0)
            continue;
        var body = src.slice(m.index + m[0].lastIndexOf('['), end + 1);
        try {
            if (!/[^0-9+\-.\[\],\s]/.test(body)) {
                var val = Function("\"use strict\";return (".concat(body, ")"))();
                if (Array.isArray(val))
                    arrays[m[1]] = val;
            }
        }
        catch (_a) { }
        re.lastIndex = end + 1;
    }
    return arrays;
}
function expandArrayLoops(text) {
    var arrays = parseLiteralArrays(text);
    var lines = String(text || "").split(/\r?\n/), passes = 0;
    var literal = function (v) { return Array.isArray(v) ? "[".concat(v.join(","), "]") : String(v); };
    var _loop_2 = function () {
        var changed = false, out = [];
        var _loop_3 = function (i) {
            var m = lines[i].match(/^(\s*)([a-z_]\w*)\.each(?:_with_index)?\s+do\s*\|\s*(?:\(([^\)]+)\)|([a-z_]\w*))(?:\s*,\s*([a-z_]\w*))?\s*\|\s*$/i);
            if (!m || !arrays[m[2]]) {
                out.push(lines[i]);
                return out_i_1 = i, "continue";
            }
            var indent = m[1].length, arr = arrays[m[2]], tupleItems = m[3] ? m[3].split(',').map(function (x) { return x.trim(); }).filter(Boolean) : null, item = m[4] || (tupleItems ? null : m[3]), idx = m[5] || null;
            var j = i + 1, depth = 0, end = -1;
            for (; j < lines.length; j++) {
                var t = lines[j].trim(), ind = (lines[j].match(/^\s*/) || [""])[0].length;
                if (ind === indent && t === "end" && depth === 0) {
                    end = j;
                    break;
                }
                if ((/^(?:case|if|unless|begin)\b/.test(t) || /\bdo\s*(?:\||$)/.test(t)) && ind >= indent)
                    depth++;
                if (t === "end" && depth > 0)
                    depth--;
            }
            if (end < 0) {
                out.push(lines[i]);
                return out_i_1 = i, "continue";
            }
            var body = lines.slice(i + 1, end);
            arr.slice(0, 96).forEach(function (value, n) {
                var e_35, _x;
                var _loop_4 = function (bl) {
                    if (Array.isArray(value)) {
                        if (tupleItems) {
                            tupleItems.forEach(function (name, k) { bl = bl.replace(new RegExp("\\b".concat(name, "\\b"), 'g'), String(value[k] != null ? value[k] : 0)); });
                        }
                        else if (item) {
                            value.forEach(function (vv, k) { bl = bl.replace(new RegExp("\\b".concat(item, "\\s*\\[\\s*").concat(k, "\\s*\\]"), 'g'), String(vv)); });
                            bl = bl.replace(new RegExp("\\b".concat(item, "\\b"), 'g'), literal(value));
                        }
                    }
                    else if (item)
                        bl = bl.replace(new RegExp("\\b".concat(item, "\\b"), 'g'), String(value));
                    if (idx)
                        bl = bl.replace(new RegExp("\\b".concat(idx, "\\b"), 'g'), String(n));
                    out.push(bl);
                };
                try {
                    for (var body_3 = (e_35 = void 0, __values(body)), body_3_1 = body_3.next(); !body_3_1.done; body_3_1 = body_3.next()) {
                        var bl = body_3_1.value;
                        _loop_4(bl);
                    }
                }
                catch (e_35_1) {
                    e_35 = { error: e_35_1 };
                }
                finally {
                    try {
                        if (body_3_1 && !body_3_1.done && (_x = body_3.return))
                            _x.call(body_3);
                    }
                    finally {
                        if (e_35)
                            throw e_35.error;
                    }
                }
            });
            i = end;
            changed = true;
            out_i_1 = i;
        };
        var out_i_1;
        for (var i = 0; i < lines.length; i++) {
            _loop_3(i);
            i = out_i_1;
        }
        lines = out;
        if (!changed)
            return "break";
    };
    while (passes++ < 8) {
        var state_1 = _loop_2();
        if (state_1 === "break")
            break;
    }
    return lines.join("\n");
}
function safeEval(expr, env) {
    var e_36, _x;
    if (env === void 0) {
        env = {};
    }
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v;
    var s = String(expr || "").trim();
    s = s.replace(/(\d+)\.even\?/g, "($1%2===0)").replace(/(\d+)\.odd\?/g, "($1%2!==0)");
    s = s.replace(/\.to_f|\.to_i/g, "").replace(/\.round\b/g, "").replace(/([\w.()]+)\.floor\b/g, "Math.floor($1)").replace(/([\w.()]+)\.ceil\b/g, "Math.ceil($1)").replace(/([\w.()]+)\.abs\b/g, "Math.abs($1)");
    s = s.replace(/Graphics\.width/g, String((_a = env.width) !== null && _a !== void 0 ? _a : 512)).replace(/Graphics\.height/g, String((_b = env.height) !== null && _b !== void 0 ? _b : 384));
    s = s.replace(/@user\.index/g, String((_c = env.userIndex) !== null && _c !== void 0 ? _c : 0)).replace(/@target\.index/g, String((_d = env.targetIndex) !== null && _d !== void 0 ? _d : 1)).replace(/@hit_num/g, String((_e = env.hitNum) !== null && _e !== void 0 ? _e : 0)).replace(/@anchor_x|\banchor_x\b|\bax\b/g, String((_f = env.anchorX) !== null && _f !== void 0 ? _f : 0)).replace(/@anchor_y|\banchor_y\b|\bay\b/g, String((_g = env.anchorY) !== null && _g !== void 0 ? _g : 0)).replace(/@side_index|\bside_index\b/g, String((_h = env.sideIndex) !== null && _h !== void 0 ? _h : 0));
    s = s.replace(/user_sprite\.x|\bus\.x\b|\borig_ux\b/g, String((_j = env.userX) !== null && _j !== void 0 ? _j : 128)).replace(/user_sprite\.y|\bus\.y\b|\borig_uy\b/g, String((_k = env.userY) !== null && _k !== void 0 ? _k : 326)).replace(/target_sprite\.x|\bts\.x\b|\borig_tx\b/g, String((_l = env.targetX) !== null && _l !== void 0 ? _l : 390)).replace(/target_sprite\.y|\bts\.y\b|\borig_ty\b/g, String((_m = env.targetY) !== null && _m !== void 0 ? _m : 174));
    s = s.replace(/\bu_h\b/g, String(((_o = env.userH) !== null && _o !== void 0 ? _o : 96) / 2)).replace(/\bt_h\b/g, String(((_p = env.targetH) !== null && _p !== void 0 ? _p : 96) / 2)).replace(/\bu_w\b/g, String((_q = env.userW) !== null && _q !== void 0 ? _q : 96)).replace(/\bt_w\b/g, String((_r = env.targetW) !== null && _r !== void 0 ? _r : 96));
    s = s.replace(/(?:user_sprite|us)\.bitmap\.width|\buw\b/g, String((_s = env.userW) !== null && _s !== void 0 ? _s : 96)).replace(/(?:user_sprite|us)\.bitmap\.height|\buh\b/g, String((_t = env.userH) !== null && _t !== void 0 ? _t : 96)).replace(/(?:target_sprite|ts)\.bitmap\.width|\btw\b/g, String((_u = env.targetW) !== null && _u !== void 0 ? _u : 96)).replace(/(?:target_sprite|ts)\.bitmap\.height|\bth\b/g, String((_v = env.targetH) !== null && _v !== void 0 ? _v : 96));
    try {
        for (var _y = __values(Object.entries(env.vars || {})), _z = _y.next(); !_z.done; _z = _y.next()) {
            var _0 = __read(_z.value, 2), k = _0[0], v = _0[1];
            if (typeof v === 'number')
                s = s.replace(new RegExp("\\b".concat(k, "\\b"), "g"), String(v));
        }
    }
    catch (e_36_1) {
        e_36 = { error: e_36_1 };
    }
    finally {
        try {
            if (_z && !_z.done && (_x = _y.return))
                _x.call(_y);
        }
        finally {
            if (e_36)
                throw e_36.error;
        }
    }
    for (var pass = 0; pass < 4; pass++)
        s = s.replace(/\[\s*([^,\[\]]+)\s*,\s*([^\[\]]+)\s*\]\.(min|max)/g, function (_, aa, b, op) { return "Math.".concat(op, "(").concat(aa, ",").concat(b, ")"); });
    s = s.replace(/rand\s*\(\s*([^()]+)\s*\)/g, function (_, n) { var v = Number(n); return Number.isFinite(v) ? String(Math.max(0, Math.floor(v / 2))) : "0"; });
    s = s.replace(/Math::PI/g, "Math.PI").replace(/\btrue\b/g, "1").replace(/\bfalse\b/g, "0");
    if (/[^0-9+\-*/%&|().,\s?:<>=!A-Za-z]/.test(s))
        return null;
    if (/[A-Za-z_]/.test(s.replace(/Math\.(min|max|floor|ceil|abs|sqrt|atan2|cos|sin)|Math::PI|Math\.PI/g, "")))
        return null;
    try {
        var v = Function("\"use strict\";return (".concat(s, ")"))();
        return Number.isFinite(Number(v)) ? Number(v) : null;
    }
    catch (_w) {
        return null;
    }
}
function splitRubyStatements(text) {
    var e_37, _x;
    var out = [];
    var cur = "", depth = 0, q = false, quote = "";
    var flush = function () {
        if (!cur.trim()) {
            cur = "";
            return;
        }
        var stmt = stripComment(cur).trim().replace(/\s+rescue\s+nil\s*$/i, "");
        var cond = stmt.match(/^(.*)\s+if\s+(.+)$/i);
        if (cond) {
            var ok = safeEval(cond[2]);
            if (ok === 0)
                stmt = "";
            else if (ok != null)
                stmt = cond[1].trim();
        }
        if (stmt)
            out.push(stmt);
        cur = "";
    };
    try {
        for (var _y = __values(String(text || "").split(/\r?\n/)), _z = _y.next(); !_z.done; _z = _y.next()) {
            var raw = _z.value;
            if (cur && !/\s$/.test(cur))
                cur += " ";
            for (var i = 0; i < raw.length; i++) {
                var c = raw[i], prev = raw[i - 1];
                if ((c === '"' || c === "'") && prev !== "\\" && (!q || quote === c)) {
                    q = !q;
                    quote = q ? c : "";
                }
                if (!q) {
                    if (c === '(' || c === '[' || c === '{')
                        depth++;
                    else if (c === ')' || c === ']' || c === '}')
                        depth = Math.max(0, depth - 1);
                    if (c === ';' && depth === 0) {
                        flush();
                        continue;
                    }
                }
                cur += c;
            }
            // Ruby allows calls/arrays to continue while delimiters are open. Do not
            // split them into fake statements just because the source has a newline.
            if (depth === 0 && !q)
                flush();
        }
    }
    catch (e_37_1) {
        e_37 = { error: e_37_1 };
    }
    finally {
        try {
            if (_z && !_z.done && (_x = _y.return))
                _x.call(_y);
        }
        finally {
            if (e_37)
                throw e_37.error;
        }
    }
    flush();
    return out.filter(Boolean);
}
function splitArgs(s) {
    var out = [];
    var cur = "", depth = 0, q = false, quote = "";
    for (var i = 0; i < String(s || "").length; i++) {
        var c = String(s)[i], prev = String(s)[i - 1];
        if ((c === '"' || c === "'") && prev !== "\\" && (!q || quote === c)) {
            q = !q;
            quote = q ? c : "";
            cur += c;
            continue;
        }
        if (!q) {
            if (c === '(' || c === '[' || c === '{')
                depth++;
            else if (c === ')' || c === ']' || c === '}')
                depth = Math.max(0, depth - 1);
            if (c === ',' && depth === 0) {
                out.push(cur.trim());
                cur = "";
                continue;
            }
        }
        cur += c;
    }
    out.push(cur.trim());
    return out;
}
function extractRubyMethod(text, methodName) {
    var lines = String(text || "").split(/\r?\n/), re = new RegExp("^\\s*def\\s+".concat(String(methodName).replace(/[.*+?^${}()|[\\]\\]/g, "\\$&"), "\\s*(?:\\(([^)]*)\\))?"), "i");
    for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(re);
        if (!m)
            continue;
        var baseIndent = (lines[i].match(/^\s*/) || [""])[0].length, body = [], params = String(m[1] || "").split(",").map(function (x) { return x.trim().split("=")[0].trim(); }).filter(Boolean);
        var depth = 1;
        for (var j = i + 1; j < lines.length; j++) {
            var line = lines[j], t = line.trim(), indent = (line.match(/^\s*/) || [""])[0].length;
            if (/^(?:def|class|module|case|if|unless|while|until|for|begin)\b/.test(t) || /\bdo\s*(?:\||$)/.test(t))
                depth++;
            if (/^end\b/.test(t)) {
                depth--;
                if (depth <= 0 && indent <= baseIndent)
                    return { params: params, body: body.join("\n") };
            }
            body.push(line);
        }
        return { params: params, body: body.join("\n") };
    }
    return null;
}
function executableRuby(text) {
    var lines = String(text || "").split(/\r?\n/), out = [];
    var foundCreate = false;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i], m = line.match(/^(\s*)def\s+([a-zA-Z_]\w*[!?=]?)/);
        if (!m) {
            if (!/^\s*(?:class|module)\b/.test(line))
                out.push(line);
            continue;
        }
        var name = m[2], baseIndent = m[1].length;
        var depth = 1, body = [];
        for (i = i + 1; i < lines.length; i++) {
            var ln = lines[i], t = ln.trim(), indent = (ln.match(/^\s*/) || [""])[0].length;
            if (/^(?:def|class|module|case|if|unless|while|until|for|begin)\b/.test(t) || /\bdo\s*(?:\||$)/.test(t))
                depth++;
            if (/^end\b/.test(t)) {
                depth--;
                if (depth <= 0 && indent <= baseIndent)
                    break;
            }
            if (depth > 0)
                body.push(ln);
        }
        if (name === "createProcesses") {
            out.push.apply(out, __spreadArray([], __read(body), false));
            foundCreate = true;
        }
    }
    return foundCreate ? out.join("\n") : String(text || "");
}
function parseCodeColor(expr, env) {
    if (env === void 0) {
        env = {};
    }
    var m = String(expr || "").match(/Color\.new\((.*)\)/i);
    if (!m)
        return null;
    var a = splitArgs(m[1]);
    var r = safeEval(a[0] || "255", env), g = safeEval(a[1] || "255", env), b = safeEval(a[2] || "255", env), alpha = safeEval(a[3] || "255", env);
    if ([r, g, b, alpha].some(function (v) { return v == null; }))
        return null;
    return { r: r, g: g, b: b, a: alpha };
}
function proceduralHelperDescriptor(text, helperName, rawArgs, baseEnv) {
    var e_38, _x;
    if (baseEnv === void 0) {
        baseEnv = {};
    }
    var method = extractRubyMethod(text, helperName);
    var args = splitArgs(rawArgs || ""), env = Object.assign({}, baseEnv, { vars: Object.assign({}, baseEnv.vars || {}) });
    if (method)
        method.params.forEach(function (p, i) {
            var v = safeEval(args[i] || "0", baseEnv);
            if (v != null)
                env.vars[p] = v;
        });
    if (/spotlight/i.test(helperName)) {
        var fy = safeEval(args[0] || "240", baseEnv) || 240;
        return { type: "spotlight", w: 200, h: Math.max(1, fy + 100), ox: 100, oy: 0, layers: [] };
    }
    var body = method ? method.body : "";
    var w = /black/i.test(helperName) ? Number(baseEnv.width || 512) : 64, h = /black/i.test(helperName) ? Number(baseEnv.height || 384) : 64, ox = null, oy = null;
    var layers = [];
    try {
        for (var _y = __values(splitRubyStatements(body)), _z = _y.next(); !_z.done; _z = _y.next()) {
            var stmt = _z.value;
            var m = stmt.match(/^([a-z_]\w*)\s*=\s*(.+)$/i);
            if (m && !/Bitmap\.new|Sprite\.new|Color\.new/.test(m[2])) {
                var v = safeEval(m[2], env);
                if (v != null)
                    env.vars[m[1]] = v;
            }
            m = stmt.match(/^[a-z_]\w*\s*=\s*Bitmap\.new\((.*)\)$/i);
            if (m) {
                var a = splitArgs(m[1]);
                w = Math.max(1, safeEval(a[0] || "64", env) || 64);
                h = Math.max(1, safeEval(a[1] || a[0] || "64", env) || 64);
                continue;
            }
            m = stmt.match(/^[a-z_]\w*\.fill_rect\((.*)\)$/i);
            if (m) {
                var a = splitArgs(m[1]);
                if (a.length >= 5) {
                    var x = safeEval(a[0], env), y = safeEval(a[1], env), lw = safeEval(a[2], env), lh = safeEval(a[3], env), color = parseCodeColor(a.slice(4).join(","), env);
                    if ([x, y, lw, lh].every(function (v) { return v != null; }) && color)
                        layers.push({ x: x, y: y, w: lw, h: lh, color: color });
                }
                continue;
            }
            m = stmt.match(/^[a-z_]\w*\.ox\s*=\s*(.+)$/i);
            if (m) {
                var v = safeEval(m[1], env);
                if (v != null)
                    ox = v;
                continue;
            }
            m = stmt.match(/^[a-z_]\w*\.oy\s*=\s*(.+)$/i);
            if (m) {
                var v = safeEval(m[1], env);
                if (v != null)
                    oy = v;
                continue;
            }
        }
    }
    catch (e_38_1) {
        e_38 = { error: e_38_1 };
    }
    finally {
        try {
            if (_z && !_z.done && (_x = _y.return))
                _x.call(_y);
        }
        finally {
            if (e_38)
                throw e_38.error;
        }
    }
    if (!layers.length && /black/i.test(helperName))
        layers.push({ x: 0, y: 0, w: w, h: h, color: { r: 0, g: 0, b: 0, a: 255 } });
    if (!layers.length)
        return null;
    return { type: "composite", w: w, h: h, ox: ox, oy: oy, layers: layers };
}
function applyProceduralDescriptor(obj, d, origin) {
    if (origin === void 0) {
        origin = "auto";
    }
    if (!obj || !d)
        return;
    obj.graphic.procedural = d.type || "composite";
    obj.graphic.proceduralW = Math.max(1, Number(d.w || 16));
    obj.graphic.proceduralH = Math.max(1, Number(d.h || 16));
    obj.graphic.proceduralLayers = d.layers || [];
    if (d.ox != null)
        obj.graphic.proceduralOx = Number(d.ox);
    if (d.oy != null)
        obj.graphic.proceduralOy = Number(d.oy);
    obj.graphic.origin = origin || obj.graphic.origin || "auto";
}
function collectCodeAssets(text) {
    var e_39, _x, e_40, _y, e_41, _z, e_42, _0, e_43, _1, e_44, _2;
    var constants = {}, assetVars = {};
    try {
        for (var _3 = __values(String(text).matchAll(/^\s*([A-Z][A-Z0-9_]+)\s*=\s*([^\r\n]+)$/gm)), _4 = _3.next(); !_4.done; _4 = _3.next()) {
            var m = _4.value;
            var strings = __spreadArray([], __read(m[2].matchAll(/["']([^"']+)["']/g)), false).map(function (x) { return x[1]; });
            if (strings.length)
                constants[m[1]] = strings;
        }
    }
    catch (e_39_1) {
        e_39 = { error: e_39_1 };
    }
    finally {
        try {
            if (_4 && !_4.done && (_x = _3.return))
                _x.call(_3);
        }
        finally {
            if (e_39)
                throw e_39.error;
        }
    }
    try {
        for (var _5 = __values(String(text).matchAll(/([A-Z][A-Z0-9_]+)\s*=\s*\[([\s\S]*?)\]/g)), _6 = _5.next(); !_6.done; _6 = _5.next()) {
            var m = _6.value;
            var strings = __spreadArray([], __read(m[2].matchAll(/["']([^"']+)["']/g)), false).map(function (x) { return x[1]; });
            if (strings.length)
                constants[m[1]] = strings;
        }
    }
    catch (e_40_1) {
        e_40 = { error: e_40_1 };
    }
    finally {
        try {
            if (_6 && !_6.done && (_y = _5.return))
                _y.call(_5);
        }
        finally {
            if (e_40)
                throw e_40.error;
        }
    }
    try {
        for (var _7 = __values(String(text).matchAll(/^\s*([a-z_]\w*)\s*=\s*[^\r\n]*(?:first_existing_asset|resolve_bitmap)\(([^\r\n]*)/gmi)), _8 = _7.next(); !_8.done; _8 = _7.next()) {
            var m = _8.value;
            var names = __spreadArray([], __read(m[2].matchAll(/(?:[A-Za-z0-9_]+::)*([A-Z][A-Z0-9_]+)/g)), false).map(function (x) { return x[1]; });
            try {
                for (var names_1 = (e_42 = void 0, __values(names)), names_1_1 = names_1.next(); !names_1_1.done; names_1_1 = names_1.next()) {
                    var n = names_1_1.value;
                    if (constants[n]) {
                        assetVars[m[1]] = constants[n];
                        break;
                    }
                }
            }
            catch (e_42_1) {
                e_42 = { error: e_42_1 };
            }
            finally {
                try {
                    if (names_1_1 && !names_1_1.done && (_0 = names_1.return))
                        _0.call(names_1);
                }
                finally {
                    if (e_42)
                        throw e_42.error;
                }
            }
            var direct = __spreadArray([], __read(m[2].matchAll(/["'](Graphics\/[^"']+)["']/g)), false).map(function (x) { return x[1]; });
            if (direct.length)
                assetVars[m[1]] = direct;
        }
    }
    catch (e_41_1) {
        e_41 = { error: e_41_1 };
    }
    finally {
        try {
            if (_8 && !_8.done && (_z = _7.return))
                _z.call(_7);
        }
        finally {
            if (e_41)
                throw e_41.error;
        }
    }
    try {
        for (var _9 = __values(String(text).matchAll(/^\s*([a-z_]\w*)\s*=\s*["'](Graphics\/[^"']+)["']/gmi)), _10 = _9.next(); !_10.done; _10 = _9.next()) {
            var m = _10.value;
            assetVars[m[1]] = [m[2]];
        }
    }
    catch (e_43_1) {
        e_43 = { error: e_43_1 };
    }
    finally {
        try {
            if (_10 && !_10.done && (_1 = _9.return))
                _1.call(_9);
        }
        finally {
            if (e_43)
                throw e_43.error;
        }
    }
    try {
        for (var _11 = __values(String(text).matchAll(/^\s*([a-z_]\w*)\s*=\s*\[([^\r\n]+)\]/gmi)), _12 = _11.next(); !_12.done; _12 = _11.next()) {
            var m = _12.value;
            var strings = __spreadArray([], __read(m[2].matchAll(/["']([^"']+)["']/g)), false).map(function (x) { return x[1]; });
            if (strings.length)
                assetVars[m[1]] = strings;
        }
    }
    catch (e_44_1) {
        e_44 = { error: e_44_1 };
    }
    finally {
        try {
            if (_12 && !_12.done && (_2 = _11.return))
                _2.call(_11);
        }
        finally {
            if (e_44)
                throw e_44.error;
        }
    }
    return { constants: constants, assetVars: assetVars };
}
function codeAsset(expr, constants, assetVars) {
    if (assetVars === void 0) {
        assetVars = {};
    }
    var raw = String(expr || "").trim(), direct = __spreadArray([], __read(raw.matchAll(/["'](Graphics\/[^"']+?)["']/g)), false).map(function (x) { return x[1]; });
    if (direct.length) {
        var prefix_1 = direct[0];
        var dyn = raw.match(/\+\s*([a-z_]\w*)\s*\[/i);
        if (dyn && assetVars[dyn[1]] && /[\/]$/.test(prefix_1)) {
            var candidates = assetVars[dyn[1]].map(function (x) { return prefix_1 + x; });
            return { path: candidates[0], candidates: candidates };
        }
        return { path: prefix_1, candidates: direct };
    }
    if (assetVars[raw])
        return { path: assetVars[raw][0], candidates: assetVars[raw] };
    var c = raw.match(/(?:[A-Za-z0-9_]+::)*([A-Z][A-Z0-9_]+)/);
    if (c && constants[c[1]])
        return { path: constants[c[1]][0], candidates: constants[c[1]] };
    return { path: "", candidates: [] };
}
function evalCodeString(expr, env, constants) {
    if (env === void 0) {
        env = {};
    }
    if (constants === void 0) {
        constants = {};
    }
    var _a;
    var raw = String(expr !== null && expr !== void 0 ? expr : "").trim();
    if (!raw)
        return "";
    var quoted = raw.match(/^["']([\s\S]*)["']$/);
    if (quoted)
        return quoted[1];
    var tern = raw.match(/^(.+?)\?\s*["']([^"']*)["']\s*:\s*["']([^"']*)["']$/);
    if (tern) {
        var cond = safeEval(tern[1], env);
        if (cond != null)
            return cond ? tern[2] : tern[3];
    }
    var cm = raw.match(/(?:[A-Za-z0-9_]+::)*([A-Z][A-Z0-9_]+)$/);
    if (cm && ((_a = constants[cm[1]]) === null || _a === void 0 ? void 0 : _a.length))
        return constants[cm[1]][0];
    return raw.replace(/^["']|["']$/g, "");
}
function mapCodeAsset(c, asset, name) {
    c.graphic.source = "code";
    c.graphic.projectPath = asset.path;
    c.graphic.assetCandidates = asset.candidates;
    c.graphic.name = (asset.path.split("/").pop() || name).replace(/\.png$/i, "");
    c.graphic.folder = asset.path.includes("AnimationStudio") ? "AnimationStudio" : asset.path.includes("BattleParticlesAnimations") ? "BattleParticlesAnimations" : asset.path.includes("Battle animations") ? "Battle animations" : "Animations";
    // Graphics/Animations is the vanilla RMXP animation atlas format: 192×192
    // cells, 5 columns, potentially multiple rows. Treating it as a horizontal
    // strip duplicated/cropped frames in Ruby imports.
    if (/^Graphics\/Animations\//i.test(asset.path)) {
        c.graphic.spritesheet = "rmxp";
        c.graphic.cellW = 192;
        c.graphic.cellH = 192;
        c.graphic.cols = 5;
    }
    else
        c.graphic.spritesheet = "auto";
}
function helperDefaults(text) {
    var e_45, _x;
    var src = String(text || ""), out = { pras: { fw: 192, fh: 192, cols: 5, mode: "grid" }, frameGrid: { fw: 192, fh: 192, mode: "index", cellMode: "square-height", specialCells: [] } };
    var sig = src.match(/def\s+apply_pras_frame\(([^\n)]*)\)/i);
    if (sig) {
        if (/absolute_frame/i.test(sig[1]))
            out.pras.mode = "absolute";
        else if (/path/i.test(sig[1]))
            out.pras.mode = "path-grid";
        else
            out.pras.mode = "grid";
    }
    var block = src.match(/def\s+apply_pras_frame\([^\n]*\)[\s\S]{0,900}?\n\s*end/);
    if (block) {
        var fw = block[0].match(/\bfw\s*=\s*(\d+)/), fh = block[0].match(/\bfh\s*=\s*(\d+)/), cols = block[0].match(/\bcols\s*=\s*(\d+)/);
        if (fw)
            out.pras.fw = Number(fw[1]);
        if (fh)
            out.pras.fh = Number(fh[1]);
        if (cols)
            out.pras.cols = Math.max(1, Number(cols[1]));
    }
    var fsig = src.match(/def\s+apply_frame\(([^\n)]*)\)/i);
    if (fsig)
        out.frameGrid.mode = /\bcol\b[\s\S]*\brow\b/i.test(fsig[1]) ? "grid" : "index";
    var info = src.match(/def\s+get_frame_info\([^\n]*\)[\s\S]{0,1600}?\n\s*end/);
    if (info) {
        var fw = info[0].match(/\bfw\s*=\s*(\d+)/), fh = info[0].match(/\bfh\s*=\s*(\d+)/);
        if (fw && fh) {
            out.frameGrid.fw = Number(fw[1]);
            out.frameGrid.fh = Number(fh[1]);
            out.frameGrid.cellMode = "fixed";
        }
        if (/fw\s*=\s*bmp\.height/i.test(info[0]))
            out.frameGrid.cellMode = "square-height";
        try {
            for (var _y = __values(info[0].matchAll(/(?:if|elsif)\s+path\.include\?\(["']([^"']+)["']\)([\s\S]{0,180}?)(?=\n\s*(?:elsif|else|end)\b)/g)), _z = _y.next(); !_z.done; _z = _y.next()) {
                var m = _z.value;
                var fw2 = m[2].match(/\bfw\s*=\s*(\d+)/), fh2 = m[2].match(/\bfh\s*=\s*(\d+)/);
                if (fw2 && fh2)
                    out.frameGrid.specialCells.push({ match: m[1], fw: Number(fw2[1]), fh: Number(fh2[1]) });
            }
        }
        catch (e_45_1) {
            e_45 = { error: e_45_1 };
        }
        finally {
            try {
                if (_z && !_z.done && (_x = _y.return))
                    _x.call(_y);
            }
            finally {
                if (e_45)
                    throw e_45.error;
            }
        }
    }
    else {
        var frameBlock = src.match(/def\s+apply_frame\([^\n]*\)[\s\S]{0,700}?\n\s*end/);
        if (frameBlock) {
            var fw = frameBlock[0].match(/fw\s*=\s*(\d+)/), fh = frameBlock[0].match(/fh\s*=\s*(\d+)/);
            if (fw)
                out.frameGrid.fw = Number(fw[1]);
            if (fh)
                out.frameGrid.fh = Number(fh[1]);
            if (fw && fh)
                out.frameGrid.cellMode = "fixed";
        }
    }
    out.hasPrasSequence = /def\s+play_pras_sequence\s*\(/i.test(src);
    var asig = src.match(/def\s+animate_sheet_fluid\(([^\n)]*)\)/i);
    out.animateSignature = asig ? asig[1] : "";
    return out;
}
function codeSheetCell(helper, clip) {
    var e_46, _x;
    var _a, _b, _c, _d;
    var path = String(((_a = clip === null || clip === void 0 ? void 0 : clip.graphic) === null || _a === void 0 ? void 0 : _a.projectPath) || ((_b = clip === null || clip === void 0 ? void 0 : clip.graphic) === null || _b === void 0 ? void 0 : _b.name) || "");
    try {
        for (var _y = __values(((_c = helper === null || helper === void 0 ? void 0 : helper.frameGrid) === null || _c === void 0 ? void 0 : _c.specialCells) || []), _z = _y.next(); !_z.done; _z = _y.next()) {
            var s = _z.value;
            if (path.includes(s.match))
                return { fw: s.fw, fh: s.fh, mode: "fixed" };
        }
    }
    catch (e_46_1) {
        e_46 = { error: e_46_1 };
    }
    finally {
        try {
            if (_z && !_z.done && (_x = _y.return))
                _x.call(_y);
        }
        finally {
            if (e_46)
                throw e_46.error;
        }
    }
    if (((_d = helper === null || helper === void 0 ? void 0 : helper.frameGrid) === null || _d === void 0 ? void 0 : _d.cellMode) === "fixed")
        return { fw: helper.frameGrid.fw, fh: helper.frameGrid.fh, mode: "fixed" };
    return { fw: 0, fh: 0, mode: "square-height" };
}
function clipFor(map, name) { return map.get(String(name || "").trim()) || null; }
function uniqueClipName(a, base) { var n = getEffectsTrack(a).clips.filter(function (c) { return c.name === base || c.name.startsWith("".concat(base, " #")); }).length; return n ? "".concat(base, " #").concat(n + 1) : base; }
function rubyFxValue(expr, env, kind) {
    if (kind === void 0) {
        kind = "color";
    }
    var raw = String(expr || "").trim();
    var m = raw.match(/(?:Color|Tone)\.new\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^\)]+)\)/i);
    if (m) {
        var vals = m.slice(1).map(function (x) { var _a; return (_a = safeEval(x, env)) !== null && _a !== void 0 ? _a : 0; });
        return kind === "tone" ? { red: vals[0], green: vals[1], blue: vals[2], gray: vals[3] } : { red: vals[0], green: vals[1], blue: vals[2], alpha: vals[3] };
    }
    // Common VERMEIL pattern: color_pool.sample. Deterministically use the first Tone/Color
    // so the static preview stays stable while runtime capture preserves true randomness.
    var first = String(env.__sourceText || "").match(new RegExp("(?:".concat(kind === "tone" ? "Tone" : "Color", ")\\.new\\(([^\\)]*)\\)"), 'i'));
    if (/\.sample\b/.test(raw) && first) {
        var bits = splitArgs(first[1]);
        if (bits.length >= 4) {
            var vals = bits.slice(0, 4).map(function (x) { var _a; return (_a = safeEval(x, env)) !== null && _a !== void 0 ? _a : 0; });
            return kind === "tone" ? { red: vals[0], green: vals[1], blue: vals[2], gray: vals[3] } : { red: vals[0], green: vals[1], blue: vals[2], alpha: vals[3] };
        }
    }
    return raw.replace(/^['"]|['"]$/g, "");
}
function staticValueAt(o, prop, frame, fallback) {
    var e_47, _x;
    var _a, _b, _c;
    var arr = (((_a = o.valueKeys) === null || _a === void 0 ? void 0 : _a[prop]) || []).slice().sort(function (a, b) { return a.frame - b.frame; });
    var v = Number((_c = (_b = o.visual) === null || _b === void 0 ? void 0 : _b[prop]) !== null && _c !== void 0 ? _c : fallback);
    try {
        for (var arr_1 = __values(arr), arr_1_1 = arr_1.next(); !arr_1_1.done; arr_1_1 = arr_1.next()) {
            var k = arr_1_1.value;
            if (k.frame > frame)
                break;
            v = Number(k.value);
        }
    }
    catch (e_47_1) {
        e_47 = { error: e_47_1 };
    }
    finally {
        try {
            if (arr_1_1 && !arr_1_1.done && (_x = arr_1.return))
                _x.call(arr_1);
        }
        finally {
            if (e_47)
                throw e_47.error;
        }
    }
    return v;
}
function staticPosAt(o, frame, env) {
    var e_48, _x;
    var _a;
    var ks = sortPositionKeys(o).slice().sort(function (a, b) { return a.frame - b.frame; });
    var p = ((_a = ks[0]) === null || _a === void 0 ? void 0 : _a.point) || { x: o.side === "target" ? env.targetX : env.userX, y: o.side === "target" ? env.targetY : env.userY, anchor: "screen" };
    try {
        for (var ks_1 = __values(ks), ks_1_1 = ks_1.next(); !ks_1_1.done; ks_1_1 = ks_1.next()) {
            var k = ks_1_1.value;
            if (k.frame > frame)
                break;
            p = k.point;
        }
    }
    catch (e_48_1) {
        e_48 = { error: e_48_1 };
    }
    finally {
        try {
            if (ks_1_1 && !ks_1_1.done && (_x = ks_1.return))
                _x.call(ks_1);
        }
        finally {
            if (e_48)
                throw e_48.error;
        }
    }
    if (p.anchor === "screen")
        return { x: Number(p.x || 0), y: Number(p.y || 0) };
    return { x: o.side === "target" ? env.targetX : env.userX, y: o.side === "target" ? env.targetY : env.userY };
}
function resolveRubyInterpolation(text) {
    return String(text || "").replace(/#\{\s*(-?\d+(?:\.\d+)?)\s*\}/g, "$1");
}
export function animationFromCode(text, filename, context, options) {
    var e_49, _x, e_50, _y, e_51, _z, e_52, _0, e_53, _1;
    if (filename === void 0) {
        filename = "Code Animation";
    }
    if (context === void 0) {
        context = {};
    }
    if (options === void 0) {
        options = {};
    }
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k;
    var variant = options.moveId || null, metadata = options.metadata || discoverCodeMetadata(text, filename), behavior = String(options.behavior || metadata.behavior || "cinematic").toLowerCase(), sideContext = options.sideContext === "foe" ? "foe" : "player", selectedRaw = options.selectedSource || selectedCodeBranch(text, variant), selectedMain = executableRuby(selectedRaw), selected = resolveRubyInterpolation(expandForLoops(expandArrayLoops(expandSimpleTimes(selectedMain)))), a = createAnimation(variant || filename.replace(/\.rb$/i, ""));
    a.tracks[0].clips = [];
    var rawUser = context.user || {}, rawTarget = context.target || {}, foe = sideContext === "foe", u = foe ? rawTarget : rawUser, t0 = foe ? rawUser : rawTarget, ui = foe ? ((_a = context.targetIndex) !== null && _a !== void 0 ? _a : 1) : ((_b = context.userIndex) !== null && _b !== void 0 ? _b : 0), ti = foe ? ((_c = context.userIndex) !== null && _c !== void 0 ? _c : 0) : ((_d = context.targetIndex) !== null && _d !== void 0 ? _d : 1);
    var t = behavior === "self_targeting" ? u : t0, sideIndex = behavior === "hazard" ? (foe ? 0 : 1) : 0;
    var baseUser = (context.bases && context.bases.user) || u, baseTarget = (context.bases && context.bases.target) || t0;
    var hazardBase = sideIndex === 0 ? baseUser : baseTarget;
    var anchorX = Math.round(Number(hazardBase.x || (sideIndex === 0 ? ((context.width || 512) * .30) : ((context.width || 512) * .70))));
    var anchorY = Math.round(Number(hazardBase.y || (sideIndex === 0 ? ((context.height || 384) * .72) : ((context.height || 384) * .44))));
    var sourceSystem = options.sourceSystem || codeSourceSystem(text, filename), unsupported = codeUnsupportedDiagnostics(selected);
    a.source = { type: "code", system: sourceSystem, path: filename, approximate: true, importMode: "static", move: variant, catalogType: options.catalogType === "common" || (metadata.common || []).includes(variant) ? "common" : "move", version: Number(options.version || 0), behavior: behavior, sideContext: sideContext, opposing: foe, hitNum: Number(options.hitNum || 0), className: ((_e = metadata.classes) === null || _e === void 0 ? void 0 : _e[0]) || "", species: String(options.sourceSpecies || ""), sourceLine: Number(options.sourceLine || 0), unsupported: unsupported, codeMetadata: { classes: metadata.classes || [], handledMoves: metadata.moves || [], common: metadata.common || [], hasCallbacks: !!metadata.hasCallbacks, hasRandom: !!metadata.hasRandom } };
    // EBDX animation code advances at the EBDX scene cadence (40 fps). Essentials
    // PictureEx/VERMEIL code uses the standard animation cadence (20 fps).
    a.fps = sourceSystem === "ebdx" ? 40 : 20;
    a.events = [];
    var collectedAssets = collectCodeAssets(text), constants = Object.assign({}, options.externalConstants || {}, collectedAssets.constants || {}), assetVars = Object.assign({}, collectedAssets.assetVars || {}), helper = helperDefaults(text), vars = {}, env = { __time: 0, width: context.width || 512, height: context.height || 384, userX: u.x || 128, userY: u.y || 326, targetX: t.x || 390, targetY: t.y || 174, userW: u.bitmapWidth || 96, userH: u.bitmapHeight || 96, targetW: t.bitmapWidth || 96, targetH: t.bitmapHeight || 96, userIndex: ui, targetIndex: ti, hitNum: Number(options.hitNum || 0), anchorX: anchorX, anchorY: anchorY, sideIndex: sideIndex, vars: vars, __sourceText: selected };
    try {
        // Re-resolve helper asset variables after external/sibling constants have
        // been merged. Cinematic files commonly call first_existing_asset with
        // constants declared in another Ruby file (Explosion -> Selfdestruct, etc.).
        for (var _2 = __values(String(text).matchAll(/^\s*([a-z_]\w*)\s*=\s*[^\r\n]*(?:first_existing_asset|resolve_bitmap)\s*\(([\s\S]*?)\)/gmi)), _3 = _2.next(); !_3.done; _3 = _2.next()) {
            var m = _3.value;
            var names = __spreadArray([], __read(m[2].matchAll(/(?:[A-Za-z0-9_]+::)*([A-Z][A-Z0-9_]+)/g)), false).map(function (x) { return x[1]; });
            try {
                for (var names_2 = (e_50 = void 0, __values(names)), names_2_1 = names_2.next(); !names_2_1.done; names_2_1 = names_2.next()) {
                    var name = names_2_1.value;
                    if (constants[name] && constants[name].length) {
                        assetVars[m[1]] = constants[name];
                        break;
                    }
                }
            }
            catch (e_50_1) {
                e_50 = { error: e_50_1 };
            }
            finally {
                try {
                    if (names_2_1 && !names_2_1.done && (_y = names_2.return))
                        _y.call(names_2);
                }
                finally {
                    if (e_50)
                        throw e_50.error;
                }
            }
        }
    }
    catch (e_49_1) {
        e_49 = { error: e_49_1 };
    }
    finally {
        try {
            if (_3 && !_3.done && (_x = _2.return))
                _x.call(_2);
        }
        finally {
            if (e_49)
                throw e_49.error;
        }
    }
    for (var pass = 0; pass < 4; pass++)
        try {
            for (var _4 = (e_51 = void 0, __values(String(text).matchAll(/^\s*([A-Z][A-Z0-9_]*)\s*=\s*([^#\r\n]+)$/gm))), _5 = _4.next(); !_5.done; _5 = _4.next()) {
                var m = _5.value;
                var v = safeEval(m[2], env);
                if (v != null)
                    env.vars[m[1]] = v;
            }
        }
        catch (e_51_1) {
            e_51 = { error: e_51_1 };
        }
        finally {
            try {
                if (_5 && !_5.done && (_z = _4.return))
                    _z.call(_4);
            }
            finally {
                if (e_51)
                    throw e_51.error;
            }
        }
    var statements = splitRubyStatements(selected), map = new Map();
    var max = 1;
    var evalOr = function (e, f) { var v = safeEval(e, env); return v == null ? f : v; };
    var _loop_5 = function (line) {
        var e_54, _8, _9;
        var pair = line.match(/^([a-z_]\w*)\s*,\s*([a-z_]\w*)\s*=\s*(.+)$/i);
        if (pair) {
            var rr = splitArgs(pair[3]);
            if (rr.length >= 2) {
                var va = safeEval(rr[0], env), vb = safeEval(rr[1], env);
                if (va != null)
                    env.vars[pair[1]] = va;
                if (vb != null)
                    env.vars[pair[2]] = vb;
            }
        }
        var centerPair = line.match(/^([a-z_]\w*)\s*,\s*([a-z_]\w*)\s*=\s*@(userSprite|targetSprite)\.(?:getCenter|getAnchor)\b/i);
        if (centerPair) {
            var side = centerPair[3] === "targetSprite" ? "target" : "user", x = side === "target" ? env.targetX : env.userX, y = side === "target" ? env.targetY : env.userY - (side === "target" ? env.targetH : env.userH) / 2;
            env.vars[centerPair[1]] = x;
            env.vars[centerPair[2]] = y;
            return "continue";
        }
        var liveAlias = line.match(/^([a-z_]\w*)\s*=\s*(?:@scene\.)?@?sprites\s*\[.*?(?:pokemon_.*?@?(user|target)|@?(user|target).*?pokemon_).*?\]/i) || line.match(/^([a-z_]\w*)\s*=\s*@(userSprite|targetSprite)\b/i);
        if (liveAlias) {
            var token = String(liveAlias[2] || liveAlias[3] || "user").toLowerCase(), side = token.includes("target") ? "target" : "user";
            map.set(liveAlias[1], getBattlerTrack(a, side));
            return "continue";
        }
        var assignNum = line.match(/^([a-z_]\w*)\s*=\s*([^#]+)$/i);
        if (assignNum && !/addNewSprite|addSprite|Sprite\.new/.test(assignNum[2])) {
            var v = safeEval(assignNum[2], env);
            if (v != null)
                env.vars[assignNum[1]] = v;
        }
        var m = line.match(/^([a-z_]\w*)\s*=\s*addNewSprite\((.*)\)(?:\s+rescue\s+nil)?$/i);
        if (m) {
            var args = splitArgs(m[2]), x = evalOr(args[0], env.width / 2), y = evalOr(args[1], env.height / 2), asset = codeAsset(args[2], constants, assetVars), base = m[1], c = createProjectile({ id: uid("clip"), name: uniqueClipName(a, base), type: "code-particle" });
            c.positionKeys = [];
            c.visibleKeys = [];
            mapCodeAsset(c, asset, base);
            var org = String(args[3] || "");
            c.graphic.origin = /BOTTOM/i.test(org) ? "bottom" : /TOP_LEFT/i.test(org) ? "top_left" : /CENTER/i.test(org) ? "center" : "auto";
            setPositionKey(c, 0, { x: x, y: y }, "linear");
            setVisibleKey(c, 0, true);
            getEffectsTrack(a).clips.push(c);
            map.set(base, c);
            return "continue";
        }
        m = line.match(/^([a-z_]\w*)\s*=\s*(make_[a-z_]\w*)(?:\((.*)\))?$/i);
        if (m) {
            var d = proceduralHelperDescriptor(text, m[2], m[3] || "", env);
            if (d) {
                var c = createProjectile({ id: uid("clip"), name: uniqueClipName(a, m[1]), type: "code-procedural" });
                c.positionKeys = [];
                c.visibleKeys = [];
                applyProceduralDescriptor(c, d, "center");
                setPositionKey(c, 0, { anchor: "screen", x: 0, y: 0 }, "linear", "screen");
                setVisibleKey(c, 0, true);
                getEffectsTrack(a).clips.push(c);
                map.set(m[1], c);
                return "continue";
            }
        }
        m = line.match(/^([a-z_]\w*)\s*=\s*addSprite\(\s*(make_[a-z_]\w*)(?:\((.*?)\))?\s*,\s*(PictureOrigin::[A-Z_]+)\s*\)$/i);
        if (m) {
            var d = proceduralHelperDescriptor(text, m[2], m[3] || "", env);
            if (d) {
                var c = createProjectile({ id: uid("clip"), name: uniqueClipName(a, m[1]), type: "code-procedural" });
                c.positionKeys = [];
                c.visibleKeys = [];
                var org = /TOP_LEFT/i.test(m[4]) ? "top_left" : /BOTTOM/i.test(m[4]) ? "bottom" : "center";
                applyProceduralDescriptor(c, d, org);
                setPositionKey(c, 0, { anchor: "screen", x: 0, y: 0 }, "linear", "screen");
                setVisibleKey(c, 0, true);
                getEffectsTrack(a).clips.push(c);
                map.set(m[1], c);
                return "continue";
            }
        }
        m = line.match(/^([a-z_]\w*)\s*=\s*build_front_attacker_sprite\((.*)\)$/i);
        if (m) {
            var args = splitArgs(m[2]), c = createProjectile({ id: uid("clip"), name: uniqueClipName(a, m[1]), type: "battler-front-clone" });
            c.positionKeys = [];
            c.visibleKeys = [];
            c.graphic.source = "battler-user-front";
            c.graphic.name = "User front";
            c.graphic.origin = "bottom";
            setPositionKey(c, 0, { anchor: "screen", x: evalOr(args[1], env.width / 2), y: evalOr(args[2], env.height / 2) }, "linear", "screen");
            setVisibleKey(c, 0, true);
            getEffectsTrack(a).clips.push(c);
            map.set(m[1], c);
            return "continue";
        }
        m = line.match(/^([a-z_]\w*)\s*=\s*addSprite\((.*)\)(?:\s+rescue\s+nil)?$/i);
        if (m) {
            var rawRhs = m[2], rhs = rawRhs.toLowerCase(), addArgs = splitArgs(rawRhs), firstArg = addArgs[0] || "", existing = clipFor(map, firstArg), side = /target|\bts\b|\btt\b/.test(rhs) ? "target" : "user";
            if (existing && existing.type !== "battler") {
                map.set(m[1], existing);
                var org = String(addArgs[1] || "");
                if (/TOP_LEFT/i.test(org))
                    existing.graphic.origin = "top_left";
                else if (/BOTTOM/i.test(org))
                    existing.graphic.origin = "bottom";
                else if (/CENTER/i.test(org))
                    existing.graphic.origin = "center";
                return "continue";
            }
            if (/create_battler_clone/.test(rhs)) {
                var c = createProjectile({ id: uid("clip"), name: uniqueClipName(a, m[1]), type: "battler-clone" });
                c.positionKeys = [];
                c.visibleKeys = [];
                c.graphic.source = side === "target" ? "battler-target" : "battler-user";
                c.graphic.name = side === "target" ? "Target clone" : "User clone";
                c.graphic.origin = "bottom";
                setPositionKey(c, 0, { anchor: "screen", x: side === "target" ? env.targetX : env.userX, y: side === "target" ? env.targetY : env.userY, offsetX: 0, offsetY: 0 }, "linear", "screen");
                setVisibleKey(c, 0, true);
                getEffectsTrack(a).clips.push(c);
                map.set(m[1], c);
            }
            else if (/^(?:us|ts|tt|user_sprite|target_sprite|@userSprite|@targetSprite)\b/i.test(firstArg.trim()) || /@sprites\s*\[/.test(firstArg)) {
                var live = getBattlerTrack(a, side);
                live.__basLiveBattlerRef = true;
                map.set(m[1], live);
            }
            return "continue";
        }
        // EBDX/Luka sprite creation: fp["name"] = Sprite.new(@viewport)
        m = line.match(/^(?:(?:[a-z_]\w*)\s*\[\s*["']([^"']+)["']\s*\]|([a-z_]\w*))\s*=\s*(?:Sprite\.new|TrailingSprite\.new)\((.*)\)$/i);
        if (m) {
            var id = m[1] || m[2];
            var asset = codeAsset(m[3], constants, assetVars);
            var c = createProjectile({ id: uid("clip"), name: uniqueClipName(a, id), type: "ebdx-sprite" });
            c.positionKeys = [];
            c.visibleKeys = [];
            c.valueKeys || (c.valueKeys = {});
            if (asset.path)
                mapCodeAsset(c, asset, id);
            setPositionKey(c, env.__time || 0, { anchor: "screen", x: env.width / 2, y: env.height / 2 }, "linear", "screen");
            setVisibleKey(c, env.__time || 0, true);
            getEffectsTrack(a).clips.push(c);
            map.set(id, c);
            return "continue";
        }
        // EBDX pbBitmap assignment
        m = line.match(/^(?:(?:[a-z_]\w*)\s*\[\s*["']([^"']+)["']\s*\]|([a-z_]\w*))\.bitmap\s*=\s*pbBitmap\((.*)\)$/i);
        if (m) {
            var id = m[1] || m[2], o = clipFor(map, id);
            if (o && !o.__basProxy) {
                var asset = codeAsset(m[3], constants, assetVars);
                if (asset.path)
                    mapCodeAsset(o, asset, id);
            }
            return "continue";
        }
        // Procedural EBDX bitmaps (circles/solid sprites) do not have a PNG asset.
        m = line.match(/^(?:([a-z_]\w*)\s*\[\s*["']([^"']+)["']\s*\]|([a-z_]\w*))\.bitmap\s*=\s*Bitmap\.new\((.*)\)$/i);
        if (m) {
            var id = m[2] || m[3], o = clipFor(map, id);
            if (o && !o.__basProxy) {
                var args = splitArgs(m[4]), w = Math.max(1, evalOr(args[0], 16)), h = Math.max(1, evalOr(args[1], 16));
                o.graphic.procedural = "rect";
                o.graphic.proceduralW = w;
                o.graphic.proceduralH = h;
            }
            return "continue";
        }
        m = line.match(/^(?:([a-z_]\w*)\s*\[\s*["']([^"']+)["']\s*\]|([a-z_]\w*))\.bitmap\.(bmp_circle|draw_circle|fill_rect)\((.*)\)$/i);
        if (m) {
            var id = m[2] || m[3], o = clipFor(map, id);
            if (o && !o.__basProxy) {
                var args = splitArgs(m[5]), circle = /circle/i.test(m[4]);
                o.graphic.procedural = circle ? "circle" : (o.graphic.procedural || "rect");
                var colorExpr = circle ? (args[0] || "Color.new(255,255,255)") : (args.slice(4).join(",") || m[5]);
                var col = parseCodeColor(colorExpr, env);
                if (col)
                    o.graphic.proceduralColor = "rgba(".concat(col.r, ",").concat(col.g, ",").concat(col.b, ",").concat(col.a / 255, ")");
                if (circle) {
                    var rr = safeEval(args[1] || "0", env);
                    if (rr)
                        o.graphic.proceduralRadius = rr;
                    o.graphic.proceduralHollow = bool(args[4]);
                }
            }
            return "continue";
        }
        m = line.match(/^(?:(?:[a-z_]\w*)\s*\[\s*["']([^"']+)["']\s*\]|([a-z_]\w*)|@(targetSprite|userSprite))\.src_rect\.set\((.*)\)$/i);
        if (m) {
            var id = m[1] || m[2] || (m[3] === "targetSprite" ? "__target" : "__user"), o = id === "__target" ? getBattlerTrack(a, "target") : id === "__user" ? getBattlerTrack(a, "user") : clipFor(map, id);
            if (!o || o.__basProxy)
                return "continue";
            var args = splitArgs(m[4]), now = Number(env.__time || 0);
            var sx = evalOr(args[0] || "0", 0), sy = evalOr(args[1] || "0", 0), sw = Math.max(1, evalOr(args[2] || "1", 1)), sh = Math.max(1, evalOr(args[3] || "1", 1));
            setValueKey(o, "srcX", now, sx, "linear");
            setValueKey(o, "srcY", now, sy, "linear");
            setValueKey(o, "srcW", now, sw, "linear");
            setValueKey(o, "srcH", now, sh, "linear");
            max = Math.max(max, now);
            return "continue";
        }
        // EBDX direct tone/color/source-rectangle channel mutations.
        m = line.match(/^(?:(?:[a-z_]\w*)\s*\[\s*["']([^"']+)["']\s*\]|([a-z_]\w*)|@(targetSprite|userSprite))\.(tone|color|src_rect)\.(red|green|blue|gray|all|alpha|x|y|width|height)\s*([+\-]?=)\s*(.+)$/i);
        if (m) {
            var id = m[1] || m[2] || (m[3] === "targetSprite" ? "__target" : "__user"), o_1 = id === "__target" ? getBattlerTrack(a, "target") : id === "__user" ? getBattlerTrack(a, "user") : clipFor(map, id);
            if (!o_1 || o_1.__basProxy)
                return "continue";
            var group = m[4], channel = m[5], opAssign_1 = m[6], now_1 = Number(env.__time || 0), raw = safeEval(m[7], env);
            if (raw == null)
                return "continue";
            var setChan = function (prop, v, fallback) {
                if (fallback === void 0) {
                    fallback = 0;
                }
                var cur = staticValueAt(o_1, prop, now_1, fallback);
                setValueKey(o_1, prop, now_1, opAssign_1 === "+=" ? cur + v : opAssign_1 === "-=" ? cur - v : v, "linear");
            };
            if (group === "tone") {
                if (channel === "all")
                    try {
                        for (var _10 = (e_54 = void 0, __values(["toneRed", "toneGreen", "toneBlue"])), _11 = _10.next(); !_11.done; _11 = _10.next()) {
                            var q = _11.value;
                            setChan(q, raw);
                        }
                    }
                    catch (e_54_1) {
                        e_54 = { error: e_54_1 };
                    }
                    finally {
                        try {
                            if (_11 && !_11.done && (_8 = _10.return))
                                _8.call(_10);
                        }
                        finally {
                            if (e_54)
                                throw e_54.error;
                        }
                    }
                else
                    setChan("tone".concat(channel[0].toUpperCase()).concat(channel.slice(1)), raw);
            }
            else if (group === "color")
                setChan("color".concat(channel[0].toUpperCase()).concat(channel.slice(1)), raw);
            else {
                var q = { x: "srcX", y: "srcY", width: "srcW", height: "srcH" }[channel];
                if (q)
                    setChan(q, raw);
            }
            max = Math.max(max, now_1);
            return "continue";
        }
        // EBDX direct property mutations over scene frames
        m = line.match(/^(?:(?:[a-z_]\w*)\s*\[\s*["']([^"']+)["']\s*\]|([a-z_]\w*)|@(targetSprite|userSprite))\.([a-z_]+)(?:\.alpha)?\s*([+\-]?=)\s*(.+)$/i);
        if (m) {
            var id = m[1] || m[2] || (m[3] === "targetSprite" ? "__target" : "__user");
            var o_2 = id === "__target" ? getBattlerTrack(a, "target") : id === "__user" ? getBattlerTrack(a, "user") : clipFor(map, id);
            if (!o_2 || o_2.__basProxy)
                return "continue";
            var prop = m[4], opAssign_2 = m[5], valueRaw = m[6];
            var now_2 = Number(env.__time || 0);
            if (prop === "ox" && /\.bitmap\.width\s*\/\s*2/.test(valueRaw)) {
                if (o_2.graphic)
                    o_2.graphic.origin = "center";
                return "continue";
            }
            if (prop === "oy" && /\.bitmap\.height\s*\/\s*2/.test(valueRaw)) {
                if (o_2.graphic)
                    o_2.graphic.origin = "center";
                return "continue";
            }
            if (prop === "oy" && /\.bitmap\.height\b/.test(valueRaw) && !/\//.test(valueRaw)) {
                if (o_2.graphic)
                    o_2.graphic.origin = "bottom";
                return "continue";
            }
            var val = safeEval(valueRaw, env);
            if (val == null)
                return "continue";
            var addVal = function (track, v) { var cur = sampleValue(o_2, track, now_2, track === "opacity" ? 100 : 0); setValueKey(o_2, track, now_2, opAssign_2 === "+=" ? cur + v : opAssign_2 === "-=" ? cur - v : v); };
            if (prop === "x" || prop === "y") {
                var p = staticPosAt(o_2, now_2, env);
                if (opAssign_2 === "+=")
                    val = (prop === "x" ? p.x : p.y) + val;
                if (opAssign_2 === "-=")
                    val = (prop === "x" ? p.x : p.y) - val;
                setPositionKey(o_2, now_2, { anchor: "screen", x: prop === "x" ? val : p.x, y: prop === "y" ? val : p.y }, "linear", "screen");
            }
            else if (prop === "zoom_x")
                addVal("scaleX", val * 100);
            else if (prop === "zoom_y")
                addVal("scaleY", val * 100);
            else if (prop === "angle")
                addVal("rotation", val);
            else if (prop === "opacity")
                addVal("opacity", val * (opAssign_2 === "=" ? 100 / 255 : 1));
            else if (prop === "z")
                addVal("z", val);
            else if (prop === "ox") {
                if (opAssign_2 === "=")
                    setValueKey(o_2, "originX", now_2, val, "linear");
                else {
                    var cur = sampleValue(o_2, "originOffsetX", now_2, 0);
                    setValueKey(o_2, "originOffsetX", now_2, opAssign_2 === "+=" ? cur + val : cur - val, "linear");
                }
            }
            else if (prop === "oy") {
                if (opAssign_2 === "=")
                    setValueKey(o_2, "originY", now_2, val, "linear");
                else {
                    var cur = sampleValue(o_2, "originOffsetY", now_2, 0);
                    setValueKey(o_2, "originOffsetY", now_2, opAssign_2 === "+=" ? cur + val : cur - val, "linear");
                }
            }
            else if (prop === "mirror")
                setValueKey(o_2, "flip", now_2, val ? 1 : 0, "linear");
            else if (prop === "visible")
                setVisibleKey(o_2, now_2, !!val);
            else if (prop === "color") { /* Color object handled below by alpha updates/runtime capture. */ }
            max = Math.max(max, now_2);
            return "continue";
        }
        m = line.match(/^pbSEPlay\(\s*["']([^"']+)["']\s*(?:,\s*([^,\)]+))?(?:,\s*([^,\)]+))?\s*\)$/i);
        if (m) {
            a.events.push({ type: "se", frame: Number(env.__time || 0), name: m[1], volume: evalOr(m[2] || "100", 100), pitch: evalOr(m[3] || "100", 100) });
            return "continue";
        }
        m = line.match(/^@scene\.wait(?:\(\s*([^,\)]*)?[^)]*\))?/i);
        if (m) {
            env.__time = Number(env.__time || 0) + Math.max(1, Math.round(evalOr(m[1] || "1", 1)));
            max = Math.max(max, env.__time);
            return "continue";
        }
        // Direct PictureEx operations.
        m = line.match(/^([a-z_]\w*)\.((?:set|move)[A-Z]\w*|setCallback)\((.*)\)$/);
        if (m) {
            var o = clipFor(map, m[1]);
            if (!o)
                return "continue";
            var op = m[2], args = splitArgs(m[3]), t_1 = evalOr(args[0], 0);
            max = Math.max(max, t_1);
            var end = function (dur) { return Math.max(0, t_1 + dur); };
            if (op === "setXY" || op === "moveXY") {
                var dur = op === "moveXY" ? evalOr(args[1], 0) : 0, ix = op === "moveXY" ? 2 : 1, iy = op === "moveXY" ? 3 : 2;
                if (dur > 0) {
                    var st = staticPosAt(o, t_1, env);
                    setPositionKey(o, t_1, { x: st.x, y: st.y }, "linear");
                }
                setPositionKey(o, end(dur), { x: evalOr(args[ix], env.width / 2), y: evalOr(args[iy], env.height / 2) }, "linear");
                max = Math.max(max, end(dur));
            }
            else if (op === "moveDelta") {
                var dur = evalOr(args[1], 0), dx = evalOr(args[2], 0), dy = evalOr(args[3], 0), base = staticPosAt(o, t_1, env);
                setPositionKey(o, t_1, { x: base.x, y: base.y }, "linear");
                setPositionKey(o, end(dur), { x: base.x + dx, y: base.y + dy }, "linear");
                max = Math.max(max, end(dur));
            }
            else if (op === "setZoom" || op === "moveZoom") {
                var dur = op === "moveZoom" ? evalOr(args[1], 0) : 0, v = evalOr(args[op === "moveZoom" ? 2 : 1], 100);
                if (dur > 0) {
                    setValueKey(o, "scaleX", t_1, staticValueAt(o, "scaleX", t_1, 100), "linear");
                    setValueKey(o, "scaleY", t_1, staticValueAt(o, "scaleY", t_1, 100), "linear");
                }
                setValueKey(o, "scaleX", end(dur), v, "linear");
                setValueKey(o, "scaleY", end(dur), v, "linear");
                max = Math.max(max, end(dur));
            }
            else if (op === "setZoomXY" || op === "moveZoomXY") {
                var moving = op === "moveZoomXY", dur = moving ? evalOr(args[1], 0) : 0, ix = moving ? 2 : 1, iy = moving ? 3 : 2;
                if (dur > 0) {
                    setValueKey(o, "scaleX", t_1, staticValueAt(o, "scaleX", t_1, 100), "linear");
                    setValueKey(o, "scaleY", t_1, staticValueAt(o, "scaleY", t_1, 100), "linear");
                }
                setValueKey(o, "scaleX", end(dur), evalOr(args[ix], 100), "linear");
                setValueKey(o, "scaleY", end(dur), evalOr(args[iy], 100), "linear");
                max = Math.max(max, end(dur));
            }
            else if (op === "setAngle" || op === "moveAngle") {
                var dur = op === "moveAngle" ? evalOr(args[1], 0) : 0;
                if (dur > 0)
                    setValueKey(o, "rotation", t_1, staticValueAt(o, "rotation", t_1, 0), "linear");
                setValueKey(o, "rotation", end(dur), evalOr(args[op === "moveAngle" ? 2 : 1], 0), "linear");
                max = Math.max(max, end(dur));
            }
            else if (op === "setOpacity" || op === "moveOpacity") {
                var dur = op === "moveOpacity" ? evalOr(args[1], 0) : 0;
                if (dur > 0)
                    setValueKey(o, "opacity", t_1, staticValueAt(o, "opacity", t_1, 100), "linear");
                setValueKey(o, "opacity", end(dur), evalOr(args[op === "moveOpacity" ? 2 : 1], 255) * 100 / 255, "linear");
                max = Math.max(max, end(dur));
            }
            else if (op === "setVisible")
                setVisibleKey(o, t_1, bool(args[1]));
            else if (op === "setZ")
                setValueKey(o, "z", t_1, evalOr(args[1], 0), "linear");
            else if (op === "setBlendType")
                setValueKey(o, "blend", t_1, evalOr(args[1], 0), "linear");
            else if (op === "setSrc") {
                setValueKey(o, "srcX", t_1, evalOr(args[1], 0), "linear");
                setValueKey(o, "srcY", t_1, evalOr(args[2], 0), "linear");
            }
            else if (op === "setSrcSize") {
                setValueKey(o, "srcW", t_1, evalOr(args[1], 0), "linear");
                setValueKey(o, "srcH", t_1, evalOr(args[2], 0), "linear");
                o.graphic.spritesheet = "code-grid";
                o.graphic.cellW = evalOr(args[1], 0);
                o.graphic.cellH = evalOr(args[2], 0);
            }
            else if (op === "setSE") {
                var resolved = evalCodeString(args[1], env, constants);
                a.events.push({ type: "se", frame: t_1, name: resolved, volume: evalOr(args[2], 100), pitch: evalOr(args[3], 100) });
            }
            else if (op === "setBitmap") {
                var asset = codeAsset((_f = args[1]) !== null && _f !== void 0 ? _f : args[0], constants, assetVars);
                if (asset.path)
                    mapCodeAsset(o, asset, o.name || "Particle");
                o.graphicSwitches || (o.graphicSwitches = []);
                o.graphicSwitches.push({ frame: t_1, value: asset.path || String((_h = (_g = args[1]) !== null && _g !== void 0 ? _g : args[0]) !== null && _h !== void 0 ? _h : "").replace(/^['"]|['"]$/g, "") });
            }
            else if (op === "setOrigin") {
                var raw = String((_k = (_j = args[1]) !== null && _j !== void 0 ? _j : args[0]) !== null && _k !== void 0 ? _k : "");
                o.graphic.origin = /BOTTOM/i.test(raw) ? "bottom" : /TOP_LEFT/i.test(raw) ? "top_left" : /CENTER/i.test(raw) ? "center" : o.graphic.origin || "auto";
            }
            else if (op === "setPokemonBitmap") {
                var raw = String(args.slice(1).join(","));
                o.graphic.source = /@target|target/i.test(raw) ? "battler-target" : "battler-user";
                o.graphic.origin = "bottom";
            }
            else if (op === "setCallback") {
                a.runtimeNotes || (a.runtimeNotes = []);
                a.runtimeNotes.push({ type: "callback", frame: t_1, source: "static" });
            }
            else if (op === "setTone" || op === "moveTone" || op === "setColor" || op === "moveColor") {
                var moving = op.startsWith("move"), dur = moving ? evalOr(args[1], 0) : 0, vi = moving ? 2 : 1, kind = /Tone/.test(op) ? "tone" : "color", value = rubyFxValue(args[vi], env, kind);
                o.fxOps || (o.fxOps = []);
                o.fxOps.push((_9 = { name: op, frame: t_1, duration: dur, value: value }, _9[kind] = value, _9.args = [t_1, dur, value], _9));
                max = Math.max(max, end(dur));
            }
            return "continue";
        }
        // VERMEIL Explosion-style dynamic sheet helper. The exact cell size is
        // resolved from the loaded bitmap in preview.js, using the same grid rules
        // as the Ruby helper instead of drawing the complete strip.
        m = line.match(/^apply_sheet_frame\((.*)\)$/i);
        if (m) {
            var args = splitArgs(m[1]), o = clipFor(map, args[0]);
            if (!o)
                return "continue";
            var asset = codeAsset(args[1], constants, assetVars);
            if (asset.path && !o.graphic.projectPath)
                mapCodeAsset(o, asset, o.name || "Particle");
            o.graphic.spritesheet = "code-dynamic-grid";
            o.graphic.sheetStyle = String(args[2] || ":default").replace(/^:/, "").replace(/["']/g, "");
            o.graphic.origin = "center";
            return "continue";
        }
        m = line.match(/^animate_sheet_frames\((.*)\)$/i);
        if (m) {
            var args = splitArgs(m[1]), o = clipFor(map, args[0]);
            if (!o)
                return "continue";
            var asset = codeAsset(args[1], constants, assetVars);
            if (asset.path && !o.graphic.projectPath)
                mapCodeAsset(o, asset, o.name || "Particle");
            o.graphic.spritesheet = "code-dynamic-grid";
            o.graphic.playSheet = true;
            o.graphic.playStart = evalOr(args[2], 0);
            o.graphic.playFrameCount = Math.max(1, Math.floor(evalOr(args[3], 1)));
            o.graphic.sheetStyle = String(args[4] || ":burst").replace(/^:/, "").replace(/["']/g, "");
            o.graphic.ticksPerFrame = 1;
            max = Math.max(max, o.graphic.playStart + o.graphic.playFrameCount);
            return "continue";
        }
        // Common PRAS spritesheet helpers. Handles both (sprite,path,col,row,time) and
        // the absolute-frame helper used by Ember/Vine Whip.
        m = line.match(/^apply_pras_frame\((.*)\)$/i);
        if (m) {
            var args = splitArgs(m[1]), o = clipFor(map, args[0]);
            if (!o)
                return "continue";
            if (helper.pras.mode === "absolute" && args.length <= 3) {
                var fr = Math.max(0, Math.floor(evalOr(args[1], 0))), t_2 = evalOr(args[2], 0), fw_1 = helper.pras.fw, fh_1 = helper.pras.fh, cols = helper.pras.cols;
                var col_1 = fr % cols, row_1 = Math.floor(fr / cols);
                setValueKey(o, "srcX", t_2, col_1 * fw_1, "linear");
                setValueKey(o, "srcY", t_2, row_1 * fh_1, "linear");
                setValueKey(o, "srcW", t_2, fw_1, "linear");
                setValueKey(o, "srcH", t_2, fh_1, "linear");
                o.graphic.spritesheet = "code-grid";
                o.graphic.cellW = fw_1;
                o.graphic.cellH = fh_1;
                o.graphic.gridCols = cols;
                max = Math.max(max, t_2);
                return "continue";
            }
            var pathExpr = String(args[1] || "").trim(), pathAsset = codeAsset(pathExpr, constants, assetVars), offset = (helper.pras.mode === "path-grid" || args.length >= 5 || pathAsset.path) ? 2 : 1;
            if (pathAsset.path && !o.graphic.projectPath)
                mapCodeAsset(o, pathAsset, o.name || "Particle");
            var col = evalOr(args[offset], 0), row = evalOr(args[offset + 1], 0), t_3 = evalOr(args[offset + 2], 0), fw = evalOr(args[offset + 3], helper.pras.fw), fh = evalOr(args[offset + 4], helper.pras.fh);
            setValueKey(o, "srcX", t_3, col * fw, "linear");
            setValueKey(o, "srcY", t_3, row * fh, "linear");
            setValueKey(o, "srcW", t_3, fw, "linear");
            setValueKey(o, "srcH", t_3, fh, "linear");
            o.graphic.spritesheet = "code-grid";
            o.graphic.cellW = fw;
            o.graphic.cellH = fh;
            max = Math.max(max, t_3);
            return "continue";
        }
        // Expands the PRAS sequence helper into visible source-rectangle keyframes.
        m = line.match(/^(?:([a-z_]\w*)\s*=\s*)?play_pras_sequence\((.*)\)$/i);
        if (m) {
            var args = splitArgs(m[2]), o = clipFor(map, args[0]);
            if (!o)
                return "continue";
            var start = evalOr(args[1], 0), first = Math.max(0, Math.floor(evalOr(args[2], 0))), count = Math.max(0, Math.floor(evalOr(args[3], 0))), ticks = Math.max(1, Math.floor(evalOr(args[4], 3))), fw = helper.pras.fw, fh = helper.pras.fh, cols = helper.pras.cols, duration = count * ticks;
            for (var j = 0; j < duration; j++) {
                var fr = first + Math.floor(j / ticks), t_4 = start + j, col = fr % cols, row = Math.floor(fr / cols);
                setValueKey(o, "srcX", t_4, col * fw, "linear");
                setValueKey(o, "srcY", t_4, row * fh, "linear");
                setValueKey(o, "srcW", t_4, fw, "linear");
                setValueKey(o, "srcH", t_4, fh, "linear");
                max = Math.max(max, t_4);
            }
            if (m[1])
                env.vars[m[1]] = duration;
            o.graphic.spritesheet = "code-grid";
            o.graphic.cellW = fw;
            o.graphic.cellH = fh;
            o.graphic.gridCols = cols;
            return "continue";
        }
        // apply_frame helpers: either an explicit col/row grid or a sequential frame index.
        m = line.match(/^apply_frame\((.*)\)$/i);
        if (m) {
            var args = splitArgs(m[1]), o = clipFor(map, args[0]);
            if (!o)
                return "continue";
            var asset = codeAsset(args[1], constants, assetVars);
            if (asset.path && !o.graphic.projectPath)
                mapCodeAsset(o, asset, o.name || "Particle");
            if (helper.frameGrid.mode === "grid" && args.length >= 5) {
                var col = evalOr(args[2], 0), row = evalOr(args[3], 0), t_5 = evalOr(args[4], 0), cell = codeSheetCell(helper, o), fw = cell.fw || helper.frameGrid.fw || 192, fh = cell.fh || helper.frameGrid.fh || 192;
                setValueKey(o, "srcX", t_5, col * fw, "linear");
                setValueKey(o, "srcY", t_5, row * fh, "linear");
                setValueKey(o, "srcW", t_5, fw, "linear");
                setValueKey(o, "srcH", t_5, fh, "linear");
                o.graphic.spritesheet = "code-grid";
                o.graphic.cellW = fw;
                o.graphic.cellH = fh;
                max = Math.max(max, t_5);
            }
            else if (args.length >= 4) {
                var fr = Math.max(0, Math.floor(evalOr(args[2], 0))), t_6 = evalOr(args[3], 0), cell = codeSheetCell(helper, o);
                setValueKey(o, "graphicFrame", t_6, fr, "linear");
                o.graphic.spritesheet = "code-auto-grid";
                o.graphic.cellMode = cell.mode;
                o.graphic.cellW = cell.fw > 0 ? cell.fw : 0;
                o.graphic.cellH = cell.fh > 0 ? cell.fh : 0;
                max = Math.max(max, t_6);
            }
            return "continue";
        }
        // Fluid sheet helpers. Supports the common full-strip signature and the
        // (start_frame, num_frames, ticks) variant used by Stalk Cutter.
        m = line.match(/^(?:([a-z_]\w*)\s*=\s*)?animate_sheet_fluid\((.*)\)$/i);
        if (m) {
            var args = splitArgs(m[2]), o = clipFor(map, args[0]);
            if (!o)
                return "continue";
            var asset = codeAsset(args[1], constants, assetVars);
            if (asset.path && !o.graphic.projectPath)
                mapCodeAsset(o, asset, o.name || "Particle");
            var st = evalOr(args[2], 0), hasRange = args.length >= 6, startFrame = hasRange ? Math.max(0, Math.floor(evalOr(args[3], 0))) : 0, frameCount = hasRange ? Math.max(1, Math.floor(evalOr(args[4], 1))) : 0, ticks = Math.max(1, Math.floor(evalOr(args[hasRange ? 5 : 3], 2))), cell = codeSheetCell(helper, o);
            o.graphic.spritesheet = "code-auto-grid";
            o.graphic.cellMode = cell.mode;
            o.graphic.cellW = cell.fw > 0 ? cell.fw : 0;
            o.graphic.cellH = cell.fh > 0 ? cell.fh : 0;
            o.graphic.playSheet = true;
            o.graphic.playStart = st;
            o.graphic.playFirstFrame = startFrame;
            o.graphic.playFrameCount = frameCount;
            o.graphic.ticksPerFrame = ticks;
            if (m[1] && frameCount > 0)
                env.vars[m[1]] = frameCount * ticks;
            max = Math.max(max, st + (frameCount > 0 ? frameCount * ticks : ticks * 8));
            return "continue";
        }
    };
    try {
        for (var statements_1 = __values(statements), statements_1_1 = statements_1.next(); !statements_1_1.done; statements_1_1 = statements_1.next()) {
            var line = statements_1_1.value;
            _loop_5(line);
        }
    }
    catch (e_52_1) {
        e_52 = { error: e_52_1 };
    }
    finally {
        try {
            if (statements_1_1 && !statements_1_1.done && (_0 = statements_1.return))
                _0.call(statements_1);
        }
        finally {
            if (e_52)
                throw e_52.error;
        }
    }
    var explicitEnd = __spreadArray([], __read(String(selected || "").matchAll(/@end_frame\s*=\s*([^#\r\n]+)/g)), false).map(function (m) { return safeEval(m[1], env); }).filter(function (v) { return v != null; });
    if (explicitEnd.length)
        max = Math.max.apply(Math, __spreadArray([max], __read(explicitEnd), false));
    var endFrame = explicitEnd.length ? Math.max.apply(Math, __spreadArray([], __read(explicitEnd), false)) : max;
    // Live battler references (addSprite(us/ts), @userSprite/@targetSprite) now
    // write directly to the base battler tracks. This avoids duplicate overlays
    // while preserving Ruby visibility, movement, zoom and opacity changes.
    a.logic = __spreadArray(__spreadArray([], __read((a.logic || [])), false), [{ type: "code_dialect", behavior: behavior, sideContext: sideContext, move: variant, source: filename, callbacks: metadata.hasCallbacks, random: metadata.hasRandom }], false);
    a.duration = Math.max(1, Math.ceil(max + 2));
    try {
        for (var _6 = __values(getEffectsTrack(a).clips), _7 = _6.next(); !_7.done; _7 = _6.next()) {
            var clip = _7.value;
            clip.endFrame = Math.max(Number(clip.endFrame || 0), a.duration);
        }
    }
    catch (e_53_1) {
        e_53 = { error: e_53_1 };
    }
    finally {
        try {
            if (_7 && !_7.done && (_1 = _6.return))
                _1.call(_6);
        }
        finally {
            if (e_53)
                throw e_53.error;
        }
    }
    return a;
}
// -----------------------------------------------------------------------------
// Exact runtime capture importer for code animations
// -----------------------------------------------------------------------------
function decoded(v) {
    if (v && typeof v === "object" && v.__type)
        return v;
    return v;
}
function argn(args, i, f) {
    if (f === void 0) {
        f = 0;
    }
    return num(decoded(args === null || args === void 0 ? void 0 : args[i]), f);
}
function sampleAbsPosition(obj, frame, fallback) {
    if (fallback === void 0) {
        fallback = { x: 0, y: 0 };
    }
    var ks = sortPositionKeys(obj);
    if (!ks.length)
        return fallback;
    var before = ks.filter(function (k) { return k.frame <= frame; }).at(-1) || ks[0], after = ks.find(function (k) { return k.frame >= frame; }) || ks.at(-1);
    var pa = before.point || fallback, pb = after.point || pa;
    if (pa.anchor !== "screen" || pb.anchor !== "screen")
        return { x: num(pa.x, fallback.x), y: num(pa.y, fallback.y) };
    if (after.frame === before.frame)
        return { x: num(pa.x), y: num(pa.y) };
    var t = (frame - before.frame) / (after.frame - before.frame);
    return { x: num(pa.x) + (num(pb.x) - num(pa.x)) * t, y: num(pa.y) + (num(pb.y) - num(pa.y)) * t };
}
function applyCapturedOp(a, obj, op) {
    var _a, _b, _c, _d;
    var name = String(op.name || op.op || ""), args = op.args || [], t = argn(args, 0, 0);
    var dur = 0, end = t;
    if (/^move/.test(name)) {
        dur = argn(args, 1, 0);
        end = t + dur;
    }
    if (name === "setXY" || name === "moveXY") {
        var ix = name === "moveXY" ? 2 : 1, iy = name === "moveXY" ? 3 : 2;
        var start = sampleAbsPosition(obj, t);
        setPositionKey(obj, t, { x: start.x, y: start.y }, "linear");
        setPositionKey(obj, end, { x: argn(args, ix, start.x), y: argn(args, iy, start.y) }, "linear");
    }
    else if (name === "moveDelta") {
        var start = sampleAbsPosition(obj, t);
        setPositionKey(obj, t, { x: start.x, y: start.y }, "linear");
        setPositionKey(obj, end, { x: start.x + argn(args, 2), y: start.y + argn(args, 3) }, "linear");
    }
    else if (name === "setZoom" || name === "moveZoom") {
        var v = argn(args, name === "moveZoom" ? 2 : 1, 100);
        if (dur > 0) {
            setValueKey(obj, "scaleX", t, staticValueAt(obj, "scaleX", t, 100), "linear");
            setValueKey(obj, "scaleY", t, staticValueAt(obj, "scaleY", t, 100), "linear");
        }
        setValueKey(obj, "scaleX", end, v, "linear");
        setValueKey(obj, "scaleY", end, v, "linear");
    }
    else if (name === "setZoomXY" || name === "moveZoomXY") {
        var ix = name === "moveZoomXY" ? 2 : 1, iy = name === "moveZoomXY" ? 3 : 2;
        if (dur > 0) {
            setValueKey(obj, "scaleX", t, staticValueAt(obj, "scaleX", t, 100), "linear");
            setValueKey(obj, "scaleY", t, staticValueAt(obj, "scaleY", t, 100), "linear");
        }
        setValueKey(obj, "scaleX", end, argn(args, ix, 100), "linear");
        setValueKey(obj, "scaleY", end, argn(args, iy, 100), "linear");
    }
    else if (name === "setAngle" || name === "moveAngle") {
        if (dur > 0)
            setValueKey(obj, "rotation", t, staticValueAt(obj, "rotation", t, 0), "linear");
        setValueKey(obj, "rotation", end, argn(args, name === "moveAngle" ? 2 : 1, 0), "linear");
    }
    else if (name === "setOpacity" || name === "moveOpacity") {
        if (dur > 0)
            setValueKey(obj, "opacity", t, staticValueAt(obj, "opacity", t, 100), "linear");
        setValueKey(obj, "opacity", end, argn(args, name === "moveOpacity" ? 2 : 1, 255) * 100 / 255, "linear");
    }
    else if (name === "setVisible")
        setVisibleKey(obj, t, !!args[1]);
    else if (name === "setZ")
        setValueKey(obj, "z", t, argn(args, 1, 0), "linear");
    else if (name === "setBlendType")
        setValueKey(obj, "blend", t, argn(args, 1, 0), "linear");
    else if (name === "setSrc") {
        setValueKey(obj, "srcX", t, argn(args, 1, 0), "linear");
        setValueKey(obj, "srcY", t, argn(args, 2, 0), "linear");
    }
    else if (name === "setSrcSize") {
        var sw = argn(args, 1, 0), sh = argn(args, 2, 0);
        setValueKey(obj, "srcW", t, sw, "linear");
        setValueKey(obj, "srcH", t, sh, "linear");
        obj.graphic || (obj.graphic = {});
        obj.graphic.spritesheet = "code-grid";
        if (sw > 0)
            obj.graphic.cellW = sw;
        if (sh > 0)
            obj.graphic.cellH = sh;
    }
    else if (name === "setBitmap") {
        obj.graphic || (obj.graphic = {});
        var v = decoded((_a = args[1]) !== null && _a !== void 0 ? _a : args[0]);
        var path = typeof v === "string" ? v : String((v === null || v === void 0 ? void 0 : v.value) || "");
        obj.graphicSwitches || (obj.graphicSwitches = []);
        obj.graphicSwitches.push({ frame: t, value: path });
        if (path && !obj.graphic.projectPath) {
            obj.graphic.source = "code";
            obj.graphic.projectPath = path;
            obj.graphic.externalRelativePath = path;
            obj.graphic.name = (path.split(/[\\/]/).pop() || obj.name || "").replace(/\.[^.]+$/g, "");
            obj.graphic.folder = path.includes("AnimationStudio") ? "AnimationStudio" : path.includes("BattleParticlesAnimations") ? "BattleParticlesAnimations" : path.includes("Battle animations") ? "Battle animations" : "Animations";
        }
    }
    else if (name === "setOrigin") {
        obj.graphic || (obj.graphic = {});
        var v = decoded((_b = args[1]) !== null && _b !== void 0 ? _b : args[0]), s = String((_d = (_c = v === null || v === void 0 ? void 0 : v.value) !== null && _c !== void 0 ? _c : v) !== null && _d !== void 0 ? _d : "").toLowerCase();
        obj.graphic.origin = s.includes("bottom") ? "bottom" : s.includes("top_left") ? "top_left" : s.includes("center") ? "center" : obj.graphic.origin || "auto";
        obj.graphic.originCode = v;
    }
    else if (name === "setPokemonBitmap") {
        obj.graphic || (obj.graphic = {});
        var raw = JSON.stringify(args || []).toLowerCase();
        obj.graphic.source = raw.includes("target") ? "battler-target" : "battler-user";
        obj.graphic.origin = "bottom";
    }
    else if (name === "setTone" || name === "moveTone" || name === "setColor" || name === "moveColor") {
        obj.fxOps || (obj.fxOps = []);
        obj.fxOps.push({ name: name, args: args });
    }
    else if (name === "setSE")
        a.events.push({ type: "se", frame: t, name: String(args[1] || ""), volume: argn(args, 2, 100), pitch: argn(args, 3, 100) });
    else if (name === "setCallback") {
        a.runtimeNotes || (a.runtimeNotes = []);
        a.runtimeNotes.push({ type: "callback", frame: t });
    }
    return Math.max(t, end);
}
function addBattlerFrames(track, frames, side) {
    var e_55, _x, e_56, _y;
    var _a, _b, _c, _d;
    if (!Array.isArray(frames) || !frames.length)
        return 0;
    track.positionKeys = [];
    track.visibleKeys = [];
    track.fxOps = [];
    try {
        for (var _z = __values(Object.values(track.valueKeys || {})), _0 = _z.next(); !_0.done; _0 = _z.next()) {
            var arr = _0.value;
            arr.length = 0;
        }
    }
    catch (e_55_1) {
        e_55 = { error: e_55_1 };
    }
    finally {
        try {
            if (_0 && !_0.done && (_x = _z.return))
                _x.call(_z);
        }
        finally {
            if (e_55)
                throw e_55.error;
        }
    }
    var first = frames.map(function (f) { return f === null || f === void 0 ? void 0 : f[side]; }).find(Boolean) || {}, baseZX = Math.max(0.0001, num((_a = first.zoom_x) !== null && _a !== void 0 ? _a : first.zoomX, 1)), baseZY = Math.max(0.0001, num((_b = first.zoom_y) !== null && _b !== void 0 ? _b : first.zoomY, 1)), baseAngle = num(first.angle, 0);
    var max = 0, lastFx = "";
    try {
        for (var frames_2 = __values(frames), frames_2_1 = frames_2.next(); !frames_2_1.done; frames_2_1 = frames_2.next()) {
            var f = frames_2_1.value;
            var fr = num(f.frame, 0), s = f[side];
            if (!s)
                continue;
            setPositionKey(track, fr, { anchor: "screen", x: num(s.x), y: num(s.y), offsetX: 0, offsetY: 0 }, "linear", "screen");
            setVisibleKey(track, fr, s.visible !== false);
            if (s.zoom_x != null || s.zoomX != null)
                setValueKey(track, "scaleX", fr, num((_c = s.zoom_x) !== null && _c !== void 0 ? _c : s.zoomX, baseZX) / baseZX * 100, "linear");
            if (s.zoom_y != null || s.zoomY != null)
                setValueKey(track, "scaleY", fr, num((_d = s.zoom_y) !== null && _d !== void 0 ? _d : s.zoomY, baseZY) / baseZY * 100, "linear");
            if (s.angle != null)
                setValueKey(track, "rotation", fr, num(s.angle, baseAngle) - baseAngle, "linear");
            if (s.opacity != null)
                setValueKey(track, "opacity", fr, num(s.opacity, 255) * 100 / 255, "linear");
            if (s.z != null)
                setValueKey(track, "z", fr, num(s.z, 0), "linear");
            var fxKey = JSON.stringify([s.tone || null, s.color || null]);
            if (fxKey !== lastFx && (s.tone || s.color)) {
                track.fxOps.push({ name: "legacyFx", frame: fr, tone: s.tone || null, color: s.color || null });
                lastFx = fxKey;
            }
            max = Math.max(max, fr);
        }
    }
    catch (e_56_1) {
        e_56 = { error: e_56_1 };
    }
    finally {
        try {
            if (frames_2_1 && !frames_2_1.done && (_y = frames_2.return))
                _y.call(frames_2);
        }
        finally {
            if (e_56)
                throw e_56.error;
        }
    }
    track.importedBase = { zoomX: baseZX, zoomY: baseZY, angle: baseAngle };
    return max;
}
function shiftAnimatableFrames(obj, offset) {
    var e_57, _x, e_58, _y, e_59, _z, e_60, _0, e_61, _1, e_62, _2;
    var _a, _b, _c;
    if (!obj || !offset)
        return;
    try {
        for (var _3 = __values(obj.positionKeys || []), _4 = _3.next(); !_4.done; _4 = _3.next()) {
            var k = _4.value;
            k.frame = Number(k.frame || 0) + offset;
        }
    }
    catch (e_57_1) {
        e_57 = { error: e_57_1 };
    }
    finally {
        try {
            if (_4 && !_4.done && (_x = _3.return))
                _x.call(_3);
        }
        finally {
            if (e_57)
                throw e_57.error;
        }
    }
    try {
        for (var _5 = __values(obj.visibleKeys || []), _6 = _5.next(); !_6.done; _6 = _5.next()) {
            var k = _6.value;
            k.frame = Number(k.frame || 0) + offset;
        }
    }
    catch (e_58_1) {
        e_58 = { error: e_58_1 };
    }
    finally {
        try {
            if (_6 && !_6.done && (_y = _5.return))
                _y.call(_5);
        }
        finally {
            if (e_58)
                throw e_58.error;
        }
    }
    try {
        for (var _7 = __values(Object.values(obj.valueKeys || {})), _8 = _7.next(); !_8.done; _8 = _7.next()) {
            var arr = _8.value;
            try {
                for (var _9 = (e_60 = void 0, __values(arr || [])), _10 = _9.next(); !_10.done; _10 = _9.next()) {
                    var k = _10.value;
                    k.frame = Number(k.frame || 0) + offset;
                }
            }
            catch (e_60_1) {
                e_60 = { error: e_60_1 };
            }
            finally {
                try {
                    if (_10 && !_10.done && (_0 = _9.return))
                        _0.call(_9);
                }
                finally {
                    if (e_60)
                        throw e_60.error;
                }
            }
        }
    }
    catch (e_59_1) {
        e_59 = { error: e_59_1 };
    }
    finally {
        try {
            if (_8 && !_8.done && (_z = _7.return))
                _z.call(_7);
        }
        finally {
            if (e_59)
                throw e_59.error;
        }
    }
    try {
        for (var _11 = __values(obj.fxOps || []), _12 = _11.next(); !_12.done; _12 = _11.next()) {
            var op = _12.value;
            op.frame = Number((_c = (_a = op.frame) !== null && _a !== void 0 ? _a : (_b = op.args) === null || _b === void 0 ? void 0 : _b[0]) !== null && _c !== void 0 ? _c : 0) + offset;
        }
    }
    catch (e_61_1) {
        e_61 = { error: e_61_1 };
    }
    finally {
        try {
            if (_12 && !_12.done && (_1 = _11.return))
                _1.call(_11);
        }
        finally {
            if (e_61)
                throw e_61.error;
        }
    }
    try {
        for (var _13 = __values(obj.graphicSwitches || []), _14 = _13.next(); !_14.done; _14 = _13.next()) {
            var sw = _14.value;
            sw.frame = Number(sw.frame || 0) + offset;
        }
    }
    catch (e_62_1) {
        e_62 = { error: e_62_1 };
    }
    finally {
        try {
            if (_14 && !_14.done && (_2 = _13.return))
                _2.call(_13);
        }
        finally {
            if (e_62)
                throw e_62.error;
        }
    }
    obj.startFrame = Number(obj.startFrame || 0) + offset;
    obj.endFrame = Number(obj.endFrame || 0) + offset;
}
function applySceneEnvelope(a, envelope) {
    var e_63, _x, e_64, _y, e_65, _z;
    var _a, _b;
    if (!envelope || typeof envelope !== "object")
        return 0;
    var type = String(envelope.type || "").toLowerCase();
    if (type !== "explosion")
        return 0;
    var pre = Math.max(0, Number(envelope.pre_frames || 0));
    if (pre > 0) {
        shiftAnimatableFrames((_a = a.battlers) === null || _a === void 0 ? void 0 : _a.user, pre);
        shiftAnimatableFrames((_b = a.battlers) === null || _b === void 0 ? void 0 : _b.target, pre);
        try {
            for (var _0 = __values(a.tracks || []), _1 = _0.next(); !_1.done; _1 = _0.next()) {
                var t = _1.value;
                try {
                    for (var _2 = (e_64 = void 0, __values(t.clips || [])), _3 = _2.next(); !_3.done; _3 = _2.next()) {
                        var c = _3.value;
                        shiftAnimatableFrames(c, pre);
                    }
                }
                catch (e_64_1) {
                    e_64 = { error: e_64_1 };
                }
                finally {
                    try {
                        if (_3 && !_3.done && (_y = _2.return))
                            _y.call(_2);
                    }
                    finally {
                        if (e_64)
                            throw e_64.error;
                    }
                }
            }
        }
        catch (e_63_1) {
            e_63 = { error: e_63_1 };
        }
        finally {
            try {
                if (_1 && !_1.done && (_x = _0.return))
                    _x.call(_0);
            }
            finally {
                if (e_63)
                    throw e_63.error;
            }
        }
        try {
            for (var _4 = __values(a.events || []), _5 = _4.next(); !_5.done; _5 = _4.next()) {
                var ev = _5.value;
                ev.frame = Number(ev.frame || 0) + pre;
            }
        }
        catch (e_65_1) {
            e_65 = { error: e_65_1 };
        }
        finally {
            try {
                if (_5 && !_5.done && (_z = _4.return))
                    _z.call(_4);
            }
            finally {
                if (e_65)
                    throw e_65.error;
            }
        }
    }
    var covered = Math.max(0, Number(envelope.covered_custom_frames || 0)), fadeIn = Math.max(1, Number(envelope.black_fade_in || 14)), hold = Math.max(0, Number(envelope.black_hold || 14));
    a.events.push({ type: "screen_black_envelope", frame: 0, duration: pre + covered, fadeIn: fadeIn, hold: hold });
    var baseEnd = Number(a.duration || 0) + pre, wi = Math.max(1, Number(envelope.white_in || 6)), wh = Math.max(0, Number(envelope.white_hold || 12)), wo = Math.max(1, Number(envelope.white_out || 16));
    a.events.push({ type: "screen_white_envelope", frame: baseEnd, duration: wi + wh + wo, fadeIn: wi, hold: wh, fadeOut: wo });
    a.duration = Math.max(a.duration + pre, baseEnd + wi + wh + wo);
    a.source.sceneEnvelope = envelope;
    return pre;
}
function applyResolvedPictureFrames(obj, frames) {
    var e_66, _x;
    var _a;
    if (!Array.isArray(frames) || !frames.length)
        return 0;
    obj.positionKeys = [];
    obj.visibleKeys = [];
    obj.graphicSwitches = [];
    obj.fxOps = [];
    var max = 0, lastName = null, lastOrigin = null;
    try {
        for (var frames_3 = __values(frames), frames_3_1 = frames_3.next(); !frames_3_1.done; frames_3_1 = frames_3.next()) {
            var state = frames_3_1.value;
            var fr = Math.max(0, Math.round(num(state.frame, 0)));
            max = Math.max(max, fr);
            setPositionKey(obj, fr, { anchor: "screen", x: num(state.x), y: num(state.y), offsetX: 0, offsetY: 0 }, "linear", "screen");
            setVisibleKey(obj, fr, state.visible !== false);
            setValueKey(obj, "scaleX", fr, num(state.zoom_x, 100), "linear");
            setValueKey(obj, "scaleY", fr, num(state.zoom_y, 100), "linear");
            setValueKey(obj, "rotation", fr, num(state.angle, 0), "linear");
            setValueKey(obj, "opacity", fr, num(state.opacity, 255) * 100 / 255, "linear");
            setValueKey(obj, "z", fr, num(state.z, 0), "linear");
            setValueKey(obj, "blend", fr, num(state.blend_type, 0), "linear");
            var src = state.src || {};
            if (Number(src.width) > 0 && Number(src.height) > 0) {
                setValueKey(obj, "srcX", fr, num(src.x, 0), "linear");
                setValueKey(obj, "srcY", fr, num(src.y, 0), "linear");
                setValueKey(obj, "srcW", fr, num(src.width, 0), "linear");
                setValueKey(obj, "srcH", fr, num(src.height, 0), "linear");
                obj.graphic || (obj.graphic = {});
                obj.graphic.spritesheet = "code-grid";
                obj.graphic.cellW = Number(src.width);
                obj.graphic.cellH = Number(src.height);
            }
            var name = String(state.name || "");
            if (name && name !== lastName) {
                obj.graphicSwitches.push({ frame: fr, value: name });
                lastName = name;
                if (!((_a = obj.graphic) === null || _a === void 0 ? void 0 : _a.projectPath)) {
                    obj.graphic || (obj.graphic = {});
                    obj.graphic.source = "code";
                    obj.graphic.projectPath = name;
                    obj.graphic.externalRelativePath = name;
                    obj.graphic.name = (name.split(/[\\/]/).pop() || obj.name || "").replace(/\.[^.]+$/g, "");
                    obj.graphic.folder = name.includes("AnimationStudio") ? "AnimationStudio" : name.includes("BattleParticlesAnimations") ? "BattleParticlesAnimations" : name.includes("Battle animations") ? "Battle animations" : "Animations";
                }
            }
            var origin = String(state.origin || "").toLowerCase();
            if (origin && origin !== lastOrigin) {
                obj.graphic || (obj.graphic = {});
                obj.graphic.origin = origin.includes("bottom") ? "bottom" : origin.includes("center") ? "center" : origin.includes("top_left") ? "top_left" : obj.graphic.origin || "auto";
                lastOrigin = origin;
            }
            if (state.tone || state.color)
                obj.fxOps.push({ name: "legacyFx", frame: fr, tone: state.tone || null, color: state.color || null });
        }
    }
    catch (e_66_1) {
        e_66 = { error: e_66_1 };
    }
    finally {
        try {
            if (frames_3_1 && !frames_3_1.done && (_x = frames_3.return))
                _x.call(frames_3);
        }
        finally {
            if (e_66)
                throw e_66.error;
        }
    }
    return max;
}
export function animationFromCodeCapture(raw) {
    var e_67, _x, e_68, _y, e_69, _z, e_70, _0;
    var _a;
    var cap = (raw === null || raw === void 0 ? void 0 : raw.capture) || raw;
    if (!cap || typeof cap !== "object")
        return null;
    var name = cap.move || cap.class_name || cap.className || "Captured Code Animation", a = createAnimation(name);
    a.tracks[0].clips = [];
    a.source = { type: "code", path: cap.source_file || "", className: cap.class_name || "", approximate: false, importMode: "runtime_resolved_frames", capturedAt: cap.captured_at || null, move: cap.move || null, behavior: cap.behavior || "cinematic", sideContext: cap.side_context || ((Number(cap.user_index || 0) % 2 === 1) ? "foe" : "player"), opposing: (cap.side_context === "foe") || (Number(cap.user_index || 0) % 2 === 1), hitNum: Number(cap.hit_num || 0), captureMode: cap.capture_mode || "ops" };
    a.fps = Math.max(1, Number(cap.fps || 40));
    a.events = [];
    var max = 0;
    // The live battler snapshots are authoritative for the original battlers.
    // This prevents addSprite(us)/clones from being drawn on top of a base battler
    // that the Ruby code has already hidden or faded out.
    max = Math.max(max, addBattlerFrames(getBattlerTrack(a, "user"), cap.battler_frames, "user"), addBattlerFrames(getBattlerTrack(a, "target"), cap.battler_frames, "target"));
    try {
        for (var _1 = __values(cap.pictures || []), _2 = _1.next(); !_2.done; _2 = _1.next()) {
            var pic = _2.value;
            var role = String(pic.role || ""), isLive = role === "user" || role === "target";
            try {
                // SE/callback operations aren't visual state, so retain them even when the
                // picture itself is represented by resolved per-frame snapshots.
                for (var _3 = (e_68 = void 0, __values(pic.ops || [])), _4 = _3.next(); !_4.done; _4 = _3.next()) {
                    var op = _4.value;
                    var n = String(op.name || op.op || "");
                    if (n === "setSE") {
                        var args = op.args || [], pictureFps = Math.max(1, Number(cap.picture_fps || 20)), eventFrame = argn(args, 0, 0) * (a.fps / pictureFps);
                        a.events.push({ type: "se", frame: eventFrame, name: String((_a = decoded(args[1])) !== null && _a !== void 0 ? _a : ""), volume: argn(args, 2, 100), pitch: argn(args, 3, 100) });
                    }
                    else if (n === "setCallback")
                        a.runtimeNotes || (a.runtimeNotes = []);
                }
            }
            catch (e_68_1) {
                e_68 = { error: e_68_1 };
            }
            finally {
                try {
                    if (_4 && !_4.done && (_y = _3.return))
                        _y.call(_3);
                }
                finally {
                    if (e_68)
                        throw e_68.error;
                }
            }
            if (isLive)
                continue;
            var obj = createProjectile({ id: uid("clip"), name: pic.name || "Picture ".concat(pic.id), type: role.includes("clone") ? "battler-clone" : "code-capture" });
            obj.positionKeys = [];
            obj.visibleKeys = [];
            var init = pic.initial || {};
            setPositionKey(obj, 0, { anchor: "screen", x: num(init.x), y: num(init.y) }, "linear", "screen");
            setVisibleKey(obj, 0, init.visible !== false);
            if (role.includes("user_front")) {
                obj.graphic.source = "battler-user-front";
                obj.graphic.origin = "bottom";
            }
            else if (role.includes("target_front")) {
                obj.graphic.source = "battler-target-front";
                obj.graphic.origin = "bottom";
            }
            else if (role.includes("user")) {
                obj.graphic.source = "battler-user";
                obj.graphic.origin = "bottom";
            }
            else if (role.includes("target")) {
                obj.graphic.source = "battler-target";
                obj.graphic.origin = "bottom";
            }
            else {
                var asset = String(pic.asset || init.name || "");
                obj.graphic.source = "code";
                obj.graphic.projectPath = asset;
                obj.graphic.externalRelativePath = asset;
                obj.graphic.name = (asset.split(/[\\/]/).pop() || pic.name || "").replace(/\.[^.]+$/g, "");
                obj.graphic.folder = asset.includes("AnimationStudio") ? "AnimationStudio" : asset.includes("BattleParticlesAnimations") ? "BattleParticlesAnimations" : asset.includes("Battle animations") ? "Battle animations" : "Animations";
                var origin = String(pic.origin || init.origin || "").toLowerCase();
                obj.graphic.origin = origin.includes("bottom") ? "bottom" : origin.includes("center") ? "center" : origin.includes("top_left") ? "top_left" : "auto";
            }
            getEffectsTrack(a).clips.push(obj);
            var picMax = 0;
            if (Array.isArray(pic.frames) && pic.frames.length) {
                picMax = applyResolvedPictureFrames(obj, pic.frames);
            }
            else {
                try {
                    for (var _5 = (e_69 = void 0, __values(pic.ops || [])), _6 = _5.next(); !_6.done; _6 = _5.next()) {
                        var op = _6.value;
                        var n = String(op.name || op.op || "");
                        if (n === "setSE" || n === "setCallback")
                            continue;
                        var m = applyCapturedOp(a, obj, op);
                        picMax = Math.max(picMax, m);
                    }
                }
                catch (e_69_1) {
                    e_69 = { error: e_69_1 };
                }
                finally {
                    try {
                        if (_6 && !_6.done && (_z = _5.return))
                            _z.call(_5);
                    }
                    finally {
                        if (e_69)
                            throw e_69.error;
                    }
                }
            }
            max = Math.max(max, picMax);
            obj.startFrame = 0;
            obj.endFrame = Math.max(picMax, 0);
        }
    }
    catch (e_67_1) {
        e_67 = { error: e_67_1 };
    }
    finally {
        try {
            if (_2 && !_2.done && (_x = _1.return))
                _x.call(_1);
        }
        finally {
            if (e_67)
                throw e_67.error;
        }
    }
    // De-duplicate SEs recorded on multiple views of the same PictureEx.
    var seen = new Set();
    a.events = a.events.filter(function (ev) {
        var k = "".concat(ev.type, "|").concat(Math.round(num(ev.frame)), "|").concat(ev.name, "|").concat(ev.volume, "|").concat(ev.pitch);
        if (seen.has(k))
            return false;
        seen.add(k);
        return true;
    });
    max = Math.max(max, num(cap.frame_count, 0));
    a.duration = Math.max(1, Math.ceil(max));
    try {
        for (var _7 = __values(getEffectsTrack(a).clips), _8 = _7.next(); !_8.done; _8 = _7.next()) {
            var clip = _8.value;
            clip.endFrame = Math.max(Number(clip.endFrame || 0), a.duration);
        }
    }
    catch (e_70_1) {
        e_70 = { error: e_70_1 };
    }
    finally {
        try {
            if (_8 && !_8.done && (_0 = _7.return))
                _0.call(_7);
        }
        finally {
            if (e_70)
                throw e_70.error;
        }
    }
    applySceneEnvelope(a, cap.scene_envelope);
    return a;
}
// -----------------------------------------------------------------------------
// Vanilla / PkmnAnimations.rxdata importer
// -----------------------------------------------------------------------------
var LEGACY_NO_USER_COMMON = new Set(["Hail", "HarshSun", "HeavyRain", "Rain", "Sandstorm", "Sun", "ShadowSky", "Rainbow", "RainbowOpp", "SeaOfFire", "SeaOfFireOpp", "Swamp", "SwampOpp"]);
var LEGACY_HAS_TARGET_COMMON = new Set(["LeechSeed", "ParentalBond"]);
function legacyParticipation(rec, options) {
    if (options === void 0) {
        options = {};
    }
    var _a;
    var move = String(rec.move || String(rec.name || "").replace(/^(Common|Move|OppMove)\s*:\s*/i, ""));
    var common = (rec.catalogType === "common") || /^Common\s*:/i.test(String(rec.name || ""));
    var hasUser = true, hasTarget = true;
    if (common) {
        if (LEGACY_NO_USER_COMMON.has(move)) {
            hasUser = false;
            hasTarget = false;
        }
        else if (!LEGACY_HAS_TARGET_COMMON.has(move))
            hasTarget = false;
    }
    var target = String(options.moveTarget || ((_a = options.moveInfo) === null || _a === void 0 ? void 0 : _a.target) || "").replace(/[^A-Za-z]/g, "").toLowerCase();
    if (!common && target && ["user", "userside", "bothsides", "none", "allbattlers", "foeside"].includes(target))
        hasTarget = false;
    return { hasUser: hasUser, hasTarget: hasTarget, move: move };
}
export function animationFromLegacy(rec, options) {
    var e_71, _x, e_72, _y;
    if (options === void 0) {
        options = {};
    }
    var _a, _b, _c, _d, _e, _f, _g;
    var display = rec.move || String(rec.name || "Animation ".concat(rec.id)).replace(/^(Common|Move|OppMove)\s*:\s*/i, "");
    var a = createAnimation(display);
    a.tracks[0].clips = [];
    var importedOpposing = !!rec.opposing;
    a.source = { type: "vanilla", system: "vanilla", id: rec.id, move: rec.move || display, version: Number(rec.version || 0), opposing: importedOpposing, sideContext: importedOpposing ? "foe" : "player", catalogType: rec.catalogType || (/common/i.test(rec.name || "") ? "common" : "move"), path: rec.sourcePath || options.sourcePath || "", native: true };
    a.fps = 20;
    a.duration = Math.max(1, Number(rec.frame_max || ((_a = rec.frames) === null || _a === void 0 ? void 0 : _a.length) || 1));
    a.events = [];
    var participation = legacyParticipation(rec, options);
    a.noUser = !participation.hasUser;
    a.noTarget = !participation.hasTarget;
    var frames = rec.frames || [], idx = rec._animframe || {};
    var at = function (cell, name, fallback) { var _a, _b; var raw = (_b = (_a = idx[name]) !== null && _a !== void 0 ? _a : idx[String(name).toUpperCase()]) !== null && _b !== void 0 ? _b : fallback, i = Number(raw); return Number.isInteger(i) ? cell === null || cell === void 0 ? void 0 : cell[i] : undefined; };
    var oldUser = { x: 128, y: 224 }, oldTarget = { x: 384, y: 96 };
    var normalizeFocus = function (focus) { focus = Number(focus); return [0, 1, 2, 3, 4].includes(focus) ? focus : 4; };
    var effectiveFocus = function (focus) {
        var f = normalizeFocus(focus);
        if ((f === 1 || f === 3) && a.noTarget)
            f = 2;
        if ((f === 2 || f === 3) && a.noUser)
            f = 0;
        return f;
    };
    var graphicSig = function (cell) { var pat = num(at(cell, "pattern", 7), 0); return pat === -1 ? "USER" : pat === -2 ? "TARGET" : "SHEET:".concat(rec.graphic || rec.animation_name || ""); };
    var positionFor = function (x, y, rawFocus, isUser, isTarget) {
        var _x, _y;
        if (isUser)
            return { anchor: "user_battler", x: 0, y: 0, offsetX: x - oldUser.x, offsetY: y - oldUser.y };
        if (isTarget)
            return { anchor: "target_battler", x: 0, y: 0, offsetX: x - oldTarget.x, offsetY: y - oldTarget.y };
        var focus = effectiveFocus(rawFocus), valX = x, valY = y;
        if (rawFocus === 1) {
            valX -= oldTarget.x;
            valY -= oldTarget.y;
        }
        else if (rawFocus === 2) {
            valX -= oldUser.x;
            valY -= oldUser.y;
        }
        else if (rawFocus === 3) {
            var ux = oldUser.x, uy = oldUser.y, tx = oldTarget.x, ty = oldTarget.y;
            if (rec.opposing) {
                _x = __read([tx, ux], 2), ux = _x[0], tx = _x[1];
                _y = __read([ty, uy], 2), uy = _y[0], ty = _y[1];
            }
            valX = ((x - ux) / (tx - ux)) * 200;
            valY = ((y - uy) / (ty - uy)) * (-200);
        }
        // Official converter preserves screen coordinates when user/target participation
        // removes a legacy focus. Apply the same pseudo-focus correction.
        if (rawFocus !== focus) {
            var pseudo = rawFocus;
            if ((pseudo === 1 || pseudo === 3) && a.noTarget)
                pseudo = 2;
            if ((pseudo === 2 || pseudo === 3) && a.noUser) {
                valX += oldUser.x;
                valY += oldUser.y;
            }
        }
        if (focus === 1)
            return { anchor: "pbs:target", x: valX, y: valY, offsetX: 0, offsetY: 0 };
        if (focus === 2)
            return { anchor: "pbs:user", x: valX, y: valY, offsetX: 0, offsetY: 0 };
        if (focus === 3)
            return { anchor: "pbs:user_and_target", x: valX, y: valY, offsetX: 0, offsetY: 0 };
        return { anchor: "screen", x: valX, y: valY, offsetX: 0, offsetY: 0 };
    };
    var zFor = function (v, ci) {
        v = Number(v || 0);
        if (v === 0)
            return -50 + ci;
        if (v === 1)
            return 25 + ci;
        if (v === 2)
            return -25 + ci;
        if (v === 3)
            return ci;
        return v;
    };
    var propState = new WeakMap();
    var setStepped = function (obj, prop, frame, value) {
        var st = propState.get(obj);
        if (!st) {
            st = {};
            propState.set(obj, st);
        }
        var prev = st[prop];
        if (prev !== undefined && Object.is(prev, value))
            return;
        if (prev !== undefined && frame > 0 && !sortValueKeysCompat(obj, prop).some(function (k) { return k.frame === frame - 1; }))
            setValueKey(obj, prop, frame - 1, prev, "linear");
        setValueKey(obj, prop, frame, value, "linear");
        st[prop] = value;
    };
    function sortValueKeysCompat(obj, prop) { var _a; obj.valueKeys || (obj.valueKeys = {}); (_a = obj.valueKeys)[prop] || (_a[prop] = []); return obj.valueKeys[prop]; }
    var applyCell = function (obj, cell, f, ci, isUser, isTarget) {
        var rawFocus = normalizeFocus(at(cell, "focus", 26)), focus = effectiveFocus(rawFocus), x = num(at(cell, "x", 0), 0), y = num(at(cell, "y", 1), 0), pt = positionFor(x, y, rawFocus, isUser, isTarget);
        // A position change in legacy is instantaneous at the frame boundary; preserve the old value until f-1.
        var ks = sortPositionKeys(obj), last = ks.at(-1);
        if (last && f > 0 && last.frame < f - 1)
            setPositionKey(obj, f - 1, last.point, "linear", last.point.anchor);
        setPositionKey(obj, f, pt, "linear", pt.anchor);
        setStepped(obj, "scaleX", f, num(at(cell, "zoomx", 2), 100));
        setStepped(obj, "scaleY", f, num(at(cell, "zoomy", 11), num(at(cell, "zoomx", 2), 100)));
        setStepped(obj, "rotation", f, num(at(cell, "angle", 3), 0));
        setStepped(obj, "opacity", f, num(at(cell, "opacity", 8), 255) * 100 / 255);
        setStepped(obj, "blend", f, num(at(cell, "blendtype", 5), 0));
        setStepped(obj, "flip", f, num(at(cell, "mirror", 4), 0) ? 1 : 0);
        if (!isUser && !isTarget)
            setStepped(obj, "z", f, zFor(at(cell, "priority", 25), ci));
        var pat = num(at(cell, "pattern", 7), 0);
        if (!isUser && !isTarget && pat >= 0)
            setStepped(obj, "graphicFrame", f, pat);
        var tone = { red: num(at(cell, "tonered", 16), 0), green: num(at(cell, "tonegreen", 17), 0), blue: num(at(cell, "toneblue", 18), 0), gray: num(at(cell, "tonegray", 19), 0) };
        var color = { red: num(at(cell, "colorred", 12), 0), green: num(at(cell, "colorgreen", 13), 0), blue: num(at(cell, "colorblue", 14), 0), alpha: num(at(cell, "coloralpha", 15), 0) };
        obj.fxOps || (obj.fxOps = []);
        var lfx = obj.fxOps.at(-1);
        if (!lfx || lfx.frame !== f || JSON.stringify(lfx.tone) !== JSON.stringify(tone) || JSON.stringify(lfx.color) !== JSON.stringify(color))
            obj.fxOps.push({ name: "legacyFx", frame: f, tone: tone, color: color });
    };
    try {
        // User and target are persistent tracks.
        for (var _z = __values([[0, "user"], [1, "target"]]), _0 = _z.next(); !_0.done; _0 = _z.next()) {
            var _1 = __read(_0.value, 2), ci = _1[0], side = _1[1];
            var obj = getBattlerTrack(a, side);
            obj.positionKeys = [];
            obj.visibleKeys = [];
            var present = side === "user" ? participation.hasUser : participation.hasTarget;
            if (!present) {
                setVisibleKey(obj, 0, false);
                continue;
            }
            for (var f = 0; f < frames.length; f++) {
                var cell = (_b = frames[f]) === null || _b === void 0 ? void 0 : _b[ci];
                if (!Array.isArray(cell)) {
                    setVisibleKey(obj, f, false);
                    continue;
                }
                setVisibleKey(obj, f, num(at(cell, "visible", 6), 1) === 1);
                applyCell(obj, cell, f, ci, side === "user", side === "target");
            }
        }
    }
    catch (e_71_1) {
        e_71 = { error: e_71_1 };
    }
    finally {
        try {
            if (_0 && !_0.done && (_x = _z.return))
                _x.call(_z);
        }
        finally {
            if (e_71)
                throw e_71.error;
        }
    }
    // Non-battler cells must split into a new particle when focus or graphic changes,
    // exactly like New Animation Editor's official old->new converter.
    var maxCells = Math.max.apply(Math, __spreadArray([0], __read(frames.map(function (f) { return Array.isArray(f) ? f.length : 0; })), false));
    var _loop_6 = function (ci) {
        var current = null, signature = null, part = 0;
        var close = function (f) {
            if (current) {
                setVisibleKey(current, f, false);
                current.endFrame = Math.max(current.startFrame, f);
                current = null;
                signature = null;
            }
        };
        for (var f = 0; f < frames.length; f++) {
            var cell = (_c = frames[f]) === null || _c === void 0 ? void 0 : _c[ci];
            if (!Array.isArray(cell)) {
                close(f);
                continue;
            }
            var focus = effectiveFocus(at(cell, "focus", 26)), gs = graphicSig(cell), sig = "".concat(focus, "|").concat(gs);
            if (!current || sig !== signature) {
                close(f);
                part++;
                current = createProjectile({ id: uid("clip"), name: "Cell ".concat(ci + 1).concat(part > 1 ? " \u00B7 ".concat(part) : ""), type: "vanilla-cell" });
                current.positionKeys = [];
                current.visibleKeys = [];
                current.valueKeys = Object.assign({}, current.valueKeys);
                current.startFrame = f;
                current.imported = { format: "vanilla", cellIndex: ci, focus: focus, locked: num(at(cell, "locked", 20), 0) === 1 };
                var pat = num(at(cell, "pattern", 7), 0);
                if (pat === -1) {
                    current.graphic.source = "battler-user";
                    current.graphic.origin = "bottom";
                }
                else if (pat === -2) {
                    current.graphic.source = "battler-target";
                    current.graphic.origin = "bottom";
                }
                else {
                    current.graphic.source = "legacy";
                    current.graphic.name = String(rec.graphic || rec.animation_name || "").replace(/\.png$/i, "");
                    current.graphic.folder = "Animations";
                    current.graphic.projectPath = "Graphics/Animations/".concat(String(rec.graphic || rec.animation_name || "").replace(/^Graphics[\\/]Animations[\\/]/i, ""));
                    current.graphic.spritesheet = "rmxp";
                    current.graphic.cellW = 192;
                    current.graphic.cellH = 192;
                    current.graphic.cols = 5;
                    current.graphic.hue = Number(rec.hue || 0);
                    if (options.sourceRoot)
                        current.graphic.externalGameRoot = options.sourceRoot;
                }
                getEffectsTrack(a).clips.push(current);
                signature = sig;
                setVisibleKey(current, 0, false);
                setVisibleKey(current, f, true);
            }
            setVisibleKey(current, f, num(at(cell, "visible", 6), 1) === 1);
            applyCell(current, cell, f, ci, false, false);
            current.endFrame = f;
        }
        close(frames.length);
    };
    for (var ci = 2; ci < maxCells; ci++) {
        _loop_6(ci);
    }
    // Legacy BG/FG timing commands become actual screen particles.
    var bg = null, fg = null;
    var screenParticle = function (kind, t) {
        var obj = kind === "background" ? bg : fg;
        if (obj)
            return obj;
        obj = createProjectile({ id: uid("clip"), name: kind === "background" ? "Legacy Background" : "Legacy Foreground", type: "legacy-".concat(kind) });
        obj.positionKeys = [];
        obj.visibleKeys = [];
        obj.positionKeys.push({ id: uid("key"), frame: 0, easing: "linear", point: { anchor: "screen", x: 0, y: 0, offsetX: 0, offsetY: 0 } });
        obj.visual.z = kind === "background" ? -10000 : 10000;
        obj.pbs = { focus: kind, tiled: true };
        obj.graphic.origin = "top_left";
        setVisibleKey(obj, 0, false);
        getEffectsTrack(a).clips.push(obj);
        if (kind === "background")
            bg = obj;
        else
            fg = obj;
        return obj;
    };
    var _loop_7 = function (t) {
        var fr = Math.max(0, Number(t.frame || 0)), type = Number(t.type || 0);
        if (type === 0) {
            if (t.name) {
                var se = String(t.name).replace(/\.(wav|ogg|mp3)$/i, "");
                if (!/[\/]/.test(se))
                    se = "Anim/".concat(se);
                a.events.push({ type: "se", frame: fr, name: se, volume: Number(t.volume || 100), pitch: Number(t.pitch || 100) });
            }
            else
                a.events.push({ type: "user_cry", frame: fr, volume: Number(t.volume || 100), pitch: Number(t.pitch || 100) });
            return "continue";
        }
        if (type >= 1 && type <= 4) {
            var kind = type <= 2 ? "background" : "foreground", obj_1 = screenParticle(kind, t);
            var dur_1 = (type === 2 || type === 4) ? Math.max(0, Number(t.duration || 0)) : 0;
            setVisibleKey(obj_1, fr, true);
            if (t.name) {
                obj_1.graphic.source = "legacy";
                obj_1.graphic.folder = "Animations";
                obj_1.graphic.name = String(t.name).replace(/\.png$/i, "");
                obj_1.graphic.projectPath = "Graphics/Animations/".concat(t.name);
                obj_1.graphic.spritesheet = "single";
                if (options.sourceRoot)
                    obj_1.graphic.externalGameRoot = options.sourceRoot;
            }
            else
                obj_1.graphic.syntheticColor = true;
            var end_1 = fr + dur_1, setK = function (prop, val, transform) {
                if (transform === void 0) {
                    transform = function (x) { return x; };
                }
                if (val == null)
                    return;
                if (dur_1 > 0) {
                    var old = sampleLegacyValue(obj_1, prop, fr, prop === "opacity" ? 0 : 0);
                    setValueKey(obj_1, prop, fr, old, "linear");
                }
                setValueKey(obj_1, prop, end_1, transform(Number(val)), "linear");
            };
            setK("opacity", t.opacity, function (x) { return x * 100 / 255; }); /* Legacy bgX/bgY are stored as the negative sprite origin; screen draw position is therefore +bgX/+bgY. */
            var p0 = { anchor: "screen", x: Number(t.x || 0), y: Number(t.y || 0), offsetX: 0, offsetY: 0 };
            setPositionKey(obj_1, end_1, p0, "linear", "screen");
            obj_1.fxOps.push({ name: "legacyBgFg", frame: fr, duration: dur_1, color: { red: Number(((_d = t.color) === null || _d === void 0 ? void 0 : _d[0]) || 0), green: Number(((_e = t.color) === null || _e === void 0 ? void 0 : _e[1]) || 0), blue: Number(((_f = t.color) === null || _f === void 0 ? void 0 : _f[2]) || 0), alpha: Number(((_g = t.color) === null || _g === void 0 ? void 0 : _g[3]) || 0) } });
            a.duration = Math.max(a.duration, end_1);
        }
    };
    try {
        for (var _2 = __values(rec.timing || []), _3 = _2.next(); !_3.done; _3 = _2.next()) {
            var t = _3.value;
            _loop_7(t);
        }
    }
    catch (e_72_1) {
        e_72 = { error: e_72_1 };
    }
    finally {
        try {
            if (_3 && !_3.done && (_y = _2.return))
                _y.call(_2);
        }
        finally {
            if (e_72)
                throw e_72.error;
        }
    }
    function sampleLegacyValue(o, prop, f, def) {
        var e_73, _x;
        var _a;
        var ks = (((_a = o.valueKeys) === null || _a === void 0 ? void 0 : _a[prop]) || []).slice().sort(function (x, y) { return x.frame - y.frame; });
        var v = def;
        try {
            for (var ks_2 = __values(ks), ks_2_1 = ks_2.next(); !ks_2_1.done; ks_2_1 = ks_2.next()) {
                var k = ks_2_1.value;
                if (k.frame > f)
                    break;
                v = k.value;
            }
        }
        catch (e_73_1) {
            e_73 = { error: e_73_1 };
        }
        finally {
            try {
                if (ks_2_1 && !ks_2_1.done && (_x = ks_2.return))
                    _x.call(ks_2);
            }
            finally {
                if (e_73)
                    throw e_73.error;
            }
        }
        return v;
    }
    a.duration = Math.max(a.duration, frames.length);
    return a;
}
