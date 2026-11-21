// Run from the repo root: node "LA BASE DE SKY/Plugins/MakerStudio/003_Editor/Mods/Battle Animation Studio/tests/forensics.test.mjs"
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const basDir = new URL("../", import.meta.url);
const source = await readFile(new URL("animation_forensics.js", basDir), "utf8");
const { auditBasAnimation, auditBasProject } = await import(
    "data:text/javascript;base64," + Buffer.from(source).toString("base64")
);
function clip(overrides={}) {
    return {id:"demo",name:"Demo",type:"projectile",startFrame:0,endFrame:20,
        graphic:{projectPath:"Graphics/Animations/demo.png"},positionKeys:[],
        visibleKeys:[],valueKeys:{},pbs:{},...overrides};
}
function animation(overrides={}) {
    return {id:"a",name:"Test",duration:30,fps:20,source:{targetScope:"single_foe"},
        tracks:[{type:"effects",clips:[clip()]}],events:[],...overrides};
}
{
    const a=animation();
    const before=JSON.stringify(a);
    const r=auditBasAnimation(a);
    assert.equal(r.totalClips,1);
    assert.equal(r.issues.length,0);
    assert.equal(JSON.stringify(a),before,"audit must never mutate project");
}
{
    const a=animation({tracks:[{clips:[clip({endFrame:80})]}],
        events:[{type:"se",frame:42,name:"Anim/Example"}]});
    const codes=auditBasAnimation(a).issues.map(x=>x.code);
    assert(codes.includes("CLIP_TAIL"));
    assert(codes.includes("EVENT_OUTSIDE"));
}
{
    const a=animation({tracks:[{clips:[clip({pbs:{
        emitter:"Straight",emitterRate:10000,emitterIntensity:5,
        emitterCommands:{emitting:[{frame:0,value:true},{frame:15,value:false}]}
    }})]}]});
    const result=auditBasAnimation(a);
    assert(result.peakParticles>=240);
    assert(result.issues.some(x=>x.code==="PREVIEW_PARTICLE_LIMIT"));
}
{
    const a=animation({tracks:[{clips:[clip({pbs:{
        emitter:"Straight",emitterCommands:{emitting:[{frame:0,value:true}]}
    }})]}]});
    assert(auditBasAnimation(a).cues.some(x=>x.kind==="emission-on"));
}
{
    const empty=auditBasProject({animations:[]});
    assert.equal(empty.animations.length,0);
    assert.equal(empty.clips,0);
}
{
    const project=JSON.parse(await readFile(new URL("../../../../../PBS/AnimationStudio/animations.json",basDir),"utf8"));
    const report=auditBasProject(project);
    assert.equal(report.animations.length,22,"actual Vermeil fixture");
    assert.equal(report.clips,114,"actual clip inventory");
    assert(report.animations.some(a=>a.name==="Ala Mortífera" && a.issues.some(i=>i.code==="CLIP_TAIL")));
    assert(report.animations.some(a=>a.name==="Lanzallamas" && a.issues.some(i=>i.code==="CLIP_TAIL")));
    const unchanged=JSON.stringify(project);
    auditBasProject(project);
    assert.equal(JSON.stringify(project),unchanged,"project must be read only");
}
console.log("BAS animation forensics: all 6 test groups passed");
