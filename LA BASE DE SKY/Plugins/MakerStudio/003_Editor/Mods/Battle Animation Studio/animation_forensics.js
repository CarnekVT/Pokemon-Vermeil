// Battle Animation Studio — animation forensics (no imported ROM content).
// Pure analysis of the *actual* BAS timeline; never mutates project, clips or runtime.
// QA patterns informed by https://github.com/originheartgold/origin-heart-gold-EN-translation
// work/advanced-ai/testbench/dev/animcheck.py and work/tools/emu_move_sweep.py.
const n = (v, fallback = 0) => { const x = Number(v); return Number.isFinite(x) ? x : fallback; };
const frameOf = (item) => n(item && item.frame);
const validArray = (v) => Array.isArray(v) ? v : [];
const isEmitter = (clip) => !!clip && !!clip.pbs && !!clip.pbs.emitter &&
    String(clip.pbs.emitter).toLowerCase() !== "none";
const fmt = (x) => Number.isInteger(x) ? String(x) : x.toFixed(1);
function sorted(items) { return validArray(items).slice().sort((a,b) => frameOf(a) - frameOf(b)); }
function sampleEmitterScalar(clip, name, frame, fallback) {
    const pbs = clip.pbs || {};
    const commands = validArray((pbs.emitterCommands || {})[name]);
    // This budget *estimate* uses the last completed command. The real preview
    // also supports interpolated duration/easing and contextual overrides.
    let value = n(pbs[name], fallback);
    for (const item of sorted(commands)) {
        if (frameOf(item) > frame + 1e-6) break;
        value = n(item.value, value);
    }
    return value;
}
function computeEmissionWindows(clip, duration) {
    const commands = sorted((clip.pbs.emitterCommands || {}).emitting);
    const windows = [];
    let start = null;
    for (const cmd of commands) {
        const frame = frameOf(cmd);
        if (frame > duration) break;
        if (start !== null) {
            windows.push({start, end: Math.max(start, frame - 1e-7)});
            start = null;
        }
        if (cmd.value) start = frame;
    }
    if (start !== null) windows.push({start, end: duration, open: true});
    return windows;
}
export function auditBasAnimation(animation) {
    const a = animation || {};
    const duration = Math.max(1, n(a.duration, 1));
    const fps = Math.max(1, n(a.fps, 20));
    const clips = validArray(a.tracks).flatMap(t => validArray(t.clips));
    const events = sorted(a.events);
    const issues = [];
    const cues = [];
    const rows = [];
    const addIssue = (severity, code, message, clip) =>
        issues.push({severity, code, message, objectId:clip && clip.id || null});
    const addCue = (frame, kind, title, objectId = null) =>
        cues.push({frame, kind, title, objectId});
    const maxFrame = Math.min(2500, Math.ceil(duration));
    const particleDelta = new Float64Array(maxFrame + 3);
    let particleEmissions = 0, emitterCount = 0;
    for (const clip of clips) {
        if (!clip) continue;
        const start = n(clip.startFrame, 0), end = n(clip.endFrame, start);
        const title = String(clip.name || clip.type || "Element");
        const emitter = isEmitter(clip);
        const pbs = clip.pbs || {};
        const keys = validArray(clip.positionKeys).length +
            Object.values(clip.valueKeys || {}).reduce((sum, arr) => sum + validArray(arr).length, 0) +
            validArray(clip.visibleKeys).length;
        const switches = sorted(clip.graphicSwitches);
        const commands = pbs.emitterCommands || {};
        const emitterKeys = Object.values(commands).reduce((sum, arr) => sum + validArray(arr).length, 0);
        rows.push({id:clip.id, name:title, type:String(clip.type || "element"), start, end,
            keys, emitterKeys, emitter:emitter ? String(pbs.emitter) : null,
            graphic:String((clip.graphic || {}).projectPath || ""), switches:switches.length});
        addCue(start, "start", title + " · inicio", clip.id);
        addCue(end, "end", title + " · fin", clip.id);
        if (end < start) addIssue("error","CLIP_NEGATIVE",
            title + ": el frame final (" + fmt(end) + ") es anterior al inicial (" + fmt(start) + ").", clip);
        if (end > duration + 0.001) addIssue("warning", "CLIP_TAIL",
            title + ": llega al frame " + fmt(end) + " y la animación termina en " + fmt(duration) + ".", clip);
        if (start < 0) addIssue("error","CLIP_START",
            title + ": empieza en un frame negativo (" + fmt(start) + ").", clip);
        for (const switchKey of switches) addCue(frameOf(switchKey), "graphic", title + " · cambio de gráfico", clip.id);
        if (clip.graphic && !clip.graphic.projectPath && !clip.graphic.name && !emitter)
            addIssue("info","GRAPHIC_EMPTY",title + ": no tiene una ruta gráfica explícita; comprobar si es procedural.",clip);
        if (!emitter) continue;
        emitterCount++;
        const emitting = validArray(commands.emitting);
        if (!emitting.length || !emitting.some(x => x && x.value)) {
            addIssue("warning","EMITTER_NEVER_STARTS",
                title + ": tiene emisor " + pbs.emitter + " pero no consta SetEmitting=true.",clip);
            continue;
        }
        for (const [name, list] of Object.entries(commands)) {
            const keysList = validArray(list);
            for (let i = 1; i < keysList.length; i++) {
                if (frameOf(keysList[i]) < frameOf(keysList[i-1])) {
                    addIssue("warning","UNSORTED_EMITTER_KEYS",
                        title + ": comandos " + name + " fuera de orden; el muestreo de BAS presupone orden.",clip);
                    break;
                }
            }
        }
        for (const command of sorted(emitting)) {
            const f = frameOf(command);
            addCue(f, command.value ? "emission-on" : "emission-off",
                title + (command.value ? " · emisión ON" : " · emisión OFF"),clip.id);
            if (f < start - 1e-3 || f > end + 1e-3)
                addIssue("info","EMISSION_OUTSIDE_CLIP",
                    title + ": cambio de emisión en " + fmt(f) + " fuera de su intervalo [" + fmt(start) + ", " + fmt(end) + "].",clip);
        }
        const windows = computeEmissionWindows(clip, duration);
        const last = sorted(emitting).filter(x => frameOf(x) <= duration).slice(-1)[0];
        if (last && !!last.value && end >= duration)
            addIssue("warning","EMITTER_UNCLOSED",
                title + ": sigue emitiendo al último frame; comprueba si debe apagarse explícitamente.",clip);
        const lifeSetting = pbs.simpleParticleLife && typeof pbs.simpleParticleLife === "object"
            ? Math.max(1,n(pbs.simpleParticleLife.duration,12)) : null;
        let guard = 0;
        for (const window of windows) {
            let f = window.start;
            while (f <= Math.min(window.end, end, maxFrame) + 1e-6 && guard++ < 16000) {
                const rate = Math.max(.01, sampleEmitterScalar(clip,"emitterRate",f,1));
                const intensity = Math.max(1, Math.round(sampleEmitterScalar(clip,"emitterIntensity",f,1)));
                const alive = lifeSetting !== null ? lifeSetting : Math.max(1,end - f);
                const startIndex = Math.max(0,Math.ceil(f));
                const endIndex = Math.min(maxFrame,Math.floor(f+alive));
                if (startIndex <= endIndex) {
                    particleDelta[startIndex] += intensity;
                    particleDelta[endIndex+1] -= intensity;
                    particleEmissions += intensity;
                }
                f += fps/rate;
            }
        }
        if (guard >= 16000) addIssue("warning","EMITTER_SAMPLING_BUDGET",
            title + ": más de 16000 muestras estimadas; revisa emisión, tasa e intervalos.",clip);
    }
    for (const ev of events) {
        const f = frameOf(ev);
        addCue(f,ev.type==="se"?"sound":ev.type==="screen_shake"?"shake":"event",
            (ev.type==="se" ? "SFX" : ev.type==="screen_shake" ? "Sacudida" : String(ev.type||"Evento")) +
            (ev.name ? " · " + ev.name : ""),null);
        if (f < 0 || f > duration) addIssue("warning","EVENT_OUTSIDE",
            "Evento " + String(ev.type||"?") + " en frame " + fmt(f) +
            " fuera de la duración " + fmt(duration) + ".",null);
        if (ev.type==="se" && !String(ev.name||"").trim())
            addIssue("warning","SOUND_WITHOUT_NAME","Un evento de sonido no tiene nombre de archivo.",null);
    }
    for (const [prop,list] of Object.entries((a.camera||{}).valueKeys||{})) {
        for (const key of validArray(list)) {
            if (!["cameraX","cameraY","cameraZoom","cameraRotation"].includes(prop)) continue;
            addCue(frameOf(key),"camera","Cámara · "+prop+" = "+String(key.value),a.camera.id || "camera_main");
        }
    }
    const scope = String((a.source||{}).targetScope||"");
    if (["all_battlers","all_foes","all_allies"].includes(scope) &&
        (a.source||{}).autoReplicateAffected===false && !validArray(a.contextTimelines).length)
        addIssue("info","MULTITARGET_CHECK",
            "Movimiento de objetivos múltiples sin réplica automática: comprueba 2v2/3v3.",null);
    let peakParticles = 0, live = 0;
    for (let f = 0; f <= maxFrame; f++) {
        live += particleDelta[f];
        peakParticles = Math.max(peakParticles,live);
    }
    if (peakParticles >= 240)
        addIssue("warning","PREVIEW_PARTICLE_LIMIT",
            "Estimación de "+Math.round(peakParticles)+" partículas simultáneas: supera el límite de preview en reproducción (240). No equivale a memoria real ni a la cifra del runtime.",null);
    if (duration > maxFrame)
        addIssue("info","LONG_TIMELINE","El cálculo de partículas se limitó a 2500 frames para proteger el editor.",null);
    cues.sort((a,b) => a.frame - b.frame ||
        (a.kind==="start" ? -1 : 0) - (b.kind==="start" ? -1 : 0));
    const rank = {error:0,warning:1,info:2};
    issues.sort((a,b) => rank[a.severity] - rank[b.severity]);
    return {animationId:a.id, name:String(a.name||"Sin título"), duration, fps,
        totalClips:clips.length, totalEvents:events.length, emitterCount,
        particleEmissions, peakParticles:Math.round(peakParticles),
        issues, rows, cues,
        source:{move:String((a.source||{}).move||""),scope,
            variants:validArray(a.contextTimelines).length}};
}
export function auditBasProject(project) {
    const list = validArray((project||{}).animations).map(auditBasAnimation);
    return {animations:list, warnings:list.reduce((sum,a)=>sum+a.issues.filter(x=>x.severity!=="info").length,0),
        clips:list.reduce((sum,a)=>sum+a.totalClips,0)};
}
