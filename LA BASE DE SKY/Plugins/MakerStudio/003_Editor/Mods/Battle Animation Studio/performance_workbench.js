import { preflightBasProject } from "./performance_preflight.js";
// BAS performance workbench: project-native metrics, no Origin HG references.
export function openPerformanceWorkbenchDialog(showDialog, project, initialId, language, onJump) {
  if (!project || !Array.isArray(project.animations) || !project.animations.length) return null;
  const en=String(language||"es").toLowerCase().startsWith("en");
  const report=preflightBasProject(project);
  const node=(tag,txt,cls)=>{const e=document.createElement(tag);if(txt!==undefined)e.textContent=String(txt);if(cls)e.className=cls;return e;};
  let dialog=null;
  dialog=showDialog({title:en?"Animation performance":"Rendimiento de animaciones",width:"1060px",height:"740px",render(body){
    body.innerHTML='<div class="bas-perf-workbench"><div class="bas-perf-wb-top"><select class="bas-select" data-pw="animation"></select><select class="bas-select" data-pw="scenario"><option value="0">1v1</option><option value="1">2v2</option><option value="2">3v3</option></select></div><div class="bas-perf-wb-metrics" data-pw="metrics"></div><div class="bas-perf-wb-note" data-pw="note"></div><h3>Carga por fotograma</h3><div class="bas-perf-wb-chart" data-pw="chart"></div><h3>Emitters más costosos</h3><div class="bas-perf-wb-emitters" data-pw="emitters"></div><h3>Recomendaciones</h3><div class="bas-perf-wb-advice" data-pw="advice"></div></div>';
    const $=k=>body.querySelector('[data-pw="'+k+'"]');
    report.animations.forEach((x,i)=>{let o=node("option",x.name||"Animación "+(i+1));o.value=String(i);$("animation").appendChild(o);});
    $("animation").value=String(Math.max(0,report.animations.findIndex(x=>x.id===initialId)));
    const fmt=new Intl.NumberFormat(en?"en-US":"es-PE");
    function render(){
      const i=Math.max(0,Math.min(report.animations.length-1,Number($("animation").value)||0)),entry=report.animations[i];
      const data=entry.report,scenario=data.scenarios[Number($("scenario").value)||0],animation=project.animations[i];
      const metrics=$("metrics");metrics.replaceChildren();
      for(const [title,value] of [[en?"Peak particles":"Pico de partículas",scenario.peak],[en?"Total births":"Nacimientos",scenario.totalSpawns],["Emitters",scenario.emitterCount],[en?"Max/frame":"Máx. nuevas/frame",scenario.maxBirthPerFrame]]){
        const card=node("div",undefined,"bas-perf-wb-metric");card.append(node("b",fmt.format(value)),node("span",title));metrics.appendChild(card);
      }
      $("note").textContent=(scenario.overBudget?"⚠ Presupuesto estimado superado. ":"")+
        (en?"Prediction, not measured FPS. Runtime limit (240) applies per emitter.":"Estimación, no FPS medidos. El límite del runtime (240) se aplica por emitter.")+
        (scenario.partial?" Timeline analizada parcialmente.":"");
      const chart=$("chart");chart.replaceChildren();const values=scenario.density||[],max=Math.max(240,scenario.peak);
      values.forEach((value,k)=>{const bar=node("button",undefined,"bas-perf-wb-column"),f=Math.round(k/Math.max(1,values.length-1)*scenario.analyzedFrames);
        bar.type="button";bar.style.height=(5+Math.round(Math.min(1,value/max)*95))+"%";
        bar.dataset.hot=value>240?"high":value>170?"medium":"low";
        bar.title="Frame "+f+" · "+value+" partículas";bar.setAttribute("aria-label",bar.title);
        bar.onclick=async()=>{if(typeof onJump==="function"){const ok=await onJump(animation,f,null);if(ok!==false&&dialog&&dialog.close)dialog.close();}};
        chart.appendChild(bar);});
      const emitters=$("emitters");emitters.replaceChildren();
      if(!scenario.topEmitters.length)emitters.appendChild(node("p",en?"No active emitters.":"Sin emitters activos."));
      for(const x of scenario.topEmitters){const line=node("div",undefined,"bas-perf-wb-line"),button=node("button",en?"Locate":"Localizar","bas-perf-wb-btn");button.type="button";
        button.onclick=async()=>{if(typeof onJump==="function"){const ok=await onJump(animation,0,x.id);if(ok!==false&&dialog&&dialog.close)dialog.close();}};
        line.append(node("strong",x.name),node("span",x.peak+" pico · "+x.spawns+" nacimientos · "+x.copies+" copias"),button);emitters.appendChild(line);}
      const advice=$("advice");advice.replaceChildren();
      for(const issue of data.issues)advice.appendChild(node("p",issue.message,"bas-perf-wb-warning"));
      for(const tip of data.recommendations)advice.appendChild(node("p",tip,"bas-perf-wb-tip"));
    }
    $("animation").onchange=render;$("scenario").onchange=render;render();
  }});
  return dialog;
}
