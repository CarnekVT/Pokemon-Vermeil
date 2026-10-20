// Run from LA BASE DE SKY:
// node --experimental-default-type=module DeveloperTests/LightingStudio/test_model.mjs
import assert from "node:assert/strict";
import {defaultProject,normalizeProject,normalizeLight,maskFilename,
  defaultTimeOfDay,normalizeTimeOfDay,evaluateTimeOfDay,normalizeSchedule,scheduleFactor} from "../../Plugins/MakerStudio/003_Editor/Mods/Lighting Studio/model.js";

const old={schema:1,maps:{"79":{enabled:true,ambient:{color:"#142439",darkness:.6},
 lights:[{id:"old_lamp",type:"radial",x:1,y:2,radiusPx:96} ]}}};
const loaded=normalizeProject(old);
assert.equal(loaded.maps["79"].lights.length,1);
assert.equal(loaded.maps["79"].lights[0].id,"old_lamp");
assert.equal(loaded.timeOfDay.enabled,false);
assert.equal(loaded.maps["79"].dayNightMode,"follow");

const light=normalizeLight({id:"cave_1",type:"mask",maskFile:"cueva_salida.png",widthPx:128,heightPx:96,rotation:90});
assert.equal(light.type,"mask");
assert.equal(light.maskFile,"cueva_salida.png");
assert.equal(light.widthPx,128);
assert.equal(light.rotation,90);
assert.equal(maskFilename("../evil.png"),"");
assert.equal(maskFilename("C:\\evil.png"),"");
assert.equal(maskFilename("valid.png"),"valid.png");

const project=defaultProject();
assert.equal(project.normalSettings.intensity,0.5);
assert.equal(project.normalSettings.warmup,true);
const normalized=normalizeProject({schema:1,normalSettings:{enabled:true,intensity:.35,warmup:false},timeOfDay:{enabled:true,source:"internal"},maps:{}});
assert.equal(normalized.normalSettings.intensity,.35);
assert.equal(normalized.normalSettings.warmup,false);
assert.equal(normalized.timeOfDay.source,"internal");

const timeline=defaultTimeOfDay();
const midnight=evaluateTimeOfDay(timeline,0);
const at24=evaluateTimeOfDay(timeline,24);
assert.equal(midnight.color,at24.color);
const atNoon=evaluateTimeOfDay(timeline,12);
assert.equal(atNoon.darkness,0);
assert.equal(evaluateTimeOfDay(timeline,18).darkness>atNoon.darkness,true);
assert.equal(normalizeTimeOfDay({enabled:true,source:"garbage"}).source,"real");
console.log("Lighting Studio model, masks and day/night tests passed");

const overnight=normalizeSchedule({enabled:true,startHour:19,endHour:7,fadeMinutes:20});
assert.equal(scheduleFactor(overnight,12),0);
assert.equal(scheduleFactor(overnight,0),1);
assert.equal(scheduleFactor(overnight,3),1);
assert.ok(Math.abs(scheduleFactor(overnight,19+10/60)-0.5)<1e-6);
assert.ok(Math.abs(scheduleFactor(overnight,6+50/60)-0.5)<1e-6);
assert.equal(scheduleFactor(normalizeSchedule({enabled:false}),12),1);
const scheduled=normalizeLight({type:'rectangle',schedule:overnight});
assert.equal(scheduled.schedule.enabled,true);
assert.equal(normalizeProject({schema:1,maps:{"79":{lights:[scheduled]}}}).maps["79"].lights[0].schedule.startHour,19);
assert.equal(evaluateTimeOfDay(defaultTimeOfDay(),11).darkness,0);
assert.ok(evaluateTimeOfDay(defaultTimeOfDay(),15).darkness<0.06);
