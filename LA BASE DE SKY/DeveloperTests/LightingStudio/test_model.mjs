// Run from LA BASE DE SKY:
// node --experimental-default-type=module DeveloperTests/LightingStudio/test_model.mjs
import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
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

const toneProject=normalizeProject({schema:1,
  timeOfDay:{enabled:true,blendMode:'tone',keyframes:[
    {hour:0,color:'#25334F',darkness:.37,tone:{red:-58,green:-58,blue:9,gray:30}},
    {hour:12,color:'#FFFFFF',darkness:0,tone:{red:0,green:0,blue:0,gray:0}}
  ]},maps:{}});
assert.equal(toneProject.timeOfDay.blendMode,'tone');
assert.equal(evaluateTimeOfDay(toneProject.timeOfDay,12).tone.red,0);
assert.equal(evaluateTimeOfDay(toneProject.timeOfDay,0).tone.gray,30);
assert.ok(evaluateTimeOfDay(toneProject.timeOfDay,6).tone.red<0);
assert.equal(defaultTimeOfDay().blendMode,'tone');
// Pokémon Fable tone anchors (Deo / Eevee Expo resource 50).
const expectedFable=[
  [0,[-30,-70,11,68]],
  [5,[-20,-60,-30,17]],
  [9,[0,0,0,0]],
  [17,[2,-20,3,17]],
  [21,[-30,-70,11,68]]
];
for(const [hour,rgba] of expectedFable){
  const t=evaluateTimeOfDay(defaultTimeOfDay(),hour).tone;
  assert.deepEqual([t.red,t.green,t.blue,t.gray],rgba);
}
const twilight=evaluateTimeOfDay(defaultTimeOfDay(),18).tone;
assert.deepEqual([twilight.red,twilight.green,twilight.blue,twilight.gray],[-8,-35,-6,28]);
const earlyNight=evaluateTimeOfDay(defaultTimeOfDay(),19).tone;
assert.deepEqual([earlyNight.red,earlyNight.green,earlyNight.blue,earlyNight.gray],[-18,-52,2,42]);
assert.ok(earlyNight.green<twilight.green);
assert.ok(earlyNight.gray>twilight.gray);
assert.deepEqual(evaluateTimeOfDay(defaultTimeOfDay(),20.75).tone,earlyNight);
assert.deepEqual(evaluateTimeOfDay(defaultTimeOfDay(),12).tone,{red:0,green:0,blue:0,gray:0});
const evening=evaluateTimeOfDay(defaultTimeOfDay(),19).tone;
assert.ok(evening.green<-20 && evening.green>-70);
assert.equal(evaluateTimeOfDay(defaultTimeOfDay(),23).tone.gray,68);
const legacyTone=normalizeTimeOfDay({blendMode:'overlay',keyframes:[
  {hour:0,color:'#112233',darkness:0.3},{hour:12,color:'#FFFFFF',darkness:0}
]});
assert.equal(legacyTone.blendMode,'overlay');
assert.equal(Number.isFinite(legacyTone.keyframes[0].tone.red),true);

console.log("Lighting Studio model, masks and day/night tests passed");

const overnight=normalizeSchedule({enabled:true,startHour:19,endHour:7,fadeMinutes:20});
assert.equal(scheduleFactor(overnight,12),0);
assert.equal(scheduleFactor(overnight,0),1);
assert.equal(scheduleFactor(overnight,3),1);
assert.ok(Math.abs(scheduleFactor(overnight,19+10/60)-0.5)<1e-6);
assert.ok(Math.abs(scheduleFactor(overnight,6+50/60)-0.5)<1e-6);
assert.equal(scheduleFactor(normalizeSchedule({enabled:false}),12),1);
const instant=normalizeSchedule({enabled:true,startHour:19,endHour:7,fadeMinutes:0,mode:'night'});
assert.equal(scheduleFactor(instant,19),1);
assert.equal(scheduleFactor(instant,7),0);
assert.equal(instant.mode,'night');

const scheduled=normalizeLight({type:'rectangle',schedule:overnight});
assert.equal(scheduled.schedule.enabled,true);
assert.equal(normalizeProject({schema:1,maps:{"79":{lights:[scheduled]}}}).maps["79"].lights[0].schedule.startHour,19);
assert.equal(evaluateTimeOfDay(defaultTimeOfDay(),11).darkness,0);
assert.ok(evaluateTimeOfDay(defaultTimeOfDay(),15).darkness<0.06);


// Prevent the editor defaults drifting from the actual 79 map's clock data.
const savedClock=JSON.parse(readFileSync("Data/LightingStudio/maps.json","utf8")).timeOfDay;
const defined=defaultTimeOfDay().keyframes;
assert.deepEqual(savedClock.keyframes,defined);
assert.equal(savedClock.source,"internal");
assert.equal(savedClock.enabled,true);
