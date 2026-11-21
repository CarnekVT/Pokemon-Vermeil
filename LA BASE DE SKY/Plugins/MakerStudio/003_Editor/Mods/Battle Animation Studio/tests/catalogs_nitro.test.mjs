// node "LA BASE DE SKY/Plugins/MakerStudio/003_Editor/Mods/Battle Animation Studio/tests/catalogs_nitro.test.mjs"
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";
const root=new URL("../",import.meta.url);
const names=["animation_catalogs.js","model.js","category_starters.js","multi_system.js","nitro_script_bridge.js"];
const src=(await Promise.all(names.map(name=>readFile(new URL(name,root),"utf8"))))
    .map(code=>code.replace(/^import [^\n]+;$/gm,"").replace(/^export /gm,"")).join("\n");
const lib=vm.runInNewContext("(()=>{\n"+src+"\nreturn {BAS_ANIMATION_CATALOGS,normalizeBasCatalogType,createAnimation,normalizeProject,applyBasCategoryStarter,buildMultiSystemRegistry,parseNitroAnimationText,parseNitroResourceMap,createBasFromNitroText};})()",{
    structuredClone:globalThis.structuredClone
});
const catalog=lib.BAS_ANIMATION_CATALOGS;
assert.equal(catalog.length,13);
const animations=catalog.map(type=>{
    const a=lib.createAnimation("Example "+type.type,{catalogType:type.type,move:"EXAMPLE_"+type.type.toUpperCase()});
    lib.applyBasCategoryStarter(a);
    assert.equal(a.source.catalogType,type.type);
    if(!["move","common","custom"].includes(type.type)){
        assert(a.tracks[0].clips.length>=1);
        assert(a.tracks[0].clips.every(c=>c.graphic.source==="procedural"));
        assert(a.tracks[0].clips.every(c=>/^rgba\(/.test(c.graphic.proceduralColor)));
        if(["weather","terrain","field","transition"].includes(type.type)) {
            assert(a.tracks[0].clips.some(c=>c.positionKeys.some(p=>
                p.point.anchor==="screen" && p.point.x===256 && p.point.y===192)));
        }
        if(type.type!=="transition")assert(a.tracks[0].clips.length>=2);

    }
    return a;
});
const p=lib.normalizeProject({format:"vermeil-battle-animation-studio",version:1,animations});
const maps=lib.buildMultiSystemRegistry(p.animations);
assert.equal(Object.keys(maps).length,13);
for(const category of catalog)assert.equal(maps[category.mode].size,1);
assert.equal(lib.normalizeBasCatalogType("unknown"),"move");
const script=`a010_486:
loadparticlefromspa 0, 499
waitparticle
addparticle 0, 2, 3
playsepan 1911, -117
wait 2
unloadparticle 0
waitstate
end`;
const parsed=lib.parseNitroAnimationText(script);
assert.equal(parsed.frameCount,2);
assert.deepEqual(Array.from(parsed.spaIds),[499]);
assert.equal(parsed.particleSpawns,1);
assert.equal(parsed.seReferences[0].pan,-117);
assert(parsed.issues.some(i=>i.code==="asynchronous-wait"));
const result=lib.createBasFromNitroText(script,{id:"NITRO_486",placeholders:true});
const mapped=lib.createBasFromNitroText(script,{id:"NITRO_MAPPED",placeholders:true,
    graphicsMap:"499:2=Graphics/Animations/Converted.png",audioMap:"1911=Anim/ConvertedSound"});
assert.equal(mapped.animation.tracks[0].clips[0].graphic.projectPath,"Graphics/Animations/Converted.png");
assert.equal(mapped.animation.events.length,1);
assert.equal(mapped.animation.events[0].name,"Anim/ConvertedSound");
assert.equal(mapped.animation.events[0].frame,0);
assert.equal(mapped.animation.events[0].nitroPan,-117);
assert.equal(mapped.animation.source.nitroUnresolvedAudio.length,0);
assert.equal(mapped.animation.source.nitroUnresolvedGraphics.length,0);
assert.throws(()=>lib.parseNitroResourceMap("499=../secret.png","graphics"));
assert.throws(()=>lib.parseNitroResourceMap("1911=https://invalid.example/sound","audio"));
assert.throws(()=>lib.parseNitroResourceMap("1911=Anim/foo\n1911=Anim/dup","audio"));
assert.equal(result.animation.source.catalogType,"subanimation");
assert.equal(result.animation.source.runtimeEnabled,false);
assert.equal(result.animation.tracks[0].clips.length,1);
assert.equal(result.animation.tracks[0].clips[0].positionKeys[0].point.anchor,"user_battler");

// HGSS jumpifside 0 selects different scripted emitters for Player and Foe.
// Origin code 3 = user, 4 = target; never merge the two branches.
const branched=`a010_499:
loadparticlefromspa 0, 510
jumpifside 0, playerPart, enemyPart
end
playerPart:
addparticle 0, 7, 3
wait 8
unloadparticle 0
end
enemyPart:
addparticle 0, 9, 4
wait 12
unloadparticle 0
end`;
const left=lib.createBasFromNitroText(branched,{id:"SIDE",side:"player"});
const right=lib.createBasFromNitroText(branched,{id:"SIDE",side:"foe"});
assert.equal(left.analysis.frameCount,8);
assert.equal(right.analysis.frameCount,12);
assert.equal(left.analysis.particleSpawns,1);
assert.equal(right.analysis.particleSpawns,1);
assert.equal(left.animation.tracks[0].clips[0].positionKeys[0].point.anchor,"user_battler");
assert.equal(right.animation.tracks[0].clips[0].positionKeys[0].point.anchor,"target_battler");
assert.equal(left.animation.source.nitroImportSide,"player");
assert.equal(right.animation.source.nitroImportSide,"foe");

// A panned DS sequence can be mapped to a real Vermeil SFX, but the pan
// automation is recorded as metadata until a compatible Ruby player exists.
const pan=lib.createBasFromNitroText("playsepanmod 1993, -117, 117, 4, 2
end",{
    id:"PAN",audioMap:"1993=Anim/StereoSample"
});
assert.equal(pan.animation.events.length,1);
assert.equal(pan.animation.events[0].nitroPanEnd,117);
assert(pan.analysis.issues.some(x=>x.code==="pan-sweep-not-emulated"));
// Known HGSS macros are imported only on explicit opt-in. They create editable
// approximations, not claims about true DS waitstate or interpolation.
const nativeScript=`a010_487:
slideattackingmon -16, 8
wait 3
shaketargetmon 3, 7
shakescreen
flashscreencolor 31, 0, 0
shadetargetmon 0, 31, 0
waitstate
end`;
const withNative=lib.createBasFromNitroText(nativeScript,{
    id:"NATIVE",adaptNativeCues:true,placeholders:false
});
assert.equal(withNative.animation.source.nitroAdaptedNativeCues,5);
assert(withNative.animation.events.some(x=>x.type==="screen_shake" && x.nitroApproximate===true));
assert(withNative.animation.events.some(x=>x.type==="screen_flash"));
assert(withNative.animation.battlers.user.positionKeys.some(x=>x.point.offsetX===-16));
assert(withNative.animation.battlers.target.positionKeys.length>2);
assert(withNative.animation.battlers.target.valueKeys.toneGreen.some(x=>x.value===255));
const withoutNative=lib.createBasFromNitroText(nativeScript,{id:"NO_NATIVE"});
assert.equal(withoutNative.animation.events.length,0);
assert.equal(withoutNative.animation.battlers.user.positionKeys.length,1);

const original=JSON.parse(await readFile(new URL("../../../../../PBS/AnimationStudio/animations.json",root),"utf8"));
assert.equal(original.animations.length,22);
const normalizedOriginal=lib.normalizeProject(original);
assert.equal(normalizedOriginal.animations.length,22);
assert(original.animations.every((a,i)=>a.source.catalogType===normalizedOriginal.animations[i].source.catalogType));
console.log("13 catalogs, 10 differentiated procedural starters, Nitro scripts and mapped project resources, and legacy data: PASS");
