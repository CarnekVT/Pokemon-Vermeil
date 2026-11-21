import { auditBasProject } from "./animation_forensics.js";

// This is a timeline inspector for Vermeil data. Origin HeartGold appears only
// as source-cited QA methodology, not as a fake animation/preset provider.
const SOURCE = "https://github.com/originheartgold/origin-heart-gold-EN-translation/blob/main/";
const ENTRIES = [
    ["animcheck.py · DS animation interpreter, particle loads and emitter commands",
     "work/advanced-ai/testbench/dev/animcheck.py"],
    ["emu_move_sweep.py · player/foe, timeout, hang and data-abort sweep",
     "work/tools/emu_move_sweep.py"],
    ["battle-hit-sound/fix.toml · sound at damage, separate from visual SFX",
     "work/patches/battle-hit-sound/fix.toml"],
    ["gfx.py · NCGR, NCLR, NSCR and NARC extraction, not a BAS pack",
     "work/tools/gfx.py"]
];
function textNode(tag, text, cls) {
    const el = document.createElement(tag);
    if (cls) el.className = cls;
    el.textContent = String(text == null ? "" : text);
    return el;
}
function link(label, url) {
    const a = textNode("a",label);
    a.href = url;
    a.rel = "noopener noreferrer";
    a.target = "_blank";
    return a;
}
function placeMarker(row, f, duration, type, label) {
    const marker = document.createElement("span");
    marker.className = "bas-forensic-marker bas-forensic-marker-" + type;
    marker.style.left = Math.min(100,Math.max(0,100*f/duration)) + "%";
    marker.title = label;
    row.appendChild(marker);
}
export function openAnimationForensicsDialog(showDialog, project, initialAnimationId, language, onJump) {
    if (!project || !Array.isArray(project.animations) || !project.animations.length) return null;
    const en = String(language||"es").toLowerCase().startsWith("en");
    const report = auditBasProject(project);
    let dialog = null;
    dialog = showDialog({
        title: en ? "Animation forensic analysis · Timelines and QA" : "Desglose de animaciones · Timeline y QA",
        width: "1120px",height:"760px",
        render(body) {
            body.innerHTML = `
<style>
.bas-forensic{display:grid;gap:10px;color:var(--text-primary,#e9eaf0);font:inherit;min-width:0}
.bas-forensic *{box-sizing:border-box}
.bas-forensic-intro{font-size:12px;line-height:1.55;color:var(--text-secondary,#c6c9d3);border:1px solid rgba(180,188,208,.22);border-radius:8px;padding:11px}
.bas-forensic-controls{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.bas-forensic-controls select{min-width:230px;max-width:100%;flex:1;border:1px solid rgba(170,176,205,.4);border-radius:7px;background:var(--bg-secondary,#262835);color:inherit;font:inherit;padding:8px}
.bas-forensic-summary{font-size:12px;color:var(--text-secondary,#bbc0cb)}
.bas-forensic-section{border:1px solid rgba(170,176,205,.23);border-radius:8px;padding:10px;min-width:0}
.bas-forensic-section h3{font-size:13px;margin:0 0 10px;color:var(--text-primary,#eff0f5)}
.bas-forensic-timeline{display:grid;gap:7px;max-height:230px;overflow-y:auto}
.bas-forensic-lane{display:grid;grid-template-columns:minmax(140px,210px) minmax(110px,1fr) 75px;gap:7px;align-items:center;font-size:11px}
.bas-forensic-lane-title{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bas-forensic-lane-meta{color:var(--text-secondary,#c6c8d2);text-align:right}
.bas-forensic-track{height:17px;position:relative;border-radius:4px;background:linear-gradient(90deg,transparent 24.8%,rgba(160,160,170,.14) 25%,transparent 25.2%,transparent 49.8%,rgba(160,160,170,.14) 50%,transparent 50.2%,transparent 74.8%,rgba(160,160,170,.14) 75%,transparent 75.2%),rgba(0,0,0,.15);overflow:hidden}
.bas-forensic-bar{position:absolute;top:4px;bottom:4px;background:#74a0de;border-radius:4px;min-width:2px}
.bas-forensic-bar.emitter{background:#bf9b68}
.bas-forensic-marker{position:absolute;top:0;bottom:0;width:2px;background:#e9c46a;z-index:2}
.bas-forensic-marker-sound{background:#75dfc7}
.bas-forensic-marker-shake{background:#e89a87}
.bas-forensic-marker-emission-on{background:#b6d886}
.bas-forensic-marker-emission-off{background:#d69094}
.bas-forensic-issues,.bas-forensic-cues{display:grid;gap:6px;max-height:215px;overflow-y:auto}
.bas-forensic-issue,.bas-forensic-cue{display:flex;gap:9px;align-items:flex-start;border-radius:6px;padding:6px 8px;background:rgba(115,125,155,.07);font-size:11px;line-height:1.4}
.bas-forensic-issue strong{font-size:10px;flex:0 0 auto;min-width:49px}
.bas-forensic-issue.error strong{color:#ee9999}
.bas-forensic-issue.warning strong{color:#e8c08f}
.bas-forensic-issue.info strong{color:#99bde5}
.bas-forensic-cue-frame{font-variant-numeric:tabular-nums;white-space:nowrap;min-width:54px;font-weight:600}
.bas-forensic-cue-label{flex:1;min-width:0;overflow-wrap:anywhere}
.bas-forensic-jump{cursor:pointer;flex:0 0 auto;padding:3px 7px;font:inherit;color:inherit;border:1px solid rgba(170,176,205,.3);background:var(--bg-secondary,#343848);border-radius:5px}
.bas-forensic-jump:hover{border-color:var(--accent,#80aaff)}
.bas-forensic-metrics{display:flex;flex-wrap:wrap;gap:9px;font-size:11px;color:var(--text-secondary,#cad0d9)}
.bas-forensic-metrics span{padding:4px 6px;background:rgba(180,190,220,.08);border-radius:5px}
.bas-forensic details{font-size:11px;line-height:1.5}
.bas-forensic details summary{cursor:pointer;font-weight:600}
.bas-forensic a{color:var(--accent,#9fbfff)}
.bas-forensic-source{display:grid;gap:4px;margin-top:8px}
@media(max-width:700px){.bas-forensic-lane{grid-template-columns:90px minmax(70px,1fr) 45px}.bas-forensic-controls select{min-width:100%}}
</style>
<div class="bas-forensic">
<div class="bas-forensic-intro" data-role="info"></div>
<div class="bas-forensic-controls">
<select data-role="selector"></select>
<span class="bas-forensic-summary" data-role="total"></span>
</div>
<div class="bas-forensic-metrics" data-role="metrics"></div>
<section class="bas-forensic-section">
<h3 data-role="heading-timeline"></h3>
<div class="bas-forensic-timeline" data-role="timeline"></div>
</section>
<section class="bas-forensic-section">
<h3 data-role="heading-issues"></h3>
<div class="bas-forensic-issues" data-role="issues"></div>
</section>
<section class="bas-forensic-section">
<h3 data-role="heading-cues"></h3>
<div class="bas-forensic-cues" data-role="cues"></div>
</section>
<details><summary data-role="heading-source"></summary>
<div class="bas-forensic-intro" data-role="source"></div></details>
</div>`;
            const $ = role => body.querySelector('[data-role="' + role + '"]');
            const sel = $("selector");
            $("info").textContent = en
                ? "Actual BAS keyframes, clips, emitters, sounds and camera cues are inspected without editing them. Particle load is estimated from preview cadence, NOT measured DS heap or Ruby memory. There is no ROM animation footage in these sources."
                : "Analiza los clips, keyframes, emitters, sonidos y cámara REALES del BAS sin modificarlos. La carga de partículas es una estimación de la cadencia del preview, NO memoria medida del juego o de la ROM. No se han extraído fotogramas de una ROM.";
            $("heading-timeline").textContent = en ? "Exact clip spans (frames)" : "Intervalos reales de los clips (frames)";
            $("heading-source").textContent = en ? "Verified Origin HeartGold source routines and limits" : "Rutinas verificadas de Origin HeartGold y límites";
            const source = $("source");
            source.appendChild(textNode("p",en
                ? "Source is a fan-translation project operating on a compiled Nintendo DS ROM. It has diagnostic tools and code patches, not exportable BAS attack timelines. In particular: interpreter command 0x33 loads particle resources, 0x2E starts emitters, double battles expose memory leaks and missing parameters, and the hit SE belongs to the damage command rather than the move animation."
                : "La fuente trabaja sobre una ROM Nintendo DS compilada. Contiene instrumentos de diagnóstico y parches, no timelines exportables al BAS. En particular: comando 0x33 carga recursos de partículas, 0x2E maneja emitters, las dobles detectan fugas y parámetros ausentes, y el sonido de golpe pertenece al comando de daño, separado del efecto visual."));
            const sources = textNode("div","","bas-forensic-source");
            ENTRIES.forEach(([name,path]) => sources.appendChild(link(name,SOURCE+path)));
            source.appendChild(sources);
            report.animations.forEach((r,index) => {
                const option = document.createElement("option");
                option.value = String(index);
                option.textContent = r.name + " · " + r.duration + "f" +
                    (r.issues.length ? " · ⚠" + r.issues.filter(x=>x.severity!=="info").length : "");
                sel.appendChild(option);
            });
            const initialIndex = report.animations.findIndex(x=>x.animationId===initialAnimationId);
            sel.value = String(initialIndex < 0 ? 0 : initialIndex);
            const makeJump = (frame,objectId,animation) => {
                const button = textNode("button",en ? "Go to frame" : "Ir al frame","bas-forensic-jump");
                button.type = "button";
                button.addEventListener("click",async()=>{
                    if (typeof onJump !== "function") return;
                    try {
                        const ok = await onJump(animation,Math.max(0,Math.min(animation.duration,frame)),objectId);
                        if (ok !== false && dialog && typeof dialog.close === "function") dialog.close();
                    } catch (err) {
                        button.textContent = String(err && err.message || err);
                    }
                });
                return button;
            };
            const render = () => {
                const i = Math.max(0,Math.min(report.animations.length-1,Number(sel.value)||0));
                const data = report.animations[i];
                const animation = project.animations[i];
                const issues = $("issues");
                const timeline = $("timeline");
                const cues = $("cues");
                timeline.replaceChildren();
                issues.replaceChildren();
                cues.replaceChildren();
                $("total").textContent = (en ? "Project" : "Proyecto") + ": " +
                    report.animations.length + " anim. · " + report.clips + " clips · " +
                    report.warnings + (en ? " warnings" : " avisos");
                const metrics = $("metrics");
                metrics.replaceChildren();
                const dataPoints = [
                    (en?"Duration":"Duración")+": "+data.duration+"f @ "+data.fps+"fps",
                    "Clips: "+data.totalClips,"Emitters: "+data.emitterCount,
                    "SFX/events: "+data.totalEvents,
                    (en?"Estimated particle peak":"Pico estimado de partículas")+": "+data.peakParticles,
                    "Move: "+(data.source.move||"—"),
                    "Scope: "+(data.source.scope||"—")
                ];
                dataPoints.forEach(value=>metrics.appendChild(textNode("span",value)));
                const warnings = data.issues.filter(x=>x.severity!=="info").length;
                $("heading-issues").textContent = (en?"Checks":"Comprobaciones")+": "+warnings+
                    (en?" warnings / errors":" avisos / errores") + ", "+(data.issues.length-warnings)+" informativos";
                $("heading-cues").textContent = (en?"Chronological cues":"Desglose cronológico")+
                    " · "+data.cues.length+(en?" events":" eventos");
                for (const row of data.rows) {
                    const lane = textNode("div","","bas-forensic-lane");
                    const tag = textNode("span",row.name,"bas-forensic-lane-title");
                    tag.title = row.name+" · "+(row.emitter||row.type)+" · "+row.keys+" keys · "+row.emitterKeys+" emitter keys"+
                        (row.graphic?" · "+row.graphic:"");
                    const track = textNode("div","","bas-forensic-track");
                    const bar = textNode("span","","bas-forensic-bar"+(row.emitter?" emitter":""));
                    const start = Math.min(data.duration,Math.max(0,row.start));
                    const end = Math.min(data.duration,Math.max(0,row.end));
                    bar.style.left = 100*start/data.duration+"%";
                    bar.style.width = Math.max(.35,100*(end-start)/data.duration)+"%";
                    bar.title = row.start+"–"+row.end+" · "+(row.emitter||row.type);
                    track.appendChild(bar);
                    data.cues.filter(x=>x.objectId===row.id && (x.kind==="emission-on"||x.kind==="emission-off"))
                        .forEach(x=>placeMarker(track,x.frame,data.duration,x.kind,x.title));
                    const time = textNode("span",row.start+"–"+row.end,"bas-forensic-lane-meta");
                    lane.append(tag,track,time);
                    timeline.appendChild(lane);
                }
                if (!data.rows.length) timeline.appendChild(textNode("p",en?"No clips in this animation.":"Esta animación no tiene clips."));
                for (const issue of data.issues) {
                    const line=textNode("div","","bas-forensic-issue "+issue.severity);
                    line.appendChild(textNode("strong",issue.severity==="error"?"ERROR":issue.severity==="warning"?"AVISO":"INFO"));
                    line.appendChild(textNode("span",issue.message));
                    if (issue.objectId) line.appendChild(makeJump(0,issue.objectId,animation));
                    issues.appendChild(line);
                }
                if (!data.issues.length) issues.appendChild(textNode("p",en?"No structural warnings detected. This does not prove correct playback.":"Sin avisos estructurales detectados. Esto no demuestra que reproduzca bien."));
                for (const cue of data.cues) {
                    const line = textNode("div","","bas-forensic-cue");
                    line.append(
                        textNode("span","F"+Math.round(cue.frame),"bas-forensic-cue-frame"),
                        textNode("span",cue.title,"bas-forensic-cue-label"),
                        makeJump(cue.frame,cue.objectId,animation)
                    );
                    cues.appendChild(line);
                }
            };
            sel.addEventListener("change",render);
            render();
        }
    });
    return dialog;
}
